import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/general_calendar_service.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';

const _service = GeneralCalendarService();

Future<(GeneralEvent, GeneralScheduleData Function())> _mount(
  WidgetTester tester,
  GeneralEventRecurrence type,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(430, 950);
  addTearDown(tester.view.reset);
  final unit = switch (type) {
    GeneralEventRecurrence.daily => GeneralEventRecurrenceUnit.day,
    GeneralEventRecurrence.weekly => GeneralEventRecurrenceUnit.week,
    _ => GeneralEventRecurrenceUnit.month,
  };
  final event = GeneralEvent(
    id: 'series',
    calendarId: 'work',
    title: 'Imported repeat',
    startDateTimeIso: '2026-01-31T09:00:00.000',
    endDateTimeIso: '2026-01-31T10:00:00.000',
    recurrenceRule: GeneralEventRecurrenceRule(
      type: type,
      unit: unit,
      interval: 2,
      count: 6,
    ),
    reminderBehavior: GeneralEventReminderBehavior.inherit,
  );
  final calendar = GeneralSchedule(id: 'work', name: 'Work', events: [event]);
  var data = GeneralScheduleData(
    activeScheduleId: 'work',
    schedules: [calendar],
    reminderAcknowledgements: [
      GeneralReminderAcknowledgement(
        occurrenceKey: buildGeneralOccurrenceKey(
          'work',
          'series',
          event.startDateTimeIso,
        ),
        updatedAtIso: '2026-01-31T08:59:00.000',
      ),
    ],
  );
  final source = GeneralEventOccurrence(
    event: event,
    calendar: calendar,
    start: DateTime(2026, 1, 31, 9),
    end: DateTime(2026, 1, 31, 10),
    sequence: 0,
  );
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: GeneralEventEditorSheet(
          initialEvent: event,
          calendars: [calendar],
          editScope: GeneralEventEditScope.entireSeries,
          onSave: (draft) async {
            data = _service
                .editOccurrence(
                  data,
                  source,
                  draft,
                  GeneralEventEditScope.entireSeries,
                )
                .data;
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (event, () => data);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  for (final type in [
    GeneralEventRecurrence.daily,
    GeneralEventRecurrence.weekly,
    GeneralEventRecurrence.monthly,
  ]) {
    testWidgets(
      '$type with a longer interval keeps its rule and handled state during a content edit',
      (tester) async {
        final (original, current) = await _mount(tester, type);
        final l10n = AppLocalizations.of(
          tester.element(find.byType(GeneralEventEditorSheet)),
        );
        final unit = switch (type) {
          GeneralEventRecurrence.daily => l10n.recurrenceDays,
          GeneralEventRecurrence.weekly => l10n.recurrenceWeeks,
          _ => l10n.recurrenceMonths,
        };
        expect(find.textContaining(l10n.repeatsEvery(2, unit)), findsOneWidget);
        await tester.enterText(find.byType(EditableText).first, 'Edited title');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await _tap(tester, find.widgetWithText(FilledButton, l10n.save));
        final saved = current().schedules.single.events.single;
        expect(saved.title, 'Edited title');
        expect(saved.recurrenceRule.toJson(), original.recurrenceRule.toJson());
        expect(current().reminderAcknowledgements, hasLength(1));
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.windows,
      }),
    );
  }

  testWidgets('changing the imported interval saves the new custom rule', (
    tester,
  ) async {
    final (_, current) = await _mount(tester, GeneralEventRecurrence.weekly);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(GeneralEventEditorSheet)),
    );
    await _tap(tester, find.byKey(const ValueKey('event-recurrence-field')));
    await _tap(
      tester,
      find.byKey(const ValueKey('recurrence-interval-increment')),
    );
    await _tap(tester, find.widgetWithText(FilledButton, l10n.confirm));
    await _tap(tester, find.widgetWithText(FilledButton, l10n.save));
    final saved = current().schedules.single.events.single;
    expect(saved.recurrenceRule.type, GeneralEventRecurrence.custom);
    expect(saved.recurrenceRule.interval, 3);
    expect(saved.recurrenceRule.unit, GeneralEventRecurrenceUnit.week);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
