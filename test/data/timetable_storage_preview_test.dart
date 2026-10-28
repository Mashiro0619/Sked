import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sked/data/migrations/app_data_migrations.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/data/timetable_storage_io.dart';
import 'package:sked/models/timetable_models.dart';

enum _State { missing, valid, corrupt, future, ioFailure }

const _names = ['Sked_data.json.tmp', 'Sked_data.json', 'Sked_data.json.bak'];

AppData _data(String name) => buildInitialAppData(buildDefaultPeriodTimes())
    .copyWith(
      generalMode: GeneralScheduleData(
        activeScheduleId: 'calendar',
        selectedDateIso: '2026-10-28',
        schedules: [
          GeneralSchedule(id: 'calendar', name: name, events: const []),
        ],
      ),
    );

Future<void> _seed(Directory directory, List<_State> states) async {
  await directory.create(recursive: true);
  for (var index = 0; index < states.length; index++) {
    final file = File(path.join(directory.path, _names[index]));
    switch (states[index]) {
      case _State.missing:
        break;
      case _State.valid:
        await file.writeAsString(_data(_names[index]).encode());
      case _State.corrupt:
        await file.writeAsString('{corrupt $index');
      case _State.future:
        final json = _data(_names[index]).toJson()
          ..['schemaVersion'] = appDataCurrentSchemaVersion + 1;
        await file.writeAsString(jsonEncode(json));
      case _State.ioFailure:
        await Directory(file.path).create();
    }
  }
}

Future<Map<String, String>> _tree(Directory directory) async {
  final values = <String, String>{};
  await for (final entity in directory.list(
    recursive: true,
    followLinks: false,
  )) {
    final relative = path.relative(entity.path, from: directory.path);
    values[relative] = entity is File
        ? base64Encode(await entity.readAsBytes())
        : 'directory';
  }
  return values;
}

