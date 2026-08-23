import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Names and path resolution for all native Sked persistence artifacts.
///
/// A layout instance can be given a directory provider by tests (or by a
/// platform host that needs an explicit root). Production callers use
/// `%APPDATA%\\Sked` on Windows and
/// [getApplicationSupportDirectory] elsewhere, so data is kept outside the
/// user's Documents root.
class AppStorageLayout {
  factory AppStorageLayout({
    Future<Directory> Function()? directoryProvider,
    bool? isWindows,
    Future<Directory> Function()? windowsRoamingDirectoryProvider,
    Future<void> Function(Directory source, Directory target)?
    windowsDirectoryMover,
    Future<void> Function(Directory target)? windowsEmptyTargetDirectoryDeleter,
  }) {
    return AppStorageLayout._(
      directoryProvider: directoryProvider,
      isWindows: isWindows ?? Platform.isWindows,
      windowsRoamingDirectoryProvider:
          windowsRoamingDirectoryProvider ?? _productionWindowsRoamingDirectory,
      windowsDirectoryMover: windowsDirectoryMover ?? _renameWindowsDirectory,
      windowsEmptyTargetDirectoryDeleter:
          windowsEmptyTargetDirectoryDeleter ?? _deleteWindowsEmptyDirectory,
    );
  }

  AppStorageLayout._({
    required this._directoryProvider,
    required this._isWindows,
    required this._windowsRoamingDirectoryProvider,
    required this._windowsDirectoryMover,
    required this._windowsEmptyTargetDirectoryDeleter,
  });

  static const appDataFileName = 'Sked_data.json';
  static const schoolSitesFileName = 'Sked_school_sites.json';
  static const instanceLockFileName = 'Sked_instance.lock';
  static const backupRestoreJournalFileName =
      'Sked_backup_restore_journal.json';
  static const backupSuffix = '.bak';
  static const temporarySuffix = '.tmp';
  static const failedTemporarySuffix = '.tmp.failed';
  static const appDataRecoveryDirectoryPrefix = 'Sked_recovery_';
  static const schoolSitesRecoveryDirectoryPrefix =
      'Sked_school_sites_recovery_';
  static const backupRestoreRecoveryDirectoryPrefix =
      'Sked_backup_restore_recovery_';

  static const windowsDirectoryName = 'Sked';
  static const legacyWindowsCompanyDirectoryName = 'Mashiro';

  static final Map<String, Future<void>> _windowsMigrationFlights = {};

  final Future<Directory> Function()? _directoryProvider;
  final bool _isWindows;
  final Future<Directory> Function() _windowsRoamingDirectoryProvider;
  final Future<void> Function(Directory source, Directory target)
  _windowsDirectoryMover;
  final Future<void> Function(Directory target)
  _windowsEmptyTargetDirectoryDeleter;

  /// Resolves and creates the common application-support directory.
  ///
  /// Creation is deliberate: an inability to create the directory is an I/O
  /// failure, never an indication that the app is being launched for the first
  /// time. Callers can therefore preserve the existing fail-closed recovery
  /// behavior.
  Future<Directory> directory() async {
    final supplied = await _resolveDirectory();
    final normalized = Directory(path.normalize(path.absolute(supplied.path)));
    if (_directoryProvider == null && _isWindows) {
      await _migrateLegacyWindowsDirectory(normalized);
    }
    await normalized.create(recursive: true);
    return normalized;
  }

  Future<Directory> _resolveDirectory() async {
    final directoryProvider = _directoryProvider;
    if (directoryProvider != null) return await directoryProvider();
    if (!_isWindows) return await getApplicationSupportDirectory();

    final roaming = await _windowsRoamingDirectoryProvider();
    return Directory(path.join(roaming.path, windowsDirectoryName));
  }

  /// Resolves the legacy Windows storage directory without creating or
  /// migrating it. Other platforms and explicitly injected roots have none.
  Future<Directory?> legacyWindowsStorageDirectory() async {
    if (!_isWindows || _directoryProvider != null) return null;
    final roaming = await _windowsRoamingDirectoryProvider();
    return Directory(
      path.join(
        roaming.path,
        legacyWindowsCompanyDirectoryName,
        windowsDirectoryName,
      ),
    );
  }

  Future<void> _migrateLegacyWindowsDirectory(Directory target) async {
    final migrationKey = path
        .normalize(path.absolute(target.path))
        .toLowerCase();
    final migration = _windowsMigrationFlights.putIfAbsent(
      migrationKey,
      () => _performLegacyWindowsMigration(target),
    );
    try {
      await migration;
    } finally {
      if (identical(_windowsMigrationFlights[migrationKey], migration)) {
        unawaited(_windowsMigrationFlights.remove(migrationKey));
      }
    }
  }

