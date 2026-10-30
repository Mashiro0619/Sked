import 'dart:async';

import 'package:flutter/foundation.dart';

import '../application/mutation_coordinator.dart';
import '../application/external_operation_coordinator.dart';
import '../application/operation_contracts.dart';
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
import 'conversations/conversation_repository.dart';
import 'provider/provider.dart';
import 'imports/school_import_tool_adapter.dart';
import 'runtime/agent_runtime_controller.dart';
import 'tools/application_tool_host.dart';
import 'tools/platform_tool_adapters.dart';
import 'tools/workflow_tool_adapters.dart';
import 'tools/conversation_tool_adapters.dart';
import 'tools/agent_control_tool_adapters.dart';

export 'connection/agent_credential_action.dart';

/// One application-owned Agent. Views share its conversations and lifetime.
/// Initialization errors here do not turn a healthy main archive read-only.
class AgentApplication extends ChangeNotifier {
  AgentApplication({
    required AppSession session,
    required AppPersistence persistence,
    required AppDataMaintenance maintenance,
    required SchoolImportSecretController legacySecrets,
    required SecretStore legacyStore,
    required VoidCallback publishViews,
    ConversationStorage? conversationStorage,
    AgentCredentialStore? credentialStore,
    ProviderClient? provider,
    SchoolSiteService? schoolSites,
    AppBackupController? backups,
    WorkspaceCommands? workspaces,
  }) : _session = session,
       _persistence = persistence,
       _maintenance = maintenance,
       _publishViews = publishViews,
       _provider = provider ?? ProviderClient(),
       conversations = ConversationRepository(storage: conversationStorage) {
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
      conversationForScope: (scope) => runtime.conversationForScope(scope),
    );
    platformTools = registerPlatformTools(
      tools,
      external: external,
      schoolSites: schoolSites,
      schoolWebSession: SchoolWebSessionService.instance,
      schoolWebSessionSupported:
          !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.macOS ||
              defaultTargetPlatform == TargetPlatform.windows),
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
    runtime = AgentRuntimeController(
      repository: conversations,
      provider: _provider,
      readSettings: _effectiveSettings,
      readApiKey: connections.readKeyFor,
      readTools: tools.toolsFor,
      executeTool: tools.execute,
      readOperationReceipt: (toolName, operationId) async {
        final receipt = toolName == 'mutation.commit'
            ? mutations.status(operationId)
            : external.status(operationId);
        return receipt?.result ??
            {'status': 'notRecorded', 'operationId': operationId};
      },
      onOpenSettings: () => onOpenSettings?.call(),
      readMaintenance: () => maintenance.isReserved || !_session.canWrite,
      onRunSettled: (scope) {
        tools.finishScope(scope);
        external.discardScope(scope);
        controlTools.discardScope(scope);
        _pruneHistory().ignore();
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
    _commits = session.commits.listen(_committed);
    session.readiness.addListener(_readinessChanged);
    maintenance.addListener(_maintenanceChanged);
  }

  final AppSession _session;
  final AppPersistence _persistence;
  final AppDataMaintenance _maintenance;
  final VoidCallback _publishViews;
  final ProviderClient _provider;
  late final diagnostics = AgentConnectionDiagnostics(provider: _provider);
  final _diagnosticTokens = <ProviderCancellationToken>{};
  final ConversationRepository conversations;
  late final MutationCoordinator mutations;
  late final ExternalOperationCoordinator external;
  late final PlatformToolAdapters platformTools;
  late final WorkflowToolAdapters workflowTools;
  late final ConversationToolAdapters conversationTools;
  late final AgentControlToolAdapters controlTools;
  late final AgentConnectionManager connections;
  late final ApplicationToolHost tools;
  late final AgentRuntimeController runtime;
  late final StreamSubscription<AppDataCommit> _commits;
  VoidCallback? onOpenSettings;
  Future<void>? _initializing;
  Future<void> _configurationTail = Future.value();
  bool _initialized = false;
  bool _initializationError = false;
  bool _disposed = false;
  bool _suspended = false;
  bool _clearSuspended = false;
  int _disableRequests = 0;
  int _navigationRevision = 0;
  OperationScope? _maintenanceScope;

  /// An accepted maintenance effect may drain all other work without waiting
  /// for the run that is itself waiting for that effect to finish.
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

  AgentSettings get settings => _session.committedData.agentSettings;
  bool get isInitialized => _initialized;
  bool get initializationError => _initializationError;
  int get navigationRevision => _navigationRevision;

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
        _disableRequests == 0,
  );

  /// The normal shell loads AppData first. Dormant, never-configured Agents do
  /// no side-store IO until their feature or settings page is opened.
  Future<void> initialize() {
    if (_disposed || _suspended || _clearSuspended) {
      return Future.error(StateError('Agent is closed.'));
    }
    if (_initialized) return Future.value();
    final existing = _initializing;
    if (existing != null) return existing;
    final operation = _initialize();
    _initializing = operation;
    operation.whenComplete(() {
      if (identical(_initializing, operation)) _initializing = null;
    }).ignore();
    return operation;
  }

  Future<void> _initialize() async {
    _initializationError = false;
    try {
      if (!_session.isLoaded ||
          _session.isLoading ||
          !_session.canWrite ||
          _session.repository.isWriteStateUnknown ||
          _maintenance.isReserved) {
        throw StateError('Application storage is not ready.');
      }
      if (!conversations.isLoaded) await conversations.load();
      await connections.initialize();
      if (_disposed || _suspended) return;
      _initialized = true;
      await _pruneHistory();
    } catch (_) {
      _initializationError = true;
      rethrow;
    } finally {
      if (!_disposed) {
        runtime.refreshSettings();
        notifyListeners();
      }
    }
  }

