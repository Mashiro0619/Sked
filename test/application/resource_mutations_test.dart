import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/application/resource_contracts.dart';
import 'package:sked/application/resource_mutations.dart';
import 'package:sked/models/timetable_models.dart';

Matcher problem(OperationErrorCode code, [String? field]) =>
    isA<OperationProblem>()
        .having((error) => error.code, 'code', code)
        .having(
          (error) => field == null || error.field == field,
          'field',
          true,
        );

void main() {
  test(
    'creates an event in a hidden disabled owner without changing selection',
    () {
      final base = fixture();
      final before = jsonEncode(base.toJson());
      final host = Host();
      final draft = host.compile(base, [
        ResourceMutation(
          kind: ResourceKind.event,
          action: ResourceMutationAction.create,
          destinationParentId: 'hidden',
          values: {
            'title': '  Research  ',
            'start': '2026-10-05T09:00:00',
            'end': '2026-10-05T10:00:00',
          },
        ),
      ]);
      final created = findEvent(draft.candidate, 'event-1');
      expect(created.title, 'Research');
      expect(created.calendarId, 'hidden');
      expect(created.reminderBehavior, GeneralEventReminderBehavior.inherit);
      expect(created.createdAtIso, host.now.toIso8601String());
      expect(created.updatedAtIso, host.now.toIso8601String());
      expect(draft.candidate.activeMode, base.activeMode);
      expect(draft.candidate.enabledWorkspaces, base.enabledWorkspaces);
      expect(draft.candidate.generalMode.activeScheduleId, 'active');
      expect(draft.candidate.generalMode.schedules.last.isVisible, false);
      expect(identical(draft.candidate.studentMode, base.studentMode), true);
      expect(draft.changes, hasLength(1));
      expect(draft.changes.single.before, isNull);
      expect(
        draft.changes.single.ref,
        const ResourceRef(
          kind: ResourceKind.event,
          id: 'event-1',
          parentId: 'hidden',
        ),
      );
      expect(jsonEncode(base.toJson()), before);
    },
  );

  test(
    'no-op patch creates no timestamps, change records or new candidate',
    () {
      final base = fixture(events: [event('a')]);
      final draft = Host().compile(base, [
        patch('a', {'title': 'Original'}),
      ]);
      expect(draft.isEmpty, true);
      expect(identical(draft.candidate, base), true);
      expect(findEvent(base, 'a').updatedAtIso, '2026-10-01T08:00:00.000');
    },
  );

  test('content patch preserves recurrence, reminders and existing acknowledgement', () {
    final base = fixture(
      events: [event('a', repeating: true)],
      acknowledgements: [ack('a')],
    );
    final draft = Host().compile(base, [
      patch('a', {'notes': 'Edited notes'}),
    ]);
    final updated = findEvent(draft.candidate, 'a');
    expect(updated.notes, 'Edited notes');
    expect(
      updated.recurrenceRule.toJson(),
      findEvent(base, 'a').recurrenceRule.toJson(),
    );
    expect(updated.reminderBehavior, GeneralEventReminderBehavior.custom);
    expect(updated.reminders.single.minutesBefore, 10);
    expect(draft.candidate.generalMode.reminderAcknowledgements, hasLength(1));
    expect(draft.changes.map((change) => change.key), [
      'resource:event:active:a',
    ]);
    expect(draft.changes.single.before, findEvent(base, 'a').toJson());
    expect(draft.changes.single.after, updated.toJson());
  });

  test(
    'invalid later commands leave the original complete batch untouched',
    () {
      final base = fixture(events: [event('a')]);
      final before = jsonEncode(base.toJson());
      expect(
        () => Host().compile(base, [
          patch('a', {'title': 'Candidate'}),
          patch('missing', {'title': 'No target'}),
        ]),
        throwsA(problem(OperationErrorCode.notFound)),
      );
      expect(jsonEncode(base.toJson()), before);
    },
  );

  test('wrong or absent parents never fall back to the active calendar', () {
    final base = fixture(events: [event('a')]);
    final invalid = [
      ResourceMutation(
        kind: ResourceKind.event,
        action: ResourceMutationAction.create,
        values: {
          'title': 'Missing owner',
          'start': '2026-10-05T09:00',
          'end': '2026-10-05T10:00',
        },
      ),
      ResourceMutation(
        kind: ResourceKind.event,
        action: ResourceMutationAction.patch,
        target: const ResourceRef(kind: ResourceKind.event, id: 'a'),
        values: {'title': 'Missing owner'},
      ),
    ];
    for (final command in invalid) {
      expect(
        () => Host().compile(base, [command]),
        throwsA(problem(OperationErrorCode.invalidArgument)),
      );
    }
    expect(
      () => Host().compile(base, [
        patch('a', {'title': 'Wrong owner'}, parent: 'hidden'),
      ]),
      throwsA(problem(OperationErrorCode.notFound)),
    );
    expect(
      () => Host().compile(base, [
        ResourceMutation(
          kind: ResourceKind.event,
          action: ResourceMutationAction.create,
          destinationParentId: 'gone',
          values: {
            'title': 'Invalid',
            'start': '2026-10-05T09:00',
            'end': '2026-10-05T10:00',
          },
        ),
      ]),
      throwsA(problem(OperationErrorCode.notFound)),
    );
  });

  test('unknown, read-only and incorrectly typed fields are rejected', () {
    final base = fixture(events: [event('a')]);
    final invalid = <Map<String, Object?>>[
      {'title': ''},
      {'title': null},
      {'start': 5},
      {'notes': false},
      {'isAllDay': 'true'},
      {'colorValue': -77},
      {'colorValue': 1.5},
      {'updatedAt': '2026-10-01'},
      {'calendarId': 'hidden'},
      {'typo': 'value'},
      {
        'recurrenceRule': {'type': 'daily', 'secret': 'value'},
      },
      {
        'recurrenceRule': {'type': 'bogus'},
      },
      {
        'recurrenceRule': {'type': 'daily', 'unit': 'month'},
      },
      {
        'recurrenceRule': {'type': 'daily', 'interval': 0},
      },
      {
        'recurrenceRule': {'type': 'daily', 'count': 0},
      },
      {
        'recurrenceRule': {'type': 'daily', 'monthlyAnchorDay': 31},
      },
      {'reminderBehavior': 'unknown'},
      {
        'reminders': [
          {'minutesBefore': 10, 'device': true},
        ],
      },
      {
        'reminders': [
          {'minutesBefore': -1},
        ],
      },
      {
        'reminders': [
          {'minutesBefore': 10},
          {'minutesBefore': 10},
        ],
      },
    ];
    for (final values in invalid) {
      expect(
        () => Host().compile(base, [patch('a', values)]),
        throwsA(problem(OperationErrorCode.invalidArgument)),
        reason: '$values',
      );
    }
  });

  test(
    'date validation rejects coercion, mixed basis and invalid all-day times',
    () {
      final base = fixture(events: [event('a')]);
      for (final values in <Map<String, Object?>>[
        {'start': '2026-02-30T09:00:00'},
        {'start': '2026-10-05T25:00:00'},
        {'start': '2026-10-05'},
        {'start': '2026-10-05T09:00:00+99:00'},
        {'start': '2026-10-05T09:00:00+99:00 ', 'end': '2026-10-06T10:00:00Z'},
        {'end': '2026-10-05T09:00:00'},
        {'end': '2026-10-05T10:00:00Z'},
        {'isAllDay': true},
        {
          'recurrenceRule': {'type': 'weekly', 'untilDate': '2026-10-04'},
        },
        {
          'recurrenceRule': {
            'type': 'weekly',
            'untilDate': '2026-10-08T00:00:00',
          },
        },
      ]) {
        expect(
          () => Host().compile(base, [patch('a', values)]),
          throwsA(problem(OperationErrorCode.invalidArgument)),
          reason: '$values',
        );
      }
      final draft = Host().compile(base, [
        patch('a', {
          'isAllDay': true,
          'start': '2026-10-05',
          'end': '2026-10-07',
        }),
      ]);
      expect(
        findEvent(draft.candidate, 'a').startDateTimeIso,
        '2026-10-05T00:00:00.000',
      );
      expect(
        findEvent(draft.candidate, 'a').endDateTimeIso,
        '2026-10-07T00:00:00.000',
      );
    },
  );

  test(
    'numeric offsets convert to the same UTC basis without losing the instant',
    () {
      final draft = Host().compile(fixture(events: [event('a')]), [
        patch('a', {
          'start': '2026-10-05T09:00:00+08:00',
          'end': '2026-10-05T10:00:00+08:00',
        }),
      ]);
      expect(
        findEvent(draft.candidate, 'a').startDateTimeIso,
        '2026-10-05T01:00:00.000Z',
      );
      expect(
        findEvent(draft.candidate, 'a').endDateTimeIso,
        '2026-10-05T02:00:00.000Z',
      );
    },
  );

  test('nullable color reset does not clear omitted fields', () {
    final draft = Host().compile(
      fixture(events: [event('a').copyWith(colorValue: 0xff123456)]),
      [
        patch('a', {'colorValue': null}),
      ],
    );
    final updated = findEvent(draft.candidate, 'a');
    expect(updated.colorValue, isNull);
    expect(updated.location, 'Office');
    expect(updated.notes, 'Original notes');
    expect(updated.reminders.single.minutesBefore, 10);
  });

  test(
    'changing reminder policy clears offsets and affected acknowledgements',
    () {
      final base = fixture(events: [event('a')], acknowledgements: [ack('a')]);
      final draft = Host().compile(base, [
        patch('a', {'reminderBehavior': 'inherit'}),
      ]);
      final updated = findEvent(draft.candidate, 'a');
      expect(updated.reminderBehavior, GeneralEventReminderBehavior.inherit);
      expect(updated.reminders, isEmpty);
      expect(draft.candidate.generalMode.reminderAcknowledgements, isEmpty);
      expect(draft.changes.last.key, 'general.reminderAcknowledgements');
      expect(
        () => Host().compile(base, [
          patch('a', {
            'reminderBehavior': 'inherit',
            'reminders': [
              {'minutesBefore': 10},
            ],
          }),
        ]),
        throwsA(problem(OperationErrorCode.invalidArgument)),
      );
      expect(
        () => Host().compile(base, [
          patch('a', {'reminders': []}),
        ]),
        throwsA(problem(OperationErrorCode.invalidArgument)),
      );
    },
  );

  test(
    'moving an event records both owners and never selects the destination',
    () {
      final base = fixture(events: [event('a')], acknowledgements: [ack('a')]);
      final draft = Host().compile(base, [
        ResourceMutation(
          kind: ResourceKind.event,
          action: ResourceMutationAction.move,
          target: eventRef('a'),
          destinationParentId: 'hidden',
        ),
      ]);
      expect(findEvent(draft.candidate, 'a').calendarId, 'hidden');
      expect(draft.candidate.generalMode.activeScheduleId, 'active');
      expect(draft.candidate.generalMode.schedules.last.isVisible, false);
      final changes = draft.changes
          .where((change) => change.ref?.kind == ResourceKind.event)
          .toList();
      expect(changes.map((change) => change.ref!.parentId), [
        'active',
        'hidden',
      ]);
      expect(changes.first.after, isNull);
      expect(changes.last.before, isNull);
      expect(draft.changes.last.key, 'general.reminderAcknowledgements');
      expect(
        () => Host().compile(base, [
          ResourceMutation(
            kind: ResourceKind.event,
            action: ResourceMutationAction.patch,
            target: eventRef('a'),
            destinationParentId: 'hidden',
          ),
        ]),
        throwsA(problem(OperationErrorCode.invalidArgument)),
      );
    },
  );

  test(
    'copying a series allocates exactly one new ID and preserves the original',
    () {
      final base = fixture(
        events: [
          event('a', repeating: true, exceptions: ['2026-10-12']),
        ],
      );
      final host = Host();
      final draft = host.compile(base, [
        ResourceMutation(
          kind: ResourceKind.event,
          action: ResourceMutationAction.copy,
          target: eventRef('a'),
          destinationParentId: 'hidden',
          values: {'title': 'Copy'},
        ),
      ]);
      expect(host.allocated, [ResourceKind.event]);
      final copy = findEvent(draft.candidate, 'event-1');
      expect(copy.calendarId, 'hidden');
      expect(copy.title, 'Copy');
      expect(copy.recurrenceExceptionDateIso, ['2026-10-12']);
      expect(
        findEvent(draft.candidate, 'a').toJson(),
        findEvent(base, 'a').toJson(),
      );
      expect(draft.changes, hasLength(1));
    },
  );

  test('same-step time changes remap exceptions by candidate sequence', () {
    final base = fixture(
      events: [
        event('a', repeating: true, exceptions: ['2026-10-12']),
      ],
    );
    final draft = Host().compile(base, [
      patch('a', {
        'start': '2026-10-06T09:00:00',
        'end': '2026-10-06T10:00:00',
      }),
    ]);
    expect(findEvent(draft.candidate, 'a').recurrenceExceptionDateIso, [
      '2026-10-13',
    ]);
  });

  test(
    'step changes retain matching absolute dates and stop clears exceptions',
    () {
      final base = fixture(
        events: [
          event('a', repeating: true, exceptions: ['2026-10-12']),
        ],
      );
      final changed = Host().compile(base, [
        patch('a', {
          'recurrenceRule': {'type': 'daily'},
        }),
      ]);
      expect(findEvent(changed.candidate, 'a').recurrenceExceptionDateIso, [
        '2026-10-12',
      ]);
      final stopped = Host().compile(base, [
        patch('a', {
          'recurrenceRule': {'type': 'none'},
        }),
      ]);
      expect(
        findEvent(stopped.candidate, 'a').recurrenceExceptionDateIso,
        isEmpty,
      );
    },
  );

  test(
    'explicit exceptions must be real distinct candidates in repeat limits',
    () {
      final base = fixture(events: [event('a', repeating: true)]);
      for (final dates in [
        ['2026-10-06'],
        ['2026-10-26'],
        ['2026-10-12', '2026-10-12'],
        ['2026-10-12T00:00:00'],
      ]) {
        expect(
          () => Host().compile(base, [
            patch('a', {'recurrenceExceptionDates': dates}),
          ]),
          throwsA(problem(OperationErrorCode.invalidArgument)),
        );
      }
      final draft = Host().compile(base, [
        patch('a', {
          'recurrenceExceptionDates': ['2026-10-19', '2026-10-12'],
        }),
      ]);
      expect(findEvent(draft.candidate, 'a').recurrenceExceptionDateIso, [
        '2026-10-12',
        '2026-10-19',
      ]);
    },
  );

  test('delete clears only the target event and its acknowledgement', () {
    final base = fixture(
      events: [event('a'), event('b')],
      acknowledgements: [ack('a'), ack('b')],
    );
    final draft = Host().compile(base, [
      ResourceMutation(
        kind: ResourceKind.event,
        action: ResourceMutationAction.delete,
        target: eventRef('a'),
      ),
    ]);
    expect(draft.candidate.generalMode.eventLocationsById('a'), isEmpty);
    expect(
      findEvent(draft.candidate, 'b').toJson(),
      findEvent(base, 'b').toJson(),
    );
    expect(
      draft.candidate.generalMode.reminderAcknowledgements.single.occurrenceKey,
      ack('b').occurrenceKey,
    );
    expect(draft.changes.first.after, isNull);
    expect(draft.changes.last.key, 'general.reminderAcknowledgements');
  });

  test(
    'calendar creation and copy keep active selection and allocate owned IDs',
    () {
      final base = fixture(events: [event('a')]);
      final host = Host();
      final draft = host.compile(base, [
        ResourceMutation(
          kind: ResourceKind.calendar,
          action: ResourceMutationAction.create,
          values: {'name': 'New', 'isVisible': false},
        ),
        ResourceMutation(
          kind: ResourceKind.calendar,
          action: ResourceMutationAction.copy,
          target: const ResourceRef(kind: ResourceKind.calendar, id: 'active'),
          values: {'name': 'Copy'},
        ),
      ]);
      expect(host.allocated, [
        ResourceKind.calendar,
        ResourceKind.calendar,
        ResourceKind.event,
      ]);
      expect(draft.candidate.generalMode.activeScheduleId, 'active');
      final copied = draft.candidate.generalMode.schedules.last;
      expect(copied.id, 'calendar-2');
      expect(copied.events.single.id, 'event-3');
      expect(copied.events.single.calendarId, copied.id);
      expect(
        draft.changes.map((change) => change.ref!.kind),
        everyElement(ResourceKind.calendar),
      );
    },
  );

  test('hiding active calendar records the resulting legal selection', () {
    final base = fixture(hiddenVisible: true);
    final draft = Host().compile(base, [
      ResourceMutation(
        kind: ResourceKind.calendar,
        action: ResourceMutationAction.patch,
        target: const ResourceRef(kind: ResourceKind.calendar, id: 'active'),
        values: {'isVisible': false},
      ),
    ]);
    expect(draft.candidate.generalMode.activeScheduleId, 'hidden');
    expect(draft.changes.map((change) => change.key), [
      'resource:calendar::active',
      'general.activeScheduleId',
    ]);
  });

  test('calendar sortOrder moves the list and records every shifted owner', () {
    final initial = fixture();
    final base = initial.copyWith(
      generalMode: initial.generalMode.copyWith(
        schedules: [
          ...initial.generalMode.schedules,
          const GeneralSchedule(id: 'third', name: 'Third', events: []),
        ],
      ),
    );
    final draft = Host().compile(base, [
      ResourceMutation(
        kind: ResourceKind.calendar,
        action: ResourceMutationAction.patch,
        target: const ResourceRef(kind: ResourceKind.calendar, id: 'third'),
        values: {'sortOrder': 0},
      ),
    ]);
    expect(draft.candidate.generalMode.schedules.map((item) => item.id), [
      'third',
      'active',
      'hidden',
    ]);
    expect(
      draft.candidate.generalMode.schedules.map((item) => item.sortOrder),
      [0, 1, 2],
    );
    expect(draft.candidate.generalMode.activeScheduleId, 'active');
    expect(draft.changes.map((change) => change.ref!.id), [
      'active',
      'hidden',
      'third',
    ]);
    expect(draft.changes.map((change) => (change.before as Map)['sortOrder']), [
      0,
      1,
      2,
    ]);
    expect(draft.changes.map((change) => (change.after as Map)['sortOrder']), [
      1,
      2,
      0,
    ]);
  });

  test('calendar creation inserts at a legal position and reports shifted metadata', () {
    final base = fixture();
    final draft = Host().compile(base, [
      ResourceMutation(
        kind: ResourceKind.calendar,
        action: ResourceMutationAction.create,
        values: {'name': 'Inserted', 'sortOrder': 1},
      ),
    ]);
    expect(draft.candidate.generalMode.schedules.map((item) => item.id), [
      'active',
      'calendar-1',
      'hidden',
    ]);
    expect(draft.changes.map((change) => change.ref!.id), [
      'calendar-1',
      'hidden',
    ]);
    expect((draft.changes.last.before as Map)['sortOrder'], 1);
    expect((draft.changes.last.after as Map)['sortOrder'], 2);
    expect(
      () => Host().compile(base, [
        ResourceMutation(
          kind: ResourceKind.calendar,
          action: ResourceMutationAction.patch,
          target: const ResourceRef(kind: ResourceKind.calendar, id: 'active'),
          values: {'sortOrder': 2},
        ),
      ]),
      throwsA(problem(OperationErrorCode.invalidArgument, 'sortOrder')),
    );
    expect(
      () => Host().compile(base, [
        ResourceMutation(
          kind: ResourceKind.calendar,
          action: ResourceMutationAction.create,
          values: {'name': 'Invalid', 'sortOrder': 3},
        ),
      ]),
      throwsA(problem(OperationErrorCode.invalidArgument, 'sortOrder')),
    );
  });

  test(
    'deleting the first calendar records the following calendar new position',
    () {
      final base = fixture(events: [event('a')], acknowledgements: [ack('a')]);
      final draft = Host().compile(base, [
        ResourceMutation(
          kind: ResourceKind.calendar,
          action: ResourceMutationAction.delete,
          target: const ResourceRef(kind: ResourceKind.calendar, id: 'active'),
        ),
      ]);
      expect(draft.candidate.generalMode.schedules.single.id, 'hidden');
      expect(draft.candidate.generalMode.schedules.single.sortOrder, 0);
      expect(draft.changes.map((change) => change.key), [
        'resource:calendar::active',
        'resource:calendar::hidden',
        'general.activeScheduleId',
        'general.reminderAcknowledgements',
      ]);
      expect((draft.changes[1].before as Map)['sortOrder'], 1);
      expect((draft.changes[1].after as Map)['sortOrder'], 0);
    },
  );

  test('creating or copying a visible calendar from all-hidden state records selection fallback', () {
    final initial = fixture();
    final base = initial.copyWith(
      generalMode: initial.generalMode.copyWith(
        schedules: [
          for (final calendar in initial.generalMode.schedules)
            calendar.copyWith(isVisible: false),
        ],
      ),
    );
    expect(base.generalMode.activeScheduleId, 'active');
    for (final command in [
      ResourceMutation(
        kind: ResourceKind.calendar,
        action: ResourceMutationAction.create,
        values: {'name': 'Visible'},
      ),
      ResourceMutation(
        kind: ResourceKind.calendar,
        action: ResourceMutationAction.copy,
        target: const ResourceRef(kind: ResourceKind.calendar, id: 'active'),
        values: {'isVisible': true},
      ),
    ]) {
      final draft = Host().compile(base, [command]);
      expect(draft.candidate.generalMode.activeScheduleId, 'calendar-1');
      final selection = draft.changes.singleWhere(
        (change) => change.key == 'general.activeScheduleId',
      );
      expect(selection.before, 'active');
      expect(selection.after, 'calendar-1');
      expect(draft.candidate.generalMode.schedules.first.isVisible, false);
      expect(draft.candidate.enabledWorkspaces, base.enabledWorkspaces);
    }
  });

  test('deleting the last calendar creates a host-identified default with full diff', () {
    final base = fixture(
      events: [event('a')],
      acknowledgements: [ack('a')],
      includeHidden: false,
    );
    final host = Host();
    final draft = host.compile(base, [
      ResourceMutation(
        kind: ResourceKind.calendar,
        action: ResourceMutationAction.delete,
        target: const ResourceRef(kind: ResourceKind.calendar, id: 'active'),
      ),
    ]);
    expect(draft.candidate.generalMode.schedules.single.id, 'calendar-1');
    expect(draft.candidate.generalMode.schedules.single.events, isEmpty);
    expect(draft.candidate.generalMode.activeScheduleId, 'calendar-1');
    expect(draft.candidate.generalMode.reminderAcknowledgements, isEmpty);
    final deleted = draft.changes.first;
    expect((deleted.before as Map)['events'], [findEvent(base, 'a').toJson()]);
    expect(deleted.after, isNull);
    expect(draft.changes.map((change) => change.key), [
      'resource:calendar::active',
      'resource:calendar::calendar-1',
      'general.activeScheduleId',
      'general.reminderAcknowledgements',
    ]);
  });

  test(
    'calendar and event changes in one batch use a complete parent diff',
    () {
      final base = fixture(events: [event('a')]);
      final draft = Host().compile(base, [
        patch('a', {'title': 'Updated child'}),
        ResourceMutation(
          kind: ResourceKind.calendar,
          action: ResourceMutationAction.patch,
          target: const ResourceRef(kind: ResourceKind.calendar, id: 'active'),
          values: {'name': 'Updated parent'},
        ),
      ]);
      expect(draft.changes, hasLength(1));
      expect(draft.changes.single.ref!.kind, ResourceKind.calendar);
      expect(
        ((draft.changes.single.after as Map)['events'] as List).single['title'],
        'Updated child',
      );
    },
  );

  test('change records retain initial before and final after across repeated patches', () {
    final base = fixture(events: [event('a')]);
    final draft = Host().compile(base, [
      patch('a', {'title': 'First'}),
      patch('a', {'title': 'Last'}),
    ]);
    expect(draft.changes, hasLength(1));
    expect((draft.changes.single.before as Map)['title'], 'Original');
    expect((draft.changes.single.after as Map)['title'], 'Last');
    expect(
      () => (draft.changes.single.after as Map)['title'] = 'tampered',
      throwsUnsupportedError,
    );
    expect(() => draft.changes.clear(), throwsUnsupportedError);
  });

  test(
    'caller changes cannot rewrite command arguments after construction',
    () {
      final values = <String, Object?>{'title': 'Fixed'};
      final command = patch('a', values);
      values['title'] = 'Changed';
      final draft = Host().compile(fixture(events: [event('a')]), [command]);
      expect(findEvent(draft.candidate, 'a').title, 'Fixed');
      expect(
        () => ResourceMutation(
          kind: ResourceKind.event,
          action: ResourceMutationAction.create,
          values: {'bad': double.nan},
        ),
        throwsA(problem(OperationErrorCode.invalidArgument)),
      );
      final cycle = <String, Object?>{};
      cycle['cycle'] = cycle;
      expect(
        () => ResourceMutation(
          kind: ResourceKind.event,
          action: ResourceMutationAction.create,
          values: cycle,
        ),
        throwsA(problem(OperationErrorCode.invalidArgument)),
      );
    },
  );

  test('duplicate host IDs and ambiguous source identities fail before persistence', () {
    final base = fixture(events: [event('a')]);
    expect(
      () => const ResourceMutationCompiler().compile(
        base,
        [
          ResourceMutation(
            kind: ResourceKind.event,
            action: ResourceMutationAction.copy,
            target: eventRef('a'),
          ),
        ],
        context: MutationContext(
          now: DateTime(2026, 10, 30),
          idGenerator: (_) => 'a',
        ),
      ),
      throwsA(problem(OperationErrorCode.conflict)),
    );
    final ambiguous = base.copyWith(
      generalMode: GeneralScheduleData(
        activeScheduleId: 'active',
        selectedDateIso: '2026-10-05',
        schedules: [
          GeneralSchedule(
            id: 'active',
            name: 'Name',
            events: [event('a'), event('a')],
          ),
        ],
      ),
    );
    expect(
      () => Host().compile(ambiguous, [
        patch('a', {'title': 'New'}),
      ]),
      throwsA(problem(OperationErrorCode.conflict)),
    );
  });

  test('command count, input bytes, unsupported kinds and empty batches are explicit', () {
    final base = fixture(events: [event('a')]);
    expect(Host().compile(base, []).isEmpty, true);
    expect(
      () =>
          Host().compile(base, [for (var i = 0; i < 1001; i++) patch('a', {})]),
      throwsA(problem(OperationErrorCode.invalidArgument, 'operations')),
    );
    expect(
      () => Host().compile(base, [
        patch('a', {'notes': 'x' * (1024 * 1024)}),
      ]),
      throwsA(problem(OperationErrorCode.invalidArgument, 'values')),
    );
    expect(
      () => Host().compile(base, [
        ResourceMutation(
          kind: ResourceKind.occurrence,
          action: ResourceMutationAction.create,
        ),
      ]),
      throwsA(problem(OperationErrorCode.unsupported)),
    );
  });
}

