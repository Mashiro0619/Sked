import 'dart:collection';

const double defaultMinimumTotalCoverage = 81.76;
const double defaultMinimumDiffCoverage = 90;

// These sources cannot appear in the VM LCOV used by the gate. Keep this list
// exact: a newly unmeasured source must fail until tests exercise it or a
// reviewer documents why coverage is technically unavailable.
const Map<String, String> coverageUnavailableSourceReasons = <String, String>{
  'lib/models/timetable_models.dart': 'is an export-only library',
  'lib/services/app_backup_restore_journal_factory_stub.dart':
      'is selected only when dart:io is unavailable',
  'lib/services/app_instance_lease.dart':
      'contains a conditional factory interface only',
  'lib/services/app_instance_lease_stub.dart':
      'is selected only when neither dart:io nor JavaScript interop is present',
  'lib/services/app_instance_web_lock.dart': 'contains interfaces only',
  'lib/services/app_instance_web_lock_browser.dart':
      'is browser-only and is exercised by the separate Chrome CI test',
  'lib/services/app_storage_layout.dart': 'is an export-only library',
  'lib/services/app_storage_layout_stub.dart':
      'is selected only when dart:io is unavailable',
  'lib/l10n/app_localization_delegates.dart':
      'contains compile-time localization delegate constants only',
  'lib/theme/app_motion.dart': 'contains compile-time theme constants only',
  'lib/utils/constants.dart': 'contains compile-time constants only',
  'lib/widgets/app_layout_tokens.dart':
      'contains compile-time layout constants only',
  'lib/services/app_data_clear_service.dart':
      'contains a conditional platform factory interface only',
  'lib/services/app_data_clear_service_stub.dart':
      'is selected only when dart:io is unavailable',
  'lib/services/app_exit_controller.dart':
      'contains a conditional platform exit interface only',
  'lib/services/app_exit_controller_stub.dart':
      'is selected only when dart:io is unavailable',
  'lib/services/app_exit_controller_io.dart':
      'terminates the native process and cannot be exercised in VM tests',
};

final RegExp _localizationSourcePattern = RegExp(
  r'^lib/l10n/app_localizations[^/]*\.dart$',
);
final RegExp _generatedSourcePattern = RegExp(
  r'(?:^|/)[^/]+\.(?:g|freezed)\.dart$',
);

String normalizeSourcePath(String path, {String? sourceRoot}) {
  var normalized = path.trim().replaceAll('\\', '/');
  while (normalized.startsWith('./')) {
    normalized = normalized.substring(2);
  }

  if (sourceRoot != null) {
    var normalizedRoot = sourceRoot.trim().replaceAll('\\', '/');
    while (normalizedRoot.endsWith('/')) {
      normalizedRoot = normalizedRoot.substring(0, normalizedRoot.length - 1);
    }
    final comparisonPath = _isWindowsDrivePath(normalized)
        ? normalized.toLowerCase()
        : normalized;
    final comparisonRoot = _isWindowsDrivePath(normalizedRoot)
        ? normalizedRoot.toLowerCase()
        : normalizedRoot;
    if (comparisonPath == comparisonRoot) {
      return '';
    }
    if (comparisonPath.startsWith('$comparisonRoot/')) {
      normalized = normalized.substring(normalizedRoot.length + 1);
    }
  }

  return normalized;
}

bool isIncludedCoverageSource(String path) {
  final normalized = normalizeSourcePath(path);
  return normalized.startsWith('lib/') &&
      normalized.endsWith('.dart') &&
      !_localizationSourcePattern.hasMatch(normalized) &&
      !_generatedSourcePattern.hasMatch(normalized);
}

bool _isWindowsDrivePath(String path) {
  return RegExp(r'^[A-Za-z]:/').hasMatch(path);
}

class CoverageFile {
  CoverageFile({required this.path, required Map<int, int> lineHits})
    : lineHits = SplayTreeMap<int, int>.from(lineHits);

  final String path;
  final SplayTreeMap<int, int> lineHits;

  int get foundLines => lineHits.length;

  int get hitLines => lineHits.values.where((int hits) => hits > 0).length;

  double get percentage => coveragePercentage(hitLines, foundLines);

  Iterable<int> get uncoveredLines sync* {
    for (final entry in lineHits.entries) {
      if (entry.value <= 0) {
        yield entry.key;
      }
    }
  }
}

