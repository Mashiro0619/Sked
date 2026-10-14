import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/widgets/general_timeline_projection.dart';

GeneralEventOccurrence _event(
  String id,
  DateTime start,
  DateTime end, {
  bool allDay = false,
}) => GeneralEventOccurrence(
  event: GeneralEvent(
    id: id,
    calendarId: 'calendar',
    title: 'Event',
    startDateTimeIso: start.toIso8601String(),
    endDateTimeIso: end.toIso8601String(),
    isAllDay: allDay,
  ),
  calendar: const GeneralSchedule(id: 'calendar', name: 'Calendar', events: []),
  start: start,
  end: end,
  sequence: 0,
);

class _ObservedOccurrences extends ListBase<GeneralEventOccurrence> {
  _ObservedOccurrences(List<GeneralEventOccurrence> values)
    : _values = List.unmodifiable(values);

  final List<GeneralEventOccurrence> _values;
  bool forbidReads = false;

  @override
  int get length => _values.length;

  @override
  set length(int value) => throw UnsupportedError('Read-only query');

  @override
  GeneralEventOccurrence operator [](int index) {
    if (forbidReads) throw StateError('A cached query was enumerated again');
    return _values[index];
  }

  @override
  void operator []=(int index, GeneralEventOccurrence value) =>
      throw UnsupportedError('Read-only query');
}

