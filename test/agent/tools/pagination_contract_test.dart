import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/conversations/conversation_models.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/tools/application_tool_host.dart';
import 'package:sked/application/operation_contracts.dart';

import 'core_tool_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'discovered page bounds are accepted and enforced by their tools',
    () async {
      final h = CoreToolHarness();
      await h.initialize();
      addTearDown(h.close);
      final scope = OperationScope(
        id: 'pagination-contract',
        policy: OperationPolicy(enabled: true, mode: AgentPermissionMode.plan),
      );
      final conversation = AgentConversation(
        id: 'conversation',
        title: 'Fixture',
        createdAt: DateTime.utc(2026, 10, 30),
        updatedAt: DateTime.utc(2026, 10, 30),
        messages: [
          ConversationMessage(
            id: 'message',
            role: ConversationRole.user,
            text: 'Synthetic pagination fixture',
            createdAt: DateTime.utc(2026, 10, 30),
          ),
        ],
      );
      final host = ApplicationToolHost(
        session: h.session,
        mutations: h.mutations,
        conversationForScope: (_) => conversation,
      );
      addTearDown(host.dispose);
      Future<Map<String, Object?>> call(
        String name,
        Map<String, Object?> args,
      ) => host.execute(
        ProviderToolCall(id: name, name: name, arguments: jsonEncode(args)),
        scope,
        (_) async => null,
      );
      const bounds = {
        'capabilities.describe': 16,
        'skills.search': 24,
        'conversation.history': 50,
        'conversation.read': 8000,
      };
      final catalog = await call('capabilities.describe', {
        'names': bounds.keys.toList(),
      });
      for (final tool in (catalog['tools'] as List).cast<Map>()) {
        final name = tool['name'] as String;
        final limit = (tool['parameters'] as Map)['properties']['limit'] as Map;
        expect(limit['minimum'], 1, reason: name);
        expect(limit['maximum'], bounds[name], reason: name);
        final args = <String, Object?>{
          if (name == 'capabilities.describe') 'names': [name],
          if (name == 'conversation.read') 'id': 'message',
        };
        await call(name, {...args, 'limit': limit['maximum']});
        for (final invalid in [0, (limit['maximum'] as int) + 1]) {
          await expectLater(
            call(name, {...args, 'limit': invalid}),
            throwsA(
              isA<OperationProblem>().having(
                (problem) => problem.code,
                'code',
                OperationErrorCode.invalidArgument,
              ),
            ),
            reason: name,
          );
        }
      }
      expect((catalog['tools'] as List), hasLength(bounds.length));
      expect(h.session.committedData.applicationLedger, isNull);
    },
  );
}
