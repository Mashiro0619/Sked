import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/widgets/timetable_grid.dart';

CourseItem _course({
  required String title,
  String location = '',
  String teacher = '',
}) => CourseItem(
  id: 'words',
  name: title,
  location: location,
  teacher: teacher,
  dayOfWeek: DateTime.monday,
  semesterWeeks: const [1],
  periods: const [1],
  startMinutes: 480,
  endMinutes: 720,
  timeRange: '08:00–12:00',
  credit: 0,
  remarks: '',
  customFields: const {},
);

Widget _grid(
  CourseItem course, {
  required TargetPlatform platform,
  double scale = 1,
  List<int> days = const [1, 2, 3, 4, 5, 6, 7],
  TextDirection direction = TextDirection.ltr,
  ValueChanged<TimetableCourseTapInfo>? onTap,
}) {
  final theme = ThemeData(platform: platform);
  return MaterialApp(
    theme: theme.copyWith(textTheme: theme.textTheme.apply(fontFamily: 'Ahem')),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale)),
      child: Directionality(textDirection: direction, child: child!),
    ),
    home: Scaffold(
      body: TimetableGrid(
        timetable: TimetableData(
          id: 'word-wrapping',
          config: TimetableConfig(
            name: 'Timetable',
            startDate: DateTime(2026, 1, 5),
            totalWeeks: 18,
            periodTimeSetId: defaultPeriodTimeSetId,
          ),
          courses: [course],
        ),
        periodTimes: const [
          CoursePeriodTime(index: 1, startMinutes: 480, endMinutes: 720),
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
  );
}

RenderParagraph _paragraph(WidgetTester tester, String original) {
  final text = find.descendant(
    of: find.byKey(const ValueKey('timetable-course-visual-words')),
    matching: find.text(original),
  );
  expect(text, findsOneWidget);
  return tester.renderObject<RenderParagraph>(
    find.descendant(of: text, matching: find.byType(RichText)),
  );
}

Set<double> _paintedLines(RenderParagraph paragraph, int start, int end) =>
    paragraph
        .getBoxesForSelection(
          TextSelection(baseOffset: start, extentOffset: end),
        )
        .where((box) => box.right > box.left && box.bottom > box.top)
        .map((box) => box.top)
        .toSet();

void _expectWordOnOnePaintedLine(RenderParagraph paragraph, String word) {
  final text = paragraph.text.toPlainText();
  final start = text.indexOf(word);
  expect(start, greaterThanOrEqualTo(0));
  // Query the mounted RenderParagraph, not nominal maxLines or an independent
  // TextPainter: a Latin word may contain several boxes, but never two line tops.
  expect(
    _paintedLines(paragraph, start, start + word.length).length,
    lessThanOrEqualTo(1),
    reason: 'The word "$word" must not continue on a second painted line',
  );
}

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.windows]) {
    for (final scale in [1.0, 2.0]) {
      for (final direction in TextDirection.values) {
        testWidgets(
          'oversized Latin words use one ellipsized line on $platform ${scale}x $direction',
          (tester) async {
            await tester.binding.setSurfaceSize(const Size(320, 900));
            addTearDown(() => tester.binding.setSurfaceSize(null));
            final semantics = tester.ensureSemantics();
            try {
              final course = _course(
                title: 'Electromagnetism',
                location: 'Laboratory201',
                teacher: 'O’Connor',
              );
              TimetableCourseTapInfo? opened;
              await tester.pumpWidget(
                _grid(
                  course,
                  platform: platform,
                  scale: scale,
                  direction: direction,
                  onTap: (value) => opened = value,
                ),
              );
              await tester.pumpAndSettle();
              for (final field in [
                course.name,
                course.location,
                course.teacher,
              ]) {
                final paragraph = _paragraph(tester, field);
                expect(paragraph.text.toPlainText(), field);
                _expectWordOnOnePaintedLine(paragraph, field);
                expect(paragraph.maxLines, 1);
                expect(paragraph.overflow, TextOverflow.ellipsis);
                expect(paragraph.didExceedMaxLines, isTrue);
                expect(paragraph.textScaler.scale(14), scale * 14);
              }
              final label =
                  'Electromagnetism, Monday, Week 1, 08:00–12:00, '
                  'Location: Laboratory201, Teacher: O’Connor';
              final node = tester.getSemantics(find.bySemanticsLabel(label));
              node.owner!.performAction(node.id, ui.SemanticsAction.tap);
              expect(opened?.course, same(course));
              expect(tester.takeException(), isNull);
            } finally {
              semantics.dispose();
            }
          },
        );
      }
    }

    testWidgets('fitting words still wrap between words on $platform', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(180, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const title = 'Art Music Lab';
      await tester.pumpWidget(
        _grid(
          _course(title: title),
          platform: platform,
          days: const [1],
        ),
      );
      await tester.pumpAndSettle();
      final paragraph = _paragraph(tester, title);
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(_paintedLines(paragraph, 0, title.length).length, greaterThan(1));
      for (final word in title.split(' ')) {
        _expectWordOnOnePaintedLine(paragraph, word);
        expect(
          _paintedLines(
            paragraph,
            title.indexOf(word),
            title.indexOf(word) + word.length,
          ),
          isNotEmpty,
        );
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'an oversized word keeps preceding complete lines on $platform',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(180, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        const word = 'Supercalifragilisticexpialidocious';
        const title = 'Art\n$word Lab';
        await tester.pumpWidget(
          _grid(
            _course(title: title),
            platform: platform,
            days: const [1],
          ),
        );
        await tester.pumpAndSettle();
        final paragraph = _paragraph(tester, title);
        _expectWordOnOnePaintedLine(paragraph, 'Art');
        _expectWordOnOnePaintedLine(paragraph, word);
        expect(_paintedLines(paragraph, 0, 3), isNotEmpty);
        expect(paragraph.maxLines, 2);
        expect(paragraph.didExceedMaxLines, isTrue);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('CJK remains naturally wrapped on $platform', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const title = '高等数学课程研究';
      await tester.pumpWidget(_grid(_course(title: title), platform: platform));
      await tester.pumpAndSettle();
      final paragraph = _paragraph(tester, title);
      expect(paragraph.text.toPlainText(), title);
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(_paintedLines(paragraph, 0, title.length).length, greaterThan(1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('accented Latin words stay intact on $platform', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final course = _course(
        title: 'Électromagnétisme',
        location: 'Laborato\u0301rio201',
      );
      await tester.pumpWidget(_grid(course, platform: platform));
      await tester.pumpAndSettle();
      for (final field in [course.name, course.location]) {
        final paragraph = _paragraph(tester, field);
        _expectWordOnOnePaintedLine(paragraph, field);
        expect(paragraph.maxLines, 1);
        expect(paragraph.didExceedMaxLines, isTrue);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('resizing releases and restores word truncation on $platform', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(180, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const title = 'Supercalifragilisticexpialidocious';
      final course = _course(title: title);
      await tester.pumpWidget(
        _grid(course, platform: platform, days: const [1]),
      );
      await tester.pumpAndSettle();
      final visual = tester.element(
        find.byKey(const ValueKey('timetable-course-visual-words')),
      );
      expect(_paragraph(tester, title).maxLines, 1);
      expect(_paragraph(tester, title).didExceedMaxLines, isTrue);
      await tester.binding.setSurfaceSize(const Size(700, 900));
      await tester.pumpAndSettle();
      expect(
        tester.element(
          find.byKey(const ValueKey('timetable-course-visual-words')),
        ),
        same(visual),
      );
      expect(_paragraph(tester, title).didExceedMaxLines, isFalse);
      _expectWordOnOnePaintedLine(_paragraph(tester, title), title);
      await tester.binding.setSurfaceSize(const Size(180, 900));
      await tester.pumpAndSettle();
      expect(
        tester.element(
          find.byKey(const ValueKey('timetable-course-visual-words')),
        ),
        same(visual),
      );
      expect(_paragraph(tester, title).maxLines, 1);
      expect(_paragraph(tester, title).didExceedMaxLines, isTrue);
      _expectWordOnOnePaintedLine(_paragraph(tester, title), title);
      expect(tester.takeException(), isNull);
    });
  }
}
