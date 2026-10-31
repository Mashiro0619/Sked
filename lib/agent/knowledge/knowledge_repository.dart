import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../utils/unique_id.dart';
import 'knowledge_models.dart';
import 'knowledge_storage.dart';

export 'knowledge_models.dart';
export 'knowledge_storage.dart';

class AgentKnowledgeRepository extends ChangeNotifier {
  AgentKnowledgeRepository({KnowledgeStorage? storage})
    : _storage = storage ?? KnowledgeStorage();
  final KnowledgeStorage _storage;
  KnowledgeArchive _archive = KnowledgeArchive();
  Future<void> _tail = Future.value();
  bool _loaded = false, _blocked = false, _frozen = false, _disposed = false;
  int _writeEpoch = 0;
  bool recovered = false;
  bool get isLoaded => _loaded;
  bool get canWrite => _loaded && !_blocked && !_frozen && !_disposed;
  bool get blocked => _blocked;
  KnowledgeArchive get snapshot => _archive;
  List<KnowledgeRecord> get records => _archive.records;
  int get revision => _archive.revision;
  KnowledgeRecord? find(String key) =>
      records.where((record) => record.key == key).firstOrNull;
  int versionFor(String key) =>
      find(key)?.revision ?? _archive.tombstones[key] ?? 0;
  KnowledgeReceipt? receiptFor(String operationId) => _archive.receipts
      .where((receipt) => receipt.operationId == operationId)
      .firstOrNull;

  Future<void> load() {
    final epoch = _writeEpoch;
    return _enqueue(() async {
      if (epoch != _writeEpoch) _unavailable();
      if (_disposed || _frozen) _unavailable();
      try {
        final loaded = await _storage.load();
        if (_disposed || _frozen || epoch != _writeEpoch) _unavailable();
        _archive = loaded.archive;
        recovered = loaded.recovered;
        _loaded = true;
        _blocked = false;
      } catch (_) {
        _blocked = true;
        rethrow;
      } finally {
        _notify();
      }
    });
  }

  /// Host-only preparation. A deleted ID requires an explicit restore/inverse.
  KnowledgeChangeSet prepare(
    Map<String, KnowledgeRecord?> desired, {
    bool allowRevive = false,
  }) {
    _checkWritable();
    if (desired.isEmpty || desired.length > 128) {
      knowledgeInvalid('Select 1–128 knowledge records.');
    }
    final changes = <KnowledgeChange>[];
    for (final entry in desired.entries) {
      final before = find(entry.key), after = entry.value;
      if (after != null && after.key != entry.key ||
          before == null && after == null) {
        knowledgeInvalid('Invalid knowledge target.');
      }
      if (!allowRevive &&
          before == null &&
          _archive.tombstones.containsKey(entry.key)) {
        _conflict();
      }
      changes.add(
        KnowledgeChange(
          key: entry.key,
          expectedRevision: versionFor(entry.key),
          before: before,
          after: after,
        ),
      );
    }
    return KnowledgeChangeSet(id: generateUuidV4(), changes: changes);
  }

  void validate(KnowledgeChangeSet plan) {
    _checkWritable();
    for (final change in plan.changes) {
      if (versionFor(change.key) != change.expectedRevision ||
          jsonEncode(find(change.key)?.toJson()) !=
              jsonEncode(change.before?.toJson())) {
        _conflict();
      }
    }
    if (plan.inverseOf != null &&
        _archive.receipts.any(
          (receipt) => receipt.inverseOf == plan.inverseOf,
        )) {
      _conflict();
    }
  }

  bool canUndo(String operationId) {
    try {
      prepareInverse(operationId);
      return true;
    } on KnowledgeException {
      return false;
    }
  }

