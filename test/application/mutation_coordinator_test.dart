import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/application/mutation_coordinator.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/application/resource_contracts.dart';
import 'package:sked/application/resource_mutations.dart';
import 'package:sked/application/setting_registry.dart';
import 'package:sked/controllers/app_session.dart';
import 'package:sked/data/app_repository.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/models/application_ledger.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/student_timetable_service.dart';

class TestStorage implements TimetableStorage {
  TestStorage(this.data);
  AppData data;
  Object? error;
  Future<void> Function()? gate;
  int saves = 0;
  @override
  Future<StorageLoadResult> load() async =>
      StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);
  @override
  Future<void> save(AppData value) async {
    saves++;
    await gate?.call();
    if (error != null) throw error!;
    data = AppData.decodeStorageSnapshot(value.encode());
  }

  @override
  Future<String?> filePath() async => null;
}

Matcher problem(OperationErrorCode code) =>
    isA<OperationProblem>().having((error) => error.code, 'code', code);

void main() {
  late TestStorage storage;
  late AppSession session;
  late MutationCoordinator coordinator;
  late OperationScope scope;
  late DateTime clock;
  var sessionRevision = 0;
  var idSequence = 0;
  var publications = 0;
  Future<void> Function() settle = () async {};

  String id() =>
      '00000000-0000-4000-8000-${(++idSequence).toString().padLeft(12, '0')}';
  Future<AppSession> newSession() async {
    final repository = AppRepository(storage: storage);
    final loaded = await repository.load();
    final result = AppSession(
      repository: repository,
      initialData: loaded!,
      requireMutationAllowed: () {},
    );
    addTearDown(result.close);
    return result;
  }

  MutationCoordinator newCoordinator(AppSession session) => MutationCoordinator(
    session: session,
    settlePendingChanges: () => settle(),
    dataSessionRevision: () => sessionRevision,
    clock: () => clock,
    idGenerator: id,
    onCommitted: () => publications++,
  );
  ResourceMutation createEvent([String title = 'Study']) => ResourceMutation(
    kind: ResourceKind.event,
    action: ResourceMutationAction.create,
    destinationParentId: 'calendar',
    values: {
      'title': title,
      'start': '2026-10-05T09:00:00',
      'end': '2026-10-05T10:00:00',
    },
  );
  GeneralEvent event(String eventId, [String title = 'Existing']) =>
      GeneralEvent(
        id: eventId,
        calendarId: 'calendar',
        title: title,
        startDateTimeIso: '2026-10-05T09:00:00.000',
        endDateTimeIso: '2026-10-05T10:00:00.000',
        createdAtIso: '2026-10-01T00:00:00.000Z',
        updatedAtIso: '2026-10-01T00:00:00.000Z',
      );
  Future<void> seedEvents(List<GeneralEvent> events) async {
    storage.data = storage.data.copyWith(
      generalMode: storage.data.generalMode.copyWith(
        schedules: [
          storage.data.generalMode.schedules.single.copyWith(events: events),
        ],
      ),
    );
    session = await newSession();
    coordinator = newCoordinator(session);
  }

  Future<void> saveUiData(AppData value) async {
    session.replaceData(value);
    await session.persist(value);
  }

  setUp(() async {
    clock = DateTime.utc(2026, 10, 5);
    sessionRevision = 0;
    idSequence = 0;
    publications = 0;
    settle = () async {};
    final data = buildInitialAppData(buildDefaultPeriodTimes()).copyWith(
      generalMode: const GeneralScheduleData(
        activeScheduleId: 'calendar',
        selectedDateIso: '2026-10-05',
        schedules: [GeneralSchedule(id: 'calendar', name: 'Study', events: [])],
      ),
    );
    storage = TestStorage(AppData.decodeStorageSnapshot(data.encode()));
    session = await newSession();
    coordinator = newCoordinator(session);
    scope = OperationScope(
      id: 'run',
      policy: OperationPolicy(enabled: true, mode: AgentPermissionMode.full),
    );
  });

  test('a retry cannot change the recurring instance scope', () async {
    final command = createEvent();
    final plan = coordinator.prepare(scope: scope, resources: [command]);
    await coordinator.commit(planId: plan.id, scope: scope);
    expect(
      () => coordinator.prepare(
        scope: scope,
        operationId: plan.operationId,
        resources: [
          ResourceMutation(
            kind: command.kind,
            action: command.action,
            destinationParentId: command.destinationParentId,
            values: command.values,
            scope: GeneralEventEditScope.thisOccurrence,
          ),
        ],
      ),
      throwsA(problem(OperationErrorCode.duplicateMismatch)),
    );
  });

  test(
    'undo uses the same permission and durable idempotency boundary',
    () async {
      final plan = coordinator.prepare(
        scope: scope,
        resources: [createEvent()],
      );
      await coordinator.commit(planId: plan.id, scope: scope);
      scope.policy.update(mode: AgentPermissionMode.plan);
      final inverse = coordinator.prepareUndo(
        scope: scope,
        operationId: plan.operationId,
      );
      await expectLater(
        coordinator.commit(planId: inverse.id, scope: scope),
        throwsA(problem(OperationErrorCode.readOnly)),
      );
      scope.policy.update(mode: AgentPermissionMode.ask);
      await expectLater(
        coordinator.commit(planId: inverse.id, scope: scope),
        throwsA(problem(OperationErrorCode.approvalRequired)),
      );
      final applied = await coordinator.commit(
        planId: inverse.id,
        scope: scope,
        approval: scope.approve(inverse.id),
      );
      expect(applied.receipt.result['undoOf'], plan.operationId);
      expect(storage.data.generalMode.schedules.single.events, isEmpty);
      final restarted = newCoordinator(await newSession());
      final retry = restarted.prepareUndo(
        scope: scope,
        operationId: plan.operationId,
      );
      expect(retry.alreadyCommitted, isTrue);
      final replay = await restarted.commit(planId: retry.id, scope: scope);
      expect(replay.replayed, isTrue);
      expect(storage.saves, 2);
    },
  );

  test(
    'preparation writes nothing; a batch and its receipt persist together',
    () async {
      final plan = coordinator.prepare(
        scope: scope,
        resources: [createEvent()],
        settings: [const SettingEdit.set('general.showWeekends', false)],
      );
      expect(storage.saves, 0);
      expect(storage.data.generalMode.schedules.single.events, isEmpty);
      expect(coordinator.status(plan.operationId), isNull);
      final result = await coordinator.commit(planId: plan.id, scope: scope);
      expect(result.replayed, isFalse);
      expect(storage.saves, 1);
      expect(
        storage.data.generalMode.schedules.single.events.single.title,
        'Study',
      );
      expect(storage.data.generalMode.showWeekends, isFalse);
      expect(
        storage.data.applicationLedger!.receiptFor(plan.operationId),
        result.receipt,
      );
      expect(result.receipt.undo!['changes'], isNotEmpty);
      expect(publications, 1);
    },
  );

  test('restarting after business commit returns the original result without creating again', () async {
    final plan = coordinator.prepare(scope: scope, resources: [createEvent()]);
    final first = await coordinator.commit(planId: plan.id, scope: scope);
    final restartedSession = await newSession();
    final restarted = newCoordinator(restartedSession);
    final retry = restarted.prepare(
      scope: scope,
      resources: [createEvent()],
      operationId: plan.operationId,
    );
    expect(retry.alreadyCommitted, isTrue);
    final second = await restarted.commit(planId: retry.id, scope: scope);
    expect(second.replayed, isTrue);
    expect(second.receipt, first.receipt);
    expect(storage.saves, 1);
    expect(storage.data.generalMode.schedules.single.events, hasLength(1));
    expect(
      () => restarted.prepare(
        scope: scope,
        resources: [createEvent('Different')],
        operationId: plan.operationId,
      ),
      throwsA(problem(OperationErrorCode.duplicateMismatch)),
    );
  });

  test('one invalid command prevents every command in the batch', () {
    expect(
      () => coordinator.prepare(
        scope: scope,
        resources: [
          createEvent(),
          ResourceMutation(
            kind: ResourceKind.event,
            action: ResourceMutationAction.delete,
            target: const ResourceRef(
              kind: ResourceKind.event,
              id: 'missing',
              parentId: 'calendar',
            ),
          ),
        ],
      ),
      throwsA(problem(OperationErrorCode.notFound)),
    );
    expect(storage.saves, 0);
    expect(storage.data.applicationLedger, isNull);
  });

  test('planning and ask modes are enforced by the commit host', () async {
    scope.policy.update(mode: AgentPermissionMode.plan);
    final plan = coordinator.prepare(scope: scope, resources: [createEvent()]);
    await expectLater(
      coordinator.commit(planId: plan.id, scope: scope),
      throwsA(problem(OperationErrorCode.readOnly)),
    );
    scope.policy.update(mode: AgentPermissionMode.ask);
    await expectLater(
      coordinator.commit(planId: plan.id, scope: scope),
      throwsA(problem(OperationErrorCode.approvalRequired)),
    );
    final approval = scope.approve(plan.id);
    await coordinator.commit(planId: plan.id, scope: scope, approval: approval);
    expect(storage.saves, 1);
  });

  test(
    'an unrelated saved UI edit preserves the approved create and its identity',
    () async {
      scope.policy.update(mode: AgentPermissionMode.ask);
      final plan = coordinator.prepare(
        scope: scope,
        resources: [createEvent()],
      );
      final approval = scope.approve(plan.id);
      final preview = plan.changes.single.after as Map;
      final lastAllocatedId = idSequence;
      await saveUiData(session.data.copyWith(localeCode: 'zh'));
      clock = clock.add(const Duration(minutes: 5));
      final result = await coordinator.commit(
        planId: plan.id,
        scope: scope,
        approval: approval,
      );
      expect(storage.data.localeCode, 'zh');
      final created = storage.data.generalMode.schedules.single.events.single;
      expect(created.toJson(), preview);
      expect(idSequence, lastAllocatedId);
      expect(result.receipt.completedAtIso, clock.toIso8601String());
      expect(result.receipt.result['changeCount'], 1);
      expect(storage.saves, 2);
      final restarted = newCoordinator(await newSession());
      final retry = restarted.prepare(
        scope: scope,
        resources: [createEvent()],
        operationId: plan.operationId,
      );
      final replay = await restarted.commit(planId: retry.id, scope: scope);
      expect(replay.receipt, result.receipt);
      expect(replay.replayed, isTrue);
      expect(storage.saves, 2);
    },
  );

  test(
    'a sibling edit survives an event change in the same calendar',
    () async {
      await seedEvents([event('target'), event('sibling')]);
      final plan = coordinator.prepare(
        scope: scope,
        resources: [
          ResourceMutation(
            kind: ResourceKind.event,
            action: ResourceMutationAction.patch,
            target: const ResourceRef(
              kind: ResourceKind.event,
              id: 'target',
              parentId: 'calendar',
            ),
            values: {'title': 'Agent change'},
          ),
        ],
      );
      expect(plan.readSet, contains('resource:event:calendar:target'));
      expect(plan.writeSet, ['resource:event:calendar:target']);
      final calendar = session.data.generalMode.schedules.single;
      await saveUiData(
        session.data.copyWith(
          generalMode: session.data.generalMode.copyWith(
            schedules: [
              calendar.copyWith(
                events: [
                  calendar.events.first,
                  calendar.events.last.copyWith(notes: 'Saved UI draft'),
                ],
              ),
            ],
          ),
        ),
      );
      final result = await coordinator.commit(planId: plan.id, scope: scope);
      final events = storage.data.generalMode.schedules.single.events;
      final target = events.singleWhere((item) => item.id == 'target');
      expect(target.title, 'Agent change');
      expect(
        events.singleWhere((item) => item.id == 'sibling').notes,
        'Saved UI draft',
      );
      final reverse = (result.receipt.undo!['changes'] as List).single as Map;
      expect(reverse['before'], event('target').toJson());
      expect(reverse['after'], target.toJson());
      final inverse = coordinator.prepareUndo(
        scope: scope,
        operationId: plan.operationId,
      );
      await coordinator.commit(planId: inverse.id, scope: scope);
      expect(
        storage.data.generalMode.schedules.single.events
            .singleWhere((item) => item.id == 'target')
            .title,
        'Existing',
      );
      expect(
        storage.data.generalMode.schedules.single.events
            .singleWhere((item) => item.id == 'sibling')
            .notes,
        'Saved UI draft',
      );
    },
  );

  test(
    'a target edit conflicts even when the original command was a no-op',
    () async {
      await seedEvents([event('target')]);
      final plan = coordinator.prepare(
        scope: scope,
        resources: [
          ResourceMutation(
            kind: ResourceKind.event,
            action: ResourceMutationAction.patch,
            target: const ResourceRef(
              kind: ResourceKind.event,
              id: 'target',
              parentId: 'calendar',
            ),
            values: {'title': 'Existing'},
          ),
        ],
      );
      expect(plan.changes, isEmpty);
      final calendar = session.data.generalMode.schedules.single;
      await saveUiData(
        session.data.copyWith(
          generalMode: session.data.generalMode.copyWith(
            schedules: [
              calendar.copyWith(
                events: [calendar.events.single.copyWith(notes: 'UI changes')],
              ),
            ],
          ),
        ),
      );
      await expectLater(
        coordinator.commit(planId: plan.id, scope: scope),
        throwsA(problem(OperationErrorCode.conflict)),
      );
      expect(storage.saves, 1);
      expect(
        storage.data.generalMode.schedules.single.events.single.notes,
        'UI changes',
      );
      expect(coordinator.status(plan.operationId), isNull);
    },
  );

  test(
    'an owner change cannot alter the meaning of an approved child create',
    () async {
      final plan = coordinator.prepare(
        scope: scope,
        resources: [createEvent()],
      );
      await saveUiData(
        session.data.copyWith(
          generalMode: session.data.generalMode.copyWith(
            schedules: [
              session.data.generalMode.schedules.single.copyWith(
                name: 'Different owner',
              ),
            ],
          ),
        ),
      );
      await expectLater(
        coordinator.commit(planId: plan.id, scope: scope),
        throwsA(problem(OperationErrorCode.conflict)),
      );
      expect(storage.data.generalMode.schedules.single.events, isEmpty);
      expect(storage.saves, 1);
    },
  );

  test(
    'a source copy still checks the fields overwritten by its command',
    () async {
      await seedEvents([event('source')]);
      final plan = coordinator.prepare(
        scope: scope,
        resources: [
          ResourceMutation(
            kind: ResourceKind.event,
            action: ResourceMutationAction.copy,
            target: const ResourceRef(
              kind: ResourceKind.event,
              id: 'source',
              parentId: 'calendar',
            ),
            values: {'title': 'Fixed copied title'},
          ),
        ],
      );
      final calendar = session.data.generalMode.schedules.single;
      await saveUiData(
        session.data.copyWith(
          generalMode: session.data.generalMode.copyWith(
            schedules: [
              calendar.copyWith(
                events: [
                  calendar.events.single.copyWith(title: 'New source title'),
                ],
              ),
            ],
          ),
        ),
      );
      await expectLater(
        coordinator.commit(planId: plan.id, scope: scope),
        throwsA(problem(OperationErrorCode.conflict)),
      );
      expect(storage.data.generalMode.schedules.single.events, hasLength(1));
    },
  );

  test(
    'an edit completed during the settle wait is retained by the reducer',
    () async {
      final plan = coordinator.prepare(
        scope: scope,
        resources: [createEvent()],
      );
      final entered = Completer<void>(), release = Completer<void>();
      settle = () async {
        entered.complete();
        await release.future;
      };
      final pending = coordinator.commit(planId: plan.id, scope: scope);
      await entered.future;
      await saveUiData(session.data.copyWith(localeCode: 'zh'));
      release.complete();
      await pending;
      expect(storage.data.localeCode, 'zh');
      expect(storage.data.generalMode.schedules.single.events, hasLength(1));
    },
  );

  test(
    'resource validation does not persist an unrelated unsaved UI draft',
    () async {
      final plan = coordinator.prepare(
        scope: scope,
        resources: [createEvent()],
      );
      session.replaceData(session.data.copyWith(localeCode: 'zh'));
      await expectLater(
        coordinator.commit(planId: plan.id, scope: scope),
        throwsA(problem(OperationErrorCode.conflict)),
      );
      expect(session.data.localeCode, 'zh');
      expect(storage.data.localeCode, isNot('zh'));
      expect(storage.saves, 0);
    },
  );

  test(
    'a failed rebased save rolls back to the latest durable UI data',
    () async {
      final plan = coordinator.prepare(
        scope: scope,
        resources: [createEvent()],
      );
      await saveUiData(session.data.copyWith(localeCode: 'zh'));
      storage.error = StateError('disk failure');
      await expectLater(
        coordinator.commit(planId: plan.id, scope: scope),
        throwsA(problem(OperationErrorCode.storageFailure)),
      );
      expect(session.data.localeCode, 'zh');
      expect(session.data.generalMode.schedules.single.events, isEmpty);
      expect(coordinator.status(plan.operationId), isNull);
      expect(publications, 0);
    },
  );

  test('undo records the resource position at the actual commit', () async {
    await seedEvents([event('target'), event('sibling')]);
    final plan = coordinator.prepare(
      scope: scope,
      resources: [
        ResourceMutation(
          kind: ResourceKind.event,
          action: ResourceMutationAction.delete,
          target: const ResourceRef(
            kind: ResourceKind.event,
            id: 'target',
            parentId: 'calendar',
          ),
        ),
      ],
    );
    final calendar = session.data.generalMode.schedules.single;
    await saveUiData(
      session.data.copyWith(
        generalMode: session.data.generalMode.copyWith(
          schedules: [
            calendar.copyWith(events: calendar.events.reversed.toList()),
          ],
        ),
      ),
    );
    final committed = await coordinator.commit(planId: plan.id, scope: scope);
    final change = (committed.receipt.undo!['changes'] as List).single as Map;
    expect(change['beforeIndex'], 1);
    final inverse = coordinator.prepareUndo(
      scope: scope,
      operationId: plan.operationId,
    );
    await coordinator.commit(planId: inverse.id, scope: scope);
    expect(
      storage.data.generalMode.schedules.single.events.map((item) => item.id),
      ['sibling', 'target'],
    );
  });

  test('the generated identity is not replaced after a collision', () async {
    final plan = coordinator.prepare(scope: scope, resources: [createEvent()]);
    final reservedId = plan.changes.single.ref!.id;
    final calendar = session.data.generalMode.schedules.single;
    await saveUiData(
      session.data.copyWith(
        generalMode: session.data.generalMode.copyWith(
          schedules: [
            calendar.copyWith(events: [event(reservedId, 'UI event')]),
          ],
        ),
      ),
    );
    final allocatedBeforeCommit = idSequence;
    await expectLater(
      coordinator.commit(planId: plan.id, scope: scope),
      throwsA(problem(OperationErrorCode.conflict)),
    );
    expect(idSequence, allocatedBeforeCommit);
    expect(
      storage.data.generalMode.schedules.single.events.single.title,
      'UI event',
    );
    expect(storage.saves, 1);
  });

  test(
    'setting dependencies reject a changed but still valid time range',
    () async {
      await saveUiData(
        session.data.copyWith(
          generalMode: session.data.generalMode.copyWith(
            dayStartHour: 6,
            dayEndHour: 22,
          ),
        ),
      );
      final plan = coordinator.prepare(
        scope: scope,
        settings: [const SettingEdit.set('general.dayStartHour', 7)],
      );
      await saveUiData(
        session.data.copyWith(
          generalMode: session.data.generalMode.copyWith(dayEndHour: 21),
        ),
      );
      await expectLater(
        coordinator.commit(planId: plan.id, scope: scope),
        throwsA(problem(OperationErrorCode.conflict)),
      );
      expect(storage.data.generalMode.dayStartHour, 6);
      expect(storage.data.generalMode.dayEndHour, 21);
      expect(storage.saves, 2);
    },
  );

  test(
    'changing a bound time set invalidates a course plan with identical fields',
    () async {
      final set = storage.data.studentMode.periodTimeSets.first;
      final table = TimetableData(
        id: 'table',
        config: TimetableConfig(
          name: 'Classes',
          startDate: DateTime(2026, 10, 5),
          totalWeeks: 16,
          periodTimeSetId: set.id,
        ),
        courses: [
          CourseItem(
            id: 'course',
            name: 'Math',
            teacher: 'Original teacher',
            location: '',
            dayOfWeek: 1,
            semesterWeeks: const [1],
            periods: const [1],
            startMinutes: set.periodTimes.first.startMinutes,
            endMinutes: set.periodTimes.first.endMinutes,
            timeRange: buildTimeRange(
              set.periodTimes.first.startMinutes,
              set.periodTimes.first.endMinutes,
            ),
            credit: 0,
            remarks: '',
            customFields: const {},
          ),
        ],
      );
      storage.data = storage.data.copyWith(
        studentMode: storage.data.studentMode.copyWith(
          activeTimetableId: table.id,
          timetables: [table],
          courseNameColorValues: buildStudentCourseNameColorValuesForTimetables(
            [table],
          ),
        ),
      );
      session = await newSession();
      coordinator = newCoordinator(session);
      final plan = coordinator.prepare(
        scope: scope,
        resources: [
          ResourceMutation(
            kind: ResourceKind.course,
            action: ResourceMutationAction.patch,
            target: const ResourceRef(
              kind: ResourceKind.course,
              id: 'course',
              parentId: 'table',
            ),
            values: {'teacher': 'Agent teacher'},
          ),
        ],
      );
      await saveUiData(
        session.data.copyWith(
          studentMode: session.data.studentMode.copyWith(
            periodTimeSets: [
              for (final item in session.data.studentMode.periodTimeSets)
                if (item.id == set.id)
                  item.copyWith(name: 'Changed time binding')
                else
                  item,
            ],
          ),
        ),
      );
      await expectLater(
        coordinator.commit(planId: plan.id, scope: scope),
        throwsA(problem(OperationErrorCode.conflict)),
      );
      expect(
        storage.data.studentMode.timetables.single.courses.single.teacher,
        'Original teacher',
      );
      expect(storage.saves, 1);
    },
  );

  test(
    'an added reference changes the approved impact of a time set edit',
    () async {
      final set = storage.data.studentMode.periodTimeSets.first;
      final plan = coordinator.prepare(
        scope: scope,
        resources: [
          ResourceMutation(
            kind: ResourceKind.periodTimeSet,
            action: ResourceMutationAction.patch,
            target: ResourceRef(kind: ResourceKind.periodTimeSet, id: set.id),
            values: {'name': 'Agent time set'},
          ),
        ],
      );
      await saveUiData(
        session.data.copyWith(
          studentMode: session.data.studentMode.copyWith(
            activeTimetableId: session.data.studentMode.timetables.isEmpty
                ? 'new-reference'
                : session.data.studentMode.activeTimetableId,
            timetables: [
              ...session.data.studentMode.timetables,
              TimetableData(
                id: 'new-reference',
                config: TimetableConfig(
                  name: 'New reference',
                  startDate: DateTime(2026, 10, 5),
                  totalWeeks: 16,
                  periodTimeSetId: set.id,
                ),
                courses: const [],
              ),
            ],
          ),
        ),
      );
      await expectLater(
        coordinator.commit(planId: plan.id, scope: scope),
        throwsA(problem(OperationErrorCode.conflict)),
      );
      expect(storage.data.studentMode.periodTimeSets.first.name, set.name);
      expect(storage.saves, 1);
    },
  );

  test(
    'derived writes must still equal the complete approved change set',
    () async {
      final plan = coordinator.prepare(
        scope: scope,
        resources: [
          ResourceMutation(
            kind: ResourceKind.calendar,
            action: ResourceMutationAction.create,
            values: {'name': 'New calendar'},
          ),
        ],
      );
      await saveUiData(
        session.data.copyWith(
          generalMode: session.data.generalMode.copyWith(
            schedules: [
              ...session.data.generalMode.schedules,
              const GeneralSchedule(
                id: 'ui-calendar',
                name: 'UI calendar',
                sortOrder: 1,
                events: [],
              ),
            ],
          ),
        ),
      );
      await expectLater(
        coordinator.commit(planId: plan.id, scope: scope),
        throwsA(problem(OperationErrorCode.conflict)),
      );
      expect(storage.data.generalMode.schedules.map((item) => item.id), [
        'calendar',
        'ui-calendar',
      ]);
      expect(storage.saves, 1);
    },
  );

  test(
    'unrelated settings can merge without reading caller-owned values again',
    () async {
      final order = session.data.generalMode.toolbarNavigationOrder.toList();
      final original = order.toList();
      final plan = coordinator.prepare(
        scope: scope,
        settings: [
          SettingEdit.set('general.toolbarNavigationOrder', order),
          const SettingEdit.set('general.showWeekends', false),
        ],
      );
      order.setAll(0, order.reversed.toList());
      await saveUiData(session.data.copyWith(localeCode: 'zh'));
      await coordinator.commit(planId: plan.id, scope: scope);
      expect(storage.data.generalMode.toolbarNavigationOrder, original);
      expect(storage.data.generalMode.showWeekends, isFalse);
      expect(storage.data.localeCode, 'zh');
    },
  );

  test(
    'host drafts keep their snapshot gate and do not rerun arbitrary compilers',
    () async {
      var compilations = 0;
      final plan = coordinator.prepareDraft(
        scope: scope,
        command: const {'hostDraft': true},
        compile: (baseline, context) {
          compilations++;
          return const ResourceMutationCompiler().compile(baseline, [
            createEvent(),
          ], context: context);
        },
      );
      expect(plan.readSet, ['snapshot']);
      await saveUiData(session.data.copyWith(localeCode: 'zh'));
      await expectLater(
        coordinator.commit(planId: plan.id, scope: scope),
        throwsA(problem(OperationErrorCode.conflict)),
      );
      expect(compilations, 1);
      expect(storage.data.generalMode.schedules.single.events, isEmpty);
    },
  );

  test(
    'changing policy while waiting for UI persistence stops the queued write',
    () async {
      scope.policy.update(mode: AgentPermissionMode.ask);
      final plan = coordinator.prepare(
        scope: scope,
        resources: [createEvent()],
      );
      final approval = scope.approve(plan.id);
      final entered = Completer<void>();
      final release = Completer<void>();
      settle = () async {
        entered.complete();
        await release.future;
      };
      final pending = coordinator.commit(
        planId: plan.id,
        scope: scope,
        approval: approval,
      );
      await entered.future;
      scope.policy.update(mode: AgentPermissionMode.plan);
      release.complete();
      await expectLater(pending, throwsA(problem(OperationErrorCode.readOnly)));
      expect(storage.saves, 0);
    },
  );

  test(
    'cancellation after a write is accepted reports its actual durable result',
    () async {
      final plan = coordinator.prepare(
        scope: scope,
        resources: [createEvent()],
      );
      final entered = Completer<void>();
      final release = Completer<void>();
      storage.gate = () async {
        entered.complete();
        await release.future;
      };
      final pending = coordinator.commit(planId: plan.id, scope: scope);
      await entered.future;
      scope.cancel();
      release.complete();
      final result = await pending;
      expect(result.stoppedAfterCommit, isTrue);
      expect(
        storage.data.applicationLedger!.receiptFor(plan.operationId),
        result.receipt,
      );
      expect(storage.data.generalMode.schedules.single.events, hasLength(1));
    },
  );

  test(
    'storage failure cannot publish a receipt or leave an optimistic event',
    () async {
      final plan = coordinator.prepare(
        scope: scope,
        resources: [createEvent()],
      );
      storage.error = StateError('disk failure');
      await expectLater(
        coordinator.commit(planId: plan.id, scope: scope),
        throwsA(problem(OperationErrorCode.storageFailure)),
      );
      expect(coordinator.status(plan.operationId), isNull);
      expect(session.data.generalMode.schedules.single.events, isEmpty);
      expect(publications, 0);
    },
  );

  test('uncertain disk completion is a distinct recovery state', () async {
    final plan = coordinator.prepare(scope: scope, resources: [createEvent()]);
    storage.error = StorageWriteStateUnknownException(
      writeError: StateError('unknown'),
      rollbackError: StateError('unknown rollback'),
      recoveryArtifacts: const ['memory://test'],
    );
    await expectLater(
      coordinator.commit(planId: plan.id, scope: scope),
      throwsA(problem(OperationErrorCode.outcomeUnknown)),
    );
    expect(session.canWrite, isFalse);
    expect(
      () => coordinator.status(plan.operationId),
      throwsA(problem(OperationErrorCode.outcomeUnknown)),
    );
  });

  test('maintenance reservations and expired plans cannot reuse prior authorization', () async {
    final first = coordinator.prepare(scope: scope, resources: [createEvent()]);
    sessionRevision++;
    await expectLater(
      coordinator.commit(planId: first.id, scope: scope),
      throwsA(problem(OperationErrorCode.expired)),
    );
    final second = coordinator.prepare(
      scope: scope,
      resources: [createEvent()],
    );
    clock = clock.add(const Duration(hours: 1));
    await expectLater(
      coordinator.commit(planId: second.id, scope: scope),
      throwsA(problem(OperationErrorCode.expired)),
    );
    expect(storage.saves, 0);
  });

  test(
    'evicted operation IDs are expired and cannot be replayed as new creates',
    () {
      final generation = coordinator.generation;
      final oldId = '$generation/1/${id()}';
      var ledger = ApplicationLedger(generation: generation);
      for (var sequence = 1; sequence <= 130; sequence++) {
        ledger = ledger.append(
          OperationReceipt(
            operationId: sequence == 1
                ? oldId
                : '$generation/$sequence/${id()}',
            sequence: sequence,
            commandDigest: 'a' * 64,
            completedAtIso: clock.toIso8601String(),
            result: const {},
          ),
        );
      }
      final data = session.data.copyWith(applicationLedger: ledger);
      storage.data = data;
      session.restoreData(data);
      expect(
        () => coordinator.prepare(
          scope: scope,
          resources: [createEvent()],
          operationId: oldId,
        ),
        throwsA(problem(OperationErrorCode.expired)),
      );
      expect(storage.saves, 0);
    },
  );

  test(
    'fingerprints ignore object field ordering while preserving explicit null',
    () {
      expect(
        mutationDigest({
          'b': 2,
          'a': [1],
        }),
        mutationDigest({
          'a': [1],
          'b': 2,
        }),
      );
      expect(mutationDigest({'a': null}), isNot(mutationDigest({})));
      expect(
        () => mutationDigest({1: 'invalid'}),
        throwsA(problem(OperationErrorCode.invalidArgument)),
      );
    },
  );
}
