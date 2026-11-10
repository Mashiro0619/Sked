import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../../application/operation_contracts.dart';
import '../../models/agent_settings.dart';
import '../connection/agent_endpoint.dart';
import '../conversations/conversation_models.dart';
import '../interactions/agent_question.dart';
import '../operations/operation_executor.dart';
import '../references/agent_composer_reference.dart';
import '../ui/agent_ui_delegate.dart';
import 'conversation_projection.dart';
import 'generated/api/contracts.dart' as bridge;
import 'generated/api/models.dart' as native;
import 'rust_agent_client.dart';

/// Application-owned projection of the native Agent. Views only subscribe to
/// this delegate; disposing a view never stops an accepted native run.
class RustAgentUiDelegate extends AgentUiDelegate {
  RustAgentUiDelegate({
    required this.client,
    required this.readSettings,
    required this.readApiKey,
    required this.onOpenSettings,
    this.readMaintenance = _notInMaintenance,
    this.resolveEndpoint = resolveRustAgentEndpoint,
    this.onSnapshot,
    this.onReasoningDelta,
    this.validateComposerReferences,
    this.readEnvironment,
  }) {
    _subscription = client.events.listen(_event, onError: _streamError);
    refreshSettings();
  }

  final AgentRustClient client;
  final AgentSettings Function() readSettings;
  final Future<String> Function(AgentSettings snapshot) readApiKey;
  final VoidCallback onOpenSettings;
  final bool Function() readMaintenance;
  final Uri Function(AgentSettings settings) resolveEndpoint;
  final void Function(native.ViewConversationSnapshot snapshot)? onSnapshot;
  final void Function(String conversationId, String runId, String text)?
  onReasoningDelta;
  final Future<List<AgentComposerReference>> Function(
    String conversationId,
    List<AgentComposerReference> references,
  )?
  validateComposerReferences;
  final Map<String, Object?> Function()? readEnvironment;

  final _state = ValueNotifier(AgentUiState());
  final _snapshots = <String, native.ViewConversationSnapshot>{};
  final _presentations = <String, bridge.RunPresentation>{};
  final _presentationEpochs = <String, int>{};
  final _runs = <String, AgentUiRunState>{};
  final _views = <String, ValueNotifier<AgentUiRunState>>{};
  final _output = <String, StringBuffer>{};
  final _outputRuns = <String, String>{};
  final _errors = <String, String>{};
  final _approvals = <String, (String, AgentUiApproval)>{};
  final _loading = <String, Future<native.ViewConversationSnapshot?>>{};
  final _transportRequests = <String, _TransportConsent>{};
  final _transportGrants = <String>{};
  String? _transportSettingsStamp;
  int _transportEpoch = 0;
  int _dataEpoch = 0;
  late final StreamSubscription<bridge.AgentEvent> _subscription;
  bool _disposed = false;

  @override
  ValueListenable<AgentUiState> get state => _state;

  @override
  ValueListenable<AgentUiRunState> watchConversation(String conversationId) {
    final view = _views.putIfAbsent(
      conversationId,
      () => ValueNotifier(_runs[conversationId] ?? const AgentUiRunState()),
    );
    if (!_snapshots.containsKey(conversationId)) {
      unawaited(_refreshConversation(conversationId));
    }
    return view;
  }

  /// Loads existing history without starting or resuming a model request.
  Future<native.ViewConversationSnapshot?> loadConversation(String id) {
    final loading = _loading[id];
    if (loading != null) return loading;
    late final Future<native.ViewConversationSnapshot?> request;
    request = _loadConversation(id).whenComplete(() {
      if (identical(_loading[id], request)) _loading.remove(id);
    });
    _loading[id] = request;
    return request;
  }

  Future<native.ViewConversationSnapshot?> _loadConversation(String id) async {
    final dataEpoch = _dataEpoch;
    final presentationEpoch = _presentationEpochs[id] ?? 0;
    final result = await client.query(
      bridge.AgentQuery(
        kind: bridge.QueryKind.readConversation,
        conversationId: id,
      ),
    );
    if (_disposed || dataEpoch != _dataEpoch) return null;
    final snapshot = result.snapshot;
    if (snapshot == null) {
      forgetConversation(id);
    } else {
      ingestSnapshot(
        snapshot,
        presentation: (_presentationEpochs[id] ?? 0) == presentationEpoch
            ? result.presentation
            : null,
      );
    }
    return snapshot;
  }

  Future<void> _refreshConversation(String id) async {
    try {
      await loadConversation(id);
    } catch (_) {
      if (_disposed) return;
      _errors[id] = 'storageUnavailable';
      _publishConversation(id);
    }
  }