class CoverageDataset {
  CoverageDataset._({
    required this.files,
    required this.filteredLcov,
    required this.includedRecordCount,
    required this.excludedRecordCount,
  });

  factory CoverageDataset.parse(String input, {String? sourceRoot}) {
    final normalizedInput = input
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    final records = <List<String>>[];
    var currentRecord = <String>[];

    for (final line in normalizedInput.split('\n')) {
      if (line == 'end_of_record') {
        currentRecord.add(line);
        records.add(currentRecord);
        currentRecord = <String>[];
      } else if (line.isNotEmpty || currentRecord.isNotEmpty) {
        currentRecord.add(line);
      }
    }
    if (currentRecord.any((String line) => line.isNotEmpty)) {
      throw const FormatException(
        'LCOV ended before the final end_of_record marker.',
      );
    }

    final fileHits = <String, Map<int, int>>{};
    final filteredRecords = <String>[];
    var includedRecords = 0;
    var excludedRecords = 0;

    for (var recordIndex = 0; recordIndex < records.length; recordIndex++) {
      final record = records[recordIndex];
      final sourceLines = record
          .where((String line) => line.startsWith('SF:'))
          .toList(growable: false);
      if (sourceLines.length != 1) {
        throw FormatException(
          'LCOV record ${recordIndex + 1} must contain exactly one SF entry.',
        );
      }

      final sourcePath = normalizeSourcePath(
        sourceLines.single.substring(3),
        sourceRoot: sourceRoot,
      );
      if (!isIncludedCoverageSource(sourcePath)) {
        excludedRecords++;
        continue;
      }

      final hits = fileHits.putIfAbsent(sourcePath, () => <int, int>{});
      for (final line in record) {
        if (!line.startsWith('DA:')) {
          continue;
        }
        final fields = line.substring(3).split(',');
        if (fields.length < 2) {
          throw FormatException('Invalid DA entry in $sourcePath: $line');
        }
        final lineNumber = int.tryParse(fields[0]);
        final hitCount = int.tryParse(fields[1]);
        if (lineNumber == null || lineNumber <= 0 || hitCount == null) {
          throw FormatException('Invalid DA entry in $sourcePath: $line');
        }
        hits.update(
          lineNumber,
          (int previous) => previous + hitCount,
          ifAbsent: () => hitCount,
        );
      }

      includedRecords++;
      filteredRecords.add(
        record
            .map(
              (String line) => line.startsWith('SF:') ? 'SF:$sourcePath' : line,
            )
            .join('\n'),
      );
    }

    final files = SplayTreeMap<String, CoverageFile>();
    for (final entry in fileHits.entries) {
      files[entry.key] = CoverageFile(path: entry.key, lineHits: entry.value);
    }

    return CoverageDataset._(
      files: UnmodifiableMapView<String, CoverageFile>(files),
      filteredLcov: filteredRecords.isEmpty
          ? ''
          : '${filteredRecords.join('\n')}\n',
      includedRecordCount: includedRecords,
      excludedRecordCount: excludedRecords,
    );
  }

  final Map<String, CoverageFile> files;
  final String filteredLcov;
  final int includedRecordCount;
  final int excludedRecordCount;

  int get foundLines => files.values.fold<int>(
    0,
    (int total, CoverageFile file) => total + file.foundLines,
  );

  int get hitLines => files.values.fold<int>(
    0,
    (int total, CoverageFile file) => total + file.hitLines,
  );

  double get percentage => coveragePercentage(hitLines, foundLines);
}

class CoverageInventoryResult {
  CoverageInventoryResult({
    required Iterable<String> sourcePaths,
    required Iterable<String> missingCoverageSources,
    required Iterable<String> unavailableCoverageSources,
    required Iterable<String> missingUnavailableSources,
    required Iterable<String> measuredUnavailableSources,
  }) : sourcePaths = List<String>.unmodifiable(sourcePaths),
       missingCoverageSources = List<String>.unmodifiable(
         missingCoverageSources,
       ),
       unavailableCoverageSources = List<String>.unmodifiable(
         unavailableCoverageSources,
       ),
       missingUnavailableSources = List<String>.unmodifiable(
         missingUnavailableSources,
       ),
       measuredUnavailableSources = List<String>.unmodifiable(
         measuredUnavailableSources,
       );

  final List<String> sourcePaths;
  final List<String> missingCoverageSources;
  final List<String> unavailableCoverageSources;
  final List<String> missingUnavailableSources;
  final List<String> measuredUnavailableSources;

