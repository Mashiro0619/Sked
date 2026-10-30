import 'package:flutter_test/flutter_test.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/student_timetable_service.dart';

import '../../support/timetable_storage_fakes.dart';
import 'tool_adapter_test_support.dart';

Matcher _problem(OperationErrorCode code) =>
    isA<OperationProblem>().having((e) => e.code, 'code', code);

CourseItem _course(
  String id, {
  int day = 1,
  int start = 480,
  int end = 525,
  List<int> weeks = const [],
}) => CourseItem(
  id: id,
  name: id,
  teacher: '',
  location: '',
  dayOfWeek: day,
  semesterWeeks: weeks,
  periods: const [1],
  startMinutes: start,
  endMinutes: end,
  timeRange: buildTimeRange(start, end),
  credit: 0,
  remarks: '',
  customFields: const {},
);

AppData _fixture() {
  final initial = buildInitialAppData(buildDefaultPeriodTimes());
  final template = TimetableData(
    id: 'current',
    config: TimetableConfig(
      name: 'Current timetable',
      startDate: DateTime(2026, 10, 26),
      totalWeeks: 20,
      periodTimeSetId: initial.studentMode.periodTimeSets.single.id,
    ),
    courses: const [],
  );
  final target = template.copyWith(
    id: 'target',
    config: template.config.copyWith(
      startDate: DateTime.now().subtract(const Duration(days: 7)),
      totalWeeks: 20,
    ),
    courses: [
      _course('a'),
      _course('b'),
      _course('c', day: 2),
      _course('d', day: 2),
    ],
  );
  return initial.copyWith(
    enabledWorkspaces: {AppMode.general},
    activeMode: AppMode.general,
    studentMode: initial.studentMode.copyWith(
      activeTimetableId: template.id,
      timetables: [template, target],
      showPastEndedCourses: false,
      showFutureCourses: false,
    ),
    generalMode: initial.generalMode.copyWith(
      selectedDateIso: '2026-10-30',
      showWeekends: false,
    ),
  );
}

