import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:sked/agent/attachments/attachment_storage.dart';
import 'package:sked/agent/connection/agent_credential_store.dart';
import 'package:sked/agent/conversations/conversation_storage.dart';
import 'package:sked/agent/conversations/conversation_storage_io.dart';
import 'package:sked/agent/knowledge/knowledge_models.dart';
import 'package:sked/agent/knowledge/knowledge_storage.dart';
import 'package:sked/agent/knowledge/knowledge_storage_io.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/backup/selective_restore_coordinator.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/data/timetable_storage_io.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/app_backup_restore_journal_io.dart';
import 'package:sked/services/app_storage_layout_io.dart';
import 'package:sked/services/device_preferences_store.dart';
import 'package:sked/services/school_site_service.dart';
import 'package:sked/services/school_site_store_io.dart';
import 'package:sked/services/secret_store.dart';

import 'agent_performance_fixtures.dart';

/// No selected workload needs a socket, native web view, HTTP or a model.
/// Deny HTTP construction's resulting client before any request can be sent,
/// while allowing the application's ordinary unused client owners to exist.
class AgentPerformanceNetworkGuard {
  int httpAttempts = 0;
  int modelAttempts = 0;

  Future<T> run<T>(Future<T> Function() action) => HttpOverrides.runZoned(
    action,
    createHttpClient: (_) => _OfflineHttpClient(this),
  );

  void verify() {
    if (httpAttempts != 0 || modelAttempts != 0) {
      throw StateError('An offline Agent workload attempted network access.');
    }
  }
}

class _OfflineHttpClient implements HttpClient {
  _OfflineHttpClient(this.guard);
  final AgentPerformanceNetworkGuard guard;

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) {
    guard.httpAttempts++;
    throw StateError('HTTP is disabled in the Agent benchmark.');
  }
}

class _OfflineTransport extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      Future.error(StateError('Agent benchmark transport is disabled.'));
}

class _OfflineProvider extends ProviderClient {
  _OfflineProvider(this.guard) : super(client: _OfflineTransport());
  final AgentPerformanceNetworkGuard guard;
  final closed = Completer<void>();

  @override
  Stream<ProviderEvent> stream(
    ProviderRequest request, {
    required String apiKey,
    ProviderCancellationToken? cancellation,
  }) {
    guard.modelAttempts++;
    return Stream.error(StateError('The Agent benchmark cannot call a model.'));
  }

  @override
  void close() {
    super.close();
    if (!closed.isCompleted) closed.complete();
  }
}

class AgentPerformanceMainStorage extends IoTimetableStorage {
  AgentPerformanceMainStorage(Directory directory)
    : super(directoryProvider: () async => directory);
  int loads = 0;
  int writes = 0;

  @override
  Future<StorageLoadResult> load() async {
    loads++;
    return super.load();
  }

  @override
  Future<void> save(AppData value) async {
    await super.save(value);
    writes++;
  }
}

class AgentPerformanceChatStorage extends PlatformConversationStorage {
  AgentPerformanceChatStorage({super.layout});
  int loads = 0;
  int writes = 0;
  int markerReads = 0;

  @override
  Future<ConversationStorageLoad> load() async {
    loads++;
    return super.load();
  }

  @override
  Future<void> save(String source, {required int revision}) async {
    await super.save(source, revision: revision);
    writes++;
  }

  @override
  Future<String?> pendingHistoryBatch() async {
    markerReads++;
    return super.pendingHistoryBatch();
  }
}

class AgentPerformanceKnowledgeStorage extends PlatformKnowledgeStorage {
  AgentPerformanceKnowledgeStorage({super.layout});
  int loads = 0;
  int writes = 0;

  @override
  Future<KnowledgeStorageLoad> load() async {
    loads++;
    return super.load();
  }

  @override
  Future<void> save(KnowledgeArchive archive) async {
    await super.save(archive);
    writes++;
  }
}

class _CountingCredentials extends MemoryAgentCredentialStore {
  int reads = 0;
  int writes = 0;

  @override
  Future<String?> read(AgentCredentialSlot slot) async {
    reads++;
    return super.read(slot);
  }

  @override
  Future<void> write(AgentCredentialSlot slot, String? value) async {
    writes++;
    await super.write(slot, value);
  }
}

class _CountingAttachments extends MemoryAttachmentStorage {
  int enumerations = 0;

  @override
  Future<Set<String>> ids() async {
    enumerations++;
    return super.ids();
  }
}

class _EmptySecrets implements SecretStore {
  @override
  Future<String> readCustomSchoolImportApiKey() async => '';

  @override
  Future<void> writeCustomSchoolImportApiKey(String value) async {
    if (value.isNotEmpty) {
      throw StateError('No benchmark operation may install a secret.');
    }
  }
}

/// Every physical artifact belongs to a newly-created system temporary root.
/// Fixture writes and constructor dependency preparation happen before timing.
class AgentPerformanceDiskSession {
  AgentPerformanceDiskSession._(
    this.directory,
    this.storage,
    this.chats,
    this.knowledge,
    this.network,
  );

