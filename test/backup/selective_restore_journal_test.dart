import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sked/backup/selective_backup_models.dart';
import 'package:sked/backup/selective_restore_coordinator.dart';
import 'package:sked/backup/selective_restore_journal.dart';
import 'package:sked/backup/selective_restore_journal_io.dart' as native;
import 'package:sked/backup/selective_restore_journal_stub.dart' as web;
import 'package:sked/services/app_storage_layout_io.dart';

SelectiveRestoreState _state() => SelectiveRestoreState(
  restoreId: 'restore-1',
  planFingerprint: backupDigest(const [1, 2]),
  targets: [
    BackupPreparedTarget(
      owner: BackupOwner.mainData,
      restoreId: 'restore-1',
      descriptor: const {'target': 'exact snapshot'},
    ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'native phase and final tombstone survive reopening and single-slot damage',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'sked-selective-journal-',
      );
      final storage = native.PlatformSelectiveJournalStorage(
        layout: AppStorageLayout(directoryProvider: () async => directory),
      );
      try {
        final journal = PersistentSelectiveRestoreJournal(storage: storage);
        final state = _state();
        await journal.write(state);
        await journal.write(state.markStarted());
        expect(
          (await PersistentSelectiveRestoreJournal(
            storage: storage,
          ).read())!.started,
          isTrue,
        );
        await journal.write(state.markApplied());
        await journal.clear();
        await File('${directory.path}/Sked_selective_restore.0.json')
            .writeAsString('{damaged');
        expect(
          await PersistentSelectiveRestoreJournal(storage: storage).read(),
          isNull,
        );
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );

  test('browser journal persists real preference keys and rejects newer format beside a valid slot', () async {
    SharedPreferences.setMockInitialValues({});
    final journal = PersistentSelectiveRestoreJournal(
      storage: web.PlatformSelectiveJournalStorage(),
    );
    await journal.write(_state());
    expect(
      (await PersistentSelectiveRestoreJournal(
        storage: web.PlatformSelectiveJournalStorage(),
      ).read())!.restoreId,
      'restore-1',
    );
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      '${web.PlatformSelectiveJournalStorage.storagePrefix}0',
      jsonEncode({'version': 99}),
    );
    await expectLater(
      journal.read(),
      throwsA(
        isA<SelectiveBackupException>().having(
          (error) => error.code,
          'code',
          SelectiveBackupError.unsupportedVersion,
        ),
      ),
    );
  });

  test('a partially confirmed phase retains its newest target and blocks backwards progress', () async {
    final storage = _Slots();
    final journal = PersistentSelectiveRestoreJournal(storage: storage);
    final state = _state();
    await journal.write(state);
    storage.failWrite = storage.writes + 2;
    await expectLater(
      journal.write(state.markStarted()),
      throwsA(isA<SelectiveBackupException>()),
    );
    expect((await journal.read())!.started, isTrue);
    storage.failWrite = null;
    await expectLater(
      journal.write(state),
      throwsA(isA<SelectiveBackupException>()),
    );
    await expectLater(
      journal.clear(),
      throwsA(isA<SelectiveBackupException>()),
    );
    await journal.write(state.markApplied());
    await journal.clear();
    expect(await journal.read(), isNull);
  });

  test('descriptor tampering is rejected before a restore can be read', () {
    final json =
        jsonDecode(jsonEncode(_state().toJson())) as Map<String, dynamic>;
    ((json['targets'] as List).single['descriptor'] as Map)['target'] =
        'changed';
    expect(
      () => SelectiveRestoreState.fromJson(json),
      throwsA(isA<SelectiveBackupException>()),
    );
  });
}

class _Slots implements SelectiveJournalStorage {
  final slots = <String?>[null, null];
  int writes = 0;
  int? failWrite;
  @override
  Future<List<String?>> readSlots() async => List.of(slots);
  @override
  Future<void> writeSlot(int slot, String source) async {
    if (++writes == failWrite) {
      throw StateError('Synthetic slot write failure.');
    }
    slots[slot] = source;
  }
}