class _FailingStorage extends MemoryTimetableStorage {
  _FailingStorage({required super.initialData});
  bool failNext = false;
  @override
  Future<void> save(AppData data) async {
    if (failNext) {
      failNext = false;
      throw StateError('Synthetic save failure');
    }
    await super.save(data);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ToolAdapterHarness h;
  late _FailingStorage storage;
  setUp(() async {
    h = ToolAdapterHarness();
    storage = _FailingStorage(initialData: _fixture());
    await h.initialize(storageOverride: storage);
    AppData.decodeStorageSnapshot(h.session.committedData.encode());
  });
  tearDown(() => h.close());

  Future<List<Map<String, Object?>>> groups({int week = 1}) async {
    final result = await h.call('courses.display.list', {
      'timetableId': 'target',
      'week': week,
    });
    return (result['rows'] as List).cast<Map<String, Object?>>();
  }

  Future<void> edit(AppData Function(AppData data) transform) => h.session
      .commitMutation(transform, expectedEpoch: h.session.mutationEpoch);

  Future<void> replaceCourses(List<CourseItem> courses) => edit(
    (data) => data.copyWith(
      studentMode: data.studentMode.copyWith(
        timetables: [
          for (final table in data.studentMode.timetables)
            table.id == 'target' ? table.copyWith(courses: courses) : table,
        ],
      ),
    ),
  );

  Map<String, Object?> displayArgs(String key, {String? courseId = 'b'}) => {
    'action': courseId == null ? 'reset' : 'set',
    'timetableId': 'target',
    'week': 1,
    'conflictKey': key,
    'courseId': ?courseId,
  };

  const rangeArgs = {
    'action': 'set',
    'start': '2026-11-01',
    'end': '2026-11-14',
  };

  test(
    'discover, select, replay and undo a disabled non-current timetable',
    () async {
      final before = h.session.committedData;
      final rows = await groups();
      expect(rows, hasLength(2));
      expect(rows.first['selectableCourseIds'], ['a', 'b']);
      expect(rows.first['displayedCourseId'], 'a');
      final key = rows.first['conflictKey'] as String;
      final args = displayArgs(key);
      final plan = await h.call('courses.display.prepare', args);
      expect(storage.saveCount, 0);
      expect(plan['changeCount'], 1);
      expect(await h.commit(plan), containsPair('status', 'committed'));
      expect(storage.data!.studentMode.conflictDisplayCourseIds[key], 'b');
      expect((await groups()).first['displayedCourseId'], 'b');
      final after = h.session.committedData;
      expect(after.enabledWorkspaces, before.enabledWorkspaces);
      expect(after.activeMode, before.activeMode);
      expect(
        after.studentMode.activeTimetableId,
        before.studentMode.activeTimetableId,
      );
      expect(
        after.studentMode.timetables.map((t) => t.toJson()),
        before.studentMode.timetables.map((t) => t.toJson()),
      );
      final replay = await h.call('courses.display.prepare', {
        ...args,
        'operationId': plan['operationId'],
      });
      expect(await h.commit(replay), containsPair('replayed', true));
      expect(storage.saveCount, 1);
      final undo = await h.call('undo.prepare', {
        'operationId': plan['operationId'],
      });
      await h.commit(undo);
      expect(
        h.session.committedData.studentMode.toJson(),
        before.studentMode.toJson(),
      );
    },
  );

  test(
    'group discovery pages deterministically and rejects invalid targets',
    () async {
      final first = await h.call('courses.display.list', {
        'timetableId': 'target',
        'week': 1,
        'limit': 1,
      });
      expect(first['itemCount'], 2);
      expect(first['nextOffset'], 1);
      final second = await h.call('courses.display.list', {
        'timetableId': 'target',
        'week': 1,
        'offset': first['nextOffset'],
        'limit': 1,
      });
      expect((second['rows'] as List).single['weekday'], 2);
      expect(second['nextOffset'], isNull);
      for (final args in [
        {'timetableId': 'target', 'week': 0},
        {'timetableId': 'target', 'week': 21},
        {'timetableId': 'target', 'week': 1, 'limit': 101},
      ]) {
        await expectLater(
          h.call('courses.display.list', args),
          throwsA(_problem(OperationErrorCode.invalidArgument)),
        );
      }
      await expectLater(
        h.call('courses.display.list', {'timetableId': 'missing', 'week': 1}),
        throwsA(_problem(OperationErrorCode.notFound)),
      );
      expect(storage.saveCount, 0);
    },
  );

  test(
    'invented, subset, mismatched keys and nonmember choices cannot prepare',
    () async {
      final key = (await groups()).first['conflictKey'] as String;
      for (final args in [
        displayArgs('invented'),
        displayArgs(key, courseId: 'c'),
        displayArgs(key.replaceAll('a,b', 'a')),
        {
          ...displayArgs(key),
          'timetableId': h.session.data.studentMode.activeTimetableId,
        },
        {...displayArgs(key, courseId: null), 'courseId': null},
      ]) {
        await expectLater(
          h.call('courses.display.prepare', args),
          throwsA(_problem(OperationErrorCode.invalidArgument)),
        );
      }
      expect(storage.saveCount, 0);
    },
  );

  test(
    'partial overlap and disjoint weeks do not create selectable conflicts',
    () async {
      final partial = [
        _course('a', start: 480, end: 540),
        _course('b', start: 520, end: 580),
        _course('c', start: 570, end: 610),
      ];
      await replaceCourses(partial);
      expect(await groups(), isEmpty);
      await expectLater(
        h.call(
          'courses.display.prepare',
          displayArgs(buildConflictKeyForCourses('target', 1, partial)),
        ),
        throwsA(_problem(OperationErrorCode.invalidArgument)),
      );
      await replaceCourses([
        _course('a', weeks: [1, 3]),
        _course('b', weeks: [2, 3]),
      ]);
      expect(await groups(), isEmpty);
      expect(await groups(week: 2), isEmpty);
      expect((await groups(week: 3)).single['selectableCourseIds'], ['a', 'b']);
    },
  );

  test(
    'legacy period times and empty weekly lists use the normal projection',
    () async {
      await replaceCourses([
        _course('a', start: 0, end: 0),
        _course('b', start: 0, end: 0),
      ]);
      final row = (await groups()).single;
      final period =
          h.session.data.studentMode.periodTimeSets.first.periodTimes.first;
      expect(row['startMinutes'], period.startMinutes);
      expect(row['endMinutes'], period.endMinutes);
      final plan = await h.call(
        'courses.display.prepare',
        displayArgs(row['conflictKey'] as String),
      );
      await h.commit(plan);
      expect((await groups(week: 20)).single['displayedCourseId'], 'b');
      expect(
        h.session.data.studentMode.timetables.last.courses.first.startMinutes,
        0,
      );
    },
  );

  test(
    'inactive preview remains inspectable but cannot replace an active choice',
    () async {
      await replaceCourses([
        _course('a', weeks: [1]),
        _course('b', weeks: [1]),
        _course('future', weeks: [2]),
      ]);
      await edit(
        (data) => data.copyWith(
          studentMode: data.studentMode.copyWith(showFutureCourses: true),
        ),
      );
      final row = (await groups()).single;
      expect(row['courseIds'], contains('future'));
      expect(row['selectableCourseIds'], ['a', 'b']);
      await expectLater(
        h.call(
          'courses.display.prepare',
          displayArgs(row['conflictKey'] as String, courseId: 'future'),
        ),
        throwsA(_problem(OperationErrorCode.invalidArgument)),
      );
    },
  );

  test(
    'reset removes equivalent legacy keys and preserves other choices',
    () async {
      final rows = await groups();
      final key = rows.first['conflictKey'] as String;
      final other = rows.last['conflictKey'] as String;
      final legacy = key.substring(3);
      final seeded = h.session.data.studentMode.copyWith(
        conflictDisplayCourseIds: {key: 'b', legacy: 'b', other: 'd'},
      );
      final reset = const StudentTimetableService()
          .setDisplayedCourseForConflict(seeded, key, null);
      expect(reset.conflictDisplayCourseIds, {other: 'd'});
      await edit((data) => data.copyWith(studentMode: seeded));
      final before =
          h.session.committedData.studentMode.conflictDisplayCourseIds;
      final plan = await h.call(
        'courses.display.prepare',
        displayArgs(key, courseId: null),
      );
      await h.commit(plan);
      expect(h.session.data.studentMode.conflictDisplayCourseIds, {other: 'd'});
      expect((await groups()).first['displayedCourseId'], 'a');
      final undo = await h.call('undo.prepare', {
        'operationId': plan['operationId'],
      });
      await h.commit(undo);
      expect(h.session.data.studentMode.conflictDisplayCourseIds, before);
    },
  );

  test(
    'date range manages a disabled workspace, replays once and undoes focus',
    () async {
      await edit(
        (data) => data.copyWith(
          enabledWorkspaces: {AppMode.student},
          activeMode: AppMode.student,
        ),
      );
      final before = h.session.committedData;
      final count = storage.saveCount;
      final plan = await h.call('navigation.range.prepare', rangeArgs);
      expect(storage.saveCount, count);
      expect(plan['changeCount'], 2);
      await h.commit(plan);
      final after = h.session.committedData;
      expect(after.generalMode.customDateRange!.dayCount, 14);
      expect(after.generalMode.selectedDateIso, '2026-11-01');
      expect(after.activeMode, before.activeMode);
      expect(after.enabledWorkspaces, before.enabledWorkspaces);
      expect(
        after.generalMode.activeScheduleId,
        before.generalMode.activeScheduleId,
      );
      final replay = await h.call('navigation.range.prepare', {
        ...rangeArgs,
        'operationId': plan['operationId'],
      });
      await h.commit(replay);
      expect(storage.saveCount, count + 1);
      final undo = await h.call('undo.prepare', {
        'operationId': plan['operationId'],
      });
      await h.commit(undo);
      expect(h.session.data.generalMode.toJson(), before.generalMode.toJson());
    },
  );

  test('range preserves an in-range focus and reset restores hidden-weekend behavior', () async {
    final plan = await h.call('navigation.range.prepare', {
      'action': 'set',
      'start': '2026-10-29',
      'end': '2026-11-01',
    });
    expect(plan['changeCount'], 1);
    await h.commit(plan);
    expect(h.session.data.generalMode.selectedDateIso, '2026-10-30');
    await edit(
      (data) => data.copyWith(
        generalMode: data.generalMode.copyWith(selectedDateIso: '2026-11-01'),
      ),
    );
    final before = h.session.committedData.generalMode;
    final reset = await h.call('navigation.range.prepare', {'action': 'reset'});
    await h.commit(reset);
    expect(h.session.data.generalMode.customDateRange, isNull);
    expect(h.session.data.generalMode.selectedDateIso, '2026-10-30');
    final undo = await h.call('undo.prepare', {
      'operationId': reset['operationId'],
    });
    await h.commit(undo);
    expect(h.session.data.generalMode.toJson(), before.toJson());
  });

  test('date boundaries are strict and inclusive', () async {
    for (final args in [
      {'action': 'set', 'start': '2026-02-30', 'end': '2026-03-01'},
      {'action': 'set', 'start': '2026-1-01', 'end': '2026-01-02'},
      {'action': 'set', 'start': '2026-01-01T00:00:00', 'end': '2026-01-02'},
      {'action': 'set', 'start': '2026-11-02', 'end': '2026-11-01'},
      {'action': 'set', 'start': '2026-11-01', 'end': '2026-11-15'},
      {'action': 'set', 'start': '1969-12-31', 'end': '1970-01-01'},
      {'action': 'set', 'start': '2100-01-01', 'end': '2100-01-02'},
      {'action': 'set', 'start': '2026-11-01'},
      {'action': 'reset', 'start': null},
      {
        'action': 'set',
        'start': '2026-11-01',
        'end': '2026-11-02',
        'focusedDate': '2026-11-01',
      },
    ]) {
      await expectLater(
        h.call('navigation.range.prepare', args),
        throwsA(_problem(OperationErrorCode.invalidArgument)),
      );
    }
    expect(storage.saveCount, 0);
    for (final date in ['1970-01-01', '2100-01-01']) {
      final plan = await h.call('navigation.range.prepare', {
        'action': 'set',
        'start': date,
        'end': date,
      });
      await h.commit(plan);
      expect(h.session.data.generalMode.customDateRange!.dayCount, 1);
      expect(h.session.data.generalMode.selectedDateIso, date);
    }
  });

  for (final tool in ['courses.display.prepare', 'navigation.range.prepare']) {
    test('$tool honors plan, ask, stale baselines and save failure', () async {
      final args = tool == 'courses.display.prepare'
          ? displayArgs((await groups()).first['conflictKey'] as String)
          : rangeArgs;
      h.scope.policy.update(mode: AgentPermissionMode.plan);
      final readOnly = await h.call(tool, args);
      await expectLater(
        h.commit(readOnly),
        throwsA(_problem(OperationErrorCode.readOnly)),
      );
      expect(storage.saveCount, 0);
      h.scope.policy.update(mode: AgentPermissionMode.ask);
      final declined = await h.call(tool, args);
      await expectLater(
        h.commit(declined),
        throwsA(_problem(OperationErrorCode.cancelled)),
      );
      expect(storage.saveCount, 0);
      var approvals = 0;
      h.approval = (plan) async {
        approvals++;
        return h.scope.approve(plan.id);
      };
      final approved = await h.call(tool, args);
      await h.commit(approved);
      expect(approvals, 1);
      final undo = await h.call('undo.prepare', {
        'operationId': approved['operationId'],
      });
      await h.commit(undo);
      h.scope.policy.update(mode: AgentPermissionMode.full);
      final stale = await h.call(tool, args);
      await edit(
        (data) => data.copyWith(
          generalMode: data.generalMode.copyWith(selectedDateIso: '2026-10-29'),
        ),
      );
      await expectLater(
        h.commit(stale),
        throwsA(_problem(OperationErrorCode.conflict)),
      );
      final before = h.session.committedData;
      final failed = await h.call(tool, args);
      storage.failNext = true;
      await expectLater(
        h.commit(failed),
        throwsA(_problem(OperationErrorCode.storageFailure)),
      );
      expect(h.session.committedData.toJson(), before.toJson());
      final retry = await h.call(tool, {
        ...args,
        'operationId': failed['operationId'],
      });
      await h.commit(retry);
      final committed = h.session.committedData;
      final failedUndo = await h.call('undo.prepare', {
        'operationId': retry['operationId'],
      });
      storage.failNext = true;
      await expectLater(
        h.commit(failedUndo),
        throwsA(_problem(OperationErrorCode.storageFailure)),
      );
      expect(h.session.committedData.toJson(), committed.toJson());
    });
  }

  test(
    'range undo does not overwrite a later manually selected date',
    () async {
      final plan = await h.call('navigation.range.prepare', rangeArgs);
      await h.commit(plan);
      await edit(
        (data) => data.copyWith(
          generalMode: data.generalMode.copyWith(selectedDateIso: '2026-11-02'),
        ),
      );
      await expectLater(
        h.call('undo.prepare', {'operationId': plan['operationId']}),
        throwsA(_problem(OperationErrorCode.conflict)),
      );
      expect(h.session.data.generalMode.selectedDateIso, '2026-11-02');
    },
  );
}
