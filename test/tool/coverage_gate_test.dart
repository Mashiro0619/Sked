import 'package:flutter_test/flutter_test.dart';

import '../../tool/src/coverage_gate.dart';

void main() {
  group('CoverageDataset', () {
    test('keeps handwritten lib sources and excludes generated records', () {
      final dataset = CoverageDataset.parse(
        _lcovRecord(r'D:\repo\lib\feature.dart', <int, int>{10: 3, 11: 0}) +
            _lcovRecord(
              r'D:\repo\lib\l10n\app_localizations_en.dart',
              <int, int>{1: 0},
            ) +
            _lcovRecord(r'D:\repo\lib\model.g.dart', <int, int>{1: 0}) +
            _lcovRecord(r'D:\repo\lib\model.freezed.dart', <int, int>{1: 0}) +
            _lcovRecord(r'D:\repo\test\helper.dart', <int, int>{1: 1}),
        sourceRoot: r'D:\repo',
      );

      expect(dataset.files.keys, <String>['lib/feature.dart']);
      expect(dataset.hitLines, 1);
      expect(dataset.foundLines, 2);
      expect(dataset.percentage, 50);
      expect(dataset.includedRecordCount, 1);
      expect(dataset.excludedRecordCount, 4);
      expect(dataset.filteredLcov, contains('SF:lib/feature.dart'));
      expect(dataset.filteredLcov, isNot(contains('app_localizations')));
    });

    test('merges repeated source records without double-counting lines', () {
      final dataset = CoverageDataset.parse(
        _lcovRecord('lib/feature.dart', <int, int>{10: 0, 11: 1}) +
            _lcovRecord('lib/feature.dart', <int, int>{10: 2, 12: 0}),
      );

      expect(dataset.files.values.single.lineHits, <int, int>{
        10: 2,
        11: 1,
        12: 0,
      });
      expect(dataset.hitLines, 2);
      expect(dataset.foundLines, 3);
    });

    test('rejects truncated or malformed LCOV', () {
      expect(
        () => CoverageDataset.parse('SF:lib/a.dart\nDA:1,1\n'),
        throwsFormatException,
      );
      expect(
        () => CoverageDataset.parse(
          'SF:lib/a.dart\nDA:not-a-line,1\nend_of_record\n',
        ),
        throwsFormatException,
      );
    });
  });

  group('ChangedLines', () {
    test('parses added ranges and ignores deleted and generated files', () {
      const diff = '''
diff --git a/lib/feature.dart b/lib/feature.dart
--- a/lib/feature.dart
+++ b/lib/feature.dart
@@ -4,0 +5,2 @@
+one
+two
@@ -9 +11 @@
-old
+new
diff --git a/lib/removed.dart b/lib/removed.dart
--- a/lib/removed.dart
+++ /dev/null
@@ -1 +0,0 @@
-gone
diff --git a/lib/generated.g.dart b/lib/generated.g.dart
--- a/lib/generated.g.dart
+++ b/lib/generated.g.dart
@@ -0,0 +1,2 @@
+one
+two
''';

      final changed = ChangedLines.parseGitDiff(diff);

      expect(changed.linesByFile, <String, Set<int>>{
        'lib/feature.dart': <int>{5, 6, 11},
      });
    });

    test('supports paths with spaces', () {
      const diff = '''
diff --git a/lib/a file.dart b/lib/a file.dart
--- a/lib/a file.dart
+++ b/lib/a file.dart
@@ -1 +1 @@
-old
+new
''';

      expect(ChangedLines.parseGitDiff(diff).linesByFile, <String, Set<int>>{
        'lib/a file.dart': <int>{1},
      });
    });

    test('ignores zero-length new hunks', () {
      const diff = '''
diff --git a/lib/feature.dart b/lib/feature.dart
--- a/lib/feature.dart
+++ b/lib/feature.dart
@@ -1 +1,0 @@
-deleted
''';

      expect(ChangedLines.parseGitDiff(diff).linesByFile, isEmpty);
    });

    test('does not mistake added source text for a new-file header', () {
      const diff = '''
diff --git a/lib/feature.dart b/lib/feature.dart
--- a/lib/feature.dart
+++ b/lib/feature.dart
@@ -1 +1 @@
-old
+++ counter;
@@ -3 +3 @@
-before
+after
''';

      expect(ChangedLines.parseGitDiff(diff).linesByFile, <String, Set<int>>{
        'lib/feature.dart': <int>{1, 3},
      });
    });

    test('uses the destination path for an edited rename', () {
      const diff = '''
diff --git a/lib/old.dart b/lib/new name.dart
similarity index 80%
rename from lib/old.dart
rename to lib/new name.dart
--- a/lib/old.dart
+++ b/lib/new name.dart
@@ -4 +4 @@
-old
+updated
''';

      expect(ChangedLines.parseGitDiff(diff).linesByFile, <String, Set<int>>{
        'lib/new name.dart': <int>{4},
      });
    });

    test('merges tracked and untracked changed lines', () {
      final merged =
          ChangedLines(<String, Set<int>>{
            'lib/a.dart': <int>{1, 2},
          }).mergedWith(
            ChangedLines(<String, Set<int>>{
              'lib/a.dart': <int>{2, 3},
              'lib/b.dart': <int>{1},
            }),
          );

      expect(merged.linesByFile, <String, Set<int>>{
        'lib/a.dart': <int>{1, 2, 3},
        'lib/b.dart': <int>{1},
      });
    });
  });

  group('coverage source inventory', () {
    test(
      'requires every handwritten source or an exact unavailable reason',
      () {
        final dataset = CoverageDataset.parse(
          _lcovRecord('lib/measured.dart', <int, int>{1: 1}) +
              _lcovRecord('lib/should_not_be_exempt.dart', <int, int>{1: 0}),
        );
        final result = validateCoverageInventory(
          dataset: dataset,
          sourcePaths: const <String>[
            'lib/measured.dart',
            'lib/unmeasured.dart',
            'lib/unavailable.dart',
            'lib/should_not_be_exempt.dart',
            'lib/generated.g.dart',
          ],
          unavailableSourceReasons: const <String, String>{
            'lib/unavailable.dart': 'declarations only',
            'lib/should_not_be_exempt.dart': 'stale measured exemption',
            'lib/deleted.dart': 'stale deleted exemption',
          },
        );

        expect(result.sourcePaths, isNot(contains('lib/generated.g.dart')));
        expect(result.missingCoverageSources, <String>['lib/unmeasured.dart']);
        expect(result.unavailableCoverageSources, <String>[
          'lib/unavailable.dart',
        ]);
        expect(result.missingUnavailableSources, <String>['lib/deleted.dart']);
        expect(result.measuredUnavailableSources, <String>[
          'lib/should_not_be_exempt.dart',
        ]);
        expect(result.passed, isFalse);
      },
    );
  });

  group('evaluateCoverage', () {
    test('checks only changed executable lines represented in LCOV', () {
      final dataset = CoverageDataset.parse(
        _lcovRecord('lib/feature.dart', <int, int>{5: 1, 7: 0, 9: 0}),
      );
      final result = evaluateCoverage(
        dataset: dataset,
        changedLines: ChangedLines(<String, Set<int>>{
          'lib/feature.dart': <int>{5, 6, 7},
        }),
        minimumTotalCoverage: 30,
        minimumDiffCoverage: 60,
      );

      expect(result.diffFoundLines, 2);
      expect(result.diffHitLines, 1);
      expect(result.uncoveredChangedLines, <SourceLocation>[
        const SourceLocation('lib/feature.dart', 7),
      ]);
      expect(result.totalPassed, isTrue);
      expect(result.diffPassed, isFalse);
    });

    test('fails when a changed source file is entirely absent from LCOV', () {
      final dataset = CoverageDataset.parse(
        _lcovRecord('lib/existing.dart', <int, int>{1: 1}),
      );
      final result = evaluateCoverage(
        dataset: dataset,
        changedLines: ChangedLines(<String, Set<int>>{
          'lib/new_feature.dart': <int>{2, 3},
        }),
        minimumTotalCoverage: 0,
        minimumDiffCoverage: 0,
      );

      expect(result.diffFoundLines, 0);
      expect(result.diffPercentage, 100);
      expect(result.diffPassed, isFalse);
      expect(result.missingCoverageFiles.single.path, 'lib/new_feature.dart');
    });

    test('reports an explicit unavailable-coverage source without failing', () {
      final dataset = CoverageDataset.parse(
        _lcovRecord('lib/existing.dart', <int, int>{1: 1}),
      );
      final result = evaluateCoverage(
        dataset: dataset,
        changedLines: ChangedLines(<String, Set<int>>{
          'lib/theme/app_motion.dart': <int>{1, 2},
        }),
        minimumTotalCoverage: 0,
        minimumDiffCoverage: 100,
      );

      expect(result.diffPassed, isTrue);
      expect(result.missingCoverageFiles, isEmpty);
      expect(
        result.coverageUnavailableFiles.single.reason,
        contains('compile-time theme constants'),
      );
    });

    test('fails when a tracked handwritten source is absent from LCOV', () {
      final dataset = CoverageDataset.parse(
        _lcovRecord('lib/feature.dart', <int, int>{1: 1}),
      );
      final sourcePaths = <String>[
        'lib/feature.dart',
        'lib/unmeasured.dart',
        ...coverageUnavailableSourceReasons.keys,
      ];
      final result = evaluateCoverage(
        dataset: dataset,
        changedLines: ChangedLines(<String, Set<int>>{}),
        sourcePaths: sourcePaths,
        minimumTotalCoverage: 0,
        minimumDiffCoverage: 0,
      );

      expect(result.sourceInventoryPassed, isFalse);
      expect(result.sourceInventory?.missingCoverageSources, <String>[
        'lib/unmeasured.dart',
      ]);
      expect(result.passed, isFalse);
      expect(
        buildCoverageReport(result, baseRef: 'base'),
        contains('Handwritten sources missing from LCOV'),
      );
      expect(
        githubErrorAnnotations(result),
        contains(contains('file=lib/unmeasured.dart,line=1')),
      );
    });

    test('passes an empty diff when total coverage meets its floor', () {
      final result = evaluateCoverage(
        dataset: CoverageDataset.parse(
          _lcovRecord('lib/feature.dart', <int, int>{1: 1}),
        ),
        changedLines: ChangedLines(<String, Set<int>>{}),
        minimumTotalCoverage: 100,
        minimumDiffCoverage: 100,
      );

      expect(result.passed, isTrue);
    });

    test('ratchets total coverage against the measured base snapshot', () {
      final result = evaluateCoverage(
        dataset: CoverageDataset.parse(
          _lcovRecord('lib/feature.dart', <int, int>{
            for (var line = 1; line <= 100; line++) line: line <= 82 ? 1 : 0,
          }),
        ),
        baselineDataset: CoverageDataset.parse(
          _lcovRecord('lib/feature.dart', <int, int>{
            for (var line = 1; line <= 100; line++) line: line <= 85 ? 1 : 0,
          }),
        ),
        changedLines: ChangedLines(<String, Set<int>>{}),
        minimumTotalCoverage: 81.76,
        minimumDiffCoverage: 100,
      );

      expect(result.dataset.percentage, 82);
      expect(result.effectiveMinimumTotalCoverage, 85);
      expect(result.totalPassed, isFalse);
    });

    test('attributes a total regression to negative file contributions', () {
      final result = evaluateCoverage(
        dataset: CoverageDataset.parse(
          _lcovRecord('lib/high.dart', <int, int>{
                for (var line = 1; line <= 10; line++) line: line <= 4 ? 1 : 0,
              }) +
              _lcovRecord('lib/low.dart', <int, int>{
                for (var line = 1; line <= 10; line++) line: line <= 5 ? 1 : 0,
              }),
        ),
        baselineDataset: CoverageDataset.parse(
          _lcovRecord('lib/high.dart', <int, int>{
                for (var line = 1; line <= 10; line++) line: 1,
              }) +
              _lcovRecord('lib/low.dart', <int, int>{
                for (var line = 1; line <= 10; line++) line: 0,
              }),
        ),
        changedLines: ChangedLines(<String, Set<int>>{}),
        minimumTotalCoverage: 0,
        minimumDiffCoverage: 100,
      );

      final regressions = baselineCoverageRegressions(result);
      expect(regressions.map((file) => file.path), <String>['lib/high.dart']);
      expect(regressions.single.regressedLines, <int>[5, 6, 7, 8, 9, 10]);
      expect(githubErrorAnnotations(result).single, contains('lib/high.dart'));
    });
  });

  test('report and annotations name failing files and lines', () {
    final result = evaluateCoverage(
      dataset: CoverageDataset.parse(
        _lcovRecord('lib/feature.dart', <int, int>{5: 0, 6: 1}),
      ),
      changedLines: ChangedLines(<String, Set<int>>{
        'lib/feature.dart': <int>{5, 6},
        'lib/missing.dart': <int>{10, 11},
      }),
      minimumTotalCoverage: 60,
      minimumDiffCoverage: 80,
    );

    final report = buildCoverageReport(
      result,
      baseRef: 'base',
      headRef: 'HEAD',
    );
    expect(report, contains('Result: FAIL'));
    expect(report, contains('lib/feature.dart:5'));
    expect(report, contains('lib/missing.dart:10-11'));

    final annotations = githubErrorAnnotations(result);
    expect(
      annotations,
      contains(
        '::error file=lib/missing.dart,line=10::Changed Dart file is '
        'absent from LCOV. Exercise it through tests.',
      ),
    );
    expect(
      annotations,
      contains(
        '::error file=lib/feature.dart,line=5::Changed executable line is '
        'not covered.',
      ),
    );
  });

  test('formatLineRanges sorts, deduplicates, and compresses ranges', () {
    expect(formatLineRanges(<int>[8, 3, 4, 4, 6]), '3-4,6,8');
    expect(formatLineRanges(<int>[]), '-');
  });
}

String _lcovRecord(String path, Map<int, int> hits) {
  final hitLines = hits.values.where((int value) => value > 0).length;
  return <String>[
    'SF:$path',
    for (final entry in hits.entries) 'DA:${entry.key},${entry.value}',
    'LF:${hits.length}',
    'LH:$hitLines',
    'end_of_record',
    '',
  ].join('\n');
}
