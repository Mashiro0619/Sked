import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/bridge/conversation_projection.dart';
import 'package:sked/agent/bridge/generated/api/management_contracts.dart';
import 'package:sked/agent/bridge/rust_conversation_attachments.dart';
import 'package:sked/agent/conversations/conversation_models.dart';

import '../../support/agent_native_fixture.dart';

class _AttachmentCore extends MemoryAgentCore {
  _AttachmentCore(ViewConversationSnapshot snapshot)
    : super(snapshots: [snapshot]);

  DraftAttachmentAdmission? admission;

  @override
  Future<ViewConversationState> admitDraftAttachment({
    required DraftAttachmentAdmission request,
  }) async {
    admission = request;
    return (await query(
      query: AgentQuery(
        kind: QueryKind.conversationState,
        conversationId: request.target.conversationId,
      ),
    )).state!;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'attachment admission uses the native input identity outside the page',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'sked-attachment-page-',
      );
      final snapshot = nativeConversationFixture(
        id: 'long-chat',
        messages: [
          nativeMessageFixture(
            id: 'original-input',
            text: 'Original request',
            role: ViewMessageRole.user,
          ),
          for (var index = 0; index < 100; index++)
            nativeMessageFixture(id: 'reply-$index', text: 'Reply $index'),
        ],
      );
      final visible = conversationFromRust(
        copyNativeSnapshot(snapshot, messages: [snapshot.messages.last]),
      );
      final core = _AttachmentCore(snapshot);
      ViewConversationState? published;
      final attachments = RustConversationAttachments(
        client: core.client,
        readConversation: (_) => visible,
        publishState: (state) => published = state,
        stagingDirectory: directory,
      );
      try {
        await attachments.attach(
          'long-chat',
          XFile.fromData(Uint8List.fromList([65, 66]), name: 'notes.txt'),
          canModify: () => true,
        );
        expect(visible.messages.single.role, ConversationRole.assistant);
        expect(core.admission!.target.expectedAfterInputId, 'original-input');
        expect(published?.conversation.id, 'long-chat');
        expect(
          core.queries.every(
            (query) => query.kind == QueryKind.conversationState,
          ),
          isTrue,
        );
        expect(attachments.hasPending('long-chat'), isFalse);
      } finally {
        await attachments.close();
        attachments.dispose();
        await core.client.shutdown();
        await directory.delete(recursive: true);
      }
    },
  );
}
