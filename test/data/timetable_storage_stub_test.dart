import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sked/data/migrations/app_data_migrations.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/data/timetable_storage_stub.dart';
import 'package:sked/models/app_data.dart';
import 'package:sked/utils/shared_preferences_recovery.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('save throws when browser storage rejects setString', () async {
    final preferences = await SharedPreferences.getInstance();
    final storage = BrowserTimetableStorage(
      preferencesProvider: () async => preferences,
      stringWriter: (_, _, _) async => false,
    );

    await expectLater(
      storage.save(AppData.fromJson(const {})),
      throwsA(isA<StorageWriteException>()),
    );
  });

  test('failed save reloads an optimistically changed cache', () async {
    const key = 'Sked_app_data';
    final oldData = AppData.fromJson(const {});
    final newData = oldData.copyWith(ignoredUpdateVersion: '9.9.9');
    final oldSource = oldData.encode();
    SharedPreferences.setMockInitialValues({key: oldSource});
    final preferences = await SharedPreferences.getInstance();
    final storage = BrowserTimetableStorage(
      preferencesProvider: () async => preferences,
      stringWriter: (target, targetKey, value) async {
        await target.setString(targetKey, value);
        SharedPreferences.setMockInitialValues({key: oldSource});
        return false;
      },
    );

    await expectLater(
      storage.save(newData),
      throwsA(isA<StorageWriteException>()),
    );

    expect(preferences.getString(key), oldSource);
    final reloaded = await storage.load();
    expect(reloaded.status, StorageLoadStatus.success);
    expect(reloaded.data?.ignoredUpdateVersion, isNull);
  });

  test(
    'unverifiable failed save remains read-only until refresh works',
    () async {
      const key = 'Sked_app_data';
      final oldData = AppData.fromJson(const {});
      final oldSource = oldData.encode();
      final newData = oldData.copyWith(ignoredUpdateVersion: '9.9.9');
      SharedPreferences.setMockInitialValues({key: oldSource});
      final preferences = await SharedPreferences.getInstance();
      var failRefresh = false;
      final storage = BrowserTimetableStorage(
        preferencesProvider: () async => preferences,
        stringWriter: (target, targetKey, value) async {
          await target.setString(targetKey, value);
          SharedPreferences.setMockInitialValues({key: oldSource});
          failRefresh = true;
          throw StateError('write failed after changing the cache');
        },
        preferencesReloader: (target) async {
          if (failRefresh) throw StateError('persistent storage unavailable');
          await target.reload();
        },
      );

      await expectLater(
        storage.save(newData),
        throwsA(isA<StorageWriteException>()),
      );
      final blocked = await storage.load();
      expect(blocked.status, StorageLoadStatus.ioFailure);
      expect(blocked.canWrite, isFalse);

      failRefresh = false;
      final recovered = await storage.load();
      expect(recovered.status, StorageLoadStatus.success);
      expect(recovered.data?.ignoredUpdateVersion, isNull);
    },
  );

  test('corrupt browser value is isolated and keeps recovery gate', () async {
    SharedPreferences.setMockInitialValues({'Sked_app_data': '{bad'});
    final preferences = await SharedPreferences.getInstance();
    final storage = BrowserTimetableStorage(
      preferencesProvider: () async => preferences,
      clock: () => DateTime.utc(2026, 8, 3, 12),
    );

    final result = await storage.load();

    expect(result.status, StorageLoadStatus.corrupt);
    expect(result.canWrite, isFalse);
    expect(result.recoveryArtifacts, hasLength(1));
    expect(preferences.getString('Sked_app_data'), isNull);
    final recoveryKey = result.recoveryArtifacts.single.split('/').last;
    expect(preferences.getString(recoveryKey), '{bad');
    expect(
      utf8.decode(
        (await storage.readRecoveryArtifact(result.recoveryArtifacts.single))!,
      ),
      '{bad',
    );
    expect(
      await storage.readRecoveryArtifact('browser://local-storage/unrelated'),
      isNull,
    );

    final retried = await storage.load();
    expect(retried.status, StorageLoadStatus.corrupt);
    expect(retried.recoveryArtifacts, result.recoveryArtifacts);
  });

  test('empty browser value is corruption rather than missing data', () async {
    SharedPreferences.setMockInitialValues({'Sked_app_data': '   '});
    final preferences = await SharedPreferences.getInstance();
    final storage = BrowserTimetableStorage(
      preferencesProvider: () async => preferences,
    );

    final result = await storage.load();

    expect(result.status, StorageLoadStatus.corrupt);
    expect(result.recoveryArtifacts, hasLength(1));
  });

  test('keeps historical recovery artifacts after save and restart', () async {
    const recoveryKey = 'Sked_app_data_recovery_20260803T120000000Z';
    const recoveryPath = 'browser://local-storage/$recoveryKey';
    const recoverySource = '{historical-broken-app-data';
    final initialData = AppData.fromJson(const {});
    SharedPreferences.setMockInitialValues({
      'Sked_app_data': initialData.encode(),
      recoveryKey: recoverySource,
    });
    final preferences = await SharedPreferences.getInstance();
    final storage = BrowserTimetableStorage(
      preferencesProvider: () async => preferences,
    );

    final loaded = await storage.load();

    expect(loaded.status, StorageLoadStatus.success);
    expect(loaded.recoveryArtifacts, [recoveryPath]);

    await storage.save(initialData.copyWith(ignoredUpdateVersion: '9.9.9'));
    final restarted = BrowserTimetableStorage(
      preferencesProvider: () async => preferences,
    );
    final reloaded = await restarted.load();

    expect(reloaded.status, StorageLoadStatus.success);
    expect(reloaded.recoveryArtifacts, [recoveryPath]);
    expect(
      utf8.decode((await restarted.readRecoveryArtifact(recoveryPath))!),
      recoverySource,
    );
  });

  for (final typedValue in <({String name, Object value})>[
    (name: 'bool', value: true),
    (name: 'int', value: 42),
    (name: 'double', value: -0.0),
    (name: 'NaN double', value: double.nan),
    (name: 'positive infinite double', value: double.infinity),
    (name: 'negative infinite double', value: double.negativeInfinity),
    (name: 'string list', value: <String>['first', 'second']),
  ]) {
    test('isolates and preserves a ${typedValue.name} browser value', () async {
      const key = 'Sked_app_data';
      SharedPreferences.setMockInitialValues({key: typedValue.value});
      final preferences = await SharedPreferences.getInstance();
      final storage = BrowserTimetableStorage(
        preferencesProvider: () async => preferences,
        clock: () => DateTime.utc(2026, 8, 3, 12),
      );

      final result = await storage.load();

      expect(result.status, StorageLoadStatus.corrupt);
      expect(result.canWrite, isFalse);
      expect(preferences.containsKey(key), isFalse);
      expect(result.recoveryArtifacts, hasLength(1));
      final artifactBeforeRestart = utf8.decode(
        (await storage.readRecoveryArtifact(result.recoveryArtifacts.single))!,
      );
      final recovered = decodeSharedPreferencesRecoveryEnvelope(
        artifactBeforeRestart,
      );
      expect(recovered.originalKey, key);
      expect(
        sharedPreferencesValuesEqual(recovered.value, typedValue.value),
        isTrue,
      );
      if (typedValue.value case final double value when value == 0) {
        expect((recovered.value as double).isNegative, value.isNegative);
      }

      await storage.save(AppData.fromJson(const {}));

      expect(preferences.getString(key), isNotNull);
      expect(
        utf8.decode(
          (await storage.readRecoveryArtifact(
            result.recoveryArtifacts.single,
          ))!,
        ),
        artifactBeforeRestart,
      );
    });
  }

  test('failed browser recovery copy reports I/O failure', () async {
    SharedPreferences.setMockInitialValues({'Sked_app_data': '{bad'});
    final preferences = await SharedPreferences.getInstance();
    final storage = BrowserTimetableStorage(
      preferencesProvider: () async => preferences,
      stringWriter: (_, _, _) async => false,
    );

    final result = await storage.load();

    expect(result.status, StorageLoadStatus.ioFailure);
    expect(result.canWrite, isFalse);
    expect(preferences.getString('Sked_app_data'), '{bad');
  });

  test('failed recovery copy discards its optimistic cache value', () async {
    const key = 'Sked_app_data';
    SharedPreferences.setMockInitialValues({key: '{bad'});
    final preferences = await SharedPreferences.getInstance();
    final storage = BrowserTimetableStorage(
      preferencesProvider: () async => preferences,
      clock: () => DateTime.utc(2026, 8, 3, 12),
      stringWriter: (target, targetKey, value) async {
        await target.setString(targetKey, value);
        SharedPreferences.setMockInitialValues({key: '{bad'});
        return false;
      },
    );

    final result = await storage.load();

    expect(result.status, StorageLoadStatus.ioFailure);
    expect(result.canWrite, isFalse);
    expect(preferences.getString(key), '{bad');
    expect(
      preferences.getKeys().where((item) => item.contains('_recovery_')),
      isEmpty,
    );
  });

  test('failed recovery removal restores the primary cache value', () async {
    const key = 'Sked_app_data';
    const recoveryKey = 'Sked_app_data_recovery_20260803T120000000Z';
    SharedPreferences.setMockInitialValues({key: '{bad'});
    final preferences = await SharedPreferences.getInstance();
    final storage = BrowserTimetableStorage(
      preferencesProvider: () async => preferences,
      clock: () => DateTime.utc(2026, 8, 3, 12),
      keyRemover: (target, targetKey) async {
        await target.remove(targetKey);
        SharedPreferences.setMockInitialValues({
          key: '{bad',
          recoveryKey: '{bad',
        });
        return false;
      },
    );

    final result = await storage.load();

    expect(result.status, StorageLoadStatus.ioFailure);
    expect(result.canWrite, isFalse);
    expect(preferences.getString(key), '{bad');
    expect(preferences.getString(recoveryKey), '{bad');
    expect(result.recoveryArtifacts, contains('browser://local-storage/$key'));
    expect(
      result.recoveryArtifacts,
      contains('browser://local-storage/$recoveryKey'),
    );
  });

  test(
    'future browser schema remains read-only and keeps historical artifacts',
    () async {
      const recoveryKey = 'Sked_app_data_recovery_20260803T120000000Z';
      const recoveryPath = 'browser://local-storage/$recoveryKey';
      final future = AppData.fromJson(const {}).toJson()
        ..['schemaVersion'] = appDataCurrentSchemaVersion + 1;
      final content = jsonEncode(future);
      SharedPreferences.setMockInitialValues({
        'Sked_app_data': content,
        recoveryKey: '{historical-broken-app-data',
      });
      final preferences = await SharedPreferences.getInstance();
      final storage = BrowserTimetableStorage(
        preferencesProvider: () async => preferences,
      );

      final result = await storage.load();

      expect(result.status, StorageLoadStatus.unsupportedVersion);
      expect(result.canWrite, isFalse);
      expect(preferences.getString('Sked_app_data'), content);
      expect(result.recoveryArtifacts, [
        'browser://local-storage/Sked_app_data',
        recoveryPath,
      ]);
    },
  );

  test('ignores browser keys that only resemble recovery artifacts', () async {
    SharedPreferences.setMockInitialValues({
      'Sked_app_data_recovery_notes': 'unrelated',
    });
    final preferences = await SharedPreferences.getInstance();
    final storage = BrowserTimetableStorage(
      preferencesProvider: () async => preferences,
    );

    final result = await storage.load();

    expect(result.status, StorageLoadStatus.missing);
    expect(result.recoveryArtifacts, isEmpty);
    expect(
      await storage.readRecoveryArtifact(
        'browser://local-storage/Sked_app_data_recovery_notes',
      ),
      isNull,
    );
  });
}
