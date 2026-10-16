// Pure clock math and validation. No Flutter binding or native calls occur here.
const startupClockProtocolId = 'win32-qpc-precise-filetime-v2';
const startupClockToleranceUs = 5000;
const startupNativeClockMaximumBracketUs = 5000;
const startupFileTimeUnixEpochTicks = 116444736000000000;
const _maximumSignedInt64 = 9223372036854775807;
final _microsecondsPerSecond = BigInt.from(1000000);
final _maximumSignedInt64Big = BigInt.from(_maximumSignedInt64);

/// Preserve the QPC epoch and truncate only after an exact integer conversion.
/// Neither ticks * 1000000 nor a large remainder multiplication uses Int64.
int startupQpcToMicroseconds(int ticks, int frequency, {bool roundUp = false}) {
  if (ticks < 0 || frequency <= 0) {
    throw ArgumentError(
      'QPC ticks must be nonnegative and frequency positive.',
    );
  }
  final seconds = ticks ~/ frequency;
  final remainder = ticks % frequency;
  final scaledRemainder = BigInt.from(remainder) * _microsecondsPerSecond;
  final divisor = BigInt.from(frequency);
  var result =
      BigInt.from(seconds) * _microsecondsPerSecond +
      scaledRemainder ~/ divisor;
  if (roundUp && scaledRemainder % divisor != BigInt.zero) {
    result += BigInt.one;
  }
  if (result > _maximumSignedInt64Big) {
    throw RangeError('QPC microseconds exceed the report Int64 range.');
  }
  return result.toInt();
}

int startupFileTimeToUnixMicroseconds(int ticks, {bool roundUp = false}) {
  if (ticks < startupFileTimeUnixEpochTicks) {
    throw ArgumentError(
      'A startup FILETIME must be at or after the Unix epoch.',
    );
  }
  final sinceEpoch = ticks - startupFileTimeUnixEpochTicks;
  return sinceEpoch ~/ 10 + (roundUp && sinceEpoch % 10 != 0 ? 1 : 0);
}

int _differenceMagnitude(int left, int right) {
  final magnitude = (BigInt.from(left) - BigInt.from(right)).abs();
  return magnitude > _maximumSignedInt64Big
      ? _maximumSignedInt64
      : magnitude.toInt();
}

int _maximum(int left, int right) => left > right ? left : right;

class StartupNativeClockSample {
  const StartupNativeClockSample({
    required this.index,
    required this.qpcFrequencyBefore,
    required this.qpcBeforeTicks,
    required this.preciseFileTimeTicks,
    required this.qpcAfterTicks,
    required this.qpcFrequencyAfter,
    required this.elapsedBeforeUs,
    required this.elapsedAfterUs,
    required this.dartUtcUsDiagnostic,
  });

  final int index;
  final int qpcFrequencyBefore;
  final int qpcBeforeTicks;
  final int preciseFileTimeTicks;
  final int qpcAfterTicks;
  final int qpcFrequencyAfter;
  final int elapsedBeforeUs;
  final int elapsedAfterUs;
  final int dartUtcUsDiagnostic;

  int get utcUs => startupFileTimeToUnixMicroseconds(preciseFileTimeTicks);
  int get utcUpperUs =>
      startupFileTimeToUnixMicroseconds(preciseFileTimeTicks, roundUp: true);
  int get qpcLowerUs =>
      startupQpcToMicroseconds(qpcBeforeTicks, qpcFrequencyBefore);
  int get qpcUpperUs => startupQpcToMicroseconds(
    qpcAfterTicks,
    qpcFrequencyBefore,
    roundUp: true,
  );
  int get bracketUs => qpcUpperUs - qpcLowerUs;
  int get offsetLowerUs => utcUs - qpcUpperUs;
  int get offsetUpperUs => utcUpperUs - qpcLowerUs;

  Map<String, int> toJson() => {
    'index': index,
    'qpcFrequencyBefore': qpcFrequencyBefore,
    'qpcBeforeTicks': qpcBeforeTicks,
    'preciseFileTimeTicks': preciseFileTimeTicks,
    'qpcAfterTicks': qpcAfterTicks,
    'qpcFrequencyAfter': qpcFrequencyAfter,
    'elapsedBeforeUs': elapsedBeforeUs,
    'elapsedAfterUs': elapsedAfterUs,
    'dartUtcUsDiagnostic': dartUtcUsDiagnostic,
  };
}

