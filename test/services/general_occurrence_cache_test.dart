import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/general_event.dart';
import 'package:sked/models/general_event_occurrence.dart';
import 'package:sked/models/general_schedule.dart';
import 'package:sked/models/general_schedule_data.dart';
import 'package:sked/models/notification_settings.dart';
import 'package:sked/services/general_occurrence_cache.dart';
import 'package:sked/services/general_occurrence_service.dart';

void main() {
  final base = DateTime.utc(2026, 1, 1);

  GeneralOccurrenceQuery query(
    int minute, {
    String searchQuery = '',
    int? colorValue,
    bool onlyVisibleCalendars = true,
    bool localStart = false,
    bool localEnd = false,
  }) {
    final utcStart = base.add(Duration(minutes: minute));
    final utcEnd = utcStart.add(const Duration(minutes: 1));
    return GeneralOccurrenceQuery(
      startInclusive: localStart
          ? DateTime.fromMicrosecondsSinceEpoch(utcStart.microsecondsSinceEpoch)
          : utcStart,
      endExclusive: localEnd
          ? DateTime.fromMicrosecondsSinceEpoch(utcEnd.microsecondsSinceEpoch)
          : utcEnd,
      searchQuery: searchQuery,
      colorValue: colorValue,
      onlyVisibleCalendars: onlyVisibleCalendars,
    );
  }

  List<GeneralSchedule> schedules() => [
    const GeneralSchedule(id: 'calendar', name: 'Calendar', events: []),
  ];

  GeneralScheduleData dataFor(List<GeneralSchedule> items) {
    return GeneralScheduleData(
      activeScheduleId: items.first.id,
      schedules: items,
    );
  }

  test('normalizes query text while separating semantic filters', () {
    final service = _CountingOccurrenceService();
    final cache = GeneralOccurrenceCache(service: service);
    final data = dataFor(schedules());

    cache.occurrencesForQuery(data, query(0, searchQuery: '  TEAM  '));
    cache.occurrencesForQuery(data, query(0, searchQuery: 'team'));
    cache.occurrencesForQuery(data, query(0, searchQuery: 'TeAm'));
    expect(service.callCount, 1);

    cache.occurrencesForQuery(data, query(0, searchQuery: 'other'));
    cache.occurrencesForQuery(
      data,
      query(0, searchQuery: 'team', colorValue: 0xFF112233),
    );
    cache.occurrencesForQuery(
      data,
      query(0, searchQuery: 'team', onlyVisibleCalendars: false),
    );
    cache.occurrencesForQuery(data, query(1, searchQuery: 'team'));
    expect(service.callCount, 5);
  });

  test('promotes a hit and evicts the least recently used entry', () {
    final service = _CountingOccurrenceService();
    final cache = GeneralOccurrenceCache(service: service);
    final data = dataFor(schedules());

    for (var index = 0; index < 64; index += 1) {
      cache.occurrencesForQuery(data, query(index));
    }
    expect(service.callCount, 64);

    cache.occurrencesForQuery(data, query(0));
    expect(service.callCount, 64);

    cache.occurrencesForQuery(data, query(64));
    expect(service.callCount, 65);

    cache.occurrencesForQuery(data, query(0));
    expect(service.callCount, 65);

    cache.occurrencesForQuery(data, query(1));
    expect(service.callCount, 66);
  });

  test('distinguishes UTC and local representation for both boundaries', () {
    final service = _CountingOccurrenceService();
    final cache = GeneralOccurrenceCache(service: service);
    final data = dataFor(schedules());
    final utc = query(0);
    final local = query(0, localStart: true, localEnd: true);

    expect(
      utc.startInclusive.microsecondsSinceEpoch,
      local.startInclusive.microsecondsSinceEpoch,
    );
    expect(utc.startInclusive.isUtc, isTrue);
    expect(local.startInclusive.isUtc, isFalse);

    cache.occurrencesForQuery(data, utc);
    cache.occurrencesForQuery(data, query(0, localStart: true));
    cache.occurrencesForQuery(data, query(0, localEnd: true));
    cache.occurrencesForQuery(data, local);

    expect(service.callCount, 4);
  });

  test('invalidates only when the schedules list identity changes', () {
    final service = _CountingOccurrenceService();
    final cache = GeneralOccurrenceCache(service: service);
    final sharedSchedules = schedules();

    cache.occurrencesForQuery(dataFor(sharedSchedules), query(0));
    cache.occurrencesForQuery(dataFor(sharedSchedules), query(0));
    expect(service.callCount, 1);

    cache.occurrencesForQuery(dataFor(List.of(sharedSchedules)), query(0));
    expect(service.callCount, 2);
  });

  test('clear invalidates cached queries', () {
    final service = _CountingOccurrenceService();
    final cache = GeneralOccurrenceCache(service: service);
    final data = dataFor(schedules());

    cache.occurrencesForQuery(data, query(0));
    cache.occurrencesForQuery(data, query(0));
    expect(service.callCount, 1);

    cache.clear();
    cache.occurrencesForQuery(data, query(0));
    expect(service.callCount, 2);
  });

  test('navigation and display changes retain warmed occurrence queries', () {
    final service = _CountingOccurrenceService();
    final cache = GeneralOccurrenceCache(service: service);
    final original = dataFor(schedules()).normalized();
    cache.occurrencesForQuery(original, query(0));

    final navigated = original.copyWith(selectedDateIso: '2026-01-02');
    final displayed = navigated.copyWith(
      showWeekends: false,
      showLunarCalendar: false,
    );
    cache.occurrencesForQuery(navigated, query(0));
    cache.occurrencesForQuery(displayed, query(0));
    expect(service.callCount, 1);

    final changed = displayed.copyWith(
      schedules: [displayed.schedules.single.copyWith(isVisible: false)],
    );
    cache.occurrencesForQuery(changed, query(0));
    expect(service.callCount, 2);
  });

  test('does not cache failures or evict a valid entry on failure', () {
    final service = _CountingOccurrenceService();
    final cache = GeneralOccurrenceCache(service: service);
    final data = dataFor(schedules());

    for (var index = 0; index < 64; index += 1) {
      cache.occurrencesForQuery(data, query(index));
    }
    service.failuresRemaining = 1;

    expect(() => cache.occurrencesForQuery(data, query(64)), throwsStateError);
    expect(service.callCount, 65);

    cache.occurrencesForQuery(data, query(0));
    expect(service.callCount, 65);

    cache.occurrencesForQuery(data, query(64));
    cache.occurrencesForQuery(data, query(64));
    expect(service.callCount, 66);
  });

  test('returns a defensive, structurally unmodifiable result', () {
    final start = base.add(const Duration(hours: 1));
    final event = GeneralEvent(
      id: 'event',
      calendarId: 'calendar',
      title: 'Event',
      startDateTimeIso: start.toIso8601String(),
      endDateTimeIso: start.add(const Duration(hours: 1)).toIso8601String(),
    );
    final calendar = GeneralSchedule(
      id: 'calendar',
      name: 'Calendar',
      events: [event],
    );
    final source = [
      GeneralEventOccurrence(
        event: event,
        calendar: calendar,
        start: start,
        end: start.add(const Duration(hours: 1)),
        sequence: 0,
      ),
    ];
    final service = _CountingOccurrenceService(results: source);
    final cache = GeneralOccurrenceCache(service: service);
    final data = dataFor([calendar]);

    final first = cache.occurrencesForQuery(data, query(0));
    expect(() => first.clear(), throwsUnsupportedError);
    source.clear();
    expect(first, hasLength(1));

    final second = cache.occurrencesForQuery(data, query(0));
    expect(identical(first, second), isTrue);
    expect(service.callCount, 1);
  });

  group('reminder candidate caching', () {
    const reference = GeneralOccurrenceService();

    GeneralScheduleData reminderData(List<GeneralEvent> events) => dataFor([
      GeneralSchedule(id: 'calendar', name: 'Calendar', events: events),
    ]);

    test('reuses expansion while statuses follow the exact clock', () {
      final service = _RecordingOccurrenceService();
      final cache = GeneralOccurrenceCache(service: service);
      final noon = base.add(const Duration(hours: 12));
      final data = reminderData([
        _reminderEvent(
          'event',
          noon.add(const Duration(seconds: 30)),
          noon.add(const Duration(seconds: 50)),
        ),
      ]);

      for (final (second, status) in [
        (5, GeneralReminderStatus.upcoming),
        (35, GeneralReminderStatus.inProgress),
        (55, GeneralReminderStatus.overdue),
        // Clock corrections must reuse candidates without retaining a status.
        (15, GeneralReminderStatus.upcoming),
      ]) {
        final now = noon.add(Duration(seconds: second));
        final items = cache.reminderItems(data, now: now);
        expect(items.single.status, status);
        expect(
          _reminderSnapshot(items),
          _reminderSnapshot(reference.reminderItems(data, now: now)),
        );
      }
      expect(service.queries, hasLength(1));
    });

    test('filters expanded candidates at the exact half-open edges', () {
      final service = _RecordingOccurrenceService();
      final cache = GeneralOccurrenceCache(service: service);
      final now = base.add(
        const Duration(hours: 12, seconds: 30, microseconds: 123456),
      );
      final start = now.subtract(const Duration(hours: 24));
      final end = now.add(const Duration(hours: 24));
      const tick = Duration(microseconds: 1);
      final data = reminderData([
        _reminderEvent(
          'old-before',
          start.subtract(const Duration(hours: 1)),
          start.subtract(tick),
        ),
        _reminderEvent(
          'old-at',
          start.subtract(const Duration(hours: 1)),
          start,
        ),
        _reminderEvent(
          'old-inside',
          start.subtract(const Duration(hours: 1)),
          start.add(tick),
        ),
        _reminderEvent(
          'future-inside',
          end.subtract(tick),
          end.add(const Duration(hours: 1)),
        ),
        _reminderEvent('future-at', end, end.add(const Duration(hours: 1))),
        _reminderEvent(
          'future-after',
          end.add(tick),
          end.add(const Duration(hours: 1)),
        ),
        _reminderEvent(
          'spanning',
          start.subtract(const Duration(days: 2)),
          now.add(const Duration(hours: 1)),
        ),
      ]);

      final first = cache.reminderItems(data, now: now);
      expect(first.map((item) => item.occurrence.event.id), [
        'spanning',
        'future-inside',
        'old-inside',
      ]);
      final next = cache.reminderItems(data, now: now.add(tick));
      expect(next.map((item) => item.occurrence.event.id), [
        'spanning',
        'future-inside',
        'future-at',
      ]);
      for (final anchor in [now, now.add(tick), now.subtract(tick)]) {
        expect(
          _reminderSnapshot(cache.reminderItems(data, now: anchor)),
          _reminderSnapshot(reference.reminderItems(data, now: anchor)),
        );
      }
      expect(service.queries, hasLength(1));
    });

    test('retains custom, bounded, and empty window behavior', () {
      final cache = GeneralOccurrenceCache();
      final now = base.add(const Duration(days: 40, seconds: 30));
      final data = reminderData([
        _reminderEvent(
          'current',
          now.subtract(const Duration(seconds: 1)),
          now.add(const Duration(seconds: 1)),
        ),
        _reminderEvent(
          'recent',
          now.subtract(const Duration(minutes: 1)),
          now.subtract(const Duration(microseconds: 1)),
        ),
        _reminderEvent(
          'future',
          now.add(const Duration(microseconds: 1)),
          now.add(const Duration(minutes: 1)),
        ),
        _reminderEvent(
          'limit',
          now.subtract(const Duration(days: 31)),
          now.subtract(const Duration(days: 30)),
        ),
        _reminderEvent(
          'old',
          now.subtract(const Duration(days: 32)),
          now.subtract(const Duration(days: 31)),
        ),
      ]);
      for (final (lookback, horizon) in [
        (Duration.zero, Duration.zero),
        (const Duration(minutes: -1), Duration.zero),
        (Duration.zero, const Duration(microseconds: -1)),
        (const Duration(microseconds: 1), Duration.zero),
        (const Duration(milliseconds: 500), const Duration(milliseconds: 500)),
        (const Duration(days: 60), Duration.zero),
        (const Duration(days: 30), Duration.zero),
        (const Duration(hours: 12), const Duration(minutes: -1)),
      ]) {
        expect(
          _reminderSnapshot(
            cache.reminderItems(
              data,
              now: now,
              overdueWindow: lookback,
              upcomingHorizon: horizon,
            ),
          ),
          _reminderSnapshot(
            reference.reminderItems(
              data,
              now: now,
              overdueWindow: lookback,
              upcomingHorizon: horizon,
            ),
          ),
          reason: '$lookback / $horizon',
        );
      }
    });

    test(
      'refreshes acknowledgements, defaults and filters on cached candidates',
      () {
        final service = _RecordingOccurrenceService();
        final cache = GeneralOccurrenceCache(service: service);
        final now = base.add(const Duration(hours: 12, seconds: 15));
        final event =
            _reminderEvent(
              'inherited',
              now.add(const Duration(minutes: 10)),
              now.add(const Duration(hours: 1)),
            ).copyWith(
              reminderBehavior: GeneralEventReminderBehavior.inherit,
              reminders: const [],
              colorValue: 0xff123456,
            );
        // Loaded domain snapshots are normalized before UI-only updates.
        // Normalizing a raw fixture on its first acknowledgement replaces the
        // schedules identity and correctly invalidates occurrence candidates.
        final data = reminderData([event]).normalized();
        const settings = NotificationSettings(generalDefaultMinutesBefore: 15);
        expect(cache.reminderItems(data, now: now), isEmpty);
        final visible = cache.reminderItems(
          data,
          now: now,
          notificationSettings: settings,
        );
        expect(visible, hasLength(1));
        final acknowledged = data.copyWith(
          reminderAcknowledgements: [
            GeneralReminderAcknowledgement(
              occurrenceKey: visible.single.occurrence.occurrenceKey,
              updatedAtIso: now.toIso8601String(),
            ),
          ],
        );
        expect(identical(data.schedules, acknowledged.schedules), isTrue);
        expect(
          cache.reminderItems(
            acknowledged,
            now: now,
            notificationSettings: settings,
          ),
          isEmpty,
        );
        expect(
          cache.reminderItems(data, now: now, notificationSettings: settings),
          hasLength(1),
        );
        expect(
          cache.reminderItems(
            data,
            now: now,
            notificationSettings: settings,
            occurrenceFilter: query(0, searchQuery: 'missing'),
          ),
          isEmpty,
        );
        expect(
          cache.reminderItems(
            data,
            now: now,
            notificationSettings: settings,
            occurrenceFilter: query(
              0,
              searchQuery: 'inherited',
              colorValue: 0xff123456,
            ),
          ),
          hasLength(1),
        );
        expect(
          cache.reminderItems(
            data,
            now: now,
            notificationSettings: settings,
            occurrenceFilter: query(0, colorValue: 0xff654321),
          ),
          isEmpty,
        );
        expect(service.queries, hasLength(1));
      },
    );

    test('separates visibility policy and invalidates changed schedules', () {
      final service = _RecordingOccurrenceService();
      final cache = GeneralOccurrenceCache(service: service);
      final now = base.add(const Duration(hours: 12, seconds: 15));
      final event = _reminderEvent(
        'visible',
        now.subtract(const Duration(minutes: 1)),
        now.add(const Duration(minutes: 1)),
      );
      final data = dataFor([
        GeneralSchedule(id: 'calendar', name: 'Visible', events: [event]),
        GeneralSchedule(
          id: 'hidden',
          name: 'Hidden',
          isVisible: false,
          events: [event.copyWith(id: 'hidden', calendarId: 'hidden')],
        ),
      ]);
      expect(cache.reminderItems(data, now: now), hasLength(1));
      expect(
        cache.reminderItems(
          data,
          now: now,
          notificationSettings: const NotificationSettings(
            remindHiddenGeneralCalendars: true,
          ),
        ),
        hasLength(2),
      );
      expect(cache.reminderItems(data, now: now), hasLength(1));
      expect(service.queries, hasLength(2));
      final changed = data.copyWith(
        schedules: [
          data.schedules.first,
          data.schedules.last.copyWith(isVisible: true),
        ],
      );
      expect(cache.reminderItems(changed, now: now), hasLength(2));
      expect(service.queries, hasLength(3));
      cache.clear();
      expect(cache.reminderItems(changed, now: now), hasLength(2));
      expect(service.queries, hasLength(4));
    });

    test(
      'separates UTC/local representations and reuses prior clock buckets',
      () {
        final service = _RecordingOccurrenceService();
        final cache = GeneralOccurrenceCache(service: service);
        final now = base.add(const Duration(hours: 12, seconds: 15));
        final data = reminderData([
          _reminderEvent(
            'event',
            now.subtract(const Duration(hours: 1)),
            now.add(const Duration(hours: 1)),
          ),
        ]);
        for (final anchor in [
          now,
          now.toLocal(),
          now.add(const Duration(minutes: 2)),
          now,
          now.toLocal(),
        ]) {
          expect(
            _reminderSnapshot(cache.reminderItems(data, now: anchor)),
            _reminderSnapshot(reference.reminderItems(data, now: anchor)),
          );
        }
        expect(service.queries, hasLength(3));
        expect(service.queries.map((item) => item.startInclusive.isUtc), [
          true,
          false,
          true,
        ]);
        expect(service.queries.map((item) => item.endExclusive.isUtc), [
          true,
          false,
          true,
        ]);
      },
    );

    test('reminder buckets share bounded LRU eviction with exact queries', () {
      final service = _RecordingOccurrenceService();
      final cache = GeneralOccurrenceCache(service: service);
      final data = dataFor(schedules());
      final now = base.add(const Duration(seconds: 15));
      for (var minute = 0; minute < 64; minute++) {
        cache.reminderItems(data, now: now.add(Duration(minutes: minute)));
      }
      cache.reminderItems(data, now: now.add(const Duration(seconds: 1)));
      expect(service.queries, hasLength(64));
      cache.occurrencesForQuery(data, query(1000));
      cache.reminderItems(data, now: now);
      expect(service.queries, hasLength(65));
      cache.reminderItems(data, now: now.add(const Duration(minutes: 1)));
      expect(service.queries, hasLength(66));
    });

    test('preserves recurring and all-day candidates around midnight', () {
      final cache = GeneralOccurrenceCache();
      final start = DateTime(2026, 1, 1);
      final data = reminderData([
        _reminderEvent('all-day', start, DateTime(2026, 1, 3)).copyWith(
          isAllDay: true,
          recurrenceRule: const GeneralEventRecurrenceRule(
            type: GeneralEventRecurrence.daily,
            count: 4,
          ),
          recurrenceExceptionDateIso: ['2026-01-02'],
        ),
        _reminderEvent(
          'utc',
          base.add(const Duration(hours: 23, minutes: 50)),
          base.add(const Duration(days: 1, minutes: 10)),
        ).copyWith(
          recurrenceRule: const GeneralEventRecurrenceRule(
            type: GeneralEventRecurrence.daily,
            count: 4,
          ),
        ),
      ]);
      for (final day in [2, 3, 5, 6]) {
        final midnight = DateTime(2026, 1, day);
        for (final anchor in [
          midnight.subtract(const Duration(microseconds: 1)),
          midnight,
          midnight.add(const Duration(microseconds: 1)),
          midnight.toUtc(),
        ]) {
          expect(
            _reminderSnapshot(cache.reminderItems(data, now: anchor)),
            _reminderSnapshot(reference.reminderItems(data, now: anchor)),
          );
        }
      }
    });

    test('rounds candidate bounds outward before the Unix epoch', () {
      final service = _RecordingOccurrenceService();
      final cache = GeneralOccurrenceCache(service: service);
      final now = DateTime.utc(1969, 12, 31, 23, 59, 30, 500);
      final data = reminderData([
        _reminderEvent(
          'old',
          now.subtract(const Duration(minutes: 2)),
          now.subtract(const Duration(seconds: 50)),
        ),
      ]);
      final items = cache.reminderItems(
        data,
        now: now,
        overdueWindow: const Duration(minutes: 1),
        upcomingHorizon: const Duration(minutes: 1),
      );
      expect(items, hasLength(1));
      expect(
        service.queries.single.startInclusive,
        DateTime.utc(1969, 12, 31, 23, 58),
      );
      expect(
        service.queries.single.endExclusive,
        DateTime.utc(1970, 1, 1, 0, 1),
      );
    });
  });
}

