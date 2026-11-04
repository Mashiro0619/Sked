import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sked/agent/agent_application.dart';
import 'package:sked/agent/attachments/attachment_repository.dart';
import 'package:sked/agent/attachments/conversation_attachments.dart';
import 'package:sked/agent/connection/agent_credential_store.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/history/conversation_history_service.dart';
import 'package:sked/agent/knowledge/knowledge_service.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/runtime/agent_runtime_controller.dart';
import 'package:sked/agent/tools/application_tool_host.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/controllers/settings_view_state.dart';
import 'package:sked/controllers/workspace_view_state.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/agent_settings.dart';
import 'package:sked/models/app_mode.dart';
import 'package:sked/screens/adaptive_sked_shell.dart';
import 'package:sked/screens/agent_connection_settings_page.dart';
import 'package:sked/screens/agent_model_settings_page.dart';
import 'package:sked/screens/agent_page.dart';
import 'package:sked/screens/agent_preferences_settings_page.dart';
import 'package:sked/screens/agent_settings_page.dart';
import 'package:sked/screens/settings_page.dart';
import 'package:sked/screens/workspace_features_page.dart';
import 'package:sked/widgets/assistant_pane.dart';
import 'package:sked/widgets/workspace_frame.dart';
import 'package:sked/widgets/workspace_navigation.dart';

import '../agent/ui/agent_ui_test_support.dart';
import '../support/workspace_harness.dart';
import '../support/agent_workspace_navigation.dart';

Finder _key(String value) => find.byKey(ValueKey(value));

class _Provider extends ProviderClient {
  final requests = <ProviderRequest>[];
  final cancellations = <ProviderCancellationToken?>[];
  final streams = <StreamController<ProviderEvent>>[];

  @override
  Stream<ProviderEvent> stream(
    ProviderRequest request, {
    required String apiKey,
    ProviderCancellationToken? cancellation,
  }) {
    expect(apiKey, 'fixture-key');
    requests.add(request);
    cancellations.add(cancellation);
    final events = StreamController<ProviderEvent>();
    streams.add(events);
    return events.stream;
  }

  Future<void> finish(int index) async {
    streams[index].add(
      ProviderCompleted(
        ProviderResponse(
          text: 'Fixture response',
          toolCalls: const [],
          finishReason: 'stop',
        ),
      ),
    );
    await streams[index].close();
  }
}

/// Navigation fixtures do not execute tools or observe notification scheduling.
class _ReadOnlyToolHost extends ChangeNotifier implements ApplicationToolHost {
  @override
  Listenable get notificationEffectChanges => this;

  @override
  Map<String, Object?> describeCommitResult(Map<String, Object?> result) => {
    ...result,
    'notificationEffect': const {'state': 'unknown', 'deliveryObserved': false},
  };

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// These navigation fixtures never invoke history mutations. The application
/// history suite exercises those commands with the actual storage owners.
class _NavigationHistory implements ConversationHistoryService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Navigation fixtures cannot execute history commands.');
}

/// Only application composition and storage are substituted. User messages,
/// run state, mode changes and cancellation use the real runtime controller.
class _Application extends ChangeNotifier implements AgentApplication {
  _Application();
  final storage = UiMemoryStorage();
  final provider = _Provider();
  @override
  final ApplicationToolHost tools = _ReadOnlyToolHost();
  @override
  final ConversationHistoryService history = _NavigationHistory();
  @override
  final attachmentStore = AttachmentRepository(
    storage: MemoryAttachmentStorage(),
  );
  @override
  late final binaryAttachments = ConversationAttachments(
    conversations: conversations,
    repository: attachmentStore,
  );
  @override
  final knowledgeRepository = AgentKnowledgeRepository(
    storage: MemoryKnowledgeStorage(),
  );
  @override
  late final knowledge = AgentKnowledgeService(repository: knowledgeRepository);
  @override
  late final ConversationRepository conversations;
  @override
  late final AgentRuntimeController runtime;
  @override
  AgentSettings settings = const AgentSettings(
    enabled: true,
    endpoint: 'https://fixture.example/v1',
    model: 'fixture-model',
    models: [
      AgentModelConfig(
        id: 'fixture-model',
        reasoningEfforts: [AgentReasoningEffort.medium],
        defaultReasoningEffort: AgentReasoningEffort.medium,
      ),
    ],
  );
  @override
  bool isInitialized = true;
  @override
  bool initializationError = false;
  @override
  int navigationRevision = 0;
  AgentCredentialAction? credentialAction;
  String? suppliedKey;
  Future<void> Function()? beforeConfigure;
  final enabledChanges = <bool>[];

