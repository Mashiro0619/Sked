import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/attachments/attachment_storage_io.dart';
import 'package:sked/agent/connection/agent_credential_store.dart';
import 'package:sked/agent/conversations/conversation_models.dart';
import 'package:sked/agent/conversations/conversation_storage_io.dart';
import 'package:sked/agent/knowledge/knowledge_models.dart';
import 'package:sked/agent/knowledge/knowledge_storage_io.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/backup/selective_backup_app_data.dart';
import 'package:sked/backup/selective_backup_models.dart';
import 'package:sked/backup/selective_restore_coordinator.dart';
import 'package:sked/backup/selective_restore_journal.dart';
import 'package:sked/backup/selective_restore_journal_io.dart';
import 'package:sked/data/timetable_storage_io.dart';
import 'package:sked/models/school_site_models.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/app_backup_restore_journal_io.dart';
import 'package:sked/services/app_storage_layout_io.dart';
import 'package:sked/services/school_site_service.dart';
import 'package:sked/services/school_site_store_io.dart';
import 'package:sked/services/secret_store.dart';

import '../support/data_transfer_codec.dart';

class _Secrets implements SecretStore {
  @override
  Future<String> readCustomSchoolImportApiKey() async => '';
  @override
  Future<void> writeCustomSchoolImportApiKey(String value) async {}
}

