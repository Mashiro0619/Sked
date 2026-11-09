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
  Future<native.ViewConversationSnapshot?> loadConversation(String id) =>
      _loading[id] ??= _loadConversation(id).whenComplete(() {
        unawaited(_loading.remove(id));
      });

  Future<native.ViewConversationSnapshot?> _loadConversation(String id) async {
    final presentationEpoch = _presentationEpochs[id] ?? 0;
    final result = await client.query(
      bridge.AgentQuery(
        kind: bridge.QueryKind.readConversation,
        conversationId: id,
      ),
    );
    if (_disposed) return result.snapshot;
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

  /// The application calls this after connection, model or maintenance changes.
  void refreshSettings() {
    if (_disposed) return;
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
      case bridge.EventKind.hostRequest:
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
    for (final id in _snapshots.keys) {
      _errors[id] = 'storageUnavailable';
      _publishConversation(id);
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
    final phase = active
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
    AgentUiApproval? approval;
    if (phase == AgentUiPhase.waitingApproval && pending != null) {
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
    );
  }

  Future<void> _input(bridge.CommandKind kind, String id, String text) async {
    final snapshot = await _conversation(id);
    final connection = await _connection(snapshot);
    final compact = text.trim() == '/compact';
    await _dispatch(
      bridge.AgentCommand(
        kind: compact ? bridge.CommandKind.compact : kind,
        conversationId: id,
        text: compact ? null : text,
        flag: compact,
        attachmentIds: snapshot.conversation.draftAttachmentIds,
        references: snapshot.conversation.draftReferences,
        connection: connection,
      ),
    );
  }

  @override
  Future<void> send(String conversationId, String text) =>
      _input(bridge.CommandKind.send, conversationId, text);

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

  Future<void> editAndRedo(
    String conversationId,
    String messageId,
    String text, {
    required List<String> attachmentIds,
    required List<AgentComposerReference> references,
  }) async {
    final snapshot = await _conversation(conversationId);
    await _dispatch(
      bridge.AgentCommand(
        kind: bridge.CommandKind.editAndRedo,
        conversationId: conversationId,
        targetId: messageId,
        text: text,
        attachmentIds: attachmentIds,
        references: references.map(referenceToRust).toList(growable: false),
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
      _dispatch(
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
    _disposed = true;
    await _subscription.cancel();
    for (final view in _views.values) {
      view.dispose();
    }
    _views.clear();
    _state.dispose();
  }
}

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
