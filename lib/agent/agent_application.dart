import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../application/mutation_coordinator.dart';
import '../application/external_operation_coordinator.dart';
import '../application/operation_contracts.dart';
import '../application/resource_queries.dart';
import '../controllers/app_data_maintenance.dart';
import '../controllers/app_backup_controller.dart';
import '../controllers/app_persistence.dart';
import '../controllers/app_session.dart';
import '../controllers/school_import_secret_controller.dart';
import '../controllers/workspace_commands.dart';
import '../models/agent_settings.dart';
import '../models/app_data_commit.dart';
import '../services/secret_store.dart';
import '../services/school_site_service.dart';
import '../services/school_web_session_service.dart';
import 'connection/agent_connection_manager.dart';
import 'connection/agent_connection_diagnostics.dart';
import 'connection/agent_endpoint.dart';
import 'conversations/conversation_models.dart';
import 'knowledge/knowledge_models.dart';
import 'provider/provider.dart';
import 'imports/school_import_tool_adapter.dart';
import 'references/agent_composer_reference.dart';
import 'references/agent_composer_reference_search.dart';
import 'skills/shared_skill_loader.dart';
import 'tools/application_tool_host.dart';
import 'tools/platform_tool_adapters.dart';
import 'tools/workflow_tool_adapters.dart';
import 'tools/conversation_tool_adapters.dart';
import 'tools/agent_control_tool_adapters.dart';
import 'bridge/rust_agent_bootstrap.dart';
import 'bridge/rust_agent_business_host.dart';
import 'bridge/rust_agent_client.dart';
import 'bridge/rust_agent_main_undo.dart';
import 'bridge/rust_agent_operation_inspector.dart';
import 'bridge/rust_agent_ui_delegate.dart';
import 'bridge/rust_conversation_repository.dart';
import 'bridge/rust_conversation_attachments.dart';
import 'bridge/rust_knowledge_editor_controller.dart';
import 'bridge/rust_history_controller.dart';
import 'history/agent_history_controller.dart';
import 'bridge/rust_history_maintenance.dart';
import 'bridge/generated/api/contracts.dart' as native;

export 'connection/agent_credential_action.dart';

part 'agent_composer_references.dart';

enum AgentInitializationFailure {
  applicationStorage,
  conversationStorage,
  connectionStorage,
  unsupportedPlatform,
}

