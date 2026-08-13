import 'dart:io';

import 'src/platform_artifact_check.dart';

const _usage = r'''
Usage:
  dart run tool/platform_artifact_check.dart android-manifest \
    --manifest <path> --resource-root <path> --application-id <id> \
    --target-sdk <integer>
  dart run tool/platform_artifact_check.dart macos-bundle \
    --info-plist <path> --entitlements-plist <path> --bundle-id <id>
''';
const _androidSecurityResourceNames = {
  'network_security_config.xml',
  'data_extraction_rules.xml',
};

void main(List<String> arguments) {
  try {
    final issues = _run(arguments);
    if (issues.isNotEmpty) {
      stderr.writeln('Platform artifact check failed:');
      for (final issue in issues) {
        stderr.writeln('- $issue');
      }
      exitCode = 1;
      return;
    }
    stdout.writeln('Platform artifact check passed.');
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    stderr.writeln(_usage);
    exitCode = 64;
  } on FileSystemException catch (error) {
    stderr.writeln(error);
    exitCode = 66;
  }
}

List<String> _run(List<String> arguments) {
  if (arguments.isEmpty) throw const FormatException('Missing command.');
  final command = arguments.first;
  final options = _parseOptions(arguments.skip(1).toList());
  switch (command) {
    case 'android-manifest':
      _expectOptions(options, const {
        '--manifest',
        '--resource-root',
        '--application-id',
        '--target-sdk',
      });
      final expectedTargetSdk = int.tryParse(options['--target-sdk']!);
      if (expectedTargetSdk == null || expectedTargetSdk <= 0) {
        throw const FormatException('--target-sdk must be a positive integer.');
      }
      return [
        ...androidMergedManifestIssues(
          File(options['--manifest']!).readAsStringSync(),
          applicationId: options['--application-id']!,
          expectedTargetSdk: expectedTargetSdk,
        ),
        ...androidReleaseResourceIssues(
          _readResourceFiles(Directory(options['--resource-root']!)),
        ),
      ];
    case 'macos-bundle':
      _expectOptions(options, const {
        '--info-plist',
        '--entitlements-plist',
        '--bundle-id',
      });
      return macosBundleMetadataIssues(
        infoPlist: File(options['--info-plist']!).readAsStringSync(),
        entitlementsPlist: File(options['--entitlements-plist']!)
            .readAsStringSync(),
        bundleIdentifier: options['--bundle-id']!,
      );
    default:
      throw FormatException('Unknown command: $command.');
  }
}

Map<String, String> _readResourceFiles(Directory root) {
  if (!root.existsSync()) {
    throw FileSystemException('Resource root does not exist', root.path);
  }
  final prefix = root.absolute.path.endsWith(Platform.pathSeparator)
      ? root.absolute.path
      : '${root.absolute.path}${Platform.pathSeparator}';
  final files = <String, String>{};
  for (final entity in root.listSync(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final absolutePath = entity.absolute.path;
    if (!absolutePath.startsWith(prefix)) {
      throw FileSystemException('Resource escaped its root', entity.path);
    }
    final normalizedRelativePath = absolutePath
        .substring(prefix.length)
        .replaceAll(Platform.pathSeparator, '/');
    final fileName = normalizedRelativePath.split('/').last;
    final isSecurityResource = _androidSecurityResourceNames.contains(fileName);
    final isValuesResource = normalizedRelativePath
        .split('/')
        .any((segment) => segment == 'values' || segment.startsWith('values-'));
    if (!isSecurityResource && !isValuesResource) continue;
    files[normalizedRelativePath] = entity.readAsStringSync();
  }
  return files;
}

Map<String, String> _parseOptions(List<String> arguments) {
  if (arguments.length.isOdd) {
    throw const FormatException('Every option requires a value.');
  }
  final result = <String, String>{};
  for (var index = 0; index < arguments.length; index += 2) {
    final name = arguments[index];
    final value = arguments[index + 1].trim();
    if (!name.startsWith('--') || value.isEmpty || result.containsKey(name)) {
      throw FormatException('Invalid option: $name.');
    }
    result[name] = value;
  }
  return result;
}

void _expectOptions(Map<String, String> actual, Set<String> expected) {
  if (actual.keys.toSet().difference(expected).isNotEmpty ||
      expected.difference(actual.keys.toSet()).isNotEmpty) {
    throw FormatException(
      'Expected options ${expected.join(', ')}, got ${actual.keys.join(', ')}.',
    );
  }
}
