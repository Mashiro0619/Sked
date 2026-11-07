import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/conversations/conversation_title_service.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/runtime/agent_service.dart';
import 'package:sked/agent/store/agent_store.dart';
import 'package:sked/agent/ui/agent_ui_delegate.dart';
import 'package:sked/models/agent_settings.dart';

class _Storage extends ConversationStorage {
  _Storage() : super.base();
  String? source;
  bool fail = false;
  @override
  Future<ConversationStorageLoad> load() async =>
      ConversationStorageLoad(source: source);
  @override
  Future<void> save(String value, {required int revision}) async {
    if (fail) throw StateError('Fixture save failed');
    source = value;
  }
}

class _Provider extends ProviderClient {
  final requests = <ProviderRequest>[];
  final keys = <String>[];
  final titleEvents = StreamController<ProviderEvent>();
  final titleEntered = Completer<void>();
  ProviderCancellationToken? titleCancellation;

  @override
  Stream<ProviderEvent> stream(
    ProviderRequest request, {
    required String apiKey,
    ProviderCancellationToken? cancellation,
  }) {
    requests.add(request);
    keys.add(apiKey);
    if (request.messages.first.text.startsWith(
      'Write a short, specific conversation title',
    )) {
      titleCancellation = cancellation;
      if (!titleEntered.isCompleted) titleEntered.complete();
      return titleEvents.stream;
    }
    return Stream.value(
      ProviderCompleted(
        ProviderResponse(
          text: 'Task reply',
          toolCalls: const [],
          finishReason: 'stop',
          usage: const ProviderUsage(
            inputTokens: 10,
            outputTokens: 5,
            totalTokens: 15,
          ),
        ),
      ),
    );
  }

  Future<void> finishTitle({
    String text = 'Semester planning',
    bool tool = false,
  }) async {
    titleEvents.add(
      ProviderCompleted(
        ProviderResponse(
          text: text,
          toolCalls: tool
              ? [
                  ProviderToolCall(
                    id: 'invalid',
                    name: 'mutate',
                    arguments: '{}',
                  ),
                ]
              : const [],
          finishReason: 'stop',
          usage: const ProviderUsage(
            inputTokens: 12,
            outputTokens: 3,
            totalTokens: 15,
          ),
        ),
      ),
    );
    await titleEvents.close();
  }

