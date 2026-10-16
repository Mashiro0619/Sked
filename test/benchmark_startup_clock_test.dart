import 'package:flutter_test/flutter_test.dart';

import '../benchmark/src/startup_clock.dart';

const _wallMinusQpcUs = 1800000000000000;

StartupNativeClockSample _sample(
  int index,
  int qpcUs, {
  int spanUs = 2,
  int wallSkewUs = 0,
  int frequencyBefore = 10000000,
  int frequencyAfter = 10000000,
  int? afterTicks,
  int dartSkewUs = 20000,
}) => StartupNativeClockSample(
  index: index,
  qpcFrequencyBefore: frequencyBefore,
  qpcBeforeTicks: qpcUs * 10,
  preciseFileTimeTicks:
      startupFileTimeUnixEpochTicks +
      (_wallMinusQpcUs + qpcUs + spanUs ~/ 2 + wallSkewUs) * 10,
  qpcAfterTicks: afterTicks ?? (qpcUs + spanUs) * 10,
  qpcFrequencyAfter: frequencyAfter,
  elapsedBeforeUs: qpcUs - 1000000,
  elapsedAfterUs: qpcUs + spanUs - 1000000,
  dartUtcUsDiagnostic: _wallMinusQpcUs + qpcUs + dartSkewUs,
);

List<StartupNativeClockSample> _samples({
  int beginUs = 1101000,
  int spanUs = 2,
  int? receiptSpanUs,
  int endSkewUs = 0,
}) => [
  _sample(0, 1000000, spanUs: spanUs),
  _sample(1, beginUs, spanUs: spanUs),
  _sample(2, 1130000, spanUs: receiptSpanUs ?? spanUs),
  _sample(3, 1140000, spanUs: spanUs, wallSkewUs: endSkewUs),
];

StartupFrameClockEvidence _frame({int wallSkewUs = 0}) =>
    StartupFrameClockEvidence(
      frameNumber: 41,
      buildStartUs: 1001000,
      buildFinishUs: 1120000,
      rasterFinishUs: 1121000,
      rasterFinishWallTimeUs: _wallMinusQpcUs + 1121000 + wallSkewUs,
      receiptSampleIndex: 2,
      beginSampleIndex: 1,
      rawBeginUs: 1117667,
    );

Map<String, Object?> _check({
  List<StartupNativeClockSample>? samples,
  int engineWallSkewUs = 0,
  List<String> observationIssues = const [],
}) => validateStartupClock(
  samples: samples ?? _samples(),
  frames: [_frame(wallSkewUs: engineWallSkewUs)],
  requiredBeginFrameNumbers: {41},
  observationIssues: observationIssues,
);

String _issues(Map<String, Object?> result) =>
    (result['issues'] as List).join('\n');

Map<String, Object?> _checkEngineOffsetDrift(int driftUs) =>
    validateStartupClock(
      samples: _samples(spanUs: 0),
      frames: [
        _frame(wallSkewUs: -2500),
        StartupFrameClockEvidence(
          frameNumber: 42,
          buildStartUs: 1125000,
          buildFinishUs: 1125000,
          rasterFinishUs: 1127000,
          rasterFinishWallTimeUs: _wallMinusQpcUs + 1127000 - 2500 + driftUs,
          receiptSampleIndex: 2,
        ),
      ],
      requiredBeginFrameNumbers: {41},
    );