  /// Receives the same persisted projection used by the conversation repository.
  /// Sequence checks also prevent a slower history query replacing a live event.
  void ingestSnapshot(
    native.ViewConversationSnapshot snapshot, {
    bridge.RunPresentation? presentation,
  }) {
    if (_disposed) return;
    final id = snapshot.conversation.id;
    final previous = _snapshots[id];
    if (previous != null && snapshot.sequence < previous.sequence) return;
    final runId = snapshot.conversation.runId;
    if (previous != null &&
        (previous.conversation.mode != snapshot.conversation.mode ||
            previous.conversation.modelSelection !=
                snapshot.conversation.modelSelection)) {
      _invalidateTransport(conversationId: id);
    }
    if (previous?.conversation.runId != runId) {
      _output.remove(id);
      _outputRuns.remove(id);
      _errors.remove(id);
      _presentations.remove(id);
    }
    if (presentation != null) _presentations[id] = presentation;
    final lastAssistant = snapshot.messages
        .where((message) => message.role == native.ViewMessageRole.assistant)
        .lastOrNull;
    final previousAssistant = previous?.messages
        .where((message) => message.role == native.ViewMessageRole.assistant)
        .lastOrNull;
    if (lastAssistant != null &&
        (lastAssistant.id != previousAssistant?.id ||
            lastAssistant.text != previousAssistant?.text)) {
      _output.remove(id);
    }
    _snapshots[id] = snapshot;
    if (!_nativeActive(snapshot.conversation.status)) _output.remove(id);
    _publishConversation(id);
    onSnapshot?.call(snapshot);
    if (previous == null ||
        previous.conversation.modelSelection !=
            snapshot.conversation.modelSelection) {
      _publishSettings();
    }
  }

  void forgetConversation(String id) {
    _invalidateTransport(conversationId: id);
    _snapshots.remove(id);
    _presentations.remove(id);
    _presentationEpochs.remove(id);
    _runs.remove(id);
    _output.remove(id);
    _outputRuns.remove(id);
    _errors.remove(id);
    _approvals.remove(id);
    if (!_disposed) {
      _views[id]?.value = const AgentUiRunState();
      _publishSettings();
    }
  }

  void invalidateAfterDataBoundary() {
    _dataEpoch++;
    _loading.clear();
    _invalidateTransport();
    for (final id in _snapshots.keys.toList()) {
      forgetConversation(id);
    }
  }

  /// The application calls this after connection, model or maintenance changes.
  void refreshSettings() {
    if (_disposed) return;
    final stamp = jsonEncode([readSettings().toJson(), readMaintenance()]);
    if (_transportSettingsStamp != null && _transportSettingsStamp != stamp) {
      _invalidateTransport();
    }
    _transportSettingsStamp = stamp;
    for (final id in _snapshots.keys) {
      _publishConversation(id);
    }
    _publishSettings();
  }

  void _publishSettings() {
    if (_disposed) return;
    final settings = readSettings();
    bool configured;
    try {
      resolveEndpoint(settings);
      configured = settings.defaultModelSelection != null;
    } on FormatException {
      configured = false;
    }
    _state.value = AgentUiState.live(
      enabled: settings.enabled,
      configured: configured,
      maintenance: readMaintenance(),
      defaultMode: settings.permissionMode,
      availableModels: settings.availableModels,
      defaultModelSelection: settings.defaultModelSelection,
      modelSelections: {
        for (final snapshot in _snapshots.values)
          if (snapshot.conversation.modelSelection != null)
            snapshot.conversation.id: modelSelectionFromRust(
              snapshot.conversation.modelSelection,
            )!,
      },
      runs: _runs,
    );
  }

