import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sked/agent/attachments/attachment_storage.dart';
import 'package:sked/agent/connection/agent_credential_store.dart';
import 'package:sked/backup/backup_staging_storage.dart';
import 'package:sked/backup/selective_backup_models.dart';
import 'package:sked/backup/selective_restore_coordinator.dart';
import 'package:sked/backup/selective_restore_journal.dart';
import 'package:sked/services/app_backup_restore_journal.dart';
import 'package:sked/services/device_preferences_store.dart';

import 'agent_native_fixture.dart';
import 'workspace_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'workspace defaults isolate platform storage and each runtime',
    () async {
      SharedPreferences.setMockInitialValues({});
      final attemptedFactories = <String>[];
      Never reject(String name) {
        attemptedFactories.add(name);
        throw StateError('The synthetic workspace reached $name storage');
      }

      debugSetAttachmentStorageFactory(() => reject('attachments'));
      debugSetSelectiveRestoreJournalFactory(() => reject('selective journal'));
      debugSetBackupStagingStorageFactory(() => reject('backup staging'));
      debugSetAppBackupRestoreJournalFactory(() => reject('legacy journal'));
      addTearDown(() {
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
          expect(runtime.agent.platformSupported, isFalse);
          expect(runtime.agent.nativeClient.isInitialized, isFalse);
          final inventory = await runtime.backups.selective.inventory();
          expect(
            inventory.records.where(
              (record) => record.key.kind == BackupObjectKind.timetable,
            ),
            isNotEmpty,
          );
          expect(
            runtime.backups.selective.journal,
            isA<MemorySelectiveRestoreJournal>(),
          );
        }
        await first.settingsCommands.updateLocaleCode('zh');
        await first.persistence.flushPendingUiStateSaves();
        expect(first.session.committedData.localeCode, 'zh');
        expect(second.session.committedData.localeCode, 'en');
        expect(
          identical(first.devicePreferences, second.devicePreferences),
          isFalse,
        );
        expect(
          identical(
            first.backups.selective.journal,
            second.backups.selective.journal,
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
    },
  );

  test(
    'explicit workspace owners receive initialization and settings writes',
    () async {
      final native = MemoryAgentCore();
      final directory = await Directory.systemTemp.createTemp('sked-ui-owner-');
      addTearDown(() => directory.delete(recursive: true));
      final journal = MemorySelectiveRestoreJournal();
      final staging = MemoryAttachmentStorage();
      final credentials = _ObservedCredentials();
      final devices = DevicePreferencesStore.memory();
      final runtime = await workspaceProvider(
        agentNativeClient: native.client,
        agentAttachmentStagingDirectory: directory,
        selectiveRestoreJournal: journal,
        backupStagingStorage: staging,
        agentCredentialStore: credentials,
        devicePreferences: devices,
      );
      try {
        await runtime.agent.initialize();
        expect(runtime.agent.isInitialized, isTrue);
        expect(runtime.agent.nativeClient, same(native.client));
        expect(native.initializationCount, 1);
        expect(credentials.reads, greaterThan(0));
        expect(runtime.backups.selective.journal, same(journal));
        expect(runtime.devicePreferences, same(devices));
        await runtime.settingsCommands.updateLocaleCode('zh');
        await runtime.persistence.flushPendingUiStateSaves();
        expect(runtime.session.committedData.localeCode, 'zh');
      } finally {
        await runtime.agent.quiesce();
        await runtime.agent.close();
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
