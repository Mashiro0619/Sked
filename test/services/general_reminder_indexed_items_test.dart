import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/general_occurrence_cache.dart';
import 'package:sked/services/general_occurrence_service.dart';

void main() {
  final now = DateTime.utc(2026, 10, 24, 9);
  const service = GeneralOccurrenceService();
  const hugeLead = 9223372036854775807;

  GeneralEvent event(
    String id, {
    int lead = hugeLead,
    int? count,
    DateTime? start,
    Duration duration = const Duration(hours: 1),
    GeneralEventRecurrence recurrence = GeneralEventRecurrence.weekly,
    List<String> exceptions = const [],
    bool allDay = false,
    bool disabled = false,
  }) {
    final date = start ?? now;
    return GeneralEvent(
      id: id,
      calendarId: 'calendar',
      title: 'Title $id',
      startDateTimeIso: date.toIso8601String(),
      endDateTimeIso: date.add(duration).toIso8601String(),
      isAllDay: allDay,
      recurrenceRule: GeneralEventRecurrenceRule(
        type: recurrence,
        count: count,
      ),
      recurrenceExceptionDateIso: exceptions,
      reminderBehavior: disabled
          ? GeneralEventReminderBehavior.disabled
          : GeneralEventReminderBehavior.custom,
      reminders: [GeneralEventReminder(minutesBefore: lead)],
    );
  }

  GeneralScheduleData data(List<GeneralEvent> events) => GeneralScheduleData(
    activeScheduleId: 'calendar',
    schedules: [
      GeneralSchedule(id: 'calendar', name: 'Calendar', events: events),
    ],
  );

  List<String> snapshot(Iterable<GeneralReminderItem> items) => [
    for (final item in items)
      '${item.status.name}:${item.occurrence.occurrenceKey}',
  ];

  for (final cached in [false, true]) {
    test(
      'huge complete reminders support random access without retention: cache=$cached',
      () {
        final original = event('huge');
        final value = data([original]);
        final before = original.toJson();
        final cache = GeneralOccurrenceCache();
        for (var minute = 0; minute < 3; minute++) {
          final anchor = now.add(Duration(minutes: minute));
          final items =
              (cached
                      ? cache.reminderItems(value, now: anchor)
                      : service.reminderItems(value, now: anchor))
                  as GeneralReminderItems;
          expect(items.length, greaterThan(400000));
          expect(items.last.occurrence.start.year, 9999);
          expect(items.first.status, GeneralReminderStatus.inProgress);
          expect(items.retainedRowCount, lessThanOrEqualTo(2));
          final middle = items.length ~/ 2;
          expect(
            items.indexOfOccurrenceKey(items[middle].occurrence.occurrenceKey),
            middle,
          );
          expect(
            items.indexOfOccurrenceKey(items.last.occurrence.occurrenceKey),
            items.length - 1,
          );
          for (var index = 0; index < 600; index++) {
            expect(items[index * 13].occurrence.event.id, 'huge');
          }
          expect(items.retainedRowCount, lessThanOrEqualTo(256));
          expect(
            items.countForStatus(GeneralReminderStatus.upcoming),
            items.length - 1,
          );
        }
        expect(original.toJson(), before);
      },
    );
  }

  test('filtered huge recurrences are rejected before expansion', () {
    final value = data([event('excluded')]);
    final cache = GeneralOccurrenceCache();
    final items = cache.reminderItems(
      value,
      now: now,
      occurrenceFilter: GeneralOccurrenceQuery(
        startInclusive: now,
        endExclusive: now.add(const Duration(days: 1)),
        searchQuery: 'does not match',
      ),
    );
    expect(items, isA<GeneralReminderItems>());
    expect(items, isEmpty);
  });

  test('indexed ordering, statuses, microseconds and row ownership match complete expansion', () {
    for (final local in [false, true]) {
      final anchor = local ? now.toLocal() : now;
      final value = data([
        event(
          'daily',
          count: 600,
          lead: 600 * 1440,
          recurrence: GeneralEventRecurrence.daily,
          start: anchor.subtract(const Duration(days: 3)),
          duration: const Duration(days: 2),
          exceptions: [
            anchor
                .add(const Duration(days: 4))
                .toIso8601String()
                .split('T')
                .first,
          ],
        ),
        event(
          'weekly',
          count: 90,
          lead: 600 * 1440,
          start: anchor.subtract(const Duration(days: 8)),
        ),
        event(
          'monthly',
          count: 24,
          lead: 600 * 1440,
          recurrence: GeneralEventRecurrence.monthly,
          start: anchor.subtract(const Duration(days: 90)),
        ),
        event(
          'tie-earlier',
          count: 600,
          lead: 600 * 1440,
          recurrence: GeneralEventRecurrence.daily,
          start: anchor.add(const Duration(microseconds: 100)),
        ),
        event(
          'tie-later',
          count: 600,
          lead: 600 * 1440,
          recurrence: GeneralEventRecurrence.daily,
          start: anchor.add(const Duration(microseconds: 900)),
        ),
        event(
          'all-day',
          count: 600,
          lead: 600 * 1440,
          recurrence: GeneralEventRecurrence.daily,
          start: normalizeDateOnly(anchor),
          allDay: true,
          duration: const Duration(days: 2),
        ),
        event('off', disabled: true),
      ]);
      final end = generalReminderCandidateEndExclusive(
        value,
        anchor: anchor,
        upcomingHorizon: const Duration(days: 1),
        notificationSettings: const NotificationSettings(),
      );
      final reference = service.reminderItemsFromOccurrences(
        value,
        expandGeneralOccurrences(
          calendars: value.schedules,
          startInclusive: anchor.subtract(const Duration(days: 1)),
          endExclusive: end,
        ),
        now: anchor,
      );
      final items = service.indexedReminderItems(value, now: anchor);
      expect(snapshot(items), snapshot(reference), reason: 'local=$local');
      expect(
        snapshot([
          for (var index = 0; index < items.length; index++) items[index],
        ]),
        snapshot(reference),
        reason: 'consecutive row access, local=$local',
      );
      final positions = [0, items.length - 1, 3, 4, items.length ~/ 2, 6, 7];
      for (final index in positions) {
        expect(snapshot([items[index]]), snapshot([reference[index]]));
      }
      for (final status in GeneralReminderStatus.values) {
        expect(
          items.countForStatus(status),
          reference.where((item) => item.status == status).length,
        );
      }
      for (var index = 0; index < items.length; index += 37) {
        final occurrence = items[index].occurrence;
        expect(items.indexOfOccurrenceKey(occurrence.occurrenceKey), index);
        expect(
          items.indexOfOccurrenceKey(
            '${occurrence.calendar.id}|${occurrence.event.id}|${occurrence.start.toIso8601String()}',
          ),
          index,
        );
      }
      final acknowledged = value.copyWith(
        reminderAcknowledgements: [
          for (final item in reference.where(
            (item) => item.occurrence.sequence % 7 == 0,
          ))
            GeneralReminderAcknowledgement(
              occurrenceKey: item.occurrence.occurrenceKey,
              updatedAtIso: anchor.toIso8601String(),
            ),
        ],
      );
      final remaining = service.indexedReminderItems(acknowledged, now: anchor);
      expect(
        snapshot(remaining),
        snapshot(reference.where((item) => item.occurrence.sequence % 7 != 0)),
      );
      for (var index = 0; index < remaining.length; index += 41) {
        expect(
          remaining.indexOfOccurrenceKey(
            remaining[index].occurrence.occurrenceKey,
          ),
          index,
        );
      }
      expect(
        remaining.indexOfOccurrenceKey(
          reference
              .firstWhere((item) => item.occurrence.sequence % 7 == 0)
              .occurrence
              .occurrenceKey,
        ),
        isNull,
      );
    }
  });

  test('indexed cache observes handling, filters, visibility and default lead changes', () {
    final source = data([
      event('huge'),
      event(
        'ordinary',
        recurrence: GeneralEventRecurrence.none,
        lead: 5,
        start: now.add(const Duration(minutes: 5)),
      ),
    ]);
    final cache = GeneralOccurrenceCache();
    final first = cache.reminderItems(source, now: now);
    expect(identical(first, cache.reminderItems(source, now: now)), isTrue);
    final handledKey = first.first.occurrence.occurrenceKey;
    final handled = source.copyWith(
      reminderAcknowledgements: [
        GeneralReminderAcknowledgement(
          occurrenceKey: handledKey,
          updatedAtIso: now.toIso8601String(),
        ),
      ],
    );
    final remaining =
        cache.reminderItems(handled, now: now) as GeneralReminderItems;
    expect(remaining.length, first.length - 1);
    expect(remaining.indexOfOccurrenceKey(handledKey), isNull);
    final hidden = source.copyWith(
      schedules: [source.schedules.single.copyWith(isVisible: false)],
    );
    expect(cache.reminderItems(hidden, now: now), isEmpty);
    expect(
      cache
          .reminderItems(
            hidden,
            now: now,
            notificationSettings: const NotificationSettings(
              remindHiddenGeneralCalendars: true,
            ),
          )
          .length,
      first.length,
    );
    final inherited = source.copyWith(
      schedules: [
        source.schedules.single.copyWith(
          events: [
            source.schedules.single.events.first.copyWith(
              reminderBehavior: GeneralEventReminderBehavior.inherit,
            ),
          ],
        ),
      ],
    );
    final long = cache.reminderItems(
      inherited,
      now: now,
      notificationSettings: const NotificationSettings(
        generalDefaultMinutesBefore: hugeLead,
      ),
    );
    expect(long.length, greaterThan(400000));
    expect(
      cache.reminderItems(
        inherited,
        now: now,
        notificationSettings: const NotificationSettings(
          generalDefaultMinutesBefore: 5,
        ),
      ),
      hasLength(1),
    );
    cache.clear();
    expect(identical(first, cache.reminderItems(source, now: now)), isFalse);
  });
}
