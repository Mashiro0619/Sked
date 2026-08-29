import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pre-commit checks staged Dart blobs for added, modified, copied, and renamed paths', () async {
    final repository = await Directory.systemTemp.createTemp(
      'sked-pre-commit-hook-',
    );
    try {
      await _runGit(repository, <String>['init']);
      await _runGit(repository, <String>[
        'config',
        'user.email',
        'pre-commit-hook@example.invalid',
      ]);
      await _runGit(repository, <String>[
        'config',
        'user.name',
        'Pre-commit Hook Test',
      ]);

      final hookDirectory = Directory(
        '${repository.path}${Platform.pathSeparator}tool'
        '${Platform.pathSeparator}hooks',
      )..createSync(recursive: true);
      final hook = await File('tool/hooks/pre-commit')
          .copy('${hookDirectory.path}${Platform.pathSeparator}pre-commit');

      const sourcePath = 'lib/source file.dart';
      final source = File(
        '${repository.path}${Platform.pathSeparator}lib'
        '${Platform.pathSeparator}source file.dart',
      )..createSync(recursive: true);
      await source.writeAsString(_unformattedDart(_sourcePadding));
      await _runGit(repository, <String>['add', sourcePath]);

      // The working tree is formatted, but the index is not. The hook must
      // reject what will actually be committed rather than inspecting disk.
      await source.writeAsString(_formattedDart(_sourcePadding));
      final stagedUnformatted = await _runHook(repository, hook);
      expect(stagedUnformatted.exitCode, 1);
      expect(stagedUnformatted.stdout, contains('source'));

      // Conversely, a formatted index must pass even when an unstaged edit
      // leaves the working-tree file unformatted.
      await source.writeAsString(_formattedDart(_sourcePadding));
      await _runGit(repository, <String>['add', sourcePath]);
      await source.writeAsString(_unformattedDart(_sourcePadding));
      final stagedFormatted = await _runHook(repository, hook);
      expect(
        stagedFormatted.exitCode,
        0,
        reason:
            'stdout: ${stagedFormatted.stdout}\n'
            'stderr: ${stagedFormatted.stderr}',
      );

      await source.writeAsString(_formattedDart(_sourcePadding));
      await _runGit(repository, <String>['add', sourcePath]);
      await _runGit(repository, <String>[
        'commit',
        '--no-verify',
        '-m',
        'base',
      ]);

      // A staged modification must be checked even if the file was repaired
      // in the working tree after staging.
      await source.writeAsString(_unformattedDart(_sourcePadding));
      await _runGit(repository, <String>['add', sourcePath]);
      await source.writeAsString(_formattedDart(_sourcePadding));
      final modifiedStagedBlob = await _runHook(repository, hook);
      expect(modifiedStagedBlob.exitCode, 1);

      await _runGit(repository, <String>['add', sourcePath]);

      // An added copy must be inspected. The hook also includes C in its
      // filter because Git may classify sufficiently similar staged files
      // that way when copy detection is enabled.
      const copiedPath = 'lib/copied source.dart';
      final copied = File(
        '${repository.path}${Platform.pathSeparator}lib'
        '${Platform.pathSeparator}copied source.dart',
      );
      await copied.writeAsString(_unformattedDart(_copiedPadding));
      await _runGit(repository, <String>['add', copiedPath]);
      await copied.writeAsString(_formattedDart(_copiedPadding));
      final copiedStagedBlob = await _runHook(repository, hook);
      expect(copiedStagedBlob.exitCode, 1);

      await _runGit(repository, <String>['add', copiedPath]);
      await _runGit(repository, <String>[
        'commit',
        '--no-verify',
        '-m',
        'add copied source',
      ]);

      const renamedPath = 'lib/renamed source.dart';
      await _runGit(repository, <String>['mv', copiedPath, renamedPath]);
      final renamed = File(
        '${repository.path}${Platform.pathSeparator}lib'
        '${Platform.pathSeparator}renamed source.dart',
      );
      await renamed.writeAsString(_unformattedDart(_copiedPadding));
      await _runGit(repository, <String>['add', renamedPath]);
      await renamed.writeAsString(_formattedDart(_copiedPadding));

      final stagedStatus = await _runGit(repository, <String>[
        'diff',
        '--cached',
        '--name-status',
        '-M',
      ]);

      // Git may represent a rename with a modified blob as A/D depending on
      // similarity. Either representation exercises the hook's R-aware
      // pathname handling; a space proves it does not split shell words.
      expect(stagedStatus.stdout, contains('renamed source.dart'));
      final renamedStagedBlob = await _runHook(repository, hook);
      expect(renamedStagedBlob.exitCode, 1);

      await _runGit(repository, <String>['add', renamedPath]);
      await renamed.writeAsString(_unformattedDart(_copiedPadding));
      final repairedRenamedIndex = await _runHook(repository, hook);
      expect(
        repairedRenamedIndex.exitCode,
        0,
        reason: repairedRenamedIndex.stderr.toString(),
      );
    } finally {
      await repository.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(seconds: 45)));

  test('pre-commit hook is tracked as executable', () async {
    final result = await Process.run('git', <String>[
      'ls-files',
      '--stage',
      'tool/hooks/pre-commit',
    ]);

    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(result.stdout, startsWith('100755 '));
  });
}

