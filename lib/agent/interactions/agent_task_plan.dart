import 'dart:convert';

import '../conversations/conversation_models.dart';
import '../provider/provider_models.dart';

enum AgentTaskStepStatus { pending, inProgress, completed, blocked }

class AgentTaskPlanStep {
  AgentTaskPlanStep({
    required this.id,
    required this.title,
    required this.status,
    this.detail,
    Iterable<String> operationIds = const [],
  }) : operationIds = List.unmodifiable(operationIds) {
    _text(id, 128);
    _text(title, maxTitleLength);
    if (detail != null) {
      _text(detail, maxDetailLength);
    }
    if (this.operationIds.length > maxOperationIds ||
        this.operationIds.toSet().length != this.operationIds.length) {
      throw const FormatException('Invalid task plan operation identities.');
    }
    for (final operationId in this.operationIds) {
      _text(operationId, 256);
    }
  }

  static const maxTitleLength = 240;
  static const maxDetailLength = 2000;
  static const maxOperationIds = 32;

  final String id;
  final String title;
  final AgentTaskStepStatus status;
  final String? detail;
  final List<String> operationIds;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'status': status.name,
    if (detail != null) 'detail': detail,
    'operationIds': operationIds,
  };

  factory AgentTaskPlanStep.fromJson(Map<String, Object?> value) {
    _keys(value, {'id', 'title', 'status', 'detail', 'operationIds'});
    final status = AgentTaskStepStatus.values
        .where((status) => status.name == value['status'])
        .firstOrNull;
    if (status == null) {
      throw const FormatException('Invalid task plan status.');
    }
    return AgentTaskPlanStep(
      id: _text(value['id'], 128),
      title: _text(value['title'], maxTitleLength),
      status: status,
      detail: value['detail'] == null
          ? null
          : _text(value['detail'], maxDetailLength),
      operationIds: value.containsKey('operationIds')
          ? _list(
              value['operationIds'],
              maxOperationIds,
            ).map((id) => _text(id, 256))
          : const [],
    );
  }
}

/// Progress reported by the Agent. Operation verification remains host-owned.
class AgentTaskPlan {
  AgentTaskPlan({
    required this.runId,
    required this.revision,
    required Iterable<AgentTaskPlanStep> steps,
  }) : steps = List.unmodifiable(steps) {
    _text(runId, 256);
    if (revision < 1 || revision > maxRevision) {
      throw const FormatException('Invalid task plan revision.');
    }
    _validateSteps(this.steps);
  }

  static const maxSteps = 20;
  static const maxRevision = 0x7fffffff;
  final String runId;
  final int revision;
  final List<AgentTaskPlanStep> steps;

  Map<String, Object?> toJson() => {
    'runId': runId,
    'revision': revision,
    'steps': steps.map((step) => step.toJson()).toList(),
  };

  Map<String, Object?> toToolResult() => {
    'status': 'updated',
    'plan': toJson(),
  };

  factory AgentTaskPlan.fromJson(Map<String, Object?> value) {
    _keys(value, {'runId', 'revision', 'steps'});
    final revision = value['revision'];
    if (revision is! int) {
      throw const FormatException('Invalid task plan revision.');
    }
    return AgentTaskPlan(
      runId: _text(value['runId'], 256),
      revision: revision,
      steps: _list(
        value['steps'],
        maxSteps,
      ).map((step) => AgentTaskPlanStep.fromJson(_object(step))),
    );
  }

  factory AgentTaskPlan.fromToolResult(Map<String, Object?> value) {
    _keys(value, {'status', 'plan'});
    if (value['status'] != 'updated') {
      throw const FormatException('Invalid task plan result.');
    }
    return AgentTaskPlan.fromJson(_object(value['plan']));
  }
}

List<AgentTaskPlanStep> parseAgentTaskPlanSteps(
  Map<String, Object?> arguments,
) {
  _keys(arguments, {'steps'});
  final steps = _list(
    arguments['steps'],
    AgentTaskPlan.maxSteps,
  ).map((step) => AgentTaskPlanStep.fromJson(_object(step))).toList();
  _validateSteps(steps);
  return List.unmodifiable(steps);
}

