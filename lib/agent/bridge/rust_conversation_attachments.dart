import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../utils/unique_id.dart';
import '../attachments/agent_attachment_controller.dart';
import '../conversations/conversation_models.dart';
import 'generated/api/contracts.dart' as native;
import 'generated/api/management_contracts.dart' as management;
import 'generated/api/models.dart' as view;
import 'rust_agent_client.dart';
import 'rust_storage_errors.dart';

class RustAttachmentReader implements AgentAttachmentReader {
  RustAttachmentReader(this.client);

  final AgentRustClient client;
  final _tokens = <AttachmentCancellation>{};
  final _reads = <Future<void>>{};
  bool _frozen = false;
  bool _closed = false;

  @override
  Future<Uint8List> readBytes(
    ConversationAttachment attachment, {
    AttachmentCancellation? cancellation,
  }) => _read(() async {
    final result = await client.query(
      native.AgentQuery(
        kind: native.QueryKind.attachmentBytes,
        attachment: _metadata(attachment),
      ),
    );
    return result.bytes ??
        (throw const AttachmentException(AttachmentError.missing));
  }, cancellation);

  @override
  Future<void> verify(
    ConversationAttachment attachment, {
    AttachmentCancellation? cancellation,
  }) => _read(() async {
    await (await client.ensureInitialized()).verifyAttachment(
      metadata: _metadata(attachment),
    );
  }, cancellation);

  Future<T> _read<T>(
    Future<T> Function() action,
    AttachmentCancellation? cancellation,
  ) async {
    if (_frozen || _closed) {
      throw const AttachmentException(AttachmentError.unavailable);
    }
    final token = cancellation ?? AttachmentCancellation();
    token.check();
    _tokens.add(token);
    final work = action();
    final settled = work.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _reads.add(settled);
    unawaited(settled.whenComplete(() => _reads.remove(settled)));
    try {
      return await token.guard(work);
    } catch (error) {
      throw attachmentErrorFromRust(error);
    } finally {
      _tokens.remove(token);
    }
  }

  Future<void> waitForPendingOperations() async {
    while (_reads.isNotEmpty) {
      await Future.wait(_reads.toList());
    }
  }

  Future<void> freezeAndDrain() async {
    _frozen = true;
    for (final token in _tokens.toList()) {
      token.cancel();
    }
    await waitForPendingOperations();
  }

  void resume() {
    if (!_closed) _frozen = false;
  }

  Future<void> close() async {
    _closed = true;
    await freezeAndDrain();
  }
}

