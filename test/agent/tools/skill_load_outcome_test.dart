import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/skills/shared_skill_loader.dart';
import 'package:sked/agent/tools/application_tool_host.dart';
import 'package:sked/application/operation_contracts.dart';

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
    'invalidAsset',
    'unreadable',
  ]) {
    test('skills.load reports $failure and exposes no new tools', () async {
      final custom = _skill(
        'custom-fixture',
        body: 'Fixture instructions',
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

  test(
    'loading more than eight Skills keeps all tools and complete content',
    () async {
      final skills = [
        for (var index = 0; index < 9; index++)
          _skill(
            'custom-$index',
            body: index == 8 ? 'x' * (96 * 1024) : 'Fixture $index',
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
      final loaded = await _call(host, scope, 'skills.load', {
        'id': skills.last.skill.id,
      });
      expect(loaded['status'], 'loaded');
      expect(loaded['instructions'], 'x' * (96 * 1024));
      expect(host.toolsFor(scope).map((tool) => tool.name).toSet(), {
        ...before,
        'agenda.query',
      });
      expect(
        await _call(host, scope, 'skills.load', {'id': skills.first.skill.id}),
        containsPair('status', 'loaded'),
      );
      expect(await _call(host, scope, 'events.list', {}), contains('items'));
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
) => host.executeInternal(
  ProviderToolCall(id: name, name: name, arguments: jsonEncode(args)),
  scope,
  (_) async => null,
);
