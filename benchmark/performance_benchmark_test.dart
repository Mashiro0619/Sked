import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'src/performance_suite.dart';

void main() {
  test('records the fixed performance suite', () async {
    const label = String.fromEnvironment(
      'SKED_BENCHMARK_LABEL',
      defaultValue: 'local',
    );
    const revision = String.fromEnvironment(
      'SKED_BENCHMARK_REVISION',
      defaultValue: 'unknown',
    );
    final report = await runPerformanceSuite(
      label: label,
      revision: revision,
      runtime: 'flutter-test-host-jit',
    );
    final outputDirectory = Directory('build/benchmarks')
      ..createSync(recursive: true);
    final output = File(
      '${outputDirectory.path}/windows-host-${report.label}.json',
    )..writeAsStringSync('${report.encode()}\n');

    stdout.writeln('Benchmark report: ${output.absolute.path}');
    expect(report.results, isNotEmpty);
  }, timeout: Timeout.none);
}
