import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/school_import_models.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/settings_page.dart';
import 'package:sked/widgets/course_details_sheet.dart';
import 'package:sked/widgets/course_editor_sheet.dart';
import 'package:sked/widgets/timetable_grid.dart';

import '../support/workspace_harness.dart';

void _viewport(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _openTimetablePicker(WidgetTester tester) async {
  final picker = find.byKey(const ValueKey('student-timetable-picker-button'));
  if (picker.evaluate().isEmpty) {
    final more = find.byKey(const ValueKey('student-desktop-toolbar-more'));
    expect(more.hitTestable(), findsOneWidget);
    await tester.tap(more);
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(picker);
  expect(picker.hitTestable(), findsOneWidget);
  await tester.tap(picker);
  await tester.pumpAndSettle();
}

Future<AppLocalizations> _openOutline(WidgetTester tester) async {
  final appearance = find.byKey(const ValueKey('settings-appearance-details'));
  if (appearance.evaluate().isNotEmpty) {
    await tester.ensureVisible(appearance);
    await tester.pumpAndSettle();
    expect(appearance.hitTestable(), findsOneWidget);
    await tester.tap(appearance);
    await tester.pumpAndSettle();
  }
  final card = find.byKey(const ValueKey('theme-outline-settings-card'));
  await tester.ensureVisible(card);
  await tester.pumpAndSettle();
  await tester.tap(find.descendant(of: card, matching: find.byType(InkWell)));
  await tester.pumpAndSettle();
  final page = find.byKey(const ValueKey('theme-outline-settings-page'));
  expect(page, findsOneWidget);
  return AppLocalizations.of(tester.element(page));
}

Future<AppLocalizations> _openExistingCourseEditor(
  WidgetTester tester,
  CourseItem course,
) async {
  final grid = tester.widget<TimetableGrid>(find.byType(TimetableGrid));
  grid.onCourseTap(
    TimetableCourseTapInfo(
      course: course,
      courses: [course],
      isFullConflict: false,
    ),
  );
  await tester.pumpAndSettle();
  final details = find.byType(CourseDetailsSheet);
  final l = AppLocalizations.of(tester.element(details));
  await tester.tap(
    find.descendant(of: details, matching: find.byTooltip(l.editCourseTooltip)),
  );
  await tester.pumpAndSettle();
  expect(find.byType(CourseEditorSheet), findsOneWidget);
  return l;
}

Future<void> _changeOutline(WidgetTester tester, bool original) async {
  final row = find.byKey(const ValueKey('live-course-outline-enabled-row'));
  await tester.tap(row);
  await tester.pumpAndSettle();
  expect(
    tester
        .widget<Switch>(find.descendant(of: row, matching: find.byType(Switch)))
        .value,
    !original,
  );
}

void main() {
  testWidgets(
    'course draft keeps its timetable when the visible picker changes selection',
    (tester) async {
      _viewport(tester, const Size(1000, 900));
      final p = await workspaceProvider();
      addTearDown(p.dispose);
      final original = p.activeTimetable;
      await p.addTimetable(original.config.copyWith(name: 'Another timetable'));
      final other = p.activeTimetable;
      await p.switchTimetable(original.id);
      await tester.pumpWidget(WorkspaceHarness(provider: p));
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(
        tester.element(find.byKey(const ValueKey('student-workspace-toolbar'))),
      );
      await tester.tap(find.text(l.addCourse).first);
      await tester.pumpAndSettle();
      final editor = find.byType(CourseEditorSheet);
      await tester.enterText(
        find.descendant(of: editor, matching: find.byType(TextField)).first,
        'Draft for original',
      );
      final editorState = tester.state(editor);
      await _openTimetablePicker(tester);
      await tester.tap(find.text(other.config.name));
      await tester.pumpAndSettle();
      expect(p.activeTimetable.id, other.id);
      expect(tester.state(editor), same(editorState));
      await tester.tap(
        find.descendant(of: editor, matching: find.text(l.save)).last,
      );
      await tester.pumpAndSettle();
      expect(editor, findsNothing);
      final originalAfter = p.timetables.singleWhere(
        (t) => t.id == original.id,
      );
      expect(
        originalAfter.courses.where((c) => c.name == 'Draft for original'),
        hasLength(1),
      );
      expect(p.activeTimetable.courses, other.courses);
      expect(
        p.activeTimetable.id,
        other.id,
        reason: 'Saving the draft must not force navigation back',
      );
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  for (final delete in [false, true]) {
    testWidgets(
      'existing course ${delete ? 'delete' : 'update'} stays bound after changing timetable',
      (tester) async {
        _viewport(tester, const Size(1000, 900));
        final p = await workspaceProvider();
        addTearDown(p.dispose);
        final original = p.activeTimetable;
        final course = original.courses.first;
        await p.addTimetable(original.config.copyWith(name: 'Other table'));
        final other = p.activeTimetable;
        await p.switchTimetable(original.id);
        await tester.pumpWidget(WorkspaceHarness(provider: p));
        await tester.pumpAndSettle();
        final l = await _openExistingCourseEditor(tester, course);
        final editor = find.byType(CourseEditorSheet);
        final editorState = tester.state(editor);
        if (!delete) {
          await tester.enterText(
            find.descendant(of: editor, matching: find.byType(TextField)).first,
            'Updated original course',
          );
        }
        await _openTimetablePicker(tester);
        await tester.tap(find.text(other.config.name));
        await tester.pumpAndSettle();
        expect(p.activeTimetable.id, other.id);
        expect(editor, findsOneWidget);
        expect(tester.state(editor), same(editorState));
        expect(find.byType(AlertDialog), findsNothing);
        if (delete) {
          await tester.tap(
            find.descendant(of: editor, matching: find.text(l.delete)),
          );
          await tester.pumpAndSettle();
          await tester.tap(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.text(l.delete),
            ),
          );
        } else {
          await tester.tap(
            find.descendant(of: editor, matching: find.text(l.save)).last,
          );
        }
        await tester.pumpAndSettle();
        expect(editor, findsNothing);
        final targetCourses = p.timetables
            .singleWhere((t) => t.id == original.id)
            .courses
            .where((c) => c.id == course.id);
        if (delete) {
          expect(targetCourses, isEmpty);
          expect(find.byType(CourseDetailsSheet), findsNothing);
        } else {
          expect(targetCourses.single.name, 'Updated original course');
          expect(
            find.descendant(
              of: find.byType(CourseDetailsSheet),
              matching: find.text('Updated original course'),
            ),
            findsOneWidget,
          );
        }
        expect(p.activeTimetable.id, other.id);
        expect(p.activeTimetable.courses, other.courses);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }

  for (final dirty in [false, true]) {
    testWidgets(
      'removing the original timetable keeps its editor and rejects save (dirty: $dirty)',
      (tester) async {
        _viewport(tester, const Size(1000, 900));
        final p = await workspaceProvider();
        addTearDown(p.dispose);
        final original = p.activeTimetable;
        final course = original.courses.first;
        await p.addTimetable(original.config.copyWith(name: 'Remaining table'));
        final other = p.activeTimetable;
        await p.switchTimetable(original.id);
        await tester.pumpWidget(WorkspaceHarness(provider: p));
        await tester.pumpAndSettle();
        final l = await _openExistingCourseEditor(tester, course);
        final editor = find.byType(CourseEditorSheet);
        final editorState = tester.state(editor);
        final title = find
            .descendant(of: editor, matching: find.byType(TextField))
            .first;
        if (dirty) await tester.enterText(title, 'Retained draft');
        await p.deleteTimetable(original.id);
        await tester.pumpAndSettle();
        expect(editor, findsOneWidget);
        expect(tester.state(editor), same(editorState));
        expect(find.byType(AlertDialog), findsNothing);
        expect(
          find.byType(CourseDetailsSheet, skipOffstage: false),
          findsNothing,
        );
        final before = p.appData.toJson();
        await tester.tap(
          find.descendant(of: editor, matching: find.text(l.save)).last,
        );
        await tester.pumpAndSettle();
        expect(tester.state(editor), same(editorState));
        expect(find.text(l.saveFailedRetry), findsOneWidget);
        expect(
          tester.widget<TextField>(title).controller!.text,
          dirty ? 'Retained draft' : course.name,
        );
        expect(p.appData.toJson(), before);
        expect(p.activeTimetable.id, other.id);
        expect(p.activeTimetable.courses, other.courses);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }

  testWidgets(
    'failed course update retains its draft and retries on the original table',
    (tester) async {
      _viewport(tester, const Size(1000, 900));
      final seed = await workspaceProvider();
      final storage = WorkspaceMemoryStorage(seed.appData);
      seed.dispose();
      final p = await workspaceProvider(storage: storage);
      addTearDown(p.dispose);
      final original = p.activeTimetable;
      final course = original.courses.first;
      await p.addTimetable(original.config.copyWith(name: 'Other table'));
      final other = p.activeTimetable;
      await p.switchTimetable(original.id);
      await tester.pumpWidget(WorkspaceHarness(provider: p));
      await tester.pumpAndSettle();
      final l = await _openExistingCourseEditor(tester, course);
      final editor = find.byType(CourseEditorSheet);
      final editorState = tester.state(editor);
      await tester.enterText(
        find.descendant(of: editor, matching: find.byType(TextField)).first,
        'Retry original',
      );
      await p.switchTimetable(other.id);
      await tester.pumpAndSettle();
      final before = p.appData.toJson();
      final save = find
          .descendant(of: editor, matching: find.text(l.save))
          .last;
      storage.saveError = StateError('retryable storage failure');
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(tester.state(editor), same(editorState));
      expect(find.text(l.saveFailedRetry), findsOneWidget);
      expect(p.appData.toJson(), before);
      expect(storage.data.toJson(), before);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(editor, findsNothing);
      final saved = p.timetables
          .singleWhere((t) => t.id == original.id)
          .courses
          .where((c) => c.id == course.id);
      expect(saved, hasLength(1));
      expect(saved.single.name, 'Retry original');
      expect(p.activeTimetable.id, other.id);
      expect(p.activeTimetable.courses, other.courses);
      expect(storage.data.toJson(), p.appData.toJson());
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets('ordinary import cannot redirect an already open course draft', (
    tester,
  ) async {
    _viewport(tester, const Size(1920, 1080));
    final p = await workspaceProvider();
    addTearDown(p.dispose);
    final original = p.activeTimetable;
    final source = p.exportSelectedTimetablesJson([original.id]);
    await tester.pumpWidget(WorkspaceHarness(provider: p));
    await tester.pumpAndSettle();
    final l = AppLocalizations.of(
      tester.element(find.byKey(const ValueKey('student-workspace-toolbar'))),
    );
    await tester.tap(find.text(l.addCourse).first);
    await tester.pumpAndSettle();
    final editor = find.byType(CourseEditorSheet);
    await tester.enterText(
      find.descendant(of: editor, matching: find.byType(TextField)).first,
      'Original timetable draft',
    );
    final editorState = tester.state(editor);
    await tester.tap(find.byKey(const ValueKey('student-resource-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.importAction).last);
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsWidgets);
    await p.importSelectedTimetablesJson(
      source,
      timetableIds: [original.id],
      mode: TimetableImportMode.addAsNew,
    );
    final importedId = p.activeTimetable.id;
    expect(importedId, isNot(original.id));
    Navigator.of(
      tester.element(find.byType(SettingsPage).last),
      rootNavigator: true,
    ).pop();
    await tester.pumpAndSettle();
    expect(tester.state(editor), same(editorState));
    await tester.tap(
      find.descendant(of: editor, matching: find.text(l.save)).last,
    );
    await tester.pumpAndSettle();
    expect(editor, findsNothing);
    expect(
      p.timetables
          .singleWhere((t) => t.id == original.id)
          .courses
          .where((c) => c.name == 'Original timetable draft'),
      hasLength(1),
    );
    expect(
      p.activeTimetable.courses.any(
        (c) => c.name == 'Original timetable draft',
      ),
      isFalse,
    );
    expect(p.activeTimetable.id, importedId);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets(
    'switching settings category awaits outline draft confirmation',
    (tester) async {
      _viewport(tester, const Size(1440, 900));
      final p = await workspaceProvider();
      addTearDown(p.dispose);
      await tester.pumpWidget(
        WorkspaceHarness(provider: p, home: const SettingsPage()),
      );
      await tester.pumpAndSettle();
      final l = await _openOutline(tester);
      final original = p.liveCourseOutlineEnabled;
      final page = find.byKey(const ValueKey('theme-outline-settings-page'));
      final state = tester.state(page);
      await _changeOutline(tester, original);
      final about = find.byKey(const ValueKey('settings-category-about'));
      await tester.tap(about);
      await tester.pumpAndSettle();
      expect(find.text(l.unsavedChangesMessage), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(l.cancel),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.state(page), same(state));
      expect(p.liveCourseOutlineEnabled, original);
      expect(
        tester
            .widget<Switch>(
              find.descendant(
                of: find.byKey(
                  const ValueKey('live-course-outline-enabled-row'),
                ),
                matching: find.byType(Switch),
              ),
            )
            .value,
        !original,
      );
      await tester.tap(about);
      await tester.pumpAndSettle();
      expect(find.text(l.unsavedChangesMessage), findsOneWidget);
      await tester.tap(find.text(l.discardChangesAndExit));
      await tester.pumpAndSettle();
      expect(page, findsNothing);
      expect(
        find.text(l.checkForUpdates),
        findsOneWidget,
        reason: 'Confirmed navigation should finish the originally requested category change',
      );
      expect(p.liveCourseOutlineEnabled, original);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.windows,
      TargetPlatform.android,
    }),
  );

  testWidgets(
    'clean outline permits category navigation without a discard prompt',
    (tester) async {
      _viewport(tester, const Size(1440, 900));
      final p = await workspaceProvider();
      addTearDown(p.dispose);
      await tester.pumpWidget(
        WorkspaceHarness(provider: p, home: const SettingsPage()),
      );
      await tester.pumpAndSettle();
      final l = await _openOutline(tester);
      await tester.tap(find.byKey(const ValueKey('settings-category-about')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('theme-outline-settings-page')),
        findsNothing,
      );
      expect(find.text(l.checkForUpdates), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets(
    'outline participates in window close guards and retains cancelled draft',
    (tester) async {
      _viewport(tester, const Size(1440, 900));
      final p = await workspaceProvider();
      addTearDown(p.dispose);
      await tester.pumpWidget(
        WorkspaceHarness(provider: p, home: const SettingsPage()),
      );
      await tester.pumpAndSettle();
      final l = await _openOutline(tester);
      final original = p.liveCourseOutlineEnabled;
      await _changeOutline(tester, original);
      final close = p.prepareForWindowClose();
      await tester.pumpAndSettle();
      expect(find.text(l.unsavedChangesMessage), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(l.cancel),
        ),
      );
      await tester.pumpAndSettle();
      expect(await close, isFalse);
      expect(
        find.byKey(const ValueKey('theme-outline-settings-page')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('theme-outline-page-apply')));
      await tester.pumpAndSettle();
      expect(p.liveCourseOutlineEnabled, !original);
      expect(find.byType(AlertDialog), findsNothing);
      expect(await p.prepareForWindowClose(), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  for (final semesterStart in [
    DateTime(2026, 9, 7),
    DateTime(2026, 9, 9),
    DateTime(2026, 12, 31),
  ]) {
    testWidgets('desktop week range agrees with grid from $semesterStart', (
      tester,
    ) async {
      _viewport(tester, const Size(1440, 900));
      final p = await workspaceProvider();
      addTearDown(p.dispose);
      await p.updateTimetableConfig(
        p.activeTimetable.config.copyWith(startDate: semesterStart),
      );
      for (final week in [1, 2, 18]) {
        await p.setSelectedWeek(week);
        await tester.pumpWidget(WorkspaceHarness(provider: p));
        await tester.pumpAndSettle();
        final expectedStart = startOfWeekFor(p.activeTimetable.config, week);
        final expectedEnd = addCalendarDays(expectedStart, 6);
        final grid = tester.widget<TimetableGrid>(
          find.byKey(ValueKey('student-timetable-grid-$week')),
        );
        expect(grid.weekDateStart, expectedStart);
        final range =
            '${expectedStart.month}/${expectedStart.day} – ${expectedEnd.month}/${expectedEnd.day}';
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('student-week-picker-button')),
            matching: find.textContaining(range),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  }
}
