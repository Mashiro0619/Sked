import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/general_event.dart';
import 'package:sked/models/general_event_occurrence.dart';
import 'package:sked/models/general_schedule.dart';
import 'package:sked/models/general_schedule_data.dart';
import 'package:sked/services/general_occurrence_cache.dart';
import 'package:sked/services/general_occurrence_service.dart';

void main() {
  final now = DateTime.utc(2026, 10, 23, 9);
  final start = now.add(const Duration(minutes: 5));
  const service = GeneralOccurrenceService();

  GeneralEvent event(
    String id, {
    bool enabled = true,
    int lead = 5,
    int? count,
    List<String> exceptions = const [],
  }) => GeneralEvent(
    id: id,
    calendarId: 'calendar',
    title: id,
    startDateTimeIso: start.toIso8601String(),
    endDateTimeIso: start.add(const Duration(hours: 1)).toIso8601String(),
    recurrenceRule: GeneralEventRecurrenceRule(
      type: count == null
          ? GeneralEventRecurrence.none
          : GeneralEventRecurrence.daily,
      count: count,
    ),
    recurrenceExceptionDateIso: exceptions,
    reminderBehavior: enabled
        ? GeneralEventReminderBehavior.custom
        : GeneralEventReminderBehavior.disabled,
    reminders: enabled ? [GeneralEventReminder(minutesBefore: lead)] : const [],
  );

  GeneralScheduleData dataFor(List<GeneralEvent> events) => GeneralScheduleData(
    activeScheduleId: 'calendar',
    schedules: [
      GeneralSchedule(id: 'calendar', name: 'Calendar', events: events),
    ],
  );

  for (final cached in [false, true]) {
    group(cached ? 'cached complete reminders' : 'complete reminders', () {
      late GeneralOccurrenceCache cache;
      setUp(() => cache = GeneralOccurrenceCache());

      List<GeneralReminderItem> items(GeneralScheduleData data) => cached
          ? cache.reminderItems(data, now: now)
          : service.reminderItems(data, now: now);

      test('disabled events cannot consume a later due reminder', () {
        final result = items(
          dataFor([
            for (var index = 0; index < 4096; index++)
              event('off-$index', enabled: false),
            event('due'),
          ]),
        );
        expect(result.map((item) => item.occurrence.event.id), ['due']);
      });

      test('retains every due occurrence beyond 512 within one series', () {
        final original = event('finite', count: 600, lead: 600 * 1440);
        final before = original.toJson();
        final result = items(dataFor([original]));
        expect(result, hasLength(600));
        expect(result.first.occurrence.sequence, 0);
        expect(result.last.occurrence.sequence, 599);
        expect(
          result.every((item) => item.status == GeneralReminderStatus.upcoming),
          isTrue,
        );
        expect(original.toJson(), before);
      });

      test('retains every due event beyond 4096 across lead groups', () {
        final result = items(
          dataFor([
            for (var index = 0; index < 4096; index++) event('due-$index'),
            event('due-other-lead', lead: 6),
          ]),
        );
        expect(result, hasLength(4097));
        expect(
          result.map((item) => item.occurrence.event.id),
          contains('due-other-lead'),
        );
      });

      test('excluded candidates cannot hide later valid occurrences', () {
        final result = items(
          dataFor([
            event(
              'excepted',
              count: 600,
              lead: 600 * 1440,
              exceptions: [
                for (var day = 0; day < 512; day++)
                  start
                      .add(Duration(days: day))
                      .toIso8601String()
                      .split('T')
                      .first,
              ],
            ),
          ]),
        );
        expect(result, hasLength(88));
        expect(result.first.occurrence.sequence, 512);
        expect(result.last.occurrence.sequence, 599);
      });

      test('handled candidates cannot hide later valid occurrences', () {
        final data = dataFor([event('handled', count: 600, lead: 600 * 1440)])
            .normalized();
        final first = items(data);
        final acknowledged = data.copyWith(
          reminderAcknowledgements: [
            for (final item in first.take(512))
              GeneralReminderAcknowledgement(
                occurrenceKey: item.occurrence.occurrenceKey,
                updatedAtIso: now.toIso8601String(),
              ),
          ],
        );
        final result = items(acknowledged);
        expect(result, hasLength(88));
        expect(result.first.occurrence.sequence, 512);
        expect(result.last.occurrence.sequence, 599);
      });
    });
  }

  test('reminder caching leaves ordinary full expansion unchanged', () {
    final cache = GeneralOccurrenceCache();
    final data = dataFor([event('finite', count: 600, lead: 600 * 1440)]);
    final query = GeneralOccurrenceQuery(
      startInclusive: now,
      endExclusive: now.add(const Duration(days: 601)),
    );
    expect(cache.reminderItems(data, now: now), hasLength(600));
    expect(cache.occurrencesForQuery(data, query), hasLength(600));
    expect(cache.reminderItems(data, now: now), hasLength(600));
    expect(
      expandGeneralEventOccurrences(
        calendar: data.schedules.single,
        event: data.schedules.single.events.single,
        startInclusive: query.startInclusive,
        endExclusive: query.endExclusive,
      ),
      hasLength(600),
    );
  });
}
