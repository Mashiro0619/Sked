import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../application/external_operation_coordinator.dart';
import '../../application/mutation_draft.dart';
import '../../application/operation_contracts.dart';
import '../bridge/generated/api/file_contracts.dart';
import '../bridge/generated/api/files.dart';
import '../bridge/rust_agent_client.dart';
import 'file_evidence.dart';

/// Owns native access and prepared file handles. Approval and the operation
/// journal remain with the application's existing external coordinator.
class AgentFileCoordinator {
  AgentFileCoordinator({
    required this._client,
    required this._external,
    required this._isAvailable,
  });

  final AgentRustClient _client;
  final ExternalOperationCoordinator _external;
  final bool Function() _isAvailable;
  final _accesses = <OperationScope, Future<_FileAccess>>{};
  final _writes = <String, _FileWrite>{};
  final _pending = <Future<void>>{};
  final _cleanupFailures = <(Object, StackTrace)>[];
  var _epoch = 0;
  var _closed = false;
  Future<void>? _closing;

  Future<FileResourceCapabilities> capabilities({
    required OperationScope scope,
    required FileResourceRef resource,
  }) => _use(scope, (access) => access.handle.capabilities(resource: resource));

  Future<FileDirectoryPage> list({
    required OperationScope scope,
    required FileResourceRef directory,
    String? cursor,
    required int pageSize,
  }) => _use(
    scope,
    (access) => access.handle.list(
      directory: directory,
      cursor: cursor,
      pageSize: pageSize,
    ),
  );

  Future<FileSearchPage> search({
    required OperationScope scope,
    required FileSearchRequest request,
    String? cursor,
    required int pageSize,
  }) => _use(
    scope,
    (access) => access.handle.search(
      request: request,
      cursor: cursor,
      pageSize: pageSize,
    ),
  );

  Future<void> closeCursor({
    required OperationScope scope,
    required String cursor,
  }) => _use(scope, (access) => access.handle.closeCursor(cursor: cursor));

  Future<FileSnapshot> snapshot({
    required OperationScope scope,
    required FileResourceRef source,
  }) => _use(scope, (access) => access.handle.snapshot(source: source));

  Future<FileSnapshot> snapshotInfo({
    required OperationScope scope,
    required String snapshotId,
  }) => _use(
    scope,
    (access) => access.handle.snapshotInfo(snapshotId: snapshotId),
  );

  Future<FileSnapshotChunk> readSnapshot({
    required OperationScope scope,
    required String snapshotId,
    required int offset,
    required int length,
  }) => _use(
    scope,
    (access) => access.handle.readSnapshot(
      snapshotId: snapshotId,
      offset: offset,
      length: length,
    ),
  );

  /// Transport chunks preserve surrogate pairs and have no total-size quota.
  /// The native digest is checked before this content can enter a write plan.
  Future<FileSnapshot> createTextSnapshot({
    required OperationScope scope,
    required String text,
  }) => _use(scope, (access) async {
    final contentId = await access.handle.beginContent();
    var finished = false;
    try {
      final digest = _DigestSink();
      final hashing = sha256.startChunkedConversion(digest);
      var offset = 0;
      try {
        for (var start = 0; start < text.length;) {
          _checkAccess(access);
          var end = start + 16 * 1024;
          if (end > text.length) end = text.length;
          if (end < text.length &&
              _isHighSurrogate(text.codeUnitAt(end - 1)) &&
              _isLowSurrogate(text.codeUnitAt(end))) {
            end--;
          }
          final bytes = Uint8List.fromList(
            utf8.encode(text.substring(start, end)),
          );
          hashing.add(bytes);
          final next = await access.handle.appendContent(
            contentId: contentId,
            offset: offset,
            bytes: bytes,
          );
          if (next != offset + bytes.length) _invalidSnapshot();
          offset = next;
          start = end;
        }
      } finally {
        hashing.close();
      }
      _checkAccess(access);
      final snapshot = await access.handle.finishContent(contentId: contentId);
      finished = true;
      if (snapshot.contentVersion.sha256 != digest.value?.toString() ||
          snapshot.contentVersion.byteLength != offset) {
        _invalidSnapshot();
      }
      return snapshot;
    } finally {
      if (!finished) {
        try {
          await access.handle.discardContent(contentId: contentId);
        } catch (error, stack) {
          _cleanupFailures.add((error, stack));
        }
      }
    }
  });

