import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/general_event_occurrence.dart';
import 'package:sked/models/general_schedule_data.dart';
import 'package:sked/services/general_calendar_service.dart';
import 'package:sked/services/general_occurrence_cache.dart';
import 'package:sked/services/general_occurrence_service.dart';

import '../integration_test/support/capture_output_directory.dart';
import 'src/benchmark_fixtures.dart';
import 'src/benchmark_runner.dart';
import 'src/performance_suite.dart';

void main() {
  test('records cold, edited and hot occurrence cache workloads', () async {
    const label = String.fromEnvironment(
      'SKED_BENCHMARK_LABEL',
      defaultValue: 'event-cache-local',
    );
    const revision = String.fromEnvironment(
      'SKED_BENCHMARK_REVISION',
      defaultValue: 'unknown',
    );
    final directory = createCaptureOutputDirectory(
      label: 'event-cache-benchmark',
      configuredPath: const String.fromEnvironment('SKED_BENCHMARK_OUTPUT_DIR'),
    );
    const verifyOnly = bool.fromEnvironment('SKED_BENCHMARK_VERIFY_ONLY');
    final fixtures = PerformanceFixtures.build();
    final initial = fixtures.generalData5000.normalized();
    final firstCalendar = initial.schedules.first;
    final edited = const GeneralCalendarService().saveEvent(
      initial,
      firstCalendar.events.first.copyWith(title: 'Edited benchmark event'),
    );
    final editedEvents = {
      for (final calendar in edited.schedules)
        for (final event in calendar.events) event.id: event,
    };
    final sharedEventCount = initial.schedules
        .expand((calendar) => calendar.events)
        .where((event) => identical(event, editedEvents[event.id]))
        .length;
    expect(sharedEventCount, 4999);
    final floatingInitial = initial
        .copyWith(
          schedules: [
            for (final calendar in initial.schedules)
              calendar.copyWith(
                events: [
                  for (final event in calendar.events)
                    event.copyWith(
                      startDateTimeIso: event.startDateTimeIso.replaceFirst(
                        RegExp(r'Z$'),
                        '',
                      ),
                      endDateTimeIso: event.endDateTimeIso.replaceFirst(
                        RegExp(r'Z$'),
                        '',
                      ),
                    ),
                ],
              ),
          ],
        )
        .normalized();
    final floatingEdited = const GeneralCalendarService().saveEvent(
      floatingInitial,
      floatingInitial.schedules.first.events.first.copyWith(
        title: 'Edited floating benchmark event',
      ),
    );
    final floatingEditedEvents = {
      for (final calendar in floatingEdited.schedules)
        for (final event in calendar.events) event.id: event,
    };
    expect(
      floatingInitial.schedules
          .expand((calendar) => calendar.events)
          .where((event) => identical(event, floatingEditedEvents[event.id])),
      hasLength(4999),
    );
    final queries = [
      for (var month = 1; month <= 3; month++)
        GeneralOccurrenceQuery(
          startInclusive: DateTime.utc(2026, month),
          endExclusive: DateTime.utc(2026, month).add(const Duration(days: 42)),
        ),
    ];
    const reference = GeneralOccurrenceService();
    List<GeneralEventOccurrence> expectedEdits(int count) => [
      for (final data in [initial, edited])
        for (final query in queries.take(count))
          ...reference.occurrencesForQuery(data, query),
    ];
    final singleCache = GeneralOccurrenceCache();
    final monthCache = GeneralOccurrenceCache();
    final hotCache = GeneralOccurrenceCache();
    final floatingCache = GeneralOccurrenceCache();
    hotCache.occurrencesForQuery(initial, queries.first);
    List<GeneralEventOccurrence> queryEdits(
      GeneralOccurrenceCache cache,
      int count,
    ) => [
      for (final data in <GeneralScheduleData>[initial, edited])
        for (final query in queries.take(count))
          ...cache.occurrencesForQuery(data, query),
    ];
    final queryChecksum = checksumOccurrences(
      reference.occurrencesForQuery(initial, queries.first),
    );
    final editChecksum = checksumOccurrences(expectedEdits(1));
    final monthEditChecksum = checksumOccurrences(expectedEdits(3));
    final floatingQueryChecksum = checksumOccurrences(
      reference.occurrencesForQuery(floatingInitial, queries.first),
    );
    final floatingEditChecksum = checksumOccurrences([
      for (final data in [floatingInitial, floatingEdited])
        ...reference.occurrencesForQuery(data, queries.first),
    ]);
    final cases = [
      PerformanceBenchmarkCase.typed<List<GeneralEventOccurrence>>(
        name: 'event_cache.5000_42d_first_query',
        operation: () => GeneralOccurrenceCache().occurrencesForQuery(
          initial,
          queries.first,
        ),
        checksum: checksumOccurrences,
        expectedChecksum: queryChecksum,
      ),
      PerformanceBenchmarkCase.typed<List<GeneralEventOccurrence>>(
        name: 'event_cache.5000_42d_two_edits',
        operation: () => queryEdits(singleCache, 1),
        checksum: checksumOccurrences,
        expectedChecksum: editChecksum,
      ),
      PerformanceBenchmarkCase.typed<List<GeneralEventOccurrence>>(
        name: 'event_cache.5000_three_months_two_edits',
        operation: () => queryEdits(monthCache, 3),
        checksum: checksumOccurrences,
        expectedChecksum: monthEditChecksum,
      ),
      PerformanceBenchmarkCase.typed<List<GeneralEventOccurrence>>(
        name: 'event_cache.5000_42d_hot_query',
        operation: () => hotCache.occurrencesForQuery(initial, queries.first),
        checksum: checksumOccurrences,
        expectedChecksum: queryChecksum,
      ),
      PerformanceBenchmarkCase.typed<List<GeneralEventOccurrence>>(
        name: 'event_cache.5000_floating_42d_first_query',
        operation: () => GeneralOccurrenceCache().occurrencesForQuery(
          floatingInitial,
          queries.first,
        ),
        checksum: checksumOccurrences,
        expectedChecksum: floatingQueryChecksum,
      ),
      PerformanceBenchmarkCase.typed<List<GeneralEventOccurrence>>(
        name: 'event_cache.5000_floating_42d_two_edits',
        operation: () => [
          for (final data in [floatingInitial, floatingEdited])
            ...floatingCache.occurrencesForQuery(data, queries.first),
        ],
        checksum: checksumOccurrences,
        expectedChecksum: floatingEditChecksum,
      ),
    ];
    final report = BenchmarkReport(
      label: safeBenchmarkLabel(label),
      revision: revision,
      datasetVersion: performanceDatasetVersion,
      runtime: {
        ...benchmarkRuntimeMetadata('flutter-test-host-jit'),
        'measurement': verifyOnly ? 'verification-only' : 'timed',
      },
      dataset: {
        ...fixtures.manifest,
        'normalizedSnapshot': true,
        'sharedEventCountAcrossEdit': sharedEventCount,
        'queryChecksum': queryChecksum,
        'editChecksum': editChecksum,
        'monthEditChecksum': monthEditChecksum,
        'floatingQueryChecksum': floatingQueryChecksum,
        'floatingEditChecksum': floatingEditChecksum,
        'floatingSharedEventCountAcrossEdit': 4999,
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
    expect(report.results.length, 6);
  }, timeout: Timeout.none);
}