  KnowledgeChangeSet prepareInverse(String operationId) {
    _checkWritable();
    final receipt = receiptFor(operationId);
    if (receipt == null ||
        receipt.inverseOf != null ||
        _archive.receipts.any(
          (candidate) => candidate.inverseOf == operationId,
        )) {
      _conflict();
    }
    final changes = <KnowledgeChange>[];
    for (final original in receipt.changes) {
      if (versionFor(original.key) != receipt.revision) _conflict();
      changes.add(
        KnowledgeChange(
          key: original.key,
          expectedRevision: receipt.revision,
          before: find(original.key),
          after: original.before,
        ),
      );
    }
    return KnowledgeChangeSet(
      id: generateUuidV4(),
      changes: changes,
      inverseOf: operationId,
    );
  }

  Future<KnowledgeReceipt> commit(
    KnowledgeChangeSet plan, {
    required String operationId,
    void Function()? validateOwner,
  }) {
    final epoch = _writeEpoch;
    return _enqueue(() async {
      if (epoch != _writeEpoch) _unavailable();
      _checkWritable();
      knowledgeText(operationId, max: 512);
      final old = receiptFor(operationId);
      if (old != null) {
        if (old.digest != plan.digest) {
          throw const KnowledgeException(
            KnowledgeError.duplicate,
            'An operation ID cannot target different knowledge changes.',
          );
        }
        return old;
      }
      validateOwner?.call();
      validate(plan);
      final nextRevision = revision + 1;
      final next = {for (final record in records) record.key: record};
      final deleted = Map<String, int>.of(_archive.tombstones);
      final accepted = <KnowledgeChange>[];
      for (final change in plan.changes) {
        final after = change.after?.copyWith(revision: nextRevision);
        if (after == null) {
          next.remove(change.key);
          deleted[change.key] = nextRevision;
        } else {
          next[change.key] = after;
          deleted.remove(change.key);
        }
        accepted.add(
          KnowledgeChange(
            key: change.key,
            expectedRevision: change.expectedRevision,
            before: change.before,
            after: after,
          ),
        );
      }
      final receipt = KnowledgeReceipt(
        operationId: operationId,
        digest: plan.digest,
        revision: nextRevision,
        changes: accepted,
        inverseOf: plan.inverseOf,
      );
      final receipts = [..._archive.receipts, receipt];
      final archive = KnowledgeArchive(
        revision: nextRevision,
        records: next.values,
        tombstones: deleted,
        receipts: receipts.skip(
          (receipts.length - KnowledgeLimits.receipts).clamp(
            0,
            receipts.length,
          ),
        ),
      );
      // Admission failures do not poison otherwise healthy storage.
      archive.encode();
      try {
        await _storage.save(archive);
        _archive = archive;
      } catch (_) {
        _blocked = true;
        _notify();
        rethrow;
      }
      _notify();
      return receipt;
    });
  }

  Future<void> waitForPendingWrites() => _tail;
  void freeze() {
    if (!_frozen) _writeEpoch++;
    _frozen = true;
    _notify();
  }

  /// A maintenance pass that did not replace this store may reopen its write
  /// gate after every accepted write settled. Failed/unknown storage remains
  /// blocked; only an explicit reload may recover it.
  void resumeAfterMaintenance() {
    if (_disposed) return;
    _frozen = false;
    _notify();
  }

  void resumeAfterFailedDataClear() {
    if (_disposed) return;
    _frozen = false;
    _blocked = true;
    _notify();
  }

  /// A restore barrier must reload the actual committed participant afterward.
  Future<void> resumeAndReload() {
    if (_disposed) _unavailable();
    _frozen = false;
    return load();
  }

  void _checkWritable() {
    if (!canWrite) _unavailable();
  }

  Never _unavailable() => throw const KnowledgeException(
    KnowledgeError.unavailable,
    'Knowledge storage is not ready.',
  );
  Never _conflict() => throw const KnowledgeException(
    KnowledgeError.conflict,
    'Knowledge changed after preparation.',
  );
  Future<T> _enqueue<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _frozen = true;
    _disposed = true;
    super.dispose();
  }
}
