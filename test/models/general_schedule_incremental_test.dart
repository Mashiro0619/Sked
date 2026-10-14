import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/general_calendar_service.dart';
import 'package:sked/services/import_export_service.dart';

GeneralEvent _event(String id, String calendarId, {int day = 25}) =>
    GeneralEvent(
      id: id,
      calendarId: calendarId,
      title: id,
      startDateTimeIso:
          '2026-05-${day.toString().padLeft(2, '0')}T09:00:00.000',
      endDateTimeIso: '2026-05-${day.toString().padLeft(2, '0')}T10:00:00.000',
      reminders: const [GeneralEventReminder(minutesBefore: 10)],
    );

GeneralReminderAcknowledgement _ack(
  String calendar,
  String event, {
  int day = 25,
}) => GeneralReminderAcknowledgement(
  occurrenceKey: buildGeneralOccurrenceKey(
    calendar,
    event,
    '2026-05-${day.toString().padLeft(2, '0')}T09:00:00.000',
  ),
  updatedAtIso: '2026-05-25T08:55:00.000',
);

GeneralScheduleData _data() => GeneralScheduleData(
  activeScheduleId: 'a',
  selectedDateIso: '2026-05-25',
  schedules: [
    GeneralSchedule(id: 'a', name: 'A', events: [_event('one', 'a')]),
    GeneralSchedule(id: 'b', name: 'B', events: [_event('two', 'b', day: 26)]),
  ],
  reminderAcknowledgements: [_ack('a', 'one'), _ack('b', 'two', day: 26)],
).normalized();

// A valid immutable event that records normalization and refuses any later
// identity/date reads. This detects work on an unrelated branch, not merely
// whether the resulting object happens to retain identity after that work.
class _GuardedEvent extends GeneralEvent {
  _GuardedEvent()
    : super(
        id: 'guarded',
        calendarId: 'b',
        title: 'Guarded',
        startDateTimeIso: '2026-05-26T09:00:00.000',
        endDateTimeIso: '2026-05-26T10:00:00.000',
        reminders: const [GeneralEventReminder(minutesBefore: 10)],
      );

  bool forbidReads = false;
  bool forbidNormalization = false;
  int normalizations = 0;

  void _read() {
    if (forbidReads) throw StateError('An unrelated event was read');
  }

  @override
  String get id {
    _read();
    return super.id;
  }

  @override
  String get startDateTimeIso {
    _read();
    return super.startDateTimeIso;
  }

  @override
  String get endDateTimeIso {
    _read();
    return super.endDateTimeIso;
  }

  @override
  GeneralEvent normalized({required String fallbackCalendarId}) {
    _read();
    if (forbidNormalization) throw StateError('Stored event was normalized');
    normalizations++;
    return this;
  }
}

GeneralScheduleData _guardedData(_GuardedEvent event) => GeneralScheduleData(
  activeScheduleId: 'a',
  schedules: [
    GeneralSchedule(id: 'a', name: 'A', events: [_event('one', 'a')]),
    GeneralSchedule(id: 'b', name: 'B', events: [event]),
  ],
  reminderAcknowledgements: [_ack('b', 'guarded', day: 26)],
).normalized();

GeneralScheduleData _copyAcrossIsolate(GeneralScheduleData data) =>
    data.copyWith(
      schedules: [
        ...data.schedules,
        const GeneralSchedule(id: 'c', name: 'C', events: []),
      ],
    );

