import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/general_calendar_service.dart';

const _service = GeneralCalendarService();

GeneralEvent _event({
  String start = '2011-12-22T09:00:00.000',
  GeneralEventRecurrenceRule rule = const GeneralEventRecurrenceRule(
    type: GeneralEventRecurrence.daily,
    count: 9,
  ),
  List<String> exceptions = const ['2011-12-31'],
}) => GeneralEvent(
  id: 'series',
  calendarId: 'work',
  title: 'Historical repeat',
  startDateTimeIso: start,
  endDateTimeIso: DateTime.parse(start)
      .add(const Duration(hours: 1))
      .toIso8601String(),
  recurrenceRule: rule,
  recurrenceExceptionDateIso: exceptions,
);

GeneralSchedule _calendar(GeneralEvent event) =>
    GeneralSchedule(id: 'work', name: 'Work', events: [event]);

List<GeneralEventOccurrence> _expanded(
  GeneralEvent event,
  DateTime first,
  DateTime end,
) => expandGeneralEventOccurrences(
  calendar: _calendar(event),
  event: event,
  startInclusive: first,
  endExclusive: end,
);

GeneralEvent _edit(
  GeneralEvent source, {
  required DateTime start,
  required GeneralEventRecurrenceRule rule,
  String? title,
}) {
  final sourceStart = DateTime.parse(source.startDateTimeIso);
  final selected = _expanded(
    source,
    sourceStart,
    sourceStart.add(const Duration(days: 1)),
  ).first;
  return _service
      .editOccurrence(
        GeneralScheduleData(
          activeScheduleId: 'work',
          schedules: [_calendar(source)],
        ),
        selected,
        source.copyWith(
          title: title,
          startDateTimeIso: start.toIso8601String(),
          endDateTimeIso: start.add(const Duration(hours: 1)).toIso8601String(),
          recurrenceRule: rule,
        ),
        GeneralEventEditScope.entireSeries,
      )
      .event;
}

void _expectLastDateStillSkipped(GeneralEvent event) {
  expect(
    {
      'exclusions': event.recurrenceExceptionDateIso,
      'visibleOnSkippedDate': _expanded(
        event,
        DateTime(2011, 12, 31),
        DateTime(2012, 1, 1),
      ).map((item) => item.exceptionDateIso).toList(),
    },
    {
      'exclusions': ['2011-12-31'],
      'visibleOnSkippedDate': <String>[],
    },
  );
}

void main() {
  if (Platform.environment['SKED_DST_TEST_ZONE'] != 'pacific-apia') {
    test(
      'exception mapping across a skipped civil date runs in native Apia',
      () {},
      skip: 'Run with TZ=Pacific/Apia and SKED_DST_TEST_ZONE=pacific-apia.',
    );
    return;
  }

  test('the native timezone really skips December 30, 2011', () {
    expect(Platform.environment['TZ'], 'Pacific/Apia');
    expect(
      DateTime(2011, 12, 29, 9).timeZoneOffset,
      const Duration(hours: -10),
    );
    final skipped = DateTime(2011, 12, 30, 9);
    expect([skipped.year, skipped.month, skipped.day], [2011, 12, 31]);
    expect(skipped.timeZoneOffset, const Duration(hours: 14));
  });

  test(
    'the last counted source candidate remains skipped after a step change',
    () {
      final source = _event();
      final candidates = _expanded(
        source.copyWith(recurrenceExceptionDateIso: const []),
        DateTime(2011, 12, 22),
        DateTime(2012, 1, 10),
      );
      expect(candidates, hasLength(9));
      expect(candidates.last.sequence, 8);
      expect(candidates.last.exceptionDateIso, '2011-12-31');
      expect(
        _expanded(source, DateTime(2011, 12, 22), DateTime(2012, 1, 10)),
        hasLength(8),
      );
      final edited = _edit(
        source,
        start: DateTime(2011, 12, 23, 9),
        rule: const GeneralEventRecurrenceRule(
          type: GeneralEventRecurrence.custom,
          unit: GeneralEventRecurrenceUnit.day,
          interval: 2,
          count: 5,
        ),
      );
      _expectLastDateStillSkipped(edited);
    },
  );

  test(
    'the last counted destination candidate accepts its original exclusion',
    () {
      final source = _event(
        start: '2011-12-24T09:00:00.000',
        rule: const GeneralEventRecurrenceRule(
          type: GeneralEventRecurrence.weekly,
          count: 3,
        ),
      );
      final edited = _edit(
        source,
        start: DateTime(2011, 12, 22, 9),
        rule: const GeneralEventRecurrenceRule(
          type: GeneralEventRecurrence.daily,
          count: 9,
        ),
      );
      _expectLastDateStillSkipped(edited);
    },
  );

  test(
    'retained exclusions survive serialization and a later content edit',
    () {
      final edited = _edit(
        _event(),
        start: DateTime(2011, 12, 23, 9),
        rule: const GeneralEventRecurrenceRule(
          type: GeneralEventRecurrence.custom,
          unit: GeneralEventRecurrenceUnit.day,
          interval: 2,
          count: 5,
        ),
      );
      final restored = GeneralScheduleData.fromJson(
        GeneralScheduleData(
          activeScheduleId: 'work',
          schedules: [_calendar(edited)],
        ).toJson(),
      ).schedules.single.events.single;
      final savedAgain = _edit(
        restored,
        title: 'Edited after reload',
        start: DateTime.parse(restored.startDateTimeIso),
        rule: restored.recurrenceRule,
      );
      expect(savedAgain.title, 'Edited after reload');
      _expectLastDateStillSkipped(savedAgain);
    },
  );

  test(
    'an exception after a wide-range stop still protects later day queries',
    () {
      final source = _event(
        rule: const GeneralEventRecurrenceRule(
          type: GeneralEventRecurrence.weekly,
          count: 4,
        ),
        exceptions: const ['2012-01-05'],
      );
      final edited = _edit(
        source,
        start: DateTime(2011, 12, 22, 9),
        rule: const GeneralEventRecurrenceRule(
          type: GeneralEventRecurrence.daily,
          count: 30,
        ),
      );
      final noExceptions = edited.copyWith(
        recurrenceExceptionDateIso: const [],
      );
      final full = _expanded(
        noExceptions,
        DateTime(2011, 12, 22),
        DateTime(2012, 1, 10),
      );
      expect(full.last.exceptionDateIso, '2011-12-31');
      expect(
        _expanded(noExceptions, DateTime(2012, 1, 5), DateTime(2012, 1, 6)),
        hasLength(1),
      );
      expect(edited.recurrenceExceptionDateIso, ['2012-01-05']);
      expect(
        _expanded(edited, DateTime(2012, 1, 5), DateTime(2012, 1, 6)),
        isEmpty,
      );
    },
  );
}
