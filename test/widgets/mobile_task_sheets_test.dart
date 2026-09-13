import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/widgets/course_details_sheet.dart';
import 'package:sked/widgets/course_editor_sheet.dart';
import 'package:sked/widgets/general_event_details_sheet.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';
import 'package:sked/widgets/sked_time_picker.dart';
import 'package:sked/widgets/workspace_frame.dart';

import '../support/mobile_layout_data.dart';
import '../support/workspace_harness.dart';

Finder _key(String key) => find.byKey(ValueKey(key));
void _size(WidgetTester t, Size size) {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = size;
  t.view.padding = const FakeViewPadding(top: 24, bottom: 24);
  t.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.view.resetPadding);
  addTearDown(t.view.resetViewPadding);
  addTearDown(t.view.resetViewInsets);
}

class _Storage extends WorkspaceMemoryStorage {
  _Storage(super.data);
  int writes = 0;
  Completer<void>? gate;
  @override
  Future<void> save(AppData data) async {
    writes++;
    await gate?.future;
    await super.save(data);
  }
}

Future<(TimetableProvider, _Storage)> _home(
  WidgetTester t,
  AppMode mode, {
  double scale = 1,
  Brightness brightness = Brightness.light,
}) async {
  final storage = _Storage(mobileLayoutData().copyWith(activeMode: mode));
  final p = await workspaceProvider(storage: storage, locale: 'zh');
  addTearDown(p.dispose);
  await t.pumpWidget(
    WorkspaceHarness(
      provider: p,
      locale: const Locale('zh'),
      textScale: scale,
      brightness: brightness,
    ),
  );
  await t.pumpAndSettle();
  return (p, storage);
}

Finder _details(AppMode mode) => find.byType(
  mode == AppMode.student ? CourseDetailsSheet : GeneralEventDetailsSheet,
);
Finder _editor(AppMode mode) => find.byType(
  mode == AppMode.student ? CourseEditorSheet : GeneralEventEditorSheet,
);
Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

Future<void> _openDetails(WidgetTester t, TimetableProvider p) async {
  await _tap(
    t,
    p.activeMode == AppMode.student
        ? _key('timetable-course-hit-${p.activeTimetable.courses.first.id}')
        : _key(
            'general-timed-occurrence-mobile-day-21-2026-09-21T08:10:00.000',
          ),
  );
}

Future<void> _editDetails(WidgetTester t, AppMode mode) async {
  final details = _details(mode);
  final l = AppLocalizations.of(t.element(details));
  await _tap(
    t,
    find.descendant(
      of: details,
      matching: find.byTooltip(
        mode == AppMode.student ? l.editCourseTooltip : l.editEvent,
      ),
    ),
  );
}

void _assertBottom(WidgetTester t, Finder task) {
  final context = t.element(task);
  expect(ModalRoute.of(context), isA<ModalBottomSheetRoute<dynamic>>());
  expect(WorkspaceTaskScope.contains(context), isFalse);
  final surface = find
      .ancestor(of: task, matching: _key('app-bottom-task-surface'))
      .first;
  final rect = t.getRect(surface);
  expect(rect.top, greaterThan(24));
  expect(rect.bottom, closeTo(t.view.physicalSize.height, 1));
  final pane = t
      .widget<WorkspaceFrame>(find.byType(WorkspaceFrame).first)
      .controller;
  expect(pane.isOpen, isTrue);
  expect(pane.hasPaneTasks, isFalse);
  expect(_key('workspace-inspector'), findsNothing);
  expect(
    t.widget<BottomSheet>(find.byType(BottomSheet).last).enableDrag,
    isFalse,
  );
}

