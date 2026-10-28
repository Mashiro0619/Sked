import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/utils/time_utils.dart';

import '../integration_test/support/capture_output_directory.dart';
import 'src/benchmark_fixtures.dart';
import 'src/benchmark_runner.dart';
import 'src/performance_suite.dart';

String _parsedChecksum(List<DateTime?> values) {
  final checksum = StableChecksum()..addInt(values.length);
  for (final value in values) {
    checksum.addString(value?.toIso8601String() ?? '<invalid>');
  }
  return checksum.finish();
}

void main() {
  test(
    'records strict date parsing and representative occurrence workloads',
    () async {
      const label = String.fromEnvironment(
        'SKED_BENCHMARK_LABEL',
        defaultValue: 'date-local',
      );
      const revision = String.fromEnvironment(
        'SKED_BENCHMARK_REVISION',
        defaultValue: 'unknown',
      );
      final directory = createCaptureOutputDirectory(
        label: 'date-benchmark',
        configuredPath: const String.fromEnvironment(
          'SKED_BENCHMARK_OUTPUT_DIR',
        ),
      );
      final fixtures = PerformanceFixtures.build();
      final fields = [
        for (final schedule in fixtures.generalData5000.schedules)
          for (final event in schedule.events) ...[
            event.startDateTimeIso,
            event.endDateTimeIso,
          ],
      ];
      expect(fields.length, 10000);
      // Fixture dates are valid ISO fields. The native parser is an independent
      // reference, evaluated before timing; the occurrence cases retain their
      // existing fixed expected checksums from the main suite.
      final expected = _parsedChecksum(fields.map(DateTime.parse).toList());
      final cases = [
        PerformanceBenchmarkCase.typed<List<DateTime?>>(
          name: 'date.strict_iso_10000_fields',
          operation: () => fields.map(tryParseStrictIsoDateTime).toList(),
          checksum: _parsedChecksum,
          expectedChecksum: expected,
        ),
        ...buildPerformanceBenchmarkCases(fixtures).where(
          (benchmarkCase) => const {
            'occurrence.5000_42d_cold',
            'occurrence.5000_180d_hot_cache',
          }.contains(benchmarkCase.name),
        ),
      ];
      final report = BenchmarkReport(
        label: safeBenchmarkLabel(label),
        revision: revision,
        datasetVersion: performanceDatasetVersion,
        runtime: benchmarkRuntimeMetadata('flutter-test-host-jit'),
        dataset: {
          ...fixtures.manifest,
          'strictDateFieldCount': fields.length,
          'strictDateReferenceChecksum': expected,
        },
        results: await runPerformanceBenchmarks(cases),
      );
      final output = File('${directory.path}/windows-host-${report.label}.json')
        ..writeAsStringSync('${report.encode()}\n');
      stdout.writeln('Benchmark report: ${output.absolute.path}');
      expect(report.results.length, 3);
    },
    timeout: Timeout.none,
  );
}
