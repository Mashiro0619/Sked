import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/widgets/course_editor_sheet.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';
import 'package:sked/widgets/workspace_frame.dart';

import '../support/workspace_harness.dart';

Finder _key(String value, {bool skipOffstage = true}) =>
    find.byKey(ValueKey(value), skipOffstage: skipOffstage);
final _desktop = TargetPlatformVariant.only(TargetPlatform.windows);

const _course = CourseItem(
  id: 'original-course',
  name: 'Original course',
  teacher: '',
  location: '',
  dayOfWeek: 1,
  semesterWeeks: [1],
  periods: [1],
  startMinutes: 480,
  endMinutes: 525,
  timeRange: '08:00-08:45',
  credit: 0,
  remarks: '',
  customFields: {},
);
final _event = GeneralEvent(
  id: 'original-event',
  calendarId: 'calendar',
  title: 'Original event',
  startDateTimeIso: '2026-09-08T08:00:00.000',
  endDateTimeIso: '2026-09-08T09:00:00.000',
);

void _viewport(WidgetTester t) {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = const Size(900, 900);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.view.resetPhysicalSize);
}

Future<WorkspacePaneController> _mount(WidgetTester t) async {
  _viewport(t);
  final pane = WorkspacePaneController();
  addTearDown(() async {
    await t.pumpWidget(const SizedBox.shrink());
    pane.dispose();
  });
  await t.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: WorkspaceFrame(
          controller: pane,
          resources: const SizedBox.shrink(),
          canvas: const Column(
            children: [
              SizedBox(height: 48),
              Expanded(child: WorkspaceCanvasBody(child: SizedBox.expand())),
            ],
          ),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  return pane;
}

Widget _editor(AppMode mode, Future<void> Function() commit) => switch (mode) {
  AppMode.student => CourseEditorSheet(
    key: const ValueKey('saving-editor'),
    periodTimes: buildDefaultPeriodTimes(),
    totalWeeks: 18,
    dayOfWeek: 1,
    initialCourse: _course,
    onSave: (_) => commit(),
    onDelete: commit,
  ),
  AppMode.general => GeneralEventEditorSheet(
    key: const ValueKey('saving-editor'),
    initialEvent: _event,
    calendars: [
      GeneralSchedule(id: 'calendar', name: 'Calendar', events: [_event]),
    ],
    onSave: (_) => commit(),
    onDelete: commit,
  ),
};

Future<void> _startCommit(WidgetTester t, AppMode mode, bool deleting) async {
  final action = find.descendant(
    of: _key('saving-editor'),
    matching: find.text(deleting ? 'Delete' : 'Save'),
  );
  await t.ensureVisible(action.last);
  await t.tap(action.last);
  if (deleting && mode == AppMode.student) {
    await t.pumpAndSettle();
    await t.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, 'Delete'),
      ),
    );
  }
  await t.pump();
  await t.pump(const Duration(milliseconds: 100));
}

class _DelayedStorage extends WorkspaceMemoryStorage {
  _DelayedStorage(super.data);
  Completer<void>? pending;
  int saves = 0;
  @override
  Future<void> save(AppData value) async {
    saves++;
    if (pending case final gate?) await gate.future;
    await super.save(value);
  }
}

