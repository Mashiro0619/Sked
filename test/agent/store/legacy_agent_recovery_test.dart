import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/knowledge/knowledge_service.dart';
import 'package:sked/agent/store/agent_store.dart';
import 'package:sked/agent/tools/knowledge_tool_adapters.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/application/operation_contracts.dart';

import '../../support/workspace_harness.dart';
import '../tools/tool_adapter_test_support.dart';

class _UnknownKnowledgeSave extends MemoryKnowledgeStorage {
  bool failAfterWrite = false;
  int failedWrites = 0;

  @override
  Future<void> save(KnowledgeArchive archive) async {
    await super.save(archive);
    if (failAfterWrite) {
      failedWrites++;
      throw const KnowledgeException(
        KnowledgeError.unknown,
        'Synthetic lost acknowledgement after the side-store save.',
      );
    }
  }
}

String _slot(Map<String, Object?> archive, int revision) {
  final source = jsonEncode(archive);
  return jsonEncode({
    'version': 1,
    'revision': revision,
    'source': source,
    'checksum': sha256.convert(utf8.encode(source)).toString(),
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final hasReceipt in [true, false]) {
    test(
      'cutover checks the retired knowledge receipt, present=$hasReceipt',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'sked-legacy-knowledge-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final host = ToolAdapterHarness();
        await host.initialize();
        addTearDown(host.close);
        final storage = _UnknownKnowledgeSave();
        final repository = AgentKnowledgeRepository(storage: storage);
        final service = AgentKnowledgeService(
          repository: repository,
          loadSkillAsset: (path) => File(path).readAsString(),
          readRegisteredTools: () => host.host.registeredNames,
        );
        addTearDown(service.dispose);
        addTearDown(repository.dispose);
        await service.initialize();
        registerKnowledgeTools(
          host.host,
          external: host.external,
          service: service,
          registerReadBack: host.platform.registerReadBack,
        );
        final plan = await host.call('memories.prepare', {
          'action': 'create',
          'title': 'Durable preference',
          'body': 'Prefer mornings.',
        });
        storage.failAfterWrite = true;
        final uncertain = await host.externalCommit(plan);
        expect(uncertain['effectStatus'], 'unknown');
        final operationId = plan['operationId'] as String;
        final savedArchive = Map<String, Object?>.from(
          jsonDecode(storage.source!) as Map,
        )..['version'] = 2;
        final archive = {...savedArchive};
        if (!hasReceipt) archive['receipts'] = <Object?>[];
        final encoded = _slot(archive, archive['storageRevision'] as int);
        for (final index in [0, 1]) {
          await File('${directory.path}/Sked_agent_knowledge.$index.json')
              .writeAsString(encoded, flush: true);
        }
        final attachmentDirectory = Directory(
          '${directory.path}/Sked_agent_attachments',
        );
        await attachmentDirectory.create();
        final oldAttachment = File('${attachmentDirectory.path}/old-file');
        await oldAttachment.writeAsString('retired attachment');
        final initial = host.session.committedData;
        final main = WorkspaceMemoryStorage(initial);
        var store = AgentStore.open(
          filePath: '${directory.path}/Sked_agent.sqlite',
        );
        var app = await workspaceProvider(storage: main, agentStore: store);
        var opened = true;
        Future<void> close() async {
          if (!opened) return;
          opened = false;
          await app.shutdown.quiesce();
          app.dispose();
          await app.backups.selective.close();
          await app.session.close();
          await store.close();
        }

        Future<void> reopen() async {
          await close();
          store = AgentStore.open(
            filePath: '${directory.path}/Sked_agent.sqlite',
          );
          app = await workspaceProvider(storage: main, agentStore: store);
          opened = true;
        }

        addTearDown(close);
        expect(app.session.canWrite, isTrue);
        expect(await oldAttachment.exists(), isFalse);
        final receipt = app.session.committedData.applicationLedger!.receiptFor(
          operationId,
        )!;
        expect(
          receipt.result['effectStatus'],
          hasReceipt ? 'applied' : 'unknown',
        );
        expect(storage.failedWrites, 1);
        expect(
          app.session.committedData.agentSettings.toJson(),
          initial.agentSettings.toJson(),
        );
        expect(
          app.session.committedData.generalMode.toJson(),
          initial.generalMode.toJson(),
        );
        expect(
          await File('${directory.path}/Sked_agent_knowledge.0.json').exists(),
          !hasReceipt,
        );
        expect((await store.knowledge.load()).archive.records, isEmpty);
        expect(
          await store.readMetadata('legacy_cutover'),
          hasReceipt ? 'complete' : 'pending',
        );
        if (!hasReceipt) {
          await attachmentDirectory.create();
          final newAttachment = File('${attachmentDirectory.path}/new-file');
          await newAttachment.writeAsString('new Agent attachment');
          final retained = await store.readRecord(
            'legacy_pending_operation',
            'legacy_cutover',
            operationId,
          );
          expect(retained!['operationId'], operationId);
          expect(
            (retained['receipt'] as Map)['commandDigest'],
            receipt.commandDigest,
          );
          await app.agent.initialize();
          await app.agent.conversations.create(
            id: 'replacement-chat',
            title: 'New Agent data',
          );
          final calendar =
              app.session.committedData.generalMode.schedules.first;
          await app.session.commitMutation(
            (current) => current.copyWith(
              generalMode: current.generalMode.withSchedule(
                calendar.copyWith(name: 'Unrelated edit'),
              ),
            ),
            expectedEpoch: null,
          );
          await reopen();
          expect(app.session.canWrite, isTrue);
          expect(
            app.session.committedData.generalMode.schedules.first.name,
            'Unrelated edit',
          );
          expect(
            app.session.committedData.applicationLedger!
                .receiptFor(operationId)!
                .result['effectStatus'],
            'unknown',
          );
          expect(
            await store.readRecord(
              'legacy_pending_operation',
              'legacy_cutover',
              operationId,
            ),
            isNotNull,
          );
          expect(await store.readConversation('replacement-chat'), isNotNull);
          final restoredEvidence = _slot(
            savedArchive,
            savedArchive['storageRevision'] as int,
          );
          for (final index in [0, 1]) {
            await File('${directory.path}/Sked_agent_knowledge.$index.json')
                .writeAsString(restoredEvidence, flush: true);
          }
          final scope = OperationScope(
            id: 'legacy-readback',
            policy: OperationPolicy(
              enabled: true,
              mode: AgentPermissionMode.full,
            ),
          );
          try {
            final observed = await app.agent.tools.execute(
              ProviderToolCall(
                id: 'legacy-readback',
                name: 'external.reconcile',
                arguments: jsonEncode({'operationId': operationId}),
              ),
              scope,
              (_) async => null,
            );
            expect(observed['effectStatus'], 'applied');
          } finally {
            app.agent.tools.finishScope(scope);
            scope.cancel();
          }
          await reopen();
          expect(await store.readMetadata('legacy_cutover'), 'complete');
          expect(
            await store.readRecord(
              'legacy_pending_operation',
              'legacy_cutover',
              operationId,
            ),
            isNull,
          );
          expect(
            await File('${directory.path}/Sked_agent_knowledge.0.json')
                .exists(),
            isFalse,
          );
          expect(await newAttachment.readAsString(), 'new Agent attachment');
          expect(
            app.session.committedData.applicationLedger!
                .receiptFor(operationId)!
                .result['effectStatus'],
            'applied',
          );
          expect(
            app.session.committedData.generalMode.schedules.first.name,
            'Unrelated edit',
          );
          expect(storage.failedWrites, 1);
        }
      },
    );
  }
}
