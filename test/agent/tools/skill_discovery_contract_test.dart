import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/skills/shared_skill_loader.dart';
import 'package:sked/agent/tools/application_tool_host.dart';
import 'package:sked/application/operation_contracts.dart';

import 'core_tool_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CoreToolHarness app;
  late ApplicationToolHost host;
  late OperationScope scope;

  setUp(() async {
    app = CoreToolHarness();
    await app.initialize();
    host = app.tools;
    scope = OperationScope(
      id: 'skill-discovery',
      policy: OperationPolicy(enabled: true, mode: AgentPermissionMode.plan),
    );
  });
  tearDown(() async {
    host.finishScope(scope);
    host.dispose();
    if (!identical(host, app.tools)) app.tools.dispose();
    await app.close();
  });

  Future<Map<String, Object?>> search(Map<String, Object?> args) =>
      host.execute(
        ProviderToolCall(
          id: 'search',
          name: 'skills.search',
          arguments: jsonEncode(args),
        ),
        scope,
        (_) async => null,
      );

  test(
    'default catalog includes all bundled skills and explicit completeness',
    () async {
      final result = await search({});
      expect(result['skills'], hasLength(24));
      expect(result['totalMatches'], 24);
      expect(result['matchType'], 'catalog');
      expect(result['hasMore'], false);
      expect(result['nextOffset'], isNull);
      expect((result['skills'] as List).last['id'], 'recover-and-undo');
      expect(jsonEncode(result), isNot(contains('instructions')));
    },
  );

  test(
    'unmatched natural language receives an explicitly labelled catalog',
    () async {
      for (final query in [
        '帮我看看明天都有什么安排',
        'Show my schedule for tomorrow',
        '帮我把所有课程的地点改成第三教学楼',
      ]) {
        final result = await search({'query': query});
        expect(result['matchType'], 'catalogFallback', reason: query);
        expect(
          (result['skills'] as List).map((item) => item['id']),
          contains('read-agenda'),
        );
        expect(result['totalMatches'], 24);
      }
      final ranked = await search({'query': 'read-agenda'});
      expect(ranked['matchType'], 'keyword');
      expect((ranked['skills'] as List).first['id'], 'read-agenda');
    },
  );

  test('custom skills and ranked matches remain fully pageable', () async {
    host = ApplicationToolHost(
      session: app.session,
      mutations: app.mutations,
      conversationForScope: (_) => null,
      readSkillSnapshot: () => SkillOverlaySnapshot([
        for (var index = 0; index < 30; index++)
          SkillOverlay(
            skill: SkillDescriptor.editable(
              id: 'custom-$index',
              title: 'Custom $index',
              summary: 'Custom fixture',
              body: 'Fixture body',
              revision: 1,
            ),
            enabled: true,
            builtIn: false,
            body: 'Fixture body',
          ),
      ]),
    );
    for (final query in ['', 'custom', 'unmatched request']) {
      final ids = <String>[];
      var offset = 0;
      final expected = query == 'custom' ? 30 : 54;
      while (true) {
        final page = await search({
          'query': query,
          'offset': offset,
          'limit': 7,
        });
        final items = page['skills'] as List;
        expect(items.length, lessThanOrEqualTo(7));
        expect(page['totalMatches'], expected);
        ids.addAll(items.map((item) => item['id'] as String));
        if (page['hasMore'] == false) {
          expect(page['nextOffset'], isNull);
          break;
        }
        offset = page['nextOffset'] as int;
        expect(offset, ids.length);
      }
      expect(ids, hasLength(expected));
      expect(ids.toSet(), hasLength(expected));
    }
    final pastEnd = await search({'offset': 54});
    expect(pastEnd['skills'], isEmpty);
    expect(pastEnd['hasMore'], false);
    await expectLater(search({'offset': -1}), throwsA(isA<OperationProblem>()));
  });
}
