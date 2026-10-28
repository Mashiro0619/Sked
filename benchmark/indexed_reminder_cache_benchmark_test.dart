import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/general_occurrence_cache.dart';
import 'package:sked/services/general_occurrence_service.dart';

import '../integration_test/support/capture_output_directory.dart';
import 'src/benchmark_runner.dart';

void main() {
  test(
    'records indexed reminder preparation and exact-query controls',
    () async {
      const label = String.fromEnvironment(
        'SKED_BENCHMARK_LABEL',
        defaultValue: 'indexed-reminder-local',
      );
      const revision = String.fromEnvironment(
        'SKED_BENCHMARK_REVISION',
        defaultValue: 'unknown',
      );
      const verifyOnly = bool.fromEnvironment('SKED_BENCHMARK_VERIFY_ONLY');
      final directory = createCaptureOutputDirectory(
        label: 'indexed-reminder-benchmark',
        configuredPath: const String.fromEnvironment(
          'SKED_BENCHMARK_OUTPUT_DIR',
        ),
      );
      final data = _fixture();
      expect(data.schedules.single.events, hasLength(100));
      expect(data.reminderAcknowledgements, hasLength(6000));
      final minute = DateTime.utc(2026, 6, 1, 9);
      final sameMinute = [
        minute,
        minute.add(const Duration(seconds: 20)),
        minute.add(const Duration(seconds: 40)),
        minute.add(const Duration(seconds: 59, microseconds: 999999)),
      ];
      final separateMinutes = [
        for (var i = 0; i < 4; i++) minute.add(Duration(minutes: i)),
      ];
      const reference = GeneralOccurrenceService();
      List<List<GeneralReminderItem>> expected(List<DateTime> anchors) => [
        for (final now in anchors) reference.reminderItems(data, now: now),
      ];
      List<List<GeneralReminderItem>> query(
        GeneralOccurrenceCache cache,
        List<DateTime> anchors,
      ) => [for (final now in anchors) cache.reminderItems(data, now: now)];
      final singleChecksum = _checksum(expected([minute]));
      final sameMinuteChecksum = _checksum(expected(sameMinute));
      final separateMinutesChecksum = _checksum(expected(separateMinutes));
      final sharedCache = GeneralOccurrenceCache();
      final separateCache = GeneralOccurrenceCache();
      final hotCache = GeneralOccurrenceCache();
      hotCache.reminderItems(data, now: minute);
      final cases = [
        PerformanceBenchmarkCase.typed<List<List<GeneralReminderItem>>>(
          name: 'indexed_reminder.100_events_6000_history_first',
          operation: () => query(GeneralOccurrenceCache(), [minute]),
          checksum: _checksum,
          expectedChecksum: singleChecksum,
        ),
        PerformanceBenchmarkCase.typed<List<List<GeneralReminderItem>>>(
          name: 'indexed_reminder.four_same_minute_queries',
          operation: () => query(sharedCache, sameMinute),
          checksum: _checksum,
          expectedChecksum: sameMinuteChecksum,
        ),
        PerformanceBenchmarkCase.typed<List<List<GeneralReminderItem>>>(
          name: 'indexed_reminder.four_separate_minute_queries',
          operation: () => query(separateCache, separateMinutes),
          checksum: _checksum,
          expectedChecksum: separateMinutesChecksum,
        ),
        PerformanceBenchmarkCase.typed<List<List<GeneralReminderItem>>>(
          name: 'indexed_reminder.exact_hot_query',
          operation: () => query(hotCache, [minute]),
          checksum: _checksum,
          expectedChecksum: singleChecksum,
        ),
      ];
      final report = BenchmarkReport(
        label: safeBenchmarkLabel(label),
        revision: revision,
        datasetVersion: 1,
        runtime: {
          ...benchmarkRuntimeMetadata('flutter-test-host-jit'),
          'measurement': verifyOnly ? 'verification-only' : 'timed',
        },
        dataset: {
          'events': 100,
          'history': 6000,
          'leadMinutes': 129 * 24 * 60,
          'normalizedSnapshot': true,
          'sameMinuteAnchors': sameMinute
              .map((value) => value.toIso8601String())
              .toList(),
          'separateMinuteAnchors': separateMinutes
              .map((value) => value.toIso8601String())
              .toList(),
          'singleChecksum': singleChecksum,
          'sameMinuteChecksum': sameMinuteChecksum,
          'separateMinutesChecksum': separateMinutesChecksum,
        },
        results: await runPerformanceBenchmarks(
          cases,
          config: verifyOnly
              ? const BenchmarkRunConfig(
                  targetSample: Duration.zero,
                  warmupBatches: 0,
                  sampleBatches: 1,
                  operationsPerSampleOverride: 1,
                )
              : const BenchmarkRunConfig(),
        ),
      );
      final output = File('${directory.path}/windows-host-${report.label}.json')
        ..writeAsStringSync('${report.encode()}\n');
      stdout.writeln('Benchmark report: ${output.absolute.path}');
      expect(report.results, hasLength(4));
    },
    timeout: Timeout.none,
  );
}

GeneralScheduleData _fixture() {
  final events = [
    for (var i = 0; i < 100; i++)
      GeneralEvent(
        id: 'event|$i',
        calendarId: 'benchmark|calendar',
        title: 'Event $i',
        startDateTimeIso: DateTime.utc(
          2026,
          1,
          1,
          9,
          0,
          i % 60,
        ).toIso8601String(),
        endDateTimeIso: DateTime.utc(
          2026,
          1,
          1,
          9,
          0,
          i % 60 + 20,
        ).toIso8601String(),
        recurrenceRule: const GeneralEventRecurrenceRule(
          type: GeneralEventRecurrence.daily,
          count: 365,
        ),
        reminderBehavior: GeneralEventReminderBehavior.custom,
        reminders: const [GeneralEventReminder(minutesBefore: 129 * 24 * 60)],
      ),
  ];
  return GeneralScheduleData(
    activeScheduleId: 'benchmark|calendar',
    selectedDateIso: '2026-06-01',
    schedules: [
      GeneralSchedule(
        id: 'benchmark|calendar',
        name: 'Calendar',
        events: events,
      ),
    ],
    reminderAcknowledgements: [
      for (final event in events)
        for (var day = 0; day < 60; day++)
          GeneralReminderAcknowledgement(
            occurrenceKey: buildGeneralOccurrenceKey(
              event.calendarId,
              event.id,
              DateTime.parse(event.startDateTimeIso)
                  .add(Duration(days: day))
                  .toIso8601String(),
            ),
            updatedAtIso: '2026-04-01T00:00:00Z',
          ),
    ],
  ).normalized();
}

String _checksum(List<List<GeneralReminderItem>> groups) {
  final checksum = StableChecksum()..addInt(groups.length);
  for (final items in groups) {
    checksum.addInt(items.length);
    for (final item in items) {
      final occurrence = item.occurrence;
      checksum
        ..addString(item.status.name)
        ..addString(occurrence.occurrenceKey)
        ..addString(occurrence.end.toIso8601String())
        ..addInt(occurrence.sequence)
        ..addString(occurrence.calendar.name)
        ..addString(occurrence.event.title);
    }
  }
  return checksum.finish();
}
