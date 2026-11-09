import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as path;
import 'package:sked/agent/attachments/attachment_storage_io.dart';
import 'package:sked/agent/bridge/generated/api.dart';
import 'package:sked/agent/bridge/generated/api/contracts.dart' as native;
import 'package:sked/agent/bridge/rust_agent_client.dart';
import 'package:sked/agent/connection/agent_credential_store.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/backup/selective_restore_coordinator.dart';
import 'package:sked/backup/selective_restore_journal.dart';
import 'package:sked/backup/selective_restore_journal_io.dart';
import 'package:sked/data/timetable_storage_io.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/app_backup_restore_journal_io.dart';
import 'package:sked/services/app_storage_layout_io.dart';
import 'package:sked/services/device_preferences_store.dart';
import 'package:sked/services/school_site_service.dart';
import 'package:sked/services/school_site_store_io.dart';
import 'package:sked/services/secret_store.dart';

/// Actual application assembly with durable data beneath the journey root.
class OfflineAgentWorkspace {
  OfflineAgentWorkspace(this.root);

  final Directory root;
  late final businessDirectory = Directory(path.join(root.path, 'business'));
  late final agentDirectory = Directory(path.join(root.path, 'agent'));
  late final stagingDirectory = Directory(path.join(root.path, 'staging'));
  late final layout = AppStorageLayout(
    directoryProvider: () async => businessDirectory,
  );
  late final stagingLayout = AppStorageLayout(
    directoryProvider: () async => stagingDirectory,
  );
  final writeGate = OfflineWriteGate();
  late AppRuntime app;
  late AgentRustClient client;
  bool _opened = false;
  bool _coreClosed = false;
  bool _closed = false;

  PersistentSelectiveRestoreJournal createRestoreJournal() =>
      PersistentSelectiveRestoreJournal(
        storage: PlatformSelectiveJournalStorage(layout: layout),
      );

  Future<void> open({
    AppData? seed,
    List<native.OfflineModelReply> replies = const [],
    SelectiveRestoreJournal? journal,
    AgentCredentialStore? credentials,
    bool initializeAgent = true,
  }) async {
    await businessDirectory.create(recursive: true);
    final storage = _OfflineTimetableStorage(
      IoTimetableStorage(
        layout: layout,
        beforeMainReplace: writeGate.beforeReplace,
      ),
      writeGate,
    );
    if (seed != null) await storage.save(seed);
    client = AgentRustClient(
      initialize: () => AgentCore.initialize(
        config: native.CoreConfig(
          dataDirectory: agentDirectory.path,
          preamble: 'Use Sked tools and report actual business receipts.',
          tools: app.agent.businessHost.definitions,
          generateTitles: false,
          offlineReplies: replies,
        ),
      ),
    );
    app = AppRuntime(
      storage: storage,
      schoolSiteService: SchoolSiteService(
        store: PlatformSchoolSiteStore(layout: layout),
      ),
      secretStore: _OfflineSecrets(),
      devicePreferences: DevicePreferencesStore.memory(),
      backupRestoreJournal: FileAppBackupRestoreJournal(layout: layout),
      selectiveRestoreJournal: journal ?? createRestoreJournal(),
      backupStagingStorage: PlatformAttachmentStorage(layout: stagingLayout),
      agentNativeClient: client,
      agentAttachmentStagingDirectory: Directory(
        path.join(stagingDirectory.path, 'picker'),
      ),
      agentCredentialStore: credentials ?? MemoryAgentCredentialStore(),
      agentGenerateConversationTitles: false,
      workspaceMutationLock: (action) => action(),
      systemLocaleCodeResolver: () => 'zh_CN',
      appVersionLoader: () async => '0.0.0',
    );
    _opened = true;
    await app.lifecycle.load();
    if (!app.session.canWrite) {
      throw StateError('The offline application failed to open writable data.');
    }
    if (initializeAgent) await app.agent.initialize();
  }

  Future<void> closeCore() async {
    if (!_opened || _coreClosed) return;
    await app.agent.close();
    _coreClosed = true;
  }

  Future<void> close() async {
    if (!_opened || _closed) return;
    writeGate.release();
    await closeCore();
    await app.backups.selective.close();
    await app.session.repository.waitForPendingWrites(propagateErrors: true);
    app.dispose();
    await app.session.close();
    _closed = true;
  }
}

class OfflineWriteGate {
  Completer<void> entered = Completer<void>();
  Completer<void>? _release;
  bool loseNextReply = false;
  int committedWrites = 0;
  int lostReplies = 0;

  void afterSaved() {
    committedWrites++;
    if (!loseNextReply) return;
    loseNextReply = false;
    lostReplies++;
    throw StorageWriteStateUnknownException(
      writeError: StateError('The durable write reply was interrupted.'),
      rollbackError: StateError(
        'The caller cannot observe the committed write.',
      ),
    );
  }

  void arm() {
    entered = Completer<void>();
    _release = Completer<void>();
  }

  Future<void> beforeReplace() async {
    final gate = _release;
    if (gate == null) return;
    if (!entered.isCompleted) entered.complete();
    await gate.future;
  }

  void release() {
    final gate = _release;
    _release = null;
    if (gate != null && !gate.isCompleted) gate.complete();
  }
}

class _OfflineTimetableStorage
    implements
        TimetableStorage,
        TimetableRecoveryArtifactReader,
        TimetableLegacySecretSanitizer {
  _OfflineTimetableStorage(this.inner, this.gate);
  final IoTimetableStorage inner;
  final OfflineWriteGate gate;

  @override
  Future<StorageLoadResult> load() => inner.load();
  @override
  Future<String?> filePath() => inner.filePath();
  @override
  Future<void> save(AppData data) async {
    await inner.save(data);
    gate.afterSaved();
  }

  @override
  Future<Uint8List?> readRecoveryArtifact(String artifactPath) =>
      inner.readRecoveryArtifact(artifactPath);
  @override
  Future<void> sanitizeLegacyAiApiSecretArtifacts() =>
      inner.sanitizeLegacyAiApiSecretArtifacts();
}

class _OfflineSecrets implements SecretStore {
  String _key = '';
  @override
  Future<String> readCustomSchoolImportApiKey() async => _key;
  @override
  Future<void> writeCustomSchoolImportApiKey(String value) async =>
      _key = value;
}
