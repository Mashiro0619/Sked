import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

import '../data/migrations/migration.dart';
import '../l10n/app_locale.dart';
import 'app_backup_restore_journal.dart';
import 'app_storage_layout_io.dart';

/// Native file-backed implementation of the pending app-backup journal.
///
/// The journal deliberately lives beside the two user-data files.  It keeps
/// the transaction protocol owned by the app instead of placing its durable
/// state in a platform-specific preferences database.
class FileAppBackupRestoreJournal extends AppBackupRestoreJournal {
  factory FileAppBackupRestoreJournal({
    AppStorageLayout? layout,
    Future<Directory> Function()? directoryProvider,
    Future<List<int>> Function(File)? fileReader,
    Future<void> Function(File)? fileDeleter,
    Stream<FileSystemEntity> Function(Directory)? directoryLister,
  }) {
    return FileAppBackupRestoreJournal._(
      layout: _resolveLayout(layout, directoryProvider),
      fileReader: fileReader,
      fileDeleter: fileDeleter,
      directoryLister: directoryLister,
    );
  }

  FileAppBackupRestoreJournal._({
    required this._layout,
    this._fileReader,
    this._fileDeleter,
    Stream<FileSystemEntity> Function(Directory)? directoryLister,
  }) : _directoryLister =
           directoryLister ??
           ((directory) => directory.list(followLinks: false)),
       super.base();

  static const _fileName = AppStorageLayout.backupRestoreJournalFileName;
  static const _tmpSuffix = AppStorageLayout.temporarySuffix;
  static const _backupSuffix = AppStorageLayout.backupSuffix;
  static const _artifactPrefix = 'app-storage://backup-restore/';
  static const _recoveryDirectoryPrefix =
      AppStorageLayout.backupRestoreRecoveryDirectoryPrefix;
  static final _recoveryDirectoryPattern = RegExp(
    '^${RegExp.escape(_recoveryDirectoryPrefix)}[a-f0-9]{64}\$',
  );
  final AppStorageLayout _layout;
  final Future<List<int>> Function(File)? _fileReader;
  final Future<void> Function(File)? _fileDeleter;
  final Stream<FileSystemEntity> Function(Directory) _directoryLister;
  Future<void> _operationTail = Future<void>.value();

  static AppStorageLayout _resolveLayout(
    AppStorageLayout? layout,
    Future<Directory> Function()? directoryProvider,
  ) {
    if (layout != null && directoryProvider != null) {
      throw ArgumentError(
        'Pass either layout or directoryProvider, but not both.',
      );
    }
    return layout ?? AppStorageLayout(directoryProvider: directoryProvider);
  }

  @override
  String get pendingArtifactPath => '$_artifactPrefix$_fileName';

  @override
  Future<AppBackupRestoreJournalLoadResult> load({
    String localeCode = defaultLocaleCode,
  }) => _enqueue(() => _loadNow(localeCode: localeCode));

  @override
  Future<String?> read() => _enqueue(() async {
    final loaded = await _loadNow(localeCode: defaultLocaleCode);
    if (loaded.status == AppBackupRestoreJournalLoadStatus.ioFailure) {
      throw AppBackupRestoreJournalException(
        'Unable to read the pending app-backup restore journal.',
        cause: loaded.error,
      );
    }
    return loaded.source;
  });

  @override
  Future<void> write(String source) => _enqueue(() async {
    try {
      await _writeAtomic(source);
    } on AppBackupRestoreJournalException {
      rethrow;
    } catch (error) {
      throw AppBackupRestoreJournalException(
        'Unable to persist the pending app-backup restore journal.',
        cause: error,
      );
    }
  });

