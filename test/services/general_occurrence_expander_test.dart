import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/general_event.dart';
import 'package:sked/models/general_event_occurrence.dart';
import 'package:sked/models/general_schedule.dart';
import 'package:sked/models/general_schedule_data.dart';
import 'package:sked/services/general_occurrence_service.dart';

void main() {
  test('injected expansion preserves source order, sorting and filtering', () {
    final start = DateTime.utc(2026, 1, 1);
    final end = start.add(const Duration(days: 2));
    final calendars = [
      for (var calendar = 0; calendar < 3; calendar++)
        GeneralSchedule(
          id: 'calendar-$calendar',
          name: 'Calendar $calendar',
          isVisible: calendar != 1,
          events: [
            for (var event = 0; event < 40; event++)
              GeneralEvent(
                id: 'event-$calendar-$event',
                calendarId: 'calendar-$calendar',
                title: 'Tied title',
                notes: event.isEven ? 'match' : 'other',
                startDateTimeIso: start.toIso8601String(),
                endDateTimeIso: end.toIso8601String(),
              ),
          ],
        ),
    ];
    final general = GeneralScheduleData(
      activeScheduleId: calendars.first.id,
      schedules: calendars,
    );
    final query = GeneralOccurrenceQuery(
      startInclusive: start,
      endExclusive: end,
      searchQuery: 'match',
    );
    final calls = <(GeneralSchedule, GeneralEvent)>[];
    final service = GeneralOccurrenceService(
      expandEvent:
          ({
            required calendar,
            required event,
            required startInclusive,
            required endExclusive,
          }) {
            expect(startInclusive, same(start));
            expect(endExclusive, same(end));
            calls.add((calendar, event));
            return expandGeneralEventOccurrences(
              calendar: calendar,
              event: event,
              startInclusive: startInclusive,
              endExclusive: endExclusive,
            );
          },
    );
    final result = service.occurrencesForQuery(general, query);
    final expected = const GeneralOccurrenceService().occurrencesForQuery(
      general,
      query,
    );
    expect(calls, [
      for (final calendar in calendars.where((item) => item.isVisible))
        for (final event in calendar.events) (calendar, event),
    ]);
    expect(
      result.map((item) => item.occurrenceKey),
      expected.map((item) => item.occurrenceKey),
    );
  });
}