  int get measuredSourceCount =>
      sourcePaths.length -
      missingCoverageSources.length -
      unavailableCoverageSources.length;

  bool get passed =>
      missingCoverageSources.isEmpty &&
      missingUnavailableSources.isEmpty &&
      measuredUnavailableSources.isEmpty;
}

CoverageInventoryResult validateCoverageInventory({
  required CoverageDataset dataset,
  required Iterable<String> sourcePaths,
  Map<String, String> unavailableSourceReasons =
      coverageUnavailableSourceReasons,
}) {
  final sources = SplayTreeSet<String>.from(
    sourcePaths.map(normalizeSourcePath).where(isIncludedCoverageSource),
  );
  final missingCoverage = <String>[];
  final unavailableCoverage = <String>[];
  for (final source in sources) {
    final file = dataset.files[source];
    if (file != null && file.foundLines > 0) {
      continue;
    }
    if (unavailableSourceReasons.containsKey(source)) {
      unavailableCoverage.add(source);
    } else {
      missingCoverage.add(source);
    }
  }

  final missingUnavailable = <String>[];
  final measuredUnavailable = <String>[];
  for (final source in unavailableSourceReasons.keys.toList()..sort()) {
    if (!sources.contains(source)) {
      missingUnavailable.add(source);
    } else if ((dataset.files[source]?.foundLines ?? 0) > 0) {
      measuredUnavailable.add(source);
    }
  }

  return CoverageInventoryResult(
    sourcePaths: sources,
    missingCoverageSources: missingCoverage,
    unavailableCoverageSources: unavailableCoverage,
    missingUnavailableSources: missingUnavailable,
    measuredUnavailableSources: measuredUnavailable,
  );
}

class ChangedLines {
  ChangedLines(Map<String, Set<int>> linesByFile)
    : linesByFile = UnmodifiableMapView<String, Set<int>>(
        _sortedChangedLines(linesByFile),
      );

  factory ChangedLines.parseGitDiff(String diff) {
    final changes = <String, Set<int>>{};
    String? currentPath;
    var awaitingNewPath = false;

    for (final line
        in diff.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n')) {
      if (line.startsWith('diff --git ')) {
        currentPath = null;
        awaitingNewPath = true;
        continue;
      }
      if (awaitingNewPath && line.startsWith('+++ ')) {
        final rawPath = line.substring(4).split('\t').first;
        awaitingNewPath = false;
        if (rawPath == '/dev/null') {
          currentPath = null;
          continue;
        }
        currentPath = normalizeSourcePath(
          rawPath.startsWith('b/') ? rawPath.substring(2) : rawPath,
        );
        if (!isIncludedCoverageSource(currentPath)) {
          currentPath = null;
        }
        continue;
      }

      if (!line.startsWith('@@ ') || currentPath == null) {
        continue;
      }
      final match = RegExp(r'^@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@')
          .firstMatch(line);
      if (match == null) {
        throw FormatException('Invalid unified diff hunk: $line');
      }
      final start = int.parse(match.group(1)!);
      final count = match.group(2) == null ? 1 : int.parse(match.group(2)!);
      if (count == 0) {
        continue;
      }
      final fileChanges = changes.putIfAbsent(currentPath, () => <int>{});
      for (var lineNumber = start; lineNumber < start + count; lineNumber++) {
        fileChanges.add(lineNumber);
      }
    }

    return ChangedLines(changes);
  }

  final Map<String, Set<int>> linesByFile;

  int get fileCount => linesByFile.length;

  ChangedLines mergedWith(ChangedLines other) {
    final merged = <String, Set<int>>{
      for (final entry in linesByFile.entries) entry.key: <int>{...entry.value},
    };
    for (final entry in other.linesByFile.entries) {
      merged.putIfAbsent(entry.key, () => <int>{}).addAll(entry.value);
    }
    return ChangedLines(merged);
  }
}

SplayTreeMap<String, Set<int>> _sortedChangedLines(
  Map<String, Set<int>> linesByFile,
) {
  final sorted = SplayTreeMap<String, Set<int>>();
  for (final entry in linesByFile.entries) {
    sorted[entry.key] = UnmodifiableSetView<int>(
      SplayTreeSet<int>.from(entry.value),
    );
  }
  return sorted;
}

class SourceLocation {
  const SourceLocation(this.path, this.line);

  final String path;
  final int line;

