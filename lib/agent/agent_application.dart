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
import 'attachments/attachment_repository.dart';
import 'attachments/conversation_attachments.dart';
import 'conversations/conversation_repository.dart';
import 'history/conversation_history_service.dart';
import 'knowledge/knowledge_service.dart';
import 'provider/provider.dart';
import 'imports/school_import_tool_adapter.dart';
import 'runtime/agent_runtime_controller.dart';
import 'tools/application_tool_host.dart';
import 'tools/platform_tool_adapters.dart';
import 'tools/workflow_tool_adapters.dart';
import 'tools/conversation_tool_adapters.dart';
import 'tools/agent_control_tool_adapters.dart';
import 'tools/knowledge_tool_adapters.dart';

export 'connection/agent_credential_action.dart';

/// Safe failure categories for product feedback; never exposes stored content.
enum AgentInitializationFailure {
  applicationStorage,
  conversationStorage,
  connectionStorage,
}

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
    AttachmentStorage? attachmentStorage,
    KnowledgeStorage? knowledgeStorage,
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
       conversations = ConversationRepository(storage: conversationStorage),
       attachmentStore = AttachmentRepository(storage: attachmentStorage),
       knowledgeRepository = AgentKnowledgeRepository(
         storage: knowledgeStorage,
       ) {
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
    _attachmentDataGeneration = mutations.generation;
    binaryAttachments = ConversationAttachments(
      conversations: conversations,
      repository: attachmentStore,
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
    knowledge = AgentKnowledgeService(
      repository: knowledgeRepository,
      readRegisteredTools: () => tools.registeredNames,
      readDataGeneration: () => mutations.generation,
      isAvailable: _knowledgeAvailable,
      validateMutation: _validateKnowledgeMutation,
    );
    tools = ApplicationToolHost(
      session: session,
      mutations: mutations,
      conversationForScope: (scope) => runtime.conversationForScope(scope),
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
      schoolWebSessionSupported:
          !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.macOS ||
              defaultTargetPlatform == TargetPlatform.windows),
      connectionManager: connections,
    );
    knowledgeTools = registerKnowledgeTools(
      tools,
      external: external,
      service: knowledge,
      registerReadBack: platformTools.registerReadBack,
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
      attachments: attachmentStore,
      onAttachmentProgress: binaryAttachments.transferProgress,
      readSettings: _effectiveSettings,
      readApiKey: (snapshot) async {
        // Side-store loading is initiated by an actual run. Opening the
        // default-on entry or editing its connection need not read knowledge.
        await knowledge.initialize();
        return connections.readKeyFor(snapshot);
      },
      additionalSystemInstructions: AgentKnowledgeService.modelGuidance,
      readTools: tools.toolsFor,
      executeTool: tools.execute,
      readOperationReceipt: (toolName, operationId) async {
        final receipt = toolName == 'mutation.commit'
            ? mutations.status(operationId)
            : external.status(operationId);
        return receipt == null
            ? {'status': 'notRecorded', 'operationId': operationId}
            : tools.describeCommitResult(receipt.result);
      },
      readPreparedOperation: (call) {
        final id = call.decodedArguments['planId'];
        if (id is! String) return null;
        return call.name == 'mutation.commit'
            ? mutations.plan(id)
            : external.plan(id);
      },
      onOpenSettings: () => onOpenSettings?.call(),
      readMaintenance: () => maintenance.isReserved || !_session.canWrite,
      onRunSettled: (scope) {
        tools.finishScope(scope);
        external.discardScope(scope);
        controlTools.discardScope(scope);
        knowledgeTools.discardScope(scope);
        _pruneHistory().ignore();
        if (_attachmentCleanupError) _scheduleAttachmentCollection();
      },
    );
    history = ConversationHistoryService(
      conversations: conversations,
      runtime: runtime,
      knowledge: knowledgeRepository,
      session: session,
      persistence: persistence,
      maintenance: maintenance,
      mutations: mutations,
      external: external,
    );
    runtime.onContinueHistoryRedo = history.continueRedo;
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
    conversations.addListener(_conversationsChanged);
  }

  final AppSession _session;
  final AppPersistence _persistence;
  final AppDataMaintenance _maintenance;
  final VoidCallback _publishViews;
  final ProviderClient _provider;
  late final diagnostics = AgentConnectionDiagnostics(provider: _provider);
  final _diagnosticTokens = <ProviderCancellationToken>{};
  final ConversationRepository conversations;
  final AttachmentRepository attachmentStore;
  late final ConversationAttachments binaryAttachments;
  final AgentKnowledgeRepository knowledgeRepository;
  late final AgentKnowledgeService knowledge;
  late final KnowledgeToolAdapters knowledgeTools;
  late final MutationCoordinator mutations;
  late final ExternalOperationCoordinator external;
  late final PlatformToolAdapters platformTools;
  late final WorkflowToolAdapters workflowTools;
  late final ConversationToolAdapters conversationTools;
  late final AgentControlToolAdapters controlTools;
  late final AgentConnectionManager connections;
  late final ApplicationToolHost tools;
  late final AgentRuntimeController runtime;
  late final ConversationHistoryService history;
  late final StreamSubscription<AppDataCommit> _commits;
  VoidCallback? onOpenSettings;
  Future<void>? _initializing;
  Future<void> _configurationTail = Future.value();
  bool _initialized = false;
  bool _initializationError = false;
  AgentInitializationFailure? _initializationFailure;
  bool _disposed = false;
  bool _suspended = false;
  bool _clearSuspended = false;
  int _disableRequests = 0;
  int _navigationRevision = 0;
  OperationScope? _maintenanceScope;
  Future<void>? _attachmentFreeze;
  Future<void>? _attachmentCollection;
  bool _attachmentCollectionRequested = false;
  bool _attachmentRecoveryRequired = false;
  bool _attachmentCleanupError = false;
  Set<String> _attachmentConversationIds = {};
  late String _attachmentDataGeneration;

  /// Failed collection leaves remaining local bytes intact and can be retried.
  bool get attachmentCleanupError => _attachmentCleanupError;

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

  /// The retired parser's model name is a candidate, never an enabled model.
  String get suggestedModelId =>
      _session.committedData.aiApiSettings.customModel.trim();
  bool get isInitialized => _initialized;
  bool get initializationError => _initializationError;
  AgentInitializationFailure? get initializationFailure =>
      _initializationFailure;
  Future<void> recoverHistoryBeforeWrites() => history.recoverBeforeWrites();
  int get navigationRevision => _navigationRevision;

  bool _knowledgeAvailable() =>
      !_disposed &&
      !_suspended &&
      !_clearSuspended &&
      _session.isLoaded &&
      !_session.isLoading &&
      _session.canWrite &&
      !_maintenance.isReserved;

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
    _initializationFailure = null;
    var stage = AgentInitializationFailure.applicationStorage;
    try {
      if (!_session.isLoaded ||
          _session.isLoading ||
          !_session.canWrite ||
          _session.repository.isWriteStateUnknown ||
          _maintenance.isReserved) {
        throw StateError('Application storage is not ready.');
      }
      stage = AgentInitializationFailure.conversationStorage;
      if (!conversations.isLoaded || conversations.blocked) {
        await conversations.load();
      }
      stage = AgentInitializationFailure.connectionStorage;
      await connections.initialize();
      if (_disposed || _suspended || _clearSuspended) return;
      stage = AgentInitializationFailure.conversationStorage;
      await _pruneHistory(initializing: true);
      if (_disposed || _suspended || _clearSuspended) return;
      _attachmentConversationIds = {
        for (final conversation in conversations.conversations) conversation.id,
      };
      _initialized = true;
      _scheduleAttachmentCollection();
    } catch (_) {
      _initialized = false;
      _initializationError = true;
      _initializationFailure = stage;
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
    final changesTransport =
        value.endpoint != settings.endpoint ||
        value.protocol != settings.protocol ||
        credentialAction != AgentCredentialAction.keep;
    if (changesTransport) {
      _disableRequests++;
      runtime.refreshSettings();
    }
    return _configureSerially(() async {
      await initialize();
      await connections.save(
        value,
        credentialAction: credentialAction,
        rawKey: rawKey,
      );
    }).whenComplete(() {
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

  Future<void> _pruneHistory({bool initializing = false}) async {
    if ((!_initialized && !initializing) ||
        _disposed ||
        _suspended ||
        _clearSuspended) {
      return;
    }
    if (initializing && !conversations.canWrite) {
      throw const ConversationStorageException(
        'Conversation storage is unavailable during initialization.',
      );
    }
    if (settings.historyRetentionDays == 0 || !conversations.canWrite) return;
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
      if (_attachmentRecoveryRequired) {
        binaryAttachments.invalidatePendingAfterDataBoundary();
      }
      _attachmentRecoveryRequired = false;
      await _resumeAttachmentsAfterMaintenance();
      _scheduleAttachmentCollection();
      _initializationError = false;
      _initializationFailure = null;
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
    knowledgeRepository.freeze();
    await _freezeAttachments();
    await conversations.waitForPendingWrites();
    await knowledge.waitForPendingOperations();
    runtime.refreshSettings();
  }

  void resumeAfterFailedDataClear() {
    _clearSuspended = false;
    _attachmentRecoveryRequired = true;
    binaryAttachments.invalidatePendingAfterDataBoundary();
    conversations.resumeAfterFailedDataClear();
    knowledgeRepository.resumeAfterFailedDataClear();
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
    final generation = mutations.generation;
    if (generation != _attachmentDataGeneration) {
      _attachmentDataGeneration = generation;
      binaryAttachments.invalidatePendingAfterDataBoundary();
    }
    runtime.refreshSettings();
    _pruneHistory().ignore();
    _notify();
  }

  void _readinessChanged() {
    if (_disposed) return;
    runtime.refreshSettings();
    knowledge.ownerChanged();
    // Opening the feature or its settings owns side-store initialization.
    // A default-on entry must not decode all chat history at app startup.
    _notify();
  }

  void _maintenanceChanged() {
    if (_maintenance.isReserved) {
      _freezeAttachments().ignore();
      runtime.cancelAll();
      mutations.invalidate();
      external.invalidate();
    } else if (!_clearSuspended && !_suspended) {
      // Existing complete backups leave shared knowledge intact. The restore
      // barrier freezes it only after accepted writes have been drained.
      knowledgeRepository.resumeAfterMaintenance();
      _resumeAttachmentsAfterMaintenance().ignore();
    }
    knowledge.ownerChanged();
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
    await knowledge.waitForPendingOperations();
    await _attachmentCollection;
    if (_maintenance.isReserved || _suspended || _clearSuspended) {
      await _freezeAttachments();
    } else {
      await binaryAttachments.waitForPendingOperations();
    }
    if (_maintenance.isReserved) knowledgeRepository.freeze();
  }

  void freeze({bool drainAcceptedRuns = false}) {
    final completingRunIds = drainAcceptedRuns
        ? runtime.acceptedRunIds
        : const <String>{};
    for (final token in _diagnosticTokens) {
      token.cancel();
    }
    _suspended = true;
    runtime.cancelAll();
    runtime.refreshSettings();
    mutations.invalidate();
    external.invalidate();
    connections.freeze();
    conversations.freeze(completingRunIds: completingRunIds);
    knowledgeRepository.freeze();
    _freezeAttachments().ignore();
    knowledge.ownerChanged();
  }

  Future<void> _freezeAttachments() =>
      _attachmentFreeze ??= binaryAttachments.freezeAndDrain();

  Future<void> _resumeAttachmentsAfterMaintenance() async {
    await _attachmentFreeze;
    if (_disposed ||
        _suspended ||
        _clearSuspended ||
        _maintenance.isReserved ||
        _attachmentRecoveryRequired ||
        !conversations.canWrite) {
      return;
    }
    _attachmentFreeze = null;
    binaryAttachments.resume();
  }

  void _conversationsChanged() {
    if (!conversations.isLoaded) return;
    final ids = {
      for (final conversation in conversations.conversations) conversation.id,
    };
    final removed = _attachmentConversationIds.any((id) => !ids.contains(id));
    _attachmentConversationIds = ids;
    if (removed) _scheduleAttachmentCollection();
  }

  void _scheduleAttachmentCollection() {
    if (!_initialized ||
        _disposed ||
        _suspended ||
        _clearSuspended ||
        _maintenance.isReserved ||
        _attachmentRecoveryRequired ||
        !conversations.canWrite) {
      return;
    }
    _attachmentCollectionRequested = true;
    if (_attachmentCollection != null) return;
    _attachmentCollection = _collectAttachments().whenComplete(() {
      _attachmentCollection = null;
    });
  }

  Future<void> _collectAttachments() async {
    while (_attachmentCollectionRequested) {
      _attachmentCollectionRequested = false;
      try {
        await binaryAttachments.collectGarbage();
        _attachmentCleanupError = false;
      } catch (_) {
        // The archive is already durable. Failed orphan cleanup must neither
        // undo that deletion nor claim that its remaining bytes were removed.
        _attachmentCleanupError = true;
      }
    }
    _notify();
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
    runtime.dispose();
    tools.dispose();
    controlTools.dispose();
    diagnostics.close();
    // A view disposal cannot race an already accepted conversation write.
    unawaited(
      runtime.waitForIdle().then((_) async {
        await conversations.waitForPendingWrites();
        await knowledge.waitForPendingOperations();
        await binaryAttachments.close();
        binaryAttachments.dispose();
        conversations.dispose();
        knowledge.dispose();
        knowledgeRepository.dispose();
        _provider.close();
      }),
    );
    super.dispose();
  }
}
