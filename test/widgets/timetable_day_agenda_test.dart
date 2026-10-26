import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/theme/timetable_contrast.dart';
import 'package:sked/widgets/timetable_day_agenda.dart';
import 'package:sked/widgets/timetable_grid.dart' show TimetableCourseTapInfo;
import 'package:sked/widgets/workspace_frame.dart';

final _weekStart = DateTime(2026, 10, 19);
const _periods = [
  CoursePeriodTime(index: 1, startMinutes: 490, endMinutes: 535),
  CoursePeriodTime(index: 2, startMinutes: 570, endMinutes: 620),
  CoursePeriodTime(index: 4, startMinutes: 720, endMinutes: 765),
];

CourseItem _course(
  String id, {
  String? name,
  int day = DateTime.monday,
  int start = 480,
  int end = 540,
  List<int> weeks = const [1],
  List<int> periods = const [],
  String teacher = '',
  String location = '',
}) => CourseItem(
  id: id,
  name: name ?? id,
  teacher: teacher,
  location: location,
  dayOfWeek: day,
  semesterWeeks: weeks,
  periods: periods,
  startMinutes: start,
  endMinutes: end,
  timeRange: buildTimeRange(start, end),
  credit: 0,
  remarks: '',
  customFields: const {},
);

TimetableData _timetable(List<CourseItem> courses) => TimetableData(
  id: 'day-agenda',
  config: TimetableConfig(
    name: 'Day agenda',
    startDate: _weekStart,
    totalWeeks: 18,
    periodTimeSetId: defaultPeriodTimeSetId,
  ),
  courses: courses,
);