  void _event(bridge.AgentEvent event) {
    if (_disposed) return;
    final id = event.conversationId;
    if (event.presentation != null) {
      _presentations[id] = event.presentation!;
      _presentationEpochs.update(id, (value) => value + 1, ifAbsent: () => 1);
    }
    switch (event.kind) {
      case bridge.EventKind.presentation:
        _publishConversation(id);
      case bridge.EventKind.snapshot:
        final snapshot = event.snapshot;
        if (snapshot != null) {
          ingestSnapshot(snapshot, presentation: event.presentation);
        }
      case bridge.EventKind.textDelta:
        if (!_acceptOutput(event)) return;
        (_output[id] ??= StringBuffer()).write(event.text ?? '');
        _publishConversation(id);
      case bridge.EventKind.reasoningDelta:
        if (!_acceptOutput(event)) return;
        onReasoningDelta?.call(id, event.runId!, event.text ?? '');
      case bridge.EventKind.outputReset:
        if (!_acceptOutput(event)) return;
        _output.remove(id);
        _publishConversation(id);
      case bridge.EventKind.runSettled:
        if (event.runId != _snapshots[id]?.conversation.runId) return;
        _output.remove(id);
        if (event.outcome == bridge.HostOutcome.error) {
          _errors[id] = _nativeErrorCode(event.errorCode);
        } else if (event.outcome == bridge.HostOutcome.unknown) {
          _errors[id] = 'interruptedRunNeedsReview';
        }
        // The preceding native snapshot owns the phase, including a steering
        // handover that deliberately remains active while the old run settles.
        _publishConversation(id);
      case bridge.EventKind.error:
        _errors[id] = _nativeErrorCode(event.errorCode);
        _publishConversation(id);
      case bridge.EventKind.resync:
        for (final conversationId in _snapshots.keys.toList()) {
          unawaited(_refreshConversation(conversationId));
        }
      case bridge.EventKind.toolProgress:
      case bridge.EventKind.usage:
      case bridge.EventKind.knowledgeChanged:
        break;
      case bridge.EventKind.hostRequest:
        final request = event.hostRequest;
        if (request != null) _transportRequest(request);
        break;
      case bridge.EventKind.ready:
        // Progress and usage are persisted before their events. Their typed
        // snapshot has already updated this projection; the host owns requests.
        break;
    }
  }

  bool _acceptOutput(bridge.AgentEvent event) {
    final runId = event.runId;
    if (runId == null ||
        runId != _snapshots[event.conversationId]?.conversation.runId) {
      return false;
    }
    if (_outputRuns[event.conversationId] != runId) {
      _output[event.conversationId] = StringBuffer();
      _outputRuns[event.conversationId] = runId;
    }
    return true;
  }

  void _streamError(Object error, StackTrace stackTrace) {
    if (_disposed) return;
    _invalidateTransport();
    for (final id in _snapshots.keys) {
      _errors[id] = 'storageUnavailable';
      _publishConversation(id);
    }
  }

  _TransportConsent? _transportApprovalFor(String id) => _transportRequests
      .values
      .where(
        (pending) =>
            pending.request.conversationId == id && pending.approval != null,
      )
      .firstOrNull;

  void _transportRequest(bridge.HostRequest request) {
    if (request.kind == bridge.HostRequestKind.cancel &&
        request.connection != null) {
      _transportRequests.remove(request.id);
      _publishConversation(request.conversationId);
      return;
    }
    if (request.kind != bridge.HostRequestKind.authorizeConnection ||
        _transportRequests.containsKey(request.id)) {
      return;
    }
    final pending = _TransportConsent(request, _transportEpoch);
    _transportRequests[request.id] = pending;
    unawaited(_evaluateTransport(pending));
  }

  Future<void> _evaluateTransport(_TransportConsent pending) async {
    if (pending.resolving || !_transportCurrent(pending)) return;
    pending.resolving = true;
    try {
      final current = await _validateTransport(pending);
      if (!_transportCurrent(pending)) return;
      if (current == null) {
        await _submitTransport(pending, false);
      } else if (current.automatic || _transportGrants.contains(current.key)) {
        await _submitTransport(pending, true);
      } else {
        final endpoint = Uri.parse(pending.request.connection!.endpoint);
        pending.approval ??= AgentUiApproval(
          id: pending.request.id,
          summary:
              'Allow sending this conversation and API credential over HTTP?',
          details: {
            'kind': 'httpTransport',
            'endpoint': Uri(
              scheme: endpoint.scheme,
              host: endpoint.host,
              port: endpoint.hasPort ? endpoint.port : null,
              path: endpoint.path,
            ).toString(),
          },
        );
        _publishConversation(pending.request.conversationId);
      }
    } catch (_) {
      await _submitTransport(pending, false);
    } finally {
      pending.resolving = false;
    }
  }

  bool _transportCurrent(_TransportConsent pending) =>
      !_disposed &&
      pending.epoch == _transportEpoch &&
      identical(_transportRequests[pending.request.id], pending);

