import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import '../integration_test/support/capture_output_directory.dart';
import 'src/agent_performance_suite.dart';
import 'src/benchmark_runner.dart';

const _benchmarkSources = [
  'benchmark/agent_performance_benchmark_test.dart',
  'benchmark/src/agent_performance_fixtures.dart',
  'benchmark/src/agent_performance_queries.dart',
  'benchmark/src/agent_performance_runtime.dart',
  'benchmark/src/agent_performance_suite.dart',
  'benchmark/src/benchmark_fixtures.dart',
  'benchmark/src/benchmark_runner.dart',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('records the fixed offline Agent workloads', () async {
    const verifyOnly = bool.fromEnvironment('SKED_BENCHMARK_VERIFY_ONLY');
    const revision = String.fromEnvironment('SKED_BENCHMARK_REVISION');
    const referencePath = String.fromEnvironment(
      'SKED_AGENT_BENCHMARK_CONTRACT',
    );
    const selected = String.fromEnvironment('SKED_AGENT_BENCHMARK_CASES');
    final caseNames = selected.isEmpty
        ? agentPerformanceCaseNames
        : selected.split(',').map((value) => value.trim()).toList();
    final label = safeBenchmarkLabel(
      const String.fromEnvironment(
        'SKED_BENCHMARK_LABEL',
        defaultValue: 'agent-local',
      ),
    );
    final sourceHashes = <String, String>{};
    for (final file in _benchmarkSources) {
      sourceHashes[file] = sha256
          .convert(await File(file).readAsBytes())
          .toString();
    }
    Map<String, Object?>? reference;
    if (referencePath.isNotEmpty) {
      if (!path.isAbsolute(referencePath)) {
        throw ArgumentError('SKED_AGENT_BENCHMARK_CONTRACT must be absolute.');
      }
      reference = (jsonDecode(await File(referencePath).readAsString()) as Map)
          .cast<String, Object?>();
    }
    final output = createCaptureOutputDirectory(
      label: 'agent-performance-benchmark',
      configuredPath: const String.fromEnvironment('SKED_BENCHMARK_OUTPUT_DIR'),
    );
    final reportFile = File(path.join(output.path, 'agent-host-$label.json'));
    final failureFile = File(
      path.join(output.path, 'agent-host-$label.failed.json'),
    );
    if (await reportFile.exists() || await failureFile.exists()) {
      throw StateError(
        'Use a fresh label or output directory; reports are retained.',
      );
    }
    try {
      final report = await runAgentPerformanceBenchmarks(
        label: label,
        revision: revision,
        verifyOnly: verifyOnly,
        caseNames: caseNames,
        reference: reference,
        benchmarkSources: sourceHashes,
        sourceNote: const String.fromEnvironment('SKED_BENCHMARK_SOURCE_NOTE'),
      );
      await reportFile.writeAsString(
        '${const JsonEncoder.withIndent('  ').convert(report)}\n',
      );
      stdout.writeln('Agent benchmark report: ${reportFile.absolute.path}');
      expect(report['cases'], hasLength(caseNames.length));
      expect(report['network'], {'httpAttempts': 0, 'modelAttempts': 0});
    } catch (error) {
      final report = {
        'status': 'failed',
        'measurement': verifyOnly ? 'verification-only' : 'timed',
        'label': label,
        'revision': revision,
        'benchmarkSources': sourceHashes,
        'cases': caseNames,
        if (error is AgentPerformanceFailure) ...error.report,
        'error': error.toString(),
      };
      await failureFile.writeAsString(
        '${const JsonEncoder.withIndent('  ').convert(report)}\n',
      );
      stdout.writeln(
        'Failed Agent benchmark report: ${failureFile.absolute.path}',
      );
      rethrow;
    }
  }, timeout: Timeout.none);
}