void main() {
  final first = DateTime(2026, 9, 8);
  final second = DateTime(2026, 9, 9);

  test(
    'unchanged query and dates reuse groups without reading occurrences',
    () {
      final cache = GeneralTimelineProjectionCache();
      final source = _ObservedOccurrences([
        _event('one', DateTime(2026, 9, 8, 9), DateTime(2026, 9, 8, 10)),
        _event('two', DateTime(2026, 9, 8, 9, 30), DateTime(2026, 9, 8, 11)),
      ]);
      final initial = cache.project(
        occurrences: source,
        days: [first],
        startHour: 6,
        endHour: 23,
      );
      source.forbidReads = true;
      final repeated = cache.project(
        occurrences: source,
        days: [DateTime(2026, 9, 8)],
        startHour: 6,
        endHour: 23,
      );
      expect(repeated, same(initial));
      expect(repeated.timedFor(first), same(initial.timedFor(first)));
      expect(repeated.allDay, same(initial.allDay));
    },
  );

  test('date, hour and source changes update only the matching projection', () {
    final cache = GeneralTimelineProjectionCache();
    final source = List<GeneralEventOccurrence>.unmodifiable([
      _event('timed', DateTime(2026, 9, 8, 9), DateTime(2026, 9, 8, 11)),
      _event('all', first, second, allDay: true),
    ]);
    final initial = cache.project(
      occurrences: source,
      days: [first],
      startHour: 6,
      endHour: 23,
    );
    final clipped = cache.project(
      occurrences: source,
      days: [first],
      startHour: 10,
      endHour: 17,
    );
    expect(clipped.timedFor(first).single.events.single.span.start, 600);
    expect(clipped.allDay, same(initial.allDay));
    expect(clipped.days, same(initial.days));
    expect(initial.timedFor(first).single.events.single.span.start, 540);
    final moved = cache.project(
      occurrences: source,
      days: [second],
      startHour: 10,
      endHour: 17,
    );
    expect(moved.timedFor(second), isEmpty);
    expect(moved.allDay.segments, isEmpty);
    final cleared = cache.project(
      occurrences: const [],
      days: [first],
      startHour: 6,
      endHour: 23,
    );
    expect(cleared.timedFor(first), isEmpty);
    expect(cleared.allDay.segments, isEmpty);
  });

  test(
    'UTC timed events use local dates while all-day events keep declared dates',
    () {
      final localStart = DateTime(2026, 9, 8, 9);
      final snapshot = GeneralTimelineProjectionCache().project(
        occurrences: [
          _event(
            'utc',
            localStart.toUtc(),
            localStart.add(const Duration(hours: 1)).toUtc(),
          ),
          _event(
            'all',
            DateTime.utc(2026, 9, 8),
            DateTime.utc(2026, 9, 10),
            allDay: true,
          ),
        ],
        days: [first, second],
        startHour: 6,
        endHour: 23,
      );
      expect(
        snapshot.timedFor(first).single.events.single.span.value.event.id,
        'utc',
      );
      expect(snapshot.timedFor(first).single.events.single.span.start, 540);
      expect(snapshot.timedFor(second), isEmpty);
      expect(snapshot.allDay.segments.single.startIndex, 0);
      expect(snapshot.allDay.segments.single.endIndex, 1);
    },
  );

  test(
    'multi-day timed events keep all-day lanes and exclude midnight end dates',
    () {
      final snapshot = GeneralTimelineProjectionCache().project(
        occurrences: [
          _event(
            'overnight',
            DateTime(2026, 9, 8, 23),
            DateTime(2026, 9, 9, 1),
          ),
          _event('midnight', DateTime(2026, 9, 8, 22), second),
        ],
        days: [first, second],
        startHour: 0,
        endHour: 24,
      );
      expect(snapshot.timedFor(first), isEmpty);
      expect(snapshot.timedFor(second), isEmpty);
      final segments = {
        for (final item in snapshot.allDay.segments)
          item.occurrence.event.id: item,
      };
      expect(segments['overnight']!.endIndex, 1);
      expect(segments['midnight']!.endIndex, 0);
      expect(
        snapshot.allDay.collapsedGroups.last.occurrences.map(
          (item) => item.event.id,
        ),
        ['overnight'],
      );
    },
  );

  test(
    'all-day lanes preserve spanning priority, hidden rows and weekday gaps',
    () {
      final friday = DateTime(2026, 9, 11);
      final monday = DateTime(2026, 9, 14);
      final snapshot = GeneralTimelineProjectionCache().project(
        occurrences: [
          _event('short', friday, DateTime(2026, 9, 12), allDay: true),
          _event('long', friday, DateTime(2026, 9, 15), allDay: true),
          _event('hidden', friday, DateTime(2026, 9, 12), allDay: true),
          _event('next', monday, DateTime(2026, 9, 15), allDay: true),
        ],
        days: [friday, monday],
        startHour: 6,
        endHour: 23,
      );
      expect(snapshot.allDay.segments.first.occurrence.event.id, 'long');
      expect(snapshot.allDay.segments.first.endIndex, 1);
      expect(snapshot.allDay.laneCount, 3);
      expect(snapshot.allDay.visibleLaneCount, 2);
      expect(snapshot.allDay.hiddenCount, 1);
      expect(
        snapshot.allDay.collapsedGroups.last.occurrences.map(
          (item) => item.event.id,
        ),
        ['long', 'next'],
      );
    },
  );

  test(
    'timed overlap columns preserve adjacent events and equal-name records',
    () {
      final snapshot = GeneralTimelineProjectionCache().project(
        occurrences: [
          _event('one', DateTime(2026, 9, 8, 9), DateTime(2026, 9, 8, 11)),
          _event('two', DateTime(2026, 9, 8, 10), DateTime(2026, 9, 8, 12)),
          _event('three', DateTime(2026, 9, 8, 12), DateTime(2026, 9, 8, 13)),
        ],
        days: [first],
        startHour: 6,
        endHour: 23,
      );
      final groups = snapshot.timedFor(first);
      expect(groups.map((group) => group.columnCount), [2, 1]);
      expect(groups.first.events.map((item) => item.span.value.event.id), [
        'one',
        'two',
      ]);
      expect(groups.first.events.map((item) => item.column), [0, 1]);
    },
  );

  test(
    'hour limits clip timed intervals and reject invalid or outside events',
    () {
      final snapshot = GeneralTimelineProjectionCache().project(
        occurrences: [
          _event('before', DateTime(2026, 9, 8, 8), DateTime(2026, 9, 8, 9)),
          _event('start', DateTime(2026, 9, 8, 9), DateTime(2026, 9, 8, 11)),
          _event('end', DateTime(2026, 9, 8, 16, 30), DateTime(2026, 9, 8, 18)),
          _event('invalid', DateTime(2026, 9, 8, 12), DateTime(2026, 9, 8, 11)),
        ],
        days: [first],
        startHour: 10,
        endHour: 17,
      );
      final spans = snapshot
          .timedFor(first)
          .expand((group) => group.events)
          .map((item) => item.span)
          .toList();
      expect(spans.map((span) => span.value.event.id), ['start', 'end']);
      expect(spans.map((span) => (span.start, span.end)), [
        (600, 660),
        (990, 1020),
      ]);
      expect(snapshot.allDay.segments, isEmpty);
    },
  );

  test('all projection collections are immutable and empty dates are safe', () {
    final cache = GeneralTimelineProjectionCache();
    final snapshot = cache.project(
      occurrences: [
        _event('timed', DateTime(2026, 9, 8, 9), DateTime(2026, 9, 8, 10)),
        _event('all', first, second, allDay: true),
      ],
      days: [first],
      startHour: 6,
      endHour: 23,
    );
    expect(snapshot.days.clear, throwsUnsupportedError);
    expect(snapshot.timedByDate.clear, throwsUnsupportedError);
    expect(snapshot.timedFor(first).clear, throwsUnsupportedError);
    expect(
      snapshot.timedFor(first).single.events.clear,
      throwsUnsupportedError,
    );
    expect(snapshot.allDay.segments.clear, throwsUnsupportedError);
    expect(snapshot.allDay.visibleSegments.clear, throwsUnsupportedError);
    expect(snapshot.allDay.collapsedGroups.clear, throwsUnsupportedError);
    expect(
      snapshot.allDay.collapsedGroups.single.occurrences.clear,
      throwsUnsupportedError,
    );
    final empty = cache.project(
      occurrences: const [],
      days: const [],
      startHour: 6,
      endHour: 23,
    );
    expect(empty.days, isEmpty);
    expect(empty.allDay.segments, isEmpty);
    expect(empty.timedFor(first), isEmpty);
  });
}