  static Future<_Application> create() async {
    final app = _Application();
    var sequence = 0;
    app.conversations = ConversationRepository(
      storage: app.storage,
      idGenerator: () => 'conversation-${sequence++}',
    );
    await app.conversations.load();
    await app.conversations.create(title: 'First conversation');
    app.runtime = AgentRuntimeController(
      repository: app.conversations,
      provider: app.provider,
      attachments: app.attachmentStore,
      onAttachmentProgress: app.binaryAttachments.transferProgress,
      readSettings: () => app.settings,
      readApiKey: (_) async => 'fixture-key',
      readTools: (_) => const [],
      executeTool: (_, _, _) => throw StateError('No tools in this fixture'),
      onOpenSettings: () => throw StateError('Host must route settings'),
    );
    return app;
  }

  @override
  Future<void> initialize() async {
    isInitialized = true;
    initializationError = false;
    notifyListeners();
  }

  @override
  void requestShowConversation() {
    navigationRevision++;
    notifyListeners();
  }

  @override
  Future<void> setEnabled(bool value) async {
    enabledChanges.add(value);
    settings = settings.copyWith(enabled: value);
    if (!value) runtime.cancelAll();
    runtime.refreshSettings();
    notifyListeners();
  }

  @override
  Future<void> configure(
    AgentSettings value, {
    AgentCredentialAction credentialAction = AgentCredentialAction.keep,
    String? rawKey,
    AgentSettings? expectedSettings,
  }) async {
    await beforeConfigure?.call();
    settings = value;
    this.credentialAction = credentialAction;
    suppliedKey = rawKey;
    runtime.refreshSettings();
    notifyListeners();
  }

  @override
  Future<void> configurePreferences(
    AgentSettings value, {
    AgentSettings? expectedSettings,
  }) async {
    await beforeConfigure?.call();
    settings = settings.copyWith(
      systemInstructions: value.systemInstructions,
      maxModelRounds: value.maxModelRounds,
      maxToolCalls: value.maxToolCalls,
      maxTotalTokens: value.maxTotalTokens,
      historyRetentionDays: value.historyRetentionDays,
    );
    runtime.refreshSettings();
    notifyListeners();
  }