/// Owns the native Agent and the Dart business transactions for the application.
class AgentApplication extends ChangeNotifier {
  AgentApplication({
    required AppSession session,
    required AppPersistence persistence,
    required AppDataMaintenance maintenance,
    required SchoolImportSecretController legacySecrets,
    required SecretStore legacyStore,
    required VoidCallback publishViews,
    AgentRustClient? nativeClient,
    Directory? attachmentStagingDirectory,
    bool? supportedPlatform,
    AgentCredentialStore? credentialStore,
    ProviderClient? provider,
    bool generateConversationTitles = true,
    SchoolSiteService? schoolSites,
    AppBackupController? backups,
    WorkspaceCommands? workspaces,
  }) : _session = session,
       _persistence = persistence,
       _maintenance = maintenance,
       _publishViews = publishViews,
       _provider = provider ?? ProviderClient(),
       _injectedClient = nativeClient != null,
       _platformOverride = supportedPlatform {
    mutations = MutationCoordinator(
      session: session,
      settlePendingChanges: persistence.flushPendingUiStateSaves,
      dataSessionRevision: () => maintenance.writeSessionRevision,
      onCommitted: publishViews,
    );
    external = ExternalOperationCoordinator(
      session: session,
      settlePendingChanges: persistence.flushPendingUiStateSaves,
      dataSessionRevision: () => maintenance.writeSessionRevision,
      onCommitted: publishViews,
      fallbackGeneration: () => mutations.generation,
    );
    this.nativeClient =
        nativeClient ??
        AgentRustClient(
          initialize: () => openRustAgentCore(
            tools: businessHost.definitions,
            preamble: _preamble,
            generateTitles: generateConversationTitles,
          ),
        );
    conversations = RustConversationRepository(this.nativeClient);
    knowledge = RustKnowledgeEditorController(
      client: this.nativeClient,
      readRegisteredTools: () => _nativeToolNames,
      readDataGeneration: () => mutations.generation,
      isReferenceCurrent: _isKnowledgeReferenceCurrent,
      isAvailable: _knowledgeAvailable,
      validateMutation: _validateKnowledgeMutation,
    );
    binaryAttachments = RustConversationAttachments(
      client: this.nativeClient,
      readConversation: conversations.find,
      publishState: conversations.ingestState,
      stagingDirectory: attachmentStagingDirectory,
      resolveStagingDirectory: resolveAgentAttachmentStaging,
      isAvailable: _knowledgeAvailable,
    );
    connections = AgentConnectionManager(
      store: credentialStore,
      readSettings: () => settings,
      persistSettings: _saveSettings,
      readLegacySettings: () => session.committedData.aiApiSettings,
      legacyStore: legacyStore,
      waitForLegacyWrites: legacySecrets.waitForPendingWrites,
      retireLegacyKey: () => legacySecrets.persist(''),
    );
    tools = ApplicationToolHost(
      session: session,
      mutations: mutations,
      conversationForScope: (scope) => businessHost.conversationForScope(scope),
      environmentForScope: (scope) => businessHost.environmentForScope(scope),
      readSkillSnapshot: () async {
        await knowledge.initialize();
        return knowledge.captureSkillSnapshot();
      },
    );
    platformTools = registerPlatformTools(
      tools,
      external: external,
      schoolSites: schoolSites,
      schoolWebSession: SchoolWebSessionService.instance,
      schoolWebSessionSupported: platformSupported,
      connectionManager: connections,
    );
    registerSchoolImportTools(tools);
    workflowTools = registerWorkflowTools(
      tools,
      external: external,
      platformTools: platformTools,
      backups: backups,
      workspaces: workspaces,
      runMaintenance: runMaintenanceFromAgent,
    );
    runtime = RustAgentUiDelegate(
      client: this.nativeClient,
      readSettings: _effectiveSettings,
      readApiKey: connections.readKeyFor,
      readEnvironment: _readEnvironment,
      readMaintenance: () => _maintenance.isReserved || !_session.canWrite,
      validateComposerReferences: validateComposerReferences,
      onOpenSettings: () => onOpenSettings?.call(),
    );
    final undo = RustAgentMainUndo(session: session, mutations: mutations);
    historyMaintenance = RustHistoryMaintenance(
      maintenance: maintenance,
      persistence: persistence,
      session: session,
      mutations: mutations,
      external: external,
      client: this.nativeClient,
      onMaintenanceChanged: (_) {
        runtime.refreshSettings();
        knowledge.ownerChanged();
        _notify();
      },
    );
    history = RustHistoryController(
      conversations: conversations,
      runtime: runtime,
      maintenance: historyMaintenance,
    );
    businessHost = RustAgentBusinessHost(
      client: this.nativeClient,
      tools: tools,
      readEnvironment: (_) => _readEnvironment(),
      readOperation: RustAgentOperationInspector(
        session: session,
        mutations: mutations,
        external: external,
      ).read,
      beginHistory: historyMaintenance.begin,
      endHistory: historyMaintenance.end,
      prepareUndo: (request) =>
          historyMaintenance.runWithOwner(request, () => undo.prepare(request)),
      commitUndo: (request) =>
          historyMaintenance.runWithOwner(request, () => undo.commit(request)),
      onScopeSettled: (scope) {
        external.discardScope(scope);
        controlTools.discardScope(scope);
        _pruneHistory().ignore();
        if (_attachmentCleanupError) _scheduleAttachmentCollection();
      },
    );
    conversationTools = registerConversationTools(
      tools,
      external: external,
      repository: conversations,
      runtime: runtime,
      platformTools: platformTools,
    );
    controlTools = AgentControlToolAdapters(
      host: tools,
      external: external,
      connections: connections,
      configure: configureFromAgent,
      platformTools: platformTools,
      diagnostics: diagnostics,
      readKey: connections.readKeyFor,
    );
    _attachmentDataGeneration = mutations.generation;
    _commits = session.commits.listen(_committed);
    session.readiness.addListener(_readinessChanged);
    maintenance.addListener(_maintenanceChanged);
    conversations.addListener(_conversationsChanged);
  }

