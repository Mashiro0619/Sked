import 'dart:convert';

import '../conversations/conversation_models.dart';
import '../history/conversation_history.dart';
import '../interactions/agent_question.dart';

/// Projects task context from the active transcript supplied by the caller.
/// Rebuild after steering, reply replacement, or history redo. Archived
/// versions and model-written summaries do not supply checkpoint authority.
Map<String, Object?> buildConversationTaskCheckpoint(
  List<ConversationMessage> messages, {
  required Set<String> omittedMessageIds,
  Iterable<ConversationTurn> turns = const [],
  int executionHistoryStart = 0,
  int maxExcerptCharacters = 1200,
  int maxDecisionExchanges = 8,
  int maxObjectReferences = 24,
  int maxClarificationCharacters = 24000,
}) {
  if (executionHistoryStart < 0 ||
      executionHistoryStart > messages.length ||
      maxExcerptCharacters < 16 ||
      maxDecisionExchanges < 0 ||
      maxObjectReferences < 0 ||
      maxClarificationCharacters < 0) {
    throw ArgumentError('Invalid task checkpoint limits.');
  }
  final turnIds = <String, String>{
    for (final turn in turns)
      if (turn.ownershipComplete)
        for (final id in turn.messageIds) id: turn.id,
  };
  final users = <Map<String, Object?>>[];
  final exchanges = <Map<String, Object?>>[];
  final clarifications = <Map<String, Object?>>[];
  final references = <Map<String, Object?>>[];
  final calls = <String, ConversationToolCall>{};
  var exchangeCount = 0;
  var clarificationCount = 0;
  var referenceCount = 0;
  ConversationMessage? previousAssistant;
  var previousAssistantImported = false;
  ConversationMessage? latestProposal;

  Map<String, Object?> source(ConversationMessage message, int index) => {
    'messageId': message.id,
    if (index < executionHistoryStart) 'importedHistory': true,
    if (index >= executionHistoryStart && turnIds[message.id] != null)
      'turnId': turnIds[message.id],
  };

  void addReference(
    Map<String, Object?> value,
    ConversationMessage message,
    ConversationToolCall call,
    String origin,
    String location,
  ) {
    final fields = <String, Object?>{};
    final omittedFields = <String>[];
    for (final key in const [
      'id',
      'kind',
      'resourceId',
      'parentId',
      'timetableId',
      'calendarId',
      'courseId',
      'scheduleId',
      'eventId',
      'sectionSetId',
      'selectionRef',
      'destinationParentId',
    ]) {
      final item = value[key];
      if (item is! String || item.isEmpty) {
        continue;
      }
      if (item.length > 256) {
        omittedFields.add(key);
      } else {
        fields[key] = item;
      }
    }
    if (fields.isEmpty && omittedFields.isEmpty) {
      return;
    }
    referenceCount++;
    references.add({
      'messageId': message.id,
      'toolCallId': call.id,
      'toolName': call.name,
      'source': origin,
      'location': location,
      'fields': fields,
      if (omittedFields.isNotEmpty) 'omittedFields': omittedFields,
    });
    if (references.length > maxObjectReferences) {
      references.removeAt(0);
    }
  }

  void collectReferences(
    Map<String, Object?> value,
    ConversationMessage message,
    ConversationToolCall call,
    String origin,
  ) {
    addReference(value, message, call, origin, 'root');
    if (value['target'] case final Map<String, Object?> target) {
      addReference(
        {'kind': value['kind'], ...target},
        message,
        call,
        origin,
        'target',
      );
    }
    for (final key in const ['items', 'commands']) {
      if (value[key] case final List items) {
        for (var index = 0; index < items.length; index++) {
          final item = items[index];
          if (item is! Map<String, Object?>) {
            continue;
          }
          addReference(item, message, call, origin, '$key[$index]');
          if (item['target'] case final Map<String, Object?> target) {
            addReference(
              {'kind': item['kind'], ...target},
              message,
              call,
              origin,
              '$key[$index].target',
            );
          }
        }
      }
    }
  }

  for (var index = 0; index < messages.length; index++) {
    final message = messages[index];
    final omitted = omittedMessageIds.contains(message.id);
    if (message.role == ConversationRole.user) {
      if (omitted) {
        users.add({
          ...source(message, index),
          'text': message.text,
          if (message.attachmentIds.isNotEmpty) ...{
            'attachmentIds': message.attachmentIds,
            'attachmentsRequireReattachment': true,
          },
        });
      }
      final assistant = previousAssistant;
      if (assistant != null &&
          (omitted || omittedMessageIds.contains(assistant.id))) {
        exchangeCount++;
        exchanges.add({
          'source': 'recordedDialogue',
          'assistantMessageId': assistant.id,
          if (previousAssistantImported) 'assistantImportedHistory': true,
          'assistant': _excerpt(assistant.text, maxExcerptCharacters),
          ...source(message, index),
          'user': _excerpt(message.text, maxExcerptCharacters),
        });
        if (exchanges.length > maxDecisionExchanges) {
          exchanges.removeAt(0);
        }
      }
      previousAssistant = null;
      latestProposal = null;
    } else if (message.role == ConversationRole.assistant &&
        message.text.trim().isNotEmpty) {
      previousAssistant = message;
      previousAssistantImported = index < executionHistoryStart;
      if (index >= executionHistoryStart) {
        latestProposal = message;
      }
    }
    if (index < executionHistoryStart) {
      continue;
    }
    for (final call in message.toolCalls) {
      calls[call.id] = call;
      if (!omitted || call.name == 'ask_user') {
        continue;
      }
      final arguments = _jsonObject(call.arguments);
      if (arguments != null) {
        collectReferences(arguments, message, call, 'toolArguments');
      }
    }
    if (!omitted || message.role != ConversationRole.tool) {
      continue;
    }
    final call = calls[message.toolCallId];
    if (call == null) {
      continue;
    }
    final result = _jsonObject(message.text);
    if (result == null) {
      continue;
    }
    if (call.name == 'ask_user') {
      final clarification = _clarification(call, result);
      if (clarification != null ||
          const {'answered', 'dismissed'}.contains(result['status'])) {
        clarificationCount++;
        clarifications.add({
          ...source(message, index),
          'toolCallId': call.id,
          'source': 'recordedUserInteraction',
          if (clarification != null)
            ...clarification
          else ...{
            'status': 'unavailable',
            'reason': 'invalidRecordedQuestion',
          },
        });
        if (clarifications.length > maxDecisionExchanges) {
          clarifications.removeAt(0);
        }
      }
    } else if (!const {
      'failed',
      'not_executed',
      'unknown',
    }.contains(result['status'])) {
      collectReferences(result, message, call, 'recordedToolResult');
    }
  }

  // Keep each structured question and answer complete, or retain its source
  // reference with an explicit omission marker. Newer answers get room first.
  var clarificationCharacters = 0;
  for (var index = clarifications.length - 1; index >= 0; index--) {
    final value = clarifications[index];
    final size = jsonEncode(value).length;
    if (clarificationCharacters + size <= maxClarificationCharacters) {
      clarificationCharacters += size;
      value['truncated'] = false;
    } else {
      clarifications[index] = {
        for (final key in const [
          'messageId',
          'turnId',
          'toolCallId',
          'source',
          'questionId',
          'status',
        ])
          if (value.containsKey(key)) key: value[key],
        'truncated': true,
        'originalCharacters': size,
      };
    }
  }
  return {
    'source': 'activeConversation',
    'userRequests': users,
    'decisionExchanges': exchanges,
    'omittedDecisionExchanges': exchangeCount - exchanges.length,
    'clarifications': clarifications,
    'omittedClarifications': clarificationCount - clarifications.length,
    'objectReferences': references,
    'omittedObjectReferences': referenceCount - references.length,
    if (latestProposal != null && omittedMessageIds.contains(latestProposal.id))
      'latestAssistantPlan': {
        'messageId': latestProposal.id,
        'source': 'assistantProposal',
        ..._excerpt(latestProposal.text, maxExcerptCharacters),
      },
  };
}