/// The SDK updates frameData only after synchronous onBeginFrame returns.
/// Bind the pending observation at draw entry; never increment or reuse an ID.
class StartupBeginAssociation {
  Map<String, Object?>? _pending;
  final frames = <int, Map<String, Object?>>{};
  final warmUps = <Map<String, Object?>>[];
  final issues = <String>[];

  Map<String, Object?>? get pending => _pending;

  void record({required Map<String, int> stamp, required int? rawBeginUs}) {
    if (_pending != null) {
      issues.add('A begin observation was replaced before its draw callback.');
    }
    _pending = {'rawBeginUs': rawBeginUs, ...stamp};
  }

  int? bindDrawFrame(int frameNumber) {
    final begin = _pending;
    _pending = null;
    if (begin == null) {
      issues.add('A Dart draw callback had no pending begin observation.');
      return null;
    }
    if (begin['rawBeginUs'] == null) {
      warmUps.add({
        ...begin,
        'kind': 'production-warm-up-without-engine-frame-id',
      });
      return null;
    }
    if (frameNumber < 0 || frames.containsKey(frameNumber)) {
      issues.add(
        'A native begin has an invalid or duplicate draw-frame ID: $frameNumber.',
      );
      return null;
    }
    frames[frameNumber] = {'frameNumber': frameNumber, ...begin};
    return frameNumber;
  }
}

class StartupFrameClockEvidence {
  const StartupFrameClockEvidence({
    required this.frameNumber,
    required this.buildStartUs,
    required this.buildFinishUs,
    required this.rasterFinishUs,
    required this.rasterFinishWallTimeUs,
    required this.receiptSampleIndex,
    this.beginSampleIndex,
    this.rawBeginUs,
  });

  final int frameNumber;
  final int buildStartUs;
  final int buildFinishUs;
  final int rasterFinishUs;
  final int rasterFinishWallTimeUs;
  final int receiptSampleIndex;
  final int? beginSampleIndex;
  final int? rawBeginUs;
}

