import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/widgets/timetable_grid.dart';

CourseItem _course({
  String id = 'course',
  String title = 'Numerical\nMethods\nSeminar',
  String location =
      'Campus\nBuilding B\nLaboratory\nRoom 201\nNorth wing\nFloor 2',
  String teacher = 'Visiting\nTeacher',
  int duration = 120,
}) => CourseItem(
  id: id,
  name: title,
  location: location,
  teacher: teacher,
  dayOfWeek: 1,
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
  Key gridKey = const ValueKey('retained-grid'),
  required List<CourseItem> courses,
  TextScaler scaler = TextScaler.noScaling,
  bool boldText = false,
  ThemeData? theme,
  double width = 1120,
  TextDirection direction = TextDirection.ltr,
  Locale locale = const Locale('en'),
  TextHeightBehavior textHeightBehavior = const TextHeightBehavior(),
  ValueChanged<TimetableCourseTapInfo>? onTap,
}) => MaterialApp(
  theme: theme ?? ThemeData(platform: TargetPlatform.windows),
  locale: locale,
  supportedLocales: const [Locale('en'), Locale('zh'), Locale('ar')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: scaler, boldText: boldText),
    child: Directionality(textDirection: direction, child: child!),
  ),
  home: Scaffold(
    body: Align(
      alignment: AlignmentDirectional.topStart,
      child: SizedBox(
        width: width,
        height: double.infinity,
        child: DefaultTextHeightBehavior(
          textHeightBehavior: textHeightBehavior,
          child: TimetableGrid(
            key: gridKey,
            timetable: TimetableData(
              id: 'desktop-typography',
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
            localeCode: locale.languageCode,
            preserveGaps: true,
            showPastEndedCourses: true,
            showFutureCourses: true,
            showGridLines: true,
            showDayHeader: false,
            fitVisibleDaysToWidth: true,
            visibleWeekdays: const [1, 2, 3, 4, 5],
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
      ),
    ),
  ),
);

Finder _visual() =>
    find.byKey(const ValueKey('timetable-course-visual-course'));
Finder _textIn(String text) =>
    find.descendant(of: _visual(), matching: find.text(text));
Finder _typographyLayout() =>
    find.descendant(of: _visual(), matching: find.byType(LayoutBuilder)).last;

RenderParagraph _paragraph(WidgetTester tester, Finder text) =>
    tester.renderObject<RenderParagraph>(
      find.descendant(of: text, matching: find.byType(RichText)),
    );

List<Object> _snapshot(WidgetTester tester) {
  final card = tester.getRect(_visual());
  final result = <Object>[card.size];
  for (final element
      in find
          .descendant(of: _visual(), matching: find.byType(Text))
          .evaluate()) {
    final finder = find.byWidget(element.widget);
    final render = _paragraph(tester, finder);
    final rect = tester.getRect(finder);
    expect(rect.left, greaterThanOrEqualTo(card.left - .01));
    expect(rect.right, lessThanOrEqualTo(card.right + .01));
    expect(rect.top, greaterThanOrEqualTo(card.top - .01));
    expect(rect.bottom, lessThanOrEqualTo(card.bottom + .01));
    result.add((
      text: render.text.toPlainText(),
      style: render.text.style,
      bounds: rect.shift(-card.topLeft),
      lines: render.maxLines,
      truncated: render.didExceedMaxLines,
      direction: render.textDirection,
      locale: render.locale,
      heightBehavior: render.textHeightBehavior,
      scaledFont: render.textScaler.scale(render.text.style!.fontSize!),
    ));
  }
  return result;
}

class _CountingTextScaler extends TextScaler {
  const _CountingTextScaler(this.onScale);

  final VoidCallback onScale;

  @override
  double scale(double fontSize) {
    onScale();
    return fontSize;
  }

  @override
  double get textScaleFactor => 1;
}

class _TitleTextScaler extends TextScaler {
  const _TitleTextScaler();

  @override
  double scale(double fontSize) => fontSize >= 16 ? fontSize * 1.8 : fontSize;

  @override
  double get textScaleFactor => 1;
}

void main() {
  testWidgets(
    'unchanged desktop rebuild reuses measurements and rebuilds text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1120, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var scales = 0;
      final scaler = _CountingTextScaler(() => scales++);
      final course = _course();
      await tester.pumpWidget(_grid(courses: [course], scaler: scaler));
      await tester.pumpAndSettle();
      expect(scales, greaterThan(0));
      final before = _snapshot(tester);
      final oldText = tester.widget<Text>(_textIn(course.name));

      scales = 0;
      // Rebuild only this card's layout so unrelated grid/header scaling cannot
      // hide redundant TextPainter work. The Text widgets must still be current.
      tester.element(_typographyLayout()).markNeedsBuild();
      await tester.pump();
      expect(scales, 0);
      expect(tester.widget<Text>(_textIn(course.name)), isNot(same(oldText)));
      expect(_snapshot(tester), before);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'retained desktop layout keeps full details and current actions',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1120, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final course = _course();
      final conflict = _course(id: 'conflict');
      var oldCalls = 0;
      TimetableCourseTapInfo? latest;
      await tester.pumpWidget(
        _grid(courses: [course, conflict], onTap: (_) => oldCalls++),
      );
      await tester.pumpAndSettle();
      final visual = tester.element(_visual());
      final before = _snapshot(tester);
      expect(
        _paragraph(tester, _textIn(course.location)).didExceedMaxLines,
        isTrue,
      );
      expect(_textIn(course.teacher), findsOneWidget);

      await tester.pumpWidget(
        _grid(
          courses: [
            course,
            conflict,
            _course(id: 'third'),
          ],
          onTap: (value) => latest = value,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.element(_visual()), same(visual));
      expect(_snapshot(tester), before);
      final badge = tester.getRect(
        find.byKey(const ValueKey('timetable-course-conflict-course')),
      );
      for (final element
          in find
              .descendant(of: _visual(), matching: find.byType(Text))
              .evaluate()) {
        expect(
          tester.getRect(find.byWidget(element.widget)).overlaps(badge),
          isFalse,
        );
      }
      await tester.tap(
        find.byKey(const ValueKey('timetable-course-hit-course')),
      );
      expect(oldCalls, 0);
      expect(latest?.course.name, course.name);
      expect(latest?.course.location, course.location);
      expect(latest?.course.teacher, course.teacher);
      expect(latest?.isFullConflict, isTrue);
      expect(
        latest?.courses.map((item) => item.id),
        unorderedEquals(['course', 'conflict', 'third']),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a trailing title newline retains its height before metadata', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1120, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final location = List.generate(
      6,
      (index) => 'Room ${index + 1}',
    ).join('\n');
    final plain = _course(
      title: 'Course',
      location: location,
      teacher: 'Teacher',
    );
    await tester.pumpWidget(_grid(courses: [plain]));
    await tester.pumpAndSettle();
    final visual = tester.element(_visual());
    final titleHeight = tester.getSize(_textIn('Course')).height;
    final locationLines = _paragraph(tester, _textIn(location)).maxLines!;
    expect(_paragraph(tester, _textIn('Course')).maxLines, 1);
    expect(locationLines, greaterThan(1));

    final withNewline = _course(
      title: 'Course\n',
      location: location,
      teacher: 'Teacher',
    );
    await tester.pumpWidget(_grid(courses: [withNewline]));
    await tester.pumpAndSettle();
    expect(tester.element(_visual()), same(visual));
    expect(_paragraph(tester, _textIn('Course\n')).maxLines, 2);
    expect(
      tester.getSize(_textIn('Course\n')).height,
      greaterThan(titleHeight),
    );
    expect(
      _paragraph(tester, _textIn(location)).maxLines,
      lessThan(locationLines),
    );
    expect(_paragraph(tester, _textIn(location)).didExceedMaxLines, isTrue);
    expect(_textIn('Teacher'), findsOneWidget);
    expect(_paragraph(tester, _textIn('Teacher')).didExceedMaxLines, isFalse);
    _snapshot(tester);

    await tester.pumpWidget(_grid(courses: [plain]));
    await tester.pumpAndSettle();
    expect(tester.element(_visual()), same(visual));
    expect(_paragraph(tester, _textIn('Course')).maxLines, 1);
    expect(tester.getSize(_textIn('Course')).height, titleHeight);
    expect(_paragraph(tester, _textIn(location)).maxLines, locationLines);
    expect(tester.takeException(), isNull);
  });

  final windows = ThemeData(platform: TargetPlatform.windows);
  final largerFont = windows.copyWith(
    textTheme: windows.textTheme
        .apply(fontFamily: 'Ahem')
        .copyWith(
          titleSmall: const TextStyle(fontFamily: 'Ahem', fontSize: 20),
          titleMedium: const TextStyle(fontFamily: 'Ahem', fontSize: 22),
        ),
  );
  final course = _course();
  final scenes = <({String label, Widget Function(Key) build})>[
    (
      label: 'edited title',
      build: (key) => _grid(
        gridKey: key,
        courses: [
          _course(title: 'Advanced numerical methods and applications'),
        ],
      ),
    ),
    (
      label: 'removed location',
      build: (key) => _grid(
        gridKey: key,
        courses: [_course(location: '')],
      ),
    ),
    (
      label: 'edited teacher',
      build: (key) => _grid(
        gridKey: key,
        courses: [
          _course(teacher: 'Visiting Professor\nDepartment of Mathematics'),
        ],
      ),
    ),
    (
      label: 'taller course',
      build: (key) => _grid(gridKey: key, courses: [_course(duration: 240)]),
    ),
    (
      label: 'narrower window',
      build: (key) => _grid(gridKey: key, courses: [course], width: 980),
    ),
    (
      label: 'large text',
      build: (key) => _grid(
        gridKey: key,
        courses: [course],
        scaler: const TextScaler.linear(2),
      ),
    ),
    (
      label: 'nonlinear text scale',
      build: (key) => _grid(
        gridKey: key,
        courses: [course],
        scaler: const _TitleTextScaler(),
      ),
    ),
    (
      label: 'font family and size',
      build: (key) => _grid(gridKey: key, courses: [course], theme: largerFont),
    ),
    (
      label: 'dark theme',
      build: (key) => _grid(
        gridKey: key,
        courses: [course],
        theme: ThemeData(
          platform: TargetPlatform.windows,
          brightness: Brightness.dark,
        ),
      ),
    ),
    (
      label: 'bold text',
      build: (key) => _grid(gridKey: key, courses: [course], boldText: true),
    ),
    (
      label: 'right to left',
      build: (key) =>
          _grid(gridKey: key, courses: [course], direction: TextDirection.rtl),
    ),
    (
      label: 'locale',
      build: (key) =>
          _grid(gridKey: key, courses: [course], locale: const Locale('zh')),
    ),
    (
      label: 'inherited text height',
      build: (key) => _grid(
        gridKey: key,
        courses: [course],
        textHeightBehavior: const TextHeightBehavior(
          applyHeightToFirstAscent: false,
          applyHeightToLastDescent: false,
        ),
      ),
    ),
    (
      label: 'conflict badge',
      build: (key) => _grid(
        gridKey: key,
        courses: [
          course,
          _course(id: 'conflict'),
        ],
      ),
    ),
  ];
  for (final scene in scenes) {
    testWidgets('retained desktop ${scene.label} matches a fresh card', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1120, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const retainedKey = ValueKey('retained-grid');
      await tester.pumpWidget(_grid(gridKey: retainedKey, courses: [course]));
      await tester.pumpAndSettle();
      final visual = tester.element(_visual());

      await tester.pumpWidget(scene.build(retainedKey));
      await tester.pumpAndSettle();
      expect(tester.element(_visual()), same(visual));
      final updated = _snapshot(tester);

      // A fresh mount is an independent layout oracle. Compare visible text,
      // line budgets, geometry and effective inherited presentation together.
      await tester.pumpWidget(scene.build(const ValueKey('fresh-grid')));
      await tester.pumpAndSettle();
      expect(tester.element(_visual()), isNot(same(visual)));
      expect(_snapshot(tester), updated);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('system font notifications refresh and release desktop cards', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1120, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var scales = 0;
    final scaler = _CountingTextScaler(() => scales++);
    await tester.pumpWidget(_grid(courses: [course], scaler: scaler));
    await tester.pumpAndSettle();
    final visual = tester.element(_visual());
    final before = _snapshot(tester);

    scales = 0;
    await tester.binding.handleSystemMessage({'type': 'fontsChange'});
    await tester.pumpAndSettle();
    expect(scales, greaterThan(0));
    expect(tester.element(_visual()), same(visual));
    expect(_snapshot(tester), before);

    scales = 0;
    tester.element(_typographyLayout()).markNeedsBuild();
    await tester.pump();
    expect(scales, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.binding.handleSystemMessage({'type': 'fontsChange'});
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
