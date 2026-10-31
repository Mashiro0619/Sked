import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/runtime/agent_runtime_controller.dart';
import 'package:sked/models/agent_settings.dart';

const _a = AgentModelSelection(
  modelId: 'model-a',
  reasoningEffort: AgentReasoningEffort.high,
);
const _b = AgentModelSelection(
  modelId: 'model-b',
  reasoningEffort: AgentReasoningEffort.low,
);
const _models = [
  AgentModelConfig(
    id: 'model-a',
    reasoningEfforts: [AgentReasoningEffort.auto, AgentReasoningEffort.high],
  ),
  AgentModelConfig(
    id: 'model-b',
    reasoningEfforts: [AgentReasoningEffort.auto, AgentReasoningEffort.low],
  ),
];

void main() {
  test('creation keeps its default before first send while legacy empty choices remain compatible', () async {
    final h = await _Harness.create((_, _) => _complete());
    addTearDown(h.dispose);
    final created = await h.repository.create(
      title: 'Created with A',
      modelSelection: h.settings.defaultModelSelection,
    );
    h.settings = h.settings.copyWith(model: 'model-b');
    h.runtime.refreshSettings();
    await h.runtime.send(created.id, 'first request after defaults changed');
    expect(h.provider.requests.last.model, 'model-a');

    // Missing selections in old archives or chats created before configuring
    // models remain unresolved until the user's first actual send.
    expect(h.repository.find(h.id)!.modelSelection, isNull);
    await h.runtime.send(h.id, 'first request with a legacy empty selection');
    expect(h.provider.requests.last.model, 'model-b');
    final archive = ConversationArchive.decode(h.storage.source!);
    expect(
      archive.conversations
          .singleWhere((c) => c.id == created.id)
          .modelSelection,
      const AgentModelSelection(modelId: 'model-a'),
    );
    expect(
      archive.conversations.singleWhere((c) => c.id == h.id).modelSelection,
      const AgentModelSelection(modelId: 'model-b'),
    );
  });

  test('selection is frozen across tool rounds while another conversation uses its own model', () async {
    final first = StreamController<ProviderEvent>();
    final entered = Completer<void>();
    var requests = 0;
    final h = await _Harness.create((request, _) {
      if (requests++ == 0) {
        entered.complete();
        return first.stream;
      }
      return _complete();
    });
    addTearDown(h.dispose);
    await h.runtime.setModelSelection(h.id, _a);
    final pending = h.runtime.send(h.id, 'read my agenda');
    await entered.future;
    await h.runtime.setModelSelection(h.id, _b);
    final other = await h.repository.create(title: 'other');
    await h.runtime.setModelSelection(other.id, _b);
    await h.runtime.send(other.id, 'another request');
    h.settings = h.settings.copyWith(model: 'model-b', models: [_models[1]]);
    h.runtime.refreshSettings();
    first.add(
      ProviderCompleted(
        ProviderResponse(
          text: '',
          toolCalls: [
            ProviderToolCall(
              id: 'read-1',
              name: 'events.list',
              arguments: '{}',
            ),
          ],
          finishReason: 'tool_calls',
        ),
      ),
    );
    await first.close();
    await pending;
    expect(h.provider.requests.map((r) => (r.model, r.reasoningEffort)), [
      ('model-a', 'high'),
      ('model-b', 'low'),
      ('model-a', 'high'),
    ]);
    expect(
      h.repository.find(h.id)!.runs.last.reasoningEffort,
      AgentReasoningEffort.high,
    );
    expect(h.repository.find(other.id)!.modelSelection, _b);
    await h.runtime.send(h.id, 'use my new selection');
    expect(h.provider.requests.last.model, 'model-b');
    expect(h.provider.requests.last.reasoningEffort, 'low');
  });

  test(
    'queued inputs keep their own selection after the composer changes again',
    () async {
      final first = StreamController<ProviderEvent>();
      final entered = Completer<void>();
      var requests = 0;
      final h = await _Harness.create((_, _) {
        if (requests++ == 0) {
          entered.complete();
          return first.stream;
        }
        return _complete();
      });
      addTearDown(h.dispose);
      await h.runtime.setModelSelection(h.id, _a);
      final sending = h.runtime.send(h.id, 'first');
      await entered.future;
      await h.runtime.setModelSelection(h.id, _b);
      await h.runtime.queueFollowUp(h.id, 'queued');
      await h.runtime.setModelSelection(h.id, _a);
      first.add(_done());
      await first.close();
      await sending;
      await h.runtime.waitForIdle();
      expect(h.provider.requests.map((r) => (r.model, r.reasoningEffort)), [
        ('model-a', 'high'),
        ('model-b', 'low'),
      ]);
      final queued = h.repository
          .find(h.id)!
          .messages
          .singleWhere((m) => m.text == 'queued');
      expect(queued.modelSelection, _b);
      expect(h.repository.find(h.id)!.modelSelection, _a);
      final reloaded = ConversationArchive.decode(h.storage.source!);
      expect(reloaded.conversations.single.modelSelection, _a);
      expect(
        reloaded.conversations.single.runs.last.reasoningEffort,
        AgentReasoningEffort.low,
      );
    },
  );

  test('removed queued choice waits for explicit reselection and continue without losing input', () async {
    final first = StreamController<ProviderEvent>();
    final entered = Completer<void>();
    var requests = 0;
    final h = await _Harness.create((_, _) {
      if (requests++ == 0) {
        entered.complete();
        return first.stream;
      }
      return _complete();
    });
    addTearDown(h.dispose);
    await h.runtime.setModelSelection(h.id, _a);
    final sending = h.runtime.send(h.id, 'first');
    await entered.future;
    await h.runtime.setModelSelection(h.id, _b);
    await h.runtime.queueFollowUp(h.id, 'keep this request');
    h.settings = h.settings.copyWith(model: 'model-a', models: [_models[0]]);
    h.runtime.refreshSettings();
    first.add(_done());
    await first.close();
    await sending;
    await h.runtime.waitForIdle();
    expect(h.provider.requests, hasLength(1));
    expect(h.runtime.pendingInputCount(h.id), 1);
    expect(h.runtime.state.value.runFor(h.id).requiresModelSelection, isTrue);
    await h.runtime.setModelSelection(h.id, _a);
    expect(h.provider.requests, hasLength(1));
    expect(h.runtime.pendingInputCount(h.id), 1);
    await h.runtime.continueConversation(h.id);
    expect(h.provider.requests, hasLength(2));
    expect(h.provider.requests.last.model, 'model-a');
    expect(h.runtime.pendingInputCount(h.id), 0);
    expect(
      h.repository
          .find(h.id)!
          .messages
          .where((m) => m.text == 'keep this request'),
      hasLength(1),
    );
  });

  test('changing models keeps text and tool results but never reuses opaque reasoning', () async {
    var requests = 0;
    const opaque = <Map<String, Object?>>[
      {
        'type': 'reasoning',
        'id': 'reason-a',
        'encrypted_content': 'model-a-private-state',
        'summary': [],
      },
    ];
    final h = await _Harness.create(
      (_, _) => Stream.value(
        ProviderCompleted(
          ProviderResponse(
            text: 'A readable answer',
            toolCalls: const [],
            finishReason: 'stop',
            responseItems: requests++ == 0 ? opaque : const [],
          ),
        ),
      ),
      protocol: AgentModelProtocol.responses,
    );
    addTearDown(h.dispose);
    await h.runtime.setModelSelection(h.id, _a);
    await h.runtime.send(h.id, 'first');
    await h.runtime.setModelSelection(h.id, _b);
    await h.runtime.send(h.id, 'continue with another model');
    expect(
      h.provider.requests.last.messages.every((m) => m.responseItems.isEmpty),
      isTrue,
    );
    expect(
      h.provider.requests.last.messages.any(
        (m) => m.text == 'A readable answer',
      ),
      isTrue,
    );
    final original = h.repository
        .find(h.id)!
        .messages
        .firstWhere((m) => m.role == ConversationRole.assistant);
    expect(original.responseItems, opaque);
    expect(original.modelSelection, _a);
    expect(original.providerProtocol, AgentModelProtocol.responses);
  });

  test('repairing a queued model as a run settles still waits for explicit continue', () async {
    final first = StreamController<ProviderEvent>();
    final entered = Completer<void>();
    var requests = 0;
    final h = await _Harness.create((_, _) {
      if (requests++ == 0) {
        entered.complete();
        return first.stream;
      }
      return _complete();
    });
    addTearDown(h.dispose);
    await h.runtime.setModelSelection(h.id, _a);
    final sending = h.runtime.send(h.id, 'first');
    await entered.future;
    await h.runtime.setModelSelection(h.id, _b);
    await h.runtime.queueFollowUp(h.id, 'wait for my confirmation');
    h.settings = h.settings.copyWith(model: 'model-a', models: [_models[0]]);
    h.runtime.refreshSettings();

    final settling = Completer<void>();
    final release = Completer<void>();
    h.storage.beforeSave = (source) async {
      final conversation = ConversationArchive.decode(source)
          .conversations
          .single;
      if (!settling.isCompleted &&
          conversation.status == ConversationStatus.idle &&
          conversation.runs.last.status == ConversationRunStatus.completed) {
        settling.complete();
        await release.future;
      }
    };
    first.add(_done());
    final closed = first.close();
    await settling.future;
    final repair = h.runtime.setModelSelection(h.id, _a);
    release.complete();
    await Future.wait([repair, sending, closed]);
    await h.runtime.waitForIdle();

    expect(h.provider.requests, hasLength(1));
    expect(h.runtime.pendingInputCount(h.id), 1);
    expect(h.runtime.state.value.runFor(h.id).requiresModelSelection, isFalse);
    await h.runtime.continueConversation(h.id);
    expect(h.provider.requests, hasLength(2));
    expect(h.provider.requests.last.model, 'model-a');
    expect(h.runtime.pendingInputCount(h.id), 0);
  });

  test('HTTP grants follow the requested model and survive unrelated default changes', () async {
    final h = await _Harness.create((_, _) => _complete());
    addTearDown(h.dispose);
    h.settings = h.settings.copyWith(endpoint: 'http://models.example/v1');
    h.runtime.refreshSettings();
    await h.runtime.setModelSelection(h.id, _a);

    final first = h.runtime.send(h.id, 'model A');
    await _waitForApproval(h.runtime, h.id);
    expect(h.provider.requests, isEmpty);
    await h.runtime.approve(
      h.id,
      h.runtime.state.value.runFor(h.id).pendingApproval!.id,
    );
    await first;

    h.settings = h.settings.copyWith(model: 'model-b');
    h.runtime.refreshSettings();
    await h.runtime
        .send(h.id, 'still model A')
        .timeout(const Duration(seconds: 5));
    expect(h.provider.requests.map((r) => r.model), ['model-a', 'model-a']);

    await h.runtime.setModelSelection(h.id, _b);
    final secondModel = h.runtime.send(h.id, 'model B');
    await _waitForApproval(h.runtime, h.id);
    expect(h.provider.requests, hasLength(2));
    await h.runtime.approve(
      h.id,
      h.runtime.state.value.runFor(h.id).pendingApproval!.id,
    );
    await secondModel;
    expect(h.provider.requests.last.model, 'model-b');

    await h.runtime.setModelSelection(h.id, _a);
    await h.runtime
        .send(h.id, 'return to A')
        .timeout(const Duration(seconds: 5));
    expect(h.provider.requests.last.model, 'model-a');
    expect(h.provider.requests, hasLength(4));

    h.settings = h.settings.copyWith(credentialRef: 'replacement-credential');
    h.runtime.refreshSettings();
    final afterReplacement = h.runtime.send(h.id, 'credential changed');
    await _waitForApproval(h.runtime, h.id);
    expect(h.provider.requests, hasLength(4));
    await h.runtime.reject(
      h.id,
      h.runtime.state.value.runFor(h.id).pendingApproval!.id,
    );
    await afterReplacement;
    expect(h.provider.requests, hasLength(4));
  });

  test('an invalid per-model effort is rejected before saving a selection or sending', () async {
    final h = await _Harness.create((_, _) => _complete());
    addTearDown(h.dispose);
    await expectLater(
      h.runtime.setModelSelection(
        h.id,
        const AgentModelSelection(
          modelId: 'model-b',
          reasoningEffort: AgentReasoningEffort.high,
        ),
      ),
      throwsA(
        isA<AgentRuntimeException>().having(
          (e) => e.code,
          'code',
          AgentRuntimeError.modelSelectionRequired,
        ),
      ),
    );
    expect(h.repository.find(h.id)!.modelSelection, isNull);
    expect(h.provider.requests, isEmpty);
  });
}

