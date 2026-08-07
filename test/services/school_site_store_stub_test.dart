import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sked/services/school_site_service.dart';
import 'package:sked/services/school_site_store.dart';
import 'package:sked/services/school_site_store_stub.dart' as browser_store;
import 'package:sked/utils/app_storage_keys.dart';
import 'package:sked/utils/shared_preferences_recovery.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('throws when SharedPreferences rejects a browser write', () async {
    final preferences = await SharedPreferences.getInstance();
    final store = browser_store.PlatformSchoolSiteStore(
      preferencesProvider: () async => preferences,
      stringWriter: (_, _, _) async => false,
    );

    await expectLater(
      store.save('[]'),
      throwsA(isA<SchoolSiteStoreWriteException>()),
    );
  });

  test(
    'uses only the sked namespace and ignores legacy browser keys',
    () async {
      const legacyKey = 'Sked_school_sites_json';
      const legacyRecoveryKey =
          'Sked_school_sites_recovery_20260803T000000000Z';
      SharedPreferences.setMockInitialValues({
        legacyKey: '[{"name":"Legacy"}]',
        legacyRecoveryKey: 'legacy recovery',
      });
      final preferences = await SharedPreferences.getInstance();
      final store = browser_store.PlatformSchoolSiteStore(
        preferencesProvider: () async => preferences,
      );

      final result = await store.loadResult();

      expect(result.candidates, isEmpty);
      expect(result.hasArtifacts, isFalse);
      expect(result.recoveryArtifacts, isEmpty);
      expect(
        await store.filePath(),
        browserLocalStorageUri(schoolSitesWebStorageKey),
      );
      expect(preferences.containsKey(schoolSitesWebStorageKey), isFalse);
      expect(preferences.getString(legacyKey), isNotNull);
      expect(preferences.getString(legacyRecoveryKey), 'legacy recovery');
    },
  );

  test('failed save reloads an optimistically changed cache', () async {
    const key = schoolSitesWebStorageKey;
    SharedPreferences.setMockInitialValues({key: 'old sites'});
    final preferences = await SharedPreferences.getInstance();
    final store = browser_store.PlatformSchoolSiteStore(
      preferencesProvider: () async => preferences,
      stringWriter: (target, targetKey, value) async {
        await target.setString(targetKey, value);
        SharedPreferences.setMockInitialValues({key: 'old sites'});
        return false;
      },
    );

    await expectLater(
      store.save('new sites'),
      throwsA(isA<SchoolSiteStoreWriteException>()),
    );

    expect(preferences.getString(key), 'old sites');
    expect(await store.load(), 'old sites');
  });

  test('unverifiable failed save blocks later writes', () async {
    const key = schoolSitesWebStorageKey;
    SharedPreferences.setMockInitialValues({key: 'old sites'});
    final preferences = await SharedPreferences.getInstance();
    var failWrite = true;
    var failRefresh = false;
    final store = browser_store.PlatformSchoolSiteStore(
      preferencesProvider: () async => preferences,
      stringWriter: (target, targetKey, value) async {
        if (!failWrite) return target.setString(targetKey, value);
        await target.setString(targetKey, value);
        SharedPreferences.setMockInitialValues({key: 'old sites'});
        failRefresh = true;
        throw StateError('write failed after changing the cache');
      },
      preferencesReloader: (target) async {
        if (failRefresh) throw StateError('persistent storage unavailable');
        await target.reload();
      },
    );

    await expectLater(
      store.save('new sites'),
      throwsA(isA<SchoolSiteStoreStateUnknownException>()),
    );
    await expectLater(
      store.save('another update'),
      throwsA(isA<SchoolSiteStoreRecoveryBlockedException>()),
    );

    failRefresh = false;
    failWrite = false;
    final reloaded = await store.loadResult();
    expect(reloaded.candidates.single.source, 'old sites');
    await reloaded.candidates.single.promote();
    await store.save('confirmed update');
    expect(await store.load(), 'confirmed update');
  });

  test('failed recovery copy discards its optimistic cache value', () async {
    const key = schoolSitesWebStorageKey;
    SharedPreferences.setMockInitialValues({key: '{ broken json'});
    final preferences = await SharedPreferences.getInstance();
    final store = browser_store.PlatformSchoolSiteStore(
      clock: () => DateTime.utc(2026, 8, 3),
      preferencesProvider: () async => preferences,
      stringWriter: (target, targetKey, value) async {
        if (!targetKey.startsWith(schoolSitesWebRecoveryKeyPrefix)) {
          return target.setString(targetKey, value);
        }
        await target.setString(targetKey, value);
        SharedPreferences.setMockInitialValues({key: '{ broken json'});
        return false;
      },
    );

    await expectLater(
      store.isolateForRecovery(),
      throwsA(isA<SchoolSiteStoreWriteException>()),
    );

    expect(preferences.getString(key), '{ broken json');
    expect(
      preferences.getKeys().where(
        (item) => item.startsWith(schoolSitesWebRecoveryKeyPrefix),
      ),
      isEmpty,
    );
    await expectLater(
      store.save('[]'),
      throwsA(isA<SchoolSiteStoreRecoveryBlockedException>()),
    );
    await store.saveAfterRecovery('[]');
  });

  test('failed recovery removal preserves both durable snapshots', () async {
    const key = schoolSitesWebStorageKey;
    const recoveryKey = '${schoolSitesWebRecoveryKeyPrefix}20260803T000000000Z';
    SharedPreferences.setMockInitialValues({key: '{ broken json'});
    final preferences = await SharedPreferences.getInstance();
    final store = browser_store.PlatformSchoolSiteStore(
      clock: () => DateTime.utc(2026, 8, 3),
      preferencesProvider: () async => preferences,
      keyRemover: (target, targetKey) async {
        await target.remove(targetKey);
        SharedPreferences.setMockInitialValues({
          key: '{ broken json',
          recoveryKey: '{ broken json',
        });
        return false;
      },
    );

    await expectLater(
      store.isolateForRecovery(),
      throwsA(isA<SchoolSiteStoreWriteException>()),
    );

    expect(preferences.getString(key), '{ broken json');
    expect(preferences.getString(recoveryKey), '{ broken json');
    await expectLater(
      store.save('[]'),
      throwsA(isA<SchoolSiteStoreRecoveryBlockedException>()),
    );
    await store.saveAfterRecovery('[]');
    expect(preferences.getString(recoveryKey), '{ broken json');
  });

  test(
    'partial typed-value isolation reports every durable artifact',
    () async {
      const key = schoolSitesWebStorageKey;
      const recoveryKey =
          '${schoolSitesWebRecoveryKeyPrefix}20260803T000000000Z';
      SharedPreferences.setMockInitialValues({key: 42});
      final preferences = await SharedPreferences.getInstance();
      final store = browser_store.PlatformSchoolSiteStore(
        clock: () => DateTime.utc(2026, 8, 3),
        preferencesProvider: () async => preferences,
        keyRemover: (target, targetKey) async {
          await target.remove(targetKey);
          SharedPreferences.setMockInitialValues({
            key: 42,
            recoveryKey: 'copy',
          });
          return false;
        },
      );
      final service = SchoolSiteService(store: store);

      final result = await service.loadSitesResult();

      expect(result.recoveryStatus, SchoolSiteRecoveryStatus.storageReadFailed);
      expect(result.canWrite, isFalse);
      expect(result.recoveryArtifacts, [
        browserLocalStorageUri(schoolSitesWebStorageKey),
        browserLocalStorageUri(recoveryKey),
      ]);
      expect(preferences.get(key), 42);
      expect(preferences.getString(recoveryKey), 'copy');

      await store.saveAfterRecovery('[]');
    },
  );

  test('isolates corrupt browser data under a recovery key', () async {
    const lookalikeKey = '${schoolSitesWebRecoveryKeyPrefix}notes';
    SharedPreferences.setMockInitialValues({
      schoolSitesWebStorageKey: '{ broken json',
      lookalikeKey: 'unrelated value',
    });
    final preferences = await SharedPreferences.getInstance();
    final store = browser_store.PlatformSchoolSiteStore(
      clock: () => DateTime.utc(2026, 8, 3),
      preferencesProvider: () async => preferences,
    );

    final artifacts = await store.isolateForRecovery();
    final result = await store.loadResult();

    expect(artifacts, [
      browserLocalStorageUri(
        '${schoolSitesWebRecoveryKeyPrefix}20260803T000000000Z',
      ),
    ]);
    expect(result.candidates, isEmpty);
    expect(result.hasArtifacts, isFalse);
    expect(result.recoveryArtifacts, artifacts);
    expect(
      utf8.decode((await store.readRecoveryArtifact(artifacts.single))!),
      '{ broken json',
    );
    expect(
      await store.readRecoveryArtifact(browserLocalStorageUri(lookalikeKey)),
      isNull,
    );
    await expectLater(
      store.save('[]'),
      throwsA(isA<SchoolSiteStoreRecoveryBlockedException>()),
    );
    await store.saveAfterRecovery('[]');
  });

  test('isolates a wrongly typed value before recovery replacement', () async {
    const key = schoolSitesWebStorageKey;
    SharedPreferences.setMockInitialValues({key: 42});
    final preferences = await SharedPreferences.getInstance();
    final store = browser_store.PlatformSchoolSiteStore(
      clock: () => DateTime.utc(2026, 8, 3),
      preferencesProvider: () async => preferences,
    );

    final result = await store.loadResult();

    expect(result.candidates, isEmpty);
    expect(result.hasArtifacts, isFalse);
    expect(result.recoveryArtifacts, hasLength(1));
    expect(preferences.containsKey(key), isFalse);
    final artifactBeforeReplacement = utf8.decode(
      (await store.readRecoveryArtifact(result.recoveryArtifacts.single))!,
    );
    final recovered = decodeSharedPreferencesRecoveryEnvelope(
      artifactBeforeReplacement,
    );
    expect(recovered.originalKey, key);
    expect(recovered.value, 42);
    await expectLater(
      store.save('[]'),
      throwsA(isA<SchoolSiteStoreRecoveryBlockedException>()),
    );

    await store.saveAfterRecovery('[]');

    expect(preferences.getString(key), '[]');
    expect(
      utf8.decode(
        (await store.readRecoveryArtifact(result.recoveryArtifacts.single))!,
      ),
      artifactBeforeReplacement,
    );

    final reloaded = await store.loadResult();
    expect(reloaded.historicalRecoveryArtifacts, result.recoveryArtifacts);
  });
}
