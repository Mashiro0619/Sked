import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/runtime/agent_runtime_controller.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/models/agent_settings.dart';

import '../tools/core_tool_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final protocol in AgentModelProtocol.values) {
    for (final streaming in [false, true]) {
      for (final text in ['', ' \n\r\t\u00a0\u3000']) {
        test(
          '$protocol streaming=$streaming rejects an empty answer of ${text.length} characters',
          () async {
            final h = await _Harness.create(
              protocol,
              streaming,
              (_, index) => _Reply(text: index == 0 ? text : 'Recovered reply'),
            );
            addTearDown(h.close);
            await h.runtime.send(h.id, 'Answer this request');
            final interrupted = h.repository.find(h.id)!;
            expect(interrupted.status, ConversationStatus.interrupted);
            expect(
              interrupted.runs.single.status,
              ConversationRunStatus.interrupted,
            );
            expect(
              interrupted.runs.single.requests.single.outcome,
              ConversationAttemptOutcome.completed,
            );
            expect(
              interrupted.runs.single.requests.single.usage!.totalTokens,
              3,
            );
            expect(interrupted.messages, hasLength(1));
            expect(interrupted.messages.single.text, 'Answer this request');
            expect(
              h.runtime.state.value.runFor(h.id).errorMessage,
              'provider.incompleteResponse',
            );
            expect(
              ConversationArchive.decode(h.storage.source!)
                  .conversations
                  .single
                  .messages
                  .single
                  .text,
              'Answer this request',
            );
            await h.runtime.continueConversation(h.id);
            final completed = h.repository.find(h.id)!;
            expect(completed.runs.last.status, ConversationRunStatus.completed);
            expect(completed.messages.last.text, 'Recovered reply');
            expect(
              completed.messages.where(
                (message) => message.role == ConversationRole.user,
              ),
              hasLength(1),
            );
            expect(h.wires, hasLength(2));
          },
        );
      }
    }

    test(
      '$protocol keeps a committed tool result when the final answer is empty',
      () async {
        final app = CoreToolHarness();
        await app.initialize();
        final original = app.session.committedData.generalMode.showWeekends;
        final calls = <String>[];
        final h = await _Harness.create(
          protocol,
          true,
          (wire, index) => switch (index) {
            0 => _Reply(
              tool: 'capabilities.describe',
              arguments: {
                'names': ['settings.prepare', 'mutation.commit'],
              },
            ),
            1 => _Reply(
              tool: 'settings.prepare',
              arguments: {
                'edits': [
                  {
                    'key': 'general.showWeekends',
                    'action': 'set',
                    'value': !original,
                  },
                ],
              },
            ),
            2 => _Reply(
              tool: 'mutation.commit',
              arguments: {'planId': _lastToolResult(wire, protocol)['planId']},
            ),
            3 => const _Reply(text: ''),
            _ => const _Reply(text: 'The setting was already saved.'),
          },
          app: app,
          executed: calls,
        );
        addTearDown(() async {
          h.close();
          app.tools.dispose();
          await app.close();
        });
        await h.runtime.send(h.id, 'Toggle weekend visibility');
        final interrupted = h.repository.find(h.id)!;
        final results = interrupted.messages
            .where((message) => message.role == ConversationRole.tool)
            .toList();
        final receipt = jsonDecode(results.last.text) as Map;
        expect(receipt['status'], 'committed');
        expect(app.session.committedData.generalMode.showWeekends, !original);
        expect(
          interrupted.runs.single.status,
          ConversationRunStatus.interrupted,
        );
        expect(
          interrupted.runs.single.tools.every(
            (tool) => tool.outcome == ConversationAttemptOutcome.completed,
          ),
          true,
        );
        expect(
          h.runtime.state.value.runFor(h.id).errorMessage,
          'provider.incompleteResponse',
        );
        expect(h.runtime.state.value.runFor(h.id).recoveryRequired, false);
        expect(calls, [
          'capabilities.describe',
          'settings.prepare',
          'mutation.commit',
        ]);
        final sequence =
            app.session.committedData.applicationLedger!.nextSequence;
        await h.runtime.continueConversation(h.id);
        expect(
          app.session.committedData.applicationLedger!.nextSequence,
          sequence,
        );
        expect(calls, [
          'capabilities.describe',
          'settings.prepare',
          'mutation.commit',
        ]);
        expect(
          h.repository
              .find(h.id)!
              .messages
              .where((message) => message.role == ConversationRole.tool)
              .last
              .text,
          results.last.text,
        );
        expect(
          h.repository.find(h.id)!.runs.last.status,
          ConversationRunStatus.completed,
        );
      },
    );

    test(
      '$protocol regeneration keeps the original reply after empty output',
      () async {
        final h = await _Harness.create(
          protocol,
          false,
          (_, index) => _Reply(text: index == 0 ? 'Original answer' : ''),
        );
        addTearDown(h.close);
        await h.runtime.send(h.id, 'Answer this request');
        final original = h.repository.find(h.id)!.messages.last;
        await h.runtime.regenerateReply(h.id, original.id);
        final after = h.repository.find(h.id)!;
        expect(after.messages.last.toJson(), original.toJson());
        expect(after.replyRevisions, isEmpty);
        expect(
          h.runtime.state.value.runFor(h.id).errorMessage,
          'provider.incompleteResponse',
        );
      },
    );
  }
}

