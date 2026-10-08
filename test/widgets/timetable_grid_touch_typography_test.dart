import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/widgets/timetable_grid.dart';

CourseItem _course({
  String id = 'course',
  String title = '学术写作',
  String location = 'B201',
  String teacher = '郑老师',
  int duration = 45,
  int day = 1,
}) => CourseItem(
  id: id,
  name: title,
  location: location,
  teacher: teacher,
  dayOfWeek: day,
  semesterWeeks: const [1],
  periods: const [1],
  startMinutes: 480,
  endMinutes: 480 + duration,
  timeRange: buildTimeRange(480, 480 + duration),
  credit: 0,
  remarks: '',
  customFields: const {},
);

Widget _grid({
  required List<CourseItem> courses,
  double scale = 1,
  List<int> days = const [1, 2, 3, 4, 5, 6, 7],
  TextDirection direction = TextDirection.ltr,
  ValueChanged<TimetableCourseTapInfo>? onTap,
}) => MaterialApp(
  theme: ThemeData(platform: TargetPlatform.android),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: Directionality(textDirection: direction, child: child!),
  ),
  home: Scaffold(
    body: TimetableGrid(
      timetable: TimetableData(
        id: 'touch-typography',
        config: TimetableConfig(
          name: 'Timetable',
          startDate: DateTime(2026, 1, 5),
          totalWeeks: 18,
          periodTimeSetId: defaultPeriodTimeSetId,
        ),
        courses: courses,
      ),
      periodTimes: const [
        CoursePeriodTime(index: 1, startMinutes: 480, endMinutes: 720),
      ],
      weekDateStart: DateTime(2026, 1, 5),
      selectedWeek: 1,
      realCurrentWeek: 1,
      localeCode: 'zh',
      preserveGaps: true,
      showPastEndedCourses: true,
      showFutureCourses: true,
      showGridLines: true,
      showDayHeader: false,
      fitVisibleDaysToWidth: true,
      visibleWeekdays: days,
      onCourseTap: onTap ?? (_) {},
      displayedCourseIdForConflict: (_) => courses.first.id,
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
);

Finder _visual([String id = 'course']) =>
    find.byKey(ValueKey('timetable-course-visual-$id'));
Finder _textIn(String text, [String id = 'course']) =>
    find.descendant(of: _visual(id), matching: find.text(text));

RenderParagraph _paragraph(WidgetTester tester, Finder text) =>
    tester.renderObject<RenderParagraph>(
      find.descendant(of: text, matching: find.byType(RichText)),
    );

void _expectWholeVisibleLines(WidgetTester tester, String id, double scale) {
  final visual = _visual(id);
  final card = tester.getRect(visual);
  final texts = find.descendant(of: visual, matching: find.byType(Text));
  for (final element in texts.evaluate()) {
    final finder = find.byWidget(element.widget);
    final render = _paragraph(tester, finder);
    if (render.text.toPlainText().isEmpty) continue;
    final rect = tester.getRect(finder);
    expect(rect.top, greaterThanOrEqualTo(card.top - .01));
    expect(rect.bottom, lessThanOrEqualTo(card.bottom + .01));
    expect(rect.left, greaterThanOrEqualTo(card.left - .01));
    expect(rect.right, lessThanOrEqualTo(card.right + .01));
    expect(render.textScaler.scale(14), closeTo(scale * 14, .01));
    expect(render.overflow, TextOverflow.ellipsis);
    expect(render.maxLines, greaterThan(0));
    final painter = TextPainter(
      text: render.text,
      textDirection: render.textDirection,
      textScaler: render.textScaler,
      locale: render.locale,
      textHeightBehavior: render.textHeightBehavior,
      maxLines: render.maxLines,
      ellipsis: '…',
    )..layout(maxWidth: render.size.width);
    // A constrained RenderParagraph can be shorter than the lines it paints.
    // Compare with an independently height-unconstrained layout, not just its box.
    expect(render.size.height, closeTo(painter.height, .01));
    for (final line in painter.computeLineMetrics()) {
      expect(line.width, lessThanOrEqualTo(render.size.width + .01));
      expect(
        line.baseline + line.descent,
        lessThanOrEqualTo(render.size.height + .01),
      );
    }
    painter.dispose();
  }
  expect(
    find.descendant(of: visual, matching: find.byType(OverflowBox)),
    findsNothing,
  );
  expect(tester.takeException(), isNull);
}

void main() {
  for (final width in [320.0, 360.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets(
        '$width dp / ${scale}x only paints whole lines in a short fitted-week card',
        (tester) async {
          await tester.binding.setSurfaceSize(Size(width, 700));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          TimetableCourseTapInfo? tapped;
          await tester.pumpWidget(
            _grid(
              courses: [_course()],
              scale: scale,
              onTap: (value) => tapped = value,
            ),
          );
          await tester.pumpAndSettle();
          final title = _textIn('学术写作');
          if (title.evaluate().isEmpty) {
            final omitted = find.descendant(
              of: _visual(),
              matching: find.byKey(
                const ValueKey('timetable-course-text-omitted'),
              ),
            );
            expect(omitted, findsOneWidget);
            final mark = tester.getRect(omitted);
            final card = tester.getRect(_visual());
            expect(mark.left, greaterThanOrEqualTo(card.left));
            expect(mark.right, lessThanOrEqualTo(card.right));
            expect(mark.bottom, lessThanOrEqualTo(card.bottom));
          } else {
            expect(tester.widget<Text>(title).style!.fontSize, 14);
          }
          expect(
            tester.getSize(_visual()).height,
            closeTo(45 * 1.4 * scale.clamp(1, 1.8), .01),
          );
          _expectWholeVisibleLines(tester, 'course', scale);
          await tester.tap(
            find.byKey(const ValueKey('timetable-course-hit-course')),
          );
          expect(tapped?.course.name, '学术写作');
          expect(tapped?.course.location, 'B201');
          expect(tapped?.course.teacher, '郑老师');
        },
      );
    }
  }

  testWidgets(
    'title gets complete lines before optional location and teacher',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const title = 'Academic\nWriting\nWorkshop\nSeminar';
      await tester.pumpWidget(
        _grid(
          courses: [_course(title: title, duration: 25)],
          days: const [1],
        ),
      );
      await tester.pumpAndSettle();
      final paragraph = _paragraph(tester, _textIn(title));
      expect(paragraph.maxLines, 1);
      expect(paragraph.didExceedMaxLines, isTrue);
      expect(_textIn('B201'), findsNothing);
      expect(_textIn('郑老师'), findsNothing);
      _expectWholeVisibleLines(tester, 'course', 1);

      await tester.pumpWidget(
        _grid(
          courses: [_course(title: title, duration: 120)],
          days: const [1],
        ),
      );
      await tester.pumpAndSettle();
      expect(_paragraph(tester, _textIn(title)).didExceedMaxLines, isFalse);
      expect(_textIn('B201'), findsOneWidget);
      expect(_textIn('郑老师'), findsOneWidget);
      _expectWholeVisibleLines(tester, 'course', 1);
    },
  );

  for (final direction in TextDirection.values) {
    testWidgets('conflict badge has its own vertical space in $direction', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final scale in [1.0, 2.0]) {
        TimetableCourseTapInfo? tapped;
        await tester.pumpWidget(
          _grid(
            courses: [
              _course(),
              _course(id: 'conflict', title: '写作讨论'),
            ],
            scale: scale,
            direction: direction,
            onTap: (value) => tapped = value,
          ),
        );
        await tester.pumpAndSettle();
        final badge = find.byKey(
          const ValueKey('timetable-course-conflict-course'),
        );
        expect(badge, findsOneWidget);
        final badgeRect = tester.getRect(badge);
        final card = tester.getRect(_visual());
        expect(badgeRect.bottom, lessThanOrEqualTo(card.bottom));
        for (final element
            in find
                .descendant(of: _visual(), matching: find.byType(Text))
                .evaluate()) {
          final textRect = tester.getRect(find.byWidget(element.widget));
          expect(textRect.overlaps(badgeRect), isFalse);
          expect(textRect.bottom, lessThanOrEqualTo(badgeRect.top - 2 + .01));
        }
        _expectWholeVisibleLines(tester, 'course', scale);
        await tester.tap(
          find.byKey(const ValueKey('timetable-course-hit-course')),
        );
        expect(tapped?.isFullConflict, isTrue);
        expect(
          tapped?.courses.map((course) => course.id),
          containsAll(['course', 'conflict']),
        );
      }
    });
  }

  testWidgets(
    'a card shorter than one full line keeps geometry and full detail access',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      TimetableCourseTapInfo? tapped;
      await tester.pumpWidget(
        _grid(
          courses: [_course(duration: 5)],
          scale: 2,
          onTap: (value) => tapped = value,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(_visual()).height, closeTo(5 * 1.4 * 1.8, .01));
      expect(
        find.descendant(of: _visual(), matching: find.byType(Text)),
        findsNothing,
      );
      expect(
        find.bySemanticsLabel('学术写作, B201, 郑老师, 08:00–08:05'),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('timetable-course-hit-course')),
      );
      expect(tapped?.course.name, '学术写作');
      expect(tapped?.course.location, 'B201');
      expect(tapped?.course.teacher, '郑老师');
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );
}
