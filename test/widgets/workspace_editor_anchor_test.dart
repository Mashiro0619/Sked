import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';

import '../support/workspace_harness.dart';

void main() {
  testWidgets(
    'calendar double-click captures its time cell without a recent pointer event',
    (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(1600, 1100);
      addTearDown(t.view.reset);
      final p = await workspaceProvider(mode: AppMode.general);
      addTearDown(p.dispose);
      await t.pumpWidget(WorkspaceHarness(provider: p));
      await t.pumpAndSettle();
      final cells = find.byWidgetPredicate(
        (w) =>
            w is GestureDetector &&
            w.key.toString().contains('general-timeline-empty-slot-'),
      );
      final cell = cells.first;
      final rect = t.getRect(cell);
      final local = const Offset(20, 240);
      final global = rect.topLeft + local;
      // Invoke the accessible gesture callback without relying on the frame's
      // one-second pointer cache; a held gesture must not lose its anchor.
      t.widget<GestureDetector>(cell).onDoubleTapDown!(
        TapDownDetails(localPosition: local, globalPosition: global),
      );
      await t.pumpAndSettle();
      expect(find.byType(GeneralEventEditorSheet), findsOneWidget);
      final panel = t.getRect(
        find.byKey(const ValueKey('workspace-detail-surface')),
      );
      expect(panel.left, closeTo(rect.right + 6, .1));
      expect((panel.top - global.dy).abs(), lessThan(60));
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