  @override
  bool operator ==(Object other) {
    return other is SourceLocation && other.path == path && other.line == line;
  }

  @override
  int get hashCode => Object.hash(path, line);

  @override
  String toString() => '$path:$line';
}

class MissingCoverageFile {
  MissingCoverageFile({required this.path, required Iterable<int> changedLines})
    : changedLines = List<int>.unmodifiable(changedLines);

  final String path;
  final List<int> changedLines;
}

class CoverageUnavailableFile extends MissingCoverageFile {
  CoverageUnavailableFile({
    required super.path,
    required super.changedLines,
    required this.reason,
  });

  final String reason;
}

class CoverageGateResult {
  CoverageGateResult({
    required this.dataset,
    required this.changedLines,
    required this.minimumTotalCoverage,
    required this.minimumDiffCoverage,
    required this.baselineDataset,
    required this.diffFoundLines,
    required this.diffHitLines,
    required this.uncoveredChangedLines,
    required this.missingCoverageFiles,
    required this.coverageUnavailableFiles,
    required this.sourceInventory,
  });

  final CoverageDataset dataset;
  final ChangedLines changedLines;
  final double minimumTotalCoverage;
  final double minimumDiffCoverage;
  final CoverageDataset? baselineDataset;
  final int diffFoundLines;
  final int diffHitLines;
  final List<SourceLocation> uncoveredChangedLines;
  final List<MissingCoverageFile> missingCoverageFiles;
  final List<CoverageUnavailableFile> coverageUnavailableFiles;
  final CoverageInventoryResult? sourceInventory;

  double get diffPercentage => coveragePercentage(diffHitLines, diffFoundLines);

  double get effectiveMinimumTotalCoverage {
    final baselinePercentage = baselineDataset?.percentage;
    if (baselinePercentage != null &&
        baselinePercentage > minimumTotalCoverage) {
      return baselinePercentage;
    }
    return minimumTotalCoverage;
  }

  bool get totalPassed =>
      dataset.foundLines > 0 &&
      dataset.percentage + 1e-9 >= effectiveMinimumTotalCoverage;

  bool get diffPassed =>
      missingCoverageFiles.isEmpty &&
      diffPercentage + 1e-9 >= minimumDiffCoverage;

  bool get sourceInventoryPassed => sourceInventory?.passed ?? true;

  bool get passed => totalPassed && diffPassed && sourceInventoryPassed;
}

class CoverageFileRegression {
  CoverageFileRegression({
    required this.path,
    required this.baselineFile,
    required this.currentFile,
    required this.contributionDelta,
  });

  final String path;
  final CoverageFile? baselineFile;
  final CoverageFile? currentFile;

  // Change in this file's (hit - baselineRate * found) margin. These deltas
  // sum to the whole-report margin, so negative values identify the files
  // that actually pull HEAD below its base snapshot.
  final double contributionDelta;

  Iterable<int> get regressedLines sync* {
    final baselineLines = baselineFile?.lineHits;
    if (baselineLines == null) {
      return;
    }
    final currentLines = currentFile?.lineHits;
    for (final entry in baselineLines.entries) {
      if (entry.value > 0 && (currentLines?[entry.key] ?? 0) <= 0) {
        yield entry.key;
      }
    }
  }
}

List<CoverageFileRegression> baselineCoverageRegressions(
  CoverageGateResult result,
) {
  final baseline = result.baselineDataset;
  if (baseline == null) {
    return const <CoverageFileRegression>[];
  }

  final baselineRate = baseline.percentage / 100;
  final paths = SplayTreeSet<String>()
    ..addAll(baseline.files.keys)
    ..addAll(result.dataset.files.keys);
  final regressions = <CoverageFileRegression>[];
  for (final path in paths) {
    final baselineFile = baseline.files[path];
    final currentFile = result.dataset.files[path];
    final baselineMargin =
        (baselineFile?.hitLines ?? 0) -
        baselineRate * (baselineFile?.foundLines ?? 0);
    final currentMargin =
        (currentFile?.hitLines ?? 0) -
        baselineRate * (currentFile?.foundLines ?? 0);
    final delta = currentMargin - baselineMargin;
    if (delta < -1e-9) {
      regressions.add(
        CoverageFileRegression(
          path: path,
          baselineFile: baselineFile,
          currentFile: currentFile,
          contributionDelta: delta,
        ),
      );
    }
  }
  regressions.sort((CoverageFileRegression a, CoverageFileRegression b) {
    final deltaComparison = a.contributionDelta.compareTo(b.contributionDelta);
    return deltaComparison != 0 ? deltaComparison : a.path.compareTo(b.path);
  });
  return List<CoverageFileRegression>.unmodifiable(regressions);
}

