import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/home_screen.dart';
import 'package:sked/widgets/course_details_sheet.dart';
import 'package:sked/widgets/course_editor_sheet.dart';
import 'package:sked/widgets/timetable_day_agenda.dart';
import 'package:sked/widgets/timetable_grid.dart';

import '../support/workspace_harness.dart';

Finder _key(String value) => find.byKey(ValueKey(value));
Finder get _agenda => _key('student-day-agenda-scroll');
Finder get _details => find.byType(CourseDetailsSheet);
Finder get _editor => find.byType(CourseEditorSheet);
Finder _inside(Finder parent, Finder child) =>
    find.descendant(of: parent, matching: child);

CourseItem _course(String id, int weekday, int start) => CourseItem(
  id: id,
  name: 'Lecture $id',
  teacher: 'Teacher $id',
  location: 'Room $id',
  dayOfWeek: weekday,
  semesterWeeks: const [],
  periods: const [],
  startMinutes: start,
  endMinutes: start + 45,
  timeRange: buildTimeRange(start, start + 45),
  credit: 0,
  remarks: '',
  customFields: const {},
);

Future<AppRuntime> _mount(
  WidgetTester tester, {
  bool desktop = false,
  bool populated = true,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = desktop
      ? const Size(1362, 768)
      : const Size(430, 850);
  addTearDown(tester.view.reset);
  final initial = buildInitialAppData(
    buildDefaultPeriodTimes(),
    localeCode: 'en',
  );
  final table = TimetableData(
    id: 'day-workflow',
    config: TimetableConfig(
      name: 'Day workflow',
      startDate: startOfWeekMonday(DateTime.now()),
      totalWeeks: 18,
      periodTimeSetId: initial.studentMode.periodTimeSets.first.id,
    ),
    courses: [
      if (populated) ...[
        for (var index = 0; index < 9; index++)
          _course('monday-$index', DateTime.monday, 480 + index * 60),
        _course('tuesday', DateTime.tuesday, 600),
      ],
    ],
  );
  final app = await workspaceProvider(
    storage: WorkspaceMemoryStorage(
      initial.copyWith(
        activeMode: AppMode.student,
        homeWorkspaceNavigationCollapsed: true,
        studentMode: initial.studentMode.copyWith(
          activeTimetableId: table.id,
          timetables: [table],
          showFutureCourses: false,
          showPastEndedCourses: false,
        ),
      ),
    ),
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    app.dispose();
  });
  await app.studentCommands.setSelectedWeek(5);
  await tester.pumpWidget(
    WorkspaceHarness(provider: app, home: const HomeScreen()),
  );
  await tester.pumpAndSettle();
  if (desktop) {
    await _tap(tester, _key('student-view-toggle'));
    await _tap(tester, find.text('Day'));
  } else {
    await _tap(tester, _key('student-view-toggle-button'));
  }
  expect(find.byType(TimetableDayAgenda), findsOneWidget);
  expect(find.byType(TimetableGrid), findsNothing);
  return app;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  expect(finder, findsOneWidget);
  if (finder.hitTestable().evaluate().isEmpty) {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

ScrollPosition _position(WidgetTester tester) => tester
    .state<ScrollableState>(_inside(_agenda, find.byType(Scrollable)))
    .position;

Future<void> _closeEditor(WidgetTester tester) async {
  final strings = AppLocalizations.of(tester.element(_editor));
  await _tap(
    tester,
    _inside(_editor, find.widgetWithText(TextButton, strings.cancel)),
  );
  expect(_editor, findsNothing);
}

void main() {
  final phone = TargetPlatformVariant.only(TargetPlatform.android);
  final desktop = TargetPlatformVariant.only(TargetPlatform.windows);

  testWidgets('day changes reset the agenda and retain week swipe navigation', (
    tester,
  ) async {
    final app = await _mount(tester);
    await tester.drag(_agenda, const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(_position(tester).pixels, greaterThan(0));

    await _tap(tester, _key('student-day-2'));
    expect(_position(tester).pixels, 0);
    expect(find.text('Lecture tuesday'), findsOneWidget);
    expect(find.text('Lecture monday-0'), findsNothing);

    await _tap(tester, _key('student-day-1'));
    expect(_position(tester).pixels, 0);
    expect(find.text('Lecture monday-0'), findsOneWidget);

    await tester.drag(_agenda, const Offset(-250, 0));
    await tester.pumpAndSettle();
    expect(app.studentView.selectedWeek, 6);
    expect(find.byType(TimetableDayAgenda), findsOneWidget);
    expect(_position(tester).pixels, 0);
    expect(tester.takeException(), isNull);
  }, variant: phone);

  testWidgets('today action returns the agenda to the current week and day', (
    tester,
  ) async {
    final app = await _mount(tester);
    final today = DateTime.now().weekday;
    final differentDay = today == DateTime.monday
        ? DateTime.tuesday
        : DateTime.monday;
    await _tap(tester, _key('student-day-$differentDay'));
    final currentWeek = currentWeekFor(app.studentView.activeTimetable.config);
    expect(app.studentView.selectedWeek, isNot(currentWeek));

    await tester.longPress(_key('student-week-picker-button'));
    await tester.pumpAndSettle();

    expect(app.studentView.selectedWeek, currentWeek);
    final agenda = tester.widget<TimetableDayAgenda>(
      _inside(
        _key('student-week-page-$currentWeek'),
        find.byType(TimetableDayAgenda),
      ),
    );
    expect(agenda.selectedWeekday, today);
    expect(agenda.selectedWeek, currentWeek);
    expect(_position(tester).pixels, 0);
    expect(tester.takeException(), isNull);
  }, variant: phone);

  testWidgets('phone FAB and empty-day add start on the selected weekday', (
    tester,
  ) async {
    await _mount(tester);
    await _tap(tester, _key('student-day-2'));
    await _tap(tester, find.byTooltip('Add course'));
    expect(
      tester.widget<CourseEditorSheet>(_editor).dayOfWeek,
      DateTime.tuesday,
    );
    await _closeEditor(tester);

    await _tap(tester, _key('student-day-3'));
    expect(find.text('No courses for this day'), findsOneWidget);
    await _tap(
      tester,
      _inside(_agenda, find.widgetWithText(FilledButton, 'Add course')),
    );
    expect(
      tester.widget<CourseEditorSheet>(_editor).dayOfWeek,
      DateTime.wednesday,
    );
    expect(tester.takeException(), isNull);
  }, variant: phone);

  testWidgets('hidden phone add preference also hides empty-day add', (
    tester,
  ) async {
    final app = await _mount(tester, populated: false);
    expect(
      _inside(_agenda, find.widgetWithText(FilledButton, 'Add course')),
      findsOneWidget,
    );
    await app.settingsCommands.updateShowAddCourseFab(false);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Add course'), findsNothing);
    expect(
      _inside(_agenda, find.widgetWithText(FilledButton, 'Add course')),
      findsNothing,
    );
    expect(
      tester
          .widget<TimetableDayAgenda>(find.byType(TimetableDayAgenda))
          .bottomContentInset,
      0,
    );
    expect(tester.takeException(), isNull);
  }, variant: phone);

  testWidgets('desktop agenda is centered and inline add uses selected day', (
    tester,
  ) async {
    await _mount(tester, desktop: true);
    final agendaRect = tester.getRect(_agenda);
    final pagerRect = tester.getRect(_key('student-week-pager'));
    expect(agendaRect.width, lessThanOrEqualTo(880));
    expect(agendaRect.center.dx, closeTo(pagerRect.center.dx, .01));
    await _tap(tester, _key('student-day-4'));
    await _tap(tester, _key('student-add-course'));
    expect(
      tester.widget<CourseEditorSheet>(_editor).dayOfWeek,
      DateTime.thursday,
    );
    expect(tester.takeException(), isNull);
  }, variant: desktop);

  testWidgets(
    'desktop details preserve list position and edit the stored course',
    (tester) async {
      final app = await _mount(tester, desktop: true);
      final row = _key('student-day-course-monday-4');
      await _position(tester).ensureVisible(tester.renderObject(row));
      await tester.pumpAndSettle();
      final position = _position(tester);
      final offset = position.pixels;
      expect(offset, greaterThan(0));
      await _tap(tester, row);
      expect(_details, findsOneWidget);
      expect(_position(tester), same(position));
      expect(position.pixels, closeTo(offset, .01));
      final strings = AppLocalizations.of(tester.element(_details));
      await _tap(
        tester,
        _inside(_details, find.byTooltip(strings.editCourseTooltip)),
      );
      expect(
        tester.widget<CourseEditorSheet>(_editor).initialCourse!.id,
        'monday-4',
      );
      await tester.enterText(
        _key('course-desktop-title'),
        'Revised day lecture',
      );
      await _tap(
        tester,
        _inside(_editor, find.widgetWithText(FilledButton, strings.save)),
      );
      expect(_editor, findsNothing);
      expect(
        app.studentView.activeTimetable.courses
            .firstWhere((course) => course.id == 'monday-4')
            .name,
        'Revised day lecture',
      );
      expect(_details, findsOneWidget);
      await _tap(tester, _inside(_details, _key('workspace-inspector-close')));
      expect(_details, findsNothing);
      expect(_position(tester), same(position));
      expect(position.pixels, closeTo(offset, .01));
      expect(tester.takeException(), isNull);
    },
    variant: desktop,
  );

  testWidgets('inactive input keeps the visible agenda disabled', (
    tester,
  ) async {
    final app = await _mount(tester);
    await tester.pumpWidget(
      WorkspaceHarness(
        provider: app,
        home: const HomeScreen(interactive: false),
      ),
    );
    await tester.pumpAndSettle();
    final agenda = tester.widget<TimetableDayAgenda>(
      find.byType(TimetableDayAgenda),
    );
    expect(agenda.onCourseTap, isNull);
    expect(agenda.onAddCourse, isNull);
    await tester.tap(_key('student-day-course-monday-0'));
    await tester.drag(_agenda, const Offset(-250, 0));
    await tester.pumpAndSettle();
    expect(_details, findsNothing);
    expect(_editor, findsNothing);
    expect(app.studentView.selectedWeek, 5);
    expect(tester.takeException(), isNull);
  }, variant: phone);
}
