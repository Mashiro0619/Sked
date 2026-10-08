import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/widgets/app_modal_sheet.dart';
import 'package:sked/widgets/course_editor_sheet.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';
import 'package:sked/widgets/timetable_grid.dart';
import 'package:sked/widgets/workspace_frame.dart';

import '../support/workspace_harness.dart';

void _viewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(852, 393);
  tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
  tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetPadding);
  addTearDown(tester.view.resetViewPadding);
  addTearDown(tester.view.resetViewInsets);
}

void _keyboard(WidgetTester tester, double height) {
  tester.view.viewInsets = FakeViewPadding(bottom: height);
  tester.view.padding = FakeViewPadding(top: 24, bottom: height == 0 ? 24 : 0);
}

Finder _action(Finder editor, String label) => find.ancestor(
  of: find.descendant(of: editor, matching: find.text(label)),
  matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final mode in AppMode.values) {
    for (final save in [false, true]) {
      testWidgets(
        '${mode.name} editor preserves its draft and ${save ? 'saves' : 'cancels'} above a landscape keyboard',
        (tester) async {
          _viewport(tester);
          final provider = await workspaceProvider(mode: mode, locale: 'zh');
          addTearDown(provider.dispose);
          await tester.pumpWidget(
            WorkspaceHarness(
              provider: provider,
              locale: const Locale('zh'),
              textScale: 2,
            ),
          );
          await tester.pumpAndSettle();
          final frameFinder = find.byType(WorkspaceFrame).first;
          final frame = tester.widget<WorkspaceFrame>(frameFinder);
          if (frame.controller.selectedId == 'general-reminders') {
            await frame.controller.close();
            await tester.pumpAndSettle();
          }
          final initialData = provider.appData.toJson();
          final table = provider.activeTimetable;
          final calendar = provider.generalSchedules.firstWhere(
            (calendar) => calendar.events.isNotEmpty,
          );
          String? savedTitle;
          final result = showAppModalSheet<Object?>(
            context: tester.element(frameFinder),
            workspacePane: frame.controller,
            workspace: mode,
            editor: WorkspaceEditorConfiguration(),
            enableDrag: false,
            maxWidth: appSheetWidthMedium,
            builder: (_) => mode == AppMode.student
                ? CourseEditorSheet(
                    periodTimes: provider.periodTimesForTimetable(table),
                    totalWeeks: table.config.totalWeeks,
                    dayOfWeek: table.courses.first.dayOfWeek,
                    initialCourse: table.courses.first,
                    onSave: (course) async => savedTitle = course.name,
                    onDelete: () async {},
                  )
                : GeneralEventEditorSheet(
                    calendars: provider.generalSchedules,
                    activeCalendarId: calendar.id,
                    initialDate: provider.selectedGeneralDate,
                    initialEvent: calendar.events.first,
                    onSave: (event) async => savedTitle = event.title,
                    onDelete: () async {},
                  ),
          );
          await tester.pumpAndSettle();
          final editor = find.byType(
            mode == AppMode.student
                ? CourseEditorSheet
                : GeneralEventEditorSheet,
          );
          final state = tester.state(editor);
          final l10n = AppLocalizations.of(tester.element(editor));
          final title = find
              .descendant(of: editor, matching: find.byType(EditableText))
              .first;
          await tester.enterText(title, '横屏输入草稿');

          _keyboard(tester, 240);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(tester.state(editor), same(state));
          expect(tester.widget<EditableText>(title).controller.text, '横屏输入草稿');
          expect(MediaQuery.textScalerOf(tester.element(title)).scale(14), 28);
          for (final label in [l10n.save, l10n.cancel]) {
            final button = _action(editor, label);
            expect(button.hitTestable(), findsOneWidget);
            final bounds = tester.getRect(button);
            expect(bounds.top, greaterThanOrEqualTo(24));
            expect(bounds.bottom, lessThanOrEqualTo(393 - 240));
            expect(
              tester.widget<ButtonStyleButton>(button).onPressed,
              isNotNull,
            );
          }
          final rail = tester.widget<NavigationRail>(
            find.byKey(const ValueKey('adaptive-shell-navigation-rail')),
          );
          expect(rail.leading, isNull);
          expect(rail.scrollable, isTrue);

          // Restoring height must not recreate the editor or lose typed input.
          _keyboard(tester, 0);
          await tester.pumpAndSettle();
          expect(tester.state(editor), same(state));
          expect(tester.widget<EditableText>(title).controller.text, '横屏输入草稿');
          _keyboard(tester, 240);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.tap(_action(editor, save ? l10n.save : l10n.cancel));
          // Leaving text input dismisses the real IME; simulate that transition
          // before any dirty-draft confirmation is laid out.
          _keyboard(tester, 0);
          await tester.pumpAndSettle();
          if (!save) {
            expect(find.text(l10n.discardChangesAndExit), findsOneWidget);
            await tester.tap(find.text(l10n.discardChangesAndExit));
            await tester.pumpAndSettle();
          }
          await result;
          expect(editor, findsNothing);
          expect(savedTitle, save ? '横屏输入草稿' : isNull);
          expect(provider.appData.toJson(), initialData);
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.android),
      );
    }
  }

  testWidgets(
    'a four-pixel grid viewport scrolls its full-size header without overflow',
    (tester) async {
      final provider = await workspaceProvider(locale: 'zh');
      addTearDown(provider.dispose);
      final table = provider.activeTimetable;
      await tester.pumpWidget(
        WorkspaceHarness(
          provider: provider,
          locale: const Locale('zh'),
          textScale: 2,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 700,
                height: 4,
                child: TimetableGrid(
                  timetable: table,
                  periodTimes: provider.periodTimesForTimetable(table),
                  weekDateStart: DateTime(2026, 10, 5),
                  selectedWeek: 1,
                  realCurrentWeek: 1,
                  localeCode: 'zh',
                  preserveGaps: false,
                  showPastEndedCourses: true,
                  showFutureCourses: true,
                  showGridLines: true,
                  onCourseTap: (_) {},
                  onEmptySlotTap: (_) {},
                  themeColorMode: themeColorModeSingle,
                  courseNameColorValues: const {},
                  colorfulCourseTextColorMode: colorfulCourseTextColorModeAuto,
                  liveCourseOutlineEnabled: false,
                  liveCourseOutlineMode: liveCourseOutlineModeCurrentOrNext,
                  liveCourseOutlineColorValue: 0xff6750a4,
                  liveCourseOutlineWidth: 2,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final header = find.byKey(const ValueKey('timetable-day-header'));
      final headerHeight = tester.getSize(header).height;
      expect(headerHeight, greaterThan(4));
      final heightScroll = find.byKey(
        const ValueKey('timetable-grid-height-scroll'),
      );
      final scrollable = find
          .descendant(of: heightScroll, matching: find.byType(Scrollable))
          .first;
      final scroll = tester.state<ScrollableState>(scrollable);
      expect(scroll.position.viewportDimension, 4);
      expect(scroll.position.maxScrollExtent, greaterThan(headerHeight));
      scroll.position.jumpTo(scroll.position.maxScrollExtent);
      await tester.pump();
      expect(tester.getSize(header).height, headerHeight);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