  Future<void> _performLegacyWindowsMigration(Directory target) async {
    final roaming = Directory(path.dirname(target.path));
    final legacyCompanyDirectory = Directory(
      path.join(roaming.path, legacyWindowsCompanyDirectoryName),
    );
    final legacy = Directory(
      path.join(legacyCompanyDirectory.path, windowsDirectoryName),
    );

    final legacyType = await FileSystemEntity.type(
      legacy.path,
      followLinks: false,
    );
    if (legacyType == FileSystemEntityType.notFound) return;
    if (legacyType != FileSystemEntityType.directory) {
      throw FileSystemException(
        'The legacy Sked storage path is not a directory.',
        legacy.path,
      );
    }

    final targetType = await FileSystemEntity.type(
      target.path,
      followLinks: false,
    );
    if (targetType == FileSystemEntityType.directory) {
      if (!await target.list(followLinks: false).isEmpty) return;
      try {
        await _windowsEmptyTargetDirectoryDeleter(target);
      } catch (error, stackTrace) {
        if (await _migrationWasCompletedByAnotherProcess(legacy, target)) {
          await _deleteDirectoryIfEmpty(legacyCompanyDirectory);
          return;
        }
        if (!await _pathIsMissing(target.path)) {
          Error.throwWithStackTrace(error, stackTrace);
        }
        // Another process removed the shared empty target but has not yet
        // completed its rename. Continue; the mover's post-failure check
        // resolves whichever process wins the remaining race.
      }
    } else if (targetType != FileSystemEntityType.notFound) {
      throw FileSystemException(
        'The Sked storage path is not a directory.',
        target.path,
      );
    }

    try {
      await _windowsDirectoryMover(legacy, target);
    } catch (error, stackTrace) {
      // Migration runs before the instance lease is acquired, so a second
      // process can observe the legacy source and then lose the rename race.
      // Accept only the exact completed state produced by the winner. Any
      // ambiguous or inaccessible state remains fail-closed.
      if (!await _migrationWasCompletedByAnotherProcess(legacy, target)) {
        Error.throwWithStackTrace(error, stackTrace);
      }
    }
    await _deleteDirectoryIfEmpty(legacyCompanyDirectory);
  }

  static Future<bool> _migrationWasCompletedByAnotherProcess(
    Directory legacy,
    Directory target,
  ) async {
    try {
      final legacyType = await FileSystemEntity.type(
        legacy.path,
        followLinks: false,
      );
      if (legacyType != FileSystemEntityType.notFound) return false;

      final targetType = await FileSystemEntity.type(
        target.path,
        followLinks: false,
      );
      if (targetType != FileSystemEntityType.directory) return false;

      // Force an actual directory read so an inaccessible or otherwise
      // unusable target is not mistaken for a successful migration.
      await target.list(followLinks: false).isEmpty;
      return true;
    } on FileSystemException {
      return false;
    }
  }

  static Future<bool> _pathIsMissing(String entityPath) async {
    try {
      return await FileSystemEntity.type(entityPath, followLinks: false) ==
          FileSystemEntityType.notFound;
    } on FileSystemException {
      return false;
    }
  }

  static Future<Directory> _productionWindowsRoamingDirectory() async {
    final appData = Platform.environment['APPDATA'];
    if (appData == null || appData.trim().isEmpty) {
      throw const FileSystemException(
        'The APPDATA environment variable is unavailable.',
      );
    }
    return Directory(appData);
  }

  static Future<void> _renameWindowsDirectory(
    Directory source,
    Directory target,
  ) async {
    await source.rename(target.path);
  }

  static Future<void> _deleteWindowsEmptyDirectory(Directory target) {
    return target.delete();
  }

  static Future<void> _deleteDirectoryIfEmpty(Directory directory) async {
    final type = await FileSystemEntity.type(
      directory.path,
      followLinks: false,
    );
    if (type != FileSystemEntityType.directory ||
        !await directory.list(followLinks: false).isEmpty) {
      return;
    }
    try {
      await directory.delete();
    } on FileSystemException {
      // Another process may have populated the legacy company directory after
      // the emptiness check. The migrated data is already safe at the target.
    }
  }

  /// Resolves a file directly below the application-support directory.
  ///
  /// Only a single safe file name is accepted. This prevents accidental path
  /// traversal when a caller builds a path from persisted or imported data.
  Future<File> file(String fileName) async {
    _validateFileName(fileName);
    final root = await directory();
    return _fileInRoot(root, fileName);
  }

  /// Resolves the complete AppData file set against one root snapshot.
  Future<AppDataStoragePaths> appDataPaths() async {
    final root = await directory();
    return AppDataStoragePaths(
      root: root,
      main: _fileInRoot(root, appDataFileName),
      backup: _fileInRoot(root, '$appDataFileName$backupSuffix'),
      temporary: _fileInRoot(root, '$appDataFileName$temporarySuffix'),
    );
  }

  /// Resolves the complete school-site file set against one root snapshot.
  Future<SchoolSiteStoragePaths> schoolSitePaths() async {
    final root = await directory();
    return SchoolSiteStoragePaths(
      root: root,
      main: _fileInRoot(root, schoolSitesFileName),
      backup: _fileInRoot(root, '$schoolSitesFileName$backupSuffix'),
      temporary: _fileInRoot(root, '$schoolSitesFileName$temporarySuffix'),
      failedTemporary: _fileInRoot(
        root,
        '$schoolSitesFileName$failedTemporarySuffix',
      ),
    );
  }