  Future<void> disposeEvents() async {
    // A single-subscription controller's done Future waits for a listener.
    // Cases that deliberately made no title request still own this stream.
    final idleDrain = titleEntered.isCompleted
        ? null
        : titleEvents.stream.drain<void>();
    if (!titleEvents.isClosed) await titleEvents.close();
    await idleDrain;
  }
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

class _Harness {
  _Harness(
    this.storage,
    this.repository,
    this.provider,
    this.titles,
    this.runtime,
  );
  final _Storage storage;
  final ConversationRepository repository;
  final _Provider provider;
  final ConversationTitleService titles;
  final AgentService runtime;
}

Future<_Harness> _harness({AgentSettings Function()? readSettings}) async {
  final storage = _Storage();
  final repository = ConversationRepository(storage: storage);
  await repository.load();
  await repository.create(id: 'chat', title: 'New conversation');
  final provider = _Provider();
  final titles = ConversationTitleService(
    repository: repository,
    provider: provider,
  );
  final runtime = AgentService(
    repository: repository,
    provider: provider,
    titleService: titles,
    readSettings: readSettings ?? () => _settings,
    readApiKey: (_) async => 'synthetic-title-key',
    readTools: (_) => const [],
    executeTool: (_, _, _) async => const {},
    onOpenSettings: () {},
  );
  addTearDown(() async {
    runtime.dispose();
    await runtime.waitForIdle();
    await provider.disposeEvents();
    repository.dispose();
    provider.close();
  });
  return _Harness(storage, repository, provider, titles, runtime);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final queued in [false, true]) {
    test(
      'first ${queued ? "queued" : "direct"} acceptance requests one independent AI title',
      () async {
        final h = await _harness();
        const original =
            'Please help me design a workable semester schedule with breaks';
        if (queued) {
          await h.repository.update(
            'chat',
            (value) => value.copyWith(
              queuedInputs: [
                ConversationQueuedInput(
                  id: 'first',
                  text: original,
                  createdAt: DateTime.utc(2026, 11, 8),
                ),
              ],
            ),
          );
          await h.runtime.continueConversation('chat');
        } else {
          await h.runtime.send('chat', original);
        }
        await h.provider.titleEntered.future;
        final firstAccepted = h.repository.find('chat')!;
        expect(firstAccepted.title, original);
        expect(
          firstAccepted.titleGeneration!.request.outcome,
          ConversationAttemptOutcome.pending,
        );
        expect(firstAccepted.runs.single.requests, hasLength(1));
        expect(h.provider.requests, hasLength(2));
        final titleRequest = h.provider.requests.firstWhere(
          (request) => request.messages.first.text.startsWith('Write a short'),
        );
        expect(titleRequest.tools, isEmpty);
        expect(titleRequest.model, 'fixture');
        expect(titleRequest.reasoningEffort, 'medium');
        expect(
          jsonDecode(titleRequest.messages.last.text)['firstMessage'],
          original,
        );
        expect(h.provider.keys, everyElement('synthetic-title-key'));

        await h.runtime.send('chat', 'Add one more course');
        final beforeTitle = h.repository.find('chat')!;
        await h.provider.finishTitle();
        await h.titles.waitForIdle();
        final saved = h.repository.find('chat')!;
        expect(saved.title, 'Semester planning');
        expect(saved.titleWasEdited, isFalse);
        expect(saved.updatedAt, beforeTitle.updatedAt);
        expect(saved.messages.first.text, original);
        expect(saved.titleGeneration!.request.usage!.inputTokens, 12);
        expect(
          saved.titleGeneration!.request.outcome,
          ConversationAttemptOutcome.completed,
        );
        expect(saved.runs.expand((run) => run.requests), hasLength(2));
        expect(h.provider.requests, hasLength(3));
        final reopened = ConversationArchive.decode(h.storage.source!)
            .conversations
            .single;
        expect(
          reopened.titleGeneration!.toJson(),
          saved.titleGeneration!.toJson(),
        );
      },
    );
  }

  test('manual titles win before and during generation', () async {
    final before = await _harness();
    await before.repository.update(
      'chat',
      (value) => value.copyWith(title: 'My own name'),
    );
    await before.runtime.send('chat', 'A different topic');
    expect(before.provider.requests, hasLength(1));
    expect(before.repository.find('chat')!.titleGeneration, isNull);

    final during = await _harness();
    await during.runtime.send('chat', 'Plan the semester');
    await during.provider.titleEntered.future;
    await during.repository.update(
      'chat',
      (value) => value.copyWith(title: 'Chosen while running'),
    );
    await during.titles.waitForIdle();
    expect(during.provider.titleCancellation!.isCancelled, isTrue);
    expect(during.repository.find('chat')!.title, 'Chosen while running');
    expect(during.repository.find('chat')!.titleWasEdited, isTrue);
  });

  test(
    'title failure keeps the temporary title, usage, and the completed chat',
    () async {
      final h = await _harness();
      await h.runtime.send('chat', 'Help plan next semester');
      final accepted = h.repository.find('chat')!;
      h.provider.titleEvents.add(
        const ProviderUsageEvent(
          ProviderUsage(inputTokens: 9, outputTokens: 1, totalTokens: 10),
        ),
      );
      h.provider.titleEvents.addError(
        const ProviderException(ProviderError.incompleteResponse),
      );
      await h.titles.waitForIdle();
      final saved = h.repository.find('chat')!;
      expect(saved.title, accepted.title);
      expect(saved.status, ConversationStatus.idle);
      expect(
        saved.titleGeneration!.request.outcome,
        ConversationAttemptOutcome.failed,
      );
      expect(saved.titleGeneration!.request.usage!.totalTokens, 10);
      expect(saved.messages.last.text, 'Task reply');
      await h.titles.generate(
        conversation: accepted,
        endpoint: Uri.parse('https://fixture.example/v1/chat/completions'),
        apiKey: 'synthetic-title-key',
        allowInsecureHttp: false,
        isOwnerCurrent: () => true,
      );
      expect(h.provider.requests, hasLength(2));
    },
  );

