import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/data/timetable_storage_io.dart';
import 'package:sked/data/migrations/app_data_migrations.dart';
import 'package:sked/models/app_data.dart';
import 'package:sked/models/app_mode.dart';
import 'package:sked/models/general_event.dart';
import 'package:sked/models/general_schedule.dart';
import 'package:sked/models/general_schedule_data.dart';

void main() {
  late Directory tempDir;
  late IoTimetableStorage storage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sked_storage_test_');
    storage = IoTimetableStorage(directoryProvider: () async => tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  AppData buildAppData(AppMode mode) {
    final empty = AppData.fromJson(const {});
    return AppData(
      activeMode: mode,
      studentMode: empty.studentMode,
      generalMode: empty.generalMode,
    );
  }

  AppData buildGeneralData(String title) {
    final empty = AppData.fromJson(const {});
    const scheduleId = 'cal';
    return AppData(
      activeMode: AppMode.general,
      studentMode: empty.studentMode,
      generalMode: GeneralScheduleData(
        activeScheduleId: scheduleId,
        schedules: [
          GeneralSchedule(
            id: scheduleId,
            name: 'Calendar',
            events: [
              GeneralEvent(
                id: 'event',
                calendarId: scheduleId,
                title: title,
                startDateTimeIso: '2026-05-25T09:00:00.000',
                endDateTimeIso: '2026-05-25T10:00:00.000',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> malformedStudentSnapshot(String part) {
    final snapshot = Map<String, dynamic>.from(
      jsonDecode(buildAppData(AppMode.general).encode()) as Map,
    );
    final timetable = <String, dynamic>{
      'id': 'table',
      'config': <String, dynamic>{
        'name': 'Term',
        'startDate': '2026-08-03T00:00:00.000',
        'totalWeeks': 18,
        'periodTimeSetId': 'periods',
      },
      'courses': <Object?>[
        <String, dynamic>{
          'id': 'course',
          'name': 'Course',
          'teacher': '',
          'location': '',
          'dayOfWeek': 1,
          'semesterWeeks': <int>[1],
          'periods': <int>[1],
          'startMinutes': 480,
          'endMinutes': 525,
          'timeRange': '08:00 - 08:45',
          'credit': 0,
          'remarks': '',
          'customFields': <String, dynamic>{},
        },
      ],
    };
    final periodTimeSet = <String, dynamic>{
      'id': 'periods',
      'name': 'Periods',
      'periodTimes': <Object?>[
        <String, dynamic>{'index': 1, 'startMinutes': 480, 'endMinutes': 525},
      ],
    };
    switch (part) {
      case 'course':
        timetable['courses'] = <Object?>['bad'];
        break;
      case 'config':
        timetable['config'] = 'bad';
        break;
      case 'period entry':
        periodTimeSet['periodTimes'] = <Object?>['bad'];
        break;
      default:
        throw ArgumentError.value(part, 'part');
    }
    final studentMode =
        Map<String, dynamic>.from(snapshot['studentMode'] as Map)
          ..['activeTimetableId'] = 'table'
          ..['timetables'] = <Object?>[timetable]
          ..['periodTimeSets'] = <Object?>[periodTimeSet];
    snapshot['studentMode'] = studentMode;
    return snapshot;
  }

  File mainFile() =>
      File('${tempDir.path}${Platform.pathSeparator}Sked_data.json');
  File backupFile() =>
      File('${tempDir.path}${Platform.pathSeparator}Sked_data.json.bak');
  File tempFile() =>
      File('${tempDir.path}${Platform.pathSeparator}Sked_data.json.tmp');

  group('IoTimetableStorage atomic write & recovery', () {
    test('first load returns null with status none', () async {
      final result = await storage.load();

      expect(result.data, isNull);
      expect(result.recoveryStatus, equals(RecoveryStatus.none));
      expect(result.status, equals(StorageLoadStatus.missing));
      expect(result.canWrite, isTrue);
    });

    test(
      'recovery enumeration failure is not treated as first launch',
      () async {
        final recoveryDirectory = await Directory(
          path.join(tempDir.path, 'Sked_recovery_20260807T000000000Z'),
        ).create();
        final historicalArtifact = File(
          path.join(recoveryDirectory.path, 'Sked_data.json'),
        );
        await historicalArtifact.writeAsString('{historical-corrupt');

        Stream<FileSystemEntity> listDirectory(Directory directory) async* {
          if (path.equals(directory.path, recoveryDirectory.path)) {
            yield historicalArtifact;
            throw FileSystemException(
              'simulated recovery enumeration failure',
              directory.path,
            );
          }
          yield* directory.list(followLinks: false);
        }

        final failingStorage = IoTimetableStorage(
          directoryProvider: () async => tempDir,
          directoryLister: listDirectory,
        );

        final result = await failingStorage.load();

        expect(result.data, isNull);
        expect(result.status, StorageLoadStatus.ioFailure);
        expect(result.recoveryStatus, RecoveryStatus.ioFailure);
        expect(result.canWrite, isFalse);
        expect(result.recoveryArtifacts, contains(historicalArtifact.path));
      },
    );

    test('write then read returns identical AppData', () async {
      final data = buildAppData(AppMode.student);

      await storage.save(data);
      final result = await storage.load();

      expect(result.data, isNotNull);
      expect(result.data!.activeMode, equals(AppMode.student));
      expect(result.recoveryStatus, equals(RecoveryStatus.none));
      expect(result.status, equals(StorageLoadStatus.success));
      expect(result.canWrite, isTrue);
    });

    test('stale recovery refuses to move a newer snapshot', () async {
      await mainFile().writeAsString('{corrupt snapshot');
      final firstRead = Completer<void>();
      final releaseRead = Completer<void>();
      var paused = false;
      final staleStorage = IoTimetableStorage(
        directoryProvider: () async => tempDir,
        fileReader: (file) async {
          final bytes = await file.readAsBytes();
          if (file.path == mainFile().path && !paused) {
            paused = true;
            firstRead.complete();
            await releaseRead.future;
          }
          return bytes;
        },
      );
      final loadFuture = staleStorage.load();
      await firstRead.future;

      final newerData = buildAppData(AppMode.general);
      await storage.save(newerData);
      releaseRead.complete();

      final result = await loadFuture;

      expect(result.status, StorageLoadStatus.ioFailure);
      expect(result.canWrite, isFalse);
      expect(
        AppData.decode(await mainFile().readAsString()).activeMode,
        AppMode.general,
      );
    });

    test('stale temp promotion preserves a newer temporary snapshot', () async {
      final pending = buildAppData(AppMode.student);
      final committed = buildAppData(AppMode.general);
      final previous = buildGeneralData('Previous backup');
      final newerTemp = buildGeneralData('Newer temporary');
      await tempFile().writeAsString(pending.encode());
      await mainFile().writeAsString(committed.encode());
      await backupFile().writeAsString(previous.encode());
      var replaced = false;
      final staleStorage = IoTimetableStorage(
        directoryProvider: () async => tempDir,
        fileReader: (file) async {
          final bytes = await file.readAsBytes();
          if (file.path == backupFile().path && !replaced) {
            replaced = true;
            await tempFile().writeAsString(newerTemp.encode());
          }
          return bytes;
        },
      );

      final result = await staleStorage.load();

      expect(result.status, StorageLoadStatus.ioFailure);
      expect(result.canWrite, isFalse);
      expect(await mainFile().readAsString(), committed.encode());
      expect(await tempFile().readAsString(), newerTemp.encode());
    });

    test('stale backup restore preserves a newer backup snapshot', () async {
      final loadedBackup = buildAppData(AppMode.student);
      final newerBackup = buildGeneralData('Newer backup');
      await mainFile().writeAsString('{corrupt main');
      await backupFile().writeAsString(loadedBackup.encode());
      var replaced = false;
      final staleStorage = IoTimetableStorage(
        directoryProvider: () async => tempDir,
        fileReader: (file) async {
          final bytes = await file.readAsBytes();
          if (file.path == backupFile().path && !replaced) {
            replaced = true;
            await backupFile().writeAsString(newerBackup.encode());
          }
          return bytes;
        },
      );

      final result = await staleStorage.load();

      expect(result.status, StorageLoadStatus.ioFailure);
      expect(result.canWrite, isFalse);
      expect(await mainFile().exists(), isFalse);
      expect(await backupFile().readAsString(), newerBackup.encode());
      expect(
        result.recoveryArtifacts.any(
          (artifact) =>
              path.basename(artifact) == mainFile().uri.pathSegments.last,
        ),
        isTrue,
      );
    });

    test('second write rotates previous main to .bak', () async {
      final v1 = buildAppData(AppMode.student);
      final v2 = buildAppData(AppMode.general);

      await storage.save(v1);
      await storage.save(v2);

      // Main now has v2.
      final result = await storage.load();
      expect(result.data!.activeMode, equals(AppMode.general));

      // .bak should contain the previous version (v1 == student mode).
      expect(await backupFile().exists(), isTrue);
      final bakContent = await backupFile().readAsString();
      final bakData = AppData.decode(bakContent);
      expect(bakData.activeMode, equals(AppMode.student));
    });

    test('successful save leaves no stale .tmp file', () async {
      final data = buildAppData(AppMode.general);

      await storage.save(data);

      expect(await tempFile().exists(), isFalse);
    });

    test('save wraps platform I/O errors as StorageWriteException', () async {
      final nonDirectory = File(
        '${tempDir.path}${Platform.pathSeparator}not-a-directory',
      );
      await nonDirectory.writeAsString('occupied');
      final failingStorage = IoTimetableStorage(
        directoryProvider: () async => Directory(nonDirectory.path),
      );

      await expectLater(
        failingStorage.save(buildAppData(AppMode.general)),
        throwsA(
          isA<StorageWriteException>().having(
            (error) => error.cause,
            'cause',
            isA<FileSystemException>(),
          ),
        ),
      );
    });

    for (final entry in <String, File Function()>{
      'main': mainFile,
      'temporary': tempFile,
      'backup': backupFile,
    }.entries) {
      test('save rejects a directory at the ${entry.key} path', () async {
        final occupied = entry.value();
        await Directory(occupied.path).create();

        await expectLater(
          storage.save(buildAppData(AppMode.general)),
          throwsA(
            isA<StorageWriteException>().having(
              (error) => error.cause,
              'cause',
              isA<FileSystemException>(),
            ),
          ),
        );

        expect(
          await FileSystemEntity.type(occupied.path, followLinks: false),
          FileSystemEntityType.directory,
        );
      });
    }

    test(
      'save rejects a temporary-file symlink without touching its target',
      () async {
        final outsideDirectory = await Directory.systemTemp.createTemp(
          'sked-storage-link-target-',
        );
        try {
          final target = File(path.join(outsideDirectory.path, 'target.json'));
          await target.writeAsString('outside data');
          try {
            await Link(tempFile().path).create(target.path);
          } on FileSystemException {
            // Windows installations without Developer Mode may not permit test
            // symlink creation. Directory-path tests still cover the rejection
            // branch deterministically on those hosts.
            return;
          }

          await expectLater(
            storage.save(buildAppData(AppMode.general)),
            throwsA(
              isA<StorageWriteException>().having(
                (error) => error.cause,
                'cause',
                isA<FileSystemException>(),
              ),
            ),
          );

          expect(await target.readAsString(), 'outside data');
          expect(
            await FileSystemEntity.type(tempFile().path, followLinks: false),
            FileSystemEntityType.link,
          );
        } finally {
          if (await outsideDirectory.exists()) {
            await outsideDirectory.delete(recursive: true);
          }
        }
      },
    );

    test('promotes valid .tmp when save crashed before rotation', () async {
      final mainData = buildAppData(AppMode.student);
      final tempData = buildAppData(AppMode.general);
      await mainFile().writeAsString(mainData.encode());
      await tempFile().writeAsString(tempData.encode());

      final result = await storage.load();

      expect(result.data!.activeMode, equals(AppMode.general));
      expect(result.recoveryStatus, equals(RecoveryStatus.none));
      expect(await tempFile().exists(), isFalse);
      expect(
        AppData.decode(await mainFile().readAsString()).activeMode,
        equals(AppMode.general),
      );
      expect(
        AppData.decode(await backupFile().readAsString()).activeMode,
        equals(AppMode.student),
      );
    });

    test('promotes valid .tmp when save crashed after main rotation', () async {
      final backupData = buildAppData(AppMode.student);
      final tempData = buildAppData(AppMode.general);
      await backupFile().writeAsString(backupData.encode());
      await tempFile().writeAsString(tempData.encode());

      final result = await storage.load();

      expect(result.data!.activeMode, equals(AppMode.general));
      expect(result.recoveryStatus, equals(RecoveryStatus.none));
      expect(await tempFile().exists(), isFalse);
      expect(
        AppData.decode(await mainFile().readAsString()).activeMode,
        equals(AppMode.general),
      );
      expect(
        AppData.decode(await backupFile().readAsString()).activeMode,
        equals(AppMode.student),
      );
    });

    test('falls back to .bak when main file is corrupted', () async {
      final v1 = buildAppData(AppMode.student);
      final v2 = buildAppData(AppMode.general);

      // Two writes: main = v2, .bak = v1.
      await storage.save(v1);
      await storage.save(v2);

      // Corrupt main file by writing invalid JSON.
      await mainFile().writeAsString('{not valid json');

      final result = await storage.load();

      expect(result.data, isNotNull);
      expect(result.data!.activeMode, equals(AppMode.student));
      expect(result.recoveryStatus, equals(RecoveryStatus.restoredFromBackup));
      expect(result.recoveryArtifacts, hasLength(1));
      expect(
        await File(result.recoveryArtifacts.single).readAsString(),
        '{not valid json',
      );
      expect(await mainFile().readAsString(), v1.encode());

      final secondLoad = await storage.load();
      expect(secondLoad.data, isNotNull);
      expect(secondLoad.data!.activeMode, equals(AppMode.student));
      expect(secondLoad.recoveryStatus, equals(RecoveryStatus.none));
    });

    test('isolates a corrupt .tmp before using a valid main', () async {
      final main = buildAppData(AppMode.general);
      await mainFile().writeAsString(main.encode());
      await tempFile().writeAsString('{corrupt temp');

      final result = await storage.load();

      expect(result.status, StorageLoadStatus.success);
      expect(result.canWrite, isTrue);
      expect(result.data?.activeMode, AppMode.general);
      expect(await mainFile().readAsString(), main.encode());
      expect(await tempFile().exists(), isFalse);
      expect(result.recoveryArtifacts, hasLength(1));
      expect(
        await File(result.recoveryArtifacts.single).readAsString(),
        '{corrupt temp',
      );
    });

    test('isolates a corrupt .bak before using a valid main', () async {
      final main = buildAppData(AppMode.general);
      await mainFile().writeAsString(main.encode());
      await backupFile().writeAsString('{corrupt backup');

      final result = await storage.load();

      expect(result.status, StorageLoadStatus.success);
      expect(result.canWrite, isTrue);
      expect(result.data?.activeMode, AppMode.general);
      expect(await mainFile().readAsString(), main.encode());
      expect(await backupFile().exists(), isFalse);
      expect(result.recoveryArtifacts, hasLength(1));
      expect(
        await File(result.recoveryArtifacts.single).readAsString(),
        '{corrupt backup',
      );
    });

    test(
      'isolation failure blocks backup promotion and later writes',
      () async {
        final backup = buildAppData(AppMode.student);
        await mainFile().writeAsString('{corrupt main');
        await backupFile().writeAsString(backup.encode());
        final failingStorage = IoTimetableStorage(
          directoryProvider: () async => tempDir,
          fileReader: (file) async {
            final bytes = await file.readAsBytes();
            if (file.path == mainFile().path) {
              await file.delete();
              await Directory(file.path).create();
            }
            return bytes;
          },
        );

        final result = await failingStorage.load();

        expect(result.status, StorageLoadStatus.ioFailure);
        expect(result.recoveryStatus, RecoveryStatus.ioFailure);
        expect(result.canWrite, isFalse);
        expect(result.data?.activeMode, AppMode.student);
        expect(
          await FileSystemEntity.type(mainFile().path),
          FileSystemEntityType.directory,
        );
        expect(await backupFile().readAsString(), backup.encode());
        expect(result.recoveryArtifacts, contains(mainFile().path));
        expect(result.recoveryArtifacts, contains(backupFile().path));
      },
    );

    test('falls back to .bak when main file is not valid UTF-8', () async {
      final v1 = buildAppData(AppMode.student);
      final v2 = buildAppData(AppMode.general);

      await storage.save(v1);
      await storage.save(v2);

      await mainFile().writeAsBytes([0xff, 0xfe, 0xfd]);

      final result = await storage.load();

      expect(result.data, isNotNull);
      expect(result.data!.activeMode, equals(AppMode.student));
      expect(result.recoveryStatus, equals(RecoveryStatus.restoredFromBackup));
    });

    test(
      'falls back to .bak when main file has malformed studentMode shape',
      () async {
        final backupData = buildGeneralData('Recovered from backup');
        await backupFile().writeAsString(backupData.encode());
        await mainFile().writeAsString('{"studentMode":"bad"}');

        final result = await storage.load();

        expect(
          result.recoveryStatus,
          equals(RecoveryStatus.restoredFromBackup),
        );
        expect(
          result.data!.generalMode.schedules.single.events.single.title,
          'Recovered from backup',
        );
      },
    );

    for (final malformedPart in const ['course', 'config', 'period entry']) {
      test(
        'falls back to .bak when main file has malformed $malformedPart',
        () async {
          final backupData = buildGeneralData(
            'Recovered after malformed $malformedPart',
          );
          await backupFile().writeAsString(backupData.encode());
          await mainFile().writeAsString(
            jsonEncode(malformedStudentSnapshot(malformedPart)),
          );

          final result = await storage.load();

          expect(
            result.recoveryStatus,
            equals(RecoveryStatus.restoredFromBackup),
          );
          expect(
            result.data!.generalMode.schedules.single.events.single.title,
            'Recovered after malformed $malformedPart',
          );
        },
      );
    }

    test(
      'falls back to .bak when main file has malformed general schedules',
      () async {
        final backupData = buildGeneralData('Recovered schedule');
        await backupFile().writeAsString(backupData.encode());
        await mainFile().writeAsString(
          '{"generalMode":{"schemaVersion":3,"schedules":["bad"]}}',
        );

        final result = await storage.load();

        expect(
          result.recoveryStatus,
          equals(RecoveryStatus.restoredFromBackup),
        );
        expect(
          result.data!.generalMode.schedules.single.events.single.title,
          'Recovered schedule',
        );
      },
    );

    test(
      'falls back to .bak when main file has mixed malformed schedules',
      () async {
        final backupData = buildGeneralData('Recovered mixed schedule');
        final mainData = buildGeneralData('Corrupt mixed schedule').toJson();
        final generalMode = Map<String, dynamic>.from(
          mainData['generalMode'] as Map,
        );
        generalMode['schedules'] = [
          ...(generalMode['schedules'] as List),
          'bad',
        ];
        mainData['generalMode'] = generalMode;
        await backupFile().writeAsString(backupData.encode());
        await mainFile().writeAsString(jsonEncode(mainData));

        final result = await storage.load();

        expect(
          result.recoveryStatus,
          equals(RecoveryStatus.restoredFromBackup),
        );
        expect(
          result.data!.generalMode.schedules.single.events.single.title,
          'Recovered mixed schedule',
        );
      },
    );

    test(
      'falls back to .bak when main file has invalid general event dates',
      () async {
        final backupData = buildGeneralData('Recovered event date');
        final mainData = buildGeneralData('Corrupt event date').toJson();
        final generalMode = Map<String, dynamic>.from(
          mainData['generalMode'] as Map,
        );
        final schedules = [
          for (final schedule in generalMode['schedules'] as List)
            Map<String, dynamic>.from(schedule as Map),
        ];
        final events = [
          for (final event in schedules.single['events'] as List)
            Map<String, dynamic>.from(event as Map),
        ];
        events.single['start'] = '2026-02-31T09:00:00.000';
        schedules.single['events'] = events;
        generalMode['schedules'] = schedules;
        mainData['generalMode'] = generalMode;
        await backupFile().writeAsString(backupData.encode());
        await mainFile().writeAsString(jsonEncode(mainData));

        final result = await storage.load();

        expect(
          result.recoveryStatus,
          equals(RecoveryStatus.restoredFromBackup),
        );
        expect(
          result.data!.generalMode.schedules.single.events.single.title,
          'Recovered event date',
        );
      },
    );

    test(
      'returns failedBackupRestore when both main and .bak are corrupted',
      () async {
        await mainFile().writeAsString('{garbage');
        await backupFile().writeAsString('{also garbage');

        final result = await storage.load();

        expect(result.data, isNull);
        expect(
          result.recoveryStatus,
          equals(RecoveryStatus.failedBackupRestore),
        );
        expect(result.status, equals(StorageLoadStatus.corrupt));
        expect(result.canWrite, isFalse);
        expect(result.recoveryArtifacts, hasLength(2));
        for (final artifact in result.recoveryArtifacts) {
          expect(await File(artifact).exists(), isTrue);
        }
        expect(await mainFile().exists(), isFalse);
        expect(await backupFile().exists(), isFalse);

        final retried = await storage.load();
        expect(retried.status, equals(StorageLoadStatus.corrupt));
        expect(retried.canWrite, isFalse);
        expect(
          retried.recoveryArtifacts,
          unorderedEquals(result.recoveryArtifacts),
        );
      },
    );

    test(
      'partial isolation failure reports preserved and still-active artifacts',
      () async {
        await mainFile().writeAsString('{main-corrupt');
        await backupFile().writeAsString('{backup-corrupt');
        await tempFile().writeAsString('{temp-corrupt');
        final failingStorage = IoTimetableStorage(
          directoryProvider: () async => tempDir,
          fileReader: (file) async {
            final bytes = await file.readAsBytes();
            if (file.path == backupFile().path) {
              await file.delete();
              await Directory(file.path).create();
            }
            return bytes;
          },
        );

        final result = await failingStorage.load();

        expect(result.status, StorageLoadStatus.ioFailure);
        expect(result.canWrite, isFalse);
        expect(result.recoveryArtifacts, hasLength(3));
        expect(result.recoveryArtifacts, contains(backupFile().path));
        expect(result.recoveryArtifacts, contains(tempFile().path));
        expect(
          result.recoveryArtifacts.any(
            (artifact) =>
                path.basename(artifact) == path.basename(mainFile().path) &&
                artifact != mainFile().path,
          ),
          isTrue,
        );
      },
    );

    test('empty main file is treated as corrupt and isolated', () async {
      await mainFile().writeAsString('   ');

      final result = await storage.load();

      expect(result.data, isNull);
      expect(result.status, equals(StorageLoadStatus.corrupt));
      expect(result.canWrite, isFalse);
      expect(result.recoveryArtifacts, hasLength(1));
      expect(await File(result.recoveryArtifacts.single).readAsString(), '   ');
      expect(await mainFile().exists(), isFalse);
    });

    test('unrecoverable .tmp file is isolated instead of ignored', () async {
      // Simulate: a previous save crashed after writing .tmp but before rotation.
      await tempFile().writeAsString('{leftover');

      final result = await storage.load();

      expect(result.data, isNull);
      expect(result.status, equals(StorageLoadStatus.corrupt));
      expect(result.recoveryArtifacts, hasLength(1));
      expect(
        await File(result.recoveryArtifacts.single).readAsString(),
        '{leftover',
      );
      expect(await tempFile().exists(), isFalse);
    });

    test('future main schema does not fall back to an older backup', () async {
      final future = buildAppData(AppMode.general).toJson()
        ..['schemaVersion'] = appDataCurrentSchemaVersion + 1;
      final backup = buildAppData(AppMode.student);
      await mainFile().writeAsString(jsonEncode(future));
      await backupFile().writeAsString(backup.encode());

      final result = await storage.load();

      expect(result.data, isNull);
      expect(result.status, equals(StorageLoadStatus.unsupportedVersion));
      expect(result.recoveryStatus, equals(RecoveryStatus.unsupportedVersion));
      expect(result.canWrite, isFalse);
      expect(await mainFile().exists(), isTrue);
      expect(await backupFile().readAsString(), backup.encode());
    });

    test(
      'future nested general schema wins over malformed fields and backup',
      () async {
        final future = buildAppData(AppMode.general).toJson();
        final generalMode =
            Map<String, dynamic>.from(future['generalMode'] as Map)
              ..['schemaVersion'] = 999
              ..['activeScheduleId'] = 42
              ..['schedules'] = 'not-a-list';
        future['generalMode'] = generalMode;
        final backup = buildAppData(AppMode.student);
        await mainFile().writeAsString(jsonEncode(future));
        await backupFile().writeAsString(backup.encode());

        final result = await storage.load();

        expect(result.data, isNull);
        expect(result.status, StorageLoadStatus.unsupportedVersion);
        expect(result.canWrite, isFalse);
        expect(await mainFile().exists(), isTrue);
        expect(await backupFile().readAsString(), backup.encode());
      },
    );

    test(
      'does not treat an active directory as data or fall back to backup',
      () async {
        await mainFile().create(recursive: true);
        await mainFile().delete();
        await Directory(mainFile().path).create();
        final backup = buildAppData(AppMode.student);
        await backupFile().writeAsString(backup.encode());

        expect(
          await FileSystemEntity.type(mainFile().path, followLinks: false),
          FileSystemEntityType.directory,
        );

        final result = await storage.load();

        expect(result.data, isNull);
        expect(result.status, equals(StorageLoadStatus.ioFailure));
        expect(result.recoveryStatus, equals(RecoveryStatus.ioFailure));
        expect(result.canWrite, isFalse);
        expect(await backupFile().readAsString(), backup.encode());
      },
    );

    test(
      'FileSystemException without an OSError is still an I/O failure',
      () async {
        final main = buildAppData(AppMode.general);
        final backup = buildAppData(AppMode.student);
        await mainFile().writeAsString(main.encode());
        await backupFile().writeAsString(backup.encode());
        final failingStorage = IoTimetableStorage(
          directoryProvider: () async => tempDir,
          fileReader: (file) async {
            if (file.path == mainFile().path) {
              throw const FileSystemException('synthetic read failure');
            }
            return file.readAsBytes();
          },
        );

        final result = await failingStorage.load();

        expect(result.data, isNull);
        expect(result.status, StorageLoadStatus.ioFailure);
        expect(result.canWrite, isFalse);
        expect(await mainFile().readAsString(), main.encode());
        expect(await backupFile().readAsString(), backup.encode());
      },
    );

    test(
      'lower-priority read failure preserves a valid main snapshot',
      () async {
        final main = buildAppData(AppMode.general);
        final backup = buildAppData(AppMode.student);
        await mainFile().writeAsString(main.encode());
        await backupFile().writeAsString(backup.encode());
        final failingStorage = IoTimetableStorage(
          directoryProvider: () async => tempDir,
          fileReader: (file) async {
            if (file.path == backupFile().path) {
              throw const FileSystemException('synthetic backup read failure');
            }
            return file.readAsBytes();
          },
        );

        final result = await failingStorage.load();

        expect(result.status, StorageLoadStatus.ioFailure);
        expect(result.canWrite, isFalse);
        expect(result.data?.activeMode, AppMode.general);
        expect(await mainFile().readAsString(), main.encode());
        expect(await backupFile().readAsString(), backup.encode());
      },
    );

    test('isolated artifacts survive later data rotations unchanged', () async {
      await mainFile().writeAsString('{main-corrupt');
      await backupFile().writeAsString('{backup-corrupt');
      await tempFile().writeAsString('{temp-corrupt');
      final failed = await storage.load();
      final originalContents = <String, String>{
        for (final artifact in failed.recoveryArtifacts)
          artifact: await File(artifact).readAsString(),
      };

      for (final entry in originalContents.entries) {
        expect(
          utf8.decode((await storage.readRecoveryArtifact(entry.key))!),
          entry.value,
        );
      }
      expect(
        await storage.readRecoveryArtifact(
          path.join(tempDir.parent.path, 'outside.json'),
        ),
        isNull,
      );

      await storage.save(buildAppData(AppMode.student));
      await storage.save(buildAppData(AppMode.general));

      for (final entry in originalContents.entries) {
        expect(await File(entry.key).readAsString(), entry.value);
      }

      final reloaded = await storage.load();
      expect(reloaded.status, StorageLoadStatus.success);
      expect(reloaded.canWrite, isTrue);
      expect(
        reloaded.recoveryArtifacts,
        unorderedEquals(originalContents.keys),
      );
    });

    test('ignores recovery-like directories and unrelated files', () async {
      final prefixOnly = await Directory(
        path.join(tempDir.path, 'Sked_recovery_notes'),
      ).create();
      final exactDirectory = await Directory(
        path.join(tempDir.path, 'Sked_recovery_20260803T000000000Z'),
      ).create();
      final prefixedArtifact = File(
        path.join(prefixOnly.path, 'Sked_data.json'),
      );
      final unrelatedArtifact = File(
        path.join(exactDirectory.path, 'notes.txt'),
      );
      await prefixedArtifact.writeAsString('unrelated');
      await unrelatedArtifact.writeAsString('unrelated');

      final result = await storage.load();

      expect(result.status, StorageLoadStatus.missing);
      expect(result.recoveryArtifacts, isEmpty);
      expect(await storage.readRecoveryArtifact(prefixedArtifact.path), isNull);
      expect(
        await storage.readRecoveryArtifact(unrelatedArtifact.path),
        isNull,
      );
    });
  });
}
