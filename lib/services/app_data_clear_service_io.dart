import 'dart:io';

import 'package:path/path.dart' as path;

import 'app_data_clear_service.dart';
import 'app_storage_layout_io.dart';
import 'secret_store.dart';

class PlatformAppDataClearService implements AppDataClearService {
  PlatformAppDataClearService({
    AppStorageLayout? layout,
    SecretStore? secretStore,
  }) : _layout = layout ?? AppStorageLayout(),
       _secretStore = secretStore ?? SecretStore();

  final AppStorageLayout _layout;
  final SecretStore _secretStore;

  @override
  Future<void> clear() async {
    final root = await _layout.directory();
    final mainDataPath = path.normalize(
      path.join(root.path, AppStorageLayout.appDataFileName),
    );
    final lockPath = path.normalize(
      path.join(root.path, AppStorageLayout.instanceLockFileName),
    );
    FileSystemEntity? mainData;

    await for (final entity in root.list(followLinks: false)) {
      final entityPath = path.normalize(entity.path);
      if (path.equals(entityPath, lockPath)) continue;
      if (path.equals(entityPath, mainDataPath)) {
        mainData = entity;
        continue;
      }
      await _deleteEntity(entity);
    }

    final legacy = await _layout.legacyWindowsStorageDirectory();
    if (legacy != null &&
        !path.equals(path.normalize(legacy.path), path.normalize(root.path))) {
      await _deleteDirectoryIfPresent(legacy);
      await _deleteDirectoryIfEmpty(legacy.parent);
    }

    await _secretStore.writeCustomSchoolImportApiKey('');

    if (mainData != null) {
      await _deleteEntity(mainData);
    }
  }

  static Future<void> _deleteDirectoryIfPresent(Directory directory) async {
    final type = await FileSystemEntity.type(
      directory.path,
      followLinks: false,
    );
    if (type == FileSystemEntityType.notFound) return;
    if (type != FileSystemEntityType.directory) {
      throw FileSystemException(
        'Expected a managed Sked directory.',
        directory.path,
      );
    }
    await directory.delete(recursive: true);
  }

  static Future<void> _deleteDirectoryIfEmpty(Directory directory) async {
    final type = await FileSystemEntity.type(
      directory.path,
      followLinks: false,
    );
    if (type != FileSystemEntityType.directory) return;
    if (await directory.list(followLinks: false).isEmpty) {
      await directory.delete();
    }
  }

  static Future<void> _deleteEntity(FileSystemEntity entity) async {
    final type = await FileSystemEntity.type(entity.path, followLinks: false);
    switch (type) {
      case FileSystemEntityType.file:
        await File(entity.path).delete();
      case FileSystemEntityType.directory:
        await Directory(entity.path).delete(recursive: true);
      case FileSystemEntityType.link:
        await Link(entity.path).delete();
      case FileSystemEntityType.notFound:
        return;
      case FileSystemEntityType.pipe:
      case FileSystemEntityType.unixDomainSock:
        throw FileSystemException(
          'Unsupported entity in the Sked data directory.',
          entity.path,
        );
    }
  }
}