  Future<Map<String, Object?>> prepareWrite({
    required OperationScope scope,
    required FileWriteRequest request,
    String? textPreview,
  }) => _track(() async {
    final access = await _access(scope);
    _checkAccess(access);
    final handle = await access.handle.prepareWrite(request: request);
    _FileWrite? write;
    try {
      _checkAccess(access);
      final preview = fileWritePreviewJson(handle.preview());
      if (handle.writeId() != preview['writeId']) _invalidSnapshot();
      write = _FileWrite(access: access, handle: handle);
      final owned = write;
      final weak = WeakReference(owned);
      unawaited(scope.whenCancelled.then((_) => weak.target?.cancel()));
      final change = ResourceChange(
        key: fileWriteAction,
        before: preview['expected'],
        after: preview,
      );
      final plan = _external.prepare(
        scope: scope,
        action: fileWriteAction,
        arguments: {'request': fileWriteRequestJson(request), 'write': preview},
        version: preview['specDigest'],
        changes: [
          if (textPreview == null)
            change
          else
            ResourceChange(
              key: fileWriteAction,
              before: preview['expected'],
              after: {...preview, 'text': textPreview},
            ),
        ],
        receiptChanges: [change],
        validate: () {
          _checkAccess(access);
          if (owned.released) _expired();
        },
        execute: (operation) => _track(
          () async => fileWriteEffect(
            await owned.run(operation.operationId),
            expected: fileIdentityFromOperation(operation),
          ),
        ),
        readBack: readBack,
      );
      _writes[plan.id] = owned;
      return plan.summary();
    } catch (error, stack) {
      if (write != null) {
        await _releaseWrite(write);
      } else {
        for (final release in [handle.cancel, handle.dispose]) {
          try {
            release();
          } catch (error, stack) {
            _cleanupFailures.add((error, stack));
          }
        }
      }
      Error.throwWithStackTrace(error, stack);
    }
  });

  Future<FileWriteReceipt> inspect(FileWriteIdentity identity) =>
      _track(() async {
        if (_closed) _expired();
        final access = (await _client.core).openFileAccess();
        try {
          return await access.inspect(identity: identity);
        } finally {
          try {
            await access.close();
          } catch (error, stack) {
            _cleanupFailures.add((error, stack));
          }
          try {
            access.dispose();
          } catch (error, stack) {
            _cleanupFailures.add((error, stack));
          }
        }
      });

  Future<ExternalEffectResult> readBack(
    ExternalOperationContext operation,
  ) async {
    final identity = fileIdentityFromOperation(operation);
    try {
      return fileWriteEffect(await inspect(identity), expected: identity);
    } catch (error) {
      final details = fileErrorFromException(error);
      if (details == null) rethrow;
      return ExternalEffectResult(
        state: ExternalEffectState.unknown,
        dataStatus: ExternalDataState.unknown,
        details: {
          'fileIdentity': fileWriteIdentityJson(identity),
          'error': details,
        },
      );
    }
  }

  Future<Map<String, Object?>?> reconcileIfOwned(String operationId) async {
    final receipt = _external.status(operationId);
    if (receipt?.result['action'] != fileWriteAction) return null;
    return fileCommitResultJson(
      await _external.reconcile(operationId: operationId, readBack: readBack),
    );
  }

  /// Called by the same OperationExecutor that owns the external candidate.
  /// Cleanup failure is retained for draining without replacing its receipt.
  Future<void> discardPlan(String planId) => _track(() async {
    final write = _writes.remove(planId);
    if (write != null) await _releaseWrite(write);
  });

  void discardScope(OperationScope scope) {
    final access = _accesses.remove(scope);
    _cleanup(() => _releaseScope(scope, access));
  }

  void invalidate() {
    _epoch++;
    for (final write in _writes.values) {
      try {
        write.cancel();
      } catch (error, stack) {
        _cleanupFailures.add((error, stack));
      }
    }
    final accesses = Map.of(_accesses);
    _accesses.clear();
    for (final entry in accesses.entries) {
      _cleanup(() => _releaseScope(entry.key, entry.value));
    }
  }

  Future<void> _releaseScope(
    OperationScope scope,
    Future<_FileAccess>? pending,
  ) async {
    _FileAccess? access;
    try {
      access = await pending;
    } catch (_) {
      // A failed open already releases any handle it acquired.
    }
    try {
      access?.cancel();
    } catch (error, stack) {
      _cleanupFailures.add((error, stack));
    }
    final plans = _writes.entries
        .where((entry) => identical(entry.value.access.scope, scope))
        .toList();
    for (final entry in plans) {
      _writes.remove(entry.key);
      _external.discard(entry.key);
      try {
        entry.value.cancel();
      } catch (error, stack) {
        _cleanupFailures.add((error, stack));
      }
      await _releaseWrite(entry.value);
    }
    if (access != null) {
      try {
        await access.close();
      } catch (error, stack) {
        _cleanupFailures.add((error, stack));
      }
    }
  }