final agentUpdatePlanTool = ToolDefinition(
  name: 'update_plan',
  description: 'Report or revise the task steps and their current progress. Keep at most one step in progress. Completed steps are your progress report; operation IDs remain subject to host verification. An empty steps list clears the plan.',
  parameters: {
    'type': 'object',
    'additionalProperties': false,
    'required': ['steps'],
    'properties': {
      'steps': {
        'type': 'array',
        'maxItems': AgentTaskPlan.maxSteps,
        'items': {
          'type': 'object',
          'additionalProperties': false,
          'required': ['id', 'title', 'status'],
          'properties': {
            'id': {'type': 'string', 'minLength': 1, 'maxLength': 128},
            'title': {
              'type': 'string',
              'minLength': 1,
              'maxLength': AgentTaskPlanStep.maxTitleLength,
            },
            'status': {
              'type': 'string',
              'enum': AgentTaskStepStatus.values
                  .map((status) => status.name)
                  .toList(),
            },
            'detail': {
              'type': ['string', 'null'],
              'minLength': 1,
              'maxLength': AgentTaskPlanStep.maxDetailLength,
            },
            'operationIds': {
              'type': 'array',
              'maxItems': AgentTaskPlanStep.maxOperationIds,
              'uniqueItems': true,
              'items': {'type': 'string', 'minLength': 1, 'maxLength': 256},
            },
          },
        },
      },
    },
  },
);

/// Reconstructs the latest paired plan in the current executable user turn.
AgentTaskPlan? projectAgentTaskPlan(AgentConversation conversation) {
  final messages = conversation.executionMessages.toList();
  final latestUser = messages.lastIndexWhere(
    (message) => message.role == ConversationRole.user,
  );
  if (latestUser < 0) {
    return null;
  }
  final turns = conversation.turns
      .where(
        (turn) =>
            turn.ownershipComplete &&
            turn.messageIds.contains(messages[latestUser].id),
      )
      .toList();
  if (turns.length > 1) {
    return null;
  }
  final turn = turns.firstOrNull;
  final first = turn == null
      ? latestUser
      : messages.indexWhere(
          (message) =>
              message.id == turn.requestMessageId &&
              message.role == ConversationRole.user,
        );
  if (first < 0) {
    return null;
  }
  final ownedMessages = turn?.messageIds.toSet();
  final runIds = conversation.runs.map((run) => run.id).toSet();
  final pending = <String, ConversationToolCall?>{};
  final revisions = <String, int>{};
  AgentTaskPlan? result;
  for (final message in messages.skip(first)) {
    if (ownedMessages != null && !ownedMessages.contains(message.id)) {
      continue;
    }
    if (message.role == ConversationRole.user) {
      pending.clear();
    } else if (message.role == ConversationRole.assistant) {
      for (final call in message.toolCalls) {
        pending[call.id] = pending.containsKey(call.id) ? null : call;
      }
    } else if (message.role == ConversationRole.tool) {
      final call = pending.remove(message.toolCallId);
      if (call == null || call.name != 'update_plan') {
        continue;
      }
      try {
        final plan = AgentTaskPlan.fromToolResult(
          _object(jsonDecode(message.text)),
        );
        final steps = parseAgentTaskPlanSteps(
          _object(jsonDecode(call.arguments)),
        );
        if (!runIds.contains(plan.runId) ||
            (turn != null && !turn.runIds.contains(plan.runId)) ||
            plan.revision <= (revisions[plan.runId] ?? 0) ||
            jsonEncode(plan.steps.map((step) => step.toJson()).toList()) !=
                jsonEncode(steps.map((step) => step.toJson()).toList())) {
          continue;
        }
        revisions[plan.runId] = plan.revision;
        result = plan;
      } on FormatException {
        // Invalid or failed tool results cannot replace a previously paired plan.
      }
    }
  }
  return result;
}

void _validateSteps(List<AgentTaskPlanStep> steps) {
  if (steps.length > AgentTaskPlan.maxSteps ||
      steps.map((step) => step.id).toSet().length != steps.length ||
      steps
              .where((step) => step.status == AgentTaskStepStatus.inProgress)
              .length >
          1) {
    throw const FormatException('Invalid task plan steps.');
  }
}

String _text(Object? value, int maximum) {
  if (value is! String || value.trim().isEmpty || value.length > maximum) {
    throw const FormatException('Invalid task plan text.');
  }
  return value;
}

List<Object?> _list(Object? value, int maximum) {
  if (value is! List || value.length > maximum) {
    throw const FormatException('Invalid task plan list.');
  }
  return value;
}

Map<String, Object?> _object(Object? value) {
  if (value is! Map<String, Object?>) {
    throw const FormatException('Invalid task plan object.');
  }
  return value;
}

void _keys(Map<String, Object?> value, Set<String> allowed) {
  if (value.keys.any((key) => !allowed.contains(key))) {
    throw const FormatException('Unknown task plan field.');
  }
}
