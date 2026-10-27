import 'dart:ui' as ui;

import 'package:flutter/semantics.dart' show SemanticsNode;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/theme/timetable_contrast.dart';
import 'package:sked/widgets/timetable_entry.dart';
import 'package:sked/widgets/timetable_grid.dart';

CourseItem _course({
  String id = 'course',
  int start = 480,
  int duration = 90,
  List<int> weeks = const [1],
  int weekday = DateTime.monday,
}) => CourseItem(
  id: id,
  name: 'Physics',
  location: 'Lab 3',
  teacher: 'Dr. Chen',
  dayOfWeek: weekday,
  semesterWeeks: weeks,
  periods: const [1],
  startMinutes: start,
  endMinutes: start + duration,
  timeRange: buildTimeRange(start, start + duration),
  credit: 0,
  remarks: '',
  customFields: const {},
);

Widget _grid({
  required List<CourseItem> courses,
  required String locale,
  List<TimetableEntry>? entries,
  ValueChanged<TimetableCourseTapInfo>? onCourseTap,
  ValueChanged<TimetableEntry>? onEntryTap,
  TargetPlatform platform = TargetPlatform.android,
  Brightness brightness = Brightness.light,
  int? courseColor,
  bool showDayHeader = false,
  List<int> visibleWeekdays = const [DateTime.monday],
  bool fitVisibleDaysToWidth = true,
  double textScale = 1,
  TextDirection direction = TextDirection.ltr,
}) => MaterialApp(
  theme: ThemeData(platform: platform, brightness: brightness),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: TextScaler.linear(textScale)),
    child: Directionality(textDirection: direction, child: child!),
  ),
  home: Scaffold(
    body: TimetableGrid(
      timetable: TimetableData(
        id: 'accessibility',
        config: TimetableConfig(
          name: 'Timetable',
          startDate: DateTime(2026, 1, 5),
          totalWeeks: 18,
          periodTimeSetId: defaultPeriodTimeSetId,
        ),
        courses: courses,
      ),
      entries: entries,
      periodTimes: const [
        CoursePeriodTime(index: 1, startMinutes: 480, endMinutes: 720),
      ],
      weekDateStart: DateTime(2026, 1, 5),
      selectedWeek: 1,
      realCurrentWeek: 1,
      localeCode: locale,
      preserveGaps: true,
      showPastEndedCourses: true,
      showFutureCourses: true,
      showGridLines: true,
      showDayHeader: showDayHeader,
      fitVisibleDaysToWidth: fitVisibleDaysToWidth,
      visibleWeekdays: visibleWeekdays,
      displayedCourseIdForConflict: (_) => courses.first.id,
      onCourseTap: onCourseTap ?? (_) {},
      onEntryTap: onEntryTap,
      onEmptySlotTap: (_) {},
      themeColorMode: courseColor == null
          ? themeColorModeSingle
          : themeColorModeColorful,
      courseNameColorValues: {'Physics': ?courseColor},
      colorfulCourseTextColorMode: colorfulCourseTextColorModeAuto,
      liveCourseOutlineEnabled: false,
      liveCourseOutlineMode: liveCourseOutlineModeCurrentOrNext,
      liveCourseOutlineColorValue: 0xff6750a4,
      liveCourseOutlineWidth: 2,
    ),
  ),
);

Finder _courseAnnotation(String label) => find.byWidgetPredicate(
  (widget) => widget is Semantics && widget.properties.label == label,
);

// The annotation's nominal 48dp rect is insufficient: the old day-column
// hardEdge Stack and scrolling ancestors can clip it down to a narrow strip.
Rect _effectiveSemanticRect(WidgetTester tester, Finder annotation) {
  final node = tester.getSemantics(annotation);
  final render = tester.renderObject<RenderBox>(annotation);
  var rect = node.rect;
  for (final clip in [node.parentPaintClipRect, node.parentSemanticsClipRect]) {
    if (clip != null) rect = rect.intersect(clip);
  }
  rect = MatrixUtils.transformRect(render.getTransformTo(null), rect);
  RenderObject child = render;
  while (child.parent != null) {
    final parent = child.parent!;
    final clip = parent.describeApproximatePaintClip(child);
    if (clip != null) {
      rect = rect.intersect(
        MatrixUtils.transformRect(parent.getTransformTo(null), clip),
      );
    }
    child = parent;
  }
  return rect;
}

