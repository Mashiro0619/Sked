import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:sked/agent/agent_application.dart';
import 'package:sked/agent/connection/agent_connection_manager.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/conversations/conversation_storage_codec.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/tools/application_tool_host.dart';
import 'package:sked/agent/tools/agent_control_tool_adapters.dart';
import 'package:sked/agent/skills/shared_skill_loader.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/application/setting_registry.dart';
import 'package:sked/models/agent_settings.dart';

import '../support/workspace_harness.dart';

class _ConversationStorage extends ConversationStorage {
  _ConversationStorage() : super.base();
  String? source;
  List<String?>? slots;
  bool failLoad = false;
  bool failSave = false;
  Future<void> Function()? beforeSave;
  int loads = 0;
  int saves = 0;
  @override
  Future<ConversationStorageLoad> load() async {
    loads++;
    if (failLoad) throw StateError('fixture storage failure');
    if (slots != null) return decodeConversationSlots(slots!);
    return ConversationStorageLoad(source: source);
  }

  @override
  Future<void> save(String value, {required int revision}) async {
    saves++;
    await beforeSave?.call();
    if (failSave) throw StateError('fixture storage write failure');
    source = value;
  }
}

class _CredentialStore extends MemoryAgentCredentialStore {
  bool failRead = false;
  int reads = 0;
  int writes = 0;
  Future<void> Function(AgentCredentialSlot, String?)? beforeWrite;

  @override
  Future<String?> read(AgentCredentialSlot slot) async {
    reads++;
    if (failRead) throw StateError('fixture credential read failure');
    return super.read(slot);
  }

