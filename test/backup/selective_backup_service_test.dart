import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/conversations/conversation_models.dart';
import 'package:sked/agent/attachments/attachment_storage.dart';
import 'package:sked/agent/knowledge/knowledge_models.dart';
import 'package:sked/backup/selective_backup_app_data.dart';
import 'package:sked/backup/selective_backup_models.dart';
import 'package:sked/backup/selective_restore_coordinator.dart';
import 'package:sked/models/school_site_models.dart';
import 'package:sked/application/operation_contracts.dart';

import '../support/memory_conversation_storage.dart';
import '../support/workspace_harness.dart';

class _CountingJournal extends MemorySelectiveRestoreJournal {
  int writes = 0;

  @override
  Future<void> write(SelectiveRestoreState state) async {
    writes++;
    await super.write(state);
  }
}

AgentConversation _chat(String id, {String? title}) => AgentConversation(
  id: id,
  title: title ?? id,
  createdAt: DateTime.utc(2026, 11, 5),
  updatedAt: DateTime.utc(2026, 11, 5),
);

class _FailAfterMainJournal extends MemorySelectiveRestoreJournal {
  bool fail = true;
  @override
  Future<void> write(SelectiveRestoreState state) async {
    if (fail && state.completed == 1) {
      fail = false;
      throw StateError('Stopped after the main store committed.');
    }
    await super.write(state);
  }
}

class _FailSecondStagedFile extends MemoryAttachmentStorage {
  int writes = 0;
  @override
  Future<void> write(String id, Stream<List<int>> bytes) async {
    await super.write(id, bytes);
    if (++writes == 2) throw StateError('Staging interrupted after writing.');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'runtime binds selective backup without initializing dormant conversations',
    () async {
      final runtime = await workspaceProvider();
      addTearDown(runtime.dispose);
      expect(runtime.backups.hasSelectiveBackup, isTrue);
      expect(runtime.agent.conversations.isLoaded, isFalse);
      expect(runtime.session.canWrite, isTrue);
      final inventory = await runtime.backups.selective.inventory();
      expect(
        inventory.records.where(
          (record) => record.key.kind == BackupObjectKind.timetable,
        ),
        isNotEmpty,
      );
    },
  );

  test(
    'concurrent exports cannot start while the first inventory is loading',
    () async {
      final runtime = await workspaceProvider();
      addTearDown(runtime.dispose);
      final service = runtime.backups.selective;
      final inventory = await service.inventory();
      final selection = BackupSelection(objects: [inventory.roots.first]);
      final first = service.export(inventory, selection);
      expect(service.isBusy, isTrue);
      await expectLater(
        service.export(inventory, selection),
        throwsA(isA<SelectiveBackupException>()),
      );
      expect(await first, isNotEmpty);
      expect(service.isBusy, isFalse);
    },
  );

  test(
    'restoring identical chat text still discards its local executable history',
    () async {
      final runtime = await workspaceProvider();
      addTearDown(runtime.dispose);
      await runtime.agent.initialize();
      final conversation = await runtime.agent.conversations.create(
        title: 'Local execution',
        mode: AgentPermissionMode.full,
      );
      await runtime.agent.runtime.runHostAction(
        conversation.id,
        (_, _) async => {'status': 'fixture completed'},
      );
      expect(
        runtime.agent.conversations.find(conversation.id)!.runs,
        isNotEmpty,
      );
      final service = runtime.backups.selective;
      final source = await service.inventory();
      final plan = await service.prepareRestore(
        source,
        BackupSelection(
          objects: [
            BackupObjectKey(BackupObjectKind.conversation, conversation.id),
          ],
        ),
      );
      await service.restore(plan);
      final restored = runtime.agent.conversations.find(conversation.id)!;
      expect(restored.runs, isEmpty);
      expect(restored.turns, isEmpty);
      expect(restored.executionMessages, isEmpty);
      expect(restored.pendingRedo, isNull);
    },
  );

  for (final (existingCount, incomingId) in [
    (199, 'incoming'),
    (200, 'local-0'),
  ]) {
    test(
      'chat restore accepts $existingCount existing chats with target $incomingId at the archive limit',
      () async {
        final storage = MemoryConversationStorage()
          ..source = ConversationArchive(
            conversations: List.generate(
              existingCount,
              (i) => _chat('local-$i'),
            ),
          ).encode();
        final runtime = await workspaceProvider(
          agentConversationStorage: storage,
        );
        addTearDown(runtime.dispose);
        final service = runtime.backups.selective;
        final source = buildSelectiveBackupInventory(
          appData: runtime.session.committedData,
          conversations: [_chat(incomingId, title: 'Restored chat')],
        );
        final plan = await service.prepareRestore(
          source,
          BackupSelection(
            objects: [
              BackupObjectKey(BackupObjectKind.conversation, incomingId),
            ],
          ),
        );

        await service.restore(plan);

        final saved = ConversationArchive.decode(storage.source!);
        expect(saved.conversations, hasLength(200));
        expect(
          saved.conversations
              .singleWhere((chat) => chat.id == incomingId)
              .title,
          'Restored chat',
        );
        expect(await service.journal.read(), isNull);
        expect(service.recoveryPending, isFalse);
        expect(runtime.session.canWrite, isTrue);
      },
    );
  }