void main() {
  const service = GeneralCalendarService();

  test('saving unchanged values retains the event and schedule index', () {
    final probe = _GuardedEvent();
    final initial = _guardedData(probe);
    probe.forbidNormalization = true;
    final saved = service.saveEvent(
      initial,
      probe.copyWith(title: probe.title),
    );
    expect(saved.schedules, same(initial.schedules));
    expect(saved.schedules.last.events.single, same(probe));
    expect(
      saved.reminderAcknowledgements,
      same(initial.reminderAcknowledgements),
    );
    expect(probe.normalizations, 1);
  });

  test('legacy exception migration also freezes the repaired dates', () {
    final original = _data();
    final calendar = original.schedules.first;
    final event = calendar.events.single.copyWith(
      recurrence: GeneralEventRecurrence.weekly,
      recurrenceExceptionDateIso: ['2026-06-01'],
    );
    final legacy =
        original.withSchedule(calendar.copyWith(events: [event])).toJson()
          ..['schemaVersion'] = 3;
    final migrated = GeneralScheduleData.fromJson(legacy);
    final dates =
        migrated.schedules.first.events.single.recurrenceExceptionDateIso;
    expect(dates, ['2026-06-01']);
    expect(dates.clear, throwsUnsupportedError);
  });

  test('legacy overlapping prefixes retain event order through ID repair', () {
    final original = _data();
    final schedules = [
      ...original.schedules,
      GeneralSchedule(
        id: 'c',
        name: 'C',
        events: [_event('x', 'c'), _event('x|y', 'c'), _event('x', 'c')],
      ),
    ];
    final acknowledgements = [
      ...original.reminderAcknowledgements,
      const GeneralReminderAcknowledgement(
        occurrenceKey: 'c|x|y|2026-05-25T09:00:00.000',
        updatedAtIso: '2026-05-25T08:55:00.000',
      ),
    ];
    final next = original.copyWith(
      schedules: schedules,
      reminderAcknowledgements: acknowledgements,
    );
    final repaired = GeneralScheduleData(
      activeScheduleId: original.activeScheduleId,
      selectedDateIso: original.selectedDateIso,
      schedules: schedules,
      reminderAcknowledgements: acknowledgements,
    ).normalized();
    expect(next.toJson(), repaired.toJson());
    expect(
      next.reminderAcknowledgements,
      hasLength(original.reminderAcknowledgements.length),
    );
  });

  test(
    'appending an imported calendar preserves the default calendar identity',
    () {
      final initial = GeneralScheduleData.createDefault();
      final imported = const ImportExportService()
          .importPreparedGeneralSchedules(
            initial,
            [_data().schedules.first],
            scheduleIds: ['a'],
            mode: GeneralScheduleImportMode.addAsNew,
            localeCode: 'en',
          );
      expect(imported.data.schedules.first, same(initial.schedules.first));
      expect(imported.data.schedules, hasLength(2));
    },
  );

  test('metadata and same-value updates do not read event branches', () {
    final probe = _GuardedEvent();
    final initial = _guardedData(probe);
    final calendar = initial.schedules.last;
    probe.forbidReads = true;
    var next = service.renameSchedule(initial, 'b', 'Renamed');
    expect(next.schedules.first, same(initial.schedules.first));
    expect(next.schedules.last.events, same(calendar.events));
    next = service.updateScheduleColor(next, 'b', 0xFF010203);
    next = service.updateScheduleVisibility(next, 'b', false);
    next = service.renameSchedule(next, 'a', 'Other');
    final unchanged = next.copyWith(schedules: [...next.schedules]);
    expect(unchanged.schedules, same(next.schedules));
    expect(
      unchanged.reminderAcknowledgements,
      same(initial.reminderAcknowledgements),
    );
    expect(
      unchanged.toolbarNavigationOrder,
      same(initial.toolbarNavigationOrder),
    );
    expect(
      unchanged.hiddenToolbarNavigationIds,
      same(initial.hiddenToolbarNavigationIds),
    );
    expect(probe.normalizations, 1);
  });

  test(
    'event save and delete only inspect calendars containing that event',
    () {
      final probe = _GuardedEvent();
      final initial = _guardedData(probe);
      final original = initial.schedules.first.events.single;
      probe.forbidReads = true;
      final saved = service.saveEvent(
        initial,
        original.copyWith(title: 'Edited'),
      );
      expect(saved.schedules.last, same(initial.schedules.last));
      expect(
        saved.reminderAcknowledgements,
        same(initial.reminderAcknowledgements),
      );
      final deleted = service.deleteEvent(saved, original.id);
      expect(deleted.schedules.last, same(initial.schedules.last));
      expect(deleted.schedules.first.events, isEmpty);
      expect(probe.normalizations, 1);
    },
  );

  test(
    'adding and removing acknowledgements skips unrelated event parsing',
    () {
      final probe = _GuardedEvent();
      final initial = _guardedData(probe);
      probe.forbidReads = true;
      final next = initial.copyWith(
        reminderAcknowledgements: [
          ...initial.reminderAcknowledgements,
          _ack('a', 'one'),
        ],
      );
      expect(next.schedules, same(initial.schedules));
      expect(next.reminderAcknowledgements, hasLength(2));
      expect(
        next.reminderAcknowledgements.last,
        same(initial.reminderAcknowledgements.single),
      );
      final restored = next.copyWith(
        reminderAcknowledgements: initial.reminderAcknowledgements,
      );
      expect(restored.schedules, same(initial.schedules));
      expect(
        restored.reminderAcknowledgements.single,
        same(initial.reminderAcknowledgements.single),
      );
      expect(probe.normalizations, 1);
    },
  );

  test(
    'new calendars reuse unrelated event indexes without reading their events',
    () {
      final probe = _GuardedEvent();
      final initial = _guardedData(probe);
      probe.forbidReads = true;
      final next = initial.withSchedule(
        GeneralSchedule(id: 'c', name: 'C', events: [_event('three', 'c')]),
      );
      expect(next.schedules[0], same(initial.schedules[0]));
      expect(next.schedules[1], same(initial.schedules[1]));
      expect(
        next.reminderAcknowledgements,
        same(initial.reminderAcknowledgements),
      );
      expect(probe.normalizations, 1);
    },
  );

  test(
    'normalized snapshot metadata remains usable after compute transfer',
    () async {
      final result = await compute(_copyAcrossIsolate, _data());
      final next = result.copyWith(schedules: [...result.schedules]);
      expect(next.schedules, same(result.schedules));
      expect(next.schedules.map((item) => item.id), ['a', 'b', 'c']);
      expect(
        service.saveEvent(next, _event('fresh', 'c')).schedules.first,
        same(next.schedules.first),
      );
    },
  );

  test('raw construction stays raw and normalization isolates all indexed collections', () {
    final exceptionDates = <String>['2026-05-27', 'not a date'];
    final reminders = <GeneralEventReminder>[
      const GeneralEventReminder(minutesBefore: 5),
    ];
    final rawEvent = _event(' one ', ' a ').copyWith(
      title: '  Event  ',
      recurrenceExceptionDateIso: exceptionDates,
      reminders: reminders,
    );
    final events = [rawEvent];
    final schedules = [GeneralSchedule(id: ' a ', name: ' A ', events: events)];
    final raw = GeneralScheduleData(
      activeScheduleId: ' a ',
      schedules: schedules,
    );
    expect(raw.schedules.first.id, ' a ');
    final normalized = raw.normalized();
    final repairedCopy = raw.copyWith(schedules: raw.schedules);
    expect(repairedCopy.toJson(), normalized.toJson());
    final savedRaw = service.saveEvent(raw, rawEvent);
    expect(savedRaw.schedules.single.events.single.title, 'Event');
    exceptionDates.clear();
    reminders.clear();
    events.clear();
    schedules.clear();
    final event = normalized.schedules.single.events.single;
    expect(event.recurrenceExceptionDateIso, ['2026-05-27']);
    expect(event.reminders, hasLength(1));
    expect(() => normalized.schedules.clear(), throwsUnsupportedError);
    expect(
      () => normalized.schedules.single.events.clear(),
      throwsUnsupportedError,
    );
    expect(
      () => event.recurrenceExceptionDateIso.clear(),
      throwsUnsupportedError,
    );
    expect(() => event.reminders.clear(), throwsUnsupportedError);
    expect(
      () => normalized.reminderAcknowledgements.add(_ack('a', 'one')),
      throwsUnsupportedError,
    );
  });

  test(
    'incremental collisions, movement and deletion match complete repair',
    () {
      final original = _data();
      final a = original.schedules[0];
      final b = original.schedules[1];
      final duplicate = GeneralSchedule(
        id: 'a',
        name: 'Duplicate',
        events: [_event('one', 'a', day: 28)],
      );
      final cases = <List<GeneralSchedule>>[
        [...original.schedules, duplicate],
        [duplicate, ...original.schedules],
        [
          a.copyWith(events: [...a.events, _event('two', 'a', day: 28)]),
          b,
        ],
        [a.copyWith(events: []), b],
        [
          a.copyWith(events: []),
          b.copyWith(events: [...b.events, a.events.single]),
        ],
        [b, a],
        [
          a,
          b,
          GeneralSchedule(
            id: '',
            name: '  ',
            events: [_event('', ''), _event('', '')],
          ),
        ],
        [
          a.copyWith(
            events: [...a.events, _event('one_copy', 'a'), _event('one', 'a')],
          ),
          b,
        ],
      ];
      for (var index = 0; index < cases.length; index++) {
        final next = original.copyWith(schedules: cases[index]);
        final repaired = GeneralScheduleData(
          activeScheduleId: original.activeScheduleId,
          selectedDateIso: original.selectedDateIso,
          schedules: cases[index],
          reminderAcknowledgements: original.reminderAcknowledgements,
        ).normalized();
        expect(next.toJson(), repaired.toJson(), reason: 'case $index');
      }
    },
  );

  test(
    'incremental legacy keys retain duplicate-ID and timezone remapping',
    () {
      final original = _data();
      final imported = GeneralSchedule(
        id: 'a',
        name: 'Imported',
        events: [
          GeneralEvent(
            id: 'one',
            calendarId: 'a',
            title: 'Repeating',
            startDateTimeIso: '2026-08-04T10:00:00+08:00',
            endDateTimeIso: '2026-08-04T11:00:00+08:00',
            recurrence: GeneralEventRecurrence.weekly,
            reminders: const [GeneralEventReminder(minutesBefore: 10)],
          ),
        ],
      );
      final schedules = [...original.schedules, imported];
      final acknowledgements = [
        ...original.reminderAcknowledgements,
        const GeneralReminderAcknowledgement(
          occurrenceKey: 'a|one|2026-08-11T10:00:00+08:00',
          updatedAtIso: '2026-08-11T09:55:00+08:00',
        ),
      ];
      final next = original.copyWith(
        schedules: schedules,
        reminderAcknowledgements: acknowledgements,
      );
      final repaired = GeneralScheduleData(
        activeScheduleId: original.activeScheduleId,
        selectedDateIso: original.selectedDateIso,
        schedules: schedules,
        reminderAcknowledgements: acknowledgements,
      ).normalized();
      expect(next.toJson(), repaired.toJson());
    },
  );
}
