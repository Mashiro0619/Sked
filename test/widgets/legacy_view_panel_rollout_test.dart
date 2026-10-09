import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/widgets/course_details_sheet.dart';
import 'package:sked/widgets/course_editor_sheet.dart';
import 'package:sked/widgets/general_event_details_sheet.dart';
import 'package:sked/widgets/workspace_view_panel.dart';

import '../support/workspace_harness.dart';

final _desktop = TargetPlatformVariant.only(TargetPlatform.windows);
Finder _key(String value) => find.byKey(ValueKey(value));
Finder _in(Finder owner, Finder matching) =>
    find.descendant(of: owner, matching: matching);
Finder get _courseDetails => find.byType(CourseDetailsSheet);
Finder get _moreEvents => _key('general-more-occurrences-sheet');

Future<void> _mount(
  WidgetTester tester,
  TimetableProvider provider, {
  Size size = const Size(1440, 1000),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
  });
  await tester.pumpWidget(WorkspaceHarness(provider: provider));
  await tester.pumpAndSettle();
}

Future<TimetableProvider> _courseProvider() async {
  final initial = buildInitialAppData(
    buildDefaultPeriodTimes(),
    localeCode: 'en',
  );
  final provider = await workspaceProvider(
    storage: WorkspaceMemoryStorage(
      initial.copyWith(
        studentMode: initial.studentMode.copyWith(
          activeTimetableId: 'view-panel-timetable',
          timetables: [
            TimetableData(
              id: 'view-panel-timetable',
              config: TimetableConfig(
                name: 'Semester',
                startDate: DateTime(2026, 10, 5),
                totalWeeks: 18,
                periodTimeSetId: initial.studentMode.periodTimeSets.first.id,
              ),
              courses: [
                CourseItem(
                  id: 'view-panel-course',
                  name: 'View panel course',
                  teacher: 'Teacher Chen',
                  location: 'Room 204',
                  dayOfWeek: 1,
                  semesterWeeks: const [1, 2],
                  periods: const [1],
                  startMinutes: 480,
                  endMinutes: 525,
                  timeRange: '08:00-08:45',
                  credit: 2,
                  remarks: 'Bring the workbook',
                  customFields: const {},
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  await provider.setSelectedWeek(1);
  return provider;
}

Future<TimetableProvider> _generalProvider({
  required List<GeneralEvent> events,
  String view = generalViewWeek,
  bool collapsed = false,
}) {
  final initial = buildInitialAppData(
    buildDefaultPeriodTimes(),
    localeCode: 'en',
  );
  return workspaceProvider(
    mode: AppMode.general,
    storage: WorkspaceMemoryStorage(
      initial.copyWith(
        activeMode: AppMode.general,
        generalMode: initial.generalMode.copyWith(
          activeScheduleId: 'view-panel-calendar',
          schedules: [
            GeneralSchedule(
              id: 'view-panel-calendar',
              name: 'Study',
              events: events,
            ),
          ],
          selectedDateIso: '2026-10-06',
          defaultView: view,
          allDayTimelineCollapsed: collapsed,
          dayStartHour: 7,
          dayEndHour: 22,
        ),
      ),
    ),
  );
}

void _expectViewHeader(WidgetTester tester, String title) {
  expect(find.byType(WorkspaceViewPanel), findsOneWidget);
  expect(_key('workspace-inspector-header'), findsNothing);
  expect(_key('workspace-view-header'), findsOneWidget);
  expect(_in(_key('workspace-view-header'), find.text(title)), findsOneWidget);
  expect(_key('workspace-inspector-close'), findsOneWidget);
  expect(
    _in(
      _key('workspace-view-header'),
      _key('workspace-inspector-close'),
    ).hitTestable(),
    findsOneWidget,
  );
  expect(tester.getSize(_key('workspace-view-body')).height, greaterThan(24));
}

void _expectFloatingBounds(WidgetTester tester) {
  final bounds = tester.getRect(_key('workspace-detail-surface'));
  final window = tester.view.physicalSize / tester.view.devicePixelRatio;
  expect(_key('workspace-view-drag-handle'), findsOneWidget);
  expect(bounds.height, greaterThan(100));
  expect(bounds.height, lessThan(window.height));
  expect(bounds.left, greaterThanOrEqualTo(0));
  expect(bounds.top, greaterThan(0));
  expect(bounds.right, lessThanOrEqualTo(window.width));
  expect(bounds.bottom, lessThanOrEqualTo(window.height));
}

Future<void> _closeView(WidgetTester tester) async {
  await tester.tap(_key('workspace-inspector-close'));
  await tester.pumpAndSettle();
}

void main() {
  for (final mode in [
    WorkspacePanelDisplayMode.overlay,
    WorkspacePanelDisplayMode.sideBySide,
  ]) {
    testWidgets(
      'course details use one view header and restore after editing: ${mode.name}',
      (tester) async {
        final provider = await _courseProvider();
        await provider.updateWorkspacePanelDisplayMode(mode);
        await _mount(tester, provider);
        final course = _key('timetable-course-hit-view-panel-course');
        await tester.tap(course);
        await tester.pumpAndSettle();

        _expectViewHeader(tester, 'View panel course');
        expect(
          _in(_courseDetails, find.text('Room 204')).hitTestable(),
          findsOneWidget,
        );
        if (mode == WorkspacePanelDisplayMode.overlay) {
          _expectFloatingBounds(tester);
          expect(
            tester.getSize(_key('workspace-detail-surface')).height,
            lessThan(650),
          );
        } else {
          expect(_key('workspace-view-drag-handle'), findsNothing);
        }

        await _closeView(tester);
        expect(_courseDetails, findsNothing);
        expect(course.hitTestable(), findsOneWidget);
        await tester.tap(course);
        await tester.pumpAndSettle();
        final l10n = AppLocalizations.of(tester.element(_courseDetails));
        final edit = _in(
          _courseDetails,
          find.byTooltip(l10n.editCourseTooltip),
        );
        await tester.tap(edit);
        await tester.pumpAndSettle();
        expect(find.byType(CourseEditorSheet), findsOneWidget);
        expect(
          tester
              .widget<CourseEditorSheet>(find.byType(CourseEditorSheet))
              .initialCourse!
              .id,
          'view-panel-course',
        );
        await tester.tap(_key('workspace-editor-close'));
        await tester.pumpAndSettle();

        expect(find.byType(CourseEditorSheet), findsNothing);
        _expectViewHeader(tester, 'View panel course');
        expect(edit.hitTestable(), findsOneWidget);
        expect(
          _in(_courseDetails, find.text('Bring the workbook')).hitTestable(),
          findsOneWidget,
        );
        await _closeView(tester);
        expect(_courseDetails, findsNothing);
        expect(tester.takeException(), isNull);
      },
      variant: _desktop,
    );
  }

  for (final view in [generalViewDay, generalViewWeek]) {
    testWidgets(
      '$view overflow opens a visible floating list and restores it after details',
      (tester) async {
        // Six overlaps overflow a week column. A full-width day needs enough
        // events that even a 1000px canvas cannot show every 64px column.
        final count = view == generalViewDay ? 16 : 6;
        final provider = await _generalProvider(
          view: view,
          events: [
            for (var index = 0; index < count; index++)
              GeneralEvent(
                id: 'view-panel-overlap-$index',
                calendarId: 'view-panel-calendar',
                title: 'Parallel event ${index + 1}',
                startDateTimeIso: '2026-10-06T09:00:00.000',
                endDateTimeIso: '2026-10-06T10:30:00.000',
                location: 'Seminar room ${index + 1}',
              ),
          ],
        );
        await _mount(tester, provider, size: const Size(1000, 900));
        final more = find.byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith(
                'general-timed-more-occurrences-view-panel-overlap-',
              ),
        );
        expect(more, findsOneWidget);
        await tester.tap(more);
        await tester.pumpAndSettle();

        final l10n = AppLocalizations.of(tester.element(_moreEvents));
        _expectViewHeader(tester, l10n.monthDayEvents(6, count));
        _expectFloatingBounds(tester);
        expect(
          _in(_moreEvents, find.text('Parallel event 1')).hitTestable(),
          findsOneWidget,
        );
        for (final index in [count - 1, 0]) {
          final row = _in(
            _moreEvents,
            find.text('Parallel event ${index + 1}'),
          );
          await tester.ensureVisible(row);
          await tester.pumpAndSettle();
          await tester.tap(row);
          await tester.pumpAndSettle();
          final details = find.byType(GeneralEventDetailsSheet);
          expect(details, findsOneWidget);
          expect(
            tester
                .widget<GeneralEventDetailsSheet>(details)
                .occurrence
                .event
                .id,
            'view-panel-overlap-$index',
          );
          await _closeView(tester);
          expect(details, findsNothing);
          _expectViewHeader(tester, l10n.monthDayEvents(6, count));
          expect(row.hitTestable(), findsOneWidget);
        }
        await _closeView(tester);
        expect(_moreEvents, findsNothing);
        await tester.tap(more);
        await tester.pumpAndSettle();
        expect(
          _in(_moreEvents, find.text('Parallel event 1')).hitTestable(),
          findsOneWidget,
        );
        await _closeView(tester);
        expect(tester.takeException(), isNull);
      },
      variant: _desktop,
    );
  }

  testWidgets(
    'collapsed all-day groups open the selected day in a floating list',
    (tester) async {
      final provider = await _generalProvider(
        collapsed: true,
        events: [
          for (final (id, title, day) in [
            ('tuesday-first', 'Tuesday first', 6),
            ('tuesday-second', 'Tuesday second', 6),
            ('thursday', 'Thursday event', 8),
          ])
            GeneralEvent(
              id: id,
              calendarId: 'view-panel-calendar',
              title: title,
              startDateTimeIso: DateTime(2026, 10, day).toIso8601String(),
              endDateTimeIso: DateTime(2026, 10, day + 1).toIso8601String(),
              isAllDay: true,
            ),
        ],
      );
      await _mount(tester, provider);
      await tester.tap(_key('general-all-day-collapsed-1'));
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(tester.element(_moreEvents));
      _expectViewHeader(tester, l10n.monthDayEvents(6, 2));
      _expectFloatingBounds(tester);
      expect(_in(_moreEvents, find.text('Thursday event')), findsNothing);
      await tester.tap(_in(_moreEvents, find.text('Tuesday first')));
      await tester.pumpAndSettle();
      expect(find.byType(GeneralEventDetailsSheet), findsOneWidget);
      await _closeView(tester);
      expect(
        _in(_moreEvents, find.text('Tuesday second')).hitTestable(),
        findsOneWidget,
      );
      await _closeView(tester);
      expect(provider.allDayTimelineCollapsed, isTrue);

      await tester.tap(_key('general-all-day-collapsed-3'));
      await tester.pumpAndSettle();
      _expectViewHeader(tester, l10n.monthDayEvents(8, 1));
      expect(
        _in(_moreEvents, find.text('Thursday event')).hitTestable(),
        findsOneWidget,
      );
      expect(_in(_moreEvents, find.text('Tuesday first')), findsNothing);
      await _closeView(tester);
      expect(_moreEvents, findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: _desktop,
  );
}
