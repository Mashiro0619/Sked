import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/history/conversation_history.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/ui/agent_conversation_timeline.dart';
import 'package:sked/agent/ui/agent_conversation_view.dart';
import 'package:sked/agent/ui/agent_operation_card.dart';
import 'package:sked/agent/ui/agent_transcript.dart';
import 'package:sked/agent/ui/agent_turn_activity.dart';
import 'package:sked/agent/ui/agent_ui_delegate.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/agent_settings.dart';

import '../acceptance/acceptance_harness.dart';
import 'agent_ui_test_support.dart';

const _desktopSize = Size(1000, 1200);
final _time = DateTime.utc(2026, 11, 5);

Finder _key(String value) => find.byKey(ValueKey(value));

void main() {
  testWidgets(
    'tool batches stay between their assistant messages in the real transcript',
    (tester) async {
      final fixture = await _mountFixture(tester, tools: 1);
      await tester.runAsync(
        () => fixture.repository.update(fixture.id, (current) {
          final messages = [
            current.messages[0],
            current.messages[1].copyWith(text: 'Checking reminders.'),
            current.messages[2],
            _message(
              'progress',
              ConversationRole.assistant,
              text: 'Now checking settings.',
              calls: const [
                ConversationToolCall(
                  id: 'settings',
                  name: 'settings.get',
                  arguments: '{}',
                ),
              ],
            ),
            _message(
              'settings-result',
              ConversationRole.tool,
              toolId: 'settings',
              text: '{"theme":"light"}',
            ),
            current.messages.last,
          ];
          return current.copyWith(
            messages: messages,
            turns: [
              current.turns.single.copyWith(
                messageIds: messages.map((message) => message.id),
              ),
            ],
          );
        }),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AgentTurnActivity), findsNWidgets(2));
      final sequence = [
        _key('agent-message-calls-0'),
        _key('agent-activity-toggle-turn-0'),
        _key('agent-message-progress'),
        _key('agent-activity-toggle-turn-0-activity-progress'),
        _key('agent-message-reply-0'),
      ];
      for (var index = 1; index < sequence.length; index++) {
        expect(
          tester.getRect(sequence[index]).top,
          greaterThanOrEqualTo(tester.getRect(sequence[index - 1]).bottom),
        );
      }
      final before = fixture.storage.source;
      await _tap(tester, sequence[3]);
      await _tap(tester, _key('agent-activity-tool-settings'));
      expect(find.textContaining('"theme": "light"'), findsOneWidget);
      expect(fixture.storage.source, before);
      expect(fixture.delegate.calls, isEmpty);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  for (final turns in [1, 2]) {
    testWidgets(
      'the real transcript groups eight ordinary tools per recorded turn with $turns ${turns == 1 ? 'turn including steering' : 'separate turns'}',
      (tester) async {
        final fixture = await _mountFixture(tester, turns: turns);
        final before = fixture.storage.source;
        final conversation = fixture.repository.selected!.toJson();
        final l = AppLocalizations.of(
          tester.element(find.byType(AgentConversationView)),
        );
        expect(find.byType(AgentTurnActivity), findsNWidgets(turns));
        expect(find.byType(ExpansionTile), findsNothing);
        expect(find.text('notifications.reminders'), findsNothing);
        expect(
          find.text(
            '${l.agentActivitySummary(8)} · ${l.agentActivityCompleted}',
          ),
          findsNWidgets(turns),
        );
        for (var turn = 0; turn < turns; turn++) {
          expect(_key('agent-activity-list-turn-$turn'), findsNothing);
          expect(
            tester.getSize(_key('agent-activity-toggle-turn-$turn')).height,
            32,
          );
        }
        final first = tester
            .widgetList<AgentTurnActivity>(find.byType(AgentTurnActivity))
            .first;
        expect(first.activity.id, 'turn-0');
        expect(first.activity.tools, hasLength(8));
        expect(
          first.activity.tools.every(
            (tool) => tool.status == AgentToolActivityStatus.completed,
          ),
          isTrue,
        );
        if (turns == 1) {
          expect(
            find.text('Include tomorrow in the same request.'),
            findsOneWidget,
          );
        }
        await _tap(tester, _key('agent-activity-toggle-turn-0'));
        expect(_key('agent-activity-list-turn-0'), findsOneWidget);
        expect(
          tester.getSize(_key('agent-activity-list-turn-0')).height,
          lessThanOrEqualTo(280),
        );
        expect(find.text('notifications.reminders'), findsNothing);
        await _tap(tester, _key('agent-activity-tool-call-0-0'));
        expect(_key('agent-activity-detail-call-0-0'), findsOneWidget);
        expect(find.text('notifications.reminders'), findsOneWidget);
        expect(find.textContaining('Stored output 0 / 0'), findsOneWidget);
        expect(find.byType(ExpansionTile), findsNothing);
        expect(fixture.repository.selected!.toJson(), conversation);
        expect(fixture.storage.source, before);
        expect(fixture.delegate.calls, isEmpty);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }

  testWidgets(
    'a pending tool stays running in the real transcript until its stored result arrives',
    (tester) async {
      final fixture = await _mountFixture(
        tester,
        tools: 1,
        outcome: ConversationAttemptOutcome.pending,
        results: false,
      );
      final l = AppLocalizations.of(
        tester.element(find.byType(AgentConversationView)),
      );
      expect(
        find.text('${l.agentActivitySummary(1)} · ${l.agentRunning}'),
        findsOneWidget,
      );
      expect(find.byType(ExpansionTile), findsNothing);
      expect(find.byType(AgentOperationCard), findsNothing);
      await _tap(tester, _key('agent-activity-toggle-turn-0'));
      await _tap(tester, _key('agent-activity-tool-call-0-0'));
      final detail = _key('agent-activity-detail-call-0-0');
      expect(
        find.descendant(of: detail, matching: find.text(l.agentRunning)),
        findsOneWidget,
      );
      final pending = tester
          .widget<AgentTurnActivity>(find.byType(AgentTurnActivity))
          .activity;
      expect(pending.tools.single.result, isNull);
      expect(pending.tools.single.status, AgentToolActivityStatus.running);
      const result = '{"items":["Accepted current output"]}';
      await tester.runAsync(
        () => fixture.repository.update(fixture.id, (current) {
          final message = _message(
            'result-0-0',
            ConversationRole.tool,
            text: result,
            toolId: 'call-0-0',
          );
          final reply = _message(
            'reply-0',
            ConversationRole.assistant,
            text: 'The current check is complete.',
          );
          return current.copyWith(
            status: ConversationStatus.idle,
            messages: [...current.messages, message, reply],
            runs: [
              current.runs.single.copyWith(
                status: ConversationRunStatus.completed,
                settledAt: _time,
                tools: const [
                  ConversationToolUsage(
                    id: 'call-0-0',
                    name: 'notifications.reminders',
                    outcome: ConversationAttemptOutcome.completed,
                  ),
                ],
              ),
            ],
            turns: [
              current.turns.single.copyWith(
                messageIds: [
                  ...current.turns.single.messageIds,
                  message.id,
                  reply.id,
                ],
              ),
            ],
          );
        }),
      );
      fixture.delegate.state.value = AgentUiState(
        enabled: true,
        configured: true,
      );
      await tester.pumpAndSettle();
      expect(
        find.text('${l.agentActivitySummary(1)} · ${l.agentActivityCompleted}'),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: detail,
          matching: find.textContaining('Accepted current output'),
        ),
        findsOneWidget,
      );
      final completed = tester
          .widget<AgentTurnActivity>(find.byType(AgentTurnActivity))
          .activity;
      expect(completed.tools.single.status, AgentToolActivityStatus.completed);
      expect(completed.tools.single.result, result);
      expect(find.byType(ExpansionTile), findsNothing);
      expect(fixture.delegate.calls, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'real prepared saved and failed receipts stay independent of collapsed transcript activity',
    (tester) async {
      addTearDown(tester.view.reset);
      final harness = AcceptanceHarness();
      await tester.runAsync(harness.initialize);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(harness.close);
      });
      final application = harness.app.agent;
      final repository = application.conversations;
      late Map<String, Object?> prepared;
      late Map<String, Object?> saved;
      late Map<String, Object?> failed;
      await tester.runAsync(() async {
        await repository.update(
          harness.conversationId,
          (current) => current.copyWith(
            messages: [
              _message(
                'actual-request',
                ConversationRole.user,
                text: 'Prepare one calendar, save another, and check a missing target.',
              ),
            ],
          ),
        );
        prepared = await application.runtime.runHostAction(
          harness.conversationId,
          (scope, approval) => application.tools.execute(
            ProviderToolCall(
              id: 'real-preview',
              name: 'mutation.prepare',
              arguments: jsonEncode({
                'commands': [
                  {
                    'kind': 'calendar',
                    'action': 'create',
                    'values': {'name': 'Pending study calendar'},
                  },
                ],
              }),
            ),
            scope,
            approval,
          ),
        );
        saved = await application.runtime.runHostAction(
          harness.conversationId,
          (scope, approval) async {
            final plan = await application.tools.execute(
              ProviderToolCall(
                id: 'real-prepare',
                name: 'mutation.prepare',
                arguments: jsonEncode({
                  'commands': [
                    {
                      'kind': 'calendar',
                      'action': 'create',
                      'values': {'name': 'Saved study calendar'},
                    },
                  ],
                }),
              ),
              scope,
              approval,
            );
            return application.tools.execute(
              ProviderToolCall(
                id: 'real-commit',
                name: 'mutation.commit',
                arguments: jsonEncode({'planId': plan['planId']}),
              ),
              scope,
              approval,
            );
          },
        );
        failed = await application.runtime.runHostAction(
          harness.conversationId,
          (scope, approval) => application.tools.execute(
            ProviderToolCall(
              id: 'real-invalid-target',
              name: 'mutation.prepare',
              arguments: jsonEncode({
                'commands': [
                  {
                    'kind': 'calendar',
                    'action': 'patch',
                    'target': {'id': 'missing-activity-target'},
                    'values': {'name': 'Must not be created'},
                  },
                ],
              }),
            ),
            scope,
            approval,
          ),
        );
      });
      expect(prepared['planId'], isA<String>());
      expect(prepared['status'], isNull);
      expect(saved['status'], 'committed');
      expect(failed['error'], isNotNull);
      expect(
        harness.saved.generalMode.schedules.where(
          (item) => item.name == 'Saved study calendar',
        ),
        hasLength(1),
      );
      expect(
        harness.saved.generalMode.schedules.where(
          (item) =>
              item.name == 'Pending study calendar' ||
              item.name == 'Must not be created',
        ),
        isEmpty,
      );
      final beforeMain = harness.saved.encode();
      final beforeHistory = harness.conversations.source;
      final beforeConversation = repository.selected!.toJson();
      await mountAgentUi(
        tester,
        AgentConversationView(
          repository: repository,
          delegate: application.runtime,
        ),
        size: const Size(1000, 1600),
      );
      final l = AppLocalizations.of(
        tester.element(find.byType(AgentConversationView)),
      );
      expect(find.byType(AgentOperationCard), findsNWidgets(3));
      expect(
        find.ancestor(
          of: find.byType(AgentOperationCard),
          matching: find.byType(AgentTurnActivity),
        ),
        findsNothing,
      );
      final messages = repository.selected!.messages
          .where((message) => message.role == ConversationRole.tool)
          .toList();
      for (final result in [prepared, saved, failed]) {
        final message = messages.singleWhere(
          (message) => message.text == jsonEncode(result),
        );
        expect(_key('agent-message-${message.id}'), findsOneWidget);
      }
      expect(find.text(l.agentPlanReady), findsOneWidget);
      expect(find.text(l.agentChangesSaved), findsOneWidget);
      expect(find.text(l.agentActionFailed), findsOneWidget);
      final activity = tester
          .widgetList<AgentTurnActivity>(find.byType(AgentTurnActivity))
          .first;
      expect(_key('agent-activity-list-${activity.activity.id}'), findsNothing);
      await _tap(tester, _key('agent-activity-toggle-${activity.activity.id}'));
      expect(find.byType(AgentOperationCard), findsNWidgets(3));
      expect(harness.saved.encode(), beforeMain);
      expect(harness.conversations.source, beforeHistory);
      expect(repository.selected!.toJson(), beforeConversation);
      expect(tester.takeException(), isNull);
    },
  );

  for (final hideActive in [true, false]) {
    testWidgets(
      'the real view expires activity callbacks and clipboard acknowledgement after ${hideActive ? 'active' : 'interactive'} reentry',
      (tester) async {
        final fixture = await _mountFixture(tester, tools: 1);
        final before = fixture.storage.source;
        final gate = Completer<void>();
        final copied = <String>[];
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(SystemChannels.platform, (
          call,
        ) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
            if (copied.length == 1) await gate.future;
          }
          return null;
        });
        addTearDown(() {
          if (!gate.isCompleted) gate.complete();
          messenger.setMockMethodCallHandler(SystemChannels.platform, null);
        });
        await _tap(tester, _key('agent-activity-toggle-turn-0'));
        await _tap(tester, _key('agent-activity-tool-call-0-0'));
        final staleToggle = tester
            .widget<InkWell>(_key('agent-activity-toggle-turn-0'))
            .onTap!;
        final staleCopy = tester
            .widget<IconButton>(_key('agent-activity-copy-call-0-0'))
            .onPressed!;
        final state = tester.state(find.byType(AgentConversationView));
        await tester.tap(_key('agent-activity-copy-call-0-0'));
        await tester.pump();
        expect(copied, hasLength(1));
        await mountAgentUi(
          tester,
          fixture.view(active: !hideActive, interactive: hideActive),
          size: _desktopSize,
        );
        await mountAgentUi(tester, fixture.view(), size: _desktopSize);
        expect(tester.state(find.byType(AgentConversationView)), same(state));
        gate.complete();
        await tester.pumpAndSettle();
        staleToggle();
        staleCopy();
        await tester.pumpAndSettle();
        expect(_key('agent-activity-detail-call-0-0'), findsNothing);
        expect(_key('agent-activity-list-turn-0'), findsNothing);
        expect(copied, hasLength(1));
        await _tap(tester, _key('agent-activity-toggle-turn-0'));
        await _tap(tester, _key('agent-activity-tool-call-0-0'));
        final l = AppLocalizations.of(
          tester.element(find.byType(AgentConversationView)),
        );
        expect(find.byTooltip(l.agentCopied), findsNothing);
        await _tap(tester, _key('agent-activity-copy-call-0-0'));
        expect(copied, hasLength(2));
        expect(find.byTooltip(l.agentCopied), findsOneWidget);
        expect(fixture.storage.source, before);
        expect(fixture.delegate.calls, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final direction in TextDirection.values) {
    testWidgets(
      'the real narrow 2x $direction transcript reaches the final activity and complete copied output',
      (tester) async {
        final output = jsonEncode({
          'items': [for (var index = 0; index < 80; index++) '完整活动输出 $index'],
        });
        final fixture = await _mountFixture(
          tester,
          tools: 12,
          result: output,
          size: const Size(320, 1000),
          scale: 2,
          brightness: Brightness.dark,
          direction: direction,
        );
        final copied = <String>[];
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(SystemChannels.platform, (
          call,
        ) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        });
        addTearDown(
          () =>
              messenger.setMockMethodCallHandler(SystemChannels.platform, null),
        );
        final toggle = _key('agent-activity-toggle-turn-0');
        final transcript = _key('agent-transcript-${fixture.id}');
        await tester.scrollUntilVisible(
          toggle,
          -100,
          scrollable: find
              .descendant(of: transcript, matching: find.byType(Scrollable))
              .first,
        );
        await _tap(tester, toggle);
        expect(tester.getSize(toggle).height, greaterThanOrEqualTo(48));
        final list = _key('agent-activity-list-turn-0');
        expect(tester.getSize(list).height, lessThanOrEqualTo(280));
        final last = _key('agent-activity-tool-call-0-11');
        await tester.dragUntilVisible(last, list, const Offset(0, -100));
        expect(tester.getSize(last).height, greaterThanOrEqualTo(48));
        await _tap(tester, last);
        final detail = _key('agent-activity-detail-call-0-11');
        expect(tester.getSize(detail).height, lessThanOrEqualTo(320));
        for (final control in [
          'agent-activity-back',
          'agent-activity-copy-call-0-11',
        ]) {
          await tester.ensureVisible(_key(control));
          await tester.pumpAndSettle();
          expect(tester.getSize(_key(control)).width, greaterThanOrEqualTo(48));
          expect(
            tester.getSize(_key(control)).height,
            greaterThanOrEqualTo(48),
          );
          expect(_key(control).hitTestable(), findsOneWidget);
        }
        await _tap(tester, _key('agent-activity-copy-call-0-11'));
        expect(copied, hasLength(1));
        expect(copied.single, contains(output));
        expect(copied.single, contains('完整活动输出 0'));
        expect(copied.single, contains('完整活动输出 79'));
        await _tap(tester, _key('agent-activity-back'));
        expect(list, findsOneWidget);
        expect(detail, findsNothing);
        expect(fixture.delegate.calls, isEmpty);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }

  for (final hideActive in [true, false]) {
    testWidgets(
      'an activity keeps its reading anchor across ${hideActive ? 'workspace' : 'overlay'} reentry',
      (tester) async {
        final fixture = await _mountFixture(tester, turns: 12);
        final transcriptFinder = find.byType(AgentTranscript);
        final transcript = tester.widget<AgentTranscript>(transcriptFinder);
        final activity = transcript.children
            .whereType<AgentTurnActivity>()
            .elementAt(5);
        final anchor = activity.key! as LocalKey;
        expect(
          tester.state<AgentTranscriptState>(transcriptFinder).reveal(anchor),
          isTrue,
        );
        await tester.pumpAndSettle();
        final toggle = _key('agent-activity-toggle-turn-5');
        expect(toggle.hitTestable(), findsOneWidget);
        final top = tester.getRect(toggle).top;
        expect(transcript.position.anchor, anchor);
        expect(transcript.position.followLatest, isFalse);
        await mountAgentUi(
          tester,
          fixture.view(active: !hideActive, interactive: hideActive),
          size: _desktopSize,
        );
        await mountAgentUi(tester, fixture.view(), size: _desktopSize);
        final restored = tester
            .widget<AgentTranscript>(transcriptFinder)
            .position;
        expect(restored.anchor, anchor);
        expect(restored.followLatest, isFalse);
        expect(toggle.hitTestable(), findsOneWidget);
        expect(tester.getRect(toggle).top, closeTo(top, 2));
        expect(fixture.delegate.calls, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final outcome in [
    ConversationAttemptOutcome.notStarted,
    ConversationAttemptOutcome.unknown,
    ConversationAttemptOutcome.pending,
  ]) {
    testWidgets(
      'an interrupted real transcript keeps $outcome distinct from completion',
      (tester) async {
        final result = outcome == ConversationAttemptOutcome.notStarted
            ? '{"status":"not_executed","error":{"code":"cancelled"}}'
            : '{"status":"outcome_unknown","error":{"code":"operationRecoveryRequired"}}';
        final fixture = await _mountFixture(
          tester,
          tools: 1,
          outcome: outcome,
          status: ConversationStatus.interrupted,
          results: outcome != ConversationAttemptOutcome.pending,
          result: result,
        );
        final semantics = tester.ensureSemantics();
        try {
          await tester.pump();
          final l = AppLocalizations.of(
            tester.element(find.byType(AgentConversationView)),
          );
          final expected = outcome == ConversationAttemptOutcome.notStarted
              ? l.agentActivityNotStarted
              : l.agentActivityUncertain;
          expect(
            find.text('${l.agentActivitySummary(1)} · $expected'),
            findsOneWidget,
          );
          expect(
            find.bySemanticsLabel(RegExp(RegExp.escape(expected))),
            findsWidgets,
          );
          expect(
            find.text(
              '${l.agentActivitySummary(1)} · ${l.agentActivityCompleted}',
            ),
            findsNothing,
          );
          expect(find.text(l.agentChangesSaved), findsNothing);
          expect(
            find.byType(AgentOperationCard),
            outcome == ConversationAttemptOutcome.pending
                ? findsNothing
                : findsOneWidget,
          );
          await _tap(tester, _key('agent-activity-toggle-turn-0'));
          await _tap(tester, _key('agent-activity-tool-call-0-0'));
          final activity = tester
              .widget<AgentTurnActivity>(find.byType(AgentTurnActivity))
              .activity;
          expect(
            activity.tools.single.status,
            outcome == ConversationAttemptOutcome.notStarted
                ? AgentToolActivityStatus.notStarted
                : AgentToolActivityStatus.uncertain,
          );
          if (outcome == ConversationAttemptOutcome.pending) {
            expect(activity.tools.single.result, isNull);
            expect(
              find.descendant(
                of: _key('agent-activity-detail-call-0-0'),
                matching: find.text(expected),
              ),
              findsOneWidget,
            );
          } else {
            expect(activity.tools.single.result, result);
          }
          expect(fixture.delegate.calls, isEmpty);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
  }
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  expect(target.hitTestable(), findsOneWidget);
  await tester.tap(target.hitTestable());
  await tester.pumpAndSettle();
}

ConversationMessage _message(
  String id,
  ConversationRole role, {
  String text = '',
  String? toolId,
  Iterable<ConversationToolCall> calls = const [],
}) => ConversationMessage(
  id: id,
  role: role,
  text: text,
  createdAt: _time,
  toolCallId: toolId,
  toolCalls: calls,
);

Future<_ActivityFixture> _mountFixture(
  WidgetTester tester, {
  int tools = 8,
  int turns = 1,
  ConversationAttemptOutcome outcome = ConversationAttemptOutcome.completed,
  ConversationStatus? status,
  bool results = true,
  String? result,
  Size size = _desktopSize,
  double scale = 1,
  Brightness brightness = Brightness.light,
  TextDirection? direction,
}) async {
  addTearDown(tester.view.reset);
  final fixture = (await tester.runAsync(
    () => _ActivityFixture.create(
      tools: tools,
      turns: turns,
      outcome: outcome,
      status: status,
      results: results,
      result: result,
    ),
  ))!;
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(fixture.repository.waitForPendingWrites);
    fixture.delegate.state.dispose();
    fixture.repository.dispose();
  });
  await mountAgentUi(
    tester,
    direction == null
        ? fixture.view()
        : Directionality(textDirection: direction, child: fixture.view()),
    size: size,
    scale: scale,
    brightness: brightness,
  );
  return fixture;
}

class _ActivityFixture {
  _ActivityFixture(this.storage, this.repository, this.delegate, this.id);
  final UiMemoryStorage storage;
  final ConversationRepository repository;
  final UiDelegate delegate;
  final String id;

  Widget view({bool active = true, bool interactive = true}) =>
      AgentConversationView(
        repository: repository,
        delegate: delegate,
        active: active,
        interactive: interactive,
      );

  static Future<_ActivityFixture> create({
    required int tools,
    required int turns,
    required ConversationAttemptOutcome outcome,
    required bool results,
    ConversationStatus? status,
    String? result,
  }) async {
    final storage = UiMemoryStorage();
    final repository = ConversationRepository(
      storage: storage,
      idGenerator: () => 'activity-conversation',
      clock: () => _time,
    );
    await repository.load();
    final conversation = await repository.create(
      title: 'Activity view fixture',
    );
    final actualStatus =
        status ??
        switch (outcome) {
          ConversationAttemptOutcome.pending => ConversationStatus.running,
          ConversationAttemptOutcome.notStarted ||
          ConversationAttemptOutcome.unknown => ConversationStatus.interrupted,
          _ => ConversationStatus.idle,
        };
    final messages = <ConversationMessage>[];
    final runs = <ConversationRunUsage>[];
    final recorded = <ConversationTurn>[];
    for (var turn = 0; turn < turns; turn++) {
      final current = <ConversationMessage>[
        _message(
          'request-$turn',
          ConversationRole.user,
          text: 'Check my reminders for request $turn.',
        ),
        _message(
          'calls-$turn',
          ConversationRole.assistant,
          calls: [
            for (var tool = 0; tool < tools; tool++)
              ConversationToolCall(
                id: 'call-$turn-$tool',
                name: 'notifications.reminders',
                arguments: '{"limit":$tool}',
              ),
          ],
        ),
        if (turns == 1 && tools > 1)
          _message(
            'steer-$turn',
            ConversationRole.user,
            text: 'Include tomorrow in the same request.',
          ),
        if (results)
          for (var tool = 0; tool < tools; tool++)
            _message(
              'result-$turn-$tool',
              ConversationRole.tool,
              toolId: 'call-$turn-$tool',
              text:
                  result ??
                  jsonEncode({
                    'items': ['Stored output $turn / $tool'],
                  }),
            ),
        if (actualStatus == ConversationStatus.idle)
          _message(
            'reply-$turn',
            ConversationRole.assistant,
            text: 'Here is the reminder summary for request $turn.',
          ),
      ];
      messages.addAll(current);
      runs.add(
        ConversationRunUsage(
          id: 'run-$turn',
          startedAt: _time,
          kind: ConversationRunKind.model,
          protocol: AgentModelProtocol.chatCompletions.name,
          model: 'activity-fixture-model',
          reasoningEffort: AgentReasoningEffort.low,
          // A lost UI session may still have an unsettled persisted ledger.
          // Settled ledgers cannot legally contain pending tool attempts.
          status: outcome == ConversationAttemptOutcome.pending
              ? ConversationRunStatus.running
              : switch (actualStatus) {
                  ConversationStatus.running ||
                  ConversationStatus.waitingApproval =>
                    ConversationRunStatus.running,
                  ConversationStatus.interrupted =>
                    ConversationRunStatus.interrupted,
                  _ => ConversationRunStatus.completed,
                },
          tools: [
            for (var tool = 0; tool < tools; tool++)
              ConversationToolUsage(
                id: 'call-$turn-$tool',
                name: 'notifications.reminders',
                outcome: outcome,
              ),
          ],
        ),
      );
      recorded.add(
        ConversationTurn(
          id: 'turn-$turn',
          requestMessageId: 'request-$turn',
          ownershipComplete: true,
          messageIds: current.map((message) => message.id),
          runIds: ['run-$turn'],
        ),
      );
    }
    await repository.update(
      conversation.id,
      (current) => current.copyWith(
        messages: messages,
        runs: runs,
        turns: recorded,
        status: actualStatus,
        runId: runs.last.id,
      ),
    );
    final delegate = UiDelegate(repository);
    if (actualStatus == ConversationStatus.running) {
      delegate.state.value = AgentUiState(
        enabled: true,
        configured: true,
        runs: {
          conversation.id: AgentUiRunState(
            phase: AgentUiPhase.running,
            runId: runs.last.id,
          ),
        },
      );
    }
    return _ActivityFixture(storage, repository, delegate, conversation.id);
  }
}
