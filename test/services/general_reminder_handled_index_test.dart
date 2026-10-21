import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/general_event.dart';
import 'package:sked/models/general_event_occurrence.dart';
import 'package:sked/models/general_schedule.dart';
import 'package:sked/models/general_schedule_data.dart';
import 'package:sked/models/notification_settings.dart';
import 'package:sked/services/general_calendar_service.dart';
import 'package:sked/services/general_occurrence_cache.dart';
import 'package:sked/services/general_occurrence_service.dart';

final _start = DateTime.utc(2026, 10, 20, 11);
final _now = _start.add(const Duration(minutes: 30));

GeneralEventOccurrence _occurrence({
  String calendarId = 'calendar',
  String eventId = 'event',
  DateTime? start,
  bool visible = true,
  GeneralEventReminderBehavior reminderBehavior =
      GeneralEventReminderBehavior.custom,
}) {
  final begin = start ?? _start;
  final end = begin.add(const Duration(hours: 1));
  final event = GeneralEvent(
    id: eventId,
    calendarId: calendarId,
    title: eventId,
    startDateTimeIso: begin.toIso8601String(),
    endDateTimeIso: end.toIso8601String(),
    reminderBehavior: reminderBehavior,
    reminders: reminderBehavior == GeneralEventReminderBehavior.custom
        ? const [GeneralEventReminder(minutesBefore: 15)]
        : const [],
  );
  return GeneralEventOccurrence(
    event: event,
    calendar: GeneralSchedule(
      id: calendarId,
      name: calendarId,
      events: [event],
      isVisible: visible,
    ),
    start: begin,
    end: end,
    sequence: 0,
  );
}

GeneralReminderAcknowledgement _ack(String key, {bool handled = true}) =>
    GeneralReminderAcknowledgement(
      occurrenceKey: key,
      isHandled: handled,
      updatedAtIso: _now.toIso8601String(),
    );

GeneralScheduleData _data(
  List<GeneralEventOccurrence> occurrences,
  List<GeneralReminderAcknowledgement> acknowledgements,
) {
  final calendars = <String, List<GeneralEventOccurrence>>{};
  for (final occurrence in occurrences) {
    (calendars[occurrence.calendar.id] ??= []).add(occurrence);
  }
  return GeneralScheduleData(
    activeScheduleId: occurrences.firstOrNull?.calendar.id ?? 'calendar',
    schedules: [
      for (final group in calendars.values)
        group.first.calendar.copyWith(
          events: [for (final occurrence in group) occurrence.event],
        ),
    ],
    reminderAcknowledgements: acknowledgements,
  );
}

class _ReadCountingList<T> extends ListBase<T> {
  _ReadCountingList(this.values);
  final List<T> values;
  int reads = 0;

  @override
  int get length => values.length;
  @override
  set length(int value) => throw UnsupportedError('Read-only test list');
  @override
  T operator [](int index) {
    reads++;
    return values[index];
  }

  @override
  void operator []=(int index, T value) =>
      throw UnsupportedError('Read-only test list');
}