Map<String, Object?> _excerpt(String text, int limit) {
  if (text.length <= limit) {
    return {'text': text, 'truncated': false};
  }
  const marker = '\n[…]\n';
  final available = limit - marker.length;
  var head = available ~/ 2;
  var tail = text.length - (available - head);
  // Keep UTF-16 surrogate pairs intact at both excerpt boundaries.
  if (text.codeUnitAt(head - 1) >= 0xd800 &&
      text.codeUnitAt(head - 1) <= 0xdbff) {
    head--;
  }
  if (text.codeUnitAt(tail) >= 0xdc00 && text.codeUnitAt(tail) <= 0xdfff) {
    tail++;
  }
  return {
    'text': '${text.substring(0, head)}$marker${text.substring(tail)}',
    'truncated': true,
    'originalCharacters': text.length,
  };
}

Map<String, Object?>? _jsonObject(String text) {
  try {
    final value = jsonDecode(text);
    return value is Map<String, Object?> ? value : null;
  } on FormatException {
    return null;
  }
}

Map<String, Object?>? _clarification(
  ConversationToolCall call,
  Map<String, Object?> result,
) {
  try {
    if (!const {'answered', 'dismissed'}.contains(result['status']) ||
        result['questionId'] is! String ||
        (result['questionId'] as String).isEmpty ||
        (result['questionId'] as String).length > 256 ||
        result['answers'] is! List) {
      return null;
    }
    final arguments = _jsonObject(call.arguments);
    if (arguments == null) {
      return null;
    }
    final questions = parseAgentQuestionPrompts(arguments);
    final originalQuestions = questions
        .map((question) => question.toJson())
        .toList();
    if (result.containsKey('questions')) {
      final recorded = parseAgentQuestionPrompts({
        'questions': result['questions'],
      });
      if (jsonEncode(originalQuestions) !=
          jsonEncode(recorded.map((question) => question.toJson()).toList())) {
        return null;
      }
    }
    final rawAnswers = result['answers'] as List;
    if (rawAnswers.length > AgentQuestionRequest.maxQuestions) {
      return null;
    }
    final answers = <AgentQuestionAnswer>[];
    for (final value in rawAnswers) {
      if (value is! Map<String, Object?>) {
        return null;
      }
      answers.add(AgentQuestionAnswer.fromJson(value));
    }
    if (result['status'] == 'dismissed') {
      if (answers.isNotEmpty) {
        return null;
      }
    } else {
      if (answers.length != questions.length ||
          answers.map((answer) => answer.questionId).toSet().length !=
              answers.length) {
        return null;
      }
      final byId = {for (final question in questions) question.id: question};
      for (final answer in answers) {
        final question = byId[answer.questionId];
        if (question == null ||
            (!question.multiple && answer.optionIds.length > 1) ||
            answer.optionIds.any(
              (id) => !question.options.any((option) => option.id == id),
            )) {
          return null;
        }
      }
    }
    return {
      'questionId': result['questionId'],
      'status': result['status'],
      'questions': originalQuestions,
      'answers': answers.map((answer) => answer.toJson()).toList(),
    };
  } on FormatException {
    return null;
  }
}
