import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/widgets/sked_week_picker.dart';

import '../support/semantics_update_audit.dart';
import '../support/workspace_harness.dart';

class _AuditedBinding extends AutomatedTestWidgetsFlutterBinding {
  final audit = SemanticsUpdateAudit();

  @override
  ui.SemanticsUpdateBuilder createSemanticsUpdateBuilder() =>
      audit.createBuilder();
}

Finder _key(String id) => find.byKey(ValueKey(id));

void main() {
  final binding = _AuditedBinding();
  testWidgets('workspace switching retires hovered tooltip traversal nodes', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.25;
    tester.view.physicalSize = const Size(1600, 900);
    final semantics = tester.ensureSemantics();
    final app = await workspaceProvider();
    final mouse = await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
    var pointerAdded = false;

    Future<void> settle(String phase) async {
      await tester.pumpAndSettle(
        const Duration(milliseconds: 50),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 15),
      );
      expect(tester.takeException(), isNull, reason: phase);
      expect(binding.audit.errors, isEmpty, reason: phase);
    }

    Future<void> click(String id) async {
      final visible = _key(id).hitTestable();
      expect(visible, findsOneWidget);
      final center = tester.getCenter(visible);
      await mouse.moveTo(center);
      await mouse.down(center);
      await mouse.up();
    }

    Future<String> hover(String id) async {
      final target = _key(id).hitTestable();
      expect(target, findsOneWidget);
      final ancestors = find.ancestor(
        of: target,
        matching: find.byType(Tooltip),
      );
      final descendants = find.descendant(
        of: target,
        matching: find.byType(Tooltip),
      );
      final tooltip = tester.widget<Tooltip>(
        ancestors.evaluate().isNotEmpty ? ancestors.first : descendants.first,
      );
      final label = tooltip.message ?? tooltip.richMessage!.toPlainText();
      await mouse.moveTo(const Offset(1278, 718));
      await tester.pump(const Duration(milliseconds: 300));
      final before = find.text(label).evaluate().length;
      await mouse.moveTo(tester.getCenter(target));
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.text(label).evaluate().length, greaterThan(before));
      await settle('hover $id');
      return label;
    }

    try {
      await app.settingsCommands.updateWorkspacePanelDisplayMode(
        WorkspacePanelDisplayMode.sideBySide,
      );
      await app.studentCommands.setSelectedWeek(2);
      await app.generalNavigation.setSelectedDate(DateTime(2026, 9, 8));
      final week = app.studentView.selectedWeek;
      final date = app.generalView.selectedDate;
      await tester.pumpWidget(WorkspaceHarness(provider: app));
      await settle('mount');
      await mouse.addPointer(location: const Offset(8, 100));
      pointerAdded = true;
      await hover('student-previous-week');
      await click('student-week-picker-button');
      await settle('week picker');
      expect(find.byType(SkedWeekPicker), findsOneWidget);
      await tester.sendKeyEvent(
        LogicalKeyboardKey.tab,
        physicalKey: PhysicalKeyboardKey.tab,
      );
      await tester.sendKeyEvent(
        LogicalKeyboardKey.escape,
        physicalKey: PhysicalKeyboardKey.escape,
      );
      await settle('keyboard escape');
      expect(find.byType(SkedWeekPicker), findsNothing);
      await click('workspace-resource-mode-general');
      await settle('student to general');
      expect(app.workspaceView.activeMode, AppMode.general);
      await hover('general-next-period');
      await click('workspace-resource-mode-student');
      await settle('general to student');
      expect(app.workspaceView.activeMode, AppMode.student);
      await hover('student-previous-week');
      expect(app.studentView.selectedWeek, week);
      expect(app.generalView.selectedDate, date);
      expect(binding.audit.updateCount, greaterThan(0));
    } finally {
      if (pointerAdded) await mouse.removePointer();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      app.dispose();
      semantics.dispose();
      tester.view.reset();
    }
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
