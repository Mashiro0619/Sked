import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/application/mutation_undo.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/application/resource_contracts.dart';
import 'package:sked/application/resource_mutations.dart';
import 'package:sked/application/setting_registry.dart';
import 'package:sked/models/application_ledger.dart';
import 'package:sked/models/timetable_models.dart';

void main() {
  test(
    'undoing creation retains later changes to other events and settings',
    () {
      final base = fixture();
      final applied = apply(base, [
        mutation(
          ResourceKind.event,
          ResourceMutationAction.copy,
          'first',
          parent: 'a',
        ),
      ]);
      final later = apply(
        applied.data,
        [
          mutation(
            ResourceKind.event,
            ResourceMutationAction.patch,
            'other',
            parent: 'b',
            values: {'notes': 'Later'},
          ),
        ],
        settings: [const SettingEdit.set('general.showWeekends', false)],
      );
      final undo = MutationUndoCompiler().prepare(later.data, applied.receipt);
      expect(findEvent(undo.candidate, 'generated-1'), isNull);
      expect(findEvent(undo.candidate, 'other')!.notes, 'Later');
      expect(undo.candidate.generalMode.showWeekends, false);
      expect(undo.changes.single.before, isNotNull);
      expect(undo.changes.single.after, isNull);
      expect(findEvent(later.data, 'generated-1'), isNotNull);
    },
  );

  test('undoing multiple deletions restores original list positions', () {
    final base = fixture();
    final applied = apply(base, [
      mutation(
        ResourceKind.event,
        ResourceMutationAction.delete,
        'first',
        parent: 'a',
      ),
      mutation(
        ResourceKind.event,
        ResourceMutationAction.delete,
        'last',
        parent: 'a',
      ),
    ]);
    final undo = MutationUndoCompiler().prepare(applied.data, applied.receipt);
    expect(
      undo.candidate.generalMode.schedules.first.events.map((item) => item.id),
      ['first', 'middle', 'last'],
    );
    expect(undo.candidate.toJson(), base.toJson());
    expect(undo.changes, hasLength(2));
  });

  test(
    'undoing an edit restores original fields without changing siblings',
    () {
      final base = fixture();
      final applied = apply(base, [
        mutation(
          ResourceKind.event,
          ResourceMutationAction.patch,
          'middle',
          parent: 'a',
          values: {
            'title': 'Edited',
            'start': '2026-10-06T15:00:00.000',
            'end': '2026-10-06T16:00:00.000',
          },
        ),
      ]);
      final later = apply(applied.data, [
        mutation(
          ResourceKind.event,
          ResourceMutationAction.patch,
          'last',
          parent: 'a',
          values: {'notes': 'Keep later'},
        ),
      ]);
      final undo = MutationUndoCompiler().prepare(later.data, applied.receipt);
      expect(
        findEvent(undo.candidate, 'middle')!.toJson(),
        findEvent(base, 'middle')!.toJson(),
      );
      expect(findEvent(undo.candidate, 'last')!.notes, 'Keep later');
      expect(
        undo.candidate.generalMode.schedules.first.events.map(
          (item) => item.id,
        ),
        ['first', 'middle', 'last'],
      );
    },
  );

  test('undoing an event move restores both owner lists', () {
    final base = fixture();
    final applied = apply(base, [
      mutation(
        ResourceKind.event,
        ResourceMutationAction.move,
        'middle',
        parent: 'a',
        destination: 'b',
      ),
    ]);
    final undo = MutationUndoCompiler().prepare(applied.data, applied.receipt);
    expect(undo.candidate.toJson(), base.toJson());
    expect(undo.changes.map((change) => change.ref!.parentId).toSet(), {
      'a',
      'b',
    });
  });

  test(
    'undoing a calendar deletion restores nested events, order and reminders',
    () {
      final base = fixture(reminders: true);
      final applied = apply(base, [
        mutation(ResourceKind.calendar, ResourceMutationAction.delete, 'a'),
      ]);
      final undo = MutationUndoCompiler().prepare(
        applied.data,
        applied.receipt,
      );
      expect(undo.candidate.toJson(), base.toJson());
      expect(
        undo.changes.map((change) => change.key),
        containsAll([
          'general.activeScheduleId',
          'general.reminderAcknowledgements',
        ]),
      );
    },
  );

  test(
    'undoing deletion of the last calendar removes the generated replacement',
    () {
      final base = fixture(singleCalendar: true);
      final applied = apply(base, [
        mutation(ResourceKind.calendar, ResourceMutationAction.delete, 'a'),
      ]);
      expect(applied.data.generalMode.schedules.single.id, 'generated-1');
      final undo = MutationUndoCompiler().prepare(
        applied.data,
        applied.receipt,
      );
      expect(undo.candidate.toJson(), base.toJson());
    },
  );

  test('restored calendar positions retain calendars added later', () {
    final base = fixture();
    final applied = apply(base, [
      mutation(ResourceKind.calendar, ResourceMutationAction.delete, 'a'),
    ]);
    final later = applied.data.copyWith(
      generalMode: applied.data.generalMode.copyWith(
        schedules: [
          ...applied.data.generalMode.schedules,
          GeneralSchedule(
            id: 'later',
            name: 'Keep later',
            sortOrder: 1,
            events: [event('later-event', 'later')],
          ),
        ],
      ),
    );
    final undo = MutationUndoCompiler().prepare(later, applied.receipt);
    expect(
      undo.candidate.generalMode.schedules.map((calendar) => calendar.id),
      ['a', 'b', 'later'],
    );
    expect(undo.candidate.generalMode.schedules.last.name, 'Keep later');
    expect(
      undo.candidate.generalMode.schedules.last.events.single.id,
      'later-event',
    );
    expect(undo.candidate.generalMode.schedules.last.sortOrder, 2);
    final shifted = undo.changes.singleWhere(
      (change) => change.ref?.id == 'later',
    );
    expect((shifted.before as Map)['sortOrder'], 1);
    expect((shifted.after as Map)['sortOrder'], 2);
  });

  test(
    'scoped occurrence edits reverse series, detached event and reminder state',
    () {
      final initial = fixture(reminders: true);
      final base = initial.copyWith(
        generalMode: initial.generalMode.copyWith(
          schedules: [
            initial.generalMode.schedules.first.copyWith(
              events: [
                initial.generalMode.schedules.first.events.first.copyWith(
                  recurrenceRule: const GeneralEventRecurrenceRule(
                    type: GeneralEventRecurrence.weekly,
                    count: 4,
                  ),
                ),
                ...initial.generalMode.schedules.first.events.skip(1),
              ],
            ),
            initial.generalMode.schedules.last,
          ],
        ),
      );
      final applied = apply(base, [
        ResourceMutation(
          kind: ResourceKind.occurrence,
          action: ResourceMutationAction.patch,
          target: ResourceRef(
            kind: ResourceKind.occurrence,
            id: buildGeneralOccurrenceKey(
              'a',
              'first',
              '2026-10-05T09:00:00.000',
            ),
            parentId: 'a',
          ),
          scope: GeneralEventEditScope.thisOccurrence,
          values: {'title': 'Detached'},
        ),
      ]);
      expect(findEvent(applied.data, 'generated-1'), isNotNull);
      expect(applied.data.generalMode.reminderAcknowledgements, isEmpty);
      final undo = MutationUndoCompiler().prepare(
        applied.data,
        applied.receipt,
      );
      expect(undo.candidate.toJson(), base.toJson());
    },
  );

  test(
    'undoing timetable deletion restores courses and derived color entries',
    () {
      final base = fixture();
      final applied = apply(base, [
        mutation(
          ResourceKind.timetable,
          ResourceMutationAction.delete,
          'table-a',
        ),
      ]);
      final undo = MutationUndoCompiler().prepare(
        applied.data,
        applied.receipt,
      );
      expect(undo.candidate.toJson(), base.toJson());
      expect(
        undo.changes.map((change) => change.key),
        contains('student.courseNameColorValues'),
      );
    },
  );

  test('course movement and period set deletion can be reversed together', () {
    final base = fixture();
    final applied = apply(base, [
      mutation(
        ResourceKind.course,
        ResourceMutationAction.move,
        'course-first',
        parent: 'table-a',
        destination: 'table-b',
      ),
      mutation(
        ResourceKind.periodTimeSet,
        ResourceMutationAction.delete,
        'unused',
      ),
    ]);
    final undo = MutationUndoCompiler().prepare(applied.data, applied.receipt);
    expect(undo.candidate.toJson(), base.toJson());
  });

  test(
    'entire copied calendars and timetables are removed as complete objects',
    () {
      for (final kind in [ResourceKind.calendar, ResourceKind.timetable]) {
        final base = fixture();
        final applied = apply(base, [
          mutation(
            kind,
            ResourceMutationAction.copy,
            kind == ResourceKind.calendar ? 'a' : 'table-a',
          ),
        ]);
        final undo = MutationUndoCompiler().prepare(
          applied.data,
          applied.receipt,
        );
        expect(undo.candidate.toJson(), base.toJson());
      }
    },
  );

  test('nullable settings reverse to absent defaults and preserve unrelated values', () {
    final base = fixture();
    final applied = apply(
      base,
      [],
      settings: [
        const SettingEdit.set('app.ignoredUpdateVersion', '9.0.0'),
        const SettingEdit.set(
          'app.notifications.generalDefaultMinutesBefore',
          20,
        ),
        const SettingEdit.set('general.customDayMinWidth', 256),
        const SettingEdit.set('app.workspacePanelDisplayMode', 'sideBySide'),
        const SettingEdit.set('app.hideHomeWorkspaceNavigation', true),
      ],
    );
    final later = apply(
      applied.data,
      [],
      settings: [const SettingEdit.set('student.showFutureCourses', false)],
    );
    final undo = MutationUndoCompiler().prepare(later.data, applied.receipt);
    expect(undo.candidate.ignoredUpdateVersion, isNull);
    expect(
      undo.candidate.notificationSettings.generalDefaultMinutesBefore,
      isNull,
    );
    expect(undo.candidate.generalMode.customDayMinWidth, isNull);
    expect(
      undo.candidate.workspacePanelDisplayMode,
      WorkspacePanelDisplayMode.overlay,
    );
    expect(undo.candidate.hideHomeWorkspaceNavigation, false);
    expect(undo.candidate.studentMode.showFutureCourses, false);
    expect(undo.candidate.toJson().containsKey('notificationSettings'), false);
  });

  test('setting reset can be reversed to the saved non-default value', () {
    final first = apply(
      fixture(),
      [],
      settings: [
        const SettingEdit.set(
          'app.notifications.courseDefaultMinutesBefore',
          15,
        ),
      ],
    );
    final reset = apply(
      first.data,
      [],
      settings: [
        const SettingEdit.reset('app.notifications.courseDefaultMinutesBefore'),
      ],
    );
    final undo = MutationUndoCompiler().prepare(reset.data, reset.receipt);
    expect(undo.candidate.notificationSettings.courseDefaultMinutesBefore, 15);
  });

  test('derived read-only outline flags reverse with their owning setting', () {
    final base = fixture();
    final applied = apply(
      base,
      [],
      settings: [
        const SettingEdit.set(
          'student.liveCourseOutlineColorValue',
          0xff987654,
        ),
      ],
    );
    expect(
      applied.data.studentMode.liveCourseOutlineCustomColorInitialized,
      true,
    );
    final undo = MutationUndoCompiler().prepare(applied.data, applied.receipt);
    expect(undo.candidate.toJson(), base.toJson());
    expect(
      undo.candidate.studentMode.liveCourseOutlineCustomColorInitialized,
      false,
    );
  });

  test(
    'changed target or settings cause conflict without partial reversal',
    () {
      final base = fixture();
      final applied = apply(
        base,
        [
          mutation(
            ResourceKind.event,
            ResourceMutationAction.patch,
            'first',
            parent: 'a',
            values: {'title': 'Earlier'},
          ),
        ],
        settings: [const SettingEdit.set('general.showWeekends', false)],
      );
      final cases = [
        apply(applied.data, [
          mutation(
            ResourceKind.event,
            ResourceMutationAction.patch,
            'first',
            parent: 'a',
            values: {'notes': 'Later'},
          ),
        ]).data,
        apply(
          applied.data,
          [],
          settings: [const SettingEdit.set('general.showWeekends', true)],
        ).data,
      ];
      for (final data in cases) {
        final before = jsonEncode(data.toJson());
        expect(
          () => MutationUndoCompiler().prepare(data, applied.receipt),
          throwsA(problem(OperationErrorCode.conflict)),
        );
        expect(jsonEncode(data.toJson()), before);
      }
    },
  );

  test(
    'changed child of a complete owner snapshot prevents overwriting it',
    () {
      final base = fixture();
      final applied = apply(base, [
        mutation(
          ResourceKind.calendar,
          ResourceMutationAction.patch,
          'a',
          values: {'name': 'Renamed'},
        ),
      ]);
      final later = apply(applied.data, [
        mutation(
          ResourceKind.event,
          ResourceMutationAction.patch,
          'first',
          parent: 'a',
          values: {'notes': 'New data'},
        ),
      ]);
      expect(
        () => MutationUndoCompiler().prepare(later.data, applied.receipt),
        throwsA(problem(OperationErrorCode.conflict)),
      );
    },
  );

  test(
    'restoring a deleted child rejects a missing original owner or reused ID',
    () {
      final base = fixture();
      final applied = apply(base, [
        mutation(
          ResourceKind.event,
          ResourceMutationAction.delete,
          'first',
          parent: 'a',
        ),
      ]);
      final missing = apply(applied.data, [
        mutation(ResourceKind.calendar, ResourceMutationAction.delete, 'a'),
      ]);
      expect(
        () => MutationUndoCompiler().prepare(missing.data, applied.receipt),
        throwsA(problem(OperationErrorCode.conflict)),
      );
      final reused = applied.data.copyWith(
        generalMode: applied.data.generalMode.copyWith(
          schedules: [
            applied.data.generalMode.schedules.first,
            applied.data.generalMode.schedules.last.copyWith(
              events: [
                ...applied.data.generalMode.schedules.last.events,
                event('first', 'b'),
              ],
            ),
          ],
        ),
      );
      expect(
        () => MutationUndoCompiler().prepare(reused, applied.receipt),
        throwsA(problem(OperationErrorCode.conflict)),
      );
    },
  );

  test('deleting a created time set rejects later timetable references', () {
    final base = fixture();
    final applied = apply(base, [
      mutation(ResourceKind.periodTimeSet, ResourceMutationAction.copy, 'day'),
    ]);
    final later = apply(applied.data, [
      mutation(
        ResourceKind.timetable,
        ResourceMutationAction.patch,
        'table-b',
        values: {'periodTimeSetId': 'generated-1'},
      ),
    ]);
    expect(
      () => MutationUndoCompiler().prepare(later.data, applied.receipt),
      throwsA(problem(OperationErrorCode.conflict)),
    );
  });

  test(
    'matching parent snapshots absorb duplicate children and auxiliary records',
    () {
      final base = fixture();
      final applied = apply(
        base,
        [
          mutation(
            ResourceKind.calendar,
            ResourceMutationAction.patch,
            'a',
            values: {'name': 'New'},
          ),
          mutation(
            ResourceKind.event,
            ResourceMutationAction.patch,
            'first',
            parent: 'a',
            values: {'title': 'New title'},
          ),
        ],
        settings: [const SettingEdit.set('general.showWeekends', false)],
      );
      final rows = List<Object?>.of(applied.receipt.undo!['changes'] as List);
      rows.add({
        ...ResourceChange(
          key: 'resource:event:a:first',
          ref: const ResourceRef(
            kind: ResourceKind.event,
            id: 'first',
            parentId: 'a',
          ),
          before: findEvent(base, 'first')!.toJson(),
          after: findEvent(applied.data, 'first')!.toJson(),
        ).toJson(),
        'beforeIndex': 0,
      });
      rows.add(rows.last);
      rows.add(
        rows.firstWhere((row) => (row as Map)['key'] == 'general.showWeekends'),
      );
      final undo = MutationUndoCompiler().prepare(applied.data, receipt(rows));
      expect(undo.changes, hasLength(2));
      expect(undo.candidate.toJson(), base.toJson());
    },
  );

  test('inconsistent duplicates and parent-child snapshots are rejected', () {
    final base = fixture();
    final applied = apply(base, [
      mutation(
        ResourceKind.calendar,
        ResourceMutationAction.patch,
        'a',
        values: {'name': 'New'},
      ),
    ]);
    final parent = (applied.receipt.undo!['changes'] as List).single as Map;
    final child = {
      ...ResourceChange(
        key: 'resource:event:a:first',
        ref: const ResourceRef(
          kind: ResourceKind.event,
          id: 'first',
          parentId: 'a',
        ),
        before: findEvent(base, 'first')!.copyWith(title: 'Forged').toJson(),
        after: findEvent(applied.data, 'first')!.toJson(),
      ).toJson(),
      'beforeIndex': 0,
    };
    expect(
      () => MutationUndoCompiler().prepare(
        applied.data,
        receipt([parent, child]),
      ),
      throwsA(problem(OperationErrorCode.invalidArgument)),
    );
    final duplicate = {...parent, 'beforeIndex': 1};
    expect(
      () => MutationUndoCompiler().prepare(
        applied.data,
        receipt([parent, duplicate]),
      ),
      throwsA(problem(OperationErrorCode.invalidArgument)),
    );
  });

  test(
    'unknown paths and read-only or adapter settings cannot be reversed',
    () {
      for (final key in [
        'general.showWeekends.bad',
        'general.schedules',
        '/generalMode/schedules/0/name',
        'app.agentSettings',
        'app.activeMode',
        'app.availableUpdateVersion',
        'legacy.parser.customPrompt',
        'device.schoolSites',
        'resource:event:a:first',
      ]) {
        expect(
          () => MutationUndoCompiler().prepare(
            fixture(),
            receipt([
              {'key': key, 'before': null, 'after': null},
            ]),
          ),
          throwsA(problem(OperationErrorCode.invalidArgument)),
          reason: key,
        );
      }
    },
  );

  test('malformed resource references and list positions are rejected', () {
    final base = fixture();
    final applied = apply(base, [
      mutation(
        ResourceKind.event,
        ResourceMutationAction.delete,
        'first',
        parent: 'a',
      ),
    ]);
    final row = (applied.receipt.undo!['changes'] as List).single as Map;
    final bad = [
      {...row}..remove('beforeIndex'),
      {...row, 'beforeIndex': -1},
      {...row, 'key': 'resource:event:b:first'},
      {
        ...row,
        'ref': {'kind': 'event', 'id': 'first'},
      },
      {
        ...row,
        'ref': {'kind': 'occurrence', 'id': 'first', 'parentId': 'a'},
      },
      {
        ...row,
        'before': {...row['before'] as Map, 'id': 'other'},
      },
      {...row}..remove('after'),
    ];
    for (final value in bad) {
      expect(
        () => MutationUndoCompiler().prepare(applied.data, receipt([value])),
        throwsA(problem(OperationErrorCode.invalidArgument)),
      );
    }
  });

  test('missing undo is unsupported and empty undo is a pure no-op', () {
    final base = fixture();
    final noUndo = OperationReceipt(
      operationId: 'receipt',
      sequence: 1,
      commandDigest: '0' * 64,
      completedAtIso: '2026-10-30T00:00:00.000Z',
      result: const {},
    );
    expect(
      () => MutationUndoCompiler().prepare(base, noUndo),
      throwsA(problem(OperationErrorCode.unsupported)),
    );
    final empty = MutationUndoCompiler().prepare(base, receipt([]));
    expect(empty.isEmpty, true);
    expect(empty.candidate, same(base));
  });
}

