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
}
