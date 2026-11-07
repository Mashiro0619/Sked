import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/conversations/conversation_models.dart';
import 'package:sked/agent/operations/operation_executor.dart';
import 'package:sked/agent/ui/agent_conversation_timeline.dart';

void main() {
  final now = DateTime.utc(2026, 11, 7);
  ConversationMessage user(String id) => ConversationMessage(
    id: id,
    role: ConversationRole.user,
    text: 'Create the timetable',
    createdAt: now,
  );
  ConversationMessage call(String id, String name, {String arguments = '{}'}) =>
      ConversationMessage(
        id: 'message-$id',
        role: ConversationRole.assistant,
        text: '',
        createdAt: now,
        toolCalls: [
          ConversationToolCall(id: id, name: name, arguments: arguments),
        ],
      );
  ConversationMessage result(String id, Map<String, Object?> value) =>
      ConversationMessage(
        id: 'result-$id',
        role: ConversationRole.tool,
        text: jsonEncode(value),
        createdAt: now,
        toolCallId: id,
      );
  AgentConversation conversation(List<ConversationMessage> messages) =>
      AgentConversation(
        id: 'conversation',
        title: 'Synthetic example',
        createdAt: now,
        updatedAt: now,
        messages: messages,
      );

  test(
    'one call retains its position from preparing through approval to saved',
    () {
      final original = conversation([
        user('request'),
        call('create', 'mutation.apply'),
      ]);
      final before = jsonEncode(original.toJson());
      const details = <String, Object?>{
        'operationId': 'host-owned',
        'planId': 'candidate',
        'toolCallId': 'create',
        'changes': [
          {'action': 'created', 'label': 'Semester timetable'},
        ],
      };
      String? anchor;
      for (final phase in [
        AgentOperationPhase.preparing,
        AgentOperationPhase.waitingApproval,
        AgentOperationPhase.executing,
      ]) {
        final timeline = projectAgentConversationTimeline(
          original,
          currentRunActive: true,
          operationUpdates: [
            AgentOperationUpdate(
              callId: 'create',
              toolName: 'mutation.apply',
              phase: phase,
              details: phase == AgentOperationPhase.preparing
                  ? const {}
                  : details,
            ),
          ],
          pendingOperation: phase == AgentOperationPhase.waitingApproval
              ? details
              : null,
        );
        final operation = timeline.whereType<AgentTimelineOperation>().single;
        anchor ??= operation.id;
        expect(operation.id, anchor);
        expect(operation.status, AgentToolActivityStatus.running);
        expect(
          operation.waitingApproval,
          phase == AgentOperationPhase.waitingApproval,
        );
        expect(timeline.whereType<AgentTimelineActivity>(), isEmpty);
        expect(timeline.whereType<AgentTimelineMessage>().length, 1);
      }
      final settled = projectAgentConversationTimeline(
        original.copyWith(
          messages: [
            ...original.messages,
            result('create', {...details, 'status': 'committed'}),
          ],
        ),
      );
      expect(settled.whereType<AgentTimelineOperation>().single.id, anchor);
      expect(
        settled.whereType<AgentTimelineOperation>().single.receipt?['status'],
        'committed',
      );
      expect(jsonEncode(original.toJson()), before);
    },
  );

  test('a saved result supersedes an executing observer whose final recording failed', () {
    final timeline = projectAgentConversationTimeline(
      conversation([
        user('request'),
        call('save', 'mutation.apply'),
        result('save', {
          'operationId': 'saved-operation',
          'status': 'committed',
          'recordingError': {'code': 'storageUnavailable'},
        }),
      ]),
      operationUpdates: [
        AgentOperationUpdate(
          callId: 'save',
          toolName: 'mutation.apply',
          phase: AgentOperationPhase.executing,
          details: const {'operationId': 'saved-operation'},
        ),
      ],
    );
    final operation = timeline.whereType<AgentTimelineOperation>().single;
    expect(operation.status, AgentToolActivityStatus.completed);
    expect(operation.receipt!['status'], 'committed');
    expect(operation.receipt!['recordingError'], isNotNull);
  });

  test(
    'a later same-name success does not invent a correction relationship',
    () {
      final timeline = projectAgentConversationTimeline(
        conversation([
          user('request'),
          call('bad', 'timetables.list'),
          result('bad', {
            'error': {'code': 'invalidArgument'},
          }),
          call('fixed', 'timetables.list'),
          result('fixed', {'items': []}),
        ]),
      );
      final activity = timeline.whereType<AgentTimelineActivity>().single;
      expect(activity.tools.first.status, AgentToolActivityStatus.failed);
      expect(activity.status, AgentToolActivityStatus.failed);
      expect(activity.tools.first.result, contains('invalidArgument'));
    },
  );

  test(
    'rejected business parameters stay in activity without a failed operation',
    () {
      final original = conversation([
        user('request'),
        call('bad', 'settings.update', arguments: '{"changes":"invalid"}'),
        result('bad', {
          'error': {'code': 'invalidArgument'},
        }),
        call('fixed', 'settings.update', arguments: '{"changes":[]}'),
        result('fixed', {
          'operationId': 'host-operation',
          'status': 'committed',
        }),
      ]);
      final before = jsonEncode(original.toJson());
      final timeline = projectAgentConversationTimeline(original);
      final operation = timeline.whereType<AgentTimelineOperation>().single;
      expect(operation.id, 'fixed');
      expect(operation.status, AgentToolActivityStatus.completed);
      final failed = timeline
          .whereType<AgentTimelineActivity>()
          .single
          .tools
          .single;
      expect(failed.id, 'bad');
      expect(failed.result, contains('invalidArgument'));
      expect(jsonEncode(original.toJson()), before);
    },
  );

  test('the same host operation retains its position and earlier failure after saving', () {
    final timeline = projectAgentConversationTimeline(
      conversation([
        user('request'),
        call('first', 'mutation.apply'),
        result('first', {
          'operationId': 'host-operation',
          'error': {'code': 'storageFailure'},
        }),
        call('retry', 'mutation.apply'),
        result('retry', {
          'operationId': 'host-operation',
          'status': 'committed',
        }),
      ]),
    );
    final operation = timeline.whereType<AgentTimelineOperation>().single;
    expect(operation.id, 'first');
    expect(operation.operationId, 'host-operation');
    expect(operation.status, AgentToolActivityStatus.completed);
    expect(operation.tools.first.status, AgentToolActivityStatus.corrected);
    expect(operation.tools.first.result, contains('storageFailure'));
    expect(operation.tools.last.status, AgentToolActivityStatus.completed);
    expect(timeline.whereType<AgentTimelineActivity>(), isEmpty);
  });

  test('a later turn cannot correct an earlier failed request', () {
    final timeline = projectAgentConversationTimeline(
      conversation([
        user('request'),
        call('bad', 'timetables.list'),
        result('bad', {
          'error': {'code': 'invalidArgument'},
        }),
        user('next-request'),
        call('next', 'timetables.list'),
        result('next', {'items': []}),
      ]),
    );
    expect(
      timeline.whereType<AgentTimelineActivity>().first.status,
      AgentToolActivityStatus.failed,
    );
  });
  test('repeated projections reuse protocol-owned decoded payloads', () {
    final query = call('read', 'events.list', arguments: '{"limit":50}');
    final reply = result('read', {'items': []});
    final original = conversation([user('request'), query, reply]);
    final first = projectAgentConversationTimeline(original)
        .whereType<AgentTimelineActivity>()
        .single
        .tools
        .single;
    final second = projectAgentConversationTimeline(original)
        .whereType<AgentTimelineActivity>()
        .single
        .tools
        .single;
    expect(first.outcome, same(reply.toolOutcome));
    expect(second.outcome, same(first.outcome));
    expect(first.argumentsObject, same(query.toolCalls.single.argumentsObject));
    expect(second.argumentsObject, same(first.argumentsObject));
    final prose = ConversationMessage(
      id: 'prose',
      role: ConversationRole.assistant,
      text: '{"operationId":"not-a-receipt","status":"committed"}',
      createdAt: now,
    );
    expect(prose.toolOutcome, isNull);
  });
}
