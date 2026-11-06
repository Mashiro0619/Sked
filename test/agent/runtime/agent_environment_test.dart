import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/connection/agent_credential_store.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/runtime/agent_runtime_controller.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/models/agent_settings.dart';

import '../../support/memory_conversation_storage.dart';
import '../../support/workspace_harness.dart';

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

class _Provider extends ProviderClient {
  final requests = <ProviderRequest>[];
  FutureOr<ProviderResponse> Function(ProviderRequest) respond = (_) =>
      ProviderResponse(text: 'Done', toolCalls: [], finishReason: 'stop');

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

Map<String, dynamic> _environment(ProviderRequest request) {
  final instructions = request.messages
      .firstWhere((message) => message.role == ProviderRole.system)
      .text;
  final line = instructions
      .split('\n')
      .firstWhere(
        (line) => line.startsWith('{') && line.contains('"localDateTime"'),
      );
  return jsonDecode(line) as Map<String, dynamic>;
}

ProviderResponse _call(String name, Map<String, Object?> args) =>
    ProviderResponse(
      text: '',
      toolCalls: [
        ProviderToolCall(
          id: 'call-$name',
          name: name,
          arguments: jsonEncode(args),
        ),
      ],
      finishReason: 'tool_calls',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('environment is frozen across tool rounds while host policy remains current', () async {
    final repository = ConversationRepository(
      storage: MemoryConversationStorage(),
    );
    await repository.load();
    final conversation = await repository.create(title: 'Snapshot');
    final provider = _Provider();
    var now = DateTime(2026, 11, 7, 23, 59);
    final start = now;
    final selection = <String, Object?>{'kind': 'calendar', 'id': 'original'};
    var captures = 0;
    late OperationScope capturedScope;
    late AgentRuntimeController runtime;
    runtime = AgentRuntimeController(
      repository: repository,
      provider: provider,
      readSettings: () => _settings,
      readApiKey: (_) async => '',
      clock: () => now,
      readEnvironment: () {
        captures++;
        return {'selectedCalendar': selection, 'workspace': 'general'};
      },
      readTools: (_) => [
        ToolDefinition(
          name: 'events.list',
          description: 'Read',
          parameters: {},
        ),
      ],
      executeTool: (_, scope, _) async {
        capturedScope = scope;
        expect(runtime.environmentForScope(scope)!['selectedCalendar'], {
          'kind': 'calendar',
          'id': 'original',
        });
        expect(
          runtime.environmentForScope(
            OperationScope(id: scope.id, policy: scope.policy),
          ),
          isNull,
        );
        selection['id'] = 'changed';
        now = DateTime(2026, 11, 8, 0, 1);
        await runtime.setMode(conversation.id, AgentPermissionMode.full);
        return {'items': []};
      },
      onOpenSettings: () {},
    );
    addTearDown(() {
      runtime.dispose();
      provider.close();
      repository.dispose();
    });
    provider.respond = (_) => provider.requests.length == 1
        ? _call('events.list', {})
        : ProviderResponse(text: 'Done', toolCalls: [], finishReason: 'stop');
    await runtime.send(conversation.id, 'Read tomorrow');
    expect(captures, 1);
    expect(provider.requests, hasLength(2));
    final first = _environment(provider.requests.first);
    final second = _environment(provider.requests.last);
    expect(DateTime.parse(first['localDateTime'] as String), start.toUtc());
    expect(first['localDateTime'], matches(RegExp(r'[+-]\d{2}:\d{2}$')));
    expect(first['utcOffsetMinutes'], start.timeZoneOffset.inMinutes);
    expect(first['timeZoneName'], start.timeZoneName);
    expect(first['weekStartsOn'], DateTime.monday);
    expect(second['localDateTime'], first['localDateTime']);
    expect(second['selectedCalendar'], {'kind': 'calendar', 'id': 'original'});
    expect(first['permissionMode'], 'ask');
    expect(second['permissionMode'], 'full');
    expect(runtime.environmentForScope(capturedScope), isNull);
  });

  test(
    'default clock snapshot refreshes for explicit continuation and new input',
    () async {
      final repository = ConversationRepository(
        storage: MemoryConversationStorage(),
      );
      await repository.load();
      final conversation = await repository.create(title: 'Refresh');
      final provider = _Provider();
      var now = DateTime(2026, 11, 7, 23, 59);
      final runtime = AgentRuntimeController(
        repository: repository,
        provider: provider,
        readSettings: () => _settings,
        readApiKey: (_) async => '',
        readTools: (_) => [],
        executeTool: (_, _, _) async => {},
        onOpenSettings: () {},
        clock: () => now,
      );
      addTearDown(() {
        runtime.dispose();
        provider.close();
        repository.dispose();
      });
      provider.respond = (_) =>
          throw const ProviderException(ProviderError.transportFailure);
      await runtime.send(conversation.id, 'Tomorrow');
      final original = _environment(provider.requests.single);
      now = DateTime(2026, 11, 8, 0, 1);
      provider.respond = (_) =>
          ProviderResponse(text: 'Done', toolCalls: [], finishReason: 'stop');
      await runtime.continueConversation(conversation.id);
      final resumed = _environment(provider.requests.last);
      expect(resumed['localDateTime'], isNot(original['localDateTime']));
      expect(DateTime.parse(resumed['localDateTime'] as String), now.toUtc());
      now = DateTime(2026, 11, 9, 0, 1);
      await runtime.send(conversation.id, 'Today');
      expect(
        DateTime.parse(
          _environment(provider.requests.last)['localDateTime'] as String,
        ),
        now.toUtc(),
      );
      expect(repository.find(conversation.id)!.runs, hasLength(3));
    },
  );

  test(
    'environment values pass the same credential checks before JSON encoding',
    () async {
      const key = 'fixture"key\\value';
      final repository = ConversationRepository(
        storage: MemoryConversationStorage(),
      );
      await repository.load();
      final conversation = await repository.create(title: 'Sensitive fixture');
      final provider = _Provider();
      final runtime = AgentRuntimeController(
        repository: repository,
        provider: provider,
        readSettings: () => _settings,
        readApiKey: (_) async => key,
        readEnvironment: () => {
          'selectedCalendar': {'id': key},
        },
        readTools: (_) => [],
        executeTool: (_, _, _) async => {},
        onOpenSettings: () {},
      );
      addTearDown(() {
        runtime.dispose();
        provider.close();
        repository.dispose();
      });
      await runtime.send(conversation.id, 'Read');
      expect(provider.requests, isEmpty);
      expect(
        runtime.state.value.runFor(conversation.id).errorMessage,
        'sensitiveContent',
      );
    },
  );

  test(
    'application supplies actual selections before a skill can query dates',
    () async {
      final provider = _Provider();
      final app = await workspaceProvider(
        agentConversationStorage: MemoryConversationStorage(),
        agentCredentialStore: MemoryAgentCredentialStore(),
        agentProvider: provider,
      );
      addTearDown(() async {
        await app.agent.quiesce();
        app.dispose();
      });
      await app.agent.configure(_settings);
      await app.agent.setEnabled(true);
      final conversation = await app.agent.conversations.create(
        title: 'Agenda',
        mode: AgentPermissionMode.plan,
      );
      final before = app.session.committedData;
      final originalData = jsonEncode(before.toJson());
      provider.respond = (request) => switch (provider.requests.length) {
        1 => _call('skills.load', {'id': 'read-agenda'}),
        2 => _call('agenda.query', {
          'start': '2026-11-08T00:00:00',
          'end': '2026-11-09T00:00:00',
        }),
        3 => _call('capabilities.describe', {
          'names': ['agenda.query'],
        }),
        _ => ProviderResponse(
          text: 'Done',
          toolCalls: [],
          finishReason: 'stop',
        ),
      };
      await app.agent.runtime.send(conversation.id, '帮我看看明天的安排');
      expect(provider.requests, hasLength(4));
      final environment = _environment(provider.requests.first);
      expect(environment['workspace'], before.activeMode.name);
      expect(environment['localeCode'], before.localeCode);
      expect(environment['datasetGeneration'], app.agent.mutations.generation);
      expect(environment['permissionMode'], 'plan');
      expect(environment['selectedCalendar'], {
        'kind': 'calendar',
        'id': before.generalMode.activeScheduleId,
      });
      expect(
        environment['selectedTimetable'],
        before.studentMode.timetables.isEmpty
            ? null
            : {'kind': 'timetable', 'id': before.studentMode.activeTimetableId},
      );
      for (final request in provider.requests) {
        expect(_environment(request), environment);
      }
      final discovery = jsonDecode(
        provider.requests.last.messages
            .lastWhere((message) => message.role == ProviderRole.tool)
            .text,
      ) as Map;
      expect(discovery['now'], environment['localDateTime']);
      expect(discovery['workspace'], environment['workspace']);
      expect(jsonEncode(app.session.committedData.toJson()), originalData);
      expect(
        app.agent.runtime.state.value.runFor(conversation.id).errorMessage,
        isNull,
      );
    },
  );
}
