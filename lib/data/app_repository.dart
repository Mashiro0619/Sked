import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_data.dart';
import '../models/app_preference_write.dart';
import 'timetable_storage.dart';

/// Acknowledges the exact snapshot whose storage transaction completed.
@immutable
class RepositoryWriteReceipt {
  const RepositoryWriteReceipt({
    required this.committedSnapshot,
    required this.batchRevision,
    required this.dataSessionRevision,
  });

  final AppData committedSnapshot;
  final int batchRevision;
  final int dataSessionRevision;
}

/// Captured before a command can wait at a workspace or maintenance boundary.
@immutable
class RepositoryWriteContext {
  const RepositoryWriteContext._(
    this._repository,
    this._loadGeneration,
    this._persistedRevision,
    this._boundaryRevision,
    this.dataSessionRevision,
  );

  final Object _repository;
  final int _loadGeneration;
  final int _persistedRevision;
  final int _boundaryRevision;
  final int dataSessionRevision;
}

/// 应用所有持久化数据的唯一入口。
///
/// 设计目标：
/// - 把 AppData 整体快照的读取、串行写入与失败回滚收敛在同一个入口。
/// - 写入队列串行化（最近一次 save 排在最末），不会因为并发 UI 操作互相覆盖。
/// - 存储失败后关闭写门禁，必须重新加载并确认持久化状态后才能继续写入。
///
/// 注意：本类不持有任何业务逻辑，只负责 AppData 整体的读、合成、写。具体的
/// 课程/事件操作应该走 Service 层，再由 Provider 提交完整快照。
class AppRepository {
  AppRepository({required this._storage});

  final TimetableStorage _storage;

  AppData? _current;
  AppData? _lastPersisted;
  RecoveryStatus _lastRecoveryStatus = RecoveryStatus.none;
  StorageLoadStatus _lastLoadStatus = StorageLoadStatus.missing;
  List<String> _recoveryArtifacts = const [];
  var _canWrite = true;
  bool _isWriteStateUnknown = false;
  Future<void> _pendingWrite = Future.value();
  var _currentRevision = 0;
  int _writesInFlight = 0;
  final _identity = Object();
  var _loadGeneration = 0;
  var _persistedRevision = 0;
  var _writeBoundaryRevision = 0;
  _PendingWriteBatch? _tailBatch;

  /// 上一次 [load] 的恢复状态。UI 必须消费这个值以决定是否给用户提示
  /// （比如 banner 或设置页通知）。
  RecoveryStatus get lastRecoveryStatus => _lastRecoveryStatus;

  StorageLoadStatus get lastLoadStatus => _lastLoadStatus;

  bool get canWrite => _canWrite;

  bool get isWriteStateUnknown => _isWriteStateUnknown;

  List<String> get recoveryArtifacts => _recoveryArtifacts;

  /// 当前内存中的 AppData 快照。[load] 之前为 null。
  AppData? get current => _current;

  /// The last snapshot confirmed by storage, never an optimistic queued write.
  AppData? get persisted => _lastPersisted;

  RepositoryWriteContext captureWriteContext({
    required int dataSessionRevision,
  }) => RepositoryWriteContext._(
    _identity,
    _loadGeneration,
    _persistedRevision,
    _writeBoundaryRevision,
    dataSessionRevision,
  );

  /// Ends the current pending batch synchronously without skipping its write.
  void sealWriteBatch() {
    _writeBoundaryRevision += 1;
    _tailBatch = null;
  }

  /// 从底层存储加载一次。返回值为 null 表示首次启动或彻底无数据。
  ///
  /// 加载结果会被缓存到 [current]，恢复状态写入 [lastRecoveryStatus]。
  Future<AppData?> load() async {
    sealWriteBatch();
    _loadGeneration += 1;
    late final StorageLoadResult result;
    try {
      result = await _storage.load();
    } catch (error, stackTrace) {
      debugPrint('AppRepository: storage load failed: $error\n$stackTrace');
      _lastRecoveryStatus = RecoveryStatus.ioFailure;
      _lastLoadStatus = StorageLoadStatus.ioFailure;
      _recoveryArtifacts = const [];
      _canWrite = false;
      _current = null;
      _lastPersisted = null;
      _currentRevision += 1;
      _persistedRevision = _currentRevision;
      return null;
    }
    _lastRecoveryStatus = result.recoveryStatus;
    _lastLoadStatus = result.status;
    _recoveryArtifacts = List.unmodifiable(result.recoveryArtifacts);
    _canWrite = result.canWrite;
    if (result.canWrite) _isWriteStateUnknown = false;
    _current = result.data;
    _lastPersisted = result.data;
    _currentRevision += 1;
    _persistedRevision = _currentRevision;
    return _current;
  }