  Future<void> setEnabled(bool enabled) {
    // Revocation affects existing scopes before this asynchronous write queues.
    if (!enabled) {
      _disableRequests++;
      runtime.refreshSettings();
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
  }) {
    _disableRequests++;
    runtime.refreshSettings();
    return _configureSerially(() async {
      await initialize();
      await connections.save(
        value,
        credentialAction: credentialAction,
        rawKey: rawKey,
      );
    }).whenComplete(() {
      _disableRequests--;
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
    return configure(value, credentialAction: credentialAction, rawKey: rawKey);
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
        snapshot.copyWith(endpoint: resolveAgentEndpoint(snapshot).toString()),
        key,
        token,
      );
    } finally {
      _diagnosticTokens.remove(token);
    }
  }

  Future<void> _configureSerially(Future<void> Function() action) {
    final result = _configurationTail.then((_) {
      if (_disposed || _suspended || _clearSuspended) {
        throw StateError('Agent is closed.');
      }
      _session.ensureMutationAllowed();
      return action();
    });
    _configurationTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  /// Preferences apply to future runs; a running request keeps its snapshot.
  Future<void> configurePreferences(AgentSettings value) =>
      _configureSerially(() async {
        value.validate();
        await _saveSettings(
          settings.copyWith(
            systemInstructions: value.systemInstructions,
            maxModelRounds: value.maxModelRounds,
            maxToolCalls: value.maxToolCalls,
            maxTotalTokens: value.maxTotalTokens,
            historyRetentionDays: value.historyRetentionDays,
          ),
        );
      });

  Future<void> _pruneHistory() async {
    if (!_initialized ||
        _disposed ||
        _suspended ||
        settings.historyRetentionDays == 0 ||
        !conversations.canWrite) {
      return;
    }
    await conversations.pruneHistory(
      days: settings.historyRetentionDays,
      canRemove: (id) =>
          !runtime.state.value.runFor(id).isActive &&
          runtime.pendingInputCount(id) == 0,
    );
  }

  Future<void> recoverConversations() async {
    if (_disposed || _suspended || _clearSuspended || _maintenance.isReserved) {
      throw StateError('Agent storage cannot be recovered during maintenance.');
    }
    _disableRequests++;
    runtime.refreshSettings();
    try {
      await quiesce();
      await conversations.load();
      _initializationError = false;
    } finally {
      _disableRequests--;
      runtime.refreshSettings();
      _notify();
    }
  }

  Future<void> prepareDataClear() async {
    _clearSuspended = true;
    runtime.cancelAll();
    conversations.freeze();
    await conversations.waitForPendingWrites();
    runtime.refreshSettings();
  }

  void resumeAfterFailedDataClear() {
    _clearSuspended = false;
    conversations.resumeAfterFailedDataClear();
    runtime.refreshSettings();
    _notify();
  }

  Future<void> _saveSettings(AgentSettings value) async {
    if (_disposed) throw StateError('Agent is closed.');
    final baseline = mutationDigest(settings.toJson());
    await _persistence.flushPendingUiStateSaves();
    await _session.repository.waitForPendingWrites(propagateErrors: true);
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

  void _committed(AppDataCommit commit) {
    if (_disposed) return;
    runtime.refreshSettings();
    _pruneHistory().ignore();
    _notify();
  }

  void _readinessChanged() {
    if (_disposed) return;
    runtime.refreshSettings();
    if (_session.isLoaded &&
        !_session.isLoading &&
        _session.canWrite &&
        !_maintenance.isReserved &&
        !_initialized &&
        !_initializationError &&
        (settings.enabled ||
            settings.endpoint.isNotEmpty ||
            _session.committedData.aiApiSettings.customBaseUrl.isNotEmpty)) {
      initialize().ignore();
    }
  }

  void _maintenanceChanged() {
    if (_maintenance.isReserved) {
      runtime.cancelAll();
      mutations.invalidate();
      external.invalidate();
    }
    runtime.refreshSettings();
    _notify();
  }

  /// Called by clear/shutdown after their gate closes. Accepted writes settle
  /// before a caller removes files or closes the main repository.
  Future<void> quiesce() async {
    for (final token in _diagnosticTokens) {
      token.cancel();
    }
    runtime.cancelAll();
    await runtime.waitForIdle(except: _maintenanceScope);
    try {
      await _initializing;
    } catch (_) {
      // Initialization already reports its error in the Agent surface. It must
      // not block draining unrelated healthy application data on close/clear.
    }
    await _configurationTail;
    await mutations.waitForPendingWrites();
    if (_maintenanceScope == null) await external.waitForPendingWrites();
    await connections.waitForPendingWrites();
    await conversations.waitForPendingWrites();
  }

  void freeze() {
    for (final token in _diagnosticTokens) {
      token.cancel();
    }
    _suspended = true;
    runtime.cancelAll();
    runtime.refreshSettings();
    mutations.invalidate();
    external.invalidate();
    connections.freeze();
    conversations.freeze();
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
    unawaited(_commits.cancel());
    runtime.dispose();
    controlTools.dispose();
    diagnostics.close();
    // A view disposal cannot race an already accepted conversation write.
    unawaited(
      runtime.waitForIdle().then((_) async {
        await conversations.waitForPendingWrites();
        conversations.dispose();
        _provider.close();
      }),
    );
    super.dispose();
  }
}
