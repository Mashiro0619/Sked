import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/general_occurrence_service.dart';

void main() {
  const service = GeneralOccurrenceService();
  for (final utc in [false, true]) {
    test('prepared reminders retain exact boundaries with utc=$utc', () {
      final minute = utc
          ? DateTime.utc(2026, 6, 1, 9)
          : DateTime(2026, 6, 1, 9);
      GeneralEvent event(String id, int second, int lead) => GeneralEvent(
        id: id,
        calendarId: 'calendar|with:separator',
        title: 'Match $id',
        startDateTimeIso: minute
            .add(Duration(seconds: second))
            .toIso8601String(),
        endDateTimeIso: minute
            .add(Duration(seconds: second + 20))
            .toIso8601String(),
        recurrenceRule: const GeneralEventRecurrenceRule(
          type: GeneralEventRecurrence.daily,
          count: 150,
        ),
        reminderBehavior: GeneralEventReminderBehavior.custom,
        reminders: [GeneralEventReminder(minutesBefore: lead)],
      );
      final first = event(
        'first|event',
        20,
        const Duration(days: 129).inMinutes,
      );
      final second = event('second', 40, 1);
      final hidden = event('hidden', 15, 2);
      final data = GeneralScheduleData(
        activeScheduleId: first.calendarId,
        schedules: [
          GeneralSchedule(
            id: first.calendarId,
            name: 'Calendar',
            colorValue: 0xff336699,
            events: [first, second],
          ),
          GeneralSchedule(
            id: 'hidden-calendar',
            name: 'Hidden',
            isVisible: false,
            events: [hidden],
          ),
        ],
        reminderAcknowledgements: [
          GeneralReminderAcknowledgement(
            occurrenceKey: buildGeneralOccurrenceKey(
              first.calendarId,
              first.id,
              minute
                  .add(const Duration(days: 1, seconds: 20))
                  .toIso8601String(),
            ),
            updatedAtIso: minute.toIso8601String(),
          ),
        ],
      );
      for (final includeHidden in [false, true]) {
        final settings = NotificationSettings(
          remindHiddenGeneralCalendars: includeHidden,
        );
        final filter = GeneralOccurrenceQuery(
          startInclusive: minute,
          endExclusive: minute.add(const Duration(days: 1)),
          searchQuery: 'match',
        );
        final prepared = service.prepareIndexedReminderInputs(
          data,
          occurrenceFilter: filter,
          notificationSettings: settings,
        );
        for (final micros in [
          0,
          19999999,
          20000000,
          39999999,
          40000000,
          59999999,
        ]) {
          final now = minute.add(Duration(microseconds: micros));
          final expected = service.reminderItemsFromOccurrences(
            data,
            service.occurrencesForRange(
              data,
              startInclusive: now.subtract(const Duration(hours: 24)),
              endExclusive: generalReminderCandidateEndExclusive(
                data,
                anchor: now,
                upcomingHorizon: const Duration(hours: 24),
                notificationSettings: settings,
              ),
              onlyVisibleCalendars: !includeHidden,
            ),
            now: now,
            occurrenceFilter: filter,
            notificationSettings: settings,
          );
          expect(
            _snapshot(
              service.indexedReminderItemsFromPrepared(prepared, now: now),
            ),
            _snapshot(expected),
          );
          expect(
            _snapshot(
              service.indexedReminderItems(
                data,
                now: now,
                occurrenceFilter: filter,
                notificationSettings: settings,
              ),
            ),
            _snapshot(expected),
          );
        }
      }
    });
  }
}

List<Object> _snapshot(List<GeneralReminderItem> items) => [
  for (final item in items)
    (
      item.status,
      item.occurrence.occurrenceKey,
      item.occurrence.end.microsecondsSinceEpoch,
      item.occurrence.sequence,
      item.occurrence.event,
      item.occurrence.calendar,
    ),
];
