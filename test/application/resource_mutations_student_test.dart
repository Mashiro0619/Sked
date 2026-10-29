import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/application/resource_contracts.dart';
import 'package:sked/application/resource_mutations.dart';
import 'package:sked/models/timetable_models.dart';

Matcher problem(OperationErrorCode code) =>
    isA<OperationProblem>().having((error) => error.code, 'code', code);

void main() {
  test(
    'shrinking or rebinding time sets cannot strand existing course periods',
    () {
      final initial = fixture(
        courses: [
          course('c', periods: [2]),
        ],
      );
      final base = initial.copyWith(
        studentMode: initial.studentMode.copyWith(
          periodTimeSets: [
            for (final set in initial.studentMode.periodTimeSets)
              if (set.id == 'day')
                set.copyWith(
                  periodTimes: [
                    ...set.periodTimes,
                    const CoursePeriodTime(
                      index: 2,
                      startMinutes: 540,
                      endMinutes: 585,
                    ),
                  ],
                )
              else
                set,
          ],
        ),
      );
      final shrink = ResourceMutation(
        kind: ResourceKind.periodTimeSet,
        action: ResourceMutationAction.patch,
        target: const ResourceRef(kind: ResourceKind.periodTimeSet, id: 'day'),
        values: {
          'periodTimes': [
            base.studentMode.periodTimeSets.first.periodTimes.first.toJson(),
          ],
        },
      );
      expect(
        () => compile(base, [shrink]),
        throwsA(problem(OperationErrorCode.conflict)),
      );
      expect(
        () => compile(base, [
          ResourceMutation(
            kind: ResourceKind.timetable,
            action: ResourceMutationAction.patch,
            target: const ResourceRef(kind: ResourceKind.timetable, id: 'a'),
            values: {'periodTimeSetId': 'alternative'},
          ),
        ]),
        throwsA(problem(OperationErrorCode.conflict)),
      );
      final adjusted = compile(base, [
        coursePatch('c', {
          'periods': [1],
        }),
        shrink,
      ]);
      expect(courseById(adjusted.candidate, 'c').periods, [1]);
      expect(
        adjusted.candidate.studentMode.periodTimeSets.first.periodTimes,
        hasLength(1),
      );
    },
  );

  test(
    'creates a course in a non-active disabled timetable using linked periods',
    () {
      final base = fixture();
      final before = jsonEncode(base.toJson());
      final draft = compile(base, [
        ResourceMutation(
          kind: ResourceKind.course,
          action: ResourceMutationAction.create,
          destinationParentId: 'b',
          values: {
            'name': 'New course',
            'dayOfWeek': 2,
            'semesterWeeks': [3, 1],
            'periods': [1],
          },
        ),
      ]);
      final created = courseById(draft.candidate, 'course-1');
      expect(created.semesterWeeks, [1, 3]);
      expect(created.startMinutes, 0);
      expect(created.endMinutes, 0);
      expect(
        resolveCourseTimeRange(
          created,
          draft.candidate.studentMode.periodTimeSets.first.periodTimes,
        ),
        (startMinutes: 480, endMinutes: 525),
      );
      expect(draft.candidate.studentMode.activeTimetableId, 'a');
      expect(draft.candidate.activeMode, AppMode.general);
      expect(draft.candidate.enabledWorkspaces, {AppMode.general});
      expect(identical(draft.candidate.generalMode, base.generalMode), true);
      expect(
        draft.changes.first.ref,
        const ResourceRef(
          kind: ResourceKind.course,
          id: 'course-1',
          parentId: 'b',
        ),
      );
      expect(draft.changes.last.key, 'student.courseNameColorValues');
      expect(jsonEncode(base.toJson()), before);
    },
  );

  test(
    'course content edits preserve legacy empty weeks and unknown raw time',
    () {
      final base = fixture(courses: [course('c', weeks: [])]);
      final before = courseById(base, 'c');
      final draft = compile(base, [
        coursePatch('c', {'teacher': 'New teacher'}),
      ]);
      final updated = courseById(draft.candidate, 'c');
      expect(updated.semesterWeeks, isEmpty);
      expect(updated.startMinutes, 0);
      expect(updated.endMinutes, 0);
      expect(updated.timeRange, before.timeRange);
      expect(updated.periods, before.periods);
      expect(updated.reminderSettings, before.reminderSettings);
      expect(
        () => compile(base, [
          coursePatch('c', {'semesterWeeks': []}),
        ]),
        throwsA(problem(OperationErrorCode.invalidArgument)),
      );
    },
  );

  test('ordinary course patch may preserve legacy unresolved time', () {
    final base = fixture(courses: [course('c', periods: [])]);
    final draft = compile(base, [
      coursePatch('c', {'remarks': 'Keep historical source'}),
    ]);
    expect(courseById(draft.candidate, 'c').periods, isEmpty);
    expect(courseById(draft.candidate, 'c').startMinutes, 0);
    expect(
      () => compile(base, [
        coursePatch('c', {'endMinutes': 600}),
      ]),
      throwsA(problem(OperationErrorCode.invalidArgument)),
    );
    expect(
      () => compile(base, [
        coursePatch('c', {'periods': []}),
      ]),
      throwsA(problem(OperationErrorCode.invalidArgument)),
    );
  });

  test(
    'course patch preserves existing list order without unrelated changes',
    () {
      final base = fixture(courses: [course('first'), course('second')]);
      final draft = compile(base, [
        coursePatch('first', {'teacher': 'Edited'}),
      ]);
      expect(tableById(draft.candidate, 'a').courses.map((item) => item.id), [
        'first',
        'second',
      ]);
      expect(draft.changes, hasLength(1));
      expect(draft.changes.single.ref, courseRef('first'));
    },
  );

  test(
    'explicit course times and custom JSON can be changed without inference',
    () {
      final draft = compile(fixture(courses: [course('c')]), [
        coursePatch('c', {
          'startMinutes': 600,
          'endMinutes': 645,
          'credit': -0.5,
          'customFields': {
            'nested': [
              true,
              null,
              {'language': 'Dart'},
            ],
          },
          'reminderSettings': {'behavior': 'custom', 'minutesBefore': 0},
        }),
      ]);
      final updated = courseById(draft.candidate, 'c');
      expect(updated.startMinutes, 600);
      expect(updated.endMinutes, 645);
      expect(updated.timeRange, buildTimeRange(600, 645));
      expect(updated.credit, -0.5);
      expect(updated.reminderSettings.minutesBefore, 0);
      expect(updated.customFields['nested'], [
        true,
        null,
        {'language': 'Dart'},
      ]);
      expect(
        () => (updated.customFields['nested'] as List).clear(),
        throwsUnsupportedError,
      );
    },
  );

  test(
    'course fields reject unknown keys, invalid numbers, weeks and reminders',
    () {
      final base = fixture(courses: [course('c')]);
      for (final values in <Map<String, Object?>>[
        {'name': ''},
        {'dayOfWeek': 8},
        {'dayOfWeek': 1.0},
        {'teacher': null},
        {
          'semesterWeeks': [1, 1],
        },
        {
          'semesterWeeks': [0],
        },
        {
          'semesterWeeks': [101],
        },
        {
          'periods': [2],
        },
        {
          'periods': [1, 1],
        },
        {'startMinutes': -1},
        {'endMinutes': 1440},
        {'startMinutes': 600, 'endMinutes': 599},
        {'credit': '1'},
        {'customFields': []},
        {'timeRange': '09:00 - 10:00'},
        {'id': 'another'},
        {
          'reminderSettings': {'behavior': 'custom'},
        },
        {
          'reminderSettings': {'behavior': 'disabled', 'minutesBefore': 5},
        },
        {
          'reminderSettings': {'behavior': 'inherit', 'unknown': true},
        },
      ]) {
        expect(
          () => compile(base, [coursePatch('c', values)]),
          throwsA(problem(OperationErrorCode.invalidArgument)),
          reason: '$values',
        );
      }
    },
  );

  test('course targets do not fall back to active timetable', () {
    final base = fixture(courses: [course('c')]);
    expect(
      () => compile(base, [
        coursePatch('c', {'name': 'Wrong owner'}, parent: 'b'),
      ]),
      throwsA(problem(OperationErrorCode.notFound)),
    );
    expect(
      () => compile(base, [
        coursePatch('c', {'name': 'Missing owner'}, parent: 'gone'),
      ]),
      throwsA(problem(OperationErrorCode.notFound)),
    );
    expect(
      () => compile(base, [
        ResourceMutation(
          kind: ResourceKind.course,
          action: ResourceMutationAction.create,
          values: {'name': 'No owner'},
        ),
      ]),
      throwsA(problem(OperationErrorCode.invalidArgument)),
    );
  });

  test(
    'course move retains custom color and records both scoped resources',
    () {
      final base = fixture(
        courses: [course('c')],
        colors: {'Math': 0xff102030},
      );
      final draft = compile(base, [
        ResourceMutation(
          kind: ResourceKind.course,
          action: ResourceMutationAction.move,
          target: courseRef('c'),
          destinationParentId: 'b',
        ),
      ]);
      expect(tableById(draft.candidate, 'a').courses, isEmpty);
      expect(tableById(draft.candidate, 'b').courses.single.id, 'c');
      expect(draft.candidate.studentMode.courseNameColorValues, {
        'Math': 0xff102030,
      });
      expect(draft.candidate.studentMode.activeTimetableId, 'a');
      expect(draft.changes.map((change) => change.key), [
        'resource:course:a:c',
        'resource:course:b:c',
      ]);
      expect(draft.changes.first.after, isNull);
      expect(draft.changes.last.before, isNull);
    },
  );

  test(
    'course copy allocates a new ID and keeps source and semester weeks',
    () {
      final base = fixture(
        courses: [
          course('c', weeks: [1, 8]),
        ],
      );
      final draft = compile(base, [
        ResourceMutation(
          kind: ResourceKind.course,
          action: ResourceMutationAction.copy,
          target: courseRef('c'),
          destinationParentId: 'b',
        ),
      ]);
      expect(
        tableById(draft.candidate, 'a').courses.single.toJson(),
        courseById(base, 'c').toJson(),
      );
      final copy = tableById(draft.candidate, 'b').courses.single;
      expect(copy.id, 'course-1');
      expect(copy.semesterWeeks, [1, 8]);
      expect(draft.candidate.studentMode.activeTimetableId, 'a');
    },
  );

  test('moving a period-based course cannot silently lose a linked period', () {
    final initial = fixture(
      courses: [
        course('c', periods: [1, 2]),
      ],
    );
    final base = initial.copyWith(
      studentMode: initial.studentMode.copyWith(
        timetables: [
          tableById(initial, 'a'),
          tableById(initial, 'b').copyWith(
            config: tableById(
              initial,
              'b',
            ).config.copyWith(periodTimeSetId: 'alternative'),
          ),
        ],
        periodTimeSets: [
          initial.studentMode.periodTimeSets.first.copyWith(
            periodTimes: const [
              CoursePeriodTime(index: 1, startMinutes: 480, endMinutes: 525),
              CoursePeriodTime(index: 2, startMinutes: 535, endMinutes: 580),
            ],
          ),
          initial.studentMode.periodTimeSets.last,
        ],
      ),
    );
    expect(
      () => compile(base, [
        ResourceMutation(
          kind: ResourceKind.course,
          action: ResourceMutationAction.move,
          target: courseRef('c'),
          destinationParentId: 'b',
        ),
      ]),
      throwsA(problem(OperationErrorCode.invalidArgument)),
    );
    expect(tableById(base, 'a').courses.single.periods, [1, 2]);
  });

  test(
    'course deletion clears obsolete name colors and keeps unrelated data',
    () {
      final base = fixture(
        courses: [
          course('c'),
          course('other', name: 'Physics'),
        ],
        colors: {'Math': 0xff112233, 'Physics': 0xff445566},
      );
      final draft = compile(base, [
        ResourceMutation(
          kind: ResourceKind.course,
          action: ResourceMutationAction.delete,
          target: courseRef('c'),
        ),
      ]);
      expect(tableById(draft.candidate, 'a').courses.single.id, 'other');
      expect(draft.candidate.studentMode.courseNameColorValues, {
        'Physics': 0xff445566,
      });
      expect(draft.changes.first.after, isNull);
      expect(draft.changes.last.key, 'student.courseNameColorValues');
    },
  );

  test(
    'course and time-set changes prune only invalid conflict preferences',
    () {
      final c1 = course('c1');
      final c2 = course('c2');
      final conflictKey = buildConflictKeyForCourses('a', 1, [
        c1.copyWith(startMinutes: 480, endMinutes: 525),
        c2.copyWith(startMinutes: 480, endMinutes: 525),
      ]);
      final base = fixture(courses: [c1, c2], conflicts: {conflictKey: 'c1'});
      final unchanged = compile(base, [
        coursePatch('c1', {'teacher': 'Teacher'}),
      ]);
      expect(unchanged.candidate.studentMode.conflictDisplayCourseIds, {
        conflictKey: 'c1',
      });
      final changed = compile(base, [
        ResourceMutation(
          kind: ResourceKind.periodTimeSet,
          action: ResourceMutationAction.patch,
          target: const ResourceRef(
            kind: ResourceKind.periodTimeSet,
            id: 'day',
          ),
          values: {
            'periodTimes': [
              {'index': 1, 'startMinutes': 600, 'endMinutes': 645},
            ],
          },
        ),
      ]);
      expect(changed.candidate.studentMode.conflictDisplayCourseIds, isEmpty);
      expect(
        changed.changes.any(
          (change) => change.key == 'student.conflictDisplayCourseIds',
        ),
        true,
      );
      expect(courseById(changed.candidate, 'c1').startMinutes, 0);
    },
  );

  test(
    'new timetables require real time bindings and preserve current selection',
    () {
      final base = fixture();
      final draft = compile(base, [
        ResourceMutation(
          kind: ResourceKind.timetable,
          action: ResourceMutationAction.create,
          values: {
            'name': 'Autumn',
            'startDate': '2026-10-05',
            'totalWeeks': 18,
            'periodTimeSetId': 'day',
          },
        ),
      ]);
      final created = tableById(draft.candidate, 'timetable-1');
      expect(created.config.periodTimeSetId, 'day');
      expect(created.config.startDate, DateTime(2026, 10, 5));
      expect(created.courses, isEmpty);
      expect(draft.candidate.studentMode.activeTimetableId, 'a');
      expect(
        () => compile(base, [
          ResourceMutation(
            kind: ResourceKind.timetable,
            action: ResourceMutationAction.create,
            values: {
              'name': 'Invalid',
              'startDate': '2026-10-05',
              'totalWeeks': 18,
              'periodTimeSetId': 'missing',
            },
          ),
        ]),
        throwsA(problem(OperationErrorCode.notFound)),
      );
      expect(
        () => compile(base, [
          ResourceMutation(
            kind: ResourceKind.timetable,
            action: ResourceMutationAction.create,
            values: {'name': 'Needs semester'},
          ),
        ]),
        throwsA(problem(OperationErrorCode.invalidArgument)),
      );
    },
  );

  test(
    'shorter semester and rebinding preserve explicit later course weeks',
    () {
      final base = fixture(
        courses: [
          course('c', weeks: [1, 8]),
        ],
      );
      final draft = compile(base, [
        ResourceMutation(
          kind: ResourceKind.timetable,
          action: ResourceMutationAction.patch,
          target: const ResourceRef(kind: ResourceKind.timetable, id: 'a'),
          values: {'totalWeeks': 2, 'periodTimeSetId': 'alternative'},
        ),
      ]);
      expect(tableById(draft.candidate, 'a').config.totalWeeks, 2);
      expect(courseById(draft.candidate, 'c').semesterWeeks, [1, 8]);
      expect(courseById(draft.candidate, 'c').startMinutes, 0);
      expect(draft.changes.single.ref!.kind, ResourceKind.timetable);
      expect((draft.changes.single.after as Map)['courses'], [
        courseById(base, 'c').toJson(),
      ]);
    },
  );

  test(
    'timetable copy gives every course a host ID and shares its bound set',
    () {
      final base = fixture(courses: [course('c1'), course('c2')]);
      final draft = compile(base, [
        ResourceMutation(
          kind: ResourceKind.timetable,
          action: ResourceMutationAction.copy,
          target: const ResourceRef(kind: ResourceKind.timetable, id: 'a'),
          values: {'name': 'Copied semester'},
        ),
      ]);
      final copy = tableById(draft.candidate, 'timetable-1');
      expect(copy.courses.map((item) => item.id), ['course-2', 'course-3']);
      expect(copy.config.periodTimeSetId, 'day');
      expect(draft.candidate.studentMode.periodTimeSets, hasLength(2));
      expect(draft.changes.single.ref!.kind, ResourceKind.timetable);
    },
  );

  test('delete active and last timetable record legal empty selection', () {
    final base = fixture(courses: [course('c')]);
    final draft = compile(base, [
      ResourceMutation(
        kind: ResourceKind.timetable,
        action: ResourceMutationAction.delete,
        target: const ResourceRef(kind: ResourceKind.timetable, id: 'a'),
      ),
      ResourceMutation(
        kind: ResourceKind.timetable,
        action: ResourceMutationAction.delete,
        target: const ResourceRef(kind: ResourceKind.timetable, id: 'b'),
      ),
    ]);
    expect(draft.candidate.studentMode.timetables, isEmpty);
    expect(draft.candidate.studentMode.activeTimetableId, '');
    final selection = draft.changes.singleWhere(
      (change) => change.key == 'student.activeTimetableId',
    );
    expect(selection.before, 'a');
    expect(selection.after, '');
    expect(draft.candidate.studentMode.periodTimeSets, hasLength(2));
  });

  test('time sets support explicit creation, copy, rename and unreferenced deletion', () {
    final base = fixture();
    final draft = compile(base, [
      ResourceMutation(
        kind: ResourceKind.periodTimeSet,
        action: ResourceMutationAction.create,
        values: {
          'name': 'Evening',
          'periodTimes': [
            {'index': 1, 'startMinutes': 1080, 'endMinutes': 1125},
          ],
        },
      ),
      ResourceMutation(
        kind: ResourceKind.periodTimeSet,
        action: ResourceMutationAction.copy,
        target: const ResourceRef(kind: ResourceKind.periodTimeSet, id: 'day'),
        values: {'name': 'Day copy'},
      ),
      ResourceMutation(
        kind: ResourceKind.periodTimeSet,
        action: ResourceMutationAction.patch,
        target: const ResourceRef(
          kind: ResourceKind.periodTimeSet,
          id: 'alternative',
        ),
        values: {'name': 'Alternative renamed'},
      ),
    ]);
    expect(draft.candidate.studentMode.periodTimeSets.map((item) => item.id), [
      'day',
      'alternative',
      'periodTimeSet-1',
      'periodTimeSet-2',
    ]);
    expect(
      draft.changes.map((change) => change.ref!.kind),
      everyElement(ResourceKind.periodTimeSet),
    );
    final deleted = compile(draft.candidate, [
      ResourceMutation(
        kind: ResourceKind.periodTimeSet,
        action: ResourceMutationAction.delete,
        target: const ResourceRef(
          kind: ResourceKind.periodTimeSet,
          id: 'periodTimeSet-1',
        ),
      ),
    ]);
    expect(deleted.changes.single.after, isNull);
  });

  test('in-use time sets require all references rebound before deletion', () {
    final base = fixture();
    final delete = ResourceMutation(
      kind: ResourceKind.periodTimeSet,
      action: ResourceMutationAction.delete,
      target: const ResourceRef(kind: ResourceKind.periodTimeSet, id: 'day'),
    );
    expect(
      () => compile(base, [delete]),
      throwsA(problem(OperationErrorCode.conflict)),
    );
    final draft = compile(base, [
      for (final id in ['a', 'b'])
        ResourceMutation(
          kind: ResourceKind.timetable,
          action: ResourceMutationAction.patch,
          target: ResourceRef(kind: ResourceKind.timetable, id: id),
          values: {'periodTimeSetId': 'alternative'},
        ),
      delete,
    ]);
    expect(draft.candidate.studentMode.periodTimeSets.single.id, 'alternative');
    expect(
      draft.changes.where(
        (change) => change.ref?.kind == ResourceKind.timetable,
      ),
      hasLength(2),
    );
  });

  test(
    'invalid period order, index and ranges are rejected without repairs',
    () {
      final base = fixture();
      for (final periods in [
        [],
        [
          {'index': 2, 'startMinutes': 480, 'endMinutes': 525},
        ],
        [
          {'index': 1, 'startMinutes': 525, 'endMinutes': 480},
        ],
        [
          {'index': 1, 'startMinutes': 1400, 'endMinutes': 1440},
        ],
        [
          {'index': 1, 'startMinutes': 480, 'endMinutes': 525},
          {'index': 2, 'startMinutes': 520, 'endMinutes': 560},
        ],
        [
          {
            'index': 1,
            'startMinutes': 480,
            'endMinutes': 525,
            'name': 'unexpected',
          },
        ],
      ]) {
        expect(
          () => compile(base, [
            ResourceMutation(
              kind: ResourceKind.periodTimeSet,
              action: ResourceMutationAction.patch,
              target: const ResourceRef(
                kind: ResourceKind.periodTimeSet,
                id: 'day',
              ),
              values: {'periodTimes': periods},
            ),
          ]),
          throwsA(problem(OperationErrorCode.invalidArgument)),
        );
      }
    },
  );

  test(
    'invalid timetable configuration and wrong target kinds are rejected',
    () {
      final base = fixture();
      for (final values in <Map<String, Object?>>[
        {'name': ''},
        {'totalWeeks': 0},
        {'totalWeeks': 101},
        {'totalWeeks': 2.5},
        {'startDate': '2026-02-30'},
        {'startDate': '2026-10-05T08:00:00'},
        {'courses': []},
        {'startDateNeedsConfirmation': true},
      ]) {
        expect(
          () => compile(base, [
            ResourceMutation(
              kind: ResourceKind.timetable,
              action: ResourceMutationAction.patch,
              target: const ResourceRef(kind: ResourceKind.timetable, id: 'a'),
              values: values,
            ),
          ]),
          throwsA(problem(OperationErrorCode.invalidArgument)),
        );
      }
      expect(
        () => compile(base, [
          ResourceMutation(
            kind: ResourceKind.course,
            action: ResourceMutationAction.delete,
            target: const ResourceRef(kind: ResourceKind.timetable, id: 'a'),
          ),
        ]),
        throwsA(problem(OperationErrorCode.invalidArgument)),
      );
    },
  );

  test(
    'mixed-domain batch errors do not alter any committed source objects',
    () {
      final base = fixture(courses: [course('c')]);
      final before = jsonEncode(base.toJson());
      expect(
        () => compile(base, [
          coursePatch('c', {'name': 'Candidate'}),
          ResourceMutation(
            kind: ResourceKind.calendar,
            action: ResourceMutationAction.create,
            values: {'name': 'Candidate calendar'},
          ),
          ResourceMutation(
            kind: ResourceKind.periodTimeSet,
            action: ResourceMutationAction.delete,
            target: const ResourceRef(
              kind: ResourceKind.periodTimeSet,
              id: 'day',
            ),
          ),
        ]),
        throwsA(problem(OperationErrorCode.conflict)),
      );
      expect(jsonEncode(base.toJson()), before);
    },
  );

  test('student commands with no changes return the original candidate', () {
    final base = fixture(courses: [course('c')]);
    final draft = compile(base, [
      coursePatch('c', {}),
      ResourceMutation(
        kind: ResourceKind.timetable,
        action: ResourceMutationAction.patch,
        target: const ResourceRef(kind: ResourceKind.timetable, id: 'a'),
        values: {'name': 'A'},
      ),
      ResourceMutation(
        kind: ResourceKind.periodTimeSet,
        action: ResourceMutationAction.patch,
        target: const ResourceRef(kind: ResourceKind.periodTimeSet, id: 'day'),
        values: {'name': 'Day'},
      ),
    ]);
    expect(draft.isEmpty, true);
    expect(identical(draft.candidate, base), true);
  });
}

