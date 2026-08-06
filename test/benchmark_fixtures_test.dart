import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/general_event_occurrence.dart';
import 'package:sked/services/general_occurrence_service.dart';
import 'package:sked/services/school_import_content_sanitizer.dart';

import '../benchmark/src/benchmark_fixtures.dart';
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
}