/// Owns picker staging and UI progress. Rust publishes and collects saved blobs.
class RustConversationAttachments extends ChangeNotifier
    implements AgentAttachmentController {
  RustConversationAttachments({
    required this.client,
    required this.readConversation,
    required this.publishSnapshot,
    this.stagingDirectory,
    this.resolveStagingDirectory,
    this.isAvailable,
  }) : repository = RustAttachmentReader(client);

  final AgentRustClient client;
  final AgentConversation? Function(String id) readConversation;
  final void Function(view.ViewConversationSnapshot snapshot) publishSnapshot;
  final Directory? stagingDirectory;
  final Future<Directory> Function()? resolveStagingDirectory;
  final bool Function()? isAvailable;

  @override
  final RustAttachmentReader repository;

  final _progress = <String, AttachmentProgress>{};
  final _pending = <String, _StagedAttachment>{};
  final _imports = <String, _AttachmentImport>{};
  Future<void> _tail = Future.value();
  Future<Directory>? _openingDirectory;
  bool _frozen = false;
  bool _closed = false;
  bool _disposed = false;
  int _epoch = 0;

  @override
  AttachmentProgress? progressFor(String conversationId) =>
      _progress[conversationId];

  @override
  bool hasPending(String conversationId) =>
      _pending.containsKey(conversationId);

  @override
  bool isImporting(String conversationId) =>
      _imports.containsKey(conversationId);

  @override
  void cancelImport(String conversationId) {
    final task = _imports[conversationId];
    if (task != null) _cancel(task);
  }

  @override
  VoidCallback? importCancellation(String conversationId) {
    final task = _imports[conversationId];
    return task == null ? null : () => _cancel(task);
  }

  void _cancel(_AttachmentImport task) {
    if (task.settled) return;
    task.cancellation.cancel();
    if (task.nativeStarted) {
      task.cancelRequest ??= () async {
        try {
          await (await client.core).cancelAttachmentImport(importId: task.id);
        } catch (_) {
          // Admission still supplies the authoritative committed/cancelled result.
        }
      }();
    }
  }

  void transferProgress(String conversationId, AttachmentProgress progress) {
    if (_disposed || _frozen) return;
    _progress[conversationId] = progress;
    notifyListeners();
  }

  @override
  Future<void> attach(
    String conversationId,
    XFile file, {
    required bool Function() canModify,
  }) => _enqueue(() async {
    _check(canModify);
    if (_pending.containsKey(conversationId)) {
      throw const AttachmentException(AttachmentError.conflict);
    }
    final target = _target(conversationId);
    final task = _AttachmentImport(generateUuidV4(), _epoch);
    _imports[conversationId] = task;
    _notify();
    File? stagedFile;
    try {
      final length = await task.cancellation.guard(file.length());
      if (length < 0) {
        throw const AttachmentException(AttachmentError.invalidMetadata);
      }
      final directory = await (_openingDirectory ??= _createStagingDirectory()
          .catchError((Object error) {
            _openingDirectory = null;
            throw error;
          }));
      task.cancellation.check();
      stagedFile = File('${directory.path}${Platform.pathSeparator}${task.id}');
      await _stage(conversationId, file, stagedFile, length, task);
      _check(canModify);
      if (task.epoch != _epoch) {
        throw const AttachmentException(AttachmentError.conflict);
      }
      final name = file.name.split(RegExp(r'[/\\]')).last;
      final staged = _StagedAttachment(
        id: task.id,
        target: target,
        file: stagedFile,
        name: name,
        mediaType: attachmentMediaType(name, file.mimeType),
        byteLength: length,
        epoch: task.epoch,
      );
      _pending[conversationId] = staged;
      await _admit(staged, task, canModify);
    } catch (error) {
      _failed(conversationId, task, error);
      if (!_pending.containsKey(conversationId) && stagedFile != null) {
        await _deleteStaged(stagedFile);
      }
      throw attachmentErrorFromRust(error);
    } finally {
      task.settled = true;
      await task.cancelRequest;
      if (identical(_imports[conversationId], task)) {
        _imports.remove(conversationId);
      }
      _notify();
    }
  });

  Future<Directory> _createStagingDirectory() async {
    final root =
        stagingDirectory ??
        await (resolveStagingDirectory ?? getTemporaryDirectory)();
    await root.create(recursive: true);
    return root.createTemp('sked-agent-import-');
  }

  Future<void> _stage(
    String conversationId,
    XFile source,
    File destination,
    int length,
    _AttachmentImport task,
  ) async {
    final output = await destination.open(mode: FileMode.write);
    var count = 0;
    try {
      for (var offset = 0; offset < length; offset += 65536) {
        final end = offset + 65536 < length ? offset + 65536 : length;
        final chunks = StreamIterator(source.openRead(offset, end));
        try {
          while (await task.cancellation.guard(chunks.moveNext())) {
            task.cancellation.check();
            count += chunks.current.length;
            if (count > length) {
              throw const AttachmentException(AttachmentError.changed);
            }
            await output.writeFrom(chunks.current);
            if (task.epoch == _epoch) {
              transferProgress(
                conversationId,
                AttachmentProgress(
                  AttachmentDelivery.saving,
                  completedBytes: count,
                  totalBytes: length,
                ),
              );
            }
          }
        } finally {
          await chunks.cancel();
        }
      }
      task.cancellation.check();
      if (count != length ||
          await task.cancellation.guard(source.length()) != length) {
        throw const AttachmentException(AttachmentError.changed);
      }
      await output.flush();
    } finally {
      await output.close();
    }
  }

  Future<void> _admit(
    _StagedAttachment staged,
    _AttachmentImport task,
    bool Function() canModify,
  ) async {
    task.cancellation.check();
    _check(canModify);
    if (staged.epoch != _epoch) {
      throw const AttachmentException(AttachmentError.conflict);
    }
    final core = await client.ensureInitialized();
    task.cancellation.check();
    _check(canModify);
    task.nativeStarted = true;
    final snapshot = await core.admitDraftAttachment(
      request: management.DraftAttachmentAdmission(
        importId: staged.id,
        target: staged.target,
        sourcePath: staged.file.path,
        name: staged.name,
        mediaType: staged.mediaType,
        byteLength: staged.byteLength,
      ),
    );
    // A cancellation after native commit must not turn a saved attachment into
    // a failed UI action. The returned snapshot is the commit result.
    if (identical(_pending[staged.target.conversationId], staged)) {
      _pending.remove(staged.target.conversationId);
    }
    await _deleteStaged(staged.file);
    if (!_disposed && staged.epoch == _epoch) {
      publishSnapshot(snapshot);
      transferProgress(
        staged.target.conversationId,
        AttachmentProgress(
          AttachmentDelivery.local,
          completedBytes: staged.byteLength,
          totalBytes: staged.byteLength,
        ),
      );
    }
  }

  @override
  Future<void> retry(
    String conversationId, {
    required bool Function() canModify,
  }) => _enqueue(() async {
    _check(canModify);
    final staged = _pending[conversationId];
    if (staged == null) return;
    final task = _AttachmentImport(staged.id, _epoch);
    _imports[conversationId] = task;
    transferProgress(
      conversationId,
      const AttachmentProgress(AttachmentDelivery.saving),
    );
    try {
      await _admit(staged, task, canModify);
    } catch (error) {
      _failed(conversationId, task, error);
      throw attachmentErrorFromRust(error);
    } finally {
      task.settled = true;
      await task.cancelRequest;
      if (identical(_imports[conversationId], task)) {
        _imports.remove(conversationId);
      }
      _notify();
    }
  });

  @override
  Future<void> discardPending(String conversationId) => _enqueue(() async {
    if (_frozen || _closed) {
      throw const AttachmentException(AttachmentError.unavailable);
    }
    final staged = _pending.remove(conversationId);
    if (staged != null) await _deleteStaged(staged.file);
    _notify();
  });

  @override
  Future<void> remove(
    String conversationId,
    String attachmentId, {
    required bool Function() canModify,
  }) => _editReference(conversationId, attachmentId, canModify, reuse: false);

  @override
  Future<void> useAgain(
    String conversationId,
    String attachmentId, {
    required bool Function() canModify,
  }) => _editReference(conversationId, attachmentId, canModify, reuse: true);

  Future<void> _editReference(
    String conversationId,
    String attachmentId,
    bool Function() canModify, {
    required bool reuse,
  }) => _enqueue(() async {
    _check(canModify);
    final target = _target(conversationId);
    final epoch = _epoch;
    try {
      final core = await client.ensureInitialized();
      _check(canModify);
      final snapshot = reuse
          ? await core.useDraftAttachment(
              target: target,
              attachmentId: attachmentId,
            )
          : await core.removeDraftAttachment(
              target: target,
              attachmentId: attachmentId,
            );
      if (!_disposed && epoch == _epoch) publishSnapshot(snapshot);
    } catch (error) {
      throw attachmentErrorFromRust(error);
    }
  });

  management.DraftAttachmentTarget _target(String conversationId) {
    final conversation = readConversation(conversationId);
    if (conversation == null || conversation.archived) {
      throw const AttachmentException(AttachmentError.conflict);
    }
    return management.DraftAttachmentTarget(
      conversationId: conversationId,
      expectedAfterRunId: conversation.runId,
      expectedAfterInputId:
          conversation.queuedInputs.lastOrNull?.id ??
          conversation.messages
              .where((message) => message.role == ConversationRole.user)
              .lastOrNull
              ?.id,
    );
  }

  Future<void> collectGarbage() => _enqueue(() async {
    await client.dispatch(
      const native.AgentCommand(kind: native.CommandKind.collectAttachments),
    );
  });

  Future<void> freezeAndDrain() async {
    _frozen = true;
    for (final task in _imports.values.toList()) {
      _cancel(task);
    }
    await Future.wait([
      waitForPendingOperations(),
      repository.freezeAndDrain(),
    ]);
  }

  void resume() {
    if (_closed || _disposed) return;
    _frozen = false;
    repository.resume();
    _notify();
  }

  Future<void> waitForPendingOperations() async {
    while (true) {
      final tail = _tail;
      await tail;
      await repository.waitForPendingOperations();
      if (identical(tail, _tail)) return;
    }
  }

  void invalidatePendingAfterDataBoundary() {
    _epoch++;
    for (final task in _imports.values.toList()) {
      _cancel(task);
    }
    final staged = _pending.values.toList();
    _pending.clear();
    _progress.clear();
    unawaited(
      _enqueue(() async {
        for (final item in staged) {
          await _deleteStaged(item.file);
        }
      }),
    );
    _notify();
  }

  Future<void> close() async {
    _closed = true;
    await freezeAndDrain();
    await repository.close();
    _pending.clear();
    final opening = _openingDirectory;
    if (opening != null) {
      final directory = await opening;
      if (await directory.exists()) await directory.delete(recursive: true);
    }
  }

  Future<void> _deleteStaged(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // The application-owned staging directory is cleaned again on close.
    }
  }

  void _failed(String id, _AttachmentImport task, Object error) {
    if (task.epoch != _epoch) return;
    transferProgress(
      id,
      AttachmentProgress(
        attachmentErrorFromRust(error).code == AttachmentError.cancelled
            ? AttachmentDelivery.cancelled
            : AttachmentDelivery.failed,
      ),
    );
  }

  void _check(bool Function() canModify) {
    if (_frozen ||
        _closed ||
        _disposed ||
        !(isAvailable?.call() ?? true) ||
        !canModify()) {
      throw const AttachmentException(AttachmentError.unavailable);
    }
  }

  void _notify() {
    if (!_disposed && !_frozen) notifyListeners();
  }

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  @override
  void dispose() {
    _disposed = true;
    _frozen = true;
    for (final task in _imports.values.toList()) {
      _cancel(task);
    }
    super.dispose();
  }
}

class _StagedAttachment {
  const _StagedAttachment({
    required this.id,
    required this.target,
    required this.file,
    required this.name,
    required this.mediaType,
    required this.byteLength,
    required this.epoch,
  });

  final String id;
  final management.DraftAttachmentTarget target;
  final File file;
  final String name;
  final String mediaType;
  final int byteLength;
  final int epoch;
}

class _AttachmentImport {
  _AttachmentImport(this.id, this.epoch);

  final String id;
  final int epoch;
  final cancellation = AttachmentCancellation();
  bool nativeStarted = false;
  bool settled = false;
  Future<void>? cancelRequest;
}

view.ViewAttachmentMetadata _metadata(ConversationAttachment value) =>
    view.ViewAttachmentMetadata(
      id: value.id,
      name: value.name,
      mediaType: value.mediaType,
      byteLength: value.byteLength,
      sha256: value.digest,
      createdAt: 0,
    );
