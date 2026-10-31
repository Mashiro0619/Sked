import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/knowledge/knowledge_service.dart';
import 'package:sked/app_runtime.dart';

import '../../support/workspace_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Storage storage;
  late AppRuntime app;

  setUp(() async {
    storage = _Storage();
    app = await workspaceProvider(agentKnowledgeStorage: storage);
  });
  tearDown(() async {
    await app.agent.quiesce();
    app.dispose();
  });

  KnowledgeRecord memory(String title) => app.agent.knowledge.newRecord(
    KnowledgeKind.memory,
    title: title,
    body: 'Prefer quiet mornings.',
  );

  test(
    'default-on entry and connection initialization leave knowledge dormant',
    () async {
      expect(app.agent.settings.enabled, isTrue);
      expect(storage.loads, 0);
      await app.agent.initialize();
      expect(storage.loads, 0);
      await app.agent.setEnabled(false);
      await app.agent.knowledge.initialize();
      await app.agent.knowledge.saveFromUi(
        app.agent.knowledge.prepareSave(memory('Study')),
      );
      expect(storage.loads, 1);
      expect(app.agent.settings.enabled, isFalse);
      expect(app.agent.knowledgeRepository.records.single.title, 'Study');
    },
  );

  test(
    'maintenance drains an accepted save and rejects a queued user edit',
    () async {
      await app.agent.knowledge.initialize();
      final first = app.agent.knowledge.prepareSave(memory('Accepted'));
      final second = app.agent.knowledge.prepareSave(memory('Queued'));
      storage.gate = Completer<void>();
      final accepted = app.agent.knowledge.saveFromUi(first);
      await storage.started.future;
      final queued = expectLater(
        app.agent.knowledge.saveFromUi(second),
        throwsA(isA<KnowledgeException>()),
      );
      final token = app.maintenance.reserve();
      try {
        final draining = app.agent.quiesce();
        expect(app.agent.knowledge.ready, isFalse);
        storage.gate!.complete();
        await accepted;
        await queued;
        await draining;
        expect(app.agent.knowledgeRepository.canWrite, isFalse);
        expect(app.agent.knowledgeRepository.records.single.title, 'Accepted');
      } finally {
        app.maintenance.release(token);
      }
      expect(app.agent.knowledge.ready, isTrue);
    },
  );

  test('failed clear reloads actual remaining knowledge instead of reviving its memory snapshot', () async {
    await app.agent.knowledge.initialize();
    await app.agent.knowledge.saveFromUi(
      app.agent.knowledge.prepareSave(memory('Removed')),
    );
    await expectLater(
      app.dataClear.run(
        clear: () async {
          storage.source = null;
          throw StateError('Synthetic failure after side-store removal.');
        },
        exit: () async {},
      ),
      throwsStateError,
    );
    expect(app.agent.knowledgeRepository.blocked, isTrue);
    await expectLater(
      app.agent.knowledge.initialize(),
      throwsA(isA<KnowledgeException>()),
    );
    expect(storage.source, isNull);
    await app.agent.knowledge.initialize(reload: true);
    expect(app.agent.knowledgeRepository.records, isEmpty);
    expect(app.agent.knowledge.ready, isTrue);
  });

  test(
    'successful clear cannot recreate knowledge when the exit callback returns',
    () async {
      await app.agent.knowledge.initialize();
      await app.agent.knowledge.saveFromUi(
        app.agent.knowledge.prepareSave(memory('Removed')),
      );
      await app.dataClear.run(
        clear: () async => storage.source = null,
        exit: () async {},
      );
      expect(app.dataClear.isCommitted, isTrue);
      expect(app.agent.knowledgeRepository.canWrite, isFalse);
      expect(
        () => app.agent.knowledge.prepareSave(memory('Late')),
        throwsA(isA<KnowledgeException>()),
      );
      expect(storage.source, isNull);
    },
  );
}

class _Storage extends MemoryKnowledgeStorage {
  int loads = 0;
  final started = Completer<void>();
  Completer<void>? gate;

  @override
  Future<KnowledgeStorageLoad> load() async {
    loads++;
    return super.load();
  }

  @override
  Future<void> save(KnowledgeArchive archive) async {
    if (!started.isCompleted) started.complete();
    await gate?.future;
    await super.save(archive);
  }
}
