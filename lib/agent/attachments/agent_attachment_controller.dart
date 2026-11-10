import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';

import 'attachment_models.dart';

export 'attachment_models.dart';

abstract interface class AgentAttachmentReader {
  Future<Uint8List> readBytes(
    ConversationAttachment attachment, {
    AttachmentCancellation? cancellation,
  });

  Future<void> verify(
    ConversationAttachment attachment, {
    AttachmentCancellation? cancellation,
  });
}

/// Optional streaming export capability for a registered private attachment.
abstract interface class AgentAttachmentFileReader {
  /// Changes when maintenance retires the current source data.
  Object get fileSession;

  Future<void> copyToFile(
    ConversationAttachment attachment,
    String destination, {
    required AttachmentCancellation cancellation,
  });
}

/// A captured conversation input shared by all files from one desktop action.
abstract interface class AgentAttachmentInput {
  Future<void> attach(XFile file, {required bool Function() canModify});
}

/// Optional capability for adapters that accept several files at once.
abstract interface class AgentAttachmentInputOwner {
  Future<AgentAttachmentInput> captureInput(
    String conversationId, {
    required bool Function() canModify,
  });
}

abstract interface class AgentAttachmentController implements Listenable {
  AgentAttachmentReader get repository;

  AttachmentProgress? progressFor(String conversationId);
  bool hasPending(String conversationId);
  bool isImporting(String conversationId);
  void cancelImport(String conversationId);
  VoidCallback? importCancellation(String conversationId);

  Future<void> attach(
    String conversationId,
    XFile file, {
    required bool Function() canModify,
  });

  Future<void> retry(
    String conversationId, {
    required bool Function() canModify,
  });

  Future<void> discardPending(String conversationId);

  Future<void> remove(
    String conversationId,
    String attachmentId, {
    required bool Function() canModify,
  });

  Future<void> useAgain(
    String conversationId,
    String attachmentId, {
    required bool Function() canModify,
  });
}

Future<XFile?> pickAgentBinaryAttachment() => openFile();