Map<String, Object?> _result(StorageLoadResult result, Directory directory) => {
  'data': result.data?.toJson(),
  'status': result.status.name,
  'recovery': result.recoveryStatus.name,
  'canWrite': result.canWrite,
  'artifacts':
      result.recoveryArtifacts
          .map((value) => path.relative(value, from: directory.path))
          .toList()
        ..sort(),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('sked-preview-storage-');
  });
  tearDown(() => root.delete(recursive: true));

  for (final temporary in _State.values) {
    for (final main in _State.values) {
      for (final backup in _State.values) {
        test(
          'preview preserves recovery tmp=$temporary main=$main backup=$backup',
          () async {
            final states = [temporary, main, backup];
            final baselineDirectory = Directory(
              path.join(root.path, 'baseline'),
            );
            final previewDirectory = Directory(path.join(root.path, 'preview'));
            await _seed(baselineDirectory, states);
            await _seed(previewDirectory, states);
            final baseline = await IoTimetableStorage(
              directoryProvider: () async => baselineDirectory,
              clock: () => DateTime.utc(2026, 10, 28),
            ).load();
            final previews = <AppData>[];
            final result = await IoTimetableStorage(
              directoryProvider: () async => previewDirectory,
              clock: () => DateTime.utc(2026, 10, 28),
            ).loadWithPreview(previews.add);
            expect(
              _result(result, previewDirectory),
              _result(baseline, baselineDirectory),
            );
            expect(
              await _tree(previewDirectory),
              await _tree(baselineDirectory),
            );
            var expectedIndex = -1;
            // Active directories fail the earlier secret-scrub preflight,
            // before any normal candidate (and hence preview) can be read.
            for (
              var index = 0;
              !states.contains(_State.ioFailure) && index < states.length;
              index++
            ) {
              if (states[index] == _State.valid) {
                expectedIndex = index;
                break;
              }
              if (states[index] == _State.future ||
                  states[index] == _State.ioFailure) {
                break;
              }
            }
            expect(previews, hasLength(expectedIndex < 0 ? 0 : 1));
            if (expectedIndex >= 0) {
              expect(
                previews.single.toJson(),
                _data(_names[expectedIndex]).toJson(),
              );
            }
          },
        );
      }
    }
  }

  test('backup bytes are frozen before the preview observer runs', () async {
    await _seed(root, [_State.missing, _State.valid, _State.future]);
    List<int>? backupBuffer;
    var bufferExistedAtPreview = false;
    final storage = IoTimetableStorage(
      directoryProvider: () async => root,
      fileReader: (file) async {
        final bytes = (await file.readAsBytes()).toList();
        if (path.basename(file.path) == _names[2]) backupBuffer = bytes;
        return bytes;
      },
    );
    final previews = <AppData>[];
    final result = await storage.loadWithPreview((data) {
      previews.add(data);
      bufferExistedAtPreview = backupBuffer != null;
      if (backupBuffer != null) {
        backupBuffer!
          ..clear()
          ..addAll(utf8.encode(_data('replacement').encode()));
      }
    });
    expect(bufferExistedAtPreview, isTrue);
    expect(previews, hasLength(1));
    expect(result.data!.generalMode.schedules.single.name, _names[1]);
    expect(result.status, StorageLoadStatus.unsupportedVersion);
    expect(result.canWrite, isFalse);
  });

  test(
    'preview precedes promotion but follows the frozen backup read',
    () async {
      await _seed(root, [_State.valid, _State.valid, _State.valid]);
      var backupRead = false;
      var previews = 0;
      bool? backupReadAtPreview;
      bool? temporaryExistedAtPreview;
      String? mainNameAtPreview;
      String? previewName;
      final storage = IoTimetableStorage(
        directoryProvider: () async => root,
        fileReader: (file) async {
          if (path.basename(file.path) == _names[2]) backupRead = true;
          return file.readAsBytes();
        },
      );
      final result = await storage.loadWithPreview((data) {
        previews += 1;
        backupReadAtPreview = backupRead;
        temporaryExistedAtPreview = File(path.join(root.path, _names[0]))
            .existsSync();
        mainNameAtPreview = AppData.decode(
          File(path.join(root.path, _names[1])).readAsStringSync(),
        ).generalMode.schedules.single.name;
        previewName = data.generalMode.schedules.single.name;
      });
      expect(previews, 1);
      expect(backupReadAtPreview, isTrue);
      expect(temporaryExistedAtPreview, isTrue);
      expect(mainNameAtPreview, _names[1]);
      expect(previewName, _names[0]);
      expect(result.canWrite, isTrue);
      expect(result.data!.generalMode.schedules.single.name, _names[0]);
      expect(File(path.join(root.path, _names[0])).existsSync(), isFalse);
    },
  );

  test('observer errors do not skip the backup write gate', () async {
    await _seed(root, [_State.missing, _State.valid, _State.future]);
    final result = await IoTimetableStorage(directoryProvider: () async => root)
        .loadWithPreview((_) => throw StateError('presentation failed'));
    expect(result.status, StorageLoadStatus.unsupportedVersion);
    expect(result.canWrite, isFalse);
    expect(result.data!.generalMode.schedules.single.name, _names[1]);
  });

  test('typed backup buffers are copied before the preview callback', () async {
    await _seed(root, [_State.missing, _State.valid, _State.future]);
    List<int>? buffer;
    var bufferExistedAtPreview = false;
    final storage = IoTimetableStorage(
      directoryProvider: () async => root,
      fileReader: (file) async {
        final bytes = await file.readAsBytes();
        if (path.basename(file.path) == _names[2]) buffer = bytes;
        return bytes;
      },
    );
    final result = await storage.loadWithPreview((_) {
      bufferExistedAtPreview = buffer != null;
      if (buffer != null) buffer![0] = 0;
    });
    expect(bufferExistedAtPreview, isTrue);
    expect(result.status, StorageLoadStatus.unsupportedVersion);
    expect(result.canWrite, isFalse);
  });

  test(
    'a changed corrupt backup is preserved and leaves authority read only',
    () async {
      await _seed(root, [_State.missing, _State.valid, _State.corrupt]);
      final replacement = _data('new backup');
      final backup = File(path.join(root.path, _names[2]));
      final result =
          await IoTimetableStorage(directoryProvider: () async => root)
              .loadWithPreview((_) {
                backup.writeAsStringSync(replacement.encode(), flush: true);
              });
      expect(result.status, StorageLoadStatus.ioFailure);
      expect(result.canWrite, isFalse);
      expect(await backup.readAsString(), replacement.encode());
      expect(result.data!.generalMode.schedules.single.name, _names[1]);
    },
  );

  test(
    'recovery artifact scan failure remains authoritative after preview',
    () async {
      await _seed(root, [_State.missing, _State.valid, _State.valid]);
      var previewed = false;
      final storage = IoTimetableStorage(
        directoryProvider: () async => root,
        directoryLister: (directory) => previewed
            ? Stream.error(const FileSystemException('scan failed'))
            : directory.list(followLinks: false),
      );
      final result = await storage.loadWithPreview((_) {
        previewed = true;
      });
      expect(previewed, isTrue);
      expect(result.status, StorageLoadStatus.ioFailure);
      expect(result.canWrite, isFalse);
      expect(result.data!.generalMode.schedules.single.name, _names[1]);
    },
  );
}
