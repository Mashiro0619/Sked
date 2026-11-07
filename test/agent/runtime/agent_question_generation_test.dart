import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/connection/agent_credential_store.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/interactions/agent_question.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/ui/agent_ui_delegate.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/models/agent_settings.dart';
import 'package:sked/models/timetable_models.dart';

import '../../support/memory_conversation_storage.dart';
import '../../support/workspace_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final answered in [false, true]) {
    test(
      'a question with answered=$answered survives a full application restart and explicit continue',
      () async {
        final h = _Harness();
        addTearDown(h.close);
        final firstProvider = _Provider()..respond = (_) => _ask();
        final first = await h.open(firstProvider);
        final id = await _ready(first);
        expect(h.storage.data.applicationLedger, isNull);
        final businessBefore = _businessData(h.storage.data.toJson());
        final run = first.agent.runtime.send(
          id,
          'Ask for the missing information',
        );
        await _waitUntil(
          first,
          id,
          () =>
              first.agent.runtime.state.value.runFor(id).phase ==
              AgentUiPhase.waitingUser,
        );
        final original = first.agent.conversations.find(id)!.pendingQuestion!;
        final generation = original.datasetGeneration;
        expect(generation, isNotNull);
        expect(h.storage.data.applicationLedger!.generation, generation);
        expect(h.storage.data.applicationLedger!.receipts, isEmpty);
        expect(h.storage.data.applicationLedger!.nextSequence, 1);
        expect(_businessData(h.storage.data.toJson()), businessBefore);
        await first.agent.runtime.stop(id);
        await run;
        expect(firstProvider.requests, hasLength(1));
        expect(
          first.agent.conversations.find(id)!.pendingQuestion!.id,
          original.id,
        );
        if (answered) {
          // A durable answer may precede interruption before its tool result is
          // finalized. Reopen that supported persisted state through the app.
          await first.agent.conversations.update(
            id,
            (current) => current.copyWith(
              pendingQuestion: current.pendingQuestion!.withAnswers(_answers()),
            ),
          );
        }
        await h.closeApp(first);

        final resumedProvider = _Provider();
        final resumed = await h.open(resumedProvider);
        await resumed.agent.initialize();
        expect(resumed.agent.mutations.generation, generation);
        expect(
          resumed.agent.conversations.find(id)!.pendingQuestion!.id,
          original.id,
        );
        expect(
          resumed.agent.conversations.find(id)!.pendingQuestion!.isResolved,
          answered,
        );
        expect(resumedProvider.requests, isEmpty);
        final continued = resumed.agent.runtime.continueConversation(id);
        if (!answered) {
          await _waitUntil(
            resumed,
            id,
            () =>
                resumed.agent.runtime.state.value.runFor(id).phase ==
                AgentUiPhase.waitingUser,
          );
          expect(
            resumed.agent.conversations.find(id)!.pendingQuestion!.id,
            original.id,
          );
          expect(resumedProvider.requests, isEmpty);
          await resumed.agent.runtime.answerQuestion(
            id,
            original.id,
            _answers(),
          );
        }
        await continued;
        expect(resumedProvider.requests, hasLength(1));
        final tool = resumedProvider.requests.single.messages.singleWhere(
          (message) =>
              message.role == ProviderRole.tool &&
              message.toolCallId == original.toolCallId,
        );
        final result = jsonDecode(tool.text) as Map;
        expect(result['status'], 'answered');
        expect(result['questionId'], original.id);
        expect(
          result['answers'],
          _answers().map((answer) => answer.toJson()).toList(),
        );
        expect(result.containsKey('contextChanged'), false);
        expect(resumed.agent.conversations.find(id)!.pendingQuestion, isNull);
        expect(
          resumed.agent.conversations.find(id)!.status,
          ConversationStatus.idle,
        );
        expect(
          resumed.agent.runtime.state.value.runFor(id).errorMessage,
          isNull,
        );
        expect(h.storage.data.applicationLedger!.generation, generation);
        expect(h.storage.data.applicationLedger!.receipts, isEmpty);
        expect(h.storage.data.applicationLedger!.nextSequence, 1);
        expect(_businessData(h.storage.data.toJson()), businessBefore);
      },
    );
  }

  test(
    'ordinary application read queries keep their namespace ephemeral',
    () async {
      final h = _Harness();
      addTearDown(h.close);
      final provider = _Provider();
      provider.respond = (_) => switch (provider.requests.length) {
        1 => _call('discover', 'capabilities.describe', {
          'names': ['calendars.list'],
        }),
        2 => _call('read', 'calendars.list', {}),
        _ => _done(),
      };
      final app = await h.open(provider);
      final id = await _ready(app);
      final before = jsonEncode(h.storage.data.toJson());
      expect(h.storage.data.applicationLedger, isNull);
      await app.agent.runtime.send(id, 'List my calendars');
      expect(provider.requests, hasLength(3));
      expect(app.agent.runtime.state.value.runFor(id).errorMessage, isNull);
      expect(h.storage.data.applicationLedger, isNull);
      expect(jsonEncode(h.storage.data.toJson()), before);
    },
  );

  test(
    'stop during namespace persistence prevents question publication',
    () async {
      final h = _Harness();
      addTearDown(h.close);
      final provider = _Provider()..respond = (_) => _ask();
      final app = await h.open(provider);
      final id = await _ready(app);
      final entered = Completer<void>();
      final release = Completer<void>();
      h.storage.beforeNamespaceSave = () async {
        if (!entered.isCompleted) entered.complete();
        await release.future;
      };
      final run = app.agent.runtime.send(id, 'Ask for details');
      try {
        await entered.future.timeout(const Duration(seconds: 5));
        expect(provider.requests, hasLength(1));
        await app.agent.runtime.stop(id);
      } finally {
        h.storage.beforeNamespaceSave = null;
        if (!release.isCompleted) release.complete();
      }
      await run;
      expect(h.storage.data.applicationLedger!.receipts, isEmpty);
      expect(h.storage.data.applicationLedger!.nextSequence, 1);
      expect(app.agent.conversations.find(id)!.pendingQuestion, isNull);
      expect(
        app.agent.conversations.find(id)!.status,
        ConversationStatus.interrupted,
      );
    },
  );
}

