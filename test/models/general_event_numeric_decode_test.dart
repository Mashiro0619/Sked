import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/general_event.dart';
import 'package:sked/services/import_export_service.dart';

void main() {
  final decoders = <String, Object Function(num)>{
    'reminder lead': (value) =>
        GeneralEventReminder.fromJson({'minutesBefore': value}),
    'recurrence interval': (value) =>
        GeneralEventRecurrenceRule.fromJson({'interval': value}),
    'recurrence count': (value) =>
        GeneralEventRecurrenceRule.fromJson({'count': value}),
    'event color': (value) => GeneralEvent.fromJson({'colorValue': value}),
  };
  for (final entry in decoders.entries) {
    for (final value in [
      double.infinity,
      double.negativeInfinity,
      double.nan,
    ]) {
      test('${entry.key} rejects $value as a format error', () {
        expect(() => entry.value(value), throwsFormatException);
      });
    }
  }

  for (final literal in ['1e999', '-1e999']) {
    test('general schedule JSON reports $literal as invalid input', () {
      final source =
          '''{
        "schema": "general-schedule-data",
        "version": 3,
        "data": {
          "schedules": [{
            "id": "calendar", "name": "Calendar",
            "events": [{
              "id": "event", "title": "Event",
              "start": "2026-10-01T09:00:00.000",
              "end": "2026-10-01T10:00:00.000",
              "colorValue": $literal
            }]
          }]
        }
      }''';
      expect(
        () => const ImportExportService().previewImportGeneralSchedules(
          source,
          localeCode: 'en',
        ),
        throwsFormatException,
      );
    });
  }

  test('finite numbers and existing nonnumeric defaults stay compatible', () {
    final rule = GeneralEventRecurrenceRule.fromJson({
      'interval': 2.9,
      'count': 4.8,
    });
    expect(rule.interval, 2);
    expect(rule.count, 4);
    expect(
      GeneralEventReminder.fromJson({'minutesBefore': 5.9}).minutesBefore,
      5,
    );
    expect(
      GeneralEventReminder.fromJson({'minutesBefore': '5'}).minutesBefore,
      0,
    );
    expect(GeneralEvent.fromJson({'colorValue': 'invalid'}).colorValue, isNull);
  });
}