  @override
  Future<void> clear() => _enqueue(() async {
    BackupRestoreJournalStoragePaths? storagePaths;
    _JournalFiles? files;
    Object? operationError;
    try {
      storagePaths = await _layout.backupRestoreJournalPaths();
      files = _journalFiles(storagePaths);
      // Remove older fallbacks before the terminal main snapshot. If cleanup
      // stops halfway, no stale prepared/dataCommitted candidate should become
      // the first readable journal on the next launch.
      for (final file in files.clearOrder) {
        final type = await FileSystemEntity.type(file.path, followLinks: false);
        if (type == FileSystemEntityType.notFound) continue;
        if (type != FileSystemEntityType.file) {
          throw FileSystemException(
            'Journal cleanup candidate is not a regular file.',
            file.path,
          );
        }
        await _delete(file);
      }
      await _bestEffortFlushDirectory(storagePaths.root);
    } catch (error) {
      operationError = error;
    }

    try {
      storagePaths ??= await _layout.backupRestoreJournalPaths();
      files ??= _journalFiles(storagePaths);
      final retained = <String>[];
      for (final file in files.all) {
        final type = await FileSystemEntity.type(file.path, followLinks: false);
        if (type != FileSystemEntityType.notFound) {
          retained.add(path.basename(file.path));
        }
      }
      if (retained.isEmpty) return;
      throw StateError(
        'Storage retained app-backup restore journal candidates: '
        '${retained.join(', ')}.',
      );
    } catch (verificationError) {
      throw AppBackupRestoreJournalStateUnknownException(
        operationError: operationError ?? 'Journal cleanup reported success.',
        verificationError: verificationError,
      );
    }
  });

  @override
  Future<String> preserveForRecovery(String source) => _enqueue(() async {
    try {
      final root = (await _layout.backupRestoreJournalPaths()).root;
      final digest = sha256.convert(utf8.encode(source)).toString();
      final directory = await _prepareRecoveryDirectory(
        root,
        '$_recoveryDirectoryPrefix$digest',
      );
      final artifact = File(path.join(directory.path, _fileName));
      final artifactType = await _regularFileOrMissing(artifact);
      if (artifactType == FileSystemEntityType.file) {
        final existing = utf8.decode(
          await _readBytes(artifact),
          allowMalformed: false,
        );
        if (existing != source) {
          throw const AppBackupRestoreJournalException(
            'A restore-journal recovery artifact collision was detected.',
          );
        }
      } else {
        await _writeFileConfirmed(artifact, utf8.encode(source));
      }
      return _artifactUri(root, artifact);
    } on AppBackupRestoreJournalException {
      rethrow;
    } catch (error) {
      throw AppBackupRestoreJournalException(
        'Unable to preserve the invalid app-backup restore journal.',
        cause: error,
      );
    }
  });

  @override
  Future<List<String>> listRecoveryArtifacts() => _enqueue(() async {
    try {
      final root = (await _layout.backupRestoreJournalPaths()).root;
      return _existingRecoveryArtifacts(root);
    } catch (error) {
      throw AppBackupRestoreJournalException(
        'Unable to enumerate app-backup restore recovery artifacts.',
        cause: error,
      );
    }
  });

  @override
  Future<Uint8List?> readRecoveryArtifact(String artifactPath) =>
      _enqueue(() async {
        try {
          final root = (await _layout.backupRestoreJournalPaths()).root;
          final file = await _resolveArtifact(root, artifactPath);
          if (file == null) return null;
          return Uint8List.fromList(await _readBytes(file));
        } catch (error) {
          throw AppBackupRestoreJournalException(
            'Unable to read an app-backup restore recovery artifact.',
            cause: error,
          );
        }
      });

