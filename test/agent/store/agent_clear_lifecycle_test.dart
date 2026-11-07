import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/store/agent_store.dart';
import 'package:sked/application/external_operation_coordinator.dart';
import 'package:sked/application/mutation_draft.dart';
import 'package:sked/application/operation_contracts.dart';

import '../../support/workspace_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('an Agent-owned clear does not wait for itself or recreate its database', () async {
    final root = await Directory.systemTemp.createTemp('sked-agent-clear-');
    final file = File('${root.path}${Platform.pathSeparator}agent.sqlite');
    final store = AgentStore.open(filePath: file.path);
    final app = await workspaceProvider(agentStore: store);
    addTearDown(() async {
      await app.agent.quiesce();
      app.dispose();
      await store.close();
      await root.delete(recursive: true);
    });
    await app.agent.initialize();
    final chat = await app.agent.conversations.create(
      title: 'Synthetic clear',
      mode: AgentPermissionMode.full,
    );
    var cleared = false;
    app.agent.tools.register(
      ToolDefinition(
        name: 'fixture.clear.prepare',
        description: 'Clear only the synthetic Agent database.',
        parameters: const {
          'type': 'object',
          'properties': {},
          'additionalProperties': false,
        },
      ),
      (_, scope, _) async => app.agent.external
          .prepare(
            scope: scope,
            action: 'fixture.clear',
            arguments: const {},
            version: 1,
            changes: [
              ResourceChange(
                key: 'fixture.database',
                before: true,
                after: false,
              ),
            ],
            validate: () {},
            execute: (_) => app.agent.runMaintenanceFromAgent(scope, () async {
              await app.dataClear.run(
                clear: () async {
                  expect(await file.exists(), isTrue);
                  await file.delete();
                  cleared = true;
                },
                exit: () async {},
              );
              return ExternalEffectResult(
                state: ExternalEffectState.applied,
                dataStatus: ExternalDataState.committed,
                details: {'cleared': true},
              );
            }),
          )
          .summary(),
    );
    try {
      await app.agent.runtime
          .runHostTool(
            chat.id,
            toolName: 'fixture.clear.apply',
            arguments: const {},
          )
          .timeout(const Duration(seconds: 10));
    } catch (error) {
      // The transcript itself was cleared. Its late result may be refused,
      // but the accepted clear must have completed and its database stay gone.
      expect(error, isNot(isA<TimeoutException>()));
    }
    expect(cleared, isTrue);
    await app.agent.quiesce();
    expect(await file.exists(), isFalse);
  });
}
