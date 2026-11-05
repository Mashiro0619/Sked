import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';

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
          if (!hidden) {
            await tester.binding.handlePopRoute();
            await tester.pumpAndSettle();
          }
          await selectAgentShellDestination(tester, 'agent');
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('agent-composer')).hitTestable(),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.android),
      );
    }
  }
}
