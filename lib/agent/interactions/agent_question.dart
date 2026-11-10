import '../../utils/time_utils.dart' show tryParseStrictIsoDateTime;
import '../provider/provider_models.dart';

class AgentQuestionOption {
  AgentQuestionOption({
    required this.id,
    required this.label,
    this.description,
  }) {
    _text(id, 'option.id');
    _text(label, 'option.label');
    if (description != null) _text(description, 'option.description');
  }

  final String id;
  final String label;
  final String? description;

  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    if (description != null) 'description': description,
  };

  factory AgentQuestionOption.fromJson(Map<String, Object?> json) {
    _keys(json, const {'id', 'label', 'description'});
    return AgentQuestionOption(
      id: _text(json['id'], 'option.id'),
      label: _text(json['label'], 'option.label'),
      description: json['description'] == null
          ? null
          : _text(json['description'], 'option.description'),
    );
  }
}

class AgentQuestionPrompt {
  AgentQuestionPrompt({
    required this.id,
    required this.question,
    Iterable<AgentQuestionOption> options = const [],
    this.multiple = false,
    this.allowFreeText = true,
  }) : options = List.unmodifiable(options) {
    _text(id, 'question.id');
    _text(question, 'question');
    if (this.options.map((option) => option.id).toSet().length !=
        this.options.length) {
      throw const FormatException('Invalid question options.');
    }
  }

  final String id;
  final String question;
  final List<AgentQuestionOption> options;
  final bool multiple;
  final bool allowFreeText;

  Map<String, Object?> toJson() => {
    'id': id,
    'question': question,
    'options': options.map((option) => option.toJson()).toList(),
    'multiple': multiple,
    'allowFreeText': allowFreeText,
  };

  factory AgentQuestionPrompt.fromJson(Map<String, Object?> json) {
    _keys(json, const {
      'id',
      'question',
      'options',
      'multiple',
      'allowFreeText',
    });
    return AgentQuestionPrompt(
      id: _text(json['id'], 'question.id'),
      question: _text(json['question'], 'question'),
      options: json.containsKey('options')
          ? _list(
              json['options'],
              'options',
            ).map((option) => AgentQuestionOption.fromJson(_object(option)))
          : const [],
      multiple: _optionalBool(json, 'multiple'),
      allowFreeText: _optionalBool(json, 'allowFreeText', defaultValue: true),
    );
  }
}

class AgentQuestionAnswer {
  AgentQuestionAnswer({
    required this.questionId,
    Iterable<String> optionIds = const [],
    this.text = '',
  }) : optionIds = List.unmodifiable(optionIds) {
    _text(questionId, 'answer.questionId');
    _text(text, 'answer.text', allowEmpty: true);
    for (final id in this.optionIds) {
      _text(id, 'answer.optionId');
    }
    if (this.optionIds.toSet().length != this.optionIds.length ||
        (this.optionIds.isEmpty && text.trim().isEmpty)) {
      throw const FormatException('An answer needs selected options or text.');
    }
  }

  final String questionId;
  final List<String> optionIds;
  final String text;

  Map<String, Object?> toJson() => {
    'questionId': questionId,
    'optionIds': optionIds,
    'text': text,
  };

  factory AgentQuestionAnswer.fromJson(Map<String, Object?> json) {
    _keys(json, const {'questionId', 'optionIds', 'text'});
    return AgentQuestionAnswer(
      questionId: _text(json['questionId'], 'answer.questionId'),
      optionIds: json.containsKey('optionIds')
          ? _list(
              json['optionIds'],
              'optionIds',
            ).map((id) => _text(id, 'answer.optionId'))
          : const [],
      text: json.containsKey('text')
          ? _text(json['text'], 'answer.text', allowEmpty: true)
          : '',
    );
  }
}

