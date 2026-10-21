import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/widgets/course_details_sheet.dart';
import 'package:sked/widgets/course_editor_sheet.dart';
import 'package:sked/widgets/sked_mutation_confirmation_dialog.dart';
import 'package:sked/widgets/workspace_editor_form.dart';

import '../support/workspace_harness.dart';

const _tableId = 'conflict-workflow';
const _otherTableId = 'other-owner';
const _periodTimes = [
  CoursePeriodTime(index: 1, startMinutes: 480, endMinutes: 525),
  CoursePeriodTime(index: 2, startMinutes: 540, endMinutes: 585),
  CoursePeriodTime(index: 3, startMinutes: 600, endMinutes: 645),
  CoursePeriodTime(index: 4, startMinutes: 660, endMinutes: 705),
];
final _phone = TargetPlatformVariant.only(TargetPlatform.android);
final _desktop = TargetPlatformVariant.only(TargetPlatform.windows);

Finder _key(String value) => find.byKey(ValueKey(value));
Finder get _details => find.byType(CourseDetailsSheet);
Finder get _editor => find.byType(CourseEditorSheet);
Finder _in(Finder parent, Finder child) =>
    find.descendant(of: parent, matching: child);

CourseItem _course(
  String id,
  String name, {
  int weekday = 1,
  int start = 480,
  int end = 585,
  List<int> weeks = const [],
}) => CourseItem(
  id: id,
  name: name,
  teacher: 'Teacher $id',
  location: 'Room $id',
  dayOfWeek: weekday,
  semesterWeeks: weeks,
  periods: const [],
  startMinutes: start,
  endMinutes: end,
  timeRange: buildTimeRange(start, end),
  credit: 3,
  remarks: '',
  customFields: const {},
);