  final AppSession _session;
  final AppPersistence _persistence;
  final AppDataMaintenance _maintenance;
  final VoidCallback _publishViews;
  final ProviderClient _provider;
  final bool _injectedClient;
  final bool? _platformOverride;
  late final AgentRustClient nativeClient;
  late final RustConversationRepository conversations;
  late final RustConversationAttachments binaryAttachments;
  RustAttachmentReader get attachmentStore => binaryAttachments.repository;
  late final RustKnowledgeEditorController knowledge;
  late final RustAgentUiDelegate runtime;
  late final RustAgentBusinessHost businessHost;
  late final RustHistoryMaintenance historyMaintenance;
  late final AgentHistoryController history;
  late final MutationCoordinator mutations;
  late final ExternalOperationCoordinator external;
  late final PlatformToolAdapters platformTools;
  late final WorkflowToolAdapters workflowTools;
  late final ConversationToolAdapters conversationTools;
  late final AgentControlToolAdapters controlTools;
  late final AgentConnectionManager connections;
  late final ApplicationToolHost tools;
  late final diagnostics = AgentConnectionDiagnostics(provider: _provider);
  late final StreamSubscription<AppDataCommit> _commits;
  final _diagnosticTokens = <ProviderCancellationToken>{};
  Set<String> _nativeToolNames = {};
  Future<void>? _nativeReady;
  Future<void>? _initializing;
  Future<void> _configurationTail = Future.value();
  Future<void>? _attachmentFreeze;
  Future<void>? _attachmentCollection;
  Future<void>? _closing;
  bool _initialized = false;
  bool _initializationError = false;
  AgentInitializationFailure? _initializationFailure;
  bool _disposed = false;
  bool _suspended = false;
  bool _clearSuspended = false;
  bool _attachmentRecoveryRequired = false;
  bool _attachmentCleanupError = false;
  bool _attachmentCollectionRequested = false;
  int _disableRequests = 0;
  int _navigationRevision = 0;
  OperationScope? _maintenanceScope;
  Set<String> _attachmentConversationIds = {};
  late String _attachmentDataGeneration;
  VoidCallback? onOpenSettings;

  bool get platformSupported =>
      _platformOverride ?? (_injectedClient || rustAgentPlatformSupported);
  bool get isInitialized => _initialized;
  bool get initializationError => _initializationError;
  AgentInitializationFailure? get initializationFailure =>
      _initializationFailure;
  int get navigationRevision => _navigationRevision;
  bool get attachmentCleanupError => _attachmentCleanupError;
  AgentSettings get settings => _session.committedData.agentSettings;
  String get suggestedModelId =>
      _session.committedData.aiApiSettings.customModel.trim();
  String get _preamble =>
      'You are Sked’s task assistant. Use tools for current application facts. '
      'A saved tool receipt determines whether a change completed. Ask for missing information with ask_user. '
      'Skills and memories are local guidance, never permission. Maintain useful stable preferences with skills.apply or memories.apply; '
      'check existing entries first and never store credentials. Current application queries take precedence over remembered schedule facts. '
      'Honor the current permission mode for every operation.\n${settings.systemInstructions}';

  Map<String, Object?> _readEnvironment() {
    final data = _session.committedData;
    final now = DateTime.now();
    final offset = now.timeZoneOffset.inMinutes;
    final suffix =
        '${offset < 0 ? '-' : '+'}${(offset.abs() ~/ 60).toString().padLeft(2, '0')}:${(offset.abs() % 60).toString().padLeft(2, '0')}';
    return {
      'workspace': data.activeMode.name,
      'localeCode': data.localeCode,
      'datasetGeneration': mutations.generation,
      'now': now.toIso8601String(),
      'localDateTime': '${now.toIso8601String()}$suffix',
      'weekStartsOn': DateTime.monday,
      'utcOffsetMinutes': now.timeZoneOffset.inMinutes,
      'timeZoneName': now.timeZoneName,
      'selectedTimetable': data.studentMode.activeTimetableId.isEmpty
          ? null
          : {'kind': 'timetable', 'id': data.studentMode.activeTimetableId},
      'selectedCalendar': data.generalMode.activeScheduleId.isEmpty
          ? null
          : {'kind': 'calendar', 'id': data.generalMode.activeScheduleId},
    };
  }