ProviderCompleted _done() => ProviderCompleted(
  ProviderResponse(text: 'done', toolCalls: const [], finishReason: 'stop'),
);
Stream<ProviderEvent> _complete() => Stream.value(_done());

Future<void> _waitForApproval(AgentRuntimeController runtime, String id) async {
  final ready = Completer<void>();
  void changed() {
    if (runtime.state.value.runFor(id).pendingApproval != null &&
        !ready.isCompleted) {
      ready.complete();
    }
  }

  runtime.state.addListener(changed);
  try {
    changed();
    await ready.future.timeout(const Duration(seconds: 5));
  } finally {
    runtime.state.removeListener(changed);
  }
}

typedef _Handler = Stream<ProviderEvent> Function(
  ProviderRequest,
  ProviderCancellationToken?,
);

class _Provider extends ProviderClient {
  _Provider(this.handler);
  final _Handler handler;
  final requests = <ProviderRequest>[];
  @override
  Stream<ProviderEvent> stream(
    ProviderRequest request, {
    required String apiKey,
    ProviderCancellationToken? cancellation,
  }) {
    requests.add(request);
    return handler(request, cancellation);
  }
}

class _Storage extends ConversationStorage {
  _Storage() : super.base();
  String? source;
  Future<void> Function(String source)? beforeSave;
  @override
  Future<ConversationStorageLoad> load() async =>
      ConversationStorageLoad(source: source);
  @override
  Future<void> save(String source, {required int revision}) async {
    if (beforeSave != null) await beforeSave!(source);
    this.source = source;
  }
}

