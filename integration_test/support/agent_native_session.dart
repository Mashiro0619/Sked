import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:sked/agent/attachments/attachment_storage.dart';
import 'package:sked/agent/connection/agent_credential_store.dart';
import 'package:sked/agent/conversations/conversation_models.dart';
import 'package:sked/agent/conversations/conversation_storage.dart';
import 'package:sked/agent/knowledge/knowledge_storage.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/backup/selective_restore_coordinator.dart';
import 'package:sked/controllers/app_lifecycle.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/agent_settings.dart';
import 'package:sked/models/application_ledger.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/app_scope.dart';
import 'package:sked/screens/app_home_screen.dart';
import 'package:sked/services/agenda_notification_service.dart';
import 'package:sked/services/app_backup_restore_journal.dart';
import 'package:sked/services/desktop_layout_preferences.dart';
import 'package:sked/services/developer_ui_preferences.dart';
import 'package:sked/services/device_preferences_store.dart';
import 'package:sked/services/import_export_service.dart';
import 'package:sked/services/school_site_service.dart';
import 'package:sked/services/school_site_store.dart';
import 'package:sked/services/secret_store.dart';
import 'package:sked/theme/app_theme.dart';
import 'package:sked/theme/sked_expressive_theme.dart';
import 'package:sked/widgets/desktop_window_host.dart';
import 'package:sked/widgets/material_ui_compatibility.dart';

import '../../test/support/agenda_notification_memory.dart';

const agentNativeLongId = 'native-long-history';
const agentNativeShortId = 'native-short-history';
const agentNativeMessageCount = 512;
const agentNativeInitialDraft = 'Long conversation initial draft';
const agentNativeShortDraft = 'Independent short conversation draft';
const agentNativeRequest = 'Reply once with a short reading confirmation.';
const agentNativeReply = 'The synthetic native reading check is complete.';

String agentNativeDigest(String source) =>
    sha256.convert(utf8.encode(source)).toString();

class AgentNativeConfig {
  const AgentNativeConfig({
    required this.name,
    required this.revision,
    required this.label,
    this.sourceNote = '',
  });

  final String name;
  final String revision;
  final String label;
  final String sourceNote;
  bool get accessible => name == 'accessible';
  double get textScale => accessible ? 2 : 1;
  Brightness get brightness => accessible ? Brightness.dark : Brightness.light;

  void validate() {
    if (!const {'baseline', 'accessible'}.contains(name)) {
      throw ArgumentError(
        'SKED_AGENT_NATIVE_CONFIG must be baseline or accessible.',
      );
    }
    if (!RegExp(r'^[0-9a-f]{40}$').hasMatch(revision)) {
      throw ArgumentError(
        'SKED_AGENT_NATIVE_REVISION must be a full source SHA.',
      );
    }
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$').hasMatch(label)) {
      throw ArgumentError(
        'SKED_AGENT_NATIVE_LABEL must be a safe filename label.',
      );
    }
  }

  Map<String, Object?> toJson() => {
    'name': name,
    'brightness': brightness.name,
    'textScale': textScale,
    'reduceMotion': accessible,
    'disableAnimations': false,
    'configurationScope': 'framework theme, TextScaler and motion scope',
  };
}

/// Installs no zone around runApp. This guard blocks dart:io HTTP operations in
/// this fresh native UI isolate, not platform networking or other processes.
class AgentNativeHttpGuard extends HttpOverrides {
  var attempts = 0;
  var clientsCreated = 0;
  var _installed = false;

  void install() {
    if (HttpOverrides.current != null) {
      throw StateError(
        'The native journey requires a fresh HTTP override owner.',
      );
    }
    HttpOverrides.global = this;
    _installed = true;
  }

  void restore() {
    if (!_installed) return;
    if (!identical(HttpOverrides.current, this)) {
      throw StateError('The native journey lost ownership of its HTTP guard.');
    }
    HttpOverrides.global = null;
    _installed = false;
  }

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    clientsCreated++;
    // Production connection diagnostics owns an idle HTTP client even when
    // this journey never opens diagnostics. Construction and close are safe.
    return _OfflineHttpClient(this);
  }
}

class _OfflineHttpClient implements HttpClient {
  _OfflineHttpClient(this.guard);
  final AgentNativeHttpGuard guard;
  @override
  void close({bool force = false}) {}
  @override
  dynamic noSuchMethod(Invocation invocation) {
    guard.attempts++;
    throw StateError(
      'Unexpected HTTP operation in the offline native journey: ${invocation.memberName}',
    );
  }
}

