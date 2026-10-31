import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/knowledge/knowledge_service.dart';
import 'package:sked/agent/skills/shared_skill_loader.dart';

void main() {
  late AgentKnowledgeRepository repository;
  late AgentKnowledgeService service;
  setUp(() async {
    repository = AgentKnowledgeRepository(storage: MemoryKnowledgeStorage());
    service = AgentKnowledgeService(
      repository: repository,
      loadSkillAsset: (path) async => File(path).readAsStringSync(),
      readDataGeneration: () => 'current',
    );
    await service.initialize();
  });
  tearDown(() async {
    await repository.waitForPendingWrites();
    service.dispose();
    repository.dispose();
  });

  test('user and later runs share edited built-in text while an existing run remains frozen', () async {
    var original = await service.read(KnowledgeKind.skill, 'read-agenda');
    final tools = {...original.requiredTools, ...original.optionalTools};
    final oldRun = SharedSkillLoader(
      loadString: (path) async => File(path).readAsStringSync(),
      registeredTools: tools,
      overlays: service.captureSkillSnapshot(),
    );
    final edited = original.copyWith(
      body: 'Local shared guidance.',
      usesOriginal: false,
      title: 'Personal agenda',
    );
    await service.saveFromUi(service.prepareSave(edited));
    final newRun = SharedSkillLoader(
      loadString: (path) async => File(path).readAsStringSync(),
      registeredTools: tools,
      overlays: service.captureSkillSnapshot(),
    );
    expect((await oldRun.load('read-agenda')).body, original.body);
    expect((await newRun.load('read-agenda')).body, 'Local shared guidance.');
    original = await service.read(KnowledgeKind.skill, 'read-agenda');
    await service.saveFromUi(
      service.prepareSave(original.copyWith(enabled: false)),
    );
    final disabled = await service.read(KnowledgeKind.skill, 'read-agenda');
    await service.saveFromUi(service.prepareOriginal(disabled));
    final restored = await service.read(KnowledgeKind.skill, 'read-agenda');
    expect(restored.enabled, false);
    expect(restored.usesOriginal, true);
    final nextRun = SharedSkillLoader(
      loadString: (path) async => File(path).readAsStringSync(),
      registeredTools: tools,
      overlays: service.captureSkillSnapshot(),
    );
    expect((await nextRun.load('read-agenda')).status, SkillStatus.disabled);
  });

  test(
    'custom Skills are discoverable and dependency checks still apply',
    () async {
      final custom = service
          .newRecord(
            KnowledgeKind.skill,
            title: 'Evening study',
            body: 'Use registered scheduling tools.',
            summary: 'Quiet revision',
          )
          .copyWith(requiredTools: ['agenda.query']);
      await service.saveFromUi(service.prepareSave(custom));
      final loader = SharedSkillLoader(
        loadString: (path) async => File(path).readAsStringSync(),
        registeredTools: {},
        overlays: service.captureSkillSnapshot(),
      );
      final found = await loader.search(userRequest: 'Evening');
      expect(found.single.skill.id, custom.id);
      expect(
        (await loader.load(custom.id)).status,
        SkillStatus.missingDependencies,
      );
    },
  );

  test('restoring a selected built-in preserves exported effective text and does not replace the installed original', () async {
    final original = await service.read(KnowledgeKind.skill, 'read-agenda');
    final json = original.toJson()
      ..['baseSha256'] = List.filled(64, 'a').join()
      ..['body'] = 'Older installed guidance';
    final selected = KnowledgeRecord.fromJson(json);
    await service.saveFromUi(service.prepareRestore([selected]));
    final restored = await service.read(KnowledgeKind.skill, 'read-agenda');
    expect(restored.body, 'Older installed guidance');
    expect(restored.usesOriginal, false);
    await service.saveFromUi(service.prepareOriginal(restored));
    expect(
      (await service.read(KnowledgeKind.skill, 'read-agenda')).body,
      original.body,
    );
  });

  test('expired or old-generation memories remain inspectable but require fresh verification', () async {
    final memory = KnowledgeRecord(
      kind: KnowledgeKind.memory,
      id: 'old-reference',
      title: 'Course preference',
      body: 'Prefer the earlier section.',
      references: [
        KnowledgeReference(kind: 'course', id: 'course-1', generation: 'old'),
      ],
    );
    await service.saveFromUi(service.prepareSave(memory));
    final restored = await service.read(KnowledgeKind.memory, memory.id);
    expect(service.needsRecheck(restored), true);
    expect(service.list(KnowledgeKind.memory), hasLength(1));
    expect(restored.references.single.generation, 'old');
  });
}
