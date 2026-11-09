import 'dart:async';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:sked/agent/attachments/agent_attachment_controller.dart';

import 'agent_memory_conversations.dart';

export 'package:sked/agent/attachments/agent_attachment_controller.dart';

class UiMemoryAttachmentBytes {
  final values = <String, Uint8List>{};
  Stream<List<int>> read(String id) async* {
    final value = values[id];
    if (value == null) throw const AttachmentException(AttachmentError.missing);
    yield value;
  }
}

class MemoryAttachmentReader implements AgentAttachmentReader {
  MemoryAttachmentReader({required this.storage});
  final UiMemoryAttachmentBytes storage;
  @override
  Future<Uint8List> readBytes(
    ConversationAttachment attachment, {
    AttachmentCancellation? cancellation,
  }) async {
    final bytes = BytesBuilder(copy: false);
    final iterator = StreamIterator(storage.read(attachment.id));
    try {
      while (await (cancellation?.guard(iterator.moveNext()) ??
          iterator.moveNext())) {
        cancellation?.check();
        bytes.add(iterator.current);
      }
    } finally {
      unawaited(iterator.cancel());
    }
    cancellation?.check();
    final result = bytes.takeBytes();
    if (result.length != attachment.byteLength ||
        sha256.convert(result).toString() != attachment.digest) {
      throw const AttachmentException(AttachmentError.corrupt);
    }
    return result;
  }

  @override
  Future<void> verify(
    ConversationAttachment attachment, {
    AttachmentCancellation? cancellation,
  }) async {
    await readBytes(attachment, cancellation: cancellation);
  }

  Future<void> close() async {}
}

/// Picker and composer interaction fixture. Blob bytes remain in test memory.
class MemoryAttachmentController extends ChangeNotifier
    implements AgentAttachmentController {
  MemoryAttachmentController({
    required this.conversations,
    required this.repository,
  });
  final MemoryConversationRepository conversations;
  @override
  final MemoryAttachmentReader repository;
  final _progress = <String, AttachmentProgress>{};
  final _pending = <String, ConversationAttachment>{};
  final _cancellations = <String, AttachmentCancellation>{};
  final _work = <Future<void>>{};
  int _sequence = 0;
  bool _closed = false;
  @override
  AttachmentProgress? progressFor(String conversationId) =>
      _progress[conversationId];
  @override
  bool hasPending(String conversationId) =>
      _pending.containsKey(conversationId);
  @override
  bool isImporting(String conversationId) =>
      _cancellations.containsKey(conversationId);
  @override
  VoidCallback? importCancellation(String conversationId) =>
      _cancellations[conversationId]?.cancel;
  @override
  void cancelImport(String conversationId) =>
      _cancellations[conversationId]?.cancel();

  @override
  Future<void> attach(
    String conversationId,
    XFile file, {
    required bool Function() canModify,
  }) {
    final future = _attach(conversationId, file, canModify);
    _work.add(future);
    unawaited(
      future.then<void>(
        (_) => _work.remove(future),
        onError: (Object _, StackTrace _) => _work.remove(future),
      ),
    );
    return future;
  }

  Future<void> _attach(String id, XFile file, bool Function() canModify) async {
    if (_closed || !canModify()) {
      throw const AttachmentException(AttachmentError.conflict);
    }
    final cancellation = AttachmentCancellation();
    _cancellations[id] = cancellation;
    _progress[id] = const AttachmentProgress(AttachmentDelivery.saving);
    notifyListeners();
    try {
      final length = await cancellation.guard(file.length());
      final bytes = BytesBuilder(copy: false);
      final iterator = StreamIterator(file.openRead());
      try {
        while (await cancellation.guard(iterator.moveNext())) {
          bytes.add(iterator.current);
          _progress[id] = AttachmentProgress(
            AttachmentDelivery.saving,
            completedBytes: bytes.length,
            totalBytes: length,
          );
          notifyListeners();
        }
      } finally {
        unawaited(iterator.cancel());
      }
      cancellation.check();
      if (!canModify()) {
        throw const AttachmentException(AttachmentError.conflict);
      }
      final value = bytes.takeBytes();
      if (length != value.length) {
        throw const AttachmentException(AttachmentError.changed);
      }
      final metadata = ConversationAttachment(
        id: 'ui-file-${++_sequence}',
        name: file.name,
        mediaType: attachmentMediaType(file.name, file.mimeType),
        byteLength: length,
        digest: sha256.convert(value).toString(),
      );
      repository.storage.values[metadata.id] = value;
      _pending[id] = metadata;
      await retry(id, canModify: canModify);
    } on AttachmentException catch (error) {
      _progress[id] = AttachmentProgress(
        error.code == AttachmentError.cancelled
            ? AttachmentDelivery.cancelled
            : AttachmentDelivery.failed,
      );
      rethrow;
    } catch (_) {
      _progress[id] = const AttachmentProgress(AttachmentDelivery.failed);
      rethrow;
    } finally {
      _cancellations.remove(id);
      notifyListeners();
    }
  }

  @override
  Future<void> retry(String id, {required bool Function() canModify}) async {
    final attachment = _pending[id];
    if (attachment == null) return;
    if (_closed || !canModify()) {
      throw const AttachmentException(AttachmentError.conflict);
    }
    await conversations.update(
      id,
      (value) => value.copyWith(
        attachments: [
          ...value.attachments.where((entry) => entry.id != attachment.id),
          attachment,
        ],
        draftAttachmentIds: [
          ...value.draftAttachmentIds.where((entry) => entry != attachment.id),
          attachment.id,
        ],
      ),
    );
    _pending.remove(id);
    _progress.remove(id);
    notifyListeners();
  }

  @override
  Future<void> discardPending(String id) async {
    final attachment = _pending.remove(id);
    if (attachment != null) repository.storage.values.remove(attachment.id);
    _progress.remove(id);
    notifyListeners();
  }

  @override
  Future<void> remove(
    String id,
    String attachmentId, {
    required bool Function() canModify,
  }) async {
    if (!canModify()) throw const AttachmentException(AttachmentError.conflict);
    await conversations.update(
      id,
      (value) => value.copyWith(
        draftAttachmentIds: value.draftAttachmentIds.where(
          (entry) => entry != attachmentId,
        ),
      ),
    );
  }

  @override
  Future<void> useAgain(
    String id,
    String attachmentId, {
    required bool Function() canModify,
  }) async {
    if (!canModify()) throw const AttachmentException(AttachmentError.conflict);
    final attachment = conversations
        .find(id)!
        .attachments
        .firstWhere((value) => value.id == attachmentId);
    await repository.verify(attachment);
    await conversations.update(
      id,
      (value) => value.copyWith(
        draftAttachmentIds: {...value.draftAttachmentIds, attachmentId},
      ),
    );
  }

  Future<void> close() async {
    _closed = true;
    for (final cancellation in _cancellations.values) {
      cancellation.cancel();
    }
    await Future.wait(_work.map((work) => work.catchError((Object _) {})));
  }
}
