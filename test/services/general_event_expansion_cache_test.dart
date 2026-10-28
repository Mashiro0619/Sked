import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/general_event.dart';
import 'package:sked/models/general_event_occurrence.dart';
import 'package:sked/models/general_schedule.dart';
import 'package:sked/models/general_schedule_data.dart';
import 'package:sked/services/general_event_expansion_cache.dart';
import 'package:sked/services/general_calendar_service.dart';
import 'package:sked/services/general_occurrence_cache.dart';
import 'package:sked/services/general_occurrence_service.dart';

final _start = DateTime.utc(2026, 1, 1, 9);
final _end = DateTime.utc(2026, 1, 10);
final _query = GeneralOccurrenceQuery(
  startInclusive: _start,
  endExclusive: _end,
);

GeneralEvent _event(String id, {List<String> exceptions = const []}) =>
    GeneralEvent(
      id: id,
      calendarId: 'calendar',
      title: 'Tied title',
      notes: id.codeUnitAt(id.length - 1).isEven ? 'match' : 'other',
      startDateTimeIso: _start.toIso8601String(),
      endDateTimeIso: _start.add(const Duration(hours: 1)).toIso8601String(),
      recurrenceRule: const GeneralEventRecurrenceRule(
        type: GeneralEventRecurrence.daily,
        count: 4,
      ),
      recurrenceExceptionDateIso: exceptions,
    );

GeneralSchedule _calendar(
  List<GeneralEvent> events, {
  String id = 'calendar',
}) => GeneralSchedule(id: id, name: id, events: events);

GeneralScheduleData _data(List<GeneralSchedule> calendars) =>
    GeneralScheduleData(
      activeScheduleId: calendars.first.id,
      schedules: calendars,
    );

List<Object> _snapshot(List<GeneralEventOccurrence> items) => [
  for (final item in items)
    (
      item.occurrenceKey,
      item.end.toIso8601String(),
      item.sequence,
      item.event,
      item.calendar,
    ),
];

List<GeneralEventOccurrence> _expectReference(
  GeneralOccurrenceCache cache,
  GeneralScheduleData data, [
  GeneralOccurrenceQuery? query,
]) {
  final actual = cache.occurrencesForQuery(data, query ?? _query);
  final expected = const GeneralOccurrenceService().occurrencesForQuery(
    data,
    query ?? _query,
  );
  expect(_snapshot(actual), _snapshot(expected));
  return actual;
}

class _Harness {
  _Harness({int maximumEntries = 20000, int maximumValues = 250000}) {
    expansions = GeneralEventExpansionCache(
      maximumEntries: maximumEntries,
      maximumValues: maximumValues,
      expandEvent:
          ({
            required calendar,
            required event,
            required startInclusive,
            required endExclusive,
          }) {
            calls.add(event.id);
            return expandGeneralEventOccurrences(
              calendar: calendar,
              event: event,
              startInclusive: startInclusive,
              endExclusive: endExclusive,
            );
          },
    );
    cache = GeneralOccurrenceCache(eventExpansionCache: expansions);
  }

  final calls = <String>[];
  late final GeneralEventExpansionCache expansions;
  late final GeneralOccurrenceCache cache;
}