Widget _app(
  TimetableData timetable, {
  int day = DateTime.monday,
  int week = 1,
  int currentWeek = 1,
  bool past = false,
  bool future = false,
  double scale = 1,
  Brightness brightness = Brightness.light,
  String? selectedId,
  String? Function(String)? conflictChoice,
  TimetableLiveCourseTarget? liveTarget,
  bool liveOutline = false,
  String liveMode = liveCourseOutlineModeCurrentOrNext,
  String themeMode = themeColorModeSingle,
  Map<String, int> courseColors = const {},
  int? customTextColor,
  ValueChanged<TimetableCourseTapInfo>? onTap,
  ValueChanged<BuildContext>? onAdd,
}) => MaterialApp(
  locale: const Locale('en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: appLocalizationsDelegates,
  theme: ThemeData(platform: TargetPlatform.windows, brightness: brightness),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(
    body: WorkspaceSelectionScope(
      selectedId: selectedId == null ? null : 'course:$selectedId',
      child: TimetableDayAgenda(
        timetable: timetable,
        periodTimes: _periods,
        weekDateStart: addCalendarDays(_weekStart, (week - 1) * 7),
        selectedWeek: week,
        realCurrentWeek: currentWeek,
        localeCode: 'en',
        selectedWeekday: day,
        showPastEndedCourses: past,
        showFutureCourses: future,
        themeColorMode: themeMode,
        courseNameColorValues: courseColors,
        colorfulCourseTextColorMode: customTextColor == null
            ? colorfulCourseTextColorModeAuto
            : colorfulCourseTextColorModeCustom,
        colorfulCourseTextColorValue: customTextColor,
        displayedCourseIdForConflict: conflictChoice,
        liveCourseTarget: liveTarget,
        liveCourseOutlineEnabled: liveOutline,
        liveCourseOutlineMode: liveMode,
        liveCourseOutlineColorValue: 0xff008577,
        liveCourseOutlineWidth: 4,
        onCourseTap: onTap,
        onAddCourse: onAdd,
      ),
    ),
  ),
);

Finder _key(String key) => find.byKey(ValueKey(key));
Finder _row(String id) => _key('student-day-course-$id');
Finder _card(String id) => _key('student-day-course-card-$id');
Finder _semantics(String id) => find.descendant(
  of: _row(id),
  matching: find.byWidgetPredicate(
    (widget) => widget is Semantics && widget.properties.button == true,
  ),
);

Future<void> _size(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
}

RoundedRectangleBorder _shape(WidgetTester tester, String id) =>
    tester.widget<Material>(_card(id)).shape! as RoundedRectangleBorder;

void main() {
  testWidgets(
    'partial conflicts stay in stable time order with real metadata',
    (tester) async {
      await _size(tester, const Size(880, 1100));
      TimetableCourseTapInfo? tapped;
      await tester.pumpWidget(
        _app(
          _timetable([
            _course('later', start: 700, end: 760),
            _course('b', start: 500, end: 570),
            _course('a', start: 500, end: 570),
            _course(
              'early',
              start: 480,
              end: 540,
              periods: const [4, 2, 1, 2],
              location: 'Room 123',
              teacher: 'Teacher Example',
            ),
          ]),
          onTap: (info) => tapped = info,
        ),
      );
      await tester.pumpAndSettle();

      final positions = [
        for (final id in ['early', 'a', 'b', 'later'])
          tester.getTopLeft(_row(id)).dy,
      ];
      expect(positions, orderedEquals([...positions]..sort()));
      expect(positions.toSet(), hasLength(4));
      expect(find.text('08:00'), findsOneWidget);
      expect(find.text('09:00'), findsOneWidget);
      expect(find.text('Period 1-2 · Period 4'), findsOneWidget);
      expect(find.text('Room 123'), findsOneWidget);
      expect(find.text('Teacher Example'), findsOneWidget);
      expect(find.text('Conflicting courses · 3'), findsNWidgets(3));
      await tester.tap(_card('early'));
      expect(tapped?.course.id, 'early');
      expect(
        tapped?.courses.map((course) => course.id),
        containsAll(['early', 'a', 'b']),
      );
      expect(tapped?.isFullConflict, isFalse);
      expect(tapped?.selectedWeek, 1);
      expect(tapped?.anchorRect, tester.getRect(_card('early')));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('full conflicts honor display choice and preserve all members', (
    tester,
  ) async {
    await _size(tester, const Size(880, 700));
    final timetable = _timetable([_course('a'), _course('b')]);
    var choice = 'b';
    String? requestedKey;
    TimetableCourseTapInfo? tapped;
    Widget app() => _app(
      timetable,
      conflictChoice: (key) {
        requestedKey = key;
        return choice;
      },
      onTap: (info) => tapped = info,
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(_row('a'), findsNothing);
    expect(_row('b'), findsOneWidget);
    expect(find.text('Conflicting courses · 2'), findsOneWidget);
    await tester.tap(_card('b'));
    expect(tapped?.course.id, 'b');
    expect(tapped?.isFullConflict, isTrue);
    expect(tapped?.conflictKey, requestedKey);
    expect(
      tapped?.courses.map((course) => course.id),
      unorderedEquals(['a', 'b']),
    );

    choice = 'a';
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(_row('a'), findsOneWidget);
    expect(_row('b'), findsNothing);
  });

  testWidgets(
    'period fallback, explicit times and week filtering share projection',
    (tester) async {
      await _size(tester, const Size(880, 1100));
      final timetable = _timetable([
        _course(
          'legacy',
          start: 0,
          end: 0,
          periods: const [1, 2],
          weeks: const [2],
        ),
        _course(
          'explicit',
          start: 660,
          end: 705,
          periods: const [4],
          weeks: const [2],
        ),
        _course('past', start: 800, end: 850, weeks: const [1]),
        _course('future', start: 900, end: 950, weeks: const [3]),
        _course('other-day', day: DateTime.tuesday, weeks: const [2]),
      ]);
      await tester.pumpWidget(_app(timetable, week: 2, currentWeek: 2));
      await tester.pumpAndSettle();
      expect(_row('legacy'), findsOneWidget);
      expect(_row('explicit'), findsOneWidget);
      expect(_row('past'), findsNothing);
      expect(_row('future'), findsNothing);
      expect(_row('other-day'), findsNothing);
      expect(find.text('08:10'), findsOneWidget);
      expect(find.text('10:20'), findsOneWidget);
      expect(find.text('11:00'), findsOneWidget);
      expect(find.text('11:45'), findsOneWidget);
      await tester.pumpWidget(
        _app(timetable, week: 2, currentWeek: 2, past: true, future: true),
      );
      await tester.pumpAndSettle();
      expect(_row('past'), findsOneWidget);
      expect(_row('future'), findsOneWidget);
      expect(find.text('Weeks 1'), findsOneWidget);
      expect(find.text('Weeks 3'), findsOneWidget);
    },
  );

  testWidgets(
    'active course wins inactive full conflict despite saved choice',
    (tester) async {
      await _size(tester, const Size(880, 700));
      await tester.pumpWidget(
        _app(
          _timetable([
            _course('active', weeks: const [2]),
            _course('future', weeks: const [3]),
          ]),
          week: 2,
          currentWeek: 2,
          future: true,
          conflictChoice: (_) => 'future',
        ),
      );
      await tester.pumpAndSettle();
      expect(_row('active'), findsOneWidget);
      expect(_row('future'), findsNothing);
      expect(find.text('Conflicting courses · 2'), findsOneWidget);
    },
  );

  testWidgets(
    'selection, live target and keyboard activation retain semantics',
    (tester) async {
      await _size(tester, const Size(880, 700));
      final semantics = tester.ensureSemantics();
      try {
        final timetable = _timetable([
          _course('selected'),
          _course('live', start: 600, end: 660),
        ]);
        final taps = <TimetableCourseTapInfo>[];
        await tester.pumpWidget(
          _app(
            timetable,
            selectedId: 'selected',
            liveOutline: true,
            liveTarget: const TimetableLiveCourseTarget(
              week: 1,
              weekday: DateTime.monday,
              courseId: 'live',
              isCurrentCourse: true,
            ),
            onTap: taps.add,
          ),
        );
        await tester.pumpAndSettle();
        expect(_shape(tester, 'selected').side.width, 2);
        expect(_shape(tester, 'live').side.width, 4);
        final selectedNode = tester.getSemantics(_semantics('selected'));
        expect(
          selectedNode.getSemanticsData().flagsCollection.isSelected,
          ui.Tristate.isTrue,
        );
        expect(
          selectedNode.getSemanticsData().label,
          contains('October 19, 2026'),
        );
        expect(selectedNode.getSemanticsData().label, contains('Week 1'));
        selectedNode.owner!.performAction(
          selectedNode.id,
          ui.SemanticsAction.tap,
        );
        expect(taps.single.course.id, 'selected');

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(taps, hasLength(2));
        expect(taps.last.anchorRect, isNotNull);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('disabled agenda exposes disabled cards and no add button', (
    tester,
  ) async {
    await _size(tester, const Size(880, 700));
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(_app(_timetable([_course('disabled')])));
      await tester.pumpAndSettle();
      final node = tester.getSemantics(_semantics('disabled'));
      expect(
        node.getSemanticsData().flagsCollection.isEnabled,
        ui.Tristate.isFalse,
      );
      expect(
        node.getSemanticsData().hasAction(ui.SemanticsAction.tap),
        isFalse,
      );
      final ink = tester.widget<InkWell>(
        find.descendant(of: _card('disabled'), matching: find.byType(InkWell)),
      );
      expect(ink.onTap, isNull);
      await tester.pumpWidget(_app(_timetable([])));
      await tester.pumpAndSettle();
      expect(find.text('No courses for this day'), findsOneWidget);
      expect(find.text('Add course'), findsNothing);
      var added = false;
      await tester.pumpWidget(_app(_timetable([]), onAdd: (_) => added = true));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add course'));
      expect(added, isTrue);
    } finally {
      semantics.dispose();
    }
  });

  for (final brightness in Brightness.values) {
    testWidgets('narrow and scaled content grows naturally in $brightness', (
      tester,
    ) async {
      await _size(tester, const Size(320, 1500));
      final timetable = _timetable([
        _course(
          'long',
          name: 'A long course title about applied mathematics and scientific computing',
          teacher: 'A teacher with an unusually long full name',
          location: 'The north wing of a distant teaching building, room number 12345',
        ),
        _course('minimal', start: 600, end: 660),
      ]);
      await tester.pumpWidget(_app(timetable, brightness: brightness));
      await tester.pumpAndSettle();
      expect(_key('student-day-course-inline-time-long'), findsOneWidget);
      final normalHeight = tester.getSize(_card('long')).height;
      expect(
        find.descendant(of: _card('minimal'), matching: find.byType(Icon)),
        findsNothing,
      );
      await tester.pumpWidget(
        _app(timetable, scale: 2, brightness: brightness),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(_card('long')).height, greaterThan(normalHeight));
      expect(tester.getRect(_card('long')).right, lessThanOrEqualTo(320));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('2x text puts times inside cards even on a wide screen', (
    tester,
  ) async {
    await _size(tester, const Size(880, 700));
    final timetable = _timetable([_course('wide')]);
    await tester.pumpWidget(_app(timetable));
    await tester.pumpAndSettle();
    expect(_key('student-day-course-inline-time-wide'), findsNothing);
    expect(tester.getTopLeft(_card('wide')).dx, greaterThan(0));
    await tester.pumpWidget(_app(timetable, scale: 2));
    await tester.pumpAndSettle();
    expect(_key('student-day-course-inline-time-wide'), findsOneWidget);
    expect(tester.getTopLeft(_card('wide')).dx, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('automatic colorful text contrasts with the light card fill', (
    tester,
  ) async {
    await _size(tester, const Size(880, 700));
    final timetable = _timetable([_course('colorful')]);
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(
        _app(
          timetable,
          brightness: brightness,
          themeMode: themeColorModeColorful,
          courseColors: const {'colorful': 0xffffff00},
        ),
      );
      await tester.pumpAndSettle();
      final background = tester.widget<Material>(_card('colorful')).color!;
      final title = tester.widget<Text>(find.text('colorful'));
      expect(
        renderedTimetableContrast(title.style!.color!, background),
        greaterThanOrEqualTo(4.5),
      );
    }
    await tester.pumpWidget(
      _app(
        timetable,
        themeMode: themeColorModeColorful,
        customTextColor: 0xff123456,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.text('colorful')).style!.color,
      const Color(0xff123456),
    );
  });

  testWidgets(
    'selection updates preserve scrolling and date changes reset it',
    (tester) async {
      await _size(tester, const Size(430, 350));
      final timetable = _timetable([
        for (final day in [DateTime.monday, DateTime.tuesday])
          for (var i = 0; i < 12; i++)
            _course(
              '$day-$i',
              day: day,
              start: 480 + i * 60,
              end: 525 + i * 60,
            ),
      ]);
      await tester.pumpWidget(_app(timetable));
      await tester.pumpAndSettle();
      final scrollable = find.descendant(
        of: _key('student-day-agenda-scroll'),
        matching: find.byType(Scrollable),
      );
      ScrollPosition position() =>
          tester.state<ScrollableState>(scrollable).position;
      await tester.drag(
        _key('student-day-agenda-scroll'),
        const Offset(0, -450),
      );
      await tester.pumpAndSettle();
      final offset = position().pixels;
      expect(offset, greaterThan(0));
      await tester.pumpWidget(_app(timetable, selectedId: '1-5'));
      await tester.pumpAndSettle();
      expect(position().pixels, offset);
      await tester.pumpWidget(_app(timetable));
      await tester.pumpAndSettle();
      expect(position().pixels, offset);
      await tester.pumpWidget(_app(timetable, day: DateTime.tuesday));
      await tester.pumpAndSettle();
      expect(position().pixels, 0);
      await tester.drag(
        _key('student-day-agenda-scroll'),
        const Offset(0, -450),
      );
      await tester.pumpAndSettle();
      expect(position().pixels, greaterThan(0));
      await tester.pumpWidget(
        _app(
          timetable,
          day: DateTime.tuesday,
          week: 2,
          future: true,
          past: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(position().pixels, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
