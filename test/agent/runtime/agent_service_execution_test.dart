import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/runtime/agent_service.dart';
import 'package:sked/models/agent_settings.dart';

class _Storage extends ConversationStorage {
  _Storage() : super.base();
  String? source;
  @override
  Future<ConversationStorageLoad> load() async =>
      ConversationStorageLoad(source: source);
  @override
  Future<void> save(String value, {required int revision}) async =>
      source = value;
}

class _Provider extends ProviderClient {
  final requests = <ProviderRequest>[];
  final response = StreamController<ProviderEvent>();
  final entered = Completer<void>();
  List<ProviderResponse>? automatic;
  @override
  Stream<ProviderEvent> stream(
    ProviderRequest request, {
    required String apiKey,
    ProviderCancellationToken? cancellation,
  }) {
    requests.add(request);
    if (!entered.isCompleted) entered.complete();
    if (automatic case final replies?) {
      return Stream.value(ProviderCompleted(replies.removeAt(0)));
    }
    return response.stream;
  }
}

const _settings = AgentSettings(
  enabled: true,
  endpoint: 'https://fixture.example/v1',
  model: 'model',
  models: [
    AgentModelConfig(
      id: 'model',
      reasoningEfforts: [AgentReasoningEffort.medium],
      defaultReasoningEffort: AgentReasoningEffort.medium,
    ),
  ],
);

