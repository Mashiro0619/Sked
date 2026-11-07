import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/agent_application.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/knowledge/knowledge_service.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/references/agent_composer_reference.dart';
import 'package:sked/agent/references/agent_composer_reference_search.dart';
import 'package:sked/agent/runtime/agent_runtime_controller.dart';
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

  final invalidReference = throwsA(
    isA<AgentRuntimeException>().having(
      (error) => error.code,
      'code',
      AgentRuntimeError.invalidReference,
    ),
  );

  for (final byteLimit in [false, true]) {
    test(
      '${byteLimit ? 'cumulative bytes' : 'Skill count'} is checked before clearing the draft',
      () async {
        final List<AgentComposerReference> references;
        if (byteLimit) {
          await app.agent.knowledge.initialize();
          final records = <String>[];
          for (var index = 0; index < 3; index++) {
            final skill = app.agent.knowledge.newRecord(
              KnowledgeKind.skill,
              title: 'Large workflow $index',
              body: 'x' * 23000,
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
        final before = saved().toJson();
        await expectLater(
          app.agent.runtime.send(id, saved().draft),
          invalidReference,
        );
        expect(provider.requests, isEmpty);
        expect(saved().toJson(), before);
        expect(saved().messages, isEmpty);
        expect(saved().runs, isEmpty);

        final reduced = byteLimit
            ? references.take(2).toList()
            : references.take(8).toList();
        await app.agent.updateComposerReferences(id, reduced);
        await app.agent.runtime.send(id, saved().draft);
        expect(provider.requests, hasLength(1));
        expect(saved().draftReferences, isEmpty);
        expect(
          saved().messages.first.contextReferences,
          hasLength(reduced.length),
        );
        expect(app.agent.runtime.state.value.runFor(id).errorMessage, isNull);
        final text = provider.requests.single.messages
            .lastWhere((message) => message.role == ProviderRole.user)
            .text;
        final context =
            jsonDecode(text.substring(text.lastIndexOf('\n') + 1)) as Map;
        expect(context['selectedSkillInstructions'], hasLength(reduced.length));
      },
    );
  }

  for (final steering in [false, true]) {
    test(
      '${steering ? 'steering' : 'follow-up'} rejects excess Skills before queue acceptance',
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
          final before = saved().toJson();
          await expectLater(
            steering
                ? app.agent.runtime.steer(id, 'Queued workflows')
                : app.agent.runtime.queueFollowUp(id, 'Queued workflows'),
            invalidReference,
          );
          expect(saved().toJson(), before);
          expect(app.agent.runtime.pendingInputCount(id), 0);
          expect(app.agent.runtime.isRunning(id), isTrue);
          expect(provider.requests, hasLength(1));
        } finally {
          release.complete(_done());
          await initial;
        }
      },
    );
  }
}