  /// Resolves the complete restore-journal file set against one root snapshot.
  Future<BackupRestoreJournalStoragePaths> backupRestoreJournalPaths() async {
    final root = await directory();
    return BackupRestoreJournalStoragePaths(
      root: root,
      main: _fileInRoot(root, backupRestoreJournalFileName),
      backup: _fileInRoot(root, '$backupRestoreJournalFileName$backupSuffix'),
      temporary: _fileInRoot(
        root,
        '$backupRestoreJournalFileName$temporarySuffix',
      ),
    );
  }

  Future<File> get appDataFile async => (await appDataPaths()).main;

  Future<File> get appDataBackupFile async => (await appDataPaths()).backup;

  Future<File> get appDataTemporaryFile async =>
      (await appDataPaths()).temporary;

  Future<File> get schoolSitesFile async => (await schoolSitePaths()).main;

  Future<File> get schoolSitesBackupFile async =>
      (await schoolSitePaths()).backup;

  Future<File> get schoolSitesTemporaryFile async =>
      (await schoolSitePaths()).temporary;

  Future<File> get schoolSitesFailedTemporaryFile async =>
      (await schoolSitePaths()).failedTemporary;

  Future<File> get instanceLockFile => file(instanceLockFileName);

  Future<File> get backupRestoreJournalFile async =>
      (await backupRestoreJournalPaths()).main;

  Future<File> get backupRestoreJournalBackupFile async =>
      (await backupRestoreJournalPaths()).backup;

  Future<File> get backupRestoreJournalTemporaryFile async =>
      (await backupRestoreJournalPaths()).temporary;

  /// Resolves one of Sked's named recovery directories below the root.
  ///
  /// Callers own creation because they must first resolve timestamp/hash
  /// collisions. Arbitrary directory names are rejected.
  Future<Directory> recoveryDirectory(String directoryName) async {
    _validateDirectoryName(directoryName);
    final root = await directory();
    final candidate = path.normalize(path.join(root.path, directoryName));
    final rootPath = path.normalize(path.absolute(root.path));
    if (!_isDirectChild(rootPath, candidate)) {
      throw ArgumentError.value(
        directoryName,
        'directoryName',
        'must stay in storage root',
      );
    }
    return Directory(candidate);
  }

  static void _validateFileName(String fileName) {
    if (fileName.isEmpty ||
        fileName == '.' ||
        fileName == '..' ||
        fileName.contains('/') ||
        fileName.contains('\\') ||
        fileName != path.basename(fileName)) {
      throw ArgumentError.value(
        fileName,
        'fileName',
        'must be a single file name without path separators',
      );
    }
  }

  static File _fileInRoot(Directory root, String fileName) {
    _validateFileName(fileName);
    final candidate = path.normalize(path.join(root.path, fileName));
    final rootPath = path.normalize(path.absolute(root.path));
    if (!_isDirectChild(rootPath, candidate)) {
      throw ArgumentError.value(
        fileName,
        'fileName',
        'must stay in storage root',
      );
    }
    return File(candidate);
  }

  static void _validateDirectoryName(String directoryName) {
    _validateFileName(directoryName);
    final hasAllowedPrefix =
        directoryName.startsWith(appDataRecoveryDirectoryPrefix) ||
        directoryName.startsWith(schoolSitesRecoveryDirectoryPrefix) ||
        directoryName.startsWith(backupRestoreRecoveryDirectoryPrefix);
    if (!hasAllowedPrefix) {
      throw ArgumentError.value(
        directoryName,
        'directoryName',
        'must use a Sked recovery-directory prefix',
      );
    }
  }

  static bool _isDirectChild(String root, String candidate) {
    final parent = path.dirname(candidate);
    return path.equals(parent, root) && !path.equals(candidate, root);
  }
}

class AppDataStoragePaths {
  AppDataStoragePaths({
    required this.root,
    required this.main,
    required this.backup,
    required this.temporary,
  });

  final Directory root;
  final File main;
  final File backup;
  final File temporary;
}

class SchoolSiteStoragePaths {
  SchoolSiteStoragePaths({
    required this.root,
    required this.main,
    required this.backup,
    required this.temporary,
    required this.failedTemporary,
  });

  final Directory root;
  final File main;
  final File backup;
  final File temporary;
  final File failedTemporary;
}

class BackupRestoreJournalStoragePaths {
  BackupRestoreJournalStoragePaths({
    required this.root,
    required this.main,
    required this.backup,
    required this.temporary,
  });

  final Directory root;
  final File main;
  final File backup;
  final File temporary;
}

/// Resolves the production native application-support directory.
Future<Directory> resolveAppStorageDirectory() =>
    AppStorageLayout().directory();
