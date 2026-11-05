import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/attachments/attachment_storage.dart';
import 'package:sked/agent/connection/agent_connection_manager.dart';
import 'package:sked/agent/conversations/conversation_models.dart';
import 'package:sked/agent/conversations/conversation_storage.dart';
import 'package:sked/agent/knowledge/knowledge_models.dart';
import 'package:sked/agent/knowledge/knowledge_storage.dart';
import 'package:sked/backup/selective_backup_app_data.dart';
import 'package:sked/backup/selective_backup_models.dart';
import 'package:sked/models/agent_settings.dart';
import 'package:sked/models/timetable_models.dart';

import '../support/memory_conversation_storage.dart';
import '../support/workspace_harness.dart';

class _UnavailableCredentials extends MemoryAgentCredentialStore {
  int reads = 0, writes = 0;

  @override
  Future<String?> read(AgentCredentialSlot slot) async {
    reads++;
    throw StateError('Synthetic unavailable keyring');
  }

  @override
  Future<void> write(AgentCredentialSlot slot, String? value) async {
    writes++;
    throw StateError('Synthetic unavailable keyring');
  }
}

class _DelayedConversations extends MemoryConversationStorage {
  final entered = Completer<void>(), resume = Completer<void>();
  int reads = 0;

  @override
  Future<ConversationStorageLoad> load() async {
    reads++;
    if (!entered.isCompleted) entered.complete();
    await resume.future;
    return super.load();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('concurrent Agent startup and backup share chat loading without sharing a keyring failure', () async {
    final chats = _DelayedConversations();
    final credentials = _UnavailableCredentials();
    final runtime = await workspaceProvider(
      agentConversationStorage: chats,
      agentCredentialStore: credentials,
    );
    addTearDown(() {
      if (!chats.resume.isCompleted) chats.resume.complete();
      runtime.dispose();
    });
    final initializationFailed = expectLater(
      runtime.agent.initialize(),
      throwsA(isA<AgentConnectionException>()),
    );
    await chats.entered.future;
    final inventory = runtime.backups.selective.inventory();
    chats.resume.complete();

    expect((await inventory).records, isNotEmpty);
    await initializationFailed;
    expect(chats.reads, 1);
    expect(credentials.reads, greaterThan(0));
    expect(runtime.agent.isInitialized, isFalse);
    expect(runtime.session.canWrite, isTrue);
  });

  test(
    'disabled Agent keyring failure does not block ordinary backup or restore',
    () async {
      final credentials = _UnavailableCredentials();
      final runtime = await workspaceProvider(
        agentCredentialStore: credentials,
      );
      addTearDown(runtime.dispose);
      await runtime.agent.setEnabled(false);
      final service = runtime.backups.selective;
      final inventory = await service.inventory();
      final calendar =
          runtime.session.committedData.generalMode.schedules.first;
      final selection = BackupSelection(
        objects: [BackupObjectKey(BackupObjectKind.calendar, calendar.id)],
      );
      final exported = service.decode(
        await service.export(inventory, selection),
      );
      expect(exported.byKey[selection.objects.single]?.label, calendar.name);

      final data = runtime.session.committedData;
      final source = buildSelectiveBackupInventory(
        appData: data.copyWith(
          generalMode: data.generalMode.withSchedule(
            calendar.copyWith(name: 'Restored calendar'),
          ),
        ),
      );
      final plan = await service.prepareRestore(source, selection);
      final restored = await service.restoreAndReadInventory(plan);
      expect(restored.refreshError, isNull);
      expect(
        restored.inventory!.byKey[selection.objects.single]?.label,
        'Restored calendar',
      );
      expect(runtime.agent.settings.enabled, isFalse);
      expect(runtime.agent.isInitialized, isFalse);
      expect(runtime.agent.connections.status.initialized, isFalse);
      expect(credentials.reads, 0);
      expect(credentials.writes, 0);
      expect(runtime.session.canWrite, isTrue);
      expect(await service.journal.read(), isNull);
    },
  );

  test('backup reads keep retained history, knowledge and selected file bytes without activating a connection', () async {
    final bytes = Uint8List.fromList([1, 2, 3]);
    final file = ConversationAttachment(
      id: 'backup-file',
      name: 'notes.txt',
      mediaType: 'text/plain',
      byteLength: bytes.length,
      digest: backupDigest(bytes),
    );
    final oldDate = DateTime.utc(2020);
    final chats = MemoryConversationStorage()
      ..source = ConversationArchive(
        conversations: [
          AgentConversation(
            id: 'old-chat',
            title: 'Retained history',
            createdAt: oldDate,
            updatedAt: oldDate,
            attachments: [file],
            messages: [
              ConversationMessage(
                id: 'message',
                role: ConversationRole.user,
                text: 'Notes',
                createdAt: oldDate,
                attachmentIds: [file.id],
              ),
            ],
          ),
        ],
      ).encode();
    final knowledge = MemoryKnowledgeStorage();
    final attachments = MemoryAttachmentStorage()..values[file.id] = bytes;
    final credentials = _UnavailableCredentials();
    final runtime = await workspaceProvider(
      storage: WorkspaceMemoryStorage(
        buildInitialAppData(buildDefaultPeriodTimes()).copyWith(
          agentSettings: const AgentSettings(
            enabled: false,
            historyRetentionDays: 7,
          ),
        ),
      ),
      agentConversationStorage: chats,
      agentKnowledgeStorage: knowledge,
      agentAttachmentStorage: attachments,
      agentCredentialStore: credentials,
    );
    addTearDown(runtime.dispose);
    await runtime.agent.knowledge.initialize();
    await runtime.agent.knowledge.saveFromUi(
      runtime.agent.knowledge.prepareSave(
        KnowledgeRecord(
          kind: KnowledgeKind.memory,
          id: 'study-preference',
          title: 'Study preference',
          body: 'Prefer mornings.',
        ),
      ),
    );
    final originalChats = chats.source;
    final originalKnowledge = knowledge.source;
    final service = runtime.backups.selective;
    final inventory = await service.inventory();
    final archive = service.decode(
      await service.export(
        inventory,
        BackupSelection(
          objects: const [
            BackupObjectKey(BackupObjectKind.conversation, 'old-chat'),
            BackupObjectKey(BackupObjectKind.memory, 'study-preference'),
          ],
          attachmentBytes: [file.id],
        ),
      ),
    );

    expect(
      archive.byKey,
      contains(
        const BackupObjectKey(BackupObjectKind.memory, 'study-preference'),
      ),
    );
    expect(
      archive.byKey,
      contains(
        const BackupObjectKey(BackupObjectKind.conversation, 'old-chat'),
      ),
    );
    expect(archive.binaries[file.digest], bytes);
    expect(chats.source, originalChats);
    expect(knowledge.source, originalKnowledge);
    expect(credentials.reads, 0);
    expect(credentials.writes, 0);
    expect(runtime.agent.isInitialized, isFalse);
  });

  for (final brokenChats in [true, false]) {
    test(
      'an unreadable ${brokenChats ? 'chat' : 'knowledge'} side store is never silently omitted from backup',
      () async {
        final chats = MemoryConversationStorage()
          ..source = brokenChats ? '{damaged' : null;
        final knowledge = MemoryKnowledgeStorage()
          ..source = brokenChats ? null : '{damaged';
        final credentials = _UnavailableCredentials();
        final runtime = await workspaceProvider(
          agentConversationStorage: chats,
          agentKnowledgeStorage: knowledge,
          agentCredentialStore: credentials,
        );
        addTearDown(runtime.dispose);
        final before = runtime.session.committedData.toJson();
        final service = runtime.backups.selective;

        await expectLater(service.inventory(), throwsA(isA<Exception>()));

        expect(chats.source, brokenChats ? '{damaged' : null);
        expect(knowledge.source, brokenChats ? null : '{damaged');
        expect(runtime.session.committedData.toJson(), before);
        expect(await service.journal.read(), isNull);
        expect(credentials.reads, 0);
        expect(credentials.writes, 0);
      },
    );
  }

  test('restoring a selected connection still checks the keyring before admitting writes', () async {
    final credentials = _UnavailableCredentials();
    final runtime = await workspaceProvider(agentCredentialStore: credentials);
    addTearDown(runtime.dispose);
    final service = runtime.backups.selective;
    final before = runtime.session.committedData;
    final source = buildSelectiveBackupInventory(
      appData: before.copyWith(
        agentSettings: before.agentSettings.copyWith(
          endpoint: 'https://restored.example.test/v1',
        ),
      ),
    );
    final plan = await service.prepareRestore(
      source,
      BackupSelection(
        objects: const [
          BackupObjectKey(BackupObjectKind.settings, 'agentConnection'),
        ],
      ),
    );
    expect(credentials.reads, 0);

    await expectLater(
      service.restore(plan),
      throwsA(isA<AgentConnectionException>()),
    );

    expect(credentials.reads, greaterThan(0));
    expect(credentials.writes, 0);
    expect(runtime.session.committedData.toJson(), before.toJson());
    expect(await service.journal.read(), isNull);
    expect(service.recoveryPending, isFalse);
    expect(runtime.session.canWrite, isTrue);
  });
}
