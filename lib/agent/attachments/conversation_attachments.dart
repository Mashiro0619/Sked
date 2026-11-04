import 'dart:async';
import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';

import '../../utils/unique_id.dart';
import '../conversations/conversation_repository.dart';
import 'attachment_repository.dart';

/// Serializes importing a blob and publishing its reference with collection.
/// UI lifetime does not own this service or its already-saved draft attachments.
class ConversationAttachments extends ChangeNotifier {
  ConversationAttachments({
    required this.conversations,
    required this.repository,
  });
  final ConversationRepository conversations;
  final AttachmentRepository repository;
  final _progress = <String, AttachmentProgress>{};
  final _pending = <String, _PendingAttachment>{};
  final _tokens = <String, AttachmentCancellation>{};
  Future<void> _tail = Future.value();
  bool _frozen = false;
  bool _disposed = false;
  int _epoch = 0;

  AttachmentProgress? progressFor(String conversationId) =>
      _progress[conversationId];
  bool hasPending(String conversationId) =>
      _pending.containsKey(conversationId);
  bool isImporting(String conversationId) =>
      _tokens.containsKey(conversationId);
  void cancelImport(String conversationId) => _tokens[conversationId]?.cancel();

  /// A UI action belongs to the import shown when that action was created.
  /// Reusing it later can cancel only that token, never a newer file import.
  VoidCallback? importCancellation(String conversationId) =>
      _tokens[conversationId]?.cancel;

  void transferProgress(String conversationId, AttachmentProgress progress) {
    if (!_disposed && !_frozen) {
      _progress[conversationId] = progress;
      notifyListeners();
    }
  }

  static Future<XFile?> pickFile() => openFile();

  Future<void> attach(
    String conversationId,
    XFile file, {
    required bool Function() canModify,
  }) => _enqueue(() async {
    _check(canModify);
    if (_pending.containsKey(conversationId)) {
      throw const AttachmentException(AttachmentError.conflict);
    }
    final conversation = conversations.find(conversationId);
    if (conversation == null ||
        conversation.archived ||
        conversation.draftAttachmentIds.length >=
            ConversationAttachment.maxPerMessage) {
      throw const AttachmentException(AttachmentError.conflict);
    }
    final cancellation = AttachmentCancellation();
    _tokens[conversationId] = cancellation;
    final epoch = _epoch;
    notifyListeners();
    final id = generateUuidV4();
    // XFile.name is a display name, never a path used to access private storage.
    final name = file.name.split(RegExp(r'[/\\]')).last;
    try {
      final length = await cancellation.guard(file.length());
      if (length < 0 || length > ConversationAttachment.maxFileBytes) {
        throw const AttachmentException(AttachmentError.tooLarge);
      }
      final attachment = await repository.put(
        id: id,
        name: name,
        mediaType: attachmentMediaType(name, file.mimeType),
        byteLength: length,
        openRead: () => _readFile(file, length, cancellation),
        cancellation: cancellation,
        onProgress: (count) {
          if (epoch != _epoch) return;
          transferProgress(
            conversationId,
            AttachmentProgress(
              AttachmentDelivery.saving,
              completedBytes: count,
              totalBytes: length,
            ),
          );
        },
      );
      cancellation.check();
      if (epoch != _epoch) {
        throw const AttachmentException(AttachmentError.conflict);
      }
      _pending[conversationId] = _PendingAttachment(
        attachment,
        conversation.runId,
        _inputBoundary(conversation),
        epoch,
      );
      await _publish(conversationId, canModify, cancellation: cancellation);
      transferProgress(
        conversationId,
        AttachmentProgress(
          AttachmentDelivery.local,
          completedBytes: length,
          totalBytes: length,
        ),
      );
    } catch (error) {
      if (epoch == _epoch) {
        transferProgress(
          conversationId,
          AttachmentProgress(
            error is AttachmentException &&
                    error.code == AttachmentError.cancelled
                ? AttachmentDelivery.cancelled
                : AttachmentDelivery.failed,
          ),
        );
      }
      rethrow;
    } finally {
      _tokens.remove(conversationId);
      if (!_disposed && !_frozen) notifyListeners();
    }
  });