void main() {
  Future<ConversationRepository> repository() async {
    var id = 0;
    final value = ConversationRepository(
      storage: _Storage(),
      idGenerator: () => 'generated-${id++}',
    );
    await value.load();
    await value.create(id: 'one', title: 'First');
    await value.create(id: 'two', title: 'Second');
    addTearDown(value.dispose);
    return value;
  }

  for (final queued in [false, true]) {
    test(
      'first accepted ${queued ? "queued" : "direct"} input derives a title without truncating input',
      () async {
        final store = await repository();
        final provider = _Provider();
        provider.automatic = [
          ProviderResponse(
            text: 'Done',
            toolCalls: const [],
            finishReason: 'stop',
          ),
        ];
        final service = AgentService(
          repository: store,
          provider: provider,
          readSettings: () => _settings,
          readApiKey: (_) async => '',
          readTools: (_) => const [],
          executeTool: (_, _, _) async => const {},
          onOpenSettings: () {},
        );
        addTearDown(service.dispose);
        addTearDown(provider.close);
        final text =
            'Build a semester timetable\n${'Complete original content ' * 6000}';
        if (queued) {
          await store.update(
            'one',
            (current) => current.copyWith(
              queuedInputs: [
                ConversationQueuedInput(
                  id: 'queued-first',
                  text: text,
                  createdAt: DateTime.utc(2026, 11, 7),
                ),
              ],
            ),
          );
          await service.continueConversation('one');
        } else {
          await service.send('one', text);
        }
        expect(store.find('one')!.title, 'Build a semester timetable');
        expect(store.find('one')!.titleWasEdited, isFalse);
        expect(store.find('one')!.messages.first.text, text);
        expect(store.find('one')!.queuedInputs, isEmpty);
        expect(
          provider.requests.single.messages.any(
            (message) => message.text == text,
          ),
          isTrue,
        );
      },
    );
  }

  test('an explicitly renamed conversation keeps its title on first accepted input', () async {
    final store = await repository();
    final provider = _Provider();
    provider.automatic = [
      ProviderResponse(text: 'Done', toolCalls: const [], finishReason: 'stop'),
    ];
    await store.update(
      'one',
      (current) => current.copyWith(title: 'A title chosen by the user'),
    );
    final service = AgentService(
      repository: store,
      provider: provider,
      readSettings: () => _settings,
      readApiKey: (_) async => '',
      readTools: (_) => const [],
      executeTool: (_, _, _) async => const {},
      onOpenSettings: () {},
    );
    addTearDown(service.dispose);
    addTearDown(provider.close);
    await service.send('one', 'Different first message');
    expect(store.find('one')!.title, 'A title chosen by the user');
    expect(store.find('one')!.titleWasEdited, isTrue);
  });

  test('frame publication updates one execution and global reads see the same state', () async {
    final store = await repository();
    final provider = _Provider();
    final service = AgentService(
      repository: store,
      provider: provider,
      readSettings: () => _settings,
      readApiKey: (_) async => '',
      readTools: (_) => const [],
      executeTool: (_, _, _) async => const {},
      onOpenSettings: () {},
    );
    addTearDown(service.dispose);
    addTearDown(provider.close);
    final own = service.watchConversation('one');
    final other = service.watchConversation('two');
    final running = service.send('one', 'Write a response');
    await provider.entered.future;
    var ownUpdates = 0;
    var otherUpdates = 0;
    var configurationUpdates = 0;
    final rendered = Completer<void>();
    final expected = 'part ' * 1000;
    own.addListener(() {
      ownUpdates++;
      if (own.value.streamingText == expected && !rendered.isCompleted) {
        rendered.complete();
      }
    });
    other.addListener(() => otherUpdates++);
    service.state.addListener(() => configurationUpdates++);
    for (var i = 0; i < 1000; i++) {
      provider.response.add(const ProviderTextDelta('part '));
    }
    await rendered.future;
    expect(ownUpdates, lessThan(1000));
    expect(otherUpdates, 0);
    expect(configurationUpdates, 0);
    expect(service.state.value.runFor('one'), same(own.value));
    expect(service.state.value.runs['one'], same(own.value));
    provider.response.add(
      ProviderCompleted(
        ProviderResponse(
          text: expected,
          toolCalls: const [],
          finishReason: 'stop',
          usage: const ProviderUsage(
            inputTokens: 100,
            outputTokens: 3,
            totalTokens: 103,
          ),
        ),
      ),
    );
    await provider.response.close();
    await running;
    expect(service.state.value.runFor('one').isActive, isFalse);
    expect(
      service.state.value.runFor('one').contextUsage!.reportedInputTokens,
      100,
    );
    expect(service.state.value.runFor('one'), same(own.value));
  });

  test('explicit read metadata permits parallel queries while writes wait for the complete group', () async {
    final store = await repository();
    final provider = _Provider();
    provider.automatic = [
      ProviderResponse(
        text: '',
        finishReason: 'tool_calls',
        usage: const ProviderUsage(
          inputTokens: 50,
          outputTokens: 5,
          totalTokens: 55,
        ),
        toolCalls: [
          ProviderToolCall(id: 'read-one', name: 'first.read', arguments: '{}'),
          ProviderToolCall(
            id: 'read-two',
            name: 'second.read',
            arguments: '{}',
          ),
          ProviderToolCall(
            id: 'write',
            name: 'business.apply',
            arguments: '{}',
          ),
        ],
      ),
      ProviderResponse(
        text: 'Saved',
        toolCalls: const [],
        finishReason: 'stop',
        usage: const ProviderUsage(
          inputTokens: 80,
          outputTokens: 2,
          totalTokens: 82,
        ),
      ),
    ];
    final entered = <String>[];
    final bothReads = Completer<void>();
    final releaseOne = Completer<void>();
    final releaseTwo = Completer<void>();
    final service = AgentService(
      repository: store,
      provider: provider,
      readSettings: () => _settings,
      readApiKey: (_) async => '',
      readTools: (_) => [
        for (final name in ['first.read', 'second.read', 'business.apply'])
          ToolDefinition(
            name: name,
            description: name,
            parameters: const {'type': 'object', 'properties': {}},
          ),
      ],
      isReadOnlyTool: (name) =>
          const {'first.read', 'second.read'}.contains(name),
      executeTool: (call, _, _) async {
        entered.add(call.id);
        if (entered.length == 2 && !bothReads.isCompleted) bothReads.complete();
        if (call.id == 'read-one') await releaseOne.future;
        if (call.id == 'read-two') await releaseTwo.future;
        return call.id == 'write'
            ? {'operationId': 'synthetic-operation', 'status': 'committed'}
            : {'items': []};
      },
      onOpenSettings: () {},
    );
    addTearDown(service.dispose);
    addTearDown(provider.close);
    final running = service.send('one', 'Read both sources then write');
    await bothReads.future;
    expect(entered, ['read-one', 'read-two']);
    releaseTwo.complete();
    expect(entered, isNot(contains('write')));
    releaseOne.complete();
    await running;
    expect(entered, ['read-one', 'read-two', 'write']);
    expect(
      store
          .find('one')!
          .messages
          .where((message) => message.role == ConversationRole.tool),
      hasLength(3),
    );
    expect(provider.requests, hasLength(2));
    expect(
      service.state.value.runFor('one').contextUsage!.reportedInputTokens,
      80,
    );
    final tools = provider.requests.last.messages.where(
      (message) => message.role == ProviderRole.tool,
    );
    expect(tools.map((message) => message.toolCallId).toSet(), {
      'read-one',
      'read-two',
      'write',
    });
  });
}
