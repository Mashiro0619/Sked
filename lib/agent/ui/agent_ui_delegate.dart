import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../../application/operation_contracts.dart';
import '../../models/agent_settings.dart';
import '../conversations/conversation_models.dart';
import '../interactions/agent_question.dart';
import '../operations/operation_executor.dart';

enum AgentUiPhase {
  idle,
  running,
  waitingApproval,
  waitingUser,
  stopped,
  failed,
}

/// Display-only approval data. The host retains the executable approval proof.
class AgentUiApproval {
  AgentUiApproval({
    required this.id,
    required this.summary,
    required Map<String, Object?> details,
  }) : details = Map.unmodifiable(details);

  final String id;
  final String summary;
  final Map<String, Object?> details;
}

/// Current request context, separate from cumulative billing usage.
class AgentContextUsage {
  const AgentContextUsage({
    this.modelId,
    this.estimatedTokens,
    this.reportedInputTokens,
    this.maxContextTokens,
    this.autoCompactAtTokens,
    this.autoCompact = true,
    this.isCompacting = false,
    this.isCompactionQueued = false,
    this.errorMessage,
  });

  final int? estimatedTokens;
  final String? modelId;
  final int? reportedInputTokens;
  final int? maxContextTokens;
  final int? autoCompactAtTokens;
  final bool autoCompact;
  final bool isCompacting;
  final bool isCompactionQueued;
  final String? errorMessage;

  @override
  bool operator ==(Object other) =>
      other is AgentContextUsage &&
      modelId == other.modelId &&
      estimatedTokens == other.estimatedTokens &&
      reportedInputTokens == other.reportedInputTokens &&
      maxContextTokens == other.maxContextTokens &&
      autoCompactAtTokens == other.autoCompactAtTokens &&
      autoCompact == other.autoCompact &&
      isCompacting == other.isCompacting &&
      isCompactionQueued == other.isCompactionQueued &&
      errorMessage == other.errorMessage;
  @override
  int get hashCode => Object.hash(
    modelId,
    estimatedTokens,
    reportedInputTokens,
    maxContextTokens,
    autoCompactAtTokens,
    autoCompact,
    isCompacting,
    isCompactionQueued,
    errorMessage,
  );
}

class AgentUiRunState {
  const AgentUiRunState({
    this.phase = AgentUiPhase.idle,
    this.runId,
    this.replyTargetMessageId,
    this.streamingText = '',
    this.errorMessage,
    this.providerErrorDetails,
    this.providerErrorResponseBody,
    this.providerErrorMetadata,
    this.pendingApproval,
    this.recoveryRequired = false,
    this.modelSelection,
    this.requiresModelSelection = false,
    this.contextUsage,
    this.operations = const [],
  });

  final AgentUiPhase phase;

  /// Application-owned run identity, including text-only reply replacement.
  final String? runId;

  /// Existing reply slot receiving this run's streaming text. Ordinary sends
  /// have no target and append at the end of the transcript.
  final String? replyTargetMessageId;

  /// Current, not-yet-persisted assistant text; no simulated messages.
  final String streamingText;

  /// The host must redact secrets before supplying a user-facing error.
  final String? errorMessage;

  /// Bounded, credential-redacted API response details for the current run.
  /// Kept separate from stable error codes and never treated as Markdown.
  final String? providerErrorDetails;
  final String? providerErrorResponseBody;
  final String? providerErrorMetadata;
  final AgentUiApproval? pendingApproval;
  final bool recoveryRequired;
  final AgentModelSelection? modelSelection;
  final bool requiresModelSelection;
  final AgentContextUsage? contextUsage;
  final List<AgentOperationUpdate> operations;

  bool get isActive =>
      phase == AgentUiPhase.running ||
      phase == AgentUiPhase.waitingApproval ||
      phase == AgentUiPhase.waitingUser ||
      contextUsage?.isCompacting == true;
}

class AgentUiState {
  /// Runtime snapshots read the authoritative conversation projections on
  /// demand. Streaming notifications belong to watchConversation, not this
  /// configuration listenable.
  AgentUiState.live({
    this.enabled = false,
    this.configured = false,
    this.maintenance = false,
    this.defaultMode = AgentPermissionMode.ask,
    List<AgentModelConfig> availableModels = const [],
    this.defaultModelSelection,
    Map<String, AgentModelSelection> modelSelections = const {},
    required Map<String, AgentUiRunState> runs,
  }) : runs = UnmodifiableMapView(runs),
       availableModels = List.unmodifiable(availableModels),
       modelSelections = Map.unmodifiable(modelSelections);

