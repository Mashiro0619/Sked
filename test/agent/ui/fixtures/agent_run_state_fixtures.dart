import 'package:sked/agent/operations/tool_outcome.dart';

import 'dart:convert';

import 'package:sked/agent/interactions/agent_question.dart';
import 'package:sked/agent/operations/operation_executor.dart';
import 'package:sked/agent/ui/agent_conversation_timeline.dart';

enum AgentPreviewState {
  running,
  approval,
  question,
  completed,
  error,
  recovery,
}

const agentPreviewReceipt = <String, Object?>{
  'operationId': 'synthetic-operation',
  'planId': 'synthetic-plan',
  'changeCount': 1,
  'changes': [
    {
      'action': 'created',
      'label': '秋季课表',
      'after': {'id': 'synthetic-timetable', 'name': '秋季课表'},
    },
  ],
};

AgentTimelineOperation previewOperation(AgentPreviewState state) {
  final phase = switch (state) {
    AgentPreviewState.running => AgentOperationPhase.executing,
    AgentPreviewState.approval => AgentOperationPhase.waitingApproval,
    AgentPreviewState.completed => AgentOperationPhase.completed,
    AgentPreviewState.error => AgentOperationPhase.failed,
    AgentPreviewState.recovery => AgentOperationPhase.unresolved,
    AgentPreviewState.question => AgentOperationPhase.preparing,
  };
  final receipt = {
    ...agentPreviewReceipt,
    if (state == AgentPreviewState.completed) 'status': 'committed',
    if (state == AgentPreviewState.error) ...{
      'status': 'failed',
      'error': {'code': 'conflict'},
    },
    if (state == AgentPreviewState.recovery) ...{
      'status': 'outcome_unknown',
      'effectStatus': 'unknown',
    },
  };
  return AgentTimelineOperation(
    id: 'create-timetable',
    anchorMessageId: 'call-message',
    turnId: 'turn',
    operationId: 'synthetic-operation',
    outcome: ToolOutcome.fromResult(receipt),
    phase: phase,
    waitingApproval: state == AgentPreviewState.approval,
    tools: [
      AgentToolActivity(
        id: 'create-timetable',
        name: 'mutation.apply',
        arguments: '{"kind":"timetable","name":"秋季课表"}',
        result:
            state == AgentPreviewState.completed ||
                state == AgentPreviewState.error
            ? jsonEncode(receipt)
            : null,
        status: switch (state) {
          AgentPreviewState.completed => AgentToolActivityStatus.completed,
          AgentPreviewState.error => AgentToolActivityStatus.failed,
          AgentPreviewState.recovery => AgentToolActivityStatus.uncertain,
          _ => AgentToolActivityStatus.running,
        },
      ),
    ],
  );
}

AgentQuestionRequest previewQuestion() => AgentQuestionRequest(
  id: 'synthetic-question',
  toolCallId: 'ask-start-date',
  runId: 'run',
  requestMessageId: 'request',
  createdAt: DateTime.utc(2026, 11, 7),
  connectionFingerprint: 'synthetic-connection',
  questions: [AgentQuestionPrompt(id: 'start', question: '这学期从哪一天开始？')],
);