class Host {
  final now = DateTime(2026, 10, 30, 8, 30);
  final allocated = <ResourceKind>[];
  MutationDraft compile(AppData base, List<ResourceMutation> commands) =>
      const ResourceMutationCompiler().compile(
        base,
        commands,
        context: MutationContext(
          now: now,
          idGenerator: (kind) {
            allocated.add(kind);
            return '${kind.name}-${allocated.length}';
          },
        ),
      );
}

ResourceRef eventRef(String id, {String parent = 'active'}) =>
    ResourceRef(kind: ResourceKind.event, id: id, parentId: parent);
ResourceMutation patch(
  String id,
  Map<String, Object?> values, {
  String parent = 'active',
}) => ResourceMutation(
  kind: ResourceKind.event,
  action: ResourceMutationAction.patch,
  target: eventRef(id, parent: parent),
  values: values,
);
GeneralEvent findEvent(AppData data, String id) =>
    data.generalMode.eventLocationsById(id).single.event;

AppData fixture({
  List<GeneralEvent> events = const [],
  List<GeneralReminderAcknowledgement> acknowledgements = const [],
  bool hiddenVisible = false,
  bool includeHidden = true,
}) => AppData(
  activeMode: AppMode.student,
  enabledWorkspaces: {AppMode.student},
  studentMode: const StudentModeData(
    activeTimetableId: '',
    timetables: [],
    periodTimeSets: [],
  ),
  generalMode: GeneralScheduleData(
    activeScheduleId: 'active',
    selectedDateIso: '2026-10-05',
    schedules: [
      GeneralSchedule(id: 'active', name: 'Current calendar', events: events),
      if (includeHidden)
        GeneralSchedule(
          id: 'hidden',
          name: 'Hidden calendar',
          events: [],
          isVisible: hiddenVisible,
        ),
    ],
    reminderAcknowledgements: acknowledgements,
  ).normalized(),
  aiApiSettings: const AiApiSettings(customApiKey: 'secret'),
);

GeneralEvent event(
  String id, {
  bool repeating = false,
  List<String> exceptions = const [],
}) => GeneralEvent(
  id: id,
  calendarId: 'active',
  title: 'Original',
  startDateTimeIso: '2026-10-05T09:00:00.000',
  endDateTimeIso: '2026-10-05T10:00:00.000',
  location: 'Office',
  notes: 'Original notes',
  recurrenceRule: repeating
      ? const GeneralEventRecurrenceRule(
          type: GeneralEventRecurrence.weekly,
          count: 3,
        )
      : const GeneralEventRecurrenceRule(),
  recurrenceExceptionDateIso: exceptions,
  reminders: [const GeneralEventReminder(minutesBefore: 10)],
  createdAtIso: '2026-10-01T08:00:00.000',
  updatedAtIso: '2026-10-01T08:00:00.000',
);

GeneralReminderAcknowledgement ack(String id) => GeneralReminderAcknowledgement(
  occurrenceKey: buildGeneralOccurrenceKey(
    'active',
    id,
    '2026-10-05T09:00:00.000',
  ),
  updatedAtIso: '2026-10-05T09:05:00.000',
);
