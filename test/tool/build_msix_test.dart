import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  final powershell = _findPowerShell();
  final buildScript = File('tool/build_msix.ps1').absolute.path;
  final tempRoot = Directory.systemTemp.resolveSymbolicLinksSync();
  late Directory fixture;
  late File capturedArguments;
  late File harness;

  setUp(() async {
    fixture = await Directory(tempRoot).createTemp('sked-msix-version-');
    capturedArguments = File(p.join(fixture.path, 'msix-args.json'));
    harness = File(p.join(fixture.path, 'invoke-msix.ps1'));
    await harness.writeAsString(r'''
param([string]$BuildScript)
$ErrorActionPreference = 'Stop'
function dart {
  @($args) | ConvertTo-Json -Compress | Set-Content -LiteralPath 'msix-args.json' -Encoding utf8
  $global:LASTEXITCODE = 0
}
& $BuildScript -Unsigned
''');
  });

  tearDown(() async {
    final target = await fixture.resolveSymbolicLinks();
    if (!p.isWithin(tempRoot, target) ||
        !p.basename(target).startsWith('sked-msix-version-')) {
      throw StateError('Refusing to delete an unexpected fixture path.');
    }
    await fixture.delete(recursive: true);
  });

  Future<ProcessResult> runBuild(String version) async {
    await File(p.join(fixture.path, 'pubspec.yaml'))
        .writeAsString('name: sked\nversion: $version\n');
    return Process.run(powershell!, [
      '-NoProfile',
      '-NonInteractive',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      harness.path,
      buildScript,
    ], workingDirectory: fixture.path);
  }

  final skip = powershell == null
      ? 'PowerShell is required to exercise the Windows MSIX build script.'
      : false;
  for (final (version, expected) in [
    ('2.3.0+14', '2.3.0.14'),
    ('2.3.0-alpha.1+14', '2.3.0.14'),
    ('2.3.0-beta.2+15', '2.3.0.15'),
    ('2.3.0-rc.10+16', '2.3.0.16'),
    ('2.3.0-alpha-test.1+14', '2.3.0.14'),
    ('2.3.0-alpha.1', '2.3.0.0'),
    ('2.3.0', '2.3.0.0'),
  ]) {
    test('maps $version to numeric MSIX version $expected', () async {
      final result = await runBuild(version);
      expect(
        result.exitCode,
        0,
        reason: [result.stdout, result.stderr].join('\n'),
      );
      final arguments = jsonDecode(await capturedArguments.readAsString());
      expect(arguments, [
        'run',
        'msix:create',
        '--build-windows',
        'false',
        '--version',
        expected,
        '--install-certificate',
        'false',
        '--sign-msix',
        'false',
        '--publisher',
        'CN=Mashiro, O=Mashiro, C=CN',
      ]);
    }, skip: skip);
  }

  for (final invalid in [
    '2.3.0-',
    '2.3.0-alpha.',
    '2.3.0-alpha..1',
    '2.3.0-alpha.1+build',
    '2.3.0 alpha.1',
  ]) {
    test(
      'rejects malformed package version $invalid before invoking dart',
      () async {
        final result = await runBuild(invalid);
        expect(result.exitCode, isNot(0));
        expect(result.stderr, contains('Could not read the Flutter version'));
        expect(await capturedArguments.exists(), isFalse);
      },
      skip: skip,
    );
  }
}

String? _findPowerShell() {
  for (final executable in ['pwsh', if (Platform.isWindows) 'powershell.exe']) {
    try {
      final result = Process.runSync(executable, [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        'exit 0',
      ]);
      if (result.exitCode == 0) return executable;
    } on ProcessException {
      continue;
    }
  }
  return null;
}
