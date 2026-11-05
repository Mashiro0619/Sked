import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/connection/agent_credential_store.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/ui/agent_conversation_view.dart';
import 'package:sked/agent/ui/agent_ui_delegate.dart';
import 'package:sked/models/agent_settings.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/screens/agent_connection_settings_page.dart';
import 'package:sked/screens/agent_settings_page.dart';

import '../../support/agent_workspace_navigation.dart';
import '../../support/workspace_harness.dart';
import 'agent_ui_test_support.dart';

Finder _key(String value) => find.byKey(ValueKey(value));

void main() {
  late ConversationRepository repository;
  late UiDelegate delegate;
  late int opened;
  late VoidCallback configure;

  Future<void> initialize() async {
    repository = ConversationRepository(storage: UiMemoryStorage());
    await repository.load();
    await repository.create(title: 'Configuration');
    delegate = UiDelegate(repository);
    delegate.state.value = AgentUiState(enabled: true);
    opened = 0;
    configure = () => opened++;
    addTearDown(repository.dispose);
    addTearDown(delegate.state.dispose);
  }

  Widget view({bool active = true, bool interactive = true}) =>
      AgentConversationView(
        repository: repository,
        delegate: delegate,
        active: active,
        interactive: interactive,
        onConfigureConnection: configure,
      );

  VoidCallback action(WidgetTester tester) => tester
      .widget<FilledButton>(_key('agent-configure-connection'))
      .onPressed!;

  testWidgets('unconfigured chat offers a named connection action', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    await initialize();
    final semantics = tester.ensureSemantics();
    await mountAgentUi(tester, view(), size: const Size(320, 740), scale: 2);
    final button = _key('agent-configure-connection');
    expect(button.hitTestable(), findsOneWidget);
    expect(
      find.descendant(
        of: button,
        matching: find.text(
          AppLocalizations.of(tester.element(button)).agentConnectionAndModels,
        ),
      ),
      findsOneWidget,
    );
    final data = tester.getSemantics(button).getSemanticsData();
    expect(data.flagsCollection.isButton, isTrue);
    await tester.tap(button);
    expect(opened, 1);
    expect(delegate.calls, isEmpty);
    expect(tester.widget<IconButton>(_key('agent-send')).onPressed, isNull);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  for (final gate in [
    'active',
    'interactive',
    'covered route',
    'configured',
    'maintenance',
    'disabled',
    'conversation',
    'callback',
    'delegate',
    'repository',
    'disposed',
  ]) {
    testWidgets('old connection action stays retired after $gate changes', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      await initialize();
      await mountAgentUi(tester, view());
      final stale = action(tester);
      switch (gate) {
        case 'active':
          await mountAgentUi(tester, view(active: false));
          stale();
          await mountAgentUi(tester, view());
        case 'interactive':
          await mountAgentUi(tester, view(interactive: false));
          stale();
          await mountAgentUi(tester, view());
        case 'covered route':
          final navigator = Navigator.of(
            tester.element(_key('agent-configure-connection')),
          );
          navigator.push<void>(
            MaterialPageRoute(
              builder: (_) => const Scaffold(body: Text('Cover')),
            ),
          );
          await tester.pumpAndSettle();
          stale();
          navigator.pop();
          await tester.pumpAndSettle();
        case 'configured':
          delegate.state.value = AgentUiState(enabled: true, configured: true);
          await tester.pumpAndSettle();
          expect(_key('agent-configure-connection'), findsNothing);
          stale();
          delegate.state.value = AgentUiState(enabled: true);
          await tester.pumpAndSettle();
        case 'maintenance':
          delegate.state.value = AgentUiState(enabled: true, maintenance: true);
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<FilledButton>(_key('agent-configure-connection'))
                .onPressed,
            isNull,
          );
          stale();
          delegate.state.value = AgentUiState(enabled: true);
          await tester.pumpAndSettle();
        case 'disabled':
          delegate.state.value = AgentUiState();
          await tester.pumpAndSettle();
          expect(_key('agent-configure-connection'), findsNothing);
          stale();
          delegate.state.value = AgentUiState(enabled: true);
          await tester.pumpAndSettle();
        case 'conversation':
          final previous = repository.selectedId!;
          await repository.create(title: 'Another');
          await tester.pumpAndSettle();
          stale();
          await repository.select(previous);
          await tester.pumpAndSettle();
        case 'callback':
          configure = () => opened += 10;
          await mountAgentUi(tester, view());
        case 'repository':
          repository = ConversationRepository(storage: UiMemoryStorage());
          addTearDown(repository.dispose);
          await repository.load();
          await repository.create(title: 'Replacement source');
          await mountAgentUi(tester, view());
        case 'disposed':
          await tester.pumpWidget(const SizedBox.shrink());
          stale();
          await mountAgentUi(tester, view());
        case 'delegate':
          delegate = UiDelegate(repository);
          addTearDown(delegate.state.dispose);
          delegate.state.value = AgentUiState(enabled: true);
          await mountAgentUi(tester, view());
      }
      stale();
      expect(opened, 0);
      await tester.tap(_key('agent-configure-connection'));
      expect(opened, gate == 'callback' ? 10 : 1);
      expect(tester.takeException(), isNull);
    });
  }

  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    testWidgets(
      'first-run action opens connection settings directly and returns to its draft on $platform',
      (tester) async {
        addTearDown(tester.view.reset);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = platform == TargetPlatform.windows
            ? const Size(1440, 900)
            : const Size(320, 740);
        final app = await workspaceProvider(
          agentCredentialStore: MemoryAgentCredentialStore(),
        );
        addTearDown(app.dispose);
        await app.agent.configure(const AgentSettings(enabled: true));
        await tester.pumpWidget(WorkspaceHarness(provider: app, textScale: 2));
        await tester.pumpAndSettle();
        await selectAgentShellDestination(tester, 'agent');
        await tester.pumpAndSettle();
        final button = _key('agent-configure-connection');
        await tester.ensureVisible(button);
        expect(button.hitTestable(), findsOneWidget);
        await tester.enterText(_key('agent-composer'), 'Keep the first draft');
        await tester.pumpAndSettle();
        final id = app.agent.conversations.selectedId!;
        final oldAction = action(tester);
        oldAction();
        oldAction();
        await tester.pumpAndSettle();
        expect(find.byType(AgentConnectionSettingsPage), findsOneWidget);
        expect(find.byType(AgentSettingsPage), findsNothing);
        expect(_key('agent-endpoint'), findsOneWidget);
        expect(
          app.agent.runtime.state.value.runFor(id).phase,
          AgentUiPhase.idle,
        );
        expect(app.agent.conversations.selected!.messages, isEmpty);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(AgentConnectionSettingsPage), findsNothing);
        expect(app.agent.conversations.selectedId, id);
        expect(
          tester.widget<TextField>(_key('agent-composer')).controller!.text,
          'Keep the first draft',
        );
        oldAction();
        await tester.pumpAndSettle();
        expect(find.byType(AgentConnectionSettingsPage), findsNothing);
        await app.agent.configure(
          const AgentSettings(
            enabled: true,
            endpoint: 'https://configuration.example.invalid/v1',
            model: 'fixture-model',
            models: [
              AgentModelConfig(
                id: 'fixture-model',
                reasoningEfforts: [AgentReasoningEffort.none],
                defaultReasoningEffort: AgentReasoningEffort.none,
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();
        expect(button, findsNothing);
        expect(
          app.agent.runtime.state.value.runFor(id).phase,
          AgentUiPhase.idle,
        );
        expect(app.agent.conversations.selected!.messages, isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
        await app.agent.quiesce();
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(platform),
    );
  }
}
