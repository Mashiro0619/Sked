import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  final powershell = _findPowerShell();
  final tempRoot = Directory.systemTemp.resolveSymbolicLinksSync();
  late Directory fixture;
  late File buildScript;
  late File harness;
  late File callsFile;
  late File configFile;

  setUp(() async {
    fixture = await Directory(tempRoot).createTemp('sked-msix-version-');
    for (final name in [
      'build_msix.ps1',
      'verify_store_msix.ps1',
      'microsoft_store.json',
    ]) {
      await File('tool/$name').copy(p.join(fixture.path, name));
    }
    buildScript = File(p.join(fixture.path, 'build_msix.ps1'));
    configFile = File(p.join(fixture.path, 'microsoft_store.json'));
    callsFile = File(p.join(fixture.path, 'calls.jsonl'));
    harness = File(p.join(fixture.path, 'invoke-msix.ps1'));
    await harness.writeAsString(r'''
param([string]$BuildScript, [string]$Mode)
$ErrorActionPreference = 'Stop'
$env:SKED_MSIX_CERTIFICATE_PATH = $null
$env:SKED_MSIX_CERTIFICATE_PASSWORD = $null
$env:SKED_MSIX_PUBLISHER = $null
function Record-Call([string]$Program, [string[]]$Arguments) {
  $record = @{ program = $Program; arguments = @($Arguments) } | ConvertTo-Json -Compress
  [System.IO.File]::AppendAllText((Join-Path (Get-Location).ProviderPath 'calls.jsonl'), $record + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
}
function flutter {
  Record-Call 'flutter' $args
  $global:LASTEXITCODE = [int]$env:SKED_TEST_BUILD_EXIT_CODE
}
function dart {
  Record-Call 'dart' $args
  $global:LASTEXITCODE = [int]$env:SKED_TEST_PACKAGE_EXIT_CODE
  if ($global:LASTEXITCODE -ne 0 -or '--store' -notin $args) { return }
  $version = $args[[array]::IndexOf($args, '--version') + 1]
  $outputPath = $args[[array]::IndexOf($args, '--output-path') + 1]
  $outputName = $args[[array]::IndexOf($args, '--output-name') + 1]
  $cfg = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'microsoft_store.json') -Raw | ConvertFrom-Json
  $name = $cfg.identityName
  $publisher = $cfg.publisher
  $displayName = $cfg.publisherDisplayName
  $architecture = 'x64'
  $appId = 'sked'
  $toast = '5d9d8f6a-4d1a-4f3a-9b0a-6a3e7d2c1f58'
  switch ($env:SKED_TEST_PACKAGE_MISMATCH) {
    'name' { $name = 'Mashiro.Sked' }
    'publisher' { $publisher = 'CN=Mashiro' }
    'displayName' { $displayName = 'Other' }
    'version' { $version = '2.3.0.14' }
    'architecture' { $architecture = 'arm64' }
    'appId' { $appId = 'other' }
    'toast' { $toast = 'other' }
  }
  $manifest = @"
<Package xmlns="http://schemas.microsoft.com/appx/manifest/foundation/windows10" xmlns:desktop="http://schemas.microsoft.com/appx/manifest/desktop/windows10">
  <Identity Name="$name" Publisher="$publisher" Version="$version" ProcessorArchitecture="$architecture" />
  <Properties><PublisherDisplayName>$displayName</PublisherDisplayName></Properties>
  <Applications><Application Id="$appId"><Extensions><desktop:ToastNotificationActivation ToastActivatorCLSID="$toast" /></Extensions></Application></Applications>
</Package>
"@
  New-Item -ItemType Directory -Path $outputPath -Force | Out-Null
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $archive = [System.IO.Compression.ZipFile]::Open((Join-Path $outputPath "$outputName.msix"), [System.IO.Compression.ZipArchiveMode]::Create)
  try {
    if ($env:SKED_TEST_PACKAGE_MISMATCH -ne 'missingManifest') {
      $writer = [System.IO.StreamWriter]::new($archive.CreateEntry('AppxManifest.xml').Open())
      try { $writer.Write($manifest) } finally { $writer.Dispose() }
    }
    if ($env:SKED_TEST_PACKAGE_MISMATCH -eq 'signature') {
      $archive.CreateEntry('AppxSignature.p7x') | Out-Null
    }
  } finally { $archive.Dispose() }
}
switch ($Mode) {
  'Store' { & $BuildScript -Store }
  'Both' { & $BuildScript -Store -Unsigned }
  'Signed' {
    $env:SKED_MSIX_CERTIFICATE_PATH = Join-Path (Get-Location).ProviderPath 'test.pfx'
    [System.IO.File]::WriteAllText($env:SKED_MSIX_CERTIFICATE_PATH, 'not a real certificate')
    $env:SKED_MSIX_CERTIFICATE_PASSWORD = 'test-password'
    $env:SKED_MSIX_PUBLISHER = 'CN=Test Publisher'
    & $BuildScript
  }
  'MissingCertificate' { & $BuildScript }
  default { & $BuildScript -Unsigned }
}
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
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

  Future<ProcessResult> runBuild(
    String version, {
    String mode = 'Unsigned',
    int buildExitCode = 0,
    int packageExitCode = 0,
    String mismatch = '',
  }) async {
    await File(p.join(fixture.path, 'pubspec.yaml'))
        .writeAsString('name: sked\nversion: $version\n');
    return Process.run(
      powershell!,
      [
        '-NoProfile',
        '-NonInteractive',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        harness.path,
        buildScript.path,
        mode,
      ],
      workingDirectory: fixture.path,
      environment: {
        'SKED_TEST_BUILD_EXIT_CODE': '$buildExitCode',
        'SKED_TEST_PACKAGE_EXIT_CODE': '$packageExitCode',
        'SKED_TEST_PACKAGE_MISMATCH': mismatch,
      },
    );
  }

  Future<List<Map<String, dynamic>>> calls() async {
    if (!await callsFile.exists()) return [];
    return (await callsFile.readAsLines())
        .where((line) => line.isNotEmpty)
        .map((line) => jsonDecode(line) as Map<String, dynamic>)
        .toList();
  }

  String argument(List<dynamic> arguments, String name) =>
      arguments[arguments.indexOf(name) + 1] as String;

  final skip = powershell == null
      ? 'PowerShell is required to exercise the MSIX build script.'
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
    test(
      'sideload maps $version to $expected and clears the Store build flag',
      () async {
        final result = await runBuild(version);
        expect(
          result.exitCode,
          0,
          reason: [result.stdout, result.stderr].join('\n'),
        );
        final recorded = await calls();
        expect(recorded.map((call) => call['program']), ['flutter', 'dart']);
        expect(
          recorded.first['arguments'],
          contains('--dart-define=SKED_MICROSOFT_STORE_ID='),
        );
        final arguments = recorded.last['arguments'] as List;
        expect(argument(arguments, '--version'), expected);
        expect(
          argument(arguments, '--publisher'),
          'CN=Mashiro, O=Mashiro, C=CN',
        );
        expect(argument(arguments, '--sign-msix'), 'false');
        expect(argument(arguments, '--install-certificate'), 'false');
        expect(arguments, isNot(contains('--store')));
      },
      skip: skip,
    );
  }

  for (final (version, expected) in [
    ('2.3.0-alpha.1+14', '2.3.14.0'),
    ('2.3.0-beta.2+15', '2.3.15.0'),
    ('2.3.0-rc.10+16', '2.3.16.0'),
    ('2.3.0+17', '2.3.17.0'),
    ('2.3.1+18', '2.3.18.0'),
  ]) {
    test(
      'Store maps $version to $expected and uses Partner Center identity',
      () async {
        final result = await runBuild(version, mode: 'Store');
        expect(
          result.exitCode,
          0,
          reason: [result.stdout, result.stderr].join('\n'),
        );
        final recorded = await calls();
        expect(recorded.map((call) => call['program']), ['flutter', 'dart']);
        expect(
          recorded.first['arguments'],
          contains('--dart-define=SKED_MICROSOFT_STORE_ID=9NWRR6ZP6K6T'),
        );
        final arguments = recorded.last['arguments'] as List;
        expect(argument(arguments, '--version'), expected);
        expect(argument(arguments, '--identity-name'), 'Mashiro0619.Sked');
        expect(
          argument(arguments, '--publisher'),
          'CN=6F54C1EE-2D68-4470-95B1-DC94E15256D4',
        );
        expect(argument(arguments, '--publisher-display-name'), 'Mashiro0619');
        expect(
          p.normalize(argument(arguments, '--output-path')),
          p.join(fixture.path, 'build', 'microsoft-store'),
        );
        expect(
          argument(arguments, '--output-name'),
          'sked-v${version.split('+').first}-store-x64',
        );
        expect(argument(arguments, '--sign-msix'), 'false');
        expect(argument(arguments, '--install-certificate'), 'false');
        expect(arguments, contains('--store'));
        expect(arguments, isNot(contains('--certificate-path')));
        expect(arguments, isNot(contains('--certificate-password')));
        expect(
          result.stdout,
          contains('Verified Store identity: Mashiro0619.Sked_8xjzenwxj0w1p'),
        );
      },
      skip: skip,
    );
  }

  for (final invalid in [
    '2.3.0-',
    '2.3.0-alpha.',
    '2.3.0-alpha..1',
    '2.3.0-alpha.1+build',
    '2.3.0 alpha.1',
    '2.3.0-alpha.01',
  ]) {
    test('rejects invalid version $invalid before building', () async {
      final result = await runBuild(invalid);
      expect(result.exitCode, isNot(0));
      expect(result.stderr, contains('Could not read the Flutter version'));
      expect(await calls(), isEmpty);
    }, skip: skip);
  }

  for (final invalid in [
    '0.3.0+14',
    '2.3.0-alpha.1',
    '2.3.0+0',
    '2.3.0+65536',
    '2.65536.0+14',
  ]) {
    test('rejects invalid Store numeric version $invalid', () async {
      final result = await runBuild(invalid, mode: 'Store');
      expect(result.exitCode, isNot(0));
      expect(await calls(), isEmpty);
    }, skip: skip);
  }

  for (final mismatch in [
    'name',
    'publisher',
    'displayName',
    'version',
    'architecture',
    'appId',
    'toast',
    'signature',
    'missingManifest',
  ]) {
    test(
      'rejects a generated Store package with mismatched $mismatch',
      () async {
        final result = await runBuild(
          '2.3.0-alpha.1+14',
          mode: 'Store',
          mismatch: mismatch,
        );
        expect(result.exitCode, isNot(0));
        expect(result.stderr, contains('Store'));
      },
      skip: skip,
    );
  }

  test('rejects pasted HTML whitespace in identity before building', () async {
    final config =
        jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
    config['identityName'] = 'Mashiro0619.Sked&#x20;';
    await configFile.writeAsString(jsonEncode(config));
    final result = await runBuild('2.3.0+14', mode: 'Store');
    expect(result.exitCode, isNot(0));
    expect(await calls(), isEmpty);
  }, skip: skip);

  test(
    'verifies the package family derived from the actual Publisher',
    () async {
      final config =
          jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
      config['packageFamilyName'] = 'Mashiro0619.Sked_0000000000000';
      await configFile.writeAsString(jsonEncode(config));
      final result = await runBuild('2.3.0+14', mode: 'Store');
      expect(result.exitCode, isNot(0));
      expect(result.stderr, contains('Store package family name'));
    },
    skip: skip,
  );

  test('Store and unsigned validation modes are mutually exclusive', () async {
    final result = await runBuild('2.3.0+14', mode: 'Both');
    expect(result.exitCode, isNot(0));
    expect(await calls(), isEmpty);
  }, skip: skip);

  test(
    'signed sideload still requires certificate configuration before building',
    () async {
      final result = await runBuild('2.3.0+14', mode: 'MissingCertificate');
      expect(result.exitCode, isNot(0));
      expect(result.stderr, contains('SKED_MSIX_CERTIFICATE_PATH'));
      expect(await calls(), isEmpty);
    },
    skip: skip,
  );

  test(
    'signed sideload retains its explicitly configured certificate',
    () async {
      final result = await runBuild('2.3.0+14', mode: 'Signed');
      expect(result.exitCode, 0, reason: result.stderr.toString());
      final arguments = (await calls()).last['arguments'] as List;
      expect(
        argument(arguments, '--certificate-path'),
        p.join(fixture.path, 'test.pfx'),
      );
      expect(argument(arguments, '--certificate-password'), 'test-password');
      expect(arguments, isNot(contains('--store')));
    },
    skip: skip,
  );

  test('failed Windows build prevents packaging stale binaries', () async {
    final result = await runBuild('2.3.0+14', mode: 'Store', buildExitCode: 7);
    expect(result.exitCode, 7);
    expect((await calls()).map((call) => call['program']), ['flutter']);
  }, skip: skip);

  test(
    'failed MSIX creation is propagated without claiming validation success',
    () async {
      final result = await runBuild(
        '2.3.0+14',
        mode: 'Store',
        packageExitCode: 8,
      );
      expect(result.exitCode, 8);
      expect(result.stdout, isNot(contains('Verified Store identity')));
    },
    skip: skip,
  );
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