void main() {
  test('local parsing and all-day local queries bypass retained geometry', () {
    final local = _event('floating').copyWith(
      startDateTimeIso: '2026-01-01T09:00:00',
      endDateTimeIso: '2026-01-01T10:00:00',
    );
    final mixed = _event('mixed')
        .copyWith(endDateTimeIso: '2026-01-01T10:00:00');
    final until = _event('until').copyWith(
      recurrenceRule: const GeneralEventRecurrenceRule(
        type: GeneralEventRecurrence.daily,
        untilDateIso: '2026-01-03',
      ),
    );
    final allDay = _event('all-day').copyWith(isAllDay: true);
    for (final event in [local, mixed, until, allDay]) {
      final harness = _Harness();
      final data = _data([
        _calendar([event]),
      ]);
      final query = GeneralOccurrenceQuery(
        startInclusive: _start.toLocal(),
        endExclusive: _end,
      );
      _expectReference(harness.cache, data, query);
      _expectReference(harness.cache, _data(List.of(data.schedules)), query);
      expect(harness.calls, [event.id, event.id]);
      expect(harness.expansions.entryCount, 0);
    }
  });

  test('explicit offsets and UTC all-day query arithmetic can be retained', () {
    for (final allDay in [false, true]) {
      final harness = _Harness();
      final event = _event('offset').copyWith(
        startDateTimeIso: '2026-01-01T11:00:00+02:00',
        endDateTimeIso: '2026-01-01T12:00:00+0200',
        isAllDay: allDay,
        recurrenceRule: const GeneralEventRecurrenceRule(
          type: GeneralEventRecurrence.daily,
          untilDateIso: '2026-01-03T00:00:00Z',
        ),
      );
      final data = _data([
        _calendar([event]),
      ]);
      _expectReference(harness.cache, data);
      _expectReference(harness.cache, _data(List.of(data.schedules)));
      expect(harness.calls, [event.id]);
      expect(harness.expansions.entryCount, 1);
    }
  });

  test(
    'the real save command retains expansions for unchanged stored events',
    () {
      final harness = _Harness();
      final initial = _data([
        _calendar([for (var i = 0; i < 30; i++) _event('event-$i')]),
      ]).normalized();
      _expectReference(harness.cache, initial);
      final edited = const GeneralCalendarService().saveEvent(
        initial,
        initial.schedules.first.events.first.copyWith(title: 'Edited title'),
      );
      _expectReference(harness.cache, edited);
      expect(harness.calls, hasLength(31));
    },
  );

  test('one edited event reuses the remaining exact expansions', () {
    final harness = _Harness();
    final calendar = _calendar([
      for (var i = 0; i < 80; i++) _event('event-$i'),
    ]);
    final data = _data([calendar]);
    _expectReference(harness.cache, data);
    expect(harness.calls, hasLength(80));

    final changed = calendar.copyWith(
      events: [
        calendar.events.first.copyWith(title: 'Changed title'),
        ...calendar.events.skip(1),
      ],
    );
    final result = _expectReference(harness.cache, _data([changed]));
    expect(harness.calls, hasLength(81));
    expect(result.every((item) => identical(item.calendar, changed)), isTrue);
    expect(harness.expansions.entryCount, 80);
    harness.cache.clear();
    expect(harness.expansions.entryCount, 0);
    expect(harness.expansions.retainedValueCount, 0);
    _expectReference(harness.cache, _data([changed]));
    expect(harness.calls, hasLength(161));
  });

  test('rebinds name, color and visibility before applying filters', () {
    final harness = _Harness();
    final calendar = _calendar([_event('event')]);
    _expectReference(harness.cache, _data([calendar]));
    var changed = calendar.copyWith(name: 'Archive', colorValue: 0xff123456);
    final filtered = GeneralOccurrenceQuery(
      startInclusive: _start,
      endExclusive: _end,
      searchQuery: 'archive',
      colorValue: 0xff123456,
    );
    expect(
      _expectReference(harness.cache, _data([changed]), filtered),
      hasLength(4),
    );
    changed = changed.copyWith(isVisible: false);
    expect(
      _expectReference(harness.cache, _data([changed]), filtered),
      isEmpty,
    );
    final hidden = GeneralOccurrenceQuery(
      startInclusive: _start,
      endExclusive: _end,
      onlyVisibleCalendars: false,
      searchQuery: 'archive',
      colorValue: 0xff123456,
    );
    expect(
      _expectReference(harness.cache, _data([changed]), hidden),
      hasLength(4),
    );
    expect(harness.calls, ['event']);
  });

  test(
    'ties keep the original input order before global sort and filtering',
    () {
      final harness = _Harness();
      final first = _calendar([for (var i = 0; i < 45; i++) _event('a-$i')]);
      final second = _calendar([
        for (var i = 0; i < 45; i++) _event('b-$i'),
      ], id: 'second');
      final filter = GeneralOccurrenceQuery(
        startInclusive: _start,
        endExclusive: _end,
        searchQuery: 'match',
      );
      _expectReference(harness.cache, _data([first, second]), filter);
      _expectReference(
        harness.cache,
        _data([
          second.copyWith(events: second.events.reversed.toList()),
          first.copyWith(events: first.events.reversed.toList()),
        ]),
        filter,
      );
      expect(harness.calls, hasLength(90));
    },
  );

  test('a shared event object never retains another calendar binding', () {
    final harness = _Harness();
    final event = _event('shared');
    final first = _calendar([event]);
    final second = _calendar([event], id: 'second');
    _expectReference(harness.cache, _data([first, second]));
    _expectReference(harness.cache, _data([second, first]));
    expect(harness.calls, ['shared']);
  });

  test('a copied list retains events but removals release cached geometry', () {
    final harness = _Harness();
    final calendar = _calendar([_event('a'), _event('b'), _event('c')]);
    _expectReference(harness.cache, _data([calendar]));
    _expectReference(harness.cache, _data(List.of([calendar])));
    expect(harness.calls, hasLength(3));
    _expectReference(
      harness.cache,
      _data([calendar.copyWith(events: calendar.events.take(2).toList())]),
    );
    expect(harness.expansions.entryCount, 2);
    _expectReference(harness.cache, _data([calendar]));
    expect(harness.calls, ['a', 'b', 'c', 'c']);
  });

  test(
    'mutable exception lists are checked even with the same event object',
    () {
      final harness = _Harness();
      final exceptions = ['2026-01-02'];
      final calendar = _calendar([_event('event', exceptions: exceptions)]);
      _expectReference(harness.cache, _data([calendar]));
      exceptions[0] = '2026-01-03';
      _expectReference(harness.cache, _data([calendar]));
      exceptions.add('2026-01-04');
      _expectReference(harness.cache, _data([calendar]));
      expect(harness.calls, ['event', 'event', 'event']);
    },
  );

  test('range boundaries retain both instant and UTC/local representation', () {
    final harness = _Harness();
    final data = _data([
      _calendar([_event('event')]),
    ]);
    for (final localStart in [false, true]) {
      for (final localEnd in [false, true]) {
        final query = GeneralOccurrenceQuery(
          startInclusive: localStart ? _start.toLocal() : _start,
          endExclusive: localEnd ? _end.toLocal() : _end,
        );
        _expectReference(harness.cache, data, query);
      }
    }
    expect(harness.calls, hasLength(4));
    _expectReference(harness.cache, _data(List.of(data.schedules)));
    expect(harness.calls, hasLength(4));
  });

  test(
    'recurrences never borrow a containing range across a civil-date skip',
    () {
      final harness = _Harness();
      final start = DateTime(2011, 12, 29, 9);
      final event = _event('date-line').copyWith(
        startDateTimeIso: start.toIso8601String(),
        endDateTimeIso: start.add(const Duration(hours: 1)).toIso8601String(),
        recurrenceRule: const GeneralEventRecurrenceRule(
          type: GeneralEventRecurrence.daily,
          count: 8,
        ),
      );
      final data = _data([
        _calendar([event]),
      ]);
      for (final begin in [DateTime(2011, 12, 29), DateTime(2011, 12, 31)]) {
        _expectReference(
          harness.cache,
          data,
          GeneralOccurrenceQuery(
            startInclusive: begin,
            endExclusive: DateTime(2012, 1, 5),
          ),
        );
      }
      expect(harness.calls, hasLength(2));
    },
  );

  test('LRU bounds empty entries and preserves a promoted hit', () {
    final calls = <String>[];
    final cache = GeneralEventExpansionCache(
      maximumEntries: 2,
      expandEvent:
          ({
            required calendar,
            required event,
            required startInclusive,
            required endExclusive,
          }) {
            calls.add(event.id);
            return [];
          },
    );
    final events = [
      for (final id in ['a', 'b', 'c']) _event(id),
    ];
    final calendar = _calendar(events);
    void read(int index) => cache.expand(
      calendar: calendar,
      event: events[index],
      startInclusive: _start,
      endExclusive: _end,
    );
    read(0);
    read(1);
    read(0);
    read(2);
    read(1);
    expect(calls, ['a', 'b', 'c', 'b']);
    expect(cache.entryCount, 2);
    expect(cache.retainedValueCount, 0);
  });

  test(
    'value budget includes exceptions and oversized results do not evict',
    () {
      final harness = _Harness(maximumValues: 4);
      final small = _event('small');
      final large = _event('large', exceptions: ['invalid', 'also-invalid']);
      final calendar = _calendar([small, large]);
      void read(GeneralEvent event) => harness.expansions.expand(
        calendar: calendar,
        event: event,
        startInclusive: _start,
        endExclusive: _end,
      );
      read(small);
      read(large);
      read(small);
      expect(harness.calls, ['small', 'large']);
      expect(harness.expansions.entryCount, 1);
      expect(harness.expansions.retainedValueCount, 4);
    },
  );

  test('returned lists and failures cannot corrupt retained geometry', () {
    final calls = <String>[];
    final cache = GeneralEventExpansionCache(
      maximumEntries: 1,
      expandEvent:
          ({
            required calendar,
            required event,
            required startInclusive,
            required endExclusive,
          }) {
            calls.add(event.id);
            if (event.id == 'failure') throw StateError('planned failure');
            return expandGeneralEventOccurrences(
              calendar: calendar,
              event: event,
              startInclusive: startInclusive,
              endExclusive: endExclusive,
            );
          },
    );
    final kept = _event('kept');
    final failure = _event('failure');
    final calendar = _calendar([kept, failure]);
    List<GeneralEventOccurrence> read(GeneralEvent event) => cache.expand(
      calendar: calendar,
      event: event,
      startInclusive: _start,
      endExclusive: _end,
    );
    read(kept).clear();
    expect(() => read(failure), throwsStateError);
    final firstHit = read(kept);
    expect(firstHit, hasLength(4));
    firstHit.clear();
    expect(read(kept), hasLength(4));
    expect(calls, ['kept', 'failure']);
    expect(cache.entryCount, 1);
  });

  test('a zero entry budget disables retention without truncating results', () {
    final harness = _Harness(maximumEntries: 0);
    final calendar = _calendar([_event('event')]);
    _expectReference(harness.cache, _data([calendar]));
    _expectReference(harness.cache, _data([calendar]));
    expect(harness.calls, ['event', 'event']);
    expect(harness.expansions.entryCount, 0);
    expect(harness.expansions.retainedValueCount, 0);
    expect(
      () => GeneralEventExpansionCache(maximumValues: -1),
      throwsArgumentError,
    );
  });
}