  Future<AppBackupRestoreJournalLoadResult> _loadNow({
    required String localeCode,
  }) async {
    late final BackupRestoreJournalStoragePaths storagePaths;
    try {
      storagePaths = await _layout.backupRestoreJournalPaths();
    } catch (error) {
      return AppBackupRestoreJournalLoadResult(
        status: AppBackupRestoreJournalLoadStatus.ioFailure,
        recoveryArtifacts: [pendingArtifactPath],
        error: error,
      );
    }

    final root = storagePaths.root;
    final files = _journalFiles(storagePaths);
    final recoveryArtifactScan = await _scanExistingRecoveryArtifacts(root);
    final historicalArtifacts = recoveryArtifactScan.artifacts;
    if (recoveryArtifactScan.error case final error?) {
      return AppBackupRestoreJournalLoadResult(
        status: AppBackupRestoreJournalLoadStatus.ioFailure,
        recoveryArtifacts: mergeAppBackupRestoreJournalRecoveryArtifacts([
          pendingArtifactPath,
          ...historicalArtifacts,
          ...await _safeActiveArtifactPaths(files.all),
        ]),
        error: error,
      );
    }
    final candidates = <_JournalCandidate>[];
    // A fully flushed temporary snapshot represents the newest attempted
    // transition. Prefer it to main, then fall back to the previous backup.
    for (final file in files.loadOrder) {
      candidates.add(await _readCandidate(file, localeCode: localeCode));
    }

    final ioFailure = candidates.where((item) => item.ioFailure).toList();
    if (ioFailure.isNotEmpty) {
      return AppBackupRestoreJournalLoadResult(
        status: AppBackupRestoreJournalLoadStatus.ioFailure,
        source: ioFailure.first.source,
        recoveryArtifacts: mergeAppBackupRestoreJournalRecoveryArtifacts([
          pendingArtifactPath,
          ...historicalArtifacts,
          ...candidates
              .where((item) => item.exists)
              .map((item) => _artifactUri(root, item.file)),
        ]),
        error: ioFailure.first.error,
      );
    }

    final unsupported = candidates.firstWhere(
      (item) => item.unsupported,
      orElse: () => _JournalCandidate.missing(files.main),
    );
    if (unsupported.unsupported) {
      return AppBackupRestoreJournalLoadResult(
        status: AppBackupRestoreJournalLoadStatus.unsupportedVersion,
        source: unsupported.source,
        recoveryArtifacts: mergeAppBackupRestoreJournalRecoveryArtifacts([
          pendingArtifactPath,
          ...historicalArtifacts,
          _artifactUri(root, unsupported.file),
        ]),
        error: unsupported.error,
      );
    }

    final corrupt = candidates.where((item) => item.corrupt).toList();
    final isolated = <String>[];
    for (final item in corrupt) {
      if (!item.exists) continue;
      try {
        isolated.add(await _isolateCandidate(root, item));
      } catch (error) {
        return AppBackupRestoreJournalLoadResult(
          status: AppBackupRestoreJournalLoadStatus.ioFailure,
          source: item.source,
          recoveryArtifacts: mergeAppBackupRestoreJournalRecoveryArtifacts([
            pendingArtifactPath,
            ...historicalArtifacts,
            _artifactUri(root, item.file),
            ...isolated,
          ]),
          error: error,
        );
      }
    }

    final valid = candidates.firstWhere(
      (item) => item.valid,
      orElse: () => _JournalCandidate.missing(files.main),
    );
    if (valid.valid) {
      try {
        if (!path.equals(valid.file.path, files.main.path)) {
          await _writeAtomic(valid.source!);
        }
      } catch (error) {
        return AppBackupRestoreJournalLoadResult(
          status: AppBackupRestoreJournalLoadStatus.ioFailure,
          source: valid.source,
          recoveryArtifacts: mergeAppBackupRestoreJournalRecoveryArtifacts([
            pendingArtifactPath,
            ...historicalArtifacts,
            ...isolated,
            ...await _safeActiveArtifactPaths(files.all),
          ]),
          error: error,
        );
      }
      return withAppBackupRestoreJournalRecoveryArtifacts(valid.result!, [
        ...historicalArtifacts,
        ...isolated,
      ]);
    }

    if (corrupt.isNotEmpty) {
      return AppBackupRestoreJournalLoadResult(
        status: AppBackupRestoreJournalLoadStatus.corrupt,
        source: corrupt
            .map((item) => item.source)
            .whereType<String>()
            .firstOrNull,
        recoveryArtifacts: mergeAppBackupRestoreJournalRecoveryArtifacts([
          pendingArtifactPath,
          ...historicalArtifacts,
          ...isolated,
        ]),
        error: corrupt.first.error,
      );
    }

    return AppBackupRestoreJournalLoadResult(
      status: AppBackupRestoreJournalLoadStatus.missing,
      recoveryArtifacts: historicalArtifacts,
    );
  }

