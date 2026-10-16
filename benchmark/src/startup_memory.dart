import 'dart:io';

import 'startup_native_clock.dart';

const startupMemoryProtocolId = 'process-rss-v1';
const _memoryPoints = [
  'entry',
  'readyRasterReportObserved',
  'responseRasterReportObserved',
  'measurementEnd',
];

/// Four whole-process RSS observations, never a per-frame sampler or Dart heap probe.
class StartupMemoryRecorder {
  StartupMemoryRecorder(this.clock);
  final StartupClock clock;
  final samples = <Map<String, Object?>>[];

  void capture(
    String point, {
    int? frameNumber,
    int? rasterFinishWallTimeUs,
    Map<String, int>? reportStamp,
  }) {
    final observerStart = clock.stopwatch.elapsedMicroseconds;
    final start = clock.stamp();
    final readStart = clock.stopwatch.elapsedMicroseconds;
    int? currentRss, maxRss;
    String? failure;
    try {
      currentRss = ProcessInfo.currentRss;
      maxRss = ProcessInfo.maxRss;
    } catch (error) {
      failure = error.toString();
    }
    final readCost = clock.stopwatch.elapsedMicroseconds - readStart;
    final end = clock.stamp();
    final sample = <String, Object?>{
      'point': point,
      'currentRssBytes': currentRss,
      'maxRssBytes': maxRss,
      'observationStart': start,
      'observationEnd': end,
      'readCostUs': readCost,
      'frameNumber': ?frameNumber,
      'rasterFinishWallTimeUs': ?rasterFinishWallTimeUs,
      'reportStamp': ?reportStamp,
      'readFailure': ?failure,
    };
    samples.add(sample);
    sample['observerCostUs'] =
        clock.stopwatch.elapsedMicroseconds - observerStart;
  }

  Map<String, Object?> report({
    required Map<String, Object>? readyRaster,
    required Map<String, Object>? responseRaster,
    required Map<String, int> measurementEnd,
  }) {
    final issues = <String>[];
    int? stampIndex(Object? value) {
      if (value is Map) {
        final index = value['nativeSampleIndex'];
        if (index is int &&
            index >= 0 &&
            index < clock.samples.length &&
            value['utcSourceIsPrecise'] == 1 &&
            value['utcUs'] is int) {
          try {
            final native = clock.samples[index];
            if (native.index == index &&
                native.utcUs == value['utcUs'] &&
                native.elapsedBeforeUs == value['elapsedBeforeUs'] &&
                native.elapsedAfterUs == value['elapsedAfterUs']) {
              return index;
            }
          } catch (_) {
            // Clock failure remains reportable and must invalidate memory too.
          }
        }
      }
      issues.add(
        'Memory observation has no matching precise native clock stamp.',
      );
      return null;
    }

    if (samples.length != _memoryPoints.length) {
      issues.add('Memory protocol requires exactly four observations.');
    }
    var previousEnd = -1;
    var previousPeak = 0;
    for (var index = 0; index < samples.length; index++) {
      final sample = samples[index];
      if (index >= _memoryPoints.length ||
          sample['point'] != _memoryPoints[index]) {
        issues.add('Memory observation order/identity is invalid at $index.');
      }
      final current = sample['currentRssBytes'];
      final peak = sample['maxRssBytes'];
      if (current is! int ||
          current <= 0 ||
          peak is! int ||
          peak < current ||
          peak < previousPeak ||
          sample['readFailure'] != null) {
        issues.add(
          'Memory RSS/peak is unavailable, nonpositive, or inconsistent at $index.',
        );
      }
      if (peak is int) {
        previousPeak = peak;
      }
      final readCost = sample['readCostUs'];
      final observerCost = sample['observerCostUs'];
      if (readCost is! int ||
          readCost < 0 ||
          observerCost is! int ||
          observerCost < readCost) {
        issues.add('Memory observation cost is invalid at $index.');
      }
      final start = stampIndex(sample['observationStart']);
      final end = stampIndex(sample['observationEnd']);
      if (start != null && end != null) {
        if (start <= previousEnd || end <= start) {
          issues.add('Memory observation time order is invalid at $index.');
        }
        previousEnd = end;
      }
      if (index == 1 || index == 2) {
        final raster = index == 1 ? readyRaster : responseRaster;
        final report = stampIndex(sample['reportStamp']);
        final expectedReport = raster?['callbackReceipt'];
        if (raster == null ||
            sample['frameNumber'] != raster['frameNumber'] ||
            sample['rasterFinishWallTimeUs'] !=
                raster['rasterFinishWallTimeUs'] ||
            expectedReport is! Map ||
            report != expectedReport['nativeSampleIndex'] ||
            start == null ||
            report == null ||
            start < report) {
          issues.add(
            'Memory observation is not tied to its ready/response report at $index.',
          );
        }
      }
    }
    final entryIndex = stampIndex(clock.entry);
    final endIndex = stampIndex(measurementEnd);
    if (samples.isNotEmpty && entryIndex != null) {
      final firstIndex = stampIndex(samples.first['observationStart']);
      if (firstIndex == null || firstIndex <= entryIndex) {
        issues.add(
          'Initial RSS must follow clock creation and precede app preparation.',
        );
      }
    }
    if (endIndex == null || previousEnd > endIndex) {
      issues.add(
        'Final RSS must precede measurement validation and report encoding.',
      );
    }

    Map<String, int>? metrics;
    if (issues.isEmpty) {
      final entry = samples[0]['currentRssBytes']! as int;
      final ready = samples[1]['currentRssBytes']! as int;
      final response = samples[2]['currentRssBytes']! as int;
      final end = samples[3]['currentRssBytes']! as int;
      final peak = samples[3]['maxRssBytes']! as int;
      metrics = {
        'entryRssBytes': entry,
        'readyRssBytes': ready,
        'responseRssBytes': response,
        'endRssBytes': end,
        'entryToReadyRssDeltaBytes': ready - entry,
        'entryToEndRssDeltaBytes': end - entry,
        'peakRssBytes': peak,
        'peakRssGrowthFromEntryBytes':
            peak - (samples[0]['maxRssBytes']! as int),
      };
    }
    return {
      'protocolId': startupMemoryProtocolId,
      'validated': issues.isEmpty,
      'source': 'dart:io ProcessInfo',
      'unit': 'bytes',
      'samples': samples,
      'metrics': metrics,
      'issues': issues,
      'scope': 'Whole-process RSS. Ready/response are observed after their raster reports; maxRss is the process lifetime peak through measurementEnd, before full validation/encoding.',
    };
  }
}
