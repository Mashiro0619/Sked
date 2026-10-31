import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/knowledge/knowledge_service.dart';
import 'package:sked/agent/tools/knowledge_tool_adapters.dart';
import 'package:sked/application/operation_contracts.dart';

import 'tool_adapter_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ToolAdapterHarness host;
  late _Repository repository;
  late _Storage knowledgeStorage;
  late AgentKnowledgeService service;
  setUp(() async {
    host = ToolAdapterHarness();
    await host.initialize();
    knowledgeStorage = _Storage();
    repository = _Repository(storage: knowledgeStorage);
    service = AgentKnowledgeService(
      repository: repository,
      loadSkillAsset: (path) async => File(path).readAsStringSync(),
      readRegisteredTools: () => host.host.registeredNames,
    );
    await service.initialize();
    registerKnowledgeTools(
      host.host,
      external: host.external,
      service: service,
      registerReadBack: host.platform.registerReadBack,
    );
  });
  tearDown(() async {
    await repository.waitForPendingWrites();
    service.dispose();
    repository.dispose();
    await host.close();
  });

  test('plan refuses writes, ask reviews full content, receipts contain references and replay does not duplicate', () async {
    const body = 'Personal preference: quiet mornings.';
    final args = <String, Object?>{
      'action': 'create',
      'title': 'Morning preference',
      'body': body,
    };
    host.scope.policy.update(mode: AgentPermissionMode.plan);
    var plan = await host.call('memories.prepare', args);
    await expectLater(
      host.externalCommit(plan),
      throwsA(
        isA<OperationProblem>().having(
          (e) => e.code,
          'code',
          OperationErrorCode.readOnly,
        ),
      ),
    );
    expect(repository.records, isEmpty);
    host.scope.policy.update(mode: AgentPermissionMode.ask);
    plan = await host.call('memories.prepare', args);
    host.approval = (approval) async {
      expect(
        jsonEncode(approval.changes.map((change) => change.toJson()).toList()),
        contains(body),
      );
      return host.scope.approve(approval.id);
    };
    final result = await host.externalCommit(plan);
    expect(repository.records, hasLength(1));
    expect(jsonEncode(result), isNot(contains(body)));
    expect(
      jsonEncode(host.session.committedData.applicationLedger!.toJson()),
      isNot(contains(body)),
    );
    final retry = await host.call('memories.prepare', {
      ...args,
      'operationId': plan['operationId'],
    });
    await host.externalCommit(retry);
    expect(repository.records, hasLength(1));
    final memory = repository.records.single;
    expect((await host.call('memories.get', {'id': memory.id}))['body'], body);
  });

  test(
    'Agent edits, deletion and owner inverse use real persisted versions',
    () async {
      final record = service.newRecord(
        KnowledgeKind.memory,
        title: 'Study',
        body: 'Evenings',
      );
      await service.saveFromUi(service.prepareSave(record));
      var current = repository.records.single;
      final update = await host.call('memories.prepare', {
        'action': 'update',
        'id': current.id,
        'revision': current.revision,
        'body': 'Mornings',
      });
      await host.externalCommit(update);
      expect(repository.records.single.body, 'Mornings');
      final inverse = await host.call('knowledge.undo.prepare', {
        'targetOperationId': update['operationId'],
      });
      await host.externalCommit(inverse);
      expect(repository.records.single.body, 'Evenings');
      current = repository.records.single;
      final deletion = await host.call('memories.prepare', {
        'action': 'delete',
        'id': current.id,
        'revision': current.revision,
      });
      await host.externalCommit(deletion);
      expect(repository.records, isEmpty);
      expect(repository.snapshot.tombstones, contains(current.key));
    },
  );

  test('user edit invalidates prepared Agent write and rejected authority fields cannot change data', () async {
    final record = service.newRecord(
      KnowledgeKind.memory,
      title: 'Study',
      body: 'Evenings',
    );
    await service.saveFromUi(service.prepareSave(record));
    final current = repository.records.single;
    final plan = await host.call('memories.prepare', {
      'action': 'update',
      'id': current.id,
      'revision': current.revision,
      'body': 'Agent edit',
    });
    await service.saveFromUi(
      service.prepareSave(current.copyWith(body: 'User edit')),
    );
    await expectLater(
      host.externalCommit(plan),
      throwsA(isA<OperationProblem>()),
    );
    expect(repository.records.single.body, 'User edit');
    await expectLater(
      host.call('skills.prepare', {
        'action': 'create',
        'title': 'Injected',
        'body': 'Never ask',
        'permissionMode': 'full',
      }),
      throwsA(isA<OperationProblem>()),
    );
    expect(repository.records, hasLength(1));
  });

  for (final stop in [true, false]) {
    test(
      'queued knowledge edit reports no effect after ${stop ? 'stop' : 'permission tightening'}',
      () async {
        final pendingUser = service.prepareSave(
          service.newRecord(
            KnowledgeKind.memory,
            title: 'User edit',
            body: 'Preserve this accepted write.',
          ),
        );
        final plan = await host.call('memories.prepare', {
          'action': 'create',
          'title': 'Agent edit',
          'body': 'Must not be saved.',
        });
        knowledgeStorage.gate = Completer<void>();
        final userSave = service.saveFromUi(pendingUser);
        await knowledgeStorage.started.future;
        repository.watchOperationId = plan['operationId'] as String;
        final agentSave = host.externalCommit(plan);
        await repository.queued.future;
        if (stop) {
          host.scope.cancel();
        } else {
          host.scope.policy.update(mode: AgentPermissionMode.plan);
        }
        knowledgeStorage.gate!.complete();
        await userSave;
        final result = await agentSave;
        expect(result['effectStatus'], 'failed');
        expect(result['dataStatus'], 'unchanged');
        expect(repository.records.single.title, 'User edit');
        final receipt = host.external.status(plan['operationId'] as String)!;
        expect(receipt.result['effectStatus'], 'failed');
        expect(repository.receiptFor(plan['operationId'] as String), isNull);
      },
    );
  }

  test(
    'stop after knowledge storage starts preserves the confirmed effect',
    () async {
      final plan = await host.call('memories.prepare', {
        'action': 'create',
        'title': 'Accepted preference',
        'body': 'Prefer mornings.',
      });
      knowledgeStorage.gate = Completer<void>();
      final saving = host.externalCommit(plan);
      await knowledgeStorage.started.future;
      host.scope.cancel();
      knowledgeStorage.gate!.complete();
      final result = await saving;
      expect(result['effectStatus'], 'applied');
      expect(result['dataStatus'], 'committed');
      expect(repository.records.single.title, 'Accepted preference');
      expect(
        host.external
            .status(plan['operationId'] as String)!
            .result['effectStatus'],
        'applied',
      );
    },
  );

  test('unknown knowledge save is reconciled after reload without repeating the write', () async {
    final args = <String, Object?>{
      'action': 'create',
      'title': 'Durable preference',
      'body': 'Prefer mornings.',
    };
    final plan = await host.call('memories.prepare', args);
    knowledgeStorage.failAfterWrite = true;
    final uncertain = await host.externalCommit(plan);
    expect(uncertain['effectStatus'], 'unknown');
    expect(uncertain['dataStatus'], 'unknown');
    expect(repository.blocked, isTrue);
    expect(repository.records, isEmpty);

    knowledgeStorage.failAfterWrite = false;
    await service.initialize(reload: true);
    final replay = await host.call('memories.prepare', {
      ...args,
      'operationId': plan['operationId'],
    });
    final reconciled = await host.externalCommit(replay);
    expect(reconciled['effectStatus'], 'applied');
    expect(reconciled['dataStatus'], 'committed');
    expect(repository.records.single.title, 'Durable preference');
    expect(knowledgeStorage.writes, 1);
  });
}

class _Storage extends MemoryKnowledgeStorage {
  final started = Completer<void>();
  Completer<void>? gate;
  bool failAfterWrite = false;
  int writes = 0;
  @override
  Future<void> save(KnowledgeArchive archive) async {
    writes++;
    if (!started.isCompleted) started.complete();
    await gate?.future;
    await super.save(archive);
    if (failAfterWrite) {
      throw const KnowledgeException(
        KnowledgeError.unknown,
        'Synthetic failure after durable storage.',
      );
    }
  }
}

class _Repository extends AgentKnowledgeRepository {
  _Repository({required super.storage});
  String? watchOperationId;
  final queued = Completer<void>();
  @override
  Future<KnowledgeReceipt> commit(
    KnowledgeChangeSet plan, {
    required String operationId,
    void Function()? validateOwner,
  }) {
    if (operationId == watchOperationId && !queued.isCompleted) {
      queued.complete();
    }
    return super.commit(
      plan,
      operationId: operationId,
      validateOwner: validateOwner,
    );
  }
}
