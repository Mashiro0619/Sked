import 'dart:convert';
import 'dart:ui' show Size;

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:material_ui/material_ui.dart' as ui;

import '../benchmark/src/ui_performance_fixtures.dart';
import '../benchmark/src/ui_performance_metrics.dart';
import '../benchmark/src/ui_performance_host_setup.dart';
import '../benchmark/src/ui_performance_scenarios.dart';
import 'support/data_transfer_codec.dart';

void main() {
  testWidgets(
    'list checkpoints observe only visible text without changing UI',
    (tester) async {
      final controller = ui.ScrollController();
      addTearDown(controller.dispose);
      var builds = 0;
      await tester.pumpWidget(
        ui.MaterialApp(
          home: ui.Scaffold(
            body: ui.Row(
              children: [
                const ui.Text('outside the measured list'),
                ui.SizedBox(
                  width: 300,
                  height: 120,
                  child: ui.ListView.builder(
                    key: const ValueKey('checkpoint-list'),
                    controller: controller,
                    padding: ui.EdgeInsets.zero,
                    scrollCacheExtent: const ScrollCacheExtent.pixels(400),
                    itemExtent: 40,
                    itemCount: 100,
                    itemBuilder: (_, index) {
                      builds++;
                      return ui.Align(
                        alignment: ui.Alignment.centerLeft,
                        child: ui.Text('row $index'),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final scrollable = find.descendant(
        of: find.byKey(const ValueKey('checkpoint-list')),
        matching: find.byType(ui.Scrollable),
      );
      expect(
        find.text('row 8', skipOffstage: false),
        findsOneWidget,
        reason:
            'The render cache must contain text outside the visible viewport.',
      );
      final initialBuilds = builds;
      final opened = captureUiPerformanceListCheckpoint(
        tester,
        scrollable,
        'opened',
      );
      final initial = opened['paragraphs']! as List<Map<String, Object?>>;
      expect(initial.map((item) => item['text']), ['row 0', 'row 1', 'row 2']);
      expect(controller.offset, 0);
      expect(builds, initialBuilds);
      expect(opened['viewport'], {'width': 300.0, 'height': 120.0});

      controller.jumpTo(80);
      await tester.pumpAndSettle();
      final moved = captureUiPerformanceListCheckpoint(
        tester,
        scrollable,
        'forward',
      );
      final forward = moved['paragraphs']! as List<Map<String, Object?>>;
      expect(forward.map((item) => item['text']), ['row 2', 'row 3', 'row 4']);
      expect(moved['offset'], 80);
      expect(
        (initial.last['rect']! as Map)['top'],
        ((forward.first['rect']! as Map)['top']! as double) + 80,
      );
      expect(
        moved['observationUs'],
        (moved['observationEndUs']! as int) -
            (moved['observationStartUs']! as int),
      );
      await tester.pumpWidget(const ui.SizedBox.shrink());
    },
  );

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

  for (final (scope, contentGuards) in [
    (UiPerformanceScope.full, false),
    (UiPerformanceScope.workspace, false),
    (UiPerformanceScope.workspace, true),
  ]) {
    testWidgets(
      'sparse ${scope.name} journey with content guards $contentGuards reaches production views',
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
            listContentGuards: contentGuards,
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
            contentGuards
                ? uiWorkspaceContentPerformanceProtocol
                : uiWorkspacePerformanceProtocol,
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
        expect(report['harnessVersion'], contentGuards ? 3 : 2);
        if (contentGuards) {
          expect(
            (report['protocol']! as Map)['listContent'],
            uiPerformanceListContentProtocol,
          );
          final fixture = buildUiPerformanceFixtures(names: ['sparse']).single;
          expect(report['workloadInputs'], [
            {
              'dataset': 'sparse',
              'inputSha256': sha256
                  .convert(
                    utf8.encode(
                      jsonEncode(
                        prepareUiPerformanceData(fixture.data).toJson(),
                      ),
                    ),
                  )
                  .toString(),
            },
          ]);
          final row = results.singleWhere(
            (row) => (row as Map)['scenario'] == 'general.list.open_scroll',
          ) as Map;
          final content = (row['details'] as Map)['listContent'] as Map;
          final points = content['checkpoints'] as List;
          expect(points.map((point) => (point as Map)['phase']), [
            'opened',
            'forward',
            'returned',
          ]);
          for (final point in points.cast<Map>()) {
            final paragraphs = point['paragraphs'] as List;
            expect(paragraphs, isNotEmpty);
            expect(
              point['textSha256'],
              sha256
                  .convert(
                    utf8.encode(
                      jsonEncode([
                        for (final paragraph in paragraphs)
                          (paragraph as Map)['text'],
                      ]),
                    ),
                  )
                  .toString(),
            );
            expect(
              point['observationStartUs'],
              greaterThanOrEqualTo(row['startUs']),
            );
            expect(point['observationEndUs'], lessThanOrEqualTo(row['endUs']));
          }
          expect(
            row['elapsedUs'],
            (row['endUs'] as int) - (row['startUs'] as int),
          );
          expect(
            results
                .where(
                  (item) =>
                      (item as Map)['scenario'] != 'general.list.open_scroll',
                )
                .every(
                  (item) => !((item as Map)['details'] as Map).containsKey(
                    'listContent',
                  ),
                ),
            isTrue,
          );
        } else {
          expect(report.containsKey('workloadInputs'), isFalse);
          expect(
            (report['protocol'] as Map).containsKey('listContent'),
            isFalse,
          );
        }
      },
      variant: TargetPlatformVariant({
        TargetPlatform.windows,
        TargetPlatform.android,
      }),
    );
  }
}
