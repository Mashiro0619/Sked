@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/conversations/conversation_storage_io.dart'
    as conversations;
import 'package:sked/agent/knowledge/knowledge_repository.dart';
import 'package:sked/agent/knowledge/knowledge_storage_io.dart' as knowledge;
import 'package:sked/backup/selective_backup_models.dart';
import 'package:sked/backup/selective_restore_coordinator.dart';
import 'package:sked/backup/selective_restore_journal.dart';
import 'package:sked/backup/selective_restore_journal_io.dart' as journals;
import 'package:sked/services/app_storage_layout_io.dart';

enum _VersionLayer { envelope, payload }

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final layer in _VersionLayer.values) {
    test(
      'native conversation ${layer.name} from a newer app blocks writes and restore without replacing either slot',
      () async {
        final fixture = await _NativeSidecar.create('conversations');
        final saved = await _seedConversation(fixture);
        await fixture.raiseVersion(layer);
        final preserved = await fixture.readSlots();
        final reopened = ConversationRepository(
          storage: conversations.PlatformConversationStorage(
            layout: fixture.layout,
          ),
        );
        addTearDown(() async {
          await reopened.waitForPendingWrites();
          reopened.dispose();
        });

        await expectLater(
          reopened.load(),
          throwsA(isA<ConversationStorageException>()),
        );
        expect(reopened.blocked, isTrue);
        expect(reopened.canWrite, isFalse);
        await expectLater(
          reopened.create(title: 'Must not replace the newer chat'),
          throwsA(isA<ConversationStorageException>()),
        );
        expect(await fixture.readSlots(), preserved);

        reopened.freeze();
        await expectLater(
          reopened.readFrozenForRestore(validateOwner: () {}),
          throwsA(isA<ConversationStorageException>()),
        );
        await expectLater(
          reopened.replaceFrozenForRestore(saved, validateOwner: () {}),
          throwsStateError,
        );
        reopened.resumeAfterMaintenance();
        expect(reopened.blocked, isTrue);
        expect(reopened.canWrite, isFalse);
        expect(await fixture.readSlots(), preserved);
      },
    );

    test(
      'native knowledge ${layer.name} from a newer app blocks prepared writes and restore without replacing either slot',
      () async {
        final fixture = await _NativeSidecar.create('knowledge');
        final seed = await _seedKnowledge(fixture);
        await fixture.raiseVersion(layer);
        final preserved = await fixture.readSlots();
        final reopened = AgentKnowledgeRepository(
          storage: knowledge.PlatformKnowledgeStorage(layout: fixture.layout),
        );
        addTearDown(() async {
          await reopened.waitForPendingWrites();
          reopened.dispose();
        });
        final unavailable = throwsA(
          isA<KnowledgeException>().having(
            (error) => error.code,
            'code',
            KnowledgeError.unavailable,
          ),
        );

        await expectLater(reopened.load(), unavailable);
        expect(reopened.blocked, isTrue);
        expect(reopened.canWrite, isFalse);
        expect(
          () => reopened.prepare({'memory:retained': _memory('Replacement')}),
          unavailable,
        );
        await expectLater(
          reopened.commit(seed.pending, operationId: 'must-not-commit'),
          unavailable,
        );
        expect(await fixture.readSlots(), preserved);

        reopened.freeze();
        await expectLater(
          reopened.readFrozenForRestore(validateOwner: () {}),
          unavailable,
        );
        await expectLater(
          reopened.replaceFrozenForRestore(seed.archive, validateOwner: () {}),
          unavailable,
        );
        reopened.resumeAfterMaintenance();
        expect(reopened.blocked, isTrue);
        expect(reopened.canWrite, isFalse);
        expect(await fixture.readSlots(), preserved);
      },
    );

    test(
      'native restore journal ${layer.name} from a newer app blocks progress and clear without replacing either slot',
      () async {
        final fixture = await _NativeSidecar.create('selective_restore');
        final writer = PersistentSelectiveRestoreJournal(
          storage: journals.PlatformSelectiveJournalStorage(
            layout: fixture.layout,
          ),
        );
        final state = _restoreState();
        await writer.write(state);
        await writer.write(state.markStarted());
        final saved = (await writer.read())!;
        expect(saved.restoreId, state.restoreId);
        expect(saved.started, isTrue);
        expect(saved.targets.single.toJson(), state.targets.single.toJson());
        await fixture.raiseVersion(
          layer,
          payloadField: 'payload',
          digestField: 'digest',
        );
        final preserved = await fixture.readSlots();
        final reopened = PersistentSelectiveRestoreJournal(
          storage: journals.PlatformSelectiveJournalStorage(
            layout: fixture.layout,
          ),
        );
        final unsupported = throwsA(
          isA<SelectiveBackupException>().having(
            (error) => error.code,
            'code',
            SelectiveBackupError.unsupportedVersion,
          ),
        );

        await expectLater(reopened.read(), unsupported);
        await expectLater(reopened.write(saved.markApplied()), unsupported);
        expect(await fixture.readSlots(), preserved);
        await expectLater(reopened.clear(), unsupported);
        expect(await fixture.readSlots(), preserved);
      },
    );
  }
}