  for (final ending in ['connection', 'delete', 'dispose']) {
    test('$ending cancels title generation and rejects a late save', () async {
      var settings = _settings;
      final h = await _harness(readSettings: () => settings);
      await h.runtime.send('chat', 'Plan next semester');
      final original = h.repository.find('chat')!;
      switch (ending) {
        case 'connection':
          settings = _settings.copyWith(endpoint: 'https://changed.example/v1');
          h.runtime.refreshSettings();
        case 'delete':
          await h.runtime.deleteConversation('chat');
        case 'dispose':
          h.runtime.dispose();
      }
      await h.titles.waitForIdle();
      expect(h.provider.titleCancellation!.isCancelled, isTrue);
      expect(
        h.repository.find('chat')?.title,
        ending == 'delete' ? isNull : original.title,
      );
    });
  }

  test('an unaccepted message never starts a title request', () async {
    final h = await _harness();
    h.storage.fail = true;
    await expectLater(
      h.runtime.send('chat', 'Cannot be saved'),
      throwsA(anything),
    );
    expect(h.provider.requests, isEmpty);
    expect(h.repository.find('chat')!.titleGeneration, isNull);
  });

  test('the title request preserves the entire first user message', () async {
    final h = await _harness();
    final message =
        '${'Detailed constraints ' * 600}The final goal is a balanced weekly timetable.';
    await h.runtime.send('chat', message);
    await h.provider.titleEntered.future;
    final request = h.provider.requests.firstWhere(
      (request) => request.messages.first.text.startsWith('Write a short'),
    );
    expect(jsonDecode(request.messages.last.text)['firstMessage'], message);
    await h.provider.finishTitle();
    await h.titles.waitForIdle();
  });

  test(
    'a provider that stalls stream cancellation cannot hold shutdown open',
    () async {
      final h = await _harness();
      final releaseCancel = Completer<void>();
      h.provider.titleEvents.onCancel = () => releaseCancel.future;
      await h.runtime.send('chat', 'Plan next semester');
      await h.provider.titleEntered.future;
      h.runtime.dispose();
      try {
        await h.runtime.waitForIdle().timeout(const Duration(seconds: 2));
        expect(h.provider.titleCancellation!.isCancelled, isTrue);
        expect(h.repository.find('chat')!.title, 'Plan next semester');
      } finally {
        releaseCancel.complete();
      }
    },
  );

