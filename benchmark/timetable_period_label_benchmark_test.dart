import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/widgets/timetable_grid.dart';

import '../integration_test/support/capture_output_directory.dart';
import '../test/support/timetable_period_rail_harness.dart';
import 'src/benchmark_runner.dart';

void main() {
  testWidgets(
    'records period label first, repeated and changed layouts',
    (tester) async {
      const label = String.fromEnvironment(
        'SKED_BENCHMARK_LABEL',
        defaultValue: 'period-label-local',
      );
      const revision = String.fromEnvironment(
        'SKED_BENCHMARK_REVISION',
        defaultValue: 'unknown',
      );
      const verifyOnly = bool.fromEnvironment('SKED_BENCHMARK_VERIFY_ONLY');
      final directory = createCaptureOutputDirectory(
        label: 'period-label-benchmark',
        configuredPath: const String.fromEnvironment(
          'SKED_BENCHMARK_OUTPUT_DIR',
        ),
      );
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final results = <BenchmarkCaseResult>[];
      final frequency = Stopwatch().frequency;
      try {
        for (final count in [12, 48]) {
          final periods = List.generate(
            count,
            (index) => CoursePeriodTime(
              index: index + 1,
              startMinutes: count == 12 ? 480 + index * 60 : index * 30,
              endMinutes: count == 12 ? 525 + index * 60 : index * 30 + 25,
            ),
          );
          final changed = [
            ...periods.take(count - 1),
            periods.last.copyWith(
              startMinutes: periods.last.startMinutes + 1,
              endMinutes: periods.last.endMinutes + 1,
            ),
          ];
          await tester.pumpWidget(periodRailHarness(periods: periods));
          await tester.pumpAndSettle();
          final expected = _checksum(tester);
          for (final mode in [
            'first',
            'eight_repeated_layouts',
            'eight_period_edits',
          ]) {
            final samples = <double>[];
            const warmups = verifyOnly ? 0 : 5;
            const sampleCount = verifyOnly ? 1 : 11;
            for (var batch = -warmups; batch < sampleCount; batch++) {
              var ticks = 0;
              if (mode == 'first') {
                await tester.pumpWidget(const SizedBox.shrink());
                final app = periodRailHarness(periods: periods);
                final stopwatch = Stopwatch()..start();
                await tester.pumpWidget(app);
                await tester.pumpAndSettle(const Duration(milliseconds: 16));
                stopwatch.stop();
                ticks = stopwatch.elapsedTicks;
              } else {
                for (var index = 0; index < 8; index++) {
                  if (mode == 'eight_repeated_layouts') {
                    final layout = tester.element(
                      find
                          .descendant(
                            of: find.byType(TimetableGrid),
                            matching: find.byType(LayoutBuilder),
                          )
                          .first,
                    );
                    final stopwatch = Stopwatch()..start();
                    layout.markNeedsBuild();
                    await tester.pumpAndSettle(
                      const Duration(milliseconds: 16),
                    );
                    stopwatch.stop();
                    ticks += stopwatch.elapsedTicks;
                  } else {
                    final app = periodRailHarness(
                      periods: index.isEven ? changed : periods,
                    );
                    final stopwatch = Stopwatch()..start();
                    await tester.pumpWidget(app);
                    await tester.pumpAndSettle(
                      const Duration(milliseconds: 16),
                    );
                    stopwatch.stop();
                    ticks += stopwatch.elapsedTicks;
                  }
                }
              }
              if (batch >= 0) {
                samples.add(ticks * Duration.microsecondsPerSecond / frequency);
              }
            }
            expect(_checksum(tester), expected);
            expect(tester.takeException(), isNull);
            final median = benchmarkMedian(samples);
            results.add(
              BenchmarkCaseResult(
                name: 'period_labels.$count.$mode',
                operationsPerSample: 1,
                warmupBatches: warmups,
                samplesMicrosPerOperation: samples,
                medianMicrosPerOperation: median,
                medianAbsoluteDeviation: benchmarkMedian(
                  samples.map((value) => (value - median).abs()).toList(),
                ),
                minimumMicrosPerOperation: samples.reduce(
                  (a, b) => a < b ? a : b,
                ),
                checksum: expected,
              ),
            );
          }
          await tester.pumpWidget(const SizedBox.shrink());
        }
        final report = BenchmarkReport(
          label: safeBenchmarkLabel(label),
          revision: revision,
          datasetVersion: 1,
          runtime: {
            ...benchmarkRuntimeMetadata('flutter-widget-test-host-jit'),
            'measurement': verifyOnly ? 'verification-only' : 'timed',
            'timingScope': 'grid-widget-layout-pumps',
            'sampleProtocol': 'one-mount-or-eight-updates-no-calibration',
          },
          dataset: {
            'periodCounts': [12, 48],
            'courses': 0,
            'preserveGaps': true,
            'surfaceWidth': 1280,
            'gridWidth': 1120,
            'height': 900,
            'devicePixelRatio': 1,
            'textScale': 1,
            'periodDurationMinutes': [45, 25],
            'periodSpacingMinutes': [60, 30],
          },
          results: results,
        );
        final output = File(
          '${directory.path}/windows-host-${report.label}.json',
        )..writeAsStringSync('${report.encode()}\n');
        stdout.writeln('Benchmark report: ${output.absolute.path}');
        expect(results, hasLength(6));
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
    timeout: Timeout.none,
  );
}

String _checksum(WidgetTester tester) {
  final checksum = StableChecksum();
  for (final finder in [
    find.byKey(const ValueKey('timetable-time-rail')),
    for (var day = 1; day <= 7; day++)
      find.byKey(ValueKey('timetable-day-column-$day')),
  ]) {
    final rect = tester.getRect(finder);
    for (final value in [rect.left, rect.top, rect.width, rect.height]) {
      checksum.addString(value.toStringAsPrecision(17));
    }
  }
  for (final text in tester.widgetList<Text>(find.byType(Text))) {
    checksum.addString(text.data ?? text.textSpan?.toPlainText() ?? '');
  }
  return checksum.finish();
}
