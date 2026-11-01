import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../utils/unique_id.dart';
import 'knowledge_models.dart';
import 'knowledge_storage.dart';

export 'knowledge_models.dart';
export 'knowledge_storage.dart';

/// A host-owned write reservation. It cannot be reconstructed from a tool
/// argument or backup. Normal editors remain blocked while the holder restores
/// a preflighted history batch, including after an uncertain owner save.
class KnowledgeUndoReservation {
  KnowledgeUndoReservation._(this.batchId);
  final String batchId;
}

class AgentKnowledgeRepository extends ChangeNotifier {
  AgentKnowledgeRepository({KnowledgeStorage? storage})
    : _storage = storage ?? KnowledgeStorage();
  final KnowledgeStorage _storage;
  KnowledgeArchive _archive = KnowledgeArchive();
  Future<void> _tail = Future.value();
  bool _loaded = false, _blocked = false, _frozen = false, _disposed = false;
  int _writeEpoch = 0;
  KnowledgeUndoReservation? _undoReservation;
  bool recovered = false;
  bool get isLoaded => _loaded;
  bool get isFrozen => _frozen;
  bool get canWrite =>
      _loaded &&
      !_blocked &&
      !_frozen &&
      !_disposed &&
      _undoReservation == null;
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
  KnowledgeUndoBatch? undoBatchFor(String operationId) => _archive.undoBatches
      .where((batch) => batch.operationId == operationId)
      .firstOrNull;

  Future<KnowledgeUndoReservation> reserveForHistoryUndo(String batchId) async {
    knowledgeText(batchId, max: 256);
    final current = _undoReservation;
    if (current != null) {
      if (current.batchId != batchId) _conflict();
      await _tail;
      _checkWritable(undoReservation: current);
      return current;
    }
    _checkWritable();
    final reservation = KnowledgeUndoReservation._(batchId);
    _undoReservation = reservation;
    // A queued, unaccepted editor must not cross the reserved history boundary.
    // Storage writes which have already started still complete and are drained.
    _writeEpoch++;
    _notify();
    try {
      await _tail;
      _checkWritable(undoReservation: reservation);
      return reservation;
    } catch (_) {
      // No history plan was accepted under this newly acquired owner. Keep a
      // failed store blocked, but do not leave an unreachable reservation that
      // prevents a reload from restoring ordinary editor access.
      if (identical(_undoReservation, reservation)) {
        _undoReservation = null;
        _writeEpoch++;
        _notify();
      }
      rethrow;
    }
  }

  void releaseHistoryUndo(KnowledgeUndoReservation reservation) {
    if (!identical(_undoReservation, reservation)) _conflict();
    _undoReservation = null;
    _writeEpoch++;
    _notify();
  }

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

