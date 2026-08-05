import 'dart:convert';
import 'dart:io';

enum CoverageBaseSource {
  eventCommit,
  initialDefaultBranch,
  defaultBranchMergeBase,
  emptyUnrelatedHistory,
}

class CoverageBaseResolution {
  const CoverageBaseResolution({
    required this.sha,
    required this.isCommit,
    required this.source,
    required this.message,
  });

  final String sha;
  final bool isCommit;
  final CoverageBaseSource source;
  final String message;
}

abstract interface class CoverageBaseGit {
  Future<bool> isCommit(String ref);

  Future<void> fetchCommit(String ref);

  Future<String?> mergeBase(String left, String right);

  Future<String> writeEmptyTree();
}

Future<CoverageBaseResolution> resolveCoverageBase({
  required String eventName,
  required String pullRequestBaseSha,
  required String pushBeforeSha,
  required String defaultBranch,
  required String currentRef,
  required CoverageBaseGit git,
}) async {
  final normalizedDefaultBranch = defaultBranch.trim();
  if (normalizedDefaultBranch.isEmpty) {
    throw const FormatException('The repository default branch is empty.');
  }
  final eventBaseSha = switch (eventName.trim()) {
    'pull_request' => pullRequestBaseSha.trim(),
    'push' => pushBeforeSha.trim(),
    final unsupported => throw FormatException(
      'Unsupported coverage event: $unsupported',
    ),
  };

  if (eventBaseSha.isNotEmpty && !_zeroObjectId.hasMatch(eventBaseSha)) {
    _validateEventSha(eventBaseSha);
    if (!await git.isCommit(eventBaseSha)) {
      await git.fetchCommit(eventBaseSha);
    }
    if (!await git.isCommit(eventBaseSha)) {
      throw StateError(
        'Cannot resolve event base $eventBaseSha; refusing to guess after a '
        'force-push.',
      );
    }
    return CoverageBaseResolution(
      sha: eventBaseSha,
      isCommit: true,
      source: CoverageBaseSource.eventCommit,
      message: 'Using event comparison base $eventBaseSha',
    );
  }

  if (currentRef.trim() == 'refs/heads/$normalizedDefaultBranch') {
    final emptyTree = await git.writeEmptyTree();
    return CoverageBaseResolution(
      sha: emptyTree,
      isCommit: false,
      source: CoverageBaseSource.initialDefaultBranch,
      message: 'Initial default-branch push: comparing against the empty tree',
    );
  }

  final defaultBranchRef = 'origin/$normalizedDefaultBranch';
  final mergeBase = await git.mergeBase('HEAD', defaultBranchRef);
  if (mergeBase != null) {
    return CoverageBaseResolution(
      sha: mergeBase,
      isCommit: true,
      source: CoverageBaseSource.defaultBranchMergeBase,
      message:
          'Unavailable/new ref: comparing against '
          '$normalizedDefaultBranch at $mergeBase',
    );
  }

  final emptyTree = await git.writeEmptyTree();
  return CoverageBaseResolution(
    sha: emptyTree,
    isCommit: false,
    source: CoverageBaseSource.emptyUnrelatedHistory,
    message:
        'No common default-branch ancestor: comparing against the empty '
        'tree',
  );
}

final RegExp _zeroObjectId = RegExp(r'^(?:0{40}|0{64})$');
final RegExp _objectId = RegExp(r'^(?:[0-9a-fA-F]{40}|[0-9a-fA-F]{64})$');

void _validateEventSha(String sha) {
  if (!_objectId.hasMatch(sha)) {
    throw FormatException('Invalid event base SHA: $sha');
  }
}

class ProcessCoverageBaseGit implements CoverageBaseGit {
  const ProcessCoverageBaseGit({required this.workingDirectory});

  final String workingDirectory;

  @override
  Future<bool> isCommit(String ref) async {
    final result = await _run(<String>['cat-file', '-e', '$ref^{commit}']);
    return result.exitCode == 0;
  }

  @override
  Future<void> fetchCommit(String ref) async {
    await _run(<String>['fetch', '--no-tags', '--depth=1', 'origin', ref]);
  }

  @override
  Future<String?> mergeBase(String left, String right) async {
    final result = await _run(<String>['merge-base', left, right]);
    if (result.exitCode == 1) {
      return null;
    }
    if (result.exitCode != 0) {
      final output = result.stdout.toString().trim();
      final error = result.stderr.toString().trim();
      throw StateError(
        'git merge-base failed (${result.exitCode}): '
        '${error.isEmpty ? output : error}',
      );
    }
    final value = result.stdout.toString().trim();
    if (!_objectId.hasMatch(value)) {
      throw StateError('git merge-base returned an invalid object ID: $value');
    }
    return value;
  }

  @override
  Future<String> writeEmptyTree() async {
    final process = await Process.start('git', const <String>[
      'mktree',
    ], workingDirectory: workingDirectory);
    await process.stdin.close();
    final stdoutFuture = utf8.decoder.bind(process.stdout).join();
    final stderrFuture = utf8.decoder.bind(process.stderr).join();
    final exitCode = await process.exitCode;
    final output = (await stdoutFuture).trim();
    final error = (await stderrFuture).trim();
    if (exitCode != 0 || !_objectId.hasMatch(output)) {
      throw StateError(
        'git mktree failed ($exitCode): '
        '${error.isEmpty ? output : error}',
      );
    }
    return output;
  }

  Future<ProcessResult> _run(List<String> arguments) {
    return Process.run(
      'git',
      arguments,
      workingDirectory: workingDirectory,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
  }
}
