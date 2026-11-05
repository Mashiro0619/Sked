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

  Finder key(String value) => find.byKey(ValueKey(value));
  TextEditingController body(WidgetTester tester) =>
      tester.widget<TextFormField>(key('knowledge-body')).controller!;
  Future<void> tap(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> open(
    WidgetTester tester,
    KnowledgeRecord record, {
    Size size = const Size(460, 1000),
    double scale = 1,
  }) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await mountAgentUi(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => AgentKnowledgeEditor(
                service: service,
                kind: record.kind,
                record: record,
                pagePresentation: true,
              ),
            ),
          ),
          child: const Text('Open editor'),
        ),
      ),
      size: size,
      scale: scale,
    );
    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    addTearDown(tester.view.reset);
  }

  testWidgets(
    'switching built-in content and full source preserves exact text without dirtying the editor',
    (tester) async {
      await initialize();
      final record = await service.read(KnowledgeKind.skill, 'read-agenda');
      await open(tester, record);
      final content = body(tester).text;
      expect(content, startsWith('## 适用任务'));
      expect(content, isNot(contains('id: read-agenda')));
      expect(content, isNot(contains('# ${record.title}\n')));
      expect(record.body, endsWith(content));
      await tap(tester, key('knowledge-source-toggle'));
      expect(body(tester).text, record.body);
      expect(body(tester).selection, const TextSelection.collapsed(offset: 0));
      await tap(tester, key('knowledge-source-toggle'));
      expect(body(tester).text, content);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(AgentKnowledgeEditor), findsNothing);
      expect(repository.records, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'changing only enablement retains the original source and provenance',
    (tester) async {
      await initialize();
      final record = await service.read(KnowledgeKind.skill, 'read-agenda');
      await open(tester, record);
      await tap(tester, find.byType(SwitchListTile));
      await tap(tester, key('knowledge-save'));
      final saved = await service.read(KnowledgeKind.skill, record.id);
      expect(saved.enabled, isFalse);
      expect(saved.usesOriginal, isTrue);
      expect(saved.body, record.body);
      expect(saved.title, record.title);
      expect(saved.summary, record.summary);
      expect(tester.takeException(), isNull);
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'full source starts at its first visible line after page scrolling at ${scale}x',
      (tester) async {
        await initialize();
        final record = await service.read(KnowledgeKind.skill, 'read-agenda');
        await open(tester, record, size: const Size(390, 844), scale: scale);
        await tap(tester, key('knowledge-source-toggle'));
        final outer = find
            .descendant(
              of: find.byKey(
                const PageStorageKey('agent-knowledge-editor-scroll'),
              ),
              matching: find.byType(Scrollable),
            )
            .first;
        expect(
          tester.state<ScrollableState>(outer).position.pixels,
          greaterThan(0),
        );
        final editable = tester.state<EditableTextState>(
          find.descendant(
            of: key('knowledge-body'),
            matching: find.byType(EditableText),
          ),
        );
        expect(editable.renderEditable.offset.pixels, 0);
        final firstLine = editable.renderEditable.getLocalRectForCaret(
          const TextPosition(offset: 0),
        );
        expect(firstLine.top, greaterThanOrEqualTo(0));
        expect(
          firstLine.bottom,
          lessThanOrEqualTo(editable.renderEditable.size.height),
        );
        expect(body(tester).text, record.body);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'empty projected instructions and the same full source use identical save validation',
    (tester) async {
      await initialize();
      final original = await service.read(KnowledgeKind.skill, 'read-agenda');
      final prefix = original.body.substring(
        0,
        original.body.indexOf('## 适用任务'),
      );
      await open(tester, original);
      await tester.enterText(key('knowledge-body'), '');
      await tap(tester, key('knowledge-save'));
      expect(find.byType(AgentKnowledgeEditor), findsNothing);
      final saved = await service.read(KnowledgeKind.skill, original.id);
      expect(saved.body, prefix);
      await open(tester, saved);
      expect(body(tester).text, isEmpty);
      await tap(tester, key('knowledge-source-toggle'));
      expect(body(tester).text, prefix);
      await tap(tester, key('knowledge-save'));
      expect(find.byType(AgentKnowledgeEditor), findsNothing);
      expect(
        (await service.read(KnowledgeKind.skill, original.id)).body,
        prefix,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'editing projected instructions preserves CRLF preamble and exact new body whitespace',
    (tester) async {
      await initialize();
      final original = await service.read(KnowledgeKind.skill, 'read-agenda');
      await service.saveFromUi(
        service.prepareSave(
          original.copyWith(
            body: original.body
                .replaceAll('\r\n', '\n')
                .replaceAll('\n', '\r\n'),
            usesOriginal: false,
          ),
        ),
      );
      final record = await service.read(KnowledgeKind.skill, original.id);
      await open(tester, record);
      final prefix = record.body.substring(
        0,
        record.body.length - body(tester).text.length,
      );
      expect(prefix, startsWith('---\r\n'));
      const edited = '## My instructions\r\n\r\nKeep two spaces.  \r\n';
      await tester.enterText(key('knowledge-body'), edited);
      await tap(tester, key('knowledge-source-toggle'));
      expect(body(tester).text, prefix + edited);
      await tap(tester, key('knowledge-source-toggle'));
      expect(body(tester).text, edited);
      await tap(tester, key('knowledge-save'));
      final saved = await service.read(KnowledgeKind.skill, record.id);
      expect(saved.body, prefix + edited);
      expect(saved.usesOriginal, isFalse);
      expect(saved.title, record.title);
      expect(saved.summary, record.summary);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'full source edits with unrecognized metadata remain visible and save verbatim',
    (tester) async {
      await initialize();
      final record = await service.read(KnowledgeKind.skill, 'read-agenda');
      await open(tester, record);
      await tap(tester, key('knowledge-source-toggle'));
      final edited =
          '${record.body.replaceFirst('id: read-agenda', 'id: user-authored-metadata\nextra: keep this')}\n  trailing source  ';
      await tester.enterText(key('knowledge-body'), edited);
      await tap(tester, key('knowledge-source-toggle'));
      expect(body(tester).text, edited);
      await tap(tester, key('knowledge-save'));
      final saved = await service.read(KnowledgeKind.skill, record.id);
      expect(saved.body, edited);
      expect(saved.id, record.id);
      expect(saved.usesOriginal, isFalse);
      await open(tester, saved);
      expect(body(tester).text, edited);
      expect(key('knowledge-source-toggle'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('changing title and summary does not rewrite source metadata', (
    tester,
  ) async {
    await initialize();
    final record = await service.read(KnowledgeKind.skill, 'read-agenda');
    await open(tester, record);
    await tester.enterText(key('knowledge-title'), 'New title');
    await tester.enterText(key('knowledge-summary'), 'New summary');
    await tap(tester, key('knowledge-save'));
    final saved = await service.read(KnowledgeKind.skill, record.id);
    expect(saved.title, 'New title');
    expect(saved.summary, 'New summary');
    expect(saved.body, record.body);
    expect(saved.usesOriginal, isFalse);
  });

  testWidgets('custom frontmatter is never hidden or normalized', (
    tester,
  ) async {
    await initialize();
    const source =
        '---\r\nid: custom-authored\r\nsummary: Keep me\r\n---\r\n\r\n# User title\r\n  Preserve spacing  \r\n';
    final record = service.newRecord(
      KnowledgeKind.skill,
      title: 'Custom',
      body: source,
    );
    await service.saveFromUi(service.prepareSave(record));
    await open(tester, await service.read(KnowledgeKind.skill, record.id));
    expect(body(tester).text, source);
    expect(key('knowledge-source-toggle'), findsNothing);
    await tap(tester, key('knowledge-save'));
    expect((await service.read(KnowledgeKind.skill, record.id)).body, source);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'restore original keeps enablement and restores the full bundled source',
    (tester) async {
      await initialize();
      final original = await service.read(KnowledgeKind.skill, 'read-agenda');
      await service.saveFromUi(
        service.prepareSave(
          original.copyWith(
            body: 'Local override',
            usesOriginal: false,
            enabled: false,
          ),
        ),
      );
      await open(tester, await service.read(KnowledgeKind.skill, original.id));
      await tap(tester, key('knowledge-restore-original'));
      final restored = await service.read(KnowledgeKind.skill, original.id);
      expect(restored.body, original.body);
      expect(restored.usesOriginal, isTrue);
      expect(restored.enabled, isFalse);
      await open(tester, restored);
      expect(body(tester).text, startsWith('## 适用任务'));
      await tap(tester, key('knowledge-source-toggle'));
      expect(body(tester).text, original.body);
      expect(tester.takeException(), isNull);
    },
  );
}