class _Harness {
  _Harness(
    this.storage,
    this.repository,
    this.provider,
    this.id,
    this.settings,
  );
  final _Storage storage;
  final ConversationRepository repository;
  final _Provider provider;
  final String id;
  AgentSettings settings;
  late AgentRuntimeController runtime;
  static Future<_Harness> create(
    _Handler handler, {
    AgentModelProtocol protocol = AgentModelProtocol.chatCompletions,
  }) async {
    final storage = _Storage();
    final repository = ConversationRepository(storage: storage);
    await repository.load();
    final conversation = await repository.create(title: 'models');
    final provider = _Provider(handler);
    final h = _Harness(
      storage,
      repository,
      provider,
      conversation.id,
      AgentSettings(
        endpoint: 'https://models.example/v1',
        model: 'model-a',
        models: _models,
        protocol: protocol,
      ),
    );
    h.runtime = AgentRuntimeController(
      repository: repository,
      provider: provider,
      readSettings: () => h.settings,
      readApiKey: (_) async => '',
      readTools: (_) => [
        ToolDefinition(
          name: 'events.list',
          description: 'Read agenda',
          parameters: {'type': 'object', 'properties': <String, Object?>{}},
        ),
      ],
      executeTool: (_, scope, _) async {
        scope.checkActive();
        return {'status': 'read'};
      },
      onOpenSettings: () {},
    );
    return h;
  }

  void dispose() {
    runtime.dispose();
    provider.close();
    repository.dispose();
  }
}