CoverageGateResult evaluateCoverage({
  required CoverageDataset dataset,
  required ChangedLines changedLines,
  Iterable<String> sourcePaths = const <String>[],
  double minimumTotalCoverage = defaultMinimumTotalCoverage,
  double minimumDiffCoverage = defaultMinimumDiffCoverage,
  CoverageDataset? baselineDataset,
}) {
  if (minimumTotalCoverage < 0 || minimumTotalCoverage > 100) {
    throw ArgumentError.value(
      minimumTotalCoverage,
      'minimumTotalCoverage',
      'must be between 0 and 100',
    );
  }
  if (minimumDiffCoverage < 0 || minimumDiffCoverage > 100) {
    throw ArgumentError.value(
      minimumDiffCoverage,
      'minimumDiffCoverage',
      'must be between 0 and 100',
    );
  }
  if (baselineDataset != null && baselineDataset.foundLines == 0) {
    throw ArgumentError.value(
      baselineDataset,
      'baselineDataset',
      'must contain at least one covered source line',
    );
  }

  var diffFoundLines = 0;
  var diffHitLines = 0;
  final uncoveredChangedLines = <SourceLocation>[];
  final missingCoverageFiles = <MissingCoverageFile>[];
  final coverageUnavailableFiles = <CoverageUnavailableFile>[];
  final sourcePathList = sourcePaths.toList(growable: false);
  final sourceInventory = sourcePathList.isEmpty
      ? null
      : validateCoverageInventory(
          dataset: dataset,
          sourcePaths: sourcePathList,
        );

  for (final entry in changedLines.linesByFile.entries) {
    final file = dataset.files[entry.key];
    if (file == null) {
      final unavailableReason = coverageUnavailableSourceReasons[entry.key];
      if (unavailableReason == null) {
        missingCoverageFiles.add(
          MissingCoverageFile(path: entry.key, changedLines: entry.value),
        );
      } else {
        coverageUnavailableFiles.add(
          CoverageUnavailableFile(
            path: entry.key,
            changedLines: entry.value,
            reason: unavailableReason,
          ),
        );
      }
      continue;
    }

    for (final lineNumber in entry.value) {
      final hits = file.lineHits[lineNumber];
      if (hits == null) {
        continue;
      }
      diffFoundLines++;
      if (hits > 0) {
        diffHitLines++;
      } else {
        uncoveredChangedLines.add(SourceLocation(entry.key, lineNumber));
      }
    }
  }

  missingCoverageFiles.sort(
    (MissingCoverageFile a, MissingCoverageFile b) => a.path.compareTo(b.path),
  );
  coverageUnavailableFiles.sort(
    (CoverageUnavailableFile a, CoverageUnavailableFile b) =>
        a.path.compareTo(b.path),
  );
  uncoveredChangedLines.sort((SourceLocation a, SourceLocation b) {
    final pathComparison = a.path.compareTo(b.path);
    return pathComparison != 0 ? pathComparison : a.line.compareTo(b.line);
  });

  return CoverageGateResult(
    dataset: dataset,
    changedLines: changedLines,
    minimumTotalCoverage: minimumTotalCoverage,
    minimumDiffCoverage: minimumDiffCoverage,
    baselineDataset: baselineDataset,
    diffFoundLines: diffFoundLines,
    diffHitLines: diffHitLines,
    uncoveredChangedLines: List<SourceLocation>.unmodifiable(
      uncoveredChangedLines,
    ),
    missingCoverageFiles: List<MissingCoverageFile>.unmodifiable(
      missingCoverageFiles,
    ),
    coverageUnavailableFiles: List<CoverageUnavailableFile>.unmodifiable(
      coverageUnavailableFiles,
    ),
    sourceInventory: sourceInventory,
  );
}

double coveragePercentage(int hitLines, int foundLines) {
  return foundLines == 0 ? 100 : hitLines * 100 / foundLines;
}

