import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart' as ui;

import '../benchmark/src/ui_performance_fixtures.dart';
import '../benchmark/src/ui_performance_metrics.dart';
import '../benchmark/src/ui_performance_scenarios.dart';
import 'support/data_transfer_codec.dart';

void main() {
  for (final canvasOverflows in [true, false]) {
    testWidgets(
      canvasOverflows
          ? 'canvas scrolling ignores longer reminders, resources and all-day lists'
          : 'a fitting primary canvas never scrolls another pane',
      (tester) async {
        final primary = ui.ScrollController();
        final resources = ui.ScrollController();
        final reminders = ui.ScrollController();
        final allDay = ui.ScrollController();
        final otherControllers = [resources, reminders, allDay];
        var anotherSurfaceMoved = false;
        for (final controller in otherControllers) {
          controller.addListener(() {
            if (controller.offset != 0) anotherSurfaceMoved = true;
          });
        }
        addTearDown(() {
          for (final controller in [primary, ...otherControllers]) {
            controller.dispose();
          }
        });
        await tester.pumpWidget(
          ui.MaterialApp(
            home: ui.Scaffold(
              body: ui.Row(
                key: const ValueKey('general-home'),
                children: [
                  ui.SizedBox(
                    key: const ValueKey('workspace-resources'),
                    width: 100,
                    child: ui.SingleChildScrollView(
                      controller: resources,
                      child: const ui.SizedBox(height: 9000),
                    ),
                  ),
                  ui.Expanded(
                    child: ui.Column(
                      key: const ValueKey('workspace-canvas'),
                      crossAxisAlignment: ui.CrossAxisAlignment.stretch,
                      children: [
                        ui.SizedBox(
                          height: 60,
                          child: ui.SingleChildScrollView(
                            key: const ValueKey(
                              'general-all-day-expanded-scroll',
                            ),
                            controller: allDay,
                            child: const ui.SizedBox(height: 4000),
                          ),
                        ),
                        ui.Expanded(
                          child: ui.SingleChildScrollView(
                            key: const ValueKey('general-timeline-scroll-view'),
                            controller: primary,
                            child: ui.SizedBox(
                              height: canvasOverflows ? 1600 : 100,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ui.SizedBox(
                    key: const ValueKey('general-reminders-list'),
                    width: 180,
                    child: ui.SingleChildScrollView(
                      key: const ValueKey('workspace-view-body'),
                      controller: reminders,
                      child: const ui.SizedBox(height: 12000),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final primaryExtent = primary.position.maxScrollExtent;
        final details = <String, Object?>{};
        await scrollUiPerformanceCanvas(tester, 'general-home', details);
        expect(details['scrollScope'], 'workspace-canvas');
        expect(details['scrollTarget'], 'general-timeline-scroll-view');
        expect(details['maxScrollExtent'], primaryExtent);
        expect(details['finalMaxScrollExtent'], primaryExtent);
        expect(anotherSurfaceMoved, isFalse);
        if (canvasOverflows) {
          expect(details['scrollStatus'], 'scrolled');
          expect(details['furthestOffset'], greaterThan(0));
        } else {
          expect(primaryExtent, 0);
          expect(details['scrollStatus'], 'content-fits-viewport');
          expect(details.containsKey('furthestOffset'), isFalse);
        }
        await tester.pumpWidget(const ui.SizedBox.shrink());
      },
    );
  }

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
          (report['protocol']! as Map)['scrollTargeting'],
          uiPerformanceScrollTargetingProtocol,
        );
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
