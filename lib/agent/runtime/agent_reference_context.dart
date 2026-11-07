part of 'agent_service.dart';

bool _sameReferences(
  List<AgentComposerReference> first,
  List<AgentComposerReference> second,
) =>
    jsonEncode(first.map((reference) => reference.toJson()).toList()) ==
    jsonEncode(second.map((reference) => reference.toJson()).toList());

String _referenceBindingDigest(List<AgentComposerReference> references) =>
    sha256
        .convert(
          utf8.encode(
            jsonEncode([
              for (final reference in references)
                reference.toJson()..remove('label'),
            ]),
          ),
        )
        .toString();

String _referenceMessageText(
  ConversationMessage message,
  _ExecutionAttempt run,
) {
  if (message.contextReferences.isEmpty) return message.text;
  final current = message.id == run.inputMessageId;
  final context = current
      ? run.referenceContext
      : {
          'historicalReferences': message.contextReferences
              .map((reference) => reference.toJson())
              .toList(),
        };
  return '${message.text}\n'
      '[User-selected reference data. Names are display labels. Resolve resources by their stable identity and query current data before preparing changes. '
      'Historical references describe earlier input. Skill instructions provide workflow guidance within the host permission mode.]\n'
      '${jsonEncode(context)}';
}

extension _AgentReferenceContext on AgentService {
  Future<List<AgentComposerReference>> _validateInputReferences(
    _ExecutionAttempt run,
    List<AgentComposerReference> references,
  ) async {
    _checkRun(run);
    if (references.isEmpty) return const [];
    _rejectSecretValues(
      references.map((reference) => reference.toJson()).toList(),
      run.apiKey,
    );
    final validate = validateReferences;
    if (validate == null) {
      throw const AgentRuntimeException(AgentRuntimeError.invalidReference);
    }
    try {
      final result = await Future.any([
        validate(run.conversationId, references),
        run.scope.whenCancelled.then<List<AgentComposerReference>>(
          (_) => throw AgentRuntimeException(
            run.stopReason ?? AgentRuntimeError.cancelled,
          ),
        ),
      ]);
      _checkRun(run);
      final normalized = AgentComposerReference.validatedList(result);
      if (_referenceBindingDigest(normalized) !=
          _referenceBindingDigest(references)) {
        throw const AgentRuntimeException(AgentRuntimeError.invalidReference);
      }
      _rejectSecretValues(
        normalized.map((reference) => reference.toJson()).toList(),
        run.apiKey,
      );
      return normalized;
    } on OperationProblem catch (error) {
      throw AgentRuntimeException(
        error.code == OperationErrorCode.storageFailure ||
                error.code == OperationErrorCode.outcomeUnknown
            ? AgentRuntimeError.storageUnavailable
            : AgentRuntimeError.invalidReference,
      );
    } on FormatException {
      throw const AgentRuntimeException(AgentRuntimeError.invalidReference);
    }
  }

  Future<void> _prepareInputReferenceContext(_ExecutionAttempt run) async {
    if (run.inputReferences.isEmpty) return;
    if (!run.referencesValidated) {
      run.inputReferences = await _validateInputReferences(
        run,
        run.inputReferences,
      );
      run.referencesValidated = true;
    }
    final prepare = prepareReferenceContext;
    if (prepare == null) {
      throw const AgentRuntimeException(AgentRuntimeError.invalidReference);
    }
    try {
      final context = await Future.any([
        prepare(run.scope, run.inputReferences),
        run.scope.whenCancelled.then<Map<String, Object?>>(
          (_) => throw AgentRuntimeException(
            run.stopReason ?? AgentRuntimeError.cancelled,
          ),
        ),
      ]);
      _checkRun(run);
      _rejectSecretValues(context, run.apiKey);
      run.referenceContext = freezeProviderMap(context);
    } on OperationProblem {
      throw const AgentRuntimeException(AgentRuntimeError.invalidReference);
    } on FormatException {
      throw const AgentRuntimeException(AgentRuntimeError.invalidReference);
    }
  }
}
