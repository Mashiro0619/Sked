import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/general_schedule_home_screen.dart';
import 'package:sked/widgets/workspace_frame.dart';

import '../integration_test/support/capture_output_directory.dart';
import '../test/support/workspace_harness.dart';
import 'src/benchmark_runner.dart';

void main() {
  testWidgets(
    'records home field subscriptions and visible-update controls',
    (tester) async {
      const label = String.fromEnvironment(
        'SKED_BENCHMARK_LABEL',
        defaultValue: 'home-subscription-local',
      );
      const revision = String.fromEnvironment(
        'SKED_BENCHMARK_REVISION',
        defaultValue: 'unknown',
      );
      const verifyOnly = bool.fromEnvironment('SKED_BENCHMARK_VERIFY_ONLY');
      final directory = createCaptureOutputDirectory(
        label: 'home-subscription-benchmark',
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
      for (final view in [generalViewWeek, generalViewMonth, generalViewList]) {
        final provider = await workspaceProvider(
          storage: WorkspaceMemoryStorage(_data(view)),
        );
        final previousHook = debugOnRebuildDirtyWidget;
        var builds = 0;
        try {
          await tester.pumpWidget(
            WorkspaceHarness(
              provider: provider,
              home: GeneralReminderTimeScope(
                now: () => DateTime(2026, 6, 1, 9),
                createTimer: Timer.new,
                child: const GeneralScheduleHomeScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          debugOnRebuildDirtyWidget = (element, builtOnce) {
            if (element.widget is GeneralScheduleHomeScreen) builds++;
            previousHook?.call(element, builtOnce);
          };
          for (final visible in [false, true]) {
            final samples = <double>[];
            final buildSamples = <double>[];
            final frameSamples = <double>[];
            final expected = _checksum(tester);
            const warmups = verifyOnly ? 0 : 5;
            const sampleCount = verifyOnly ? 1 : 11;
            for (var batch = -warmups; batch < sampleCount; batch++) {
              var elapsedTicks = 0;
              var frames = 0;
              builds = 0;
              for (final alternate in [true, false, true, false]) {
                // Complete the memory save before measuring the widget response.
                // Only pump work is timed; this is not end-to-end save latency.
                if (visible) {
                  await provider.generalCommands.renameSchedule(
                    'calendar',
                    alternate ? 'Calendar B' : 'Calendar A',
                  );
                } else {
                  await provider.generalCommands.updateDisplaySettings(
                    closeEventPopupOnOutsideTap: !alternate,
                  );
                }
                final stopwatch = Stopwatch()..start();
                frames += await tester.pumpAndSettle(
                  const Duration(milliseconds: 16),
                );
                stopwatch.stop();
                elapsedTicks += stopwatch.elapsedTicks;
              }
              if (batch >= 0) {
                samples.add(
                  elapsedTicks * Duration.microsecondsPerSecond / frequency,
                );
                buildSamples.add(builds.toDouble());
                frameSamples.add(frames.toDouble());
              }
            }
            expect(_checksum(tester), expected);
            expect(tester.takeException(), isNull);
            final median = benchmarkMedian(samples);
            results.add(
              BenchmarkCaseResult(
                name:
                    'home.$view.${visible ? 'visible_calendar_name' : 'popup_setting'}.four_updates',
                operationsPerSample: 1,
                warmupBatches: warmups,
                samplesMicrosPerOperation: samples,
                medianMicrosPerOperation: median,
                medianAbsoluteDeviation: benchmarkMedian(
                  samples.map((sample) => (sample - median).abs()).toList(),
                ),
                minimumMicrosPerOperation: samples.reduce(
                  (a, b) => a < b ? a : b,
                ),
                checksum: expected,
                metrics: {
                  'homeBuildsPerOperation': benchmarkMedian(buildSamples),
                  'framePumpsPerOperation': benchmarkMedian(frameSamples),
                },
              ),
            );
          }
        } finally {
          debugOnRebuildDirtyWidget = previousHook;
          await tester.pumpWidget(const SizedBox.shrink());
          provider.dispose();
        }
      }
      final report = BenchmarkReport(
        label: safeBenchmarkLabel(label),
        revision: revision,
        datasetVersion: 1,
        runtime: {
          ...benchmarkRuntimeMetadata('flutter-widget-test-host-jit'),
          'measurement': verifyOnly ? 'verification-only' : 'timed',
          'timingScope': 'widget-pumps-after-memory-save',
          'sampleProtocol': 'four-updates-per-sample-no-calibration',
        },
        dataset: {
          'events': 100,
          'width': 1280,
          'height': 900,
          'devicePixelRatio': 1,
          'textScale': 1,
          'selectedDate': '2026-06-01',
          'reminderNow': '2026-06-01T09:00:00 local',
          'views': [generalViewWeek, generalViewMonth, generalViewList],
        },
        results: results,
      );
      final output = File('${directory.path}/windows-host-${report.label}.json')
        ..writeAsStringSync('${report.encode()}\n');
      stdout.writeln('Benchmark report: ${output.absolute.path}');
      expect(results, hasLength(6));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
    timeout: Timeout.none,
  );
}

AppData _data(String view) =>
    buildInitialAppData(buildDefaultPeriodTimes(), localeCode: 'en').copyWith(
      activeMode: AppMode.general,
      generalMode: GeneralScheduleData(
        activeScheduleId: 'calendar',
        selectedDateIso: '2026-06-01',
        defaultView: view,
        schedules: [
          GeneralSchedule(
            id: 'calendar',
            name: 'Calendar A',
            events: [
              for (var i = 0; i < 100; i++)
                GeneralEvent(
                  id: 'event-$i',
                  calendarId: 'calendar',
                  title: 'Event $i',
                  startDateTimeIso: DateTime(
                    2026,
                    6,
                    1 + i % 28,
                    8 + i % 10,
                  ).toIso8601String(),
                  endDateTimeIso: DateTime(
                    2026,
                    6,
                    1 + i % 28,
                    9 + i % 10,
                  ).toIso8601String(),
                ),
            ],
          ),
        ],
      ),
    );

String _checksum(WidgetTester tester) {
  final checksum = StableChecksum();
  final frame = tester.widget<WorkspaceFrame>(
    find.byType(WorkspaceFrame).first,
  );
  final context = frame.contextSnapshot!;
  checksum
    ..addString(context.view)
    ..addString(context.resourceId ?? '')
    ..addString(context.date?.toIso8601String() ?? '')
    ..addString(context.endDate?.toIso8601String() ?? '');
  for (final text in tester.widgetList<Text>(find.byType(Text))) {
    checksum.addString(text.data ?? text.textSpan?.toPlainText() ?? '');
  }
  return checksum.finish();
}