class _RejectingTransport extends http.BaseClient {
  var attempts = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    attempts++;
    throw StateError(
      'The native journey must not use provider HTTP transport.',
    );
  }
}

/// The production runtime owns this provider. Only its model event stream is
/// controlled; no AgentApplication, UI delegate or navigation callback is faked.
class AgentNativeProvider extends ProviderClient {
  AgentNativeProvider._(this._transport) : super(client: _transport);
  factory AgentNativeProvider() => AgentNativeProvider._(_RejectingTransport());

  final _RejectingTransport _transport;
  final started = Completer<void>();
  final closed = Completer<void>();
  final requests = <ProviderRequest>[];
  ProviderCancellationToken? cancellation;
  StreamController<ProviderEvent>? _events;
  Future<void>? _finish;
  var completedReplies = 0;
  var deltas = 0;

  @override
  Stream<ProviderEvent> stream(
    ProviderRequest request, {
    required String apiKey,
    ProviderCancellationToken? cancellation,
  }) {
    requests.add(request);
    if (requests.length != 1 ||
        request.model != 'native-ui-fixture' ||
        request.endpoint.host != 'native-ui.invalid' ||
        apiKey.isNotEmpty ||
        cancellation == null) {
      return Stream.error(
        StateError('Unexpected native journey model request.'),
      );
    }
    this.cancellation = cancellation;
    final events = _events = StreamController<ProviderEvent>();
    unawaited(
      cancellation.whenCancelled.then((_) {
        if (!events.isClosed) {
          events.addError(const ProviderException(ProviderError.cancelled));
          unawaited(_finish ??= events.close());
        }
      }),
    );
    started.complete();
    return events.stream;
  }

  void emitDelta() {
    final events = _events;
    if (events == null || events.isClosed || deltas != 0) {
      throw StateError(
        'The controlled stream is not ready for its single delta.',
      );
    }
    deltas++;
    events.add(const ProviderTextDelta(agentNativeReply));
  }

  Future<void> completeReply() {
    final events = _events;
    if (events == null || events.isClosed || deltas != 1) {
      throw StateError('The controlled stream is not ready for completion.');
    }
    completedReplies++;
    events.add(
      ProviderCompleted(
        ProviderResponse(
          text: agentNativeReply,
          toolCalls: const [],
          finishReason: 'stop',
        ),
      ),
    );
    return _finish ??= events.close();
  }

  Future<void> stop() async {
    final events = _events;
    if (events != null && !events.isClosed) cancellation?.cancel();
    if (events != null) await (_finish ??= events.close());
  }

  Map<String, Object?> toJson() => {
    'requests': requests.length,
    'deltas': deltas,
    'completedReplies': completedReplies,
    'cancelled': cancellation?.isCancelled ?? false,
    'transportAttempts': _transport.attempts,
    'closed': closed.isCompleted,
    'requestMessageCounts': [
      for (final request in requests) request.messages.length,
    ],
  };

  @override
  void close() {
    if (closed.isCompleted) return;
    super.close();
    _transport.close();
    closed.complete();
  }
}

/// Adds lifetime observation without changing the injected provider's requests,
/// events or cancellation token. Feature journeys can provide another client.
class _OwnedProvider implements ProviderClient {
  _OwnedProvider(this.client) {
    // Defer close errors to the explicit close-agent cleanup checkpoint.
    closed.future.ignore();
  }
  final ProviderClient client;
  final closed = Completer<void>();

  @override
  Future<ProviderResponse> collect(
    ProviderRequest request, {
    required String apiKey,
    ProviderCancellationToken? cancellation,
  }) => client.collect(request, apiKey: apiKey, cancellation: cancellation);

  @override
  Stream<ProviderEvent> stream(
    ProviderRequest request, {
    required String apiKey,
    ProviderCancellationToken? cancellation,
  }) => client.stream(request, apiKey: apiKey, cancellation: cancellation);

  @override
  void close() {
    if (closed.isCompleted) return;
    try {
      client.close();
      closed.complete();
    } catch (error, stack) {
      closed.completeError(error, stack);
    }
  }
}

class _MainStorage implements TimetableStorage {
  _MainStorage(this.source);
  String source;
  var loads = 0;
  var writes = 0;

  @override
  Future<StorageLoadResult> load() async {
    loads++;
    return StorageLoadResult(
      data: AppData.decodeStorageSnapshot(source),
      recoveryStatus: RecoveryStatus.none,
    );
  }