String buildCoverageReport(
  CoverageGateResult result, {
  required String baseRef,
  String? headRef,
}) {
  final buffer = StringBuffer()
    ..writeln('# Coverage gate')
    ..writeln()
    ..writeln('Result: ${result.passed ? 'PASS' : 'FAIL'}')
    ..writeln('Comparison: $baseRef -> ${headRef ?? 'working tree'}')
    ..writeln(
      'Configured total floor: '
      '${_formatPercentage(result.minimumTotalCoverage)}',
    );
  if (result.baselineDataset case final baseline?) {
    buffer.writeln(
      'Base snapshot: ${baseline.hitLines}/${baseline.foundLines} '
      '(${_formatPercentage(baseline.percentage)})',
    );
  }
  buffer
    ..writeln(
      'Total: ${result.dataset.hitLines}/${result.dataset.foundLines} '
      '(${_formatPercentage(result.dataset.percentage)}), required '
      '${_formatPercentage(result.effectiveMinimumTotalCoverage)} '
      '[${result.totalPassed ? 'PASS' : 'FAIL'}]',
    )
    ..writeln(
      'Diff: ${result.diffHitLines}/${result.diffFoundLines} '
      '(${_formatPercentage(result.diffPercentage)}), minimum '
      '${_formatPercentage(result.minimumDiffCoverage)} '
      '[${result.diffPassed ? 'PASS' : 'FAIL'}]',
    )
    ..writeln(
      'LCOV records: ${result.dataset.includedRecordCount} included, '
      '${result.dataset.excludedRecordCount} excluded',
    )
    ..writeln('Changed Dart files: ${result.changedLines.fileCount}');

  if (result.sourceInventory case final inventory?) {
    buffer.writeln(
      'Source inventory: ${inventory.measuredSourceCount} measured, '
      '${inventory.unavailableCoverageSources.length} explicitly unavailable, '
      '${inventory.sourcePaths.length} tracked '
      '[${result.sourceInventoryPassed ? 'PASS' : 'FAIL'}]',
    );
    if (inventory.missingCoverageSources.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('## Handwritten sources missing from LCOV')
        ..writeln();
      for (final path in inventory.missingCoverageSources) {
        buffer.writeln('- $path');
      }
    }
    final staleDeclarations = <String>{
      ...inventory.missingUnavailableSources,
      ...inventory.measuredUnavailableSources,
    }.toList()..sort();
    if (staleDeclarations.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('## Stale unavailable-coverage declarations')
        ..writeln();
      for (final path in staleDeclarations) {
        buffer.writeln('- $path');
      }
    }
  }

  if (result.missingCoverageFiles.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln('## Changed files missing from LCOV')
      ..writeln();
    for (final file in result.missingCoverageFiles) {
      buffer.writeln('- ${file.path}:${formatLineRanges(file.changedLines)}');
    }
  }

  if (result.coverageUnavailableFiles.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln('## Changed files with unavailable VM coverage')
      ..writeln();
    for (final file in result.coverageUnavailableFiles) {
      buffer.writeln(
        '- ${file.path}:${formatLineRanges(file.changedLines)} '
        '(${file.reason})',
      );
    }
  }

  if (result.uncoveredChangedLines.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln('## Uncovered changed lines')
      ..writeln();
    final linesByFile = <String, List<int>>{};
    for (final location in result.uncoveredChangedLines) {
      linesByFile.putIfAbsent(location.path, () => <int>[]).add(location.line);
    }
    for (final entry in linesByFile.entries) {
      buffer.writeln('- ${entry.key}:${formatLineRanges(entry.value)}');
    }
  }

  if (!result.totalPassed && result.baselineDataset != null) {
    final regressions = baselineCoverageRegressions(result);
    if (regressions.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('## Negative coverage contributions from base')
        ..writeln()
        ..writeln('| File | Base | Current | Margin delta |')
        ..writeln('|---|---:|---:|---:|');
      for (final regression in regressions) {
        buffer.writeln(
          '| ${regression.path} | '
          '${_fileCoverage(regression.baselineFile)} | '
          '${_fileCoverage(regression.currentFile)} | '
          '${regression.contributionDelta.toStringAsFixed(2)} lines |',
        );
      }
    }
  }

  final filesByCoverage = result.dataset.files.values.toList()
    ..sort((CoverageFile a, CoverageFile b) {
      final percentageComparison = a.percentage.compareTo(b.percentage);
      return percentageComparison != 0
          ? percentageComparison
          : a.path.compareTo(b.path);
    });
  buffer
    ..writeln()
    ..writeln('## File coverage')
    ..writeln()
    ..writeln('| File | Lines | Coverage |')
    ..writeln('|---|---:|---:|');
  for (final file in filesByCoverage) {
    buffer.writeln(
      '| ${file.path} | ${file.hitLines}/${file.foundLines} | '
      '${_formatPercentage(file.percentage)} |',
    );
  }

  return buffer.toString();
}

