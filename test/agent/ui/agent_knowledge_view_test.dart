import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/knowledge/knowledge_service.dart';
import 'package:sked/agent/ui/agent_knowledge_view.dart';

import 'agent_ui_test_support.dart';

void main() {
  late AgentKnowledgeRepository repository;
  late AgentKnowledgeService service;
  Future<void> initialize() async {
    repository = AgentKnowledgeRepository(storage: MemoryKnowledgeStorage());
    service = AgentKnowledgeService(
      repository: repository,
      loadSkillAsset: (path) async => File(path).readAsStringSync(),
    );
    await service.initialize();
  }

  tearDown(() {
    service.dispose();
    repository.dispose();
  });

  testWidgets(
    'settings editor persists shared memory and exposes conditional undo',
    (tester) async {
      await initialize();
      await mountAgentUi(
        tester,
        AgentKnowledgeView(service: service, kind: KnowledgeKind.memory),
      );
      await tester.tap(find.byKey(const ValueKey('knowledge-add-memory')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('knowledge-title')),
        'Study preference',
      );
      await tester.enterText(
        find.byKey(const ValueKey('knowledge-body')),
        'Prefer quiet mornings.',
      );
      await tester.ensureVisible(find.byKey(const ValueKey('knowledge-save')));
      await tester.tap(find.byKey(const ValueKey('knowledge-save')));
      await tester.pumpAndSettle();
      expect(repository.records.single.body, 'Prefer quiet mornings.');
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(repository.records, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await repository.waitForPendingWrites();
    },
  );

  testWidgets(
    'concurrent change preserves editor draft and rejects a stale save',
    (tester) async {
      await initialize();
      await service.saveFromUi(
        service.prepareSave(
          service.newRecord(
            KnowledgeKind.memory,
            title: 'Study',
            body: 'Morning',
          ),
        ),
      );
      final current = repository.records.single;
      await mountAgentUi(
        tester,
        AgentKnowledgeView(service: service, kind: KnowledgeKind.memory),
      );
      await tester.tap(find.byKey(ValueKey('knowledge-item-${current.key}')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('knowledge-body')),
        'Editor draft',
      );
      await service.saveFromUi(
        service.prepareSave(current.copyWith(body: 'Concurrent update')),
      );
      await tester.tap(find.byKey(const ValueKey('knowledge-save')));
      await tester.pumpAndSettle();
      expect(repository.records.single.body, 'Concurrent update');
      expect(
        find.text('This item changed. Reopen it before saving.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('knowledge-body')))
            .controller!
            .text,
        'Editor draft',
      );
      await tester.pumpWidget(const SizedBox());
      await repository.waitForPendingWrites();
    },
  );

  testWidgets(
    'built-in editor has reset and independent enable state at large text',
    (tester) async {
      await initialize();
      final record = await service.read(KnowledgeKind.skill, 'read-agenda');
      await mountAgentUi(
        tester,
        AgentKnowledgeEditor(
          service: service,
          kind: KnowledgeKind.skill,
          record: record,
        ),
        size: const Size(460, 1000),
        scale: 2,
      );
      expect(
        find.byKey(const ValueKey('knowledge-restore-original')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('knowledge-delete')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'knowledge header and records remain reachable in a short large-text phone',
    (tester) async {
      await initialize();
      final memory = service.newRecord(
        KnowledgeKind.memory,
        title: 'Study',
        body: 'Mornings',
      );
      await service.saveFromUi(service.prepareSave(memory));
      await mountAgentUi(
        tester,
        AgentKnowledgeView(service: service, kind: KnowledgeKind.memory),
        size: const Size(320, 360),
        scale: 2,
      );
      expect(tester.takeException(), isNull);
      final item = find.byKey(ValueKey('knowledge-item-${memory.key}'));
      await tester.scrollUntilVisible(
        item,
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(item);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('knowledge-body')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
