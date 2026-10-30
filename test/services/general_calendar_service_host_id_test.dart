import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/general_calendar_service.dart';

const service = GeneralCalendarService();

void main() {
  test('host owns the ID and timestamp of copied or detached occurrences', () {
    final data = fixture();
    final source = occurrence(data);
    final now = DateTime(2026, 10, 30, 9);
    final before = jsonEncode(data.toJson());
    final copied = service.duplicateOccurrence(
      data,
      source,
      now: now,
      newEventId: 'host-copy',
    );
    expect(copied.event.id, 'host-copy');
    expect(copied.event.createdAtIso, now.toIso8601String());
    for (final scope in [
      GeneralEventEditScope.thisOccurrence,
      GeneralEventEditScope.thisAndFollowing,
    ]) {
      final result = service.editOccurrence(
        data,
        source,
        service.prepareOccurrenceEdit(source, scope).copyWith(title: 'Edited'),
        scope,
        now: now,
        newEventId: 'host-split',
      );
      expect(result.event.id, 'host-split');
      expect(result.event.createdAtIso, now.toIso8601String());
      expect(result.event.updatedAtIso, now.toIso8601String());
    }
    expect(jsonEncode(data.toJson()), before);
  });

  test('invalid supplied IDs reject before the candidate source changes', () {
    final data = fixture();
    final source = occurrence(data);
    final before = jsonEncode(data.toJson());
    for (final id in ['', ' spaced ', 'series']) {
      expect(
        () => service.duplicateOccurrence(data, source, newEventId: id),
        throwsArgumentError,
      );
      expect(
        () => service.editOccurrence(
          data,
          source,
          service
              .prepareOccurrenceEdit(
                source,
                GeneralEventEditScope.thisOccurrence,
              )
              .copyWith(title: 'Edited'),
          GeneralEventEditScope.thisOccurrence,
          newEventId: id,
        ),
        throwsArgumentError,
      );
      expect(jsonEncode(data.toJson()), before);
    }
  });

  test('old UI callers continue allocating distinct new IDs by default', () {
    final data = fixture();
    final source = occurrence(data);
    final copied = service.duplicateOccurrence(data, source);
    final again = service.duplicateOccurrence(copied.data, source);
    expect(copied.event.id, isNot('series'));
    expect(again.event.id, isNot(copied.event.id));
    final entire = service.editOccurrence(
      data,
      source,
      source.event.copyWith(title: 'Entire'),
      GeneralEventEditScope.entireSeries,
    );
    expect(entire.event.id, 'series');
  });

  test(
    'pruning a long-duration series reaches an exact acknowledgement lazily',
    () {
      final event = GeneralEvent(
        id: 'series',
        calendarId: 'calendar',
        title: 'Long',
        startDateTimeIso: '0001-01-01T09:00:00.000Z',
        endDateTimeIso: '8000-01-01T10:00:00.000Z',
        recurrenceRule: const GeneralEventRecurrenceRule(
          type: GeneralEventRecurrence.daily,
          unit: GeneralEventRecurrenceUnit.day,
        ),
        reminders: const [GeneralEventReminder(minutesBefore: 10)],
      );
      final key = buildGeneralOccurrenceKey(
        'calendar',
        'series',
        '2000-01-01T09:00:00.000Z',
      );
      final data = GeneralScheduleData(
        activeScheduleId: 'calendar',
        selectedDateIso: '2026-10-30',
        schedules: [
          GeneralSchedule(id: 'calendar', name: 'Calendar', events: [event]),
        ],
        reminderAcknowledgements: [
          GeneralReminderAcknowledgement(
            occurrenceKey: key,
            updatedAtIso: '2026-10-30T09:00:00.000Z',
          ),
        ],
      );
      final result = service.pruneReminderAcknowledgements(
        data,
        now: DateTime.utc(2026, 10, 30),
      );
      expect(result, same(data));
      expect(result.reminderAcknowledgements.single.occurrenceKey, key);
    },
  );
}

GeneralScheduleData fixture() => GeneralScheduleData(
  activeScheduleId: 'calendar',
  selectedDateIso: '2026-10-30',
  schedules: [
    GeneralSchedule(
      id: 'calendar',
      name: 'Calendar',
      events: [
        GeneralEvent(
          id: 'series',
          calendarId: 'calendar',
          title: 'Series',
          startDateTimeIso: '2026-10-05T09:00:00.000',
          endDateTimeIso: '2026-10-05T10:00:00.000',
          recurrenceRule: const GeneralEventRecurrenceRule(
            type: GeneralEventRecurrence.weekly,
            count: 6,
          ),
        ),
      ],
    ),
  ],
);

GeneralEventOccurrence occurrence(GeneralScheduleData data) =>
    GeneralEventOccurrenceRange(
      calendar: data.schedules.single,
      event: data.schedules.single.events.single,
      startInclusive: DateTime(2026, 10, 19),
      endExclusive: DateTime(2026, 10, 20),
    ).single;
