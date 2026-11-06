import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/application/external_operation_coordinator.dart';
import 'package:sked/application/mutation_draft.dart';
import 'package:sked/application/operation_contracts.dart';

import 'tool_adapter_test_support.dart';

Matcher _invalidIdentity() => isA<OperationProblem>()
    .having((error) => error.code, 'code', OperationErrorCode.invalidArgument)
    .having((error) => error.field, 'field', 'operationId')
    .having(
      (error) => error.message,
      'new operation guidance',
      contains('Omit'),
    )
    .having(
      (error) => error.message,
      'existing operation guidance',
      contains('exact operationId returned by the host'),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ToolAdapterHarness h;
  setUp(() async {
    h = ToolAdapterHarness();
    await h.initialize();
  });
  tearDown(() => h.close());

  test(
    'discovery and provider schemas explain host-owned operation IDs',
    () async {
      const optionalNames = {
        'settings.prepare',
        'agent_settings.prepare',
        'mutation.prepare',
        'developer.sample.prepare',
        'notifications.permission.prepare',
      };
      const requiredNames = {
        'operations.status',
        'undo.prepare',
        'external.status',
        'external.reconcile',
      };
      final discovery = await h.call('capabilities.describe', {
        'names': [...optionalNames, ...requiredNames],
      });
      final tools = discovery['tools'] as List;
      expect(tools, hasLength(optionalNames.length + requiredNames.length));
      final providerTools = {
        for (final tool in h.host.toolsFor(h.scope)) tool.name: tool,
      };
      for (final tool in tools) {
        final name = tool['name'] as String;
        final parameters = tool['parameters'] as Map;
        final properties = parameters['properties'] as Map;
        final identity = properties['operationId'] as Map;
        expect(identity['type'], 'string');
        expect(
          identity['description'],
          contains('exact operationId'),
          reason: name,
        );
        if (optionalNames.contains(name)) {
          expect(identity['description'], contains('Omit for a new operation'));
          expect(
            identity['description'],
            contains('keep the original arguments'),
          );
          expect(parameters['required'], isNot(contains('operationId')));
        } else {
          expect(identity['description'], contains('for the target operation'));
          expect(parameters['required'], contains('operationId'));
        }
        expect(providerTools[name]!.parameters, parameters);
      }
    },
  );

  test(
    'identity guidance preserves adapter schema metadata and descriptions',
    () async {
      final definition = ToolDefinition(
        name: 'identity_test.prepare',
        description: 'Prepare the adapter operation.',
        strict: true,
        parameters: const {
          'type': 'object',
          'properties': {
            'operationId': {
              'type': 'string',
              'description': 'Adapter retry identity.',
              'maxLength': 256,
            },
            'value': {'type': 'string'},
          },
          'required': ['value'],
          'additionalProperties': false,
        },
      );
      h.host.register(definition, (args, _, _) async => args);
      await h.call('capabilities.describe', {
        'names': [definition.name],
      });
      final exposed = h.host
          .toolsFor(h.scope)
          .singleWhere((tool) => tool.name == definition.name);
      expect(exposed.strict, isTrue);
      expect(exposed.description, definition.description);
      expect(exposed.parameters['required'], ['value']);
      expect(exposed.parameters['additionalProperties'], isFalse);
      final properties = exposed.parameters['properties'] as Map;
      expect(properties['value'], {'type': 'string'});
      expect((properties['operationId'] as Map)['maxLength'], 256);
      expect(
        (properties['operationId'] as Map)['description'],
        startsWith('Adapter retry identity.'),
      );
      expect(
        ((definition.parameters['properties'] as Map)['operationId']
            as Map)['description'],
        'Adapter retry identity.',
      );
    },
  );

  test(
    'new mutation omits the identity and retries reuse the host receipt',
    () async {
      final original = h.session.committedData.generalMode.showWeekends;
      final arguments = {
        'edits': [
          {'key': 'general.showWeekends', 'action': 'set', 'value': !original},
        ],
      };
      for (final identity in [
        'change-settings',
        '00000000-0000-4000-8000-000000000001',
      ]) {
        await expectLater(
          h.call('settings.prepare', {...arguments, 'operationId': identity}),
          throwsA(_invalidIdentity()),
        );
        await expectLater(
          h.call('operations.status', {'operationId': identity}),
          throwsA(_invalidIdentity()),
        );
      }
      expect(h.storage.saveCount, 0);
      final plan = await h.call('settings.prepare', arguments);
      final operationId = plan['operationId'] as String;
      expect(operationId.split('/'), hasLength(3));
      expect(h.storage.saveCount, 0);
      final committed = await h.commit(plan);
      expect(committed['status'], 'committed');
      expect(h.session.committedData.generalMode.showWeekends, !original);
      final saves = h.storage.saveCount;
      final replay = await h.call('settings.prepare', {
        ...arguments,
        'operationId': operationId,
      });
      expect((await h.commit(replay))['replayed'], isTrue);
      expect(h.storage.saveCount, saves);
      final status = await h.call('operations.status', {
        'operationId': operationId,
      });
      expect(status['status'], 'committed');
      expect(status['operationId'], operationId);
    },
  );

  test(
    'external identity failures give guidance and host identity replays once',
    () async {
      var effects = 0;
      PreparedExternalMutation prepare({String? operationId}) =>
          h.external.prepare(
            scope: h.scope,
            action: 'identityTest.set',
            arguments: const {'enabled': true},
            version: 0,
            changes: [
              ResourceChange(
                key: 'identityTest:enabled',
                before: false,
                after: true,
              ),
            ],
            validate: () {},
            execute: (_) async {
              effects++;
              return ExternalEffectResult(
                state: ExternalEffectState.applied,
                details: const {'enabled': true},
              );
            },
            operationId: operationId,
          );
      for (final identity in [
        'change-device',
        '00000000-0000-4000-8000-000000000001',
      ]) {
        expect(
          () => prepare(operationId: identity),
          throwsA(_invalidIdentity()),
        );
        await expectLater(
          h.call('external.status', {'operationId': identity}),
          throwsA(_invalidIdentity()),
        );
      }
      expect(effects, 0);
      expect(h.storage.saveCount, 0);
      final plan = prepare();
      expect(plan.operationId.split('/'), hasLength(3));
      await h.external.commit(planId: plan.id, scope: h.scope);
      expect(effects, 1);
      final saves = h.storage.saveCount;
      final replay = prepare(operationId: plan.operationId);
      final result = await h.external.commit(planId: replay.id, scope: h.scope);
      expect(result.replayed, isTrue);
      expect(effects, 1);
      expect(h.storage.saveCount, saves);
      final status = await h.call('external.status', {
        'operationId': plan.operationId,
      });
      expect(status['operationId'], plan.operationId);
      expect(status['effectStatus'], 'applied');
    },
  );
}
