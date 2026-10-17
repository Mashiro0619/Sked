import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/widgets/general_list_projection.dart';

GeneralEventOccurrence _occurrence(
  String id,
  DateTime start, {
  DateTime? end,
  bool allDay = false,
}) {
  final finish = end ?? start.add(const Duration(hours: 1));
  return GeneralEventOccurrence(
    event: GeneralEvent(
      id: id,
      title: id,
      calendarId: 'calendar',
      startDateTimeIso: start.toIso8601String(),
      endDateTimeIso: finish.toIso8601String(),
      isAllDay: allDay,
    ),
    calendar: const GeneralSchedule(
      id: 'calendar',
      name: 'Calendar',
      events: [],
    ),
    start: start,
    end: finish,
    sequence: 0,
  );
}

void main() {
  test('unchanged query results retain the complete grouped snapshot', () {
    final cache = GeneralListProjectionCache();
    final occurrences = List<GeneralEventOccurrence>.unmodifiable([
      _occurrence('first', DateTime(2026, 9, 8, 10)),
      _occurrence('second', DateTime(2026, 9, 8, 11)),
    ]);
    final first = cache.project(occurrences);
    final repeated = cache.project(occurrences);
    expect(repeated, same(first));
    expect(repeated.days.single.date, same(first.days.single.date));
    expect(
      repeated.days.single.occurrences,
      same(first.days.single.occurrences),
    );
  });

  test(
    'replaced query results refresh groups without mutating prior snapshots',
    () {
      final cache = GeneralListProjectionCache();
      final first = cache.project([
        _occurrence('original', DateTime(2026, 9, 8, 10)),
      ]);
      final changed = cache.project([
        _occurrence('updated', DateTime(2026, 9, 9, 11)),
      ]);
      expect(changed, isNot(same(first)));
      expect(changed.days.single.date, DateTime(2026, 9, 9));
      expect(changed.days.single.occurrences.single.event.title, 'updated');
      expect(first.days.single.occurrences.single.event.title, 'original');
      expect(cache.project(const []).isEmpty, isTrue);
    },
  );

  test('group and event order follow the query without an additional sort', () {
    final snapshot = GeneralListProjectionCache().project([
      _occurrence('later first', DateTime(2027, 1, 1, 12)),
      _occurrence('previous year', DateTime(2026, 12, 31, 9)),
      _occurrence('earlier second', DateTime(2027, 1, 1, 8)),
    ]);
    expect(snapshot.days.map((day) => day.date), [
      DateTime(2027, 1, 1),
      DateTime(2026, 12, 31),
    ]);
    expect(snapshot.days.first.occurrences.map((item) => item.event.id), [
      'later first',
      'earlier second',
    ]);
  });

  test(
    'UTC all-day dates and local timed dates group only at their starts',
    () {
      final local = DateTime(2026, 9, 8, 23);
      final snapshot = GeneralListProjectionCache().project([
        _occurrence(
          'all-day',
          DateTime.utc(2026, 9, 8),
          end: DateTime.utc(2026, 9, 10),
          allDay: true,
        ),
        _occurrence(
          'UTC timed',
          local.toUtc(),
          end: DateTime(2026, 9, 9, 1).toUtc(),
        ),
        _occurrence('next day', DateTime(2026, 9, 9, 9)),
      ]);
      expect(snapshot.days.map((day) => day.date), [
        DateTime(2026, 9, 8),
        DateTime(2026, 9, 9),
      ]);
      expect(snapshot.days.first.occurrences.map((item) => item.event.id), [
        'all-day',
        'UTC timed',
      ]);
      expect(snapshot.days.last.occurrences.single.event.id, 'next day');
    },
  );

  test('renderers cannot mutate a snapshot or one of its date groups', () {
    final cache = GeneralListProjectionCache();
    final source = List<GeneralEventOccurrence>.unmodifiable([
      _occurrence('event', DateTime(2026, 9, 8, 10)),
    ]);
    final snapshot = cache.project(source);
    expect(() => snapshot.days.clear(), throwsUnsupportedError);
    expect(
      () => snapshot.days.single.occurrences.clear(),
      throwsUnsupportedError,
    );
    expect(cache.project(source).days.single.occurrences, hasLength(1));
    expect(() => cache.project(const []).days.clear(), throwsUnsupportedError);
  });

  test('row lookup interleaves headers without counting them as events', () {
    final first = _occurrence('first', DateTime(2026, 9, 8, 10));
    final second = _occurrence('second', DateTime(2026, 9, 8, 11));
    final third = _occurrence('third', DateTime(2026, 9, 9, 9));
    final fourth = _occurrence('fourth', DateTime(2026, 9, 10, 9));
    final snapshot = GeneralListProjectionCache().project([
      first,
      second,
      third,
      fourth,
    ]);
    expect(snapshot.rowCount, 7);
    expect(snapshot.occurrenceCount, 4);
    final rows = List.generate(snapshot.rowCount, snapshot.rowAt);
    expect(rows.map((row) => row.occurrence), [
      null,
      same(first),
      same(second),
      null,
      same(third),
      null,
      same(fourth),
    ]);
    expect(rows.map((row) => row.semanticIndex), [
      null,
      0,
      1,
      null,
      2,
      null,
      3,
    ]);
    expect(rows.map((row) => row.date), [
      DateTime(2026, 9, 8),
      DateTime(2026, 9, 8),
      DateTime(2026, 9, 8),
      DateTime(2026, 9, 9),
      DateTime(2026, 9, 9),
      DateTime(2026, 9, 10),
      DateTime(2026, 9, 10),
    ]);
    for (var index = 0; index < rows.length; index++) {
      expect(snapshot.rowIndexOf(rows[index].key), index);
    }
    expect(() => snapshot.rowAt(-1), throwsRangeError);
    expect(() => snapshot.rowAt(snapshot.rowCount), throwsRangeError);
    final empty = GeneralListProjectionCache().project(const []);
    expect(empty.rowCount, 0);
    expect(empty.occurrenceCount, 0);
    expect(() => empty.rowAt(0), throwsRangeError);
  });

  test(
    'mounted row keys survive insertions and detect removed occurrences',
    () {
      final cache = GeneralListProjectionCache();
      final original = cache.project([
        _occurrence('kept', DateTime(2026, 9, 8, 10)),
        _occurrence('removed', DateTime(2026, 9, 8, 11)),
        _occurrence('removed-day', DateTime(2026, 9, 9, 11)),
      ]);
      final updated = cache.project([
        _occurrence('inserted', DateTime(2026, 9, 8, 9)),
        _occurrence('kept', DateTime(2026, 9, 8, 10)),
        _occurrence('kept', DateTime(2026, 9, 10, 10)),
      ]);
      expect(updated.rowIndexOf(original.rowAt(0).key), 0);
      expect(updated.rowIndexOf(original.rowAt(1).key), 2);
      expect(updated.rowIndexOf(original.rowAt(2).key), isNull);
      expect(updated.rowIndexOf(original.rowAt(3).key), isNull);
      expect(updated.rowIndexOf(original.rowAt(4).key), isNull);
      expect(original.rowAt(1).occurrence!.event.id, 'kept');
    },
  );
}
