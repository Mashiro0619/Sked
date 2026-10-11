import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/general_calendar_service.dart';

const _service = GeneralCalendarService();

GeneralEvent _event({
  String start = '2026-05-20T09:00:00.000',
  String end = '2026-05-20T10:00:00.000',
  GeneralEventRecurrenceRule rule = const GeneralEventRecurrenceRule(
    type: GeneralEventRecurrence.daily,
    unit: GeneralEventRecurrenceUnit.day,
    count: 6,
  ),
  List<String> exceptions = const [],
  bool allDay = false,
  GeneralEventReminderBehavior reminderBehavior =
      GeneralEventReminderBehavior.custom,
}) => GeneralEvent(
  id: 'series',
  calendarId: 'work',
  title: 'Original',
  startDateTimeIso: start,
  endDateTimeIso: end,
  recurrenceRule: rule,
  recurrenceExceptionDateIso: exceptions,
  isAllDay: allDay,
  location: 'Room A',
  notes: 'Keep notes',
  reminderBehavior: reminderBehavior,
  reminders: reminderBehavior == GeneralEventReminderBehavior.custom
      ? const [GeneralEventReminder(minutesBefore: 10)]
      : const [],
  createdAtIso: '2026-01-01T12:00:00.000',
);

GeneralScheduleData _data(
  GeneralEvent event, {
  List<GeneralReminderAcknowledgement> acknowledgements = const [],
}) => GeneralScheduleData(
  activeScheduleId: 'work',
  schedules: [
    GeneralSchedule(id: 'work', name: 'Work', events: [event]),
    const GeneralSchedule(
      id: 'hidden',
      name: 'Hidden',
      events: [],
      isVisible: false,
    ),
  ],
  reminderAcknowledgements: acknowledgements,
);

GeneralEventOccurrence _occurrence(GeneralScheduleData data, String start) {
  final instant = DateTime.parse(start);
  return expandGeneralEventOccurrences(
    calendar: data.schedules.first,
    event: data.schedules.first.events.single,
    startInclusive: instant,
    endExclusive: instant.add(const Duration(microseconds: 1)),
  ).singleWhere((item) => item.start.isAtSameMomentAs(instant));
}

List<GeneralEventOccurrence> _expanded(GeneralScheduleData data) =>
    expandGeneralOccurrences(
      calendars: data.schedules,
      startInclusive: DateTime(2026),
      endExclusive: DateTime(2027),
      onlyVisibleCalendars: false,
    );

GeneralReminderAcknowledgement _handled(String date) =>
    GeneralReminderAcknowledgement(
      occurrenceKey: buildGeneralOccurrenceKey(
        'work',
        'series',
        '${date}T09:00:00.000',
      ),
      updatedAtIso: '${date}T08:59:00.000',
    );

