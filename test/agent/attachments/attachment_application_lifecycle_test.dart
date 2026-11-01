import 'dart:async';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/attachments/attachment_repository.dart';
import 'package:sked/agent/connection/agent_credential_store.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/knowledge/knowledge_storage.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/ui/agent_conversation_view.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/controllers/app_backup_controller.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/app_backup_restore_journal.dart';
import 'package:sked/services/school_site_service.dart';
import 'package:sked/services/school_site_store.dart';
import 'package:sked/services/secret_store.dart';

import '../../support/data_transfer_codec.dart';
import '../../support/timetable_storage_fakes.dart';
import '../ui/agent_ui_test_support.dart' show mountAgentUi;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('disabling the feature rejects unpublished references and preserves saved files for explicit retry', () async {
    final h = await _ApplicationFixture.create();
    addTearDown(h.close);
    await h.attach();
    final savedId = h.conversation.attachments.single.id;
    final hold = h.blobs.holdNextWrite();
    final pending = expectLater(
      h.attach(),
      throwsA(isA<AttachmentException>()),
    );
    await hold.started.future;
    await h.app.agent.setEnabled(false);
    expect(h.app.agent.runtime.state.value.enabled, isFalse);
    hold.release();
    await pending;
    expect(h.conversation.draftAttachmentIds, [savedId]);
    expect(h.app.agent.binaryAttachments.hasPending(h.id), isTrue);
    await expectLater(h.attach(), throwsA(isA<AttachmentException>()));

    await h.app.agent.setEnabled(true);
    expect(h.conversation.draftAttachmentIds, [savedId]);
    await h.app.agent.binaryAttachments.retry(
      h.id,
      canModify: () => h.canModify,
    );
    expect(h.conversation.draftAttachmentIds, hasLength(2));
    expect(h.conversation.draftAttachmentIds.first, savedId);
    expect(h.blobs.values, hasLength(2));
  });

  test('complete restore drains an accepted attachment reference before journal and app-data writes', () async {
    final h = await _ApplicationFixture.create();
    addTearDown(h.close);
    final hold = h.chats.holdNextWrite();
    final attaching = h.attach();
    await hold.started.future;
    final beforeGeneration = h.app.agent.mutations.generation;
    final mainSaves = h.main.saveCount;
    var restoreFinished = false;
    final restoring = h.restore().then((_) => restoreFinished = true);
    expect(h.app.maintenance.isReserved, isTrue);
    expect(restoreFinished, isFalse);
    expect(h.journal.writeCount, 0);
    expect(h.main.saveCount, mainSaves);
    final rejectedDuringRestore = expectLater(
      h.app.agent.binaryAttachments.attach(
        h.id,
        _file(),
        canModify: () => true,
      ),
      throwsA(isA<AttachmentException>()),
    );
    hold.release();
    await attaching;
    await rejectedDuringRestore;
    await restoring;
    await h.app.agent.quiesce();

    expect(h.app.agent.mutations.generation, isNot(beforeGeneration));
    expect(h.app.session.committedData.localeCode, 'zh');
    expect(h.conversation.draftAttachmentIds, hasLength(1));
    final attachment = h.conversation.attachments.single;
    expect(await h.app.agent.attachmentStore.readBytes(attachment), [1, 2, 3]);
    expect(h.journal.source, isNull);
    expect(
      h.events.indexOf('attachment-reference-saved'),
      lessThan(h.events.indexOf('restore-journal-written')),
    );
    await h.attach();
    expect(h.conversation.draftAttachmentIds, hasLength(2));
  });

  test('complete restore invalidates unpublished retries while preserving prior published attachments', () async {
    final h = await _ApplicationFixture.create();
    addTearDown(h.close);
    await h.attach();
    final original = h.conversation.attachments.single;
    h.chats.failNextSave = true;
    await expectLater(h.attach(), throwsStateError);
    expect(h.app.agent.binaryAttachments.hasPending(h.id), isTrue);
    // Recovery of the same archive is allowed to retain a verified retry.
    await h.app.agent.recoverConversations();
    expect(h.app.agent.binaryAttachments.hasPending(h.id), isTrue);
    final generation = h.app.agent.mutations.generation;

    await h.restore();
    await h.app.agent.quiesce();
    expect(h.app.agent.mutations.generation, isNot(generation));
    expect(h.app.agent.binaryAttachments.hasPending(h.id), isFalse);
    await h.app.agent.binaryAttachments.retry(
      h.id,
      canModify: () => h.canModify,
    );
    expect(h.conversation.draftAttachmentIds, [original.id]);
    expect(await h.app.agent.attachmentStore.readBytes(original), [1, 2, 3]);
    await h.app.agent.binaryAttachments.collectGarbage();
    expect(h.blobs.values.keys, [original.id]);
  });

  test('clear waits for cancelled file copying and leaves all attachment admission closed', () async {
    final h = await _ApplicationFixture.create();
    addTearDown(h.close);
    final hold = h.blobs.holdNextWrite();
    final attaching = expectLater(
      h.attach(),
      throwsA(isA<AttachmentException>()),
    );
    await hold.started.future;
    var cleared = false;
    final clearing = h.app.dataClear.run(
      clear: () async {
        expect(h.app.agent.conversations.canWrite, isFalse);
        await h.app.agent.binaryAttachments.clearFrozen();
        h.chats.source = null;
        cleared = true;
      },
      exit: () async {},
    );
    expect(h.app.maintenance.isReserved, isTrue);
    expect(cleared, isFalse);
    hold.release();
    await attaching;
    await clearing;
    expect(cleared, isTrue);
    expect(h.app.dataClear.isCommitted, isTrue);
    expect(h.blobs.values, isEmpty);
    expect(h.chats.source, isNull);
    await expectLater(
      h.app.agent.binaryAttachments.attach(
        h.id,
        _file(),
        canModify: () => true,
      ),
      throwsA(isA<AttachmentException>()),
    );
    await expectLater(h.app.agent.recoverConversations(), throwsStateError);
    await h.app.shutdown.quiesce();
    expect(h.chats.source, isNull);
  });

  test('failed partial clear needs explicit archive recovery and never republishes the old retry', () async {
    final h = await _ApplicationFixture.create();
    addTearDown(h.close);
    h.chats.failNextSave = true;
    await expectLater(h.attach(), throwsStateError);
    expect(h.app.agent.binaryAttachments.hasPending(h.id), isTrue);
    await expectLater(
      h.app.dataClear.run(
        clear: () async {
          await h.app.agent.binaryAttachments.clearFrozen();
          h.chats.source = null;
          throw StateError('Synthetic failure after side-store removal.');
        },
        exit: () async {},
      ),
      throwsStateError,
    );
    expect(h.app.maintenance.isReserved, isFalse);
    expect(h.app.agent.conversations.canWrite, isFalse);
    expect(h.app.agent.binaryAttachments.hasPending(h.id), isFalse);
    await expectLater(
      h.app.agent.binaryAttachments.attach(
        h.id,
        _file(),
        canModify: () => true,
      ),
      throwsA(isA<AttachmentException>()),
    );
    await h.app.agent.recoverConversations();
    expect(h.app.agent.conversations.find(h.id), isNull);
    await h.app.agent.conversations.create(
      id: h.id,
      title: 'Recreated after clear',
    );
    await h.app.agent.binaryAttachments.retry(
      h.id,
      canModify: () => h.canModify,
    );
    expect(h.conversation.attachments, isEmpty);
    await h.attach();
    expect(h.conversation.attachments, hasLength(1));
    expect(h.blobs.values, hasLength(1));
  });

  test('final shutdown closes new admission but drains already accepted reference persistence', () async {
    final h = await _ApplicationFixture.create();
    addTearDown(h.close);
    final hold = h.chats.holdNextWrite();
    final attaching = h.attach();
    await hold.started.future;
    var shutdownFinished = false;
    final shuttingDown = h.app.shutdown.quiesce().then(
      (_) => shutdownFinished = true,
    );
    expect(h.app.agent.runtime.state.value.enabled, isFalse);
    expect(h.app.agent.conversations.canWrite, isFalse);
    expect(shutdownFinished, isFalse);
    hold.release();
    await attaching;
    await shuttingDown;
    final persisted = ConversationArchive.decode(h.chats.source!);
    final saved = persisted.conversations.single.attachments.single;
    expect(h.blobs.values.keys, [saved.id]);
    await expectLater(
      h.app.agent.binaryAttachments.attach(
        h.id,
        _file(),
        canModify: () => true,
      ),
      throwsA(isA<AttachmentException>()),
    );
    await h.app.shutdown.quiesce();
    expect(
      ConversationArchive.decode(h.chats.source!)
          .conversations
          .single
          .attachments
          .single
          .id,
      saved.id,
    );
  });

  testWidgets(
    'a real complete restore rejects a late picker result from the open chat',
    (tester) async {
      final h = (await tester.runAsync(_ApplicationFixture.create))!;
      addTearDown(h.close);
      addTearDown(tester.view.reset);
      final picked = (await tester.runAsync(() async => Completer<XFile?>()))!;
      final pickerOpened = (await tester.runAsync(
        () async => Completer<void>(),
      ))!;
      await mountAgentUi(
        tester,
        AgentConversationView(
          repository: h.app.agent.conversations,
          delegate: h.app.agent.runtime,
          binaryAttachments: h.app.agent.binaryAttachments,
          readDatasetGeneration: () => h.app.agent.mutations.generation,
          recoverConversations: h.app.agent.recoverConversations,
          pickBinaryAttachment: () {
            pickerOpened.complete();
            return picked.future;
          },
        ),
      );
      final generation = h.app.agent.mutations.generation;
      await tester.ensureVisible(
        find.byKey(const ValueKey('agent-attach-file')),
      );
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('agent-attach-file')));
        await pickerOpened.future;
        await h.restore();
      });
      expect(h.app.agent.mutations.generation, isNot(generation));
      await tester.runAsync(() async {
        picked.complete(_file());
        await h.app.agent.binaryAttachments.waitForPendingOperations();
      });
      await tester.pumpAndSettle();
      expect(h.conversation.attachments, isEmpty);
      expect(h.blobs.values, isEmpty);
      expect(h.blobs.writeCount, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

XFile _file() => XFile.fromData(
  Uint8List.fromList([1, 2, 3]),
  path: 'fixture.pdf',
  name: 'fixture.pdf',
);

class _WriteGate {
  final started = Completer<void>();
  final _released = Completer<void>();
  void release() {
    if (!_released.isCompleted) _released.complete();
  }

  Future<void> wait() {
    if (!started.isCompleted) started.complete();
    return _released.future;
  }
}

class _ChatStorage extends ConversationStorage {
  _ChatStorage(this.events) : super.base();
  final List<String> events;
  String? source;
  bool failNextSave = false;
  _WriteGate? _nextWrite;
  final gates = <_WriteGate>[];
  _WriteGate holdNextWrite() {
    final gate = _WriteGate();
    gates.add(gate);
    return _nextWrite = gate;
  }

  @override
  Future<ConversationStorageLoad> load() async =>
      ConversationStorageLoad(source: source);
  @override
  Future<void> save(String value, {required int revision}) async {
    final gate = _nextWrite;
    _nextWrite = null;
    await gate?.wait();
    if (failNextSave) {
      failNextSave = false;
      throw StateError('Synthetic attachment reference failure.');
    }
    source = value;
    if (ConversationArchive.decode(value).conversations
        .any((c) => c.attachments.isNotEmpty)) {
      events.add('attachment-reference-saved');
    }
  }
}

class _BlobStorage extends MemoryAttachmentStorage {
  int writeCount = 0;
  _WriteGate? _nextWrite;
  final gates = <_WriteGate>[];
  _WriteGate holdNextWrite() {
    final gate = _WriteGate();
    gates.add(gate);
    return _nextWrite = gate;
  }

  @override
  Future<void> write(String id, Stream<List<int>> bytes) async {
    writeCount++;
    final gate = _nextWrite;
    _nextWrite = null;
    await gate?.wait();
    await super.write(id, bytes);
  }
}

class _Journal extends AppBackupRestoreJournal {
  _Journal(this.events) : super.base();
  final List<String> events;
  String? source;
  int writeCount = 0;
  @override
  String get pendingArtifactPath => 'memory://attachment-lifecycle/restore';
  @override
  Future<String?> read() async => source;
  @override
  Future<void> write(String value) async {
    writeCount++;
    source = value;
    events.add('restore-journal-written');
  }

  @override
  Future<void> clear() async => source = null;
  @override
  Future<String> preserveForRecovery(String value) async =>
      'memory://attachment-lifecycle/recovery';
  @override
  Future<Uint8List?> readRecoveryArtifact(String path) async => null;
}

class _Sites extends SchoolSiteStore {
  _Sites() : super.base();
  String source = '[]';
  @override
  Future<String?> load() async => source;
  @override
  Future<void> save(String value) async => source = value;
  @override
  Future<String?> filePath() async => 'memory://attachment-lifecycle/sites';
}

class _Secrets implements SecretStore {
  String value = '';
  @override
  Future<String> readCustomSchoolImportApiKey() async => value;
  @override
  Future<void> writeCustomSchoolImportApiKey(String key) async => value = key;
}

class _ApplicationFixture {
  _ApplicationFixture();
  final events = <String>[];
  late final chats = _ChatStorage(events);
  final blobs = _BlobStorage();
  late final journal = _Journal(events);
  final main = MemoryTimetableStorage(
    initialData: buildInitialAppData(
      buildDefaultPeriodTimes(),
      localeCode: 'en',
    ),
  );
  late final http.Client client;
  late final ProviderClient provider;
  late final AppRuntime app;
  late final String id;
  var requests = 0;
  bool _closed = false;
  AgentConversation get conversation => app.agent.conversations.find(id)!;
  bool get canModify =>
      app.agent.runtime.state.value.enabled &&
      !app.maintenance.isReserved &&
      app.agent.conversations.canWrite;

  static Future<_ApplicationFixture> create() async {
    final h = _ApplicationFixture();
    h.client = MockClient((_) async {
      h.requests++;
      return http.Response('Unexpected synthetic request.', 500);
    });
    h.provider = ProviderClient(client: h.client);
    h.app = AppRuntime(
      storage: h.main,
      secretStore: _Secrets(),
      schoolSiteService: SchoolSiteService(store: _Sites()),
      backupRestoreJournal: h.journal,
      dataTransferCodec: inlineDataTransferCodec,
      agentConversationStorage: h.chats,
      agentAttachmentStorage: h.blobs,
      agentKnowledgeStorage: MemoryKnowledgeStorage(),
      agentCredentialStore: MemoryAgentCredentialStore(),
      agentProvider: h.provider,
      systemLocaleCodeResolver: () => 'en',
      appVersionLoader: () async => '3.0.0',
      uiStateSaveDelay: Duration.zero,
      workspaceMutationLock: (action) => action(),
    );
    await h.app.lifecycle.load();
    await h.app.agent.initialize();
    await h.app.agent.quiesce();
    h.id = (await h.app.agent.conversations.create(
      title: 'Application attachments',
    )).id;
    await h.app.agent.quiesce();
    return h;
  }

  Future<void> attach() {
    final generation = app.agent.mutations.generation;
    return app.agent.binaryAttachments.attach(
      id,
      _file(),
      canModify: () =>
          canModify && generation == app.agent.mutations.generation,
    );
  }

  Future<void> restore() async {
    await app.backups.importJson(
      encodeAppBackup(
        buildInitialAppData(buildDefaultPeriodTimes(), localeCode: 'zh'),
        const [],
      ),
      mode: AppImportMode.replaceAll,
    );
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    for (final gate in [...chats.gates, ...blobs.gates]) {
      gate.release();
    }
    await app.shutdown.quiesce();
    app.dispose();
    await app.agent.attachmentStore.close();
    await app.session.close();
    provider.close();
    client.close();
    expect(requests, 0);
  }
}
