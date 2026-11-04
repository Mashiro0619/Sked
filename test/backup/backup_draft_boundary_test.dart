import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/attachments/attachment_storage.dart';
import 'package:sked/agent/connection/agent_credential_store.dart';
import 'package:sked/agent/conversations/conversation_models.dart';
import 'package:sked/agent/knowledge/knowledge_storage.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/backup/selective_backup_app_data.dart';
import 'package:sked/backup/selective_backup_models.dart';
import 'package:sked/backup/selective_backup_planner.dart';
import 'package:sked/backup/selective_restore_coordinator.dart';
import 'package:sked/controllers/app_backup_controller.dart';
import 'package:sked/models/school_site_models.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/app_backup_restore_journal.dart';
import 'package:sked/services/device_preferences_store.dart';
import 'package:sked/services/school_site_service.dart';
import 'package:sked/services/school_site_store.dart';
import 'package:sked/services/secret_store.dart';

import '../support/data_transfer_codec.dart';
import '../support/memory_conversation_storage.dart';
import '../support/workspace_harness.dart';

const _savedId = 'saved-boundary-chat';
const _draftId = 'unsent-boundary-chat';
const _draftText = 'Unsent input from the old data session';
const _savedDraft = 'Keep the unselected saved chat draft';
const _site = SchoolSite(
  id: 'boundary-site',
  name: 'Restored site',
  loginUrl: 'https://school.example.invalid',
);

class _ChatStorage extends MemoryConversationStorage {
  int writes = 0;
  @override
  Future<void> save(String value, {required int revision}) async {
    writes++;
    await super.save(value, revision: revision);
  }
}

class _SelectiveJournal extends MemorySelectiveRestoreJournal {
  bool failClear = false;
  int clearAttempts = 0;
  @override
  Future<void> clear() async {
    clearAttempts++;
    if (failClear) throw StateError('Synthetic selective cleanup failure');
    await super.clear();
  }
}

class _CompleteJournal extends AppBackupRestoreJournal {
  _CompleteJournal() : super.base();
  String? source;
  bool failClear = false;
  @override
  String get pendingArtifactPath => 'memory://draft-boundary-restore';
  @override
  Future<String?> read() async => source;
  @override
  Future<void> write(String value) async => source = value;
  @override
  Future<void> clear() async {
    if (failClear) throw StateError('Synthetic complete cleanup failure');
    source = null;
  }

  @override
  Future<String> preserveForRecovery(String source) async =>
      'memory://draft-boundary-recovery';
  @override
  Future<Uint8List?> readRecoveryArtifact(String path) async => null;
}

class _Secrets implements SecretStore {
  String key = '';
  @override
  Future<String> readCustomSchoolImportApiKey() async => key;
  @override
  Future<void> writeCustomSchoolImportApiKey(String value) async => key = value;
}

class _Sites extends SchoolSiteStore {
  _Sites() : super.base();
  String? source = '[]';
  @override
  Future<String?> load() async => source;
  @override
  Future<void> save(String value) async => source = value;
  @override
  Future<String?> filePath() async => 'memory://draft-boundary-sites';
}

class _Fixture {
  _Fixture(
    this.app,
    this.main,
    this.chats,
    this.blobs,
    this.generation,
    this.savedAttachment,
    this.draftAttachment,
  );
  final AppRuntime app;
  final WorkspaceMemoryStorage main;
  final _ChatStorage chats;
  final MemoryAttachmentStorage blobs;
  final String generation;
  final ConversationAttachment savedAttachment, draftAttachment;

