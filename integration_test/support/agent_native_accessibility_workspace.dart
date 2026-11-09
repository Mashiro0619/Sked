import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:sked/agent/bridge/conversation_projection.dart';
import 'package:sked/agent/bridge/generated/api/contracts.dart' as native;
import 'package:sked/agent/bridge/generated/api/models.dart' as view;
import 'package:sked/agent/conversations/conversation_models.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/backup/selective_backup_agent_store.dart';
import 'package:sked/controllers/app_lifecycle.dart';
import 'package:sked/data/timetable_storage_io.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/agent_settings.dart';
import 'package:sked/models/application_ledger.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/app_scope.dart';
import 'package:sked/screens/app_home_screen.dart';
import 'package:sked/services/agenda_notification_service.dart';
import 'package:sked/services/desktop_layout_preferences.dart';
import 'package:sked/services/developer_ui_preferences.dart';
import 'package:sked/services/import_export_service.dart';
import 'package:sked/theme/app_theme.dart';
import 'package:sked/theme/sked_expressive_theme.dart';
import 'package:sked/widgets/desktop_window_host.dart';
import 'package:sked/widgets/material_ui_compatibility.dart';

import '../../test/support/agenda_notification_memory.dart';
import 'agent_rust_offline_workspace.dart';

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

/// Observations come from the generated native event stream and stored messages.
class NativeAccessibilityObservation {
  NativeAccessibilityObservation(this.workspace, this.name) {
    _subscription = workspace.client.events.listen((event) {
      final snapshot = event.snapshot;
      if (snapshot != null &&
          snapshot.runs.isNotEmpty &&
          snapshot.conversation.id != agentNativeLongId &&
          snapshot.conversation.id != agentNativeShortId) {
        _snapshot = snapshot;
      }
    });
  }
  final OfflineAgentWorkspace workspace;
  final String name;
  late final StreamSubscription<native.AgentEvent> _subscription;
  view.ViewConversationSnapshot? _snapshot;
  bool closed = false;
  int get requests =>
      _snapshot?.runs.fold<int>(
        0,
        (count, run) => count + run.requests.length,
      ) ??
      0;
  List<String> get tools => [
    for (final message in _snapshot?.messages ?? const <view.ViewMessage>[])
      for (final call in message.toolCalls) call.name,
  ];
  Map<String, dynamic>? get result {
    if (requests < 3) return null;
    final message = _snapshot?.messages
        .where((message) => message.toolCallId == 'native-msaa-$name-2')
        .lastOrNull;
    return message == null
        ? null
        : (jsonDecode(message.text) as Map).cast<String, dynamic>();
  }

  Map<String, Object?> toJson() => {
    'requests': requests,
    'requestedTools': tools,
    'closed': closed,
    'modelTransport': 'native offline scripted transport',
    'result': result,
  };
  Future<void> close() async {
    if (closed) return;
    closed = true;
    await _subscription.cancel();
  }
}

/// Native stores and the production application assembly are confined to F:.
class AgentNativeSession {
  AgentNativeSession._(this.directory, this.workspace, this.provider);
  final Directory directory;
  final OfflineAgentWorkspace workspace;
  final NativeAccessibilityObservation provider;
  AppRuntime get app => workspace.app;
  DesktopLayoutPreferences get layout => app.devicePreferences.layout;
  DeveloperUiPreferences get developerUi => app.devicePreferences.developerUi;
  final notifications = AgendaNotificationService(
    enabled: false,
    gateway: MemoryAgendaNotificationGateway(),
    runtimeStore: MemoryAgendaNotificationRuntimeStore(),
  );
  late final String _mainPath;
  late final String initialMainDigest;
  late final String originalHistoryDigest;
  late final List<ConversationMessage> originalMessages;
  Map<String, Object?>? _closedStorageReport;
  Future<Map<String, Object?>>? _closing;