  /// 重新探测底层存储。I/O/权限问题消失后，成功结果会自动解除写门禁。
  Future<AppData?> retryLoad() async {
    sealWriteBatch();
    try {
      await _pendingWrite;
    } catch (_) {
      // The structured reload below decides whether writes may resume.
    }
    _pendingWrite = Future.value();
    return load();
  }

  /// Waits for writes that were already accepted by this repository.
  ///
  /// Backup restore uses this before taking its provider-level write lease so
  /// an earlier UI save cannot finish in the middle of the restore transaction.
  Future<void> waitForPendingWrites({bool propagateErrors = false}) async {
    sealWriteBatch();
    final observeFailure = propagateErrors && _writesInFlight > 0;
    while (true) {
      final pendingWrite = _pendingWrite;
      try {
        await pendingWrite;
      } catch (_) {
        if (observeFailure) rethrow;
        // The save caller observes the failure. Lease acquisition only needs
        // to wait for completion; storage failures are enforced by the gate.
      }
      await Future<void>.microtask(() {});
      if (identical(pendingWrite, _pendingWrite)) {
        return;
      }
    }
  }

  void blockWritesAfterInitializationFailure() {
    sealWriteBatch();
    _lastRecoveryStatus = RecoveryStatus.ioFailure;
    _lastLoadStatus = StorageLoadStatus.ioFailure;
    _canWrite = false;
  }

  /// 在损坏文件已经隔离后，以一份明确的新快照开始使用应用。
  ///
  /// 未来 schema 和 I/O 错误不能通过此入口覆盖；它们必须先升级应用或重试读取。
  Future<void> startFreshAfterRecovery(AppData data) async {
    if (_canWrite ||
        _lastLoadStatus != StorageLoadStatus.corrupt ||
        _recoveryArtifacts.isEmpty) {
      throw RecoveryWriteBlockedException(_lastLoadStatus);
    }
    final blockedStatus = _lastLoadStatus;
    final blockedRecoveryStatus = _lastRecoveryStatus;
    try {
      final revision = _replaceCurrent(data);
      await _awaitOrRollback(
        _enqueueWrite(
          data,
          revision: revision,
          allowWhileRecoveryBlocked: true,
        ),
        revision,
      );
    } catch (error) {
      if (error is! StorageWriteException) {
        _lastLoadStatus = blockedStatus;
        _lastRecoveryStatus = blockedRecoveryStatus;
      }
      rethrow;
    }
    _canWrite = true;
    _lastLoadStatus = StorageLoadStatus.success;
    _lastRecoveryStatus = RecoveryStatus.none;
  }

  /// 整份替换当前 AppData，并立即落盘（默认 flush=true，因为整份替换基本
  /// 都发生在导入、初始化等不能丢的场景）。
  Future<RepositoryWriteReceipt> save(
    AppData data, {
    int dataSessionRevision = 0,
    AppPreferenceWrite? preferenceWrite,
    RepositoryWriteContext? writeContext,
  }) async {
    _ensureWritable();
    final revision = _replaceCurrent(data);
    final pendingWrite = _enqueueWrite(
      data,
      revision: revision,
      dataSessionRevision: dataSessionRevision,
      preferenceWrite: preferenceWrite,
      writeContext: writeContext,
    );
    return _awaitOrRollback(pendingWrite, revision);
  }

  Future<String?> filePath() async {
    try {
      return await _storage.filePath();
    } catch (error, stackTrace) {
      debugPrint(
        'AppRepository: storage path unavailable: $error\n$stackTrace',
      );
      return null;
    }
  }

  Future<Uint8List?> readRecoveryArtifact(String artifactPath) async {
    if (!_recoveryArtifacts.contains(artifactPath)) return null;
    final storage = _storage;
    if (storage case final TimetableRecoveryArtifactReader reader) {
      return reader.readRecoveryArtifact(artifactPath);
    }
    return null;
  }

  Future<void> sanitizeLegacyAiApiSecretArtifacts() async {
    final storage = _storage;
    if (storage case final TimetableLegacySecretSanitizer sanitizer) {
      await sanitizer.sanitizeLegacyAiApiSecretArtifacts();
    }
  }

  void _ensureWritable() {
    if (!_canWrite) {
      throw RecoveryWriteBlockedException(_lastLoadStatus);
    }
  }

  void _blockWritesAfterStorageFailure() {
    sealWriteBatch();
    _lastRecoveryStatus = RecoveryStatus.ioFailure;
    _lastLoadStatus = StorageLoadStatus.ioFailure;
    _canWrite = false;
  }

  int _replaceCurrent(AppData data) {
    _current = data;
    _currentRevision += 1;
    return _currentRevision;
  }

