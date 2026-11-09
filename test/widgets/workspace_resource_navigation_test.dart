import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';

import '../support/agent_native_fixture.dart' as native;
import '../support/agent_workspace_navigation.dart';
import '../support/workbench_dense_data.dart';
import '../support/workspace_harness.dart';

void main() {
  for (final width in [390.0, 800.0]) {
    for (final hidden in [false, true]) {
      testWidgets(
        'resource drawer at $width supplies destinations only when the bar is hidden: $hidden',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 900);
          addTearDown(tester.view.reset);
          final app = await workspaceProvider(
            mode: AppMode.general,
            agentNativeClient: native.MemoryAgentCore().client,
            storage: WorkspaceMemoryStorage(
              denseWorkbenchData().copyWith(
                hideHomeWorkspaceNavigation: hidden,
              ),
            ),
          );
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox.shrink());
            app.dispose();
          });
          await tester.pumpWidget(WorkspaceHarness(provider: app));
          await tester.pumpAndSettle();
          await openWorkspaceShellResources(tester);
          await tester.pumpAndSettle();
          for (final key in [
            'workspace-resource-mode-student',
            'workspace-resource-mode-general',
            'workspace-agent-entry',
          ]) {
            expect(
              find.byKey(ValueKey(key)),
              hidden ? findsOneWidget : findsNothing,
            );
          }
          expect(
            find
                .byKey(const ValueKey('resource-calendar-dense-cal-0'))
                .hitTestable(),
            findsOneWidget,
          );
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          await selectAgentShellDestination(tester, 'agent');
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('agent-composer')).hitTestable(),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await app.agent.quiesce();
        },
        variant: TargetPlatformVariant.only(TargetPlatform.android),
      );
    }
  }

  for (final (width, scale) in [(640.0, 1.0), (1440.0, 1.0), (640.0, 2.0)]) {
    testWidgets(
      'desktop destinations at $width and ${scale}x wait for input through consecutive workspace transitions',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 900);
        addTearDown(tester.view.reset);
        final app = await workspaceProvider(
          mode: AppMode.general,
          agentNativeClient: native.MemoryAgentCore().client,
        );
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

        await selectAgentShellDestination(tester, 'general');
        final agentEntries = find.byWidgetPredicate(
          (widget) => const [
            ValueKey('adaptive-shell-agent-destination'),
            ValueKey('adaptive-shell-agent-entry'),
            ValueKey('adaptive-shell-agent-selected'),
            ValueKey('workspace-agent-entry'),
          ].contains(widget.key),
        );
        expect(agentEntries.hitTestable(), findsNothing);
        await selectAgentShellDestination(tester, 'agent');
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('agent-composer')).hitTestable(),
          findsOneWidget,
        );
        expect(app.workspaceView.activeMode, AppMode.general);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await app.agent.quiesce();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }
}