void _expectAccessibleRect(
  WidgetTester tester,
  Finder annotation,
  Rect viewport,
) {
  final node = tester.getSemantics(annotation);
  expect(node.getSemanticsData().flagsCollection.isHidden, isFalse);
  final effective = _effectiveSemanticRect(tester, annotation);
  expect(effective.width, greaterThanOrEqualTo(48 - .001));
  expect(effective.height, greaterThanOrEqualTo(48 - .001));
  expect(effective.left, greaterThanOrEqualTo(viewport.left - .001));
  expect(effective.top, greaterThanOrEqualTo(viewport.top - .001));
  expect(effective.right, lessThanOrEqualTo(viewport.right + .001));
  expect(effective.bottom, lessThanOrEqualTo(viewport.bottom + .001));
}

SemanticsNode _scrollAncestor(SemanticsNode node, ui.SemanticsAction action) {
  var parent = node.parent;
  while (parent != null) {
    if (parent.getSemanticsData().hasAction(action)) return parent;
    parent = parent.parent;
  }
  throw TestFailure('No scroll ancestor handles $action for ${node.label}');
}

Future<void> _semanticScrollToEdge(
  WidgetTester tester,
  SemanticsNode parent,
  ui.SemanticsAction action,
) async {
  for (var page = 0; page < 10; page++) {
    if (!parent.getSemanticsData().hasAction(action)) return;
    parent.owner!.performAction(parent.id, action);
    await tester.pumpAndSettle();
  }
  fail('Semantic scrolling did not reach the edge');
}

