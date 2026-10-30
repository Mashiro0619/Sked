import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/application/resource_contracts.dart';
import 'package:sked/application/resource_mutations.dart';
import 'package:sked/models/timetable_models.dart';

void main() {
  test(
    'single edit detaches the exact hidden occurrence with host identity',
    () {
      final base = fixture(acknowledgements: [ack(5), ack(19), ack(26)]);
      final before = jsonEncode(base.toJson());
      final host = Host();
      final draft = host.compile(base, [
        command(ResourceMutationAction.patch, values: {'title': 'Edited'}),
      ]);
      expect(jsonEncode(base.toJson()), before);
      final original = eventById(draft, 'series');
      final detached = eventById(draft, 'event-1');
      expect(original.recurrenceExceptionDateIso, ['2026-10-12', '2026-10-19']);
      expect(detached.title, 'Edited');
      expect(detached.startDateTimeIso, '2026-10-19T09:00:00.000');
      expect(detached.recurrenceRule.isRepeating, false);
      expect(detached.recurrenceExceptionDateIso, isEmpty);
      expect(detached.createdAtIso, host.now.toIso8601String());
      expect(original.updatedAtIso, host.now.toIso8601String());
      expect(draft.candidate.generalMode.activeScheduleId, 'active');
      expect(draft.candidate.generalMode.schedules.last.isVisible, false);
      expect(draft.candidate.enabledWorkspaces, {AppMode.student});
      expect(draft.candidate.activeMode, AppMode.student);
      expect(host.allocated, [ResourceKind.event]);
      expect(draft.changes.map((item) => item.key).toSet(), {
        'resource:event:hidden:series',
        'resource:event:hidden:event-1',
        'general.reminderAcknowledgements',
      });
      expect(keys(draft), [key(5), key(26)]);
      final reminderChange = draft.changes.singleWhere(
        (item) => item.ref == null,
      );
      expect((reminderChange.before as List), hasLength(3));
      expect((reminderChange.after as List), hasLength(2));
    },
  );

  test('following edit splits candidate counts and preserves prefix state', () {
    final host = Host();
    final draft = host.compile(
      fixture(
        acknowledgements: [ack(5), ack(19), ack(26)],
        exceptions: ['2026-10-12', '2026-11-02'],
      ),
      [
        command(
          ResourceMutationAction.patch,
          scope: GeneralEventEditScope.thisAndFollowing,
          values: {'title': 'Suffix'},
        ),
      ],
    );
    final prefix = eventById(draft, 'series');
    final suffix = eventById(draft, 'event-1');
    expect(prefix.recurrenceRule.count, 2);
    expect(prefix.recurrenceRule.untilDateIso, '2026-10-18');
    expect(prefix.recurrenceExceptionDateIso, ['2026-10-12']);
    expect(suffix.recurrenceRule.count, 4);
    expect(suffix.recurrenceExceptionDateIso, ['2026-11-02']);
    expect(keys(draft), [key(5)]);
  });

  test('monthly suffix retains the unclipped anchor and remaining count', () {
    final base = fixture(
      events: [
        series(
          start: '2026-01-31T09:00:00.000',
          end: '2026-01-31T10:00:00.000',
          rule: const GeneralEventRecurrenceRule(
            type: GeneralEventRecurrence.monthly,
            unit: GeneralEventRecurrenceUnit.month,
            count: 5,
          ),
          exceptions: ['2026-04-30'],
        ),
      ],
    );
    for (final action in [
      ResourceMutationAction.patch,
      ResourceMutationAction.copy,
    ]) {
      final draft = Host().compile(base, [
        command(
          action,
          start: '2026-02-28T09:00:00.000',
          scope: GeneralEventEditScope.thisAndFollowing,
          values: {
            'title': 'Monthly suffix',
            'recurrenceRule': {'type': 'monthly', 'count': 4},
            'recurrenceExceptionDates': ['2026-04-30'],
          },
        ),
      ]);
      final suffix = eventById(draft, 'event-1');
      expect(suffix.recurrenceRule.monthlyAnchorDay, 31);
      expect(suffix.recurrenceRule.count, 4);
      expect(suffix.recurrenceExceptionDateIso, ['2026-04-30']);
      final occurrences = GeneralEventOccurrenceRange(
        calendar: draft.candidate.generalMode.schedules.last,
        event: suffix,
        startInclusive: DateTime(2026),
        endExclusive: DateTime(2027),
      );
      expect(occurrences.map((item) => item.exceptionDateIso), [
        '2026-02-28',
        '2026-03-31',
        '2026-05-31',
      ]);
    }
  });

  test(
    'entire edit retains ID and handled reminders for content-only edits',
    () {
      final host = Host();
      final draft = host.compile(fixture(acknowledgements: [ack(5), ack(19)]), [
        command(
          ResourceMutationAction.patch,
          scope: GeneralEventEditScope.entireSeries,
          values: {'notes': 'Updated'},
        ),
      ]);
      expect(eventById(draft, 'series').notes, 'Updated');
      expect(
        eventById(draft, 'series').createdAtIso,
        '2026-10-01T08:00:00.000',
      );
      expect(host.allocated, isEmpty);
      expect(draft.changes, hasLength(1));
      expect(keys(draft), [key(5), key(19)]);
    },
  );

  test(
    'first following edit is the whole series even with later exceptions',
    () {
      final host = Host();
      final draft = host.compile(fixture(), [
        command(
          ResourceMutationAction.patch,
          start: '2026-10-05T09:00:00.000',
          scope: GeneralEventEditScope.thisAndFollowing,
          values: {'title': 'Whole'},
        ),
      ]);
      expect(host.allocated, isEmpty);
      expect(eventById(draft, 'series').recurrenceRule.count, 6);
      expect(eventById(draft, 'series').recurrenceExceptionDateIso, [
        '2026-10-12',
      ]);
    },
  );

  test(
    'single, following and entire copies leave source and reminders intact',
    () {
      for (final scope in GeneralEventEditScope.values) {
        final base = fixture(acknowledgements: [ack(5), ack(19)]);
        final draft = Host().compile(base, [
          command(
            ResourceMutationAction.copy,
            scope: scope,
            destination: 'active',
          ),
        ]);
        final copy = eventById(draft, 'event-1');
        expect(copy.calendarId, 'active');
        expect(copy.recurrenceRule.count, switch (scope) {
          GeneralEventEditScope.thisOccurrence => null,
          GeneralEventEditScope.thisAndFollowing => 4,
          GeneralEventEditScope.entireSeries => 6,
        });
        expect(
          copy.startDateTimeIso,
          scope == GeneralEventEditScope.entireSeries
              ? '2026-10-05T09:00:00.000'
              : '2026-10-19T09:00:00.000',
        );
        expect(copy.reminderBehavior, GeneralEventReminderBehavior.custom);
        expect(
          eventById(draft, 'series').toJson(),
          base.generalMode.schedules.last.events.single.toJson(),
        );
        expect(draft.changes, hasLength(1));
        expect(draft.changes.single.before, isNull);
        expect(keys(draft), [key(5), key(19)]);
        expect(draft.candidate.generalMode.activeScheduleId, 'active');
      }
    },
  );

  test('scope deletions retain only the intended source prefix and keys', () {
    for (final scope in GeneralEventEditScope.values) {
      final base = fixture(acknowledgements: [ack(5), ack(19), ack(26)]);
      final draft = Host().compile(base, [
        command(ResourceMutationAction.delete, scope: scope),
      ]);
      if (scope == GeneralEventEditScope.entireSeries) {
        expect(
          draft.candidate.generalMode.eventLocationsById('series'),
          isEmpty,
        );
        expect(keys(draft), isEmpty);
      } else {
        final event = eventById(draft, 'series');
        expect(event.recurrenceRule.count, 6);
        expect(
          event.recurrenceRule.untilDateIso,
          scope == GeneralEventEditScope.thisAndFollowing ? '2026-10-18' : null,
        );
        expect(
          event.recurrenceExceptionDateIso,
          scope == GeneralEventEditScope.thisOccurrence
              ? ['2026-10-12', '2026-10-19']
              : ['2026-10-12'],
        );
        expect(
          keys(draft),
          scope == GeneralEventEditScope.thisOccurrence
              ? [key(5), key(26)]
              : [key(5)],
        );
      }
      expect(draft.changes.last.key, 'general.reminderAcknowledgements');
      expect(draft.candidate.generalMode.activeScheduleId, 'active');
    }
  });

  test(
    'one-off edits and deletions resolve the exact start under every scope',
    () {
      final event = series(
        rule: const GeneralEventRecurrenceRule(),
        exceptions: [],
      );
      for (final scope in GeneralEventEditScope.values) {
        final base = fixture(events: [event]);
        final host = Host();
        final edit = host.compile(base, [
          command(
            ResourceMutationAction.patch,
            start: event.startDateTimeIso,
            scope: scope,
            values: {'title': 'Edited'},
          ),
        ]);
        expect(host.allocated, isEmpty);
        expect(eventById(edit, 'series').title, 'Edited');
        final deleted = host.compile(base, [
          command(
            ResourceMutationAction.delete,
            start: event.startDateTimeIso,
            scope: scope,
          ),
        ]);
        expect(deleted.candidate.generalMode.schedules.last.events, isEmpty);
      }
    },
  );

  test('moving a scoped edit changes only its selected range and captures both owners', () {
    final draft = Host().compile(fixture(), [
      command(
        ResourceMutationAction.patch,
        scope: GeneralEventEditScope.thisAndFollowing,
        destination: 'active',
        values: {'title': 'Moved'},
      ),
    ]);
    expect(eventById(draft, 'series').calendarId, 'hidden');
    expect(eventById(draft, 'event-1').calendarId, 'active');
    expect(
      draft.changes.map((item) => item.ref?.parentId),
      containsAll(['hidden', 'active']),
    );
  });

  test('exception remapping follows civil candidates when time shifts', () {
    final draft = Host().compile(
      fixture(exceptions: ['2026-10-12', '2026-11-02']),
      [
        command(
          ResourceMutationAction.patch,
          scope: GeneralEventEditScope.thisAndFollowing,
          values: {
            'start': '2026-10-20T11:00:00.000',
            'end': '2026-10-20T12:00:00.000',
          },
        ),
      ],
    );
    expect(eventById(draft, 'series').recurrenceExceptionDateIso, [
      '2026-10-12',
    ]);
    expect(eventById(draft, 'event-1').recurrenceExceptionDateIso, [
      '2026-11-03',
    ]);
  });

  test(
    'frequency change retains matching absolute exceptions and detached events',
    () {
      final base = fixture(
        events: [
          series(exceptions: ['2026-10-12', '2026-11-02']),
          series(
            id: 'detached',
            rule: const GeneralEventRecurrenceRule(),
            exceptions: [],
          ),
        ],
      );
      final draft = Host().compile(base, [
        command(
          ResourceMutationAction.patch,
          scope: GeneralEventEditScope.thisAndFollowing,
          values: {
            'recurrenceRule': {'type': 'daily', 'count': 30},
          },
        ),
      ]);
      expect(eventById(draft, 'event-1').recurrenceExceptionDateIso, [
        '2026-11-02',
      ]);
      expect(
        eventById(draft, 'detached').toJson(),
        base.generalMode.schedules.last.events.last.toJson(),
      );
    },
  );

  test(
    'explicit recurrence metadata is validated and is never silently discarded',
    () {
      final draft = Host().compile(fixture(), [
        command(
          ResourceMutationAction.patch,
          scope: GeneralEventEditScope.entireSeries,
          values: {
            'recurrenceRule': {
              'type': 'monthly',
              'count': 4,
              'monthlyAnchorDay': 7,
            },
            'recurrenceExceptionDates': ['2026-11-07'],
          },
        ),
      ]);
      expect(eventById(draft, 'series').recurrenceRule.monthlyAnchorDay, 7);
      expect(eventById(draft, 'series').recurrenceExceptionDateIso, [
        '2026-11-07',
      ]);
    },
  );

  test('no-op scoped patches neither detach nor allocate identities', () {
    final base = fixture();
    final host = Host();
    for (final scope in GeneralEventEditScope.values) {
      final draft = host.compile(base, [
        command(ResourceMutationAction.patch, scope: scope),
      ]);
      expect(draft.isEmpty, true);
      expect(draft.candidate, same(base));
    }
    expect(host.allocated, isEmpty);
  });

  test('reminder dismissal and restoration use fixed host time and full aux changes', () {
    final base = fixture(acknowledgements: [ack(26)]);
    final host = Host();
    final dismissed = host.compile(base, [
      command(ResourceMutationAction.dismissReminder, scope: null),
    ]);
    expect(dismissed.changes.single.key, 'general.reminderAcknowledgements');
    expect(
      dismissed.candidate.generalMode.reminderAcknowledgements
          .singleWhere((item) => item.occurrenceKey == key(19))
          .updatedAtIso,
      host.now.toIso8601String(),
    );
    final repeated = host.compile(dismissed.candidate, [
      command(ResourceMutationAction.dismissReminder, scope: null),
    ]);
    expect(repeated.isEmpty, true);
    final restored = host.compile(dismissed.candidate, [
      command(ResourceMutationAction.restoreReminder, scope: null),
    ]);
    expect(keys(restored), [key(26)]);
    expect(host.allocated, isEmpty);
  });

  test(
    'reminder actions respect inherited defaults without enabling settings',
    () {
      final inherited = series().copyWith(
        reminderBehavior: GeneralEventReminderBehavior.inherit,
        reminders: [],
      );
      final off = fixture(events: [inherited]);
      expect(
        () => Host().compile(off, [
          command(ResourceMutationAction.dismissReminder, scope: null),
        ]),
        throwsA(problem(OperationErrorCode.invalidArgument, 'target')),
      );
      final on = off.copyWith(
        notificationSettings: const NotificationSettings(
          generalDefaultMinutesBefore: 10,
        ),
      );
      final dismissed = Host().compile(on, [
        command(ResourceMutationAction.dismissReminder, scope: null),
      ]);
      expect(keys(dismissed), [key(19)]);
      expect(dismissed.candidate.notificationSettings.enabled, false);
      final disabledDefault = dismissed.candidate.copyWith(
        notificationSettings: const NotificationSettings(),
      );
      final restored = Host().compile(disabledDefault, [
        command(ResourceMutationAction.restoreReminder, scope: null),
      ]);
      expect(keys(restored), isEmpty);
    },
  );

  test('reminder pruning appears in the candidate diff and retains live other entries', () {
    final base = fixture(
      acknowledgements: [
        ack(5),
        ack(26),
        GeneralReminderAcknowledgement(
          occurrenceKey: buildGeneralOccurrenceKey(
            'hidden',
            'missing',
            '2026-10-19T09:00:00.000',
          ),
          updatedAtIso: '2026-10-19T09:00:00.000',
        ),
      ],
    );
    final draft = Host().compile(base, [
      command(ResourceMutationAction.dismissReminder, scope: null),
    ]);
    expect(keys(draft).toSet(), {key(5), key(19), key(26)});
    expect((draft.changes.single.before as List), hasLength(3));
    expect((draft.changes.single.after as List), hasLength(3));
  });

  test(
    'excluded, out-of-count, UNTIL and noncandidate starts never fall back',
    () {
      for (final start in [
        '2026-10-12T09:00:00.000',
        '2026-11-16T09:00:00.000',
        '2026-10-19T09:01:00.000',
      ]) {
        expect(
          () => Host().compile(fixture(), [
            command(ResourceMutationAction.delete, start: start),
          ]),
          throwsA(problem(OperationErrorCode.notFound)),
        );
      }
      final base = fixture(
        events: [
          series(
            rule: const GeneralEventRecurrenceRule(
              type: GeneralEventRecurrence.weekly,
              untilDateIso: '2026-10-18',
            ),
          ),
        ],
      );
      expect(
        () => Host().compile(base, [command(ResourceMutationAction.copy)]),
        throwsA(problem(OperationErrorCode.notFound)),
      );
    },
  );

  test('legacy keys, noncanonical encodings, time bases and wrong owners are rejected', () {
    final starts = <ResourceRef>[
      const ResourceRef(
        kind: ResourceKind.occurrence,
        id: 'hidden|series|2026-10-19T09:00:00.000',
        parentId: 'hidden',
      ),
      ResourceRef(
        kind: ResourceKind.occurrence,
        id: key(19).replaceFirst('hidden', '%68idden'),
        parentId: 'hidden',
      ),
      ResourceRef(
        kind: ResourceKind.occurrence,
        id: buildGeneralOccurrenceKey(
          'hidden',
          'series',
          '2026-10-19T09:00:00',
        ),
        parentId: 'hidden',
      ),
      ResourceRef(
        kind: ResourceKind.occurrence,
        id: key(19),
        parentId: 'active',
      ),
      ResourceRef(kind: ResourceKind.event, id: key(19), parentId: 'hidden'),
    ];
    for (final ref in starts) {
      expect(
        () => Host().compile(fixture(), [
          ResourceMutation(
            kind: ResourceKind.occurrence,
            action: ResourceMutationAction.delete,
            target: ref,
            scope: GeneralEventEditScope.thisOccurrence,
          ),
        ]),
        throwsA(problem(OperationErrorCode.invalidArgument)),
      );
    }
    final utc = fixture(
      events: [
        series(
          start: '2026-10-05T09:00:00.000Z',
          end: '2026-10-05T10:00:00.000Z',
        ),
      ],
    );
    expect(
      () => Host().compile(utc, [command(ResourceMutationAction.delete)]),
      throwsA(problem(OperationErrorCode.notFound)),
    );
  });

  test(
    'scope, fields, destinations and actions are validated before mutation',
    () {
      final commands = [
        command(ResourceMutationAction.delete, scope: null),
        command(ResourceMutationAction.dismissReminder),
        command(
          ResourceMutationAction.restoreReminder,
          scope: null,
          destination: 'active',
        ),
        command(ResourceMutationAction.delete, values: {'title': 'Bad'}),
        command(ResourceMutationAction.patch, values: {'updatedAt': 'Bad'}),
        command(
          ResourceMutationAction.patch,
          values: {
            'recurrenceRule': {'type': 'daily'},
          },
        ),
        ResourceMutation(
          kind: ResourceKind.event,
          action: ResourceMutationAction.patch,
          target: const ResourceRef(
            kind: ResourceKind.event,
            id: 'series',
            parentId: 'hidden',
          ),
          scope: GeneralEventEditScope.entireSeries,
        ),
        ResourceMutation(
          kind: ResourceKind.event,
          action: ResourceMutationAction.dismissReminder,
          target: const ResourceRef(
            kind: ResourceKind.event,
            id: 'series',
            parentId: 'hidden',
          ),
        ),
      ];
      for (final operation in commands) {
        expect(
          () => Host().compile(fixture(), [operation]),
          throwsA(problem(OperationErrorCode.invalidArgument)),
        );
      }
      expect(
        () => Host().compile(fixture(), [
          command(ResourceMutationAction.copy, destination: 'missing'),
        ]),
        throwsA(problem(OperationErrorCode.notFound)),
      );
      expect(
        () => Host().compile(fixture(), [command(ResourceMutationAction.move)]),
        throwsA(problem(OperationErrorCode.unsupported)),
      );
    },
  );

  test('a batch observes previous occurrence deletions and does not return partial data', () {
    final base = fixture();
    final before = jsonEncode(base.toJson());
    expect(
      () => Host().compile(base, [
        command(ResourceMutationAction.delete),
        command(ResourceMutationAction.copy),
      ]),
      throwsA(problem(OperationErrorCode.notFound)),
    );
    expect(jsonEncode(base.toJson()), before);
  });

  test('host ID collision prevents series splitting or copying', () {
    for (final action in [
      ResourceMutationAction.patch,
      ResourceMutationAction.copy,
    ]) {
      expect(
        () => const ResourceMutationCompiler().compile(
          fixture(),
          [
            command(action, values: {'title': 'Changed'}),
          ],
          context: MutationContext(
            now: DateTime(2026, 10, 30),
            idGenerator: (_) => 'series',
          ),
        ),
        throwsA(problem(OperationErrorCode.conflict, 'generatedId')),
      );
    }
  });

  test('UTC and all-day exact occurrences retain their time and span', () {
    final cases = [
      series(
        start: '2026-10-05T09:00:00.000Z',
        end: '2026-10-06T11:00:00.000Z',
      ),
      series(
        start: '2026-10-05T00:00:00.000',
        end: '2026-10-07T00:00:00.000',
      ).copyWith(isAllDay: true),
    ];
    for (final event in cases) {
      final start = event.isAllDay
          ? '2026-10-19T00:00:00.000'
          : '2026-10-19T09:00:00.000Z';
      final draft = Host().compile(fixture(events: [event]), [
        command(ResourceMutationAction.copy, start: start),
      ]);
      final copied = eventById(draft, 'event-1');
      expect(copied.startDateTimeIso, start);
      expect(
        copied.endDateTimeIso,
        event.isAllDay ? '2026-10-21T00:00:00.000' : '2026-10-20T11:00:00.000Z',
      );
      expect(copied.isAllDay, event.isAllDay);
    }
  });

  test(
    'long-duration daily series resolves exact far-future instances lazily',
    () {
      final event = series(
        start: '0001-01-01T09:00:00.000Z',
        end: '8000-01-01T10:00:00.000Z',
        rule: const GeneralEventRecurrenceRule(
          type: GeneralEventRecurrence.daily,
          unit: GeneralEventRecurrenceUnit.day,
        ),
        exceptions: [],
      );
      final base = fixture(events: [event]);
      final draft = Host().compile(base, [
        command(ResourceMutationAction.copy, start: '2000-01-01T09:00:00.000Z'),
      ]);
      expect(
        eventById(draft, 'event-1').startDateTimeIso,
        '2000-01-01T09:00:00.000Z',
      );
      expect(draft.changes, hasLength(1));
    },
  );
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

ResourceMutation command(
  ResourceMutationAction action, {
  GeneralEventEditScope? scope = GeneralEventEditScope.thisOccurrence,
  String start = '2026-10-19T09:00:00.000',
  String? destination,
  Map<String, Object?> values = const {},
}) => ResourceMutation(
  kind: ResourceKind.occurrence,
  action: action,
  target: ResourceRef(
    kind: ResourceKind.occurrence,
    id: buildGeneralOccurrenceKey('hidden', 'series', start),
    parentId: 'hidden',
  ),
  scope: scope,
  destinationParentId: destination,
  values: values,
);

GeneralEvent eventById(MutationDraft draft, String id) =>
    draft.candidate.generalMode.eventLocationsById(id).single.event;
List<String> keys(MutationDraft draft) => draft
    .candidate
    .generalMode
    .reminderAcknowledgements
    .map((item) => item.occurrenceKey)
    .toList();
String key(int day) => buildGeneralOccurrenceKey(
  'hidden',
  'series',
  '2026-10-${day.toString().padLeft(2, '0')}T09:00:00.000',
);
GeneralReminderAcknowledgement ack(int day) => GeneralReminderAcknowledgement(
  occurrenceKey: key(day),
  updatedAtIso: '2026-10-30T08:00:00.000',
);

AppData fixture({
  List<GeneralEvent>? events,
  List<String> exceptions = const ['2026-10-12'],
  List<GeneralReminderAcknowledgement> acknowledgements = const [],
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
    selectedDateIso: '2026-10-30',
    schedules: [
      GeneralSchedule(id: 'active', name: 'Active', events: []),
      GeneralSchedule(
        id: 'hidden',
        name: 'Hidden',
        isVisible: false,
        sortOrder: 1,
        events: events ?? [series(exceptions: exceptions)],
      ),
    ],
    reminderAcknowledgements: acknowledgements,
  ),
);

GeneralEvent series({
  String id = 'series',
  String start = '2026-10-05T09:00:00.000',
  String end = '2026-10-05T10:00:00.000',
  GeneralEventRecurrenceRule rule = const GeneralEventRecurrenceRule(
    type: GeneralEventRecurrence.weekly,
    count: 6,
  ),
  List<String> exceptions = const ['2026-10-12'],
}) => GeneralEvent(
  id: id,
  calendarId: 'hidden',
  title: 'Series',
  startDateTimeIso: start,
  endDateTimeIso: end,
  recurrenceRule: rule,
  recurrenceExceptionDateIso: exceptions,
  reminders: const [GeneralEventReminder(minutesBefore: 10)],
  createdAtIso: '2026-10-01T08:00:00.000',
  updatedAtIso: '2026-10-01T08:00:00.000',
);

Matcher problem(OperationErrorCode code, [String? field]) =>
    isA<OperationProblem>()
        .having((item) => item.code, 'code', code)
        .having(
          (item) => field == null || item.field == field,
          'field matches',
          true,
        );