MutationDraft compile(AppData base, List<ResourceMutation> operations) {
  var next = 0;
  return const ResourceMutationCompiler().compile(
    base,
    operations,
    context: MutationContext(
      now: DateTime(2026, 10, 30, 10),
      idGenerator: (kind) => '${kind.name}-${++next}',
    ),
  );
}

ResourceRef courseRef(String id, {String parent = 'a'}) =>
    ResourceRef(kind: ResourceKind.course, id: id, parentId: parent);
ResourceMutation coursePatch(
  String id,
  Map<String, Object?> values, {
  String parent = 'a',
}) => ResourceMutation(
  kind: ResourceKind.course,
  action: ResourceMutationAction.patch,
  target: courseRef(id, parent: parent),
  values: values,
);
TimetableData tableById(AppData data, String id) =>
    data.studentMode.timetables.singleWhere((item) => item.id == id);
CourseItem courseById(AppData data, String id) => data.studentMode.timetables
    .expand((table) => table.courses)
    .singleWhere((item) => item.id == id);
AppData fixture({
  List<CourseItem> courses = const [],
  Map<String, int>? colors,
  Map<String, String> conflicts = const {},
}) => AppData(
  activeMode: AppMode.general,
  enabledWorkspaces: {AppMode.general},
  generalMode: const GeneralScheduleData(
    activeScheduleId: 'cal',
    selectedDateIso: '2026-10-05',
    schedules: [GeneralSchedule(id: 'cal', name: 'Calendar', events: [])],
  ),
  studentMode: StudentModeData(
    activeTimetableId: 'a',
    timetables: [table('a', 'A', courses), table('b', 'B', [])],
    periodTimeSets: const [
      PeriodTimeSet(
        id: 'day',
        name: 'Day',
        periodTimes: [
          CoursePeriodTime(index: 1, startMinutes: 480, endMinutes: 525),
        ],
      ),
      PeriodTimeSet(
        id: 'alternative',
        name: 'Alternative',
        periodTimes: [
          CoursePeriodTime(index: 1, startMinutes: 600, endMinutes: 645),
        ],
      ),
    ],
    conflictDisplayCourseIds: conflicts,
    courseNameColorValues:
        colors ?? {for (final course in courses) course.name: 0xff123456},
  ),
);
TimetableData table(String id, String name, List<CourseItem> courses) =>
    TimetableData(
      id: id,
      config: TimetableConfig(
        name: name,
        startDate: DateTime(2026, 10, 5),
        totalWeeks: 8,
        periodTimeSetId: 'day',
      ),
      courses: courses,
    );
CourseItem course(
  String id, {
  String name = 'Math',
  List<int> weeks = const [1, 3],
  List<int> periods = const [1],
}) => CourseItem(
  id: id,
  name: name,
  teacher: '',
  location: '',
  dayOfWeek: 1,
  semesterWeeks: weeks,
  periods: periods,
  startMinutes: 0,
  endMinutes: 0,
  timeRange: buildTimeRange(0, 0),
  credit: 0,
  remarks: '',
  customFields: {},
);
