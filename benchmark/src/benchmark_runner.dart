import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

typedef BenchmarkOperation = Object Function();
typedef BenchmarkChecksum = String Function(Object result);
typedef BenchmarkMetrics = Map<String, num> Function(Object result);

Object? _benchmarkSink;

class PerformanceBenchmarkCase {
  const PerformanceBenchmarkCase({
    required this.name,
    required this.operation,
    required this.checksum,
    required this.expectedChecksum,
    this.metrics,
  });

  static PerformanceBenchmarkCase typed<T extends Object>({
    required String name,
    required T Function() operation,
    required String Function(T result) checksum,
    required String expectedChecksum,
    Map<String, num> Function(T result)? metrics,
  }) {
    return PerformanceBenchmarkCase(
      name: name,
      operation: operation,
      checksum: (result) => checksum(result as T),
      expectedChecksum: expectedChecksum,
      metrics: metrics == null ? null : (result) => metrics(result as T),
    );
  }

  final String name;
  final BenchmarkOperation operation;
  final BenchmarkChecksum checksum;
  final String expectedChecksum;
  final BenchmarkMetrics? metrics;
}

class BenchmarkRunConfig {
  const BenchmarkRunConfig({
    this.targetSample = const Duration(milliseconds: 250),
    this.warmupBatches = 5,
    this.sampleBatches = 11,
    this.maximumOperationsPerSample = 1 << 24,
    this.operationsPerSampleOverride,
  });

  final Duration targetSample;
  final int warmupBatches;
  final int sampleBatches;
  final int maximumOperationsPerSample;
  final int? operationsPerSampleOverride;

  void validate() {
    if (targetSample.isNegative ||
        warmupBatches < 0 ||
        sampleBatches < 1 ||
        sampleBatches.isEven ||
        maximumOperationsPerSample < 1 ||
        (operationsPerSampleOverride != null &&
            operationsPerSampleOverride! < 1)) {
      throw ArgumentError('Benchmark run configuration is invalid.');
    }
  }
}

class BenchmarkCaseResult {
  const BenchmarkCaseResult({
    required this.name,
    required this.operationsPerSample,
    required this.warmupBatches,
    required this.samplesMicrosPerOperation,
    required this.medianMicrosPerOperation,
    required this.medianAbsoluteDeviation,
    required this.minimumMicrosPerOperation,
    required this.checksum,
    this.metrics = const {},
  });

  final String name;
  final int operationsPerSample;
  final int warmupBatches;
  final List<double> samplesMicrosPerOperation;
  final double medianMicrosPerOperation;
  final double medianAbsoluteDeviation;
  final double minimumMicrosPerOperation;
  final String checksum;
  final Map<String, num> metrics;

  Map<String, Object> toJson() => {
    'name': name,
    'unit': 'us/op',
    'operationsPerSample': operationsPerSample,
    'warmupBatches': warmupBatches,
    'sampleBatches': samplesMicrosPerOperation.length,
    'samples': samplesMicrosPerOperation,
    'median': medianMicrosPerOperation,
    'mad': medianAbsoluteDeviation,
    'minimum': minimumMicrosPerOperation,
    'checksum': checksum,
    if (metrics.isNotEmpty) 'metrics': metrics,
  };
}

class BenchmarkReport {
  const BenchmarkReport({
    required this.label,
    required this.revision,
    required this.datasetVersion,
    required this.runtime,
    required this.dataset,
    required this.results,
  });

  final String label;
  final String revision;
  final int datasetVersion;
  final Map<String, Object> runtime;
  final Map<String, Object> dataset;
  final List<BenchmarkCaseResult> results;

  Map<String, Object> toJson() => {
    'schemaVersion': 1,
    'datasetVersion': datasetVersion,
    'label': label,
    'revision': revision,
    'runtime': runtime,
    'dataset': dataset,
    'cases': results.map((result) => result.toJson()).toList(),
  };

  String encode({bool pretty = true}) {
    return pretty
        ? const JsonEncoder.withIndent('  ').convert(toJson())
        : jsonEncode(toJson());
  }
}

Future<List<BenchmarkCaseResult>> runPerformanceBenchmarks(
  List<PerformanceBenchmarkCase> cases, {
  BenchmarkRunConfig config = const BenchmarkRunConfig(),
}) async {
  config.validate();
  final results = <BenchmarkCaseResult>[];
  for (final benchmarkCase in cases) {
    results.add(await _measureCase(benchmarkCase, config));
  }
  return results;
}

Future<BenchmarkCaseResult> _measureCase(
  PerformanceBenchmarkCase benchmarkCase,
  BenchmarkRunConfig config,
) async {
  final verificationResult = benchmarkCase.operation();
  _benchmarkSink = verificationResult;
  final checksumBefore = benchmarkCase.checksum(verificationResult);
  _verifyChecksum(benchmarkCase, checksumBefore);

  final operationsPerSample =
      config.operationsPerSampleOverride ??
      _calibrateOperationsPerSample(benchmarkCase.operation, config);

  for (var index = 0; index < config.warmupBatches; index += 1) {
    _runBatch(benchmarkCase.operation, operationsPerSample);
    await Future<void>.delayed(Duration.zero);
  }

  final samples = <double>[];
  Object? finalResult;
  for (var index = 0; index < config.sampleBatches; index += 1) {
    final stopwatch = Stopwatch()..start();
    finalResult = _runBatch(benchmarkCase.operation, operationsPerSample);
    stopwatch.stop();
    samples.add(
      stopwatch.elapsedTicks *
          Duration.microsecondsPerSecond /
          stopwatch.frequency /
          operationsPerSample,
    );
    await Future<void>.delayed(Duration.zero);
  }

  final checksumAfter = benchmarkCase.checksum(finalResult!);
  _verifyChecksum(benchmarkCase, checksumAfter);
  if (checksumAfter != checksumBefore) {
    throw StateError(
      '${benchmarkCase.name} produced inconsistent checksums: '
      '$checksumBefore then $checksumAfter.',
    );
  }

  final median = benchmarkMedian(samples);
  return BenchmarkCaseResult(
    name: benchmarkCase.name,
    operationsPerSample: operationsPerSample,
    warmupBatches: config.warmupBatches,
    samplesMicrosPerOperation: List<double>.unmodifiable(samples),
    medianMicrosPerOperation: median,
    medianAbsoluteDeviation: benchmarkMedian(
      samples.map((sample) => (sample - median).abs()).toList(),
    ),
    minimumMicrosPerOperation: samples.reduce(
      (current, sample) => sample < current ? sample : current,
    ),
    checksum: checksumAfter,
    metrics: Map<String, num>.unmodifiable(
      benchmarkCase.metrics?.call(finalResult) ?? const {},
    ),
  );
}