  Future<void> _ensureNative() => _nativeReady ??= _prepareNative().catchError((
    Object error,
    StackTrace stack,
  ) {
    _nativeReady = null;
    Error.throwWithStackTrace(error, stack);
  });

  Future<void> _prepareNative() async {
    final core = await nativeClient.ensureInitialized();
    await core.dispatch(
      command: native.AgentCommand(
        kind: native.CommandKind.setTools,
        tools: businessHost.definitions,
      ),
    );
    await core.dispatch(
      command: native.AgentCommand(
        kind: native.CommandKind.setPreamble,
        text: _preamble,
      ),
    );
    _nativeToolNames = (await core.toolDefinitions())
        .map((tool) => tool.name)
        .toSet();
    await core.registerBuiltinSkills(
      records: await loadRustBuiltinSkills(_nativeToolNames),
    );
  }

  Future<T> runMaintenanceFromAgent<T>(
    OperationScope scope,
    Future<T> Function() action,
  ) async {
    scope.checkActive();
    if (_maintenanceScope != null) {
      throw const OperationProblem(
        OperationErrorCode.busy,
        'Agent maintenance is already active.',
      );
    }
    _maintenanceScope = scope;
    try {
      return await action();
    } finally {
      _maintenanceScope = null;
    }
  }

  bool _knowledgeAvailable() =>
      !_disposed &&
      !_suspended &&
      !_clearSuspended &&
      _session.isLoaded &&
      !_session.isLoading &&
      _session.canWrite &&
      !_maintenance.isReserved;

  bool _isKnowledgeReferenceCurrent(KnowledgeReference reference) {
    if (reference.generation != mutations.generation) return false;
    final kind = ResourceKind.values
        .where((kind) => kind.name == reference.kind)
        .firstOrNull;
    // Occurrences require a fresh query with a date window.
    if (kind == null || kind == ResourceKind.occurrence) return false;
    try {
      ResourceQueries(
        snapshot: _session.committedData,
        datasetGeneration: mutations.generation,
        snapshotRevision: _session.mutationEpoch,
      ).get(
        ResourceRef(kind: kind, id: reference.id, parentId: reference.parentId),
        fields: const {},
      );
      return true;
    } on ResourceQueryException {
      return false;
    }
  }

  void _validateKnowledgeMutation() {
    if (!_knowledgeAvailable()) {
      throw const KnowledgeException(
        KnowledgeError.unavailable,
        'Application maintenance prevents this knowledge change.',
      );
    }
    _session.ensureMutationAllowed();
  }

  void requestShowConversation() {
    if (_disposed || !settings.enabled) return;
    _navigationRevision++;
    _notify();
  }

  AgentSettings _effectiveSettings() => settings.copyWith(
    enabled:
        settings.enabled &&
        _initialized &&
        !_suspended &&
        !_clearSuspended &&
        !_disposed &&
        _disableRequests == 0 &&
        platformSupported,
  );

  Future<void> initialize() {
    if (_disposed || _suspended || _clearSuspended) {
      return Future.error(StateError('Agent is closed.'));
    }
    if (_initialized) return Future.value();
    return _initializing ??= _initialize().whenComplete(
      () => _initializing = null,
    );
  }

