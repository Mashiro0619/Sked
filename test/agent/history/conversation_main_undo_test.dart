import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/history/conversation_history.dart';
import 'package:sked/agent/history/conversation_history_preflight.dart';
import 'package:sked/agent/history/conversation_main_undo.dart';
import 'package:sked/agent/history/conversation_redo_coordinator.dart';
import 'package:sked/application/mutation_coordinator.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/application/resource_contracts.dart';
import 'package:sked/application/resource_mutations.dart';
import 'package:sked/controllers/app_session.dart';
import 'package:sked/data/app_repository.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/models/timetable_models.dart';

void main() {
  test('a restarted participant commits the sealed range once and verifies its result', () async {
    final fixture = await _Fixture.create();
    final create = await fixture.createEvent();
    final event =
        fixture.session.data.generalMode.schedules.single.events.single;
    final update = await fixture.updateEvent(event.id, 'Updated');
    final ticket = await fixture.participant().prepare(
      batchId: 'redo',
      operationIds: [create, update],
    );
    final restored = ConversationUndoTicket.fromJson(
      jsonDecode(jsonEncode(ticket.toJson())),
    );
    final restarted = fixture.participant();
    expect(await restarted.readState(restored), ConversationUndoState.prepared);
    final saves = fixture.storage.saves;
    await restarted.validate(restored);
    await restarted.commit(restored);
    expect(fixture.storage.saves, saves + 1);
    expect(fixture.session.data.generalMode.schedules.single.events, isEmpty);
    expect(await restarted.readState(restored), ConversationUndoState.applied);
    final again = fixture.participant();
    expect(await again.readState(restored), ConversationUndoState.applied);
    expect(fixture.storage.saves, saves + 1);
  });

  test('a mismatched ticket cannot execute a cached prepared plan', () async {
    final fixture = await _Fixture.create();
    final operationId = await fixture.createEvent();
    final participant = fixture.participant();
    final ticket = await participant.prepare(
      batchId: 'redo',
      operationIds: [operationId],
    );
    final wrong = ConversationUndoTicket(
      owner: ticket.owner,
      token: ticket.token,
      digest: '0' * 64,
      operationIds: ticket.operationIds,
    );
    final before = fixture.storage.saves;
    await expectLater(
      participant.commit(wrong),
      throwsA(_error(ConversationHistoryError.conflict)),
    );
    expect(fixture.storage.saves, before);
    expect(
      fixture.session.data.generalMode.schedules.single.events,
      hasLength(1),
    );
  });

  test(
    'target drift after preflight prevents the complete range from committing',
    () async {
      final fixture = await _Fixture.create();
      final first = await fixture.createEvent();
      final event =
          fixture.session.data.generalMode.schedules.single.events.single;
      final participant = fixture.participant();
      final ticket = await participant.prepare(
        batchId: 'redo',
        operationIds: [first],
      );
      await fixture.updateEvent(event.id, 'A later manual change');
      final before = fixture.storage.saves;
      await expectLater(
        participant.validate(ticket),
        throwsA(_error(ConversationHistoryError.conflict)),
      );
      expect(fixture.storage.saves, before);
      expect(
        fixture.session.data.generalMode.schedules.single.events.single.title,
        'A later manual change',
      );
      expect(
        fixture.session.data.applicationLedger!.receipts.where(
          (receipt) => receipt.result['undoBatchId'] == 'redo',
        ),
        isEmpty,
      );
    },
  );

  test('an applied receipt with a changed post-state is unresolved during recovery', () async {
    final fixture = await _Fixture.create();
    await fixture.createEvent();
    final event =
        fixture.session.data.generalMode.schedules.single.events.single;
    final update = await fixture.updateEvent(event.id, 'Updated');
    final participant = fixture.participant();
    final ticket = await participant.prepare(
      batchId: 'redo',
      operationIds: [update],
    );
    await participant.validate(ticket);
    await participant.commit(ticket);
    expect(await participant.readState(ticket), ConversationUndoState.applied);
    await fixture.updateEvent(event.id, 'Outside the recovery barrier');
    expect(await participant.readState(ticket), ConversationUndoState.unknown);
  });

  test(
    'the host scope still controls permission at the final commit boundary',
    () async {
      final fixture = await _Fixture.create();
      final operation = await fixture.createEvent();
      final participant = fixture.participant();
      final ticket = await participant.prepare(
        batchId: 'redo',
        operationIds: [operation],
      );
      await participant.validate(ticket);
      fixture.scope.policy.update(mode: AgentPermissionMode.plan);
      final before = fixture.storage.saves;
      await expectLater(
        participant.commit(ticket),
        throwsA(_error(ConversationHistoryError.permissionDenied)),
      );
      expect(fixture.storage.saves, before);
    },
  );
}

Matcher _error(ConversationHistoryError code) =>
    isA<ConversationHistoryException>().having(
      (error) => error.code,
      'code',
      code,
    );

class _Fixture {
  _Fixture(this.storage, this.session) {
    mutations = MutationCoordinator(
      session: session,
      settlePendingChanges: () async {},
      dataSessionRevision: () => 0,
      clock: () => DateTime.utc(2026, 10, 31),
      idGenerator: () =>
          '00000000-0000-4000-8000-${(++_id).toString().padLeft(12, '0')}',
    );
  }

  final _Storage storage;
  final AppSession session;
  late final MutationCoordinator mutations;
  var _id = 0;
  final scope = OperationScope(
    id: 'host',
    policy: OperationPolicy(enabled: true, mode: AgentPermissionMode.full),
  );

  static Future<_Fixture> create() async {
    final data = buildInitialAppData(buildDefaultPeriodTimes()).copyWith(
      generalMode: const GeneralScheduleData(
        activeScheduleId: 'calendar',
        selectedDateIso: '2026-10-31',
        schedules: [GeneralSchedule(id: 'calendar', name: 'Study', events: [])],
      ),
    );
    final storage = _Storage(data);
    final repository = AppRepository(storage: storage);
    final loaded = await repository.load();
    final session = AppSession(
      repository: repository,
      initialData: loaded!,
      requireMutationAllowed: () {},
    );
    addTearDown(session.close);
    return _Fixture(storage, session);
  }

  ConversationMainUndoParticipant participant() =>
      ConversationMainUndoParticipant(
        mutations: mutations,
        readCommittedData: () => session.committedData,
        scope: () => scope,
      );

  Future<String> createEvent() => _commit(
    ResourceMutation(
      kind: ResourceKind.event,
      action: ResourceMutationAction.create,
      destinationParentId: 'calendar',
      values: {
        'title': 'Study',
        'start': '2026-10-31T09:00:00',
        'end': '2026-10-31T10:00:00',
      },
    ),
  );

  Future<String> updateEvent(String id, String title) => _commit(
    ResourceMutation(
      kind: ResourceKind.event,
      action: ResourceMutationAction.patch,
      target: ResourceRef(
        kind: ResourceKind.event,
        id: id,
        parentId: 'calendar',
      ),
      values: {'title': title},
    ),
  );

  Future<String> _commit(ResourceMutation command) async {
    final plan = mutations.prepare(scope: scope, resources: [command]);
    await mutations.commit(planId: plan.id, scope: scope);
    return plan.operationId;
  }
}

class _Storage implements TimetableStorage {
  _Storage(this.data);
  AppData data;
  int saves = 0;
  @override
  Future<StorageLoadResult> load() async =>
      StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);
  @override
  Future<void> save(AppData value) async {
    data = AppData.decodeStorageSnapshot(value.encode());
    saves++;
  }

  @override
  Future<String?> filePath() async => null;
}