void main() {
  group('QPC and FILETIME conversion', () {
    test(
      'retains large absolute QPC epochs without multiplying Int64 ticks',
      () {
        expect(
          startupQpcToMicroseconds(9223372036854775806, 10000000),
          922337203685477580,
        );
        expect(
          startupQpcToMicroseconds(
            9223372036854775806,
            10000000,
            roundUp: true,
          ),
          922337203685477581,
        );
        expect(
          startupQpcToMicroseconds(9223372036854775782, 9223372036854775783),
          999999,
        );
        expect(
          startupQpcToMicroseconds(
            9223372036854775782,
            9223372036854775783,
            roundUp: true,
          ),
          1000000,
        );
      },
    );

    test('rejects unavailable frequency, invalid counter and unrepresentable output', () {
      expect(() => startupQpcToMicroseconds(1, 0), throwsArgumentError);
      expect(() => startupQpcToMicroseconds(-1, 10000000), throwsArgumentError);
      expect(
        () => startupQpcToMicroseconds(9223372036854775807, 1),
        throwsRangeError,
      );
    });

    test('converts FILETIME using the 1601 to 1970 epoch offset and bounds fractions', () {
      expect(
        startupFileTimeToUnixMicroseconds(startupFileTimeUnixEpochTicks),
        0,
      );
      expect(
        startupFileTimeToUnixMicroseconds(startupFileTimeUnixEpochTicks + 1),
        0,
      );
      expect(
        startupFileTimeToUnixMicroseconds(
          startupFileTimeUnixEpochTicks + 1,
          roundUp: true,
        ),
        1,
      );
      expect(
        startupFileTimeToUnixMicroseconds(startupFileTimeUnixEpochTicks + 10),
        1,
      );
    });
  });

  group('begin frame association', () {
    test('binds pending samples to actual draw IDs without assuming consecutive IDs', () {
      final association = StartupBeginAssociation();
      association.record(
        stamp: {'nativeSampleIndex': 1, 'utcUs': 1000},
        rawBeginUs: 100,
      );
      expect(association.frames, isEmpty);
      expect(association.bindDrawFrame(37), 37);
      association.record(
        stamp: {'nativeSampleIndex': 2, 'utcUs': 2000},
        rawBeginUs: 200,
      );
      expect(association.bindDrawFrame(54), 54);
      expect(association.frames[37]!['nativeSampleIndex'], 1);
      expect(association.frames[54]!['nativeSampleIndex'], 2);
      expect(association.frames.containsKey(38), isFalse);
      expect(association.pending, isNull);
      expect(association.issues, isEmpty);
      expect(association.bindDrawFrame(55), isNull);
      expect(association.frames.length, 2);
    });

    test(
      'keeps raw-null production warm-up separate from the previous engine ID',
      () {
        final association = StartupBeginAssociation();
        association.record(stamp: {'nativeSampleIndex': 0}, rawBeginUs: null);
        expect(association.bindDrawFrame(99), isNull);
        expect(association.frames, isEmpty);
        expect(association.warmUps.single['nativeSampleIndex'], 0);
        association.record(stamp: {'nativeSampleIndex': 1}, rawBeginUs: 100);
        expect(association.bindDrawFrame(101), 101);
        expect(association.frames.keys, [101]);
        expect(association.issues, isEmpty);
      },
    );

    test('rejects replacement before draw and duplicate draw IDs without overwriting evidence', () {
      final association = StartupBeginAssociation();
      association.record(stamp: {'nativeSampleIndex': 1}, rawBeginUs: 100);
      association.record(stamp: {'nativeSampleIndex': 2}, rawBeginUs: 200);
      association.bindDrawFrame(10);
      association.record(stamp: {'nativeSampleIndex': 3}, rawBeginUs: 300);
      expect(association.bindDrawFrame(10), isNull);
      expect(association.frames[10]!['nativeSampleIndex'], 2);
      expect(association.issues.length, 2);
    });
  });

  group('independent native calibration', () {
    test('allows 100 ms dispatch inside build and treats coarse Dart UTC as diagnostic', () {
      final result = _check();
      expect(result['protocolId'], 'win32-qpc-precise-filetime-v2');
      expect(result['utcCorrelationValid'], isTrue, reason: _issues(result));
      final begin = (result['beginDiagnostics'] as List).single as Map;
      expect(begin['dispatchDelayLowerUs'], 100000);
      expect(begin['withinBuildInterval'], isTrue);
      expect(begin['beginUtcResidualDiagnosticUs'], greaterThan(5000));
      final native = (result['nativeSampleChecks'] as List).first as Map;
      expect(native['dartUtcMinusPreciseUtcDiagnosticUs'], greaterThan(5000));
    });

    test('rejects a stale frame ID that puts begin beyond build finish', () {
      final result = _check(samples: _samples(beginUs: 1126000));
      expect(result['utcCorrelationValid'], isFalse);
      expect(_issues(result), contains('outside its build interval'));
    });

    test('preserves the exact 5000 us engine offset gate', () {
      expect(
        _check(
          samples: _samples(spanUs: 0),
          engineWallSkewUs: 5000,
        )['utcCorrelationValid'],
        isTrue,
      );
      final rejected = _check(
        samples: _samples(spanUs: 0),
        engineWallSkewUs: 5001,
      );
      expect(rejected['utcCorrelationValid'], isFalse);
      expect(_issues(rejected), contains('differs from native calibration'));
    });

    test('accepts exactly 5000 us of drift from the first engine frame', () {
      final result = _checkEngineOffsetDrift(5000);
      expect(result['utcCorrelationValid'], isTrue, reason: _issues(result));
      final checks = (result['frameOffsetChecks'] as List).cast<Map>();
      expect(checks.first['engineOffsetAnchorFrameNumber'], 41);
      expect(checks.first['engineOffsetDriftFromFirstUs'], 0);
      expect(checks.last['engineOffsetDriftFromFirstUs'], 5000);
    });

    test(
      'rejects 5001 us engine drift even when both native residuals pass',
      () {
        for (final drift in [5001, 5500]) {
          final result = _checkEngineOffsetDrift(drift);
          expect(result['utcCorrelationValid'], isFalse);
          expect(
            _issues(result),
            contains('offset drift from the first frame'),
          );
          final checks = (result['frameOffsetChecks'] as List).cast<Map>();
          expect(checks.last['engineOffsetDriftFromFirstUs'], drift);
          for (final check in checks) {
            expect(
              check['nativeOffsetResidualConservativeBoundUs'],
              lessThanOrEqualTo(5000),
            );
          }
        }
      },
    );

    test('rejects real native wall/QPC offset drift above 5000 us', () {
      final result = _check(samples: _samples(endSkewUs: 5001));
      expect(result['utcCorrelationValid'], isFalse);
      expect(_issues(result), contains('FILETIME/QPC offset drift'));
    });

    test(
      'rejects wide brackets and does not let uncertainty enlarge tolerance',
      () {
        final wide = _check(samples: _samples(receiptSpanUs: 5001));
        expect(wide['utcCorrelationValid'], isFalse);
        expect(_issues(wide), contains('bracket exceeds 5000 us'));
        final biased = _check(
          samples: _samples(receiptSpanUs: 5000),
          engineWallSkewUs: 3000,
        );
        expect(biased['utcCorrelationValid'], isFalse);
        expect(_issues(biased), contains('differs from native calibration'));
      },
    );

    test(
      'rejects frequency changes, missing frequency and counter reversal',
      () {
        for (final bad in [
          _sample(0, 1000000, frequencyBefore: 0),
          _sample(0, 1000000, frequencyAfter: 20000000),
          _sample(0, 1000000, afterTicks: 9999999),
        ]) {
          final result = _check(samples: [bad, ..._samples().skip(1)]);
          expect(
            result['utcCorrelationValid'],
            isFalse,
            reason: bad.toJson().toString(),
          );
        }
      },
    );

    test('native query failure cannot produce an accepted clock report', () {
      final result = _check(
        observationIssues: ['QueryPerformanceCounter failed'],
      );
      expect(result['utcCorrelationValid'], isFalse);
      expect(_issues(result), contains('QueryPerformanceCounter failed'));
    });

    test('accepts raster-only frames without fabricating begin, but never as ready', () {
      const rasterOnly = StartupFrameClockEvidence(
        frameNumber: 3,
        buildStartUs: 1000900,
        buildFinishUs: 1000900,
        rasterFinishUs: 1000950,
        rasterFinishWallTimeUs: _wallMinusQpcUs + 1000950,
        receiptSampleIndex: 2,
      );
      final result = validateStartupClock(
        samples: _samples(),
        frames: [rasterOnly, _frame()],
        requiredBeginFrameNumbers: {41},
      );
      expect(result['utcCorrelationValid'], isTrue, reason: _issues(result));
      expect(
        ((result['beginDiagnostics'] as List).first as Map)['kind'],
        'no-dart-begin-observed',
      );
      final invalidReady = validateStartupClock(
        samples: _samples(),
        frames: [rasterOnly, _frame()],
        requiredBeginFrameNumbers: {3, 41},
      );
      expect(invalidReady['utcCorrelationValid'], isFalse);
      expect(_issues(invalidReady), contains('Ready/response frame 3'));
    });
  });
}
