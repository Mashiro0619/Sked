import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Names and path resolution for all native Sked persistence artifacts.
///
/// A layout instance can be given a directory provider by tests (or by a
/// platform host that needs an explicit root). Production callers use
/// [getApplicationSupportDirectory], so data is kept in the platform's
/// application-specific support area instead of the user's Documents root.
class AppStorageLayout {
  AppStorageLayout({Future<Directory> Function()? directoryProvider})
    : _directoryProvider = directoryProvider ?? getApplicationSupportDirectory;

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

  final Future<Directory> Function() _directoryProvider;

  /// Resolves and creates the common application-support directory.
  ///
  /// Creation is deliberate: an inability to create the directory is an I/O
  /// failure, never an indication that the app is being launched for the first
  /// time. Callers can therefore preserve the existing fail-closed recovery
  /// behavior.
  Future<Directory> directory() async {
    final supplied = await _directoryProvider();
    final normalized = Directory(path.normalize(path.absolute(supplied.path)));
    await normalized.create(recursive: true);
    return normalized;
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
