import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/skills/shared_skill_loader.dart';

void main() {
  test(
    'all 24 published source assets match manifest metadata and digests',
    () async {
      final raw = jsonDecode(
        await File(SharedSkillLoader.manifestAsset).readAsString(),
      ) as Map;
      final entries = raw['skills'] as List;
      expect(entries, hasLength(24));
      expect(entries.map((entry) => entry['id']).toSet(), {
        'locate-and-navigate',
        'read-agenda',
        'find-free-time',
        'manage-semester',
        'edit-courses',
        'manage-period-times',
        'resolve-course-conflicts',
        'organize-calendars',
        'edit-events',
        'edit-recurring-events',
        'manage-reminders',
        'batch-change',
        'import-school-web',
        'import-pasted-content',
        'import-structured-files',
        'export-and-backup',
        'restore-and-clear',
        'configure-appearance',
        'configure-display',
        'configure-workspaces',
        'troubleshoot-notifications',
        'manage-school-access',
        'configure-agent-connection',
        'recover-and-undo',
      });
      final tools = <String>{
        for (final entry in entries)
          ...List<String>.from(entry['requiredTools'] as List),
      };
      final loader = SharedSkillLoader(
        loadString: (asset) => File(asset).readAsString(),
        registeredTools: tools,
        budgets: const SkillBudgets(
          maxLoadedSkills: 24,
          maxLoadedBytes: 256 * 1024,
        ),
      );
      final catalog = await loader.catalog();
      expect(
        catalog.every((entry) => entry.status == SkillStatus.available),
        true,
      );
      expect(loader.loadedSkills, isEmpty);
      for (final entry in catalog) {
        final result = await loader.load(entry.skill.id);
        expect(result.status, SkillStatus.loaded, reason: entry.skill.id);
        expect(result.body, contains('只读计划模式'));
        expect(result.body, contains('每次修改前询问模式'));
        expect(result.body, contains('完全权限'));
        expect(result.body, contains('正常：'));
        expect(result.body, contains('边界：'));
        expect(result.body, contains('失败：'));
      }
      expect(loader.loadedSkills, hasLength(24));
    },
  );

  test(
    'catalog with no registered dependencies cannot claim any task usable',
    () async {
      final loader = SharedSkillLoader(
        loadString: (asset) => File(asset).readAsString(),
        registeredTools: {},
      );
      final catalog = await loader.catalog();
      expect(
        catalog.every(
          (entry) =>
              entry.status == SkillStatus.missingDependencies &&
              entry.missingTools.isNotEmpty,
        ),
        true,
      );
      expect(loader.loadedSkills, isEmpty);
    },
  );

  test(
    'catalog and search read only the manifest, load is cached per run',
    () async {
      final fixture = _Fixture();
      final loader = fixture.loader();
      await loader.catalog();
      final found = await loader.search(userRequest: '请查看安排');
      expect(found.single.skill.id, 'read-agenda');
      expect(fixture.reads, [SharedSkillLoader.manifestAsset]);
      final first = await loader.load('read-agenda');
      final second = await loader.load('read-agenda');
      expect(first.status, SkillStatus.loaded);
      expect(identical(first, second), true);
      expect(fixture.reads, [
        SharedSkillLoader.manifestAsset,
        '${SharedSkillLoader.assetRoot}read-agenda/SKILL.md',
      ]);
      expect(loader.loadedBytes, utf8.encode(first.body!).length);
      expect(first.toRecord(), {
        'id': 'read-agenda',
        'status': 'loaded',
        'version': '1.0.0',
        'contentSha256': first.skill!.contentSha256,
      });
      expect(first.toRecord().containsKey('body'), false);
    },
  );

  test('missing required tool is explicit and body is not loaded', () async {
    final fixture = _Fixture();
    final loader = fixture.loader(tools: {});
    final result = await loader.load('read-agenda');
    expect(result.status, SkillStatus.missingDependencies);
    expect(result.missingTools, ['agenda.query']);
    expect(result.body, null);
    expect(fixture.reads, [SharedSkillLoader.manifestAsset]);
    expect(loader.loadedBytes, 0);
  });

  test('optional tools never make a skill unavailable', () async {
    final fixture = _Fixture();
    fixture.entry()['optionalTools'] = ['navigation.open'];
    expect(
      (await fixture.loader().load('read-agenda')).status,
      SkillStatus.loaded,
    );
  });

  test('dependency set is frozen at run start', () async {
    final tools = <String>{};
    final loader = _Fixture().loader(tools: tools);
    tools.add('agenda.query');
    expect(
      (await loader.load('read-agenda')).status,
      SkillStatus.missingDependencies,
    );
  });

  test('unknown IDs and arbitrary paths never reach asset loader', () async {
    final fixture = _Fixture();
    final loader = fixture.loader();
    for (final id in [
      'missing',
      '../secret',
      'https://example.test/SKILL.md',
      'read-agenda/SKILL.md',
    ]) {
      expect((await loader.load(id)).status, SkillStatus.notFound);
    }
    expect(fixture.reads, [SharedSkillLoader.manifestAsset]);
  });

  test(
    'search matches user goal or trusted ID and respects source kinds',
    () async {
      final fixture = _Fixture();
      fixture.entry()['sourceKinds'] = ['reviewed_school_web'];
      final loader = fixture.loader();
      expect(await loader.search(userRequest: '不相关的问候'), isEmpty);
      expect(await loader.search(userRequest: ''), isEmpty);
      expect(
        await loader.search(
          userRequest: 'read-agenda',
          sourceKinds: {'pasted_text'},
        ),
        isEmpty,
      );
      expect(
        (await loader.search(
          userRequest: 'read-agenda',
          sourceKinds: {'reviewed_school_web'},
        )).single.skill.id,
        'read-agenda',
      );
      expect(
        await loader.search(userRequest: 'read-agenda', limit: 0),
        isEmpty,
      );
      expect(fixture.reads, [SharedSkillLoader.manifestAsset]);
    },
  );

  test('old skill version or hash cannot continue a run', () async {
    final fixture = _Fixture();
    final loader = fixture.loader();
    expect(
      (await loader.load('read-agenda', expectedVersion: '0.9.0')).status,
      SkillStatus.incompatible,
    );
    expect(
      (await loader.load('read-agenda', expectedSha256: 'old-hash')).status,
      SkillStatus.incompatible,
    );
    expect(fixture.reads, [SharedSkillLoader.manifestAsset]);
    final result = await loader.load(
      'read-agenda',
      expectedVersion: '1.0.0',
      expectedSha256: fixture.entry()['contentSha256'] as String,
    );
    expect(result.status, SkillStatus.loaded);
  });

  test('runtime and tool contract compatibility has inclusive lower and exclusive upper bounds', () async {
    final fixture = _Fixture();
    expect(
      (await fixture.loader(runtimeVersion: 2).load('read-agenda')).status,
      SkillStatus.incompatible,
    );
    expect(
      (await fixture.loader(toolVersion: '0.9.9').load('read-agenda')).status,
      SkillStatus.incompatible,
    );
    expect(
      (await fixture.loader(toolVersion: '2.0.0').load('read-agenda')).status,
      SkillStatus.incompatible,
    );
    expect(
      (await fixture.loader(toolVersion: '1.9.99').load('read-agenda')).status,
      SkillStatus.loaded,
    );
  });

  for (final path in [
    '../read-agenda/SKILL.md',
    '/read-agenda/SKILL.md',
    'https://example.test/SKILL.md',
    r'read-agenda\SKILL.md',
    'read-agenda/%2e%2e/SKILL.md',
  ]) {
    test('manifest rejects invalid asset path $path', () async {
      final fixture = _Fixture();
      fixture.entry()['asset'] = path;
      await expectLater(
        fixture.loader().catalog(),
        throwsA(_packError(SkillPackError.invalidManifest)),
      );
      expect(fixture.reads, [SharedSkillLoader.manifestAsset]);
    });
  }

  for (final change in <String, void Function(_Fixture)>{
    'duplicate IDs': (f) => (f.manifest['skills'] as List).add(
      Map<String, Object?>.from(f.entry()),
    ),
    'wildcard dependencies': (f) => f.entry()['requiredTools'] = ['agenda.*'],
    'slash dependencies': (f) => f.entry()['requiredTools'] = ['agenda/query'],
    'duplicate dependencies': (f) =>
        f.entry()['optionalTools'] = ['agenda.query'],
    'invalid ID': (f) => f.entry()['id'] = '../read-agenda',
    'invalid digest': (f) => f.entry()['contentSha256'] = 'not-a-digest',
    'invalid content version': (f) => f.entry()['version'] = '1.0',
    'invalid pack version': (f) => f.manifest['packVersion'] = '01.0.0',
    'invalid runtime version': (f) => f.manifest['runtimeContractVersion'] = 0,
    'unknown schema': (f) => f.manifest['schemaVersion'] = 2,
    'unsupported version range': (f) =>
        f.manifest['toolApiCompatibility'] = '*',
    'empty version range': (f) =>
        f.manifest['toolApiCompatibility'] = '>=2.0.0 <1.0.0',
  }.entries) {
    test('manifest rejects ${change.key}', () async {
      final fixture = _Fixture();
      change.value(fixture);
      await expectLater(
        fixture.loader().catalog(),
        throwsA(_packError(SkillPackError.invalidManifest)),
      );
    });
  }

  test(
    'body hash mismatch and missing asset produce no loaded record',
    () async {
      final fixture = _Fixture();
      fixture.bodies['read-agenda'] =
          '${fixture.bodies['read-agenda']}tampered';
      final loader = fixture.loader();
      expect(
        (await loader.load('read-agenda')).status,
        SkillStatus.invalidAsset,
      );
      expect(loader.loadedSkills, isEmpty);
      expect(loader.loadedBytes, 0);
      fixture.bodies.clear();
      expect(
        (await fixture.loader().load('read-agenda')).status,
        SkillStatus.invalidAsset,
      );
    },
  );

  test(
    'frontmatter and required structure are checked even with matching digest',
    () async {
      final fixture = _Fixture();
      fixture.setBody(
        'read-agenda',
        fixture.bodies['read-agenda']!.replaceFirst(
          'version: 1.0.0',
          'version: 9.0.0',
        ),
      );
      expect(
        (await fixture.loader().load('read-agenda')).status,
        SkillStatus.invalidAsset,
      );
      fixture.setBody(
        'read-agenda',
        _body('read-agenda').replaceFirst('## 失败处理', '## 无失败处理'),
      );
      expect(
        (await fixture.loader().load('read-agenda')).status,
        SkillStatus.invalidAsset,
      );
    },
  );

  test('manifest byte budget includes multibyte text', () async {
    final fixture = _Fixture();
    await expectLater(
      fixture
          .loader(budgets: const SkillBudgets(maxManifestBytes: 10))
          .catalog(),
      throwsA(_packError(SkillPackError.manifestBudgetExceeded)),
    );
  });

  test('per-body and total byte budgets reject before caching', () async {
    final fixture = _Fixture();
    final length = utf8.encode(fixture.bodies['read-agenda']!).length;
    expect(
      (await fixture
              .loader(budgets: SkillBudgets(maxSkillBytes: length - 1))
              .load('read-agenda'))
          .status,
      SkillStatus.budgetExceeded,
    );
    final loader = fixture.loader(
      budgets: SkillBudgets(maxLoadedBytes: length),
    );
    expect((await loader.load('read-agenda')).status, SkillStatus.loaded);
    expect((await loader.load('read-agenda')).status, SkillStatus.loaded);
    expect(
      (await loader.load('edit-events')).status,
      SkillStatus.budgetExceeded,
    );
    expect(loader.loadedBytes, length);
    expect(loader.loadedSkills, hasLength(1));
  });

  test('concurrent loads cannot oversubscribe count budget', () async {
    final fixture = _Fixture();
    final loader = fixture.loader(
      budgets: const SkillBudgets(maxLoadedSkills: 1),
    );
    final results = await Future.wait([
      loader.load('read-agenda'),
      loader.load('edit-events'),
      loader.load('read-agenda'),
    ]);
    expect(results.map((result) => result.status), [
      SkillStatus.loaded,
      SkillStatus.budgetExceeded,
      SkillStatus.loaded,
    ]);
    expect(
      fixture.reads.where((path) => path.endsWith('read-agenda/SKILL.md')),
      hasLength(1),
    );
    expect(
      fixture.reads.where((path) => path.endsWith('edit-events/SKILL.md')),
      isEmpty,
    );
  });

  test('asset loading exceptions are sanitized', () async {
    final loader = SharedSkillLoader(
      loadString: (_) async => throw StateError('private path and credential'),
      registeredTools: {},
    );
    await expectLater(
      loader.catalog(),
      throwsA(
        _packError(SkillPackError.unavailable).having(
          (error) => error.toString(),
          'safe diagnostic',
          isNot(contains('private')),
        ),
      ),
    );
  });
}