  Future<void> waitForPending() async {
    while (_pending.isNotEmpty) {
      await Future.wait(_pending.toList());
    }
    if (_cleanupFailures.isNotEmpty) {
      final (error, stack) = _cleanupFailures.first;
      Error.throwWithStackTrace(error, stack);
    }
  }

  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    _closed = true;
    invalidate();
    await waitForPending();
  }

  Future<T> _use<T>(
    OperationScope scope,
    Future<T> Function(_FileAccess) action,
  ) => _track(() async {
    final access = await _access(scope);
    _checkAccess(access);
    final result = await action(access);
    _checkAccess(access);
    return result;
  });

  Future<_FileAccess> _access(OperationScope scope) {
    _checkAdmission(scope, _epoch);
    final existing = _accesses[scope];
    if (existing != null) return existing;
    late Future<_FileAccess> opening;
    opening = _openAccess(scope, _epoch).onError((
      Object error,
      StackTrace stack,
    ) {
      if (identical(_accesses[scope], opening)) {
        unawaited(_accesses.remove(scope));
      }
      Error.throwWithStackTrace(error, stack);
    });
    _accesses[scope] = opening;
    return opening;
  }

  Future<_FileAccess> _openAccess(OperationScope scope, int epoch) async {
    final core = await _client.ensureInitialized();
    _checkAdmission(scope, epoch);
    final access = _FileAccess(scope, epoch, core.openFileAccess());
    try {
      _checkAccess(access);
      final weak = WeakReference(access);
      unawaited(scope.whenCancelled.then((_) => weak.target?.cancel()));
      return access;
    } catch (error, stack) {
      try {
        await access.close();
      } catch (error, stack) {
        _cleanupFailures.add((error, stack));
      }
      Error.throwWithStackTrace(error, stack);
    }
  }

  void _checkAdmission(OperationScope scope, int epoch) {
    scope.checkActive();
    if (_closed || !_isAvailable()) {
      throw const OperationProblem(
        OperationErrorCode.unsupported,
        'The application file service is unavailable.',
      );
    }
    if (epoch != _epoch) _expired();
  }

  void _checkAccess(_FileAccess access) {
    _checkAdmission(access.scope, access.epoch);
    if (access.closed) _expired();
  }

  Future<void> _releaseWrite(_FileWrite write) async {
    try {
      await write.close();
    } catch (error, stack) {
      _cleanupFailures.add((error, stack));
    }
  }

  void _cleanup(Future<void> Function() action) {
    unawaited(
      _track(action).catchError((Object error, StackTrace stack) {
        _cleanupFailures.add((error, stack));
      }),
    );
  }

  Future<T> _track<T>(Future<T> Function() action) {
    final result = Future<T>.sync(action);
    late final Future<void> marker;
    marker = result
        .then<void>((_) {}, onError: (Object _, StackTrace _) {})
        .whenComplete(() => _pending.remove(marker));
    _pending.add(marker);
    return result;
  }
}

class _FileAccess {
  _FileAccess(this.scope, this.epoch, this.handle);
  final OperationScope scope;
  final int epoch;
  final FileAccessHandle handle;
  bool closed = false;
  Future<void>? _closing;

  void cancel() {
    if (!closed) handle.cancel();
  }

  Future<void> close() => _closing ??= _close();
  Future<void> _close() async {
    Object? firstError;
    StackTrace? firstStack;
    try {
      cancel();
    } catch (error, stack) {
      firstError = error;
      firstStack = stack;
    }
    closed = true;
    try {
      await handle.close();
    } catch (error, stack) {
      firstError ??= error;
      firstStack ??= stack;
    }
    try {
      handle.dispose();
    } catch (error, stack) {
      firstError ??= error;
      firstStack ??= stack;
    }
    if (firstError != null) Error.throwWithStackTrace(firstError, firstStack!);
  }
}

class _FileWrite {
  _FileWrite({required this.access, required this.handle});
  final _FileAccess access;
  final PreparedFileWriteHandle handle;
  String? _operationId;
  Future<FileWriteReceipt>? _running;
  Future<void>? _closing;
  bool released = false;

  Future<FileWriteReceipt> run(String operationId) {
    if (released || (_operationId != null && _operationId != operationId)) {
      _expired();
    }
    _operationId = operationId;
    return _running ??= handle.startOnce(operationId: operationId);
  }

  void cancel() {
    if (!released) handle.cancel();
  }

  Future<void> close() => _closing ??= _close();
  Future<void> _close() async {
    Object? firstError;
    StackTrace? firstStack;
    if (_running == null) {
      try {
        cancel();
      } catch (error, stack) {
        firstError = error;
        firstStack = stack;
      }
    }
    try {
      await _running;
    } catch (_) {
      // The external coordinator observes or reconciles the original failure.
    }
    try {
      handle.dispose();
    } catch (error, stack) {
      firstError ??= error;
      firstStack ??= stack;
    } finally {
      released = true;
    }
    if (firstError != null) Error.throwWithStackTrace(firstError, firstStack!);
  }
}

class _DigestSink implements Sink<Digest> {
  Digest? value;
  @override
  void add(Digest data) => value = data;
  @override
  void close() {}
}

bool _isHighSurrogate(int value) => value >= 0xd800 && value <= 0xdbff;
bool _isLowSurrogate(int value) => value >= 0xdc00 && value <= 0xdfff;

Never _expired() => throw const OperationProblem(
  OperationErrorCode.expired,
  'The file access or prepared write is no longer current.',
);
Never _invalidSnapshot() => throw const OperationProblem(
  OperationErrorCode.storageFailure,
  'The immutable file content did not match its expected length or digest.',
);