  AgentUiState({
    this.enabled = false,
    this.configured = false,
    this.maintenance = false,
    this.defaultMode = AgentPermissionMode.ask,
    List<AgentModelConfig> availableModels = const [],
    this.defaultModelSelection,
    Map<String, AgentModelSelection> modelSelections = const {},
    Map<String, AgentUiRunState> runs = const {},
  }) : runs = Map.unmodifiable(runs),
       availableModels = List.unmodifiable(availableModels),
       modelSelections = Map.unmodifiable(modelSelections);

  final bool enabled;
  final bool configured;
  final bool maintenance;
  final AgentPermissionMode defaultMode;
  final Map<String, AgentUiRunState> runs;
  final List<AgentModelConfig> availableModels;
  final AgentModelSelection? defaultModelSelection;
  final Map<String, AgentModelSelection> modelSelections;

  AgentModelSelection? selectionFor(String conversationId) =>
      modelSelections[conversationId] ?? defaultModelSelection;

  AgentUiRunState runFor(String conversationId) =>
      runs[conversationId] ?? const AgentUiRunState();
}

/// Runtime-owned actions. This view never manufactures a tool result, grants
/// an approval, stores a credential, or initiates a model request by itself.
abstract class AgentUiDelegate {
  ValueListenable<AgentUiState> get state;
  Future<void> setConversationActive(
    Object owner,
    String? conversationId,
  ) async {}

  /// Hosts with per-conversation publication can return their own listenable.
  /// The default adapter is owned and disposed by the requesting view.
  ValueListenable<AgentUiRunState> watchConversation(String conversationId) =>
      AgentConversationRunListenable(state, conversationId);

  Future<void> compactContext(String conversationId) async {}

  /// The host persists the user message and clears the accepted draft. It may
  /// complete this future after acceptance or after the whole run.
  Future<void> send(String conversationId, String text);
  Future<void> queueFollowUp(String conversationId, String text) =>
      send(conversationId, text);
  Future<void> steer(String conversationId, String text) =>
      send(conversationId, text);
  Future<void> continueConversation(String conversationId) async {}
  int pendingInputCount(String conversationId) => 0;
  bool canManageQueuedInput(String conversationId, String inputId) => false;
  Future<void> restoreQueuedInput(
    String conversationId,
    ConversationMessage input, {
    void Function()? validate,
  }) => Future.error(
    const OperationProblem(
      OperationErrorCode.unsupported,
      'This host cannot edit queued input.',
    ),
  );
  Future<void> cancelQueuedInput(
    String conversationId,
    ConversationMessage input, {
    void Function()? validate,
  }) => Future.error(
    const OperationProblem(
      OperationErrorCode.unsupported,
      'This host cannot cancel queued input.',
    ),
  );
  Future<void> setArchived(String conversationId, bool archived) async {}
  Future<void> stop(String conversationId);
  Future<void> approve(String conversationId, String planId);
  Future<void> reject(String conversationId, String planId);

  Future<void> answerQuestion(
    String conversationId,
    String questionId,
    List<AgentQuestionAnswer> answers,
  ) async {}
  Future<void> dismissQuestion(
    String conversationId,
    String questionId,
  ) async {}

  /// Applied immediately by the host so tightening a policy also affects an
  /// in-flight run. The host persists the conversation's selected mode.
  Future<void> setMode(String conversationId, AgentPermissionMode mode);

  /// Persists the next request's selection without changing an active run.
  /// An explicit new selection also repairs queued requests whose old choice
  /// is no longer enabled; continuing them remains a separate user action.
  Future<void> setModelSelection(
    String conversationId,
    AgentModelSelection selection,
  ) async {}
  void openSettings();
}

class AgentConversationRunListenable extends ChangeNotifier
    implements ValueListenable<AgentUiRunState> {
  AgentConversationRunListenable(this.source, this.conversationId)
    : _value = source.value.runFor(conversationId) {
    source.addListener(_changed);
  }

  final ValueListenable<AgentUiState> source;
  final String conversationId;
  AgentUiRunState _value;

  @override
  AgentUiRunState get value => _value;

  void _changed() {
    final next = source.value.runFor(conversationId);
    if (identical(next, _value)) return;
    _value = next;
    notifyListeners();
  }

  @override
  void dispose() {
    source.removeListener(_changed);
    super.dispose();
  }
}
