import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sked/data/migrations/app_data_migrations.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/data/timetable_storage_io.dart';
import 'package:sked/models/timetable_models.dart';

enum _FileState { missing, valid, empty, corrupt }

AppData _snapshot(String name) {
  final base = buildInitialAppData(buildDefaultPeriodTimes(), localeCode: 'en');
  return base.copyWith(
    generalMode: GeneralScheduleData(
      activeScheduleId: 'calendar',
      selectedDateIso: '2026-09-02',
      schedules: [
        GeneralSchedule(id: 'calendar', name: name, events: const []),
      ],
    ),
  );
}

void main() {
  late Directory directory;
  const fileNames = [
    'Sked_data.json.tmp',
    'Sked_data.json',
    'Sked_data.json.bak',
  ];
  final snapshots = [
    _snapshot('temporary'),
    _snapshot('main'),
    _snapshot('backup'),
  ];

  File fileAt(int index) => File(path.join(directory.path, fileNames[index]));
  IoTimetableStorage newStorage() =>
      IoTimetableStorage(directoryProvider: () async => directory);

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('sked_recovery_matrix_');
  });
  tearDown(() async {
    if (!await directory.exists()) return;
    final resolved = await directory.resolveSymbolicLinks();
    final tempRoot = await Directory.systemTemp.resolveSymbolicLinks();
    if (!path.isWithin(tempRoot, resolved) ||
        !path.basename(resolved).startsWith('sked_recovery_matrix_')) {
      throw StateError('Refusing to remove an unexpected test directory.');
    }
    await directory.delete(recursive: true);
  });

  for (final main in _FileState.values) {
    for (final backup in _FileState.values) {
      for (final temporary in _FileState.values) {
        test(
          'recovery matrix main=${main.name} backup=${backup.name} temp=${temporary.name}',
          () async {
            // A flushed temporary snapshot is the newest accepted write, not
            // an arbitrary leftover to discard. Never choose by file mtime.
            final states = [temporary, main, backup];
            final corruptContents = <String>[];
            for (var i = 0; i < states.length; i += 1) {
              final contents = switch (states[i]) {
                _FileState.missing => null,
                _FileState.valid => snapshots[i].encode(),
                _FileState.empty => '',
                _FileState.corrupt => '{invalid snapshot $i',
              };
              if (contents != null) {
                await fileAt(i).writeAsString(contents, flush: true);
                if (states[i] != _FileState.valid) {
                  corruptContents.add(contents);
                }
              }
            }
            final selected = states.indexOf(_FileState.valid);
            final result = await newStorage().load();
            if (selected >= 0) {
              expect(result.canWrite, isTrue);
              expect(
                result.status,
                selected == 2
                    ? StorageLoadStatus.restored
                    : StorageLoadStatus.success,
              );
              expect(
                result.recoveryStatus,
                selected == 2
                    ? RecoveryStatus.restoredFromBackup
                    : RecoveryStatus.none,
              );
              expect(result.data!.toJson(), snapshots[selected].toJson());
              expect(
                await fileAt(1).readAsString(),
                snapshots[selected].encode(),
              );
            } else {
              expect(result.data, isNull);
              expect(result.canWrite, corruptContents.isEmpty);
              expect(
                result.status,
                corruptContents.isEmpty
                    ? StorageLoadStatus.missing
                    : StorageLoadStatus.corrupt,
              );
            }
            expect(await fileAt(0).exists(), isFalse);
            expect(
              await Future.wait(
                result.recoveryArtifacts.map((p) => File(p).readAsString()),
              ),
              unorderedEquals(corruptContents),
            );

            // A second process must see the same recovered data (or the same
            // read-only corruption gate), not treat isolated files as first run.
            final reloaded = await newStorage().load();
            expect(reloaded.canWrite, result.canWrite);
            expect(reloaded.data?.toJson(), result.data?.toJson());
            expect(
              reloaded.recoveryArtifacts,
              unorderedEquals(result.recoveryArtifacts),
            );
            if (selected < 0) expect(reloaded.status, result.status);
          },
        );
      }
    }
  }

  for (
    var blockedIndex = 0;
    blockedIndex < fileNames.length;
    blockedIndex += 1
  ) {
    final index = blockedIndex;
    test(
      'future schema in ${fileNames[index]} blocks all file mutation',
      () async {
        final originalContents = <String>[];
        for (var i = 0; i < snapshots.length; i += 1) {
          final json = snapshots[i].toJson();
          if (i == index) {
            json['schemaVersion'] = appDataCurrentSchemaVersion + 1;
          }
          final contents = jsonEncode(json);
          originalContents.add(contents);
          await fileAt(i).writeAsString(contents, flush: true);
        }
        for (var attempt = 0; attempt < 2; attempt += 1) {
          final result = await newStorage().load();
          expect(result.status, StorageLoadStatus.unsupportedVersion);
          expect(result.canWrite, isFalse);
          expect(
            result.data?.toJson(),
            index == 0 ? null : snapshots[0].toJson(),
          );
          for (var i = 0; i < snapshots.length; i += 1) {
            expect(await fileAt(i).readAsString(), originalContents[i]);
          }
        }
      },
    );

    test(
      'read failure in ${fileNames[index]} preserves every candidate',
      () async {
        for (var i = 0; i < snapshots.length; i += 1) {
          await fileAt(i).writeAsString(snapshots[i].encode(), flush: true);
        }
        final storage = IoTimetableStorage(
          directoryProvider: () async => directory,
          fileReader: (file) async {
            if (path.equals(file.path, fileAt(index).path)) {
              throw FileSystemException(
                'simulated permission denial',
                file.path,
                const OSError('denied', 13),
              );
            }
            return file.readAsBytes();
          },
        );
        final result = await storage.load();
        expect(result.status, StorageLoadStatus.ioFailure);
        expect(result.canWrite, isFalse);
        expect(
          result.data?.toJson(),
          index == 0 ? null : snapshots[0].toJson(),
        );
        for (var i = 0; i < snapshots.length; i += 1) {
          expect(await fileAt(i).readAsString(), snapshots[i].encode());
        }
        final recovered = await newStorage().load();
        expect(recovered.canWrite, isTrue);
        expect(recovered.data!.toJson(), snapshots[0].toJson());
      },
    );
  }
}
