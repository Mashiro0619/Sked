import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/agent_application.dart';
import 'package:sked/agent/connection/agent_credential_store.dart';
import 'package:sked/agent/conversations/conversation_models.dart';
import 'package:sked/agent/conversations/conversation_storage.dart';
import 'package:sked/agent/ui/agent_conversation_view.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/agent_settings.dart';
import 'package:sked/screens/agent_page.dart';
import 'package:sked/screens/agent_settings_page.dart';

import '../../support/workspace_harness.dart';
import '../../support/agent_workspace_navigation.dart';

class _Storage extends ConversationStorage {
  _Storage() : super.base();
  int loads = 0;
  final started = Completer<void>();
  Completer<void>? gate;
  Object? failure;
  String? source;
  final saves = <String>[];

  @override
  Future<ConversationStorageLoad> load() async {
    loads++;
    if (!started.isCompleted) started.complete();
    await gate?.future;
    if (failure case final error?) throw error;
    return ConversationStorageLoad(source: source);
  }

  @override
  Future<void> save(String value, {required int revision}) async {
    saves.add(value);
    source = value;
  }
}

/// These presentation fixtures never initialize storage or execute requests.
class _FailureApplication extends ChangeNotifier implements AgentApplication {
  _FailureApplication(this.initializationFailure);

