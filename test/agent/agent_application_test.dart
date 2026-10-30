import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:sked/agent/connection/agent_connection_manager.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/tools/application_tool_host.dart';
import 'package:sked/agent/skills/shared_skill_loader.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/application/setting_registry.dart';
import 'package:sked/models/agent_settings.dart';

import '../support/workspace_harness.dart';

class _ConversationStorage extends ConversationStorage {
  _ConversationStorage() : super.base();
  String? source;
  bool failLoad = false;
  int loads = 0;
  @override
  Future<ConversationStorageLoad> load() async {
    loads++;
    if (failLoad) throw StateError('fixture storage failure');
    return ConversationStorageLoad(source: source);
  }

  @override
  Future<void> save(String value, {required int revision}) async {
    source = value;
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
  late _Provider provider;
  late AppRuntime app;

  setUp(() async {
    conversations = _ConversationStorage();
    provider = _Provider()..respond = (_) => _done();
    app = await workspaceProvider(
      agentConversationStorage: conversations,
      agentCredentialStore: MemoryAgentCredentialStore(),
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

  test(
    'disabled never-configured Agent stays dormant until explicitly opened',
    () async {
      expect(app.agent.settings.enabled, isFalse);
      expect(app.agent.isInitialized, isFalse);
      expect(conversations.loads, 0);
      expect(provider.requests, isEmpty);
      await app.agent.initialize();
      expect(conversations.loads, 1);
      expect(app.agent.isInitialized, isTrue);
      expect(app.agent.runtime.state.value.enabled, isFalse);
    },
  );

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
      expect(app.session.canWrite, isTrue);
      conversations.failLoad = false;
      await app.agent.initialize();
      expect(app.agent.initializationError, isFalse);
      expect(app.agent.isInitialized, isTrue);
    },
  );

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