  @override
  Future<void> save(AppData data) async {
    writes++;
    source = data.encode();
  }

  @override
  Future<String?> filePath() async => 'memory://agent-native-main';
}

class _ChatStorage extends ConversationStorage {
  _ChatStorage(this.source) : super.base();
  String source;
  var loads = 0;
  var writes = 0;
  var revision = 0;

  @override
  Future<ConversationStorageLoad> load() async {
    loads++;
    return ConversationStorageLoad(source: source);
  }

  @override
  Future<void> save(String value, {required int revision}) async {
    final decoded = ConversationArchive.decode(value);
    if (decoded.revision != revision) {
      throw StateError(
        'Conversation save revision does not match its archive.',
      );
    }
    writes++;
    this.revision = revision;
    source = value;
  }
}

class _Secrets implements SecretStore {
  String value = '';
  @override
  Future<String> readCustomSchoolImportApiKey() async => value;
  @override
  Future<void> writeCustomSchoolImportApiKey(String value) async {
    this.value = value;
  }
}

class _Sites extends SchoolSiteStore {
  _Sites() : super.base();
  String source = '[]';
  @override
  Future<String?> load() async => source;
  @override
  Future<void> save(String source) async {
    this.source = source;
  }

  @override
  Future<String?> filePath() async => 'memory://agent-native-sites';
}

class _LegacyJournal extends AppBackupRestoreJournal {
  _LegacyJournal() : super.base();
  String? source;
  final artifacts = <String, Uint8List>{};
  @override
  String get pendingArtifactPath => 'memory://agent-native-journal';
  @override
  Future<String?> read() async => source;
  @override
  Future<void> write(String source) async {
    this.source = source;
  }

  @override
  Future<void> clear() async {
    source = null;
  }

  @override
  Future<String> preserveForRecovery(String source) async {
    final path = 'memory://agent-native-recovery-${artifacts.length}';
    artifacts[path] = Uint8List.fromList(utf8.encode(source));
    return path;
  }

  @override
  Future<List<String>> listRecoveryArtifacts() async => artifacts.keys.toList();
  @override
  Future<Uint8List?> readRecoveryArtifact(String artifactPath) async =>
      artifacts[artifactPath];
}

AppData _mainFixture() {
  const periods = PeriodTimeSet(
    id: 'native-periods',
    name: 'Native periods',
    periodTimes: [
      CoursePeriodTime(index: 1, startMinutes: 480, endMinutes: 540),
    ],
  );
  return const ImportExportService().normalizeAppData(
    AppData(
      activeMode: AppMode.general,
      localeCode: 'en',
      privacyPolicyAcceptedVersion: bundledPrivacyPolicyVersion,
      privacyPolicyAcceptedAtIso: '2026-09-07T00:00:00.000Z',
      applicationLedger: ApplicationLedger(
        generation: '7b9c71e1-3b4f-4a2c-9a20-3e93e378a912',
      ),
      agentSettings: const AgentSettings(
        enabled: true,
        permissionMode: AgentPermissionMode.full,
        endpoint: 'https://native-ui.invalid/v1',
        model: 'native-ui-fixture',
        models: [
          AgentModelConfig(
            id: 'native-ui-fixture',
            reasoningEfforts: [AgentReasoningEffort.medium],
            defaultReasoningEffort: AgentReasoningEffort.medium,
          ),
        ],
      ),
      studentMode: StudentModeData(
        activeTimetableId: 'native-table',
        periodTimeSets: const [periods],
        timetables: [
          TimetableData(
            id: 'native-table',
            config: TimetableConfig(
              name: 'Native timetable',
              startDate: DateTime(2026, 9, 7),
              totalWeeks: 18,
              periodTimeSetId: periods.id,
            ),
            courses: const [],
          ),
        ],
      ),
      generalMode: GeneralScheduleData(
        activeScheduleId: 'native-calendar',
        selectedDateIso: '2026-09-07',
        defaultView: generalViewDay,
        schedules: [
          GeneralSchedule(
            id: 'native-calendar',
            name: 'Native calendar',
            events: [
              GeneralEvent(
                id: 'native-event',
                calendarId: 'native-calendar',
                title: 'Synthetic reading session',
                startDateTimeIso: '2026-09-07T10:00:00.000',
                endDateTimeIso: '2026-09-07T11:00:00.000',
              ),
            ],
          ),
        ],
      ),
    ),
    localeCode: 'en',
  );
}

