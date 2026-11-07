import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/context/context_checkpoint.dart';
import 'package:sked/agent/context/context_service.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/runtime/agent_service.dart';
import 'package:sked/models/agent_settings.dart';

AgentModelConfig _model(
  String id,
  int window, {
  bool auto = true,
  int? trigger,
}) => AgentModelConfig(
  id: id,
  reasoningEfforts: const [AgentReasoningEffort.medium],
  defaultReasoningEffort: AgentReasoningEffort.medium,
  maxContextTokens: window,
  autoCompact: auto,
  autoCompactAtTokens: trigger,
);
AgentSettings _settings(AgentModelConfig first) => AgentSettings(
  endpoint: 'https://fixture.example/v1',
  model: 'A',
  models: [first, _model('B', 32000)],
);
ProviderResponse _done() => ProviderResponse(
  text: 'Done',
  toolCalls: const [],
  finishReason: 'stop',
  usage: const ProviderUsage(
    inputTokens: 100,
    outputTokens: 10,
    totalTokens: 110,
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final togglesAuto in [false, true]) {
    test(
      'a running model reads the updated ${togglesAuto ? 'automatic switch' : 'threshold'} before its next request',
      () async {
        final fixture = await _Fixture.create(
          _model(
            'A',
            128000,
            auto: !togglesAuto,
            trigger: togglesAuto ? 1 : 100000,
          ),
        );
        addTearDown(fixture.close);
        final entered = Completer<void>(), release = Completer<void>();
        fixture.unblock = () {
          if (!release.isCompleted) release.complete();
        };
        fixture.execute = () async {
          entered.complete();
          await release.future;
          return {'items': []};
        };
        fixture.provider.respond = (_) => fixture.provider.requests.length == 1
            ? ProviderResponse(
                text: '',
                finishReason: 'tool_calls',
                toolCalls: [
                  ProviderToolCall(
                    id: 'read',
                    name: 'events.list',
                    arguments: '{}',
                  ),
                ],
              )
            : _done();
        final running = fixture.service.send('chat', 'Read then answer');
        await entered.future;
        final runId = fixture.repository.find('chat')!.runId;
        expect(fixture.context.compactions, isEmpty);
        fixture.settings = _settings(_model('A', 128000, trigger: 1));
        fixture.service.refreshSettings();
        release.complete();
        await running;
        expect(fixture.context.compactions, hasLength(1));
        expect(fixture.context.compactions.single.model.id, 'A');
        expect(fixture.context.compactions.single.model.autoCompact, isTrue);
        expect(fixture.context.compactions.single.model.autoCompactAtTokens, 1);
        expect(fixture.provider.requests.map((request) => request.model), [
          'A',
          'A',
        ]);
        expect(fixture.repository.find('chat')!.runs.single.id, runId);
      },
    );
  }

  test('an idle model switch clears the previous model measurement', () async {
    final fixture = await _Fixture.create(_model('A', 128000));
    addTearDown(fixture.close);
    fixture.provider.respond = (_) => _done();
    await fixture.service.send('chat', 'Answer');
    final before = fixture.service.state.value.runFor('chat').contextUsage!;
    expect(before.modelId, 'A');
    expect(before.estimatedTokens, isNotNull);
    expect(before.reportedInputTokens, 100);
    await fixture.service.setModelSelection(
      'chat',
      const AgentModelSelection(
        modelId: 'B',
        reasoningEffort: AgentReasoningEffort.medium,
      ),
    );
    final after = fixture.service.state.value.runFor('chat').contextUsage!;
    expect(after.modelId, 'B');
    expect(after.maxContextTokens, 32000);
    expect(after.autoCompactAtTokens, 25600);
    expect(after.estimatedTokens, isNull);
    expect(after.reportedInputTokens, isNull);
  });

  test('choosing the next model during a request retains the active model context identity', () async {
    final fixture = await _Fixture.create(_model('A', 128000));
    addTearDown(fixture.close);
    final entered = Completer<void>(), response = Completer<ProviderResponse>();
    fixture.unblock = () {
      if (!response.isCompleted) response.complete(_done());
    };
    fixture.provider.respond = (_) {
      entered.complete();
      return response.future;
    };
    final running = fixture.service.send('chat', 'Answer');
    await entered.future;
    await fixture.service.setModelSelection(
      'chat',
      const AgentModelSelection(
        modelId: 'B',
        reasoningEffort: AgentReasoningEffort.medium,
      ),
    );
    expect(fixture.repository.find('chat')!.modelSelection!.modelId, 'B');
    final active = fixture.service.state.value.runFor('chat').contextUsage!;
    expect(active.modelId, 'A');
    expect(active.maxContextTokens, 128000);
    expect(active.estimatedTokens, isNotNull);
    response.complete(_done());
    await running;
    expect(fixture.provider.requests.single.model, 'A');
    final idle = fixture.service.state.value.runFor('chat').contextUsage!;
    expect(idle.modelId, 'B');
    expect(idle.estimatedTokens, isNull);
    expect(idle.reportedInputTokens, isNull);
  });

  for (final target in ['chat', 'another-chat']) {
    test(
      'reported input usage belongs to the completed request when the next request uses $target',
      () async {
        final fixture = await _Fixture.create(_model('A', 128000, auto: false));
        addTearDown(fixture.close);
        if (target != 'chat') {
          await fixture.repository.create(id: target, title: 'Another context');
        }
        fixture.provider.respond = (_) => _done();
        await fixture.service.send('chat', 'Complete the first request');
        expect(
          fixture.service
              .watchConversation('chat')
              .value
              .contextUsage!
              .reportedInputTokens,
          100,
        );

        final entered = Completer<void>(),
            response = Completer<ProviderResponse>();
        fixture.unblock = () {
          if (!response.isCompleted) response.complete(_done());
        };
        fixture.provider.respond = (_) {
          entered.complete();
          return response.future;
        };
        final running = fixture.service.send(
          target,
          'Start a new request using the same model',
        );
        await entered.future;

        final pending = fixture.service
            .watchConversation(target)
            .value
            .contextUsage!;
        expect(pending.estimatedTokens, isNotNull);
        expect(pending.reportedInputTokens, isNull);
        if (target != 'chat') {
          expect(
            fixture.service
                .watchConversation('chat')
                .value
                .contextUsage!
                .reportedInputTokens,
            100,
          );
        }

        response.complete(
          ProviderResponse(
            text: 'Second request complete',
            toolCalls: const [],
            finishReason: 'stop',
            usage: const ProviderUsage(
              inputTokens: 240,
              outputTokens: 10,
              totalTokens: 250,
            ),
          ),
        );
        await running;
        expect(
          fixture.service
              .watchConversation(target)
              .value
              .contextUsage!
              .reportedInputTokens,
          240,
        );
        if (target != 'chat') {
          expect(
            fixture.service
                .watchConversation('chat')
                .value
                .contextUsage!
                .reportedInputTokens,
            100,
          );
        }
      },
    );
  }
}