  static Future<AgentNativeSession> create({
    required String name,
    required List<native.OfflineModelReply> replies,
  }) async {
    final temporary = Directory.systemTemp;
    if (Platform.isWindows && !temporary.path.toLowerCase().startsWith('f:')) {
      throw StateError('Native accessibility temporary data must use F:.');
    }
    final directory = await temporary.createTemp(
      'sked-agent-native-accessibility-',
    );
    final workspace = OfflineAgentWorkspace(directory);
    await workspace.open(
      seed: _mainFixture(),
      replies: replies,
      initializeAgent: false,
    );
    final observation = NativeAccessibilityObservation(workspace, name);
    final session = AgentNativeSession._(directory, workspace, observation);
    session._mainPath = await IoTimetableStorage(layout: workspace.layout)
        .filePath();
    session.initialMainDigest = agentNativeDigest(session.mainSource);
    final start = DateTime.utc(2026, 9, 7, 12).millisecondsSinceEpoch;
    Map<String, Object?> message(int index, {bool short = false}) {
      final marker = index.toString().padLeft(4, '0');
      return {
        'id': short ? 'native-short-$index' : 'native-message-$marker',
        'role': index.isEven ? 'user' : 'assistant',
        'text': short
            ? (index == 0
                  ? 'A separate synthetic conversation.'
                  : 'Its draft stays independent.')
            : index.isEven
            ? 'Native history $marker: keep the plan unchanged.'
            : '**Native history $marker**\n\nRead this stable Markdown example without changing the calendar.\n\n'
                  '```dart\nconst slot = $index;\n```\n\nThe following conversation remains independent.',
        'createdAt': start + index * 1000,
      };
    }

    await NativeAgentBackupStore(workspace.client).restore({
      'conversations': [
        {
          'conversation': {
            'id': agentNativeLongId,
            'title': 'Native long history',
            'createdAt': start,
            'updatedAt': start + 600000,
          },
          'messages': List.generate(
            agentNativeMessageCount,
            (index) => message(index),
          ),
        },
        {
          'conversation': {
            'id': agentNativeShortId,
            'title': 'Native short history',
            'createdAt': start,
            'updatedAt': start,
          },
          'messages': List.generate(2, (index) => message(index, short: true)),
        },
      ],
      'knowledge': <Object?>[],
      'attachments': <Object?>[],
    }, 'native-accessibility-seed');
    final repository = workspace.app.agent.conversations;
    await repository.load();
    await repository.updateDraftText(
      agentNativeLongId,
      agentNativeInitialDraft,
    );
    await repository.updateDraftText(agentNativeShortId, agentNativeShortDraft);
    await repository.select(agentNativeLongId);
    session.originalMessages = (await repository.read(agentNativeLongId))
        .messages;
    session.originalHistoryDigest = historyDigest(session.originalMessages);
    return session;
  }

  String get mainSource => File(_mainPath).readAsStringSync();
  Future<
    ({AgentConversation conversation, view.ViewConversationSnapshot snapshot})
  >
  readStoredConversation(String id) async {
    final snapshot = (await workspace.client.query(
      native.AgentQuery(
        kind: native.QueryKind.readConversation,
        conversationId: id,
      ),
    )).snapshot!;
    return (conversation: conversationFromRust(snapshot), snapshot: snapshot);
  }

  static String historyDigest(Iterable<ConversationMessage> messages) =>
      agentNativeDigest(
        jsonEncode(messages.map((message) => message.toJson()).toList()),
      );
  Map<String, Object?> fixtureReport() => {
    'mainSha256': initialMainDigest,
    'longHistorySha256': originalHistoryDigest,
    'longMessageCount': originalMessages.length,
    'shortMessageCount': 2,
    'conversationCount': 2,
    'timetableCount': 1,
    'calendarCount': 1,
    'eventCount': 1,
    'storage': 'real AppRuntime, native JSONL/SQLite and F: business files',
  };
  Future<Map<String, Object?>> storageReport() async =>
      _closedStorageReport ??
      {
        'backend': 'native-jsonl-sqlite',
        'mainSha256': agentNativeDigest(mainSource),
        'archiveSha256': agentNativeDigest(
          jsonEncode(
            await NativeAgentBackupStore(workspace.client).exportParts(),
          ),
        ),
      };
  Future<Map<String, Object?>> close() => _closing ??= _close();
  Future<Map<String, Object?>> _close() async {
    _closedStorageReport = await storageReport();
    await workspace.close();
    final nativeCoreClosed = !workspace.client.isInitialized;
    final businessSessionClosed = app.session.isClosed;
    _closedStorageReport = {
      ..._closedStorageReport!,
      'mainSha256': agentNativeDigest(mainSource),
    };
    await provider.close();
    notifications.dispose();
    await directory.delete(recursive: true);
    return {
      'status': 'complete',
      'nativeCoreClosed': nativeCoreClosed,
      'businessSessionClosed': businessSessionClosed,
      'providerClosed': provider.closed,
      'temporaryDataRemoved': !await directory.exists(),
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