ConversationArchive _chatFixture() {
  final start = DateTime.utc(2026, 9, 7, 12);
  final messages = List.generate(agentNativeMessageCount, (index) {
    final marker = index.toString().padLeft(4, '0');
    return ConversationMessage(
      id: 'native-message-$marker',
      role: index.isEven ? ConversationRole.user : ConversationRole.assistant,
      text: index.isEven
          ? 'Native history $marker: keep the plan unchanged.'
          : '**Native history $marker**\n\n'
                'Read this stable Markdown example without changing the calendar.\n\n'
                '```dart\nconst slot = $index;\n```\n\n'
                'The following conversation remains independent.',
      createdAt: start.add(Duration(seconds: index)),
    );
  });
  final archive = ConversationArchive(
    selectedId: agentNativeLongId,
    conversations: [
      AgentConversation(
        id: agentNativeLongId,
        title: 'Native long history',
        createdAt: start,
        updatedAt: start.add(const Duration(minutes: 10)),
        mode: AgentPermissionMode.full,
        draft: agentNativeInitialDraft,
        messages: messages,
      ),
      AgentConversation(
        id: agentNativeShortId,
        title: 'Native short history',
        createdAt: start,
        updatedAt: start,
        mode: AgentPermissionMode.full,
        draft: agentNativeShortDraft,
        messages: [
          ConversationMessage(
            id: 'native-short-user',
            role: ConversationRole.user,
            text: 'A separate synthetic conversation.',
            createdAt: start,
          ),
          ConversationMessage(
            id: 'native-short-assistant',
            role: ConversationRole.assistant,
            text: 'Its draft stays independent.',
            createdAt: start.add(const Duration(seconds: 1)),
          ),
        ],
      ),
    ],
  );
  return ConversationArchive.decode(archive.encode());
}

/// Owns every persistence boundary explicitly, while retaining the production
/// codec, normal write scheduling, runtime and formal home-page composition.
class AgentNativeSession {
  AgentNativeSession({ProviderClient? provider})
    : provider = provider ?? AgentNativeProvider() {
    final fixture = _chatFixture();
    _chat = _ChatStorage(fixture.encode());
    _main = _MainStorage(_mainFixture().encode());
    initialMainDigest = agentNativeDigest(_main.source);
    initialArchiveDigest = agentNativeDigest(_chat.source);
    originalMessages = List.unmodifiable(fixture.conversations.first.messages);
    originalHistoryDigest = historyDigest(originalMessages);
    _ownedProvider = _OwnedProvider(this.provider);
    app = AppRuntime(
      storage: _main,
      systemLocaleCodeResolver: () => 'en',
      secretStore: _Secrets(),
      schoolSiteService: SchoolSiteService(store: _Sites()),
      backupRestoreJournal: _LegacyJournal(),
      devicePreferences: DevicePreferencesStore(
        layout: layout,
        developerUi: developerUi,
      ),
      workspaceMutationLock: (action) => action(),
      agentConversationStorage: _chat,
      agentAttachmentStorage: MemoryAttachmentStorage(),
      backupStagingStorage: MemoryAttachmentStorage(),
      selectiveRestoreJournal: MemorySelectiveRestoreJournal(),
      agentKnowledgeStorage: MemoryKnowledgeStorage(),
      agentCredentialStore: MemoryAgentCredentialStore(),
      agentProvider: _ownedProvider,
    );
  }

  final ProviderClient provider;
  late final _OwnedProvider _ownedProvider;
  final layout = DesktopLayoutPreferences.memory();
  final developerUi = DeveloperUiPreferences.memory(visible: false);
  final notifications = AgendaNotificationService(
    enabled: false,
    gateway: MemoryAgendaNotificationGateway(),
    runtimeStore: MemoryAgendaNotificationRuntimeStore(),
  );
  late final AppRuntime app;
  late final _MainStorage _main;
  late final _ChatStorage _chat;
  late final String initialMainDigest;
  late final String initialArchiveDigest;
  late final String originalHistoryDigest;
  late final List<ConversationMessage> originalMessages;
  Future<Map<String, Object?>>? _closing;

  int get conversationLoads => _chat.loads;
  String get mainSource => _main.source;
  String get chatSource => _chat.source;
  AgentNativeProvider get controlledProvider {
    final client = provider;
    if (client is! AgentNativeProvider) {
      throw StateError(
        'The core journey requires its single-stream controlled provider.',
      );
    }
    return client;
  }