class _Fixture {
  _Fixture(this.settings);
  AgentSettings settings;
  late ConversationRepository repository;
  final provider = _Provider();
  late _Context context;
  late AgentService service;
  Future<Map<String, Object?>> Function()? execute;
  void Function()? unblock;
  static Future<_Fixture> create(AgentModelConfig first) async {
    final value = _Fixture(_settings(first));
    value.repository = ConversationRepository(storage: _Storage());
    await value.repository.load();
    await value.repository.create(id: 'chat', title: 'Context');
    value.context = _Context(provider: value.provider, store: _Checkpoints());
    value.service = AgentService(
      repository: value.repository,
      provider: value.provider,
      contextService: value.context,
      readSettings: () => value.settings,
      readApiKey: (_) async => '',
      readTools: (_) => [
        ToolDefinition(
          name: 'events.list',
          description: 'Read events',
          parameters: const {'type': 'object', 'properties': {}},
        ),
      ],
      executeTool: (_, _, _) async =>
          value.execute == null ? {'items': []} : await value.execute!(),
      onOpenSettings: () {},
    );
    return value;
  }

  Future<void> close() async {
    unblock?.call();
    service.cancelAll();
    await service.waitForIdle();
    service.dispose();
    repository.dispose();
    provider.close();
  }
}

class _Context extends ContextService {
  _Context({required super.provider, required super.store});
  final compactions = <ContextSnapshot>[];
  @override
  Future<bool> compact(
    ContextSnapshot snapshot, {
    required String apiKey,
    required ProviderCancellationToken cancellation,
    bool manual = false,
    void Function()? validateSource,
    Future<void> Function()? beforeRequest,
    Future<ProviderResponse> Function(ProviderRequest request)? executeRequest,
  }) async {
    validateSource?.call();
    compactions.add(snapshot);
    return false;
  }
}

class _Provider extends ProviderClient {
  late FutureOr<ProviderResponse> Function(ProviderRequest) respond;
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

class _Checkpoints implements ContextCheckpointStore {
  @override
  Future<ContextCheckpoint?> latest(String id) async => null;
  @override
  Future<void> append(
    ContextCheckpoint checkpoint, {
    void Function()? validate,
  }) async => validate?.call();
  @override
  Future<void> clear(String id) async {}
  @override
  Future<ContextCompactionFailure?> failedSource(String id, String key) async =>
      null;
  @override
  Future<void> saveFailure(ContextCompactionFailure failure) async {}
  @override
  Future<void> clearFailure(String id, String key) async {}
}
