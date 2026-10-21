import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/widgets/timetable_grid.dart';
import 'package:sked/widgets/workspace_frame.dart';

class _SelectionLabel extends StatelessWidget {
  const _SelectionLabel();

  @override
  Widget build(BuildContext context) =>
      Text(WorkspaceSelectionScope.of(context) ?? 'No selection');
}

Finder _visual(int index) =>
    find.byKey(ValueKey('timetable-course-visual-course-$index'));

Finder _hit(int index) =>
    find.byKey(ValueKey('timetable-course-hit-course-$index'));

Finder _annotation(int index) => find.byWidgetPredicate(
  (widget) =>
      widget is Semantics &&
      (widget.properties.label?.startsWith('Course $index,') ?? false),
);

Widget _grid(ValueChanged<TimetableCourseTapInfo> onTap) => TimetableGrid(
  timetable: TimetableData(
    id: 'selection',
    config: TimetableConfig(
      name: 'Timetable',
      startDate: DateTime(2026, 1, 5),
      totalWeeks: 18,
      periodTimeSetId: defaultPeriodTimeSetId,
    ),
    courses: List.generate(70, (index) {
      final start = 480 + (index ~/ 7) * 50;
      return CourseItem(
        id: 'course-$index',
        name: 'Course $index',
        location: 'Room ${index + 1}',
        teacher: 'Teacher',
        dayOfWeek: index % 7 + 1,
        semesterWeeks: const [1],
        periods: const [],
        startMinutes: start,
        endMinutes: start + 45,
        timeRange: buildTimeRange(start, start + 45),
        credit: 0,
        remarks: '',
        customFields: const {},
      );
    }),
  ),
  periodTimes: const [
    CoursePeriodTime(index: 1, startMinutes: 480, endMinutes: 1020),
  ],
  weekDateStart: DateTime(2026, 1, 5),
  selectedWeek: 1,
  realCurrentWeek: 1,
  localeCode: 'en',
  preserveGaps: true,
  showPastEndedCourses: true,
  showFutureCourses: true,
  showGridLines: true,
  fitVisibleDaysToWidth: true,
  onCourseTap: onTap,
  onEmptySlotTap: (_) {},
  themeColorMode: themeColorModeSingle,
  courseNameColorValues: const {},
  colorfulCourseTextColorMode: colorfulCourseTextColorModeAuto,
  liveCourseOutlineEnabled: false,
  liveCourseOutlineMode: liveCourseOutlineModeCurrentOrNext,
  liveCourseOutlineColorValue: 0xff6750a4,
  liveCourseOutlineWidth: 2,
);

void main() {
  testWidgets(
    'selection updates only changed courses and preserves focus and semantics',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final semantics = tester.ensureSemantics();
      try {
        final selection = ValueNotifier<String?>('course:course-0');
        addTearDown(selection.dispose);
        TimetableCourseTapInfo? activated;
        final retainedGrid = _grid((info) => activated = info);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: TargetPlatform.windows),
            home: Scaffold(
              body: ValueListenableBuilder<String?>(
                valueListenable: selection,
                child: Column(
                  children: [
                    const _SelectionLabel(),
                    Expanded(child: retainedGrid),
                  ],
                ),
                builder: (_, id, child) =>
                    WorkspaceSelectionScope(selectedId: id, child: child!),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final unaffectedCard = tester.widget(_visual(2));
        final unaffectedProperties = tester
            .widget<Semantics>(_annotation(2))
            .properties;
        final nodeIds = {
          for (final index in [0, 1, 2, 3])
            index: tester.getSemantics(_annotation(index)).id,
        };
        final focus = Focus.of(
          tester.element(
            find
                .descendant(of: _hit(0), matching: find.byType(MouseRegion))
                .first,
          ),
        );
        focus.requestFocus();
        await tester.pumpAndSettle();
        expect(FocusManager.instance.primaryFocus, same(focus));

        final builds = <String, int>{};
        final previous = debugOnRebuildDirtyWidget;
        debugOnRebuildDirtyWidget = (element, builtOnce) {
          previous?.call(element, builtOnce);
          final type = element.widget.runtimeType.toString();
          builds.update(type, (value) => value + 1, ifAbsent: () => 1);
        };
        addTearDown(() => debugOnRebuildDirtyWidget = previous);
        int? oldIndex = 0;
        for (final nextIndex in <int?>[1, 3, 0, null]) {
          builds.clear();
          selection.value = nextIndex == null
              ? null
              : 'course:course-$nextIndex';
          await tester.pumpAndSettle();
          final changed = {?oldIndex, ?nextIndex};
          expect(builds['TimetableGrid'] ?? 0, 0);
          expect(builds['_CourseCard'], changed.length);
          expect(builds['_CourseHitTarget'], changed.length);
          expect(builds['_CourseSemantics'], changed.length);
          expect(tester.widget(_visual(2)), same(unaffectedCard));
          expect(
            tester.widget<Semantics>(_annotation(2)).properties,
            same(unaffectedProperties),
          );
          expect(FocusManager.instance.primaryFocus, same(focus));
          // The unfiltered API still updates consumers that need the whole ID.
          expect(find.text(selection.value ?? 'No selection'), findsOneWidget);
          for (final index in nodeIds.keys) {
            final node = tester.getSemantics(_annotation(index));
            expect(node.id, nodeIds[index]);
            expect(
              node.getSemanticsData().flagsCollection.isSelected,
              index == nextIndex ? ui.Tristate.isTrue : ui.Tristate.isFalse,
            );
          }
          oldIndex = nextIndex;
        }
        final target = tester.getSemantics(_annotation(1));
        target.owner!.performAction(target.id, ui.SemanticsAction.tap);
        expect(activated?.course.id, 'course-1');
        expect(activated?.anchorRect, tester.getRect(_hit(1)));
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
