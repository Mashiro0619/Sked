import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/widgets/timetable_grid.dart';
import 'package:sked/widgets/workspace_frame.dart';

CourseItem _course(String id, int weekday, {int startMinutes = 480}) =>
    CourseItem(
      id: id,
      name: 'Course $id',
      location: 'Room 201',
      teacher: 'Teacher',
      dayOfWeek: weekday,
      semesterWeeks: const [1],
      periods: const [1],
      startMinutes: startMinutes,
      endMinutes: startMinutes + 90,
      timeRange: buildTimeRange(startMinutes, startMinutes + 90),
      credit: 0,
      remarks: '',
      customFields: const {},
    );

Widget _grid({
  required List<CourseItem> courses,
  bool enabled = true,
  bool forceFrames = false,
  String? selectedId,
  List<int> days = const [1, 2],
  ValueChanged<TimetableCourseTapInfo>? onTap,
}) => MaterialApp(
  theme: ThemeData(platform: TargetPlatform.windows),
  home: Scaffold(
    body: TickerMode(
      enabled: enabled,
      forceFrames: forceFrames,
      child: WorkspaceSelectionScope(
        selectedId: selectedId == null ? null : 'course:$selectedId',
        child: TimetableGrid(
          timetable: TimetableData(
            id: 'ticker-scope',
            config: TimetableConfig(
              name: 'Timetable',
              startDate: DateTime(2026, 1, 5),
              totalWeeks: 18,
              periodTimeSetId: defaultPeriodTimeSetId,
            ),
            courses: courses,
          ),
          periodTimes: const [
            CoursePeriodTime(index: 1, startMinutes: 480, endMinutes: 750),
          ],
          weekDateStart: DateTime(2026, 1, 5),
          selectedWeek: 1,
          realCurrentWeek: 1,
          localeCode: 'en',
          preserveGaps: true,
          showPastEndedCourses: true,
          showFutureCourses: true,
          showGridLines: true,
          showDayHeader: false,
          fitVisibleDaysToWidth: true,
          visibleWeekdays: days,
          onCourseTap: onTap ?? (_) {},
          onEmptySlotTap: (_) {},
          themeColorMode: themeColorModeSingle,
          courseNameColorValues: const {},
          colorfulCourseTextColorMode: colorfulCourseTextColorModeAuto,
          liveCourseOutlineEnabled: false,
          liveCourseOutlineMode: liveCourseOutlineModeCurrentOrNext,
          liveCourseOutlineColorValue: 0xff6750a4,
          liveCourseOutlineWidth: 2,
        ),
      ),
    ),
  ),
);

Finder _visual(String id) =>
    find.byKey(ValueKey('timetable-course-visual-$id'));
Finder _hit(String id) => find.byKey(ValueKey('timetable-course-hit-$id'));

double _paintedBorderWidth(WidgetTester tester, String id) {
  final physicalShape = tester.widget<PhysicalShape>(
    find.descendant(of: _visual(id), matching: find.byType(PhysicalShape)),
  );
  final clipper = physicalShape.clipper as ShapeBorderClipper;
  return (clipper.shape as RoundedRectangleBorder).side.width;
}

ValueListenable<TickerModeData> _modeFor(WidgetTester tester, Finder finder) =>
    TickerMode.getValuesNotifier(tester.element(finder));

