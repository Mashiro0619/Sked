import '../../services/desktop_file_actions.dart';
import 'agent_attachment_controller.dart';

class DesktopAttachmentFiles {
  const DesktopAttachmentFiles();

  Future<SavedDesktopFile> prepare(
    AgentAttachmentFileReader reader,
    ConversationAttachment attachment, {
    required AttachmentCancellation cancellation,
  }) async => throw const AttachmentException(AttachmentError.unsupported);
}
