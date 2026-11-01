import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/connection/agent_credential_store.dart';
import 'package:sked/agent/knowledge/knowledge_models.dart';
import 'package:sked/agent/knowledge/knowledge_storage.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/services/desktop_layout_preferences.dart';

import 'acceptance_harness.dart';
import 'write_tool_coverage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AcceptanceHarness h;
  late _TrackingKnowledgeStorage knowledgeStorage;
  setUp(() async {
    knowledgeStorage = _TrackingKnowledgeStorage();
    h = AcceptanceHarness();
    await h.initialize(knowledgeStorage: knowledgeStorage);
  });
  tearDown(() async {
    await h.close();
  });

  test('all actual tools have an explicit effect and regression owner', () {
    expect(
      readOnlyToolInventory.intersection(writeToolCoverage.keys.toSet()),
      isEmpty,
    );
    expect(h.app.agent.tools.registeredNames, {
      ...readOnlyToolInventory,
      ...writeToolCoverage.keys,
    }, reason: 'Classify new tools and connect their domain failure suite.');
    for (final coverage in writeToolCoverage.values) {
      expect(sharedFailureSuites[coverage.boundary], isNotEmpty);
      expect(coverage.domainSuite, startsWith('test/'));
    }
  });

  test('every write entry rejects unknown fields before any persisted or native effect', () async {
    await h.run(() async {
      final knowledge = h.app.agent.knowledge;
      await knowledge.initialize();
      await knowledge.saveFromUi(
        knowledge.prepareSave(
          knowledge.newRecord(
            KnowledgeKind.memory,
            title: 'Keep this memory',
            body: 'Invalid tool input must preserve this saved content.',
          ),
        ),
      );
      expect(knowledgeStorage.writeCount, greaterThan(0));
      expect(knowledgeStorage.source, contains('Keep this memory'));
      final before = h.saved.encode();
      final beforeConversations = h.conversations.source;
      final beforeKnowledge = knowledgeStorage.source;
      final beforeKnowledgeWrites = knowledgeStorage.writeCount;
      final beforeKnowledgeSnapshot = knowledge.repository.snapshot.encode();
      final beforePermission = h.gateway.permission;
      final beforeCredentials = {
        for (final slot in AgentCredentialSlot.values)
          slot: await h.credentials.read(slot),
      };
      for (final name in writeToolCoverage.keys) {
        await expectLater(
          h.call(name, {'unregistered_argument': true}),
          throwsA(
            isA<OperationProblem>().having(
              (error) => error.code,
              'code',
              OperationErrorCode.invalidArgument,
            ),
          ),
          reason: '$name must reject unknown tool fields before starting work.',
        );
        expect(h.saved.encode(), before, reason: name);
        expect(h.conversations.source, beforeConversations, reason: name);
        expect(knowledgeStorage.source, beforeKnowledge, reason: name);
        expect(
          knowledgeStorage.writeCount,
          beforeKnowledgeWrites,
          reason: name,
        );
        expect(
          knowledge.repository.snapshot.encode(),
          beforeKnowledgeSnapshot,
          reason: name,
        );
        expect(h.gateway.permission, beforePermission, reason: name);
        expect(h.writtenArtifacts, isEmpty, reason: name);
        expect(h.navigationTargets, isEmpty, reason: name);
        expect(h.developer.assistantVisible, isFalse, reason: name);
        for (final region in DesktopLayoutRegion.values) {
          expect(h.layout.preferenceFor(region), isNull, reason: name);
        }
        for (final slot in AgentCredentialSlot.values) {
          expect(
            await h.credentials.read(slot),
            beforeCredentials[slot],
            reason: name,
          );
        }
      }
      expect((await h.call('school_sites.list'))['items'], isEmpty);
    });
  });
}

class _TrackingKnowledgeStorage extends MemoryKnowledgeStorage {
  int writeCount = 0;
  @override
  Future<void> save(KnowledgeArchive archive) async {
    writeCount++;
    await super.save(archive);
  }
}