({AppData data, OperationReceipt receipt}) apply(
  AppData before,
  List<ResourceMutation> commands, {
  List<SettingEdit> settings = const [],
}) {
  var nextId = 0;
  final resources = const ResourceMutationCompiler().compile(
    before,
    commands,
    context: MutationContext(
      now: DateTime.utc(2026, 10, 30),
      idGenerator: (_) => 'generated-${++nextId}',
    ),
  );
  final settingDraft = SettingRegistry().prepare(resources.candidate, settings);
  final byKey = <String, ResourceChange>{};
  for (final change in [
    ...resources.changes,
    for (final change in settingDraft.changes)
      ResourceChange(
        key: change.key,
        before: change.before,
        after: change.after,
      ),
  ]) {
    final prior = byKey[change.key];
    byKey[change.key] = ResourceChange(
      key: change.key,
      ref: change.ref ?? prior?.ref,
      before: prior?.before ?? change.before,
      after: change.after,
    );
  }
  return (
    data: settingDraft.candidate,
    receipt: receipt([
      for (final change in byKey.values)
        {
          ...change.toJson(),
          if (change.ref != null)
            'beforeIndex': resourceIndex(before, change.ref!),
        },
    ]),
  );
}

OperationReceipt receipt(List<Object?> changes) => OperationReceipt(
  operationId: 'receipt',
  sequence: 1,
  commandDigest: '0' * 64,
  completedAtIso: '2026-10-30T00:00:00.000Z',
  result: const {'status': 'committed'},
  undo: {'changes': changes},
);