GeneralEvent _reminderEvent(String id, DateTime start, DateTime end) =>
    GeneralEvent(
      id: id,
      calendarId: 'calendar',
      title: id,
      startDateTimeIso: start.toIso8601String(),
      endDateTimeIso: end.toIso8601String(),
      reminders: const [GeneralEventReminder(minutesBefore: 2880)],
    );

List<(String, String, int, GeneralReminderStatus)> _reminderSnapshot(
  List<GeneralReminderItem> items,
) => [
  for (final item in items)
    (
      item.occurrence.occurrenceKey,
      item.occurrence.end.toIso8601String(),
      item.occurrence.sequence,
      item.status,
    ),
];

class _RecordingOccurrenceService extends GeneralOccurrenceService {
  final queries = <GeneralOccurrenceQuery>[];

  @override
  List<GeneralEventOccurrence> occurrencesForQuery(
    GeneralScheduleData general,
    GeneralOccurrenceQuery query,
  ) {
    queries.add(query);
    return super.occurrencesForQuery(general, query);
  }
}

class _CountingOccurrenceService extends GeneralOccurrenceService {
  _CountingOccurrenceService({List<GeneralEventOccurrence>? results})
    : results = results ?? <GeneralEventOccurrence>[];

  final List<GeneralEventOccurrence> results;
  int callCount = 0;
  int failuresRemaining = 0;

  @override
  List<GeneralEventOccurrence> occurrencesForQuery(
    GeneralScheduleData general,
    GeneralOccurrenceQuery query,
  ) {
    callCount += 1;
    if (failuresRemaining > 0) {
      failuresRemaining -= 1;
      throw StateError('planned failure');
    }
    return results;
  }
}
