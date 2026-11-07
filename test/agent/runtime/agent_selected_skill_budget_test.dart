import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/agent_application.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/knowledge/knowledge_service.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/references/agent_composer_reference.dart';
import 'package:sked/agent/references/agent_composer_reference_search.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/models/agent_settings.dart';

import '../../support/memory_conversation_storage.dart';
import '../../support/workspace_harness.dart';

ProviderResponse _done() => ProviderResponse(
  text: 'Completed',
  toolCalls: const [],
  finishReason: 'stop',
);

class _Provider extends ProviderClient {
  FutureOr<ProviderResponse> Function(ProviderRequest) respond = (_) => _done();
  final requests = <ProviderRequest>[];

  @override
  Stream<ProviderEvent> stream(
    ProviderRequest request, {
    required String apiKey,
    ProviderCancellationToken? cancellation,
  }) async* {
    requests.add(request);
    yield ProviderCompleted(await respond(request));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppRuntime app;
  late _Provider provider;
  late MemoryConversationStorage storage;
  late String id;

  AgentConversation saved() =>
      ConversationArchive.decode(storage.source!).conversations.single;

  Future<List<AgentComposerReference>> builtins(int count) async {
    final search = await app.agent.createReferenceSearch(id);
    final result = await search.search('', limitPerGroup: 20);
    return result
        .group(AgentComposerReferenceGroup.skill)
        .candidates
        .where((candidate) => candidate.isSelectable)
        .take(count)
        .map((candidate) => candidate.reference)
        .toList();
  }

  setUp(() async {
    provider = _Provider();
    storage = MemoryConversationStorage();
    app = await workspaceProvider(
      agentProvider: provider,
      agentConversationStorage: storage,
    );
    await app.agent.configure(
      const AgentSettings(
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
    );
    await app.agent.setEnabled(true);
    id = (await app.agent.conversations.create(title: 'Skill allowance')).id;
    await app.agent.conversations.update(
      id,
      (current) => current.copyWith(draft: 'Use the selected workflows.'),
    );
  });

  tearDown(() async {
    await app.agent.quiesce();
    app.dispose();
  });

  for (final byteLimit in [false, true]) {
    test(
      'selected ${byteLimit ? 'large Skill bodies' : 'Skills above eight'} are all accepted',
      () async {
        final List<AgentComposerReference> references;
        if (byteLimit) {
          await app.agent.knowledge.initialize();
          final records = <String>[];
          for (var index = 0; index < 3; index++) {
            final skill = app.agent.knowledge.newRecord(
              KnowledgeKind.skill,
              title: 'Large workflow $index',
              body: 'x' * 96000,
              summary: 'Synthetic large workflow',
            );
            await app.agent.knowledge.saveFromUi(
              app.agent.knowledge.prepareSave(skill),
            );
            records.add(skill.id);
          }
          final search = await app.agent.createReferenceSearch(id);
          references = [
            for (final record in records)
              (await search.search(record))
                  .group(AgentComposerReferenceGroup.skill)
                  .candidates
                  .single
                  .reference,
          ];
        } else {
          references = await builtins(9);
        }
        await app.agent.updateComposerReferences(id, references);
        if (byteLimit) {
          provider.respond = (_) => provider.requests.length == 1
              ? ProviderResponse(
                  text: '',
                  toolCalls: [
                    ProviderToolCall(
                      id: 'load-large',
                      name: 'skills.load',
                      arguments: jsonEncode({'id': references.first.skillId}),
                    ),
                  ],
                  finishReason: 'tool_calls',
                )
              : _done();
        }
        await app.agent.runtime.send(id, saved().draft);
        expect(provider.requests, hasLength(byteLimit ? 2 : 1));
        if (byteLimit) {
          final result = provider.requests.last.messages.lastWhere(
            (message) => message.role == ProviderRole.tool,
          );
          expect(jsonDecode(result.text)['instructions'], 'x' * 96000);
        }
        expect(saved().draftReferences, isEmpty);
        expect(
          saved().messages.first.contextReferences,
          hasLength(references.length),
        );
        expect(app.agent.runtime.state.value.runFor(id).errorMessage, isNull);
        final text = provider.requests.first.messages
            .lastWhere((message) => message.role == ProviderRole.user)
            .text;
        final context =
            jsonDecode(text.substring(text.lastIndexOf('\n') + 1)) as Map;
        expect(
          context['selectedSkillInstructions'],
          hasLength(references.length),
        );
      },
    );
  }

  for (final steering in [false, true]) {
    test(
      '${steering ? 'steering' : 'follow-up'} accepts all selected Skills',
      () async {
        final entered = Completer<void>();
        final release = Completer<ProviderResponse>();
        provider.respond = (_) {
          entered.complete();
          return release.future;
        };
        final initial = app.agent.runtime.send(id, 'Initial task');
        try {
          await entered.future;
          final references = await builtins(9);
          await app.agent.updateComposerReferences(id, references);
          await app.agent.conversations.update(
            id,
            (current) => current.copyWith(draft: 'Queued workflows'),
          );
          if (steering) {
            await app.agent.runtime.steer(id, 'Queued workflows');
          } else {
            await app.agent.runtime.queueFollowUp(id, 'Queued workflows');
          }
          expect(app.agent.runtime.pendingInputCount(id), 1);
          expect(saved().queuedInputs.single.contextReferences, hasLength(9));
          expect(provider.requests, hasLength(1));
        } finally {
          provider.respond = (_) => _done();
          release.complete(_done());
          await initial;
        }
      },
    );
  }
}
