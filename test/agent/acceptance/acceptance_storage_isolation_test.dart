import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sked/agent/attachments/attachment_storage.dart';
import 'package:sked/agent/conversations/conversation_storage.dart';
import 'package:sked/agent/knowledge/knowledge_storage.dart';
import 'package:sked/backup/backup_staging_storage.dart';
import 'package:sked/backup/selective_backup_models.dart';
import 'package:sked/backup/selective_restore_coordinator.dart';
import 'package:sked/backup/selective_restore_journal.dart';
import 'package:sked/services/app_backup_restore_journal.dart';

import 'acceptance_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('native acceptance initializes and reads backups without any default storage factory', () async {
    // Mirrors native smoke, which does not inherit test/flutter_test_config.
    SharedPreferences.setMockInitialValues({});
    final attemptedFactories = <String>[];
    Never reject(String name) {
      attemptedFactories.add(name);
      throw StateError('The synthetic harness reached $name platform storage');
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

    for (final suppliedAttachments in <MemoryAttachmentStorage?>[
      null,
      MemoryAttachmentStorage(),
    ]) {
      final harness = AcceptanceHarness();
      await harness.initialize(attachmentStorage: suppliedAttachments);
      try {
        final inventory = await harness.app.backups.selective.inventory();
        expect(
          inventory.records.where(
            (record) => record.key.kind == BackupObjectKind.timetable,
          ),
          hasLength(2),
        );
        expect(
          harness.app.backups.selective.journal,
          isA<MemorySelectiveRestoreJournal>(),
        );
        expect(await harness.app.backups.selective.journal.read(), isNull);
        if (suppliedAttachments != null) {
          expect(
            harness.app.agent.attachmentStore.storage,
            same(suppliedAttachments),
          );
        } else {
          expect(
            harness.app.agent.attachmentStore.storage,
            isA<MemoryAttachmentStorage>(),
          );
        }
      } finally {
        await harness.close();
      }
    }
    expect(attemptedFactories, isEmpty);
  });
}
