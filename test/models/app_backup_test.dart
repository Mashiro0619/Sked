import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/school_site_models.dart';
import 'package:sked/models/timetable_models.dart';

void main() {
  AppData appData({String localeCode = 'en'}) =>
      buildInitialAppData(buildDefaultPeriodTimes(), localeCode: localeCode);

  const sites = [
    SchoolSite(name: 'Example University', loginUrl: 'https://example.test'),
  ];

  test('round-trips app data and school sites without API keys', () {
    final data = appData(localeCode: 'zh').copyWith(
      studentMode: appData().studentMode.copyWith(
        schoolImportParserSettings: const SchoolImportParserSettings(
          customBaseUrl: 'https://api.example.test/v1',
          customApiKey: 'sk-secret',
          customModel: 'model-a',
        ),
      ),
    );

    final source = encodeAppBackup(data, sites);
    final decoded = decodeAppBackup(source);

    expect(source, isNot(contains('sk-secret')));
    expect(decoded.includesSchoolSites, isTrue);
    expect(decoded.appData.localeCode, 'zh');
    expect(decoded.schoolSites.single.name, 'Example University');
    expect(
      decoded.appData.studentMode.schoolImportParserSettings.customApiKey,
      isEmpty,
    );
  });

  test('accepts legacy app-data backups without claiming school sites', () {
    final decoded = decodeAppBackup(encodeAppDataEnvelope(appData()));

    expect(decoded.includesSchoolSites, isFalse);
    expect(decoded.schoolSites, isEmpty);
  });

  test('accepts each historical app-data schema alias', () {
    for (final schema in const [
      'classmate-app-data',
      'KeSchedule-app-data',
      'Sked-app-data',
    ]) {
      final source = ImportExportEnvelope(
        schema: schema,
        version: importExportVersion,
        data: appData().toJson(),
      ).encode();

      final decoded = decodeAppBackup(source);

      expect(decoded.includesSchoolSites, isFalse, reason: schema);
      expect(decoded.schoolSites, isEmpty, reason: schema);
    }
  });

  test('rejects a composite backup containing one malformed school site', () {
    final source = jsonEncode({
      'schema': appBackupSchema,
      'version': appBackupVersion,
      'data': {
        'appData': appData().toJson(),
        'schoolSites': [
          sites.single.toJson(),
          {'name': 42, 'loginUrl': 'https://invalid.test'},
        ],
      },
    });

    expect(() => decodeAppBackup(source), throwsFormatException);
  });

  test('rejects malformed nested app data before returning school sites', () {
    final source = jsonEncode({
      'schema': appBackupSchema,
      'version': appBackupVersion,
      'data': {
        'appData': {
          ...appData().toJson(),
          'studentMode': {
            ...appData().studentMode.toJson(),
            'timetables': [
              {'id': 'broken', 'config': 'not-an-object', 'courses': []},
            ],
          },
        },
        'schoolSites': sites.map((site) => site.toJson()).toList(),
      },
    });

    expect(() => decodeAppBackup(source), throwsFormatException);
  });

  test('rejects arbitrary schema suffixes', () {
    final source = ImportExportEnvelope(
      schema: 'attacker-$appBackupSchema',
      version: appBackupVersion,
      data: {
        'appData': appData().toJson(),
        'schoolSites': sites.map((site) => site.toJson()).toList(),
      },
    ).encode();

    expect(() => decodeAppBackup(source), throwsFormatException);
  });

  test('rejects invented brand aliases for composite backups', () {
    final source = ImportExportEnvelope(
      schema: 'Sked-$appBackupSchema',
      version: appBackupVersion,
      data: {
        'appData': appData().toJson(),
        'schoolSites': sites.map((site) => site.toJson()).toList(),
      },
    ).encode();

    expect(() => decodeAppBackup(source), throwsFormatException);
  });
}
