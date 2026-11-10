import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/bridge/conversation_projection.dart';
import 'package:sked/agent/history/conversation_history.dart';

import '../../support/agent_native_fixture.dart';

void main() {
  test(
    'reply versions preserve their own model instead of the current model',
    () {
      final conversation = conversationFromRust(
        _snapshot(
          const ViewReplyRevision(
            id: 'original-version',
            messageId: 'reply',
            runId: 'replacement-run',
            createdAt: 1793664000000,
            text: 'Original reply',
            model: ViewModelSelection(
              modelId: 'original-model',
              reasoningEffort: 'high',
              protocol: 'chatCompletions',
            ),
            providerProtocol: 'chatCompletions',
            responseItems: [],
          ),
        ),
      );
      final revision = conversation.replyRevisions.single;
      expect(revision.text, 'Original reply');
      expect(revision.modelSelection?.modelId, 'original-model');
      expect(revision.providerProtocol?.name, 'chatCompletions');
      final restored = ConversationReplyRevision.fromJson(revision.toJson());
      expect(restored.toJson(), revision.toJson());
    },
  );

  test('native reply versions with unknown provenance remain readable', () {
    final conversation = conversationFromRust(
      _snapshot(
        const ViewReplyRevision(
          id: 'original-version',
          messageId: 'reply',
          runId: 'replacement-run',
          createdAt: 1793664000000,
          text: 'Original reply',
          responseItems: [],
        ),
      ),
    );
    final revision = conversation.replyRevisions.single;
    expect(revision.text, 'Original reply');
    expect(revision.modelSelection, isNull);
    expect(revision.providerProtocol, isNull);
    expect(conversation.messages.single.text, 'Current reply');
    final restored = ConversationReplyRevision.fromJson(revision.toJson());
    expect(restored.toJson(), revision.toJson());
  });
}

ViewConversationSnapshot _snapshot(ViewReplyRevision revision) {
  final source = nativeConversationFixture(
    modelSelection: const ViewModelSelection(
      modelId: 'current-model',
      protocol: 'responses',
    ),
    messages: [nativeMessageFixture(id: 'reply', text: 'Current reply')],
  );
  return ViewConversationSnapshot(
    conversation: source.conversation,
    sequence: source.sequence,
    messages: source.messages,
    runs: source.runs,
    turns: source.turns,
    operations: source.operations,
    queuedInputs: source.queuedInputs,
    queuedControls: source.queuedControls,
    contextFailures: source.contextFailures,
    historyVersions: source.historyVersions,
    replyRevisions: [revision],
    redoBatches: source.redoBatches,
    attachments: source.attachments,
    attachmentReferences: source.attachmentReferences,
    sources: source.sources,
    handoffs: source.handoffs,
    providerHistory: source.providerHistory,
    extensions: source.extensions,
  );
}
