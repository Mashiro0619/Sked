import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/conversations/conversation_models.dart';
import 'package:sked/agent/history/conversation_history.dart';
import 'package:sked/agent/ui/agent_conversation_timeline.dart';

void main() {
  final time = DateTime.utc(2026, 11, 5);
  ConversationMessage message(
    String id,
    ConversationRole role, {
    String text = '',
    List<ConversationToolCall> calls = const [],
    String? toolId,
  }) => ConversationMessage(
    id: id,
    role: role,
    text: text,
    createdAt: time,
    toolCalls: calls,
    toolCallId: toolId,
  );
  AgentConversation conversation(
    List<ConversationMessage> messages, {
    List<ConversationRunUsage> runs = const [],
    List<ConversationTurn> turns = const [],
    ConversationStatus status = ConversationStatus.idle,
    String? runId,
  }) => AgentConversation(
    id: 'conversation',
    title: 'A real request',
    createdAt: time,
    updatedAt: time,
    messages: messages,
    runs: runs,
    turns: turns,
    status: status,
    runId: runId,
  );

  test(
    'eight read calls become one activity without changing stored messages',
    () {
      final messages = <ConversationMessage>[
        message('user', ConversationRole.user, text: 'Check my reminders'),
        message(
          'calls',
          ConversationRole.assistant,
          calls: [
            for (var index = 0; index < 8; index++)
              ConversationToolCall(
                id: 'call-$index',
                name: 'notifications.reminders',
                arguments: '{"limit":$index}',
              ),
          ],
        ),
        for (var index = 0; index < 8; index++)
          message(
            'result-$index',
            ConversationRole.tool,
            toolId: 'call-$index',
            text: '{"items":[$index]}',
          ),
        message(
          'reply',
          ConversationRole.assistant,
          text: 'Here is the result.',
        ),
      ];
      final stored = conversation(messages);
      final before = jsonEncode(stored.toJson());
      final timeline = projectAgentConversationTimeline(stored);
      expect(timeline, hasLength(3));
      expect(timeline.whereType<AgentTimelineActivity>(), hasLength(1));
      final activity = timeline.whereType<AgentTimelineActivity>().single;
      expect(activity.tools, hasLength(8));
      expect(activity.anchorMessageId, 'calls');
      expect(activity.status, AgentToolActivityStatus.completed);
      expect(
        timeline.whereType<AgentTimelineMessage>().map(
          (entry) => entry.message.id,
        ),
        ['user', 'reply'],
      );
      expect(jsonEncode(stored.toJson()), before);
    },
  );

  test(
    'host plans, saved receipts and failures stay outside collapsed activity',
    () {
      final stored = conversation([
        message('user', ConversationRole.user, text: 'Update the schedule'),
        message(
          'calls',
          ConversationRole.assistant,
          calls: const [
            ConversationToolCall(
              id: 'prepare',
              name: 'mutation.prepare',
              arguments: '{}',
            ),
            ConversationToolCall(
              id: 'commit',
              name: 'mutation.commit',
              arguments: '{}',
            ),
            ConversationToolCall(
              id: 'external',
              name: 'external.commit',
              arguments: '{}',
            ),
            ConversationToolCall(
              id: 'failed',
              name: 'settings.get',
              arguments: '{}',
            ),
          ],
        ),
        message(
          'plan',
          ConversationRole.tool,
          toolId: 'prepare',
          text: '{"planId":"p"}',
        ),
        message(
          'saved',
          ConversationRole.tool,
          toolId: 'commit',
          text: '{"operationId":"o","status":"committed"}',
        ),
        message(
          'uncertain',
          ConversationRole.tool,
          toolId: 'external',
          text: '{"operationId":"e","effectStatus":"unknown"}',
        ),
        message(
          'failed',
          ConversationRole.tool,
          toolId: 'failed',
          text: '{"error":"not_available"}',
        ),
        message(
          'reply',
          ConversationRole.assistant,
          text: 'Some results need checking.',
        ),
      ]);
      final timeline = projectAgentConversationTimeline(stored);
      expect(
        timeline.whereType<AgentTimelineMessage>().map(
          (entry) => entry.message.id,
        ),
        ['user', 'plan', 'saved', 'uncertain', 'failed', 'reply'],
      );
      final activity = timeline.whereType<AgentTimelineActivity>().single;
      expect(activity.tools.every((tool) => tool.receipt), isTrue);
      expect(activity.status, AgentToolActivityStatus.uncertain);
      expect(
        activity.tools.singleWhere((tool) => tool.id == 'failed').status,
        AgentToolActivityStatus.failed,
      );
    },
  );

  test('recorded steering stays in one activity, accepted follow-up starts another', () {
    final messages = [
      message('request', ConversationRole.user, text: 'Read my schedule'),
      message(
        'first-call',
        ConversationRole.assistant,
        calls: const [
          ConversationToolCall(
            id: 'read',
            name: 'agenda.query',
            arguments: '{}',
          ),
        ],
      ),
      message('steer', ConversationRole.user, text: 'Include tomorrow'),
      message('read-result', ConversationRole.tool, toolId: 'read', text: '[]'),
      message('reply', ConversationRole.assistant, text: 'Done'),
      message('follow-up', ConversationRole.user, text: 'Now check settings'),
      message(
        'second-call',
        ConversationRole.assistant,
        calls: const [
          ConversationToolCall(
            id: 'settings',
            name: 'settings.get',
            arguments: '{}',
          ),
        ],
      ),
    ];
    final runs = [
      ConversationRunUsage(
        id: 'run-1',
        startedAt: time,
        kind: ConversationRunKind.model,
      ),
      ConversationRunUsage(
        id: 'run-2',
        startedAt: time,
        kind: ConversationRunKind.model,
      ),
    ];
    final stored = conversation(
      messages,
      runs: runs,
      turns: [
        ConversationTurn(
          id: 'turn-1',
          requestMessageId: 'request',
          ownershipComplete: true,
          messageIds: messages.take(5).map((message) => message.id),
          runIds: const ['run-1'],
        ),
        ConversationTurn(
          id: 'turn-2',
          requestMessageId: 'follow-up',
          ownershipComplete: true,
          messageIds: const ['follow-up', 'second-call'],
          runIds: const ['run-2'],
        ),
      ],
      runId: 'run-2',
      status: ConversationStatus.running,
    );
    final activities = projectAgentConversationTimeline(
      stored,
      activeRunId: 'run-2',
    ).whereType<AgentTimelineActivity>().toList();
    expect(activities.map((entry) => entry.id), ['turn-1', 'turn-2']);
    expect(activities.first.status, AgentToolActivityStatus.completed);
    expect(activities.last.status, AgentToolActivityStatus.running);
  });

  test('unfinished accounting remains uncertain after interruption', () {
    final stored = conversation(
      [message('user', ConversationRole.user, text: 'Check the device')],
      status: ConversationStatus.interrupted,
      runs: [
        ConversationRunUsage(
          id: 'interrupted',
          startedAt: time,
          kind: ConversationRunKind.model,
          status: ConversationRunStatus.interrupted,
          tools: const [
            ConversationToolUsage(id: 'pending', name: 'platform.status'),
            ConversationToolUsage(
              id: 'failed',
              name: 'platform.status',
              outcome: ConversationAttemptOutcome.failed,
            ),
          ],
        ),
      ],
    );
    final timeline = projectAgentConversationTimeline(stored);
    expect(timeline.first, isA<AgentTimelineMessage>());
    final activity = timeline.last as AgentTimelineActivity;
    expect(activity.status, AgentToolActivityStatus.uncertain);
    expect(activity.tools.first.status, AgentToolActivityStatus.uncertain);
    expect(activity.tools.last.status, AgentToolActivityStatus.failed);
  });

  test(
    'an unowned legacy usage-only run stays outside a newer active turn',
    () {
      final legacyRequest = ConversationMessage(
        id: 'legacy-request',
        role: ConversationRole.user,
        text: 'A previous interrupted request',
        createdAt: time.subtract(const Duration(minutes: 2)),
      );
      final stored = conversation(
        [
          legacyRequest,
          message('new-request', ConversationRole.user, text: 'A new request'),
          message(
            'new-call',
            ConversationRole.assistant,
            calls: const [
              ConversationToolCall(
                id: 'new-tool',
                name: 'agenda.query',
                arguments: '{}',
              ),
            ],
          ),
        ],
        status: ConversationStatus.running,
        runId: 'new-run',
        turns: [
          ConversationTurn(
            id: 'new-turn',
            requestMessageId: 'new-request',
            ownershipComplete: true,
            messageIds: const ['new-request', 'new-call'],
            runIds: const ['new-run'],
          ),
        ],
        runs: [
          ConversationRunUsage(
            id: 'legacy-run',
            startedAt: time.subtract(const Duration(minutes: 1)),
            kind: ConversationRunKind.model,
            protocol: 'chatCompletions',
            model: 'fixture',
            status: ConversationRunStatus.interrupted,
            tools: const [
              ConversationToolUsage(
                id: 'legacy-tool',
                name: 'platform.status',
                outcome: ConversationAttemptOutcome.unknown,
              ),
            ],
          ),
          ConversationRunUsage(
            id: 'new-run',
            startedAt: time,
            kind: ConversationRunKind.model,
            protocol: 'chatCompletions',
            model: 'fixture',
            tools: const [
              ConversationToolUsage(id: 'new-tool', name: 'agenda.query'),
            ],
          ),
        ],
      );
      final source = jsonEncode(stored.toJson());
      final decoded = AgentConversation.fromJson(
        jsonDecode(source) as Map<String, dynamic>,
      );
      final activities = projectAgentConversationTimeline(
        decoded,
        activeRunId: 'new-run',
      ).whereType<AgentTimelineActivity>().toList();
      expect(activities, hasLength(2));
      expect(activities.first.id, 'legacy-run-legacy-run');
      expect(activities.first.anchorMessageId, 'legacy-request');
      expect(activities.first.tools.single.id, 'legacy-tool');
      expect(activities.first.status, AgentToolActivityStatus.uncertain);
      expect(activities.last.id, 'new-turn');
      expect(activities.last.tools.single.id, 'new-tool');
      expect(activities.last.status, AgentToolActivityStatus.running);
      expect(jsonEncode(stored.toJson()), source);
    },
  );

  test(
    'an active usage-only host run publishes running without a recorded turn',
    () {
      final stored = conversation(
        [
          message(
            'request',
            ConversationRole.user,
            text: 'Check system settings',
          ),
        ],
        status: ConversationStatus.running,
        runId: 'host-run',
        runs: [
          ConversationRunUsage(
            id: 'host-run',
            startedAt: time,
            kind: ConversationRunKind.host,
            tools: const [
              ConversationToolUsage(id: 'host-tool', name: 'host.action'),
            ],
          ),
        ],
      );
      final source = jsonEncode(stored.toJson());
      final decoded = AgentConversation.fromJson(
        jsonDecode(source) as Map<String, dynamic>,
      );
      final activity = projectAgentConversationTimeline(
        decoded,
        activeRunId: 'host-run',
      ).whereType<AgentTimelineActivity>().single;
      expect(activity.id, 'legacy-run-host-run');
      expect(activity.anchorMessageId, 'request');
      expect(activity.status, AgentToolActivityStatus.running);
      expect(jsonEncode(stored.toJson()), source);
    },
  );

  for (final sharedTurn in [false, true]) {
    test(
      'reused historical call IDs preserve each result ${sharedTurn ? 'within one turn' : 'across turns'}',
      () {
        final messages = [
          message('u1', ConversationRole.user, text: 'Read agenda'),
          message(
            'a1',
            ConversationRole.assistant,
            calls: const [
              ConversationToolCall(
                id: 'call_0',
                name: 'agenda.list',
                arguments: '{"source":"old"}',
              ),
            ],
          ),
          message(
            't1',
            ConversationRole.tool,
            toolId: 'call_0',
            text: '{"items":["old agenda"]}',
          ),
          message('u2', ConversationRole.user, text: 'Read settings'),
          message(
            'a2',
            ConversationRole.assistant,
            calls: const [
              ConversationToolCall(
                id: 'call_0',
                name: 'settings.get',
                arguments: '{"source":"new"}',
              ),
            ],
          ),
          message(
            't2',
            ConversationRole.tool,
            toolId: 'call_0',
            text: '{"error":"new failure"}',
          ),
        ];
        final stored = conversation(
          messages,
          turns: sharedTurn
              ? [
                  ConversationTurn(
                    id: 'turn',
                    requestMessageId: 'u1',
                    ownershipComplete: false,
                    messageIds: messages.map((message) => message.id),
                    runIds: const ['r1', 'r2'],
                  ),
                ]
              : [
                  ConversationTurn(
                    id: 'turn1',
                    requestMessageId: 'u1',
                    ownershipComplete: true,
                    messageIds: const ['u1', 'a1', 't1'],
                    runIds: const ['r1'],
                  ),
                  ConversationTurn(
                    id: 'turn2',
                    requestMessageId: 'u2',
                    ownershipComplete: true,
                    messageIds: const ['u2', 'a2', 't2'],
                    runIds: const ['r2'],
                  ),
                ],
          runs: [
            for (var run = 1; run <= 2; run++)
              ConversationRunUsage(
                id: 'r$run',
                startedAt: time,
                kind: ConversationRunKind.model,
                protocol: 'chatCompletions',
                model: 'fixture',
                status: ConversationRunStatus.completed,
                tools: [
                  ConversationToolUsage(
                    id: 'call_0',
                    name: run == 1 ? 'agenda.list' : 'settings.get',
                    outcome: run == 1
                        ? ConversationAttemptOutcome.completed
                        : ConversationAttemptOutcome.failed,
                  ),
                ],
              ),
          ],
        );
        final source = jsonEncode(stored.toJson());
        final decoded = AgentConversation.fromJson(
          jsonDecode(source) as Map<String, dynamic>,
        );
        final activities = projectAgentConversationTimeline(decoded)
            .whereType<AgentTimelineActivity>()
            .toList();
        final ordinary = activities
            .where((activity) => !activity.id.startsWith('legacy-run-'))
            .toList();
        final tools = ordinary.expand((activity) => activity.tools).toList();
        expect(ordinary, hasLength(sharedTurn ? 1 : 2));
        expect(tools, hasLength(2));
        expect(tools.map((tool) => tool.id).toSet(), hasLength(2));
        expect(tools.first.name, 'agenda.list');
        expect(tools.first.arguments, '{"source":"old"}');
        expect(tools.first.result, '{"items":["old agenda"]}');
        expect(tools.first.status, AgentToolActivityStatus.completed);
        expect(tools.last.name, 'settings.get');
        expect(tools.last.arguments, '{"source":"new"}');
        expect(tools.last.result, '{"error":"new failure"}');
        expect(tools.last.status, AgentToolActivityStatus.failed);
        if (sharedTurn) {
          expect(
            activities.where(
              (activity) => activity.id.startsWith('legacy-run-'),
            ),
            hasLength(2),
          );
        }
        expect(jsonEncode(stored.toJson()), source);
      },
    );
  }

  test('usage-only old metadata cannot be swallowed by a new call with the same ID', () {
    final oldRequest = ConversationMessage(
      id: 'old-request',
      role: ConversationRole.user,
      text: 'Old request',
      createdAt: time.subtract(const Duration(minutes: 2)),
    );
    final stored = conversation(
      [
        oldRequest,
        message('request', ConversationRole.user, text: 'New request'),
        message(
          'call',
          ConversationRole.assistant,
          calls: const [
            ConversationToolCall(
              id: 'call_0',
              name: 'agenda.list',
              arguments: '{}',
            ),
          ],
        ),
      ],
      status: ConversationStatus.running,
      runId: 'new-run',
      turns: [
        ConversationTurn(
          id: 'turn',
          requestMessageId: 'request',
          ownershipComplete: true,
          messageIds: const ['request', 'call'],
          runIds: const ['new-run'],
        ),
      ],
      runs: [
        ConversationRunUsage(
          id: 'old-run',
          startedAt: time.subtract(const Duration(minutes: 1)),
          kind: ConversationRunKind.host,
          status: ConversationRunStatus.interrupted,
          tools: const [
            ConversationToolUsage(
              id: 'call_0',
              name: 'platform.status',
              outcome: ConversationAttemptOutcome.unknown,
            ),
          ],
        ),
        ConversationRunUsage(
          id: 'new-run',
          startedAt: time,
          kind: ConversationRunKind.model,
          protocol: 'chatCompletions',
          model: 'fixture',
          tools: const [
            ConversationToolUsage(id: 'call_0', name: 'agenda.list'),
          ],
        ),
      ],
    );
    final source = jsonEncode(stored.toJson());
    final decoded = AgentConversation.fromJson(
      jsonDecode(source) as Map<String, dynamic>,
    );
    final activities = projectAgentConversationTimeline(
      decoded,
      activeRunId: 'new-run',
    ).whereType<AgentTimelineActivity>().toList();
    expect(activities, hasLength(2));
    expect(activities.first.anchorMessageId, 'old-request');
    expect(activities.first.tools.single.name, 'platform.status');
    expect(activities.first.status, AgentToolActivityStatus.uncertain);
    expect(activities.last.tools.single.name, 'agenda.list');
    expect(activities.last.status, AgentToolActivityStatus.running);
    expect(jsonEncode(stored.toJson()), source);
  });

  for (final hasOldRequest in [false, true]) {
    test(
      'legacy usage cannot claim a later call ${hasOldRequest ? 'after its settlement' : 'without an earlier request'}',
      () {
        final request = ConversationMessage(
          id: 'request',
          role: ConversationRole.user,
          text: 'A current legacy request',
          createdAt: hasOldRequest
              ? time.subtract(const Duration(minutes: 2))
              : time,
        );
        final stored = conversation(
          [
            request,
            message(
              'call',
              ConversationRole.assistant,
              calls: const [
                ConversationToolCall(
                  id: 'call_0',
                  name: 'agenda.query',
                  arguments: '{}',
                ),
              ],
            ),
          ],
          status: ConversationStatus.running,
          runId: 'new-run',
          runs: [
            ConversationRunUsage(
              id: 'old-run',
              kind: ConversationRunKind.host,
              startedAt: time.subtract(const Duration(minutes: 1)),
              settledAt: time.subtract(const Duration(seconds: 30)),
              status: ConversationRunStatus.interrupted,
              tools: const [
                ConversationToolUsage(
                  id: 'call_0',
                  name: 'platform.status',
                  outcome: ConversationAttemptOutcome.unknown,
                ),
              ],
            ),
            ConversationRunUsage(
              id: 'new-run',
              kind: ConversationRunKind.host,
              startedAt: time,
              tools: const [
                ConversationToolUsage(id: 'call_0', name: 'agenda.query'),
              ],
            ),
          ],
        );
        final source = jsonEncode(stored.toJson());
        final decoded = AgentConversation.fromJson(
          jsonDecode(source) as Map<String, dynamic>,
        );
        final activities = projectAgentConversationTimeline(
          decoded,
          activeRunId: 'new-run',
        ).whereType<AgentTimelineActivity>().toList();
        expect(activities, hasLength(2));
        final previous = activities.singleWhere(
          (activity) => activity.id == 'legacy-run-old-run',
        );
        expect(previous.tools.single.name, 'platform.status');
        expect(previous.status, AgentToolActivityStatus.uncertain);
        final current = activities.singleWhere(
          (activity) => activity.id == 'request',
        );
        expect(current.tools.single.name, 'agenda.query');
        expect(current.status, AgentToolActivityStatus.running);
        expect(jsonEncode(stored.toJson()), source);
      },
    );
  }

  for (final withAccounting in [false, true]) {
    test(
      'cancelled not-executed tool remains not started ${withAccounting ? 'with' : 'without'} usage accounting',
      () {
        final stored = conversation(
          [
            message('user', ConversationRole.user, text: 'Check my schedule'),
            message(
              'call',
              ConversationRole.assistant,
              calls: const [
                ConversationToolCall(
                  id: 'cancelled',
                  name: 'agenda.query',
                  arguments: '{}',
                ),
              ],
            ),
            message(
              'result',
              ConversationRole.tool,
              toolId: 'cancelled',
              text: '{"status":"not_executed","error":{"code":"cancelled"}}',
            ),
          ],
          runs: withAccounting
              ? [
                  ConversationRunUsage(
                    id: 'run',
                    startedAt: time,
                    kind: ConversationRunKind.model,
                    tools: const [
                      ConversationToolUsage(
                        id: 'cancelled',
                        name: 'agenda.query',
                        outcome: ConversationAttemptOutcome.notStarted,
                      ),
                    ],
                  ),
                ]
              : const [],
        );
        final timeline = projectAgentConversationTimeline(stored);
        final activity = timeline.whereType<AgentTimelineActivity>().single;
        expect(activity.status, AgentToolActivityStatus.notStarted);
        expect(
          activity.tools.single.status,
          AgentToolActivityStatus.notStarted,
        );
        expect(
          timeline.whereType<AgentTimelineMessage>().last.message.id,
          'result',
        );
      },
    );
  }

  for (final status in ['outcome_unknown', 'outcomeUnknown']) {
    test(
      'a legacy $status result remains uncertain even with an error field',
      () {
        final stored = conversation([
          message('user', ConversationRole.user, text: 'Update my schedule'),
          message(
            'call',
            ConversationRole.assistant,
            calls: const [
              ConversationToolCall(
                id: 'unknown',
                name: 'mutation.commit',
                arguments: '{}',
              ),
            ],
          ),
          message(
            'result',
            ConversationRole.tool,
            toolId: 'unknown',
            text: jsonEncode({
              'status': status,
              'error': {'code': 'operationRecoveryRequired'},
            }),
          ),
        ]);
        final timeline = projectAgentConversationTimeline(stored);
        final activity = timeline.whereType<AgentTimelineActivity>().single;
        expect(activity.status, AgentToolActivityStatus.uncertain);
        expect(activity.tools.single.status, AgentToolActivityStatus.uncertain);
        expect(
          timeline.whereType<AgentTimelineMessage>().last.message.id,
          'result',
        );
      },
    );
  }
}
