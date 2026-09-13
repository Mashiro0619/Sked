import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/app_backup.dart';
import 'package:sked/models/app_data.dart';
import 'package:sked/models/general_event_occurrence.dart';
import 'package:sked/services/general_occurrence_service.dart';
import 'package:sked/services/school_import_content_sanitizer.dart';

import '../benchmark/src/benchmark_fixtures.dart';
import '../benchmark/src/benchmark_runner.dart';
import '../benchmark/src/performance_suite.dart';

void main() {
  late PerformanceFixtures fixtures;

  setUpAll(() {
    fixtures = PerformanceFixtures.build();
  });

  test('fixture has the fixed large-data shape', () {
    expect(fixtures.generalData1000.schedules, hasLength(8));
    expect(
      fixtures.generalData1000.schedules.expand((schedule) => schedule.events),
      hasLength(1000),
    );
    expect(
      fixtures.generalData5000.schedules.expand((schedule) => schedule.events),
      hasLength(5000),
    );
    expect(fixtures.appData.studentMode.timetables, hasLength(5));
    expect(
      fixtures.appData.studentMode.timetables.expand(
        (timetable) => timetable.courses,
      ),
      hasLength(5000),
    );
    expect(fixtures.schoolSites, hasLength(128));
    expect(
      fixtures.sanitizerTableInput.length,
      lessThan(SchoolImportContentSanitizer.maxInputLength),
    );
    expect(
      fixtures.sanitizerNearLimitInput.length,
      greaterThan(SchoolImportContentSanitizer.maxInputLength),
    );
    expect(
      fixtures.sanitizerNearLimitInput.length,
      lessThan(SchoolImportContentSanitizer.maxInputLength + 10000),
    );
    expect(fixtures.appDataSnapshot.length, greaterThan(500000));
    expect(fixtures.appBackupSnapshot.length, greaterThan(500000));
  });

  test('fixture exercises full and bounded sanitizer paths', () {
    final full = SchoolImportContentSanitizer.sanitizeWithResult(
      fixtures.sanitizerTableInput,
    );
    final bounded = SchoolImportContentSanitizer.sanitizeWithResult(
      fixtures.sanitizerNearLimitInput,
    );

    expect(full.wasTruncated, isFalse);
    expect(full.content.length, lessThan(120000));
    expect(bounded.wasTruncated, isTrue);
    expect(bounded.content.length, lessThanOrEqualTo(120000));
  });

  test('range fixtures exercise the 1k/5k and 7/42/180 day matrix', () {
    const service = GeneralOccurrenceService();
    final start = DateTime.utc(2026);
    final small7Days = service.occurrencesForQuery(
      fixtures.generalData1000,
      GeneralOccurrenceQuery(
        startInclusive: start,
        endExclusive: start.add(const Duration(days: 7)),
      ),
    );
    final large42Days = service.occurrencesForQuery(
      fixtures.generalData5000,
      GeneralOccurrenceQuery(
        startInclusive: start,
        endExclusive: start.add(const Duration(days: 42)),
      ),
    );
    final large180Days = service.occurrencesForQuery(
      fixtures.generalData5000,
      GeneralOccurrenceQuery(
        startInclusive: start,
        endExclusive: start.add(const Duration(days: 180)),
      ),
    );

    expect(small7Days, isNotEmpty);
    expect(large42Days.length, greaterThan(small7Days.length));
    expect(large180Days.length, greaterThan(large42Days.length));
  });

  test('fixture workloads retain their contract checksums', () {
    final actual = computePerformanceFixtureChecksums(fixtures);

    expect(actual, expectedPerformanceFixtureChecksums);
  });
  test(
    'v5 and display-default additions do not change fixture workload data',
    () {
      String asV4(String source) {
        expect(RegExp('"schemaVersion":5').allMatches(source), hasLength(1));
        final root = jsonDecode(source) as Map<String, dynamic>;
        final app =
            (root['data'] == null
                    ? root
                    : (root['data'] as Map<String, dynamic>)['appData'])
                as Map<String, dynamic>;
        final general = app['generalMode'] as Map<String, dynamic>;
        expect(general.remove('fitWeekColumnsToWidth'), isTrue);
        general['schemaVersion'] = 4;
        return jsonEncode(root);
      }

      expect(
        checksumString(asV4(fixtures.appData.encode())),
        'fnv1a64-utf16le:8c67108b3c250c39',
      );
      expect(
        checksumString(
          asV4(
            AppData.decodeStorageSnapshot(fixtures.appDataSnapshot).encode(),
          ),
        ),
        'fnv1a64-utf16le:e36d066bc8da45bf',
      );
      expect(
        checksumString(
          asV4(encodeAppBackup(fixtures.appData, fixtures.schoolSites)),
        ),
        'fnv1a64-utf16le:e1b21719137bb127',
      );
      final decoded = decodeAppBackup(fixtures.appBackupSnapshot);
      final checksum = StableChecksum()
        ..addBool(decoded.includesSchoolSites)
        ..addString(
          asV4(encodeAppBackup(decoded.appData, decoded.schoolSites)),
        );
      expect(checksum.finish(), 'fnv1a64-utf16le:7401c4a42a54dc73');
    },
  );
}
