import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/widgets/course_editor_sheet.dart';
import 'package:sked/widgets/period_time_set_picker_dialog.dart';
import 'package:sked/widgets/sked_floating_surface.dart';
import 'package:sked/widgets/sked_task_dialog.dart';
import 'package:sked/widgets/sked_adaptive_picker_dialog.dart';
import 'package:sked/screens/theme_settings_page.dart';
import 'package:sked/models/timetable_models.dart';

import '../support/workspace_harness.dart';

final desktop = TargetPlatformVariant.only(TargetPlatform.windows);
void viewport(WidgetTester t, [Size size = const Size(1200, 900)]) {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = size;
  addTearDown(t.view.reset);
}

void main() {
  for (final scale in [1.0, 1.5, 2.0]) {
    testWidgets('right editor weekday attaches to its field at scale $scale', (
      t,
    ) async {
      viewport(t);
      final p = await workspaceProvider();
      addTearDown(p.dispose);
      await t.pumpWidget(
        WorkspaceHarness(
          provider: p,
          textScale: scale,
          home: Scaffold(
            body: Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 380,
                child: CourseEditorSheet(
                  periodTimes: buildDefaultPeriodTimes(),
                  totalWeeks: 18,
                  dayOfWeek: 1,
                ),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final field = find.text('Day').first;
      await t.ensureVisible(field);
      await t.tap(field);
      await t.pumpAndSettle();
      final panel = t.getRect(find.byType(SkedFloatingSurface));
      expect(panel.right, lessThanOrEqualTo(t.getRect(field).left));
      expect(panel.height, lessThan(200 * scale));
      final handle = find.byKey(const ValueKey('sked-picker-drag-handle'));
      await t.drag(handle, const Offset(-50, 40));
      await t.pumpAndSettle();
      expect(
        t.getRect(find.byType(SkedFloatingSurface)).top,
        closeTo(panel.top + 40, 1),
      );
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      await t.tap(field);
      await t.pumpAndSettle();
      expect(t.getRect(find.byType(SkedFloatingSurface)), panel);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    }, variant: desktop);
    testWidgets(
      'desktop course secondary choices use a single bounded floating surface at $scale',
      (t) async {
        viewport(t);
        final p = await workspaceProvider();
        addTearDown(p.dispose);
        await t.pumpWidget(
          WorkspaceHarness(
            provider: p,
            textScale: scale,
            home: Scaffold(
              body: CourseEditorSheet(
                periodTimes: buildDefaultPeriodTimes(),
                totalWeeks: 18,
                dayOfWeek: 1,
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        for (final label in ['Day', 'Weeks', 'Linked periods']) {
          final trigger = find.text(label).first;
          await t.ensureVisible(trigger);
          await t.tap(trigger);
          await t.pumpAndSettle();
          expect(find.byType(SkedFloatingSurface), findsOneWidget);
          expect(find.byType(AlertDialog), findsNothing);
          expect(
            find.byKey(const ValueKey('sked-picker-drag-handle')),
            findsOneWidget,
          );
          final rect = t.getRect(find.byType(SkedFloatingSurface));
          expect(
            find.byKey(const ValueKey('sked-picker-drag-handle')),
            findsOneWidget,
          );
          await t.drag(
            find.byKey(const ValueKey('sked-picker-drag-handle')),
            Offset(rect.left < 60 ? 30 : -30, rect.bottom > 840 ? -30 : 30),
          );
          await t.pumpAndSettle();
          final moved = t.getRect(find.byType(SkedFloatingSurface));
          expect(
            moved.topLeft,
            isNot(rect.topLeft),
            reason:
                '$label scale=$scale rect=$rect handle=${t.getRect(find.byKey(const ValueKey('sked-picker-drag-handle')))}',
          );
          expect(rect.left, greaterThanOrEqualTo(8));
          expect(rect.bottom, lessThanOrEqualTo(892));
          await t.sendKeyEvent(LogicalKeyboardKey.escape);
          await t.pumpAndSettle();
          expect(find.byType(SkedFloatingSurface), findsNothing);
        }
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      },
      variant: desktop,
    );
  }

  testWidgets(
    'period-time selection keeps pending commit alive across resize and Escape',
    (t) async {
      viewport(t);
      final p = await workspaceProvider();
      addTearDown(p.dispose);
      final gate = Completer<void>();
      var commits = 0;
      await t.pumpWidget(
        WorkspaceHarness(
          provider: p,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: Builder(
                builder: (anchor) => TextButton(
                  onPressed: () => unawaited(
                    showPeriodTimeSetPickerDialog(
                      anchor,
                      provider: p,
                      anchorContext: anchor,
                      selectedPeriodTimeSetId: p.periodTimeSets.first.id,
                      commitSelection: (_) async {
                        commits++;
                        await gate.future;
                      },
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Open'));
      await t.pumpAndSettle();
      expect(find.byType(SkedFloatingSurface), findsOneWidget);
      await t.tap(find.text(p.periodTimeSets.first.name));
      await t.pump();
      t.view.physicalSize = const Size(700, 600);
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pump();
      expect(find.byType(SkedFloatingSurface), findsOneWidget);
      expect(commits, 1);
      gate.complete();
      await t.pumpAndSettle();
      expect(find.byType(SkedFloatingSurface), findsNothing);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
    variant: desktop,
  );

  testWidgets(
    'theme color opens as a non-draggable floating choice and cancels unchanged',
    (t) async {
      viewport(t);
      final p = await workspaceProvider();
      addTearDown(p.dispose);
      final seed = p.themeSeedColorValue;
      await t.pumpWidget(
        WorkspaceHarness(provider: p, home: const ThemeSettingsPage()),
      );
      await t.pumpAndSettle();
      final trigger = find.text('Custom color').first;
      await t.ensureVisible(trigger);
      await t.tap(trigger);
      await t.pumpAndSettle();
      expect(find.byType(SkedFloatingSurface), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      t.view.physicalSize = const Size(700, 500);
      await t.pumpAndSettle();
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(p.themeSeedColorValue, seed);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
    variant: desktop,
  );

  testWidgets('picker closure drafts survive window rebuilds', (t) async {
    viewport(t);
    final p = await workspaceProvider();
    addTearDown(p.dispose);
    var builds = 0;
    await t.pumpWidget(
      WorkspaceHarness(
        provider: p,
        home: Scaffold(
          body: Builder(
            builder: (anchor) => TextButton(
              onPressed: () => unawaited(
                showSkedAdaptivePickerDialog<void>(
                  context: anchor,
                  anchorContext: anchor,
                  routeName: 'draft-test',
                  builder: (_) {
                    builds++;
                    var value = 0;
                    return StatefulBuilder(
                      builder: (context, refresh) => SkedTaskDialog(
                        title: const Text('Draft'),
                        content: Text('Value $value'),
                        actions: [
                          TextButton(
                            onPressed: () => refresh(() => value++),
                            child: const Text('Increment'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    await t.tap(find.text('Increment'));
    await t.pumpAndSettle();
    t.view.physicalSize = const Size(600, 400);
    await t.pumpAndSettle();
    expect(find.text('Value 1'), findsOneWidget);
    expect(builds, 1);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  }, variant: desktop);
}
