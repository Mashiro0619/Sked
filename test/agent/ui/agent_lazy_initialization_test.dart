import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/connection/agent_credential_store.dart';
import 'package:sked/agent/conversations/conversation_storage.dart';
import 'package:sked/agent/ui/agent_conversation_view.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/screens/agent_page.dart';
import 'package:sked/screens/agent_settings_page.dart';

import '../../support/workspace_harness.dart';

class _Storage extends ConversationStorage {
  _Storage() : super.base();
  int loads = 0;
  final started = Completer<void>();

  @override
  Future<ConversationStorageLoad> load() async {
    loads++;
    if (!started.isCompleted) started.complete();
    return const ConversationStorageLoad();
  }

  @override
  Future<void> save(String value, {required int revision}) async {}
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
}