  void validate(
    KnowledgeChangeSet plan, {
    KnowledgeUndoReservation? undoReservation,
  }) {
    _checkWritable(undoReservation: undoReservation);
    for (final change in plan.changes) {
      if (versionFor(change.key) != change.expectedRevision ||
          jsonEncode(find(change.key)?.toJson()) !=
              jsonEncode(change.before?.toJson())) {
        _conflict();
      }
    }
    if (_archive.receipts.any(
      (receipt) => receipt.inverseTargets.any(plan.inverseTargets.contains),
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
        receipt.inverseTargets.isNotEmpty ||
        _archive.receipts.any(
          (candidate) => candidate.inverseTargets.contains(operationId),
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

  /// Evaluates the complete selected range against a shadow copy before any
  /// inverse is accepted. Revisions rewind only in this private simulation;
  /// the published inverse advances every affected key once as a single save.
  KnowledgeChangeSet prepareInverseMany(
    Iterable<String> operationIds, {
    KnowledgeUndoReservation? undoReservation,
  }) {
    _checkWritable(undoReservation: undoReservation);
    final ids = operationIds.toList();
    if (ids.isEmpty ||
        ids.length > KnowledgeLimits.receipts ||
        ids.toSet().length != ids.length) {
      knowledgeInvalid('Select a bounded, unique operation range.');
    }
    final originals = <KnowledgeReceipt>[];
    for (final id in ids) {
      knowledgeText(id, max: 512);
      final receipt = receiptFor(id);
      if (receipt == null ||
          receipt.inverseTargets.isNotEmpty ||
          _archive.receipts.any((other) => other.inverseTargets.contains(id))) {
        _conflict();
      }
      originals.add(receipt);
    }
    originals.sort((a, b) => b.revision.compareTo(a.revision));
    final shadow = {for (final record in records) record.key: record};
    final versions = {
      ..._archive.tombstones,
      for (final record in records) record.key: record.revision,
    };
    final touched = <String>{};
    for (final receipt in originals) {
      for (final change in receipt.changes) {
        if (versions[change.key] != receipt.revision ||
            jsonEncode(shadow[change.key]?.toJson()) !=
                jsonEncode(change.after?.toJson())) {
          _conflict();
        }
        if (change.before == null) {
          shadow.remove(change.key);
        } else {
          shadow[change.key] = change.before!;
        }
        versions[change.key] = change.expectedRevision;
        touched.add(change.key);
        if (touched.length > 128) {
          throw const KnowledgeException(
            KnowledgeError.limit,
            'The complete inverse has too many targets.',
          );
        }
      }
    }
    final keys = touched.toList()..sort();
    return KnowledgeChangeSet(
      id: generateUuidV4(),
      inverseOperationIds: ids,
      changes: [
        for (final key in keys)
          KnowledgeChange(
            key: key,
            expectedRevision: versionFor(key),
            before: find(key),
            after: shadow[key],
          ),
      ],
    );
  }

  Future<KnowledgeUndoBatch> prepareInverseBatch({
    required String batchId,
    required List<String> operationIds,
    required KnowledgeUndoReservation reservation,
  }) {
    final epoch = _writeEpoch;
    final ids = List<String>.of(operationIds);
    return _enqueue(() async {
      if (epoch != _writeEpoch) _unavailable();
      _checkWritable(undoReservation: reservation);
      if (reservation.batchId != batchId) _conflict();
      final existing = _archive.undoBatches
          .where((item) => item.batchId == batchId)
          .firstOrNull;
      if (existing != null) {
        if (!listEquals(existing.operationIds, ids)) _conflict();
        return existing;
      }
      final operationId = 'history-undo:${knowledgeDigest(batchId)}';
      // An evicted owner ticket may not be regenerated against newer data.
      if (receiptFor(operationId) != null) _conflict();
      final plan = prepareInverseMany(ids, undoReservation: reservation);
      final batch = KnowledgeUndoBatch(
        batchId: batchId,
        operationId: operationId,
        plan: plan,
      );
      final retained = [..._archive.undoBatches];
      while (retained.length >= KnowledgeLimits.undoBatches) {
        final removable = retained.indexWhere(
          (item) => receiptFor(item.operationId)?.digest == item.digest,
        );
        if (removable < 0) {
          throw const KnowledgeException(
            KnowledgeError.limit,
            'Too many incomplete knowledge undo batches.',
          );
        }
        retained.removeAt(removable);
      }
      final prepared = KnowledgeArchive(
        revision: revision,
        storageRevision: _archive.storageRevision + 1,
        records: records,
        tombstones: _archive.tombstones,
        receipts: _archive.receipts,
        undoBatches: [...retained, batch],
      );
      // Include the eventual receipt and preserved owner plan in admission.
      // A cross-store coordinator must learn about this limit before the main
      // data owner has accepted its inverse.
      _projectCommit(plan, operationId, base: prepared).archive.encode();
      await _saveOwnerState(prepared);
      return batch;
    });
  }

  void validateInverseBatch(
    KnowledgeUndoBatch batch, {
    required KnowledgeUndoReservation reservation,
  }) {
    _checkWritable(undoReservation: reservation);
    if (reservation.batchId != batch.batchId ||
        undoBatchFor(batch.operationId)?.digest != batch.digest) {
      _conflict();
    }
    final receipt = receiptFor(batch.operationId);
    if (receipt != null) {
      if (receipt.digest != batch.digest) _conflict();
      return;
    }
    validate(batch.plan, undoReservation: reservation);
    _projectCommit(batch.plan, batch.operationId).archive.encode();
  }

  Future<KnowledgeReceipt> commitInverseBatch(
    KnowledgeUndoBatch batch, {
    required KnowledgeUndoReservation reservation,
  }) {
    validateInverseBatch(batch, reservation: reservation);
    return commit(
      batch.plan,
      operationId: batch.operationId,
      undoReservation: reservation,
      validateOwner: () =>
          validateInverseBatch(batch, reservation: reservation),
    );
  }

  /// Called only when the chat owner discarded an entirely unstarted batch.
  Future<void> discardInverseBatch(
    KnowledgeUndoBatch batch, {
    required KnowledgeUndoReservation reservation,
  }) => _enqueue(() async {
    _checkWritable(undoReservation: reservation);
    if (reservation.batchId != batch.batchId ||
        undoBatchFor(batch.operationId)?.digest != batch.digest ||
        receiptFor(batch.operationId) != null) {
      _conflict();
    }
    await _saveOwnerState(
      KnowledgeArchive(
        revision: revision,
        storageRevision: _archive.storageRevision + 1,
        records: records,
        tombstones: _archive.tombstones,
        receipts: _archive.receipts,
        undoBatches: _archive.undoBatches.where(
          (item) => item.operationId != batch.operationId,
        ),
      ),
    );
  });

  Future<KnowledgeReceipt> commit(
    KnowledgeChangeSet plan, {
    required String operationId,
    void Function()? validateOwner,
    KnowledgeUndoReservation? undoReservation,
  }) {
    final epoch = _writeEpoch;
    return _enqueue(() async {
      if (epoch != _writeEpoch) _unavailable();
      _checkWritable(undoReservation: undoReservation);
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
      validate(plan, undoReservation: undoReservation);
      final result = _projectCommit(plan, operationId);
      await _saveOwnerState(result.archive);
      return result.receipt;
    });
  }

  ({KnowledgeArchive archive, KnowledgeReceipt receipt}) _projectCommit(
    KnowledgeChangeSet plan,
    String operationId, {
    KnowledgeArchive? base,
  }) {
    final source = base ?? _archive;
    final nextRevision = source.revision + 1;
    final next = {for (final record in source.records) record.key: record};
    final deleted = Map<String, int>.of(source.tombstones);
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
      inverseOperationIds: plan.inverseOperationIds,
    );
    final receipts = [...source.receipts, receipt];
    final evictedReceiptIds = receipts
        .take(
          (receipts.length - KnowledgeLimits.receipts).clamp(
            0,
            receipts.length,
          ),
        )
        .map((item) => item.operationId)
        .toSet();
    final archive = KnowledgeArchive(
      revision: nextRevision,
      storageRevision: source.storageRevision + 1,
      records: next.values,
      tombstones: deleted,
      receipts: receipts.skip(
        (receipts.length - KnowledgeLimits.receipts).clamp(0, receipts.length),
      ),
      // A completed owner ticket cannot remain after its completion evidence
      // expires; otherwise it would be misclassified as an incomplete batch
      // and eventually consume every reserved history slot.
      undoBatches: source.undoBatches.where(
        (batch) => !evictedReceiptIds.contains(batch.operationId),
      ),
    );
    return (archive: archive, receipt: receipt);
  }

  Future<void> waitForPendingWrites() => _tail;

  Future<KnowledgeArchive> readFrozenForRestore({
    required void Function() validateOwner,
  }) => _enqueue(() async {
    if (!_frozen || _disposed || _undoReservation != null) _unavailable();
    validateOwner();
    try {
      final loaded = await _storage.load();
      validateOwner();
      _archive = loaded.archive;
      _loaded = true;
      _blocked = false;
      recovered = loaded.recovered;
      _notify();
      return _archive;
    } catch (_) {
      _blocked = true;
      _notify();
      rethrow;
    }
  });

  /// Produces a complete fixed target with only selected content replaced.
  /// Large selections use bounded receipt groups but one side-store write.
  KnowledgeArchive projectFrozenRestore(
    Iterable<KnowledgeRecord> selected, {
    required String restoreId,
    required void Function() validateOwner,
  }) {
    if (!_frozen ||
        _disposed ||
        !_loaded ||
        _blocked ||
        _undoReservation != null) {
      _unavailable();
    }
    validateOwner();
    final desired = selected.toList();
    if (desired.isEmpty ||
        desired.length > KnowledgeLimits.records ||
        desired.map((record) => record.key).toSet().length != desired.length) {
      knowledgeInvalid('Invalid selected knowledge restore targets.');
    }
    var result = _archive;
    for (var offset = 0; offset < desired.length; offset += 128) {
      final current = {for (final record in result.records) record.key: record};
      final plan = KnowledgeChangeSet(
        id: 'backup-$restoreId-$offset',
        changes: [
          for (final record in desired.skip(offset).take(128))
            KnowledgeChange(
              key: record.key,
              expectedRevision:
                  current[record.key]?.revision ??
                  result.tombstones[record.key] ??
                  0,
              before: current[record.key],
              after: record,
            ),
        ],
      );
      result = _projectCommit(
        plan,
        'backup-restore:$restoreId:$offset',
        base: result,
      ).archive;
    }
    KnowledgeArchive.decode(result.encode());
    return result;
  }

  Future<void> replaceFrozenForRestore(
    KnowledgeArchive target, {
    required void Function() validateOwner,
  }) => _enqueue(() async {
    if (!_frozen ||
        _disposed ||
        !_loaded ||
        _blocked ||
        _undoReservation != null) {
      _unavailable();
    }
    validateOwner();
    final source = target.encode();
    KnowledgeArchive.decode(source);
    if (target.storageRevision <= _archive.storageRevision &&
        source != _archive.encode()) {
      _conflict();
    }
    try {
      await _saveOwnerState(target);
      final confirmed = await _storage.load();
      validateOwner();
      if (confirmed.archive.encode() != source) {
        throw const KnowledgeException(
          KnowledgeError.unknown,
          'The knowledge restore could not be read back.',
        );
      }
    } catch (_) {
      _blocked = true;
      _notify();
      rethrow;
    }
  });

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

  void _checkWritable({KnowledgeUndoReservation? undoReservation}) {
    if (!_loaded ||
        _blocked ||
        _frozen ||
        _disposed ||
        !identical(_undoReservation, undoReservation)) {
      _unavailable();
    }
  }

  Future<void> _saveOwnerState(KnowledgeArchive archive) async {
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