Map _lastToolResult(Map<String, dynamic> wire, AgentModelProtocol protocol) {
  final messages =
      (wire[protocol == AgentModelProtocol.responses ? 'input' : 'messages']
              as List)
          .cast<Map>();
  final result = protocol == AgentModelProtocol.responses
      ? messages.lastWhere(
          (message) => message['type'] == 'function_call_output',
        )['output']
      : messages.lastWhere((message) => message['role'] == 'tool')['content'];
  return jsonDecode(result as String) as Map;
}

class _Reply {
  const _Reply({this.text = '', this.tool, this.arguments = const {}});
  final String text;
  final String? tool;
  final Map<String, Object?> arguments;

  http.Response encode(AgentModelProtocol protocol, bool streaming, int index) {
    final toolName = tool == null ? null : ToolNameCodec.encode(tool!);
    if (protocol == AgentModelProtocol.chatCompletions) {
      final message = {
        'role': 'assistant',
        'content': text,
        if (toolName != null)
          'tool_calls': [
            {
              if (streaming) 'index': 0,
              'id': 'call-$index',
              'type': 'function',
              'function': {
                'name': toolName,
                'arguments': jsonEncode(arguments),
              },
            },
          ],
      };
      final value = {
        'choices': [
          {
            'index': 0,
            streaming ? 'delta' : 'message': message,
            'finish_reason': tool == null ? 'stop' : 'tool_calls',
          },
        ],
        'usage': {
          'prompt_tokens': 2,
          'completion_tokens': 1,
          'total_tokens': 3,
        },
      };
      return http.Response(
        streaming
            ? 'data: ${jsonEncode(value)}\n\ndata: [DONE]\n\n'
            : jsonEncode(value),
        200,
        headers: {
          'content-type': streaming
              ? 'text/event-stream; charset=utf-8'
              : 'application/json; charset=utf-8',
        },
      );
    }
    final value = {
      'id': 'response-$index',
      'status': 'completed',
      'output': [
        if (text.isNotEmpty)
          {
            'id': 'message-$index',
            'type': 'message',
            'role': 'assistant',
            'status': 'completed',
            'content': [
              {'type': 'output_text', 'text': text, 'annotations': []},
            ],
          },
        if (toolName != null)
          {
            'id': 'item-$index',
            'call_id': 'call-$index',
            'type': 'function_call',
            'name': toolName,
            'arguments': jsonEncode(arguments),
            'status': 'completed',
          },
      ],
      'usage': {'input_tokens': 2, 'output_tokens': 1, 'total_tokens': 3},
    };
    return http.Response(
      streaming
          ? 'event: response.completed\ndata: ${jsonEncode({'type': 'response.completed', 'response': value})}\n\n'
          : jsonEncode(value),
      200,
      headers: {
        'content-type': streaming
            ? 'text/event-stream; charset=utf-8'
            : 'application/json; charset=utf-8',
      },
    );
  }
}

class _Memory extends ConversationStorage {
  _Memory() : super.base();
  String? source;
  @override
  Future<ConversationStorageLoad> load() async =>
      ConversationStorageLoad(source: source);
  @override
  Future<void> save(String value, {required int revision}) async {
    source = value;
  }
}

class _Harness {
  final storage = _Memory();
  final wires = <Map<String, dynamic>>[];
  late final ConversationRepository repository;
  late final ProviderClient provider;
  late final AgentRuntimeController runtime;
  late final String id;

  static Future<_Harness> create(
    AgentModelProtocol protocol,
    bool streaming,
    _Reply Function(Map<String, dynamic>, int) reply, {
    CoreToolHarness? app,
    List<String>? executed,
  }) async {
    final h = _Harness();
    h.repository = ConversationRepository(storage: h.storage);
    await h.repository.load();
    h.id = (await h.repository.create(
      title: 'Empty response fixture',
      mode: AgentPermissionMode.full,
    )).id;
    h.provider = ProviderClient(
      client: MockClient((request) async {
        final wire = jsonDecode(request.body) as Map<String, dynamic>;
        h.wires.add(wire);
        return reply(
          wire,
          h.wires.length - 1,
        ).encode(protocol, streaming, h.wires.length - 1);
      }),
    );
    final settings = AgentSettings(
      enabled: true,
      endpoint: 'https://fixture.example/v1',
      model: 'fixture',
      protocol: protocol,
      models: [
        AgentModelConfig(
          id: 'fixture',
          reasoningEfforts: [AgentReasoningEffort.medium],
          defaultReasoningEffort: AgentReasoningEffort.medium,
        ),
      ],
    );
    h.runtime = AgentRuntimeController(
      repository: h.repository,
      provider: h.provider,
      readSettings: () => settings,
      readApiKey: (_) async => 'fixture-key',
      readTools: app?.tools.toolsFor ?? (_) => const [],
      executeTool: (call, scope, approval) async {
        executed?.add(call.name);
        return app!.tools.execute(call, scope, approval);
      },
      readPreparedOperation: app == null
          ? null
          : (call) => call.name == 'mutation.commit'
                ? app.mutations.plan(call.decodedArguments['planId'] as String)
                : null,
      onRunSettled: app?.tools.finishScope,
      onOpenSettings: () {},
    );
    return h;
  }

  void close() {
    runtime.dispose();
    repository.dispose();
    provider.close();
  }
}