  Future<({String key, bool automatic})?> _validateTransport(
    _TransportConsent pending,
  ) async {
    if (!_transportCurrent(pending)) return null;
    final request = pending.request;
    final identity = request.connection;
    final configured = readSettings();
    if (identity == null || !configured.enabled || readMaintenance()) {
      return null;
    }
    final snapshot = await loadConversation(request.conversationId);
    if (snapshot == null ||
        snapshot.conversation.archived ||
        (request.runId != null &&
            request.runId != snapshot.conversation.runId)) {
      return null;
    }
    final selection =
        modelSelectionFromRust(snapshot.conversation.modelSelection) ??
        configured.defaultModelSelection;
    if (selection == null ||
        !configured.allowsSelection(selection) ||
        selection.modelId != identity.model) {
      return null;
    }
    final settings = configured.copyWith(model: selection.modelId);
    final endpoint = resolveEndpoint(settings);
    if (endpoint.toString() != identity.endpoint ||
        settings.protocol.name != identity.protocol.name) {
      return null;
    }
    final settingsStamp = jsonEncode([configured.toJson(), readMaintenance()]);
    final apiKey = await readApiKey(settings);
    if (!_transportCurrent(pending) ||
        settingsStamp !=
            jsonEncode([readSettings().toJson(), readMaintenance()]) ||
        sha256.convert(utf8.encode(apiKey)).toString() !=
            identity.fingerprint) {
      return null;
    }
    final mode = _snapshots[request.conversationId]?.conversation.mode;
    if (mode != native.ViewPermissionMode.full && mode != request.mode) {
      return null;
    }
    return (
      key: jsonEncode([
        identity.endpoint,
        identity.protocol.name,
        identity.model,
        identity.fingerprint,
      ]),
      automatic:
          endpoint.scheme == 'https' || mode == native.ViewPermissionMode.full,
    );
  }

  Future<void> _transportDecision(
    String id,
    String target,
    bool approved,
  ) async {
    final pending = _transportRequests[target];
    if (pending == null ||
        pending.request.conversationId != id ||
        !pending.presented ||
        pending.resolving ||
        !_transportCurrent(pending)) {
      throw const OperationProblem(
        OperationErrorCode.invalidApproval,
        'The HTTP approval is no longer current.',
      );
    }
    pending.resolving = true;
    String? granted;
    try {
      if (approved) {
        final current = await _validateTransport(pending);
        if (current == null || !_transportCurrent(pending)) {
          await _submitTransport(pending, false);
          throw const OperationProblem(
            OperationErrorCode.invalidApproval,
            'The connection changed before approval.',
          );
        }
        if (!current.automatic) {
          granted = current.key;
          _transportGrants.add(granted);
        }
      }
      if (!await _submitTransport(pending, approved)) {
        if (granted != null) _transportGrants.remove(granted);
        throw const OperationProblem(
          OperationErrorCode.invalidApproval,
          'The HTTP request is no longer pending.',
        );
      }
      if (granted != null) {
        for (final other in _transportRequests.values.toList()) {
          unawaited(_evaluateTransport(other));
        }
      }
    } finally {
      pending.resolving = false;
    }
  }

  Future<bool> _submitTransport(
    _TransportConsent pending,
    bool approved,
  ) async {
    if (identical(_transportRequests[pending.request.id], pending)) {
      _transportRequests.remove(pending.request.id);
    }
    if (!_disposed) _publishConversation(pending.request.conversationId);
    try {
      await (await client.core).submitHostResult(
        result: bridge.HostResult(
          requestId: pending.request.id,
          outcome: approved
              ? bridge.HostOutcome.success
              : bridge.HostOutcome.cancelled,
        ),
      );
      return true;
    } catch (_) {
      // Native cancellation may already have removed this ephemeral request.
      return false;
    }
  }

  void _invalidateTransport({String? conversationId}) {
    _transportGrants.clear();
    if (conversationId == null) _transportEpoch++;
    for (final pending in _transportRequests.values.toList()) {
      if (conversationId == null ||
          pending.request.conversationId == conversationId) {
        _transportRequests.remove(pending.request.id);
        unawaited(_submitTransport(pending, false));
      }
    }
  }

