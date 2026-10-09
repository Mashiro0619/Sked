import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/widgets/course_details_sheet.dart';
import 'package:sked/widgets/course_editor_sheet.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';
import 'package:sked/widgets/timetable_information_form.dart';
import 'package:sked/widgets/workspace_frame.dart';

import '../support/desktop_panel_harness.dart';
import '../support/workspace_harness.dart';

Finder _key(String value) => find.byKey(ValueKey(value));
final _desktop = TargetPlatformVariant.only(TargetPlatform.windows);
const floatingAnchorCaptureKey = ValueKey('floating-anchor-capture');

enum FloatingAnchorVisualGroup { student, general }

typedef FloatingAnchorCapture = Future<void> Function(
  WidgetTester tester,
  String scene,
);

Future<void> _mount(
  WidgetTester tester,
  TimetableProvider provider, {
  Size size = const Size(1366, 768),
  Widget? app,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    provider.dispose();
  });
  await provider.updateWorkspacePanelDisplayMode(
    WorkspacePanelDisplayMode.overlay,
  );
  await tester.pumpWidget(
    RepaintBoundary(
      key: floatingAnchorCaptureKey,
      child: app ?? WorkspaceHarness(provider: provider),
    ),
  );
  await tester.pumpAndSettle();
}

Future<TimetableProvider> _studentProvider({
  int weekday = 1,
  int period = 1,
  int timetableCount = 1,
}) async {
  final times = buildDefaultPeriodTimes();
  final time = times[period - 1];
  final initial = buildInitialAppData(times, localeCode: 'en');
  final provider = await workspaceProvider(
    storage: WorkspaceMemoryStorage(
      initial.copyWith(
        studentMode: initial.studentMode.copyWith(
          activeTimetableId: 'anchor-timetable',
          timetables: [
            TimetableData(
              id: 'anchor-timetable',
              config: TimetableConfig(
                name: 'Semester',
                startDate: DateTime(2026, 10, 5),
                totalWeeks: 18,
                periodTimeSetId: initial.studentMode.periodTimeSets.first.id,
              ),
              courses: [
                CourseItem(
                  id: 'anchor-course',
                  name: 'Anchored course',
                  teacher: 'Teacher Chen',
                  location: 'Room 204',
                  dayOfWeek: weekday,
                  semesterWeeks: const [1, 2],
                  periods: [period],
                  startMinutes: time.startMinutes,
                  endMinutes: time.endMinutes,
                  timeRange: '',
                  credit: 2,
                  remarks: 'Bring the workbook',
                  customFields: const {},
                ),
              ],
            ),
            for (var index = 1; index < timetableCount; index++)
              TimetableData(
                id: 'anchor-timetable-$index',
                config: TimetableConfig(
                  name: 'Semester ${index + 1}',
                  startDate: DateTime(2026, 10, 5),
                  totalWeeks: 18,
                  periodTimeSetId: initial.studentMode.periodTimeSets.first.id,
                ),
                courses: const [],
              ),
          ],
        ),
      ),
    ),
  );
  await provider.setSelectedWeek(1);
  return provider;
}

