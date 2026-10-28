import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/theme/timetable_contrast.dart';
import 'package:sked/widgets/timetable_grid.dart';
import 'package:sked/widgets/workspace_frame.dart';

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
  List<int> semesterWeeks = const [1],
}) {
  return CourseItem(
    id: id,
    name: title ?? id,
    teacher: teacher,
    location: location,
    dayOfWeek: weekday,
    semesterWeeks: semesterWeeks,
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
  TargetPlatform? platform,
  Brightness brightness = Brightness.light,
  String themeColorMode = themeColorModeSingle,
  Map<String, int> courseColors = const {},
  int? textColor,
  ColorScheme? colorScheme,
  String? Function(String)? displayedCourseIdForConflict,
  TimetableLiveCourseTarget? liveCourseTarget,
  bool liveCourseOutlineEnabled = false,
  int liveCourseOutlineColorValue = 0xFF6750A4,
  int selectedWeek = 1,
  int realCurrentWeek = 1,
  String? selectedCourseId,
}) {
  return MaterialApp(
    theme: ThemeData(
      platform: platform,
      brightness: brightness,
      colorScheme: colorScheme,
    ),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: Directionality(textDirection: textDirection, child: child!),
    ),
    home: Scaffold(
      body: WorkspaceSelectionScope(
        selectedId: selectedCourseId == null
            ? null
            : 'course:$selectedCourseId',
        child: SizedBox.expand(
          child: TimetableGrid(
            timetable: timetable,
            periodTimes: periodTimes,
            weekDateStart: DateTime(2026, 1, 5),
            selectedWeek: selectedWeek,
            realCurrentWeek: realCurrentWeek,
            localeCode: 'en',
            preserveGaps: preserveGaps,
            showPastEndedCourses: true,
            showFutureCourses: true,
            showGridLines: true,
            onCourseTap: onCourseTap ?? (_) {},
            onEmptySlotTap: enableLongPressAdd
                ? onEmptySlotTap ?? (_) {}
                : null,
            themeColorMode: themeColorMode,
            courseNameColorValues: courseColors,
            colorfulCourseTextColorMode: textColor == null
                ? colorfulCourseTextColorModeAuto
                : colorfulCourseTextColorModeCustom,
            colorfulCourseTextColorValue: textColor,
            displayedCourseIdForConflict: displayedCourseIdForConflict,
            liveCourseTarget: liveCourseTarget,
            liveCourseOutlineEnabled: liveCourseOutlineEnabled,
            liveCourseOutlineMode: liveCourseOutlineModeCurrentOrNext,
            liveCourseOutlineColorValue: liveCourseOutlineColorValue,
            liveCourseOutlineWidth: 2,
            visibleWeekdays: visibleWeekdays,
            showDayHeader: showDayHeader,
            bottomContentInset: bottomContentInset,
            fitVisibleDaysToWidth: fitVisibleDaysToWidth,
          ),
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
  for (final customColor in const [0xff767676, 0xf5767676]) {
    testWidgets('custom text keeps its exact alpha at $customColor', (
      tester,
    ) async {
      await tester.pumpWidget(
        _gridHarness(
          timetable: _timetableWithCourses([
            _course(
              id: 'custom-alpha',
              weekday: 1,
              startMinutes: 480,
              endMinutes: 600,
              teacher: 'Teacher',
            ),
          ]),
          periodTimes: const [
            CoursePeriodTime(index: 1, startMinutes: 480, endMinutes: 600),
          ],
          visibleWeekdays: const [1],
          platform: TargetPlatform.android,
          themeColorMode: themeColorModeColorful,
          courseColors: const {'custom-alpha': 0xffffffff},
          textColor: customColor,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue)
              .copyWith(surface: Colors.white),
        ),
      );
      await tester.pumpAndSettle();
      final visual = find.byKey(
        const ValueKey('timetable-course-visual-custom-alpha'),
      );
      final title = find.descendant(
        of: visual,
        matching: find.text('custom-alpha'),
      );
      final text = tester.widget<Text>(title).style!.color!;
      final background = tester.widget<Card>(visual).color!;
      expect(text, Color(customColor));
      final actualRatio = renderedTimetableContrast(text, background);
      expect(
        hasLowContrastCourseText(
          textColor: text,
          courseColorValues: const [0xffffffff],
          surfaceColor: Colors.white,
        ),
        actualRatio < 4.5,
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      'colorful course text and outlines use each final fill in $brightness',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1200, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final table = _timetableWithCourses([
          _course(
            id: 'dark',
            weekday: 1,
            startMinutes: 480,
            endMinutes: 600,
            semesterWeeks: const [2],
          ),
          _course(
            id: 'light',
            weekday: 2,
            startMinutes: 480,
            endMinutes: 600,
            semesterWeeks: const [2],
          ),
          _course(
            id: 'future',
            weekday: 3,
            startMinutes: 480,
            endMinutes: 600,
            semesterWeeks: const [3],
          ),
          _course(id: 'past', weekday: 4, startMinutes: 480, endMinutes: 600),
          _course(
            id: 'overlap-a',
            periods: const [],
            weekday: 5,
            startMinutes: 480,
            endMinutes: 600,
            semesterWeeks: const [2],
          ),
          _course(
            id: 'overlap-b',
            periods: const [],
            weekday: 5,
            startMinutes: 510,
            endMinutes: 630,
            semesterWeeks: const [2],
          ),
        ]);
        await tester.pumpWidget(
          _gridHarness(
            timetable: table,
            periodTimes: const [
              CoursePeriodTime(index: 1, startMinutes: 480, endMinutes: 600),
            ],
            platform: TargetPlatform.android,
            brightness: brightness,
            themeColorMode: themeColorModeColorful,
            selectedWeek: 2,
            realCurrentWeek: 2,
            selectedCourseId: 'dark',
            courseColors: const {
              'dark': 0xff111111,
              'light': 0xffffd54f,
              'future': 0xff003366,
              'past': 0xff770022,
              'overlap-a': 0xffcccccc,
              'overlap-b': 0xff220022,
            },
            liveCourseOutlineEnabled: true,
            liveCourseOutlineColorValue: 0xffffd54f,
            liveCourseTarget: const TimetableLiveCourseTarget(
              week: 2,
              weekday: 2,
              courseId: 'light',
              isCurrentCourse: true,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final foregrounds = <String, Color>{};
        for (final id in const [
          'dark',
          'light',
          'future',
          'past',
          'overlap-a',
          'overlap-b',
        ]) {
          final visual = find.byKey(ValueKey('timetable-course-visual-$id'));
          expect(visual, findsOneWidget, reason: 'Rendered state $id');
          final card = tester.widget<Card>(visual);
          expect(card.color!.a, 1);
          final fill = Color.alphaBlend(
            card.color!,
            Theme.of(tester.element(visual)).colorScheme.surface,
          );
          final title = find.descendant(of: visual, matching: find.text(id));
          final color = tester.widget<Text>(title).style!.color!;
          foregrounds[id] = color;
          expect(
            renderedTimetableContrast(color, fill),
            greaterThanOrEqualTo(4.5),
            reason: '$id text on $fill',
          );
          final side = (card.shape! as RoundedRectangleBorder).side;
          if (id == 'dark' || id == 'light') {
            expect(side.width, greaterThan(0));
            expect(
              renderedTimetableContrast(
                side.color,
                Theme.of(tester.element(visual)).colorScheme.surface,
              ),
              greaterThanOrEqualTo(3),
              reason: '$id outline outside on surrounding canvas',
            );
            final guard = find.byKey(
              ValueKey('timetable-course-outline-guard-$id'),
            );
            final inside = guard.evaluate().isEmpty
                ? side.color
                : ((tester.widget<DecoratedBox>(guard).decoration
                                  as ShapeDecoration)
                              .shape
                          as RoundedRectangleBorder)
                      .side
                      .color;
            expect(
              renderedTimetableContrast(inside, fill),
              greaterThanOrEqualTo(3),
              reason: '$id outline inside on $fill',
            );
          }
        }
        expect(foregrounds['dark'], isNot(foregrounds['light']));
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final width in [320.0, 360.0, 393.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final direction in TextDirection.values) {
        for (final dayCount in [5, 7]) {
          testWidgets(
            'fitted $width dp $dayCount-day week at ${scale}x $direction fits every selected column',
            (tester) async {
              await tester.binding.setSurfaceSize(Size(width, 800));
              addTearDown(() => tester.binding.setSurfaceSize(null));
              final semantics = tester.ensureSemantics();
              final weekdays = List.generate(dayCount, (index) => index + 1);
              TimetableCourseTapInfo? opened;
              Widget grid({required bool fit}) => _gridHarness(
                timetable: _timetableWithCourses([
                  _course(
                    id: 'last-day',
                    title: 'Last selected day with full details',
                    location: 'Building B201',
                    teacher: 'Teacher',
                    weekday: weekdays.last,
                    startMinutes: 480,
                    endMinutes: 600,
                  ),
                ]),
                periodTimes: const [
                  CoursePeriodTime(
                    index: 1,
                    startMinutes: 480,
                    endMinutes: 600,
                  ),
                ],
                platform: TargetPlatform.android,
                visibleWeekdays: weekdays,
                fitVisibleDaysToWidth: fit,
                textScale: scale,
                textDirection: direction,
                onCourseTap: (info) => opened = info,
              );
              await tester.pumpWidget(grid(fit: true));
              await tester.pumpAndSettle();
              final body = find.byKey(
                const ValueKey('timetable-grid-horizontal-scroll'),
              );
              final viewport = tester.getRect(body);
              final content = tester.getRect(
                find.byKey(const ValueKey('timetable-grid-horizontal-content')),
              );
              expect(content.width, closeTo(viewport.width, .01));
              for (final weekday in weekdays) {
                final column = tester.getRect(
                  find.byKey(ValueKey('timetable-day-column-$weekday')),
                );
                expect(column.width, closeTo(viewport.width / dayCount, .01));
                expect(column.left, greaterThanOrEqualTo(viewport.left - .01));
                expect(column.right, lessThanOrEqualTo(viewport.right + .01));
                final header = tester.getRect(
                  find.byKey(ValueKey('timetable-day-header-$weekday')),
                );
                expect(header.center.dx, closeTo(column.center.dx, .01));
                expect(header.left, greaterThanOrEqualTo(viewport.left - .01));
                expect(header.right, lessThanOrEqualTo(viewport.right + .01));
              }
              for (final key in [
                const ValueKey('timetable-day-header-horizontal-scroll'),
                const ValueKey('timetable-grid-horizontal-scroll'),
              ]) {
                final position = _horizontalScrollState(tester, key).position;
                expect(position.maxScrollExtent, closeTo(0, .01));
                expect(position.pixels, closeTo(0, .01));
              }
              expect(
                MediaQuery.textScalerOf(
                  tester.element(find.byType(TimetableGrid)),
                ).scale(14),
                closeTo(scale * 14, .01),
              );
              final lastCourse = find.byKey(
                const ValueKey('timetable-course-hit-last-day'),
              );
              expect(lastCourse.hitTestable(), findsOneWidget);
              await tester.tap(lastCourse);
              expect(
                opened?.course.name,
                'Last selected day with full details',
              );
              expect(opened?.course.location, 'Building B201');
              expect(opened?.course.teacher, 'Teacher');
              expect(
                tester
                    .getSemantics(
                      find.bySemanticsLabel(
                        RegExp('^Last selected day with full details, '),
                      ),
                    )
                    .label,
                contains('Building B201'),
              );
              semantics.dispose();
              expect(tester.takeException(), isNull);

              await tester.pumpWidget(grid(fit: false));
              await tester.pumpAndSettle();
              expect(
                tester
                    .getSize(
                      find.byKey(const ValueKey('timetable-day-column-1')),
                    )
                    .width,
                greaterThanOrEqualTo(scale == 2 ? 156 : 112),
              );
              expect(
                _horizontalScrollState(
                  tester,
                  const ValueKey('timetable-grid-horizontal-scroll'),
                ).position.maxScrollExtent,
                greaterThan(0),
              );
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }
  }

  testWidgets('reused week updates live outlines and conflict choices', (
    tester,
  ) async {
    final timetable = _timetableWithCourses([
      _course(id: 'first', weekday: 1, startMinutes: 480, endMinutes: 540),
      _course(
        id: 'alternative',
        weekday: 1,
        startMinutes: 480,
        endMinutes: 540,
      ),
      _course(id: 'next', weekday: 1, startMinutes: 600, endMinutes: 660),
    ]);
    String? selected = 'first';
    String? choose(String key) => selected;
    TimetableCourseTapInfo? tapped;
    Future<void> pump(String target) async {
      await tester.pumpWidget(
        _gridHarness(
          timetable: timetable,
          periodTimes: const [
            CoursePeriodTime(index: 1, startMinutes: 480, endMinutes: 540),
            CoursePeriodTime(index: 2, startMinutes: 600, endMinutes: 660),
          ],
          visibleWeekdays: const [1],
          showDayHeader: false,
          platform: TargetPlatform.windows,
          displayedCourseIdForConflict: choose,
          liveCourseOutlineEnabled: true,
          liveCourseTarget: TimetableLiveCourseTarget(
            week: 1,
            weekday: 1,
            courseId: target,
            isCurrentCourse: target != 'next',
          ),
          onCourseTap: (value) => tapped = value,
        ),
      );
      await tester.pumpAndSettle();
    }

    Finder card(String id) =>
        find.byKey(ValueKey('timetable-course-visual-$id'));
    BorderSide outline(String id) =>
        (tester.widget<Card>(card(id)).shape! as RoundedRectangleBorder).side;
    await pump('first');
    expect(outline('first'), isNot(BorderSide.none));
    final nextBounds = tester.getRect(card('next'));
    await pump('next');
    expect(outline('first'), BorderSide.none);
    expect(outline('next'), isNot(BorderSide.none));
    expect(tester.getRect(card('next')), nextBounds);
    selected = 'alternative';
    await pump('alternative');
    expect(card('first'), findsNothing);
    expect(outline('alternative'), isNot(BorderSide.none));
    await tester.tap(
      find.byKey(const ValueKey('timetable-course-hit-alternative')),
    );
    expect(tapped!.course.id, 'alternative');
    expect(tapped!.selectedWeek, 1);
    expect(
      tapped!.courses.map((course) => course.id),
      containsAll(['first', 'alternative']),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'day view keeps its per-card text and observes only its own fill edits',
    (tester) async {
      final timetable = _timetableWithCourses([
        _course(
          id: 'monday',
          title: 'Monday',
          weekday: 1,
          startMinutes: 480,
          endMinutes: 600,
        ),
        _course(
          id: 'tuesday',
          title: 'Tuesday',
          weekday: 2,
          startMinutes: 480,
          endMinutes: 600,
        ),
      ]);
      final colors = {'Monday': 0xffffffff, 'Tuesday': 0xff000000};
      Future<void> pump(List<int> days) async {
        await tester.pumpWidget(
          _gridHarness(
            timetable: timetable,
            periodTimes: const [
              CoursePeriodTime(index: 1, startMinutes: 480, endMinutes: 600),
            ],
            visibleWeekdays: days,
            showDayHeader: false,
            platform: TargetPlatform.windows,
            themeColorMode: themeColorModeColorful,
            courseColors: colors,
          ),
        );
        await tester.pumpAndSettle();
      }

      Color titleColor() =>
          tester.widget<Text>(find.text('Monday')).style!.color!;
      await pump(const [1, 2]);
      final wholeWeekColor = titleColor();
      await pump(const [1]);
      expect(titleColor(), wholeWeekColor);
      colors['Tuesday'] = 0xffffffff;
      await pump(const [1]);
      expect(titleColor(), wholeWeekColor);
      colors['Monday'] = 0xff000000;
      await pump(const [1]);
      expect(titleColor(), isNot(wholeWeekColor));
      final editedDayColor = titleColor();
      await pump(const [1, 2]);
      expect(titleColor(), editedDayColor);
      expect(
        tester.widget<Text>(find.text('Tuesday')).style!.color,
        isNot(editedDayColor),
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final platform in [
    TargetPlatform.windows,
    TargetPlatform.macOS,
    TargetPlatform.linux,
    TargetPlatform.android,
    TargetPlatform.iOS,
  ]) {
    testWidgets(
      'time rail centers period numbers and both times on $platform',
      (tester) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));
        for (final scale in [1.0, 1.3, 2.0]) {
          for (final direction in TextDirection.values) {
            for (final size in [const Size(420, 900), const Size(1440, 900)]) {
              await tester.binding.setSurfaceSize(size);
              await tester.pumpWidget(
                _gridHarness(
                  platform: platform,
                  textScale: scale,
                  textDirection: direction,
                  timetable: _timetableWithCourses(const []),
                  periodTimes: const [
                    CoursePeriodTime(
                      index: 1,
                      startMinutes: 480,
                      endMinutes: 525,
                    ),
                    CoursePeriodTime(
                      index: 10,
                      startMinutes: 600,
                      endMinutes: 645,
                    ),
                  ],
                ),
              );
              await tester.pumpAndSettle();
              final rail = find.byKey(const ValueKey('timetable-time-rail'));
              final bounds = tester.getRect(rail);
              for (final label in [
                '1',
                '08:00',
                '08:45',
                '10',
                '10:00',
                '10:45',
              ]) {
                final text = find.descendant(
                  of: rail,
                  matching: find.text(label),
                );
                final rect = tester.getRect(text);
                expect(
                  rect.center.dx,
                  closeTo(bounds.center.dx, .01),
                  reason: '$label / $scale / $direction / $size',
                );
                expect(rect.left, greaterThanOrEqualTo(bounds.left));
                expect(rect.right, lessThanOrEqualTo(bounds.right));
              }
              expect(tester.takeException(), isNull);
            }
          }
        }
      },
    );
  }
  testWidgets(
    'short desktop period keeps its number centered when times are hidden',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 750));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _gridHarness(
          platform: TargetPlatform.windows,
          timetable: _timetableWithCourses(const []),
          periodTimes: const [
            CoursePeriodTime(index: 10, startMinutes: 480, endMinutes: 500),
          ],
        ),
      );
      await tester.pumpAndSettle();
      final rail = find.byKey(const ValueKey('timetable-time-rail'));
      final number = find.descendant(of: rail, matching: find.text('10'));
      expect(
        tester.getRect(number).center.dx,
        closeTo(tester.getRect(rail).center.dx, .01),
      );
      expect(
        tester.getRect(number).center.dy,
        closeTo(tester.getRect(rail).center.dy, .01),
      );
      final hiddenTime = find.descendant(
        of: rail,
        matching: find.text('08:00'),
      );
      // Natural text is laid out to choose which lines fit, then clipped.
      expect(
        tester.getRect(hiddenTime).overlaps(tester.getRect(rail)),
        isFalse,
      );
      expect(
        tester
            .widget<ClipRect>(
              find
                  .ancestor(of: hiddenTime, matching: find.byType(ClipRect))
                  .first,
            )
            .clipBehavior,
        Clip.hardEdge,
      );
      expect(tester.takeException(), isNull);
    },
  );

  group('course typography', () {
    const slots = [
      CoursePeriodTime(index: 1, startMinutes: 480, endMinutes: 540),
      CoursePeriodTime(index: 2, startMinutes: 540, endMinutes: 600),
      CoursePeriodTime(index: 3, startMinutes: 600, endMinutes: 660),
      CoursePeriodTime(index: 4, startMinutes: 660, endMinutes: 720),
    ];
    Finder within(String id, Finder finder) => find.descendant(
      of: find.byKey(ValueKey('timetable-course-visual-$id')),
      matching: finder,
    );
    for (final platform in TargetPlatform.values.where(
      (p) => p != TargetPlatform.fuchsia,
    )) {
      testWidgets('top-aligned typography follows platform $platform', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(1440, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final desktop = [
          TargetPlatform.windows,
          TargetPlatform.macOS,
          TargetPlatform.linux,
        ].contains(platform);
        for (final scale in [1.0, 1.3, 2.0]) {
          var tapped = false;
          await tester.pumpWidget(
            _gridHarness(
              platform: platform,
              textScale: scale,
              periodTimes: slots,
              visibleWeekdays: [1, 2, 3],
              onCourseTap: (_) => tapped = true,
              timetable: _timetableWithCourses([
                _course(
                  id: 'type',
                  weekday: 1,
                  startMinutes: 480,
                  endMinutes: 660,
                  title: '计算方法',
                  location: '辽河路校区 玉衡 B308(公共机房)',
                  teacher: '肖莎莎',
                  periods: [1, 2, 3],
                ),
              ]),
            ),
          );
          await tester.pumpAndSettle();
          final card = tester.getRect(
            find.byKey(const ValueKey('timetable-course-visual-type')),
          );
          final titleFinder = within('type', find.text('计算方法'));
          final locationFinder = within(
            'type',
            find.text('辽河路校区 玉衡 B308(公共机房)'),
          );
          final teacherFinder = within('type', find.text('肖莎莎'));
          final title = tester.widget<Text>(titleFinder);
          final location = tester.widget<Text>(locationFinder);
          final teacher = tester.widget<Text>(teacherFinder);
          expect(
            tester.getRect(teacherFinder).bottom,
            lessThan(card.center.dy),
          );
          if (desktop) {
            expect(
              title.style!.fontSize,
              greaterThan(location.style!.fontSize!),
            );
            expect(title.style!.fontWeight, FontWeight.w600);
            expect(title.style!.fontSize, 16);
            expect(location.style!.fontSize, 13);
            expect(location.style, teacher.style);
            expect(teacher.style!.fontWeight, FontWeight.w400);
            expect(location.style!.height, 1.3);
            expect(tester.getRect(titleFinder).top - card.top, closeTo(12, .1));
            expect(
              tester.getRect(titleFinder).left - card.left,
              closeTo(12, .1),
            );
            expect(
              tester.getRect(locationFinder).left,
              tester.getRect(titleFinder).left,
            );
            expect(
              tester.getRect(teacherFinder).left,
              tester.getRect(titleFinder).left,
            );
            expect(
              tester.getRect(locationFinder).top -
                  tester.getRect(titleFinder).bottom,
              closeTo(12, .1),
            );
            expect(
              tester.getRect(teacherFinder).top -
                  tester.getRect(locationFinder).bottom,
              closeTo(2, .1),
            );
          } else {
            expect(title.style!.height, 1.1);
            expect(teacher.style!.fontWeight, FontWeight.w600);
            expect(
              tester.getRect(locationFinder).top,
              closeTo(tester.getRect(titleFinder).bottom, .1),
            );
          }
          await tester.tap(
            find.byKey(const ValueKey('timetable-course-hit-type')),
          );
          expect(tapped, isTrue);
          expect(tester.takeException(), isNull);
        }
      });
    }
    double contrast(Color a, Color b) {
      final x = a.computeLuminance();
      final y = b.computeLuminance();
      return x > y ? (x + .05) / (y + .05) : (y + .05) / (x + .05);
    }

    for (final brightness in Brightness.values) {
      testWidgets(
        'desktop foreground hierarchy retains contrast and custom colors in $brightness',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(1440, 900));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final table = _timetableWithCourses([
            _course(
              id: 'contrast',
              weekday: 1,
              startMinutes: 480,
              endMinutes: 600,
              title: 'Calculus',
              location: 'Building A101',
              teacher: 'Teacher',
            ),
          ]);
          for (final colorful in [false, true]) {
            await tester.pumpWidget(
              _gridHarness(
                timetable: table,
                periodTimes: slots,
                platform: TargetPlatform.windows,
                brightness: brightness,
                themeColorMode: colorful
                    ? themeColorModeColorful
                    : themeColorModeSingle,
                courseColors: const {'Calculus': 0xfff4bb22},
                textColor: colorful ? 0xff654321 : null,
              ),
            );
            await tester.pumpAndSettle();
            final cardFinder = find.byKey(
              const ValueKey('timetable-course-visual-contrast'),
            );
            final card = tester.widget<Card>(cardFinder);
            final title = tester
                .widget<Text>(within('contrast', find.text('Calculus')))
                .style!
                .color!;
            final metadata = tester
                .widget<Text>(within('contrast', find.text('Building A101')))
                .style!
                .color!;
            if (colorful) {
              expect(title, metadata);
              expect(title.withValues(alpha: 1), const Color(0xff654321));
            } else {
              final background = Color.alphaBlend(
                card.color!,
                Theme.of(tester.element(cardFinder)).colorScheme.surface,
              );
              expect(contrast(title, background), greaterThanOrEqualTo(4.5));
              expect(contrast(metadata, background), greaterThanOrEqualTo(4.5));
              expect(
                contrast(title, background),
                greaterThan(contrast(metadata, background)),
              );
            }
            expect(tester.takeException(), isNull);
          }
        },
      );
    }
    testWidgets(
      'theme foregrounds remain readable even when custom monochrome colors are low contrast',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1440, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        for (final foreground in [
          const Color(0xffaaaaaa),
          const Color(0xff747474),
        ]) {
          final scheme = ColorScheme.fromSeed(seedColor: Colors.purple)
              .copyWith(
                surface: Colors.white,
                primaryContainer: Colors.white,
                secondaryContainer: Colors.white,
                onSurface: foreground,
                onSurfaceVariant: foreground,
              );
          await tester.pumpWidget(
            _gridHarness(
              platform: TargetPlatform.windows,
              colorScheme: scheme,
              periodTimes: slots,
              timetable: _timetableWithCourses([
                _course(
                  id: 'custom-theme',
                  weekday: 1,
                  startMinutes: 480,
                  endMinutes: 600,
                  title: 'Course',
                  location: 'Location',
                  teacher: 'Teacher',
                ),
              ]),
            ),
          );
          await tester.pumpAndSettle();
          for (final text in ['Course', 'Location', 'Teacher']) {
            final color = tester
                .widget<Text>(within('custom-theme', find.text(text)))
                .style!
                .color!;
            expect(contrast(color, Colors.white), greaterThanOrEqualTo(4.5));
          }
          expect(tester.takeException(), isNull);
        }
      },
    );
    testWidgets(
      'desktop gutters separate adjacent courses without shifting their time hit boundaries',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1440, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          _gridHarness(
            platform: TargetPlatform.windows,
            periodTimes: slots,
            fitVisibleDaysToWidth: true,
            timetable: _timetableWithCourses([
              _course(id: 'a', weekday: 1, startMinutes: 480, endMinutes: 540),
              _course(id: 'b', weekday: 1, startMinutes: 540, endMinutes: 600),
              _course(id: 'c', weekday: 2, startMinutes: 480, endMinutes: 540),
            ]),
          ),
        );
        await tester.pumpAndSettle();
        Rect rect(String prefix, String id) => tester.getRect(
          find.byKey(ValueKey('timetable-course-$prefix-$id')),
        );
        expect(
          rect('visual', 'c').left - rect('visual', 'a').right,
          closeTo(8, .01),
        );
        expect(
          rect('visual', 'b').top - rect('visual', 'a').bottom,
          closeTo(8, .01),
        );
        expect(rect('hit', 'b').top, closeTo(rect('hit', 'a').bottom, .01));
        expect(rect('visual', 'a').top, closeTo(rect('hit', 'a').top, .01));
        expect(
          rect('visual', 'b').bottom,
          closeTo(rect('hit', 'b').bottom, .01),
        );
        expect(tester.takeException(), isNull);
      },
    );
    RenderParagraph paragraph(WidgetTester tester, Finder text) =>
        tester.renderObject<RenderParagraph>(
          find.descendant(of: text, matching: find.byType(RichText)),
        );
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets(
        'uses available height for every field beyond two lines at $scale',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(1440, 900));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          // This case isolates the vertical line budget. Oversized Latin words
          // have separate wrapping/truncation coverage at narrow widths.
          const title = '物理实验\nMath\nLab';
          const location = '辽河路校区\n玉衡 B112\n理学院物理\n实验室';
          const teacher = '范玉乔\nTutor';
          await tester.pumpWidget(
            _gridHarness(
              platform: TargetPlatform.windows,
              textScale: scale,
              fitVisibleDaysToWidth: true,
              periodTimes: slots,
              timetable: _timetableWithCourses([
                _course(
                  id: 'full',
                  weekday: 1,
                  startMinutes: 480,
                  endMinutes: 720,
                  title: title,
                  location: location,
                  teacher: teacher,
                  periods: [1, 2, 3, 4],
                ),
              ]),
            ),
          );
          await tester.pumpAndSettle();
          final card = tester.getRect(
            find.byKey(const ValueKey('timetable-course-visual-full')),
          );
          for (final value in [title, location, teacher]) {
            final finder = within('full', find.text(value));
            final render = paragraph(tester, finder);
            expect(render.didExceedMaxLines, isFalse, reason: value);
            final painter = TextPainter(
              text: render.text,
              textDirection: render.textDirection,
              textScaler: render.textScaler,
              locale: render.locale,
            )..layout(maxWidth: render.size.width);
            expect(render.size.height, closeTo(painter.height, .01));
            painter.dispose();
            expect(
              tester.getRect(finder).bottom,
              lessThanOrEqualTo(card.bottom - 12 + .1),
            );
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
    testWidgets(
      'naturally wrapped long locations are fully visible when the card has room',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        for (final direction in TextDirection.values) {
          const location = '辽河路校区 玉衡 B112(理学院物理实验教学中心，实验课程专用教室)';
          await tester.pumpWidget(
            _gridHarness(
              platform: TargetPlatform.windows,
              textScale: 1.3,
              textDirection: direction,
              fitVisibleDaysToWidth: true,
              periodTimes: slots,
              timetable: _timetableWithCourses([
                _course(
                  id: 'wrapped',
                  weekday: 1,
                  startMinutes: 480,
                  endMinutes: 720,
                  title: '物理实验A(下)',
                  location: location,
                  teacher: '范玉乔',
                  periods: [1, 2, 3, 4],
                ),
              ]),
            ),
          );
          await tester.pumpAndSettle();
          final finder = within('wrapped', find.text(location));
          final render = paragraph(tester, finder);
          final painter = TextPainter(
            text: render.text,
            textDirection: render.textDirection,
            textScaler: render.textScaler,
            locale: render.locale,
          )..layout(maxWidth: render.size.width);
          expect(painter.computeLineMetrics().length, greaterThan(2));
          expect(render.didExceedMaxLines, isFalse);
          expect(render.size.height, closeTo(painter.height, .01));
          painter.dispose();
          expect(within('wrapped', find.text('范玉乔')), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      },
    );
    testWidgets(
      'truncates only to the height budget and keeps teacher, expands on taller course',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1440, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        const title = '物理实验A(下)';
        final location = List.generate(12, (i) => '实验室 $i').join('\n');
        Future<void> pump(int end) async {
          await tester.pumpWidget(
            _gridHarness(
              platform: TargetPlatform.windows,
              fitVisibleDaysToWidth: true,
              periodTimes: slots,
              timetable: _timetableWithCourses([
                _course(
                  id: 'grow',
                  weekday: 1,
                  startMinutes: 480,
                  endMinutes: end,
                  title: title,
                  location: location,
                  teacher: '范玉乔',
                ),
              ]),
            ),
          );
          await tester.pumpAndSettle();
        }

        await pump(600);
        final finder = within('grow', find.text(location));
        final shortParagraph = paragraph(tester, finder);
        expect(shortParagraph.didExceedMaxLines, isTrue);
        expect(shortParagraph.maxLines, greaterThan(2));
        final teacherFinder = within('grow', find.text('范玉乔'));
        expect(teacherFinder, findsOneWidget);
        expect(paragraph(tester, teacherFinder).didExceedMaxLines, isFalse);
        final rect = tester.getRect(
          find.byKey(const ValueKey('timetable-course-visual-grow')),
        );
        expect(
          tester.getRect(teacherFinder).bottom,
          lessThanOrEqualTo(rect.bottom - 12 + .1),
        );
        // No full extra line should fit in the deliberately truncated field.
        final extra = TextPainter(
          text: shortParagraph.text,
          textDirection: shortParagraph.textDirection,
          textScaler: shortParagraph.textScaler,
          locale: shortParagraph.locale,
          maxLines: shortParagraph.maxLines! + 1,
          ellipsis: '…',
        )..layout(maxWidth: shortParagraph.size.width);
        expect(
          extra.height - shortParagraph.size.height,
          greaterThan(
            rect.bottom - 12 - tester.getRect(teacherFinder).bottom + .01,
          ),
        );
        extra.dispose();
        await pump(720);
        expect(paragraph(tester, finder).didExceedMaxLines, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
    for (final brightness in Brightness.values) {
      testWidgets(
        'narrow cards, missing fields and conflicts remain bounded in $brightness',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(800, 750));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          for (final scale in [1.0, 1.3, 2.0]) {
            await tester.pumpWidget(
              _gridHarness(
                platform: TargetPlatform.windows,
                brightness: brightness,
                textScale: scale,
                periodTimes: slots,
                fitVisibleDaysToWidth: true,
                timetable: _timetableWithCourses([
                  _course(
                    id: 'short',
                    weekday: 1,
                    startMinutes: 480,
                    endMinutes: 490,
                    title: 'Numerical Methods',
                    location: 'Computer lab B308',
                    teacher: 'Xiao Shasha',
                  ),
                  _course(
                    id: 'empty',
                    weekday: 2,
                    startMinutes: 480,
                    endMinutes: 600,
                    title: 'Title only',
                  ),
                  _course(
                    id: 'long',
                    weekday: 3,
                    startMinutes: 480,
                    endMinutes: 600,
                    title: '很长的课程名称 Long course title ' * 5,
                    location: 'Campus building B308 Computer Lab ' * 5,
                    teacher: 'Teacher name ' * 5,
                  ),
                  _course(
                    id: 'conflict1',
                    weekday: 4,
                    startMinutes: 480,
                    endMinutes: 600,
                    title: 'Conflict one',
                    location: 'B308',
                    teacher: 'Teacher',
                  ),
                  _course(
                    id: 'conflict2',
                    weekday: 4,
                    startMinutes: 480,
                    endMinutes: 600,
                    title: 'Conflict two',
                  ),
                ]),
              ),
            );
            await tester.pumpAndSettle();
            for (final id in ['short', 'empty', 'long', 'conflict1']) {
              final card = tester.getRect(
                find.byKey(ValueKey('timetable-course-visual-$id')),
              );
              for (final e in within(id, find.byType(Text)).evaluate()) {
                final r = tester.getRect(find.byWidget(e.widget));
                expect(r.bottom, lessThanOrEqualTo(card.bottom + .1));
                expect(r.right, lessThanOrEqualTo(card.right + .1));
                for (final badge in within(
                  id,
                  find.byIcon(Icons.layers_outlined),
                ).evaluate()) {
                  expect(
                    r.overlaps(
                      tester.getRect(find.byWidget(badge.widget)).inflate(3),
                    ),
                    isFalse,
                  );
                }
              }
            }
            expect(tester.takeException(), isNull);
          }
        },
      );
    }
  });

  for (final scenario in [
    (scale: 1.8, size: const Size(430, 776), maxHeight: 120.0),
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
    expect(tester.widget<Card>(visual).shape, isA<RoundedRectangleBorder>());
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
    expect(
      find.bySemanticsLabel('Legacy course, Monday, Week 1, 09:00–09:45'),
      findsOneWidget,
    );
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

  testWidgets('fit mode divides readable columns across a wide viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 640));
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

  testWidgets('compact fitted week ellipsizes an oversized course word', (
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
    expect(titleText.maxLines, 1);
    expect(titleText.softWrap, isTrue);
    expect(titleText.overflow, TextOverflow.ellipsis);
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: title, matching: find.byType(RichText)),
    );
    expect(paragraph.didExceedMaxLines, isTrue);
    expect(paragraph.text.toPlainText(), 'Advanced Mathematics');
    expect(
      tester.getRect(title).bottom,
      lessThanOrEqualTo(tester.getRect(visual).bottom),
    );
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

  testWidgets(
    'turning on fit mode clears horizontal offsets at the current width',
    (tester) async {
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
                    colorfulCourseTextColorMode:
                        colorfulCourseTextColorModeAuto,
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
      expect(fitBody.position.maxScrollExtent, closeTo(0, .01));
      expect(fitHeader.position.maxScrollExtent, closeTo(0, .01));
      expect(fitBody.position.pixels, closeTo(0, .01));
      expect(fitHeader.position.pixels, closeTo(0, .01));
      await tester.binding.setSurfaceSize(const Size(1000, 640));
      await tester.pumpAndSettle();
      expect(fitBody.position.maxScrollExtent, closeTo(0, 0.01));
      expect(fitHeader.position.maxScrollExtent, closeTo(0, 0.01));
      expect(fitBody.position.pixels, closeTo(0, 0.01));
      expect(fitHeader.position.pixels, closeTo(0, 0.01));

      updateGrid(() => fitVisibleDaysToWidth = false);
      await tester.binding.setSurfaceSize(const Size(360, 640));
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
    },
  );

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
    expect(headerScroll.position.maxScrollExtent, closeTo(0, .01));
    expect(bodyScroll.position.maxScrollExtent, closeTo(0, .01));
    expect(
      headerScroll.position.pixels,
      closeTo(bodyScroll.position.pixels, .5),
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('timetable-day-column-1')))
          .width,
      closeTo(
        tester
                .getSize(
                  find.byKey(
                    const ValueKey('timetable-grid-horizontal-scroll'),
                  ),
                )
                .width /
            7,
        .01,
      ),
    );
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
      'first-short, Monday, Week 1, 08:00–08:10',
      'second-short, Monday, Week 1, 08:10–08:20',
    ]) {
      final node = tester.getSemantics(find.bySemanticsLabel(label));
      expect(node.rect.height, greaterThanOrEqualTo(48));
      expect(node.getSemanticsData().hasAction(ui.SemanticsAction.tap), isTrue);
    }
    semantics.dispose();
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.windows]) {
    testWidgets(
      'short overlapping course hits match their visible cards on $platform',
      (tester) async {
        await tester.binding.setSurfaceSize(
          platform == TargetPlatform.android
              ? const Size(390, 844)
              : const Size(960, 700),
        );
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final tapped = <TimetableCourseTapInfo>[];
        await tester.pumpWidget(
          _gridHarness(
            timetable: _timetableWithCourses([
              _course(
                id: 'earlier-partial',
                weekday: DateTime.monday,
                startMinutes: 480,
                endMinutes: 505,
              ),
              _course(
                id: 'later-partial',
                weekday: DateTime.monday,
                startMinutes: 500,
                endMinutes: 510,
              ),
            ]),
            periodTimes: const [
              CoursePeriodTime(index: 1, startMinutes: 480, endMinutes: 540),
            ],
            visibleWeekdays: const [DateTime.monday],
            showDayHeader: false,
            platform: platform,
            onCourseTap: tapped.add,
          ),
        );
        await tester.pumpAndSettle();
        Rect visual(String id) =>
            tester.getRect(find.byKey(ValueKey('timetable-course-visual-$id')));
        Rect hit(String id) =>
            tester.getRect(find.byKey(ValueKey('timetable-course-hit-$id')));
        expect(hit('earlier-partial'), visual('earlier-partial'));
        expect(hit('later-partial'), visual('later-partial'));
        await tester.tapAt(
          Offset(
            visual('earlier-partial').center.dx,
            visual('earlier-partial').top + 14,
          ),
        );
        await tester.pump();
        await tester.tapAt(visual('later-partial').center);
        await tester.pump();
        expect(tapped.map((info) => info.course.id), [
          'earlier-partial',
          'later-partial',
        ]);
        expect(tapped.first.isFullConflict, isFalse);
        expect(tapped.first.conflictKey, isNull);
        expect(tapped.first.courses.map((course) => course.id), [
          'earlier-partial',
          'later-partial',
        ]);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'collapsed occupied gaps keep both custom and period courses reachable on $platform',
      (tester) async {
        await tester.binding.setSurfaceSize(
          platform == TargetPlatform.android
              ? const Size(390, 844)
              : const Size(960, 700),
        );
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final semantics = tester.ensureSemantics();
        final tapped = <TimetableCourseTapInfo>[];
        await tester.pumpWidget(
          _gridHarness(
            timetable: _timetableWithCourses([
              _course(
                id: 'gap-custom',
                weekday: DateTime.monday,
                startMinutes: 560,
                endMinutes: 580,
                periods: const [],
              ),
              _course(
                id: 'after-gap-period',
                weekday: DateTime.monday,
                startMinutes: 600,
                endMinutes: 660,
                periods: const [2],
              ),
            ]),
            periodTimes: const [
              CoursePeriodTime(index: 1, startMinutes: 480, endMinutes: 540),
              CoursePeriodTime(index: 2, startMinutes: 600, endMinutes: 660),
            ],
            visibleWeekdays: const [DateTime.monday],
            showDayHeader: false,
            preserveGaps: false,
            platform: platform,
            onCourseTap: tapped.add,
          ),
        );
        await tester.pumpAndSettle();
        final gap = find.byKey(
          const ValueKey('timetable-course-visual-gap-custom'),
        );
        final period = find.byKey(
          const ValueKey('timetable-course-visual-after-gap-period'),
        );
        expect(
          tester.getRect(gap).bottom,
          lessThan(tester.getRect(period).top),
        );
        expect(tester.getSize(gap).height, greaterThan(0));
        expect(find.byIcon(Icons.layers_outlined), findsNothing);
        await tester.tap(
          find.byKey(const ValueKey('timetable-course-hit-gap-custom')),
        );
        await tester.pump();
        await tester.tap(
          find.byKey(const ValueKey('timetable-course-hit-after-gap-period')),
        );
        await tester.pump();
        expect(tapped.map((info) => info.course.id), [
          'gap-custom',
          'after-gap-period',
        ]);
        expect(
          (tapped.first.course.startMinutes, tapped.first.course.endMinutes),
          (560, 580),
        );
        expect(tapped.every((info) => info.courses.length == 1), isTrue);
        expect(tapped.every((info) => info.conflictKey == null), isTrue);
        expect(
          find.bySemanticsLabel('gap-custom, Monday, Week 1, 09:20–09:40'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );
  }

  testWidgets('adjacent course cards keep a visible vertical gap', (
    tester,
  ) async {
    final tappedIds = <String>[];
    final timetable = _timetableWithCourses([
      _course(
        id: 'first-adjacent',
        weekday: DateTime.monday,
        startMinutes: 480,
        endMinutes: 525,
      ),
      _course(
        id: 'second-adjacent',
        weekday: DateTime.monday,
        startMinutes: 525,
        endMinutes: 570,
      ),
    ]);

    await tester.pumpWidget(
      _gridHarness(
        timetable: timetable,
        periodTimes: const [
          CoursePeriodTime(index: 1, startMinutes: 480, endMinutes: 570),
        ],
        visibleWeekdays: const [DateTime.monday],
        showDayHeader: false,
        preserveGaps: false,
        onCourseTap: (info) => tappedIds.add(info.course.id),
      ),
    );
    await tester.pumpAndSettle();

    final firstVisual = tester.getRect(
      find.byKey(const ValueKey('timetable-course-visual-first-adjacent')),
    );
    final secondVisual = tester.getRect(
      find.byKey(const ValueKey('timetable-course-visual-second-adjacent')),
    );
    expect(secondVisual.top - firstVisual.bottom, greaterThanOrEqualTo(3));

    await tester.tap(
      find.byKey(const ValueKey('timetable-course-hit-first-adjacent')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('timetable-course-hit-second-adjacent')),
    );
    await tester.pump();
    expect(tappedIds, const ['first-adjacent', 'second-adjacent']);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'course ink paints hover, press and keyboard focus with activation',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(960, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final previousHighlightStrategy = FocusManager.instance.highlightStrategy;
      addTearDown(
        () =>
            FocusManager.instance.highlightStrategy = previousHighlightStrategy,
      );
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTouch;
      final boundaryKey = GlobalKey();
      final tappedIds = <String>[];
      final hit = find.byKey(
        const ValueKey('timetable-course-hit-ink-feedback'),
      );
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: _gridHarness(
            platform: TargetPlatform.windows,
            timetable: _timetableWithCourses([
              _course(
                id: 'ink-feedback',
                weekday: 1,
                startMinutes: 480,
                endMinutes: 600,
                title: 'Course',
              ),
            ]),
            periodTimes: const [
              CoursePeriodTime(index: 1, startMinutes: 480, endMinutes: 720),
            ],
            visibleWeekdays: const [1],
            showDayHeader: false,
            fitVisibleDaysToWidth: true,
            onCourseTap: (info) => tappedIds.add(info.course.id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final hitRect = tester.getRect(hit);

      Future<List<int>> pixels() async => (await tester.runAsync(() async {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        try {
          final data = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          final bytes = data.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          );
          final region = <int>[];
          for (var y = hitRect.top.ceil(); y < hitRect.bottom.floor(); y++) {
            region.addAll(
              bytes.sublist(
                (y * image.width + hitRect.left.ceil()) * 4,
                (y * image.width + hitRect.right.floor()) * 4,
              ),
            );
          }
          return region;
        } finally {
          image.dispose();
        }
      }))!;

      final before = await pixels();
      final mouse = await tester.createGesture(
        kind: ui.PointerDeviceKind.mouse,
        pointer: 7,
      );
      await mouse.addPointer(location: const Offset(2, 690));
      try {
        await mouse.moveTo(hitRect.center);
        await tester.pumpAndSettle();
        expect(
          listEquals(await pixels(), before),
          isFalse,
          reason: 'Hover feedback must be painted above the course.',
        );
        await mouse.moveTo(const Offset(2, 690));
        await tester.pumpAndSettle();
        expect(listEquals(await pixels(), before), isTrue);

        final press = await tester.startGesture(hitRect.center);
        late List<int> pressed;
        try {
          await tester.pump(kPressTimeout);
          await tester.pump(const Duration(milliseconds: 150));
          pressed = await pixels();
        } finally {
          await press.up();
        }
        expect(
          listEquals(pressed, before),
          isFalse,
          reason: 'A touch press must still paint its ink effect.',
        );
        await tester.pumpAndSettle();
        expect(tappedIds, ['ink-feedback']);

        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.alwaysTraditional;
        final gesture = find
            .descendant(of: hit, matching: find.byType(GestureDetector))
            .last;
        final focus = Focus.of(tester.element(gesture));
        focus.requestFocus();
        await tester.pumpAndSettle();
        expect(focus.hasFocus, isTrue);
        expect(
          listEquals(await pixels(), before),
          isFalse,
          reason: 'Keyboard users must see which course has focus.',
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(tappedIds, ['ink-feedback', 'ink-feedback']);
        expect(tester.getRect(hit), hitRect);
        expect(tester.takeException(), isNull);
      } finally {
        await mouse.removePointer();
        FocusManager.instance.primaryFocus?.unfocus();
        FocusManager.instance.highlightStrategy = previousHighlightStrategy;
        await tester.pumpAndSettle();
      }
    },
  );

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

  testWidgets('empty-slot long press has a weekday and add-course label', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final emptySlots = <TimetableEmptySlotTapInfo>[];
    final timetable = _timetableWithCourses([
      _course(
        id: 'separate-course',
        weekday: DateTime.monday,
        startMinutes: 550,
        endMinutes: 610,
      ),
    ]);
    const periods = [
      CoursePeriodTime(index: 1, startMinutes: 480, endMinutes: 540),
      CoursePeriodTime(index: 2, startMinutes: 550, endMinutes: 610),
    ];
    await tester.pumpWidget(
      _gridHarness(
        timetable: timetable,
        periodTimes: periods,
        visibleWeekdays: const [DateTime.monday],
        onEmptySlotTap: emptySlots.add,
      ),
    );
    await tester.pumpAndSettle();

    final node = tester.getSemantics(
      find.bySemanticsLabel('Monday, Add course'),
    );
    expect(
      node.getSemanticsData().hasAction(ui.SemanticsAction.longPress),
      isTrue,
    );
    expect(
      find.bySemanticsLabel('separate-course, Monday, Week 1, 09:10–10:10'),
      findsOneWidget,
    );
    node.owner!.performAction(node.id, ui.SemanticsAction.longPress);
    await tester.pump();
    expect(emptySlots.single.weekday, DateTime.monday);
    expect(emptySlots.single.periods, isNotEmpty);

    await tester.pumpWidget(
      _gridHarness(
        timetable: timetable,
        periodTimes: periods,
        visibleWeekdays: const [DateTime.monday],
        enableLongPressAdd: false,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Monday, Add course'), findsNothing);
    expect(
      find.bySemanticsLabel('separate-course, Monday, Week 1, 09:10–10:10'),
      findsOneWidget,
    );
    semantics.dispose();
  });

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
    final column = tester.getRect(
      find.byKey(const ValueKey('timetable-day-column-long-press-1')),
    );
    final anchor = emptySlots.single.anchorRect!;
    expect(anchor.left, column.left);
    expect(anchor.width, column.width);
    expect(anchor.height, greaterThan(1));
    expect(column.contains(anchor.center), isTrue);
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
      find.bySemanticsLabel(
        'Advanced Physics, Monday, Week 1, 08:00–08:10, Location: Lab 3, Teacher: Dr. Chen',
      ),
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
