import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/settings_page.dart';
import 'package:sked/widgets/sked_tooltip.dart';
import 'package:sked/widgets/sked_date_picker.dart';
import 'package:sked/widgets/sked_week_picker.dart';
import 'package:sked/widgets/workbench_resource_widgets.dart';

import '../support/semantics_update_audit.dart';
import '../support/workspace_harness.dart';

class _AuditedBinding extends AutomatedTestWidgetsFlutterBinding {
  final audit = SemanticsUpdateAudit();

  @override
  ui.SemanticsUpdateBuilder createSemanticsUpdateBuilder() =>
      audit.createBuilder();
}

Future<void> _hoverTooltips(
  WidgetTester tester,
  _AuditedBinding binding,
  TestGesture mouse,
) async {
  var hovered = 0;
  final viewport =
      Offset.zero & (tester.view.physicalSize / tester.view.devicePixelRatio);
  for (final element in find.byType(Tooltip).evaluate().toList()) {
    final finder = find.byWidget(element.widget);
    if (finder.evaluate().isEmpty || tester.getSize(finder).isEmpty) continue;
    final point = tester.getCenter(finder);
    if (!viewport.contains(point)) continue;
    await mouse.moveTo(point);
    await tester.pump(const Duration(milliseconds: 400));
    hovered++;
    expect(
      binding.audit.errors,
      isEmpty,
      reason: 'tooltip=${(element.widget as Tooltip).message}',
    );
  }
  expect(hovered, greaterThan(0));
}

