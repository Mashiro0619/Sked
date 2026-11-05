import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/ui/agent_conversation_view.dart';
import 'package:sked/agent/ui/agent_ui_delegate.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/application/operation_contracts.dart';

import 'agent_ui_test_support.dart';

void main() {
  late ConversationRepository repository;
  late UiDelegate delegate;
  late String id;
  late AgentUiApproval plan;
  Finder key(String value) => find.byKey(ValueKey(value));

  void publish({bool maintenance = false, AgentUiApproval? approval}) {
    delegate.state.value = AgentUiState(
      enabled: true,
      configured: true,
      maintenance: maintenance,
      runs: {
        id: AgentUiRunState(
          phase: AgentUiPhase.waitingApproval,
          runId: 'run-1',
          pendingApproval: approval ?? plan,
        ),
      },
    );
  }

  Future<void> initialize({String draft = '', bool http = false}) async {
    repository = ConversationRepository(storage: UiMemoryStorage());
    await repository.load();
    id = (await repository.create(title: 'Review course change')).id;
    if (draft.isNotEmpty) {
      await repository.update(id, (current) => current.copyWith(draft: draft));
    }
    delegate = UiDelegate(repository);
    plan = AgentUiApproval(
      id: 'plan-1',
      summary: 'Change course location',
      details: http
          ? {'kind': 'httpTransport', 'endpoint': 'http://localhost:8000/v1'}
          : {
              'planId': 'plan-1',
              'changeCount': 1,
              'changes': [
                {
                  'key': 'course',
                  'before': {'title': '高等数学', 'location': 'A201'},
                  'after': {'title': '高等数学', 'location': 'B305'},
                },
              ],
            },
    );
    publish();
    addTearDown(repository.dispose);
    addTearDown(delegate.state.dispose);
  }

  Widget view({bool active = true, bool interactive = true}) =>
      AgentConversationView(
        repository: repository,
        delegate: delegate,
        active: active,
        interactive: interactive,
      );
  VoidCallback revise(WidgetTester tester) =>
      tester.widget<TextButton>(key('agent-revise-approval')).onPressed!;
  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await repository.waitForPendingWrites();
    await tester.pumpAndSettle();
  }

  for (final draft in ['', '已有草稿，请保留']) {
    testWidgets(
      'approval correction focuses original input without submitting or replacing draft "$draft"',
      (tester) async {
        addTearDown(tester.view.reset);
        await initialize(draft: draft);
        await mountAgentUi(
          tester,
          view(),
          size: const Size(390, 844),
          locale: const Locale('zh'),
        );
        final field = tester.widget<TextField>(key('agent-composer'));
        final controller = field.controller!;
        if (draft.isNotEmpty) {
          controller.selection = const TextSelection(
            baseOffset: 1,
            extentOffset: 3,
          );
        }
        final originalValue = controller.value;
        expect(key('agent-revise-approval'), findsOneWidget);
        if (draft.isEmpty) {
          expect(key('agent-steer'), findsNothing);
        }
        await tester.ensureVisible(key('agent-revise-approval'));
        await tester.pumpAndSettle();
        await tester.tap(key('agent-revise-approval'));
        await settle(tester);
        expect(field.focusNode!.hasFocus, isTrue);
        expect(tester.testTextInput.hasAnyClients, isTrue);
        expect(controller.value, originalValue);
        expect(repository.selected!.draft, draft);
        expect(delegate.calls, isEmpty);
        expect(delegate.state.value.runFor(id).pendingApproval, same(plan));
        expect(key('agent-composer').hitTestable(), findsOneWidget);
        final l = AppLocalizations.of(tester.element(key('agent-composer')));
        expect(find.text(l.agentApprovalReviseHint), findsOneWidget);
        await tester.enterText(key('agent-composer'), '请改为 B402，时间保持不变');
        await settle(tester);
        expect(key('agent-approval-revise-hint'), findsOneWidget);
        await tester.ensureVisible(key('agent-steer'));
        await tester.pumpAndSettle();
        await tester.tap(key('agent-steer'));
        await settle(tester);
        expect(delegate.calls, ['steer:$id:请改为 B402，时间保持不变']);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }

  testWidgets('320px 2x approval correction reaches input above the keyboard', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    await initialize(draft: '保留草稿');
    await mountAgentUi(
      tester,
      view(),
      size: const Size(320, 740),
      scale: 2,
      keyboard: 280,
      locale: const Locale('zh'),
    );
    expect(key('agent-approve').hitTestable(), findsOneWidget);
    await tester.drag(key('agent-transcript-$id'), const Offset(0, 180));
    await tester.pumpAndSettle();
    await tester.ensureVisible(key('agent-revise-approval'));
    await tester.pumpAndSettle();
    expect(key('agent-revise-approval').hitTestable(), findsOneWidget);
    await tester.tap(key('agent-revise-approval'));
    await settle(tester);
    final field = tester.widget<TextField>(key('agent-composer'));
    expect(field.controller!.text, '保留草稿');
    expect(field.focusNode!.hasFocus, isTrue);
    expect(tester.testTextInput.hasAnyClients, isTrue);
    expect(delegate.calls, isEmpty);
    expect(key('agent-composer').hitTestable(), findsOneWidget);
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '请保留时间，只改教室',
        selection: TextSelection.collapsed(offset: 10),
      ),
    );
    await settle(tester);
    await tester.ensureVisible(key('agent-steer'));
    await tester.pumpAndSettle();
    expect(key('agent-steer').hitTestable(), findsOneWidget);
    await tester.tap(key('agent-steer'));
    await settle(tester);
    expect(delegate.calls, ['steer:$id:请保留时间，只改教室']);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('HTTP permission keeps its own decision actions', (tester) async {
    await initialize(http: true);
    await mountAgentUi(tester, view());
    expect(key('agent-revise-approval'), findsNothing);
    expect(key('agent-approve'), findsOneWidget);
    expect(key('agent-reject'), findsOneWidget);
    expect(key('agent-approval-revise-hint'), findsNothing);
  });

  for (final boundary in [
    'conversation',
    'permission',
    'approval',
    'covered route',
    'hidden host',
    'maintenance',
  ]) {
    testWidgets(
      'old approval correction cannot focus after $boundary round trip',
      (tester) async {
        await initialize();
        await mountAgentUi(tester, view());
        final old = revise(tester);
        final field = tester.widget<TextField>(key('agent-composer'));
        switch (boundary) {
          case 'conversation':
            await repository.create(title: 'Other conversation');
            await settle(tester);
            old();
            await repository.select(id);
            await settle(tester);
          case 'permission':
            final mode = repository.selected!.mode;
            await repository.update(
              id,
              (current) => current.copyWith(mode: AgentPermissionMode.plan),
            );
            await settle(tester);
            old();
            await repository.update(
              id,
              (current) => current.copyWith(mode: mode),
            );
            await settle(tester);
          case 'approval':
            publish(
              approval: AgentUiApproval(
                id: 'plan-2',
                summary: 'Another change',
                details: const {'changeCount': 0},
              ),
            );
            await settle(tester);
            old();
            publish();
            await settle(tester);
          case 'covered route':
            final navigator = Navigator.of(
              tester.element(key('agent-revise-approval')),
            );
            navigator.push<void>(
              MaterialPageRoute(
                builder: (_) => const Scaffold(body: Text('Other page')),
              ),
            );
            await tester.pumpAndSettle();
            old();
            navigator.pop();
            await tester.pumpAndSettle();
          case 'hidden host':
            await mountAgentUi(tester, view(active: false));
            old();
            await mountAgentUi(tester, view());
          case 'maintenance':
            publish(maintenance: true);
            await settle(tester);
            old();
            publish();
            await settle(tester);
        }
        old();
        await settle(tester);
        expect(field.focusNode!.hasFocus, isFalse);
        expect(key('agent-approval-revise-hint'), findsNothing);
        expect(delegate.calls, isEmpty);
        await tester.ensureVisible(key('agent-revise-approval'));
        await tester.pumpAndSettle();
        await tester.tap(key('agent-revise-approval'));
        await settle(tester);
        expect(field.focusNode!.hasFocus, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
