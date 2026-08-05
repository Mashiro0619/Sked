import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/widgets/course_editor_sheet.dart';

Widget _localizedApp(Widget child) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
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
  testWidgets('lays out on narrow screens', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
    expect(tester.takeException(), isNull);
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
