import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sked/agent/attachments/attachment_storage.dart';
import 'package:sked/agent/connection/agent_credential_store.dart';
import 'package:sked/agent/conversations/conversation_storage.dart';
import 'package:sked/agent/knowledge/knowledge_models.dart';
import 'package:sked/agent/knowledge/knowledge_storage.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/backup/backup_staging_storage.dart';
import 'package:sked/backup/selective_backup_models.dart';
import 'package:sked/backup/selective_restore_coordinator.dart';
import 'package:sked/backup/selective_restore_journal.dart';
import 'package:sked/services/app_backup_restore_journal.dart';
import 'package:sked/services/device_preferences_store.dart';

import 'memory_conversation_storage.dart';
import 'workspace_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('workspace defaults isolate native storage and each runtime', () async {
    SharedPreferences.setMockInitialValues({});
    final attemptedFactories = <String>[];
    Never reject(String name) {
      attemptedFactories.add(name);
      throw StateError('The synthetic workspace reached $name storage');
    }

    debugSetConversationStorageFactory(() => reject('conversations'));
    debugSetKnowledgeStorageFactory(() => reject('knowledge'));
    debugSetAttachmentStorageFactory(() => reject('attachments'));
    debugSetSelectiveRestoreJournalFactory(() => reject('selective journal'));
    debugSetBackupStagingStorageFactory(() => reject('backup staging'));
    debugSetAppBackupRestoreJournalFactory(() => reject('legacy journal'));
    addTearDown(() {
      debugSetConversationStorageFactory(null);
      debugSetKnowledgeStorageFactory(null);
      debugSetAttachmentStorageFactory(null);
      debugSetSelectiveRestoreJournalFactory(null);
      debugSetBackupStagingStorageFactory(null);
      debugSetAppBackupRestoreJournalFactory(null);
    });

    final first = await workspaceProvider();
    final second = await workspaceProvider();
    try {
      for (final runtime in [first, second]) {
        expect(runtime.session.canWrite, isTrue);
        await runtime.agent.initialize();
        expect(runtime.agent.isInitialized, isTrue);
        expect(
          runtime.agent.connections.status.storageKind,
          AgentCredentialStorageKind.memoryOnly,
        );
        final inventory = await runtime.backups.selective.inventory();
        expect(
          inventory.records.where(
            (record) => record.key.kind == BackupObjectKind.timetable,
          ),
          isNotEmpty,
        );
        expect(
          runtime.agent.attachmentStore.storage,
          isA<MemoryAttachmentStorage>(),
        );
        expect(
          runtime.backups.selective.journal,
          isA<MemorySelectiveRestoreJournal>(),
        );
      }
      final conversation = await first.agent.conversations.create(
        title: 'Owned by the first runtime',
        mode: AgentPermissionMode.ask,
      );
      expect(second.agent.conversations.find(conversation.id), isNull);
      expect(
        identical(
          first.agent.attachmentStore.storage,
          second.agent.attachmentStore.storage,
        ),
        isFalse,
      );
      expect(attemptedFactories, isEmpty);
    } finally {
      await first.agent.quiesce();
      first.dispose();
      await second.agent.quiesce();
      second.dispose();
    }
  });

  test(
    'explicit workspace stores own initialization and accepted writes',
    () async {
      final conversations = MemoryConversationStorage();
      final knowledge = MemoryKnowledgeStorage();
      final attachments = MemoryAttachmentStorage();
      final journal = MemorySelectiveRestoreJournal();
      final staging = MemoryAttachmentStorage();
      final credentials = _ObservedCredentials();
      final devices = DevicePreferencesStore.memory();
      final runtime = await workspaceProvider(
        agentConversationStorage: conversations,
        agentKnowledgeStorage: knowledge,
        agentAttachmentStorage: attachments,
        selectiveRestoreJournal: journal,
        backupStagingStorage: staging,
        agentCredentialStore: credentials,
        devicePreferences: devices,
      );
      try {
        await runtime.agent.initialize();
        expect(runtime.agent.isInitialized, isTrue);
        expect(credentials.reads, greaterThan(0));
        expect(runtime.agent.attachmentStore.storage, same(attachments));
        expect(runtime.backups.selective.journal, same(journal));
        expect(runtime.devicePreferences, same(devices));
        final conversation = await runtime.agent.conversations.create(
          title: 'Explicit conversation owner',
          mode: AgentPermissionMode.ask,
        );
        expect(conversations.source, contains(conversation.id));
        final service = runtime.agent.knowledge;
        await service.initialize();
        await service.saveFromUi(
          service.prepareSave(
            service.newRecord(
              KnowledgeKind.memory,
              title: 'Explicit knowledge owner',
              body: 'The caller owns this storage.',
            ),
          ),
        );
        expect(knowledge.source, contains('Explicit knowledge owner'));
      } finally {
        await runtime.agent.quiesce();
        runtime.dispose();
      }
    },
  );
}

class _ObservedCredentials extends MemoryAgentCredentialStore {
  int reads = 0;

  @override
  Future<String?> read(AgentCredentialSlot slot) async {
    reads++;
    return super.read(slot);
  }
}
