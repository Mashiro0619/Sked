import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../benchmark/src/benchmark_runner.dart';

void main() {
  test('median handles odd and even sample counts without mutating input', () {
    final odd = [9.0, 1.0, 5.0];
    final even = [8.0, 2.0, 6.0, 4.0];

    expect(benchmarkMedian(odd), 5);
    expect(benchmarkMedian(even), 5);
    expect(odd, [9.0, 1.0, 5.0]);
    expect(even, [8.0, 2.0, 6.0, 4.0]);
    expect(() => benchmarkMedian(const []), throwsArgumentError);
  });

  test('calibration grows in bounded steps and respects the cap', () {
    expect(
      nextBenchmarkOperationCount(
        currentOperations: 2,
        elapsedTicks: 1,
        stopwatchFrequency: 1000,
        target: const Duration(seconds: 1),
        maximumOperations: 100,
      ),
      16,
    );
    expect(
      nextBenchmarkOperationCount(
        currentOperations: 80,
        elapsedTicks: 1,
        stopwatchFrequency: 1000,
        target: const Duration(seconds: 1),
        maximumOperations: 100,
      ),
      100,
    );
    expect(
      nextBenchmarkOperationCount(
        currentOperations: 3,
        elapsedTicks: 1000,
        stopwatchFrequency: 1000,
        target: const Duration(seconds: 1),
        maximumOperations: 100,
      ),
      3,
    );
  });

  test('stable checksum distinguishes values and is repeatable', () {
    String buildChecksum(String value, int number, bool flag) {
      final checksum = StableChecksum()
        ..addString(value)
        ..addInt(number)
        ..addBool(flag);
      return checksum.finish();
    }

    final first = buildChecksum('course', 42, true);

    expect(first, buildChecksum('course', 42, true));
    expect(first, startsWith('fnv1a64-utf16le:'));
    expect(first, isNot(buildChecksum('course', 43, true)));
    expect(first, isNot(buildChecksum('course', 42, false)));
  });

  test('runner reports samples and rejects a changed checksum', () async {
    var calls = 0;
    final expected = StableChecksum()..addInt(7);
    final benchmarkCase = PerformanceBenchmarkCase.typed<int>(
      name: 'fixed',
      operation: () {
        calls += 1;
        return 7;
      },
      checksum: (value) {
        final checksum = StableChecksum()..addInt(value);
        return checksum.finish();
      },
      expectedChecksum: expected.finish(),
      metrics: (value) => {'value': value},
    );

    final results = await runPerformanceBenchmarks(
      [benchmarkCase],
      config: const BenchmarkRunConfig(
        targetSample: Duration.zero,
        warmupBatches: 1,
        sampleBatches: 3,
        operationsPerSampleOverride: 2,
      ),
    );

    expect(results.single.samplesMicrosPerOperation, hasLength(3));
    expect(results.single.operationsPerSample, 2);
    expect(results.single.checksum, expected.finish());
    expect(results.single.metrics, {'value': 7});
    expect(results.single.toJson()['metrics'], {'value': 7});
    expect(calls, 9);

    final invalid = PerformanceBenchmarkCase.typed<int>(
      name: 'invalid',
      operation: () => 8,
      checksum: (value) {
        final checksum = StableChecksum()..addInt(value);
        return checksum.finish();
      },
      expectedChecksum: expected.finish(),
    );
    await expectLater(
      runPerformanceBenchmarks(
        [invalid],
        config: const BenchmarkRunConfig(
          targetSample: Duration.zero,
          warmupBatches: 0,
          sampleBatches: 1,
        ),
      ),
      throwsStateError,
    );
  });

  test('report is JSON serializable and labels cannot escape output paths', () {
    const result = BenchmarkCaseResult(
      name: 'sample',
      operationsPerSample: 2,
      warmupBatches: 1,
      samplesMicrosPerOperation: [2, 4, 3],
      medianMicrosPerOperation: 3,
      medianAbsoluteDeviation: 1,
      minimumMicrosPerOperation: 2,
      checksum: 'checksum',
    );
    const report = BenchmarkReport(
      label: 'before-lru-r1',
      revision: 'abc123',
      datasetVersion: 1,
      runtime: {'platform': 'test'},
      dataset: {'events': 1},
      results: [result],
    );

    final encoded = report.encode(pretty: false);
    expect(encoded, contains('"schemaVersion":1'));
    expect(jsonDecode(encoded), isA<Map<String, dynamic>>());
    expect(safeBenchmarkLabel('before-lru-r1'), 'before-lru-r1');
    expect(() => safeBenchmarkLabel('../escape'), throwsArgumentError);
    expect(() => safeBenchmarkLabel(''), throwsArgumentError);
  });
}
