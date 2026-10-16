import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';

import '../benchmark/src/ui_performance_fixtures.dart';
import '../benchmark/src/ui_performance_metrics.dart';
import '../benchmark/src/ui_performance_scenarios.dart';
import 'support/data_transfer_codec.dart';

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

  for (final scope in UiPerformanceScope.values) {
    testWidgets(
      'sparse ${scope.name} journey reaches production views with isolated data',
      (tester) async {
        tester.view.physicalSize =
            (defaultTargetPlatform == TargetPlatform.windows
                ? const Size(1280, 720)
                : const Size(393, 852)) *
            tester.view.devicePixelRatio;
        addTearDown(tester.view.resetPhysicalSize);
        final report = await runUiPerformanceBenchmarks(
          tester,
          smokeTestCodec: inlineDataTransferCodec,
          config: UiPerformanceConfig(
            datasets: const ['sparse'],
            warmRuns: 0,
            scope: scope,
            requireFrameTimings: false,
          ),
        );
        expect(
          report['measurement'],
          scope == UiPerformanceScope.full
              ? 'widget-smoke-only'
              : 'workspace-widget-smoke-only',
        );
        final results = report['results']! as List;
        expect(results.map((row) => (row as Map)['scenario']), [
          'general.month.swipe',
          'general.month.vertical_scroll',
          'general.day.open_scroll',
          'general.week.open_scroll',
          'general.list.open_scroll',
          'workspace.student.open',
          'student.timetable.switch',
          'student.week.scroll',
          'student.day.open_scroll',
          'workspace.general.open',
          if (scope == UiPerformanceScope.full) 'settings.general.toggle',
        ]);
        if (scope == UiPerformanceScope.workspace) {
          expect(
            (report['protocol']! as Map)['scope'],
            uiWorkspacePerformanceProtocol,
          );
        }
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
}
