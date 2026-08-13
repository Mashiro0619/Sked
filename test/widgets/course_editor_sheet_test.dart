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

void main() {
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
                  enableDrag: false,
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
    expect(sheetWidget.showDragHandle, isFalse);
    final title = find.descendant(
      of: find.byType(CourseEditorSheet),
      matching: find.text('Add course'),
    );
    expect(title, findsOneWidget);
    expect(
      tester.getTopLeft(title).dy - tester.getRect(sheet).top,
      greaterThanOrEqualTo(20),
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
    expect(titleTop, greaterThanOrEqualTo(20));
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
      expect(inkWell.customBorder, isA<RoundedSuperellipseBorder>());
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
    expect(find.byType(TimePickerDialog), findsOneWidget);
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(endTime);
    await tester.pumpAndSettle();
    await tester.tap(endTime);
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
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
      matching: find.byType(SingleChildScrollView),
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

    await tester.tap(firstWeek);
    await tester.pump();
    expect(
      tester
          .getSemantics(firstWeek)
          .getSemanticsData()
          .flagsCollection
          .isSelected,
      ui.Tristate.isFalse,
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
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
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
