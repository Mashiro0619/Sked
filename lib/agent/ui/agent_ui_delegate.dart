import 'package:flutter/foundation.dart';

import '../../application/operation_contracts.dart';
import '../../models/agent_settings.dart';

enum AgentUiPhase { idle, running, waitingApproval, stopped, failed }

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

class AgentUiRunState {
  const AgentUiRunState({
    this.phase = AgentUiPhase.idle,
    this.runId,
    this.replyTargetMessageId,
    this.streamingText = '',
    this.errorMessage,
    this.providerErrorDetails,
    this.pendingApproval,
    this.recoveryRequired = false,
    this.modelSelection,
    this.requiresModelSelection = false,
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
  final AgentUiApproval? pendingApproval;
  final bool recoveryRequired;
  final AgentModelSelection? modelSelection;
  final bool requiresModelSelection;

  bool get isActive =>
      phase == AgentUiPhase.running || phase == AgentUiPhase.waitingApproval;
}

class AgentUiState {
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

  /// The host persists the user message and clears the accepted draft. It may
  /// complete this future after acceptance or after the whole run.
  Future<void> send(String conversationId, String text);
  Future<void> queueFollowUp(String conversationId, String text) =>
      send(conversationId, text);
  Future<void> steer(String conversationId, String text) =>
      send(conversationId, text);
  Future<void> continueConversation(String conversationId) async {}
  int pendingInputCount(String conversationId) => 0;
  Future<void> setArchived(String conversationId, bool archived) async {}
  Future<void> stop(String conversationId);
  Future<void> approve(String conversationId, String planId);
  Future<void> reject(String conversationId, String planId);

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
