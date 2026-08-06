import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/data/migrations/app_data_migrations.dart';
import 'package:sked/data/migrations/migration.dart';
import 'package:sked/models/app_data.dart';
import 'package:sked/models/app_mode.dart';
import 'package:sked/utils/constants.dart';

void main() {
  group('AppData schemaVersion', () {
    test('current schema is version 2', () {
      expect(appDataCurrentSchemaVersion, 2);
    });

    test('v1 moves legacy top-level themes into unthemed modes', () {
      final input = <String, dynamic>{
        'schemaVersion': 1,
        'activeMode': 'student',
        'studentMode': <String, dynamic>{},
        'generalMode': <String, dynamic>{},
        'themeMode': 'dark',
        'themeColorMode': themeColorModeColorful,
        'themeSeedColorValue': 0xFF00897B,
        'colorfulUiColorValues': <String, int>{
          colorfulUiPrimaryKey: 0xFF112233,
        },
      };

      final migrated = appDataMigrationRunner.run(input);

      expect(migrated['schemaVersion'], 2);
      for (final modeKey in const ['studentMode', 'generalMode']) {
        final mode = migrated[modeKey] as Map<String, dynamic>;
        expect(mode['themeMode'], 'dark');
        expect(mode['themeColorMode'], themeColorModeColorful);
        expect(mode['themeSeedColorValue'], 0xFF00897B);
        expect(mode['colorfulUiColorValues'], {
          colorfulUiPrimaryKey: 0xFF112233,
        });
      }
      for (final key in const [
        'themeMode',
        'themeColorMode',
        'themeSeedColorValue',
        'colorfulUiColorValues',
      ]) {
        expect(migrated, contains(key));
      }
      expect(
        input,
        equals({
          'schemaVersion': 1,
          'activeMode': 'student',
          'studentMode': <String, dynamic>{},
          'generalMode': <String, dynamic>{},
          'themeMode': 'dark',
          'themeColorMode': themeColorModeColorful,
          'themeSeedColorValue': 0xFF00897B,
          'colorfulUiColorValues': <String, int>{
            colorfulUiPrimaryKey: 0xFF112233,
          },
        }),
      );
    });

    test('v1 preserves mode-owned themes over legacy top-level themes', () {
      final migrated = appDataMigrationRunner.run({
        'schemaVersion': 1,
        'studentMode': <String, dynamic>{'themeMode': 'light'},
        'generalMode': <String, dynamic>{},
        'themeMode': 'dark',
        'themeColorMode': themeColorModeColorful,
        'themeSeedColorValue': 0xFF00897B,
      });

      final student = migrated['studentMode'] as Map<String, dynamic>;
      final general = migrated['generalMode'] as Map<String, dynamic>;
      expect(student, {'themeMode': 'light'});
      expect(general['themeMode'], 'dark');
      expect(general['themeColorMode'], themeColorModeColorful);
      expect(general['themeSeedColorValue'], 0xFF00897B);
    });

    test('v2 does not reapply the legacy top-level theme migration', () {
      final data = AppData.fromJson({
        'schemaVersion': 2,
        'activeMode': 'student',
        'studentMode': <String, dynamic>{
          'activeTimetableId': '',
          'timetables': <Object?>[],
          'periodTimeSets': <Object?>[],
        },
        'generalMode': <String, dynamic>{},
        'themeMode': 'dark',
      });

      expect(data.studentMode.themeMode, defaultThemeMode);
      expect(data.generalMode.themeMode, defaultThemeMode);
    });

    test('toJson always writes the current schemaVersion', () {
      final data = AppData(
        activeMode: AppMode.general,
        studentMode: AppData.fromJson(const {}).studentMode,
        generalMode: AppData.fromJson(const {}).generalMode,
      );

      final json = data.toJson();

      expect(json['schemaVersion'], equals(appDataCurrentSchemaVersion));
    });

    test('encode -> decode round-trips schemaVersion to current', () {
      final original = AppData.fromJson(const {});
      final encoded = original.encode();

      final decoded = AppData.decode(encoded);
      final reencoded = jsonDecode(decoded.encode()) as Map<String, dynamic>;

      expect(reencoded['schemaVersion'], equals(appDataCurrentSchemaVersion));
    });

    test('fromJson accepts raw maps without schemaVersion (legacy)', () {
      // No schemaVersion -> treated as v1 by runner -> still upgrades cleanly.
      final json = <String, dynamic>{'activeMode': 'general'};

      // Should not throw.
      final data = AppData.fromJson(json);

      expect(data.activeMode, equals(AppMode.general));
    });

    test('fromJson throws MigrationException for future schemaVersion', () {
      final json = <String, dynamic>{
        'schemaVersion': appDataCurrentSchemaVersion + 99,
      };

      expect(() => AppData.fromJson(json), throwsA(isA<MigrationException>()));
    });

    test('fromJson rejects future schemaVersion encoded as a string', () {
      final json = <String, dynamic>{
        'schemaVersion': '${appDataCurrentSchemaVersion + 99}',
      };

      expect(() => AppData.fromJson(json), throwsA(isA<MigrationException>()));
    });

    test('fromJson rejects malformed schemaVersion values', () {
      for (final value in ['future', '1.0', 1.5, 0, -1, null]) {
        expect(
          () => AppData.fromJson({'schemaVersion': value}),
          throwsA(isA<MigrationException>()),
        );
      }
    });

    test('import/export envelopes reject non-positive versions', () {
      for (final value in [0, -1]) {
        expect(
          () => ImportExportEnvelope.fromJson({
            'schema': appDataSchema,
            'version': value,
            'data': <String, dynamic>{},
          }),
          throwsA(isA<FormatException>()),
        );
      }
    });

    test('decode runs migrations before constructing AppData', () {
      // Synthesize a JSON document at the current schemaVersion.
      final source = jsonEncode({
        'schemaVersion': appDataCurrentSchemaVersion,
        'activeMode': 'student',
      });

      final data = AppData.decode(source);

      expect(data.activeMode, equals(AppMode.student));
    });
  });
}