  @override
  void dispose() {
    runtime.dispose();
    tools.dispose();
    unawaited(binaryAttachments.close());
    binaryAttachments.dispose();
    knowledge.dispose();
    knowledgeRepository.dispose();
    provider.close();
    conversations.dispose();
    super.dispose();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  for (var attempt = 0; attempt < 100 && !ready(); attempt++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
  expect(ready(), isTrue);
}

Future<void> _settleSettingsUi(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pumpAndSettle();
}

Future<void> _revealSettingsUi(WidgetTester tester, Finder target) async {
  // Let caret scrolling and real route futures finish before locating an action.
  await _settleSettingsUi(tester);
  await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
  await _settleSettingsUi(tester);
  if (target.hitTestable().evaluate().isEmpty) {
    final scroll = find
        .ancestor(of: target, matching: find.byType(Scrollable))
        .first;
    final direction = tester.getCenter(target).dy < tester.getRect(scroll).top
        ? 180.0
        : -180.0;
    await tester.dragUntilVisible(
      target.hitTestable(),
      scroll,
      Offset(0, direction),
      maxIteration: 24,
    );
    await _settleSettingsUi(tester);
  }
}

Future<void> _tapSettingsUi(WidgetTester tester, Finder target) async {
  await _revealSettingsUi(tester, target);
  expect(target.hitTestable(), findsOneWidget);
  await tester.runAsync(() => tester.tap(target.hitTestable()));
  await _settleSettingsUi(tester);
}

Future<void> _backSettingsUi(WidgetTester tester) async {
  await tester.runAsync(tester.binding.handlePopRoute);
  await _settleSettingsUi(tester);
}

Future<WorkspacePaneController> _mountFrame(
  WidgetTester tester,
  _Application application, {
  required Size size,
  double scale = 1,
}) async {
  final app = await workspaceProvider();
  addTearDown(app.dispose);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  await tester.pumpWidget(
    WorkspaceHarness(
      provider: app,
      agentApplication: application,
      textScale: scale,
    ),
  );
  await tester.pumpAndSettle();
  return tester.widget<WorkspaceFrame>(find.byType(WorkspaceFrame)).controller;
}

void main() {
  setUp(() {
    // Asset futures must belong to this test's async zone.
    rootBundle.clear();
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'connection model and run preference pages retain independent drafts',
    (tester) async {
      final application = (await tester.runAsync(_Application.create))!;
      addTearDown(application.dispose);
      addTearDown(tester.view.reset);
      await mountAgentUi(
        tester,
        ChangeNotifierProvider<AgentApplication>.value(
          value: application,
          child: const AgentSettingsPage(),
        ),
      );
      expect(find.byType(TabBar), findsNothing);
      await _tapSettingsUi(tester, _key('agent-settings-connection'));
      final parent = tester.state(find.byType(AgentConnectionSettingsPage));
      await tester.enterText(
        _key('agent-endpoint'),
        'https://draft.example/v1',
      );
      await _tapSettingsUi(
        tester,
        _key('agent-configured-model-fixture-model'),
      );
      expect(find.byType(AgentModelSettingsPage), findsOneWidget);
      await _tapSettingsUi(tester, _key('agent-model-effort-high'));
      await _tapSettingsUi(tester, _key('agent-save-model'));
      expect(find.byType(AgentModelSettingsPage), findsNothing);
      expect(
        tester.state(find.byType(AgentConnectionSettingsPage)),
        same(parent),
      );
      expect(
        application.settings.modelConfig('fixture-model')!.reasoningEfforts,
        [AgentReasoningEffort.medium, AgentReasoningEffort.high],
      );
      expect(application.settings.endpoint, 'https://fixture.example/v1');
      expect(application.settings.systemInstructions, isEmpty);
      expect(
        tester.widget<TextFormField>(_key('agent-endpoint')).controller!.text,
        'https://draft.example/v1',
      );
      await _tapSettingsUi(tester, _key('agent-save-connection'));
      expect(find.byType(AgentConnectionSettingsPage), findsNothing);
      expect(_key('agent-settings-preferences').hitTestable(), findsOneWidget);
      await _tapSettingsUi(tester, _key('agent-settings-preferences'));
      await tester.enterText(
        _key('agent-system-instructions'),
        'Keep this unsaved preference',
      );
      expect(application.settings.systemInstructions, isEmpty);
      await _backSettingsUi(tester);
      final l = AppLocalizations.of(tester.element(find.byType(AlertDialog)));
      await _tapSettingsUi(tester, find.widgetWithText(TextButton, l.cancel));
      expect(find.byType(AgentPreferencesSettingsPage), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(_key('agent-system-instructions'))
            .controller!
            .text,
        'Keep this unsaved preference',
      );
      expect(application.settings.endpoint, 'https://draft.example/v1');
      await _tapSettingsUi(tester, _key('agent-save-preferences'));
      expect(find.byType(AgentPreferencesSettingsPage), findsNothing);
      expect(_key('agent-settings-connection').hitTestable(), findsOneWidget);
      expect(
        application.settings.systemInstructions,
        'Keep this unsaved preference',
      );
      expect(application.settings.endpoint, 'https://draft.example/v1');
      expect(
        application.settings.modelConfig('fixture-model')!.reasoningEfforts,
        [AgentReasoningEffort.medium, AgentReasoningEffort.high],
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'follow-up remains available while the original send awaits its model run',
    (tester) async {
      final application = await _Application.create();
      final assistant = AssistantPaneController();
      final workspace = WorkspacePaneController();
      addTearDown(application.dispose);
      addTearDown(assistant.dispose);
      addTearDown(workspace.dispose);
      addTearDown(tester.view.reset);
      await _mountFrame(tester, application, size: const Size(1280, 1000));
      await selectAgentShellDestination(tester, 'agent');
      await tester.pumpAndSettle();
      await tester.enterText(_key('agent-composer'), 'First request');
      await tester.pump();
      await tester.tap(_key('agent-send'));
      await _until(tester, () => application.provider.requests.length == 1);
      await tester.enterText(_key('agent-composer'), 'Second request');
      await tester.pump();
      await tester.ensureVisible(_key('agent-queue'));
      expect(
        tester.widget<FilledButton>(_key('agent-queue')).onPressed,
        isNotNull,
      );
      await tester.tap(_key('agent-queue'));
      await _until(
        tester,
        () =>
            application.runtime.pendingInputCount(
              application.conversations.selectedId!,
            ) ==
            1,
      );
      await application.provider.finish(0);
      await _until(tester, () => application.provider.requests.length == 2);
      await application.provider.finish(1);
      await _until(
        tester,
        () => !application.runtime.state.value
            .runFor(application.conversations.selectedId!)
            .isActive,
      );
      expect(
        application.conversations.selected!.messages
            .where((message) => message.role == ConversationRole.user)
            .map((message) => message.text),
        ['First request', 'Second request'],
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'full Agent workspace keeps retained calendar tasks covered and unfocused',
    (tester) async {
      final application = await _Application.create();
      final assistant = AssistantPaneController();
      final workspace = WorkspacePaneController();
      addTearDown(application.dispose);
      addTearDown(assistant.dispose);
      addTearDown(workspace.dispose);
      addTearDown(tester.view.reset);
      final retainedWorkspace = await _mountFrame(
        tester,
        application,
        size: const Size(720, 1000),
        scale: 2,
      );
      await selectAgentShellDestination(tester, 'agent');
      await tester.pumpAndSettle();
      await tester.ensureVisible(_key('agent-composer'));
      await tester.tap(_key('agent-composer'));
      await tester.pump();
      final focus = tester.widget<TextField>(_key('agent-composer')).focusNode!;
      expect(focus.hasFocus, isTrue);
      unawaited(
        retainedWorkspace.show<void>(
          (_) => const Center(child: Text('Foreground task')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Foreground task'), findsNothing);
      expect(_key('agent-composer').hitTestable(), findsOneWidget);
      expect(focus.hasFocus, isTrue);
      await retainedWorkspace.close();
      await tester.pumpAndSettle();
      expect(_key('agent-composer'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  for (final desktop in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        '${desktop ? 'desktop' : 'phone'} full Agent workspace sends, switches conversations and keeps a running draft at ${scale}x',
        (tester) async {
          final application = await _Application.create();
          final assistant = AssistantPaneController();
          final workspace = WorkspacePaneController();
          addTearDown(application.dispose);
          addTearDown(assistant.dispose);
          addTearDown(workspace.dispose);
          addTearDown(tester.view.reset);
          await _mountFrame(
            tester,
            application,
            size: desktop ? const Size(1440, 1000) : const Size(390, 844),
            scale: scale,
          );
          await selectAgentShellDestination(tester, 'agent');
          await tester.pumpAndSettle();
          expect(find.byType(AgentPage), findsOneWidget);
          expect(find.byType(AssistantPreviewPane), findsNothing);
          expect(find.text('First conversation'), findsWidgets);
          final first = application.conversations.selectedId!;
          await tester.ensureVisible(_key('agent-composer'));
          await tester.enterText(_key('agent-composer'), 'Read my schedule');
          await tester.pump();
          await tester.ensureVisible(_key('agent-send'));
          await tester.tap(_key('agent-send'));
          await _until(tester, () => application.provider.requests.isNotEmpty);
          expect(
            application.conversations.find(first)!.messages.single.text,
            'Read my schedule',
          );
          await tester.ensureVisible(_key('agent-mode-picker'));
          await tester.tap(_key('agent-mode-picker'));
          await tester.pumpAndSettle();
          await tester.ensureVisible(_key('agent-mode-full'));
          await tester.tap(_key('agent-mode-full'));
          await tester.pumpAndSettle();
          expect(
            application.conversations.find(first)!.mode,
            AgentPermissionMode.full,
          );
          await tester.ensureVisible(_key('agent-mode-picker'));
          await tester.tap(_key('agent-mode-picker'));
          await tester.pumpAndSettle();
          await tester.ensureVisible(_key('agent-mode-plan'));
          await tester.tap(_key('agent-mode-plan'));
          await tester.pumpAndSettle();
          expect(
            application.conversations.find(first)!.mode,
            AgentPermissionMode.plan,
          );
          await tester.ensureVisible(_key('agent-new'));
          await tester.tap(_key('agent-new'));
          await tester.pumpAndSettle();
          final second = application.conversations.selectedId!;
          expect(second, isNot(first));
          await tester.ensureVisible(_key('agent-composer'));
          await tester.enterText(_key('agent-composer'), 'Second draft');
          await openAgentShellHistory(tester);
          await tester.ensureVisible(_key('agent-history-$first'));
          await tester.tap(_key('agent-history-$first'));
          await tester.pumpAndSettle();
          await tester.ensureVisible(_key('agent-composer'));
          await tester.enterText(_key('agent-composer'), 'Next question');
          await selectAgentShellDestination(tester, 'student');
          await tester.pumpAndSettle();
          expect(
            application.runtime.state.value.runFor(first).isActive,
            isTrue,
          );
          expect(
            application.provider.cancellations.single!.isCancelled,
            isFalse,
          );
          expect(assistant.isOpen, isFalse);
          if (desktop) {
            tester.view.physicalSize = const Size(800, 1000);
            await tester.pumpAndSettle();
          }
          await selectAgentShellDestination(tester, 'agent');
          await tester.pumpAndSettle();
          expect(
            tester.widget<TextField>(_key('agent-composer')).controller!.text,
            'Next question',
          );
          expect(application.conversations.find(second)!.draft, 'Second draft');
          await application.provider.finish(0);
          await _until(
            tester,
            () => !application.runtime.state.value.runFor(first).isActive,
          );
          expect(
            application.conversations.find(first)!.messages.last.text,
            'Fixture response',
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
        variant: TargetPlatformVariant.only(
          desktop ? TargetPlatform.windows : TargetPlatform.android,
        ),
      );
    }
  }

  for (final desktop in [false, true]) {
    testWidgets(
      'application-owned Agent enables and runs in the ${desktop ? 'desktop' : 'phone'} full workspace',
      (tester) async {
        final storage = UiMemoryStorage();
        final provider = _Provider();
        final app = await workspaceProvider(
          agentConversationStorage: storage,
          agentCredentialStore: MemoryAgentCredentialStore(),
          agentProvider: provider,
        );
        addTearDown(app.dispose);
        addTearDown(tester.view.reset);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = desktop
            ? const Size(1440, 1000)
            : const Size(390, 844);
        await app.agent.configure(
          const AgentSettings(
            enabled: false,
            endpoint: 'https://fixture.example/v1',
            model: 'fixture-model',
            models: [
              AgentModelConfig(
                id: 'fixture-model',
                reasoningEfforts: [AgentReasoningEffort.medium],
                defaultReasoningEffort: AgentReasoningEffort.medium,
              ),
            ],
          ),
          credentialAction: AgentCredentialAction.replace,
          rawKey: 'fixture-key',
        );
        await app.agent.setEnabled(false);
        expect(app.agent.settings.enabled, isFalse);
        final workspaces = app.workspaceView.enabledWorkspaces;
        await tester.pumpWidget(
          WorkspaceHarness(provider: app, home: const WorkspaceFeaturesPage()),
        );
        await tester.pumpAndSettle();
        await tester.tap(_key('agent-enabled'));
        await _until(tester, () => app.agent.settings.enabled);
        expect(app.workspaceView.enabledWorkspaces, workspaces);
        expect(provider.requests, isEmpty);
        expect(app.agent.knowledge.isLoaded, isFalse);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(WorkspaceHarness(provider: app));
        await tester.pumpAndSettle();
        expect(find.byType(AgentAssistantPane), findsNothing);
        final entry = _key('workspace-agent-entry');
        if (!desktop) expect(entry, findsNothing);
        if (entry.evaluate().isEmpty) {
          await tester.tap(_key('workspace-main-navigation'));
          await tester.pumpAndSettle();
        }
        expect(entry, findsOneWidget);
        await tester.tap(entry);
        await tester.pumpAndSettle();
        expect(find.byType(AssistantPreviewPane), findsNothing);
        expect(find.byType(AgentPage), findsOneWidget);
        expect(find.byType(AgentAssistantPane), findsNothing);
        await tester.tap(_key('agent-new'));
        await tester.pumpAndSettle();
        final conversation = app.agent.conversations.selectedId!;
        await tester.tap(_key('agent-mode-picker'));
        await tester.pumpAndSettle();
        for (final mode in AgentPermissionMode.values) {
          expect(_key('agent-mode-${mode.name}'), findsOneWidget);
        }
        await tester.tap(_key('agent-mode-plan'));
        await tester.pumpAndSettle();
        await tester.enterText(_key('agent-composer'), 'Read my calendar');
        await tester.pump();
        await tester.tap(_key('agent-send'));
        await _until(tester, () => provider.requests.isNotEmpty);
        expect(
          app.agent.conversations.find(conversation)!.mode,
          AgentPermissionMode.plan,
        );
        expect(
          app.agent.conversations.find(conversation)!.messages.single.text,
          'Read my calendar',
        );
        await tester.enterText(_key('agent-composer'), 'Keep this draft');
        await selectAgentShellDestination(
          tester,
          app.workspaceView.activeMode.value,
        );
        await tester.pumpAndSettle();
        if (desktop) tester.view.physicalSize = const Size(720, 1000);
        unawaited(
          AgentPage.openConversation(
            tester.element(find.byType(AdaptiveSkedShell)),
          ),
        );
        await tester.pumpAndSettle();
        expect(app.agent.conversations.selectedId, conversation);
        expect(
          tester.widget<TextField>(_key('agent-composer')).controller!.text,
          'Keep this draft',
        );
        expect(provider.cancellations.single!.isCancelled, isFalse);
        await provider.finish(0);
        await _until(
          tester,
          () => !app.agent.runtime.state.value.runFor(conversation).isActive,
        );
        expect(
          app.agent.conversations.find(conversation)!.messages.last.text,
          'Fixture response',
        );
        expect(storage.source, isNot(contains('fixture-key')));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        // Drain while the widget test's async zone is still being pumped.
        // A tearDown registered outside that zone cannot advance its Futures.
        await app.agent.quiesce();
      },
      variant: TargetPlatformVariant.only(
        desktop ? TargetPlatform.windows : TargetPlatform.android,
      ),
    );
  }

  testWidgets(
    'desktop full workspace preserves one running conversation across reopen',
    (tester) async {
      final application = await _Application.create();
      final assistant = AssistantPaneController();
      final workspace = WorkspacePaneController();
      addTearDown(application.dispose);
      addTearDown(assistant.dispose);
      addTearDown(workspace.dispose);
      addTearDown(tester.view.reset);
      await _mountFrame(tester, application, size: const Size(1440, 1000));
      await selectAgentShellDestination(tester, 'agent');
      await tester.pumpAndSettle();
      final id = application.conversations.selectedId!;
      await tester.enterText(_key('agent-composer'), 'Read my schedule');
      await tester.pump();
      await tester.tap(_key('agent-send'));
      await _until(tester, () => application.provider.requests.isNotEmpty);
      await tester.enterText(_key('agent-composer'), 'Keep this next question');
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(720, 1000);
      await tester.pumpAndSettle();
      expect(find.byType(AgentPage), findsOneWidget);
      expect(
        _key('workspace-resource-mode-student').hitTestable(),
        findsOneWidget,
      );
      expect(_key('agent-composer'), findsOneWidget);
      expect(application.conversations.selectedId, id);
      expect(application.provider.requests.length, 1);
      expect(application.provider.cancellations.single!.isCancelled, isFalse);
      expect(
        tester.widget<TextField>(_key('agent-composer')).controller!.text,
        'Keep this next question',
      );
      await tester.enterText(_key('agent-composer'), 'Edited in full chat');
      await selectAgentShellDestination(tester, 'student');
      await tester.pumpAndSettle();
      expect(find.byType(AgentPage), findsNothing);
      expect(find.byType(AgentAssistantPane), findsNothing);
      expect(assistant.isOpen, isFalse);
      await selectAgentShellDestination(tester, 'agent');
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(_key('agent-composer')).controller!.text,
        'Edited in full chat',
      );
      expect(application.runtime.state.value.runFor(id).isActive, isTrue);
      await application.provider.finish(0);
      await _until(
        tester,
        () => !application.runtime.state.value.runFor(id).isActive,
      );
      expect(
        application.conversations.find(id)!.messages.last.text,
        'Fixture response',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'disabling hides desktop entry and enabling preserves closed state and draft',
    (tester) async {
      final application = await _Application.create();
      final assistant = AssistantPaneController();
      final workspace = WorkspacePaneController();
      addTearDown(application.dispose);
      addTearDown(assistant.dispose);
      addTearDown(workspace.dispose);
      addTearDown(tester.view.reset);
      await _mountFrame(tester, application, size: const Size(1440, 900));
      await selectAgentShellDestination(tester, 'agent');
      await tester.pumpAndSettle();
      await tester.enterText(_key('agent-composer'), 'Preserved draft');
      await application.setEnabled(false);
      await tester.pumpAndSettle();
      expect(_key('workspace-agent-entry'), findsNothing);
      expect(find.byType(AgentAssistantPane), findsNothing);
      expect(assistant.isOpen, isFalse);
      await application.setEnabled(true);
      await tester.pumpAndSettle();
      expect(_key('workspace-agent-entry'), findsOneWidget);
      expect(assistant.isOpen, isFalse);
      await tester.tap(_key('workspace-agent-entry'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(_key('agent-composer')).controller!.text,
        'Preserved draft',
      );
      await selectAgentShellDestination(tester, 'student');
      await tester.pumpAndSettle();
      expect(assistant.isOpen, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'nested model and connection routes pass credentials only on connection save at 2x',
    (tester) async {
      final application = (await tester.runAsync(_Application.create))!;
      addTearDown(application.dispose);
      addTearDown(tester.view.reset);
      await mountAgentUi(
        tester,
        ChangeNotifierProvider<AgentApplication>.value(
          value: application,
          child: const AgentPage(),
        ),
        size: const Size(390, 844),
        scale: 2,
      );
      await _tapSettingsUi(tester, _key('agent-conversation-menu'));
      await _tapSettingsUi(tester, _key('agent-settings'));
      expect(find.byType(AgentSettingsPage), findsOneWidget);
      await _tapSettingsUi(tester, _key('agent-settings-connection'));
      final parent = tester.state(find.byType(AgentConnectionSettingsPage));
      await _revealSettingsUi(tester, _key('agent-api-key'));
      await tester.enterText(_key('agent-api-key'), 'transient-fixture-key');
      await _tapSettingsUi(tester, _key('agent-add-model'));
      expect(find.byType(AgentModelSettingsPage), findsOneWidget);
      await _revealSettingsUi(tester, _key('agent-model'));
      await tester.enterText(_key('agent-model'), 'changed-model');
      await _tapSettingsUi(tester, _key('agent-model-effort-medium'));
      await _tapSettingsUi(tester, _key('agent-default-effort-null'));
      final l = AppLocalizations.of(
        tester.element(find.byType(AgentModelSettingsPage)),
      );
      await _tapSettingsUi(
        tester,
        find.widgetWithText(MenuItemButton, l.agentEffortMedium),
      );
      await _tapSettingsUi(tester, _key('agent-save-model'));
      expect(find.byType(AgentModelSettingsPage), findsNothing);
      expect(
        tester.state(find.byType(AgentConnectionSettingsPage)),
        same(parent),
      );
      expect(application.settings.model, 'fixture-model');
      expect(
        application.settings.modelConfig('changed-model'),
        const AgentModelConfig(
          id: 'changed-model',
          reasoningEfforts: [AgentReasoningEffort.medium],
          defaultReasoningEffort: AgentReasoningEffort.medium,
        ),
      );
      expect(application.suppliedKey, isNull);
      expect(application.credentialAction, AgentCredentialAction.keep);
      expect(
        tester.widget<TextFormField>(_key('agent-api-key')).controller!.text,
        'transient-fixture-key',
      );
      expect(
        application.storage.source,
        isNot(contains('transient-fixture-key')),
      );
      await _tapSettingsUi(tester, _key('agent-save-connection'));
      expect(application.suppliedKey, 'transient-fixture-key');
      expect(application.credentialAction, AgentCredentialAction.replace);
      expect(
        application.storage.source,
        isNot(contains('transient-fixture-key')),
      );
      expect(find.byType(AgentConnectionSettingsPage), findsNothing);
      expect(find.byType(AgentSettingsPage), findsOneWidget);
      expect(_key('agent-settings-connection').hitTestable(), findsOneWidget);
      expect(find.byType(AgentPage, skipOffstage: false), findsOneWidget);
      await _backSettingsUi(tester);
      expect(find.byType(AgentSettingsPage), findsNothing);
      expect(find.byType(AgentPage), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'feature management has one Agent switch independent of workspaces',
    (tester) async {
      final application = await _Application.create();
      final app = await workspaceProvider();
      addTearDown(application.dispose);
      addTearDown(app.dispose);
      addTearDown(tester.view.reset);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpWidget(
        WorkspaceHarness(
          provider: app,
          textScale: 2,
          home: ChangeNotifierProvider<AgentApplication>.value(
            value: application,
            child: const WorkspaceFeaturesPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_key('agent-enabled'), findsOneWidget);
      await tester.ensureVisible(_key('agent-enabled'));
      await tester.tap(_key('agent-enabled'));
      await tester.pumpAndSettle();
      expect(application.enabledChanges, [false]);
      expect(app.workspaceView.enabledWorkspaces, {
        AppMode.student,
        AppMode.general,
      });
      await tester.tap(_key('agent-enabled'));
      await tester.pumpAndSettle();
      expect(application.enabledChanges, [false, true]);
      expect(_key('agent-model-settings-entry'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        WorkspaceHarness(
          provider: app,
          textScale: 2,
          home: ChangeNotifierProvider<AgentApplication>.value(
            value: application,
            child: const SettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(_key('settings-agent'));
      await tester.pumpAndSettle();
      await tester.tap(_key('settings-agent'));
      await tester.pumpAndSettle();
      expect(find.byType(AgentSettingsPage), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'connection save keeps its own route until persistence completes',
    (tester) async {
      final application = (await tester.runAsync(_Application.create))!;
      final saving = (await tester.runAsync(() async => Completer<void>()))!;
      final entered = (await tester.runAsync(() async => Completer<void>()))!;
      application.beforeConfigure = () {
        entered.complete();
        return saving.future;
      };
      addTearDown(application.dispose);
      addTearDown(tester.view.reset);
      addTearDown(() {
        if (!saving.isCompleted) saving.complete();
      });
      await mountAgentUi(
        tester,
        ChangeNotifierProvider<AgentApplication>.value(
          value: application,
          child: const AgentPage(),
        ),
      );
      await _tapSettingsUi(tester, _key('agent-conversation-menu'));
      await _tapSettingsUi(tester, _key('agent-settings'));
      await _tapSettingsUi(tester, _key('agent-settings-connection'));
      final source = ModalRoute.of(
        tester.element(find.byType(AgentConnectionSettingsPage)),
      )!;
      await tester.enterText(
        _key('agent-endpoint'),
        'https://saved.example/v1',
      );
      await _revealSettingsUi(tester, _key('agent-save-connection'));
      await tester.runAsync(() async {
        await tester.tap(_key('agent-save-connection').hitTestable());
        await entered.future.timeout(const Duration(seconds: 10));
      });
      await tester.pump();
      expect(application.settings.endpoint, 'https://fixture.example/v1');
      expect(
        tester.widget<FilledButton>(_key('agent-save-connection')).onPressed,
        isNull,
      );
      await _backSettingsUi(tester);
      expect(find.byType(AgentConnectionSettingsPage), findsOneWidget);
      expect(source.isCurrent, isTrue);
      expect(find.byType(AlertDialog), findsNothing);
      await _tapSettingsUi(
        tester,
        find.descendant(
          of: find.byType(AgentConnectionSettingsPage),
          matching: find.byType(BackButton),
        ),
      );
      expect(find.byType(AgentConnectionSettingsPage), findsOneWidget);
      expect(source.isCurrent, isTrue);
      expect(
        find.byType(AgentSettingsPage, skipOffstage: false),
        findsOneWidget,
      );
      await tester.runAsync(() async {
        saving.complete();
        await Future<void>.delayed(Duration.zero);
      });
      await _settleSettingsUi(tester);
      expect(application.settings.endpoint, 'https://saved.example/v1');
      expect(find.byType(AgentConnectionSettingsPage), findsNothing);
      expect(source.isActive, isFalse);
      expect(find.byType(AgentSettingsPage), findsOneWidget);
      expect(_key('agent-settings-connection').hitTestable(), findsOneWidget);
      expect(find.byType(AgentPage, skipOffstage: false), findsOneWidget);
      await _backSettingsUi(tester);
      expect(find.byType(AgentSettingsPage), findsNothing);
      expect(find.byType(AgentPage), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'desktop schedule and timetable reopen the same running full workspace',
    (tester) async {
      final application = await _Application.create();
      final app = await workspaceProvider(mode: AppMode.general);
      addTearDown(application.dispose);
      addTearDown(app.dispose);
      addTearDown(tester.view.reset);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 1000);
      await tester.pumpWidget(
        WorkspaceHarness(
          provider: app,
          home: ChangeNotifierProvider<AgentApplication>.value(
            value: application,
            child: Consumer2<WorkspaceViewState, SettingsViewState>(
              builder: (_, workspace, settings, _) => AdaptiveSkedShell(
                workspace: workspace,
                workspaces: app.workspaces,
                settings: settings,
                settingsCommands: app.settingsCommands,
                activeMode: workspace.activeMode,
                onOpenSettings: () async {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      unawaited(
        AgentPage.openConversation(
          tester.element(find.byType(AdaptiveSkedShell)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(_key('agent-composer'), 'Read across workspaces');
      await tester.pump();
      await tester.tap(_key('agent-send'));
      await _until(tester, () => application.provider.requests.isNotEmpty);
      final id = application.conversations.selectedId!;
      await tester.enterText(_key('agent-composer'), 'Shared next question');
      await selectAgentShellDestination(tester, 'student');
      await tester.pumpAndSettle();
      expect(app.workspaceView.activeMode, AppMode.student);
      expect(find.byType(AgentAssistantPane), findsNothing);
      await application.configure(application.settings);
      await tester.pumpAndSettle();
      expect(find.byType(AgentAssistantPane), findsNothing);
      await tester.tap(_key('workspace-agent-entry'));
      await tester.pumpAndSettle();
      expect(find.byType(AgentPage), findsOneWidget);
      expect(application.conversations.selectedId, id);
      expect(
        tester.widget<TextField>(_key('agent-composer')).controller!.text,
        'Shared next question',
      );
      expect(application.runtime.state.value.runFor(id).isActive, isTrue);
      expect(application.provider.cancellations.single!.isCancelled, isFalse);
      await application.provider.finish(0);
      await _until(
        tester,
        () => !application.runtime.state.value.runFor(id).isActive,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  for (final mode in AppMode.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'single ${mode.name} workspace retains Agent drawer entry at ${scale}x with hidden bottom navigation',
        (tester) async {
          final application = await _Application.create();
          final app = await workspaceProvider(mode: mode);
          addTearDown(application.dispose);
          addTearDown(app.dispose);
          addTearDown(tester.view.reset);
          await app.settingsCommands.updateHideHomeWorkspaceNavigation(true);
          await app.workspaces.setEnabled(
            mode == AppMode.student ? AppMode.general : AppMode.student,
            false,
          );
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(390, 844);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await tester.pumpWidget(
            WorkspaceHarness(
              provider: app,
              home: ChangeNotifierProvider<AgentApplication>.value(
                value: application,
                child: Consumer2<WorkspaceViewState, SettingsViewState>(
                  builder: (_, workspace, settings, _) => AdaptiveSkedShell(
                    workspace: workspace,
                    workspaces: app.workspaces,
                    settings: settings,
                    settingsCommands: app.settingsCommands,
                    activeMode: workspace.activeMode,
                    onOpenSettings: () async {},
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(NavigationBar), findsNothing);
          expect(_key('assistant-toggle'), findsNothing);
          expect(_key('workspace-main-navigation'), findsOneWidget);
          final navigation = WorkspaceNavigationScope.maybeOf(
            tester.element(_key('workspace-main-navigation')),
          )!;
          final entry = _key('workspace-agent-entry');
          if (entry.evaluate().isEmpty) {
            await tester.tap(_key('workspace-main-navigation'));
            await tester.pumpAndSettle();
          }
          await tester.ensureVisible(entry);
          await tester.tap(entry);
          await tester.pumpAndSettle();
          navigation.onOpenAgent!();
          navigation.onOpenAgent!();
          await tester.pumpAndSettle();
          expect(find.byType(AgentPage), findsOneWidget);
          expect(find.byType(AgentPage, skipOffstage: false), findsOneWidget);
          expect(_key('workspace-resource-scrim'), findsNothing);
          expect(find.byType(AssistantPreviewPane), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
        variant: TargetPlatformVariant.only(TargetPlatform.android),
      );
    }
  }
}