  Stream<List<int>> _readFile(
    XFile file,
    int length,
    AttachmentCancellation cancellation,
  ) async* {
    // Fixed-size slices prevent Web XFile from buffering a whole large Blob.
    for (var offset = 0; offset < length; offset += 65536) {
      cancellation.check();
      final end = offset + 65536 < length ? offset + 65536 : length;
      yield* file.openRead(offset, end);
    }
    if (await cancellation.guard(file.length()) != length) {
      throw const AttachmentException(AttachmentError.changed);
    }
  }

  Future<void> retry(
    String conversationId, {
    required bool Function() canModify,
  }) => _enqueue(() async {
    _check(canModify);
    final pending = _pending[conversationId];
    if (pending == null) return;
    final cancellation = AttachmentCancellation();
    final epoch = _epoch;
    _tokens[conversationId] = cancellation;
    transferProgress(
      conversationId,
      const AttachmentProgress(AttachmentDelivery.saving),
    );
    try {
      await _publish(conversationId, canModify, cancellation: cancellation);
      transferProgress(
        conversationId,
        AttachmentProgress(
          AttachmentDelivery.local,
          completedBytes: pending.attachment.byteLength,
          totalBytes: pending.attachment.byteLength,
        ),
      );
    } catch (error) {
      if (epoch == _epoch) {
        transferProgress(
          conversationId,
          AttachmentProgress(
            error is AttachmentException &&
                    error.code == AttachmentError.cancelled
                ? AttachmentDelivery.cancelled
                : AttachmentDelivery.failed,
          ),
        );
      }
      rethrow;
    } finally {
      _tokens.remove(conversationId);
      if (!_disposed && !_frozen) notifyListeners();
    }
  });
  Future<void> _publish(
    String id,
    bool Function() canModify, {
    AttachmentCancellation? cancellation,
  }) async {
    cancellation?.check();
    _check(canModify);
    final pending = _pending[id];
    if (pending == null) return;
    final epoch = _epoch;
    await repository.verify(pending.attachment, cancellation: cancellation);
    await conversations.update(id, (current) {
      cancellation?.check();
      _check(canModify);
      if (epoch != _epoch || pending.epoch != _epoch) {
        throw const AttachmentException(AttachmentError.conflict);
      }
      final existing = current.attachments
          .where((a) => a.id == pending.attachment.id)
          .firstOrNull;
      if (existing != null) {
        if (existing.digest != pending.attachment.digest) {
          throw const AttachmentException(AttachmentError.conflict);
        }
        return current;
      }
      if (current.archived ||
          current.runId != pending.afterRunId ||
          _inputBoundary(current) != pending.afterMessageId ||
          current.draftAttachmentIds.length >=
              ConversationAttachment.maxPerMessage) {
        throw const AttachmentException(AttachmentError.conflict);
      }
      return current.copyWith(
        attachments: [...current.attachments, pending.attachment],
        draftAttachmentIds: [
          ...current.draftAttachmentIds,
          pending.attachment.id,
        ],
      );
    });
    _pending.remove(id);
  }

  Future<void> discardPending(String conversationId) => _enqueue(() async {
    if (_frozen) throw const AttachmentException(AttachmentError.unavailable);
    _pending.remove(conversationId);
    await _collect();
  });
  Future<void> remove(
    String conversationId,
    String attachmentId, {
    required bool Function() canModify,
  }) => _enqueue(() async {
    _check(canModify);
    await conversations.update(conversationId, (current) {
      _check(canModify);
      if (current.archived) {
        throw const AttachmentException(AttachmentError.conflict);
      }
      return current.copyWith(
        draftAttachmentIds: current.draftAttachmentIds.where(
          (id) => id != attachmentId,
        ),
      );
    });
    await _collect();
  });

