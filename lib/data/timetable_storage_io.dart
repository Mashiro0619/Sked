import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'migrations/migration.dart';
import '../models/timetable_models.dart';
import 'timetable_storage.dart';

TimetableStorage createTimetableStorage() => IoTimetableStorage();

class IoTimetableStorage
    implements TimetableStorage, TimetableRecoveryArtifactReader {
  IoTimetableStorage({
    Future<Directory> Function()? directoryProvider,
    DateTime Function()? clock,
    this._fileReader,
  }) : _directoryProvider =
           directoryProvider ?? getApplicationDocumentsDirectory,
       _clock = clock ?? DateTime.now;

  static const _fileName = 'Sked_data.json';
  static const _backupSuffix = '.bak';
  static const _tempSuffix = '.tmp';
  static const _recoveryDirectoryPrefix = 'Sked_recovery_';
  static final _recoveryDirectoryNamePattern = RegExp(
    r'^Sked_recovery_\d{8}T\d{9}(?:\d{3})?Z(?:_\d+)?$',
  );

  final Future<Directory> Function() _directoryProvider;
  final DateTime Function() _clock;
  final Future<List<int>> Function(File)? _fileReader;

  @override
  Future<StorageLoadResult> load() async {
    late final File main;
    try {
      main = await _resolveFile();
    } catch (_) {
      return const StorageLoadResult(
        data: null,
        recoveryStatus: RecoveryStatus.ioFailure,
        status: StorageLoadStatus.ioFailure,
      );
    }
    final tmp = File('${main.path}$_tempSuffix');
    final backup = File('${main.path}$_backupSuffix');

    final tmpAttempt = await _tryDecode(tmp);
    final mainAttempt = await _tryDecode(main);
    final backupAttempt = await _tryDecode(backup);
    final attempts = <File, _DecodeAttempt>{
      tmp: tmpAttempt,
      main: mainAttempt,
      backup: backupAttempt,
    };
    final safelyLoadedData = _readableDataBeforeBlockingCandidate([
      tmpAttempt,
      mainAttempt,
      backupAttempt,
    ]);
    final directory = main.parent;
    final existingRecoveryArtifacts = await _safeExistingRecoveryArtifacts(
      directory,
    );

    final unsupportedPaths = _pathsWithOutcome(
      attempts,
      _Outcome.unsupportedVersion,
    );
    if (unsupportedPaths.isNotEmpty) {
      return StorageLoadResult(
        data: safelyLoadedData,
        recoveryStatus: RecoveryStatus.unsupportedVersion,
        status: StorageLoadStatus.unsupportedVersion,
        recoveryArtifacts: {
          ...existingRecoveryArtifacts,
          ...unsupportedPaths,
        }.toList()..sort(),
      );
    }

    final ioFailurePaths = _pathsWithOutcome(attempts, _Outcome.ioFailure);
    if (ioFailurePaths.isNotEmpty) {
      return StorageLoadResult(
        data: safelyLoadedData,
        recoveryStatus: RecoveryStatus.ioFailure,
        status: StorageLoadStatus.ioFailure,
        recoveryArtifacts: {
          ...existingRecoveryArtifacts,
          ...ioFailurePaths,
        }.toList()..sort(),
      );
    }

    final corruptFiles = [
      for (final entry in attempts.entries)
        if (entry.value.outcome == _Outcome.corrupt) entry.key,
    ];
    final hasReadableCandidate = attempts.values.any(
      (attempt) => attempt.outcome == _Outcome.success,
    );
    var recoveryArtifacts = existingRecoveryArtifacts;
    final isolatedSourcePaths = <String>{};
    if (hasReadableCandidate && corruptFiles.isNotEmpty) {
      try {
        isolatedSourcePaths.addAll(
          corruptFiles.map((file) => path.normalize(file.path)),
        );
        final isolated = await _isolateActiveFiles(
          directory: directory,
          files: corruptFiles,
          expectedFiles: {
            for (final file in corruptFiles) file: attempts[file]!,
          },
        );
        recoveryArtifacts = {...existingRecoveryArtifacts, ...isolated}.toList()
          ..sort();
      } catch (_) {
        return StorageLoadResult(
          data: safelyLoadedData,
          recoveryStatus: RecoveryStatus.ioFailure,
          status: StorageLoadStatus.ioFailure,
          recoveryArtifacts: await _recoveryArtifactsIncludingActive(
            directory: directory,
            activeFiles: [tmp, main, backup],
            knownArtifacts: existingRecoveryArtifacts,
          ),
        );
      }
    }

    if (tmpAttempt.outcome == _Outcome.success) {
      try {
        final expectedMain = _expectedAttempt(
          main,
          attempts,
          isolatedSourcePaths,
        );
        final expectedBackup = _expectedAttempt(
          backup,
          attempts,
          isolatedSourcePaths,
        );
        await _promoteTempToMain(
          tmp: tmp,
          main: main,
          backup: backup,
          expectedTemp: tmpAttempt,
          expectedMain: expectedMain,
          expectedBackup: expectedBackup,
        );
      } catch (_) {
        return StorageLoadResult(
          data: tmpAttempt.data,
          recoveryStatus: RecoveryStatus.ioFailure,
          status: StorageLoadStatus.ioFailure,
          recoveryArtifacts: await _recoveryArtifactsIncludingActive(
            directory: directory,
            activeFiles: [tmp, main, backup],
            knownArtifacts: recoveryArtifacts,
          ),
        );
      }
      return StorageLoadResult(
        data: tmpAttempt.data,
        recoveryStatus: RecoveryStatus.none,
        status: StorageLoadStatus.success,
        recoveryArtifacts: recoveryArtifacts,
      );
    }

    if (mainAttempt.outcome == _Outcome.success) {
      return StorageLoadResult(
        data: mainAttempt.data,
        recoveryStatus: RecoveryStatus.none,
        status: StorageLoadStatus.success,
        recoveryArtifacts: recoveryArtifacts,
      );
    }

    if (backupAttempt.outcome == _Outcome.success) {
      try {
        final expectedMain = _expectedAttempt(
          main,
          attempts,
          isolatedSourcePaths,
        );
        final expectedTemp = _expectedAttempt(
          tmp,
          attempts,
          isolatedSourcePaths,
        );
        await _restoreBackupToMain(
          backup: backup,
          main: main,
          expectedBackup: backupAttempt,
          expectedMain: expectedMain,
          expectedTemp: expectedTemp,
        );
      } catch (_) {
        return StorageLoadResult(
          data: backupAttempt.data,
          recoveryStatus: RecoveryStatus.ioFailure,
          status: StorageLoadStatus.ioFailure,
          recoveryArtifacts: await _recoveryArtifactsIncludingActive(
            directory: directory,
            activeFiles: [tmp, main, backup],
            knownArtifacts: recoveryArtifacts,
          ),
        );
      }
      return StorageLoadResult(
        data: backupAttempt.data,
        recoveryStatus: RecoveryStatus.restoredFromBackup,
        status: StorageLoadStatus.restored,
        recoveryArtifacts: recoveryArtifacts,
      );
    }

    final hasCorruptActiveFile = attempts.values.any(
      (attempt) => attempt.outcome == _Outcome.corrupt,
    );
    if (!hasCorruptActiveFile) {
      try {
        final existingArtifacts = await _existingRecoveryArtifacts(directory);
        if (existingArtifacts.isEmpty) {
          return const StorageLoadResult.empty();
        }
        return StorageLoadResult(
          data: null,
          recoveryStatus: RecoveryStatus.failedBackupRestore,
          status: StorageLoadStatus.corrupt,
          recoveryArtifacts: existingArtifacts,
        );
      } catch (_) {
        return const StorageLoadResult(
          data: null,
          recoveryStatus: RecoveryStatus.ioFailure,
          status: StorageLoadStatus.ioFailure,
        );
      }
    }

    try {
      final files = [main, backup, tmp];
      final expectedFiles = {for (final file in files) file: attempts[file]!};
      isolatedSourcePaths.addAll(
        files
            .where((file) => expectedFiles[file]!.outcome != _Outcome.missing)
            .map((file) => path.normalize(file.path)),
      );
      final artifacts = await _isolateActiveFiles(
        directory: directory,
        files: files,
        expectedFiles: expectedFiles,
      );
      final previousArtifacts = await _existingRecoveryArtifacts(directory);
      return StorageLoadResult(
        data: null,
        recoveryStatus: RecoveryStatus.failedBackupRestore,
        status: StorageLoadStatus.corrupt,
        recoveryArtifacts: {...previousArtifacts, ...artifacts}.toList()
          ..sort(),
      );
    } catch (_) {
      return StorageLoadResult(
        data: null,
        recoveryStatus: RecoveryStatus.ioFailure,
        status: StorageLoadStatus.ioFailure,
        recoveryArtifacts: await _recoveryArtifactsIncludingActive(
          directory: directory,
          activeFiles: [tmp, main, backup],
        ),
      );
    }
  }

  @override
  Future<void> save(AppData data) async {
    try {
      await _save(data);
    } on StorageWriteException {
      rethrow;
    } catch (error, stackTrace) {
      throw StorageWriteException(
        'Failed to persist AppData to disk.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _save(AppData data) async {
    final main = await _resolveFile();
    final tmp = File('${main.path}$_tempSuffix');
    final backup = File('${main.path}$_backupSuffix');

    // 1. 写入 .tmp 并 flush，确保数据真的落盘。
    final raf = await tmp.open(mode: FileMode.write);
    try {
      await raf.writeString(data.encode());
      await raf.flush();
    } finally {
      await raf.close();
    }

    // 2. 旋转：把现有主文件移到 .bak（覆盖旧 .bak），再把 .tmp 升为主文件。
    if (await main.exists()) {
      if (await backup.exists()) {
        await backup.delete();
      }
      await main.rename(backup.path);
    }
    await tmp.rename(main.path);
    await _bestEffortFlushDirectory(main.parent);
  }

  @override
  Future<String> filePath() async {
    final file = await _resolveFile();
    return file.path;
  }

  @override
  Future<Uint8List?> readRecoveryArtifact(String artifactPath) async {
    try {
      final main = await _resolveFile();
      final candidatePath = path.normalize(artifactPath);
      final activePaths = <String>{
        path.normalize(main.path),
        path.normalize('${main.path}$_backupSuffix'),
        path.normalize('${main.path}$_tempSuffix'),
      };
      final recoveryDirectory = path.dirname(candidatePath);
      final isIsolatedArtifact =
          path.equals(path.dirname(recoveryDirectory), main.parent.path) &&
          _recoveryDirectoryNamePattern.hasMatch(
            path.basename(recoveryDirectory),
          ) &&
          _isAllowedRecoveryArtifactName(path.basename(candidatePath)) &&
          await FileSystemEntity.type(recoveryDirectory, followLinks: false) ==
              FileSystemEntityType.directory;
      final isActiveArtifact = activePaths.any(
        (activePath) => path.equals(activePath, candidatePath),
      );
      if (!isActiveArtifact && !isIsolatedArtifact) return null;
      if (await FileSystemEntity.type(candidatePath, followLinks: false) !=
          FileSystemEntityType.file) {
        return null;
      }
      return File(candidatePath).readAsBytes();
    } catch (_) {
      return null;
    }
  }

  Future<File> _resolveFile() async {
    final directory = await _directoryProvider();
    final filePath = path.join(directory.path, _fileName);
    return File(filePath);
  }

  Future<void> _promoteTempToMain({
    required File tmp,
    required File main,
    required File backup,
    required _DecodeAttempt expectedTemp,
    required _DecodeAttempt expectedMain,
    required _DecodeAttempt expectedBackup,
  }) async {
    await _verifyExpectedState(tmp, expectedTemp);
    await _verifyExpectedState(main, expectedMain);
    await _verifyExpectedState(backup, expectedBackup);
    if (expectedMain.outcome == _Outcome.missing) {
      await tmp.rename(main.path);
      await _bestEffortFlushDirectory(main.parent);
      return;
    }
    if (expectedMain.outcome == _Outcome.success) {
      if (await backup.exists()) {
        await backup.delete();
      }
      await main.rename(backup.path);
    } else {
      await main.delete();
    }
    await tmp.rename(main.path);
    await _bestEffortFlushDirectory(main.parent);
  }

  Future<void> _restoreBackupToMain({
    required File backup,
    required File main,
    required _DecodeAttempt expectedBackup,
    required _DecodeAttempt expectedMain,
    required _DecodeAttempt expectedTemp,
  }) async {
    await _verifyExpectedState(backup, expectedBackup);
    await _verifyExpectedState(main, expectedMain);
    await _verifyExpectedState(File('${main.path}$_tempSuffix'), expectedTemp);
    final tmp = File('${main.path}$_tempSuffix');
    if (await tmp.exists()) {
      await tmp.delete();
    }
    await backup.copy(tmp.path);
    if (await main.exists()) {
      await main.delete();
    }
    await tmp.rename(main.path);
    await _bestEffortFlushDirectory(main.parent);
  }

  Future<_DecodeAttempt> _tryDecode(File file) async {
    List<int>? snapshot;
    try {
      final type = await FileSystemEntity.type(file.path);
      if (type == FileSystemEntityType.notFound) {
        return const _DecodeAttempt(_Outcome.missing, null);
      }
      if (type != FileSystemEntityType.file) {
        return const _DecodeAttempt(_Outcome.ioFailure, null);
      }
      final bytes = await (_fileReader?.call(file) ?? file.readAsBytes());
      snapshot = List<int>.unmodifiable(bytes);
      final content = utf8.decode(bytes, allowMalformed: false);
      if (content.trim().isEmpty) {
        return _DecodeAttempt(_Outcome.corrupt, null, snapshot);
      }
      final data = AppData.decodeStorageSnapshot(content);
      return _DecodeAttempt(_Outcome.success, data, snapshot);
    } on UnsupportedSchemaVersionException {
      return _DecodeAttempt(_Outcome.unsupportedVersion, null, snapshot);
    } on FileSystemException {
      return const _DecodeAttempt(_Outcome.ioFailure, null);
    } on FormatException {
      return _DecodeAttempt(_Outcome.corrupt, null, snapshot);
    } catch (_) {
      return _DecodeAttempt(_Outcome.corrupt, null, snapshot);
    }
  }

  List<String> _pathsWithOutcome(
    Map<File, _DecodeAttempt> attempts,
    _Outcome outcome,
  ) {
    return [
      for (final entry in attempts.entries)
        if (entry.value.outcome == outcome) entry.key.path,
    ];
  }

  AppData? _readableDataBeforeBlockingCandidate(List<_DecodeAttempt> attempts) {
    for (final attempt in attempts) {
      switch (attempt.outcome) {
        case _Outcome.success:
          return attempt.data;
        case _Outcome.ioFailure || _Outcome.unsupportedVersion:
          return null;
        case _Outcome.missing || _Outcome.corrupt:
          continue;
      }
    }
    return null;
  }

  Future<List<String>> _isolateActiveFiles({
    required Directory directory,
    required List<File> files,
    required Map<File, _DecodeAttempt> expectedFiles,
  }) async {
    final recoveryDirectory = await _createRecoveryDirectory(directory);
    final artifacts = <String>[];
    for (final file in files) {
      // Verify each source immediately before moving it. This prevents a
      // changed file from being moved while preserving already-isolated
      // sources when a later source changes during recovery.
      await _verifyExpectedState(file, expectedFiles[file]!);
      final type = await FileSystemEntity.type(file.path);
      if (type == FileSystemEntityType.notFound) continue;
      if (type != FileSystemEntityType.file) {
        throw FileSystemException(
          'Recovery source is not a regular file.',
          file.path,
        );
      }
      final target = path.join(
        recoveryDirectory.path,
        path.basename(file.path),
      );
      await file.rename(target);
      artifacts.add(target);
    }
    if (artifacts.isEmpty) {
      await recoveryDirectory.delete();
    }
    return artifacts;
  }

  _DecodeAttempt _expectedAttempt(
    File file,
    Map<File, _DecodeAttempt> attempts,
    Set<String> isolatedSourcePaths,
  ) {
    if (isolatedSourcePaths.contains(path.normalize(file.path))) {
      return const _DecodeAttempt(_Outcome.missing, null);
    }
    return attempts[file]!;
  }

  Future<void> _verifyExpectedState(File file, _DecodeAttempt expected) async {
    final type = await FileSystemEntity.type(file.path);
    if (expected.outcome == _Outcome.missing) {
      if (type != FileSystemEntityType.notFound) {
        throw const _StaleStorageSnapshotException();
      }
      return;
    }
    if (type != FileSystemEntityType.file || expected.bytes == null) {
      throw const _StaleStorageSnapshotException();
    }
    final current = await (_fileReader?.call(file) ?? file.readAsBytes());
    if (!_sameBytes(current, expected.bytes!)) {
      throw const _StaleStorageSnapshotException();
    }
  }

  bool _sameBytes(List<int> first, List<int> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index += 1) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }

  Future<Directory> _createRecoveryDirectory(Directory parent) async {
    final stamp = _clock().toUtc().toIso8601String().replaceAll(
      RegExp(r'[-:.]'),
      '',
    );
    var suffix = 0;
    while (true) {
      final name =
          '$_recoveryDirectoryPrefix$stamp${suffix == 0 ? '' : '_$suffix'}';
      final candidate = Directory(path.join(parent.path, name));
      if (!await candidate.exists()) {
        return candidate.create();
      }
      suffix += 1;
    }
  }

  Future<List<String>> _existingRecoveryArtifacts(Directory parent) async {
    if (!await parent.exists()) return const [];
    final artifacts = <String>[];
    await for (final entity in parent.list(followLinks: false)) {
      if (entity is! Directory ||
          !_recoveryDirectoryNamePattern.hasMatch(path.basename(entity.path))) {
        continue;
      }
      await for (final artifact in entity.list(followLinks: false)) {
        if (artifact is File &&
            _isAllowedRecoveryArtifactName(path.basename(artifact.path))) {
          artifacts.add(artifact.path);
        }
      }
    }
    artifacts.sort();
    return artifacts;
  }

  Future<List<String>> _safeExistingRecoveryArtifacts(Directory parent) async {
    try {
      return await _existingRecoveryArtifacts(parent);
    } catch (_) {
      return const [];
    }
  }

  Future<List<String>> _safeExistingActivePaths(List<File> files) async {
    final paths = <String>[];
    for (final file in files) {
      try {
        if (await FileSystemEntity.type(file.path) !=
            FileSystemEntityType.notFound) {
          paths.add(file.path);
        }
      } catch (_) {
        paths.add(file.path);
      }
    }
    return paths;
  }

  Future<List<String>> _recoveryArtifactsIncludingActive({
    required Directory directory,
    required List<File> activeFiles,
    Iterable<String> knownArtifacts = const <String>[],
  }) async {
    final artifacts = <String>{
      ...knownArtifacts,
      ...await _safeExistingRecoveryArtifacts(directory),
      ...await _safeExistingActivePaths(activeFiles),
    }.toList()..sort();
    return artifacts;
  }

  bool _isAllowedRecoveryArtifactName(String name) {
    return name == _fileName ||
        name == '$_fileName$_backupSuffix' ||
        name == '$_fileName$_tempSuffix';
  }

  Future<void> _bestEffortFlushDirectory(Directory directory) async {
    if (Platform.isWindows) return;
    RandomAccessFile? handle;
    try {
      handle = await File(directory.path).open(mode: FileMode.read);
      await handle.flush();
    } catch (_) {
      // Directory fsync is unavailable on some Dart/platform combinations.
    } finally {
      try {
        await handle?.close();
      } catch (_) {
        // Closing a directory handle is part of the same best-effort flush.
      }
    }
  }
}

enum _Outcome { success, missing, corrupt, ioFailure, unsupportedVersion }

class _DecodeAttempt {
  const _DecodeAttempt(this.outcome, this.data, [this.bytes]);

  final _Outcome outcome;
  final AppData? data;
  final List<int>? bytes;
}

class _StaleStorageSnapshotException implements Exception {
  const _StaleStorageSnapshotException();
}
