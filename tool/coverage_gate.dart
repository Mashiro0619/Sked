import 'dart:convert';
import 'dart:io';

import 'src/coverage_gate.dart';

const String _usage = '''
Usage: dart run tool/coverage_gate.dart --base-ref <git-ref> [options]

Options:
  --base-ref <ref>          Required comparison base.
  --head-ref <ref>          Comparison head. Omit to include the working tree.
  --lcov <path>             Input LCOV (default: coverage/lcov.info).
  --output <path>           Filtered LCOV output
                            (default: coverage/lcov.filtered.info).
  --report <path>           Text/Markdown report
                            (default: coverage/coverage-summary.txt).
  --baseline-lcov <path>    Optional LCOV measured at the comparison commit.
  --baseline-root <path>    Source root used by absolute baseline SF paths.
  --minimum-total <percent> Overall floor (default: 81.76).
  --minimum-diff <percent>  Changed-line floor (default: 90).
  --github-annotations      Emit GitHub Actions file/line errors.
  --help                    Show this help.
''';

Future<void> main(List<String> arguments) async {
  _Options? options;
  try {
    options = _Options.parse(arguments);
    if (options.showHelp) {
      stdout.write(_usage);
      return;
    }

    final sourceRoot = Directory.current.absolute.path;
    final inputFile = File(options.lcovPath);
    if (!inputFile.existsSync()) {
      throw StateError('LCOV input does not exist: ${options.lcovPath}');
    }
    final dataset = CoverageDataset.parse(
      await inputFile.readAsString(),
      sourceRoot: sourceRoot,
    );
    CoverageDataset? baselineDataset;
    if (options.baselineLcovPath case final baselinePath?) {
      final baselineFile = File(baselinePath);
      if (!baselineFile.existsSync()) {
        throw StateError('Baseline LCOV does not exist: $baselinePath');
      }
      baselineDataset = CoverageDataset.parse(
        await baselineFile.readAsString(),
        sourceRoot: options.baselineSourceRoot ?? sourceRoot,
      );
    }

    final diff = await _loadGitDiff(
      baseRef: options.baseRef!,
      headRef: options.headRef,
      workingDirectory: sourceRoot,
    );
    var changes = ChangedLines.parseGitDiff(diff);
    if (options.headRef == null) {
      changes = changes.mergedWith(
        await _loadUntrackedChanges(workingDirectory: sourceRoot),
      );
    }
    final sourcePaths = await _loadCoverageSourcePaths(sourceRoot: sourceRoot);
    final result = evaluateCoverage(
      dataset: dataset,
      changedLines: changes,
      sourcePaths: sourcePaths,
      minimumTotalCoverage: options.minimumTotalCoverage,
      minimumDiffCoverage: options.minimumDiffCoverage,
      baselineDataset: baselineDataset,
    );
    final report = buildCoverageReport(
      result,
      baseRef: options.baseRef!,
      headRef: options.headRef,
    );

    await _writeFile(options.outputPath, dataset.filteredLcov);
    await _writeFile(options.reportPath, report);
    stdout.write(report);
    if (options.githubAnnotations && !result.passed) {
      for (final annotation in githubErrorAnnotations(result)) {
        stdout.writeln(annotation);
      }
    }
    if (!result.passed) {
      exitCode = 1;
    }
  } on _UsageException catch (error) {
    stderr.writeln(error.message);
    stderr.write(_usage);
    exitCode = 64;
  } catch (error) {
    final message = 'Coverage gate failed: $error';
    stderr.writeln(message);
    if (arguments.contains('--github-annotations')) {
      stdout.writeln('::error::${_escapeGitHubMessage(message)}');
    }
    final reportPath = options?.reportPath ?? 'coverage/coverage-summary.txt';
    await _writeFile(
      reportPath,
      '# Coverage gate\n\nResult: ERROR\n\n$message\n',
    );
    exitCode = 2;
  }
}

String _escapeGitHubMessage(String value) {
  return value
      .replaceAll('%', '%25')
      .replaceAll('\r', '%0D')
      .replaceAll('\n', '%0A');
}

