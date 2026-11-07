import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/history/conversation_history.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/runtime/agent_runtime_controller.dart';
import 'package:sked/agent/store/agent_store.dart';
import 'package:sked/agent/tools/conversation_tool_adapters.dart';
import 'package:sked/agent/tools/workflow_tool_adapters.dart';
import 'package:sked/models/agent_settings.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/models/timetable_models.dart';

import 'tool_adapter_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.utc(2026, 11, 7);
  late AgentStore store;
  late ConversationRepository conversations;
  late ToolAdapterHarness harness;
  late AgentRuntimeController runtime;
  late ConversationToolAdapters adapter;
  late _Provider provider;
  late String target, other;
  final exported = <AgentDataArtifact>[];
  setUp(() async {
    exported.clear();
    store = AgentStore(AgentDatabase(NativeDatabase.memory()));
    conversations = ConversationRepository(storage: store.conversations);
    await conversations.load();
    target = (await conversations.create(
      title: 'Target',
      mode: AgentPermissionMode.full,
    )).id;
    await conversations.update(
      target,
      (current) => current.copyWith(
        messages: [
          for (var i = 0; i < 35; i++) ...[
            ConversationMessage(
              id: 'user-$i',
              role: ConversationRole.user,
              text: 'Private request $i',
              createdAt: now,
            ),
            ConversationMessage(
              id: 'answer-$i',
              role: ConversationRole.assistant,
              text: 'Private answer $i',
              createdAt: now,
            ),
          ],
        ],
        sources: [
          ConversationSource(
            id: 'source',
            kind: 'text',
            text: 'Private source',
          ),
        ],
        runs: [
          for (var i = 0; i < 35; i++)
            ConversationRunUsage(
              id: 'run-$i',
              startedAt: now,
              settledAt: now,
              kind: ConversationRunKind.model,
              protocol: 'chatCompletions',
              model: 'fixture',
              status: ConversationRunStatus.completed,
              requests: [
                ConversationRequestUsage(
                  id: 'request-$i',
                  startedAt: now,
                  outcome: ConversationAttemptOutcome.completed,
                  usage: const ConversationTokenUsage(
                    inputTokens: 90,
                    outputTokens: 10,
                    totalTokens: 100,
                  ),
                ),
              ],
            ),
        ],
        turns: [
          for (var i = 0; i < 35; i++)
            ConversationTurn(
              id: 'turn-$i',
              requestMessageId: 'user-$i',
              ownershipComplete: true,
              messageIds: ['user-$i', 'answer-$i'],
              runIds: ['run-$i'],
            ),
        ],
        runId: 'run-34',
      ),
    );
    other = (await conversations.create(title: 'Other')).id;
    harness = ToolAdapterHarness();
    await harness.initialize(
      data: buildInitialAppData(buildDefaultPeriodTimes()).copyWith(
        agentSettings: const AgentSettings(
          endpoint: 'https://fixture.example/v1',
          model: 'fixture',
          models: [
            AgentModelConfig(
              id: 'fixture',
              reasoningEfforts: [AgentReasoningEffort.medium],
              defaultReasoningEffort: AgentReasoningEffort.medium,
            ),
          ],
        ),
      ),
    );
    provider = _Provider();
    runtime = AgentRuntimeController(
      repository: conversations,
      provider: provider,
      readSettings: () => harness.session.committedData.agentSettings,
      readApiKey: (_) async => '',
      readTools: harness.host.toolsFor,
      executeTool: harness.host.execute,
      onOpenSettings: () {},
    );
    adapter = registerConversationTools(
      harness.host,
      external: harness.external,
      repository: conversations,
      runtime: runtime,
      platformTools: harness.platform,
    );
    adapter.bindServices(
      saveArtifact: (artifact) async {
        exported.add(artifact);
        return const AgentArtifactWriteResult(
          saved: true,
          destination: 'memory://export',
        );
      },
    );
  });
  tearDown(() async {
    runtime.cancelAll();
    await runtime.waitForIdle();
    runtime.dispose();
    conversations.dispose();
    provider.close();
    await harness.close();
    await store.close();
  });
  Future<void> unload(bool selected) async {
    await conversations.select(selected ? target : other);
    await conversations.load();
    expect(conversations.isConversationLoaded(target), isFalse);
  }

  Future<Map<String, Object?>> call(String name, Map<String, Object?> args) =>
      harness.host.execute(
        ProviderToolCall(
          id: 'call-$name',
          name: name,
          arguments: jsonEncode(args),
        ),
        harness.scope,
        (_) async => null,
      );

  for (final selected in [false, true]) {
    test(
      'metadata remains complete without hydrating a ${selected ? 'paged' : 'header-only'} conversation',
      () async {
        await unload(selected);
        final value = await call('conversations.get', {'id': target});
        expect(value['messageCount'], 70);
        expect(value['sourceCount'], 1);
        expect((value['usage'] as Map)['recordedRuns'], 35);
        expect((value['usage'] as Map)['reportedTokens']['totalTokens'], 3500);
        final listing = await call('conversations.list', {'state': 'all'});
        final listed = (listing['conversations'] as List)
            .cast<Map>()
            .singleWhere((item) => item['id'] == target);
        expect(listed['messageCount'], 70);
        expect(listed['sourceCount'], 1);
        expect(jsonEncode(listing), isNot(contains('Private')));
        expect(conversations.isConversationLoaded(target), isFalse);
      },
    );

    test(
      'UI and model exports read the complete ${selected ? 'paged' : 'header-only'} transcript',
      () async {
        await unload(selected);
        await adapter.exportConversation(target);
        await unload(selected);
        final result = await call('conversations.export', {'id': target});
        expect(result['status'], 'applied');
        expect(exported, hasLength(2));
        for (final artifact in exported) {
          final value =
              (jsonDecode(artifact.text) as Map)['conversation'] as Map;
          expect(value['messages'], hasLength(70));
          expect((value['messages'] as List).first['id'], 'user-0');
          expect(value['sources'], hasLength(1));
          expect(value['runs'], hasLength(35));
        }
      },
    );

    test(
      'archive and delete bind a complete ${selected ? 'paged' : 'header-only'} target version',
      () async {
        await unload(selected);
        final archived = await call('conversations.archive', {
          'id': target,
          'archived': true,
        });
        expect(archived['status'], 'applied');
        expect((await store.readConversation(target))!.messages, hasLength(70));
        await unload(selected);
        final deleted = await call('conversations.delete', {'id': target});
        expect(deleted['status'], 'applied');
        expect(await store.readConversation(target), isNull);
        expect(conversations.find(other), isNotNull);
      },
    );

    test(
      'resume finds the real request in a ${selected ? 'paged' : 'header-only'} conversation',
      () async {
        await unload(selected);
        final result = await call('runs.resume', {'conversationId': target});
        expect(result['status'], 'applied');
        await runtime.waitForIdle();
        expect(provider.requests, hasLength(1));
        expect(
          provider.requests.single.messages.any(
            (message) => message.text == 'Private request 0',
          ),
          isTrue,
        );
        final current = (await store.readConversation(target))!;
        expect(current.messages.first.id, 'user-0');
        expect(current.messages, hasLength(71));
        expect(current.turns, hasLength(35));
      },
    );
  }
}

class _Provider extends ProviderClient {
  final requests = <ProviderRequest>[];
  @override
  Stream<ProviderEvent> stream(
    ProviderRequest request, {
    required String apiKey,
    ProviderCancellationToken? cancellation,
  }) async* {
    requests.add(request);
    yield ProviderCompleted(
      ProviderResponse(text: 'Resumed', toolCalls: [], finishReason: 'stop'),
    );
  }
}
