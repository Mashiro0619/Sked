import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as path;

/// Filesystem access shared by stores that keep isolated recovery copies.
/// The owning store retains its candidate selection and write transactions.
class RecoveryArtifactAccess {
  const RecoveryArtifactAccess({
    required this.directoryPrefix,
    required this.directoryNamePattern,
    required this.allowedArtifactNames,
    required this.invalidDirectoryMessage,
    this.rootArtifactNames = const {},
  });

  final String directoryPrefix;
  final RegExp directoryNamePattern;
  final Set<String> allowedArtifactNames;
  final String invalidDirectoryMessage;
  final Set<String> rootArtifactNames;

  Future<Uint8List?> read(
    String artifactPath, {
    required Directory root,
    required Iterable<File> activeFiles,
  }) async {
    final candidatePath = path.normalize(artifactPath);
    final activePaths = activeFiles
        .map((file) => path.normalize(file.path))
        .toSet();
    final recoveryDirectory = path.dirname(candidatePath);
    final isIsolatedArtifact =
        path.equals(path.dirname(recoveryDirectory), root.path) &&
        directoryNamePattern.hasMatch(path.basename(recoveryDirectory)) &&
        allowedArtifactNames.contains(path.basename(candidatePath)) &&
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
  }

  Future<Directory> createDirectory(
    Directory parent, {
    required Future<Directory> Function(String name) resolveDirectory,
    required DateTime Function() clock,
  }) async {
    final stamp = clock().toUtc().toIso8601String().replaceAll(
      RegExp(r'[-:.]'),
      '',
    );
    var suffix = 0;
    while (true) {
      final name = '$directoryPrefix$stamp${suffix == 0 ? '' : '_$suffix'}';
      final candidate = await resolveDirectory(name);
      if (!path.equals(candidate.parent.path, parent.path)) {
        throw StateError(
          'App storage directory changed while resolving recovery paths.',
        );
      }
      var type = await FileSystemEntity.type(
        candidate.path,
        followLinks: false,
      );
      if (type == FileSystemEntityType.notFound) {
        await candidate.create();
        type = await FileSystemEntity.type(candidate.path, followLinks: false);
        if (type != FileSystemEntityType.directory) {
          throw FileSystemException(invalidDirectoryMessage, candidate.path);
        }
        return candidate;
      }
      if (type != FileSystemEntityType.directory) {
        throw FileSystemException(invalidDirectoryMessage, candidate.path);
      }
      suffix += 1;
    }
  }

  Future<RecoveryArtifactScan> scan(
    Directory parent, {
    required Stream<FileSystemEntity> Function(Directory) directoryLister,
  }) async {
    final artifacts = <String>[];
    try {
      if (!await parent.exists()) {
        return const RecoveryArtifactScan.success(<String>[]);
      }
      await for (final entity in directoryLister(parent)) {
        if (rootArtifactNames.contains(path.basename(entity.path)) &&
            await FileSystemEntity.type(entity.path, followLinks: false) ==
                FileSystemEntityType.file) {
          artifacts.add(entity.path);
          continue;
        }
        if (await FileSystemEntity.type(entity.path, followLinks: false) !=
                FileSystemEntityType.directory ||
            !directoryNamePattern.hasMatch(path.basename(entity.path))) {
          continue;
        }
        final recoveryDirectory = Directory(entity.path);
        await for (final artifact in directoryLister(recoveryDirectory)) {
          if (await FileSystemEntity.type(artifact.path, followLinks: false) ==
                  FileSystemEntityType.file &&
              allowedArtifactNames.contains(path.basename(artifact.path))) {
            artifacts.add(artifact.path);
          }
        }
      }
    } catch (error, stackTrace) {
      artifacts.sort();
      return RecoveryArtifactScan.failure(
        List.unmodifiable(artifacts),
        error,
        stackTrace,
      );
    }
    artifacts.sort();
    return RecoveryArtifactScan.success(List.unmodifiable(artifacts));
  }
}

class RecoveryArtifactScan {
  const RecoveryArtifactScan.success(this.artifacts)
    : error = null,
      stackTrace = null;

  const RecoveryArtifactScan.failure(
    this.artifacts,
    this.error,
    this.stackTrace,
  );

  final List<String> artifacts;
  final Object? error;
  final StackTrace? stackTrace;

  List<String> requireArtifacts() {
    final failure = error;
    if (failure != null) {
      Error.throwWithStackTrace(failure, stackTrace!);
    }
    return artifacts;
  }
}