void _verifyChecksum(PerformanceBenchmarkCase benchmarkCase, String actual) {
  if (actual != benchmarkCase.expectedChecksum) {
    throw StateError(
      '${benchmarkCase.name} checksum changed: expected '
      '${benchmarkCase.expectedChecksum}, got $actual.',
    );
  }
}

int _calibrateOperationsPerSample(
  BenchmarkOperation operation,
  BenchmarkRunConfig config,
) {
  if (config.targetSample == Duration.zero) return 1;
  var operations = 1;
  for (var attempt = 0; attempt < 8; attempt += 1) {
    final stopwatch = Stopwatch()..start();
    _runBatch(operation, operations);
    stopwatch.stop();
    final next = nextBenchmarkOperationCount(
      currentOperations: operations,
      elapsedTicks: stopwatch.elapsedTicks,
      stopwatchFrequency: stopwatch.frequency,
      target: config.targetSample,
      maximumOperations: config.maximumOperationsPerSample,
    );
    if (next == operations) return operations;
    operations = next;
  }
  return operations;
}

Object _runBatch(BenchmarkOperation operation, int operations) {
  Object? result;
  for (var index = 0; index < operations; index += 1) {
    result = operation();
  }
  _benchmarkSink = result;
  return _benchmarkSink!;
}

int nextBenchmarkOperationCount({
  required int currentOperations,
  required int elapsedTicks,
  required int stopwatchFrequency,
  required Duration target,
  required int maximumOperations,
}) {
  if (currentOperations < 1 ||
      elapsedTicks < 0 ||
      stopwatchFrequency < 1 ||
      target.isNegative ||
      maximumOperations < 1) {
    throw ArgumentError('Benchmark calibration input is invalid.');
  }
  if (currentOperations >= maximumOperations || target == Duration.zero) {
    return currentOperations.clamp(1, maximumOperations);
  }
  if (elapsedTicks == 0) {
    return (currentOperations * 8).clamp(1, maximumOperations);
  }
  final targetTicks =
      target.inMicroseconds *
      stopwatchFrequency /
      Duration.microsecondsPerSecond;
  if (elapsedTicks >= targetTicks) return currentOperations;
  final estimated = (currentOperations * targetTicks / elapsedTicks).ceil();
  final boundedGrowth = currentOperations * 8;
  return estimated.clamp(
    currentOperations + 1,
    boundedGrowth < maximumOperations ? boundedGrowth : maximumOperations,
  );
}

double benchmarkMedian(List<double> values) {
  if (values.isEmpty) {
    throw ArgumentError.value(values, 'values', 'must not be empty');
  }
  final sorted = [...values]..sort();
  final middle = sorted.length ~/ 2;
  if (sorted.length.isOdd) return sorted[middle];
  return (sorted[middle - 1] + sorted[middle]) / 2;
}

Map<String, Object> benchmarkRuntimeMetadata(String runtime) => {
  'runtime': runtime,
  'platform': Platform.operatingSystem,
  'platformVersion': Platform.operatingSystemVersion,
  'dartVersion': Platform.version,
  'processors': Platform.numberOfProcessors,
  'buildMode': kProfileMode
      ? 'profile'
      : kReleaseMode
      ? 'release'
      : 'debug',
};

String safeBenchmarkLabel(String label) {
  final normalized = label.trim();
  if (normalized.isEmpty ||
      !RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$').hasMatch(normalized)) {
    throw ArgumentError.value(label, 'label', 'is not a safe benchmark label');
  }
  return normalized;
}

class StableChecksum {
  static final BigInt _offsetBasis = BigInt.parse(
    'cbf29ce484222325',
    radix: 16,
  );
  static final BigInt _prime = BigInt.parse('100000001b3', radix: 16);
  static final BigInt _mask = (BigInt.one << 64) - BigInt.one;

  BigInt _value = _offsetBasis;

  void addString(String value) {
    _addByte(1);
    _addLength(value.length);
    for (final codeUnit in value.codeUnits) {
      _addByte(codeUnit & 0xff);
      _addByte((codeUnit >> 8) & 0xff);
    }
  }

  void addInt(int value) {
    _addByte(2);
    addString(value.toString());
  }

  void addBool(bool value) {
    _addByte(value ? 3 : 4);
  }

  void _addLength(int length) {
    for (var shift = 0; shift < 64; shift += 8) {
      _addByte((length >> shift) & 0xff);
    }
  }

  void _addByte(int byte) {
    _value = ((_value ^ BigInt.from(byte)) * _prime) & _mask;
  }

  String finish() =>
      'fnv1a64-utf16le:${_value.toRadixString(16).padLeft(16, '0')}';
}
