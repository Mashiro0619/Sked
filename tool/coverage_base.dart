import 'dart:io';

import 'src/coverage_base.dart';

Future<void> main() async {
  try {
    final environment = Platform.environment;
    final outputPath = environment['GITHUB_OUTPUT']?.trim() ?? '';
    if (outputPath.isEmpty) {
      throw const FormatException('GITHUB_OUTPUT is not set.');
    }
    final resolution = await resolveCoverageBase(
      eventName: environment['EVENT_NAME'] ?? '',
      pullRequestBaseSha: environment['PULL_REQUEST_BASE_SHA'] ?? '',
      pushBeforeSha: environment['PUSH_BEFORE_SHA'] ?? '',
      defaultBranch: environment['DEFAULT_BRANCH'] ?? '',
      currentRef: environment['CURRENT_REF'] ?? '',
      git: ProcessCoverageBaseGit(workingDirectory: Directory.current.path),
    );
    stdout.writeln(resolution.message);
    await File(outputPath).writeAsString(
      'sha=${resolution.sha}\n'
      'is_commit=${resolution.isCommit}\n',
      mode: FileMode.append,
      flush: true,
    );
  } catch (error) {
    final message = 'Coverage base resolution failed: $error';
    stderr.writeln(message);
    stdout.writeln('::error::${_escapeGitHubMessage(message)}');
    exitCode = 1;
  }
}

String _escapeGitHubMessage(String value) {
  return value
      .replaceAll('%', '%25')
      .replaceAll('\r', '%0D')
      .replaceAll('\n', '%0A');
}
