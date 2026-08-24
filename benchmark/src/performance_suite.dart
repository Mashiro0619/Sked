import 'package:sked/models/app_backup.dart';
import 'package:sked/models/app_data.dart';
import 'package:sked/models/general_event_occurrence.dart';
import 'package:sked/models/general_schedule_data.dart';
import 'package:sked/services/general_occurrence_cache.dart';
import 'package:sked/services/general_occurrence_service.dart';
import 'package:sked/services/school_import_content_sanitizer.dart';

import 'benchmark_fixtures.dart';
import 'benchmark_runner.dart';

const _expectedChecksums = <String, String>{
  'occurrence.1000_7d_cold': 'fnv1a64-utf16le:cf98943344242498',
  'occurrence.5000_42d_cold': 'fnv1a64-utf16le:de23b67a384a1d3e',
  'occurrence.5000_180d_cold': 'fnv1a64-utf16le:81ac72fd37e970c9',
  'occurrence.5000_180d_hot_cache': 'fnv1a64-utf16le:81ac72fd37e970c9',
  'cache.1000_churn': 'fnv1a64-utf16le:41afccfcf48cf9ee',
  'sanitizer.table_full': 'fnv1a64-utf16le:e8d76fa6544f75cd',
  'sanitizer.table_240k': 'fnv1a64-utf16le:3f7220f07decc524',
  'app_data.5000_encode': 'fnv1a64-utf16le:83d9ccdcc4c8e194',
  'app_data.5000_decode_storage': 'fnv1a64-utf16le:69711c0e45009903',
  'app_backup.5000_encode': 'fnv1a64-utf16le:b64a088d9b9072f0',
  'app_backup.5000_decode': 'fnv1a64-utf16le:ce38f919f0744de5',
};

List<PerformanceBenchmarkCase> buildPerformanceBenchmarkCases(
  PerformanceFixtures fixtures,
) {
  const occurrenceService = GeneralOccurrenceService();
  final query7Days = _rangeQuery(const Duration(days: 7));
  final query42Days = _rangeQuery(const Duration(days: 42));
  final query180Days = _rangeQuery(const Duration(days: 180));
  final hotCache = GeneralOccurrenceCache();
  hotCache.occurrencesForQuery(fixtures.generalData5000, query180Days);

  return [
    PerformanceBenchmarkCase.typed<List<GeneralEventOccurrence>>(
      name: 'occurrence.1000_7d_cold',
      operation: () => occurrenceService.occurrencesForQuery(
        fixtures.generalData1000,
        query7Days,
      ),
      checksum: checksumOccurrences,
      expectedChecksum: _expectedChecksums['occurrence.1000_7d_cold']!,
    ),
    PerformanceBenchmarkCase.typed<List<GeneralEventOccurrence>>(
      name: 'occurrence.5000_42d_cold',
      operation: () => occurrenceService.occurrencesForQuery(
        fixtures.generalData5000,
        query42Days,
      ),
      checksum: checksumOccurrences,
      expectedChecksum: _expectedChecksums['occurrence.5000_42d_cold']!,
    ),
    PerformanceBenchmarkCase.typed<List<GeneralEventOccurrence>>(
      name: 'occurrence.5000_180d_cold',
      operation: () => occurrenceService.occurrencesForQuery(
        fixtures.generalData5000,
        query180Days,
      ),
      checksum: checksumOccurrences,
      expectedChecksum: _expectedChecksums['occurrence.5000_180d_cold']!,
    ),
    PerformanceBenchmarkCase.typed<List<GeneralEventOccurrence>>(
      name: 'occurrence.5000_180d_hot_cache',
      operation: () =>
          hotCache.occurrencesForQuery(fixtures.generalData5000, query180Days),
      checksum: checksumOccurrences,
      expectedChecksum: _expectedChecksums['occurrence.5000_180d_hot_cache']!,
    ),
    PerformanceBenchmarkCase.typed<CacheChurnBenchmarkResult>(
      name: 'cache.1000_churn',
      operation: () => runCacheChurnBenchmark(fixtures.generalData1000),
      checksum: checksumCacheChurn,
      expectedChecksum: _expectedChecksums['cache.1000_churn']!,
      metrics: (result) => {'serviceCalls': result.serviceCalls},
    ),
    PerformanceBenchmarkCase.typed<SchoolImportSanitizationResult>(
      name: 'sanitizer.table_full',
      operation: () => SchoolImportContentSanitizer.sanitizeWithResult(
        fixtures.sanitizerTableInput,
      ),
      checksum: checksumSanitizationResult,
      expectedChecksum: _expectedChecksums['sanitizer.table_full']!,
    ),
    PerformanceBenchmarkCase.typed<SchoolImportSanitizationResult>(
      name: 'sanitizer.table_240k',
      operation: () => SchoolImportContentSanitizer.sanitizeWithResult(
        fixtures.sanitizerNearLimitInput,
      ),
      checksum: checksumSanitizationResult,
      expectedChecksum: _expectedChecksums['sanitizer.table_240k']!,
    ),
    PerformanceBenchmarkCase.typed<String>(
      name: 'app_data.5000_encode',
      operation: fixtures.appData.encode,
      checksum: checksumString,
      expectedChecksum: _expectedChecksums['app_data.5000_encode']!,
    ),
    PerformanceBenchmarkCase.typed<AppData>(
      name: 'app_data.5000_decode_storage',
      operation: () => AppData.decodeStorageSnapshot(fixtures.appDataSnapshot),
      checksum: checksumAppData,
      expectedChecksum: _expectedChecksums['app_data.5000_decode_storage']!,
    ),
    PerformanceBenchmarkCase.typed<String>(
      name: 'app_backup.5000_encode',
      operation: () => encodeAppBackup(fixtures.appData, fixtures.schoolSites),
      checksum: checksumString,
      expectedChecksum: _expectedChecksums['app_backup.5000_encode']!,
    ),
    PerformanceBenchmarkCase.typed<AppBackupData>(
      name: 'app_backup.5000_decode',
      operation: () => decodeAppBackup(fixtures.appBackupSnapshot),
      checksum: checksumAppBackup,
      expectedChecksum: _expectedChecksums['app_backup.5000_decode']!,
    ),
  ];
}