Future<TimetableProvider> _overflowProvider() {
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
          activeScheduleId: 'anchor-calendar',
          selectedDateIso: '2026-10-06',
          defaultView: generalViewWeek,
          dayStartHour: 7,
          dayEndHour: 22,
          schedules: [
            GeneralSchedule(
              id: 'anchor-calendar',
              name: 'Study',
              events: [
                for (var index = 0; index < 6; index++)
                  GeneralEvent(
                    id: 'anchor-overlap-$index',
                    calendarId: 'anchor-calendar',
                    title: 'Evening session ${index + 1}',
                    startDateTimeIso: '2026-10-06T19:00:00.000',
                    endDateTimeIso: '2026-10-06T20:30:00.000',
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

Rect _availableBounds(WidgetTester tester) {
  final canvas = tester.getRect(_key('workspace-canvas'));
  final body = tester.getRect(find.byType(WorkspaceCanvasBody));
  final window = tester.view.physicalSize / tester.view.devicePixelRatio;
  return Rect.fromLTRB(
    canvas.left + 8,
    body.top + 8,
    canvas.right - 8,
    window.height - 8,
  );
}

double _distance(Rect first, Rect second) {
  final dx = math.max(
    0.0,
    math.max(first.left - second.right, second.left - first.right),
  );
  final dy = math.max(
    0.0,
    math.max(first.top - second.bottom, second.top - first.bottom),
  );
  return math.sqrt(dx * dx + dy * dy);
}

Rect _expectNearTrigger(
  WidgetTester tester,
  Rect trigger, {
  required String entry,
}) {
  final panel = tester.getRect(_key('workspace-detail-surface'));
  final available = _availableBounds(tester);
  expect(panel.left, greaterThanOrEqualTo(available.left - .1));
  expect(panel.top, greaterThanOrEqualTo(available.top - .1));
  expect(panel.right, lessThanOrEqualTo(available.right + .1));
  expect(panel.bottom, lessThanOrEqualTo(available.bottom + .1));
  // A toolbar or sidebar control can be outside the safe canvas. Allow only
  // that unavoidable inset plus the small visual gap, not a centered fallback.
  expect(
    _distance(trigger, panel),
    lessThanOrEqualTo(_distance(trigger, available) + 8.1),
    reason: '$entry must open beside its trigger $trigger; got $panel.',
  );
  expect(
    panel.overlaps(trigger),
    isFalse,
    reason:
        'These fixtures leave room beside the whole trigger, not just its '
        'pointer position: $entry, trigger $trigger, panel $panel.',
  );
  return panel;
}

void main() {
  runFloatingAnchorRegressionTests();
  _registerPickerHandoffTests();
  _registerNestedEditorTests();
}

void runFloatingAnchorRegressionTests({
  FloatingAnchorVisualGroup? group,
  FloatingAnchorCapture? capture,
}) {
  if (group == null || group == FloatingAnchorVisualGroup.student) {
    _registerStudentAnchorTests(capture);
  }
  if (group == null || group == FloatingAnchorVisualGroup.general) {
    _registerGeneralAnchorTests(capture);
  }
}

void _registerStudentAnchorTests(FloatingAnchorCapture? capture) {
  for (final editing in [true, false]) {
    testWidgets(
      'sidebar ${editing ? 'edit' : 'create'} timetable stays at its button',
      (tester) async {
        final provider = await _studentProvider();
        await _mount(tester, provider);
        final Finder trigger;
        if (editing) {
          final row = _key('resource-timetable-anchor-timetable');
          final mouse = await tester.createGesture(
            kind: PointerDeviceKind.mouse,
          );
          await mouse.addPointer(location: tester.getCenter(row));
          addTearDown(mouse.removePointer);
          await tester.pumpAndSettle();
          trigger = _key('resource-timetable-edit-anchor-timetable');
        } else {
          final l10n = AppLocalizations.of(
            tester.element(find.byType(WorkspaceFrame)),
          );
          trigger = find.byTooltip(l10n.createTimetable).hitTestable();
        }
        final anchor = tester.getRect(trigger);
        expect(trigger.hitTestable(), findsOneWidget);
        await tester.tap(trigger);
        await tester.pumpAndSettle();
        expect(find.byType(TimetableInformationDialogSurface), findsOneWidget);
        final panel = _expectNearTrigger(
          tester,
          anchor,
          entry: editing ? 'Edit timetable' : 'Create timetable',
        );
        expect(panel.left, closeTo(_availableBounds(tester).left, .1));
        expect(
          panel.top,
          closeTo(anchor.top, .1),
          reason: 'The panel follows the actual icon, not the entire row.',
        );
        expect(tester.takeException(), isNull);
        await capture?.call(
          tester,
          editing ? 'sidebar-edit-timetable' : 'sidebar-create-timetable',
        );
      },
      variant: _desktop,
    );
  }

  for (final (weekday, period) in [(1, 1), (7, 12)]) {
    testWidgets(
      'course details attach to day $weekday period $period and fit the window',
      (tester) async {
        final provider = await _studentProvider(
          weekday: weekday,
          period: period,
        );
        await _mount(tester, provider);
        final course = _key('timetable-course-hit-anchor-course');
        await Scrollable.ensureVisible(
          tester.element(course),
          alignment: period == 1 ? 0 : .9,
        );
        await tester.pumpAndSettle();
        final anchor = tester.getRect(course);
        expect(course.hitTestable(), findsOneWidget);
        await tester.tap(course);
        await tester.pumpAndSettle();
        expect(find.byType(CourseDetailsSheet), findsOneWidget);
        final panel = _expectNearTrigger(
          tester,
          anchor,
          entry: 'Course details',
        );
        if (weekday == 1) {
          expect(panel.left, closeTo(anchor.right + 6, .1));
        } else {
          expect(panel.right, closeTo(anchor.left - 6, .1));
          expect(panel.top, lessThan(anchor.top));
        }
        expect(tester.takeException(), isNull);
        await capture?.call(tester, 'course-day-$weekday-period-$period');
      },
      variant: _desktop,
    );
  }
}

void _registerGeneralAnchorTests(FloatingAnchorCapture? capture) {
  testWidgets('evening overflow list opens beside its visible more card', (
    tester,
  ) async {
    final provider = await _overflowProvider();
    await _mount(tester, provider, size: const Size(1000, 900));
    final more = find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith(
            'general-timed-more-occurrences-anchor-overlap-',
          ),
    );
    expect(more, findsOneWidget);
    await Scrollable.ensureVisible(tester.element(more), alignment: .9);
    await tester.pumpAndSettle();
    final anchor = tester.getRect(more);
    expect(more.hitTestable(), findsOneWidget);
    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(_key('general-more-occurrences-sheet'), findsOneWidget);
    final panel = _expectNearTrigger(tester, anchor, entry: 'More events');
    expect(panel.top, lessThan(anchor.top));
    expect(tester.takeException(), isNull);
    await capture?.call(tester, 'evening-more-events');
  }, variant: _desktop);

  for (final (entry, content) in [
    ('general-day-agenda-toggle', 'general-selected-day-agenda'),
    ('general-reminders-action', 'general-reminders-list'),
  ]) {
    testWidgets('$entry follows the toolbar without a cached pointer event', (
      tester,
    ) async {
      final provider = await workspaceProvider(
        mode: AppMode.general,
        storage: desktopPanelStorage(count: 3),
      );
      await _mount(
        tester,
        provider,
        size: const Size(1100, 900),
        app: desktopPanelHarness(provider),
      );
      final trigger = _key(entry);
      final anchor = tester.getRect(trigger);
      // Keyboard and accessibility activation invoke this callback without
      // generating the mouse event used by the frame's fallback anchor cache.
      tester.widget<IconButton>(trigger).onPressed!();
      await tester.pumpAndSettle();
      expect(_key(content), findsOneWidget);
      _expectNearTrigger(tester, anchor, entry: entry);
      expect(tester.takeException(), isNull);
      await capture?.call(tester, entry);
    }, variant: _desktop);
  }
}

void _registerPickerHandoffTests() {
  for (final editing in [true, false]) {
    testWidgets(
      'timetable picker ${editing ? 'low-row edit' : 'footer create'} keeps the dismissed button anchor',
      (tester) async {
        final provider = await _studentProvider(timetableCount: 6);
        await _mount(tester, provider, size: const Size(1366, 1000));
        final l10n = AppLocalizations.of(
          tester.element(find.byType(WorkspaceFrame)),
        );
        await tester.tap(_key('workspace-resource-open'));
        await tester.pumpAndSettle();
        final trigger = editing
            ? find
                  .ancestor(
                    of: find.descendant(
                      of: _key('timetable-picker-item-anchor-timetable-5'),
                      matching: find.byTooltip(l10n.editTimetable),
                    ),
                    matching: find.byType(IconButton),
                  )
                  .first
            : find.widgetWithText(FilledButton, l10n.createTimetable);
        await tester.ensureVisible(trigger);
        await tester.pumpAndSettle();
        // The last mouse input opened the picker at its toolbar button. Expire
        // that fallback and activate the actual low button as a keyboard does.
        await tester.pump(const Duration(seconds: 2));
        final anchor = tester.getRect(trigger);
        final source = tester.element(trigger);
        if (editing) {
          tester.widget<IconButton>(trigger).onPressed!();
        } else {
          tester.widget<FilledButton>(trigger).onPressed!();
        }
        await tester.pumpAndSettle();
        expect(source.mounted, isFalse);
        expect(find.text(l10n.multiTimetableSwitch), findsNothing);
        expect(find.byType(TimetableInformationDialogSurface), findsOneWidget);
        final panel = _expectNearTrigger(
          tester,
          anchor,
          entry: editing ? 'Picker edit timetable' : 'Picker create timetable',
        );
        expect(panel.top, closeTo(anchor.top, .1));
        for (var frame = 0; frame < 3; frame++) {
          await tester.pump(const Duration(milliseconds: 100));
          expect(tester.getRect(_key('workspace-detail-surface')), panel);
        }
        expect(tester.takeException(), isNull);
      },
      variant: _desktop,
    );
  }
}

void _registerNestedEditorTests() {
  for (final student in [true, false]) {
    testWidgets(
      '${student ? 'course details edit' : 'floating day agenda add'} keeps its original anchor through layout and typing',
      (tester) async {
        final provider = student
            ? await _studentProvider()
            : await workspaceProvider(
                mode: AppMode.general,
                storage: desktopPanelStorage(count: 3),
              );
        final originalSize = student
            ? const Size(1600, 1100)
            : const Size(1100, 900);
        await _mount(
          tester,
          provider,
          size: originalSize,
          app: student ? null : desktopPanelHarness(provider),
        );
        await tester.tap(
          _key(
            student
                ? 'timetable-course-hit-anchor-course'
                : 'general-day-agenda-toggle',
          ),
        );
        await tester.pumpAndSettle();
        final sourcePanel = student
            ? find.byType(CourseDetailsSheet)
            : _key('general-selected-day-agenda');
        final sourceNavigator = Navigator.of(tester.element(sourcePanel));
        final l10n = AppLocalizations.of(tester.element(sourcePanel));
        final trigger = student
            ? find.descendant(
                of: sourcePanel,
                matching: find.byTooltip(l10n.editCourseTooltip),
              )
            : _key('general-day-agenda-add');
        final anchor = tester.getRect(trigger);
        await tester.tap(trigger);
        await tester.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 3),
        );
        final editor = student
            ? find.byType(CourseEditorSheet)
            : find.byType(GeneralEventEditorSheet);
        expect(editor, findsOneWidget);
        expect(Navigator.of(tester.element(editor)), same(sourceNavigator));
        final editorElement = tester.element(editor);
        final panel = _expectNearTrigger(
          tester,
          anchor,
          entry: student ? 'Edit viewed course' : 'Add selected-day event',
        );
        for (var frame = 0; frame < 4; frame++) {
          await tester.pump(const Duration(milliseconds: 100));
          expect(tester.getRect(_key('workspace-detail-surface')), panel);
        }
        final title = find
            .descendant(of: editor, matching: find.byType(TextField))
            .first;
        await tester.enterText(title, 'Retained anchor draft');
        await tester.pumpAndSettle();
        expect(tester.getRect(_key('workspace-detail-surface')), panel);
        // Both sizes retain enough room at the original captured position.
        // Resizing the shared Navigator must not make its hidden source chase
        // the new editor, and returning to the old size must not move it again.
        for (final size in [
          student ? const Size(1500, 1000) : const Size(1100, 950),
          originalSize,
        ]) {
          tester.view.physicalSize = size;
          await tester.pumpAndSettle();
          final available = _availableBounds(tester);
          expect(panel.left, greaterThanOrEqualTo(available.left));
          expect(panel.right, lessThanOrEqualTo(available.right));
          expect(panel.top, greaterThanOrEqualTo(available.top));
          expect(panel.bottom, lessThanOrEqualTo(available.bottom));
          expect(tester.getRect(_key('workspace-detail-surface')), panel);
          expect(tester.element(editor), same(editorElement));
          expect(find.text('Retained anchor draft'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
      variant: _desktop,
    );
  }
}