  void _publishConversation(String id) {
    if (_disposed) return;
    final snapshot = _snapshots[id];
    final presentation = _presentations[id];
    final context = presentation?.contextUsage;
    final runId = snapshot?.conversation.runId;
    final settings = readSettings();
    final selected =
        modelSelectionFromRust(snapshot?.conversation.modelSelection) ??
        settings.defaultModelSelection;
    final run = snapshot?.runs.where((run) => run.id == runId).lastOrNull;
    final selection = modelSelectionFromRust(run?.model) ?? selected;
    final contextModelId = context?.modelId ?? selected?.modelId;
    final model = contextModelId == null
        ? null
        : settings.modelConfig(contextModelId);
    final operations =
        snapshot?.operations
            .where((operation) => operation.runId == runId)
            .map(_operation)
            .toList(growable: false) ??
        const <AgentOperationUpdate>[];
    final pending = operations
        .where(
          (operation) => operation.phase == AgentOperationPhase.waitingApproval,
        )
        .firstOrNull;
    final error =
        _errors[id] ??
        (run?.errorCode == null ? null : _nativeErrorCode(run!.errorCode));
    final status =
        snapshot?.conversation.status ?? native.ViewConversationStatus.idle;
    final active = presentation?.active ?? _nativeActive(status);
    final transport = _transportApprovalFor(id);
    final phase = transport != null
        ? AgentUiPhase.waitingApproval
        : active
        ? switch (status) {
            native.ViewConversationStatus.waitingApproval =>
              AgentUiPhase.waitingApproval,
            native.ViewConversationStatus.waitingUser =>
              AgentUiPhase.waitingUser,
            _ => AgentUiPhase.running,
          }
        : error != null
        ? AgentUiPhase.failed
        : status == native.ViewConversationStatus.idle
        ? AgentUiPhase.idle
        : AgentUiPhase.stopped;
    final control = snapshot?.queuedControls
        .where(
          (control) => control.kind == native.ViewControlKind.compactContext,
        )
        .lastOrNull;
    final compacting = presentation?.compacting ?? false;
    AgentUiApproval? approval = transport?.approval;
    if (transport != null) {
      transport.presented = true;
    } else if (phase == AgentUiPhase.waitingApproval && pending != null) {
      final key = jsonEncode([runId, pending.callId, pending.details]);
      final saved = _approvals[id];
      approval = saved?.$1 == key
          ? saved!.$2
          : AgentUiApproval(
              id: pending.callId,
              summary: pending.details['summary'] as String? ?? '',
              details: pending.details,
            );
      _approvals[id] = (key, approval);
    } else {
      _approvals.remove(id);
    }
    final value = AgentUiRunState(
      phase: phase,
      runId: snapshot?.conversation.runId,
      replyTargetMessageId: presentation?.replyTargetMessageId,
      streamingText: _output[id]?.toString() ?? '',
      errorMessage: error,
      pendingApproval: approval,
      recoveryRequired:
          operations.any(
            (operation) => operation.phase == AgentOperationPhase.unresolved,
          ) ||
          (!active &&
              presentation?.canContinue == false &&
              error == 'storageUnavailable'),
      modelSelection: selection,
      requiresModelSelection:
          selected != null && !settings.allowsSelection(selected),
      contextUsage: AgentContextUsage(
        modelId: contextModelId,
        estimatedTokens: context?.estimated == true
            ? context?.inputTokens
            : null,
        reportedInputTokens: context?.estimated == false
            ? context?.inputTokens
            : null,
        maxContextTokens:
            context?.maxContextTokens ?? model?.effectiveContextTokens,
        autoCompactAtTokens:
            context?.autoCompactAtTokens ?? model?.effectiveCompactAtTokens,
        autoCompact: model?.autoCompact ?? true,
        isCompacting: compacting,
        isCompactionQueued:
            !compacting && control?.status == native.ViewControlStatus.queued,
        errorMessage: control?.status == native.ViewControlStatus.failed
            ? control?.errorMessage
            : null,
      ),
      operations: operations,
    );
    _runs[id] = value;
    _views[id]?.value = value;
  }

  Future<void> _dispatch(bridge.AgentCommand command) async {
    final result = await client.dispatch(command);
    if (_disposed) return;
    final snapshot = result.snapshot;
    if (snapshot != null) {
      ingestSnapshot(snapshot);
    } else if (command.conversationId != null) {
      await loadConversation(command.conversationId!);
    }
  }

  Future<native.ViewConversationSnapshot> _conversation(String id) async =>
      await loadConversation(id) ??
      (throw const OperationProblem(
        OperationErrorCode.notFound,
        'The Agent conversation no longer exists.',
      ));

  Future<bridge.ModelConnection> _connection(
    native.ViewConversationSnapshot snapshot,
  ) async {
    final configured = readSettings();
    if (_disposed || !configured.enabled) {
      throw const OperationProblem(
        OperationErrorCode.disabled,
        'Agent is disabled.',
      );
    }
    if (readMaintenance()) {
      throw const OperationProblem(
        OperationErrorCode.busy,
        'Agent data is being updated.',
      );
    }
    final selection =
        modelSelectionFromRust(snapshot.conversation.modelSelection) ??
        configured.defaultModelSelection;
    if (selection == null || !configured.allowsSelection(selection)) {
      throw const OperationProblem(
        OperationErrorCode.invalidArgument,
        'Choose an enabled model and reasoning effort.',
        field: 'modelSelection',
      );
    }
    final settings = configured.copyWith(model: selection.modelId);
    final endpoint = resolveEndpoint(settings);
    final apiKey = await readApiKey(settings);
    if (_disposed ||
        readMaintenance() ||
        jsonEncode(readSettings().toJson()) !=
            jsonEncode(configured.toJson())) {
      throw const OperationProblem(
        OperationErrorCode.expired,
        'The Agent connection changed while its credential was being read.',
      );
    }
    final model = settings.modelConfig(selection.modelId)!;
    return bridge.ModelConnection(
      protocol: settings.protocol == AgentModelProtocol.responses
          ? bridge.ModelProtocol.responses
          : bridge.ModelProtocol.chatCompletions,
      endpoint: endpoint.toString(),
      modelConfigId: model.id,
      connectionFingerprint: rustAgentConnectionFingerprint(settings, endpoint),
      model: model.id,
      apiKey: apiKey,
      reasoningEffort: selection.wireReasoningEffort,
      maxContextTokens: model.effectiveContextTokens,
      autoCompactAtTokens: model.effectiveCompactAtTokens,
      environment: native.JsonPayload(
        json: jsonEncode(readEnvironment?.call() ?? const <String, Object?>{}),
      ),
    );
  }

