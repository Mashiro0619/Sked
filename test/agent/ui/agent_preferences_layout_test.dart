import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/screens/agent_preferences_settings_page.dart';
import 'package:sked/screens/agent_settings_page.dart';

import '../../support/agent_native_fixture.dart' as native;
import '../../support/workspace_harness.dart';

void main() {
  testWidgets(
    'grouped preferences keep editable drafts through narrow large-text reflow',
    (tester) async {
      final app = (await tester.runAsync(() async {
        final result = await workspaceProvider(
          agentNativeClient: native.MemoryAgentCore().client,
        );
        await result.agent.initialize();
        return result;
      }))!;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(app.agent.quiesce);
        app.dispose();
        tester.view.reset();
      });
      tester.view.devicePixelRatio = 1;
      Future<void> mount(double width, double scale) async {
        tester.view.physicalSize = Size(width, 900);
        await tester.pumpWidget(
          WorkspaceHarness(
            provider: app,
            home: const AgentSettingsPage(),
            textScale: scale,
          ),
        );
        await tester.pumpAndSettle();
      }

      Future<void> reveal(Finder target) async {
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        expect(target.hitTestable(), findsOneWidget);
      }

      Finder field(String key) => find.byKey(ValueKey(key));
      await mount(1200, 1);
      await tester.tap(field('agent-settings-preferences'));
      await tester.pumpAndSettle();
      expect(field('agent-max-tokens'), findsNothing);
      expect(field('agent-max-rounds'), findsNothing);
      expect(field('agent-max-calls'), findsNothing);
      await tester.enterText(
        field('agent-system-instructions'),
        'Use concise replies.',
      );
      await mount(320, 2);
      expect(find.byType(AgentPreferencesSettingsPage), findsOneWidget);
      await reveal(field('agent-history-retention'));
      await tester.enterText(field('agent-history-retention'), '30');
      expect(tester.takeException(), isNull);

      await mount(1200, 1);
      expect(
        tester
            .widget<TextFormField>(field('agent-system-instructions'))
            .controller!
            .text,
        'Use concise replies.',
      );
      await reveal(field('agent-save-preferences'));
      await tester.runAsync(() async {
        await tester.tap(field('agent-save-preferences'));
        await app.agent.quiesce();
      });
      await tester.pumpAndSettle();
      expect(find.byType(AgentPreferencesSettingsPage), findsNothing);
      expect(app.agent.settings.systemInstructions, 'Use concise replies.');
      expect(app.agent.settings.historyRetentionDays, 30);
      expect(tester.takeException(), isNull);
    },
  );
}