TypeMatcher<SkillPackException> _packError(SkillPackError code) =>
    isA<SkillPackException>().having((error) => error.code, 'code', code);

class _Fixture {
  _Fixture() {
    for (final id in ['read-agenda', 'edit-events']) {
      final body = _body(id);
      bodies[id] = body;
      (manifest['skills'] as List).add({
        'id': id,
        'version': '1.0.0',
        'title': '测试技能',
        'summary': '读取明确范围的安排。',
        'asset': '$id/SKILL.md',
        'contentSha256': sha256.convert(utf8.encode(body)).toString(),
        'triggers': id == 'read-agenda' ? ['查看安排'] : ['编辑日程'],
        'sourceKinds': <String>[],
        'requiredTools': ['agenda.query'],
        'optionalTools': <String>[],
      });
    }
  }
  final Map<String, Object?> manifest = {
    'schemaVersion': 1,
    'packVersion': '1.0.0',
    'runtimeContractVersion': 1,
    'toolApiCompatibility': '>=1.0.0 <2.0.0',
    'skills': <Map<String, Object?>>[],
  };
  final bodies = <String, String>{};
  final reads = <String>[];

  Map<String, Object?> entry([String id = 'read-agenda']) =>
      (manifest['skills'] as List).cast<Map<String, Object?>>().singleWhere(
        (entry) => entry['id'] == id,
      );

