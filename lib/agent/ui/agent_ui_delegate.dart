import 'package:flutter/foundation.dart';

import '../../application/operation_contracts.dart';

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
    this.streamingText = '',
    this.errorMessage,
    this.pendingApproval,
    this.recoveryRequired = false,
  });

  final AgentUiPhase phase;

  /// Current, not-yet-persisted assistant text; no simulated messages.
  final String streamingText;

  /// The host must redact secrets before supplying a user-facing error.
  final String? errorMessage;
  final AgentUiApproval? pendingApproval;
  final bool recoveryRequired;

  bool get isActive =>
      phase == AgentUiPhase.running || phase == AgentUiPhase.waitingApproval;
}

class AgentUiState {
  AgentUiState({
    this.enabled = false,
    this.configured = false,
    this.maintenance = false,
    this.defaultMode = AgentPermissionMode.ask,
    Map<String, AgentUiRunState> runs = const {},
  }) : runs = Map.unmodifiable(runs);

  final bool enabled;
  final bool configured;
  final bool maintenance;
  final AgentPermissionMode defaultMode;
  final Map<String, AgentUiRunState> runs;

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
  void openSettings();
}