  Future<void> _input(bridge.CommandKind kind, String id, String text) async {
    final snapshot = await _conversation(id);
    final compact = text.trim() == '/compact';
    final references = compact
        ? const <AgentComposerReference>[]
        : await _validatedReferences(
            id,
            snapshot.conversation.draftReferences
                .map(referenceFromRust)
                .toList(),
          );
    final current = await _conversation(id);
    if (!compact &&
        (!listEquals(
              snapshot.conversation.draftAttachmentIds,
              current.conversation.draftAttachmentIds,
            ) ||
            _referenceDigest(snapshot.conversation.draftReferences) !=
                _referenceDigest(current.conversation.draftReferences))) {
      throw const OperationProblem(
        OperationErrorCode.expired,
        'The input references changed while they were being validated.',
      );
    }
    final connection = await _connection(current);
    await _dispatch(
      bridge.AgentCommand(
        kind: compact ? bridge.CommandKind.compact : kind,
        conversationId: id,
        text: compact ? null : text,
        flag: compact,
        attachmentIds: current.conversation.draftAttachmentIds,
        references: references.map(referenceToRust).toList(growable: false),
        connection: connection,
      ),
    );
  }

  Future<List<AgentComposerReference>> _validatedReferences(
    String id,
    List<AgentComposerReference> references,
  ) async {
    final selected = AgentComposerReference.validatedList(references);
    if (selected.isEmpty) return const [];
    final validate = validateComposerReferences;
    if (validate == null) {
      throw const OperationProblem(
        OperationErrorCode.unsupported,
        'The application reference validator is unavailable.',
        field: 'references',
      );
    }
    return AgentComposerReference.validatedList(await validate(id, selected));
  }

  @override
  Future<void> send(String conversationId, String text) =>
      _input(bridge.CommandKind.send, conversationId, text);

  Future<void> startHandoff(String conversationId) =>
      _modelCommand(bridge.CommandKind.startHandoff, conversationId);

  @override
  Future<void> queueFollowUp(String conversationId, String text) =>
      _input(bridge.CommandKind.queue, conversationId, text);

  @override
  Future<void> steer(String conversationId, String text) =>
      _input(bridge.CommandKind.steer, conversationId, text);

  Future<void> _modelCommand(bridge.CommandKind kind, String id) async {
    final snapshot = await _conversation(id);
    final connection = await _connection(snapshot);
    await _dispatch(
      bridge.AgentCommand(
        kind: kind,
        conversationId: id,
        connection: connection,
      ),
    );
  }

  @override
  Future<void> continueConversation(String conversationId) async {
    final snapshot = await _conversation(conversationId);
    final connection = await _connection(snapshot);
    final redo = snapshot.redoBatches
        .where((batch) => !_terminalRedo(batch.phase))
        .lastOrNull;
    await _dispatch(
      bridge.AgentCommand(
        kind: redo == null
            ? bridge.CommandKind.continue_
            : bridge.CommandKind.resumeRedo,
        conversationId: conversationId,
        targetId: redo?.id,
        connection: connection,
      ),
    );
  }

  @override
  Future<void> compactContext(String conversationId) =>
      _modelCommand(bridge.CommandKind.compact, conversationId);

  Future<String> requestResume(
    String conversationId, {
    required String runId,
  }) async {
    final snapshot = await _conversation(conversationId);
    if (snapshot.redoBatches.any((batch) => !_terminalRedo(batch.phase))) {
      throw StateError(
        'Complete the pending history operation before resuming.',
      );
    }
    final connection = await _connection(snapshot);
    final result = await client.dispatch(
      bridge.AgentCommand(
        kind: bridge.CommandKind.continue_,
        conversationId: conversationId,
        targetId: runId,
        connection: connection,
      ),
    );
    await loadConversation(conversationId);
    return result.id ??
        (throw StateError('Native resume did not return its run identity.'));
  }