  Future<void> _initialize() async {
    _initializationError = false;
    _initializationFailure = null;
    var stage = AgentInitializationFailure.applicationStorage;
    try {
      if (!platformSupported) {
        stage = AgentInitializationFailure.unsupportedPlatform;
        throw UnsupportedError('Agent is unavailable on this platform.');
      }
      if (!_knowledgeAvailable() || _session.repository.isWriteStateUnknown) {
        throw StateError('Application storage is not ready.');
      }
      stage = AgentInitializationFailure.conversationStorage;
      await _ensureNative();
      await historyMaintenance.recoverBeforeWrites();
      await (await nativeClient.core).recoverOperations();
      await conversations.load();
      stage = AgentInitializationFailure.connectionStorage;
      await connections.initialize();
      if (_disposed || _suspended || _clearSuspended) return;
      _attachmentRecoveryRequired = false;
      await _resumeAttachmentsAfterMaintenance();
      _initialized = true;
      await _pruneHistory();
      _scheduleAttachmentCollection();
    } catch (_) {
      _initialized = false;
      _initializationError = true;
      _initializationFailure = stage;
      rethrow;
    } finally {
      runtime.refreshSettings();
      _notify();
    }
  }

  Future<void> recoverHistoryBeforeWrites() async {
    if (!platformSupported) return;
    await _ensureNative();
    await historyMaintenance.recoverBeforeWrites();
    await (await nativeClient.core).recoverOperations();
  }

  Future<void> prepareBackupRead() async {
    if (!platformSupported) return;
    if (!_knowledgeAvailable() || _session.repository.isWriteStateUnknown) {
      throw StateError('Application storage is not ready for backup.');
    }
    await _ensureNative();
    await _resumeAttachmentsAfterMaintenance();
  }

  Future<void> prepareNativeBackupRestore() async {
    if (!platformSupported) return;
    await _ensureNative();
    if (historyMaintenance.ownsMaintenance) {
      throw StateError('Complete history recovery before restoring a backup.');
    }
    await quiesce();
    conversations.setMaintenance(true);
    await knowledge.freezeAndDrain();
    await _freezeAttachments();
  }

  Future<void> refreshAfterNativeBackupRestore() async {
    if (!platformSupported || !nativeClient.isInitialized) return;
    conversations.invalidateAfterDataBoundary();
    if (_initialized) await conversations.load();
  }

  void resumeAfterNativeBackupRestore() {
    if (_disposed || _suspended || _clearSuspended) return;
    conversations.setMaintenance(false);
    knowledge.resume();
    _resumeAttachmentsAfterMaintenance().ignore();
    runtime.refreshSettings();
    _notify();
  }

  Future<void> completeSuccessfulDataRestore() async {
    if (_disposed) return;
    runtime.invalidateAfterDataBoundary();
    if (platformSupported && nativeClient.isInitialized) {
      await nativeClient.dispatch(
        const native.AgentCommand(kind: native.CommandKind.discardDrafts),
      );
    }
    conversations.invalidateAfterDataBoundary();
    binaryAttachments.invalidatePendingAfterDataBoundary();
    _attachmentDataGeneration = mutations.generation;
    _scheduleAttachmentCollection();
    _notify();
  }

  Future<void> setEnabled(bool enabled) {
    // Revocation affects existing scopes before this asynchronous write queues.
    if (!enabled) {
      _disableRequests++;
      runtime.refreshSettings();
      _stopNative(preserveHistoryOwner: false).ignore();
    }
    return _configureSerially(() async {
      if (enabled) await initialize();
      await _saveSettings(settings.copyWith(enabled: enabled));
    }).whenComplete(() {
      if (!enabled) _disableRequests--;
      runtime.refreshSettings();
    });
  }

  Future<void> configure(
    AgentSettings value, {
    AgentCredentialAction credentialAction = AgentCredentialAction.keep,
    String? rawKey,
    AgentSettings? expectedSettings,
  }) {
    final changesTransport =
        value.endpoint != settings.endpoint ||
        value.protocol != settings.protocol ||
        credentialAction != AgentCredentialAction.keep;
    if (changesTransport) {
      _disableRequests++;
      runtime.refreshSettings();
      _stopNative(preserveHistoryOwner: false).ignore();
    }
    return _configureSerially(() async {
      await initialize();
      _checkExpectedSettings(expectedSettings);
      await connections.save(
        value,
        credentialAction: credentialAction,
        rawKey: rawKey,
        expectedSettings: expectedSettings,
      );
    }, expectedSettings: expectedSettings).whenComplete(() {
      if (changesTransport) _disableRequests--;
      runtime.refreshSettings();
      _notify();
    });
  }