  /// Reuses an existing local file in a new user message without copying bytes.
  Future<void> useAgain(
    String conversationId,
    String attachmentId, {
    required bool Function() canModify,
  }) => _enqueue(() async {
    _check(canModify);
    final current = conversations.find(conversationId);
    final attachment = current?.attachments
        .where((a) => a.id == attachmentId)
        .firstOrNull;
    if (attachment == null) {
      throw const AttachmentException(AttachmentError.missing);
    }
    await repository.verify(attachment);
    await conversations.update(conversationId, (current) {
      _check(canModify);
      if (current.archived ||
          current.draftAttachmentIds.length >=
              ConversationAttachment.maxPerMessage) {
        throw const AttachmentException(AttachmentError.conflict);
      }
      return current.copyWith(
        draftAttachmentIds: {...current.draftAttachmentIds, attachmentId},
      );
    });
  });
  Future<void> collectGarbage() => _enqueue(_collect);
  Future<void> _collect() async {
    if (_frozen || !conversations.canWrite) return;
    _pending.removeWhere((id, _) => conversations.find(id) == null);
    final references = <String>{
      for (final conversation in conversations.ownedConversations)
        ...conversationAttachmentIds(conversation),
      for (final pending in _pending.values) pending.attachment.id,
    };
    // Remove stale metadata before deleting its bytes. A failed archive save
    // leaves all bytes intact and cannot damage another message's reference.
    for (final conversation in conversations.ownedConversations.toList()) {
      if (conversation.attachments.any((a) => !references.contains(a.id))) {
        await conversations.update(
          conversation.id,
          (current) => current.copyWith(
            attachments: current.attachments.where(
              (a) => references.contains(a.id),
            ),
          ),
        );
      }
    }
    await repository.collect(references);
  }

  Future<void> freezeAndDrain() async {
    _frozen = true;
    for (final token in _tokens.values.toList()) {
      token.cancel();
    }
    // Final reference verification and history reuse also read the repository.
    // Cancel those reads before waiting for the service action that owns them.
    await Future.wait([_tail, repository.freezeAndDrain()]);
  }

  void resume() {
    if (!_disposed) {
      _frozen = false;
      repository.resume();
    }
  }

  Future<void> waitForPendingOperations() async {
    while (true) {
      final pending = _tail;
      await pending;
      await repository.waitForPendingOperations();
      if (identical(pending, _tail)) return;
    }
  }

  /// Invalidate picker results and unpublished retries across data generations.
  void invalidatePendingAfterDataBoundary() {
    _epoch++;
    for (final token in _tokens.values.toList()) {
      token.cancel();
    }
    _pending.clear();
    _progress.clear();
    if (!_disposed) notifyListeners();
  }

  Future<void> clearFrozen() async {
    if (!_frozen) throw const AttachmentException(AttachmentError.unavailable);
    await repository.clearFrozen();
    _pending.clear();
    _progress.clear();
  }

  Future<void> close() async {
    await freezeAndDrain();
    await repository.close();
  }

  void _check(bool Function() canModify) {
    if (_frozen || _disposed || !conversations.canWrite || !canModify()) {
      throw const AttachmentException(AttachmentError.unavailable);
    }
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
    for (final token in _tokens.values.toList()) {
      token.cancel();
    }
    super.dispose();
  }
}

class _PendingAttachment {
  const _PendingAttachment(
    this.attachment,
    this.afterRunId,
    this.afterMessageId,
    this.epoch,
  );
  final ConversationAttachment attachment;
  final String? afterRunId;
  final String? afterMessageId;
  final int epoch;
}

String? _inputBoundary(AgentConversation conversation) {
  for (final message in conversation.messages.reversed) {
    if (message.role == ConversationRole.user) return message.id;
    if (message.role != ConversationRole.notice) continue;
    try {
      final value = jsonDecode(message.text);
      if (value is Map && value['kind'] == 'agent_pending_input') {
        return message.id;
      }
    } on FormatException {
      // Ordinary notices do not define a queued-input boundary.
    }
  }
  return null;
}