Future<AppRuntime> _mount(
  WidgetTester tester,
  List<CourseItem> courses, {
  bool desktop = false,
  List<CourseItem>? otherCourses,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = desktop
      ? const Size(1600, 1000)
      : const Size(430, 950);
  addTearDown(tester.view.reset);
  final initial = buildInitialAppData(_periodTimes, localeCode: 'en');
  final config = TimetableConfig(
    name: 'Original timetable',
    startDate: startOfWeekMonday(DateTime.now()),
    totalWeeks: 18,
    periodTimeSetId: initial.studentMode.periodTimeSets.first.id,
  );
  final provider = await workspaceProvider(
    storage: WorkspaceMemoryStorage(
      initial.copyWith(
        activeMode: AppMode.student,
        studentMode: initial.studentMode.copyWith(
          activeTimetableId: _tableId,
          showFutureCourses: false,
          showPastEndedCourses: false,
          timetables: [
            TimetableData(id: _tableId, config: config, courses: courses),
            if (otherCourses != null)
              TimetableData(
                id: _otherTableId,
                config: config.copyWith(name: 'Other timetable'),
                courses: otherCourses,
              ),
          ],
        ),
      ),
    ),
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
  });
  await provider.studentCommands.setSelectedWeek(1);
  if (desktop) {
    await provider.settingsCommands.updateWorkspacePanelDisplayMode(
      WorkspacePanelDisplayMode.sideBySide,
    );
  }
  await tester.pumpWidget(WorkspaceHarness(provider: provider));
  await tester.pumpAndSettle();
  return provider;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _openCourse(WidgetTester tester, String id) async {
  await _tap(tester, _key('timetable-course-hit-$id').hitTestable());
  expect(_details, findsOneWidget);
}

Finder _conflictAction(String name, String tooltip) {
  final title = _in(_details, find.text(name));
  final card = find.ancestor(of: title, matching: find.byType(Material)).first;
  return _in(card, find.byTooltip(tooltip));
}

AppLocalizations _strings(WidgetTester tester) =>
    AppLocalizations.of(tester.element(_details));

Future<void> _saveEditor(WidgetTester tester) async {
  final strings = AppLocalizations.of(tester.element(_editor));
  await _tap(
    tester,
    _in(_editor, find.widgetWithText(FilledButton, strings.save)),
  );
  expect(_editor, findsNothing);
}

Future<void> _deleteEditor(WidgetTester tester) async {
  final strings = AppLocalizations.of(tester.element(_editor));
  await _tap(
    tester,
    _in(_editor, find.widgetWithText(TextButton, strings.delete)),
  );
  await _tap(
    tester,
    _in(
      find.byType(SkedMutationConfirmationDialog),
      find.widgetWithText(TextButton, strings.delete),
    ),
  );
  expect(_editor, findsNothing);
}

void main() {
  testWidgets(
    'real conflict details respect the opened week and exclude hidden future courses',
    (tester) async {
      final a = _course('course-a', 'Week one A', weeks: const [1]);
      final b = _course('course-b', 'Week one B', weeks: const [1]);
      final future = _course('course-c', 'Week two only', weeks: const [2]);
      final provider = await _mount(tester, [a, b, future]);
      await _openCourse(tester, a.id);
      expect(_in(_details, find.text(b.name)), findsOneWidget);
      expect(_in(_details, find.text(future.name)), findsNothing);

      await _tap(
        tester,
        _conflictAction(b.name, _strings(tester).setAsDisplayed),
      );
      expect(_details, findsNothing);
      final conflictKey = buildConflictKeyForCourses(_tableId, 1, [a, b]);
      expect(
        provider.studentView.data.conflictDisplayCourseIds[conflictKey],
        b.id,
      );
      expect(
        _key('timetable-course-hit-${b.id}').hitTestable(),
        findsOneWidget,
      );
      await provider.studentCommands.setSelectedWeek(2);
      await tester.pumpAndSettle();
      expect(_key('timetable-course-hit-${a.id}'), findsNothing);
      expect(_key('timetable-course-hit-${b.id}'), findsNothing);
      await _openCourse(tester, future.id);
      expect(_in(_details, find.text(a.name)), findsNothing);
      expect(_in(_details, find.text(b.name)), findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: _phone,
  );

  testWidgets(
    'deleting another conflict course returns to details and selects the remaining live group',
    (tester) async {
      final a = _course('course-a', 'Course A');
      final b = _course('course-b', 'Course B');
      final c = _course('course-c', 'Course C');
      final provider = await _mount(tester, [a, b, c]);
      await _openCourse(tester, a.id);
      await _tap(
        tester,
        _conflictAction(c.name, _strings(tester).editThisCourse),
      );
      expect(tester.widget<CourseEditorSheet>(_editor).initialCourse!.id, c.id);
      await _deleteEditor(tester);
      expect(_details, findsOneWidget);
      expect(_in(_details, find.text(c.name)), findsNothing);
      expect(_in(_details, find.text(b.name)), findsOneWidget);

      await _tap(
        tester,
        _conflictAction(b.name, _strings(tester).setAsDisplayed),
      );
      expect(_details, findsNothing);
      final key = buildConflictKeyForCourses(_tableId, 1, [a, b]);
      expect(provider.studentView.data.conflictDisplayCourseIds[key], b.id);
      expect(
        _key('timetable-course-hit-${b.id}').hitTestable(),
        findsOneWidget,
      );
      expect(_key('timetable-course-hit-${a.id}'), findsNothing);
      expect(provider.studentView.activeTimetable.courses.map((c) => c.id), [
        a.id,
        b.id,
      ]);
      expect(tester.takeException(), isNull);
    },
    variant: _phone,
  );

  testWidgets(
    'changing the opened course weekday resolves and selects its new conflict group',
    (tester) async {
      final a = _course('course-a', 'Course A');
      final b = _course('course-b', 'Old Monday conflict');
      final d = _course('course-d', 'New Tuesday conflict', weekday: 2);
      final provider = await _mount(tester, [a, b, d]);
      await _openCourse(tester, a.id);
      await _tap(
        tester,
        _in(_details, find.byTooltip(_strings(tester).editCourseTooltip)),
      );
      final strings = AppLocalizations.of(tester.element(_editor));
      final weekdayField = _in(
        _editor,
        find.byWidgetPredicate(
          (widget) =>
              widget is SkedEditorValueField &&
              widget.label == strings.dayOfWeek,
        ),
      );
      await _tap(tester, weekdayField);
      await _tap(tester, find.text(formatDayOfWeekLabel(2, localeCode: 'en')));
      await _saveEditor(tester);
      expect(_details, findsOneWidget);
      expect(_in(_details, find.text(b.name)), findsNothing);
      expect(_in(_details, find.text(d.name)), findsOneWidget);

      await _tap(
        tester,
        _conflictAction(d.name, _strings(tester).setAsDisplayed),
      );
      final moved = provider.studentView.activeTimetable.courses.firstWhere(
        (course) => course.id == a.id,
      );
      expect(moved.dayOfWeek, 2);
      final key = buildConflictKeyForCourses(_tableId, 2, [moved, d]);
      expect(provider.studentView.data.conflictDisplayCourseIds[key], d.id);
      expect(
        _key('timetable-course-hit-${d.id}').hitTestable(),
        findsOneWidget,
      );
      expect(_key('timetable-course-hit-${a.id}'), findsNothing);
      expect(
        _key('timetable-course-hit-${b.id}').hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
    variant: _phone,
  );

  testWidgets(
    'a longer displayed course exposes the fully contained course through the real card',
    (tester) async {
      final long = _course('course-a', 'Long lecture', end: 645);
      final short = _course('course-b', 'Contained seminar', start: 540);
      final provider = await _mount(tester, [long, short]);
      await _openCourse(tester, long.id);
      expect(_in(_details, find.text(short.name)), findsOneWidget);
      await _tap(
        tester,
        _conflictAction(short.name, _strings(tester).setAsDisplayed),
      );
      final key = buildConflictKeyForCourses(_tableId, 1, [long, short]);
      expect(provider.studentView.data.conflictDisplayCourseIds[key], short.id);
      expect(
        _key('timetable-course-hit-${short.id}').hitTestable(),
        findsOneWidget,
      );
      expect(_key('timetable-course-hit-${long.id}'), findsNothing);
      await _openCourse(tester, short.id);
      expect(_in(_details, find.text(long.name)), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: _phone,
  );

  testWidgets(
    'partial chain details use the tapped middle course and only its direct overlaps',
    (tester) async {
      final a = _course('course-a', 'Early lecture', start: 480, end: 540);
      final b = _course('course-b', 'Middle workshop', start: 510, end: 570);
      final c = _course('course-c', 'Later seminar', start: 555, end: 600);
      final remote = _course(
        'course-d',
        'Remote chain member',
        start: 590,
        end: 645,
      );
      await _mount(tester, [a, b, c, remote]);
      await _openCourse(tester, b.id);
      expect(_in(_details, find.text(b.name)), findsOneWidget);
      expect(_in(_details, find.text(a.name)), findsOneWidget);
      expect(_in(_details, find.text(c.name)), findsOneWidget);
      expect(_in(_details, find.text(remote.name)), findsNothing);
      expect(
        _in(_details, find.byTooltip(_strings(tester).setAsDisplayed)),
        findsNothing,
      );

      await _tap(
        tester,
        _conflictAction(c.name, _strings(tester).editThisCourse),
      );
      final initialCourse = tester
          .widget<CourseEditorSheet>(_editor)
          .initialCourse!;
      expect(initialCourse.id, c.id);
      expect(initialCourse.startMinutes, 555);
      expect(initialCourse.endMinutes, 600);
      final strings = AppLocalizations.of(tester.element(_editor));
      await _tap(
        tester,
        _in(_editor, find.widgetWithText(TextButton, strings.cancel)),
      );
      expect(_editor, findsNothing);
      expect(_in(_details, find.text(b.name)), findsOneWidget);
      expect(_in(_details, find.text(c.name)), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: _phone,
  );

  testWidgets(
    'retained conflict editor follows its original timetable after canvas selection changes',
    (tester) async {
      final a = _course('course-a', 'Original A');
      final b = _course('course-b', 'Original B');
      final unrelatedA = a.copyWith(name: 'Other owner A');
      final unrelatedB = b.copyWith(name: 'Other owner B');
      final provider = await _mount(
        tester,
        [a, b],
        desktop: true,
        otherCourses: [unrelatedA, unrelatedB],
      );
      // App loading normalizes duplicate IDs across timetables. Capture the
      // actual persisted owner rather than assuming the fixture IDs survive.
      final otherBefore = provider.studentView.timetables
          .firstWhere((table) => table.id == _otherTableId)
          .toJson();
      await _openCourse(tester, a.id);
      await _tap(tester, _key('resource-timetable-$_otherTableId'));
      expect(provider.studentView.activeTimetable.id, _otherTableId);
      expect(_details, findsOneWidget);
      expect(_in(_details, find.text(a.name)), findsOneWidget);
      expect(_in(_details, find.text(b.name)), findsOneWidget);
      expect(_in(_details, find.text(unrelatedB.name)), findsNothing);
      await _tap(
        tester,
        _conflictAction(b.name, _strings(tester).editThisCourse),
      );
      final initialCourse = tester
          .widget<CourseEditorSheet>(_editor)
          .initialCourse!;
      expect(initialCourse.id, b.id);
      expect(initialCourse.name, b.name);
      await tester.enterText(_key('course-desktop-title'), 'Edited original B');
      await _saveEditor(tester);
      final original = provider.studentView.timetables.firstWhere(
        (table) => table.id == _tableId,
      );
      expect(
        original.courses.firstWhere((course) => course.id == b.id).name,
        'Edited original B',
      );
      expect(provider.studentView.activeTimetable.toJson(), otherBefore);
      expect(
        provider.session.committedData.studentMode.timetables
            .firstWhere((table) => table.id == _otherTableId)
            .toJson(),
        otherBefore,
      );
      expect(provider.studentView.activeTimetable.id, _otherTableId);
      expect(_in(_details, find.text('Edited original B')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: _desktop,
  );
}