  Future<RepositoryWriteReceipt> _awaitOrRollback(
    Future<RepositoryWriteReceipt> pendingWrite,
    int revision,
  ) async {
    try {
      return await pendingWrite;
    } catch (_) {
      if (_currentRevision == revision) {
        _current = _lastPersisted;
        _currentRevision += 1;
      }
      rethrow;
    }
  }

  Future<RepositoryWriteReceipt> _enqueueWrite(
    AppData data, {
    required int revision,
    int dataSessionRevision = 0,
    bool allowWhileRecoveryBlocked = false,
    AppPreferenceWrite? preferenceWrite,
    RepositoryWriteContext? writeContext,
  }) {
    final prepared =
        !allowWhileRecoveryBlocked &&
        preferenceWrite != null &&
        identical(preferenceWrite.snapshot, data) &&
        writeContext != null &&
        _isCurrentWriteContext(writeContext, dataSessionRevision);
    if (!prepared) sealWriteBatch();
    final tail = _tailBatch;
    if (prepared &&
        tail != null &&
        !tail.started &&
        _sameWriteContext(tail.context, writeContext) &&
        identical(tail.data, preferenceWrite.before) &&
        !tail.fields.any(preferenceWrite.fields.contains)) {
      // The verified before/after chain proves that every earlier command's
      // disjoint fields still exist in this exact final snapshot.
      tail.data = data;
      tail.revision = revision;
      tail.fields.addAll(preferenceWrite.fields);
      return tail.future;
    }
    final batch = _PendingWriteBatch(
      data: data,
      revision: revision,
      context: prepared ? writeContext : null,
      fields: prepared ? preferenceWrite.fields : const {},
    );
    _tailBatch = batch;
    _writesInFlight++;
    final write = _pendingWrite
        .catchError((e) {
          debugPrint(
            'AppRepository: previous write failed; continuing queue: $e',
          );
        })
        .then((_) async {
          batch.started = true;
          final data = batch.data;
          if (!allowWhileRecoveryBlocked) {
            _ensureAcceptedWriteStillWritable();
          }
          try {
            await _storage.save(data);
          } on StorageWriteException catch (error) {
            _isWriteStateUnknown = error is StorageWriteStateUnknownException;
            if (error is StorageWriteStateUnknownException) {
              _recoveryArtifacts = List.unmodifiable({
                ..._recoveryArtifacts,
                ...error.recoveryArtifacts,
              });
            }
            _blockWritesAfterStorageFailure();
            rethrow;
          }
          _lastPersisted = data;
          _persistedRevision = batch.revision;
          return RepositoryWriteReceipt(
            committedSnapshot: data,
            batchRevision: batch.revision,
            dataSessionRevision: dataSessionRevision,
          );
        });
    batch.future = write;
    _pendingWrite = write.then<void>((_) {});
    unawaited(
      _pendingWrite.then<void>(
        (_) {
          _writesInFlight--;
        },
        onError: (Object _, StackTrace _) {
          _writesInFlight--;
        },
      ),
    );
    return write;
  }

  bool _isCurrentWriteContext(RepositoryWriteContext context, int session) =>
      identical(context._repository, _identity) &&
      context._loadGeneration == _loadGeneration &&
      context._persistedRevision == _persistedRevision &&
      context._boundaryRevision == _writeBoundaryRevision &&
      context.dataSessionRevision == session;

  bool _sameWriteContext(RepositoryWriteContext? a, RepositoryWriteContext b) =>
      a != null &&
      identical(a._repository, b._repository) &&
      a._loadGeneration == b._loadGeneration &&
      a._persistedRevision == b._persistedRevision &&
      a._boundaryRevision == b._boundaryRevision &&
      a.dataSessionRevision == b.dataSessionRevision;

  void _ensureAcceptedWriteStillWritable() {
    if (!_canWrite) {
      throw AcceptedWriteBlockedException(_lastLoadStatus);
    }
  }
}

class _PendingWriteBatch {
  _PendingWriteBatch({
    required this.data,
    required this.revision,
    required this.context,
    required Set<AppPreferenceField> fields,
  }) : fields = {...fields};

  AppData data;
  int revision;
  final RepositoryWriteContext? context;
  final Set<AppPreferenceField> fields;
  bool started = false;
  late final Future<RepositoryWriteReceipt> future;
}

class RecoveryWriteBlockedException implements Exception {
  const RecoveryWriteBlockedException(this.status);

  final StorageLoadStatus status;

  @override
  String toString() =>
      'RecoveryWriteBlockedException: writes are blocked while storage status '
      'is ${status.name}.';
}

class AcceptedWriteBlockedException extends RecoveryWriteBlockedException {
  const AcceptedWriteBlockedException(super.status);

  @override
  String toString() =>
      'AcceptedWriteBlockedException: an accepted write was blocked before '
      'reaching storage because status is ${status.name}.';
}
