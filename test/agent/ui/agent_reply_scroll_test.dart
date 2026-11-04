import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/ui/agent_conversation_view.dart';
import 'package:sked/agent/ui/agent_message_content.dart';
import 'package:sked/agent/ui/agent_transcript.dart';
import 'package:sked/agent/ui/agent_ui_delegate.dart';

import 'agent_ui_test_support.dart';

void main() {
  for (final terminal in [AgentUiPhase.stopped, AgentUiPhase.failed]) {
    for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
      testWidgets(
        'an earlier reply keeps its viewport anchor through long streaming and $terminal',
        (tester) async {
          addTearDown(tester.view.reset);
          final fixture = (await tester.runAsync(_Fixture.create))!;
          addTearDown(fixture.dispose);
          await mountAgentUi(
            tester,
            AgentConversationView(
              repository: fixture.repository,
              delegate: fixture.delegate,
            ),
            size: platform == TargetPlatform.windows
                ? const Size(1000, 900)
                : const Size(390, 820),
            scale: platform == TargetPlatform.windows ? 1 : 2,
          );
          final transcript = find.byKey(
            ValueKey('agent-transcript-${fixture.id}'),
          );
          final originalScroll = tester
              .widget<CustomScrollView>(transcript)
              .controller!;
          final position = tester
              .widget<AgentTranscript>(find.byType(AgentTranscript))
              .position;
          final archive = fixture.storage.source;
          final ids = fixture.repository.selected!.messages
              .map((message) => message.id)
              .toList();
          expect(originalScroll.position.maxScrollExtent, greaterThan(1000));
          expect(originalScroll.position.extentAfter, lessThan(1));
          expect(position.followLatest, isTrue);
          expect(_visible(tester, _group(_Fixture.lastId), transcript), isTrue);
          expect(
            _visible(tester, _group(_Fixture.replyId), transcript),
            isFalse,
          );

          fixture.publish(AgentUiPhase.running);
          await tester.pumpAndSettle();
          final reply = _group(_Fixture.replyId);
          final viewport = tester.getRect(transcript);
          expect(_visible(tester, reply, transcript), isTrue);
          expect(
            tester.getRect(reply).top,
            greaterThanOrEqualTo(viewport.top - 2),
          );
          expect(
            position.anchor,
            const ValueKey('agent-message-group-${_Fixture.replyId}'),
          );
          expect(position.followLatest, isFalse);
          expect(
            _visible(tester, _group(_Fixture.lastId), transcript),
            isFalse,
          );
          final top = tester.getRect(reply).top;

          for (final count in [36, 72]) {
            final text = List.generate(
              count,
              (index) =>
                  'Streaming paragraph $index. This is a readable update to the selected earlier reply. '
                  'It does not move the later conversation or change the saved schedule.',
            ).join('\n\n');
            fixture.publish(AgentUiPhase.running, text: text);
            await tester.pumpAndSettle();
            expect(_content(tester, reply).text, text);
            expect(
              tester.getRect(reply).height,
              greaterThan(viewport.height * 2),
            );
            expect(tester.getRect(reply).top, closeTo(top, 2));
            expect(
              position.anchor,
              const ValueKey('agent-message-group-${_Fixture.replyId}'),
            );
            expect(position.followLatest, isFalse);
            expect(
              _visible(tester, _group(_Fixture.lastId), transcript),
              isFalse,
            );
            expect(
              find.byKey(const ValueKey('agent-streaming-text')),
              findsNothing,
            );
            expect(fixture.storage.source, archive);
          }

          fixture.publish(
            terminal,
            text:
                'A late uncommitted partial response must not remain visible.',
            error: terminal == AgentUiPhase.failed ? 'provider.network' : null,
          );
          await tester.pumpAndSettle();
          expect(_content(tester, reply).text, _Fixture.savedReply);
          expect(tester.getRect(reply).top, closeTo(top, 2));
          expect(
            position.anchor,
            const ValueKey('agent-message-group-${_Fixture.replyId}'),
          );
          expect(position.followLatest, isFalse);
          expect(
            _visible(tester, _group(_Fixture.lastId), transcript),
            isFalse,
          );
          expect(fixture.storage.source, archive);
          expect(
            fixture.repository.selected!.messages.map((message) => message.id),
            ids,
          );
          expect(fixture.repository.selected!.replyRevisions, isEmpty);
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(platform),
      );
    }
  }
}

Finder _group(String id) => find.byKey(ValueKey('agent-message-group-$id'));

bool _visible(WidgetTester tester, Finder message, Finder transcript) {
  if (message.evaluate().isEmpty) return false;
  final rect = tester.getRect(message);
  final viewport = tester.getRect(transcript);
  return rect.bottom > viewport.top && rect.top < viewport.bottom;
}

AgentMessageContent _content(WidgetTester tester, Finder group) =>
    tester.widget(
      find.descendant(of: group, matching: find.byType(AgentMessageContent)),
    );

class _Fixture {
  _Fixture(this.storage, this.repository, this.delegate, this.id);
  static const replyId = 'early-reply';
  static const lastId = 'tail-reply-23';
  static const savedReply = 'The saved early reply stays here.';
  final UiMemoryStorage storage;
  final ConversationRepository repository;
  final UiDelegate delegate;
  final String id;

  static Future<_Fixture> create() async {
    final storage = UiMemoryStorage();
    final repository = ConversationRepository(storage: storage);
    await repository.load();
    final id = (await repository.create(title: 'Reading an earlier reply')).id;
    ConversationMessage message(
      String id,
      ConversationRole role,
      String text,
    ) => ConversationMessage(
      id: id,
      role: role,
      text: text,
      createdAt: DateTime.utc(2026, 11, 5),
    );
    await repository.update(
      id,
      (current) => current.copyWith(
        messages: [
          message(
            'early-request',
            ConversationRole.user,
            'Explain this saved schedule.',
          ),
          message(replyId, ConversationRole.assistant, savedReply),
          for (var index = 0; index < 24; index++) ...[
            message(
              'tail-request-$index',
              ConversationRole.user,
              'Later request $index keeps its recorded identity.',
            ),
            message(
              'tail-reply-$index',
              ConversationRole.assistant,
              'Later saved reply $index.\n\n${List.filled(3, 'The following conversation remains available at its original position.').join(' ')}',
            ),
          ],
        ],
      ),
    );
    return _Fixture(storage, repository, UiDelegate(repository), id);
  }

  void publish(AgentUiPhase phase, {String text = '', String? error}) {
    delegate.state.value = AgentUiState(
      enabled: true,
      configured: true,
      runs: {
        id: AgentUiRunState(
          phase: phase,
          runId: 'same-replacement-run',
          replyTargetMessageId: replyId,
          streamingText: text,
          errorMessage: error,
        ),
      },
    );
  }

  void dispose() {
    repository.dispose();
    delegate.state.dispose();
  }
}