String formatLineRanges(Iterable<int> lines) {
  final sorted = SplayTreeSet<int>.from(lines);
  if (sorted.isEmpty) {
    return '-';
  }

  final ranges = <String>[];
  int? start;
  int? previous;
  void finishRange() {
    if (start == null || previous == null) {
      return;
    }
    ranges.add(start == previous ? '$start' : '$start-$previous');
  }

  for (final line in sorted) {
    if (start == null) {
      start = line;
      previous = line;
    } else if (line == previous! + 1) {
      previous = line;
    } else {
      finishRange();
      start = line;
      previous = line;
    }
  }
  finishRange();
  return ranges.join(',');
}

String _formatPercentage(double value) => '${value.toStringAsFixed(4)}%';

String _fileCoverage(CoverageFile? file) {
  if (file == null) {
    return 'absent';
  }
  return '${file.hitLines}/${file.foundLines} '
      '(${_formatPercentage(file.percentage)})';
}

List<String> githubErrorAnnotations(CoverageGateResult result) {
  final annotations = <String>[];
  if (result.sourceInventory case final inventory?) {
    for (final path in inventory.missingCoverageSources) {
      annotations.add(
        _githubError(
          path,
          1,
          'Handwritten Dart source is absent from LCOV. Exercise it through '
          'tests or document why VM coverage is unavailable.',
        ),
      );
    }
    for (final path in <String>{
      ...inventory.missingUnavailableSources,
      ...inventory.measuredUnavailableSources,
    }) {
      annotations.add(
        _githubError(
          path,
          1,
          'Unavailable-coverage declaration is stale. Remove or update it.',
        ),
      );
    }
  }
  for (final file in result.missingCoverageFiles) {
    final line = file.changedLines.isEmpty ? 1 : file.changedLines.first;
    annotations.add(
      _githubError(
        file.path,
        line,
        'Changed Dart file is absent from LCOV. Exercise it through tests.',
      ),
    );
  }
  for (final location in result.uncoveredChangedLines.take(50)) {
    annotations.add(
      _githubError(
        location.path,
        location.line,
        'Changed executable line is not covered.',
      ),
    );
  }

  if (!result.totalPassed && result.baselineDataset != null) {
    for (final regression in baselineCoverageRegressions(result).take(20)) {
      final line =
          regression.regressedLines.firstOrNull ??
          regression.currentFile?.uncoveredLines.firstOrNull ??
          1;
      annotations.add(
        _githubError(
          regression.path,
          line,
          'Coverage contribution regressed from '
          '${_fileCoverage(regression.baselineFile)} to '
          '${_fileCoverage(regression.currentFile)} '
          '(${regression.contributionDelta.toStringAsFixed(2)} lines).',
        ),
      );
    }
  } else if (!result.totalPassed && result.dataset.files.isNotEmpty) {
    final lowestCoverageFiles = result.dataset.files.values.toList()
      ..sort((CoverageFile a, CoverageFile b) {
        final comparison = a.percentage.compareTo(b.percentage);
        return comparison != 0 ? comparison : a.path.compareTo(b.path);
      });
    for (final file in lowestCoverageFiles.take(10)) {
      final firstUncovered = file.uncoveredLines.firstOrNull;
      annotations.add(
        _githubError(
          file.path,
          firstUncovered ?? 1,
          'File coverage is ${_formatPercentage(file.percentage)}; total '
          'coverage is ${_formatPercentage(result.dataset.percentage)}, '
          'below ${_formatPercentage(result.effectiveMinimumTotalCoverage)}.',
        ),
      );
    }
  }
  return annotations;
}

String _githubError(String path, int line, String message) {
  return '::error file=${_escapeGitHubProperty(path)},line=$line::'
      '${_escapeGitHubMessage(message)}';
}

String _escapeGitHubProperty(String value) {
  return _escapeGitHubMessage(value)
      .replaceAll(':', '%3A')
      .replaceAll(',', '%2C');
}

String _escapeGitHubMessage(String value) {
  return value
      .replaceAll('%', '%25')
      .replaceAll('\r', '%0D')
      .replaceAll('\n', '%0A');
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
