import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'selective_backup_models.dart';
import 'selective_restore_coordinator.dart';
import 'selective_restore_journal_stub.dart'
    if (dart.library.io) 'selective_restore_journal_io.dart';

abstract class SelectiveJournalStorage {
  Future<List<String?>> readSlots();
  Future<void> writeSlot(int slot, String source);
}

typedef SelectiveRestoreJournalFactory = SelectiveRestoreJournal Function();
SelectiveRestoreJournalFactory? _factory;
@visibleForTesting
void debugSetSelectiveRestoreJournalFactory(
  SelectiveRestoreJournalFactory? factory,
) => _factory = factory;
SelectiveRestoreJournal createSelectiveRestoreJournal() =>
    _factory?.call() ?? PersistentSelectiveRestoreJournal();

class PersistentSelectiveRestoreJournal implements SelectiveRestoreJournal {
  PersistentSelectiveRestoreJournal({SelectiveJournalStorage? storage})
    : _storage = storage ?? PlatformSelectiveJournalStorage();
  final SelectiveJournalStorage _storage;
  Future<void> _tail = Future.value();

  @override
  Future<SelectiveRestoreState?> read() =>
      _serialize(() async => _decodeSlots(await _storage.readSlots()).state);
  @override
  Future<void> write(SelectiveRestoreState state) =>
      _serialize(() => _save(state));
  @override
  Future<void> clear() => _serialize(() => _save(null));

  Future<void> _save(SelectiveRestoreState? state) async {
    final current = _decodeSlots(await _storage.readSlots());
    if (state == null && current.state != null && !current.state!.isComplete) {
      throw const SelectiveBackupException(
        SelectiveBackupError.conflict,
        'An unfinished restore journal cannot be cleared.',
      );
    }
    if (state != null &&
        current.state == null &&
        (state.completed != 0 || state.started)) {
      throw const SelectiveBackupException(
        SelectiveBackupError.conflict,
        'A restore must begin with its prepared target.',
      );
    }
    if (state != null && current.state != null) {
      final old = current.state!;
      if (state.restoreId != old.restoreId ||
          state.planFingerprint != old.planFingerprint ||
          canonicalBackupJson(
                state.targets.map((target) => target.toJson()).toList(),
              ) !=
              canonicalBackupJson(
                old.targets.map((target) => target.toJson()).toList(),
              ) ||
          state.completed < old.completed ||
          state.completed > old.completed + 1 ||
          state.completed == old.completed && old.started && !state.started) {
        throw const SelectiveBackupException(
          SelectiveBackupError.conflict,
          'Restore journal progress cannot replace its fixed target or move backwards.',
        );
      }
    }
    final payload = state == null ? null : jsonEncode(state.toJson());
    final encoded = jsonEncode({
      'version': 1,
      'revision': current.revision + 1,
      'payload': payload,
      'digest': backupDigest(utf8.encode(payload ?? 'null')),
    });
    if (utf8.encode(encoded).length > SelectiveBackupLimits.journalBytes) {
      backupLimit('The restore journal exceeds its byte budget.');
    }
    try {
      for (final slot in [(current.revision + 1) % 2, current.revision % 2]) {
        await _storage.writeSlot(slot, encoded);
        if ((await _storage.readSlots())[slot] != encoded) {
          throw StateError('Restore journal readback failed.');
        }
      }
    } catch (_) {
      try {
        if ((await _storage.readSlots()).every((source) => source == encoded)) {
          return;
        }
      } catch (_) {
        // Preserve the last readable journal; the host keeps its restore gate.
      }
      throw const SelectiveBackupException(
        SelectiveBackupError.unknown,
        'The restore journal write could not be confirmed.',
      );
    }
  }

  Future<T> _serialize<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }
}

({int revision, SelectiveRestoreState? state}) _decodeSlots(
  List<String?> slots,
) {
  if (slots.length != 2) backupInvalid('Invalid restore journal slot count.');
  final valid =
      <({int revision, String source, SelectiveRestoreState? state})>[];
  var damaged = false;
  for (final source in slots) {
    if (source == null) continue;
    try {
      if (utf8.encode(source).length > SelectiveBackupLimits.journalBytes) {
        backupLimit('The restore journal exceeds its byte budget.');
      }
      final decoded = jsonDecode(source);
      if (decoded is Map &&
          decoded['version'] is int &&
          decoded['version'] > 1) {
        throw const SelectiveBackupException(
          SelectiveBackupError.unsupportedVersion,
          'A newer application is required for this restore journal.',
        );
      }
      final json = backupMap(decoded, {
        'version',
        'revision',
        'payload',
        'digest',
      });
      if (json['version'] != 1 ||
          json['payload'] != null && json['payload'] is! String) {
        backupInvalid('Invalid restore journal envelope.');
      }
      final payload = json['payload'] as String?;
      if (json['digest'] != backupDigest(utf8.encode(payload ?? 'null'))) {
        backupInvalid('Restore journal checksum mismatch.');
      }
      valid.add((
        revision: backupInteger(
          json['revision'],
          min: 1,
          max: 9007199254740991,
        ),
        source: source,
        state: payload == null
            ? null
            : SelectiveRestoreState.fromJson(jsonDecode(payload)),
      ));
    } on SelectiveBackupException catch (error) {
      if (error.code == SelectiveBackupError.unsupportedVersion) rethrow;
      damaged = true;
    } catch (_) {
      damaged = true;
    }
  }
  if (valid.isEmpty) {
    if (damaged) {
      throw const SelectiveBackupException(
        SelectiveBackupError.unavailable,
        'The restore journal is damaged; existing data was preserved.',
      );
    }
    return (revision: 0, state: null);
  }
  valid.sort((a, b) => b.revision.compareTo(a.revision));
  if (valid.length > 1 &&
      valid[0].revision == valid[1].revision &&
      valid[0].source != valid[1].source) {
    throw const SelectiveBackupException(
      SelectiveBackupError.conflict,
      'Restore journal slots disagree.',
    );
  }
  return (revision: valid.first.revision, state: valid.first.state);
}
