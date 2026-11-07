import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/conversations/conversation_models.dart';
import 'package:sked/agent/knowledge/knowledge_models.dart';
import 'package:sked/agent/store/agent_store.dart';
import 'package:sked/backup/selective_backup_models.dart';
import 'package:sked/backup/selective_restore_coordinator.dart';
import 'package:sked/backup/selective_restore_journal.dart';
import 'package:sked/backup/selective_restore_journal_io.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/app_storage_layout_io.dart';

import '../support/workspace_harness.dart';

class _MainStorage extends WorkspaceMemoryStorage {
  _MainStorage(super.data);
  int writes = 0;
  @override
  Future<void> save(AppData value) async {
    await super.save(value);
    writes++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final completed in [0, 2, 3]) {
    test(
      'startup completes the sealed legacy restore with $completed stages recorded',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'sked-legacy-restore-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final layout = AppStorageLayout(
          directoryProvider: () async => directory,
        );
        final journal = PersistentSelectiveRestoreJournal(
          storage: PlatformSelectiveJournalStorage(layout: layout),
        );
        final before = buildInitialAppData(
          buildDefaultPeriodTimes(),
          localeCode: 'en',
        );
        final calendar = before.generalMode.schedules.first;
        final after = before.copyWith(
          generalMode: before.generalMode.withSchedule(
            calendar.copyWith(name: 'Accepted legacy restore'),
          ),
        );
        Map<String, Object?> oldMain(AppData data) => {
          ...data.toJson(),
          'schemaVersion': 6,
        };
        final oldKnowledge = {
          ...KnowledgeArchive(revision: 19, storageRevision: 21).toJson(),
          'version': 2,
        };
        final oldConversations = {
          ...ConversationArchive(revision: 37).toJson(),
          'version': 8,
        };
        const restoreId = 'accepted-legacy-restore';
        var progress = SelectiveRestoreState(
          restoreId: restoreId,
          planFingerprint: backupDigest(utf8.encode('legacy plan')),
          targets: [
            BackupPreparedTarget(
              owner: BackupOwner.mainData,
              restoreId: restoreId,
              descriptor: {'before': oldMain(before), 'target': oldMain(after)},
            ),
            BackupPreparedTarget(
              owner: BackupOwner.knowledge,
              restoreId: restoreId,
              descriptor: {
                'before': oldKnowledge,
                'target': {...oldKnowledge, 'storageRevision': 22},
              },
            ),
            BackupPreparedTarget(
              owner: BackupOwner.conversations,
              restoreId: restoreId,
              descriptor: {
                'before': oldConversations,
                'target': {...oldConversations, 'revision': 38},
              },
            ),
          ],
        );
        await journal.write(progress);
        for (var index = 0; index < completed; index++) {
          progress = progress.markApplied();
          await journal.write(progress);
        }
        final main = _MainStorage(completed == 0 ? before : after);
        final store = AgentStore.open(
          filePath: '${directory.path}/Sked_agent.sqlite',
        );
        final app = await workspaceProvider(
          storage: main,
          agentStore: store,
          selectiveRestoreJournal: journal,
        );
        addTearDown(() async {
          await app.shutdown.quiesce();
          app.dispose();
          await app.backups.selective.close();
          await app.session.close();
          await store.close();
        });
        expect(app.session.canWrite, isTrue);
        expect(
          app.session.committedData.generalMode.schedules.first.name,
          'Accepted legacy restore',
        );
        expect(main.writes, completed == 0 ? 1 : 0);
        expect(await journal.read(), isNull);
        expect(
          await store.readMetadata('legacy_restore:knowledge:$restoreId'),
          progress.targets[1].fingerprint,
        );
        expect(
          await store.readMetadata('legacy_restore:conversations:$restoreId'),
          progress.targets[2].fingerprint,
        );
        expect(await store.conversations.readRevision(), 0);
        expect(await store.knowledge.readRevision(), 0);
        expect(app.agent.conversations.conversations, isEmpty);
        expect(await store.readMetadata('legacy_cutover'), 'complete');
      },
    );
  }
}
