import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/connection/agent_connection_manager.dart';
import 'package:sked/agent/connection/agent_connection_diagnostics.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/tools/agent_control_tool_adapters.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/models/agent_settings.dart';
import 'package:sked/models/timetable_models.dart';

import 'tool_adapter_test_support.dart';

Matcher _problem(OperationErrorCode code) =>
    isA<OperationProblem>().having((error) => error.code, 'code', code);

class _Diagnostics extends AgentConnectionDiagnostics {
  int probes = 0, catalogs = 0;
  @override
  Future<AgentConnectionProbeResult> probe(
    AgentSettings settings, {
    required String apiKey,
    bool allowInsecureHttp = false,
    ProviderCancellationToken? cancellation,
  }) async {
    probes++;
    expect(settings.model, 'model-a');
    return const AgentConnectionProbeResult(toolCallingObserved: false);
  }

  @override
  Future<AgentModelCatalog> listModels(
    AgentSettings settings, {
    required String apiKey,
    Uri? explicitEndpoint,
    bool allowInsecureHttp = false,
    ProviderCancellationToken? cancellation,
  }) async {
    catalogs++;
    return AgentModelCatalog(
      models: [for (var i = 0; i < 1800; i++) 'model-$i-${'x' * 64}'],
      complete: true,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ToolAdapterHarness h;
  late AgentConnectionManager connections;
  late AgentControlToolAdapters control;
  late _Diagnostics diagnostics;
  var writes = 0;
  var currentTime = DateTime.utc(2026, 10, 30);
  setUp(() async {
    writes = 0;
    currentTime = DateTime.utc(2026, 10, 30);
    h = ToolAdapterHarness();
    await h.initialize(
      data: buildInitialAppData(buildDefaultPeriodTimes()).copyWith(
        agentSettings: const AgentSettings(
          enabled: true,
          permissionMode: AgentPermissionMode.ask,
          endpoint: 'https://model.test/v1',
          model: 'model-a',
          systemInstructions: 'Keep my preference',
        ),
      ),
    );
    connections = AgentConnectionManager(
      store: MemoryAgentCredentialStore(),
      readSettings: () => h.session.committedData.agentSettings,
      persistSettings: (settings) async {
        await h.session.commitMutation(
          (data) => data.copyWith(agentSettings: settings),
          expectedEpoch: h.session.mutationEpoch,
        );
      },
    );
    await connections.initialize(migrateLegacy: false);
    diagnostics = _Diagnostics();
    control = AgentControlToolAdapters(
      host: h.host,
      external: h.external,
      connections: connections,
      platformTools: h.platform,
      diagnostics: diagnostics,
      clock: () => currentTime,
      configure: (scope, settings, {required credentialAction, rawKey}) async {
        expect(scope, same(h.scope));
        writes++;
        await connections.save(
          settings,
          credentialAction: credentialAction,
          rawKey: rawKey,
        );
      },
    );
  });
  tearDown(() async {
    control.dispose();
    diagnostics.close();
    await h.close();
  });

  test('diagnostics are explicit gated operations and catalogs page without another request', () async {
    final test = await h.call('connection.test.prepare');
    expect(diagnostics.probes, 0);
    h.scope.policy.update(mode: AgentPermissionMode.plan);
    await expectLater(
      h.externalCommit(test),
      throwsA(_problem(OperationErrorCode.readOnly)),
    );
    expect(diagnostics.probes, 0);
    h.scope.policy.update(mode: AgentPermissionMode.full);
    final tested = await h.externalCommit(test);
    expect((tested['effectResult'] as Map)['transportConnected'], isTrue);
    expect((tested['effectResult'] as Map)['toolCallingObserved'], isFalse);
    final catalog = await h.call('connection.models.prepare');
    final fetched = await h.externalCommit(catalog);
    expect(fetched['effectStatus'], 'applied');
    expect(fetched['detailsOmitted'], isTrue);
    final retry = await h.call('connection.models.prepare', {
      'operationId': catalog['operationId'],
    });
    expect((await h.externalCommit(retry))['replayed'], isTrue);
    h.scope.policy.update(mode: AgentPermissionMode.plan);
    final first = await h.call('connection.models.get', {
      'operationId': catalog['operationId'],
      'limit': 50,
    });
    expect(first['models'], hasLength(50));
    expect(first['hasMore'], isTrue);
    expect(first['count'], 1800);
    final last = await h.call('connection.models.get', {
      'operationId': catalog['operationId'],
      'offset': 1750,
    });
    expect(last['models'], hasLength(50));
    expect(last['hasMore'], isFalse);
    expect(diagnostics.catalogs, 1);
  });

  test('connection changes use three modes and preserve feature, permission and preferences', () async {
    final plan = await h.call('connection.prepare', {
      'action': 'set',
      'model': 'model-b',
    });
    expect(writes, 0);
    h.scope.policy.update(mode: AgentPermissionMode.plan);
    await expectLater(
      h.externalCommit(plan),
      throwsA(_problem(OperationErrorCode.readOnly)),
    );
    h.scope.policy.update(mode: AgentPermissionMode.ask);
    await expectLater(
      h.externalCommit(plan),
      throwsA(_problem(OperationErrorCode.cancelled)),
    );
    h.approval = (plan) async => h.scope.approve(plan.id);
    expect((await h.externalCommit(plan))['effectStatus'], 'applied');
    final settings = h.session.committedData.agentSettings;
    expect(settings.model, 'model-b');
    expect(settings.enabled, isTrue);
    expect(settings.permissionMode, AgentPermissionMode.ask);
    expect(settings.systemInstructions, 'Keep my preference');
    final retry = await h.call('connection.prepare', {
      'action': 'set',
      'model': 'model-b',
      'operationId': plan['operationId'],
    });
    expect((await h.externalCommit(retry))['replayed'], isTrue);
    expect(writes, 1);
  });

  test('model-list changes retain all enabled choices and their reasoning defaults', () async {
    final models = [
      const AgentModelConfig(id: 'model-a').toJson(),
      const AgentModelConfig(
        id: 'model-b',
        reasoningEfforts: [
          AgentReasoningEffort.auto,
          AgentReasoningEffort.high,
        ],
        defaultReasoningEffort: AgentReasoningEffort.high,
      ).toJson(),
    ];
    final plan = await h.call('connection.prepare', {
      'action': 'set',
      'model': 'model-b',
      'models': models,
    });
    h.scope.policy.update(mode: AgentPermissionMode.full);
    expect((await h.externalCommit(plan))['effectStatus'], 'applied');
    final actual = h.session.committedData.agentSettings;
    expect(actual.model, 'model-b');
    expect(actual.defaultModelSelection!.wireReasoningEffort, 'high');
    final described = await h.call('connection.describe');
    expect(described['models'], models);
    expect(described['writableFields'], contains('models'));
    expect(actual.credentialRef, isNull);
  });

  test(
    'invalid model lists fail preparation without writing configuration',
    () async {
      for (final models in [
        [
          {
            'id': 'model-a',
            'reasoningEfforts': ['high'],
            'defaultReasoningEffort': 'high',
          },
        ],
        [
          {
            'id': 'model-a',
            'reasoningEfforts': ['auto'],
            'defaultReasoningEffort': 'high',
          },
        ],
        [
          {
            'id': 'model-b',
            'reasoningEfforts': ['auto'],
            'defaultReasoningEffort': 'auto',
          },
        ],
      ]) {
        await expectLater(
          h.call('connection.prepare', {'action': 'set', 'models': models}),
          throwsA(_problem(OperationErrorCode.invalidArgument)),
        );
      }
      expect(writes, 0);
      expect(h.session.committedData.agentSettings.model, 'model-a');
    },
  );

  test(
    'an empty model list cannot silently discard an explicit default',
    () async {
      final before = h.session.committedData.agentSettings;
      await expectLater(
        h.call('connection.prepare', {
          'action': 'set',
          'model': 'model-a',
          'models': <Object?>[],
        }),
        throwsA(_problem(OperationErrorCode.invalidArgument)),
      );
      expect(writes, 0);
      expect(h.session.committedData.agentSettings, before);

      final plan = await h.call('connection.prepare', {
        'action': 'set',
        'models': <Object?>[],
      });
      h.scope.policy.update(mode: AgentPermissionMode.full);
      expect((await h.externalCommit(plan))['effectStatus'], 'applied');
      expect(h.session.committedData.agentSettings.availableModels, isEmpty);
      expect(h.session.committedData.agentSettings.model, isEmpty);
      expect(h.session.committedData.agentSettings.endpoint, before.endpoint);
    },
  );

  test('secure replacement uses an opaque handle and never returns or records the key', () async {
    const key = 'private-input-never-serialize';
    control.bindCredentialInput((endpoint) async {
      expect(endpoint.toString(), 'https://next.test/v1');
      return AgentCredentialInput(key);
    });
    final input = await h.call('credentials.request_input', {
      'endpoint': 'https://next.test/v1',
    });
    expect(input['configured'], isFalse);
    expect(jsonEncode(input), isNot(contains(key)));
    final args = {
      'action': 'set',
      'endpoint': 'https://next.test/v1',
      'model': 'model-c',
      'credentialAction': 'replace',
      'credentialHandle': input['credentialHandle'],
    };
    final plan = await h.call('connection.prepare', args);
    expect(connections.status.credentialAvailable, isFalse);
    final result = await h.externalCommit(plan);
    expect(result['effectStatus'], 'applied');
    expect(
      await connections.readKeyFor(h.session.committedData.agentSettings),
      key,
    );
    for (final value in [
      input,
      plan,
      result,
      h.session.committedData.toJson(),
    ]) {
      expect(jsonEncode(value), isNot(contains(key)));
    }
    control.bindCredentialInput(null);
    final retry = await h.call('connection.prepare', {
      ...args,
      'operationId': plan['operationId'],
    });
    expect((await h.externalCommit(retry))['replayed'], isTrue);
    expect(writes, 1);
    await expectLater(
      h.call('connection.prepare', {
        ...args,
        'model': 'different',
        'operationId': plan['operationId'],
      }),
      throwsA(_problem(OperationErrorCode.duplicateMismatch)),
    );
  });

  test(
    'handles cannot move across endpoints or runs and expire without saving',
    () async {
      control.bindCredentialInput((_) async => AgentCredentialInput('key'));
      final input = await h.call('credentials.request_input', {
        'endpoint': 'https://next.test/v1',
      });
      final args = {
        'action': 'set',
        'endpoint': 'https://next.test/v1',
        'credentialAction': 'replace',
        'credentialHandle': input['credentialHandle'],
      };
      await expectLater(
        h.call('connection.prepare', {
          ...args,
          'endpoint': 'https://other.test',
        }),
        throwsA(_problem(OperationErrorCode.expired)),
      );
      final other = OperationScope(
        id: 'other',
        policy: OperationPolicy(enabled: true, mode: AgentPermissionMode.full),
      );
      await expectLater(
        h.host.execute(
          ProviderToolCall(
            id: 'cross',
            name: 'connection.prepare',
            arguments: jsonEncode(args),
          ),
          other,
          (_) async => null,
        ),
        throwsA(_problem(OperationErrorCode.expired)),
      );
      final plan = await h.call('connection.prepare', args);
      currentTime = currentTime.add(const Duration(minutes: 16));
      await expectLater(
        h.externalCommit(plan),
        throwsA(_problem(OperationErrorCode.conflict)),
      );
      await expectLater(
        h.call('connection.prepare', args),
        throwsA(_problem(OperationErrorCode.expired)),
      );
      expect(writes, 0);
    },
  );

  test(
    'revocation while input is open discards the secret and returns no handle',
    () async {
      final opened = Completer<void>();
      final pending = Completer<AgentCredentialInput?>();
      control.bindCredentialInput((_) {
        opened.complete();
        return pending.future;
      });
      final action = h.call('credentials.request_input', {
        'endpoint': 'https://model.test/v1',
      });
      final expected = expectLater(
        action,
        throwsA(_problem(OperationErrorCode.cancelled)),
      );
      await opened.future;
      h.scope.cancel();
      final input = AgentCredentialInput('discard-me');
      pending.complete(input);
      await expected;
      expect(input.take(), isNull);
      expect(writes, 0);
    },
  );

  test('plan mode does not open credential input and raw-key or permission arguments are rejected', () async {
    var opened = 0;
    control.bindCredentialInput((_) async {
      opened++;
      return AgentCredentialInput('key');
    });
    h.scope.policy.update(mode: AgentPermissionMode.plan);
    await expectLater(
      h.call('credentials.request_input', {
        'endpoint': 'https://model.test/v1',
      }),
      throwsA(_problem(OperationErrorCode.readOnly)),
    );
    for (final args in [
      {'action': 'set', 'rawKey': 'secret'},
      {'action': 'set', 'permissionMode': 'full'},
    ]) {
      await expectLater(
        h.call('connection.prepare', args),
        throwsA(_problem(OperationErrorCode.invalidArgument)),
      );
    }
    expect(opened, 0);
    expect(writes, 0);
  });

  test('destination changes cannot keep a key and reset clears only connection state', () async {
    await connections.save(
      h.session.committedData.agentSettings,
      credentialAction: AgentCredentialAction.replace,
      rawKey: 'old-private-key',
    );
    await expectLater(
      h.call('connection.prepare', {
        'action': 'set',
        'endpoint': 'https://next.test/v1',
      }),
      throwsA(_problem(OperationErrorCode.invalidArgument)),
    );
    final plan = await h.call('connection.prepare', {'action': 'reset'});
    expect((await h.externalCommit(plan))['effectStatus'], 'applied');
    final settings = h.session.committedData.agentSettings;
    expect(settings.endpoint, isEmpty);
    expect(settings.model, isEmpty);
    expect(settings.credentialRef, isNull);
    expect(settings.enabled, isTrue);
    expect(settings.permissionMode, AgentPermissionMode.ask);
    expect(settings.systemInstructions, 'Keep my preference');
    expect(connections.status.credentialAvailable, isFalse);
  });

  test('connection discovery strips stored URL query data and credential references', () async {
    await connections.save(
      h.session.committedData.agentSettings.copyWith(
        endpoint: 'https://model.test/v1?token=private-query',
      ),
      credentialAction: AgentCredentialAction.replace,
      rawKey: 'private-key',
    );
    final result = await h.call('connection.describe');
    expect(result['endpoint'], 'https://model.test/v1');
    expect(jsonEncode(result), isNot(contains('private')));
    expect(
      jsonEncode(result),
      isNot(contains(h.session.committedData.agentSettings.credentialRef!)),
    );
  });
}
