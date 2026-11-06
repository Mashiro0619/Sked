import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/runtime/agent_runtime_controller.dart';
import 'package:sked/agent/skills/shared_skill_loader.dart';
import 'package:sked/agent/tools/application_tool_host.dart';
import 'package:sked/agent/ui/agent_conversation_timeline.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/models/agent_settings.dart';

import 'core_tool_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CoreToolHarness app;
  setUp(() async {
    app = CoreToolHarness();
    await app.initialize();
  });
  tearDown(() async {
    app.tools.dispose();
    await app.close();
  });

  for (final failure in [
    'notFound',
    'disabled',
    'missingDependencies',
    'incompatible',
    'budgetExceeded',
    'invalidAsset',
    'unreadable',
  ]) {
    test('skills.load reports $failure and exposes no new tools', () async {
      final custom = _skill(
        'custom-fixture',
        body: failure == 'budgetExceeded'
            ? 'x' * (24 * 1024 + 1)
            : 'Fixture instructions',
        enabled: failure != 'disabled',
        requiredTools: [
          if (failure == 'missingDependencies') 'missing.tool',
          'agenda.query',
        ],
      );
      final host = ApplicationToolHost(
        session: app.session,
        mutations: app.mutations,
        conversationForScope: (_) => null,
        readSkillSnapshot: () => SkillOverlaySnapshot([custom]),
        loadSkillAsset: (path) async {
          if (path == SharedSkillLoader.manifestAsset) {
            final manifest = jsonDecode(await File(path).readAsString()) as Map;
            if (failure == 'incompatible') {
              manifest['runtimeContractVersion'] = 99;
            }
            return jsonEncode(manifest);
          }
          if (failure == 'invalidAsset') return 'Corrupt body';
          if (failure == 'unreadable') {
            throw StateError('Synthetic asset read failure');
          }
          return File(path).readAsString();
        },
      );
      addTearDown(host.dispose);
      final scope = OperationScope(
        id: failure,
        policy: OperationPolicy(enabled: true, mode: AgentPermissionMode.plan),
      );
      addTearDown(() => host.finishScope(scope));
      final before = host.toolsFor(scope).map((tool) => tool.name).toSet();
      final id = switch (failure) {
        'notFound' => 'nonexistent-skill',
        'invalidAsset' || 'unreadable' => 'read-agenda',
        _ => custom.skill.id,
      };
      final code = switch (failure) {
        'notFound' => OperationErrorCode.notFound,
        'disabled' ||
        'missingDependencies' ||
        'incompatible' => OperationErrorCode.unsupported,
        _ => OperationErrorCode.invalidArgument,
      };
      await expectLater(
        _call(host, scope, 'skills.load', {'id': id}),
        throwsA(
          isA<OperationProblem>()
              .having((error) => error.code, 'code', code)
              .having((error) => error.field, 'field', 'id')
              .having(
                (error) => error.message,
                'corrective guidance',
                isNotEmpty,
              ),
        ),
      );
      expect(host.toolsFor(scope).map((tool) => tool.name).toSet(), before);
      expect(scope.policy.enabled, true);
      expect(scope.isCancelled, false);
      expect(app.session.committedData.applicationLedger, isNull);
    });
  }

  test('reaching the loaded Skill count keeps existing tools and rejects the next load', () async {
    final skills = [
      for (var index = 0; index < 9; index++)
        _skill(
          'custom-$index',
          body: 'Fixture $index',
          requiredTools: [index == 8 ? 'agenda.query' : 'events.list'],
        ),
    ];
    final host = ApplicationToolHost(
      session: app.session,
      mutations: app.mutations,
      conversationForScope: (_) => null,
      loadSkillAsset: (path) => File(path).readAsString(),
      readSkillSnapshot: () => SkillOverlaySnapshot(skills),
    );
    addTearDown(host.dispose);
    final scope = OperationScope(
      id: 'count-budget',
      policy: OperationPolicy(enabled: true, mode: AgentPermissionMode.plan),
    );
    addTearDown(() => host.finishScope(scope));
    for (final skill in skills.take(8)) {
      expect(
        await _call(host, scope, 'skills.load', {'id': skill.skill.id}),
        containsPair('status', 'loaded'),
      );
    }
    final before = host.toolsFor(scope).map((tool) => tool.name).toSet();
    await expectLater(
      _call(host, scope, 'skills.load', {'id': skills.last.skill.id}),
      throwsA(
        isA<OperationProblem>().having(
          (error) => error.message,
          'budget guidance',
          contains('budget'),
        ),
      ),
    );
    expect(host.toolsFor(scope).map((tool) => tool.name).toSet(), before);
    expect(
      await _call(host, scope, 'skills.load', {'id': skills.first.skill.id}),
      containsPair('status', 'loaded'),
    );
    expect(await _call(host, scope, 'events.list', {}), contains('items'));
  });

  test(
    'runtime records a failed Skill load before the corrected load and query',
    () async {
      final storage = _Memory();
      final conversations = ConversationRepository(storage: storage);
      await conversations.load();
      final conversation = await conversations.create(title: 'Skill recovery');
      final provider = _Provider();
      final host = ApplicationToolHost(
        session: app.session,
        mutations: app.mutations,
        conversationForScope: (_) => conversations.find(conversation.id),
        loadSkillAsset: (path) => File(path).readAsString(),
      );
      final settings = AgentSettings(
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
      final runtime = AgentRuntimeController(
        repository: conversations,
        provider: provider,
        readSettings: () => settings,
        readApiKey: (_) async => 'fixture-key',
        readTools: host.toolsFor,
        executeTool: host.execute,
        onRunSettled: host.finishScope,
        onOpenSettings: () {},
      );
      addTearDown(() {
        runtime.dispose();
        conversations.dispose();
        provider.close();
        host.dispose();
      });
      await runtime.send(conversation.id, 'Inspect my agenda');
      final stored = ConversationArchive.decode(storage.source!)
          .conversations
          .single;
      final tools = stored.messages
          .where((message) => message.role == ConversationRole.tool)
          .toList();
      final failed = jsonDecode(tools.first.text) as Map;
      expect(failed['status'], 'failed');
      expect(failed['error'], containsPair('code', 'notFound'));
      expect(failed['error'], containsPair('field', 'id'));
      expect(jsonDecode(tools[1].text), containsPair('status', 'loaded'));
      expect(stored.runs.single.tools.map((tool) => tool.outcome), [
        ConversationAttemptOutcome.failed,
        ConversationAttemptOutcome.completed,
        ConversationAttemptOutcome.completed,
      ]);
      expect(stored.runs.single.status, ConversationRunStatus.completed);
      final activities = projectAgentConversationTimeline(stored)
          .whereType<AgentTimelineActivity>()
          .expand((activity) => activity.tools);
      expect(activities.map((activity) => activity.status), [
        AgentToolActivityStatus.failed,
        AgentToolActivityStatus.completed,
        AgentToolActivityStatus.completed,
      ]);
      expect(provider.requests, hasLength(4));
      expect(runtime.state.value.runFor(conversation.id).errorMessage, isNull);
      expect(app.session.committedData.applicationLedger, isNull);
    },
  );
}