/// One durable user interaction, bound to the original assistant tool call.
/// Resolving it records user input without granting execution permission.
class AgentQuestionRequest {
  AgentQuestionRequest({
    required this.id,
    required this.toolCallId,
    required this.runId,
    required this.requestMessageId,
    required this.createdAt,
    required this.connectionFingerprint,
    this.datasetGeneration,
    this.contextReferenceDigest,
    required Iterable<AgentQuestionPrompt> questions,
    Iterable<AgentQuestionAnswer>? answers,
    this.dismissed = false,
  }) : questions = List.unmodifiable(questions),
       answers = answers == null ? null : List.unmodifiable(answers) {
    _text(id, 'request.id');
    _text(toolCallId, 'request.toolCallId');
    _text(runId, 'request.runId');
    _text(requestMessageId, 'request.requestMessageId');
    _text(connectionFingerprint, 'request.connectionFingerprint');
    if (datasetGeneration != null) {
      _text(datasetGeneration, 'request.datasetGeneration');
    }
    if (contextReferenceDigest != null &&
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(contextReferenceDigest!)) {
      throw const FormatException('Invalid question context reference digest.');
    }
    _validateQuestions(this.questions);
    if (dismissed && this.answers != null) {
      throw const FormatException('A dismissed question cannot have answers.');
    }
    if (this.answers != null) _validateAnswers(this.questions, this.answers!);
  }

  final String id;
  final String toolCallId;
  final String runId;
  final String requestMessageId;
  final DateTime createdAt;
  final String connectionFingerprint;
  final String? datasetGeneration;
  final String? contextReferenceDigest;
  final List<AgentQuestionPrompt> questions;
  final List<AgentQuestionAnswer>? answers;
  final bool dismissed;

  bool get isResolved => answers != null || dismissed;

  AgentQuestionRequest withAnswers(Iterable<AgentQuestionAnswer> answers) {
    _requireUnresolved();
    return AgentQuestionRequest(
      id: id,
      toolCallId: toolCallId,
      runId: runId,
      requestMessageId: requestMessageId,
      createdAt: createdAt,
      connectionFingerprint: connectionFingerprint,
      datasetGeneration: datasetGeneration,
      contextReferenceDigest: contextReferenceDigest,
      questions: questions,
      answers: answers,
    );
  }

  AgentQuestionRequest withDismissed() {
    _requireUnresolved();
    return AgentQuestionRequest(
      id: id,
      toolCallId: toolCallId,
      runId: runId,
      requestMessageId: requestMessageId,
      createdAt: createdAt,
      connectionFingerprint: connectionFingerprint,
      datasetGeneration: datasetGeneration,
      contextReferenceDigest: contextReferenceDigest,
      questions: questions,
      dismissed: true,
    );
  }

  void _requireUnresolved() {
    if (isResolved) {
      throw const FormatException('The question has already been resolved.');
    }
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'toolCallId': toolCallId,
    'runId': runId,
    'requestMessageId': requestMessageId,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'connectionFingerprint': connectionFingerprint,
    if (datasetGeneration != null) 'datasetGeneration': datasetGeneration,
    if (contextReferenceDigest != null)
      'contextReferenceDigest': contextReferenceDigest,
    'questions': questions.map((question) => question.toJson()).toList(),
    if (answers != null)
      'answers': answers!.map((answer) => answer.toJson()).toList(),
    if (dismissed) 'dismissed': true,
  };

  factory AgentQuestionRequest.fromJson(Map<String, Object?> json) {
    _keys(json, const {
      'id',
      'toolCallId',
      'runId',
      'requestMessageId',
      'createdAt',
      'connectionFingerprint',
      'datasetGeneration',
      'contextReferenceDigest',
      'questions',
      'answers',
      'dismissed',
    });
    final createdAt = tryParseStrictIsoDateTime(
      _text(json['createdAt'], 'request.createdAt'),
    );
    if (createdAt == null) {
      throw const FormatException('Invalid question creation time.');
    }
    return AgentQuestionRequest(
      id: _text(json['id'], 'request.id'),
      toolCallId: _text(json['toolCallId'], 'request.toolCallId'),
      runId: _text(json['runId'], 'request.runId'),
      requestMessageId: _text(
        json['requestMessageId'],
        'request.requestMessageId',
      ),
      createdAt: createdAt,
      connectionFingerprint: _text(
        json['connectionFingerprint'],
        'request.connectionFingerprint',
      ),
      datasetGeneration: json['datasetGeneration'] == null
          ? null
          : _text(json['datasetGeneration'], 'request.datasetGeneration'),
      contextReferenceDigest: json['contextReferenceDigest'] == null
          ? null
          : _text(
              json['contextReferenceDigest'],
              'request.contextReferenceDigest',
            ),
      questions: _list(
        json['questions'],
        'questions',
      ).map((question) => AgentQuestionPrompt.fromJson(_object(question))),
      answers: json['answers'] == null
          ? null
          : _list(
              json['answers'],
              'answers',
            ).map((answer) => AgentQuestionAnswer.fromJson(_object(answer))),
      dismissed: _optionalBool(json, 'dismissed'),
    );
  }
}

