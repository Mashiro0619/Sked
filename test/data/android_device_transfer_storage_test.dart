import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/data/timetable_storage_io.dart';
import 'package:sked/models/app_data.dart';
import 'package:sked/services/app_storage_layout_io.dart';

const _fixtures = 'android/app/src/test/resources/device_transfer';

Future<void> _hardLink(File source, File target) async {
  final result = Platform.isWindows
      ? await Process.run(
          'powershell.exe',
          [
            '-NoProfile',
            '-NonInteractive',
            '-Command',
            r'New-Item -ItemType HardLink -Path $env:SKED_TEST_LINK '
                r'-Target $env:SKED_TEST_SOURCE -ErrorAction Stop | Out-Null',
          ],
          environment: {
            'SKED_TEST_LINK': target.path,
            'SKED_TEST_SOURCE': source.path,
          },
        )
      : await Process.run('ln', [source.path, target.path]);
  expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  expect(await FileSystemEntity.identical(source.path, target.path), isTrue);
}

void main() {
  late Directory directory;
  late AppDataStoragePaths paths;
  late String snapshot;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('sked-device-transfer-');
    paths = await AppStorageLayout(directoryProvider: () async => directory)
        .appDataPaths();
    snapshot = await File('$_fixtures/sanitized.json').readAsString();
  });

  tearDown(() async => directory.delete(recursive: true));

  test(
    'native-filtered shared fixture preserves ordinary AppData values',
    () async {
      final before = AppData.decodeStorageSnapshot(
        await File('$_fixtures/legacy.json').readAsString(),
      );
      final after = AppData.decodeStorageSnapshot(snapshot);
      expect(after.toJson(), before.toJson());
      expect(after.aiApiSettings.customApiKey, isEmpty);
      expect(before.aiApiSettings.customApiKey, 'SYNTHETIC_CURRENT_KEY');
      expect(snapshot, isNot(contains('SYNTHETIC_')));
      expect(after.studentMode.timetables.single.courses.single.name, '普通课程');
      expect(after.generalMode.schedules.single.events.single.title, '迁移日程');
      expect(after.studentMode.periodTimeSets.single.periodTimes, isNotEmpty);
      expect(after.aiApiSettings.customModel, 'synthetic-model');
    },
  );

  test(
    'interrupted native promotion uses the normal temporary recovery path',
    () async {
      await paths.temporary.writeAsString(snapshot, flush: true);
      final result = await IoTimetableStorage(
        directoryProvider: () async => directory,
      ).load();
      expect(result.status, StorageLoadStatus.success);
      expect(result.canWrite, isTrue);
      expect(result.data!.aiApiSettings.customApiKey, isEmpty);
      expect(await paths.main.readAsString(), snapshot);
      expect(await paths.temporary.exists(), isFalse);
    },
  );

  for (final failSave in [false, true]) {
    test(
      'linked main and temporary recover before ${failSave ? 'failed' : 'successful'} save',
      () async {
        await paths.temporary.writeAsString(snapshot, flush: true);
        await _hardLink(paths.temporary, paths.main);
        final storage = IoTimetableStorage(
          directoryProvider: () async => directory,
          beforeMainReplace: () async {
            // Prove writing the new .tmp never truncates the restored main.
            expect(await paths.main.readAsString(), snapshot);
            expect(
              await FileSystemEntity.identical(
                paths.main.path,
                paths.temporary.path,
              ),
              isFalse,
            );
            if (failSave) {
              throw const FileSystemException('Injected save interruption');
            }
          },
        );
        final loaded = await storage.load();
        expect(loaded.status, StorageLoadStatus.success);
        expect(loaded.canWrite, isTrue);
        expect(await paths.temporary.exists(), isFalse);
        expect(await paths.main.readAsString(), snapshot);

        final edited = loaded.data!.copyWith(localeCode: 'en');
        if (failSave) {
          await expectLater(
            storage.save(edited),
            throwsA(isA<StorageWriteException>()),
          );
          expect(await paths.main.readAsString(), snapshot);
        } else {
          await storage.save(edited);
          expect(
            AppData.decodeStorageSnapshot(await paths.main.readAsString())
                .localeCode,
            'en',
          );
          expect(await paths.backup.readAsString(), snapshot);
        }
        expect(await paths.temporary.exists(), isFalse);
      },
    );
  }

  for (final candidate in ['main', 'temporary']) {
    test(
      'unsupported migrated schema in $candidate keeps the storage write gate closed',
      () async {
        final future = jsonDecode(snapshot) as Map<String, dynamic>;
        future['schemaVersion'] = 999;
        final target = candidate == 'main' ? paths.main : paths.temporary;
        await target.writeAsString(jsonEncode(future), flush: true);
        final result = await IoTimetableStorage(
          directoryProvider: () async => directory,
        ).load();
        expect(result.status, StorageLoadStatus.unsupportedVersion);
        expect(result.canWrite, isFalse);
        expect(result.recoveryArtifacts, contains(target.path));
        expect(await target.readAsString(), jsonEncode(future));
      },
    );
  }
}