  Future<_JournalCandidate> _readCandidate(
    File file, {
    required String localeCode,
  }) async {
    List<int>? bytes;
    try {
      final type = await FileSystemEntity.type(file.path, followLinks: false);
      if (type == FileSystemEntityType.notFound) {
        return _JournalCandidate.missing(file);
      }
      if (type != FileSystemEntityType.file) {
        return _JournalCandidate.ioFailure(
          file,
          error: FileSystemException(
            'Journal candidate is not a file.',
            file.path,
          ),
        );
      }
      bytes = await _readBytes(file);
      final source = utf8.decode(bytes, allowMalformed: false);
      try {
        final result = decodeAppBackupRestoreJournalSource(
          source,
          localeCode: localeCode,
          pendingArtifactPath: pendingArtifactPath,
        );
        return _JournalCandidate.valid(file, source, result);
      } on UnsupportedSchemaVersionException catch (error) {
        return _JournalCandidate.unsupported(file, source, error);
      } on UnsupportedAppBackupRestoreJournalVersionException catch (error) {
        return _JournalCandidate.unsupported(file, source, error);
      } on UnsupportedAppBackupRestoreJournalPhaseException catch (error) {
        return _JournalCandidate.unsupported(file, source, error);
      } catch (error, stackTrace) {
        return _JournalCandidate.corrupt(file, source, error, stackTrace);
      }
    } on FileSystemException catch (error, stackTrace) {
      return _JournalCandidate.ioFailure(
        file,
        error: error,
        stackTrace: stackTrace,
      );
    } on FormatException catch (error, stackTrace) {
      return _JournalCandidate.corrupt(
        file,
        bytes == null ? null : utf8.decode(bytes, allowMalformed: true),
        error,
        stackTrace,
        bytes: bytes,
      );
    } catch (error, stackTrace) {
      return _JournalCandidate.ioFailure(
        file,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _writeAtomic(String source) async {
    final storagePaths = await _layout.backupRestoreJournalPaths();
    final root = storagePaths.root;
    final files = _journalFiles(storagePaths);
    final bytes = utf8.encode(source);

    try {
      // Reject links and unexpected entity types before any write can follow
      // them outside the application storage root.
      await _regularFileOrMissing(files.main);
      await _regularFileOrMissing(files.temporary);
      await _regularFileOrMissing(files.backup);
      await _writeFileConfirmed(files.temporary, bytes);
      if (await _isRegularFile(files.main)) {
        if (await _isRegularFile(files.backup)) {
          await _delete(files.backup);
        }
        await files.main.rename(files.backup.path);
      }
      await files.temporary.rename(files.main.path);
      await _writeReadbackConfirmed(files.main, bytes);
      await _bestEffortFlushDirectory(root);
    } on AppBackupRestoreJournalStateUnknownException {
      rethrow;
    } catch (error) {
      throw AppBackupRestoreJournalStateUnknownException(
        operationError: error,
        verificationError: StateError(
          'The requested restore-journal snapshot could not be confirmed '
          'after a persistence failure.',
        ),
      );
    }
  }

  Future<void> _writeFileConfirmed(File file, List<int> bytes) async {
    await file.writeAsBytes(bytes, flush: true);
    await _writeReadbackConfirmed(file, bytes);
  }

  Future<void> _writeReadbackConfirmed(File file, List<int> expected) async {
    final actual = await _readBytes(file);
    if (!_sameBytes(actual, expected)) {
      throw AppBackupRestoreJournalStateUnknownException(
        operationError: 'Journal write completed.',
        verificationError: StateError('Journal read-back did not match.'),
      );
    }
  }

  Future<String> _isolateCandidate(
    Directory root,
    _JournalCandidate candidate,
  ) async {
    final bytes =
        candidate.bytes ??
        (candidate.source == null
            ? await _readBytes(candidate.file)
            : utf8.encode(candidate.source!));
    final digest = sha256.convert(bytes).toString();
    final recovery = await _prepareRecoveryDirectory(
      root,
      '$_recoveryDirectoryPrefix$digest',
    );
    final target = File(
      path.join(recovery.path, path.basename(candidate.file.path)),
    );
    final targetType = await _regularFileOrMissing(target);
    if (targetType == FileSystemEntityType.file) {
      if (!_sameBytes(await _readBytes(target), bytes)) {
        throw const AppBackupRestoreJournalException(
          'A restore-journal recovery artifact collision was detected.',
        );
      }
    } else {
      // Keep the corrupt active candidate as a durable marker until the
      // recovery owner explicitly reconciles or clears the journal. Moving it
      // away creates a crash window: if the process dies after this method
      // returns but before the provider records the recovery state, the next
      // launch would see only a historical artifact and incorrectly classify
      // the journal as missing (allowing writes to resume).
      await _writeFileConfirmed(target, bytes);
    }
    await _bestEffortFlushDirectory(root);
    return _artifactUri(root, target);
  }

  Future<List<String>> _existingRecoveryArtifacts(Directory root) async {
    final scan = await _scanExistingRecoveryArtifacts(root);
    final error = scan.error;
    if (error != null) {
      Error.throwWithStackTrace(error, scan.stackTrace!);
    }
    return scan.artifacts;
  }

  Future<_RecoveryArtifactScan> _scanExistingRecoveryArtifacts(
    Directory root,
  ) async {
    final artifacts = <String>[];
    try {
      await for (final entity in _directoryLister(root)) {
        if (await FileSystemEntity.type(entity.path, followLinks: false) !=
                FileSystemEntityType.directory ||
            !_recoveryDirectoryPattern.hasMatch(path.basename(entity.path))) {
          continue;
        }
        final directory = Directory(entity.path);
        await for (final child in _directoryLister(directory)) {
          if (await FileSystemEntity.type(child.path, followLinks: false) ==
                  FileSystemEntityType.file &&
              _isAllowedRecoveryFile(path.basename(child.path))) {
            artifacts.add(_artifactUri(root, File(child.path)));
          }
        }
      }
    } catch (error, stackTrace) {
      artifacts.sort();
      return _RecoveryArtifactScan.failure(
        List.unmodifiable(artifacts),
        error,
        stackTrace,
      );
    }
    artifacts.sort();
    return _RecoveryArtifactScan.success(List.unmodifiable(artifacts));
  }

  Future<List<String>> _safeActiveArtifactPaths(List<File> files) async {
    final result = <String>[];
    for (final file in files) {
      try {
        if (await FileSystemEntity.type(file.path, followLinks: false) !=
            FileSystemEntityType.notFound) {
          result.add(_artifactUri(file.parent, file));
        }
      } catch (_) {
        result.add(_artifactUri(file.parent, file));
      }
    }
    return result;
  }

  _JournalFiles _journalFiles(BackupRestoreJournalStoragePaths paths) {
    return _JournalFiles(
      main: paths.main,
      temporary: paths.temporary,
      backup: paths.backup,
    );
  }

  Future<File?> _resolveArtifact(Directory root, String artifactPath) async {
    if (!artifactPath.startsWith(_artifactPrefix)) return null;
    final relative = artifactPath.substring(_artifactPrefix.length);
    if (relative.isEmpty || relative.contains('\\')) return null;
    final segments = relative.split('/');
    if (segments.any(
      (segment) => segment.isEmpty || segment == '.' || segment == '..',
    )) {
      return null;
    }

    final isActive =
        segments.length == 1 && _isAllowedRecoveryFile(segments.first);
    final isIsolated =
        segments.length == 2 &&
        _recoveryDirectoryPattern.hasMatch(segments.first) &&
        _isAllowedRecoveryFile(segments.last);
    if (!isActive && !isIsolated) {
      return null;
    }

    final candidate = File(path.joinAll([root.path, ...segments]));
    final normalizedRoot = path.normalize(path.absolute(root.path));
    final normalizedCandidate = path.normalize(path.absolute(candidate.path));
    final relativeCandidate = path.relative(
      normalizedCandidate,
      from: normalizedRoot,
    );
    if (relativeCandidate == '..' ||
        relativeCandidate.startsWith('..${path.separator}')) {
      return null;
    }

    if (isIsolated &&
        await FileSystemEntity.type(
              path.dirname(candidate.path),
              followLinks: false,
            ) !=
            FileSystemEntityType.directory) {
      return null;
    }
    if (await FileSystemEntity.type(candidate.path, followLinks: false) !=
        FileSystemEntityType.file) {
      return null;
    }
    return candidate;
  }

  String _artifactUri(Directory root, File file) {
    final relative = path
        .relative(file.path, from: root.path)
        .replaceAll('\\', '/');
    return '$_artifactPrefix$relative';
  }

  Future<Directory> _prepareRecoveryDirectory(
    Directory root,
    String name,
  ) async {
    final directory = await _layout.recoveryDirectory(name);
    if (!path.equals(directory.parent.path, root.path)) {
      throw StateError(
        'App storage directory changed while resolving a recovery artifact.',
      );
    }
    var type = await FileSystemEntity.type(directory.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      await directory.create();
      type = await FileSystemEntity.type(directory.path, followLinks: false);
    }
    if (type != FileSystemEntityType.directory) {
      throw FileSystemException(
        'Restore-journal recovery path is not a regular directory.',
        directory.path,
      );
    }
    return directory;
  }

  Future<FileSystemEntityType> _regularFileOrMissing(File file) async {
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (type == FileSystemEntityType.notFound ||
        type == FileSystemEntityType.file) {
      return type;
    }
    throw FileSystemException(
      'Restore-journal path is not a regular file.',
      file.path,
    );
  }

  Future<bool> _isRegularFile(File file) async {
    return await FileSystemEntity.type(file.path, followLinks: false) ==
        FileSystemEntityType.file;
  }

  Future<List<int>> _readBytes(File file) {
    return _fileReader?.call(file) ?? file.readAsBytes();
  }

  Future<void> _delete(File file) {
    return _fileDeleter?.call(file) ?? file.delete();
  }

  Future<void> _bestEffortFlushDirectory(Directory directory) async {
    RandomAccessFile? handle;
    try {
      handle = await File(directory.path).open(mode: FileMode.read);
      await handle.flush();
    } catch (_) {
      // Directory fsync is not supported uniformly by Dart/platform hosts.
    } finally {
      try {
        await handle?.close();
      } catch (_) {
        // Closing a best-effort directory handle must not change the result.
      }
    }
  }

  bool _isAllowedRecoveryFile(String name) {
    return name == _fileName ||
        name == '$_fileName$_tmpSuffix' ||
        name == '$_fileName$_backupSuffix';
  }

  bool _sameBytes(List<int> first, List<int> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index += 1) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final result = _operationTail.then((_) => action());
    _operationTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }
}

class _JournalFiles {
  const _JournalFiles({
    required this.main,
    required this.temporary,
    required this.backup,
  });

  final File main;
  final File temporary;
  final File backup;

  List<File> get loadOrder => [temporary, main, backup];

  List<File> get clearOrder => [backup, temporary, main];

  List<File> get all => [main, temporary, backup];
}

class _RecoveryArtifactScan {
  const _RecoveryArtifactScan.success(this.artifacts)
    : error = null,
      stackTrace = null;

  const _RecoveryArtifactScan.failure(
    this.artifacts,
    this.error,
    this.stackTrace,
  );

  final List<String> artifacts;
  final Object? error;
  final StackTrace? stackTrace;
}

class _JournalCandidate {
  const _JournalCandidate._({
    required this.file,
    this.source,
    this.bytes,
    this.result,
    this.error,
    this.stackTrace,
    this.status = _JournalCandidateStatus.missing,
  });

  factory _JournalCandidate.missing(File file) =>
      _JournalCandidate._(file: file);

  factory _JournalCandidate.valid(
    File file,
    String source,
    AppBackupRestoreJournalLoadResult result,
  ) => _JournalCandidate._(
    file: file,
    source: source,
    bytes: utf8.encode(source),
    result: result,
    status: _JournalCandidateStatus.valid,
  );

  factory _JournalCandidate.unsupported(
    File file,
    String source,
    Object error,
  ) => _JournalCandidate._(
    file: file,
    source: source,
    bytes: utf8.encode(source),
    error: error,
    status: _JournalCandidateStatus.unsupported,
  );

  factory _JournalCandidate.corrupt(
    File file,
    String? source,
    Object error,
    StackTrace stackTrace, {
    List<int>? bytes,
  }) => _JournalCandidate._(
    file: file,
    source: source,
    bytes: bytes ?? (source == null ? null : utf8.encode(source)),
    error: error,
    stackTrace: stackTrace,
    status: _JournalCandidateStatus.corrupt,
  );

  factory _JournalCandidate.ioFailure(
    File file, {
    required Object error,
    StackTrace? stackTrace,
  }) => _JournalCandidate._(
    file: file,
    error: error,
    stackTrace: stackTrace,
    status: _JournalCandidateStatus.ioFailure,
  );

  final File file;
  final String? source;
  final List<int>? bytes;
  final AppBackupRestoreJournalLoadResult? result;
  final Object? error;
  final StackTrace? stackTrace;
  final _JournalCandidateStatus status;

  bool get exists => status != _JournalCandidateStatus.missing;
  bool get valid => status == _JournalCandidateStatus.valid;
  bool get corrupt => status == _JournalCandidateStatus.corrupt;
  bool get unsupported => status == _JournalCandidateStatus.unsupported;
  bool get ioFailure => status == _JournalCandidateStatus.ioFailure;
}

enum _JournalCandidateStatus { missing, valid, corrupt, unsupported, ioFailure }