  static Future<_Fixture> create({
    _CompleteJournal? completeJournal,
    _SelectiveJournal? selectiveJournal,
  }) async {
    final main = WorkspaceMemoryStorage(
      buildInitialAppData(buildDefaultPeriodTimes(), localeCode: 'en'),
    );
    final chats = _ChatStorage();
    final blobs = MemoryAttachmentStorage();
    final AppRuntime app;
    if (completeJournal == null) {
      app = await workspaceProvider(
        storage: main,
        agentConversationStorage: chats,
        agentAttachmentStorage: blobs,
        selectiveRestoreJournal: selectiveJournal,
      );
    } else {
      app = AppRuntime(
        storage: main,
        secretStore: _Secrets(),
        schoolSiteService: SchoolSiteService(store: _Sites()),
        backupRestoreJournal: completeJournal,
        agentConversationStorage: chats,
        agentAttachmentStorage: blobs,
        agentKnowledgeStorage: MemoryKnowledgeStorage(),
        agentCredentialStore: MemoryAgentCredentialStore(),
        selectiveRestoreJournal:
            selectiveJournal ?? MemorySelectiveRestoreJournal(),
        backupStagingStorage: MemoryAttachmentStorage(),
        devicePreferences: DevicePreferencesStore.memory(),
        dataTransferCodec: inlineDataTransferCodec,
        workspaceMutationLock: (action) => action(),
        systemLocaleCodeResolver: () => 'en',
        uiStateSaveDelay: Duration.zero,
      );
      await app.lifecycle.load();
    }
    addTearDown(() async {
      await app.agent.quiesce();
      app.dispose();
    });
    await app.agent.initialize();
    final generation = app.agent.mutations.generation;
    final at = DateTime.utc(2026, 11, 5);
    ConversationSource source(String id) => ConversationSource(
      id: id,
      text: 'Reviewed material from the original data',
      kind: 'web',
      targetId:
          app.session.committedData.studentMode.timetables.firstOrNull?.id,
      provenance: ConversationSourceProvenance(
        title: 'Original source',
        capturedAt: at,
        reviewedAt: at,
        datasetGeneration: generation,
        localeCode: 'en',
      ),
    );
    await app.agent.conversations.create(title: 'Saved history', id: _savedId);
    Future<void> attach(String id, String name, List<int> bytes) =>
        app.agent.binaryAttachments.attach(
          id,
          XFile.fromData(Uint8List.fromList(bytes), path: name, name: name),
          canModify: () => true,
        );
    await attach(_savedId, 'saved.bin', [1, 2, 3]);
    final savedAttachment = app.agent.conversations
        .find(_savedId)!
        .attachments
        .single;
    await app.agent.conversations.update(
      _savedId,
      (chat) => chat.copyWith(
        draft: _savedDraft,
        sources: [source('saved-source')],
        messages: [
          ConversationMessage(
            id: 'saved-user-message',
            role: ConversationRole.user,
            text: 'Previously sent request',
            createdAt: at,
            attachmentIds: [savedAttachment.id],
          ),
        ],
      ),
    );
    final beforeDraft = chats.source;
    final writesBeforeDraft = chats.writes;
    await app.agent.conversations.createDraft(title: 'New chat', id: _draftId);
    await app.agent.conversations.update(
      _draftId,
      (chat) =>
          chat.copyWith(draft: _draftText, sources: [source('draft-source')]),
    );
    await attach(_draftId, 'unsent.bin', [4, 5, 6]);
    final draftAttachment = app.agent.conversations
        .find(_draftId)!
        .attachments
        .single;
    expect(chats.source, beforeDraft);
    expect(chats.writes, writesBeforeDraft);
    return _Fixture(
      app,
      main,
      chats,
      blobs,
      generation,
      savedAttachment,
      draftAttachment,
    );
  }

  void assertArchiveSelection() {
    final archive = ConversationArchive.decode(chats.source!);
    expect(archive.selectedId, _savedId);
    // An explicitly imported history may share the volatile identity. Its
    // presence must not serialize the old in-memory input or file references.
    final sameIdentity = archive.conversations.where(
      (chat) => chat.id == _draftId,
    );
    expect(sameIdentity.any((chat) => chat.draft == _draftText), isFalse);
    expect(
      sameIdentity.any(
        (chat) => chat.sources.any((source) => source.id == 'draft-source'),
      ),
      isFalse,
    );
    expect(
      sameIdentity.any(
        (chat) => chat.attachments.any(
          (attachment) => attachment.id == draftAttachment.id,
        ),
      ),
      isFalse,
    );
  }

  void assertDraftRetained() {
    final draft = app.agent.conversations.draftConversation;
    expect(draft?.id, _draftId);
    expect(draft?.draft, _draftText);
    expect(draft?.sources.single.provenance?.datasetGeneration, generation);
    expect(draft?.draftAttachmentIds, [draftAttachment.id]);
    expect(app.agent.conversations.selectedId, _draftId);
    expect(blobs.values[draftAttachment.id], [4, 5, 6]);
    assertArchiveSelection();
  }

