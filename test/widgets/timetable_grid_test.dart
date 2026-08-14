import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/widgets/timetable_grid.dart';

Widget _gridApp({required double textScale}) {
  final timetable = TimetableData(
    id: 'grid-test',
    config: TimetableConfig(
      name: 'Grid test',
      startDate: DateTime(2026, 1, 5),
      totalWeeks: 18,
      periodTimeSetId: defaultPeriodTimeSetId,
    ),
    courses: const [],
  );
  return MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Scaffold(
      body: SizedBox.expand(
        child: TimetableGrid(
          timetable: timetable,
          periodTimes: buildDefaultPeriodTimes(),
          weekDateStart: DateTime(2026, 1, 5),
          selectedWeek: 1,
          realCurrentWeek: 1,
          localeCode: 'en',
          preserveGaps: false,
          showPastEndedCourses: true,
          showFutureCourses: true,
          showGridLines: true,
          onCourseTap: (_) {},
          onEmptySlotTap: (_) {},
          themeColorMode: themeColorModeSingle,
          courseNameColorValues: const {},
          colorfulCourseTextColorMode: colorfulCourseTextColorModeAuto,
          liveCourseOutlineEnabled: false,
          liveCourseOutlineMode: liveCourseOutlineModeCurrentOrNext,
          liveCourseOutlineColorValue: 0xFF6750A4,
          liveCourseOutlineWidth: 2,
        ),
      ),
    ),
  );
}

CourseItem _course({
  required String id,
  required int weekday,
  required int startMinutes,
  required int endMinutes,
  String? title,
  String location = '',
  String teacher = '',
  List<int> periods = const [1],
}) {
  return CourseItem(
    id: id,
    name: title ?? id,
    teacher: teacher,
    location: location,
    dayOfWeek: weekday,
    semesterWeeks: const [1],
    periods: periods,
    startMinutes: startMinutes,
    endMinutes: endMinutes,
    timeRange: buildTimeRange(startMinutes, endMinutes),
    credit: 0,
    remarks: '',
    customFields: const {},
  );
}

TimetableData _timetableWithCourses(List<CourseItem> courses) {
  return TimetableData(
    id: 'grid-test-courses',
    config: TimetableConfig(
      name: 'Grid test',
      startDate: DateTime(2026, 1, 5),
      totalWeeks: 18,
      periodTimeSetId: defaultPeriodTimeSetId,
    ),
    courses: courses,
  );
}

Widget _gridHarness({
  required TimetableData timetable,
  required List<CoursePeriodTime> periodTimes,
  List<int> visibleWeekdays = const [1, 2, 3, 4, 5, 6, 7],
  bool showDayHeader = true,
  bool preserveGaps = true,
  double textScale = 1,
  double bottomContentInset = 0,
  bool fitVisibleDaysToWidth = false,
  TextDirection textDirection = TextDirection.ltr,
  ValueChanged<TimetableCourseTapInfo>? onCourseTap,
  ValueChanged<TimetableEmptySlotTapInfo>? onEmptySlotTap,
  bool enableLongPressAdd = true,
}) {
  return MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: Directionality(textDirection: textDirection, child: child!),
    ),
    home: Scaffold(
      body: SizedBox.expand(
        child: TimetableGrid(
          timetable: timetable,
          periodTimes: periodTimes,
          weekDateStart: DateTime(2026, 1, 5),
          selectedWeek: 1,
          realCurrentWeek: 1,
          localeCode: 'en',
          preserveGaps: preserveGaps,
          showPastEndedCourses: true,
          showFutureCourses: true,
          showGridLines: true,
          onCourseTap: onCourseTap ?? (_) {},
          onEmptySlotTap: enableLongPressAdd ? onEmptySlotTap ?? (_) {} : null,
          themeColorMode: themeColorModeSingle,
          courseNameColorValues: const {},
          colorfulCourseTextColorMode: colorfulCourseTextColorModeAuto,
          liveCourseOutlineEnabled: false,
          liveCourseOutlineMode: liveCourseOutlineModeCurrentOrNext,
          liveCourseOutlineColorValue: 0xFF6750A4,
          liveCourseOutlineWidth: 2,
          visibleWeekdays: visibleWeekdays,
          showDayHeader: showDayHeader,
          bottomContentInset: bottomContentInset,
          fitVisibleDaysToWidth: fitVisibleDaysToWidth,
        ),
      ),
    ),
  );
}