void main() {
  for (final mode in AppMode.values) {
    for (final width in [320.0, 360.0, 393.0, 412.0]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        testWidgets(
          '$mode $width scale $scale detail/edit use real bottom tasks',
          (t) async {
            _size(t, Size(width, 900));
            final (p, storage) = await _home(
              t,
              mode,
              scale: scale,
              brightness: scale == 1.3 ? Brightness.dark : Brightness.light,
            );
            final before = storage.writes;
            await _openDetails(t, p);
            _assertBottom(t, _details(mode));
            await _editDetails(t, mode);
            _assertBottom(t, _editor(mode));
            final state = t.state(_editor(mode));
            t.view.physicalSize = Size(width, 960);
            await t.pumpAndSettle();
            expect(t.state(_editor(mode)), same(state));
            final l = AppLocalizations.of(t.element(_editor(mode)));
            await _tap(
              t,
              find.descendant(of: _editor(mode), matching: find.text(l.cancel)),
            );
            expect(_editor(mode), findsNothing);
            expect(storage.writes, before);
            expect(t.takeException(), isNull);
          },
          variant: TargetPlatformVariant.only(TargetPlatform.android),
        );
      }
    }

    testWidgets(
      '$mode new task keeps draft with IME, rejects outside/back discard',
      (t) async {
        _size(t, const Size(393, 852));
        final (_, storage) = await _home(t, mode);
        final before = storage.writes;
        await _tap(t, find.byType(FloatingActionButton).first);
        final editor = _editor(mode);
        _assertBottom(t, editor);
        final state = t.state(editor);
        final field = find
            .descendant(
              of: editor,
              matching: find.byWidgetPredicate(
                (w) => w is TextField || w is TextFormField,
              ),
            )
            .first;
        await t.enterText(field, '手机草稿仍需保留');
        t.view.viewInsets = const FakeViewPadding(bottom: 300);
        t.view.padding = const FakeViewPadding(top: 24);
        await t.pumpAndSettle();
        expect(t.state(editor), same(state));
        final l = AppLocalizations.of(t.element(editor));
        final save = find.descendant(of: editor, matching: find.text(l.save));
        final cancel = find.descendant(
          of: editor,
          matching: find.text(l.cancel),
        );
        expect(save.hitTestable(), findsOneWidget);
        expect(cancel.hitTestable(), findsOneWidget);
        expect(t.getRect(save).bottom, lessThanOrEqualTo(552));
        t.view.viewInsets = const FakeViewPadding();
        await t.pumpAndSettle();
        await t.tapAt(const Offset(15, 30));
        await t.pumpAndSettle();
        expect(find.text(l.unsavedChangesMessage), findsOneWidget);
        await t.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text(l.cancel),
          ),
        );
        await t.pumpAndSettle();
        expect(t.state(editor), same(state));
        expect(find.text('手机草稿仍需保留'), findsOneWidget);
        await Navigator.of(t.element(editor)).maybePop();
        await t.pumpAndSettle();
        await t.tap(find.text(l.discardChangesAndExit));
        await t.pumpAndSettle();
        expect(editor, findsNothing);
        expect(storage.writes, before);
        expect(t.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets(
      '$mode mobile save blocks closing, fails in place and retries once',
      (t) async {
        _size(t, const Size(393, 900));
        final (p, storage) = await _home(t, mode);
        await _openDetails(t, p);
        await _editDetails(t, mode);
        final editor = _editor(mode);
        final l = AppLocalizations.of(t.element(editor));
        await t.enterText(
          find
              .descendant(
                of: editor,
                matching: find.byWidgetPredicate(
                  (w) => w is TextField || w is TextFormField,
                ),
              )
              .first,
          '重试保存的手机草稿',
        );
        final gate = Completer<void>();
        addTearDown(() {
          if (!gate.isCompleted) gate.complete();
        });
        storage.gate = gate;
        storage.saveError = StateError('mobile save retry');
        final before = storage.writes;
        final save = find
            .descendant(of: editor, matching: find.byType(FilledButton))
            .last;
        await t.ensureVisible(save);
        await t.pumpAndSettle();
        final staleSave = t.widget<FilledButton>(save).onPressed!;
        await t.tap(save);
        await t.pump();
        staleSave();
        await t.pump();
        final pane = t
            .widget<WorkspaceFrame>(find.byType(WorkspaceFrame).first)
            .controller;
        await pane.close();
        await t.pump();
        expect(editor, findsOneWidget);
        expect(storage.writes, before + 1);
        gate.complete();
        await t.pumpAndSettle();
        expect(editor, findsOneWidget);
        expect(find.text('重试保存的手机草稿'), findsOneWidget);
        expect(find.text(l.saveFailedRetry), findsWidgets);
        storage.gate = null;
        await _tap(t, save);
        expect(editor, findsNothing);
        expect(storage.writes, before + 2);
        expect(t.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    for (final replaced in [false, true]) {
      testWidgets('$mode detail/session invalidates replace=$replaced', (
        t,
      ) async {
        _size(t, const Size(360, 850));
        final (p, _) = await _home(t, mode);
        final backup = await p.exportAppDataJson();
        await _openDetails(t, p);
        if (replaced) {
          await p.importAppDataJson(backup, mode: AppImportMode.replaceAll);
        } else {
          await p.setWorkspaceEnabled(mode, false);
        }
        await t.pumpAndSettle();
        expect(_details(mode), findsNothing);
        expect(_key('app-bottom-task-surface'), findsNothing);
        expect(t.takeException(), isNull);
      }, variant: TargetPlatformVariant.only(TargetPlatform.android));
    }
  }

  testWidgets('phone course task close does not pop its nested time picker', (
    t,
  ) async {
    _size(t, const Size(393, 852));
    final (p, storage) = await _home(t, AppMode.student);
    await _openDetails(t, p);
    await _editDetails(t, AppMode.student);
    final pane = t
        .widget<WorkspaceFrame>(find.byType(WorkspaceFrame).first)
        .controller;
    final before = storage.writes;
    await _tap(t, _key('course-start-time-action'));
    expect(find.byType(SkedTimePicker), findsOneWidget);
    await pane.close();
    await t.pumpAndSettle();
    expect(find.byType(SkedTimePicker), findsOneWidget);
    await _tap(t, _key('sked-time-cancel'));
    expect(find.byType(CourseEditorSheet), findsOneWidget);
    await pane.close();
    await t.pumpAndSettle();
    expect(find.byType(CourseEditorSheet), findsNothing);
    expect(find.byType(CourseDetailsSheet), findsOneWidget);
    expect(storage.writes, before);
    expect(t.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets(
    'bottom task invalidation retires its nested picker after object deletion',
    (t) async {
      _size(t, const Size(393, 852));
      final (p, _) = await _home(t, AppMode.student);
      final course = p.activeTimetable.courses.first;
      await _openDetails(t, p);
      await _editDetails(t, AppMode.student);
      await _tap(t, _key('course-start-time-action'));
      await p.deleteCourse(course.id, timetableId: p.activeTimetable.id);
      await t.pumpAndSettle();
      expect(find.byType(CourseEditorSheet), findsNothing);
      expect(find.byType(CourseDetailsSheet), findsNothing);
      expect(find.byType(SkedTimePicker), findsNothing);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'phone details remain the owner of edits after widening to a tablet',
    (t) async {
      _size(t, const Size(393, 852));
      final (p, _) = await _home(t, AppMode.student);
      await _openDetails(t, p);
      t.view.physicalSize = const Size(1280, 1000);
      await t.pumpAndSettle();
      await _editDetails(t, AppMode.student);
      expect(
        ModalRoute.of(t.element(find.byType(CourseEditorSheet))),
        isA<ModalBottomSheetRoute<dynamic>>(),
      );
      expect(
        t
            .widget<WorkspaceFrame>(find.byType(WorkspaceFrame).first)
            .controller
            .hasPaneTasks,
        isFalse,
      );
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'wide tablet still uses its pane and does not move the draft on rotation',
    (t) async {
      _size(t, const Size(1280, 1000));
      final (p, _) = await _home(t, AppMode.general);
      await _openDetails(t, p);
      expect(find.byType(BottomSheet), findsNothing);
      expect(
        WorkspaceTaskScope.contains(t.element(_details(AppMode.general))),
        isTrue,
      );
      t.view.physicalSize = const Size(393, 852);
      await t.pumpAndSettle();
      expect(
        find.byType(BottomSheet),
        findsNothing,
        reason: 'Presentation is latched at open',
      );
      expect(_details(AppMode.general), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('narrow Windows preserves the existing inspector', (t) async {
    _size(t, const Size(500, 900));
    final (p, _) = await _home(t, AppMode.student);
    await _openDetails(t, p);
    expect(find.byType(BottomSheet), findsNothing);
    expect(
      WorkspaceTaskScope.contains(t.element(find.byType(CourseDetailsSheet))),
      isTrue,
    );
    expect(t.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