class _InterruptedJournal implements SelectiveRestoreJournal {
  _InterruptedJournal(this.delegate);
  final SelectiveRestoreJournal delegate;
  bool interrupt = true;
  @override
  Future<SelectiveRestoreState?> read() => delegate.read();
  @override
  Future<void> clear() => delegate.clear();
  @override
  Future<void> write(SelectiveRestoreState state) async {
    if (interrupt && state.completed == 2) {
      interrupt = false;
      throw StateError('Lost progress after the attachment and main writes.');
    }
    await delegate.write(state);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('native stores reopen and finish the fixed cross-store target after a lost phase write', () async {
    final directory = await Directory.systemTemp.createTemp(
      'sked-selective-recovery-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final layout = AppStorageLayout(directoryProvider: () async => directory);
    final stageLayout = AppStorageLayout(
      directoryProvider: () async => Directory('${directory.path}/staging'),
    );
    PersistentSelectiveRestoreJournal journal() =>
        PersistentSelectiveRestoreJournal(
          storage: PlatformSelectiveJournalStorage(layout: layout),
        );
    final interrupted = _InterruptedJournal(journal());
    final seed = buildInitialAppData(buildDefaultPeriodTimes());
    await IoTimetableStorage(layout: layout).save(seed);
    await PlatformSchoolSiteStore(layout: layout).save(
      encodeSchoolSites(const [
        SchoolSite(
          id: 'untouched-site',
          name: 'Keep this site',
          loginUrl: 'https://keep.example.test',
        ),
      ]),
    );

    Future<AppRuntime> open(SelectiveRestoreJournal progress) async {
      final runtime = AppRuntime(
        storage: IoTimetableStorage(layout: layout),
        schoolSiteService: SchoolSiteService(
          store: PlatformSchoolSiteStore(layout: layout),
        ),
        secretStore: _Secrets(),
        backupRestoreJournal: FileAppBackupRestoreJournal(layout: layout),
        agentConversationStorage: PlatformConversationStorage(layout: layout),
        agentAttachmentStorage: PlatformAttachmentStorage(layout: layout),
        agentKnowledgeStorage: PlatformKnowledgeStorage(layout: layout),
        agentCredentialStore: MemoryAgentCredentialStore(),
        selectiveRestoreJournal: progress,
        backupStagingStorage: PlatformAttachmentStorage(layout: stageLayout),
        dataTransferCodec: inlineDataTransferCodec,
        workspaceMutationLock: (action) => action(),
        systemLocaleCodeResolver: () => 'en',
      );
      await runtime.lifecycle.load();
      return runtime;
    }

    Future<void> close(AppRuntime runtime) async {
      await runtime.shutdown.quiesce();
      runtime.dispose();
      await runtime.backups.selective.close();
      await runtime.session.close();
    }

    final first = await open(interrupted);
    var firstClosed = false;
    addTearDown(() async {
      if (!firstClosed) await close(first);
    });
    final selectedCalendar =
        first.session.committedData.generalMode.schedules.first;
    final incoming = first.session.committedData.copyWith(
      generalMode: first.session.committedData.generalMode.withSchedule(
        selectedCalendar.copyWith(name: 'Restored calendar'),
      ),
    );
    final bytes = Uint8List.fromList([0, 1, 2, 0xff, 0x80]);
    final file = ConversationAttachment(
      id: 'archive-file',
      name: 'receipt.bin',
      byteLength: bytes.length,
      mediaType: 'application/octet-stream',
      digest: backupDigest(bytes),
    );
    final inventory = buildSelectiveBackupInventory(
      appData: incoming,
      schoolSites: const [
        SchoolSite(
          id: 'archive-site',
          name: 'Restored site',
          loginUrl: 'https://archive.example.test',
        ),
      ],
      knowledge: [
        KnowledgeRecord(
          kind: KnowledgeKind.memory,
          id: 'archive-memory',
          title: 'Imported preference',
          body: 'Prefer afternoon meetings.',
        ),
      ],
      conversations: [
        AgentConversation(
          id: 'archive-chat',
          title: 'Imported history',
          createdAt: DateTime.utc(2026, 10, 31),
          updatedAt: DateTime.utc(2026, 10, 31),
          attachments: [file],
          messages: [
            ConversationMessage(
              id: 'archive-request',
              role: ConversationRole.user,
              text: 'Read this file',
              createdAt: DateTime.utc(2026, 10, 31),
              attachmentIds: [file.id],
            ),
          ],
        ),
      ],
    );
    final selection = BackupSelection(
      objects: [
        BackupObjectKey(BackupObjectKind.calendar, selectedCalendar.id),
        const BackupObjectKey(BackupObjectKind.schoolSite, 'archive-site'),
        const BackupObjectKey(BackupObjectKind.memory, 'archive-memory'),
        const BackupObjectKey(BackupObjectKind.conversation, 'archive-chat'),
      ],
      attachmentBytes: [file.id],
    );
    final source = await exportSelectiveBackup(
      inventory: inventory,
      selection: selection,
      readAttachment: (_, _) async => bytes,
    );
    final plan = await first.backups.selective.prepareRestore(
      source,
      selection,
    );
    await expectLater(first.backups.selective.restore(plan), throwsStateError);
    expect(first.session.canWrite, isFalse);
    expect(first.backups.selective.recoveryPending, isTrue);
    expect((await journal().read())!.restoreId, plan.id);
    expect(
      first.agent.knowledgeRepository.find('memory:archive-memory'),
      isNull,
    );
    final mainBeforeRestart = (await IoTimetableStorage(
      layout: layout,
    ).load()).data!;
    expect(
      mainBeforeRestart.applicationLedger!.generation,
      plan.dataGeneration,
    );
    expect(
      mainBeforeRestart.generalMode.schedules.first.name,
      'Restored calendar',
    );
    await close(first);
    firstClosed = true;

    final restarted = await open(journal());
    addTearDown(() => close(restarted));
    expect(restarted.session.canWrite, isTrue);
    expect(restarted.backups.selective.recoveryPending, isFalse);
    expect(await journal().read(), isNull);
    expect(
      restarted.session.committedData.applicationLedger!.generation,
      plan.dataGeneration,
    );
    expect(
      restarted.agent.knowledgeRepository.find('memory:archive-memory')!.body,
      'Prefer afternoon meetings.',
    );
    final restoredChat = restarted.agent.conversations.find('archive-chat')!;
    expect(restoredChat.executionMessages, isEmpty);
    expect(restoredChat.runs, isEmpty);
    expect(restoredChat.pendingRedo, isNull);
    expect(restoredChat.executionHistoryStart, 1);
    expect(
      await restarted.agent.attachmentStore.readBytes(
        restoredChat.attachments.single,
      ),
      bytes,
    );
    final sites = await SchoolSiteService(
      store: PlatformSchoolSiteStore(layout: layout),
    ).loadSites();
    expect(sites.map((site) => site.id), ['untouched-site', 'archive-site']);
    expect(await PlatformAttachmentStorage(layout: stageLayout).ids(), isEmpty);
  });
}