  void setBody(String id, String body) {
    bodies[id] = body;
    entry(id)['contentSha256'] = sha256.convert(utf8.encode(body)).toString();
  }

  SharedSkillLoader loader({
    Set<String>? tools,
    int runtimeVersion = 1,
    String toolVersion = '1.0.0',
    SkillBudgets budgets = const SkillBudgets(),
  }) => SharedSkillLoader(
    loadString: (asset) async {
      reads.add(asset);
      if (asset == SharedSkillLoader.manifestAsset) return jsonEncode(manifest);
      for (final entry in bodies.entries) {
        if (asset == '${SharedSkillLoader.assetRoot}${entry.key}/SKILL.md') {
          return entry.value;
        }
      }
      throw StateError('missing synthetic asset');
    },
    registeredTools: tools ?? {'agenda.query'},
    runtimeContractVersion: runtimeVersion,
    toolApiVersion: toolVersion,
    budgets: budgets,
  );
}

String _body(String id) =>
    '''---
id: $id
version: 1.0.0
summary: 读取明确范围的安排。
---

${['适用任务', '何时不使用', '输入', '依赖工具', '操作步骤', '业务注意事项', '完成条件', '失败处理'].map((heading) => '## $heading\n\n合成技能内容。\n').join('\n')}
''';
