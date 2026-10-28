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
  Size? viewportSize,
  double textScale = 1,
  bool compactCourseLabels = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize =
      viewportSize ?? (desktop ? const Size(1362, 768) : const Size(430, 850));
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
          _course('monday-$index', DateTime.monday, 480 + index * 60).copyWith(
            name: compactCourseLabels ? 'Class ${index + 1}' : null,
            teacher: compactCourseLabels ? 'Dr Lin' : null,
            location: compactCourseLabels ? 'R108' : null,
          ),
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
    WorkspaceHarness(
      provider: app,
      home: const HomeScreen(),
      textScale: textScale,
    ),
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

Future<void> _dragToEnd(WidgetTester tester) async {
  expect(_position(tester).maxScrollExtent, greaterThan(0));
  final drag = Offset(0, -tester.getSize(_agenda).height * .8);
  for (var attempt = 0; attempt < 12; attempt++) {
    if (_position(tester).extentAfter < .5) break;
    await tester.drag(_agenda, drag);
    await tester.pumpAndSettle();
  }
  expect(_position(tester).extentAfter, lessThan(.5));
}

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

  for (final size in [const Size(320, 640), const Size(390, 844)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'last HomeScreen day card clears the FAB and releases space when hidden: $size at $scale',
        (tester) async {
          tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
          tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
          final app = await _mount(
            tester,
            viewportSize: size,
            textScale: scale,
            compactCourseLabels: true,
          );
          final before = app.studentView.activeTimetable.toJson();
          final lastCard = _key('student-day-course-card-monday-8');
          final fab = find.byType(FloatingActionButton);
          await _dragToEnd(tester);
          final viewport = tester.getRect(_agenda);
          final button = tester.getRect(fab);
          final cardWithFab = tester.getRect(lastCard);

          // These are painted HomeScreen bounds, not an assertion about the
          // inset parameter. The whole last card must fit above the real FAB.
          expect(cardWithFab.top, greaterThanOrEqualTo(viewport.top));
          expect(cardWithFab.bottom, lessThanOrEqualTo(button.top - 8));
          expect(cardWithFab.left, lessThan(button.right));
          expect(cardWithFab.right, greaterThan(button.left));
          expect(lastCard.hitTestable(), findsOneWidget);

          await app.settingsCommands.updateShowAddCourseFab(false);
          await tester.pumpAndSettle();
          await _dragToEnd(tester);
          expect(fab, findsNothing);
          expect(tester.getRect(_agenda), viewport);
          final cardWithoutFab = tester.getRect(lastCard);
          expect(cardWithoutFab.top, greaterThanOrEqualTo(viewport.top));
          expect(cardWithoutFab.bottom, lessThanOrEqualTo(viewport.bottom));
          expect(
            cardWithoutFab.bottom - cardWithFab.bottom,
            greaterThan(button.height),
          );
          expect(lastCard.hitTestable(), findsOneWidget);

          await app.settingsCommands.updateShowAddCourseFab(true);
          await tester.pumpAndSettle();
          await _dragToEnd(tester);
          final restoredCard = tester.getRect(lastCard);
          final restoredFab = tester.getRect(fab);
          expect(tester.getRect(_agenda), viewport);
          expect(restoredCard.top, greaterThanOrEqualTo(viewport.top));
          expect(restoredCard.bottom, lessThanOrEqualTo(restoredFab.top - 8));
          expect(app.studentView.activeTimetable.toJson(), before);

          // Probe the card's lower-right area in the FAB's horizontal column.
          // An obscured card would open the add editor or miss this tap.
          final point = Offset(restoredFab.center.dx, restoredCard.bottom - 12);
          expect(restoredCard.contains(point), isTrue);
          await tester.tapAt(point);
          await tester.pumpAndSettle();
          expect(_details, findsOneWidget);
          expect(
            tester.widget<CourseDetailsSheet>(_details).courseId,
            'monday-8',
          );
          expect(_editor, findsNothing);
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant({
          TargetPlatform.android,
          TargetPlatform.iOS,
        }),
      );
    }
  }

  testWidgets(
    'a tall final day card exposes its start and tail without FAB obstruction',
    (tester) async {
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
      tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
      final app = await _mount(
        tester,
        viewportSize: const Size(320, 640),
        textScale: 2,
      );
      final before = app.studentView.activeTimetable.toJson();
      final lastCard = _key('student-day-course-card-monday-8');
      final time = _key('student-day-course-inline-time-monday-8');
      final title = _inside(lastCard, find.text('Lecture monday-8'));
      final teacher = _inside(lastCard, find.text('Teacher monday-8'));
      await _dragToEnd(tester);
      final viewport = tester.getRect(_agenda);
      final fab = tester.getRect(find.byType(FloatingActionButton));
      final card = tester.getRect(lastCard);
      expect(card.height, greaterThan(fab.top - viewport.top));
      expect(card.bottom, lessThanOrEqualTo(fab.top - 8));

      // A card taller than the unobstructed viewport must be readable in
      // sections. Reveal the clipped start, then return to its cleared tail.
      expect(tester.getRect(time).top, lessThan(viewport.top));
      await _position(tester).ensureVisible(tester.renderObject(time));
      await tester.pumpAndSettle();
      expect(_position(tester).extentAfter, greaterThan(0));
      for (final content in [time, title]) {
        final rect = tester.getRect(content);
        expect(rect.top, greaterThanOrEqualTo(viewport.top));
        expect(rect.bottom, lessThanOrEqualTo(fab.top));
      }
      await _dragToEnd(tester);
      final tail = tester.getRect(teacher);
      expect(tail.top, greaterThanOrEqualTo(viewport.top));
      expect(tail.bottom, lessThanOrEqualTo(fab.top));
      final finalCard = tester.getRect(lastCard);
      await tester.tapAt(Offset(fab.center.dx, finalCard.bottom - 12));
      await tester.pumpAndSettle();
      expect(tester.widget<CourseDetailsSheet>(_details).courseId, 'monday-8');
      expect(_editor, findsNothing);
      expect(app.studentView.activeTimetable.toJson(), before);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

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

  testWidgets('phone FAB remains the single add action on empty days', (
    tester,
  ) async {
    final app = await _mount(tester);
    await _tap(tester, _key('student-day-2'));
    await _tap(tester, find.byTooltip('Add course'));
    expect(
      tester.widget<CourseEditorSheet>(_editor).dayOfWeek,
      DateTime.tuesday,
    );
    await _closeEditor(tester);

    await _tap(tester, _key('student-day-3'));
    expect(find.text('No courses for this day'), findsOneWidget);
    expect(
      _inside(_agenda, find.widgetWithText(FilledButton, 'Add course')),
      findsNothing,
    );
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text('Lecture monday-0'), findsOneWidget);
    final nextDate = startOfWeekFor(app.studentView.activeTimetable.config, 6);
    final strings = MaterialLocalizations.of(tester.element(_agenda));
    expect(find.text(strings.formatFullDate(nextDate)), findsOneWidget);
    await _tap(tester, find.byType(FloatingActionButton));
    expect(
      tester.widget<CourseEditorSheet>(_editor).dayOfWeek,
      DateTime.wednesday,
    );
    expect(tester.takeException(), isNull);
  }, variant: phone);

  testWidgets('empty-day add respects the existing phone FAB preference', (
    tester,
  ) async {
    final app = await _mount(tester, populated: false);
    expect(
      _inside(_agenda, find.widgetWithText(FilledButton, 'Add course')),
      findsNothing,
    );
    expect(find.byType(FloatingActionButton), findsOneWidget);
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
    await app.settingsCommands.updateShowAddCourseFab(true);
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsOneWidget);
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
    expect(find.text('No courses for this day'), findsOneWidget);
    expect(
      _inside(_agenda, find.widgetWithText(FilledButton, 'Add course')),
      findsNothing,
    );
    expect(_key('student-add-course'), findsOneWidget);
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
