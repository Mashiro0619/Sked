import 'package:flutter_test/flutter_test.dart';

import '../../tool/src/coverage_base.dart';

const _pullRequestBase = '1111111111111111111111111111111111111111';
const _pushBefore = '2222222222222222222222222222222222222222';
const _fetchedBase = '3333333333333333333333333333333333333333';
const _mergeBase = '4444444444444444444444444444444444444444';
const _emptyTree = '4b825dc642cb6eb9a060e54bf8d69288fbee4904';

class _FakeGit implements CoverageBaseGit {
  _FakeGit({
    Set<String> commits = const <String>{},
    Set<String> fetchableCommits = const <String>{},
    this.mergeBaseResult,
  }) : commits = <String>{...commits},
       fetchableCommits = <String>{...fetchableCommits};

  final Set<String> commits;
  final Set<String> fetchableCommits;
  final String? mergeBaseResult;
  final List<String> fetched = <String>[];
  final List<(String, String)> mergeBaseCalls = <(String, String)>[];
  var emptyTreeCalls = 0;

  @override
  Future<void> fetchCommit(String ref) async {
    fetched.add(ref);
    if (fetchableCommits.contains(ref)) commits.add(ref);
  }

  @override
  Future<bool> isCommit(String ref) async => commits.contains(ref);

  @override
  Future<String?> mergeBase(String left, String right) async {
    mergeBaseCalls.add((left, right));
    return mergeBaseResult;
  }

  @override
  Future<String> writeEmptyTree() async {
    emptyTreeCalls += 1;
    return _emptyTree;
  }
}

Future<CoverageBaseResolution> _resolve(
  _FakeGit git, {
  String eventName = 'push',
  String pullRequestBaseSha = '',
  String pushBeforeSha = '',
  String currentRef = 'refs/heads/feature',
}) {
  return resolveCoverageBase(
    eventName: eventName,
    pullRequestBaseSha: pullRequestBaseSha,
    pushBeforeSha: pushBeforeSha,
    defaultBranch: 'main',
    currentRef: currentRef,
    git: git,
  );
}

void main() {
  test('pull requests select the PR base instead of push metadata', () async {
    final git = _FakeGit(commits: const <String>{_pullRequestBase});

    final result = await _resolve(
      git,
      eventName: 'pull_request',
      pullRequestBaseSha: _pullRequestBase,
      pushBeforeSha: _pushBefore,
    );

    expect(result.sha, _pullRequestBase);
    expect(result.isCommit, isTrue);
    expect(result.source, CoverageBaseSource.eventCommit);
    expect(git.fetched, isEmpty);
  });

  test('ordinary pushes select the before commit', () async {
    final git = _FakeGit(commits: const <String>{_pushBefore});

    final result = await _resolve(
      git,
      pushBeforeSha: _pushBefore,
      pullRequestBaseSha: _pullRequestBase,
    );

    expect(result.sha, _pushBefore);
    expect(result.source, CoverageBaseSource.eventCommit);
  });

  test('an event commit can be fetched by exact object ID', () async {
    final git = _FakeGit(fetchableCommits: const <String>{_fetchedBase});

    final result = await _resolve(git, pushBeforeSha: _fetchedBase);

    expect(result.sha, _fetchedBase);
    expect(git.fetched, <String>[_fetchedBase]);
  });

  test('an unresolved force-push base fails closed', () async {
    final git = _FakeGit();

    await expectLater(
      _resolve(git, pushBeforeSha: _pushBefore),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('refusing to guess'),
        ),
      ),
    );
    expect(git.fetched, <String>[_pushBefore]);
    expect(git.mergeBaseCalls, isEmpty);
    expect(git.emptyTreeCalls, 0);
  });

  test('an initial default-branch push uses the empty tree', () async {
    final git = _FakeGit();

    final result = await _resolve(
      git,
      pushBeforeSha: '0000000000000000000000000000000000000000',
      currentRef: 'refs/heads/main',
    );

    expect(result.sha, _emptyTree);
    expect(result.isCommit, isFalse);
    expect(result.source, CoverageBaseSource.initialDefaultBranch);
    expect(git.mergeBaseCalls, isEmpty);
    expect(git.emptyTreeCalls, 1);
  });

  test('a new branch uses its merge-base with the default branch', () async {
    final git = _FakeGit(mergeBaseResult: _mergeBase);

    final result = await _resolve(
      git,
      pushBeforeSha: '0000000000000000000000000000000000000000',
    );

    expect(result.sha, _mergeBase);
    expect(result.isCommit, isTrue);
    expect(result.source, CoverageBaseSource.defaultBranchMergeBase);
    expect(git.mergeBaseCalls, <(String, String)>[('HEAD', 'origin/main')]);
  });

  test('unrelated new history uses the empty tree', () async {
    final git = _FakeGit();

    final result = await _resolve(git);

    expect(result.sha, _emptyTree);
    expect(result.isCommit, isFalse);
    expect(result.source, CoverageBaseSource.emptyUnrelatedHistory);
    expect(git.emptyTreeCalls, 1);
  });

  test(
    'unsupported events and malformed SHAs fail before git access',
    () async {
      final unsupportedGit = _FakeGit();
      await expectLater(
        _resolve(unsupportedGit, eventName: 'workflow_dispatch'),
        throwsFormatException,
      );

      final malformedGit = _FakeGit();
      await expectLater(
        _resolve(malformedGit, pushBeforeSha: '--not-a-sha'),
        throwsFormatException,
      );
      await expectLater(
        _resolve(malformedGit, pushBeforeSha: '0000'),
        throwsFormatException,
      );
      expect(malformedGit.fetched, isEmpty);
    },
  );
}
