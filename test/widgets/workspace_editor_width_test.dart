import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/widgets/sked_floating_surface.dart';
import 'package:sked/widgets/workspace_editor.dart';
import 'package:sked/widgets/workspace_frame.dart';

import '../support/workspace_harness.dart';

void main() {
  testWidgets('width overrides retain the moving and last measured anchor', (
    tester,
  ) async {
    final offset = ValueNotifier(20.0);
    final visible = ValueNotifier(true);
    addTearDown(offset.dispose);
    addTearDown(visible.dispose);
    final trigger = GlobalKey();
    final host = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            key: host,
            width: 600,
            height: 400,
            child: ValueListenableBuilder<double>(
              valueListenable: offset,
              builder: (context, left, _) => Stack(
                children: [
                  Positioned(
                    left: left,
                    top: 40,
                    child: ValueListenableBuilder<bool>(
                      valueListenable: visible,
                      builder: (context, visible, _) => visible
                          ? SizedBox(key: trigger, width: 80, height: 40)
                          : const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final original = WorkspaceEditorConfiguration(
      anchorContext: trigger.currentContext,
      placement: SkedFloatingPlacement.left,
    );
    final initial = original.initialAnchor;
    final event = original.withPreferredWidth(480);
    final snapshot = event.snapshotIfInside(
      host.currentContext!.findRenderObject(),
    );
    expect(original.preferredWidth, 440);
    expect(event.preferredWidth, 480);
    expect(snapshot.preferredWidth, 480);
    expect(event.placement, SkedFloatingPlacement.left);
    expect(event.initialAnchor, initial);
    expect(event.withPreferredWidth(480), same(event));

    offset.value = 160;
    await tester.pump();
    final moved = tester.getRect(find.byKey(trigger));
    expect(event.liveAnchor, moved);
    expect(event.initialAnchor, initial);
    expect(snapshot.liveAnchor, initial);

    // Only the width-adjusted copy reads the new rectangle before removal.
    // Sharing the same anchor lets the original retain that last position too.
    visible.value = false;
    await tester.pump();
    expect(original.liveAnchor, moved);
    expect(event.liveAnchor, moved);
    expect(snapshot.liveAnchor, initial);
    expect(tester.takeException(), isNull);
  });

  for (final (name, mode, width, triggerKey) in [
    ('course', AppMode.student, 440.0, 'student-add-course'),
    ('event', AppMode.general, 480.0, 'general-add-event'),
    ('timetable', AppMode.student, 360.0, null),
  ]) {
    testWidgets(
      '$name opens at its own width and retains manual sizing when docked',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(1920, 1100);
        addTearDown(tester.view.reset);
        final provider = await workspaceProvider(mode: mode);
        addTearDown(provider.dispose);
        await tester.pumpWidget(WorkspaceHarness(provider: provider));
        await tester.pumpAndSettle();
        final trigger = triggerKey == null
            ? find
                  .byTooltip(
                    AppLocalizations.of(
                      tester.element(find.byType(WorkspaceFrame)),
                    ).createTimetable,
                  )
                  .hitTestable()
            : find.byKey(ValueKey(triggerKey));
        await tester.tap(trigger);
        await tester.pumpAndSettle();
        final panel = find.byKey(const ValueKey('workspace-detail-surface'));
        final resize = find.byKey(const ValueKey('workspace-detail-resize'));
        final editor = find.byType(WorkspaceEditorScaffold);
        final element = tester.element(editor);
        expect(tester.getSize(panel).width, width);

        await tester.drag(resize, const Offset(-40, 0));
        await tester.pumpAndSettle();
        expect(tester.getSize(panel).width, width + 40);
        await provider.updateWorkspacePanelDisplayMode(
          WorkspacePanelDisplayMode.sideBySide,
        );
        await tester.pumpAndSettle();
        expect(tester.getSize(panel).width, width + 40);
        expect(tester.element(editor), same(element));

        await tester.drag(resize, const Offset(-1000, 0));
        await tester.pumpAndSettle();
        expect(tester.getSize(panel).width, 680);
        await tester.drag(resize, const Offset(1000, 0));
        await tester.pumpAndSettle();
        expect(tester.getSize(panel).width, 320);
        await provider.updateWorkspacePanelDisplayMode(
          WorkspacePanelDisplayMode.overlay,
        );
        await tester.pumpAndSettle();
        expect(tester.getSize(panel).width, 320);
        expect(tester.element(editor), same(element));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }
}