void main() {
  const service = GeneralOccurrenceService();

  for (final (candidateCount, historyCount) in [(100, 1000), (200, 2000)]) {
    test('reads $historyCount handled records once for $candidateCount cached '
        'candidates', () {
      final current = [
        for (var i = 0; i < candidateCount; i++)
          _occurrence(eventId: 'current-$i'),
      ];
      final history = [
        for (var i = 0; i < historyCount; i++)
          _occurrence(
            eventId: 'history-$i',
            start: _start.subtract(const Duration(days: 10)),
          ),
      ];
      // Every historical key belongs to a real event inside the 30-day
      // acknowledgement retention window, but outside the reminder query.
      final acknowledgements = _ReadCountingList([
        for (final occurrence in history) _ack(occurrence.occurrenceKey),
      ]);
      final data = _data([...current, ...history], acknowledgements);
      final cache = GeneralOccurrenceCache();
      expect(cache.reminderItems(data, now: _now), hasLength(candidateCount));

      acknowledgements.reads = 0;
      expect(cache.reminderItems(data, now: _now), hasLength(candidateCount));
      expect(acknowledgements.reads, historyCount);
    });
  }

  test('does not read handled history for empty or filtered-out batches', () {
    final current = _occurrence();
    final hidden = _occurrence(visible: false);
    final disabled = _occurrence(
      reminderBehavior: GeneralEventReminderBehavior.disabled,
    );
    final inherited = _occurrence(
      reminderBehavior: GeneralEventReminderBehavior.inherit,
    );
    final acknowledgements = _ReadCountingList([_ack('unrelated')]);
    final data = _data([current], acknowledgements);
    final missingText = GeneralOccurrenceQuery(
      startInclusive: _start,
      endExclusive: current.end,
      searchQuery: 'absent-title',
    );
    final missingColor = GeneralOccurrenceQuery(
      startInclusive: _start,
      endExclusive: current.end,
      colorValue: 0xff123456,
    );

    for (final (occurrences, filter) in [
      (<GeneralEventOccurrence>[], null),
      ([hidden], null),
      ([disabled], null),
      ([inherited], null),
      ([current], missingText),
      ([current], missingColor),
    ]) {
      expect(
        service.reminderItemsFromOccurrences(
          data,
          occurrences,
          now: _now,
          occurrenceFilter: filter,
        ),
        isEmpty,
      );
      expect(acknowledgements.reads, 0);
    }

    expect(
      service.reminderItemsFromOccurrences(
        data,
        [hidden, inherited],
        now: _now,
        notificationSettings: const NotificationSettings(
          remindHiddenGeneralCalendars: true,
          generalDefaultMinutesBefore: 15,
        ),
      ),
      hasLength(2),
    );
    expect(acknowledgements.reads, 1);
  });

  test('batch lookup preserves parsed and raw key matching', () {
    final iso = _start.toIso8601String();
    String v2(String calendar, String event, [String? start]) =>
        buildGeneralOccurrenceKey(calendar, event, start ?? iso);
    final cases =
        <
          ({
            String label,
            String calendar,
            String event,
            String key,
            bool handled,
          })
        >[
          (
            label: 'versioned',
            calendar: 'calendar',
            event: 'event',
            key: v2('calendar', 'event'),
            handled: true,
          ),
          (
            label: 'legacy',
            calendar: 'calendar',
            event: 'event',
            key: 'calendar|event|$iso',
            handled: true,
          ),
          (
            label: 'encoded pipes and Unicode',
            calendar: '日历|main',
            event: '待办|1',
            key: v2('日历|main', '待办|1'),
            handled: true,
          ),
          (
            label: 'legacy pipes',
            calendar: 'calendar|main',
            event: 'event|1',
            key: 'calendar|main|event|1|$iso',
            handled: true,
          ),
          (
            label: 'case-insensitive URI escapes',
            calendar: 'calendar|main',
            event: 'event|1',
            key: v2('calendar|main', 'event|1').replaceAll('%7C', '%7c'),
            handled: true,
          ),
          (
            label: 'decode only once',
            calendar: 'calendar%7Cmain',
            event: 'event',
            key: v2('calendar%7Cmain', 'event'),
            handled: true,
          ),
          (
            label: 'double encoding does not become a pipe',
            calendar: 'calendar|main',
            event: 'event',
            key: v2('calendar%7Cmain', 'event'),
            handled: false,
          ),
          (
            label: 'malformed versioned escape uses raw fallback',
            calendar: 'v2',
            event: 'bad%|event',
            key: 'v2|bad%|event|$iso',
            handled: true,
          ),
          (
            label: 'malformed UTF-8 uses raw fallback',
            calendar: 'v2',
            event: '%FF|event',
            key: 'v2|%FF|event|$iso',
            handled: true,
          ),
          (
            label: 'parsed versioned key has no raw fallback',
            calendar: 'v2',
            event: 'calendar|event',
            key: 'v2|calendar|event|$iso',
            handled: false,
          ),
          (
            label: 'parsed versioned ownership wins',
            calendar: 'calendar',
            event: 'event',
            key: 'v2|calendar|event|$iso',
            handled: true,
          ),
          (
            label: 'different calendar',
            calendar: 'calendar',
            event: 'event',
            key: v2('other', 'event'),
            handled: false,
          ),
          (
            label: 'different event',
            calendar: 'calendar',
            event: 'event',
            key: v2('calendar', 'other'),
            handled: false,
          ),
          (
            label: 'IDs stay case-sensitive',
            calendar: 'Calendar',
            event: 'event',
            key: v2('calendar', 'event'),
            handled: false,
          ),
          (
            label: 'missing fractional seconds',
            calendar: 'calendar',
            event: 'event',
            key: v2('calendar', 'event', iso.replaceFirst('.000Z', 'Z')),
            handled: false,
          ),
          (
            label: 'equivalent offset is different ISO text',
            calendar: 'calendar',
            event: 'event',
            key: v2('calendar', 'event', iso.replaceFirst('Z', '+00:00')),
            handled: false,
          ),
          (
            label: 'legacy start text stays exact',
            calendar: 'calendar',
            event: 'event',
            key: 'calendar|event|${iso.replaceFirst('.000Z', 'Z')}',
            handled: false,
          ),
        ];

    for (final sample in cases) {
      final occurrence = _occurrence(
        calendarId: sample.calendar,
        eventId: sample.event,
      );
      final data = _data([occurrence], [_ack(sample.key)]);
      // The existing public matcher is a compatibility reference. Explicit
      // expected values also prevent both query paths drifting together.
      expect(
        service.isReminderHandled(data, occurrence),
        sample.handled,
        reason: sample.label,
      );
      expect(
        service.reminderItemsFromOccurrences(data, [occurrence], now: _now),
        sample.handled ? isEmpty : hasLength(1),
        reason: sample.label,
      );
    }
  });

  test(
    'preserves ambiguous raw joins without merging versioned identities',
    () {
      final left = _occurrence(calendarId: 'a|b', eventId: 'c');
      final right = _occurrence(calendarId: 'a', eventId: 'b|c');
      final candidates = [left, right];
      final raw = _data(candidates, [
        _ack('a|b|c|${_start.toIso8601String()}'),
      ]);
      expect(
        service.reminderItemsFromOccurrences(raw, candidates, now: _now),
        isEmpty,
      );
      final versioned = _data(candidates, [_ack(left.occurrenceKey)]);
      expect(
        service
            .reminderItemsFromOccurrences(versioned, candidates, now: _now)
            .single
            .occurrence,
        same(right),
      );
    },
  );

  test(
    'only handled entries suppress a reminder, regardless of duplicate order',
    () {
      final occurrence = _occurrence();
      final handled = _ack(occurrence.occurrenceKey);
      final unhandled = _ack(occurrence.occurrenceKey, handled: false);
      for (final entries in [
        [unhandled],
        [handled, unhandled],
        [unhandled, handled],
      ]) {
        final items = service.reminderItemsFromOccurrences(
          _data([occurrence], entries),
          [occurrence],
          now: _now,
        );
        expect(items.length, entries.length == 1 ? 1 : 0);
      }
    },
  );

  test('a new batch observes edits to a raw acknowledgement list', () {
    final occurrence = _occurrence();
    final entries = [_ack(occurrence.occurrenceKey, handled: false)];
    final data = _data([occurrence], entries);
    List<GeneralReminderItem> read() =>
        service.reminderItemsFromOccurrences(data, [occurrence], now: _now);
    expect(read(), hasLength(1));
    entries[0] = _ack(occurrence.occurrenceKey);
    expect(read(), isEmpty);
    entries.clear();
    expect(read(), hasLength(1));
  });

  test(
    'dismissal, undo and restored snapshots share live occurrence candidates',
    () {
      const calendarService = GeneralCalendarService();
      final original = _data([_occurrence()], []).normalized();
      final cache = GeneralOccurrenceCache();
      final occurrence = cache
          .reminderItems(original, now: _now)
          .single
          .occurrence;
      final dismissed = calendarService.dismissReminder(
        original,
        occurrence,
        now: _now,
      );
      expect(dismissed.schedules, same(original.schedules));
      expect(cache.reminderItems(dismissed, now: _now), isEmpty);
      final undone = calendarService.restoreReminder(dismissed, occurrence);
      expect(undone.schedules, same(original.schedules));
      expect(
        cache.reminderItems(undone, now: _now).single.occurrence,
        same(occurrence),
      );
      expect(cache.reminderItems(dismissed, now: _now), isEmpty);
      expect(
        cache.reminderItems(original, now: _now).single.occurrence,
        same(occurrence),
      );
    },
  );
}
