import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';

const _weekly = GeneralEventRecurrenceRule(
  type: GeneralEventRecurrence.weekly,
  count: 8,
);

GeneralEvent _event({
  GeneralEventRecurrenceRule rule = _weekly,
  List<String> exceptions = const ['2026-01-08', '2026-01-15', '2026-01-22'],
  String start = '2026-01-01T09:00:00.000',
}) => GeneralEvent(
  id: 'series',
  calendarId: 'work',
  title: 'Repeated',
  startDateTimeIso: start,
  endDateTimeIso: DateTime.parse(start)
      .add(const Duration(hours: 1))
      .toIso8601String(),
  recurrenceRule: rule,
  recurrenceExceptionDateIso: exceptions,
);

List<String> _mapped(
  GeneralEvent source,
  GeneralEventRecurrenceRule rule, {
  String? start,
  int offset = 0,
}) => remapGeneralRecurrenceExceptionDates(
  source: source,
  destination: source.copyWith(
    recurrenceRule: rule,
    startDateTimeIso: start,
    endDateTimeIso: start == null
        ? source.endDateTimeIso
        : DateTime.parse(start).add(const Duration(hours: 1)).toIso8601String(),
  ),
  sourceSequenceOffset: offset,
);

void main() {
  for (final suffix in ['', 'Z']) {
    test('weekly to daily keeps matching absolute dates: $suffix', () {
      final source = _event(start: '2026-01-01T09:00:00.000$suffix');
      expect(
        _mapped(
          source,
          const GeneralEventRecurrenceRule(
            type: GeneralEventRecurrence.daily,
            count: 40,
          ),
        ),
        source.recurrenceExceptionDateIso,
      );
    });
  }

  test('changed interval drops dates between new candidates', () {
    expect(
      _mapped(
        _event(),
        const GeneralEventRecurrenceRule(
          type: GeneralEventRecurrence.weekly,
          interval: 2,
          count: 3,
        ),
      ),
      ['2026-01-15'],
    );
  });

  test('changed unit never turns an exclusion into a different month', () {
    expect(
      _mapped(
        _event(),
        const GeneralEventRecurrenceRule(
          type: GeneralEventRecurrence.custom,
          unit: GeneralEventRecurrenceUnit.month,
          count: 3,
        ),
      ),
      isEmpty,
    );
  });

  test('new count and cutoff bound absolute exclusions after a change', () {
    expect(
      _mapped(
        _event(),
        const GeneralEventRecurrenceRule(
          type: GeneralEventRecurrence.daily,
          count: 10,
          untilDateIso: '2026-01-09',
        ),
      ),
      ['2026-01-08'],
    );
  });

  test(
    'moving the start while changing the step still keeps absolute dates',
    () {
      expect(
        _mapped(
          _event(),
          const GeneralEventRecurrenceRule(
            type: GeneralEventRecurrence.daily,
            count: 25,
          ),
          start: '2026-01-05T09:00:00.000',
        ),
        ['2026-01-08', '2026-01-15', '2026-01-22'],
      );
    },
  );

  test('following range cannot adopt exclusions from before its split', () {
    final source = _event(
      exceptions: ['2026-01-08', '2026-01-22', '2026-01-29'],
    );
    expect(
      _mapped(
        source,
        const GeneralEventRecurrenceRule(
          type: GeneralEventRecurrence.daily,
          count: 20,
        ),
        start: '2026-01-15T09:00:00.000',
        offset: 2,
      ),
      ['2026-01-22', '2026-01-29'],
    );
  });

  test('invalid or previously off-rule dates cannot become new exclusions', () {
    final source = _event(exceptions: ['bad', '2026-01-08', '2026-01-10']);
    expect(
      _mapped(
        source,
        const GeneralEventRecurrenceRule(
          type: GeneralEventRecurrence.daily,
          count: 30,
        ),
      ),
      ['2026-01-08'],
    );
  });

  test('equivalent week and seven-day rules keep ordinal movement', () {
    expect(
      _mapped(
        _event(),
        const GeneralEventRecurrenceRule(
          type: GeneralEventRecurrence.custom,
          unit: GeneralEventRecurrenceUnit.day,
          interval: 7,
          count: 8,
        ),
        start: '2026-01-02T09:00:00.000',
      ),
      ['2026-01-09', '2026-01-16', '2026-01-23'],
    );
  });

  test(
    'unused unit fields and count changes do not change the effective step',
    () {
      expect(
        _mapped(
          _event(rule: _weekly.copyWith(unit: GeneralEventRecurrenceUnit.day)),
          _weekly.copyWith(unit: GeneralEventRecurrenceUnit.month, count: 2),
          start: '2026-01-02T09:00:00.000',
        ),
        ['2026-01-09'],
      );
    },
  );

  test('normalized minimum intervals preserve the same ordinal sequence', () {
    final source = _event(
      rule: const GeneralEventRecurrenceRule(
        type: GeneralEventRecurrence.daily,
        interval: 0,
      ),
      exceptions: ['2026-01-02', '2026-01-03'],
    );
    expect(
      _mapped(
        source,
        const GeneralEventRecurrenceRule(
          type: GeneralEventRecurrence.custom,
          unit: GeneralEventRecurrenceUnit.day,
        ),
        start: '2026-01-05T09:00:00.000',
      ),
      ['2026-01-06', '2026-01-07'],
    );
  });

  test('turning repeats off removes all exclusions', () {
    expect(_mapped(_event(), const GeneralEventRecurrenceRule()), isEmpty);
  });
}