ScrollableState _horizontalScrollState(WidgetTester tester, Key ownerKey) {
  final scrollable = find.descendant(
    of: find.byKey(ownerKey),
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable &&
          (widget.axisDirection == AxisDirection.right ||
              widget.axisDirection == AxisDirection.left),
    ),
  );
  return tester.state<ScrollableState>(scrollable.first);
}

void main() {
  for (final scenario in [
    (scale: 1.8, size: const Size(430, 776), maxHeight: 96.0),
    (scale: 2.0, size: const Size(1120, 800), maxHeight: 120.0),
  ]) {
    testWidgets(
      'day header uses measured height at ${scenario.scale}x text scale',
      (tester) async {
        await tester.binding.setSurfaceSize(scenario.size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(_gridApp(textScale: scenario.scale));
        await tester.pumpAndSettle();

        final headerHeight = tester
            .getSize(find.byKey(const ValueKey('timetable-day-header')))
            .height;
        expect(headerHeight, greaterThan(56));
        expect(headerHeight, lessThan(scenario.maxHeight));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('course visuals follow real time geometry and use Sked shapes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 776));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final timetable = _timetableWithCourses([
      _course(
        id: 'short-course',
        weekday: DateTime.monday,
        startMinutes: 480,
        endMinutes: 490,
      ),
    ]);

    await tester.pumpWidget(
      _gridHarness(
        timetable: timetable,
        periodTimes: const [
          CoursePeriodTime(index: 1, startMinutes: 480, endMinutes: 540),
        ],
        visibleWeekdays: const [DateTime.monday],
        showDayHeader: false,
      ),
    );
    await tester.pumpAndSettle();

    final visual = find.byKey(
      const ValueKey('timetable-course-visual-short-course'),
    );
    expect(tester.getSize(visual).height, closeTo(14, 0.01));
    expect(tester.widget<Card>(visual).shape, isA<RoundedSuperellipseBorder>());
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey('timetable-course-hit-short-course')),
          )
          .height,
      greaterThanOrEqualTo(48),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('legacy unknown time range resolves from configured periods', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final timetable = _timetableWithCourses([
      _course(
        id: 'legacy-period-course',
        title: 'Legacy course',
        weekday: DateTime.monday,
        startMinutes: 0,
        endMinutes: 0,
        periods: const [2],
      ),
    ]);

    await tester.pumpWidget(
      _gridHarness(
        timetable: timetable,
        periodTimes: const [
          CoursePeriodTime(index: 1, startMinutes: 480, endMinutes: 525),
          CoursePeriodTime(index: 2, startMinutes: 540, endMinutes: 585),
        ],
        visibleWeekdays: const [DateTime.monday],
        showDayHeader: false,
      ),
    );
    await tester.pumpAndSettle();

    final visual = find.byKey(
      const ValueKey('timetable-course-visual-legacy-period-course'),
    );
    final dayColumn = find.byKey(const ValueKey('timetable-day-column-1'));
    expect(tester.getSize(visual).height, closeTo(63, 0.01));
    expect(
      tester.getTopLeft(visual).dy - tester.getTopLeft(dayColumn).dy,
      closeTo(84, 0.01),
    );
    expect(find.bySemanticsLabel('Legacy course, 09:00–09:45'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('collapsed gaps keep custom courses visibly rendered', (
    tester,
  ) async {
    final timetable = _timetableWithCourses([
      _course(
        id: 'before-first',
        weekday: DateTime.monday,
        startMinutes: 450,
        endMinutes: 460,
      ),
      _course(
        id: 'in-break',
        weekday: DateTime.monday,
        startMinutes: 525,
        endMinutes: 535,
        periods: const [],
      ),
      _course(
        id: 'after-last',
        weekday: DateTime.monday,
        startMinutes: 660,
        endMinutes: 675,
      ),
    ]);
    await tester.pumpWidget(
      _gridHarness(
        timetable: timetable,
        periodTimes: const [
          CoursePeriodTime(index: 1, startMinutes: 480, endMinutes: 525),
          CoursePeriodTime(index: 2, startMinutes: 540, endMinutes: 585),
          CoursePeriodTime(index: 3, startMinutes: 600, endMinutes: 645),
        ],
        visibleWeekdays: const [DateTime.monday],
        showDayHeader: false,
        preserveGaps: false,
      ),
    );
    await tester.pumpAndSettle();

    for (final id in const ['before-first', 'in-break', 'after-last']) {
      expect(
        tester
            .getSize(find.byKey(ValueKey('timetable-course-visual-$id')))
            .height,
        greaterThan(0),
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('legacy courses in one period retain conflict grouping', (
    tester,
  ) async {
    TimetableCourseTapInfo? tapInfo;
    final timetable = _timetableWithCourses([
      _course(
        id: 'legacy-a',
        weekday: DateTime.monday,
        startMinutes: 0,
        endMinutes: 0,
        periods: const [2],
      ),
      _course(
        id: 'legacy-b',
        weekday: DateTime.monday,
        startMinutes: 0,
        endMinutes: 0,
        periods: const [2],
      ),
    ]);
    await tester.pumpWidget(
      _gridHarness(
        timetable: timetable,
        periodTimes: const [
          CoursePeriodTime(index: 1, startMinutes: 480, endMinutes: 525),
          CoursePeriodTime(index: 2, startMinutes: 540, endMinutes: 585),
        ],
        visibleWeekdays: const [DateTime.monday],
        showDayHeader: false,
        onCourseTap: (info) => tapInfo = info,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('timetable-course-visual-legacy-a')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('timetable-course-visual-legacy-b')),
      findsNothing,
    );
    await tester.tap(
      find.byKey(const ValueKey('timetable-course-hit-legacy-a')),
    );
    expect(
      tapInfo?.courses.map((course) => course.id),
      containsAll(<String>['legacy-a', 'legacy-b']),
    );
    expect(find.byIcon(Icons.layers_outlined), findsOneWidget);
  });

  testWidgets('narrow week keeps time rail fixed and syncs header scrolling', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _gridHarness(
        timetable: _timetableWithCourses(const []),
        periodTimes: buildDefaultPeriodTimes().take(4).toList(),
        fitVisibleDaysToWidth: false,
      ),
    );
    await tester.pumpAndSettle();

    final timeRail = find.byKey(const ValueKey('timetable-time-rail'));
    final mondayHeader = find.byKey(const ValueKey('timetable-day-header-1'));
    final mondayColumn = find.byKey(const ValueKey('timetable-day-column-1'));
    final railBefore = tester.getTopLeft(timeRail);
    final headerBefore = tester.getTopLeft(mondayHeader);
    final columnBefore = tester.getTopLeft(mondayColumn);

    await tester.drag(
      find.byKey(const ValueKey('timetable-grid-horizontal-scroll')),
      const Offset(-240, 0),
    );
    await tester.pumpAndSettle();

    final headerAfter = tester.getTopLeft(mondayHeader);
    final columnAfter = tester.getTopLeft(mondayColumn);
    expect(tester.getTopLeft(timeRail), railBefore);
    expect(columnAfter.dx, lessThan(columnBefore.dx - 100));
    expect(
      headerAfter.dx - headerBefore.dx,
      closeTo(columnAfter.dx - columnBefore.dx, 0.5),
    );
  });

  testWidgets('fit mode divides all visible columns across the viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _gridHarness(
        timetable: _timetableWithCourses(const []),
        periodTimes: buildDefaultPeriodTimes().take(4).toList(),
        fitVisibleDaysToWidth: true,
      ),
    );
    await tester.pumpAndSettle();

    final headerScroll = _horizontalScrollState(
      tester,
      const ValueKey('timetable-day-header-horizontal-scroll'),
    );
    final bodyScroll = _horizontalScrollState(
      tester,
      const ValueKey('timetable-grid-horizontal-scroll'),
    );
    expect(headerScroll.position.maxScrollExtent, closeTo(0, 0.01));
    expect(bodyScroll.position.maxScrollExtent, closeTo(0, 0.01));

    final viewport = tester.getSize(
      find.byKey(const ValueKey('timetable-grid-horizontal-scroll')),
    );
    final content = tester.getSize(
      find.byKey(const ValueKey('timetable-grid-horizontal-content')),
    );
    expect(content.width, closeTo(viewport.width, 0.01));

    final firstColumn = tester.getSize(
      find.byKey(const ValueKey('timetable-day-column-1')),
    );
    final lastColumn = tester.getSize(
      find.byKey(const ValueKey('timetable-day-column-7')),
    );
    expect(firstColumn.width, closeTo(content.width / 7, 0.01));
    expect(lastColumn.width, closeTo(firstColumn.width, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact fitted week wraps the course title within its card', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final timetable = _timetableWithCourses([
      _course(
        id: 'narrow-course',
        title: 'Advanced Mathematics',
        weekday: DateTime.monday,
        startMinutes: 480,
        endMinutes: 525,
      ),
    ]);

    await tester.pumpWidget(
      _gridHarness(
        timetable: timetable,
        periodTimes: const [
          CoursePeriodTime(index: 1, startMinutes: 480, endMinutes: 525),
        ],
        fitVisibleDaysToWidth: true,
      ),
    );
    await tester.pumpAndSettle();

    final rail = find.byKey(const ValueKey('timetable-time-rail'));
    expect(tester.getSize(rail).width, inInclusiveRange(48, 56));
    final visual = find.byKey(
      const ValueKey('timetable-course-visual-narrow-course'),
    );
    final title = find.descendant(
      of: visual,
      matching: find.text('Advanced Mathematics'),
    );
    expect(title, findsOneWidget);
    final titleText = tester.widget<Text>(title);
    expect(titleText.maxLines, isNull);
    expect(titleText.softWrap, isTrue);
    expect(titleText.overflow, TextOverflow.visible);
    expect(tester.getSize(title).height, greaterThan(20));
    expect(tester.takeException(), isNull);
  });

  testWidgets('large text expands the measured time rail', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _gridHarness(
        timetable: _timetableWithCourses(const []),
        periodTimes: const [
          CoursePeriodTime(index: 1, startMinutes: 480, endMinutes: 525),
        ],
        textScale: 2,
      ),
    );
    await tester.pumpAndSettle();

    final rail = find.byKey(const ValueKey('timetable-time-rail'));
    expect(tester.getSize(rail).width, greaterThan(56));
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching fit mode clamps synchronized scroll offsets', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var fitVisibleDaysToWidth = false;
    late void Function(void Function()) updateGrid;
    final timetable = _timetableWithCourses([
      _course(
        id: 'fit-toggle-course',
        weekday: DateTime.monday,
        startMinutes: 480,
        endMinutes: 525,
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            updateGrid = setState;
            return Scaffold(
              body: SizedBox.expand(
                child: TimetableGrid(
                  timetable: timetable,
                  periodTimes: buildDefaultPeriodTimes().take(4).toList(),
                  weekDateStart: DateTime(2026, 1, 5),
                  selectedWeek: 1,
                  realCurrentWeek: 1,
                  localeCode: 'en',
                  preserveGaps: true,
                  showPastEndedCourses: true,
                  showFutureCourses: true,
                  showGridLines: true,
                  onCourseTap: (_) {},
                  onEmptySlotTap: (_) {},
                  themeColorMode: themeColorModeSingle,
                  courseNameColorValues: const {},
                  colorfulCourseTextColorMode: colorfulCourseTextColorModeAuto,
                  liveCourseOutlineEnabled: false,
                  liveCourseOutlineMode: liveCourseOutlineModeCurrentOrNext,
                  liveCourseOutlineColorValue: 0xFF6750A4,
                  liveCourseOutlineWidth: 2,
                  fitVisibleDaysToWidth: fitVisibleDaysToWidth,
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    const bodyKey = ValueKey('timetable-grid-horizontal-scroll');
    final bodyFinder = find.byKey(bodyKey);
    await tester.drag(bodyFinder, const Offset(-180, 0));
    await tester.pumpAndSettle();
    final bodyBeforeToggle = _horizontalScrollState(
      tester,
      bodyKey,
    ).position.pixels;
    expect(bodyBeforeToggle, greaterThan(0));

    updateGrid(() => fitVisibleDaysToWidth = true);
    await tester.pumpAndSettle();
    final fitBody = _horizontalScrollState(tester, bodyKey);
    final fitHeader = _horizontalScrollState(
      tester,
      const ValueKey('timetable-day-header-horizontal-scroll'),
    );
    expect(fitBody.position.maxScrollExtent, closeTo(0, 0.01));
    expect(fitHeader.position.maxScrollExtent, closeTo(0, 0.01));
    expect(fitBody.position.pixels, closeTo(0, 0.01));
    expect(fitHeader.position.pixels, closeTo(0, 0.01));

    updateGrid(() => fitVisibleDaysToWidth = false);
    await tester.pumpAndSettle();
    final restoredBody = _horizontalScrollState(tester, bodyKey);
    final restoredHeader = _horizontalScrollState(
      tester,
      const ValueKey('timetable-day-header-horizontal-scroll'),
    );
    expect(restoredBody.position.maxScrollExtent, greaterThan(0));
    expect(restoredHeader.position.maxScrollExtent, greaterThan(0));
    expect(restoredBody.position.pixels, closeTo(0, 0.01));
    expect(restoredHeader.position.pixels, closeTo(0, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('fit mode remains bounded on a narrow large-text viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _gridHarness(
        timetable: _timetableWithCourses(const []),
        periodTimes: buildDefaultPeriodTimes().take(3).toList(),
        fitVisibleDaysToWidth: true,
        textScale: 2,
        textDirection: TextDirection.rtl,
      ),
    );
    await tester.pumpAndSettle();

    final headerScroll = _horizontalScrollState(
      tester,
      const ValueKey('timetable-day-header-horizontal-scroll'),
    );
    final bodyScroll = _horizontalScrollState(
      tester,
      const ValueKey('timetable-grid-horizontal-scroll'),
    );
    expect(headerScroll.position.maxScrollExtent, closeTo(0, 0.01));
    expect(bodyScroll.position.maxScrollExtent, closeTo(0, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching week and day views keeps horizontal offsets aligned', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var visibleWeekdays = const [1, 2, 3, 4, 5, 6, 7];
    late void Function(void Function()) updateGrid;
    final timetable = _timetableWithCourses(const []);

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            updateGrid = setState;
            return Scaffold(
              body: SizedBox.expand(
                child: TimetableGrid(
                  timetable: timetable,
                  periodTimes: buildDefaultPeriodTimes().take(4).toList(),
                  weekDateStart: DateTime(2026, 1, 5),
                  selectedWeek: 1,
                  realCurrentWeek: 1,
                  localeCode: 'en',
                  preserveGaps: true,
                  showPastEndedCourses: true,
                  showFutureCourses: true,
                  showGridLines: true,
                  onCourseTap: (_) {},
                  onEmptySlotTap: (_) {},
                  themeColorMode: themeColorModeSingle,
                  courseNameColorValues: const {},
                  colorfulCourseTextColorMode: colorfulCourseTextColorModeAuto,
                  liveCourseOutlineEnabled: false,
                  liveCourseOutlineMode: liveCourseOutlineModeCurrentOrNext,
                  liveCourseOutlineColorValue: 0xFF6750A4,
                  liveCourseOutlineWidth: 2,
                  visibleWeekdays: visibleWeekdays,
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('timetable-grid-horizontal-scroll')),
      const Offset(-180, 0),
    );
    await tester.pumpAndSettle();

    updateGrid(() => visibleWeekdays = const [DateTime.monday]);
    await tester.pumpAndSettle();
    updateGrid(() => visibleWeekdays = const [1, 2, 3, 4, 5, 6, 7]);
    await tester.pumpAndSettle();

    final header = tester.getTopLeft(
      find.byKey(const ValueKey('timetable-day-header-1')),
    );
    final column = tester.getTopLeft(
      find.byKey(const ValueKey('timetable-day-column-1')),
    );
    expect(header.dx - column.dx, closeTo(0, 0.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'single day mode shares course preparation and hides the header',
    (tester) async {
      final timetable = _timetableWithCourses([
        _course(
          id: 'monday-course',
          title: 'Monday course',
          weekday: DateTime.monday,
          startMinutes: 480,
          endMinutes: 525,
        ),
        _course(
          id: 'wednesday-course',
          title: 'Wednesday course',
          weekday: DateTime.wednesday,
          startMinutes: 480,
          endMinutes: 525,
        ),
      ]);

      await tester.pumpWidget(
        _gridHarness(
          timetable: timetable,
          periodTimes: const [
            CoursePeriodTime(index: 1, startMinutes: 480, endMinutes: 540),
          ],
          visibleWeekdays: const [DateTime.wednesday],
          showDayHeader: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('timetable-day-header')), findsNothing);
      expect(
        find.byKey(const ValueKey('timetable-day-column-3')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('timetable-day-column-1')),
        findsNothing,
      );
      expect(find.text('Wednesday course'), findsOneWidget);
      expect(find.text('Monday course'), findsNothing);
    },
  );

  testWidgets('adjacent short course hit targets do not activate each other', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final tappedIds = <String>[];
    final timetable = _timetableWithCourses([
      _course(
        id: 'first-short',
        weekday: DateTime.monday,
        startMinutes: 480,
        endMinutes: 490,
      ),
      _course(
        id: 'second-short',
        weekday: DateTime.monday,
        startMinutes: 490,
        endMinutes: 500,
      ),
    ]);
    await tester.pumpWidget(
      _gridHarness(
        timetable: timetable,
        periodTimes: const [
          CoursePeriodTime(index: 1, startMinutes: 480, endMinutes: 540),
        ],
        visibleWeekdays: const [DateTime.monday],
        showDayHeader: false,
        onCourseTap: (info) => tappedIds.add(info.course.id),
      ),
    );
    await tester.pumpAndSettle();

    final first = find.byKey(
      const ValueKey('timetable-course-hit-first-short'),
    );
    final second = find.byKey(
      const ValueKey('timetable-course-hit-second-short'),
    );
    expect(
      tester.getRect(first).bottom,
      lessThanOrEqualTo(tester.getRect(second).top + 0.01),
    );

    await tester.tap(first);
    await tester.pump();
    await tester.tap(second);
    await tester.pump();
    expect(tappedIds, const ['first-short', 'second-short']);
    for (final label in const [
      'first-short, 08:00–08:10',
      'second-short, 08:10–08:20',
    ]) {
      final node = tester.getSemantics(find.bySemanticsLabel(label));
      expect(node.rect.height, greaterThanOrEqualTo(48));
      expect(node.getSemanticsData().hasAction(ui.SemanticsAction.tap), isTrue);
    }
    semantics.dispose();
  });

  testWidgets('long press on a course never activates the empty slot action', (
    tester,
  ) async {
    final tappedIds = <String>[];
    final emptySlots = <TimetableEmptySlotTapInfo>[];
    final timetable = _timetableWithCourses([
      _course(
        id: 'long-press-course',
        weekday: DateTime.monday,
        startMinutes: 480,
        endMinutes: 490,
      ),
    ]);
    await tester.pumpWidget(
      _gridHarness(
        timetable: timetable,
        periodTimes: const [
          CoursePeriodTime(index: 1, startMinutes: 480, endMinutes: 540),
        ],
        visibleWeekdays: const [DateTime.monday],
        showDayHeader: false,
        onCourseTap: (info) => tappedIds.add(info.course.id),
        onEmptySlotTap: emptySlots.add,
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(
      find.byKey(const ValueKey('timetable-course-hit-long-press-course')),
    );
    await tester.pump();

    expect(tappedIds, const ['long-press-course']);
    expect(emptySlots, isEmpty);
  });

  testWidgets(
    'disabled empty-slot long press removes the grid recognizer but keeps course interaction',
    (tester) async {
      final tappedIds = <String>[];
      final timetable = _timetableWithCourses([
        _course(
          id: 'long-press-course-disabled-add',
          weekday: DateTime.monday,
          startMinutes: 480,
          endMinutes: 540,
        ),
      ]);
      await tester.pumpWidget(
        _gridHarness(
          timetable: timetable,
          periodTimes: const [
            CoursePeriodTime(index: 1, startMinutes: 480, endMinutes: 540),
            CoursePeriodTime(index: 2, startMinutes: 550, endMinutes: 610),
          ],
          visibleWeekdays: const [DateTime.monday],
          showDayHeader: false,
          enableLongPressAdd: false,
          onCourseTap: (info) => tappedIds.add(info.course.id),
        ),
      );
      await tester.pumpAndSettle();

      final dayColumn = find.byKey(const ValueKey('timetable-day-column-1'));
      final emptyGridLongPress = find.descendant(
        of: dayColumn,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is GestureDetector && widget.onLongPressStart != null,
        ),
      );
      expect(emptyGridLongPress, findsNothing);

      await tester.longPress(
        find.byKey(
          const ValueKey('timetable-course-hit-long-press-course-disabled-add'),
        ),
      );
      await tester.pump();

      expect(tappedIds, const ['long-press-course-disabled-add']);
    },
  );

  testWidgets('primary mouse long press can add from an empty slot', (
    tester,
  ) async {
    final emptySlots = <TimetableEmptySlotTapInfo>[];
    await tester.pumpWidget(
      _gridHarness(
        timetable: _timetableWithCourses(const []),
        periodTimes: const [
          CoursePeriodTime(index: 1, startMinutes: 480, endMinutes: 540),
        ],
        visibleWeekdays: const [DateTime.monday],
        showDayHeader: false,
        onEmptySlotTap: emptySlots.add,
      ),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(
        find.byKey(const ValueKey('timetable-day-column-long-press-1')),
      ),
      kind: ui.PointerDeviceKind.mouse,
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await gesture.up();
    await tester.pump();

    expect(emptySlots, hasLength(1));
    expect(emptySlots.single.weekday, DateTime.monday);
    expect(emptySlots.single.periods, const [1]);
  });

  testWidgets('short visual still exposes complete course semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final timetable = _timetableWithCourses([
      _course(
        id: 'semantic-course',
        title: 'Advanced Physics',
        location: 'Lab 3',
        teacher: 'Dr. Chen',
        weekday: DateTime.monday,
        startMinutes: 480,
        endMinutes: 490,
      ),
    ]);

    await tester.pumpWidget(
      _gridHarness(
        timetable: timetable,
        periodTimes: const [
          CoursePeriodTime(index: 1, startMinutes: 480, endMinutes: 540),
        ],
        visibleWeekdays: const [DateTime.monday],
        showDayHeader: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel('Advanced Physics, Lab 3, Dr. Chen, 08:00–08:10'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('2x RTL layout keeps the time rail on the leading edge', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _gridHarness(
        timetable: _timetableWithCourses(const []),
        periodTimes: buildDefaultPeriodTimes().take(4).toList(),
        textScale: 2,
        textDirection: TextDirection.rtl,
      ),
    );
    await tester.pumpAndSettle();

    final railRect = tester.getRect(
      find.byKey(const ValueKey('timetable-time-rail')),
    );
    expect(railRect.right, closeTo(320, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('bottom content inset only extends the vertical scroll tail', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 360));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final periodTimes = buildDefaultPeriodTimes();
    final lastPeriod = periodTimes.last;
    final timetable = _timetableWithCourses([
      _course(
        id: 'last-course',
        weekday: DateTime.monday,
        startMinutes: lastPeriod.startMinutes,
        endMinutes: lastPeriod.endMinutes,
        periods: [lastPeriod.index],
      ),
    ]);

    await tester.pumpWidget(
      _gridHarness(
        timetable: timetable,
        periodTimes: periodTimes,
        visibleWeekdays: const [DateTime.monday],
        showDayHeader: false,
      ),
    );
    await tester.pumpAndSettle();

    final scrollFinder = find.byKey(
      const ValueKey('timetable-grid-vertical-scroll'),
    );
    final scrollableFinder = find.descendant(
      of: scrollFinder,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    );
    final courseFinder = find.byKey(
      const ValueKey('timetable-course-visual-last-course'),
    );
    final courseTopWithoutInset = tester.getTopLeft(courseFinder).dy;
    final extentWithoutInset = tester
        .state<ScrollableState>(scrollableFinder)
        .position
        .maxScrollExtent;
    expect(
      tester
          .widget<SingleChildScrollView>(scrollFinder)
          .padding!
          .resolve(TextDirection.ltr)
          .bottom,
      0,
    );

    await tester.pumpWidget(
      _gridHarness(
        timetable: timetable,
        periodTimes: periodTimes,
        visibleWeekdays: const [DateTime.monday],
        showDayHeader: false,
        bottomContentInset: 80,
      ),
    );
    await tester.pumpAndSettle();

    final position = tester.state<ScrollableState>(scrollableFinder).position;
    expect(
      tester.getTopLeft(courseFinder).dy,
      closeTo(courseTopWithoutInset, 0.01),
    );
    expect(position.maxScrollExtent, closeTo(extentWithoutInset + 80, 0.01));
    expect(
      tester
          .widget<SingleChildScrollView>(scrollFinder)
          .padding!
          .resolve(TextDirection.ltr)
          .bottom,
      80,
    );

    position.jumpTo(position.maxScrollExtent);
    await tester.pump();
    final viewportBottom = tester.getRect(scrollFinder).bottom;
    expect(
      tester.getRect(courseFinder).bottom,
      lessThanOrEqualTo(viewportBottom - 80),
    );
    expect(tester.takeException(), isNull);
  });
}