List<AgentQuestionPrompt> parseAgentQuestionPrompts(
  Map<String, Object?> arguments,
) {
  _keys(arguments, const {'questions'});
  final questions = _list(
    arguments['questions'],
    'questions',
  ).map((question) => AgentQuestionPrompt.fromJson(_object(question))).toList();
  _validateQuestions(questions);
  return List.unmodifiable(questions);
}

final ToolDefinition agentAskUserTool = ToolDefinition(
  name: 'ask_user',
  description:
      'Ask the user to clarify a choice, missing information or an ambiguous goal. '
      'Present questions with optional choices. Free text is supported by default; '
      'set allowFreeText to false to accept only the listed choices. '
      'User answers provide task input and never grant permission for an operation.',
  parameters: {
    'type': 'object',
    'additionalProperties': false,
    'required': ['questions'],
    'properties': {
      'questions': {
        'type': 'array',
        'minItems': 1,
        'items': {
          'type': 'object',
          'additionalProperties': false,
          'required': ['id', 'question'],
          'properties': {
            'id': {'type': 'string', 'minLength': 1},
            'question': {'type': 'string', 'minLength': 1},
            'multiple': {'type': 'boolean', 'default': false},
            'allowFreeText': {'type': 'boolean', 'default': true},
            'options': {
              'type': 'array',
              'items': {
                'type': 'object',
                'additionalProperties': false,
                'required': ['id', 'label'],
                'properties': {
                  'id': {'type': 'string', 'minLength': 1},
                  'label': {'type': 'string', 'minLength': 1},
                  'description': {
                    'type': ['string', 'null'],
                    'minLength': 1,
                  },
                },
              },
            },
          },
        },
      },
    },
  },
);

void _validateQuestions(List<AgentQuestionPrompt> questions) {
  if (questions.isEmpty ||
      questions.map((question) => question.id).toSet().length !=
          questions.length) {
    throw const FormatException('Invalid question identities or count.');
  }
}

void _validateAnswers(
  List<AgentQuestionPrompt> questions,
  List<AgentQuestionAnswer> answers,
) {
  if (answers.length != questions.length ||
      answers.map((answer) => answer.questionId).toSet().length !=
          answers.length) {
    throw const FormatException('Every question needs exactly one answer.');
  }
  final questionsById = {
    for (final question in questions) question.id: question,
  };
  for (final answer in answers) {
    final question = questionsById[answer.questionId];
    if (question == null ||
        (!question.multiple && answer.optionIds.length > 1) ||
        (!question.allowFreeText && answer.text.isNotEmpty) ||
        answer.optionIds.any(
          (id) => !question.options.any((option) => option.id == id),
        )) {
      throw const FormatException('The answer does not match the question.');
    }
  }
}

String _text(Object? value, String field, {bool allowEmpty = false}) {
  if (value is! String || (!allowEmpty && value.trim().isEmpty)) {
    throw FormatException('Invalid $field.');
  }
  return value;
}

List<Object?> _list(Object? value, String field) {
  if (value is! List) {
    throw FormatException('Invalid $field.');
  }
  return value;
}

Map<String, Object?> _object(Object? value) {
  if (value is! Map<String, Object?>) {
    throw const FormatException('Expected a question object.');
  }
  return value;
}

void _keys(Map<String, Object?> value, Set<String> allowed) {
  if (value.keys.any((key) => !allowed.contains(key))) {
    throw const FormatException('Unknown question field.');
  }
}

bool _optionalBool(
  Map<String, Object?> value,
  String key, {
  bool defaultValue = false,
}) {
  if (!value.containsKey(key)) return defaultValue;
  final result = value[key];
  if (result is! bool) throw FormatException('Invalid $key.');
  return result;
}
