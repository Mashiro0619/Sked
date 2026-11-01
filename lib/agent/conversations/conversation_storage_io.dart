import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import '../../services/app_storage_layout_io.dart';
import 'conversation_models.dart';
import 'conversation_storage.dart';
import 'conversation_storage_codec.dart';

class PlatformConversationStorage extends ConversationStorage {
  PlatformConversationStorage({AppStorageLayout? layout})
    : _layout = layout ?? AppStorageLayout(),
      super.base();

  final AppStorageLayout _layout;

  Future<File> _historyMarker() async => File(
    path.join(
      (await _layout.directory()).path,
      'Sked_agent_conversations.pending',
    ),
  );

  @override
  Future<String?> pendingHistoryBatch() async {
    final file = await _historyMarker();
    if (!await file.exists()) return null;
    if (await file.length() > 256) {
      throw const ConversationStorageException(
        'Invalid pending history marker.',
      );
    }
    final value = await file.readAsString();
    validatePendingHistoryBatch(value);
    return value;
  }

  @override
  Future<void> writePendingHistoryBatch(String? batchId) async {
    validatePendingHistoryBatch(batchId);
    final file = await _historyMarker();
    if (batchId == null) {
      if (await file.exists()) await file.delete();
    } else {
      await file.writeAsString(batchId, flush: true);
    }
    if (await pendingHistoryBatch() != batchId) {
      throw const ConversationStorageException(
        'History admission could not be verified.',
        outcomeUnknown: true,
      );
    }
  }

  Future<File> _file(int slot) async => File(
    path.join(
      (await _layout.directory()).path,
      'Sked_agent_conversations.$slot.json',
    ),
  );

  Future<String?> _read(File file) async {
    if (!await file.exists()) return null;
    if (await file.length() > ConversationArchive.maxBytes * 2 + 1024) {
      throw const ConversationStorageException(
        'Conversation storage exceeds its size budget.',
      );
    }
    try {
      return utf8.decode(await file.readAsBytes(), allowMalformed: false);
    } on FormatException {
      return '{invalid-encoding';
    }
  }

  @override
  Future<ConversationStorageLoad> load() async {
    final slots = <String?>[];
    for (var i = 0; i < 2; i++) {
      slots.add(await _read(await _file(i)));
    }
    return decodeConversationSlots(slots);
  }

  @override
  Future<void> save(String source, {required int revision}) async {
    final encoded = encodeConversationSlot(source, revision);
    final files = [await _file(revision % 2), await _file((revision + 1) % 2)];
    try {
      // Mirror the confirmed snapshot so recovery cannot resurrect content
      // deleted by a previously successful transaction from an older slot.
      for (final file in files) {
        await file.writeAsString(encoded, flush: true);
        if (await _read(file) != encoded) {
          throw const ConversationStorageException(
            'Conversation write could not be verified.',
            outcomeUnknown: true,
          );
        }
      }
    } catch (_) {
      try {
        final stored = [for (final file in files) await _read(file)];
        if (stored.every((value) => value == encoded)) return;
        if (stored.any((value) => value == encoded)) {
          throw const ConversationStorageException(
            'Conversation write is partially confirmed; reload before retrying.',
            outcomeUnknown: true,
          );
        }
      } catch (_) {
        throw const ConversationStorageException(
          'Conversation write outcome is unknown; reload before retrying.',
          outcomeUnknown: true,
        );
      }
      throw const ConversationStorageException(
        'Conversation write failed; reload before retrying.',
      );
    }
  }
}
