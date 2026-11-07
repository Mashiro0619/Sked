import 'package:flutter_test/flutter_test.dart';
import 'package:sked/application/agenda_queries.dart';
import 'package:sked/application/resource_queries.dart';
import 'package:sked/models/timetable_models.dart';

void main() {
  DateTime at(int hour, [int minute = 0]) =>
      DateTime.utc(2026, 10, 5, hour, minute);
  GeneralEvent event(
    String id,
    int start,
    int end, {
    int startMinute = 0,
    int endMinute = 0,
  }) => GeneralEvent(
    id: id,
    calendarId: 'calendar',
    title: id,
    startDateTimeIso: at(start, startMinute).toIso8601String(),
    endDateTimeIso: at(end, endMinute).toIso8601String(),
  );
  ResourceQueries reader(
    List<GeneralEvent> events, {
    GeneralEventOccurrenceExpander? expander,
  }) {
    final data = buildInitialAppData(buildDefaultPeriodTimes()).copyWith(
      enabledWorkspaces: {AppMode.student},
      activeMode: AppMode.student,
      generalMode: GeneralScheduleData(
        activeScheduleId: 'calendar',
        schedules: [
          GeneralSchedule(
            id: 'calendar',
            name: 'Hidden',
            events: events,
            isVisible: false,
          ),
        ],
      ),
    );
    return ResourceQueries(
      snapshot: data,
      datasetGeneration: 'test',
      snapshotRevision: 7,
      expandEvent: expander,
    );
  }

  test(
    'free time merges overlaps and adjacency across hidden disabled data',
    () {
      final agenda = AgendaQueries(
        reader([
          event('a', 10, 11),
          event('b', 10, 12, startMinute: 30),
          event('c', 12, 13),
        ]),
      );
      final free = agenda.freeSlots(start: at(9), end: at(18));
      expect(free.items.map((item) => (item.start, item.end)), [
        (at(9), at(10)),
        (at(13), at(18)),
      ]);
      expect(free.occurrenceCount, 3);
      expect(free.hasMore, isFalse);
      expect(free.snapshotRevision, 7);
      final visible = agenda.freeSlots(
        start: at(9),
        end: at(18),
        includeHidden: false,
      );
      expect(visible.items.single.minutes, 9 * 60);
      expect(
        agenda
            .freeSlots(start: at(9), end: at(18), includeDisabled: false)
            .occurrenceCount,
        0,
      );
    },
  );

  test('conflicts report actual overlaps and do not treat touching intervals as a conflict', () {
    final agenda = AgendaQueries(
      reader([
        event('a', 10, 11),
        event('b', 10, 12, startMinute: 30),
        event('c', 12, 13),
      ]),
    );
    final conflicts = agenda.conflicts(start: at(9), end: at(18));
    expect(conflicts.items, hasLength(1));
    expect(conflicts.items.single.overlap.minutes, 30);
    expect(conflicts.hasMore, isFalse);
  });

  test('occupied intervals are clipped to the requested window', () {
    final agenda = AgendaQueries(
      reader([event('a', 7, 10), event('b', 17, 23)]),
    );
    final free = agenda.freeSlots(start: at(9), end: at(18));
    expect(free.items.map((item) => (item.start, item.end)), [
      (at(10), at(17)),
    ]);
  });

  test(
    'short gaps are excluded and omitted aggregate results are explicit',
    () {
      final agenda = AgendaQueries(
        reader([event('a', 10, 11), event('b', 12, 13), event('c', 14, 15)]),
      );
      final free = agenda.freeSlots(start: at(9), end: at(18), limit: 1);
      expect(free.items, hasLength(1));
      expect(free.hasMore, isTrue);
      expect(
        agenda
            .freeSlots(start: at(9), end: at(18), minimumMinutes: 120)
            .items
            .single
            .minutes,
        180,
      );
      final conflicts = AgendaQueries(
        reader([event('a', 10, 13), event('b', 10, 12), event('c', 11, 14)]),
      ).conflicts(start: at(9), end: at(18), limit: 1);
      expect(conflicts.items, hasLength(1));
      expect(conflicts.hasMore, isTrue);
    },
  );

  test('aggregate candidates expand each selected event only once', () {
    var expansions = 0;
    final resources = reader(
      [event('a', 10, 11), event('b', 12, 13)],
      expander:
          ({
            required calendar,
            required event,
            required startInclusive,
            required endExclusive,
          }) {
            expansions++;
            return GeneralEventOccurrenceRange(
              calendar: calendar,
              event: event,
              startInclusive: startInclusive,
              endExclusive: endExclusive,
            );
          },
    );
    final agenda = AgendaQueries(resources);
    agenda.freeSlots(start: at(9), end: at(18), sourceIds: {'a'});
    expect(expansions, 1);
  });

  test('count does not read oversized fields or inherit a page cursor', () {
    final huge = event('a', 10, 11).copyWith(notes: 'x' * 100000);
    final agenda = AgendaQueries(reader([huge]));
    expect(
      agenda.count(
        ResourceQuery(kind: ResourceKind.event, view: ResourceView.detail),
      ),
      1,
    );
  });

  test('aggregates include more than the former candidate budget', () {
    final agenda = AgendaQueries(
      reader(List.generate(2001, (i) => event('e$i', 10, 11))),
    );
    final result = agenda.freeSlots(start: at(9), end: at(18));
    expect(result.occurrenceCount, 2001);
    expect(result.items, hasLength(2));
    expect(result.hasMore, isFalse);
    expect(
      () => agenda.freeSlots(start: at(9), end: at(18), minimumMinutes: 0),
      throwsA(isA<ResourceQueryException>()),
    );
    expect(
      AgendaQueries(reader([]))
          .conflicts(start: at(9), end: at(18), limit: 101)
          .items,
      isEmpty,
    );
  });
  test('aggregate offsets traverse every free slot and conflict once', () {
    final agenda = AgendaQueries(
      reader([event('a', 10, 11), event('b', 12, 13), event('c', 14, 15)]),
    );
    final slots = <(DateTime, DateTime)>[];
    var offset = 0;
    while (true) {
      final page = agenda.freeSlots(
        start: at(9),
        end: at(18),
        offset: offset,
        limit: 1,
      );
      expect(page.offset, offset);
      slots.addAll(page.items.map((item) => (item.start, item.end)));
      if (!page.hasMore) {
        expect(page.nextOffset, isNull);
        break;
      }
      offset = page.nextOffset!;
    }
    expect(slots, [
      (at(9), at(10)),
      (at(11), at(12)),
      (at(13), at(14)),
      (at(15), at(18)),
    ]);
    final overlapping = AgendaQueries(
      reader([event('a', 10, 13), event('b', 10, 12), event('c', 11, 14)]),
    );
    final pairs = <(String, String)>[];
    offset = 0;
    while (true) {
      final page = overlapping.conflicts(
        start: at(9),
        end: at(18),
        offset: offset,
        limit: 1,
      );
      pairs.addAll(page.items.map((item) => (item.first.id, item.second.id)));
      if (!page.hasMore) {
        expect(page.nextOffset, isNull);
        break;
      }
      offset = page.nextOffset!;
    }
    final full = overlapping.conflicts(start: at(9), end: at(18));
    expect(pairs, full.items.map((item) => (item.first.id, item.second.id)));
    expect(pairs, hasLength(3));
    expect(
      agenda.freeSlots(start: at(9), end: at(18), offset: 10).items,
      isEmpty,
    );
    expect(
      () => agenda.freeSlots(start: at(9), end: at(18), offset: -1),
      throwsA(isA<ResourceQueryException>()),
    );
    expect(
      () => agenda.conflicts(start: at(9), end: at(18), offset: -1),
      throwsA(isA<ResourceQueryException>()),
    );
  });
}