void main() {
  testWidgets(
    'timetable configuration finishes only its route while a course editor is open',
    (t) async {
      _viewport(t);
      t.view.physicalSize = const Size(1440, 900);
      final storage = _DelayedStorage(
        buildInitialAppData(buildDefaultPeriodTimes()),
      );
      final provider = await workspaceProvider(storage: storage);
      addTearDown(provider.dispose);
      await provider.addTimetable(
        TimetableConfig(
          name: 'Original timetable',
          startDate: DateTime(2026, 9, 7),
          totalWeeks: 18,
          periodTimeSetId: provider.periodTimeSets.first.id,
        ),
      );
      await t.pumpWidget(WorkspaceHarness(provider: provider));
      await t.pumpAndSettle();
      final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(
        location: t.getCenter(
          _key('resource-timetable-${provider.activeTimetable.id}'),
        ),
      );
      addTearDown(mouse.removePointer);
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Edit timetable'));
      await t.pumpAndSettle();
      final nameField = find.byType(TextField).first;
      final configRoute = ModalRoute.of(t.element(nameField))!;
      var completions = 0;
      Object? configResult;
      unawaited(
        configRoute.popped.then((value) {
          configResult = value;
          completions++;
        }),
      );
      await t.enterText(nameField, 'Renamed in background');
      final save = find.widgetWithText(FilledButton, 'Save');
      await t.ensureVisible(save);
      await t.pumpAndSettle();
      final gate = storage.pending = Completer<void>();
      addTearDown(() {
        if (!gate.isCompleted) gate.complete();
      });
      final saves = storage.saves;
      await t.tap(save);
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      expect(storage.saves, saves + 1);
      await t.tap(
        find.widgetWithText(FilledButton, 'Add course').hitTestable(),
      );
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      final editor = find.byType(CourseEditorSheet);
      final state = t.state(editor);
      gate.complete();
      await t.pumpAndSettle();
      expect(configRoute.isActive, isFalse);
      expect(completions, 1);
      expect(configResult, 'save');
      expect(t.state(editor), same(state));
      expect(provider.activeTimetable.config.name, 'Renamed in background');
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
    },
    variant: _desktop,
  );

  for (final mode in AppMode.values) {
    for (final deleting in [false, true]) {
      testWidgets(
        '$mode commit deleting=$deleting completes its own route beneath a newer task',
        (t) async {
          final pane = await _mount(t);
          final gate = Completer<void>();
          addTearDown(() {
            if (!gate.isCompleted) gate.complete();
          });
          var commits = 0;
          Object? result;
          var completions = 0;
          unawaited(
            pane
                .show<Object?>(
                  (_) => _editor(mode, () {
                    commits++;
                    return gate.future;
                  }),
                )
                .then((value) {
                  result = value;
                  completions++;
                }),
          );
          await t.pumpAndSettle();
          await _startCommit(t, mode, deleting);
          expect(commits, 1);
          final newerDraft = TextEditingController(text: 'Newer unsaved draft');
          addTearDown(newerDraft.dispose);
          unawaited(
            pane.show<void>(
              (_) => PopScope<void>(
                canPop: false,
                child: TextField(
                  key: const ValueKey('newer-task'),
                  controller: newerDraft,
                ),
              ),
            ),
          );
          await t.pump();
          await t.pump(const Duration(milliseconds: 400));
          final newerState = t.state(_key('newer-task'));
          gate.complete();
          await t.pump();
          await t.pump(const Duration(milliseconds: 600));
          await t.pump();
          expect(_key('saving-editor', skipOffstage: false), findsNothing);
          expect(t.state(_key('newer-task')), same(newerState));
          expect(newerDraft.text, 'Newer unsaved draft');
          expect(completions, 1);
          switch (mode) {
            case AppMode.student:
              expect(result, isA<CourseEditorResult>());
              final saved = result! as CourseEditorResult;
              expect(saved.delete, deleting);
              if (!deleting) expect(saved.course!.id, _course.id);
            case AppMode.general:
              expect(result, isA<GeneralEventEditorResult>());
              final saved = result! as GeneralEventEditorResult;
              expect(saved.delete, deleting);
              if (!deleting) expect(saved.event!.id, _event.id);
          }
          // Completing the older route must neither consult nor bypass the
          // current task's unsaved-exit guard.
          await pane.close();
          await t.pumpAndSettle();
          expect(_key('newer-task'), findsOneWidget);
          expect(pane.hasPaneTasks, isTrue);
          pane.navigatorKey.currentState!.pop();
          await t.pumpAndSettle();
          expect(pane.hasPaneTasks, isFalse);
          expect(completions, 1);
          expect(t.takeException(), isNull);
        },
        variant: _desktop,
      );
    }

    testWidgets('$mode failed background save preserves the editor for retry', (
      t,
    ) async {
      final pane = await _mount(t);
      final gate = Completer<void>();
      addTearDown(() {
        if (!gate.isCompleted) gate.complete();
      });
      var commits = 0;
      var completions = 0;
      unawaited(
        pane
            .show<Object?>(
              (_) => _editor(mode, () async {
                commits++;
                if (commits == 1) await gate.future;
              }),
            )
            .then((_) => completions++),
      );
      await t.pumpAndSettle();
      final state = t.state(_key('saving-editor'));
      final field = find
          .descendant(
            of: _key('saving-editor'),
            matching: find.byType(TextField),
          )
          .first;
      await t.enterText(field, 'Retry this draft');
      await _startCommit(t, mode, false);
      expect(commits, 1);
      unawaited(pane.show<void>((_) => const Text('New foreground task')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      gate.completeError(StateError('delayed save failed'));
      await t.pumpAndSettle();
      expect(find.text('New foreground task'), findsOneWidget);
      expect(t.state(_key('saving-editor', skipOffstage: false)), same(state));
      expect(completions, 0);
      await pane.close();
      await t.pumpAndSettle();
      expect(t.state(_key('saving-editor')), same(state));
      expect(t.widget<TextField>(field).controller!.text, 'Retry this draft');
      await _startCommit(t, mode, false);
      await t.pumpAndSettle();
      expect(commits, 2);
      expect(completions, 1);
      expect(pane.hasPaneTasks, isFalse);
      expect(t.takeException(), isNull);
    }, variant: _desktop);
  }

  testWidgets(
    'real schedule toolbar reminder survives completion of a background save',
    (t) async {
      _viewport(t);
      final storage = _DelayedStorage(
        buildInitialAppData(buildDefaultPeriodTimes())
            .copyWith(activeMode: AppMode.general),
      );
      final provider = await workspaceProvider(
        mode: AppMode.general,
        storage: storage,
      );
      addTearDown(provider.dispose);
      await t.pumpWidget(WorkspaceHarness(provider: provider));
      await t.pumpAndSettle();
      await t.tap(_key('general-add-event'));
      await t.pumpAndSettle();
      final editor = find.byType(GeneralEventEditorSheet);
      await t.enterText(
        find.descendant(of: editor, matching: find.byType(TextFormField)).first,
        'Saved without closing reminders',
      );
      final initialSaves = storage.saves;
      final gate = storage.pending = Completer<void>();
      addTearDown(() {
        if (!gate.isCompleted) gate.complete();
      });
      await t.tap(
        find.descendant(
          of: editor,
          matching: find.widgetWithText(FilledButton, 'Save'),
        ),
      );
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      expect(storage.saves, initialSaves + 1);
      await t.tap(_key('general-reminders-action'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      final reminders = t.element(_key('general-reminders-list'));
      expect(editor, findsNothing);
      gate.complete();
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      await t.pump();
      expect(t.element(_key('general-reminders-list')), same(reminders));
      expect(
        find.byType(GeneralEventEditorSheet, skipOffstage: false),
        findsNothing,
      );
      expect(
        storage.data.generalMode.schedules
            .expand((calendar) => calendar.events)
            .where((event) => event.title == 'Saved without closing reminders'),
        hasLength(1),
      );
      // The original route future must also clear the home-screen busy flag.
      expect(
        t.widget<FilledButton>(_key('general-add-event')).onPressed,
        isNotNull,
      );
      await t.tap(_key('workspace-inspector-close'));
      await t.pumpAndSettle();
      expect(
        t
            .widget<WorkspaceFrame>(find.byType(WorkspaceFrame))
            .controller
            .hasPaneTasks,
        isFalse,
      );
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
    },
    variant: _desktop,
  );
}
