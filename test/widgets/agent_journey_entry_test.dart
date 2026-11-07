import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:sked/controllers/app_session.dart';
import 'package:sked/controllers/app_backup_controller.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/agent_page.dart';
import 'package:sked/screens/settings_page.dart';

import '../support/agent_workspace_navigation.dart';
import '../support/workspace_harness.dart';

Finder _key(String value) => find.byKey(ValueKey(value));

void main() {
  testWidgets(
    'native feature readiness reaches the actual narrow desktop resource entry',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(640, 900);
      addTearDown(tester.view.reset);
      final app = await workspaceProvider(mode: AppMode.general);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        app.dispose();
      });
      await tester.pumpWidget(WorkspaceHarness(provider: app, textScale: 2));
      await tester.pumpAndSettle();
      expect(agentShellEntryControl(), 'general-desktop-toolbar-more');
      expect(app.agent.isInitialized, isFalse);
      await selectAgentShellDestination(tester, 'agent');
      await tester.pumpAndSettle();
      expect(_key('agent-composer').hitTestable(), findsOneWidget);
      expect(tester.widget<AgentPage>(find.byType(AgentPage)).embedded, isTrue);
      expect(app.agent.isInitialized, isTrue);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  for (final (platform, width, scale) in [
    (TargetPlatform.android, 390.0, 1.0),
    (TargetPlatform.android, 800.0, 1.0),
    (TargetPlatform.windows, 1440.0, 1.0),
    (TargetPlatform.windows, 640.0, 2.0),
  ]) {
    testWidgets(
      'selective backup keeps its embedded Agent and owners through shell settings at $width / $scale',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 900);
        addTearDown(tester.view.reset);
        final app = await workspaceProvider(mode: AppMode.general);
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          app.dispose();
        });
        await tester.pumpWidget(
          WorkspaceHarness(provider: app, textScale: scale),
        );
        await tester.pumpAndSettle();
        await selectAgentShellDestination(tester, 'agent');
        await tester.pumpAndSettle();
        expect(
          tester.widget<AgentPage>(find.byType(AgentPage)).embedded,
          isTrue,
        );
        final agentState = tester.state(find.byType(AgentPage));
        const draft = 'Unsent draft retained through application settings';
        await tester.enterText(_key('agent-composer'), draft);
        await tester.pumpAndSettle();
        final conversationId = app.agent.conversations.selectedId;
        expect(app.agent.conversations.selected?.draft, draft);
        await selectAgentShellDestination(
          tester,
          app.workspaceView.activeMode.name,
        );
        await tester.pumpAndSettle();
        expect(find.byType(AgentPage).hitTestable(), findsNothing);
        final retained = find.byType(AgentPage, skipOffstage: false);
        expect(retained, findsOneWidget);
        expect(tester.state(retained), same(agentState));
        final route = await openWorkspaceShellSettings(tester);
        await tester.pumpAndSettle();
        final settings = find.byType(SettingsPage).hitTestable();
        expect(settings, findsOneWidget);
        final context = tester.element(settings);
        expect(context.read<AppSession>(), same(app.session));
        expect(context.read<AppBackupController>(), same(app.backups));
        expect(ModalRoute.of(context)?.isCurrent, isTrue);
        expect(route.control.endsWith(route.entry), isTrue);
        expect(app.agent.conversations.selectedId, conversationId);
        expect(app.agent.conversations.selected?.draft, draft);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        await selectAgentShellDestination(tester, 'agent');
        await tester.pumpAndSettle();
        expect(tester.state(find.byType(AgentPage)), same(agentState));
        expect(
          tester.widget<TextField>(_key('agent-composer')).controller!.text,
          draft,
        );
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(platform),
    );
  }
}
