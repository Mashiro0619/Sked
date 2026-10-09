import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/widgets/app_modal_sheet.dart';
import 'package:sked/widgets/course_editor_sheet.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';
import 'package:sked/widgets/timetable_information_form.dart';
import 'package:sked/widgets/workspace_editor_time_rows.dart';
import 'package:sked/widgets/workspace_frame.dart';

import '../test/support/workspace_harness.dart';

enum _EditorGroup { course, event, timetable }

const _captureKey = ValueKey('hybrid-editor-visual-capture');
const _surfaceKey = ValueKey('workspace-detail-surface');
const _resizeKey = ValueKey('workspace-detail-resize');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Run each family in its own Windows runner process. This also makes a
  // failed native run independently reproducible without mixing workspaces.
  final group = _EditorGroup.values.byName(
    const String.fromEnvironment('SKED_VISUAL_GROUP', defaultValue: 'course'),
  );
  for (final (locale, editing, scale, brightness, direction) in [
    ('zh', false, 1.0, Brightness.light, TextDirection.ltr),
    ('zh', true, 1.0, Brightness.light, TextDirection.ltr),
    ('en', true, 1.0, Brightness.light, TextDirection.ltr),
    ('en', true, 2.0, Brightness.dark, TextDirection.rtl),
  ]) {
    final name = '${group.name}-$locale-${editing ? 'edit' : 'add'}-${scale}x';
    testWidgets('hybrid editor Windows fonts: $name', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 1000);
      addTearDown(tester.view.reset);
      final mode = group == _EditorGroup.event
          ? AppMode.general
          : AppMode.student;
      final storage = WorkspaceMemoryStorage(_fixtureData(mode, locale));
      final provider = await workspaceProvider(
        mode: mode,
        locale: locale,
        storage: storage,
      );
      await provider.updateWorkspacePanelDisplayMode(
        WorkspacePanelDisplayMode.overlay,
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        provider.dispose();
      });
      await tester.pumpWidget(
        RepaintBoundary(
          key: _captureKey,
          child: WorkspaceHarness(
            provider: provider,
            locale: Locale(locale),
            textScale: scale,
            brightness: brightness,
            textDirection: direction,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _openEditor(tester, provider, group, editing: editing);
      await tester.pumpAndSettle();
      final editor = find.byType(switch (group) {
        _EditorGroup.course => CourseEditorSheet,
        _EditorGroup.event => GeneralEventEditorSheet,
        _EditorGroup.timetable => TimetableInformationDialogSurface,
      });
      expect(editor, findsOneWidget);
      final element = tester.element(editor);
      final strings = AppLocalizations.of(element);
      final title = find
          .descendant(of: editor, matching: find.byType(TextField))
          .first;
      final titleController = tester.widget<TextField>(title).controller!;
      final draft = titleController.text;
      expect(tester.getSize(find.byKey(_surfaceKey)).width, closeTo(600, .1));
      if (group == _EditorGroup.event && scale == 1) {
        final dates = find.descendant(
          of: find.byType(WorkspaceEditorTimeRows),
          matching: find.byTooltip(strings.pickDate),
        );
        final allDay = find.descendant(
          of: find.byType(WorkspaceEditorTimeRows),
          matching: find.byType(Switch),
        );
        expect(
          tester.getRect(allDay).bottom,
          lessThan(tester.getRect(dates.first).top),
        );
        expect(
          tester.getRect(dates.first).top,
          closeTo(tester.getRect(dates.last).top, .1),
        );
      }
      await _capture(tester, '$name-floating');
      if (locale == 'zh' && editing) {
        if (group == _EditorGroup.event) {
          final toggle = find.descendant(
            of: find.byType(WorkspaceEditorTimeRows),
            matching: find.byType(Switch),
          );
          await tester.tap(toggle);
          await tester.pumpAndSettle();
          expect(
            find.descendant(
              of: editor,
              matching: find.byTooltip(strings.pickTime),
            ),
            findsNothing,
          );
          await _capture(tester, '$name-all-day');
          await tester.tap(toggle);
          await tester.pumpAndSettle();
          expect(
            find.descendant(
              of: editor,
              matching: find.byTooltip(strings.pickTime),
            ),
            findsNWidgets(2),
          );
        }
        if (group != _EditorGroup.timetable) {
          final more = find.descendant(
            of: editor,
            matching: find.byType(ExpansionTile),
          );
          await tester.ensureVisible(more);
          final disclosure = tester.widget<ExpansionTile>(more);
          if (!(disclosure.controller?.isExpanded ??
              disclosure.initiallyExpanded)) {
            await tester.tap(
              find.descendant(of: more, matching: find.text(strings.more)),
            );
          }
          await tester.pumpAndSettle();
          await _capture(tester, '$name-more');
        }
        await provider.updateWorkspacePanelDisplayMode(
          WorkspacePanelDisplayMode.sideBySide,
        );
        await tester.pumpAndSettle();
        expect(tester.element(editor), same(element));
        await _capture(tester, '$name-docked');
        await provider.updateWorkspacePanelDisplayMode(
          WorkspacePanelDisplayMode.overlay,
        );
        await tester.pumpAndSettle();
        for (final (width, delta) in [(480, 120.0), (320, 160.0)]) {
          await tester.drag(find.byKey(_resizeKey), Offset(delta, 0));
          await tester.pumpAndSettle();
          expect(
            tester.getSize(find.byKey(_surfaceKey)).width,
            closeTo(width, .1),
          );
          expect(tester.element(editor), same(element));
          expect(
            tester.widget<TextField>(title).controller,
            same(titleController),
          );
          expect(titleController.text, draft);
          await _capture(tester, '$name-width-$width');
        }
        tester.view.physicalSize = const Size(720, 420);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('workspace-editor-close')).hitTestable(),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(FilledButton, strings.save).hitTestable(),
          findsOneWidget,
        );
        await _capture(tester, '$name-short');
        tester.view.physicalSize = const Size(1440, 1000);
        await tester.pumpAndSettle();
        await tester.drag(find.byKey(_resizeKey), const Offset(-280, 0));
        await tester.pumpAndSettle();
        expect(tester.getSize(find.byKey(_surfaceKey)).width, closeTo(600, .1));
        await tester.ensureVisible(title);
        await tester.enterText(title, '$draft · 更新');
        await tester.pumpAndSettle();
        final retryDraft = titleController.text;
        storage.saveError = StateError('Visual test: in-memory save failed');
        final save = find.widgetWithText(FilledButton, strings.save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(tester.element(editor), same(element));
        expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
        expect(titleController.text, retryDraft);
        expect(find.text(strings.saveFailedRetry), findsWidgets);
        await _capture(tester, '$name-save-error');
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(editor, findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  }
}

AppData _fixtureData(AppMode mode, String locale) {
  final initial = buildInitialAppData(
    buildDefaultPeriodTimes(),
    localeCode: locale,
  );
  final zh = locale == 'zh';
  return initial.copyWith(
    activeMode: mode,
    studentMode: initial.studentMode.copyWith(
      activeTimetableId: 'hybrid-timetable',
      timetables: [
        TimetableData(
          id: 'hybrid-timetable',
          config: TimetableConfig(
            name: zh ? '秋季学期' : 'Autumn semester',
            startDate: DateTime(2026, 10, 5),
            totalWeeks: 18,
            periodTimeSetId: initial.studentMode.periodTimeSets.first.id,
          ),
          courses: [
            CourseItem(
              id: 'hybrid-course',
              name: zh ? '线性代数' : 'Linear algebra',
              teacher: zh ? '陈老师' : 'Professor Chen',
              location: zh ? '教学楼 A-204' : 'Building A, Room 204',
              dayOfWeek: 1,
              semesterWeeks: List<int>.generate(18, (index) => index + 1),
              periods: const [1, 2],
              startMinutes: 480,
              endMinutes: 575,
              timeRange: '',
              credit: 3,
              remarks: zh ? '带上教材和笔记本' : 'Bring the textbook and a notebook',
              customFields: const {},
            ),
          ],
        ),
      ],
    ),
    generalMode: initial.generalMode.copyWith(
      activeScheduleId: 'hybrid-calendar',
      selectedDateIso: '2026-10-09',
      defaultView: generalViewWeek,
      schedules: [
        GeneralSchedule(
          id: 'hybrid-calendar',
          name: zh ? '学习' : 'Study',
          events: [
            GeneralEvent(
              id: 'hybrid-event',
              calendarId: 'hybrid-calendar',
              title: zh ? '项目进度讨论' : 'Project review',
              location: zh ? '图书馆研讨室' : 'Library seminar room',
              startDateTimeIso: '2026-10-09T10:00:00.000',
              endDateTimeIso: '2026-10-09T11:30:00.000',
              notes: zh
                  ? '整理本周进度，安排下一步工作'
                  : 'Review this week and plan the next steps',
            ),
          ],
        ),
        GeneralSchedule(
          id: 'hybrid-personal',
          name: zh ? '生活' : 'Personal',
          events: const [],
        ),
      ],
    ),
  );
}

Future<void> _openEditor(
  WidgetTester tester,
  TimetableProvider provider,
  _EditorGroup group, {
  required bool editing,
}) async {
  if (group == _EditorGroup.timetable) {
    if (editing) {
      final resourceRow = find.byKey(
        const ValueKey('resource-timetable-hybrid-timetable'),
      );
      if (resourceRow.hitTestable().evaluate().isEmpty) {
        final picker = find.byKey(
          const ValueKey('student-timetable-picker-button'),
        );
        await tester.tap(
          picker.hitTestable().evaluate().isNotEmpty
              ? picker
              : find.byKey(const ValueKey('workspace-resource-collapse')),
        );
        await tester.pumpAndSettle();
      }
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(resourceRow));
      addTearDown(mouse.removePointer);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('resource-timetable-edit-hybrid-timetable')),
      );
    } else {
      final strings = AppLocalizations.of(
        tester.element(find.byType(WorkspaceFrame)),
      );
      await tester.tap(find.byTooltip(strings.createTimetable).hitTestable());
    }
    return;
  }
  final event = group == _EditorGroup.event;
  final frame = find.byType(WorkspaceFrame);
  final table = provider.activeTimetable;
  final calendar = provider.generalSchedules.first;
  final anchor = find.byKey(
    ValueKey(event ? 'general-add-event' : 'student-add-course'),
  );
  unawaited(
    showAppModalSheet<void>(
      context: tester.element(frame),
      workspacePane: tester.widget<WorkspaceFrame>(frame).controller,
      editor: WorkspaceEditorConfiguration(
        anchorContext: tester.element(anchor),
      ),
      workspace: event ? AppMode.general : AppMode.student,
      builder: (_) => event
          ? GeneralEventEditorSheet(
              calendars: provider.generalSchedules,
              activeCalendarId: calendar.id,
              initialDate: DateTime(2026, 10, 9),
              initialEvent: editing ? calendar.events.single : null,
              onSave: provider.saveGeneralEvent,
            )
          : CourseEditorSheet(
              periodTimes: provider.periodTimesForTimetable(table),
              totalWeeks: table.config.totalWeeks,
              dayOfWeek: 1,
              initialPeriods: const [1, 2],
              initialStartMinutes: 480,
              initialEndMinutes: 575,
              initialCourse: editing ? table.courses.single : null,
              onSave: (course) =>
                  provider.saveCourse(course, timetableId: table.id),
            ),
    ),
  );
}

Future<void> _capture(WidgetTester tester, String name) async {
  expect(tester.takeException(), isNull);
  final output = Directory(
    const String.fromEnvironment(
      'SKED_VISUAL_OUTPUT',
      defaultValue: '.scratch/hybrid-editor-visual',
    ),
  );
  await output.create(recursive: true);
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_captureKey),
  );
  final image = await boundary.toImage(pixelRatio: 1);
  try {
    final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    await File('${output.path}/$name.png')
        .writeAsBytes(data.buffer.asUint8List());
  } finally {
    image.dispose();
  }
}
