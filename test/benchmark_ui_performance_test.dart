import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';

import '../benchmark/src/ui_performance_fixtures.dart';
import '../benchmark/src/ui_performance_metrics.dart';
import '../benchmark/src/ui_performance_scenarios.dart';

void main() {
  test(
    'frame percentiles preserve long tails and empty samples stay unavailable',
    () {
      expect(uiDurationDistribution([1, 2, 3, 4, 100]), {
        'p50Us': 3,
        'p95Us': 100,
        'p99Us': 100,
        'maxUs': 100,
      });
      final empty = summarizeUiFrames([], frameBudgetUs: 10000);
      expect((empty['build']! as Map)['p50Us'], isNull);
      expect((empty['overBudget']! as Map)['eitherStageRatio'], isNull);
      final summary = summarizeUiFrames([
        const UiPerformanceFrame(
          vsyncStart: 0,
          build: 8000,
          raster: 12000,
          total: 15000,
          vsyncOverhead: 0,
        ),
        const UiPerformanceFrame(
          vsyncStart: 10000,
          build: 13000,
          raster: 7000,
          total: 16000,
          vsyncOverhead: 0,
        ),
      ], frameBudgetUs: 10000);
      expect(summary['overBudget'], {
        'buildFrames': 1,
        'rasterFrames': 1,
        'eitherStageFrames': 2,
        'eitherStageRatio': 1.0,
      });
    },
  );

  test('UI datasets retain declared event and course scales', () {
    final fixtures = buildUiPerformanceFixtures();
    expect(fixtures.map((f) => f.manifest['events']), [24, 1000, 5000]);
    expect(fixtures.map((f) => f.manifest['courses']), [60, 1000, 5000]);
    expect(
      () => buildUiPerformanceFixtures(names: ['unknown']),
      throwsArgumentError,
    );
  });

  testWidgets(
    'sparse UI journey reaches production views and persists only in memory',
    (tester) async {
      tester.view.physicalSize =
          (defaultTargetPlatform == TargetPlatform.windows
              ? const Size(1280, 720)
              : const Size(393, 852)) *
          tester.view.devicePixelRatio;
      addTearDown(tester.view.resetPhysicalSize);
      final report = await runUiPerformanceBenchmarks(
        tester,
        config: const UiPerformanceConfig(
          datasets: ['sparse'],
          warmRuns: 0,
          requireFrameTimings: false,
        ),
      );
      expect(report['measurement'], 'widget-smoke-only');
      final results = report['results']! as List;
      expect(results, hasLength(11));
      expect(
        results.every((result) => (result as Map)['elapsedUs'] is int),
        isTrue,
      );
    },
    variant: TargetPlatformVariant({
      TargetPlatform.windows,
      TargetPlatform.android,
    }),
  );
}
