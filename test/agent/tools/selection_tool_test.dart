import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/application/resource_mutations.dart';
import 'package:sked/application/resource_contracts.dart';

import 'core_tool_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CoreToolHarness app;
  late OperationScope scope;

  setUp(() async {
    app = CoreToolHarness();
    await app.initialize();
    scope = OperationScope(
      id: 'selection-run',
      policy: OperationPolicy(enabled: true, mode: AgentPermissionMode.full),
    );
    final plan = app.mutations.prepare(
      scope: scope,
      resources: [
        for (final suffix in ['A', 'B'])
          ResourceMutation(
            kind: ResourceKind.calendar,
            action: ResourceMutationAction.create,
            values: {'name': 'Managed $suffix'},
          ),
      ],
    );
    await app.mutations.commit(planId: plan.id, scope: scope);
  });
  tearDown(() async {
    scope.cancel();
    await app.close();
  });

  Future<Map<String, Object?>> call(String name, Map<String, Object?> args) =>
      app.tools.execute(
        ProviderToolCall(id: name, name: name, arguments: jsonEncode(args)),
        scope,
        (_) async => null,
      );

  test(
    'a common patch applies exactly the selected hidden and inactive resources',
    () async {
      final selection = await call('selection.create', {
        'kind': 'calendar',
        'query': 'Managed',
      });
      expect(selection['totalMatches'], 2);
      final plan = await call('mutation.prepare', {
        'selectionRef': selection['selectionRef'],
        'action': 'patch',
        'values': {'isVisible': false},
      });
      final result = await call('mutation.commit', {'planId': plan['planId']});
      expect(result['status'], 'committed');
      expect(result['changeCount'], 2);
      final calendars = app.session.committedData.generalMode.schedules;
      expect(
        calendars
            .where((item) => item.name.startsWith('Managed'))
            .every((item) => !item.isVisible),
        isTrue,
      );
      expect(
        calendars
            .where((item) => !item.name.startsWith('Managed'))
            .every((item) => item.isVisible),
        isTrue,
      );
      await expectLater(
        call('selection.get', {'selectionRef': selection['selectionRef']}),
        throwsA(
          isA<OperationProblem>().having(
            (error) => error.code,
            'code',
            OperationErrorCode.expired,
          ),
        ),
      );
    },
  );

  test(
    'a selection cannot be combined with different explicit targets or create',
    () async {
      final selection = await call('selection.create', {
        'kind': 'calendar',
        'query': 'Managed',
      });
      final before = jsonEncode(app.session.committedData.toJson());
      for (final extra in [
        <String, Object?>{'commands': []},
        <String, Object?>{'action': 'create'},
      ]) {
        await expectLater(
          call('mutation.prepare', {
            'selectionRef': selection['selectionRef'],
            'action': 'delete',
            ...extra,
          }),
          throwsA(
            isA<OperationProblem>().having(
              (error) => error.code,
              'code',
              OperationErrorCode.invalidArgument,
            ),
          ),
        );
      }
      expect(jsonEncode(app.session.committedData.toJson()), before);
    },
  );

  test(
    'planning mode can inspect and prepare a set but cannot commit it',
    () async {
      scope.policy.update(mode: AgentPermissionMode.plan);
      final selection = await call('selection.create', {
        'kind': 'calendar',
        'query': 'Managed',
      });
      final plan = await call('mutation.prepare', {
        'selectionRef': selection['selectionRef'],
        'action': 'delete',
      });
      await expectLater(
        call('mutation.commit', {'planId': plan['planId']}),
        throwsA(
          isA<OperationProblem>().having(
            (error) => error.code,
            'code',
            OperationErrorCode.readOnly,
          ),
        ),
      );
      expect(
        app.session.committedData.generalMode.schedules.where(
          (item) => item.name.startsWith('Managed'),
        ),
        hasLength(2),
      );
    },
  );

  test('resource discovery exposes the actual command fields without returning business data', () async {
    for (final kind in ResourceKind.values) {
      final descriptor = await call('resources.describe', {'kind': kind.name});
      final schema = descriptor['valuesSchema'] as Map;
      expect(schema['additionalProperties'], isFalse);
      expect(schema['properties'], isNotEmpty);
      expect(jsonEncode(descriptor), isNot(contains('Managed A')));
    }
    final occurrence = await call('resources.describe', {'kind': 'occurrence'});
    expect(occurrence['actions'], contains('dismissReminder'));
    expect(occurrence['actions'], isNot(contains('create')));
  });
}
