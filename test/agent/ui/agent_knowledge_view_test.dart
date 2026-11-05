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

  Future<void> chooseFilter(
    WidgetTester tester,
    String key,
    String label,
  ) async {
    final field = find.byKey(ValueKey(key));
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, label));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'memory rows show a bounded body excerpt without changing the saved text',
    (tester) async {
      await initialize();
      final body = 'Prefer mornings.\n${'👩‍💻' * 180} private-tail';
      final memory = service.newRecord(
        KnowledgeKind.memory,
        title: 'Study',
        body: body,
      );
      await service.saveFromUi(service.prepareSave(memory));
      await mountAgentUi(
        tester,
        AgentKnowledgeView(service: service, kind: KnowledgeKind.memory),
        size: const Size(390, 844),
      );
      final preview = tester.widget<Text>(
        find.byKey(ValueKey('knowledge-preview-${memory.key}')),
      );
      expect(preview.maxLines, 2);
      expect(preview.data!.startsWith('Prefer mornings. '), isTrue);
      expect(preview.data!.characters.length, 161);
      expect(preview.data, endsWith('…'));
      expect(preview.data, isNot(contains('private-tail')));
      expect(repository.records.single.body, body);
      await tester.tap(find.byKey(ValueKey('knowledge-item-${memory.key}')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('knowledge-body')))
            .controller!
            .text,
        body,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'skill filters distinguish original, customized, disabled and missing-tool records',
    (tester) async {
      await initialize();
      final original = await service.read(KnowledgeKind.skill, 'read-agenda');
      await service.saveFromUi(
        service.prepareSave(
          original.copyWith(
            body: '${original.body}\nCustom instruction.',
            usesOriginal: false,
          ),
        ),
      );
      final enabled = service.newRecord(
        KnowledgeKind.skill,
        title: 'Custom active',
        body: 'Help plan a day.',
      );
      final disabled = service
          .newRecord(
            KnowledgeKind.skill,
            title: 'Custom paused',
            body: 'Optional planning.',
          )
          .copyWith(enabled: false);
      final missing = service
          .newRecord(
            KnowledgeKind.skill,
            title: 'Custom missing tool',
            body: 'Requires an unavailable tool.',
          )
          .copyWith(requiredTools: ['resources.unavailable']);
      for (final record in [enabled, disabled, missing]) {
        await service.saveFromUi(service.prepareSave(record));
      }
      await mountAgentUi(
        tester,
        AgentKnowledgeView(service: service, kind: KnowledgeKind.skill),
        size: const Size(460, 1000),
      );
      Finder item(KnowledgeRecord record) =>
          find.byKey(ValueKey('knowledge-item-${record.key}'));
      await chooseFilter(tester, 'knowledge-origin', 'Custom');
      expect(item(enabled), findsOneWidget);
      expect(item(disabled), findsOneWidget);
      expect(item(missing), findsOneWidget);
      expect(item(original), findsNothing);
      await chooseFilter(tester, 'knowledge-state-skill', 'Disabled');
      expect(item(disabled), findsOneWidget);
      expect(item(enabled), findsNothing);
      expect(item(missing), findsNothing);
      await chooseFilter(
        tester,
        'knowledge-state-skill',
        'Required tools unavailable',
      );
      expect(item(missing), findsOneWidget);
      expect(item(disabled), findsNothing);
      expect(
        tester
            .widget<Text>(
              find.byKey(ValueKey('knowledge-status-${missing.key}')),
            )
            .data,
        contains('Enabled'),
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(ValueKey('knowledge-status-${missing.key}')),
            )
            .data,
        contains('Required tools unavailable'),
      );
      await chooseFilter(tester, 'knowledge-state-skill', 'Enabled');
      await chooseFilter(tester, 'knowledge-origin', 'Customized built-in');
      expect(item(original), findsOneWidget);
      expect(item(enabled), findsNothing);
      await chooseFilter(tester, 'knowledge-origin', 'Built-in');
      expect(item(original), findsNothing);
      expect(
        find.byKey(const ValueKey('knowledge-item-skill:locate-and-navigate')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'search and filters survive opening an editor and show a distinct empty result',
    (tester) async {
      await initialize();
      final memory = service
          .newRecord(KnowledgeKind.memory, title: 'Study', body: 'Morning')
          .copyWith(enabled: false);
      await service.saveFromUi(service.prepareSave(memory));
      await mountAgentUi(
        tester,
        AgentKnowledgeView(service: service, kind: KnowledgeKind.memory),
      );
      final search = find.byKey(const ValueKey('knowledge-search-memory'));
      await tester.enterText(search, 'Study');
      await chooseFilter(tester, 'knowledge-state-memory', 'Disabled');
      await tester.tap(find.byKey(ValueKey('knowledge-item-${memory.key}')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(search).controller!.text, 'Study');
      expect(
        find.byKey(ValueKey('knowledge-item-${memory.key}')),
        findsOneWidget,
      );
      await chooseFilter(tester, 'knowledge-state-memory', 'Enabled');
      expect(find.text('No matching items'), findsOneWidget);
      expect(find.text('Nothing saved yet'), findsNothing);
      await tester.enterText(search, '');
      await chooseFilter(tester, 'knowledge-state-memory', 'All states');
      expect(
        find.byKey(ValueKey('knowledge-item-${memory.key}')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

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
