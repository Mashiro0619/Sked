import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/attachments/attachment_storage.dart';
import 'package:sked/agent/conversations/conversation_storage.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/controllers/app_backup_controller.dart';
import 'package:sked/models/timetable_models.dart';

import '../support/memory_conversation_storage.dart';
import '../support/workspace_harness.dart';

const _orphanId = 'dormant-orphan-before-first-entry';

class _ChatStorage extends MemoryConversationStorage {
  int reads = 0, writes = 0;

  @override
  Future<ConversationStorageLoad> load() async {
    reads++;
    return super.load();
  }

  @override
  Future<void> save(String value, {required int revision}) async {
    writes++;
    await super.save(value, revision: revision);
  }
}

class _AttachmentStorage extends MemoryAttachmentStorage {
  int reads = 0, listings = 0, writes = 0;
  final deleted = <String>[];

  @override
  Stream<List<int>> read(String id) async* {
    reads++;
    yield* super.read(id);
  }

  @override
  Future<Set<String>> ids() async {
    listings++;
    return super.ids();
  }

  @override
  Future<void> write(String id, Stream<List<int>> bytes) async {
    writes++;
    await super.write(id, bytes);
  }

  @override
  Future<void> delete(String id) async {
    deleted.add(id);
    await super.delete(id);
  }
}

class _DormantApp {
  _DormantApp(this.app, this.main, this.chats, this.files);

  final AppRuntime app;
  final WorkspaceMemoryStorage main;
  final _ChatStorage chats;
  final _AttachmentStorage files;
  final maintenanceStates = <bool>[false];

  static Future<_DormantApp> create() async {
    final main = WorkspaceMemoryStorage(
      buildInitialAppData(buildDefaultPeriodTimes(), localeCode: 'en'),
    );
    final chats = _ChatStorage();
    final files = _AttachmentStorage()
      ..values[_orphanId] = Uint8List.fromList([9, 8, 7]);
    final app = await workspaceProvider(
      storage: main,
      agentConversationStorage: chats,
      agentAttachmentStorage: files,
    );
    final fixture = _DormantApp(app, main, chats, files);
    void recordMaintenance() {
      final reserved = app.maintenance.isReserved;
      if (fixture.maintenanceStates.last != reserved) {
        fixture.maintenanceStates.add(reserved);
      }
    }

    app.maintenance.addListener(recordMaintenance);
    addTearDown(() async {
      app.maintenance.removeListener(recordMaintenance);
      await app.agent.quiesce();
      app.dispose();
    });
    fixture.assertDormant();
    return fixture;
  }

  String get backup => encodeAppBackup(
    app.session.committedData.copyWith(hideHomeWorkspaceNavigation: true),
    const [],
  );

  void assertDormant() {
    expect(app.agent.settings.enabled, isTrue);
    expect(app.agent.isInitialized, isFalse);
    expect(app.agent.conversations.isLoaded, isFalse);
    expect(app.agent.conversations.canWrite, isFalse);
    expect(chats.reads, 0);
    expect(chats.writes, 0);
    expect(files.reads, 0);
    expect(files.listings, 0);
    expect(files.writes, 0);
    expect(files.deleted, isEmpty);
    expect(files.values.keys, [_orphanId]);
  }

  Future<void> assertFirstEntryCanAttachAndCollect() async {
    // The ready result itself must reopen attachments. No maintenance retry or
    // secondary initialization is allowed before this first attachment.
    await app.agent.initialize();
    expect(app.agent.isInitialized, isTrue);
    expect(app.agent.conversations.canWrite, isTrue);
    final conversation = await app.agent.conversations.createDraft(
      title: 'First unsent chat',
      id: 'dormant-first-chat',
    );
    final bytes = Uint8List.fromList([1, 2, 3, 4]);
    await app.agent.binaryAttachments.attach(
      conversation.id,
      XFile.fromData(bytes, path: 'first.bin', name: 'first.bin'),
      canModify: () =>
          app.agent.isInitialized &&
          app.session.canWrite &&
          !app.maintenance.isReserved,
    );
    await app.agent.quiesce();
    final current = app.agent.conversations.find(conversation.id)!;
    final attachment = current.attachments.single;
    expect(current.draftAttachmentIds, [attachment.id]);
    expect(files.values[attachment.id], bytes);
    // First-entry automatic collection must run, not merely permit a direct
    // garbage-collection call that could bypass the application's freeze gate.
    expect(files.listings, greaterThan(0));
    expect(files.deleted, contains(_orphanId));
    expect(files.values.keys, [attachment.id]);
    expect(app.agent.attachmentCleanupError, isFalse);
    expect(await app.agent.attachmentStore.readBytes(attachment), bytes);
    expect(chats.reads, greaterThan(0));
    expect(chats.writes, 0);
    expect(chats.source, isNull);
    expect(app.agent.conversations.conversations, isEmpty);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('dormant default-on Agent stays lazy through successful complete restore and resumes attachments at first entry', () async {
    final fixture = await _DormantApp.create();
    await fixture.app.backups.importJson(
      fixture.backup,
      mode: AppImportMode.replaceAll,
    );
    await fixture.app.agent.quiesce();
    expect(fixture.maintenanceStates, [false, true, false]);
    expect(
      fixture.app.session.committedData.hideHomeWorkspaceNavigation,
      isTrue,
    );
    fixture.assertDormant();
    await fixture.assertFirstEntryCanAttachAndCollect();
  });

  test('failed complete restore leaves dormant Agent lazy and first-entry attachments usable after rollback', () async {
    final fixture = await _DormantApp.create();
    final failure = StateError('Synthetic dormant restore write failure');
    fixture.main.saveError = failure;
    await expectLater(
      fixture.app.backups.importJson(
        fixture.backup,
        mode: AppImportMode.replaceAll,
      ),
      throwsA(same(failure)),
    );
    await fixture.app.agent.quiesce();
    expect(fixture.maintenanceStates, [false, true, false]);
    expect(
      fixture.app.session.committedData.hideHomeWorkspaceNavigation,
      isFalse,
    );
    fixture.assertDormant();
    await fixture.assertFirstEntryCanAttachAndCollect();
  });

  test('malformed complete restore releases dormant attachment freeze without eagerly reading history', () async {
    final fixture = await _DormantApp.create();
    await expectLater(
      fixture.app.backups.importJson(
        'invalid JSON',
        mode: AppImportMode.replaceAll,
      ),
      throwsFormatException,
    );
    await fixture.app.agent.quiesce();
    expect(fixture.maintenanceStates, [false, true, false]);
    fixture.assertDormant();
    await fixture.assertFirstEntryCanAttachAndCollect();
  });

  test('declined complete restore keeps dormant Agent lazy and first-entry attachments available', () async {
    final fixture = await _DormantApp.create();
    final unregister = fixture.app.workspaces.registerExitGuard(
      AppMode.student,
      () async => false,
    );
    addTearDown(unregister);
    await expectLater(
      fixture.app.backups.importJson(
        fixture.backup,
        mode: AppImportMode.replaceAll,
      ),
      throwsA(isA<WorkspaceChangeCancelledException>()),
    );
    await fixture.app.agent.quiesce();
    expect(fixture.maintenanceStates, [false]);
    expect(
      fixture.app.session.committedData.hideHomeWorkspaceNavigation,
      isFalse,
    );
    fixture.assertDormant();
    await fixture.assertFirstEntryCanAttachAndCollect();
  });
}