void main() {
  testWidgets(
    'parent ticker mode mutes and resumes the painted course animation',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(960, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final courses = [_course('monday', 1), _course('tuesday', 2)];
      await tester.pumpWidget(_grid(courses: courses));
      await tester.pumpAndSettle();
      final cardRect = tester.getRect(_visual('monday'));
      final hitRect = tester.getRect(_hit('monday'));
      expect(_paintedBorderWidth(tester, 'monday'), 0);

      await tester.pumpWidget(_grid(courses: courses, selectedId: 'monday'));
      await tester.pump(const Duration(milliseconds: 50));
      final advancingWidth = _paintedBorderWidth(tester, 'monday');
      expect(advancingWidth, greaterThan(0));
      expect(advancingWidth, lessThan(2));

      await tester.pumpWidget(
        _grid(courses: courses, selectedId: 'monday', enabled: false),
      );
      final mutedWidth = _paintedBorderWidth(tester, 'monday');
      await tester.pump(const Duration(milliseconds: 350));
      expect(_paintedBorderWidth(tester, 'monday'), mutedWidth);
      expect(_modeFor(tester, _visual('monday')).value.enabled, isFalse);
      expect(_modeFor(tester, _hit('tuesday')).value.enabled, isFalse);
      expect(tester.getRect(_visual('monday')), cardRect);
      expect(tester.getRect(_hit('monday')), hitRect);

      await tester.pumpWidget(_grid(courses: courses, selectedId: 'monday'));
      await tester.pump(const Duration(milliseconds: 50));
      // Muting suppresses ticker callbacks, while elapsed time still advances.
      // After reactivation the painted border must catch up to its target.
      expect(_paintedBorderWidth(tester, 'monday'), greaterThan(mutedWidth));
      await tester.pumpAndSettle();
      expect(_paintedBorderWidth(tester, 'monday'), 2);
      expect(tester.getRect(_visual('monday')), cardRect);
      expect(tester.getRect(_hit('monday')), hitRect);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('day scopes inherit mode changes for cards and hit targets', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(960, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final courses = [
      _course('monday', 1),
      _course('monday-late', 1, startMinutes: 660),
      _course('tuesday', 2),
    ];
    await tester.pumpWidget(_grid(courses: courses));
    await tester.pumpAndSettle();
    final monday = _modeFor(tester, _visual('monday'));
    final tuesday = _modeFor(tester, _visual('tuesday'));
    expect(_modeFor(tester, _hit('monday')), same(monday));
    expect(_modeFor(tester, _visual('monday-late')), same(monday));
    expect(_modeFor(tester, _hit('tuesday')), same(tuesday));
    expect(tuesday, isNot(same(monday)));
    final changes = <TickerModeData>[];
    void onChanged() => changes.add(monday.value);
    monday.addListener(onChanged);
    addTearDown(() => monday.removeListener(onChanged));

    for (final mode in [
      const TickerModeData(enabled: true, forceFrames: true),
      const TickerModeData(enabled: false, forceFrames: true),
      const TickerModeData(enabled: true, forceFrames: false),
    ]) {
      await tester.pumpWidget(
        _grid(
          courses: courses,
          enabled: mode.enabled,
          forceFrames: mode.forceFrames,
        ),
      );
      await tester.pump();
      expect(_modeFor(tester, _visual('monday')), same(monday));
      expect(_modeFor(tester, _visual('tuesday')), same(tuesday));
      expect(monday.value, mode);
      expect(tuesday.value, mode);
      expect(changes.last, mode);
    }
    expect(changes, hasLength(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching and removing columns releases active animations', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(960, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final courses = [_course('monday', 1), _course('tuesday', 2)];
    await tester.pumpWidget(_grid(courses: courses));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_grid(courses: courses, selectedId: 'monday'));
    await tester.pump(const Duration(milliseconds: 30));
    expect(_paintedBorderWidth(tester, 'monday'), greaterThan(0));
    expect(_paintedBorderWidth(tester, 'monday'), lessThan(2));

    TimetableCourseTapInfo? tapped;
    await tester.pumpWidget(
      _grid(
        courses: courses,
        days: const [2],
        selectedId: 'tuesday',
        onTap: (value) => tapped = value,
      ),
    );
    await tester.pumpAndSettle();
    expect(_visual('monday'), findsNothing);
    expect(_visual('tuesday'), findsOneWidget);
    await tester.tap(_hit('tuesday'));
    expect(tapped?.course.id, 'tuesday');
    expect(tapped?.course.name, 'Course tuesday');
    expect(tapped?.course.location, 'Room 201');
    expect(tapped?.course.teacher, 'Teacher');
    await tester.pumpAndSettle();

    await tester.pumpWidget(_grid(courses: courses, selectedId: 'tuesday'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_grid(courses: courses, selectedId: 'monday'));
    await tester.pump(const Duration(milliseconds: 30));
    expect(_paintedBorderWidth(tester, 'monday'), greaterThan(0));
    expect(_paintedBorderWidth(tester, 'monday'), lessThan(2));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });
}
