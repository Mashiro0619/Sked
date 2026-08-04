import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';
import 'package:sked/widgets/sked_dropdown_menu.dart';

Widget _localizedApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

Widget _localizedZhApp(Widget child) {
  return MaterialApp(
    locale: const Locale('zh'),
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
        GeneralEventEditorSheet(
          calendars: const [
            GeneralSchedule(id: 'work', name: 'Work calendar', events: []),
          ],
          activeCalendarId: 'work',
          initialEvent: GeneralEvent(
            id: 'event',
            calendarId: 'work',
            title: 'Long planning session',
            startDateTimeIso: '2026-05-25T09:00:00.000',
            endDateTimeIso: '2026-05-25T10:00:00.000',
            recurrenceRule: const GeneralEventRecurrenceRule(
              type: GeneralEventRecurrence.custom,
              interval: 2,
              unit: GeneralEventRecurrenceUnit.week,
              count: 4,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(GeneralEventEditorSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('builds with an empty calendar list', (tester) async {
    await tester.pumpWidget(
      _localizedApp(const GeneralEventEditorSheet(calendars: [])),
    );
    await tester.pump();

    expect(find.byType(GeneralEventEditorSheet), findsOneWidget);
    expect(find.byType(SkedDropdownMenu<String>), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hides calendar picker when only one calendar exists', (
    tester,
  ) async {
    await tester.pumpWidget(
      _localizedApp(
        GeneralEventEditorSheet(
          calendars: const [
            GeneralSchedule(id: 'work', name: 'Work', events: []),
          ],
          activeCalendarId: 'work',
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(SkedDropdownMenu<String>), findsNothing);
    expect(find.text('Work'), findsNothing);
  });

  testWidgets('shows event place field below title in Chinese locale', (
    tester,
  ) async {
    await tester.pumpWidget(
      _localizedZhApp(
        GeneralEventEditorSheet(
          calendars: const [
            GeneralSchedule(id: 'work', name: 'Work', events: []),
          ],
          activeCalendarId: 'work',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('地点'), findsOneWidget);
    expect(find.text('上课地点'), findsNothing);

    final titleTop = tester.getTopLeft(find.text('日程标题')).dy;
    final placeTop = tester.getTopLeft(find.text('地点')).dy;
    expect(placeTop, greaterThan(titleTop));
  });

  testWidgets('all-day switch tap changes once', (tester) async {
    await tester.pumpWidget(
      _localizedApp(
        GeneralEventEditorSheet(
          calendars: const [
            GeneralSchedule(id: 'work', name: 'Work', events: []),
          ],
          activeCalendarId: 'work',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Pick time'), findsNWidgets(2));

    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(find.byTooltip('Pick time'), findsNothing);
  });

  testWidgets('trims the initial event calendar id', (tester) async {
    await tester.pumpWidget(
      _localizedApp(
        GeneralEventEditorSheet(
          calendars: const [
            GeneralSchedule(id: 'work', name: 'Work', events: []),
            GeneralSchedule(id: 'home', name: 'Home', events: []),
          ],
          activeCalendarId: 'work',
          initialEvent: GeneralEvent(
            id: 'event',
            calendarId: ' home ',
            title: 'Dinner',
            startDateTimeIso: '2026-05-25T18:00:00.000',
            endDateTimeIso: '2026-05-25T19:00:00.000',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('shows calendar picker when multiple calendars exist', (
    tester,
  ) async {
    await tester.pumpWidget(
      _localizedApp(
        GeneralEventEditorSheet(
          calendars: const [
            GeneralSchedule(id: 'work', name: 'Work', events: []),
            GeneralSchedule(id: 'home', name: 'Home', events: []),
          ],
          activeCalendarId: 'work',
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(SkedDropdownMenu<String>), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);
  });

  testWidgets('save / cancel / delete cannot pop twice on rapid tap', (
    tester,
  ) async {
    final results = <GeneralEventEditorResult?>[];

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  final outcome =
                      await showModalBottomSheet<GeneralEventEditorResult>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => GeneralEventEditorSheet(
                          calendars: const [
                            GeneralSchedule(
                              id: 'work',
                              name: 'Work',
                              events: [],
                            ),
                          ],
                          activeCalendarId: 'work',
                          initialEvent: GeneralEvent(
                            id: 'event',
                            calendarId: 'work',
                            title: 'Meeting',
                            startDateTimeIso: '2026-05-25T09:00:00.000',
                            endDateTimeIso: '2026-05-25T10:00:00.000',
                          ),
                        ),
                      );
                  results.add(outcome);
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(GeneralEventEditorSheet)),
    );
    final cancelFinder = find.widgetWithText(TextButton, l10n.cancel);
    expect(cancelFinder, findsOneWidget);

    await tester.tap(cancelFinder);
    await tester.tap(cancelFinder, warnIfMissed: false);
    await tester.pump();

    expect(
      (tester.widget(cancelFinder) as TextButton).onPressed,
      isNull,
      reason:
          'Cancel button must be disabled after first tap to block re-entry.',
    );

    await tester.pumpAndSettle();

    expect(results, hasLength(1));
    expect(results.single, isNull);
    expect(
      find.text('Open'),
      findsOneWidget,
      reason: 'Parent route must remain after double-tap on cancel.',
    );
  });

  testWidgets('date picker ignores rapid duplicate taps', (tester) async {
    await tester.pumpWidget(
      _localizedApp(
        GeneralEventEditorSheet(
          calendars: const [
            GeneralSchedule(id: 'work', name: 'Work', events: []),
          ],
          activeCalendarId: 'work',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final pickDateButton = find.byTooltip('Pick date').first;
    await tester.tap(pickDateButton);
    await tester.tap(pickDateButton, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(DatePickerDialog),
        matching: find.widgetWithText(TextButton, 'Cancel'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsNothing);
  });

  testWidgets('recurrence end picker starts no earlier than event start', (
    tester,
  ) async {
    await tester.pumpWidget(
      _localizedApp(
        GeneralEventEditorSheet(
          calendars: const [
            GeneralSchedule(id: 'work', name: 'Work', events: []),
          ],
          activeCalendarId: 'work',
          initialEvent: GeneralEvent(
            id: 'event',
            calendarId: 'work',
            title: 'Meeting',
            startDateTimeIso: '2026-05-25T09:00:00.000',
            endDateTimeIso: '2026-05-25T10:00:00.000',
            recurrenceRule: const GeneralEventRecurrenceRule(
              type: GeneralEventRecurrence.weekly,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final endDateButton = find.widgetWithText(FilledButton, 'End date');
    await tester.ensureVisible(endDateButton);
    await tester.tap(endDateButton);
    await tester.pumpAndSettle();

    final calendar = tester.widget<CalendarDatePicker>(
      find.byType(CalendarDatePicker),
    );
    expect(calendar.firstDate, DateTime(2026, 5, 25));
  });
}
