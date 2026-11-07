part of 'agent_service.dart';

/// The single in-memory owner of a conversation's active attempt and its
/// current/settled presentation. The global view reads this same record.
class ConversationExecution extends ChangeNotifier
    implements ValueListenable<AgentUiRunState> {
  ConversationExecution(this.conversationId);
  final String conversationId;
  _ExecutionAttempt? _attempt;
  AgentUiRunState _value = const AgentUiRunState();
  AgentUiRunState? _published;

  @override
  AgentUiRunState get value => _value;

  void _begin(_ExecutionAttempt value) {
    if (_attempt != null) {
      throw const AgentRuntimeException(AgentRuntimeError.busy);
    }
    _attempt = value;
  }

  void _finish(_ExecutionAttempt value) {
    if (identical(_attempt, value)) _attempt = null;
  }

  void transition(AgentUiRunState next) {
    _value = next;
  }

  void publish() {
    if (identical(_published, _value)) return;
    _published = _value;
    notifyListeners();
  }

  AgentContextUsage? get contextUsage => _value.contextUsage;
  set contextUsage(AgentContextUsage? next) =>
      _updateMetadata(context: next, requiresSelection: requiresModelSelection);
  bool get requiresModelSelection => _value.requiresModelSelection;
  set requiresModelSelection(bool next) =>
      _updateMetadata(context: contextUsage, requiresSelection: next);

  void _updateMetadata({
    AgentContextUsage? context,
    required bool requiresSelection,
  }) {
    if (context == _value.contextUsage &&
        requiresSelection == _value.requiresModelSelection) {
      return;
    }
    _value = AgentUiRunState(
      phase: _value.phase,
      runId: _value.runId,
      replyTargetMessageId: _value.replyTargetMessageId,
      streamingText: _value.streamingText,
      errorMessage: _value.errorMessage,
      providerErrorDetails: _value.providerErrorDetails,
      providerErrorResponseBody: _value.providerErrorResponseBody,
      providerErrorMetadata: _value.providerErrorMetadata,
      pendingApproval: _value.pendingApproval,
      recoveryRequired: _value.recoveryRequired,
      modelSelection: _value.modelSelection,
      requiresModelSelection: requiresSelection,
      contextUsage: context,
      operations: _value.operations,
    );
  }
}

class _ExecutionViews extends MapBase<String, AgentUiRunState> {
  _ExecutionViews(this.executions);
  final Map<String, ConversationExecution> executions;
  @override
  AgentUiRunState? operator [](Object? key) => executions[key]?.value;
  @override
  Iterable<String> get keys => executions.keys;
  @override
  void operator []=(String key, AgentUiRunState value) =>
      throw UnsupportedError('Execution views are read-only.');
  @override
  void clear() => throw UnsupportedError('Execution views are read-only.');
  @override
  AgentUiRunState? remove(Object? key) =>
      throw UnsupportedError('Execution views are read-only.');
}

class _ExecutionAttempt {
  _ExecutionAttempt({
    required this.id,
    required this.conversationId,
    required this.settings,
    this.modelSelection,
    this.pendingInputId,
    required this.endpoint,
    required this.fingerprint,
    required AgentPermissionMode mode,
    required DateTime startedAt,
    this.environment = const {},
    String? continuedFromRunId,
    this.hostAction = false,
    this.replyMessageId,
  }) : usage = ConversationRunUsage(
         id: id,
         startedAt: startedAt,
         kind: hostAction
             ? ConversationRunKind.host
             : ConversationRunKind.model,
         protocol: hostAction ? null : settings.protocol.name,
         model: hostAction ? null : settings.model,
         reasoningEffort: hostAction ? null : modelSelection?.reasoningEffort,
         continuedFromRunId: continuedFromRunId,
       ),
       scope = OperationScope(
         id: id,
         policy: OperationPolicy(enabled: settings.enabled, mode: mode),
       );
  final String id;
  final String conversationId;
  final AgentSettings settings;
  final AgentModelSelection? modelSelection;
  final String? pendingInputId;
  final Uri endpoint;
  final String fingerprint;
  final Map<String, Object?> environment;
  final bool hostAction;
  final String? replyMessageId;
  String? turnId;
  ConversationRunUsage usage;
  final issuedToolCallIds = <String>{};
  List<ToolDefinition> tools = const [];
  String? inputMessageId;
  List<AgentComposerReference> inputReferences = const [];
  Map<String, Object?> referenceContext = const {};
  bool referencesValidated = false;
  List<ContextEntry> contextEntries = const [];
  final operations = <String, AgentOperationUpdate>{};
  List<AgentOperationUpdate> operationSnapshot = const [];
  final OperationScope scope;
  final cancellation = ProviderCancellationToken();
  final settled = Completer<void>();
  final started = Completer<bool>();
  Future<void> get done => settled.future;
  bool accepted = false;
  bool succeeded = false;
  bool outcomeUnknown = false;
  String? failureCode;
  bool recoveryRequired = false;
  String? hostToolCallId;
  String apiKey = '';
  int toolCalls = 0;
  AgentRuntimeError? stopReason;
  _PendingApproval? approval;
  _PendingHttpTransport? httpApproval;
  ProviderToolCall? activeToolCall;
  _PendingUserQuestion? userQuestion;
}