  static Future<AgentPerformanceDiskSession> prepare(
    AgentPerformanceFixtures fixtures, {
    required bool agentEnabled,
    required AgentPerformanceNetworkGuard network,
  }) async {
    final directory = await Directory.systemTemp.createTemp(
      'sked-agent-performance-',
    );
    try {
      final layout = AppStorageLayout(directoryProvider: () async => directory);
      final storage = AgentPerformanceMainStorage(directory);
      final chats = AgentPerformanceChatStorage(layout: layout);
      final knowledge = AgentPerformanceKnowledgeStorage(layout: layout);
      await storage.save(fixtures.dataWithAgent(agentEnabled));
      await chats.save(
        fixtures.archive.encode(),
        revision: fixtures.archive.revision,
      );
      await knowledge.save(KnowledgeArchive());
      storage.writes = 0;
      chats.writes = 0;
      knowledge.writes = 0;
      return AgentPerformanceDiskSession._(
        directory,
        storage,
        chats,
        knowledge,
        network,
      );
    } catch (_) {
      await directory.delete(recursive: true);
      rethrow;
    }
  }

  final Directory directory;
  final AgentPerformanceMainStorage storage;
  final AgentPerformanceChatStorage chats;
  final AgentPerformanceKnowledgeStorage knowledge;
  final AgentPerformanceNetworkGuard network;
  final _credentials = _CountingCredentials();
  final _attachments = _CountingAttachments();
  final _devicePreferences = DevicePreferencesStore.memory();
  late final _OfflineProvider _provider = _OfflineProvider(network);
  AppRuntime? _app;

  AppRuntime get app => _app ?? (throw StateError('Runtime not constructed.'));

  void constructRuntime() {
    if (_app != null) throw StateError('Each load uses a new AppRuntime.');
    _app = AppRuntime(
      storage: storage,
      secretStore: _EmptySecrets(),
      schoolSiteService: SchoolSiteService(
        store: PlatformSchoolSiteStore(
          directoryProvider: () async => directory,
        ),
      ),
      backupRestoreJournal: FileAppBackupRestoreJournal(
        directoryProvider: () async => directory,
      ),
      devicePreferences: _devicePreferences,
      // Explicit test owners prevent this benchmark from opening user stores.
      // ignore: invalid_use_of_visible_for_testing_member
      selectiveRestoreJournal: MemorySelectiveRestoreJournal(),
      // ignore: invalid_use_of_visible_for_testing_member
      backupStagingStorage: MemoryAttachmentStorage(),
      // ignore: invalid_use_of_visible_for_testing_member
      agentConversationStorage: chats,
      // ignore: invalid_use_of_visible_for_testing_member
      agentKnowledgeStorage: knowledge,
      // ignore: invalid_use_of_visible_for_testing_member
      agentAttachmentStorage: _attachments,
      // ignore: invalid_use_of_visible_for_testing_member
      agentCredentialStore: _credentials,
      // ignore: invalid_use_of_visible_for_testing_member
      agentProvider: _provider,
      systemLocaleCodeResolver: () => 'en',
      // Preserve production codecs and durable writes. This test target must
      // never acquire the user's notification runtime lock.
      // ignore: invalid_use_of_visible_for_testing_member
      workspaceMutationLock: (action) => action(),
    );
  }

  Future<void> load({required bool openAgent}) async {
    await app.lifecycle.load();
    if (!app.session.isLoaded || !app.session.canWrite) {
      throw StateError('The isolated main archive did not become writable.');
    }
    if (openAgent) await app.agent.initialize();
    // Initialization can schedule attachment collection. Observe counters/RSS
    // only after its accepted work has drained, without loading dormant stores.
    await app.agent.quiesce();
  }

  Map<String, int> get counters => {
    'mainLoads': storage.loads,
    'mainWrites': storage.writes,
    'chatLoads': chats.loads,
    'chatWrites': chats.writes,
    'historyMarkerReads': chats.markerReads,
    'knowledgeLoads': knowledge.loads,
    'knowledgeWrites': knowledge.writes,
    'credentialReads': _credentials.reads,
    'credentialWrites': _credentials.writes,
    'attachmentEnumerations': _attachments.enumerations,
  };

  Future<AppData> readBack() async {
    final readback = await IoTimetableStorage(
      directoryProvider: () async => directory,
    ).load();
    if (!readback.canWrite || readback.data == null) {
      throw StateError('Independent main archive readback was not writable.');
    }
    return readback.data!;
  }

  Future<void> close() async {
    try {
      if (_app != null) {
        try {
          await app.shutdown.quiesce();
        } finally {
          app.dispose();
          try {
            // Await the service directly: closeSelective also disposes its
            // notifier. This fixture's memory staging close is safe to repeat.
            await Future.wait<void>([
              _provider.closed.future,
              app.backups.selective.close(),
              app.session.close(),
            ]);
          } finally {
            // Session close seals the event stream, not repository writes.
            // Drain after the other producers, even if quiescence failed.
            await app.session.repository.waitForPendingWrites();
          }
        }
      }
    } finally {
      try {
        _devicePreferences.dispose();
      } finally {
        await directory.delete(recursive: true);
      }
    }
  }
}

/// Whole-process endpoints in the already-running flutter_tester process.
/// Neither field is a Dart heap measurement or a phase-specific memory peak.
Map<String, int> observeAgentPerformanceMemory(Stopwatch protocolClock) {
  final observedAtUs = protocolClock.elapsedMicroseconds;
  final cost = Stopwatch()..start();
  final current = ProcessInfo.currentRss;
  final lifetimePeak = ProcessInfo.maxRss;
  cost.stop();
  return {
    'observedAtElapsedUs': observedAtUs,
    'rssBytes': current,
    'processLifetimePeakRssBytes': lifetimePeak,
    'readCostUs': cost.elapsedMicroseconds,
  };
}
