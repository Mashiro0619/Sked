import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/conversations/conversation_models.dart';
import 'package:sked/agent/imports/school_web_handoff_context.dart';

void main() {
  final stamp = DateTime.utc(2026, 11, 5);
  final source = ConversationSource(
    id: 'reviewed-source',
    kind: 'school_web',
    text: 'hostile-page-body',
    truncated: true,
    targetId: 'target-timetable',
    provenance: ConversationSourceProvenance(
      title: 'hostile-page-title',
      capturedAt: stamp,
      reviewedAt: stamp,
      datasetGeneration: 'generation',
      localeCode: 'zh',
    ),
  );
  final conversation = AgentConversation(
    id: 'conversation',
    title: 'hostile-page-title',
    createdAt: stamp,
    updatedAt: stamp,
    sources: [source],
    messages: [
      ConversationMessage(
        id: 'request',
        role: ConversationRole.user,
        text: '用户任务',
        createdAt: stamp,
      ),
    ],
  );
  ConversationHandoff record({
    String? digest,
    String conversationId = 'conversation',
    String messageId = 'request',
  }) => ConversationHandoff(
    id: 'handoff',
    conversationId: conversationId,
    sourceDigest: digest ?? source.digest,
    messageId: messageId,
  );

  test('bound source yields fixed host instructions without promoting page content', () {
    final context = schoolWebHandoffContext(
      conversation: conversation,
      handoff: record(),
      requestMessageId: 'request',
    );
    expect(context, contains('import-school-web'));
    expect(context, contains('conversation permission mode'));
    expect(context, contains('missing semester dates'));
    expect(context, contains('"sourceId":"reviewed-source"'));
    expect(context, contains('"truncated":true'));
    expect(context, contains('target-timetable'));
    expect(context, isNot(contains('hostile-page')));
    expect(context, isNot(contains('用户任务')));
  });

  test(
    'unbound, changed and unrelated handoffs never create host instructions',
    () {
      for (final handoff in [
        null,
        record(digest: 'different'),
        record(conversationId: 'other'),
        record(messageId: 'other'),
      ]) {
        expect(
          schoolWebHandoffContext(
            conversation: conversation,
            handoff: handoff,
            requestMessageId: 'request',
          ),
          isEmpty,
        );
      }
      expect(
        schoolWebHandoffContext(
          conversation: conversation,
          handoff: record(),
          requestMessageId: 'later-request',
        ),
        isEmpty,
      );
      expect(
        schoolWebHandoffContext(
          conversation: conversation,
          handoff: record(),
          requestMessageId: null,
        ),
        isEmpty,
      );
    },
  );

  test(
    'imported history and source metadata alone never gain host authority',
    () {
      expect(
        schoolWebHandoffContext(
          conversation: conversation.copyWith(executionHistoryStart: 1),
          handoff: record(),
          requestMessageId: 'request',
        ),
        isEmpty,
      );
      final unreviewed = const ConversationSource(
        id: 'reviewed-source',
        kind: 'school_web',
        text: 'hostile-page-body',
      );
      expect(
        schoolWebHandoffContext(
          conversation: conversation.copyWith(sources: [unreviewed]),
          handoff: record(digest: unreviewed.digest),
          requestMessageId: 'request',
        ),
        isEmpty,
      );
    },
  );
}