SkillOverlay _skill(
  String id, {
  required String body,
  bool enabled = true,
  List<String> requiredTools = const [],
}) => SkillOverlay(
  skill: SkillDescriptor.editable(
    id: id,
    title: id,
    summary: 'Synthetic Skill',
    body: body,
    revision: 1,
    requiredTools: requiredTools,
  ),
  enabled: enabled,
  builtIn: false,
  body: body,
);

Future<Map<String, Object?>> _call(
  ApplicationToolHost host,
  OperationScope scope,
  String name,
  Map<String, Object?> args,
) => host.execute(
  ProviderToolCall(id: name, name: name, arguments: jsonEncode(args)),
  scope,
  (_) async => null,
);

class _Memory extends ConversationStorage {
  _Memory() : super.base();
  String? source;
  @override
  Future<ConversationStorageLoad> load() async =>
      ConversationStorageLoad(source: source);
  @override
  Future<void> save(String value, {required int revision}) async {
    source = value;
  }
}

class _Provider extends ProviderClient {
  final requests = <ProviderRequest>[];
  @override
  Stream<ProviderEvent> stream(
    ProviderRequest request, {
    required String apiKey,
    ProviderCancellationToken? cancellation,
  }) async* {
    final index = requests.length;
    requests.add(request);
    if (index == 1) {
      final result = jsonDecode(request.messages.last.text) as Map;
      expect(result['status'], 'failed');
      expect(result['error']['code'], 'notFound');
    }
    if (index == 2) {
      expect(request.tools.map((tool) => tool.name), contains('agenda.query'));
      expect(
        jsonDecode(request.messages.last.text),
        containsPair('status', 'loaded'),
      );
    }
    final call = switch (index) {
      0 => ProviderToolCall(
        id: 'missing',
        name: 'skills.load',
        arguments: '{"id":"unknown-skill"}',
      ),
      1 => ProviderToolCall(
        id: 'corrected',
        name: 'skills.load',
        arguments: '{"id":"read-agenda"}',
      ),
      2 => ProviderToolCall(
        id: 'query',
        name: 'agenda.query',
        arguments:
            '{"start":"2026-11-07T00:00:00","end":"2026-11-08T00:00:00"}',
      ),
      _ => null,
    };
    yield ProviderCompleted(
      ProviderResponse(
        text: call == null ? 'Agenda query completed.' : '',
        toolCalls: call == null ? [] : [call],
        finishReason: call == null ? 'stop' : 'tool_calls',
      ),
    );
  }
}