ResourceMutation mutation(
  ResourceKind kind,
  ResourceMutationAction action,
  String id, {
  String? parent,
  String? destination,
  Map<String, Object?> values = const {},
}) => ResourceMutation(
  kind: kind,
  action: action,
  target: ResourceRef(kind: kind, id: id, parentId: parent),
  destinationParentId: destination,
  values: values,
);

GeneralEvent? findEvent(AppData data, String id) =>
    data.generalMode.eventLocationsById(id).firstOrNull?.event;

int? resourceIndex(AppData data, ResourceRef ref) {
  final ids = switch (ref.kind) {
    ResourceKind.calendar => data.generalMode.schedules.map((item) => item.id),
    ResourceKind.event =>
      data.generalMode.schedules
          .singleWhere((item) => item.id == ref.parentId)
          .events
          .map((item) => item.id),
    ResourceKind.timetable => data.studentMode.timetables.map(
      (item) => item.id,
    ),
    ResourceKind.course =>
      data.studentMode.timetables
          .singleWhere((item) => item.id == ref.parentId)
          .courses
          .map((item) => item.id),
    ResourceKind.periodTimeSet => data.studentMode.periodTimeSets.map(
      (item) => item.id,
    ),
    ResourceKind.occurrence => const <String>[],
  };
  final index = ids.toList().indexOf(ref.id);
  return index < 0 ? null : index;
}

