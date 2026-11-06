import '../../utils/time_utils.dart' show tryParseStrictIsoDateTime;
import '../provider/provider_models.dart';

class AgentQuestionOption {
  AgentQuestionOption({
    required this.id,
    required this.label,
    this.description,
  }) {
    _text(id, 'option.id', 128);
    _text(label, 'option.label', 240);
    if (description != null) _text(description, 'option.description', 1000);
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
      id: _text(json['id'], 'option.id', 128),
      label: _text(json['label'], 'option.label', 240),
      description: json['description'] == null
          ? null
          : _text(json['description'], 'option.description', 1000),
    );
  }
}

class AgentQuestionPrompt {
  AgentQuestionPrompt({
    required this.id,
    required this.question,
    Iterable<AgentQuestionOption> options = const [],
    this.multiple = false,
  }) : options = List.unmodifiable(options) {
    _text(id, 'question.id', 128);
    _text(question, 'question', maxQuestionLength);
    if (this.options.length > maxOptions ||
        this.options.map((option) => option.id).toSet().length !=
            this.options.length) {
      throw const FormatException('Invalid question options.');
    }
  }

  static const maxOptions = 12;
  static const maxQuestionLength = 2000;

  final String id;
  final String question;
  final List<AgentQuestionOption> options;
  final bool multiple;

  Map<String, Object?> toJson() => {
    'id': id,
    'question': question,
    'options': options.map((option) => option.toJson()).toList(),
    'multiple': multiple,
  };

  factory AgentQuestionPrompt.fromJson(Map<String, Object?> json) {
    _keys(json, const {'id', 'question', 'options', 'multiple'});
    return AgentQuestionPrompt(
      id: _text(json['id'], 'question.id', 128),
      question: _text(json['question'], 'question', maxQuestionLength),
      options: json.containsKey('options')
          ? _list(
              json['options'],
              'options',
              maxOptions,
            ).map((option) => AgentQuestionOption.fromJson(_object(option)))
          : const [],
      multiple: _optionalBool(json, 'multiple'),
    );
  }
}

class AgentQuestionAnswer {
  AgentQuestionAnswer({
    required this.questionId,
    Iterable<String> optionIds = const [],
    this.text = '',
  }) : optionIds = List.unmodifiable(optionIds) {
    _text(questionId, 'answer.questionId', 128);
    _text(text, 'answer.text', maxTextLength, allowEmpty: true);
    for (final id in this.optionIds) {
      _text(id, 'answer.optionId', 128);
    }
    if (this.optionIds.length > AgentQuestionPrompt.maxOptions ||
        this.optionIds.toSet().length != this.optionIds.length ||
        (this.optionIds.isEmpty && text.trim().isEmpty)) {
      throw const FormatException('An answer needs selected options or text.');
    }
  }

  static const maxTextLength = 4000;

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
      questionId: _text(json['questionId'], 'answer.questionId', 128),
      optionIds: json.containsKey('optionIds')
          ? _list(
              json['optionIds'],
              'optionIds',
              AgentQuestionPrompt.maxOptions,
            ).map((id) => _text(id, 'answer.optionId', 128))
          : const [],
      text: json.containsKey('text')
          ? _text(json['text'], 'answer.text', maxTextLength, allowEmpty: true)
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
    _text(id, 'request.id', 256);
    _text(toolCallId, 'request.toolCallId', 256);
    _text(runId, 'request.runId', 256);
    _text(requestMessageId, 'request.requestMessageId', 256);
    _text(connectionFingerprint, 'request.connectionFingerprint', 256);
    if (datasetGeneration != null) {
      _text(datasetGeneration, 'request.datasetGeneration', 256);
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

  static const maxQuestions = 5;

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
      _text(json['createdAt'], 'request.createdAt', 64),
    );
    if (createdAt == null) {
      throw const FormatException('Invalid question creation time.');
    }
    return AgentQuestionRequest(
      id: _text(json['id'], 'request.id', 256),
      toolCallId: _text(json['toolCallId'], 'request.toolCallId', 256),
      runId: _text(json['runId'], 'request.runId', 256),
      requestMessageId: _text(
        json['requestMessageId'],
        'request.requestMessageId',
        256,
      ),
      createdAt: createdAt,
      connectionFingerprint: _text(
        json['connectionFingerprint'],
        'request.connectionFingerprint',
        256,
      ),
      datasetGeneration: json['datasetGeneration'] == null
          ? null
          : _text(json['datasetGeneration'], 'request.datasetGeneration', 256),
      contextReferenceDigest: json['contextReferenceDigest'] == null
          ? null
          : _text(
              json['contextReferenceDigest'],
              'request.contextReferenceDigest',
              64,
            ),
      questions: _list(
        json['questions'],
        'questions',
        maxQuestions,
      ).map((question) => AgentQuestionPrompt.fromJson(_object(question))),
      answers: json['answers'] == null
          ? null
          : _list(
              json['answers'],
              'answers',
              maxQuestions,
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
    AgentQuestionRequest.maxQuestions,
  ).map((question) => AgentQuestionPrompt.fromJson(_object(question))).toList();
  _validateQuestions(questions);
  return List.unmodifiable(questions);
}

final ToolDefinition agentAskUserTool = ToolDefinition(
  name: 'ask_user',
  description:
      'Ask the user to clarify a choice, missing information or an ambiguous goal. '
      'Present up to five questions with optional choices. Free text is always supported. '
      'User answers provide task input and never grant permission for an operation.',
  parameters: {
    'type': 'object',
    'additionalProperties': false,
    'required': ['questions'],
    'properties': {
      'questions': {
        'type': 'array',
        'minItems': 1,
        'maxItems': AgentQuestionRequest.maxQuestions,
        'items': {
          'type': 'object',
          'additionalProperties': false,
          'required': ['id', 'question'],
          'properties': {
            'id': {'type': 'string', 'minLength': 1, 'maxLength': 128},
            'question': {
              'type': 'string',
              'minLength': 1,
              'maxLength': AgentQuestionPrompt.maxQuestionLength,
            },
            'multiple': {'type': 'boolean', 'default': false},
            'options': {
              'type': 'array',
              'maxItems': AgentQuestionPrompt.maxOptions,
              'items': {
                'type': 'object',
                'additionalProperties': false,
                'required': ['id', 'label'],
                'properties': {
                  'id': {'type': 'string', 'minLength': 1, 'maxLength': 128},
                  'label': {'type': 'string', 'minLength': 1, 'maxLength': 240},
                  'description': {
                    'type': ['string', 'null'],
                    'minLength': 1,
                    'maxLength': 1000,
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
      questions.length > AgentQuestionRequest.maxQuestions ||
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
        answer.optionIds.any(
          (id) => !question.options.any((option) => option.id == id),
        )) {
      throw const FormatException('The answer does not match the question.');
    }
  }
}

String _text(Object? value, String field, int max, {bool allowEmpty = false}) {
  if (value is! String ||
      value.length > max ||
      (!allowEmpty && value.trim().isEmpty)) {
    throw FormatException('Invalid $field.');
  }
  return value;
}

List<Object?> _list(Object? value, String field, int max) {
  if (value is! List || value.length > max) {
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

bool _optionalBool(Map<String, Object?> value, String key) {
  if (!value.containsKey(key)) return false;
  final result = value[key];
  if (result is! bool) throw FormatException('Invalid $key.');
  return result;
}
