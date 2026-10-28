import 'package:flutter/gestures.dart';

import 'package:sked/widgets/sked_time_picker.dart';

import 'dart:async';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/widgets/app_modal_sheet.dart';
import 'package:sked/widgets/course_editor_sheet.dart';

Widget _localizedApp(Widget child) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

Future<void> _pumpEditorHost(
  WidgetTester tester, {
  CourseItem? initialCourse,
  Future<void> Function(CourseItem)? onSave,
  Future<void> Function()? onDelete,
}) async {
  await tester.pumpWidget(
    _localizedApp(
      Builder(
        builder: (context) => FilledButton(
          onPressed: () {
            unawaited(
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    body: CourseEditorSheet(
                      periodTimes: buildDefaultPeriodTimes().take(4).toList(),
                      totalWeeks: 18,
                      dayOfWeek: 1,
                      initialCourse: initialCourse,
                      onSave: onSave,
                      onDelete: onDelete,
                    ),
                  ),
                ),
              ),
            );
          },
          child: const Text('Open editor'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open editor'));
  await tester.pumpAndSettle();
}

Future<void> _scrollTimeMinute(WidgetTester tester, int rows) async {
  final wheel = find.byKey(const ValueKey('sked-time-minute-wheel'));
  if (wheel.evaluate().isEmpty) {
    await tester.tap(find.byKey(const ValueKey('sked-time-input-toggle')));
    await tester.pumpAndSettle();
  }
  final extent = tester.widget<ListWheelScrollView>(wheel).itemExtent;
  await tester.sendEventToBinding(
    PointerScrollEvent(
      kind: PointerDeviceKind.mouse,
      position: tester.getCenter(wheel),
      scrollDelta: Offset(0, rows * extent),
    ),
  );
  await tester.pumpAndSettle();
  if (find.byKey(const ValueKey('sked-time-minute-input')).evaluate().isEmpty) {
    await tester.tap(find.byKey(const ValueKey('sked-time-input-toggle')));
    await tester.pumpAndSettle();
  }
}

void main() {
  CourseItem legacyCourse() => CourseItem(
    id: 'legacy',
    name: 'Legacy course',
    teacher: '',
    location: '',
    dayOfWeek: 1,
    semesterWeeks: const [],
    periods: const [2],
    startMinutes: 0,
    endMinutes: 0,
    timeRange: buildTimeRange(0, 0),
    credit: 0,
    remarks: '',
    customFields: const {},
  );

  testWidgets(
    'renaming a legacy course does not store its displayed period time',
    (tester) async {
      CourseItem? saved;
      final source = legacyCourse();
      await _pumpEditorHost(
        tester,
        initialCourse: source,
        onSave: (course) async => saved = course,
      );
      final name = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.controller?.text == source.name,
      );
      expect(
        find.text(formatMinutes(buildDefaultPeriodTimes()[1].startMinutes)),
        findsWidgets,
      );
      await tester.enterText(name, 'Renamed course');
      final save = find.widgetWithText(FilledButton, 'Save');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(saved?.name, 'Renamed course');
      expect(saved?.startMinutes, 0);
      expect(saved?.endMinutes, 0);
      expect(saved?.periods, [2]);
      expect(saved?.semesterWeeks, isEmpty);
    },
  );

  testWidgets(
    'editing a legacy course time explicitly stores the chosen time',
    (tester) async {
      CourseItem? saved;
      await _pumpEditorHost(
        tester,
        initialCourse: legacyCourse(),
        onSave: (course) async => saved = course,
      );
      await tester.tap(find.byKey(const ValueKey('course-end-time-action')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('sked-time-hour-input')),
        '11',
      );
      await tester.enterText(
        find.byKey(const ValueKey('sked-time-minute-input')),
        '00',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('sked-time-confirm')));
      await tester.pumpAndSettle();
      final save = find.widgetWithText(FilledButton, 'Save');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(saved?.startMinutes, buildDefaultPeriodTimes()[1].startMinutes);
      expect(saved?.endMinutes, 11 * 60);
    },
  );

  testWidgets('clearing semester weeks cannot confirm or silently select all', (
    tester,
  ) async {
    CourseItem? saved;
    await _pumpEditorHost(
      tester,
      initialCourse: legacyCourse(),
      onSave: (course) async => saved = course,
    );
    final l10n = AppLocalizations.of(
      tester.element(find.byType(CourseEditorSheet)),
    );
    await tester.tap(find.text(l10n.semesterWeeks));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, l10n.clear));
    await tester.pumpAndSettle();
    expect(find.text(l10n.selectAtLeastOneWeek), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, l10n.confirm))
          .onPressed,
      isNull,
    );
    await tester.tap(find.widgetWithText(TextButton, l10n.cancel).last);
    await tester.pumpAndSettle();
    final save = find.widgetWithText(FilledButton, l10n.save);
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(saved?.semesterWeeks, isEmpty);
  });

  testWidgets(
    'collapsed reminder overrides survive editing without opening More',
    (tester) async {
      for (final setting in [
        const CourseReminderSettings(),
        const CourseReminderSettings(behavior: CourseReminderBehavior.disabled),
        const CourseReminderSettings(
          behavior: CourseReminderBehavior.custom,
          minutesBefore: 25,
        ),
      ]) {
        CourseItem? saved;
        final initial = CourseItem(
          id: 'reminder-edit',
          name: 'Retained reminder',
          teacher: '',
          location: '',
          dayOfWeek: 1,
          semesterWeeks: const [1],
          periods: const [1],
          startMinutes: 480,
          endMinutes: 525,
          timeRange: '08:00-08:45',
          credit: 0,
          remarks: '',
          customFields: const {},
          reminderSettings: setting,
        );
        await _pumpEditorHost(
          tester,
          initialCourse: initial,
          onSave: (course) async => saved = course,
        );
        expect(
          find.byKey(const ValueKey('course-reminder-behavior')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('course-open-notifications')),
          findsNothing,
        );
        final more = find.widgetWithText(ExpansionTile, 'More');
        expect(tester.widget<ExpansionTile>(more).initiallyExpanded, isFalse);
        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await tester.pumpAndSettle();
        expect(saved?.reminderSettings, setting);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'invalid hidden reminder expands More and focuses the error instead of saving a default',
    (tester) async {
      CourseItem? saved;
      final initial = CourseItem(
        id: 'reminder-validation',
        name: 'Validated reminder',
        teacher: '',
        location: '',
        dayOfWeek: 1,
        semesterWeeks: const [1],
        periods: const [1],
        startMinutes: 480,
        endMinutes: 525,
        timeRange: '08:00-08:45',
        credit: 0,
        remarks: '',
        customFields: const {},
        reminderSettings: const CourseReminderSettings(
          behavior: CourseReminderBehavior.custom,
          minutesBefore: 5,
        ),
      );
      await _pumpEditorHost(
        tester,
        initialCourse: initial,
        onSave: (course) async => saved = course,
      );
      final minutes = find.byKey(
        const ValueKey('course-reminder-custom-minutes'),
      );
      final save = find.widgetWithText(FilledButton, 'Save');
      await tester.ensureVisible(find.text('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      for (final invalid in ['', '-1', '1.5', 'oops']) {
        await tester.ensureVisible(minutes);
        await tester.enterText(minutes, invalid);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('More'));
        await tester.pumpAndSettle();
        expect(find.text('More').hitTestable(), findsOneWidget);
        await tester.tap(find.text('More'));
        await tester.pumpAndSettle();
        expect(minutes, findsNothing);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(saved, isNull);
        expect(minutes, findsOneWidget);
        expect(
          find.text('Enter a whole number of minutes, zero or greater.'),
          findsOneWidget,
        );
        expect(tester.widget<TextField>(minutes).focusNode!.hasFocus, isTrue);
      }
      await tester.enterText(minutes, '0');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('More'));
      await tester.pumpAndSettle();
      expect(find.text('More').hitTestable(), findsOneWidget);
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(
        saved?.reminderSettings,
        const CourseReminderSettings(
          behavior: CourseReminderBehavior.custom,
          minutesBefore: 0,
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cyclic time changes stay in the course draft until confirmation and save',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1000, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final saved = <CourseItem>[];
      await _pumpEditorHost(
        tester,
        onSave: (course) async {
          saved.add(course);
        },
      );
      await tester.enterText(
        find.byKey(const ValueKey('course-desktop-title')),
        'Cyclic course',
      );
      final start = find.byKey(const ValueKey('course-start-time-action'));
      await tester.ensureVisible(start);
      await tester.tap(start);
      await tester.pumpAndSettle();
      await _scrollTimeMinute(tester, -1);
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('sked-time-hour-input')),
            )
            .controller!
            .text,
        '08',
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('sked-time-minute-input')),
            )
            .controller!
            .text,
        '59',
      );
      await tester.tap(find.byKey(const ValueKey('sked-time-cancel')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: start, matching: find.text('08:00')),
        findsOneWidget,
      );
      final end = find.byKey(const ValueKey('course-end-time-action'));
      await tester.ensureVisible(end);
      await tester.tap(end);
      await tester.pumpAndSettle();
      await _scrollTimeMinute(tester, 1);
      expect(saved, isEmpty);
      await tester.tap(find.byKey(const ValueKey('sked-time-confirm')));
      await tester.pumpAndSettle();
      expect(saved, isEmpty);
      expect(
        find.descendant(of: end, matching: find.text('09:41')),
        findsOneWidget,
      );
      final save = find.widgetWithText(FilledButton, 'Save');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(saved, hasLength(1));
      expect(saved.single.startMinutes, 480);
      expect(saved.single.endMinutes, 581);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets('real course sheet offsets title from its top edge', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 776);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _localizedApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () {
              unawaited(
                showAppModalSheet<void>(
                  context: context,
                  builder: (_) => CourseEditorSheet(
                    periodTimes: buildDefaultPeriodTimes().take(4).toList(),
                    totalWeeks: 18,
                    dayOfWeek: 1,
                  ),
                ),
              );
            },
            child: const Text('Open course sheet'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open course sheet'));
    await tester.pumpAndSettle();

    final sheet = find.byType(BottomSheet);
    expect(sheet, findsOneWidget);
    final sheetWidget = tester.widget<BottomSheet>(sheet);
    expect(sheetWidget.enableDrag, isTrue);
    expect(sheetWidget.showDragHandle, isFalse);
    final title = find.descendant(
      of: find.byType(CourseEditorSheet),
      matching: find.text('Add course'),
    );
    expect(title, findsOneWidget);
    expect(
      tester.getTopLeft(title).dy - tester.getRect(sheet).top,
      closeTo(16, .1),
    );
    expect(
      tester.getTopLeft(title).dx,
      tester.getTopLeft(find.byKey(const ValueKey('course-desktop-title'))).dx,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the editor title below the sheet top edge', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 776);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _localizedApp(
        CourseEditorSheet(
          periodTimes: buildDefaultPeriodTimes().take(4).toList(),
          totalWeeks: 18,
          dayOfWeek: 1,
        ),
      ),
    );
    await tester.pump();

    final titleTop = tester.getTopLeft(find.text('Add course')).dy;
    expect(titleTop, closeTo(16, .1));
    expect(
      tester.getTopLeft(find.text('Add course')).dx,
      tester.getTopLeft(find.byKey(const ValueKey('course-desktop-title'))).dx,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('lays out on narrow screens', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _localizedApp(
        CourseEditorSheet(
          periodTimes: buildDefaultPeriodTimes().take(4).toList(),
          totalWeeks: 18,
          dayOfWeek: 1,
          initialCourse: CourseItem(
            id: 'course',
            name: 'Advanced interaction design',
            teacher: 'Teacher',
            location: 'Room 101',
            dayOfWeek: 1,
            semesterWeeks: buildAllSemesterWeeks(18),
            periods: const [1, 2],
            startMinutes: 8 * 60,
            endMinutes: 9 * 60 + 40,
            timeRange: '08:00-09:40',
            credit: 2,
            remarks: '',
            customFields: const {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CourseEditorSheet), findsOneWidget);
    final startTime = find.byKey(const ValueKey('course-start-time-action'));
    final endTime = find.byKey(const ValueKey('course-end-time-action'));
    expect(startTime, findsOneWidget);
    expect(endTime, findsOneWidget);
    expect(tester.getSize(startTime).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(endTime).height, greaterThanOrEqualTo(48));
    expect(
      tester.getTopLeft(endTime).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(startTime).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('groups course times and exposes separate accessible actions', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 776);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _localizedApp(
        CourseEditorSheet(
          periodTimes: buildDefaultPeriodTimes().take(4).toList(),
          totalWeeks: 18,
          dayOfWeek: 1,
        ),
      ),
    );
    await tester.pump();

    final range = find.byKey(const ValueKey('course-time-range'));
    final startTime = find.byKey(const ValueKey('course-start-time-action'));
    final endTime = find.byKey(const ValueKey('course-end-time-action'));
    final rangeContent = find.byKey(
      const ValueKey('course-time-range-content'),
    );
    final rangeArrow = find.byKey(const ValueKey('course-time-range-arrow'));
    final iconBackground = find.byKey(
      const ValueKey('course-time-range-icon-background'),
    );
    expect(range, findsOneWidget);
    expect(startTime, findsOneWidget);
    expect(endTime, findsOneWidget);
    expect(rangeContent, findsOneWidget);
    expect(rangeArrow, findsOneWidget);
    expect(iconBackground, findsOneWidget);
    expect(
      tester.getTopLeft(startTime).dy,
      moreOrLessEquals(tester.getTopLeft(endTime).dy, epsilon: 1),
    );
    expect(
      tester.getSize(startTime).width,
      moreOrLessEquals(tester.getSize(endTime).width, epsilon: 0.1),
    );
    expect(
      tester.getCenter(rangeArrow).dx,
      moreOrLessEquals(tester.getCenter(rangeContent).dx, epsilon: 0.1),
    );
    expect(tester.getSize(iconBackground), const Size.square(42));
    for (final action in <Finder>[startTime, endTime]) {
      final inkWell = tester.widget<InkWell>(
        find.descendant(of: action, matching: find.byType(InkWell)),
      );
      expect(inkWell.customBorder, isA<RoundedRectangleBorder>());
    }
    final iconContainer = tester.widget<Container>(
      find.descendant(of: iconBackground, matching: find.byType(Container)),
    );
    final iconDecoration = iconContainer.decoration! as ShapeDecoration;
    expect(iconDecoration.shape, isA<RoundedRectangleBorder>());
    expect(iconDecoration.color, isNot(Colors.transparent));
    expect(tester.getSemantics(startTime).label, 'Start time');
    expect(tester.getSemantics(startTime).value, '08:00');
    expect(tester.getSemantics(endTime).label, 'End time');
    expect(tester.getSemantics(endTime).value, '09:40');
    expect(
      find.descendant(
        of: range,
        matching: find.byIcon(Icons.schedule_outlined),
      ),
      findsOneWidget,
    );
    expect(find.text('More'), findsOneWidget);
    expect(find.text('Teacher · Remarks'), findsNothing);

    await tester.ensureVisible(startTime);
    await tester.pumpAndSettle();
    await tester.tap(startTime);
    await tester.pumpAndSettle();
    expect(find.byType(SkedTimePicker), findsOneWidget);
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(endTime);
    await tester.pumpAndSettle();
    await tester.tap(endTime);
    await tester.pumpAndSettle();
    expect(find.byType(SkedTimePicker), findsOneWidget);
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('course time range remains reachable with large text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: CourseEditorSheet(
            periodTimes: buildDefaultPeriodTimes().take(4).toList(),
            totalWeeks: 18,
            dayOfWeek: 1,
          ),
        ),
      ),
    );
    await tester.pump();

    final startTime = find.byKey(const ValueKey('course-start-time-action'));
    final endTime = find.byKey(const ValueKey('course-end-time-action'));
    expect(startTime, findsOneWidget);
    expect(endTime, findsOneWidget);
    expect(tester.getSize(startTime).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(endTime).height, greaterThanOrEqualTo(48));
    expect(
      tester.getTopLeft(endTime).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(startTime).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps an editable form viewport above the Android IME', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(2),
            viewInsets: const EdgeInsets.only(bottom: 220),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => unawaited(
                showAppModalSheet<void>(
                  context: context,
                  enableDrag: false,
                  builder: (_) => CourseEditorSheet(
                    periodTimes: buildDefaultPeriodTimes().take(4).toList(),
                    totalWeeks: 18,
                    dayOfWeek: 1,
                    initialCourse: CourseItem(
                      id: 'course-ime',
                      name: 'Android editing',
                      teacher: 'Teacher',
                      location: 'Room 101',
                      dayOfWeek: 1,
                      semesterWeeks: buildAllSemesterWeeks(18),
                      periods: const [1],
                      startMinutes: 8 * 60,
                      endMinutes: 8 * 60 + 45,
                      timeRange: '08:00-08:45',
                      credit: 2,
                      remarks: 'Keep this draft reachable',
                      customFields: const {},
                    ),
                  ),
                ),
              ),
              child: const Text('Open course sheet'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open course sheet'));
    await tester.pumpAndSettle();

    final editor = find.byType(CourseEditorSheet);
    final scrollView = find.descendant(
      of: editor,
      matching: find.byKey(const PageStorageKey('app-sheet-body')),
    );
    expect(scrollView, findsOneWidget);
    expect(tester.getSize(scrollView).height, greaterThanOrEqualTo(48));
    expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('semester week cells keep Android size and selected semantics', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _localizedApp(
        CourseEditorSheet(
          periodTimes: buildDefaultPeriodTimes().take(4).toList(),
          totalWeeks: 18,
          dayOfWeek: 1,
        ),
      ),
    );
    await tester.pump();

    final weeks = find.text('Weeks').last;
    await tester.ensureVisible(weeks);
    await tester.pumpAndSettle();
    await tester.tap(weeks);
    await tester.pumpAndSettle();

    final firstWeek = find.byKey(const ValueKey('course-semester-week-1'));
    expect(tester.getSize(firstWeek).height, greaterThanOrEqualTo(48));
    expect(
      tester
          .getSemantics(firstWeek)
          .getSemanticsData()
          .flagsCollection
          .isSelected,
      ui.Tristate.isTrue,
    );

    final firstWeekNode = tester.getSemantics(firstWeek);
    expect(
      firstWeekNode.getSemanticsData().hasAction(ui.SemanticsAction.tap),
      isTrue,
    );
    firstWeekNode.owner!.performAction(
      firstWeekNode.id,
      ui.SemanticsAction.tap,
    );
    await tester.pump();
    expect(
      tester
          .getSemantics(firstWeek)
          .getSemanticsData()
          .flagsCollection
          .isSelected,
      ui.Tristate.isFalse,
    );
    await tester.tap(firstWeek);
    await tester.pump();
    expect(
      tester
          .getSemantics(firstWeek)
          .getSemanticsData()
          .flagsCollection
          .isSelected,
      ui.Tristate.isTrue,
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('secondary picker ignores rapid duplicate taps', (tester) async {
    await tester.pumpWidget(
      _localizedApp(
        CourseEditorSheet(
          periodTimes: buildDefaultPeriodTimes().take(4).toList(),
          totalWeeks: 18,
          dayOfWeek: 1,
        ),
      ),
    );
    await tester.pump();

    final dayPicker = find.text('Day');
    expect(dayPicker, findsOneWidget);

    await tester.tap(dayPicker);
    await tester.tap(dayPicker, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Choose day'), findsOneWidget);

    await tester.tap(find.text('Tuesday'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('save failure preserves the draft and allows retry', (
    tester,
  ) async {
    var failSave = true;
    var saveCount = 0;
    CourseItem? savedCourse;
    await _pumpEditorHost(
      tester,
      onSave: (course) async {
        saveCount += 1;
        if (failSave) throw StateError('course save failed');
        savedCourse = course;
      },
    );

    final nameField = find.widgetWithText(TextField, 'Course name');
    await tester.enterText(nameField, 'Retryable course draft');
    final saveButton = find.widgetWithText(FilledButton, 'Save');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(saveCount, 1);
    expect(savedCourse, isNull);
    expect(find.byType(CourseEditorSheet), findsOneWidget);
    expect(
      tester.widget<TextField>(nameField).controller?.text,
      'Retryable course draft',
    );
    expect(find.text('Save failed. Please try again later.'), findsOneWidget);
    expect(tester.takeException(), isNull);

    failSave = false;
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(saveCount, 2);
    expect(savedCourse?.name, 'Retryable course draft');
    expect(find.byType(CourseEditorSheet), findsNothing);
    expect(find.text('Open editor'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selection tiles are disabled while save is pending', (
    tester,
  ) async {
    final saveStarted = Completer<void>();
    final allowSave = Completer<void>();
    await _pumpEditorHost(
      tester,
      onSave: (_) {
        saveStarted.complete();
        return allowSave.future;
      },
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Course name'),
      'Pending course',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await saveStarted.future;
    await tester.pump();

    final dayTile = find
        .ancestor(of: find.text('Day'), matching: find.byType(InkWell))
        .first;
    expect(tester.widget<InkWell>(dayTile).onTap, isNull);

    allowSave.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CourseEditorSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('course reminder editor supports inherit, disabled, and custom', (
    tester,
  ) async {
    CourseItem? savedCourse;
    await _pumpEditorHost(
      tester,
      onSave: (course) async => savedCourse = course,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Course name'),
      'Reminder course',
    );

    await tester.ensureVisible(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    final section = find.byKey(const ValueKey('course-reminder-section'));
    expect(section, findsOneWidget);
    await tester.ensureVisible(section);
    await tester.tap(find.byKey(const ValueKey('course-reminder-behavior')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('course-reminder-behavior')),
      findsOneWidget,
    );
    final disabled = find.text('No reminder');
    await tester.ensureVisible(disabled);
    await tester.tap(disabled);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('course-reminder-behavior')));
    await tester.pumpAndSettle();
    final custom = find.text('Custom').last;
    await tester.ensureVisible(custom);
    await tester.tap(custom);
    await tester.pumpAndSettle();
    final customMinutes = find.byKey(
      const ValueKey('course-reminder-custom-minutes'),
    );
    await tester.ensureVisible(customMinutes);
    await tester.enterText(customMinutes, '25');
    final saveButton = find.widgetWithText(FilledButton, 'Save');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(
      savedCourse?.reminderSettings,
      const CourseReminderSettings(
        behavior: CourseReminderBehavior.custom,
        minutesBefore: 25,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('course deletion preserves a newer root task', (tester) async {
    final gate = Completer<void>();
    var writes = 0;
    final initialCourse = CourseItem(
      id: 'course-delete-owner',
      name: 'Course to delete',
      teacher: '',
      location: '',
      dayOfWeek: 1,
      semesterWeeks: const [1],
      periods: const [1],
      startMinutes: 480,
      endMinutes: 525,
      timeRange: '08:00-08:45',
      credit: 0,
      remarks: '',
      customFields: const {},
    );
    try {
      await _pumpEditorHost(
        tester,
        initialCourse: initialCourse,
        onDelete: () async {
          writes++;
          await gate.future;
        },
      );
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();
      final confirmation = find.byType(AlertDialog);
      final ownerContext = tester.element(confirmation);
      final owner = ModalRoute.of(ownerContext)!;
      final confirm = find.descendant(
        of: confirmation,
        matching: find.widgetWithText(TextButton, 'Delete'),
      );
      await tester.tap(confirm);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(writes, 1);
      final newer = DialogRoute<bool>(
        context: ownerContext,
        builder: (_) => const AlertDialog(
          key: ValueKey('newer-course-task'),
          title: Text('Other task'),
        ),
      );
      unawaited(Navigator.of(ownerContext, rootNavigator: true).push(newer));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(owner.isCurrent, isFalse);
      gate.complete();
      await tester.pumpAndSettle();

      expect(writes, 1);
      expect(owner.isActive, isFalse);
      expect(newer.isActive, isTrue);
      expect(find.byKey(const ValueKey('newer-course-task')), findsOneWidget);
      expect(find.byType(CourseEditorSheet), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      if (!gate.isCompleted) gate.complete();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });

  testWidgets('delete failure keeps confirmation open and allows retry', (
    tester,
  ) async {
    var failDelete = true;
    var deleteCount = 0;
    final initialCourse = CourseItem(
      id: 'course-delete',
      name: 'Course to delete',
      teacher: '',
      location: '',
      dayOfWeek: 1,
      semesterWeeks: buildAllSemesterWeeks(18),
      periods: const [1],
      startMinutes: 8 * 60,
      endMinutes: 8 * 60 + 45,
      timeRange: '08:00-08:45',
      credit: 0,
      remarks: '',
      customFields: const {},
    );
    await _pumpEditorHost(
      tester,
      initialCourse: initialCourse,
      onDelete: () async {
        deleteCount += 1;
        if (failDelete) throw StateError('course delete failed');
      },
    );

    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
    final confirmDelete = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(TextButton, 'Delete'),
    );
    await tester.tap(confirmDelete);
    await tester.pumpAndSettle();

    expect(deleteCount, 1);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(CourseEditorSheet), findsOneWidget);
    expect(find.text('Save failed. Please try again later.'), findsOneWidget);
    expect(tester.widget<TextButton>(confirmDelete).onPressed, isNotNull);
    expect(tester.takeException(), isNull);

    failDelete = false;
    await tester.tap(confirmDelete);
    await tester.pumpAndSettle();

    expect(deleteCount, 2);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(CourseEditorSheet), findsNothing);
    expect(find.text('Open editor'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
