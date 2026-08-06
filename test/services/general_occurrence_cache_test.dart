import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/general_event.dart';
import 'package:sked/models/general_event_occurrence.dart';
import 'package:sked/models/general_schedule.dart';
import 'package:sked/models/general_schedule_data.dart';
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
