import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/skills/shared_skill_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Flutter asset bundle contains all versioned shared Skill bodies',
    () async {
      final manifest = jsonDecode(
        await rootBundle.loadString(SharedSkillLoader.manifestAsset),
      ) as Map;
      final descriptors = manifest['skills'] as List;
      final tools = <String>{
        for (final item in descriptors)
          ...List<String>.from(item['requiredTools'] as List),
      };
      final loader = SharedSkillLoader(
        loadString: rootBundle.loadString,
        registeredTools: tools,
        budgets: const SkillBudgets(
          maxLoadedSkills: 24,
          maxLoadedBytes: 256 * 1024,
        ),
      );
      final catalog = await loader.catalog();
      expect(catalog, hasLength(24));
      for (final entry in catalog) {
        final result = await loader.load(entry.skill.id);
        expect(result.status, SkillStatus.loaded, reason: entry.skill.id);
        expect(result.body, isNotEmpty);
      }
    },
  );
}