  Future<void> regenerateReply(String conversationId, String messageId) async {
    final snapshot = await _conversation(conversationId);
    await _dispatch(
      bridge.AgentCommand(
        kind: bridge.CommandKind.regenerate,
        conversationId: conversationId,
        targetId: messageId,
        connection: await _connection(snapshot),
      ),
    );
  }

  Future<Map<String, Object?>> runHostTool(
    String conversationId, {
    required String toolName,
    required Map<String, Object?> arguments,
  }) async {
    if (_disposed || !readSettings().enabled || readMaintenance()) {
      throw const OperationProblem(
        OperationErrorCode.busy,
        'Agent is unavailable during maintenance.',
      );
    }
    final result = await (await client.ensureInitialized()).runHostTool(
      conversationId: conversationId,
      toolName: toolName,
      arguments: native.JsonPayload(json: jsonEncode(arguments)),
      environment: native.JsonPayload(
        json: jsonEncode(readEnvironment?.call() ?? const <String, Object?>{}),
      ),
    );
    await loadConversation(conversationId);
    return (jsonDecode(result.json) as Map).cast<String, Object?>();
  }

  Future<void> editAndRedo(
    String conversationId,
    String messageId,
    String text, {
    required List<String> attachmentIds,
    required List<AgentComposerReference> references,
  }) async {
    final fixedAttachments = List<String>.unmodifiable(attachmentIds);
    final fixedReferences = await _validatedReferences(
      conversationId,
      references,
    );
    final snapshot = await _conversation(conversationId);
    await _dispatch(
      bridge.AgentCommand(
        kind: bridge.CommandKind.editAndRedo,
        conversationId: conversationId,
        targetId: messageId,
        text: text,
        attachmentIds: fixedAttachments,
        references: fixedReferences
            .map(referenceToRust)
            .toList(growable: false),
        connection: await _connection(snapshot),
      ),
    );
  }

  Future<void> endHistoryRedo(
    String conversationId, {
    required String batchId,
    void Function()? validate,
  }) async {
    validate?.call();
    await _decision(bridge.CommandKind.endRedo, conversationId, batchId);
  }

  @override
  Future<void> stop(String conversationId) => _dispatch(
    bridge.AgentCommand(
      kind: bridge.CommandKind.stop,
      conversationId: conversationId,
    ),
  );

  @override
  Future<void> approve(String conversationId, String planId) =>
      _decision(bridge.CommandKind.approve, conversationId, planId);

  @override
  Future<void> reject(String conversationId, String planId) =>
      _decision(bridge.CommandKind.reject, conversationId, planId);

  Future<void> _decision(bridge.CommandKind kind, String id, String target) =>
      _transportRequests.containsKey(target) &&
          (kind == bridge.CommandKind.approve ||
              kind == bridge.CommandKind.reject)
      ? _transportDecision(id, target, kind == bridge.CommandKind.approve)
      : _dispatch(
          bridge.AgentCommand(kind: kind, conversationId: id, targetId: target),
        );

  @override
  Future<void> answerQuestion(
    String conversationId,
    String questionId,
    List<AgentQuestionAnswer> answers,
  ) => _dispatch(
    bridge.AgentCommand(
      kind: bridge.CommandKind.answerQuestion,
      conversationId: conversationId,
      targetId: questionId,
      answers: answers
          .map(
            (answer) => native.ViewQuestionAnswer(
              questionId: answer.questionId,
              optionIds: answer.optionIds,
              text: answer.text,
            ),
          )
          .toList(growable: false),
    ),
  );

  @override
  Future<void> dismissQuestion(String conversationId, String questionId) =>
      _decision(bridge.CommandKind.dismissQuestion, conversationId, questionId);

  @override
  Future<void> setMode(String conversationId, AgentPermissionMode mode) =>
      _dispatch(
        bridge.AgentCommand(
          kind: bridge.CommandKind.setMode,
          conversationId: conversationId,
          mode: native.ViewPermissionMode.values.byName(mode.name),
        ),
      );

  @override
  Future<void> setModelSelection(
    String conversationId,
    AgentModelSelection selection,
  ) async {
    if (!readSettings().allowsSelection(selection)) {
      throw const OperationProblem(
        OperationErrorCode.invalidArgument,
        'Choose an enabled model and reasoning effort.',
        field: 'modelSelection',
      );
    }
    await _dispatch(
      bridge.AgentCommand(
        kind: bridge.CommandKind.setModel,
        conversationId: conversationId,
        selection: modelSelectionToRust(selection),
      ),
    );
  }

  @override
  Future<void> setArchived(String conversationId, bool archived) => _dispatch(
    bridge.AgentCommand(
      kind: bridge.CommandKind.archive,
      conversationId: conversationId,
      flag: archived,
    ),
  );

  @override
  int pendingInputCount(String conversationId) =>
      _snapshots[conversationId]?.queuedInputs.length ?? 0;

