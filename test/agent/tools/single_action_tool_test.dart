import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/operations/operation_executor.dart';
import 'package:sked/agent/operations/tool_outcome.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/tools/application_tool_host.dart';
import 'package:sked/agent/tools/platform_tool_adapters.dart';
import 'package:sked/application/external_operation_coordinator.dart';
import 'package:sked/application/mutation_draft.dart';
import 'package:sked/application/operation_contracts.dart';

import 'core_tool_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CoreToolHarness core;
  late ApplicationToolHost host;
  late OperationScope scope;
  late List<AgentOperationUpdate> updates;
  var knowledgeReads = 0;

  setUp(() async {
    core = CoreToolHarness();
    await core.initialize();
    knowledgeReads = 0;
    host = ApplicationToolHost(
      session: core.session,
      mutations: core.mutations,
      conversationForScope: (_) => null,
      readSkillSnapshot: () {
        knowledgeReads++;
        throw StateError('Knowledge storage is unavailable.');
      },
    );
    scope = OperationScope(
      id: 'single-action',
      policy: OperationPolicy(enabled: true, mode: AgentPermissionMode.full),
    );
    updates = [];
    host.onOperationUpdate = (_, update) async => updates.add(update);
  });
  tearDown(() async {
    host.finishScope(scope);
    host.dispose();
    core.tools.dispose();
    await core.close();
  });

  ProviderToolCall call(
    String name,
    Map<String, Object?> args, [
    String id = 'call',
  ]) => ProviderToolCall(id: id, name: name, arguments: jsonEncode(args));

  final create = {
    'commands': [
      {
        'kind': 'calendar',
        'action': 'create',
        'values': {'name': 'Created'},
      },
    ],
  };

  test(
    'discovery publishes one business action without host identities',
    () async {
      final catalog = await host.execute(
        call('capabilities.describe', {
          'names': [
            'mutation.apply',
            'settings.update',
            'operations.undo',
            'calendars.list',
          ],
        }),
        scope,
        (_) async => fail('A read cannot request approval.'),
      );
      expect(catalog['toolApiVersion'], '2.0.0');
      expect(
        host.registeredNames,
        containsAll(['mutation.apply', 'operations.undo']),
      );
      expect(
        host.registeredNames.any(
          (name) => name.contains('.prepare') || name.endsWith('.commit'),
        ),
        isFalse,
      );
      final definition = host
          .toolsFor(scope)
          .firstWhere((item) => item.name == 'mutation.apply');
      expect(
        (definition.parameters['properties'] as Map).containsKey('operationId'),
        isFalse,
      );
      for (final name in ['mutation.apply', 'settings.update']) {
        final description = host
            .toolsFor(scope)
            .singleWhere((tool) => tool.name == name)
            .description;
        expect(description, isNot(contains('does not write')));
        expect(description, isNot(contains('without saving')));
        expect(description, isNot(contains('Commit the returned plan')));
      }
      final undo = host
          .toolsFor(scope)
          .firstWhere((item) => item.name == 'operations.undo');
      expect(
        (undo.parameters['properties'] as Map).keys,
        contains('targetOperationId'),
      );
      expect(
        (undo.parameters['properties'] as Map).containsKey('operationId'),
        isFalse,
      );
      await host.execute(
        call('calendars.list', {}),
        scope,
        (_) async => fail('Unexpected approval'),
      );
      expect(knowledgeReads, 0);
    },
  );

  for (final mode in AgentPermissionMode.values) {
    test('a single invocation completes the $mode policy', () async {
      scope.policy.update(mode: mode);
      final before = core.session.committedData.generalMode.schedules.length;
      var approvals = 0;
      var ownershipSaved = false;
      host.onOperationPrepared =
          (original, owner, receiptTool, prepared) async {
            expect(original.id, 'business-call');
            expect(identical(owner, scope), isTrue);
            expect(receiptTool, 'mutation.commit');
            expect(prepared['operationId'], isNotEmpty);
            expect(
              core.session.committedData.generalMode.schedules.length,
              before,
            );
            ownershipSaved = true;
          };
      final result = await host.executeOutcome(
        call('mutation.apply', create, 'business-call'),
        scope,
        (plan) async {
          expect(ownershipSaved, isTrue);
          approvals++;
          return scope.approve(plan.id);
        },
      );
      expect(result.payload.containsKey('planId'), isFalse);
      final planId = updates
          .map((update) => update.details['planId'])
          .whereType<String>()
          .first;
      expect(core.mutations.plan(planId), isNull);
      expect(
        updates.every((update) => update.callId == 'business-call'),
        isTrue,
      );
      if (mode == AgentPermissionMode.plan) {
        expect(result.kind, ToolOutcomeKind.preview);
        expect(core.session.committedData.generalMode.schedules.length, before);
        expect(ownershipSaved, isFalse);
        expect(updates.last.phase, AgentOperationPhase.previewed);
      } else {
        expect(result.kind, ToolOutcomeKind.saved);
        expect(
          core.session.committedData.generalMode.schedules.length,
          before + 1,
        );
        expect(
          core
              .session
              .committedData
              .applicationLedger!
              .receipts
              .single
              .operationId,
          result.operationId,
        );
        expect(updates.last.phase, AgentOperationPhase.completed);
      }
      expect(approvals, mode == AgentPermissionMode.ask ? 1 : 0);
      if (mode == AgentPermissionMode.ask) {
        expect(updates.map((update) => update.phase), [
          AgentOperationPhase.preparing,
          AgentOperationPhase.waitingApproval,
          AgentOperationPhase.executing,
          AgentOperationPhase.completed,
        ]);
      }
    });
  }

  test(
    'ownership persistence completes before approval or any accepted write',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      host.onOperationPrepared = (_, _, _, _) async {
        entered.complete();
        await release.future;
      };
      final before = core.session.committedData;
      final running = host.execute(
        call('mutation.apply', create),
        scope,
        (_) async => fail('Unexpected approval'),
      );
      await entered.future;
      expect(core.session.committedData, same(before));
      release.complete();
      expect((await running)['status'], 'committed');
    },
  );

  test(
    'declining the inline approval produces one cancelled result and no save',
    () async {
      scope.policy.update(mode: AgentPermissionMode.ask);
      final before = core.session.committedData;
      final result = await host.executeOutcome(
        call('mutation.apply', create),
        scope,
        (_) async => null,
      );
      expect(result.kind, ToolOutcomeKind.cancelled);
      expect(core.session.committedData, same(before));
      expect(updates.last.phase, AgentOperationPhase.cancelled);
      final planId = updates
          .map((update) => update.details['planId'])
          .whereType<String>()
          .first;
      expect(core.mutations.plan(planId), isNull);
    },
  );

  test('invalid arguments return a correctable outcome and a corrected call can save', () async {
    final invalid = await host.executeOutcome(
      call('mutation.apply', {
        'commands': [
          {
            'kind': 'calendar',
            'action': 'create',
            'values': {'title': 'wrong field'},
          },
        ],
      }),
      scope,
      (_) async => fail('Unexpected approval'),
    );
    expect(invalid.kind, ToolOutcomeKind.correctableError);
    final corrected = await host.executeOutcome(
      call('mutation.apply', create, 'corrected'),
      scope,
      (_) async => fail('Unexpected approval'),
    );
    expect(corrected.kind, ToolOutcomeKind.saved);
    expect(
      core.session.committedData.applicationLedger!.receipts,
      hasLength(1),
    );
    final unknown = await host.executeOutcome(
      call('missing.tool', {}),
      scope,
      (_) async => null,
    );
    expect(unknown.kind, ToolOutcomeKind.correctableError);
  });

  test(
    'invalid wire arguments are correctable at the tool entrypoint',
    () async {
      for (final arguments in ['[]', '{', '{"value":1e999}']) {
        final outcome = await host.executeOutcome(
          ProviderToolCall(
            id: 'invalid',
            name: 'mutation.apply',
            arguments: arguments,
          ),
          scope,
          (_) async => null,
        );
        expect(outcome.kind, ToolOutcomeKind.correctableError);
        expect((outcome.payload['error'] as Map)['code'], 'invalidArgument');
      }
      expect(core.session.committedData.applicationLedger, isNull);
      final corrected = await host.executeOutcome(
        call('mutation.apply', create),
        scope,
        (_) async => null,
      );
      expect(corrected.kind, ToolOutcomeKind.saved);
    },
  );

  test(
    'activity and model share the same normalized argument failure',
    () async {
      host.register(
        ToolDefinition(
          name: 'synthetic.prepare',
          description: 'Synthetic action',
          parameters: {'type': 'object', 'properties': <String, Object?>{}},
        ),
        (_, _, _) async =>
            throw const FormatException('Internal decoder detail'),
      );
      final result = await host.executeOutcome(
        call('synthetic.apply', {}),
        scope,
        (_) async => null,
      );
      expect(result.kind, ToolOutcomeKind.correctableError);
      expect(updates.last.phase, AgentOperationPhase.failed);
      expect(updates.last.details['error'], result.payload['error']);
    },
  );

  test(
    'the whole batch is validated before a single business transaction',
    () async {
      final before = core.session.committedData;
      final result = await host.executeOutcome(
        call('mutation.apply', {
          'commands': [
            {
              'kind': 'calendar',
              'action': 'create',
              'values': {'name': 'Valid'},
            },
            {
              'kind': 'calendar',
              'action': 'create',
              'values': {'title': 'Invalid'},
            },
          ],
        }),
        scope,
        (_) async => fail('Unexpected approval'),
      );
      expect(result.kind, ToolOutcomeKind.correctableError);
      expect(core.session.committedData, same(before));
    },
  );

  test(
    'external adapters use the same invocation and durable receipt bridge',
    () async {
      final external = ExternalOperationCoordinator(
        session: core.session,
        settlePendingChanges: () async {},
        dataSessionRevision: () => 0,
        fallbackGeneration: () => core.mutations.generation,
      );
      registerPlatformTools(host, external: external);
      var effects = 0;
      host.register(
        ToolDefinition(
          name: 'fixture.prepare',
          description: 'Prepare a fixture effect.',
          parameters: {
            'type': 'object',
            'properties': {
              'operationId': {'type': 'string'},
            },
            'required': <String>[],
            'additionalProperties': false,
          },
        ),
        (_, owner, _) async => external
            .prepare(
              scope: owner,
              action: 'fixture.apply',
              arguments: const {},
              version: 1,
              changes: [
                ResourceChange(key: 'fixture', before: false, after: true),
              ],
              validate: () {},
              execute: (operation) async {
                effects++;
                expect(
                  core.session.committedData.applicationLedger!.receiptFor(
                    operation.operationId,
                  ),
                  isNotNull,
                );
                return ExternalEffectResult(state: ExternalEffectState.applied);
              },
            )
            .summary(),
      );
      host.onOperationPrepared = (_, _, receiptTool, _) async =>
          expect(receiptTool, 'external.commit');
      scope.policy.update(mode: AgentPermissionMode.plan);
      final preview = await host.executeOutcome(
        call('fixture.apply', {}, 'preview'),
        scope,
        (_) async => fail('Unexpected approval'),
      );
      expect(preview.kind, ToolOutcomeKind.preview);
      expect(effects, 0);
      expect(external.plan(updates.last.details['planId'] as String), isNull);
      scope.policy.update(mode: AgentPermissionMode.full);
      final result = await host.executeOutcome(
        call('fixture.apply', {}),
        scope,
        (_) async => fail('Unexpected approval'),
      );
      expect(result.kind, ToolOutcomeKind.saved);
      expect(effects, 1);
      expect(
        core.session.committedData.applicationLedger!.receipts,
        hasLength(1),
      );
      expect(result.operationId, isNotNull);
    },
  );
}