  Map<String, Object?> providerReport() => provider is AgentNativeProvider
      ? (provider as AgentNativeProvider).toJson()
      : {
          'type': provider.runtimeType.toString(),
          'closed': _ownedProvider.closed.isCompleted,
        };

  static String historyDigest(Iterable<ConversationMessage> messages) =>
      agentNativeDigest(
        jsonEncode(messages.map((message) => message.toJson()).toList()),
      );

  Map<String, Object?> fixtureReport() => {
    'mainSha256': initialMainDigest,
    'archiveSha256': initialArchiveDigest,
    'longHistorySha256': originalHistoryDigest,
    'longMessageCount': originalMessages.length,
    'shortMessageCount': 2,
    'conversationCount': 2,
    'timetableCount': 1,
    'calendarCount': 1,
    'eventCount': 1,
    'storage': 'explicit synthetic in-memory owners; production codecs',
  };

  Map<String, Object?> storageReport() => {
    'mainLoads': _main.loads,
    'mainWrites': _main.writes,
    'conversationLoads': _chat.loads,
    'conversationWrites': _chat.writes,
    'conversationRevision': _chat.revision,
    'mainSha256': agentNativeDigest(_main.source),
    'archiveSha256': agentNativeDigest(_chat.source),
  };

  /// Called only after the native widgets have been unmounted. Every failed
  /// drain is retained; cleanup never replaces the primary journey failure.
  Future<Map<String, Object?>> close() => _closing ??= _close();

  Future<Map<String, Object?>> _close() async {
    final steps = <Map<String, Object?>>[];
    Future<void> step(String name, Future<void> Function() action) async {
      final result = <String, Object?>{'name': name, 'status': 'running'};
      steps.add(result);
      try {
        await action().timeout(const Duration(seconds: 15));
        result['status'] = 'complete';
      } catch (error, stack) {
        result.addAll({
          'status': 'failed',
          'error': '$error',
          'stack': '$stack',
        });
      }
    }

    await step('cancel-active-run', () async {
      app.agent.runtime.cancelAll();
      if (provider case final AgentNativeProvider client) await client.stop();
    });
    await step('quiesce', app.shutdown.quiesce);
    await step('dispose-runtime', () async => app.dispose());
    // AppRuntime already owns closeSelective + notifier disposal. Repeating
    // only the service close waits for staging without disposing it twice.
    await step('close-agent', () => _ownedProvider.closed.future);
    await step('close-backup-staging', app.backups.selective.close);
    await step('close-session', app.session.close);
    await step(
      'drain-main-writes',
      () => app.session.repository.waitForPendingWrites(propagateErrors: true),
    );
    await step('flush-layout', () async {
      if (!await layout.flush()) {
        throw StateError('Layout save was not confirmed.');
      }
    });
    await step('release-owned-preferences', () async {
      notifications.dispose();
      layout.dispose();
      developerUi.dispose();
    });
    return {
      'status': steps.every((step) => step['status'] == 'complete')
          ? 'complete'
          : 'failed',
      'steps': steps,
    };
  }
}

class AgentNativeApp extends StatefulWidget {
  const AgentNativeApp({
    super.key,
    required this.session,
    required this.config,
  });
  final AgentNativeSession session;
  final AgentNativeConfig config;
  @override
  State<AgentNativeApp> createState() => _AgentNativeAppState();
}

class _AgentNativeAppState extends State<AgentNativeApp> {
  final _modals = DesktopWindowModalObserver();
  @override
  void dispose() {
    _modals.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final config = widget.config;
    return SkedMotionPolicyScope(
      disableAnimations: false,
      reduceMotion: config.accessible,
      child: MultiProvider(
        providers: [
          ...AppScope.providersFor(session.app),
          ChangeNotifierProvider<DesktopLayoutPreferences>.value(
            value: session.layout,
          ),
          ChangeNotifierProvider<DeveloperUiPreferences>.value(
            value: session.developerUi,
          ),
          ChangeNotifierProvider<AgendaNotificationService>.value(
            value: session.notifications,
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          navigatorObservers: [_modals],
          locale: const Locale('en'),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildAppTheme(
            seedColor: const Color(defaultThemeSeedColorValue),
            brightness: config.brightness,
            themeColorMode: themeColorModeSingle,
            colorfulUiColorValues: const {},
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(config.textScale),
              disableAnimations: false,
            ),
            child: DesktopWindowHost(
              modalObserver: _modals,
              child: bridgeLegacyMaterialUi(context, child),
            ),
          ),
          home: const AppHomeScreen(),
        ),
      ),
    );
  }
}