  for (final changed in [false, true]) {
    test(
      'paged and background title source ${changed ? "rejects changed input" : "retains the actual first message"}',
      () async {
        final store = AgentStore(AgentDatabase(NativeDatabase.memory()));
        final repository = ConversationRepository(storage: store.conversations);
        final provider = _Provider();
        final titles = ConversationTitleService(
          repository: repository,
          provider: provider,
        );
        addTearDown(() async {
          titles.dispose();
          await titles.waitForIdle();
          await provider.disposeEvents();
          repository.dispose();
          await store.close();
          provider.close();
        });
        await repository.load();
        await repository.create(id: 'paged', title: 'Temporary');
        final messages = List.generate(
          64,
          (index) => ConversationMessage(
            id: 'message-$index',
            role: ConversationRole.user,
            text: 'Request $index',
            createdAt: DateTime.utc(2026, 11, 8).add(Duration(seconds: index)),
          ),
        );
        final generation = ConversationTitleGeneration(
          sourceMessageId: messages.first.id,
          sourceDigest: ConversationTitleService.sourceDigest(messages.first),
          model: 'fixture',
          protocol: 'chatCompletions',
          request: ConversationRequestUsage(
            id: 'paged-title',
            startedAt: DateTime.utc(2026, 11, 8),
          ),
        );
        final accepted = await repository.update(
          'paged',
          (value) =>
              value.copyWith(messages: messages, titleGeneration: generation),
        );
        if (changed) {
          await repository.update(
            'paged',
            (value) => value.copyWith(
              messages: [
                value.messages.first.copyWith(text: 'Changed first request'),
                ...value.messages.skip(1),
              ],
            ),
          );
        }
        await repository.create(id: 'other', title: 'Other conversation');
        await repository.load();
        expect(repository.isConversationLoaded('paged'), isFalse);
        final pending = titles.generate(
          conversation: accepted,
          endpoint: Uri.parse('https://fixture.example/v1/chat/completions'),
          apiKey: '',
          allowInsecureHttp: false,
          isOwnerCurrent: () => true,
        );
        if (changed) {
          await pending;
          expect(provider.requests, isEmpty);
          expect(repository.find('paged')!.title, 'Temporary');
        } else {
          await provider.titleEntered.future;
          expect(repository.isConversationLoaded('paged'), isFalse);
          await repository.select('paged');
          final visibleFirst = repository.visibleMessages('paged').first.id;
          expect(visibleFirst, isNot(messages.first.id));
          await repository.select('other');
          expect(provider.titleCancellation!.isCancelled, isFalse);
          await provider.finishTitle();
          await pending;
          expect(repository.find('paged')!.title, 'Semester planning');
          expect(repository.selectedId, 'other');
          expect(repository.visibleMessages('paged').first.id, visibleFirst);
        }
      },
    );
  }

  for (final response in ['First line\nSecond line', 'synthetic-title-key']) {
    test(
      'invalid generated title is rejected: ${response.contains("\n") ? "multiple lines" : "credential"}',
      () async {
        final h = await _harness();
        await h.runtime.send('chat', 'Plan next semester');
        await h.provider.finishTitle(text: response);
        await h.titles.waitForIdle();
        final saved = h.repository.find('chat')!;
        expect(saved.title, 'Plan next semester');
        expect(
          saved.titleGeneration!.request.outcome,
          ConversationAttemptOutcome.failed,
        );
        expect(h.storage.source, isNot(contains('synthetic-title-key')));
      },
    );
  }

  test('a title response cannot execute returned tools', () async {
    final h = await _harness();
    await h.runtime.send('chat', 'Plan next semester');
    await h.provider.finishTitle(tool: true);
    await h.titles.waitForIdle();
    expect(h.repository.find('chat')!.title, 'Plan next semester');
    expect(
      h.repository.find('chat')!.titleGeneration!.request.outcome,
      ConversationAttemptOutcome.failed,
    );
    expect(h.provider.requests, hasLength(2));
  });

  test(
    'HTTP title waits for the existing conversation transport approval',
    () async {
      final h = await _harness(
        readSettings: () =>
            _settings.copyWith(endpoint: 'http://fixture.example/v1'),
      );
      final running = h.runtime.send('chat', 'Plan next semester');
      final state = h.runtime.watchConversation('chat');
      final waiting = Completer<void>();
      void changed() {
        if (state.value.phase == AgentUiPhase.waitingApproval &&
            !waiting.isCompleted) {
          waiting.complete();
        }
      }

      state.addListener(changed);
      changed();
      await waiting.future;
      expect(h.provider.requests, isEmpty);
      await h.runtime.approve('chat', state.value.pendingApproval!.id);
      await running;
      await h.provider.titleEntered.future;
      expect(
        h.provider.requests.every((request) => request.allowInsecureHttp),
        isTrue,
      );
      await h.provider.finishTitle();
      await h.titles.waitForIdle();
      state.removeListener(changed);
      if (state is AgentConversationRunListenable) state.dispose();
    },
  );
}
