import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/knowledge/knowledge_service.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/application/operation_contracts.dart';

import '../../support/workspace_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'host actions load shared knowledge and freeze skills before any edit',
    () async {
      final app = await workspaceProvider(
        agentKnowledgeStorage: MemoryKnowledgeStorage(),
      );
      addTearDown(() async {
        await app.agent.quiesce();
        app.dispose();
      });
      await app.agent.initialize();
      expect(app.agent.knowledge.isLoaded, isFalse);
      final conversation = await app.agent.conversations.create(
        title: 'Skill snapshot',
        mode: AgentPermissionMode.full,
      );
      const changedBody = 'Use the next-run skill revision.';
      await app.agent.runtime.runHostAction(conversation.id, (
        scope,
        approve,
      ) async {
        Future<Map<String, Object?>> call(
          String name,
          Map<String, Object?> args,
        ) => app.agent.tools.execute(
          ProviderToolCall(
            id: '$name-first',
            name: name,
            arguments: jsonEncode(args),
          ),
          scope,
          approve,
        );
        await call('capabilities.describe', {
          'names': ['skills.load'],
        });
        expect(app.agent.knowledge.isLoaded, isTrue);
        final original = await app.agent.knowledge.read(
          KnowledgeKind.skill,
          'read-agenda',
        );
        await app.agent.knowledge.saveFromUi(
          app.agent.knowledge.prepareSave(original.copyWith(body: changedBody)),
        );
        final currentRun = await call('skills.load', {'id': 'read-agenda'});
        expect(currentRun['status'], 'loaded');
        expect(jsonEncode(currentRun), isNot(contains(changedBody)));
        return currentRun;
      });
      await app.agent.runtime.runHostAction(conversation.id, (
        scope,
        approve,
      ) async {
        final nextRun = await app.agent.tools.execute(
          ProviderToolCall(
            id: 'load-next',
            name: 'skills.load',
            arguments: jsonEncode({'id': 'read-agenda'}),
          ),
          scope,
          approve,
        );
        expect(nextRun['status'], 'loaded');
        expect(jsonEncode(nextRun), contains(changedBody));
        return nextRun;
      });
    },
  );
}
