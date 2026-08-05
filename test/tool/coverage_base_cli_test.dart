import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _emptyTree = '4b825dc642cb6eb9a060e54bf8d69288fbee4904';
const _zeroObject = '0000000000000000000000000000000000000000';
const _missingObject = 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
const _pushPlaceholder = 'ffffffffffffffffffffffffffffffffffffffff';

void main() {
  test(
    'coverage base CLI resolves event, new-ref, empty, and failure paths',
    () async {
      final repository = await Directory.systemTemp.createTemp(
        'sked-coverage-base-',
      );
      final script = File('tool/coverage_base.dart').absolute.path;
      try {
        await _runGit(repository, <String>['init']);
        await _runGit(repository, <String>[
          'config',
          'user.email',
          'coverage-base@example.invalid',
        ]);
        await _runGit(repository, <String>[
          'config',
          'user.name',
          'Coverage Base Test',
        ]);
        await _runGit(repository, <String>[
          'commit',
          '--allow-empty',
          '-m',
          'base',
        ]);
        await _runGit(repository, <String>['branch', '-M', 'main']);
        final base = (await _runGit(repository, <String>[
          'rev-parse',
          'HEAD',
        ])).stdout.toString().trim();
        await _runGit(repository, <String>[
          'update-ref',
          'refs/remotes/origin/main',
          base,
        ]);
        await _runGit(repository, <String>['switch', '-c', 'feature']);
        await _runGit(repository, <String>[
          'commit',
          '--allow-empty',
          '-m',
          'feature',
        ]);

        final pullRequestOutput = File(
          '${repository.path}${Platform.pathSeparator}pull-output.txt',
        );
        final pullRequest = await _runCli(
          script,
          repository,
          pullRequestOutput,
          eventName: 'pull_request',
          pullRequestBaseSha: base,
          pushBeforeSha: _pushPlaceholder,
          currentRef: 'refs/pull/1/merge',
        );
        expect(pullRequest.exitCode, 0, reason: pullRequest.stderr.toString());
        expect(
          await pullRequestOutput.readAsString(),
          'sha=$base\nis_commit=true\n',
        );

        final newRefOutput = File(
          '${repository.path}${Platform.pathSeparator}new-ref-output.txt',
        );
        final newRef = await _runCli(
          script,
          repository,
          newRefOutput,
          eventName: 'push',
          pushBeforeSha: _zeroObject,
          currentRef: 'refs/heads/feature',
        );
        expect(newRef.exitCode, 0, reason: newRef.stderr.toString());
        expect(
          await newRefOutput.readAsString(),
          'sha=$base\nis_commit=true\n',
        );

        final initialOutput = File(
          '${repository.path}${Platform.pathSeparator}initial-output.txt',
        );
        final initial = await _runCli(
          script,
          repository,
          initialOutput,
          eventName: 'push',
          pushBeforeSha: _zeroObject,
          currentRef: 'refs/heads/main',
        );
        expect(initial.exitCode, 0, reason: initial.stderr.toString());
        expect(
          await initialOutput.readAsString(),
          'sha=$_emptyTree\nis_commit=false\n',
        );

        final failureOutput = File(
          '${repository.path}${Platform.pathSeparator}failure-output.txt',
        );
        final failure = await _runCli(
          script,
          repository,
          failureOutput,
          eventName: 'push',
          pushBeforeSha: _missingObject,
          currentRef: 'refs/heads/feature',
        );
        expect(failure.exitCode, 1);
        expect(failure.stderr, contains('refusing to guess'));
        expect(failureOutput.existsSync(), isFalse);

        final unrelatedCommit = (await _runGit(repository, <String>[
          'commit-tree',
          _emptyTree,
          '-m',
          'unrelated',
        ])).stdout.toString().trim();
        await _runGit(repository, <String>[
          'update-ref',
          'refs/heads/unrelated',
          unrelatedCommit,
        ]);
        await _runGit(repository, <String>['switch', 'unrelated']);

        final unrelatedOutput = File(
          '${repository.path}${Platform.pathSeparator}unrelated-output.txt',
        );
        final unrelated = await _runCli(
          script,
          repository,
          unrelatedOutput,
          eventName: 'push',
          pushBeforeSha: _zeroObject,
          currentRef: 'refs/heads/unrelated',
        );
        expect(unrelated.exitCode, 0, reason: unrelated.stderr.toString());
        expect(
          await unrelatedOutput.readAsString(),
          'sha=$_emptyTree\nis_commit=false\n',
        );

        await _runGit(repository, <String>[
          'update-ref',
          '-d',
          'refs/remotes/origin/main',
        ]);
        final fatalOutput = File(
          '${repository.path}${Platform.pathSeparator}fatal-output.txt',
        );
        final fatal = await _runCli(
          script,
          repository,
          fatalOutput,
          eventName: 'push',
          pushBeforeSha: _zeroObject,
          currentRef: 'refs/heads/unrelated',
        );
        expect(fatal.exitCode, 1);
        expect(fatal.stderr, contains('git merge-base failed (128)'));
        expect(fatal.stderr, contains('origin/main'));
        expect(fatalOutput.existsSync(), isFalse);
      } finally {
        await repository.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}

Future<ProcessResult> _runCli(
  String script,
  Directory repository,
  File output, {
  required String eventName,
  required String pushBeforeSha,
  required String currentRef,
  String pullRequestBaseSha = '',
}) {
  return Process.run(
    _dartExecutable,
    <String>[script],
    workingDirectory: repository.path,
    environment: <String, String>{
      'GITHUB_OUTPUT': output.path,
      'EVENT_NAME': eventName,
      'PULL_REQUEST_BASE_SHA': pullRequestBaseSha,
      'PUSH_BEFORE_SHA': pushBeforeSha,
      'DEFAULT_BRANCH': 'main',
      'CURRENT_REF': currentRef,
    },
  );
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

String get _dartExecutable => Platform.isWindows ? 'dart.bat' : 'dart';
