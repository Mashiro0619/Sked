import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sked/agent/context/context_service.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/runtime/agent_service.dart';
import 'package:sked/agent/store/agent_store.dart';
import 'package:sked/agent/store/sqlite_context_checkpoint_store.dart';
import 'package:sked/agent/ui/agent_ui_delegate.dart';
import 'package:sked/models/agent_settings.dart';
import 'package:sked/application/operation_contracts.dart';

import '../../support/memory_conversation_storage.dart';

const _model = AgentModelConfig(
  id: 'fixture-model',
  reasoningEfforts: [AgentReasoningEffort.medium],
  defaultReasoningEffort: AgentReasoningEffort.medium,
  maxContextTokens: 32000,
  autoCompact: false,
);
AgentSettings _settings({bool insecure = false}) => AgentSettings(
  enabled: true,
  endpoint: '${insecure ? 'http' : 'https'}://fixture.example/v1',
  model: _model.id,
  models: const [_model],
);
http.Response _reply(
  String text, {
  List<Map<String, Object?>> tools = const [],
}) => http.Response(
  jsonEncode({
    'choices': [
      {
        'index': 0,
        'message': {
          'role': 'assistant',
          'content': text,
          if (tools.isNotEmpty) 'tool_calls': tools,
        },
        'finish_reason': tools.isEmpty ? 'stop' : 'tool_calls',
      },
    ],
    'usage': {
      'prompt_tokens': 500,
      'completion_tokens': 40,
      'total_tokens': 540,
    },
  }),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
bool _isSummary(http.Request request) =>
    request.body.contains('Summarize the supplied conversation');

class _SummaryCancelledAfterUsage extends ProviderClient {
  final started = Completer<void>();

  @override
  Stream<ProviderEvent> stream(
    ProviderRequest request, {
    required String apiKey,
    ProviderCancellationToken? cancellation,
  }) async* {
    yield const ProviderUsageEvent(
      ProviderUsage(inputTokens: 500, outputTokens: 40, totalTokens: 540),
    );
    yield const ProviderTextDelta('Internal summary text');
    started.complete();
    await cancellation!.whenCancelled;
    throw const ProviderException(ProviderError.cancelled);
  }
}

Future<void> _seed(
  ConversationRepository repository, {
  AgentPermissionMode mode = AgentPermissionMode.full,
}) async {
  await repository.load();
  await repository.create(id: 'chat', title: 'Synthetic history', mode: mode);
  await repository.update(
    'chat',
    (current) => current.copyWith(
      messages: [
        for (var index = 0; index < 8; index++)
          ConversationMessage(
            id: 'history-$index',
            role: index.isEven
                ? ConversationRole.user
                : ConversationRole.assistant,
            text:
                'Historical task $index ${'complete synthetic context ' * 500}',
            createdAt: DateTime.utc(2026, 11, 7),
          ),
      ],
    ),
  );
}

Future<AgentUiApproval> _approval(AgentService service) {
  final watch = service.watchConversation('chat');
  if (watch.value.pendingApproval case final value?) return Future.value(value);
  final done = Completer<AgentUiApproval>();
  void changed() {
    if (watch.value.pendingApproval case final value?) {
      watch.removeListener(changed);
      done.complete(value);
    }
  }

  watch.addListener(changed);
  return done.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cancelled compaction retains reported request usage without publishing its summary', () async {
    final store = AgentStore(AgentDatabase(NativeDatabase.memory()));
    final repository = ConversationRepository(storage: store.conversations);
    await _seed(repository);
    final provider = _SummaryCancelledAfterUsage();
    final service = AgentService(
      repository: repository,
      provider: provider,
      contextService: ContextService(
        store: SqliteContextCheckpointStore(store),
        provider: provider,
      ),
      readSettings: _settings,
      readApiKey: (_) async => '',
      readTools: (_) => const [],
      executeTool: (_, _, _) async => const {},
      onOpenSettings: () {},
    );
    addTearDown(() async {
      service.dispose();
      repository.dispose();
      provider.close();
      await store.close();
    });
    final streamingText = <String>[];
    final watch = service.watchConversation('chat');
    watch.addListener(() => streamingText.add(watch.value.streamingText));

    final compacting = service.compactContext('chat');
    await provider.started.future;
    await service.stop('chat');
    await compacting;
    final saved = (await store.readConversation('chat'))!;
    final request = saved.runs.single.requests.single;
    expect(request.kind, ConversationRequestKind.contextCompaction);
    expect(request.outcome, ConversationAttemptOutcome.unknown);
    expect(request.usage!.totalTokens, 540);
    expect(request.errorCode, 'provider.cancelled');
    expect(saved.runs.single.status, ConversationRunStatus.interrupted);
    expect(streamingText, everyElement(isEmpty));
    expect(saved.messages, hasLength(8));
    expect(await SqliteContextCheckpointStore(store).latest('chat'), isNull);
  });

  test('Stop returns during a pending compaction queue save and its late control stays cancelled', () async {
    final storage = _QueuedControlStorage();
    final repository = ConversationRepository(storage: storage);
    await _seed(repository);
    final entered = Completer<void>(), release = Completer<void>();
    storage.beforeSave = (value) async {
      final pending = ConversationArchive.decode(value)
          .conversations
          .single
          .queuedControls;
      if (!entered.isCompleted &&
          pending.any(
            (control) => control.status == ConversationControlStatus.queued,
          )) {
        entered.complete();
        await release.future;
      }
    };
    final provider = ProviderClient();
    final service = AgentService(
      repository: repository,
      provider: provider,
      readSettings: _settings,
      readApiKey: (_) async => '',
      readTools: (_) => const [],
      executeTool: (_, _, _) async => const {},
      onOpenSettings: () {},
    );
    addTearDown(() {
      if (!release.isCompleted) release.complete();
      service.dispose();
      repository.dispose();
      provider.close();
    });

    final queued = service.compactContext('chat');
    await entered.future;
    await service.stop('chat');
    release.complete();
    await queued;

    final saved = ConversationArchive.decode(storage.source!)
        .conversations
        .single;
    expect(
      saved.queuedControls.single.status,
      ConversationControlStatus.cancelled,
    );
    expect(saved.runs, isEmpty);
    expect(service.watchConversation('chat').value.isActive, isFalse);
  });

  for (final mode in AgentPermissionMode.values) {
    test(
      'idle /compact shares HTTP authorization in ${mode.name} mode',
      () async {
        final store = AgentStore(AgentDatabase(NativeDatabase.memory()));
        final repository = ConversationRepository(storage: store.conversations);
        await _seed(repository, mode: mode);
        final original = repository
            .find('chat')!
            .messages
            .map((message) => message.toJson())
            .toList();
        await repository.update(
          'chat',
          (current) => current.copyWith(draft: '/compact'),
        );
        var requests = 0;
        final provider = ProviderClient(
          client: MockClient((request) async {
            requests++;
            expect(_isSummary(request), isTrue);
            return _reply('Prior decisions and saved work.');
          }),
        );
        final checkpoints = SqliteContextCheckpointStore(store);
        final service = AgentService(
          repository: repository,
          provider: provider,
          contextService: ContextService(
            store: checkpoints,
            provider: provider,
          ),
          readSettings: () => _settings(insecure: true),
          readApiKey: (_) async => '',
          readTools: (_) => const [],
          executeTool: (_, _, _) async => const {},
          onOpenSettings: () {},
        );
        addTearDown(() async {
          service.dispose();
          repository.dispose();
          provider.close();
          await store.close();
        });
        final running = service.send('chat', '/compact');
        if (mode != AgentPermissionMode.full) {
          final approval = await _approval(service);
          expect(approval.details['kind'], 'httpTransport');
          expect(requests, 0);
          await service.approve('chat', approval.id);
        }
        await running;
        expect(requests, 1);
        expect(
          repository
              .find('chat')!
              .messages
              .map((message) => message.toJson())
              .toList(),
          original,
        );
        expect(repository.find('chat')!.queuedControls, isEmpty);
        expect(repository.find('chat')!.draft, isEmpty);
        expect(await checkpoints.latest('chat'), isNotNull);
        final saved = (await store.readConversation('chat'))!;
        expect(saved.status, ConversationStatus.idle);
        expect(saved.runs.single.status, ConversationRunStatus.completed);
        expect(saved.runs.single.settledAt, isNotNull);
        final request = saved.runs.single.requests.single;
        expect(request.kind, ConversationRequestKind.contextCompaction);
        expect(request.outcome, ConversationAttemptOutcome.completed);
        expect(request.usage!.totalTokens, 540);
        expect(
          service.watchConversation('chat').value.contextUsage!.isCompacting,
          isFalse,
        );
      },
    );
  }

  test(
    'queued compaction waits for all results in a complete tool group',
    () async {
      final store = AgentStore(AgentDatabase(NativeDatabase.memory()));
      final repository = ConversationRepository(storage: store.conversations);
      await _seed(repository);
      final entered = Completer<void>();
      final first = Completer<void>();
      final second = Completer<void>();
      var ordinaryRequests = 0;
      var summaryRequests = 0;
      var toolsEntered = 0;
      final provider = ProviderClient(
        client: MockClient((request) async {
          if (_isSummary(request)) {
            summaryRequests++;
            expect(
              repository
                  .find('chat')!
                  .messages
                  .where((message) => message.role == ConversationRole.tool),
              hasLength(2),
            );
            return _reply(
              'Historical work, both query results, and the current goal.',
            );
          }
          ordinaryRequests++;
          if (ordinaryRequests == 1) {
            return _reply(
              '',
              tools: [
                for (final id in ['first', 'second'])
                  {
                    'id': id,
                    'type': 'function',
                    'function': {'name': 'query_$id', 'arguments': '{}'},
                  },
              ],
            );
          }
          return _reply('Queries complete.');
        }),
      );
      final service = AgentService(
        repository: repository,
        provider: provider,
        contextService: ContextService(
          store: SqliteContextCheckpointStore(store),
          provider: provider,
        ),
        readSettings: _settings,
        readApiKey: (_) async => '',
        readTools: (_) => [
          for (final id in ['first', 'second'])
            ToolDefinition(
              name: 'query_$id',
              description: 'Read a synthetic source',
              parameters: const {'type': 'object', 'properties': {}},
            ),
        ],
        isReadOnlyTool: (_) => true,
        executeTool: (call, _, _) async {
          if (++toolsEntered == 2) entered.complete();
          await (call.id == 'first' ? first.future : second.future);
          return {
            'items': [call.id],
          };
        },
        onOpenSettings: () {},
      );
      addTearDown(() async {
        service.dispose();
        repository.dispose();
        provider.close();
        await store.close();
      });
      final running = service.send('chat', 'Query both sources');
      await entered.future;
      await service.queueFollowUp('chat', '/compact');
      expect(
        (await store.readConversation('chat'))!.queuedControls.single.status,
        ConversationControlStatus.queued,
      );
      expect(
        service
            .watchConversation('chat')
            .value
            .contextUsage!
            .isCompactionQueued,
        isTrue,
      );
      first.complete();
      await Future<void>.delayed(Duration.zero);
      expect(summaryRequests, 0);
      second.complete();
      await running;
      await service.waitForIdle();
      expect(summaryRequests, 1);
      expect(ordinaryRequests, 2);
      final requests = (await store.readConversation('chat'))!
          .runs
          .single
          .requests;
      expect(requests.map((request) => request.kind), [
        ConversationRequestKind.response,
        ConversationRequestKind.contextCompaction,
        ConversationRequestKind.response,
      ]);
      expect(requests.map((request) => request.usage!.totalTokens), [
        540,
        540,
        540,
      ]);
      expect(repository.find('chat')!.queuedControls, isEmpty);
      expect(repository.find('chat')!.queuedInputs, isEmpty);
    },
  );

  test('restart consumes a durable control by reusing the checkpoint already saved for its source', () async {
    final directory = await Directory.systemTemp.createTemp(
      'sked-compaction-restart-',
    );
    final file = File('${directory.path}/agent.sqlite');
    var store = AgentStore(AgentDatabase(NativeDatabase(file)));
    var repository = ConversationRepository(storage: store.conversations);
    await _seed(repository);
    var summaryRequests = 0;
    final provider = ProviderClient(
      client: MockClient((request) async {
        expect(_isSummary(request), isTrue);
        summaryRequests++;
        return _reply('Earlier decisions and saved results.');
      }),
    );
    AgentService create() => AgentService(
      repository: repository,
      provider: provider,
      contextService: ContextService(
        store: SqliteContextCheckpointStore(store),
        provider: provider,
      ),
      readSettings: _settings,
      readApiKey: (_) async => '',
      readTools: (_) => const [],
      executeTool: (_, _, _) async => const {},
      onOpenSettings: () {},
    );
    var service = create();
    addTearDown(() async {
      service.dispose();
      repository.dispose();
      provider.close();
      await store.close();
      await directory.delete(recursive: true);
    });
    await service.compactContext('chat');
    final checkpoint = await SqliteContextCheckpointStore(store).latest('chat');
    // This is the durable state at the crash boundary between checkpoint commit
    // and consuming the queued command in the conversation transaction.
    await repository.update(
      'chat',
      (current) => current.copyWith(
        queuedControls: [
          ConversationControlCommand(
            id: 'unconsumed-control',
            kind: ConversationControlKind.compactContext,
            createdAt: DateTime.utc(2026, 11, 7),
          ),
        ],
      ),
    );
    service.dispose();
    repository.dispose();
    await store.close();
    store = AgentStore(AgentDatabase(NativeDatabase(file)));
    repository = ConversationRepository(storage: store.conversations);
    await repository.load();
    service = create();
    expect(
      service.watchConversation('chat').value.contextUsage!.isCompactionQueued,
      isTrue,
    );
    await service.continueConversation('chat');
    expect(summaryRequests, 1);
    expect(repository.find('chat')!.queuedControls, isEmpty);
    expect(
      (await SqliteContextCheckpointStore(store).latest('chat'))!.id,
      checkpoint!.id,
    );
  });

  test('Stop cancels compaction and preserves the original context with a durable cancelled control', () async {
    final store = AgentStore(AgentDatabase(NativeDatabase.memory()));
    final repository = ConversationRepository(storage: store.conversations);
    await _seed(repository);
    final original = repository
        .find('chat')!
        .messages
        .map((message) => message.toJson())
        .toList();
    final entered = Completer<void>();
    final release = Completer<void>();
    final provider = ProviderClient(
      client: MockClient((request) async {
        entered.complete();
        await release.future;
        return _reply('Cancelled summary.');
      }),
    );
    final checkpoints = SqliteContextCheckpointStore(store);
    final service = AgentService(
      repository: repository,
      provider: provider,
      contextService: ContextService(store: checkpoints, provider: provider),
      readSettings: _settings,
      readApiKey: (_) async => '',
      readTools: (_) => const [],
      executeTool: (_, _, _) async => const {},
      onOpenSettings: () {},
    );
    addTearDown(() async {
      service.dispose();
      repository.dispose();
      provider.close();
      await store.close();
    });
    final running = service.compactContext('chat');
    await entered.future;
    await service.stop('chat');
    release.complete();
    await running;
    expect(await checkpoints.latest('chat'), isNull);
    expect(
      repository
          .find('chat')!
          .messages
          .map((message) => message.toJson())
          .toList(),
      original,
    );
    expect(
      repository.find('chat')!.queuedControls.single.status,
      ConversationControlStatus.cancelled,
    );
    expect(
      service.watchConversation('chat').value.contextUsage!.isCompacting,
      isFalse,
    );
    expect(
      service.watchConversation('chat').value.contextUsage!.isCompactionQueued,
      isFalse,
    );
    expect(repository.find('chat')!.status, ConversationStatus.interrupted);
    final saved = (await store.readConversation('chat'))!;
    expect(saved.status, ConversationStatus.interrupted);
    expect(saved.runs.single.status, ConversationRunStatus.interrupted);
    expect(saved.runs.single.settledAt, isNotNull);
  });

  test('a failed idle compaction settles its run and keeps the failed control available for retry', () async {
    final store = AgentStore(AgentDatabase(NativeDatabase.memory()));
    final repository = ConversationRepository(storage: store.conversations);
    await _seed(repository);
    final original = repository
        .find('chat')!
        .messages
        .map((m) => m.toJson())
        .toList();
    final provider = ProviderClient(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'error': {'message': 'Synthetic summary failure'},
          }),
          503,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    final checkpoints = SqliteContextCheckpointStore(store);
    final service = AgentService(
      repository: repository,
      provider: provider,
      contextService: ContextService(store: checkpoints, provider: provider),
      readSettings: _settings,
      readApiKey: (_) async => '',
      readTools: (_) => const [],
      executeTool: (_, _, _) async => const {},
      onOpenSettings: () {},
    );
    addTearDown(() async {
      service.dispose();
      repository.dispose();
      provider.close();
      await store.close();
    });

    await service.compactContext('chat');

    expect(await checkpoints.latest('chat'), isNull);
    final saved = (await store.readConversation('chat'))!;
    expect(saved.messages.map((m) => m.toJson()).toList(), original);
    expect(saved.status, ConversationStatus.interrupted);
    expect(saved.runs.single.status, ConversationRunStatus.interrupted);
    expect(saved.runs.single.settledAt, isNotNull);
    expect(
      saved.queuedControls.single.status,
      ConversationControlStatus.failed,
    );
    expect(saved.queuedControls.single.errorMessage, isNotEmpty);
    expect(service.watchConversation('chat').value.phase, AgentUiPhase.failed);
    expect(
      service.watchConversation('chat').value.contextUsage!.errorMessage,
      isNotEmpty,
    );
  });

  for (final change in ['disable', 'connection']) {
    test(
      '$change during idle compaction persists an interrupted run',
      () async {
        final store = AgentStore(AgentDatabase(NativeDatabase.memory()));
        final repository = ConversationRepository(storage: store.conversations);
        await _seed(repository);
        var settings = _settings();
        final entered = Completer<void>(), release = Completer<void>();
        var requests = 0;
        final provider = ProviderClient(
          client: MockClient((_) async {
            requests++;
            entered.complete();
            await release.future;
            return _reply('Obsolete summary.');
          }),
        );
        final checkpoints = SqliteContextCheckpointStore(store);
        final service = AgentService(
          repository: repository,
          provider: provider,
          contextService: ContextService(
            store: checkpoints,
            provider: provider,
          ),
          readSettings: () => settings,
          readApiKey: (_) async => '',
          readTools: (_) => const [],
          executeTool: (_, _, _) async => const {},
          onOpenSettings: () {},
        );
        addTearDown(() async {
          service.dispose();
          repository.dispose();
          provider.close();
          await store.close();
        });
        final running = service.compactContext('chat');
        await entered.future;
        settings = change == 'disable'
            ? settings.copyWith(enabled: false)
            : settings.copyWith(endpoint: 'https://another.fixture.example/v1');
        service.refreshSettings();
        release.complete();
        await running;

        final saved = (await store.readConversation('chat'))!;
        expect(requests, 1);
        expect(await checkpoints.latest('chat'), isNull);
        expect(saved.status, ConversationStatus.interrupted);
        expect(saved.runs.single.status, ConversationRunStatus.interrupted);
        expect(saved.runs.single.settledAt, isNotNull);
        expect(service.watchConversation('chat').value.isActive, isFalse);
      },
    );
  }
}

class _QueuedControlStorage extends MemoryConversationStorage {
  Future<void> Function(String value)? beforeSave;

  @override
  Future<void> save(String value, {required int revision}) async {
    await beforeSave?.call(value);
    await super.save(value, revision: revision);
  }
}
