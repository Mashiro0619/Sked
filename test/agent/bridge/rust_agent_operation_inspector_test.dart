import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/bridge/generated/api/contracts.dart' as native;
import 'package:sked/agent/bridge/generated/api/models.dart' as view;
import 'package:sked/agent/bridge/rust_agent_operation_inspector.dart';
import 'package:sked/agent/operations/tool_outcome.dart';
import 'package:sked/application/external_operation_coordinator.dart';
import 'package:sked/application/mutation_coordinator.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/application/resource_contracts.dart';
import 'package:sked/application/resource_mutations.dart';
import 'package:sked/controllers/app_session.dart';
import 'package:sked/data/app_repository.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/models/application_ledger.dart';
import 'package:sked/models/timetable_models.dart';

void main() {
  test('lost main-save acknowledgement resolves after reload without another write', () async {
    final fixture = await _Fixture.create();
    final plan = fixture.prepare();
    fixture.storage.loseNextReply = true;
    await expectLater(
      fixture.mutations.commit(planId: plan.id, scope: fixture.scope),
      throwsA(isA<OperationProblem>()),
    );
    expect(
      (await fixture.inspect(plan.operationId))['status'],
      'outcome_unknown',
    );
    final stored = await fixture.session.repository.retryLoad();
    fixture.session.restoreData(stored!);
    // Startup receipt checks run before the UI marks the session loaded.
    expect(fixture.session.isLoaded, isFalse);
    final result = await fixture.inspect(plan.operationId);
    expect(result['status'], 'committed');
    expect(result['operationId'], plan.operationId);
    expect(result['changes'], hasLength(1));
    expect(fixture.storage.saves, 1);
    expect(
      fixture.storage.data.generalMode.schedules.single.events,
      hasLength(1),
    );
  });

  test(
    'only a missing receipt in the current generation proves non-execution',
    () async {
      final fixture = await _Fixture.create();
      final plan = fixture.prepare();
      expect(
        (await fixture.inspect(plan.operationId))['status'],
        'not_executed',
      );
      fixture.storage.data = fixture.storage.data.copyWith(
        applicationLedger: ApplicationLedger(
          generation: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        ),
      );
      fixture.session.restoreData(
        (await fixture.session.repository.retryLoad())!,
      );
      expect(
        (await fixture.inspect(plan.operationId))['status'],
        'outcome_unknown',
      );
      expect(fixture.storage.saves, 0);
    },
  );

  for (final state in ['pending', 'unknown', 'applied']) {
    test(
      'external $state receipts preserve their outcome without executing effects',
      () async {
        final fixture = await _Fixture.create();
        final generation = fixture.mutations.generation;
        final operationId =
            '$generation/1/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
        fixture.storage.data = fixture.storage.data.copyWith(
          applicationLedger: ApplicationLedger(
            generation: generation,
            nextSequence: 2,
            receipts: [
              OperationReceipt(
                operationId: operationId,
                sequence: 1,
                commandDigest: 'a' * 64,
                completedAtIso: '2026-11-10T00:00:00Z',
                result: {
                  'kind': 'external',
                  'operationId': operationId,
                  'generation': generation,
                  'sequence': 1,
                  'action': 'file.write',
                  'arguments': const <String, Object?>{},
                  'version': null,
                  'status': state == 'applied' ? 'applied' : 'effectsPending',
                  'effectStatus': state,
                  'dataStatus': 'unchanged',
                  'effectResult': const <String, Object?>{},
                },
              ),
            ],
          ),
        );
        fixture.session.restoreData(
          (await fixture.session.repository.retryLoad())!,
        );
        final result = await fixture.inspect(operationId, external: true);
        expect(result['effectStatus'], state);
        expect(
          ToolOutcome.fromResult(result).kind,
          state == 'applied'
              ? ToolOutcomeKind.saved
              : ToolOutcomeKind.needsReconciliation,
        );
        expect(fixture.storage.saves, 0);
      },
    );
  }
}

class _Fixture {
  _Fixture(this.storage, this.session) {
    mutations = MutationCoordinator(
      session: session,
      settlePendingChanges: () async {},
      dataSessionRevision: () => 0,
    );
    final external = ExternalOperationCoordinator(
      session: session,
      settlePendingChanges: () async {},
      dataSessionRevision: () => 0,
      fallbackGeneration: () => mutations.generation,
    );
    inspector = RustAgentOperationInspector(
      session: session,
      mutations: mutations,
      external: external,
    );
  }

  final _Storage storage;
  final AppSession session;
  late final MutationCoordinator mutations;
  late final RustAgentOperationInspector inspector;
  final scope = OperationScope(
    id: 'receipt-inspection',
    policy: OperationPolicy(enabled: true, mode: AgentPermissionMode.full),
  );

  static Future<_Fixture> create() async {
    final data = buildInitialAppData(buildDefaultPeriodTimes()).copyWith(
      generalMode: const GeneralScheduleData(
        activeScheduleId: 'calendar',
        selectedDateIso: '2026-11-10',
        schedules: [GeneralSchedule(id: 'calendar', name: 'Study', events: [])],
      ),
    );
    final storage = _Storage(data);
    final repository = AppRepository(storage: storage);
    final session = AppSession(
      repository: repository,
      initialData: (await repository.load())!,
      requireMutationAllowed: () {},
    );
    addTearDown(session.close);
    return _Fixture(storage, session);
  }

  PreparedMutation prepare() => mutations.prepare(
    scope: scope,
    resources: [
      ResourceMutation(
        kind: ResourceKind.event,
        action: ResourceMutationAction.create,
        destinationParentId: 'calendar',
        values: {
          'title': 'Study',
          'start': '2026-11-10T09:00:00',
          'end': '2026-11-10T10:00:00',
        },
      ),
    ],
  );

  Future<Map<String, Object?>> inspect(String id, {bool external = false}) =>
      inspector.read(
        native.HostRequest(
          id: 'inspect',
          kind: native.HostRequestKind.inspectOperation,
          conversationId: 'conversation',
          owner: external
              ? view.ViewOperationStore.external_
              : view.ViewOperationStore.main,
          operationIds: [id],
          arguments: view.JsonPayload(json: jsonEncode({'operationId': id})),
        ),
      );
}

class _Storage implements TimetableStorage {
  _Storage(this.data);
  AppData data;
  int saves = 0;
  bool loseNextReply = false;

  @override
  Future<StorageLoadResult> load() async =>
      StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);

  @override
  Future<void> save(AppData value) async {
    data = AppData.decodeStorageSnapshot(value.encode());
    saves++;
    if (loseNextReply) {
      loseNextReply = false;
      throw const StorageWriteStateUnknownException(
        writeError: 'The save reply was lost.',
        rollbackError: 'The caller cannot establish the durable state.',
      );
    }
  }

  @override
  Future<String?> filePath() async => null;
}