void main() {
  for (final width in [320.0, 393.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final direction in TextDirection.values) {
        testWidgets(
          'touch week semantics survive real clipping at $width ${scale}x $direction',
          (tester) async {
            await tester.binding.setSurfaceSize(Size(width, 800));
            addTearDown(() => tester.binding.setSurfaceSize(null));
            final handle = tester.ensureSemantics();
            try {
              final courses = [
                for (var day = 1; day <= 7; day++)
                  _course(id: 'day-$day', weekday: day, duration: 5),
                _course(id: 'next', start: 485, duration: 5),
              ];
              final opened = <String>[];
              await tester.pumpWidget(
                _grid(
                  courses: courses,
                  locale: 'en',
                  showDayHeader: true,
                  visibleWeekdays: const [1, 2, 3, 4, 5, 6, 7],
                  textScale: scale,
                  direction: direction,
                  onCourseTap: (info) => opened.add(info.course.id),
                ),
              );
              await tester.pumpAndSettle();
              final body = tester.getRect(
                find.byKey(const ValueKey('timetable-grid-vertical-scroll')),
              );
              final header = tester.getRect(
                find.byKey(
                  const ValueKey('timetable-day-header-horizontal-scroll'),
                ),
              );
              final week = Rect.fromLTRB(
                header.left,
                body.top,
                header.right,
                body.bottom,
              );
              final localizations = MaterialLocalizations.of(
                tester.element(find.byType(TimetableGrid)),
              );
              for (var day = 1; day <= 7; day++) {
                final column = tester.getRect(
                  find.byKey(ValueKey('timetable-day-column-$day')),
                );
                expect(column.width, closeTo(week.width / 7, .001));
                final dayLabel = localizations.formatFullDate(
                  DateTime(2026, 1, 4 + day),
                );
                final annotation = _courseAnnotation(dayLabel);
                expect(annotation, findsOneWidget);
                _expectAccessibleRect(tester, annotation, header);
                // Headers expose date information and do not invent a tap action.
                expect(
                  tester
                      .getSemantics(annotation)
                      .getSemanticsData()
                      .hasAction(ui.SemanticsAction.tap),
                  isFalse,
                );
              }
              for (final course in courses) {
                final weekday = const [
                  'Monday',
                  'Tuesday',
                  'Wednesday',
                  'Thursday',
                  'Friday',
                  'Saturday',
                  'Sunday',
                ][course.dayOfWeek - 1];
                final label =
                    'Physics, $weekday, Week 1, ${formatMinutes(course.startMinutes)}–${formatMinutes(course.endMinutes)}, Location: Lab 3, Teacher: Dr. Chen';
                final annotation = _courseAnnotation(label);
                expect(annotation, findsOneWidget);
                _expectAccessibleRect(tester, annotation, week);
                final node = tester.getSemantics(annotation);
                node.owner!.performAction(node.id, ui.SemanticsAction.tap);
                expect(opened.last, course.id);
                final hit = find.byKey(
                  ValueKey('timetable-course-hit-${course.id}'),
                );
                expect(tester.getSize(hit).width, lessThan(48));
                await tester.tap(hit);
                expect(opened.last, course.id);
              }
              final first = tester.getRect(
                find.byKey(const ValueKey('timetable-course-hit-day-1')),
              );
              final next = tester.getRect(
                find.byKey(const ValueKey('timetable-course-hit-next')),
              );
              expect(first.height, lessThan(48));
              expect(first.bottom, lessThanOrEqualTo(next.top));
              expect(opened.length, courses.length * 2);
              expect(tester.takeException(), isNull);
            } finally {
              handle.dispose();
            }
          },
        );
      }
    }
  }

  for (final direction in TextDirection.values) {
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      testWidgets(
        'focused course reaches offscreen courses through semantic scrolling $direction $platform',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(320, 190));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final handle = tester.ensureSemantics();
          try {
            TimetableCourseTapInfo? opened;
            await tester.pumpWidget(
              _grid(
                courses: [
                  _course(id: 'top', duration: 5),
                  _course(id: 'bottom', weekday: 7, start: 715, duration: 5),
                ],
                locale: 'en',
                platform: platform,
                showDayHeader: true,
                visibleWeekdays: const [1, 2, 3, 4, 5, 6, 7],
                fitVisibleDaysToWidth: false,
                direction: direction,
                onCourseTap: (value) => opened = value,
              ),
            );
            await tester.pumpAndSettle();
            const topLabel =
                'Physics, Monday, Week 1, 08:00–08:05, Location: Lab 3, Teacher: Dr. Chen';
            const bottomLabel =
                'Physics, Sunday, Week 1, 11:55–12:00, Location: Lab 3, Teacher: Dr. Chen';
            final forward = direction == TextDirection.ltr
                ? ui.SemanticsAction.scrollLeft
                : ui.SemanticsAction.scrollRight;
            final backward = direction == TextDirection.ltr
                ? ui.SemanticsAction.scrollRight
                : ui.SemanticsAction.scrollLeft;
            final top = tester.getSemantics(_courseAnnotation(topLabel));
            final horizontal = _scrollAncestor(top, forward);
            final vertical = _scrollAncestor(top, ui.SemanticsAction.scrollUp);
            expect(horizontal.getSemanticsData().scrollPosition, 0);
            expect(vertical.getSemanticsData().scrollPosition, 0);
            await _semanticScrollToEdge(tester, horizontal, forward);
            await _semanticScrollToEdge(
              tester,
              vertical,
              ui.SemanticsAction.scrollUp,
            );
            expect(_courseAnnotation(topLabel), findsNothing);
            final bottom = tester.getSemantics(_courseAnnotation(bottomLabel));
            bottom.owner!.performAction(bottom.id, ui.SemanticsAction.tap);
            expect(opened?.course.id, 'bottom');
            expect(
              horizontal.getSemanticsData().scrollPosition,
              horizontal.getSemanticsData().scrollExtentMax,
            );
            expect(
              vertical.getSemanticsData().scrollPosition,
              vertical.getSemanticsData().scrollExtentMax,
            );
            await _semanticScrollToEdge(
              tester,
              _scrollAncestor(bottom, backward),
              backward,
            );
            await _semanticScrollToEdge(
              tester,
              vertical,
              ui.SemanticsAction.scrollDown,
            );
            expect(horizontal.getSemanticsData().scrollPosition, 0);
            expect(vertical.getSemanticsData().scrollPosition, 0);
            final restored = tester.getSemantics(_courseAnnotation(topLabel));
            restored.owner!.performAction(restored.id, ui.SemanticsAction.tap);
            expect(opened?.course.id, 'top');
            expect(tester.takeException(), isNull);
          } finally {
            handle.dispose();
          }
        },
      );
    }
  }

  for (final direction in TextDirection.values) {
    testWidgets(
      'touch targets stay inside the visible week while scrolling $direction',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 190));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final handle = tester.ensureSemantics();
        try {
          TimetableCourseTapInfo? opened;
          await tester.pumpWidget(
            _grid(
              courses: [
                _course(id: 'top', duration: 5),
                _course(id: 'bottom', weekday: 7, start: 715, duration: 5),
              ],
              locale: 'en',
              showDayHeader: true,
              visibleWeekdays: const [1, 2, 3, 4, 5, 6, 7],
              fitVisibleDaysToWidth: false,
              direction: direction,
              onCourseTap: (value) => opened = value,
            ),
          );
          await tester.pumpAndSettle();
          final horizontal = tester
              .state<ScrollableState>(
                find.descendant(
                  of: find.byKey(
                    const ValueKey('timetable-grid-horizontal-scroll'),
                  ),
                  matching: find.byType(Scrollable),
                ),
              )
              .position;
          final vertical = tester
              .state<ScrollableState>(
                find.descendant(
                  of: find.byKey(
                    const ValueKey('timetable-grid-vertical-scroll'),
                  ),
                  matching: find.byWidgetPredicate(
                    (widget) =>
                        widget is Scrollable &&
                        widget.axisDirection == AxisDirection.down,
                  ),
                ),
              )
              .position;
          const topLabel =
              'Physics, Monday, Week 1, 08:00–08:05, Location: Lab 3, Teacher: Dr. Chen';
          const bottomLabel =
              'Physics, Sunday, Week 1, 11:55–12:00, Location: Lab 3, Teacher: Dr. Chen';
          expect(_courseAnnotation(bottomLabel), findsNothing);
          // Leave only a small part of the first day and short course visible.
          horizontal.jumpTo(20);
          vertical.jumpTo(4);
          await tester.pumpAndSettle();
          final body = tester.getRect(
            find.byKey(const ValueKey('timetable-grid-vertical-scroll')),
          );
          final header = tester.getRect(
            find.byKey(
              const ValueKey('timetable-day-header-horizontal-scroll'),
            ),
          );
          final week = Rect.fromLTRB(
            header.left,
            body.top,
            header.right,
            body.bottom,
          );
          _expectAccessibleRect(tester, _courseAnnotation(topLabel), week);
          final topNode = tester.getSemantics(_courseAnnotation(topLabel));
          topNode.owner!.performAction(topNode.id, ui.SemanticsAction.tap);
          expect(opened?.course.id, 'top');
          horizontal.jumpTo(horizontal.maxScrollExtent);
          vertical.jumpTo(vertical.maxScrollExtent);
          await tester.pumpAndSettle();
          expect(_courseAnnotation(topLabel), findsNothing);
          _expectAccessibleRect(tester, _courseAnnotation(bottomLabel), week);
          final bottomNode = tester.getSemantics(
            _courseAnnotation(bottomLabel),
          );
          bottomNode.owner!.performAction(
            bottomNode.id,
            ui.SemanticsAction.tap,
          );
          expect(opened?.course.id, 'bottom');
          final sunday = MaterialLocalizations.of(
            tester.element(find.byType(TimetableGrid)),
          ).formatFullDate(DateTime(2026, 1, 11));
          _expectAccessibleRect(tester, _courseAnnotation(sunday), header);
          expect(tester.takeException(), isNull);
        } finally {
          handle.dispose();
        }
      },
    );
  }

  for (final brightness in Brightness.values) {
    for (final courseColor in [0xff000000, 0xff888888, 0xffffffff]) {
      testWidgets(
        'keyboard focus is distinct from hover on $brightness $courseColor',
        (tester) async {
          final previous = FocusManager.instance.highlightStrategy;
          FocusManager.instance.highlightStrategy =
              FocusHighlightStrategy.alwaysTraditional;
          final mouse = await tester.createGesture(
            kind: ui.PointerDeviceKind.mouse,
          );
          try {
            var opened = 0;
            await tester.pumpWidget(
              _grid(
                courses: [_course()],
                locale: 'en',
                platform: TargetPlatform.windows,
                brightness: brightness,
                courseColor: courseColor,
                onCourseTap: (_) => opened++,
              ),
            );
            await tester.pumpAndSettle();
            final hit = find.byKey(
              const ValueKey('timetable-course-hit-course'),
            );
            final focusRing = find.byKey(
              const ValueKey('timetable-course-focus-course'),
            );
            final bounds = tester.getRect(hit);
            await mouse.addPointer(location: bounds.center);
            await mouse.moveTo(bounds.center);
            await tester.pumpAndSettle();
            expect(focusRing, findsNothing);

            final gesture = find
                .descendant(of: hit, matching: find.byType(GestureDetector))
                .last;
            final focus = Focus.of(tester.element(gesture));
            focus.requestFocus();
            await tester.pumpAndSettle();
            expect(focus.hasFocus, isTrue);
            expect(focusRing, findsOneWidget);
            final outer =
                (tester.widget<DecoratedBox>(focusRing).decoration
                            as ShapeDecoration)
                        .shape
                    as OutlinedBorder;
            final inner =
                (tester
                                .widget<DecoratedBox>(
                                  find.byKey(
                                    const ValueKey(
                                      'timetable-course-focus-inner-course',
                                    ),
                                  ),
                                )
                                .decoration
                            as ShapeDecoration)
                        .shape
                    as OutlinedBorder;
            final surface = Theme.of(tester.element(hit)).colorScheme.surface;
            final fill = Color.alphaBlend(
              Color(courseColor).withValues(alpha: .92),
              surface,
            );
            expect(
              renderedTimetableContrast(outer.side.color, surface),
              greaterThanOrEqualTo(3),
            );
            expect(
              [
                outer.side.color,
                inner.side.color,
              ].any((color) => renderedTimetableContrast(color, fill) >= 3),
              isTrue,
            );
            expect(
              renderedTimetableContrast(outer.side.color, inner.side.color),
              21,
            );
            expect(tester.getRect(hit), bounds);
            await tester.sendKeyEvent(LogicalKeyboardKey.space);
            await tester.pumpAndSettle();
            expect(opened, 1);
            focus.unfocus();
            await tester.pumpAndSettle();
            expect(focusRing, findsNothing);
          } finally {
            await mouse.removePointer();
            FocusManager.instance.highlightStrategy = previous;
          }
        },
      );
    }
  }

  for (final locale in ['en', 'zh']) {
    final prefix = locale == 'en'
        ? 'Physics, Monday, Week 1'
        : 'Physics, 星期一, 第 1 周';
    final details = locale == 'en'
        ? 'Location: Lab 3, Teacher: Dr. Chen'
        : '上课地点: Lab 3, 老师姓名: Dr. Chen';
    final inactive = locale == 'en'
        ? 'Not scheduled this week, Weeks 2-3'
        : '本周不上课, 第 2-3 周';

    for (final dense in [false, true]) {
      testWidgets(
        'course labels include the displayed week in $locale dense=$dense',
        (tester) async {
          final semantics = tester.ensureSemantics();
          try {
            TimetableCourseTapInfo? opened;
            await tester.pumpWidget(
              _grid(
                locale: locale,
                courses: [
                  _course(duration: dense ? 5 : 90),
                  if (dense) _course(id: 'next', start: 485, duration: 5),
                ],
                onCourseTap: (info) => opened = info,
              ),
            );
            await tester.pumpAndSettle();
            final time = dense ? '08:00–08:05' : '08:00–09:30';
            final finder = find.bySemanticsLabel('$prefix, $time, $details');
            expect(finder, findsOneWidget);
            final node = tester.getSemantics(finder);
            node.owner!.performAction(node.id, ui.SemanticsAction.tap);
            expect(opened?.course.id, 'course');
            expect(opened?.selectedWeek, 1);
          } finally {
            semantics.dispose();
          }
        },
      );
    }

    for (final viaEntry in [false, true]) {
      testWidgets(
        'inactive course announces actual weeks in $locale entry=$viaEntry',
        (tester) async {
          final semantics = tester.ensureSemantics();
          try {
            final course = _course(weeks: const [2, 3]);
            await tester.pumpWidget(
              _grid(
                locale: locale,
                courses: [course],
                entries: viaEntry
                    ? [courseToEntry(course, isInactive: true)]
                    : null,
                onEntryTap: (_) {},
              ),
            );
            await tester.pumpAndSettle();
            expect(
              find.bySemanticsLabel(
                '$prefix, 08:00–09:30, $details, $inactive',
              ),
              findsOneWidget,
            );
          } finally {
            semantics.dispose();
          }
        },
      );
    }

    testWidgets('conflict count is announced in $locale', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          _grid(
            locale: locale,
            courses: [
              _course(),
              _course(id: 'conflict'),
            ],
          ),
        );
        await tester.pumpAndSettle();
        final conflict = locale == 'en' ? 'Conflicting courses' : '冲突课程';
        expect(
          find.bySemanticsLabel('$prefix, 08:00–09:30, $details, $conflict: 2'),
          findsOneWidget,
        );
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('general entries do not inherit course status in $locale', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        const entry = TimetableEntry(
          id: 'event',
          kind: TimetableEntryKind.generalEvent,
          title: 'Appointment',
          dayOfWeek: DateTime.monday,
          startMinutes: 480,
          endMinutes: 570,
          isInactive: true,
          source: 'event',
        );
        TimetableEntry? opened;
        await tester.pumpWidget(
          _grid(
            locale: locale,
            courses: const [],
            entries: const [entry],
            onEntryTap: (value) => opened = value,
          ),
        );
        await tester.pumpAndSettle();
        final label = locale == 'en'
            ? 'Appointment, Monday, Week 1, 08:00–09:30'
            : 'Appointment, 星期一, 第 1 周, 08:00–09:30';
        final node = tester.getSemantics(find.bySemanticsLabel(label));
        node.owner!.performAction(node.id, ui.SemanticsAction.tap);
        expect(opened, same(entry));
      } finally {
        semantics.dispose();
      }
    });
  }
}