void main() {
  test(
    'single edit excludes exactly one source candidate and creates one event',
    () {
      final original = _event(
        exceptions: const ['2026-05-21'],
        reminderBehavior: GeneralEventReminderBehavior.inherit,
      );
      final data = _data(
        original,
        acknowledgements: [
          _handled('2026-05-20'),
          _handled('2026-05-22'),
          _handled('2026-05-23'),
        ],
      );
      final source = _occurrence(data, '2026-05-22T09:00:00.000');
      final draft = _service.prepareOccurrenceEdit(
        source,
        GeneralEventEditScope.thisOccurrence,
      );
      expect(draft.startDateTimeIso, source.start.toIso8601String());
      expect(draft.recurrenceRule.isRepeating, isFalse);
      final result = _service.editOccurrence(
        data,
        source,
        draft.copyWith(title: 'Changed once', calendarId: 'hidden'),
        GeneralEventEditScope.thisOccurrence,
      );

      expect(result.event.id, isNot(original.id));
      expect(result.event.calendarId, 'hidden');
      expect(result.event.recurrenceRule.isRepeating, isFalse);
      expect(
        result.event.reminderBehavior,
        GeneralEventReminderBehavior.inherit,
      );
      expect(result.data.activeScheduleId, 'work');
      expect(result.data.schedules.last.isVisible, isFalse);
      expect(
        result.data.schedules.first.events.single.recurrenceExceptionDateIso,
        ['2026-05-21', '2026-05-22'],
      );
      expect(
        result.data.reminderAcknowledgements.map((item) => item.occurrenceKey),
        [
          _handled('2026-05-20').occurrenceKey,
          _handled('2026-05-23').occurrenceKey,
        ],
      );
      expect(data.schedules.first.events.single.toJson(), original.toJson());
    },
  );

  test('future split counts excluded candidates and preserves earlier handled state', () {
    final data = _data(
      _event(exceptions: const ['2026-05-21', '2026-05-24']),
      acknowledgements: [
        _handled('2026-05-20'),
        _handled('2026-05-22'),
        _handled('2026-05-23'),
      ],
    );
    final source = _occurrence(data, '2026-05-22T09:00:00.000');
    expect(source.sequence, 2);
    final draft = _service.prepareOccurrenceEdit(
      source,
      GeneralEventEditScope.thisAndFollowing,
    );
    expect(draft.recurrenceRule.count, 4);
    final result = _service.editOccurrence(
      data,
      source,
      draft.copyWith(title: 'Future'),
      GeneralEventEditScope.thisAndFollowing,
    );
    final prefix = result.data.schedules.first.events.singleWhere(
      (event) => event.id == 'series',
    );
    expect(prefix.recurrenceRule.count, 2);
    expect(prefix.recurrenceRule.untilDateIso, '2026-05-21');
    expect(prefix.recurrenceExceptionDateIso, ['2026-05-21']);
    expect(result.event.recurrenceExceptionDateIso, ['2026-05-24']);
    expect(
      _expanded(result.data)
          .map((item) => '${item.start.day}:${item.event.title}'),
      ['20:Original', '22:Future', '23:Future', '25:Future'],
    );
    expect(
      result.data.reminderAcknowledgements.map((item) => item.occurrenceKey),
      [_handled('2026-05-20').occurrenceKey],
    );
  });

  for (final interval in [1, 2]) {
    test('month-end split preserves anchor with interval $interval', () {
      final data = _data(
        _event(
          start: '2026-01-31T09:00:00.000',
          end: '2026-01-31T10:00:00.000',
          rule: GeneralEventRecurrenceRule(
            type: GeneralEventRecurrence.custom,
            unit: GeneralEventRecurrenceUnit.month,
            interval: interval,
            count: 4,
          ),
        ),
      );
      final selected = interval == 1
          ? '2026-02-28T09:00:00.000'
          : '2026-03-31T09:00:00.000';
      final source = _occurrence(data, selected);
      final draft = _service.prepareOccurrenceEdit(
        source,
        GeneralEventEditScope.thisAndFollowing,
      );
      expect(draft.recurrenceRule.monthlyAnchorDay, 31);
      final result = _service.editOccurrence(
        data,
        source,
        draft.copyWith(location: 'Room B'),
        GeneralEventEditScope.thisAndFollowing,
      );
      expect(result.event.recurrenceRule.monthlyAnchorDay, 31);
      expect(
        _expanded(result.data)
            .map((item) => [item.start.month, item.start.day]),
        interval == 1
            ? [
                [1, 31],
                [2, 28],
                [3, 31],
                [4, 30],
              ]
            : [
                [1, 31],
                [3, 31],
                [5, 31],
                [7, 31],
              ],
      );
    });
  }

  test(
    'moving a clipped monthly suffix deliberately chooses its new date anchor',
    () {
      final data = _data(
        _event(
          start: '2026-01-31T09:00:00.000',
          end: '2026-01-31T10:00:00.000',
          rule: const GeneralEventRecurrenceRule(
            type: GeneralEventRecurrence.monthly,
            count: 4,
          ),
        ),
      );
      final source = _occurrence(data, '2026-02-28T09:00:00.000');
      final draft = _service.prepareOccurrenceEdit(
        source,
        GeneralEventEditScope.thisAndFollowing,
      );
      final result = _service.editOccurrence(
        data,
        source,
        draft.copyWith(
          startDateTimeIso: '2026-02-27T09:00:00.000',
          endDateTimeIso: '2026-02-27T10:00:00.000',
        ),
        GeneralEventEditScope.thisAndFollowing,
      );
      expect(result.event.recurrenceRule.monthlyAnchorDay, isNull);
      expect(
        _expanded(result.data)
            .map((item) => [item.start.month, item.start.day]),
        [
          [1, 31],
          [2, 27],
          [3, 27],
          [4, 27],
        ],
      );
    },
  );

  test('series rescheduling remaps exceptions by ordinal and drops out-of-range ones', () {
    final data = _data(
      _event(
        rule: const GeneralEventRecurrenceRule(
          type: GeneralEventRecurrence.weekly,
          count: 5,
        ),
        exceptions: const ['2026-05-27', '2026-06-10'],
      ),
    );
    final source = _occurrence(data, '2026-06-03T09:00:00.000');
    final draft = _service.prepareOccurrenceEdit(
      source,
      GeneralEventEditScope.entireSeries,
    );
    final result = _service.editOccurrence(
      data,
      source,
      draft.copyWith(
        startDateTimeIso: '2026-05-22T09:00:00.000',
        endDateTimeIso: '2026-05-22T10:00:00.000',
        recurrenceRule: draft.recurrenceRule.copyWith(count: 3),
      ),
      GeneralEventEditScope.entireSeries,
    );
    expect(result.event.id, 'series');
    expect(result.event.recurrenceExceptionDateIso, ['2026-05-29']);
    expect(_expanded(result.data).map((item) => item.start.toIso8601String()), [
      '2026-05-22T09:00:00.000',
      '2026-06-05T09:00:00.000',
    ]);
  });

  test('metadata-only whole-series edits preserve handled state', () {
    final data = _data(_event(), acknowledgements: [_handled('2026-05-20')]);
    final source = _occurrence(data, '2026-05-22T09:00:00.000');
    final result = _service.editOccurrence(
      data,
      source,
      source.event.copyWith(location: 'Room B'),
      GeneralEventEditScope.entireSeries,
    );
    expect(
      result.data.reminderAcknowledgements
          .map((item) => item.toJson())
          .toList(),
      data.reminderAcknowledgements.map((item) => item.toJson()).toList(),
    );
    final changedReminder = _service.editOccurrence(
      data,
      source,
      source.event.copyWith(
        reminderBehavior: GeneralEventReminderBehavior.inherit,
      ),
      GeneralEventEditScope.entireSeries,
    );
    expect(changedReminder.data.reminderAcknowledgements, isEmpty);
  });

  test('a multi-day all-day prefix is divided by start, retaining overlapping ends', () {
    final data = _data(
      _event(
        start: '2026-05-20T00:00:00.000',
        end: '2026-05-23T00:00:00.000',
        allDay: true,
      ),
    );
    final source = _occurrence(data, '2026-05-22T00:00:00.000');
    final draft = _service.prepareOccurrenceEdit(
      source,
      GeneralEventEditScope.thisAndFollowing,
    );
    final result = _service.editOccurrence(
      data,
      source,
      draft.copyWith(title: 'Future'),
      GeneralEventEditScope.thisAndFollowing,
    );
    final earlier = _expanded(result.data)
        .where((item) => item.event.id == 'series')
        .toList();
    expect(earlier.map((item) => item.start.day), [20, 21]);
    expect(earlier.last.end.day, 24);
    expect(DateTime.parse(result.event.endDateTimeIso).day, 25);
  });

  test(
    'stale source or removed destination is rejected before changing any data',
    () {
      final data = _data(_event());
      final source = _occurrence(data, '2026-05-22T09:00:00.000');
      final draft = _service.prepareOccurrenceEdit(
        source,
        GeneralEventEditScope.thisOccurrence,
      );
      final newer = _service.saveEvent(
        data,
        source.event.copyWith(location: 'New location'),
      );
      expect(
        () => _service.editOccurrence(
          newer,
          source,
          draft,
          GeneralEventEditScope.thisOccurrence,
        ),
        throwsA(isA<GeneralEventEditConflictException>()),
      );
      expect(
        () => _service.editOccurrence(
          data,
          source,
          draft.copyWith(calendarId: 'missing'),
          GeneralEventEditScope.thisOccurrence,
        ),
        throwsA(isA<GeneralEventEditConflictException>()),
      );
      expect(newer.schedules.first.events.single.location, 'New location');
      expect(newer.schedules.first.events, hasLength(1));
      expect(
        data.schedules.first.events.single.recurrenceExceptionDateIso,
        isEmpty,
      );
    },
  );

  test('first candidate following-edit uses the original series ID', () {
    final data = _data(_event());
    final source = _occurrence(data, '2026-05-20T09:00:00.000');
    final result = _service.editOccurrence(
      data,
      source,
      _service
          .prepareOccurrenceEdit(source, GeneralEventEditScope.thisAndFollowing)
          .copyWith(title: 'All'),
      GeneralEventEditScope.thisAndFollowing,
    );
    expect(result.event.id, 'series');
    expect(result.data.schedules.first.events, hasLength(1));
  });

  test('UNTIL bounds remaining COUNT independently of exceptions', () {
    final data = _data(
      _event(
        rule: const GeneralEventRecurrenceRule(
          type: GeneralEventRecurrence.daily,
          count: 10,
          untilDateIso: '2026-05-24',
        ),
        exceptions: const ['2026-05-21'],
      ),
    );
    final source = _occurrence(data, '2026-05-22T09:00:00.000');
    final result = _service.editOccurrence(
      data,
      source,
      _service.prepareOccurrenceEdit(
        source,
        GeneralEventEditScope.thisAndFollowing,
      ),
      GeneralEventEditScope.thisAndFollowing,
    );
    expect(result.event.recurrenceRule.count, 8);
    expect(result.event.recurrenceRule.untilDateIso, '2026-05-24');
    expect(_expanded(result.data).map((item) => item.start.day), [
      20,
      22,
      23,
      24,
    ]);
    expect(
      boundedGeneralRecurrenceCount(
        DateTime.parse(result.event.startDateTimeIso),
        result.event.recurrenceRule,
      ),
      3,
    );
  });

  test('inherited handled state survives a temporarily disabled default', () {
    final data = _data(
      _event(reminderBehavior: GeneralEventReminderBehavior.inherit),
    );
    final source = _occurrence(data, '2026-05-22T09:00:00.000');
    final handled = _service.dismissReminder(
      data,
      source,
      now: DateTime(2026, 5, 22, 8, 55),
      defaultMinutesBefore: 10,
    );
    expect(handled.reminderAcknowledgements, hasLength(1));
    expect(
      _service
          .pruneReminderAcknowledgements(handled, now: DateTime(2026, 5, 22))
          .reminderAcknowledgements,
      hasLength(1),
    );
    expect(
      _service.dismissReminder(data, source, now: DateTime(2026, 5, 22)),
      same(data),
    );
  });
}
