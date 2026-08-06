import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'school_site_store.dart';

class PlatformSchoolSiteStore extends SchoolSiteStore {
  PlatformSchoolSiteStore({
    this._directoryProvider,
    this._beforeMainReplace,
    this._afterMainReplace,
    this._fileReader,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       super.base();

  static const _fileName = 'Sked_school_sites.json';
  static const _backupSuffix = '.bak';
  static const _tempSuffix = '.tmp';
  static const _failedTempSuffix = '.tmp.failed';
  static const _recoveryDirectoryPrefix = 'Sked_school_sites_recovery_';
  static final _recoveryDirectoryNamePattern = RegExp(
    r'^Sked_school_sites_recovery_\d{8}T\d{9}(?:\d{3})?Z(?:_\d+)?$',
  );
  static Future<void> _writeTail = Future<void>.value();
  static var _generation = 0;
  static final Map<String, SchoolSiteStoreRecoveryBlockedException>
  _writeBlocks = {};

  final Future<Directory> Function()? _directoryProvider;
  final Future<void> Function()? _beforeMainReplace;
  final Future<void> Function()? _afterMainReplace;
  final Future<List<int>> Function(File)? _fileReader;
  final DateTime Function() _clock;

  @override
  Future<String?> load() async {
    final result = await loadResult();
    if (result.hasReadFailures) {
      throw SchoolSiteStoreReadException(result.issues);
    }
    if (result.candidates.isEmpty) {
      return null;
    }
    final first = result.candidates.first;
    await first.promote();
    return first.source;
  }

  @override
  Future<List<SchoolSiteStoreCandidate>> loadCandidates() async {
    return (await loadResult()).candidates;
  }

  @override
  Future<SchoolSiteStoreLoadResult> loadResult() => _enqueue(_loadResultNow);

  Future<SchoolSiteStoreLoadResult> _loadResultNow() async {
    final file = await _resolveFile();
    final tmp = File('${file.path}$_tempSuffix');
    final backup = File('${file.path}$_backupSuffix');
    final failedTemp = File('${file.path}$_failedTempSuffix');
    final generation = _generation;
    final reads = await Future.wait([
      _readArtifact(
        tmp,
        SchoolSiteStoreArtifact.temporary,
        promoteWithContext: (expectedSource, preservePrimaryAsBackup) =>
            _enqueue(
              () => _promoteTempToMain(
                tmp: tmp,
                main: file,
                backup: backup,
                expectedSource: expectedSource,
                expectedGeneration: generation,
                preservePrimaryAsBackup: preservePrimaryAsBackup,
              ),
            ),
      ),
      _readArtifact(
        file,
        SchoolSiteStoreArtifact.primary,
        promote: (expectedSource) => _enqueue(
          () => _confirmPrimaryCandidate(
            main: file,
            expectedSource: expectedSource,
            expectedGeneration: generation,
          ),
        ),
      ),
      _readArtifact(
        backup,
        SchoolSiteStoreArtifact.backup,
        promote: (expectedSource) => _enqueue(
          () => _restoreBackupToMain(
            backup: backup,
            main: file,
            expectedSource: expectedSource,
            expectedGeneration: generation,
          ),
        ),
      ),
    ]);
    final failedTempSnapshot = await _readFileSnapshot(failedTemp);
    final existingRecoveryArtifacts = await _safeExistingRecoveryArtifacts(
      file.parent,
    );
    final activeArtifacts = reads
        .where((read) => read.exists)
        .map((read) => read.path)
        .nonNulls
        .toList();
    if (failedTempSnapshot.exists) {
      activeArtifacts.add(failedTemp.path);
    }
    final hasActiveArtifacts = activeArtifacts.isNotEmpty;
    final candidates = reads.map((read) => read.candidate).nonNulls.toList();
    final recoveryIssues = <SchoolSiteStoreIssue>[
      ...reads.map((read) => read.issue).nonNulls,
      if (failedTempSnapshot.exists)
        SchoolSiteStoreIssue(
          artifact: SchoolSiteStoreArtifact.temporary,
          type: SchoolSiteStoreIssueType.recoveryArtifact,
          error: SchoolSiteStoreRecoveryArtifactException(failedTemp.path),
        ),
    ];
    // Keep an explicit snapshot for every active path, including files that
    // were missing during the read. Recovery must reject a file that appears
    // after this load rather than treating it as an empty slot.
    final expectedFiles = <String, _FileSnapshot>{
      path.normalize(tmp.path): _FileSnapshot(
        exists: reads[0].exists,
        bytes: reads[0].bytes,
      ),
      path.normalize(file.path): _FileSnapshot(
        exists: reads[1].exists,
        bytes: reads[1].bytes,
      ),
      path.normalize(backup.path): _FileSnapshot(
        exists: reads[2].exists,
        bytes: reads[2].bytes,
      ),
      path.normalize(failedTemp.path): failedTempSnapshot,
    };
    final storageKey = _storageKey(file);
    // A failed temporary snapshot is the only evidence of a write that could
    // not be rolled back. Keep writes blocked until the snapshot has been
    // explicitly isolated, even when the committed main is still readable.
    if (failedTempSnapshot.exists) {
      _writeBlocks.putIfAbsent(
        storageKey,
        SchoolSiteStoreRecoveryBlockedException.new,
      );
    } else if (!hasActiveArtifacts && recoveryIssues.isEmpty) {
      if (existingRecoveryArtifacts.isEmpty) {
        _writeBlocks.remove(storageKey);
      } else {
        _writeBlocks.putIfAbsent(
          storageKey,
          SchoolSiteStoreRecoveryBlockedException.new,
        );
      }
    } else if (hasActiveArtifacts && candidates.isEmpty) {
      _writeBlocks.putIfAbsent(
        storageKey,
        SchoolSiteStoreRecoveryBlockedException.new,
      );
    }
    return SchoolSiteStoreLoadResult(
      candidates: candidates,
      issues: recoveryIssues,
      hasArtifacts: hasActiveArtifacts,
      recoveryArtifacts: {
        ...existingRecoveryArtifacts,
        ...activeArtifacts,
      }.toList()..sort(),
      historicalRecoveryArtifacts: existingRecoveryArtifacts,
      isolateForRecovery: () => _enqueue(
        () => _isolateForRecoveryNow(
          expectedGeneration: generation,
          expectedFiles: expectedFiles,
        ),
      ),
    );
  }

  @override
  Future<void> save(String source) => _enqueue(() => _saveNow(source));

  @override
  Future<void> saveAfterRecovery(String source) =>
      _enqueue(() => _saveNow(source, allowRecoveryBlocked: true));

  @override
  Future<List<String>> isolateForRecovery() => _enqueue(_isolateForRecoveryNow);

  Future<void> _saveNow(
    String source, {
    bool allowRecoveryBlocked = false,
  }) async {
    final file = await _resolveFile();
    final storageKey = _storageKey(file);
    final writeBlock = _writeBlocks[storageKey];
    if (!allowRecoveryBlocked && writeBlock != null) {
      throw writeBlock;
    }
    final tmp = File('${file.path}$_tempSuffix');
    final backup = File('${file.path}$_backupSuffix');
    var ownsTemp = false;
    var hadMain = false;
    var backupReady = false;
    var mainReplaceAttempted = false;
    try {
      final tmpType = await _regularFileOrMissing(tmp);
      final mainType = await _regularFileOrMissing(file);
      await _regularFileOrMissing(backup);
      if (tmpType == FileSystemEntityType.file) {
        await tmp.delete();
      }
      _generation += 1;
      final raf = await tmp.open(mode: FileMode.write);
      ownsTemp = true;
      try {
        await raf.writeString(source);
        await raf.flush();
      } finally {
        await raf.close();
      }

      hadMain = mainType == FileSystemEntityType.file;
      if (hadMain) {
        await _copyAndFlush(file, backup);
        backupReady = true;
        await _flushParentDirectory(file);
      }
      await _beforeMainReplace?.call();
      mainReplaceAttempted = true;
      await _copyAndFlush(tmp, file);
      await _afterMainReplace?.call();
      await _discardOwnedTemp(tmp);
      await _flushParentDirectory(file);
      _writeBlocks.remove(storageKey);
    } catch (error, stackTrace) {
      Object? rollbackError;
      StackTrace? rollbackStackTrace;

      Future<void> attemptRollback(Future<void> Function() action) async {
        try {
          await action();
        } catch (caught, caughtStackTrace) {
          rollbackError ??= caught;
          rollbackStackTrace ??= caughtStackTrace;
        }
      }

      if (mainReplaceAttempted) {
        await attemptRollback(() async {
          if (hadMain && backupReady) {
            await _copyAndFlush(backup, file);
          } else if (!hadMain) {
            final currentType = await _regularFileOrMissing(file);
            if (currentType == FileSystemEntityType.file) {
              await file.delete();
            }
          }
        });
      }
      if (ownsTemp) {
        await attemptRollback(() => _discardOwnedTemp(tmp));
      }
      await attemptRollback(() => _flushParentDirectory(file));
      if (rollbackError != null) {
        final blocked = SchoolSiteStoreStateUnknownException(
          writeError: error,
          rollbackError: rollbackError!,
        );
        _writeBlocks[storageKey] = blocked;
        Error.throwWithStackTrace(blocked, rollbackStackTrace!);
      }
      Error.throwWithStackTrace(
        SchoolSiteStoreWriteException(
          'Failed to persist the school-site update.',
          cause: error,
          stackTrace: stackTrace,
        ),
        stackTrace,
      );
    }
  }

  Future<void> _discardOwnedTemp(File tmp) async {
    final type = await _regularFileOrMissing(tmp);
    if (type == FileSystemEntityType.notFound) return;
    try {
      await tmp.delete();
    } catch (_) {
      final failed = File('${tmp.path}.failed');
      final failedType = await _regularFileOrMissing(failed);
      if (failedType == FileSystemEntityType.file) {
        await failed.delete();
      }
      await tmp.rename(failed.path);
    }
  }

  @override
  Future<String?> filePath() async {
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
        path.normalize('${main.path}$_failedTempSuffix'),
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
    final directoryProvider =
        _directoryProvider ?? getApplicationDocumentsDirectory;
    final directory = await directoryProvider();
    return File(path.join(directory.path, _fileName));
  }

  Future<List<String>> _isolateForRecoveryNow({
    int? expectedGeneration,
    Map<String, _FileSnapshot>? expectedFiles,
  }) async {
    final main = await _resolveFile();
    if (expectedGeneration != null && _generation != expectedGeneration) {
      throw const SchoolSiteStoreStaleCandidateException();
    }
    final storageKey = _storageKey(main);
    _writeBlocks.putIfAbsent(
      storageKey,
      SchoolSiteStoreRecoveryBlockedException.new,
    );
    final files = [
      main,
      File('${main.path}$_backupSuffix'),
      File('${main.path}$_tempSuffix'),
      File('${main.path}$_failedTempSuffix'),
    ];
    final existingFiles = <File>[];
    for (final file in files) {
      final expected = expectedFiles?[path.normalize(file.path)];
      if (expectedFiles != null &&
          (expected == null || !await _matchesSnapshot(file, expected))) {
        throw const SchoolSiteStoreStaleCandidateException();
      }
      final type = await FileSystemEntity.type(file.path, followLinks: false);
      if (type == FileSystemEntityType.notFound) continue;
      if (type != FileSystemEntityType.file) {
        throw FileSystemException(
          'School-site recovery source is not a regular file.',
          file.path,
        );
      }
      existingFiles.add(file);
    }
    if (existingFiles.isNotEmpty) {
      _generation += 1;
      final recoveryDirectory = await _createRecoveryDirectory(main.parent);
      for (final file in existingFiles) {
        await file.rename(
          path.join(recoveryDirectory.path, path.basename(file.path)),
        );
      }
      await _flushParentDirectory(main);
    }
    final artifacts = await _existingRecoveryArtifacts(main.parent);
    if (artifacts.isEmpty) {
      _writeBlocks.remove(storageKey);
    }
    return artifacts;
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
    if (!await parent.exists()) return const <String>[];
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
      return const <String>[];
    }
  }

  Future<_ArtifactRead> _readArtifact(
    File file,
    SchoolSiteStoreArtifact artifact, {
    Future<void> Function(String expectedSource)? promote,
    Future<void> Function(String expectedSource, bool preservePrimaryAsBackup)?
    promoteWithContext,
  }) async {
    try {
      final type = await FileSystemEntity.type(file.path, followLinks: false);
      if (type == FileSystemEntityType.notFound) {
        return const _ArtifactRead.missing();
      }
      if (type != FileSystemEntityType.file) {
        throw FileSystemException(
          'School-site snapshot is not a regular file.',
          file.path,
        );
      }
      final bytes = await (_fileReader?.call(file) ?? file.readAsBytes());
      final snapshot = List<int>.unmodifiable(bytes);
      try {
        final source = utf8.decode(snapshot, allowMalformed: false);
        return _ArtifactRead.candidate(
          SchoolSiteStoreCandidate(
            source: source,
            artifact: artifact,
            promote: promote == null ? null : () => promote(source),
            promoteWithContext: promoteWithContext == null
                ? null
                : (preservePrimaryAsBackup) =>
                      promoteWithContext(source, preservePrimaryAsBackup),
          ),
          file.path,
          snapshot,
        );
      } on FormatException catch (error, stackTrace) {
        return _ArtifactRead.issue(
          SchoolSiteStoreIssue(
            artifact: artifact,
            type: SchoolSiteStoreIssueType.invalidEncoding,
            error: error,
            stackTrace: stackTrace,
          ),
          file.path,
          snapshot,
        );
      }
    } catch (error, stackTrace) {
      return _ArtifactRead.issue(
        SchoolSiteStoreIssue(
          artifact: artifact,
          type: SchoolSiteStoreIssueType.readFailure,
          error: error,
          stackTrace: stackTrace,
        ),
        file.path,
        null,
      );
    }
  }

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final result = _writeTail.then((_) => action());
    _writeTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<_FileSnapshot> _readFileSnapshot(File file) async {
    try {
      final type = await FileSystemEntity.type(file.path, followLinks: false);
      if (type == FileSystemEntityType.notFound) {
        return const _FileSnapshot.missing();
      }
      if (type != FileSystemEntityType.file) {
        return const _FileSnapshot.exists();
      }
      final bytes = await (_fileReader?.call(file) ?? file.readAsBytes());
      return _FileSnapshot.exists(List<int>.unmodifiable(bytes));
    } catch (_) {
      return const _FileSnapshot.exists();
    }
  }

  Future<bool> _matchesSnapshot(File file, _FileSnapshot expected) async {
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (!expected.exists) return type == FileSystemEntityType.notFound;
    if (type != FileSystemEntityType.file || expected.bytes == null) {
      return false;
    }
    final bytes = await (_fileReader?.call(file) ?? file.readAsBytes());
    if (bytes.length != expected.bytes!.length) return false;
    for (var index = 0; index < bytes.length; index += 1) {
      if (bytes[index] != expected.bytes![index]) return false;
    }
    return true;
  }

  Future<void> _promoteTempToMain({
    required File tmp,
    required File main,
    required File backup,
    required String expectedSource,
    required int expectedGeneration,
    required bool preservePrimaryAsBackup,
  }) async {
    await _verifyCandidate(
      tmp,
      expectedSource: expectedSource,
      expectedGeneration: expectedGeneration,
    );
    final mainType = await _regularFileOrMissing(main);
    if (preservePrimaryAsBackup) {
      await _regularFileOrMissing(backup);
    }
    _generation += 1;
    if (preservePrimaryAsBackup && mainType == FileSystemEntityType.file) {
      await _copyAndFlush(main, backup);
    }
    await _copyAndFlush(tmp, main);
    await _discardOwnedTemp(tmp);
    await _flushParentDirectory(main);
    _writeBlocks.remove(_storageKey(main));
  }

  Future<void> _restoreBackupToMain({
    required File backup,
    required File main,
    required String expectedSource,
    required int expectedGeneration,
  }) async {
    await _verifyCandidate(
      backup,
      expectedSource: expectedSource,
      expectedGeneration: expectedGeneration,
    );
    final tmp = File('${main.path}$_tempSuffix');
    final tmpType = await _regularFileOrMissing(tmp);
    final mainType = await _regularFileOrMissing(main);
    _generation += 1;
    if (tmpType == FileSystemEntityType.file) {
      await tmp.delete();
    }
    await _copyAndFlush(backup, tmp);
    if (mainType == FileSystemEntityType.file) {
      await main.delete();
    }
    await tmp.rename(main.path);
    await _flushParentDirectory(main);
    _writeBlocks.remove(_storageKey(main));
  }

  Future<void> _confirmPrimaryCandidate({
    required File main,
    required String expectedSource,
    required int expectedGeneration,
  }) async {
    await _verifyCandidate(
      main,
      expectedSource: expectedSource,
      expectedGeneration: expectedGeneration,
    );
    _writeBlocks.remove(_storageKey(main));
  }

  Future<void> _verifyCandidate(
    File file, {
    required String expectedSource,
    required int expectedGeneration,
  }) async {
    if (_generation != expectedGeneration) {
      throw const SchoolSiteStoreStaleCandidateException();
    }
    final type = await _regularFileOrMissing(file);
    if (type != FileSystemEntityType.file) {
      throw const SchoolSiteStoreStaleCandidateException();
    }
    final bytes = await (_fileReader?.call(file) ?? file.readAsBytes());
    final source = utf8.decode(bytes, allowMalformed: false);
    if (source != expectedSource) {
      throw const SchoolSiteStoreStaleCandidateException();
    }
  }

  Future<FileSystemEntityType> _regularFileOrMissing(File file) async {
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (type != FileSystemEntityType.file &&
        type != FileSystemEntityType.notFound) {
      throw FileSystemException(
        'School-site storage path is not a regular file.',
        file.path,
      );
    }
    return type;
  }

  String _storageKey(File main) {
    final normalized = path.normalize(path.absolute(main.path));
    return Platform.isWindows ? normalized.toLowerCase() : normalized;
  }

  Future<void> _copyAndFlush(File source, File target) async {
    await source.copy(target.path);
    await _flushFile(target);
  }

  Future<void> _flushFile(File file) async {
    final raf = await file.open(mode: FileMode.append);
    try {
      await raf.flush();
    } finally {
      await raf.close();
    }
  }

  bool _isAllowedRecoveryArtifactName(String name) {
    return name == _fileName ||
        name == '$_fileName$_backupSuffix' ||
        name == '$_fileName$_tempSuffix' ||
        name == '$_fileName$_failedTempSuffix';
  }

  Future<void> _flushParentDirectory(File file) async {
    if (!Platform.isLinux && !Platform.isMacOS) {
      return;
    }
    RandomAccessFile? raf;
    try {
      raf = await File(path.dirname(file.path)).open(mode: FileMode.read);
      await raf.flush();
    } catch (_) {
      // Directory fsync is best-effort; some platforms/filesystems reject it.
    } finally {
      try {
        await raf?.close();
      } catch (_) {
        // Closing a directory handle is part of the same best-effort flush.
      }
    }
  }
}

class _ArtifactRead {
  const _ArtifactRead._({
    this.candidate,
    this.issue,
    required this.exists,
    this.path,
    this.bytes,
  });

  const _ArtifactRead.missing()
    : this._(
        candidate: null,
        issue: null,
        exists: false,
        path: null,
        bytes: null,
      );

  const _ArtifactRead.candidate(
    SchoolSiteStoreCandidate candidate,
    String path,
    List<int> bytes,
  ) : this._(
        candidate: candidate,
        issue: null,
        exists: true,
        path: path,
        bytes: bytes,
      );

  const _ArtifactRead.issue(
    SchoolSiteStoreIssue issue,
    String path,
    List<int>? bytes,
  ) : this._(
        candidate: null,
        issue: issue,
        exists: true,
        path: path,
        bytes: bytes,
      );

  final SchoolSiteStoreCandidate? candidate;
  final SchoolSiteStoreIssue? issue;
  final bool exists;
  final String? path;
  final List<int>? bytes;
}

class _FileSnapshot {
  const _FileSnapshot({required this.exists, this.bytes});

  const _FileSnapshot.missing() : this(exists: false);

  const _FileSnapshot.exists([this.bytes]) : exists = true;

  final bool exists;
  final List<int>? bytes;
}