  /// The external coordinator has already accepted this concrete change. Do
  /// not wait for runs that may themselves be queued behind that coordinator.
  Future<void> configureFromAgent(
    OperationScope scope,
    AgentSettings value, {
    required AgentCredentialAction credentialAction,
    String? rawKey,
  }) {
    scope.checkActive();
    return runMaintenanceFromAgent(scope, () async {
      await configure(
        value,
        credentialAction: credentialAction,
        rawKey: rawKey,
      );
      final conversationId = businessHost.conversationForScope(scope)?.id;
      if (conversationId != null && nativeClient.isInitialized) {
        nativeClient
            .dispatch(
              native.AgentCommand(
                kind: native.CommandKind.stop,
                conversationId: conversationId,
              ),
            )
            .ignore();
      }
    });
  }

  Future<AgentConnectionProbeResult> probeConnection({
    bool allowInsecureHttp = false,
    ProviderCancellationToken? cancellation,
  }) => _diagnoseConnection(
    (snapshot, key, token) => diagnostics.probe(
      snapshot,
      apiKey: key,
      allowInsecureHttp: allowInsecureHttp,
      cancellation: token,
    ),
    cancellation,
  );

  Future<AgentModelCatalog> listConnectionModels({
    bool allowInsecureHttp = false,
    ProviderCancellationToken? cancellation,
  }) => _diagnoseConnection(
    (snapshot, key, token) => diagnostics.listModels(
      snapshot,
      apiKey: key,
      allowInsecureHttp: allowInsecureHttp,
      cancellation: token,
    ),
    cancellation,
  );

  Future<T> _diagnoseConnection<T>(
    Future<T> Function(
      AgentSettings snapshot,
      String key,
      ProviderCancellationToken token,
    )
    action,
    ProviderCancellationToken? cancellation,
  ) async {
    await initialize();
    final snapshot = settings;
    final key = await connections.readKeyFor(snapshot);
    if (_disposed ||
        _suspended ||
        _maintenance.isReserved ||
        snapshot != settings) {
      throw const AgentConnectionException(
        AgentConnectionErrorCode.configurationChanged,
      );
    }
    final token = cancellation ?? ProviderCancellationToken();
    _diagnosticTokens.add(token);
    try {
      return await action(
        snapshot.copyWith(
          endpoint: resolveConfiguredAgentEndpoint(snapshot).toString(),
        ),
        key,
        token,
      );
    } finally {
      _diagnosticTokens.remove(token);
    }
  }

  void _checkExpectedSettings(AgentSettings? expectedSettings) {
    if (expectedSettings != null && settings != expectedSettings) {
      throw const AgentConnectionException(
        AgentConnectionErrorCode.configurationChanged,
      );
    }
  }

