import '../attachments/attachment_models.dart';
import '../knowledge/knowledge_models.dart';

KnowledgeException knowledgeErrorFromRust(Object error) {
  if (error is KnowledgeException) return error;
  final message = error.toString();
  final code = message.split(':').first;
  return KnowledgeException(switch (code) {
    'knowledge_conflict' => KnowledgeError.conflict,
    'knowledge_invalid' => KnowledgeError.invalid,
    'unavailable' => KnowledgeError.unavailable,
    _ => KnowledgeError.unknown,
  }, message);
}

AttachmentException attachmentErrorFromRust(Object error) {
  if (error is AttachmentException) return error;
  final code = error.toString().split(':').first;
  return AttachmentException(switch (code) {
    'cancelled' => AttachmentError.cancelled,
    'draft_changed' => AttachmentError.conflict,
    'attachment_missing' => AttachmentError.missing,
    'attachment_corrupt' => AttachmentError.corrupt,
    'attachment_changed' => AttachmentError.changed,
    'attachment_invalid' => AttachmentError.invalidMetadata,
    _ => AttachmentError.unavailable,
  });
}