Future<String> _loadGitDiff({
  required String baseRef,
  required String? headRef,
  required String workingDirectory,
}) async {
  for (final ref in <String?>[baseRef, headRef]) {
    if (ref != null && (ref.isEmpty || ref.startsWith('-'))) {
      throw _UsageException('Invalid git ref: $ref');
    }
  }
  final revisions = <String>[baseRef];
  if (headRef != null) {
    revisions.add(headRef);
  }
  final arguments = <String>[
    '-c',
    'core.quotepath=false',
    'diff',
    '--unified=0',
    '--no-color',
    '--no-ext-diff',
    '--diff-filter=ACMR',
    ...revisions,
    '--',
    'lib',
  ];
  final process = await Process.run(
    'git',
    arguments,
    workingDirectory: workingDirectory,
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  if (process.exitCode != 0) {
    throw StateError(
      'git diff failed (${process.exitCode}): ${process.stderr}',
    );
  }
  return process.stdout as String;
}

Future<ChangedLines> _loadUntrackedChanges({
  required String workingDirectory,
}) async {
  final process = await Process.run(
    'git',
    <String>[
      '-c',
      'core.quotepath=false',
      'ls-files',
      '--others',
      '--exclude-standard',
      '-z',
      '--',
      'lib',
    ],
    workingDirectory: workingDirectory,
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  if (process.exitCode != 0) {
    throw StateError(
      'git ls-files failed (${process.exitCode}): ${process.stderr}',
    );
  }

  final changes = <String, Set<int>>{};
  for (final rawPath in (process.stdout as String).split('\u0000')) {
    final path = normalizeSourcePath(rawPath);
    if (!isIncludedCoverageSource(path)) {
      continue;
    }
    final platformPath = path.replaceAll('/', Platform.pathSeparator);
    final file = File(
      '$workingDirectory${Platform.pathSeparator}$platformPath',
    );
    final lineCount = (await file.readAsLines()).length;
    if (lineCount > 0) {
      changes[path] = <int>{for (var line = 1; line <= lineCount; line++) line};
    }
  }
  return ChangedLines(changes);
}

Future<List<String>> _loadCoverageSourcePaths({
  required String sourceRoot,
}) async {
  final libDirectory = Directory('$sourceRoot${Platform.pathSeparator}lib');
  if (!libDirectory.existsSync()) {
    throw StateError('Source directory does not exist: ${libDirectory.path}');
  }

  final paths = <String>[];
  await for (final entity in libDirectory.list(
    recursive: true,
    followLinks: false,
  )) {
    if (entity is! File || !entity.path.endsWith('.dart')) {
      continue;
    }
    final path = normalizeSourcePath(
      entity.absolute.path,
      sourceRoot: sourceRoot,
    );
    if (isIncludedCoverageSource(path)) {
      paths.add(path);
    }
  }
  paths.sort();
  return paths;
}

Future<void> _writeFile(String path, String contents) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsString(contents);
}

class _Options {
  const _Options({
    required this.baseRef,
    required this.headRef,
    required this.lcovPath,
    required this.outputPath,
    required this.reportPath,
    required this.baselineLcovPath,
    required this.baselineSourceRoot,
    required this.minimumTotalCoverage,
    required this.minimumDiffCoverage,
    required this.githubAnnotations,
    required this.showHelp,
  });

  factory _Options.parse(List<String> arguments) {
    String? baseRef;
    String? headRef;
    var lcovPath = 'coverage/lcov.info';
    var outputPath = 'coverage/lcov.filtered.info';
    var reportPath = 'coverage/coverage-summary.txt';
    String? baselineLcovPath;
    String? baselineSourceRoot;
    var minimumTotalCoverage = defaultMinimumTotalCoverage;
    var minimumDiffCoverage = defaultMinimumDiffCoverage;
    var githubAnnotations = false;
    var showHelp = false;

    String readValue(int index, String option) {
      if (index + 1 >= arguments.length) {
        throw _UsageException('$option requires a value.');
      }
      return arguments[index + 1];
    }

    for (var index = 0; index < arguments.length; index++) {
      final argument = arguments[index];
      switch (argument) {
        case '--base-ref':
          baseRef = readValue(index, argument);
          index++;
        case '--head-ref':
          headRef = readValue(index, argument);
          index++;
        case '--lcov':
          lcovPath = readValue(index, argument);
          index++;
        case '--output':
          outputPath = readValue(index, argument);
          index++;
        case '--report':
          reportPath = readValue(index, argument);
          index++;
        case '--baseline-lcov':
          baselineLcovPath = readValue(index, argument);
          index++;
        case '--baseline-root':
          baselineSourceRoot = readValue(index, argument);
          index++;
        case '--minimum-total':
          minimumTotalCoverage = _readPercentage(
            readValue(index, argument),
            argument,
          );
          index++;
        case '--minimum-diff':
          minimumDiffCoverage = _readPercentage(
            readValue(index, argument),
            argument,
          );
          index++;
        case '--github-annotations':
          githubAnnotations = true;
        case '--help':
        case '-h':
          showHelp = true;
        default:
          throw _UsageException('Unknown option: $argument');
      }
    }

    if (!showHelp && (baseRef == null || baseRef.isEmpty)) {
      throw _UsageException('--base-ref is required.');
    }
    if (baselineSourceRoot != null && baselineLcovPath == null) {
      throw _UsageException('--baseline-root requires --baseline-lcov.');
    }
    return _Options(
      baseRef: baseRef,
      headRef: headRef,
      lcovPath: lcovPath,
      outputPath: outputPath,
      reportPath: reportPath,
      baselineLcovPath: baselineLcovPath,
      baselineSourceRoot: baselineSourceRoot,
      minimumTotalCoverage: minimumTotalCoverage,
      minimumDiffCoverage: minimumDiffCoverage,
      githubAnnotations: githubAnnotations,
      showHelp: showHelp,
    );
  }

  final String? baseRef;
  final String? headRef;
  final String lcovPath;
  final String outputPath;
  final String reportPath;
  final String? baselineLcovPath;
  final String? baselineSourceRoot;
  final double minimumTotalCoverage;
  final double minimumDiffCoverage;
  final bool githubAnnotations;
  final bool showHelp;
}

double _readPercentage(String value, String option) {
  final parsed = double.tryParse(value);
  if (parsed == null || !parsed.isFinite || parsed < 0 || parsed > 100) {
    throw _UsageException('$option must be a number between 0 and 100.');
  }
  return parsed;
}

class _UsageException implements Exception {
  const _UsageException(this.message);

  final String message;
}