  @override
  bool canManageQueuedInput(String conversationId, String inputId) {
    final snapshot = _snapshots[conversationId];
    return !_disposed &&
        !readMaintenance() &&
        snapshot != null &&
        !snapshot.conversation.archived &&
        !snapshot.redoBatches.any((batch) => !_terminalRedo(batch.phase)) &&
        snapshot.queuedInputs.any((input) => input.id == inputId);
  }

  @override
  Future<void> restoreQueuedInput(
    String conversationId,
    ConversationMessage input, {
    void Function()? validate,
  }) async {
    validate?.call();
    await _decision(bridge.CommandKind.restoreInput, conversationId, input.id);
  }

  @override
  Future<void> cancelQueuedInput(
    String conversationId,
    ConversationMessage input, {
    void Function()? validate,
  }) async {
    validate?.call();
    await _decision(bridge.CommandKind.cancelInput, conversationId, input.id);
  }

  @override
  void openSettings() => onOpenSettings();

  /// The application disposes this projection after it has quiesced the core.
  /// Native ownership remains with AgentRustClient's application owner.
  Future<void> dispose() async {
    if (_disposed) return;
    final pending = _transportRequests.values.toList();
    _transportRequests.clear();
    _transportGrants.clear();
    _transportEpoch++;
    _disposed = true;
    await Future.wait(
      pending.map((request) => _submitTransport(request, false)),
    );
    await _subscription.cancel();
    for (final view in _views.values) {
      view.dispose();
    }
    _views.clear();
    _state.dispose();
  }
}

class _TransportConsent {
  _TransportConsent(this.request, this.epoch);

  final bridge.HostRequest request;
  final int epoch;
  AgentUiApproval? approval;
  bool presented = false;
  bool resolving = false;
}

String _referenceDigest(Iterable<native.ViewContextReference> references) =>
    jsonEncode(
      references.map(referenceFromRust).map((value) => value.toJson()).toList(),
    );

AgentOperationUpdate _operation(native.ViewOperationRecord operation) {
  final value = jsonDecode(operation.details.json);
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Agent operation details must be an object.');
  }
  final model = value['modelPayload'];
  final detail = value['details'];
  final details = <String, Object?>{
    if (model is Map<String, dynamic>) ...model,
    if (detail is Map<String, dynamic>) ...detail,
    if (model == null && detail == null) ...value,
    if (operation.binding != null)
      'operationId': operation.binding!.operationId,
  };
  return AgentOperationUpdate(
    callId: operation.toolCallId,
    toolName: operation.toolName,
    phase: switch (operation.phase) {
      native.ViewOperationPhase.preparing => AgentOperationPhase.preparing,
      native.ViewOperationPhase.waitingApproval =>
        AgentOperationPhase.waitingApproval,
      native.ViewOperationPhase.executing => AgentOperationPhase.executing,
      native.ViewOperationPhase.previewed => AgentOperationPhase.previewed,
      native.ViewOperationPhase.committed => AgentOperationPhase.completed,
      native.ViewOperationPhase.cancelled => AgentOperationPhase.cancelled,
      native.ViewOperationPhase.failed => AgentOperationPhase.failed,
      native.ViewOperationPhase.unresolved => AgentOperationPhase.unresolved,
    },
    details: Map.unmodifiable(details),
  );
}

bool _nativeActive(native.ViewConversationStatus status) => switch (status) {
  native.ViewConversationStatus.running ||
  native.ViewConversationStatus.waitingApproval ||
  native.ViewConversationStatus.waitingUser ||
  native.ViewConversationStatus.stopping => true,
  native.ViewConversationStatus.idle ||
  native.ViewConversationStatus.interrupted => false,
};

bool _terminalRedo(native.ViewRedoPhase phase) =>
    phase == native.ViewRedoPhase.completed ||
    phase == native.ViewRedoPhase.cancelled;

bool _notInMaintenance() => false;

String _nativeErrorCode(String? code) => switch (code) {
  'run_save_failed' || 'progress_save_failed' => 'storageUnavailable',
  'queued_model_unavailable' => 'modelSelectionRequired',
  null || '' => 'toolFailure',
  _ => code,
};

/// Uses the same endpoint rules as connection configuration and diagnostics.
Uri resolveRustAgentEndpoint(AgentSettings settings) =>
    resolveConfiguredAgentEndpoint(settings);

String rustAgentConnectionFingerprint(AgentSettings settings, Uri endpoint) =>
    sha256
        .convert(
          utf8.encode(
            jsonEncode({
              'endpoint': endpoint.toString(),
              'protocol': settings.protocol.name,
            }),
          ),
        )
        .toString();