  test('an oversized merged chat archive is rejected before journal admission or main-data changes', () async {
    final storage = MemoryConversationStorage()
      ..source = ConversationArchive(
        conversations: List.generate(200, (i) => _chat('local-$i')),
      ).encode();
    final journal = _CountingJournal();
    final runtime = await workspaceProvider(
      agentConversationStorage: storage,
      selectiveRestoreJournal: journal,
    );
    addTearDown(runtime.dispose);
    final service = runtime.backups.selective;
    await service.inventory();
    final before = runtime.session.committedData;
    final beforeChats = storage.source;
    final calendar = before.generalMode.schedules.first;
    final source = buildSelectiveBackupInventory(
      appData: before.copyWith(
        generalMode: before.generalMode.withSchedule(
          calendar.copyWith(name: 'Must not be applied'),
        ),
      ),
      conversations: [_chat('incoming')],
    );
    final plan = await service.prepareRestore(
      source,
      BackupSelection(
        objects: [
          BackupObjectKey(BackupObjectKind.calendar, calendar.id),
          const BackupObjectKey(BackupObjectKind.conversation, 'incoming'),
        ],
      ),
    );

    await expectLater(service.restore(plan), throwsFormatException);

    expect(journal.writes, 0);
    expect(await journal.read(), isNull);
    expect(runtime.session.committedData.toJson(), before.toJson());
    expect(storage.source, beforeChats);
    expect(service.recoveryPending, isFalse);
    expect(runtime.session.canWrite, isTrue);
    expect(runtime.agent.conversations.canWrite, isTrue);
    await service.resume();
    expect(journal.writes, 0);
    expect(runtime.session.canWrite, isTrue);
  });

  test('a partially prepared attachment stage is cleaned without admitting any data write', () async {
    final staging = _FailSecondStagedFile();
    final runtime = await workspaceProvider(backupStagingStorage: staging);
    addTearDown(runtime.dispose);
    final before = runtime.session.committedData.toJson();
    final firstBytes = Uint8List.fromList([1, 2, 3]);
    final secondBytes = Uint8List.fromList([4, 5, 6]);
    final files = [
      for (final (index, bytes) in [firstBytes, secondBytes].indexed)
        ConversationAttachment(
          id: 'staged-file-$index',
          name: 'file-$index.bin',
          mediaType: 'application/octet-stream',
          byteLength: bytes.length,
          digest: backupDigest(bytes),
        ),
    ];
    final inventory = buildSelectiveBackupInventory(
      appData: runtime.session.committedData,
      conversations: [
        AgentConversation(
          id: 'staged-conversation',
          title: 'Files',
          createdAt: DateTime.utc(2026, 10, 31),
          updatedAt: DateTime.utc(2026, 10, 31),
          attachments: files,
        ),
      ],
    );
    final selection = BackupSelection(
      objects: const [
        BackupObjectKey(BackupObjectKind.conversation, 'staged-conversation'),
      ],
      attachmentBytes: files.map((file) => file.id),
    );
    final source = await exportSelectiveBackup(
      inventory: inventory,
      selection: selection,
      readAttachment: (file, _) async =>
          file.id == files.first.id ? firstBytes : secondBytes,
    );
    final service = runtime.backups.selective;
    await expectLater(
      service.prepareRestore(
        source,
        BackupSelection(
          objects: [
            BackupObjectKey(BackupObjectKind.attachment, files.first.id),
          ],
          attachmentBytes: [files.first.id],
        ),
      ),
      throwsA(isA<SelectiveBackupException>()),
    );
    final plan = await service.prepareRestore(source, selection);
    await expectLater(service.restore(plan), throwsStateError);
    expect(await staging.ids(), isEmpty);
    expect(await runtime.agent.attachmentStore.storage.ids(), isEmpty);
    expect(await service.journal.read(), isNull);
    expect(runtime.session.committedData.toJson(), before);
    expect(runtime.session.canWrite, isTrue);
  });

