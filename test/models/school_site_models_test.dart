import 'package:flutter_test/flutter_test.dart';
import 'package:sked/data/migrations/app_data_migrations.dart';
import 'package:sked/models/school_site_models.dart';

void main() {
  group('SchoolSite validation', () {
    test('accepts absolute HTTP and HTTPS URLs with hosts', () {
      expect(
        const SchoolSite(
          name: 'School',
          loginUrl: 'https://school.example.edu/login',
        ).isValid,
        isTrue,
      );
      expect(
        const SchoolSite(
          name: 'School',
          loginUrl: 'http://school.example.edu/login',
        ).isValid,
        isTrue,
      );
    });

    test('rejects non-web and hostless login URLs', () {
      for (final url in [
        'javascript:alert(1)',
        'data:text/html,hello',
        'file:///etc/passwd',
        'https:///missing-host',
        '/relative/path',
      ]) {
        expect(
          SchoolSite(name: 'School', loginUrl: url).isValid,
          isFalse,
          reason: url,
        );
      }
    });

    test(
      'import preview preserves valid sites and reports every invalid item',
      () {
        final preview = decodeSchoolSitesForImport('''
[
  {"name":"Valid","loginUrl":" https://school.example.edu/login "},
  {"name":"","loginUrl":"https://school.example.edu/empty-name"},
  {"name":"Bad URL","loginUrl":"javascript:alert(1)"},
  "not-an-object"
]
''');

        expect(preview.sites, hasLength(1));
        expect(preview.sites.single.name, 'Valid');
        expect(preview.issues.map((issue) => issue.index), [1, 2, 3]);
        expect(preview.issues.map((issue) => issue.type), [
          SchoolSiteImportIssueType.missingOrInvalidName,
          SchoolSiteImportIssueType.missingOrInvalidLoginUrl,
          SchoolSiteImportIssueType.notAnObject,
        ]);
      },
    );

    test('import preview keeps an empty list as a valid replacement', () {
      final preview = decodeSchoolSitesForImport('[]');

      expect(preview.sites, isEmpty);
      expect(preview.issues, isEmpty);
    });

    test('strict decoder rejects a partially invalid stored list', () {
      expect(
        () => decodeSchoolSitesStrict('''
[
  {"name":"Valid","loginUrl":"https://school.example.edu/login"},
  {"name":"Broken","loginUrl":42}
]
'''),
        throwsFormatException,
      );
    });

    test('versioned storage snapshots round-trip without changing exports', () {
      const sites = [
        SchoolSite(
          name: 'School',
          loginUrl: 'https://school.example.edu/login',
        ),
      ];

      final storageSource = encodeSchoolSiteStorageSnapshot(sites);

      expect(decodeSchoolSitesStrict(storageSource).single.name, 'School');
      expect(
        decodeSchoolSitesStrict(encodeSchoolSites(sites)).single.name,
        'School',
      );
      expect(
        decodeSchoolSitesForImport(encodeSchoolSites(sites)).issues,
        isEmpty,
      );
      expect(
        () => decodeSchoolSitesForImport(storageSource),
        throwsFormatException,
      );
    });

    test('future storage snapshots are rejected without legacy fallback', () {
      final source =
          '''
{"schema":"$schoolSiteStorageSchema","version":${schoolSiteStorageVersion + 1},"data":{"sites":[]}}
''';

      expect(
        () => decodeSchoolSitesStrict(source),
        throwsA(isA<UnsupportedSchoolSiteStorageVersionException>()),
      );
    });

    test('does not use the AppData schema version for school-site storage', () {
      expect(appDataCurrentSchemaVersion, 2);
      expect(schoolSiteStorageVersion, 1);
      final source =
          '''
{"schema":"$schoolSiteStorageSchema","version":$appDataCurrentSchemaVersion,"data":{"sites":[]}}
''';

      expect(
        () => decodeSchoolSitesStrict(source),
        throwsA(isA<UnsupportedSchoolSiteStorageVersionException>()),
      );
    });
  });
}
