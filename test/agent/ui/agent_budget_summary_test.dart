import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/ui/agent_budget_summary.dart';
import 'package:sked/agent/ui/agent_conversation_view.dart';
import 'package:sked/agent/ui/agent_message_content.dart';
import 'package:sked/agent/ui/agent_selectable_text.dart';
import 'package:sked/agent/ui/agent_ui_delegate.dart';
import 'package:sked/l10n/app_localizations.dart';

import 'agent_ui_test_support.dart';

void main() {
  testWidgets(
    'version three records requests without inventing a request allowance',
    (tester) async {
      addTearDown(tester.view.reset);
      final payload = _payload(reason: 'tools')
        ..['version'] = 3
        ..['requests'] = {'attempted': 102}
        ..['tokens'] = {'reported': 2400000, 'unreportedRequests': 0};
      final summary = AgentBudgetSummary.parse(_notice(payload))!;
      expect(summary.requests, {'attempted': 102});
      await mountAgentUi(
        tester,
        SingleChildScrollView(child: AgentBudgetSummaryView(summary: summary)),
      );
      final l = AppLocalizations.of(
        tester.element(find.byType(AgentBudgetSummaryView)),
      );
      expect(
        find.text(l.agentBudgetSummaryRecordedUsage(102, 2400000)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      for (final invalid in [-1, '1', null]) {
        expect(
          AgentBudgetSummary.parse(
            _notice({
              ...payload,
              'requests': {'attempted': 102, 'limit': invalid},
            }),
          ),
          isNull,
        );
      }
    },
  );

  testWidgets('new summaries show actual usage without a token allowance', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    final payload = _payload(reason: 'rounds')
      ..['version'] = 2
      ..['tokens'] = {'reported': 2400000, 'unreportedRequests': 1};
    final summary = AgentBudgetSummary.parse(_notice(payload))!;
    expect(summary.tokens.containsKey('limit'), isFalse);
    expect(summary.requestTokens, isNull);
    await mountAgentUi(
      tester,
      SingleChildScrollView(child: AgentBudgetSummaryView(summary: summary)),
    );
    final l = AppLocalizations.of(
      tester.element(find.byType(AgentBudgetSummaryView)),
    );
    expect(
      find.text(l.agentBudgetSummaryReportedUsage(3, 4, 2400000)),
      findsOneWidget,
    );
    expect(find.text(l.agentBudgetSummaryMissingUsage(1)), findsOneWidget);
    expect(find.text(l.agentBudgetSummaryTokenLimit), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('new summaries reject retired token stop reasons and invalid usage', () {
    final payload = _payload(reason: 'tools')
      ..['version'] = 2
      ..['tokens'] = {'reported': 2400000, 'unreportedRequests': 0};
    expect(
      AgentBudgetSummary.parse(_notice(payload))!.tokens['reported'],
      2400000,
    );
    for (final reason in ['tokens', 'requestTokens']) {
      expect(
        AgentBudgetSummary.parse(_notice({...payload, 'reason': reason})),
        isNull,
      );
    }
    for (final invalid in [null, -1, '1', 1.0]) {
      expect(
        AgentBudgetSummary.parse(
          _notice({
            ...payload,
            'tokens': {'reported': invalid, 'unreportedRequests': 0},
          }),
        ),
        isNull,
      );
    }
  });

  for (final reason in ['tokens', 'requestTokens', 'rounds', 'tools']) {
    test('parser retains $reason and all reported outcome categories', () {
      final summary = AgentBudgetSummary.parse(
        _notice(_payload(reason: reason)),
      )!;
      expect(summary.reason, reason);
      expect(summary.runId, 'run');
      expect(summary.counts, {
        'completed': 1,
        'failed': 2,
        'notStarted': 3,
        'unknown': 4,
      });
      expect(summary.requests, {'attempted': 3, 'limit': 4});
      expect(summary.tokens, {
        'reported': 1200,
        'unreportedRequests': 1,
        'limit': 2000,
      });
      expect(() => summary.counts['completed'] = 99, throwsUnsupportedError);
      expect(() => summary.requests.clear(), throwsUnsupportedError);
      expect(() => summary.tokens.clear(), throwsUnsupportedError);
    });

    testWidgets('the $reason summary preserves categories and missing usage', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      final summary = AgentBudgetSummary.parse(
        _notice(_payload(reason: reason)),
      )!;
      await mountAgentUi(
        tester,
        SingleChildScrollView(child: AgentBudgetSummaryView(summary: summary)),
      );
      final view = find.byType(AgentBudgetSummaryView);
      final l = AppLocalizations.of(tester.element(view));
      expect(find.text(_reasonLabel(l, reason)), findsOneWidget);
      expect(find.text(l.agentBudgetSummaryTools(1, 2, 3, 4)), findsOneWidget);
      expect(
        find.text(l.agentBudgetSummaryUsage(3, 4, 1200, 2000)),
        findsOneWidget,
      );
      expect(find.text(l.agentBudgetSummaryMissingUsage(1)), findsOneWidget);
    });
  }

  test(
    'legacy summaries remain readable without run identity or request tokens',
    () {
      final payload = _payload()..remove('runId');
      final summary = AgentBudgetSummary.parse(_notice(payload))!;
      expect(summary.runId, isNull);
      expect(summary.requestTokens, isNull);
      expect(summary.tokens['reported'], 1200);
    },
  );

  test('request tokens are optional immutable nonnegative counters', () {
    final payload = _payload(reason: 'requestTokens')
      ..['requestTokens'] = {'reported': 33999, 'limit': 32768};
    final summary = AgentBudgetSummary.parse(_notice(payload))!;
    expect(summary.requestTokens, {'reported': 33999, 'limit': 32768});
    expect(() => summary.requestTokens!.clear(), throwsUnsupportedError);
    for (final field in ['reported', 'limit']) {
      for (final invalid in [null, -1, 1.0, false, '1']) {
        expect(
          AgentBudgetSummary.parse(
            _notice({
              ...payload,
              'requestTokens': {
                'reported': 33999,
                'limit': 32768,
                field: invalid,
              },
            }),
          ),
          isNull,
        );
      }
      expect(
        AgentBudgetSummary.parse(
          _notice({
            ...payload,
            'requestTokens': {'reported': 33999, 'limit': 32768}..remove(field),
          }),
        ),
        isNull,
      );
    }
    for (final invalid in [null, 1, '33999', <Object?>[]]) {
      expect(
        AgentBudgetSummary.parse(
          _notice({...payload, 'requestTokens': invalid}),
        ),
        isNull,
      );
    }
    for (final invalid in ['', 1, false, 'x' * 257]) {
      expect(
        AgentBudgetSummary.parse(_notice({...payload, 'runId': invalid})),
        isNull,
      );
    }
  });

  testWidgets('request and accumulated token limits are displayed separately', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    final payload =
        _payload(reason: 'requestTokens', reported: 83516, unreported: 0)
          ..['tokens'] = {
            'reported': 83516,
            'unreportedRequests': 0,
            'limit': 100000,
          }
          ..['requestTokens'] = {'reported': 33999, 'limit': 32768};
    await mountAgentUi(
      tester,
      AgentBudgetSummaryView(
        summary: AgentBudgetSummary.parse(_notice(payload))!,
      ),
    );
    final l = AppLocalizations.of(
      tester.element(find.byType(AgentBudgetSummaryView)),
    );
    expect(find.text(l.agentBudgetSummaryRequestTokenLimit), findsOneWidget);
    expect(
      find.text(l.agentBudgetSummaryRequestTokenUsage(33999, 32768)),
      findsOneWidget,
    );
    expect(
      find.text(l.agentBudgetSummaryUsage(3, 4, 83516, 100000)),
      findsOneWidget,
    );
    expect(find.text(l.agentBudgetSummaryTokenLimit), findsNothing);
  });

  for (final (reason, error) in const [
    ('tokens', 'tokenBudgetExceeded'),
    ('tokens', 'provider.tokenBudgetExceeded'),
    ('requestTokens', 'requestTokenBudgetExceeded'),
    ('requestTokens', 'provider.tokenBudgetExceeded'),
    ('rounds', 'roundBudgetExceeded'),
    ('tools', 'toolBudgetExceeded'),
  ]) {
    testWidgets(
      '$error uses the matching run summary and retains explicit Continue',
      (tester) async {
        addTearDown(tester.view.reset);
        final app = await _fixture(_payload(reason: reason));
        _setFailure(app, error);
        await mountAgentUi(tester, app.view());
        expect(find.byType(AgentBudgetSummaryView), findsOneWidget);
        expect(find.byKey(const ValueKey('agent-request-error')), findsNothing);
        final continuation = find.byKey(const ValueKey('agent-continue'));
        expect(tester.widget<TextButton>(continuation).onPressed, isNotNull);
        await tester.tap(continuation);
        await tester.pumpAndSettle();
        expect(app.delegate.calls, ['continue:conversation']);
      },
    );
  }

  testWidgets(
    'regeneration keeps a short budget message beside its original reply',
    (tester) async {
      addTearDown(tester.view.reset);
      final app = await _fixture(_payload());
      await app.repository.update(
        'conversation',
        (current) => current.copyWith(
          messages: [
            ...current.messages.take(current.messages.length - 1),
            ConversationMessage(
              id: 'old-reply',
              role: ConversationRole.assistant,
              text: 'Original reply',
              createdAt: _now,
            ),
            current.messages.last,
          ],
        ),
      );
      app.delegate.state.value = AgentUiState(
        enabled: true,
        configured: true,
        runs: {
          'conversation': AgentUiRunState(
            runId: 'run',
            replyTargetMessageId: 'old-reply',
            phase: AgentUiPhase.failed,
            errorMessage: 'tokenBudgetExceeded',
          ),
        },
      );
      await mountAgentUi(tester, app.view());
      final failure = find.descendant(
        of: find.byKey(const ValueKey('agent-message-group-old-reply')),
        matching: find.byKey(const ValueKey('agent-request-error')),
      );
      expect(failure, findsOneWidget);
      final l = AppLocalizations.of(tester.element(failure));
      expect(
        tester.widget<AgentSelectableText>(failure).data,
        l.agentLimitsReached,
      );
      expect(find.byType(AgentBudgetSummaryView), findsOneWidget);
    },
  );

  for (final mismatch in [
    'oldRun',
    'missingRun',
    'differentReason',
    'importedHistory',
  ]) {
    testWidgets('$mismatch summaries cannot suppress a current budget error', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      final payload = _payload(
        reason: mismatch == 'differentReason' ? 'tools' : 'tokens',
      );
      if (mismatch == 'oldRun') payload['runId'] = 'old-run';
      if (mismatch == 'missingRun') payload.remove('runId');
      final app = await _fixture(payload);
      if (mismatch == 'importedHistory') {
        await app.repository.update(
          'conversation',
          (current) =>
              current.copyWith(executionHistoryStart: current.messages.length),
        );
      }
      _setFailure(app, 'tokenBudgetExceeded');
      await mountAgentUi(tester, app.view());
      expect(find.byKey(const ValueKey('agent-request-error')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final error in ['provider.authentication', 'provider.invalidResponse']) {
    testWidgets('a same-run budget notice preserves $error diagnostics', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      final app = await _fixture(_payload());
      _setFailure(app, error);
      await mountAgentUi(tester, app.view());
      final failure = find.byKey(const ValueKey('agent-request-error'));
      expect(failure, findsOneWidget);
      expect(tester.widget<AgentSelectableText>(failure).data, _rawFailure);
    });
  }

  test('only supported notice envelopes can become budget summaries', () {
    for (final raw in ['not JSON', '[]', 'null', '{}']) {
      expect(AgentBudgetSummary.parse(_rawNotice(raw)), isNull);
    }
    for (final change in <Map<String, Object?>>[
      {'kind': 'other_notice'},
      {'kind': null},
      {'version': 0},
      {'version': 2},
      {'version': '1'},
      {'version': 1.0},
      {'reason': 'unknown'},
      {'reason': null},
      {'counts': null},
      {'requests': null},
      {'tokens': null},
    ]) {
      expect(
        AgentBudgetSummary.parse(_notice({..._payload(), ...change})),
        isNull,
        reason: change.toString(),
      );
    }
    for (final role in [
      ConversationRole.user,
      ConversationRole.assistant,
      ConversationRole.tool,
    ]) {
      final message = ConversationMessage(
        id: 'not-notice',
        role: role,
        toolCallId: role == ConversationRole.tool ? 'call' : null,
        text: jsonEncode(_payload()),
        createdAt: _now,
      );
      expect(AgentBudgetSummary.parse(message), isNull, reason: role.name);
    }
  });

  test('every counter must be an explicit nonnegative integer', () {
    const fields = {
      'counts': ['completed', 'failed', 'notStarted', 'unknown'],
      'requests': ['attempted', 'limit'],
      'tokens': ['reported', 'unreportedRequests', 'limit'],
    };
    for (final section in fields.entries) {
      for (final field in section.value) {
        for (final invalid in [null, -1, 1.0, false, '1']) {
          final payload = _payload();
          final counters = Map<String, Object?>.from(
            payload[section.key] as Map,
          );
          counters[field] = invalid;
          payload[section.key] = counters;
          expect(
            AgentBudgetSummary.parse(_notice(payload)),
            isNull,
            reason: '${section.key}.$field=$invalid',
          );
        }
        final payload = _payload();
        payload[section.key] = Map<String, Object?>.from(
          payload[section.key] as Map,
        )..remove(field);
        expect(
          AgentBudgetSummary.parse(_notice(payload)),
          isNull,
          reason: '${section.key}.$field missing',
        );
      }
    }
  });

  testWidgets('unreported usage is retained without inventing a zero total', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    final payload = _payload(unreported: 3, reported: 0);
    await mountAgentUi(
      tester,
      AgentBudgetSummaryView(
        summary: AgentBudgetSummary.parse(_notice(payload))!,
      ),
    );
    final l = AppLocalizations.of(
      tester.element(find.byType(AgentBudgetSummaryView)),
    );
    expect(find.text(l.agentBudgetSummaryUsage(3, 4, 0, 2000)), findsOneWidget);
    expect(find.text(l.agentBudgetSummaryMissingUsage(3)), findsOneWidget);
    await mountAgentUi(
      tester,
      AgentBudgetSummaryView(
        summary: AgentBudgetSummary.parse(_notice(_payload(unreported: 0)))!,
      ),
    );
    expect(find.text(l.agentBudgetSummaryMissingUsage(3)), findsNothing);
    expect(find.text(l.agentBudgetSummaryMissingUsage(0)), findsNothing);
  });

  testWidgets(
    'real conversation notices keep completed failed skipped and unknown separate',
    (tester) async {
      addTearDown(tester.view.reset);
      final app = await _fixture(
        _payload(
          counts: const {
            'completed': 1,
            'failed': 1,
            'notStarted': 1,
            'unknown': 1,
          },
        ),
      );
      await mountAgentUi(tester, app.view());
      final view = find.byType(AgentBudgetSummaryView);
      expect(view, findsOneWidget);
      final l = AppLocalizations.of(tester.element(view));
      expect(
        find.descendant(
          of: view,
          matching: find.text(l.agentBudgetSummaryTools(1, 1, 1, 1)),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: view,
          matching: find.text(l.agentBudgetSummaryTools(4, 0, 0, 0)),
        ),
        findsNothing,
      );
      expect(
        app.repository.selected!.runs.single.tools.map((tool) => tool.outcome),
        [
          ConversationAttemptOutcome.completed,
          ConversationAttemptOutcome.failed,
          ConversationAttemptOutcome.notStarted,
          ConversationAttemptOutcome.unknown,
        ],
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is AgentMessageContent && widget.text == app.notice.text,
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final defect in ['invalidCounter', 'missingUsage', 'unknownVersion']) {
    testWidgets('$defect notices fall back to their original message', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      final payload = _payload();
      switch (defect) {
        case 'invalidCounter':
          payload['counts'] = {
            'completed': -1,
            'failed': 0,
            'notStarted': 0,
            'unknown': 0,
          };
        case 'missingUsage':
          payload.remove('tokens');
        case 'unknownVersion':
          payload['version'] = 999;
      }
      final app = await _fixture(payload);
      await mountAgentUi(tester, app.view());
      expect(find.byType(AgentBudgetSummaryView), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is AgentMessageContent && widget.text == app.notice.text,
        ),
        findsOneWidget,
      );
      final l = AppLocalizations.of(
        tester.element(find.byType(AgentConversationView)),
      );
      expect(find.text(l.agentBudgetSummaryTitle), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'a 320px 2x conversation exposes the full budget summary without overflow',
    (tester) async {
      addTearDown(tester.view.reset);
      final app = await _fixture(_payload(unreported: 2));
      await mountAgentUi(
        tester,
        app.view(),
        size: const Size(320, 480),
        scale: 2,
      );
      final view = find.byType(AgentBudgetSummaryView);
      final l = AppLocalizations.of(
        tester.element(find.byType(AgentConversationView)),
      );
      // The short layout follows its composer footer. Reveal the preceding
      // lazy transcript item before looking up any of its descendants.
      await tester.scrollUntilVisible(
        view,
        -180,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('agent-transcript-conversation')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.ensureVisible(
        find.text(l.agentBudgetSummaryMissingUsage(2)),
      );
      await tester.pumpAndSettle();
      expect(find.text(l.agentBudgetSummaryMissingUsage(2)), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'equal notice IDs in a replacement repository use the replacement summary',
    (tester) async {
      addTearDown(tester.view.reset);
      final original = await _fixture(
        _payload(reason: 'tokens', unreported: 1),
      );
      final replacement = await _fixture(
        _payload(reason: 'tools', reported: 99, unreported: 0),
      );
      await mountAgentUi(tester, original.view());
      final l = AppLocalizations.of(
        tester.element(find.byType(AgentBudgetSummaryView)),
      );
      expect(find.text(l.agentBudgetSummaryTokenLimit), findsOneWidget);
      await mountAgentUi(tester, replacement.view());
      expect(find.byType(AgentBudgetSummaryView), findsOneWidget);
      expect(find.text(l.agentBudgetSummaryToolLimit), findsOneWidget);
      expect(
        find.text(l.agentBudgetSummaryUsage(3, 4, 99, 2000)),
        findsOneWidget,
      );
      expect(find.text(l.agentBudgetSummaryTokenLimit), findsNothing);
      expect(find.text(l.agentBudgetSummaryMissingUsage(1)), findsNothing);
    },
  );

  testWidgets(
    'changing the current notice or conversation cannot retain an old summary',
    (tester) async {
      addTearDown(tester.view.reset);
      final app = await _fixture(_payload());
      await mountAgentUi(tester, app.view());
      final l = AppLocalizations.of(
        tester.element(find.byType(AgentBudgetSummaryView)),
      );
      final replacement = _notice(
        _payload(reason: 'rounds', reported: 77, unreported: 0),
      );
      await app.repository.update(
        'conversation',
        (current) => current.copyWith(
          messages: [
            for (final message in current.messages)
              message.id == replacement.id ? replacement : message,
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(l.agentBudgetSummaryRoundLimit), findsOneWidget);
      expect(find.text(l.agentBudgetSummaryTokenLimit), findsNothing);
      await app.repository.create(id: 'other', title: 'Other conversation');
      await app.repository.update(
        'other',
        (current) => current.copyWith(
          messages: [
            ConversationMessage(
              id: 'new-user',
              role: ConversationRole.user,
              text: 'A separate request',
              createdAt: _now,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AgentBudgetSummaryView), findsNothing);
      expect(find.text(l.agentBudgetSummaryRoundLimit), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

final _now = DateTime.utc(2026, 11, 7);

Map<String, Object?> _payload({
  String reason = 'tokens',
  int reported = 1200,
  int unreported = 1,
  Map<String, int>? counts,
}) => {
  'kind': 'agent_budget_summary',
  'version': 1,
  'runId': 'run',
  'reason': reason,
  'errorCode': switch (reason) {
    'requestTokens' => 'requestTokenBudgetExceeded',
    'rounds' => 'roundBudgetExceeded',
    'tools' => 'toolBudgetExceeded',
    _ => 'tokenBudgetExceeded',
  },
  'counts':
      counts ?? {'completed': 1, 'failed': 2, 'notStarted': 3, 'unknown': 4},
  'requests': {'attempted': 3, 'limit': 4},
  'tokens': {
    'reported': reported,
    'unreportedRequests': unreported,
    'limit': 2000,
  },
  'tools': {'attempted': 4, 'limit': 4},
};

ConversationMessage _notice(Map<String, Object?> payload) =>
    _rawNotice(jsonEncode(payload));
ConversationMessage _rawNotice(String text) => ConversationMessage(
  id: 'budget',
  role: ConversationRole.notice,
  text: text,
  createdAt: _now,
);

Future<_BudgetFixture> _fixture(Map<String, Object?> payload) async {
  final repository = ConversationRepository(storage: UiMemoryStorage());
  await repository.load();
  await repository.create(id: 'conversation', title: 'Budget fixture');
  final results = <String, Map<String, Object?>>{
    'completed': {'status': 'ok', 'items': []},
    'failed': {
      'status': 'failed',
      'error': {'code': 'invalidArgument'},
    },
    'notStarted': {
      'status': 'not_executed',
      'error': {'code': 'tool_budget_exceeded'},
    },
    'unknown': {
      'status': 'outcome_unknown',
      'error': {'code': 'outcomeUnknown'},
    },
  };
  final notice = _notice(payload);
  await repository.update(
    'conversation',
    (current) => current.copyWith(
      status: ConversationStatus.interrupted,
      runId: 'run',
      messages: [
        ConversationMessage(
          id: 'user',
          role: ConversationRole.user,
          text: 'Read the current data',
          createdAt: _now,
        ),
        ConversationMessage(
          id: 'assistant',
          role: ConversationRole.assistant,
          text: '',
          createdAt: _now,
          toolCalls: [
            for (final id in results.keys)
              ConversationToolCall(
                id: id,
                name: 'resources.describe',
                arguments: '{"kind":"calendar"}',
              ),
          ],
        ),
        for (final result in results.entries)
          ConversationMessage(
            id: 'tool-${result.key}',
            role: ConversationRole.tool,
            toolCallId: result.key,
            text: jsonEncode(result.value),
            createdAt: _now,
          ),
        notice,
      ],
      runs: [
        ConversationRunUsage(
          id: 'run',
          startedAt: _now,
          kind: ConversationRunKind.model,
          protocol: 'chatCompletions',
          model: 'fixture',
          status: ConversationRunStatus.interrupted,
          tools: [
            for (final id in results.keys)
              ConversationToolUsage(
                id: id,
                name: 'resources.describe',
                outcome: ConversationAttemptOutcome.values.byName(id),
              ),
          ],
        ),
      ],
    ),
  );
  final delegate = UiDelegate(repository);
  addTearDown(delegate.state.dispose);
  addTearDown(repository.dispose);
  return _BudgetFixture(repository, delegate, notice);
}

class _BudgetFixture {
  _BudgetFixture(this.repository, this.delegate, this.notice);
  final ConversationRepository repository;
  final UiDelegate delegate;
  final ConversationMessage notice;
  Widget view() =>
      AgentConversationView(repository: repository, delegate: delegate);
}

String _reasonLabel(AppLocalizations l, String reason) => switch (reason) {
  'tokens' => l.agentBudgetSummaryTokenLimit,
  'requestTokens' => l.agentBudgetSummaryRequestTokenLimit,
  'rounds' => l.agentBudgetSummaryRoundLimit,
  _ => l.agentBudgetSummaryToolLimit,
};

const _rawFailure = 'Synthetic provider response body';

void _setFailure(_BudgetFixture app, String error) {
  app.delegate.state.value = AgentUiState(
    enabled: true,
    configured: true,
    runs: {
      'conversation': AgentUiRunState(
        runId: 'run',
        phase: AgentUiPhase.failed,
        errorMessage: error,
        providerErrorResponseBody: _rawFailure,
      ),
    },
  );
}