Future<BenchmarkReport> runPerformanceSuite({
  required String label,
  required String revision,
  required String runtime,
  BenchmarkRunConfig config = const BenchmarkRunConfig(),
}) async {
  final safeLabel = safeBenchmarkLabel(label);
  final fixtures = PerformanceFixtures.build();
  final results = await runPerformanceBenchmarks(
    buildPerformanceBenchmarkCases(fixtures),
    config: config,
  );
  return BenchmarkReport(
    label: safeLabel,
    revision: revision.trim().isEmpty ? 'unknown' : revision.trim(),
    datasetVersion: performanceDatasetVersion,
    runtime: benchmarkRuntimeMetadata(runtime),
    dataset: fixtures.manifest,
    results: results,
  );
}

GeneralOccurrenceQuery _rangeQuery(Duration duration) {
  final start = DateTime.utc(2026);
  return GeneralOccurrenceQuery(
    startInclusive: start,
    endExclusive: start.add(duration),
  );
}

String checksumOccurrences(List<GeneralEventOccurrence> occurrences) {
  final checksum = StableChecksum()..addInt(occurrences.length);
  for (final occurrence in occurrences) {
    checksum
      ..addString(occurrence.calendar.id)
      ..addString(occurrence.event.id)
      ..addString(occurrence.start.toIso8601String())
      ..addString(occurrence.end.toIso8601String())
      ..addInt(occurrence.sequence);
  }
  return checksum.finish();
}

String checksumSanitizationResult(SchoolImportSanitizationResult result) {
  final checksum = StableChecksum()
    ..addBool(result.wasTruncated)
    ..addString(result.content);
  return checksum.finish();
}

String checksumString(String value) {
  final checksum = StableChecksum()..addString(value);
  return checksum.finish();
}

String checksumAppData(AppData value) => checksumString(value.encode());

String checksumAppBackup(AppBackupData value) {
  final checksum = StableChecksum()
    ..addBool(value.includesSchoolSites)
    ..addString(encodeAppBackup(value.appData, value.schoolSites));
  return checksum.finish();
}

class CacheChurnBenchmarkResult {
  const CacheChurnBenchmarkResult({
    required this.queriesIssued,
    required this.resultsSeen,
    required this.serviceCalls,
  });

  final int queriesIssued;
  final int resultsSeen;
  final int serviceCalls;
}

CacheChurnBenchmarkResult runCacheChurnBenchmark(GeneralScheduleData general) {
  final service = _CountingOccurrenceService();
  final cache = GeneralOccurrenceCache(service: service);
  const hotEntryCount = 16;
  const coldEntriesPerRound = 48;
  const rounds = 12;
  var queriesIssued = 0;
  var resultsSeen = 0;

  void query(int index) {
    final start = DateTime.utc(2026).add(Duration(minutes: index));
    resultsSeen += cache
        .occurrencesForQuery(
          general,
          GeneralOccurrenceQuery(
            startInclusive: start,
            endExclusive: start.add(const Duration(minutes: 1)),
          ),
        )
        .length;
    queriesIssued += 1;
  }

  for (var index = 0; index < 64; index += 1) {
    query(index);
  }
  var nextColdEntry = 64;
  for (var round = 0; round < rounds; round += 1) {
    for (var hotEntry = 0; hotEntry < hotEntryCount; hotEntry += 1) {
      query(hotEntry);
    }
    for (var coldEntry = 0; coldEntry < coldEntriesPerRound; coldEntry += 1) {
      query(nextColdEntry);
      nextColdEntry += 1;
    }
  }

  return CacheChurnBenchmarkResult(
    queriesIssued: queriesIssued,
    resultsSeen: resultsSeen,
    serviceCalls: service.callCount,
  );
}

String checksumCacheChurn(CacheChurnBenchmarkResult result) {
  final checksum = StableChecksum()
    ..addInt(result.queriesIssued)
    ..addInt(result.resultsSeen);
  return checksum.finish();
}

class _CountingOccurrenceService extends GeneralOccurrenceService {
  int callCount = 0;

  @override
  List<GeneralEventOccurrence> occurrencesForQuery(
    GeneralScheduleData general,
    GeneralOccurrenceQuery query,
  ) {
    callCount += 1;
    return const [];
  }
}

Map<String, String> computePerformanceFixtureChecksums(
  PerformanceFixtures fixtures,
) {
  return {
    for (final benchmarkCase in buildPerformanceBenchmarkCases(fixtures))
      benchmarkCase.name: benchmarkCase.checksum(benchmarkCase.operation()),
  };
}

Map<String, String> get expectedPerformanceFixtureChecksums =>
    _expectedChecksums;