AppData fixture({bool reminders = false, bool singleCalendar = false}) {
  final courses = [
    course('course-first', 'Math'),
    course('course-last', 'Physics'),
  ];
  final data = AppData(
    activeMode: AppMode.general,
    enabledWorkspaces: {AppMode.general},
    generalMode: GeneralScheduleData(
      activeScheduleId: 'a',
      selectedDateIso: '2026-10-30',
      schedules: [
        GeneralSchedule(
          id: 'a',
          name: 'A',
          events: [
            event('first', 'a', reminders: reminders),
            event('middle', 'a'),
            event('last', 'a'),
          ],
        ),
        if (!singleCalendar)
          GeneralSchedule(
            id: 'b',
            name: 'B',
            sortOrder: 1,
            events: [event('other', 'b')],
          ),
      ],
      reminderAcknowledgements: reminders
          ? [
              GeneralReminderAcknowledgement(
                occurrenceKey: buildGeneralOccurrenceKey(
                  'a',
                  'first',
                  '2026-10-05T09:00:00.000',
                ),
                updatedAtIso: '2026-10-30T08:00:00.000',
              ),
            ]
          : [],
    ),
    studentMode: StudentModeData(
      activeTimetableId: 'table-a',
      timetables: [table('table-a', courses), table('table-b', [])],
      periodTimeSets: const [
        PeriodTimeSet(
          id: 'day',
          name: 'Day',
          periodTimes: [
            CoursePeriodTime(index: 1, startMinutes: 480, endMinutes: 525),
          ],
        ),
        PeriodTimeSet(
          id: 'unused',
          name: 'Unused',
          periodTimes: [
            CoursePeriodTime(index: 1, startMinutes: 600, endMinutes: 645),
          ],
        ),
      ],
      courseNameColorValues: {
        for (final course in courses) course.name: 0xff123456,
      },
    ),
  );
  return AppData.decodeStorageSnapshot(data.encode());
}

GeneralEvent event(String id, String parent, {bool reminders = false}) =>
    GeneralEvent(
      id: id,
      calendarId: parent,
      title: id,
      startDateTimeIso: '2026-10-05T09:00:00.000',
      endDateTimeIso: '2026-10-05T10:00:00.000',
      reminders: reminders
          ? const [GeneralEventReminder(minutesBefore: 10)]
          : const [],
    );
TimetableData table(String id, List<CourseItem> courses) => TimetableData(
  id: id,
  config: TimetableConfig(
    name: id,
    startDate: DateTime(2026, 10, 5),
    totalWeeks: 8,
    periodTimeSetId: 'day',
  ),
  courses: courses,
);
CourseItem course(String id, String name) => CourseItem(
  id: id,
  name: name,
  teacher: '',
  location: '',
  dayOfWeek: 1,
  semesterWeeks: const [1, 2],
  periods: const [1],
  startMinutes: 0,
  endMinutes: 0,
  timeRange: buildTimeRange(0, 0),
  credit: 0,
  remarks: '',
  customFields: const {},
);
Matcher problem(OperationErrorCode code) =>
    isA<OperationProblem>().having((error) => error.code, 'code', code);