  @override
  Future<void> write(AgentCredentialSlot slot, String? value) async {
    writes++;
    await beforeWrite?.call(slot, value);
    await super.write(slot, value);
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

ProviderResponse _call(String name, Map<String, Object?> arguments) =>
    ProviderResponse(
      text: '',
      toolCalls: [
        ProviderToolCall(
          id: 'call-$name',
          name: name,
          arguments: jsonEncode(arguments),
        ),
      ],
      finishReason: 'tool_calls',
    );

ProviderResponse _done() =>
    ProviderResponse(text: 'Done', toolCalls: const [], finishReason: 'stop');
Map<String, dynamic> _lastTool(ProviderRequest request) => jsonDecode(
  request.messages
      .lastWhere((message) => message.role == ProviderRole.tool)
      .text,
) as Map<String, dynamic>;

Future<void> _until(AppRuntime app, bool Function() predicate) async {
  if (predicate()) return;
  final done = Completer<void>();
  void changed() {
    if (predicate() && !done.isCompleted) done.complete();
  }

  app.agent.runtime.state.addListener(changed);
  try {
    await done.future.timeout(const Duration(seconds: 5));
  } finally {
    app.agent.runtime.state.removeListener(changed);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _ConversationStorage conversations;
  late _CredentialStore credentials;
  late _Provider provider;
  late AppRuntime app;

  setUp(() async {
    conversations = _ConversationStorage();
    credentials = _CredentialStore();
    provider = _Provider()..respond = (_) => _done();
    app = await workspaceProvider(
      agentConversationStorage: conversations,
      agentCredentialStore: credentials,
      agentProvider: provider,
    );
  });
  tearDown(() async {
    await app.agent.quiesce();
    app.dispose();
  });

  Future<AgentConversation> ready(AgentPermissionMode mode) async {
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
    return app.agent.conversations.create(title: 'Fixture', mode: mode);
  }

  void createCalendarScript() {
    var round = 0;
    provider.respond = (request) => switch (round++) {
      0 => _call('capabilities.describe', {
        'names': ['mutation.prepare', 'mutation.commit'],
      }),
      1 => _call('mutation.prepare', {
        'commands': [
          {
            'kind': 'calendar',
            'action': 'create',
            'values': {'name': 'Agent calendar', 'isVisible': false},
          },
        ],
      }),
      2 => _call('mutation.commit', {'planId': _lastTool(request)['planId']}),
      _ => _done(),
    };
  }

  for (final ending in ['stop', 'maintenance', 'shutdown']) {
    test('$ending drains an open credential request without waiting for input', () async {
      final conversation = await ready(AgentPermissionMode.ask);
      final opened = Completer<void>();
      final pending = Completer<AgentCredentialInput?>();
      late ProviderCancellationToken cancellation;
      app.agent.controlTools.bindCredentialInput((_, token) {
        cancellation = token;
        opened.complete();
        return pending.future;
      });
      var round = 0;
      provider.respond = (_) => switch (round++) {
        0 => _call('capabilities.describe', {
          'names': ['credentials.request_input'],
        }),
        1 => _call('credentials.request_input', {
          'endpoint': 'https://fixture.example/v1',
        }),
        _ => _done(),
      };
      final writes = credentials.writes;
      final run = app.agent.runtime.send(conversation.id, 'Update my API key');
      await opened.future.timeout(const Duration(seconds: 5));
      switch (ending) {
        case 'stop':
          await app.agent.runtime.stop(conversation.id);
          await app.agent.runtime.waitForIdle().timeout(
            const Duration(seconds: 5),
          );
        case 'maintenance':
          await app.agent.quiesce().timeout(const Duration(seconds: 5));
        case 'shutdown':
          await app.shutdown.quiesce().timeout(const Duration(seconds: 5));
      }
      await run;
      expect(cancellation.isCancelled, isTrue);
      expect(app.agent.runtime.isRunning(conversation.id), isFalse);
      expect(credentials.writes, writes);
      // A host that ignored cancellation cannot leak a late secret to history.
      final lateInput = AgentCredentialInput('late-fixture-key');
      pending.complete(lateInput);
      await pumpEventQueue();
      expect(lateInput.take(), isNull);
      expect(conversations.source, isNot(contains('late-fixture-key')));
      if (ending == 'stop') {
        await app.agent.runtime.send(conversation.id, 'A new request');
        expect(
          app.agent.conversations.find(conversation.id)!.messages.last.text,
          'Done',
        );
      }
    });
  }

  test('default-on Agent stays dormant until explicitly opened', () async {
    expect(app.agent.settings.enabled, isTrue);
    expect(app.agent.isInitialized, isFalse);
    expect(conversations.loads, 0);
    expect(provider.requests, isEmpty);
    await app.agent.initialize();
    expect(conversations.loads, 1);
    expect(app.agent.isInitialized, isTrue);
    expect(app.agent.runtime.state.value.enabled, isTrue);
  });

  test(
    'all bundled Skills load against the real application tool registry',
    () async {
      final loader = SharedSkillLoader(
        loadString: rootBundle.loadString,
        registeredTools: app.agent.tools.registeredNames,
        budgets: const SkillBudgets(
          maxLoadedSkills: 24,
          maxLoadedBytes: 256 * 1024,
        ),
      );
      final catalog = await loader.catalog();
      expect(catalog, hasLength(24));
      for (final setting in SettingRegistry().descriptors.where(
        (value) => value.requiresAdapter && !value.readOnly,
      )) {
        expect(
          setting.adapterTool,
          isNotNull,
          reason: '${setting.key} requires an explicit owning tool.',
        );
        expect(
          app.agent.tools.registeredNames,
          contains(setting.adapterTool),
          reason: '${setting.key} must have a registered write adapter.',
        );
      }
      final missing = {
        for (final entry in catalog)
          if (entry.missingTools.isNotEmpty) entry.skill.id: entry.missingTools,
      };
      expect(
        missing,
        isEmpty,
        reason: 'Published Skills must refer to tools actually registered by AppRuntime.',
      );
      for (final entry in catalog) {
        expect(
          (await loader.load(entry.skill.id)).status,
          SkillStatus.loaded,
          reason: entry.skill.id,
        );
      }
    },
  );

  test('successful clear cannot recreate conversations when the exit callback returns', () async {
    final conversation = await ready(AgentPermissionMode.full);
    Object? lateFailure;
    await app.agent.runtime
        .runHostAction(conversation.id, (scope, _) async {
          await app.agent.runMaintenanceFromAgent(scope, () async {
            await app.dataClear.run(
              clear: () async {
                conversations.source = null;
              },
              exit: () async {},
            );
          });
          return {
            'status': 'applied',
            'kind': 'external',
            'effectStatus': 'applied',
          };
        })
        .then<void>(
          (_) {},
          onError: (Object error) {
            lateFailure = error;
          },
        );
    await app.agent.runtime.waitForIdle();
    expect(app.dataClear.isCommitted, isTrue);
    expect(app.agent.conversations.canWrite, isFalse);
    expect(conversations.source, isNull);
    // A cleared process may no longer record a final chat reply. The important
    // boundary is that neither a returning exit callback nor that failure can
    // recreate the removed archive.
    expect(lateFailure, anyOf(isNull, isA<ConversationStorageException>()));
  });

  test(
    'failed clear requires explicit conversation recovery before writing again',
    () async {
      final conversation = await ready(AgentPermissionMode.full);
      final before = conversations.source;
      await expectLater(
        app.dataClear.run(
          clear: () async => throw StateError('synthetic failed clear'),
          exit: () async {},
        ),
        throwsStateError,
      );
      expect(app.agent.conversations.canWrite, isFalse);
      expect(conversations.source, before);
      await app.agent.recoverConversations();
      expect(app.agent.conversations.canWrite, isTrue);
      expect(app.agent.conversations.find(conversation.id), isNotNull);
    },
  );

  test('history paging preserves original Unicode tool content and conversation isolation', () async {
    final now = DateTime.utc(2026, 10, 30);
    final original = ConversationMessage(
      id: 'original',
      role: ConversationRole.assistant,
      text: '原始内容🌸' * 3000,
      createdAt: now,
      toolCalls: const [
        ConversationToolCall(
          id: 'tool',
          name: 'mutation.prepare',
          arguments: '{"name":"课程"}',
        ),
      ],
    );
    final conversation = AgentConversation(
      id: 'own',
      title: 'Own',
      createdAt: now,
      updatedAt: now,
      messages: [original],
    );
    final scope = OperationScope(
      id: 'history',
      policy: OperationPolicy(enabled: true, mode: AgentPermissionMode.plan),
    );
    final host = ApplicationToolHost(
      session: app.session,
      mutations: app.agent.mutations,
      conversationForScope: (candidate) =>
          identical(candidate, scope) ? conversation : null,
    );
    Future<Map<String, Object?>> read(String name, Map<String, Object?> args) =>
        host.execute(
          ProviderToolCall(id: name, name: name, arguments: jsonEncode(args)),
          scope,
          (_) async => null,
        );
    final page = await read('conversation.history', {'limit': 1});
    expect(page['total'], 1);
    expect(page['hasMore'], false);
    var offset = 0;
    final output = StringBuffer();
    while (true) {
      final part = await read('conversation.read', {
        'id': 'original',
        'offset': offset,
        'limit': 8000,
      });
      output.write(part['text']);
      expect(
        utf8.encode(jsonEncode(part)).length,
        lessThan(ApplicationToolHost.maxResultBytes),
      );
      if (part['hasMore'] != true) break;
      offset = part['nextOffset'] as int;
    }
    expect(jsonDecode(output.toString()), original.toJson());
    await expectLater(
      read('conversation.read', {'id': 'other-conversation'}),
      throwsA(isA<OperationProblem>()),
    );
    expect(app.session.committedData.applicationLedger, isNull);
  });

  test(
    'real composition discovers tools, commits and durably records actual IDs',
    () async {
      final conversation = await ready(AgentPermissionMode.full);
      createCalendarScript();
      final previousCount =
          app.session.committedData.generalMode.schedules.length;
      await app.agent.runtime.send(conversation.id, 'Create a hidden calendar');
      final snapshot = app.session.committedData;
      expect(snapshot.generalMode.schedules.length, previousCount + 1);
      final calendar = snapshot.generalMode.schedules.last;
      expect(calendar.name, 'Agent calendar');
      expect(calendar.isVisible, isFalse);
      expect(snapshot.applicationLedger!.receipts, hasLength(1));
      final result = _lastTool(provider.requests.last);
      expect(result['status'], 'committed');
      expect(jsonEncode(result), contains(calendar.id));
      expect(conversations.source, contains('committed'));
      expect(
        provider.requests.first.tools.map((tool) => tool.name),
        isNot(contains('mutation.commit')),
      );
      expect(
        provider.requests[1].tools.map((tool) => tool.name),
        contains('mutation.commit'),
      );
      final other = await app.agent.conversations.create(title: 'Other');
      provider.respond = (_) => _done();
      await app.agent.runtime.send(other.id, 'Hello');
      expect(
        provider.requests.last.tools.map((tool) => tool.name),
        isNot(contains('mutation.commit')),
      );
      expect(
        provider.requests.last.messages.any(
          (item) => item.text.contains('Create a hidden calendar'),
        ),
        isFalse,
      );
    },
  );

  test(
    'planning mode prepares but cannot commit through the real host',
    () async {
      final conversation = await ready(AgentPermissionMode.plan);
      createCalendarScript();
      final before = app.session.committedData.generalMode.schedules.length;
      await app.agent.runtime.send(conversation.id, 'Plan a calendar');
      expect(
        app.session.committedData.generalMode.schedules,
        hasLength(before),
      );
      expect(app.session.committedData.applicationLedger, isNull);
      expect(
        _lastTool(provider.requests.last)['error'],
        containsPair('code', 'readOnly'),
      );
    },
  );

  test(
    'Agent can disable its feature through a committed plan and then stops',
    () async {
      final conversation = await ready(AgentPermissionMode.full);
      var round = 0;
      provider.respond = (request) => switch (round++) {
        0 => _call('capabilities.describe', {
          'names': ['agent_settings.prepare', 'mutation.commit'],
        }),
        1 => _call('agent_settings.prepare', {
          'edits': [
            {'key': 'agent.enabled', 'action': 'set', 'value': false},
          ],
        }),
        2 => _call('mutation.commit', {'planId': _lastTool(request)['planId']}),
        _ => throw StateError(
          'No further model request is allowed after disabling Agent.',
        ),
      };
      await app.agent.runtime.send(
        conversation.id,
        'Disable the Agent feature',
      );
      expect(app.agent.settings.enabled, isFalse);
      expect(provider.requests, hasLength(3));
      expect(
        app
            .session
            .committedData
            .applicationLedger!
            .receipts
            .single
            .result['status'],
        'committed',
      );
      expect(app.agent.conversations.find(conversation.id), isNotNull);
    },
  );

  test(
    'ask-to-full transition applies exactly the displayed plan once',
    () async {
      final conversation = await ready(AgentPermissionMode.ask);
      createCalendarScript();
      final sending = app.agent.runtime.send(
        conversation.id,
        'Create a calendar',
      );
      await _until(
        app,
        () =>
            app.agent.runtime.state.value
                .runFor(conversation.id)
                .pendingApproval !=
            null,
      );
      final preview = app.agent.runtime.state.value
          .runFor(conversation.id)
          .pendingApproval!;
      expect(jsonEncode(preview.details), contains('Agent calendar'));
      expect(app.session.committedData.applicationLedger, isNull);
      await app.agent.runtime.setMode(
        conversation.id,
        AgentPermissionMode.full,
      );
      await sending;
      expect(
        app.session.committedData.applicationLedger!.receipts,
        hasLength(1),
      );
    },
  );

  test(
    'maintenance cancels a waiting confirmation and invalidates its handle',
    () async {
      final conversation = await ready(AgentPermissionMode.ask);
      createCalendarScript();
      final sending = app.agent.runtime.send(
        conversation.id,
        'Create a calendar',
      );
      await _until(
        app,
        () =>
            app.agent.runtime.state.value
                .runFor(conversation.id)
                .pendingApproval !=
            null,
      );
      final plan = app.agent.runtime.state.value
          .runFor(conversation.id)
          .pendingApproval!
          .id;
      final reservation = app.maintenance.reserve();
      try {
        await sending;
        expect(app.agent.mutations.plan(plan), isNull);
        expect(app.session.committedData.applicationLedger, isNull);
      } finally {
        app.maintenance.release(reservation);
      }
    },
  );

  test(
    'saving a new model list keeps an already started request on its model',
    () async {
      final conversation = await ready(AgentPermissionMode.full);
      final started = Completer<void>();
      final response = Completer<ProviderResponse>();
      provider.respond = (_) {
        started.complete();
        return response.future;
      };
      final sending = app.agent.runtime.send(conversation.id, 'Answer once');
      await started.future.timeout(const Duration(seconds: 5));
      try {
        await app.agent.configure(
          app.agent.settings.copyWith(
            model: 'next-model',
            models: const [
              AgentModelConfig(
                id: 'next-model',
                reasoningEfforts: [AgentReasoningEffort.medium],
                defaultReasoningEffort: AgentReasoningEffort.medium,
              ),
            ],
          ),
        );
        expect(app.agent.settings.model, 'next-model');
        expect(provider.requests.single.model, 'fixture');
        expect(
          app.agent.runtime.state.value.runFor(conversation.id).isActive,
          isTrue,
        );
        response.complete(_done());
        await sending;
        expect(
          app.agent.conversations.find(conversation.id)!.messages.last.text,
          'Done',
        );
      } finally {
        if (!response.isCompleted) response.complete(_done());
        await sending;
      }
    },
  );

  test(
    'feature disable revokes a run before its settings save finishes',
    () async {
      final conversation = await ready(AgentPermissionMode.ask);
      createCalendarScript();
      final sending = app.agent.runtime.send(
        conversation.id,
        'Create a calendar',
      );
      await _until(
        app,
        () =>
            app.agent.runtime.state.value
                .runFor(conversation.id)
                .pendingApproval !=
            null,
      );
      final disabling = app.agent.setEnabled(false);
      expect(app.agent.runtime.state.value.enabled, isFalse);
      await disabling;
      await sending;
      expect(app.agent.settings.enabled, isFalse);
      expect(app.session.committedData.applicationLedger, isNull);
    },
  );

  test(
    'conversation load failure is retryable and leaves main storage writable',
    () async {
      conversations.failLoad = true;
      await expectLater(app.agent.initialize(), throwsStateError);
      expect(app.agent.initializationError, isTrue);
      expect(
        app.agent.initializationFailure,
        AgentInitializationFailure.conversationStorage,
      );
      expect(app.agent.isInitialized, isFalse);
      expect(app.session.canWrite, isTrue);
      conversations.failLoad = false;
      await app.agent.initialize();
      expect(app.agent.initializationError, isFalse);
      expect(app.agent.initializationFailure, isNull);
      expect(app.agent.isInitialized, isTrue);
    },
  );

  test('initialization identifies unavailable main storage before opening side stores', () async {
    final reservation = app.maintenance.reserve();
    try {
      await expectLater(app.agent.initialize(), throwsStateError);
      expect(
        app.agent.initializationFailure,
        AgentInitializationFailure.applicationStorage,
      );
      expect(app.agent.initializationError, isTrue);
      expect(app.agent.isInitialized, isFalse);
      expect(conversations.loads, 0);
      expect(credentials.reads, 0);
      expect(provider.requests, isEmpty);
    } finally {
      app.maintenance.release(reservation);
    }
    await app.agent.initialize();
    expect(app.agent.initializationFailure, isNull);
    expect(app.agent.isInitialized, isTrue);
  });

  test(
    'connection initialization failure is classified and cleared on retry',
    () async {
      credentials.failRead = true;
      await expectLater(
        app.agent.initialize(),
        throwsA(isA<AgentConnectionException>()),
      );
      expect(
        app.agent.initializationFailure,
        AgentInitializationFailure.connectionStorage,
      );
      expect(app.agent.initializationError, isTrue);
      expect(app.agent.isInitialized, isFalse);
      expect(conversations.loads, 1);
      expect(app.session.canWrite, isTrue);
      expect(provider.requests, isEmpty);
      credentials.failRead = false;
      await app.agent.initialize();
      expect(app.agent.initializationFailure, isNull);
      expect(app.agent.initializationError, isFalse);
      expect(app.agent.isInitialized, isTrue);
    },
  );

  test('checksum-valid retired automatic metadata fails safely without clearing conversations', () async {
    final createdAt = DateTime.utc(2026, 10, 30);
    final archive = ConversationArchive(
      revision: 5,
      selectedId: 'legacy-fixture',
      conversations: [
        AgentConversation(
          id: 'legacy-fixture',
          title: 'Preserved fixture',
          createdAt: createdAt,
          updatedAt: createdAt,
          modelSelection: const AgentModelSelection(
            modelId: 'fixture',
            reasoningEffort: AgentReasoningEffort.medium,
          ),
        ),
      ],
    );
    final raw = jsonDecode(archive.encode()) as Map;
    (((raw['conversations'] as List).single as Map)['modelSelection']
            as Map)['reasoningEffort'] =
        'auto';
    final source = jsonEncode(raw);
    final slot = jsonEncode({
      'version': 1,
      'revision': 5,
      'checksum': sha256.convert(utf8.encode(source)).toString(),
      'source': source,
    });
    conversations.slots = [slot, slot];
    await expectLater(
      app.agent.initialize(),
      throwsA(isA<ConversationStorageException>()),
    );
    expect(
      app.agent.initializationFailure,
      AgentInitializationFailure.conversationStorage,
    );
    expect(app.agent.isInitialized, isFalse);
    expect(app.agent.runtime.state.value.enabled, isFalse);
    expect(conversations.slots, [slot, slot]);
    expect(conversations.saves, 0);
    expect(app.session.canWrite, isTrue);
    expect(provider.requests, isEmpty);
  });

  test('initialization waits for retention persistence and does not report a late failure as ready', () async {
    await app.session.commitMutation(
      (data) => data.copyWith(
        agentSettings: data.agentSettings.copyWith(historyRetentionDays: 7),
      ),
      expectedEpoch: app.session.mutationEpoch,
    );
    final createdAt = DateTime.utc(2000);
    conversations.source = ConversationArchive(
      revision: 1,
      selectedId: 'expired-fixture',
      conversations: [
        AgentConversation(
          id: 'expired-fixture',
          title: 'Expired fixture',
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      ],
    ).encode();
    final entered = Completer<void>();
    final release = Completer<void>();
    addTearDown(() {
      if (!release.isCompleted) release.complete();
    });
    conversations.beforeSave = () async {
      entered.complete();
      await release.future;
    };
    conversations.failSave = true;
    final initialization = app.agent.initialize();
    final failure = expectLater(initialization, throwsStateError);
    await entered.future.timeout(const Duration(seconds: 5));
    expect(app.agent.isInitialized, isFalse);
    expect(app.agent.runtime.state.value.enabled, isFalse);
    expect(app.agent.initializationFailure, isNull);
    release.complete();
    await failure;
    expect(
      app.agent.initializationFailure,
      AgentInitializationFailure.conversationStorage,
    );
    expect(app.agent.initializationError, isTrue);
    expect(app.agent.isInitialized, isFalse);
    conversations.beforeSave = null;
    conversations.failSave = false;
    await app.agent.initialize();
    expect(app.agent.isInitialized, isTrue);
    expect(app.agent.initializationFailure, isNull);
    expect(app.agent.initializationError, isFalse);
    expect(app.agent.conversations.conversations, isEmpty);
    expect(provider.requests, isEmpty);
  });

  test('configuration never saves a currently unsaved UI edit', () async {
    await ready(AgentPermissionMode.full);
    final before = app.agent.settings.endpoint;
    app.session.replaceData(app.session.data.copyWith(localeCode: 'ja'));
    await expectLater(
      app.agent.configure(
        app.agent.settings.copyWith(endpoint: 'https://new.example/v1'),
      ),
      throwsA(isA<AgentConnectionException>()),
    );
    expect(app.agent.settings.endpoint, before);
    expect(app.session.data.localeCode, 'ja');
    expect(app.session.committedData.localeCode, isNot('ja'));
  });

  test('queued connection saves reject the old committed settings', () async {
    await ready(AgentPermissionMode.full);
    final baseline = app.agent.settings;
    final entered = Completer<void>();
    final release = Completer<void>();
    addTearDown(() {
      if (!release.isCompleted) release.complete();
    });
    credentials.beforeWrite = (slot, _) async {
      if (slot != AgentCredentialSlot.pending || entered.isCompleted) return;
      entered.complete();
      await release.future;
    };
    final writes = credentials.writes;
    final first = app.agent.configure(
      baseline.copyWith(endpoint: 'https://first.example/v1'),
      expectedSettings: baseline,
    );
    await entered.future.timeout(const Duration(seconds: 5));
    final stale = expectLater(
      app.agent.configure(
        baseline.copyWith(endpoint: 'https://stale.example/v1'),
        expectedSettings: baseline,
      ),
      throwsA(
        isA<AgentConnectionException>().having(
          (error) => error.code,
          'code',
          AgentConnectionErrorCode.configurationChanged,
        ),
      ),
    );
    release.complete();
    await first;
    await stale;
    expect(app.agent.settings.endpoint, 'https://first.example/v1');
    expect(credentials.writes - writes, 3);
    expect(app.agent.connections.status.needsRecovery, isFalse);
    expect(provider.requests, isEmpty);
    final current = app.agent.settings;
    await app.agent.configure(
      current.copyWith(endpoint: 'https://accepted.example/v1'),
      expectedSettings: current,
    );
    expect(app.agent.settings.endpoint, 'https://accepted.example/v1');
  });

  test('queued preferences cannot restore a stale settings page', () async {
    await ready(AgentPermissionMode.full);
    final baseline = app.agent.settings;
    final entered = Completer<void>();
    final release = Completer<void>();
    addTearDown(() {
      if (!release.isCompleted) release.complete();
    });
    credentials.beforeWrite = (slot, _) async {
      if (slot != AgentCredentialSlot.pending || entered.isCompleted) return;
      entered.complete();
      await release.future;
    };
    final first = app.agent.configure(
      baseline.copyWith(endpoint: 'https://new.example/v1'),
      expectedSettings: baseline,
    );
    await entered.future.timeout(const Duration(seconds: 5));
    final stale = expectLater(
      app.agent.configurePreferences(
        baseline.copyWith(systemInstructions: 'Unsaved old page'),
        expectedSettings: baseline,
      ),
      throwsA(
        isA<AgentConnectionException>().having(
          (error) => error.code,
          'code',
          AgentConnectionErrorCode.configurationChanged,
        ),
      ),
    );
    release.complete();
    await first;
    await stale;
    expect(app.agent.settings.endpoint, 'https://new.example/v1');
    expect(app.agent.settings.systemInstructions, baseline.systemInstructions);
    final current = app.agent.settings;
    await app.agent.configurePreferences(
      current.copyWith(systemInstructions: 'Current page'),
      expectedSettings: current,
    );
    expect(app.agent.settings.systemInstructions, 'Current page');
    expect(app.agent.settings.endpoint, current.endpoint);
  });

  test(
    'typed host validates unknown enum values and paginates discovery',
    () async {
      final scope = OperationScope(
        id: 'scope',
        policy: OperationPolicy(enabled: true, mode: AgentPermissionMode.plan),
      );
      Future<Map<String, Object?>> invoke(
        String name,
        Map<String, Object?> args,
      ) => app.agent.tools.execute(
        ProviderToolCall(id: name, name: name, arguments: jsonEncode(args)),
        scope,
        (_) async => null,
      );
      final first = await invoke('capabilities.describe', {'limit': 1});
      final next = await invoke('capabilities.describe', {
        'limit': 1,
        'offset': first['nextOffset'],
      });
      expect(first['tools'], isNot(next['tools']));
      for (final args in [
        {
          'commands': [
            {'kind': 'imaginary', 'action': 'create'},
          ],
        },
        {
          'commands': [
            {'kind': 'calendar', 'action': 'imaginary'},
          ],
        },
        {
          'commands': [
            {'kind': 'occurrence', 'action': 'patch', 'scope': 'imaginary'},
          ],
        },
      ]) {
        await expectLater(
          invoke('mutation.prepare', args),
          throwsA(
            isA<OperationProblem>().having(
              (e) => e.code,
              'code',
              OperationErrorCode.invalidArgument,
            ),
          ),
        );
      }
    },
  );

  test('receipt byte compaction preserves applied status and continuation', () {
    final value = boundedToolReceipt({
      'status': 'committed',
      'operationId': 'fixed',
      'replayed': false,
      'changes': List.generate(
        30,
        (i) => {'key': 'event:$i', 'before': 'x' * 80000, 'after': null},
      ),
    });
    expect(
      utf8.encode(jsonEncode(value)).length,
      lessThan(ApplicationToolHost.maxResultBytes),
    );
    expect(value['status'], 'committed');
    expect(value['operationId'], 'fixed');
    expect(value['hasMoreChanges'], isTrue);
    expect(value['nextOffset'], 1);
  });
}