Future<ConversationArchive> _seedConversation(_NativeSidecar fixture) async {
  final storage = conversations.PlatformConversationStorage(
    layout: fixture.layout,
  );
  final writer = ConversationRepository(
    storage: storage,
    clock: () => DateTime.utc(2026, 11, 3),
  );
  try {
    await writer.load();
    final chat = await writer.create(title: 'Retained synthetic conversation');
    await writer.update(
      chat.id,
      (current) => current.copyWith(draft: 'Keep this unsent question.'),
    );
    final archive = ConversationArchive.decode((await storage.load()).source!);
    expect(archive.conversations.single.id, chat.id);
    expect(archive.conversations.single.draft, 'Keep this unsent question.');
    return archive;
  } finally {
    await writer.waitForPendingWrites();
    writer.dispose();
  }
}

Future<({KnowledgeArchive archive, KnowledgeChangeSet pending})> _seedKnowledge(
  _NativeSidecar fixture,
) async {
  final storage = knowledge.PlatformKnowledgeStorage(layout: fixture.layout);
  final writer = AgentKnowledgeRepository(storage: storage);
  try {
    await writer.load();
    await writer.commit(
      writer.prepare({
        'memory:retained': _memory('Keep the saved preference.'),
      }),
      operationId: 'seed-memory',
    );
    final archive = (await storage.load()).archive;
    expect(archive.records.single.body, 'Keep the saved preference.');
    expect(archive.receipts.single.operationId, 'seed-memory');
    final pending = writer.prepare({
      'memory:retained': _memory('Must not overwrite the newer archive.'),
    });
    return (archive: archive, pending: pending);
  } finally {
    await writer.waitForPendingWrites();
    writer.dispose();
  }
}

KnowledgeRecord _memory(String body) => KnowledgeRecord(
  kind: KnowledgeKind.memory,
  id: 'retained',
  title: 'Synthetic study preference',
  body: body,
);

SelectiveRestoreState _restoreState() => SelectiveRestoreState(
  restoreId: 'retained-restore',
  planFingerprint: backupDigest(utf8.encode('fixed synthetic restore')),
  targets: [
    BackupPreparedTarget(
      owner: BackupOwner.conversations,
      restoreId: 'retained-restore',
      descriptor: const {'target': 'fixed synthetic conversation snapshot'},
    ),
  ],
);

/// Only the current writer creates envelopes. Change one recognized version,
/// updating its derived digest for an inner payload, and leave a valid sibling.
class _NativeSidecar {
  _NativeSidecar(this.directory, this.stem);
  final Directory directory;
  final String stem;

  static Future<_NativeSidecar> create(String owner) async {
    final directory = await Directory.systemTemp.createTemp(
      'sked-future-$owner-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final stem = owner == 'selective_restore'
        ? 'Sked_selective_restore'
        : 'Sked_agent_$owner';
    return _NativeSidecar(directory, stem);
  }

  AppStorageLayout get layout =>
      AppStorageLayout(directoryProvider: () async => directory);
  File slot(int index) => File('${directory.path}/$stem.$index.json');

  Future<List<List<int>>> readSlots() async => [
    for (var index = 0; index < 2; index++) await slot(index).readAsBytes(),
  ];

  Future<void> raiseVersion(
    _VersionLayer layer, {
    String payloadField = 'source',
    String digestField = 'checksum',
  }) async {
    final before = await readSlots();
    expect(
      before[0],
      before[1],
      reason: 'The real writer must mirror both slots.',
    );
    final envelope = jsonDecode(utf8.decode(before[0])) as Map<String, dynamic>;
    if (layer == _VersionLayer.envelope) {
      envelope['version'] = (envelope['version'] as int) + 1;
    } else {
      final payload =
          jsonDecode(envelope[payloadField] as String) as Map<String, dynamic>;
      payload['version'] = (payload['version'] as int) + 1;
      final source = jsonEncode(payload);
      envelope[payloadField] = source;
      envelope[digestField] = sha256.convert(utf8.encode(source)).toString();
    }
    await slot(0).writeAsString(jsonEncode(envelope), flush: true);
    expect(await slot(1).readAsBytes(), before[1]);
  }
}