  test('one restore preserves unselected objects and restores files, knowledge and inert chat history', () async {
    final runtime = await workspaceProvider();
    addTearDown(runtime.dispose);
    final original = runtime.session.committedData;
    final selected = original.generalMode.schedules.first;
    final changed = original.copyWith(
      generalMode: original.generalMode.withSchedule(
        selected.copyWith(name: 'Restored calendar'),
      ),
    );
    final bytes = Uint8List.fromList([0, 1, 0xff, 2]);
    final file = ConversationAttachment(
      id: 'restored-file',
      name: 'opaque.dat',
      mediaType: 'application/octet-stream',
      byteLength: bytes.length,
      digest: backupDigest(bytes),
    );
    final chat = AgentConversation(
      id: 'restored-chat',
      title: 'Saved chat',
      createdAt: DateTime.utc(2026, 10, 31),
      updatedAt: DateTime.utc(2026, 10, 31),
      attachments: [file],
    );
    final inventory = buildSelectiveBackupInventory(
      appData: changed,
      schoolSites: const [
        SchoolSite(
          id: 'restored-site',
          name: 'Saved site',
          loginUrl: 'https://school.example.test',
        ),
      ],
      knowledge: [
        KnowledgeRecord(
          kind: KnowledgeKind.memory,
          id: 'restored-memory',
          title: 'Preference',
          body: 'Prefer mornings',
        ),
      ],
      conversations: [chat],
    );
    final selection = BackupSelection(
      objects: [
        BackupObjectKey(BackupObjectKind.calendar, selected.id),
        const BackupObjectKey(BackupObjectKind.schoolSite, 'restored-site'),
        const BackupObjectKey(BackupObjectKind.memory, 'restored-memory'),
        const BackupObjectKey(BackupObjectKind.conversation, 'restored-chat'),
      ],
      attachmentBytes: const ['restored-file'],
    );
    final source = await exportSelectiveBackup(
      inventory: inventory,
      selection: selection,
      readAttachment: (_, _) async => bytes,
    );
    final service = runtime.backups.selective;
    final plan = await service.prepareRestore(source, selection);
    await service.restore(plan);
    expect(service.recoveryPending, isFalse);
    expect(runtime.session.canWrite, isTrue);
    expect(
      runtime.session.committedData.studentMode.toJson(),
      original.studentMode.toJson(),
    );
    expect(
      runtime.session.committedData.generalMode.schedules.first.name,
      'Restored calendar',
    );
    expect(
      runtime.session.committedData.generalMode.schedules
          .skip(1)
          .map((calendar) => calendar.toJson()),
      original.generalMode.schedules
          .skip(1)
          .map((calendar) => calendar.toJson()),
    );
    expect(
      runtime.agent.knowledgeRepository.find('memory:restored-memory')!.body,
      'Prefer mornings',
    );
    final restored = runtime.agent.conversations.find('restored-chat')!;
    expect(restored.turns, isEmpty);
    expect(restored.executionMessages, isEmpty);
    expect(
      await runtime.agent.attachmentStore.readBytes(
        restored.attachments.single,
      ),
      bytes,
    );
    expect(
      (await service.inventory())
          .byKey[const BackupObjectKey(
            BackupObjectKind.schoolSite,
            'restored-site',
          )]!
          .label,
      'Saved site',
    );
  });

  test('phase failure closes ordinary writes and lifecycle retry resumes the same target', () async {
    final journal = _FailAfterMainJournal();
    final runtime = await workspaceProvider(selectiveRestoreJournal: journal);
    addTearDown(runtime.dispose);
    final source = buildSelectiveBackupInventory(
      appData: runtime.session.committedData,
      schoolSites: const [
        SchoolSite(
          id: 'recovery-site',
          name: 'After recovery',
          loginUrl: 'https://school.example.test',
        ),
      ],
    );
    final service = runtime.backups.selective;
    final plan = await service.prepareRestore(
      source,
      BackupSelection(
        objects: const [
          BackupObjectKey(BackupObjectKind.schoolSite, 'recovery-site'),
        ],
      ),
    );
    await expectLater(service.restore(plan), throwsStateError);
    expect(service.recoveryPending, isTrue);
    expect(runtime.session.canWrite, isFalse);
    expect(
      runtime.session.committedData.applicationLedger!.generation,
      plan.dataGeneration,
    );
    await runtime.lifecycle.retryStorageLoad();
    expect(service.recoveryPending, isFalse);
    expect(runtime.session.canWrite, isTrue);
    expect(
      runtime.session.committedData.applicationLedger!.generation,
      plan.dataGeneration,
    );
    expect(
      (await service.inventory())
          .byKey[const BackupObjectKey(
            BackupObjectKind.schoolSite,
            'recovery-site',
          )]!
          .label,
      'After recovery',
    );
  });
}