void main() {
  final binding = _AuditedBinding();
  setUp(binding.audit.reset);

  testWidgets(
    'sibling tooltip overlays remain reachable after hover and scroll',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final scroll = ScrollController();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 240,
                child: ListView(
                  controller: scroll,
                  children: [
                    for (var row = 0; row < 12; row++)
                      Row(
                        children: [
                          for (final column in ['A', 'B'])
                            SkedTooltip(
                              message: '$row $column',
                              waitDuration: Duration.zero,
                              child: SizedBox(
                                key: ValueKey('$row $column'),
                                width: 100,
                                height: 80,
                                child: Center(child: Text('$row $column')),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await mouse.addPointer(location: const Offset(400, 300));
        for (var cycle = 0; cycle < 6; cycle++) {
          for (final label in ['0 A', '0 B']) {
            await mouse.moveTo(tester.getCenter(find.byKey(ValueKey(label))));
            await tester.pump(const Duration(milliseconds: 200));
            expect(find.text(label), findsNWidgets(2));
            expect(binding.audit.errors, isEmpty);
          }
        }
        scroll.jumpTo(scroll.position.maxScrollExtent);
        await tester.pumpAndSettle();
        await mouse.moveTo(
          tester.getCenter(find.byKey(const ValueKey('11 B'))),
        );
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text('11 B'), findsNWidgets(2));
        scroll.jumpTo(0);
        await tester.pumpAndSettle();
        await mouse.moveTo(tester.getCenter(find.byKey(const ValueKey('0 B'))));
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text('0 B'), findsNWidgets(2));
        expect(binding.audit.errors, isEmpty);
        expect(binding.audit.updateCount, greaterThan(12));
      } finally {
        await mouse.removePointer();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        scroll.dispose();
        semantics.dispose();
      }
    },
  );

  testWidgets('tooltip retains its accessible label and source action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var presses = 0;
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SkedTooltip(
              message: 'Toggle calendar',
              child: Semantics(
                key: const ValueKey('source-action'),
                label: 'Calendar',
                checked: true,
                onTap: () => presses++,
                child: ExcludeSemantics(
                  child: TextButton(
                    onPressed: () => presses++,
                    child: const Text('Calendar'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final data = tester
          .getSemantics(find.byKey(const ValueKey('source-action')))
          .getSemanticsData();
      expect(data.label, 'Calendar');
      expect(data.tooltip, 'Toggle calendar');
      expect(data.hasAction(ui.SemanticsAction.tap), isTrue);
      await tester.tap(find.text('Calendar'));
      expect(presses, 1);
      expect(binding.audit.errors, isEmpty);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      semantics.dispose();
    }
  });

  testWidgets('decorative tooltip keeps an excluded source subtree connected', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SkedTooltip(
              message: 'Week one details',
              excludeFromSemantics: true,
              waitDuration: Duration.zero,
              child: Semantics(
                label: 'Week one',
                button: true,
                excludeSemantics: true,
                child: const SizedBox(
                  key: ValueKey('decorative-tooltip'),
                  width: 100,
                  height: 80,
                  child: Text('Week one'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await mouse.addPointer(location: const Offset(400, 300));
      await mouse.moveTo(
        tester.getCenter(find.byKey(const ValueKey('decorative-tooltip'))),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Week one details'), findsOneWidget);
      expect(binding.audit.errors, isEmpty);
    } finally {
      await mouse.removePointer();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      semantics.dispose();
    }
  });

  testWidgets(
    'workspace and settings tooltips preserve native traversal',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      final semantics = tester.ensureSemantics();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      try {
        await mouse.addPointer(location: const Offset(1500, 950));
        for (final mode in AppMode.values) {
          final provider = await workspaceProvider(mode: mode);
          try {
            for (final (width, settings) in [
              (1600.0, false),
              (520.0, false),
              (1600.0, true),
              (520.0, true),
            ]) {
              tester.view.physicalSize = Size(width, 1000);
              await tester.pumpWidget(
                WorkspaceHarness(
                  provider: provider,
                  home: settings ? const SettingsPage() : null,
                ),
              );
              await tester.pumpAndSettle();
              await _hoverTooltips(tester, binding, mouse);
            }
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
            provider.dispose();
          }
        }
        expect(binding.audit.updateCount, greaterThan(0));
      } finally {
        await mouse.removePointer();
        semantics.dispose();
        tester.view.reset();
      }
    },
    variant: TargetPlatformVariant({
      TargetPlatform.windows,
      TargetPlatform.android,
    }),
  );

  testWidgets(
    'pickers and a hiding resource action keep tooltip anchors',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      final semantics = tester.ensureSemantics();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      final provider = await workspaceProvider();
      try {
        await mouse.addPointer(location: const Offset(1500, 950));
        for (final content in [
          SkedWeekPicker(
            config: TimetableConfig(
              name: 'Semester',
              startDate: DateTime(2026, 9, 7),
              totalWeeks: 18,
              periodTimeSetId: defaultPeriodTimeSetId,
            ),
            selectedWeek: 2,
            currentDate: DateTime(2026, 9, 12),
            onSelected: (_) {},
            onCancel: () {},
          ),
          SkedDatePicker(
            initialDate: DateTime(2026, 9, 12),
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
            onSelected: (_) {},
            onCancel: () {},
          ),
          TimetableResourceRow(
            timetableId: 'example',
            name: 'Sample timetable',
            selected: true,
            onSelected: () {},
            onEdit: () {},
          ),
        ]) {
          await tester.pumpWidget(
            WorkspaceHarness(
              provider: provider,
              home: Scaffold(
                body: Center(child: SizedBox(width: 360, child: content)),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await _hoverTooltips(tester, binding, mouse);
          if (content is TimetableResourceRow) {
            await tester.pump(const Duration(milliseconds: 100));
            expect(find.text('Edit timetable'), findsOneWidget);
          }
          await mouse.moveTo(const Offset(1500, 950));
          await tester.pump(const Duration(milliseconds: 16));
          expect(binding.audit.errors, isEmpty);
          await tester.pumpAndSettle();
          expect(binding.audit.errors, isEmpty);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        }
      } finally {
        await mouse.removePointer();
        provider.dispose();
        semantics.dispose();
        tester.view.reset();
      }
    },
    variant: TargetPlatformVariant({
      TargetPlatform.windows,
      TargetPlatform.android,
    }),
  );

  testWidgets('a hovered source can open and close picker routes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    final semantics = tester.ensureSemantics();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    final provider = await workspaceProvider();
    try {
      await mouse.addPointer(location: const Offset(1500, 950));
      for (final week in [true, false]) {
        await tester.pumpWidget(
          WorkspaceHarness(
            provider: provider,
            home: Scaffold(
              body: Center(
                child: Builder(
                  builder: (context) => SkedTooltip(
                    message: 'Open picker',
                    waitDuration: Duration.zero,
                    child: TextButton(
                      key: const ValueKey('open-picker-route'),
                      onPressed: () {
                        if (week) {
                          unawaited(
                            showSkedWeekPicker(
                              context: context,
                              anchorContext: context,
                              config: TimetableConfig(
                                name: 'Semester',
                                startDate: DateTime(2026, 9, 7),
                                totalWeeks: 18,
                                periodTimeSetId: defaultPeriodTimeSetId,
                              ),
                              selectedWeek: 2,
                            ),
                          );
                        } else {
                          unawaited(
                            showSkedDatePicker(
                              context: context,
                              anchorContext: context,
                              initialDate: DateTime(2026, 9, 12),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            ),
                          );
                        }
                      },
                      child: const Text('Choose'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final source = find.byKey(const ValueKey('open-picker-route'));
        await mouse.moveTo(tester.getCenter(source));
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text('Open picker'), findsOneWidget);
        await tester.tap(source);
        await tester.pumpAndSettle();
        expect(
          week ? find.byType(SkedWeekPicker) : find.byType(SkedDatePicker),
          findsOneWidget,
        );
        await _hoverTooltips(tester, binding, mouse);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byType(SkedWeekPicker), findsNothing);
        expect(find.byType(SkedDatePicker), findsNothing);
        expect(binding.audit.errors, isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    } finally {
      await mouse.removePointer();
      provider.dispose();
      semantics.dispose();
      tester.view.reset();
    }
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
