import 'dart:convert';

import '../../services/text_file_picker.dart';
import '../../utils/unique_id.dart';
import '../conversations/conversation_repository.dart';

export '../../services/text_file_picker.dart'
    show PickedTextFile, TextFileTooLargeException;

/// A failed attachment save retains the same source identity for explicit
/// recovery. No file content is sent to a model by this local operation.
class ConversationFileAttachments {
  ConversationFileAttachments(this.repository);
  final ConversationRepository repository;
  static const maxBytes = 512 * 1024;
  static const extensions = ['json', 'ics', 'txt', 'html', 'htm'];
  final _pending = <String, ConversationSource>{};

  static Future<PickedTextFile?> pickFile() => TextFilePicker.pickDocument(
    allowedExtensions: extensions,
    byteLimit: maxBytes,
  );

  ConversationSource? pending(String conversationId) =>
      _pending[conversationId];
  void discardPending(String conversationId) => _pending.remove(conversationId);
  void discardDeletedConversations() =>
      _pending.removeWhere((id, _) => repository.find(id) == null);

  Future<void> attach(
    String conversationId,
    PickedTextFile file, {
    required String generation,
    required String locale,
    required bool Function() canModify,
  }) async {
    if (_pending.containsKey(conversationId)) {
      throw StateError('Retry the pending attachment first.');
    }
    final conversation = repository.find(conversationId);
    if (conversation == null || !canModify() || conversation.archived) {
      throw StateError('The conversation is no longer editable.');
    }
    if (file.text.length > maxBytes ||
        utf8.encode(file.text).length > maxBytes) {
      throw const TextFileTooLargeException();
    }
    if (file.name.isEmpty ||
        file.name.length > 256 ||
        !extensions.contains(file.name.split('.').last.toLowerCase()) ||
        file.text.trim().isEmpty) {
      throw const FormatException('Attach a supported, non-empty text file.');
    }
    final now = DateTime.now().toUtc();
    final source = ConversationSource(
      id: generateUuidV4(),
      kind: 'structured_file',
      text: file.text,
      attachedAfterRunId: conversation.runId,
      attachedAfterMessageId: conversation.messages.lastOrNull?.id,
      provenance: ConversationSourceProvenance(
        title: file.name,
        capturedAt: now,
        reviewedAt: now,
        datasetGeneration: generation,
        localeCode: locale,
      ),
    );
    ConversationSource.fromJson(Map<String, dynamic>.from(source.toJson()));
    _pending[conversationId] = source;
    await retry(conversationId, generation: generation, canModify: canModify);
  }

  Future<void> retry(
    String conversationId, {
    required String generation,
    required bool Function() canModify,
  }) async {
    final source = _pending[conversationId];
    if (source == null) return;
    await repository.update(conversationId, (current) {
      final existing = current.sources
          .where((value) => value.id == source.id)
          .firstOrNull;
      if (existing != null) {
        if (existing.digest != source.digest) {
          throw StateError('The attachment identity changed.');
        }
        return current;
      }
      if (!canModify() ||
          current.archived ||
          source.provenance!.datasetGeneration != generation ||
          !_sameInputBoundary(current, source)) {
        throw StateError(
          'The conversation changed before its attachment was saved.',
        );
      }
      return current.copyWith(sources: [...current.sources, source]);
    });
    _pending.remove(conversationId);
  }

  static bool canRemove(
    AgentConversation conversation,
    ConversationSource source,
  ) =>
      source.kind == 'structured_file' &&
      !conversation.archived &&
      _sameInputBoundary(conversation, source);

  Future<void> remove(
    String conversationId,
    String sourceId, {
    required bool Function() canModify,
  }) async {
    await repository.update(conversationId, (current) {
      final source = current.sources
          .where((value) => value.id == sourceId)
          .firstOrNull;
      if (source == null) return current;
      if (!canModify() || !canRemove(current, source)) {
        throw StateError(
          'An attachment used by a run must remain in its history.',
        );
      }
      return current.copyWith(
        sources: current.sources.where((value) => value.id != sourceId),
      );
    });
  }
}

bool _sameInputBoundary(
  AgentConversation conversation,
  ConversationSource source,
) =>
    conversation.runId == source.attachedAfterRunId &&
    conversation.messages.lastOrNull?.id == source.attachedAfterMessageId;