  @override
  final AgentInitializationFailure initializationFailure;
  @override
  bool get initializationError => true;
  @override
  bool get isInitialized => false;
  @override
  AgentSettings get settings => const AgentSettings();
  @override
  int navigationRevision = 0;
  @override
  void requestShowConversation() {
    navigationRevision++;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Finder _key(String value) => find.byKey(ValueKey(value));

String _storedChat() {
  final date = DateTime.utc(2026, 11, 3);
  return ConversationArchive(
    selectedId: 'stored-chat',
    conversations: [
      AgentConversation(
        id: 'stored-chat',
        title: 'Stored conversation',
        createdAt: date,
        updatedAt: date,
        draft: 'Stored draft',
        messages: [
          ConversationMessage(
            id: 'stored-message',
            role: ConversationRole.user,
            text: 'Stored message',
            createdAt: date,
          ),
        ],
      ),
    ],
  ).encode();
}

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  for (var attempt = 0; attempt < 100 && !ready(); attempt++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
  expect(ready(), isTrue);
}

bool _routeReady(WidgetTester tester, Finder page) {
  if (page.evaluate().isEmpty) return false;
  final route = ModalRoute.of(tester.element(page));
  return route?.isCurrent == true &&
      route?.animation?.status == AnimationStatus.completed;
}

void main() {
  late AppRuntime app;
  late _Storage storage;

  Future<void> create() async {
    storage = _Storage();
    app = await workspaceProvider(
      agentConversationStorage: storage,
      agentCredentialStore: MemoryAgentCredentialStore(),
    );
    addTearDown(app.dispose);
  }

  Future<void> finishLoading(WidgetTester tester) async {
    await tester.pumpAndSettle();
    expect(storage.started.isCompleted, isTrue);
    expect(app.agent.isInitialized, isTrue);
  }

  Future<void> mountEntry(WidgetTester tester) async {
    await tester.pumpWidget(WorkspaceHarness(provider: app));
    await tester.pumpAndSettle();
    await selectAgentShellDestination(tester, 'agent');
  }

  testWidgets('a retained hidden host loads only when first shown', (
    tester,
  ) async {
    await create();
    Future<void> mount(bool active) => tester.pumpWidget(
      WorkspaceHarness(
        provider: app,
        home: Scaffold(body: AgentConversationHost(active: active)),
      ),
    );
    await mount(false);
    await tester.pumpAndSettle();
    expect(app.agent.isInitialized, isFalse);
    expect(storage.loads, 0);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await mount(true);
    await finishLoading(tester);
    expect(storage.loads, 1);
    expect(find.byType(AgentConversationView), findsOneWidget);
    await mount(false);
    await mount(true);
    await tester.pumpAndSettle();
    expect(storage.loads, 1);
    await tester.pumpWidget(const SizedBox());
    await app.agent.quiesce();
  });

  testWidgets('opening Agent settings initializes without enabling requests', (
    tester,
  ) async {
    await create();
    await app.agent.setEnabled(false);
    expect(storage.loads, 0);
    await tester.pumpWidget(
      WorkspaceHarness(provider: app, home: const AgentSettingsPage()),
    );
    await finishLoading(tester);
    expect(storage.loads, 1);
    expect(app.agent.settings.enabled, isFalse);
    expect(app.agent.runtime.state.value.runs, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await app.agent.quiesce();
  });

  testWidgets(
    'loading embedded chat keeps settings and main navigation reachable',
    (tester) async {
      await create();
      final original = _storedChat();
      storage.source = original;
      final gate = Completer<void>();
      storage.gate = gate;
      addTearDown(() {
        if (!gate.isCompleted) gate.complete();
      });
      await mountEntry(tester);
      await _until(tester, () => storage.started.isCompleted);
      await _until(tester, () => _routeReady(tester, find.byType(AgentPage)));
      expect(_key('agent-initialization-header'), findsOneWidget);
      expect(_key('agent-initialization-back'), findsNothing);
      expect(_key('workspace-main-navigation').hitTestable(), findsOneWidget);
      expect(
        _key('agent-initialization-settings').hitTestable(),
        findsOneWidget,
      );
      expect(find.byType(AgentConversationView), findsNothing);

      await tester.tap(_key('agent-initialization-settings'));
      await _until(
        tester,
        () => _routeReady(tester, find.byType(AgentSettingsPage)),
      );
      expect(find.byType(AgentSettingsPage), findsOneWidget);
      expect(storage.loads, 1);
      expect(app.agent.runtime.state.value.runs, isEmpty);
      await tester.binding.handlePopRoute();
      await _until(
        tester,
        () =>
            find.byType(AgentSettingsPage).evaluate().isEmpty &&
            _key('workspace-main-navigation')
                .hitTestable()
                .evaluate()
                .isNotEmpty,
      );
      await selectAgentShellDestination(tester, 'student');
      await _until(tester, () => find.byType(AgentPage).evaluate().isEmpty);
      expect(find.byType(AgentPage), findsNothing);
      expect(find.byType(AgentPage, skipOffstage: false), findsOneWidget);
      expect(storage.source, original);
      expect(storage.saves, isEmpty);

      gate.complete();
      storage.gate = null;
      await tester.pumpAndSettle();
      expect(find.byType(AgentPage), findsNothing);
      expect(app.agent.isInitialized, isTrue);
      expect(
        app.agent.conversations.find('stored-chat')!.draft,
        'Stored draft',
      );
      expect(storage.source, original);
      expect(storage.saves, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed embedded chat switches content, opens settings and retries intact',
    (tester) async {
      await create();
      final original = _storedChat();
      const rawError = 'fixture-secret /private/chat-file failed';
      storage.source = original;
      storage.failure = const ConversationStorageException(rawError);
      await mountEntry(tester);
      await _until(tester, () => app.agent.initializationError);
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(tester.element(find.byType(AgentPage)));
      expect(find.text(l.agentInitializationFailed), findsOneWidget);
      expect(
        find.text(l.agentInitializationConversationStorage),
        findsOneWidget,
      );
      expect(find.textContaining(rawError), findsNothing);
      expect(_key('agent-initialization-back'), findsNothing);
      expect(_key('workspace-main-navigation').hitTestable(), findsOneWidget);
      expect(
        _key('agent-initialization-settings').hitTestable(),
        findsOneWidget,
      );
      expect(storage.saves, isEmpty);

      await tester.tap(_key('agent-initialization-settings'));
      await tester.pumpAndSettle();
      expect(find.byType(AgentSettingsPage), findsOneWidget);
      expect(app.agent.runtime.state.value.runs, isEmpty);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await selectAgentShellDestination(tester, 'student');
      await tester.pumpAndSettle();
      expect(find.byType(AgentPage), findsNothing);
      final failedLoads = storage.loads;
      await selectAgentShellDestination(tester, 'agent');
      await tester.pumpAndSettle();
      expect(storage.loads, failedLoads);
      expect(_key('agent-initialization-header'), findsOneWidget);

      storage.failure = null;
      await tester.tap(_key('agent-initialization-retry'));
      await tester.pumpAndSettle();
      expect(app.agent.isInitialized, isTrue);
      expect(_key('agent-initialization-header'), findsNothing);
      expect(find.byType(AgentConversationView), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
      final chat = app.agent.conversations.find('stored-chat')!;
      expect(chat.draft, 'Stored draft');
      expect(chat.messages.single.text, 'Stored message');
      expect(storage.source, original);
      expect(storage.saves, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  for (final failure in AgentInitializationFailure.values) {
    testWidgets(
      'short embedded chat shows safe ${failure.name} failure',
      (tester) async {
        await create();
        final application = _FailureApplication(failure);
        addTearDown(application.dispose);
        addTearDown(tester.view.reset);
        tester.view.devicePixelRatio = 1;
        // The embedded shell also budgets its three-destination bottom bar.
        // Keep a short content area while leaving room for the 48 dp header.
        tester.view.physicalSize = const Size(320, 320);
        await tester.pumpWidget(
          WorkspaceHarness(
            provider: app,
            agentApplication: application,
            textScale: 2,
          ),
        );
        await tester.pumpAndSettle();
        await selectAgentShellDestination(tester, 'agent');
        await tester.pumpAndSettle();
        final l = AppLocalizations.of(tester.element(find.byType(AgentPage)));
        final reason = switch (failure) {
          AgentInitializationFailure.applicationStorage =>
            l.agentInitializationApplicationStorage,
          AgentInitializationFailure.conversationStorage =>
            l.agentInitializationConversationStorage,
          AgentInitializationFailure.connectionStorage =>
            l.agentInitializationConnectionStorage,
        };
        expect(find.text(reason), findsOneWidget);
        expect(_key('agent-initialization-back'), findsNothing);
        expect(_key('workspace-main-navigation').hitTestable(), findsOneWidget);
        expect(
          _key('agent-initialization-settings').hitTestable(),
          findsOneWidget,
        );
        for (final key in [
          'workspace-main-navigation',
          'agent-initialization-settings',
        ]) {
          final size = tester.getSize(_key(key));
          final desktopNavigation =
              key == 'workspace-main-navigation' &&
              Theme.of(tester.element(_key(key))).platform ==
                  TargetPlatform.windows;
          final minimumTarget = desktopNavigation ? 32.0 : 48.0;
          expect(size.width, greaterThanOrEqualTo(minimumTarget));
          expect(size.height, greaterThanOrEqualTo(minimumTarget));
        }
        final retry = _key('agent-initialization-retry');
        await tester.ensureVisible(retry);
        await tester.pumpAndSettle();
        expect(retry.hitTestable(), findsOneWidget);
        final viewport = tester.getRect(_key('agent-initialization-scroll'));
        final rect = tester.getRect(retry);
        expect(viewport.height, greaterThanOrEqualTo(rect.height));
        expect(rect.top, greaterThanOrEqualTo(viewport.top));
        expect(rect.bottom, lessThanOrEqualTo(viewport.bottom));
        expect(tester.takeException(), isNull);
      },
      variant: const TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.windows,
      }),
    );
  }
}