Map<String, Object?> validateStartupClock({
  required List<StartupNativeClockSample> samples,
  required List<StartupFrameClockEvidence> frames,
  required Set<int> requiredBeginFrameNumbers,
  List<String> observationIssues = const [],
}) {
  final issues = <String>[...observationIssues];
  final byIndex = <int, StartupNativeClockSample>{};
  final sampleChecks = <Map<String, Object?>>[];
  final frameChecks = <Map<String, Object?>>[];
  final beginDiagnostics = <Map<String, Object?>>[];
  StartupNativeClockSample? anchor;
  StartupNativeClockSample? previous;

  for (final sample in samples) {
    final sampleIssues = <String>[];
    try {
      if (sample.qpcFrequencyBefore <= 0 ||
          sample.qpcFrequencyBefore != sample.qpcFrequencyAfter) {
        sampleIssues.add(
          'QPC frequency is unavailable or changed during the sample.',
        );
      }
      if (sample.qpcBeforeTicks < 0 ||
          sample.qpcAfterTicks < sample.qpcBeforeTicks) {
        sampleIssues.add('QPC counter order is invalid.');
      }
      if (sample.elapsedAfterUs < sample.elapsedBeforeUs) {
        sampleIssues.add('Stopwatch observation order is invalid.');
      }
      if (byIndex.containsKey(sample.index) || sample.index < 0) {
        sampleIssues.add('Native sample index is invalid or duplicated.');
      }
      if (sampleIssues.isEmpty) {
        if (sample.bracketUs > startupNativeClockMaximumBracketUs) {
          sampleIssues.add('Native QPC/FILETIME bracket exceeds 5000 us.');
        }
        if (anchor != null &&
            sample.qpcFrequencyBefore != anchor.qpcFrequencyBefore) {
          sampleIssues.add('QPC frequency changed across the measurement.');
        }
        if (previous != null &&
            sample.qpcBeforeTicks < previous.qpcAfterTicks) {
          sampleIssues.add('Native QPC samples are not ordered.');
        }
        final offsetDriftBound = anchor == null
            ? 0
            : _maximum(
                _differenceMagnitude(
                  sample.offsetLowerUs,
                  anchor.offsetUpperUs,
                ),
                _differenceMagnitude(
                  sample.offsetUpperUs,
                  anchor.offsetLowerUs,
                ),
              );
        if (offsetDriftBound > startupClockToleranceUs) {
          sampleIssues.add(
            'Precise FILETIME/QPC offset drift exceeds 5000 us.',
          );
        }
        sampleChecks.add({
          'sampleIndex': sample.index,
          'qpcLowerUs': sample.qpcLowerUs,
          'qpcUpperUs': sample.qpcUpperUs,
          'preciseUtcUs': sample.utcUs,
          'preciseUtcUpperUs': sample.utcUpperUs,
          'bracketUs': sample.bracketUs,
          'offsetLowerUs': sample.offsetLowerUs,
          'offsetUpperUs': sample.offsetUpperUs,
          'offsetDriftConservativeBoundUs': offsetDriftBound,
          'stopwatchObservationSpanUs':
              sample.elapsedAfterUs - sample.elapsedBeforeUs,
          'dartUtcMinusPreciseUtcDiagnosticUs':
              sample.dartUtcUsDiagnostic - sample.utcUs,
          'issues': sampleIssues,
        });
        if (sampleIssues.isEmpty) {
          anchor ??= sample;
          previous = sample;
          byIndex[sample.index] = sample;
        }
      }
    } catch (error) {
      sampleIssues.add('Native clock conversion failed: $error');
    }
    issues.addAll(
      sampleIssues.map((issue) => 'Native sample ${sample.index}: $issue'),
    );
  }
  if (byIndex.length < 2) {
    issues.add(
      'At least two valid independent native clock samples are required.',
    );
  }
  if (frames.isEmpty) {
    issues.add(
      'No engine raster timing was available for native clock calibration.',
    );
  }

  final seenFrameNumbers = <int>{};
  final observedBeginFrames = <int>{};
  final orderedFrames = frames.toList()
    ..sort((left, right) => left.frameNumber.compareTo(right.frameNumber));
  int? firstEngineOffset;
  int? firstEngineFrameNumber;
  for (final frame in orderedFrames) {
    final frameIssues = <String>[];
    if (frame.frameNumber < 0 || !seenFrameNumbers.add(frame.frameNumber)) {
      frameIssues.add('Engine frame identity is invalid or duplicated.');
    }
    if (frame.buildStartUs < 0 ||
        frame.buildFinishUs < frame.buildStartUs ||
        frame.rasterFinishUs < frame.buildFinishUs) {
      frameIssues.add('Engine build/raster phases are not ordered.');
    }
    final receipt = byIndex[frame.receiptSampleIndex];
    final engineOffset = frame.rasterFinishWallTimeUs - frame.rasterFinishUs;
    firstEngineOffset ??= engineOffset;
    firstEngineFrameNumber ??= frame.frameNumber;
    final engineOffsetDrift = _differenceMagnitude(
      engineOffset,
      firstEngineOffset,
    );
    if (engineOffsetDrift > startupClockToleranceUs) {
      frameIssues.add(
        'Engine wall/monotonic offset drift from the first frame exceeds 5000 us.',
      );
    }
    int? residualBound;
    if (receipt == null) {
      frameIssues.add(
        'The raster report has no valid native receipt calibration.',
      );
    } else {
      // Require both ends of the independent uncertainty interval to fit the
      // original tolerance. A wide interval never silently increases tolerance.
      residualBound = _maximum(
        _differenceMagnitude(engineOffset, receipt.offsetLowerUs),
        _differenceMagnitude(engineOffset, receipt.offsetUpperUs),
      );
      if (residualBound > startupClockToleranceUs) {
        frameIssues.add(
          'Engine wall/monotonic offset differs from native calibration by over 5000 us.',
        );
      }
      if (frame.rasterFinishUs > receipt.qpcUpperUs + startupClockToleranceUs ||
          frame.rasterFinishWallTimeUs >
              receipt.utcUpperUs + startupClockToleranceUs ||
          (anchor != null &&
              (frame.rasterFinishUs <
                      anchor.qpcLowerUs - startupClockToleranceUs ||
                  frame.rasterFinishWallTimeUs <
                      anchor.utcUs - startupClockToleranceUs))) {
        frameIssues.add(
          'Raster timing lies outside native entry/report bounds.',
        );
      }
    }
    if (frame.beginSampleIndex == null) {
      beginDiagnostics.add({
        'frameNumber': frame.frameNumber,
        'kind': 'no-dart-begin-observed',
        'note': 'Raster-only DrawLastLayerTrees frames can have no Dart begin.',
      });
    } else {
      observedBeginFrames.add(frame.frameNumber);
      final begin = byIndex[frame.beginSampleIndex];
      if (begin == null) {
        frameIssues.add(
          'The associated Dart begin has no valid native calibration.',
        );
      } else {
        // The one-microsecond allowance covers integer phase quantization,
        // not dispatch delay. The entire native begin bracket must fit build.
        final withinBuild =
            begin.qpcLowerUs >= frame.buildStartUs - 1 &&
            begin.qpcUpperUs <= frame.buildFinishUs + 1;
        if (!withinBuild) {
          frameIssues.add(
            'The associated Dart begin QPC bracket is outside its build interval.',
          );
        }
        beginDiagnostics.add({
          'frameNumber': frame.frameNumber,
          'kind': 'draw-associated-dart-begin',
          'nativeSampleIndex': begin.index,
          'qpcLowerUs': begin.qpcLowerUs,
          'qpcUpperUs': begin.qpcUpperUs,
          'buildStartUs': frame.buildStartUs,
          'buildFinishUs': frame.buildFinishUs,
          'withinBuildInterval': withinBuild,
          'dispatchDelayLowerUs': begin.qpcLowerUs - frame.buildStartUs,
          'dispatchDelayUpperUs': begin.qpcUpperUs - frame.buildStartUs,
          'beginUtcResidualDiagnosticUs':
              begin.utcUs - (frame.buildStartUs + engineOffset),
          'rawBeginVsBuildStartDiagnosticUs': frame.rawBeginUs == null
              ? null
              : frame.rawBeginUs! - frame.buildStartUs,
        });
      }
    }
    frameChecks.add({
      'frameNumber': frame.frameNumber,
      'receiptSampleIndex': frame.receiptSampleIndex,
      'engineWallMinusMonotonicUs': engineOffset,
      'engineOffsetAnchorFrameNumber': firstEngineFrameNumber,
      'engineOffsetDriftFromFirstUs': engineOffsetDrift,
      'nativeOffsetResidualConservativeBoundUs': residualBound,
      'issues': frameIssues,
    });
    issues.addAll(
      frameIssues.map((issue) => 'Frame ${frame.frameNumber}: $issue'),
    );
  }
  for (final number in requiredBeginFrameNumbers) {
    if (!observedBeginFrames.contains(number)) {
      issues.add(
        'Ready/response frame $number has no draw-associated Dart begin.',
      );
    }
  }

  int? stopwatchDriftDiagnostic;
  if (samples.length >= 2) {
    try {
      final first = samples.first;
      final last = samples.last;
      stopwatchDriftDiagnostic =
          (last.utcUs - first.utcUs) -
          (last.elapsedAfterUs - first.elapsedAfterUs);
    } catch (_) {
      // Invalid raw samples are already retained and rejected above.
    }
  }
  return {
    'protocolId': startupClockProtocolId,
    'utcCorrelationValid': issues.isEmpty,
    'utcSource': 'GetSystemTimePreciseAsFileTime',
    'monotonicSource': 'QueryPerformanceCounter / QueryPerformanceFrequency',
    'toleranceUs': startupClockToleranceUs,
    'maximumNativeBracketUs': startupNativeClockMaximumBracketUs,
    'fileTimeUnixEpochTicks': startupFileTimeUnixEpochTicks,
    'preciseUtcStopwatchDriftDiagnosticUs': stopwatchDriftDiagnostic,
    'legacyDartDateTimeAndBeginResidualAreDiagnosticOnly': true,
    'nativeSamples': samples.map((sample) => sample.toJson()).toList(),
    'nativeSampleChecks': sampleChecks,
    'frameOffsetChecks': frameChecks,
    'beginDiagnostics': beginDiagnostics,
    'issues': issues,
  };
}
