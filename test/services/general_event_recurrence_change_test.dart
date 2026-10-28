import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/general_calendar_service.dart';

const _service = GeneralCalendarService();

GeneralScheduleData _data() => GeneralScheduleData(
  activeScheduleId: 'work',
  schedules: [
    GeneralSchedule(
      id: 'work',
      name: 'Work',
      events: [
        GeneralEvent(
          id: 'series',
          calendarId: 'work',
          title: 'Original',
          startDateTimeIso: '2026-05-20T09:00:00.000',
          endDateTimeIso: '2026-05-20T10:00:00.000',
          recurrenceRule: const GeneralEventRecurrenceRule(
            type: GeneralEventRecurrence.weekly,
            count: 6,
          ),
          recurrenceExceptionDateIso: const [
            '2026-05-27',
            '2026-06-10',
            '2026-06-24',
          ],
          reminderBehavior: GeneralEventReminderBehavior.inherit,
        ),
      ],
    ),
  ],
);

GeneralEventOccurrence _occurrence(GeneralScheduleData data, String iso) {
  final start = DateTime.parse(iso);
  return expandGeneralEventOccurrences(
    calendar: data.schedules.single,
    event: data.schedules.single.events.singleWhere(
      (event) => event.id == 'series',
    ),
    startInclusive: start,
    endExclusive: start.add(const Duration(microseconds: 1)),
  ).single;
}

void main() {
  for (final scope in [
    GeneralEventEditScope.entireSeries,
    GeneralEventEditScope.thisAndFollowing,
  ]) {
    test(
      '$scope changes the step without moving exclusions or touching detached events',
      () {
        var data = _data();
        final first = _occurrence(data, '2026-05-20T09:00:00.000');
        final detached = _service.editOccurrence(
          data,
          first,
          _service
              .prepareOccurrenceEdit(
                first,
                GeneralEventEditScope.thisOccurrence,
              )
              .copyWith(
                title: 'Detached',
                startDateTimeIso: '2026-05-21T14:00:00.000',
                endDateTimeIso: '2026-05-21T15:00:00.000',
              ),
          GeneralEventEditScope.thisOccurrence,
        );
        data = detached.data;
        final source = _occurrence(data, '2026-06-03T09:00:00.000');
        final draft = _service
            .prepareOccurrenceEdit(source, scope)
            .copyWith(
              title: 'New pattern',
              recurrenceRule: const GeneralEventRecurrenceRule(
                type: GeneralEventRecurrence.daily,
                count: 45,
              ),
            );
        final before = jsonEncode(data.toJson());
        final result = _service.editOccurrence(data, source, draft, scope);
        expect(jsonEncode(data.toJson()), before);
        expect(
          result.data.schedules.single.events
              .singleWhere((event) => event.id == detached.event.id)
              .toJson(),
          detached.event.toJson(),
        );
        if (scope == GeneralEventEditScope.entireSeries) {
          expect(result.event.id, 'series');
          expect(result.event.recurrenceExceptionDateIso, [
            '2026-05-20',
            '2026-05-27',
            '2026-06-10',
            '2026-06-24',
          ]);
          expect(result.data.schedules.single.events, hasLength(2));
        } else {
          expect(result.event.id, isNot('series'));
          expect(result.event.recurrenceExceptionDateIso, [
            '2026-06-10',
            '2026-06-24',
          ]);
          final prefix = result.data.schedules.single.events.singleWhere(
            (event) => event.id == 'series',
          );
          expect(prefix.recurrenceRule.type, GeneralEventRecurrence.weekly);
          expect(prefix.recurrenceRule.count, 2);
          expect(prefix.recurrenceExceptionDateIso, [
            '2026-05-20',
            '2026-05-27',
          ]);
          expect(result.data.schedules.single.events, hasLength(3));
        }
        final expanded = expandGeneralEventOccurrences(
          calendar: result.data.schedules.single,
          event: result.event,
          startInclusive: DateTime(2026, 5),
          endExclusive: DateTime(2026, 8),
        );
        expect(
          expanded.any((item) => item.exceptionDateIso == '2026-06-10'),
          isFalse,
        );
        expect(
          expanded.any((item) => item.exceptionDateIso == '2026-06-24'),
          isFalse,
        );
        expect(
          expanded.any((item) => item.exceptionDateIso == '2026-06-11'),
          isTrue,
        );
      },
    );
  }

  test(
    'equivalent day/week notation preserves both exclusions and handled state',
    () {
      var data = _data();
      final key = buildGeneralOccurrenceKey(
        'work',
        'series',
        '2026-06-03T09:00:00.000',
      );
      data = data.copyWith(
        reminderAcknowledgements: [
          GeneralReminderAcknowledgement(
            occurrenceKey: key,
            updatedAtIso: '2026-06-03T08:59:00.000',
          ),
        ],
      );
      final source = _occurrence(data, '2026-06-03T09:00:00.000');
      final result = _service.editOccurrence(
        data,
        source,
        source.event.copyWith(
          recurrenceRule: source.event.recurrenceRule.copyWith(
            type: GeneralEventRecurrence.custom,
            unit: GeneralEventRecurrenceUnit.day,
            interval: 7,
          ),
        ),
        GeneralEventEditScope.entireSeries,
      );
      expect(
        result.event.recurrenceExceptionDateIso,
        source.event.recurrenceExceptionDateIso,
      );
      expect(
        result.data.reminderAcknowledgements.map((item) => item.occurrenceKey),
        [key],
      );
    },
  );
}