const _settings = AgentSettings(
  enabled: true,
  endpoint: 'https://fixture.example/v1',
  model: 'fixture',
  models: [
    AgentModelConfig(
      id: 'fixture',
      reasoningEfforts: [AgentReasoningEffort.medium],
      defaultReasoningEffort: AgentReasoningEffort.medium,
    ),
  ],
);

Future<String> _ready(AppRuntime app) async {
  await app.agent.configure(_settings);
  await app.agent.setEnabled(true);
  return (await app.agent.conversations.create(
    title: 'Question generation',
    mode: AgentPermissionMode.plan,
  )).id;
}

List<AgentQuestionAnswer> _answers() => [
  AgentQuestionAnswer(questionId: 'detail', text: 'Use the morning'),
];

ProviderResponse _ask() => _call('ask-call', 'ask_user', {
  'questions': [
    {'id': 'detail', 'question': 'Which part of the day should I use?'},
  ],
});

ProviderResponse _call(
  String id,
  String name,
  Map<String, Object?> arguments,
) => ProviderResponse(
  text: '',
  toolCalls: [
    ProviderToolCall(id: id, name: name, arguments: jsonEncode(arguments)),
  ],
  finishReason: 'tool_calls',
);

ProviderResponse _done() => ProviderResponse(
  text: 'The answer is recorded.',
  toolCalls: [],
  finishReason: 'stop',
);

Map<String, Object?> _businessData(Map<String, Object?> data) =>
    Map<String, Object?>.from(data)..remove('applicationLedger');

Future<void> _waitUntil(
  AppRuntime app,
  String conversationId,
  bool Function() predicate,
) async {
  if (predicate()) return;
  final execution = app.agent.runtime.watchConversation(conversationId);
  final done = Completer<void>();
  void changed() {
    if (!done.isCompleted && predicate()) done.complete();
  }

  execution.addListener(changed);
  app.agent.conversations.addListener(changed);
  try {
    changed();
    await done.future.timeout(const Duration(seconds: 5));
  } finally {
    execution.removeListener(changed);
    app.agent.conversations.removeListener(changed);
  }
}

class _Provider extends ProviderClient {
  final requests = <ProviderRequest>[];
  ProviderResponse Function(ProviderRequest) respond = (_) => _done();
  @override
  Stream<ProviderEvent> stream(
    ProviderRequest request, {
    required String apiKey,
    ProviderCancellationToken? cancellation,
  }) async* {
    requests.add(request);
    yield ProviderCompleted(respond(request));
  }
}

class _Harness {
  final storage = _GenerationStorage();
  final conversations = MemoryConversationStorage();
  final credentials = MemoryAgentCredentialStore();
  final apps = <AppRuntime>[];

  Future<AppRuntime> open(_Provider provider) async {
    final app = await workspaceProvider(
      storage: storage,
      agentConversationStorage: conversations,
      agentCredentialStore: credentials,
      agentProvider: provider,
    );
    apps.add(app);
    return app;
  }

  Future<void> closeApp(AppRuntime app) async {
    await app.agent.quiesce();
    app.dispose();
    apps.remove(app);
  }

  Future<void> close() async {
    for (final app in apps.toList().reversed) {
      await closeApp(app);
    }
  }
}

class _GenerationStorage extends WorkspaceMemoryStorage {
  _GenerationStorage() : super(buildInitialAppData(buildDefaultPeriodTimes()));
  Future<void> Function()? beforeNamespaceSave;

  @override
  Future<void> save(AppData value) async {
    if (data.applicationLedger == null && value.applicationLedger != null) {
      await beforeNamespaceSave?.call();
    }
    await super.save(value);
  }
}