  Future<void> _configureSerially(
    Future<void> Function() action, {
    AgentSettings? expectedSettings,
  }) {
    final result = _configurationTail.then((_) {
      if (_disposed || _suspended || _clearSuspended) {
        throw StateError('Agent is closed.');
      }
      _session.ensureMutationAllowed();
      _checkExpectedSettings(expectedSettings);
      return action();
    });
    _configurationTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  /// Preferences apply to future runs; a running request keeps its snapshot.
  Future<void> configurePreferences(
    AgentSettings value, {
    AgentSettings? expectedSettings,
  }) => _configureSerially(() async {
    value.validate();
    await _saveSettings(
      settings.copyWith(
        systemInstructions: value.systemInstructions,
        historyRetentionDays: value.historyRetentionDays,
      ),
      expectedSettings: expectedSettings,
    );
  }, expectedSettings: expectedSettings);

  Future<void> _saveSettings(
    AgentSettings value, {
    AgentSettings? expectedSettings,
  }) async {
    if (_disposed) throw StateError('Agent is closed.');
    _checkExpectedSettings(expectedSettings);
    final baseline = mutationDigest(settings.toJson());
    await _persistence.flushPendingUiStateSaves();
    await _session.repository.waitForPendingWrites(propagateErrors: true);
    _checkExpectedSettings(expectedSettings);
    if (mutationDigest(settings.toJson()) != baseline) {
      throw const AgentConnectionException(
        AgentConnectionErrorCode.configurationChanged,
      );
    }
    final epoch = _session.mutationEpoch;
    await _session.commitMutation(
      (current) => current.copyWith(agentSettings: value),
      expectedEpoch: epoch,
      dataSessionRevision: _maintenance.writeSessionRevision,
    );
    runtime.refreshSettings();
    _publishViews();
    _notify();
  }

  Future<void> _pruneHistory() async {
    if (!_initialized ||
        _disposed ||
        _suspended ||
        _clearSuspended ||
        !conversations.canWrite ||
        settings.historyRetentionDays == 0) {
      return;
    }
    await conversations.pruneHistory(days: settings.historyRetentionDays);
  }

  Future<void> recoverConversations() async {
    if (!_knowledgeAvailable()) {
      throw StateError('Agent storage cannot be recovered during maintenance.');
    }
    _disableRequests++;
    runtime.refreshSettings();
    try {
      await quiesce();
      await (await nativeClient.core).recoverOperations();
      conversations.invalidateAfterDataBoundary();
      await conversations.load();
      await knowledge.initialize(reload: true);
      binaryAttachments.invalidatePendingAfterDataBoundary();
      _attachmentRecoveryRequired = false;
      await _resumeAttachmentsAfterMaintenance();
      _initializationError = false;
      _initializationFailure = null;
      _scheduleAttachmentCollection();
    } finally {
      _disableRequests--;
      runtime.refreshSettings();
      _notify();
    }
  }

  Future<void> prepareDataClear() async {
    _clearSuspended = true;
    runtime.refreshSettings();
    await quiesce();
    conversations.setMaintenance(true);
    await knowledge.freezeAndDrain();
    await _freezeAttachments();
    if (platformSupported) {
      await nativeClient.suspendForDataClear(
        conversationId: _maintenanceScope == null
            ? null
            : businessHost.conversationForScope(_maintenanceScope!)?.id,
      );
      _nativeReady = null;
    }
  }

  void resumeAfterFailedDataClear() {
    _clearSuspended = false;
    _initialized = false;
    nativeClient.resumeAfterFailedDataClear();
    knowledge.invalidateAfterDataBoundary();
    runtime.invalidateAfterDataBoundary();
    _attachmentRecoveryRequired = true;
    conversations.invalidateAfterDataBoundary();
    conversations.setMaintenance(false);
    knowledge.resume();
    binaryAttachments.invalidatePendingAfterDataBoundary();
    runtime.refreshSettings();
    _notify();
  }

  void _committed(AppDataCommit commit) {
    if (_disposed) return;
    final generation = mutations.generation;
    if (generation != _attachmentDataGeneration) {
      _attachmentDataGeneration = generation;
      if (!_maintenance.isReserved) {
        binaryAttachments.invalidatePendingAfterDataBoundary();
      }
    }
    runtime.refreshSettings();
    if (nativeClient.isInitialized) {
      nativeClient
          .dispatch(
            native.AgentCommand(
              kind: native.CommandKind.setPreamble,
              text: _preamble,
            ),
          )
          .ignore();
    }
    _pruneHistory().ignore();
    _notify();
  }

  void _readinessChanged() {
    if (!_disposed) {
      runtime.refreshSettings();
      knowledge.ownerChanged();
      _notify();
    }
  }

  void _maintenanceChanged() {
    if (_maintenance.isReserved) {
      conversations.setMaintenance(true);
      if (!historyMaintenance.ownsMaintenance) {
        _stopNative().ignore();
        mutations.invalidate();
        external.invalidate();
      }
      _freezeAttachments().ignore();
    } else if (!_suspended && !_clearSuspended) {
      conversations.setMaintenance(false);
      knowledge.resume();
      _resumeAttachmentsAfterMaintenance().ignore();
    }
    knowledge.ownerChanged();
    runtime.refreshSettings();
    _notify();
  }

  Future<void> _stopNative({bool preserveHistoryOwner = true}) async {
    if (!nativeClient.isInitialized) return;
    final except = _maintenanceScope == null
        ? (preserveHistoryOwner ? historyMaintenance.ownerConversationId : null)
        : businessHost.conversationForScope(_maintenanceScope!)?.id;
    await nativeClient.dispatch(
      native.AgentCommand(
        kind: native.CommandKind.quiesce,
        conversationId: except,
      ),
    );
  }

  Future<void> quiesce() async {
    for (final token in _diagnosticTokens) {
      token.cancel();
    }
    await _stopNative();
    await _configurationTail;
    await mutations.waitForPendingWrites();
    if (_maintenanceScope == null) await external.waitForPendingWrites();
    if (_maintenanceScope == null) {
      await conversationTools.waitForPendingOperations();
    }
    await connections.waitForPendingWrites();
    await conversations.waitForPendingWrites();
    await knowledge.waitForPendingOperations();
    await _attachmentCollection;
    if (_maintenance.isReserved || _suspended || _clearSuspended) {
      await _freezeAttachments();
    } else {
      await binaryAttachments.waitForPendingOperations();
    }
  }

  void freeze({bool drainAcceptedRuns = false}) {
    _suspended = true;
    for (final token in _diagnosticTokens) {
      token.cancel();
    }
    _stopNative().ignore();
    runtime.refreshSettings();
    mutations.invalidate();
    external.invalidate();
    connections.freeze();
    conversations.setMaintenance(true);
    knowledge.freezeAndDrain().ignore();
    _freezeAttachments().ignore();
  }

  Future<void> _freezeAttachments() =>
      _attachmentFreeze ??= binaryAttachments.freezeAndDrain();
  Future<void> _resumeAttachmentsAfterMaintenance() async {
    await _attachmentFreeze;
    if (_disposed ||
        _suspended ||
        _clearSuspended ||
        _maintenance.isReserved ||
        _attachmentRecoveryRequired) {
      return;
    }
    _attachmentFreeze = null;
    binaryAttachments.resume();
    if (_attachmentCollectionRequested) _scheduleAttachmentCollection();
  }

  void _conversationsChanged() {
    if (!conversations.isLoaded) return;
    final ids = conversations.ownedConversations.map((item) => item.id).toSet();
    final removed = _attachmentConversationIds.any((id) => !ids.contains(id));
    _attachmentConversationIds = ids;
    if (removed) _scheduleAttachmentCollection();
  }

  bool get _canCollectAttachments =>
      nativeClient.isInitialized &&
      !_disposed &&
      !_suspended &&
      !_clearSuspended &&
      !_maintenance.isReserved &&
      !_attachmentRecoveryRequired &&
      _attachmentFreeze == null;
  void _scheduleAttachmentCollection() {
    if (_disposed) return;
    _attachmentCollectionRequested = true;
    if (!_canCollectAttachments || _attachmentCollection != null) return;
    _attachmentCollection = _collectAttachments().whenComplete(() {
      _attachmentCollection = null;
      if (_attachmentCollectionRequested && _canCollectAttachments) {
        _scheduleAttachmentCollection();
      }
    });
  }

  Future<void> _collectAttachments() async {
    while (_attachmentCollectionRequested && _canCollectAttachments) {
      _attachmentCollectionRequested = false;
      try {
        await binaryAttachments.collectGarbage();
        _attachmentCleanupError = false;
      } catch (_) {
        _attachmentCleanupError = true;
      }
    }
    _notify();
  }

  Future<void> close() => _closing ??= _close();
  Future<void> _close() async {
    if (nativeClient.isInitialized && !_clearSuspended) {
      await nativeClient.dispatch(
        const native.AgentCommand(kind: native.CommandKind.quiesce),
      );
    }
    await quiesce();
    await historyMaintenance.close();
    await nativeClient.shutdown();
    await businessHost.dispose();
    await runtime.dispose();
    await binaryAttachments.close();
    binaryAttachments.dispose();
    conversations.dispose();
    knowledge.dispose();
    tools.dispose();
    controlTools.dispose();
    diagnostics.close();
    _provider.close();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    freeze();
    _disposed = true;
    _session.readiness.removeListener(_readinessChanged);
    _maintenance.removeListener(_maintenanceChanged);
    conversations.removeListener(_conversationsChanged);
    unawaited(_commits.cancel());
    close().ignore();
    super.dispose();
  }
}