Future<ProcessResult> _runGit(
  Directory repository,
  List<String> arguments,
) async {
  final result = await Process.run(
    'git',
    arguments,
    workingDirectory: repository.path,
  );
  if (result.exitCode != 0) {
    fail(
      'git ${arguments.join(' ')} failed (${result.exitCode}):\n'
      '${result.stderr}',
    );
  }
  return result;
}

Future<ProcessResult> _runHook(Directory repository, File hook) async {
  return Process.run(await _bashExecutable(), <String>[
    hook.path,
  ], workingDirectory: repository.path);
}

Future<String> _bashExecutable() async {
  if (!Platform.isWindows) {
    return 'bash';
  }

  final gitExecPath = await Process.run('git', <String>['--exec-path']);
  if (gitExecPath.exitCode != 0) {
    fail('git --exec-path failed: ${gitExecPath.stderr}');
  }

  final gitCoreDirectory = Directory(gitExecPath.stdout.toString().trim());
  final gitInstallation = gitCoreDirectory.parent.parent.parent;
  final gitBash = File(
    '${gitInstallation.path}${Platform.pathSeparator}bin'
    '${Platform.pathSeparator}bash.exe',
  );
  if (!gitBash.existsSync()) {
    fail('Unable to find Git Bash at ${gitBash.path}.');
  }
  return gitBash.path;
}

String _formattedDart(String padding) =>
    r'''
void main() {
  const message = 'Sked';
  final labels = <String>[
    'course',
    'event',
    'settings',
    'timetable',
    'calendar',
    'week',
    'view',
    'theme',
  ];
  for (final label in labels) {
    print(message + ': ' + label);
  }
}
''' +
    padding;

String _unformattedDart(String padding) =>
    r'''
void main(){
  const message='Sked';
  final labels=<String>[
    'course','event','settings','timetable','calendar','week','view','theme'];
  for(final label in labels){
    print(message+': '+label);
  }
}
''' +
    padding;

const _sourcePadding = '''
// source padding 000000000000000000000000000000000000000000000000000000000000
// source padding 111111111111111111111111111111111111111111111111111111111111
// source padding 222222222222222222222222222222222222222222222222222222222222
// source padding 333333333333333333333333333333333333333333333333333333333333
// source padding 444444444444444444444444444444444444444444444444444444444444
// source padding 555555555555555555555555555555555555555555555555555555555555
// source padding 666666666666666666666666666666666666666666666666666666666666
// source padding 777777777777777777777777777777777777777777777777777777777777
// source padding 888888888888888888888888888888888888888888888888888888888888
// source padding 999999999999999999999999999999999999999999999999999999999999
''';

const _copiedPadding = '''
// copied padding aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
// copied padding bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
// copied padding cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
// copied padding dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
// copied padding eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
// copied padding ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
// copied padding gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
// copied padding hhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhh
// copied padding iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii
// copied padding jjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjj
''';