  void assertSavedChatPreserved() {
    final saved = app.agent.conversations.find(_savedId)!;
    expect(saved.draft, _savedDraft);
    expect(saved.messages.single.text, 'Previously sent request');
    expect(saved.sources.single.provenance?.datasetGeneration, generation);
    expect(saved.draftAttachmentIds, [savedAttachment.id]);
    expect(blobs.values[savedAttachment.id], [1, 2, 3]);
    assertArchiveSelection();
  }

  Future<void> assertSuccessfulBoundary({String? importedDraftTitle}) async {
    await app.agent.quiesce();
    await app.agent.binaryAttachments.waitForPendingOperations();
    expect(app.agent.conversations.draftConversation, isNull);
    if (importedDraftTitle == null) {
      expect(app.agent.conversations.find(_draftId), isNull);
    } else {
      expect(app.agent.conversations.find(_draftId)?.title, importedDraftTitle);
    }
    expect(app.agent.conversations.selectedId, _savedId);
    expect(blobs.values.containsKey(draftAttachment.id), isFalse);
    assertSavedChatPreserved();
  }

  Future<BackupRestorePlan> sitePlan() => app.backups.selective.prepareRestore(
    buildSelectiveBackupInventory(
      appData: app.session.committedData,
      schoolSites: const [_site],
    ),
    BackupSelection(
      objects: const [
        BackupObjectKey(BackupObjectKind.schoolSite, 'boundary-site'),
      ],
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'backup reads, settings and workspace navigation preserve unsent input',
    () async {
      final fixture = await _Fixture.create();
      final app = fixture.app;
      final before = fixture.chats.source;
      final inventory = await app.backups.selective.inventory();
      expect(
        inventory.byKey.containsKey(
          const BackupObjectKey(BackupObjectKind.conversation, _draftId),
        ),
        isFalse,
      );
      await app.backups.selective.export(
        inventory,
        BackupSelection(
          objects: inventory.roots.where(
            (key) => key.kind != BackupObjectKind.conversation,
          ),
        ),
      );
      final legacy = await app.backups.exportJson();
      await app.backups.prepareJson(legacy);
      await app.settingsCommands.updateLocaleCode('zh');
      await app.workspaces.switchMode(AppMode.general);
      await app.workspaces.switchMode(AppMode.student);
      expect(fixture.chats.source, before);
      fixture.assertDraftRetained();
      fixture.assertSavedChatPreserved();
    },
  );

  test(
    'invalid complete restore and declined guards preserve the draft',
    () async {
      final fixture = await _Fixture.create();
      final app = fixture.app;
      await expectLater(
        app.backups.importJson('invalid JSON', mode: AppImportMode.replaceAll),
        throwsFormatException,
      );
      fixture.assertDraftRetained();
      final source = await app.backups.exportJson();
      final unregister = app.workspaces.registerExitGuard(
        AppMode.student,
        () async => false,
      );
      addTearDown(unregister);
      await expectLater(
        app.backups.importJson(source, mode: AppImportMode.replaceAll),
        throwsA(isA<WorkspaceChangeCancelledException>()),
      );
      expect(app.maintenance.isReserved, isFalse);
      fixture.assertDraftRetained();
    },
  );

  test(
    'cancelled, empty and already-empty selective restore preserve the draft',
    () async {
      final fixture = await _Fixture.create();
      final service = fixture.app.backups.selective;
      final cancelled = BackupCancellation()..cancel();
      await expectLater(
        service.restore(await fixture.sitePlan(), cancellation: cancelled),
        throwsA(
          isA<SelectiveBackupException>().having(
            (error) => error.code,
            'code',
            SelectiveBackupError.cancelled,
          ),
        ),
      );
      fixture.assertDraftRetained();
      final empty = await service.prepareRestore(
        await service.inventory(),
        BackupSelection(objects: const []),
      );
      expect(empty.owners, isEmpty);
      await service.restore(empty);
      await service.resume();
      expect(await service.journal.read(), isNull);
      fixture.assertDraftRetained();
    },
  );

  test(
    'successful complete restore discards volatile input after confirmation',
    () async {
      final fixture = await _Fixture.create();
      final source = await fixture.app.backups.exportJson();
      await fixture.app.backups.importJson(
        source,
        mode: AppImportMode.replaceAll,
      );
      await fixture.assertSuccessfulBoundary();
    },
  );

  test(
    'failed complete data write does not discard old unsent input',
    () async {
      final fixture = await _Fixture.create();
      final source = await fixture.app.backups.exportJson();
      final failure = StateError('Synthetic main restore write failure');
      fixture.main.saveError = failure;
      await expectLater(
        fixture.app.backups.importJson(source, mode: AppImportMode.replaceAll),
        throwsA(
          anyOf(
            same(failure),
            isA<AppBackupRestoreException>().having(
              (error) => error.cause,
              'cause',
              same(failure),
            ),
          ),
        ),
      );
      fixture.assertDraftRetained();
      fixture.assertSavedChatPreserved();
    },
  );

  test('complete cleanup failure retains input and unpublished file retry until recovery', () async {
    final journal = _CompleteJournal();
    final fixture = await _Fixture.create(completeJournal: journal);
    final files = fixture.app.agent.binaryAttachments;
    var checks = 0;
    await expectLater(
      files.attach(
        _draftId,
        XFile.fromData(
          Uint8List.fromList([7, 8, 9]),
          path: 'retry.bin',
          name: 'retry.bin',
        ),
        canModify: () => ++checks == 1,
      ),
      throwsA(isA<AttachmentException>()),
    );
    expect(files.hasPending(_draftId), isTrue);
    final source = await fixture.app.backups.exportJson();
    journal.failClear = true;
    await expectLater(
      fixture.app.backups.importJson(source, mode: AppImportMode.replaceAll),
      throwsA(
        isA<AppBackupRestoreException>().having(
          (error) => error.recoveryPending,
          'pending recovery',
          isTrue,
        ),
      ),
    );
    fixture.assertDraftRetained();
    expect(files.hasPending(_draftId), isTrue);
    expect(fixture.blobs.values, hasLength(3));
    final pendingGeneration =
        fixture.app.session.committedData.applicationLedger!.generation;
    journal.failClear = false;
    await fixture.app.lifecycle.retryStorageLoad();
    expect(
      fixture.app.session.committedData.applicationLedger!.generation,
      pendingGeneration,
    );
    expect(await journal.read(), isNull);
    expect(files.hasPending(_draftId), isFalse);
    await fixture.assertSuccessfulBoundary();
    expect(fixture.blobs.values.keys, [fixture.savedAttachment.id]);
  });

  test('successful selective restore without chats still ends the old draft boundary', () async {
    final fixture = await _Fixture.create();
    final plan = await fixture.sitePlan();
    expect(plan.owners, isNot(contains(BackupOwner.conversations)));
    await fixture.app.backups.selective.restore(plan);
    expect(
      fixture.app.session.committedData.applicationLedger!.generation,
      plan.dataGeneration,
    );
    await fixture.assertSuccessfulBoundary();
  });

  for (final incomingId in ['incoming-boundary-chat', _draftId]) {
    test(
      'frozen target $incomingId and failed cleanup preserve the volatile selection',
      () async {
        final journal = _SelectiveJournal();
        final fixture = await _Fixture.create(selectiveJournal: journal);
        final incoming = AgentConversation(
          id: incomingId,
          title: 'Imported history',
          createdAt: DateTime.utc(2026, 11, 5),
          updatedAt: DateTime.utc(2026, 11, 5),
        );
        final source = buildSelectiveBackupInventory(
          appData: fixture.app.session.committedData,
          conversations: [incoming],
        );
        final plan = await fixture.app.backups.selective.prepareRestore(
          source,
          BackupSelection(
            objects: [
              BackupObjectKey(BackupObjectKind.conversation, incomingId),
            ],
          ),
        );
        journal.failClear = true;
        await expectLater(
          fixture.app.backups.selective.restore(plan),
          throwsStateError,
        );
        expect((await journal.read())!.isComplete, isTrue);
        expect(fixture.app.backups.selective.recoveryPending, isTrue);
        fixture.assertDraftRetained();
        expect(
          ConversationArchive.decode(fixture.chats.source!).conversations
              .map((chat) => chat.id),
          contains(incoming.id),
        );
        journal.failClear = false;
        await fixture.app.lifecycle.retryStorageLoad();
        expect(await journal.read(), isNull);
        expect(
          fixture.app.session.committedData.applicationLedger!.generation,
          plan.dataGeneration,
        );
        await fixture.assertSuccessfulBoundary(
          importedDraftTitle: incomingId == _draftId ? incoming.title : null,
        );
        expect(
          fixture.app.agent.conversations.find(incoming.id)?.title,
          incoming.title,
        );
      },
    );
  }
}
