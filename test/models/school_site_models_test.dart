import 'dart:convert';

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

    test(
      'versioned snapshots and portable exports preserve stable identities',
      () {
        const sites = [
          SchoolSite(
            id: 'school-fixture',
            name: 'School',
            loginUrl: 'https://school.example.edu/login',
          ),
        ];

        final storageSource = encodeSchoolSiteStorageSnapshot(sites);

        expect(decodeSchoolSitesStrict(storageSource).single.name, 'School');
        expect(
          decodeSchoolSitesStrict(storageSource).single.id,
          'school-fixture',
        );
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
      },
    );

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
      expect(schoolSiteStorageVersion, 2);
      expect(
        appDataCurrentSchemaVersion,
        greaterThan(schoolSiteStorageVersion),
      );
      final source =
          '''
{"schema":"$schoolSiteStorageSchema","version":$appDataCurrentSchemaVersion,"data":{"sites":[]}}
''';

      expect(
        () => decodeSchoolSitesStrict(source),
        throwsA(isA<UnsupportedSchoolSiteStorageVersionException>()),
      );
    });

    test('legacy lists and v1 decode without inventing durable identity', () {
      final legacy = [
        {'name': 'Same', 'loginUrl': 'https://same.test'},
        {'name': 'Same', 'loginUrl': 'https://same.test'},
      ];
      for (final source in [
        jsonEncode(legacy),
        jsonEncode({
          'schema': schoolSiteStorageSchema,
          'version': 1,
          'data': {'sites': legacy},
        }),
      ]) {
        final decoded = decodeSchoolSiteStorageSnapshot(source);
        expect(decoded.needsIdentityMigration, isTrue);
        expect(decoded.sites.map((site) => site.id), ['', '']);
        final identified = assignSchoolSiteIdentities(decoded.sites);
        expect(identified.map((site) => site.id).toSet(), hasLength(2));
        expect(identified.every((site) => validSchoolSiteId(site.id)), isTrue);
        final stored = encodeSchoolSiteStorageSnapshot(identified);
        expect(
          decodeSchoolSiteStorageSnapshot(stored).needsIdentityMigration,
          isFalse,
        );
        expect(
          decodeSchoolSitesStrict(stored).map((site) => site.id),
          identified.map((site) => site.id),
        );
      }
    });

    test('renaming preserves identity while creating and copying allocate independent IDs', () {
      final site = SchoolSite.create(
        name: 'Campus',
        loginUrl: 'https://old.test',
      );
      final edited = site.copyWith(
        name: 'Renamed',
        loginUrl: 'https://new.test',
      );
      final copy = edited.duplicate();
      expect(edited.id, site.id);
      expect(copy.id, isNot(edited.id));
      expect(copy.name, edited.name);
      expect(copy.loginUrl, edited.loginUrl);
      expect(SchoolSite.fromJson(edited.toJson()).id, site.id);
    });

    test(
      'v2 requires unique IDs and malformed supplied identities are rejected',
      () {
        final site = const SchoolSite(
          id: 'stable',
          name: 'Campus',
          loginUrl: 'https://campus.test',
        ).toJson();
        for (final entries in [
          [Map<String, dynamic>.of(site)..remove('id')],
          [site, site],
          [
            for (final value in ['', null, 42, '../path', ' has-space '])
              {...site, 'id': value},
          ],
        ]) {
          expect(
            () => decodeSchoolSitesStrict(
              jsonEncode({
                'schema': schoolSiteStorageSchema,
                'version': 2,
                'data': {'sites': entries},
              }),
            ),
            throwsFormatException,
          );
        }
        expect(
          () => decodeSchoolSitesForImport(jsonEncode([site, site])),
          throwsFormatException,
        );
      },
    );

    test('append preserves duplicate content while copying colliding IDs', () {
      const site = SchoolSite(
        id: 'existing',
        name: 'Campus',
        loginUrl: 'https://campus.test',
      );
      expect(
        () => assignSchoolSiteIdentities([site], occupiedIds: {'existing'}),
        throwsFormatException,
      );
      final copies = assignSchoolSiteIdentities(
        [site],
        occupiedIds: {'existing'},
        copyConflicts: true,
        idGenerator: () => 'imported-copy',
      );
      expect(copies.single.id, 'imported-copy');
      expect(copies.single.name, site.name);
      expect(copies.single.loginUrl, site.loginUrl);
      final imported = decodeSchoolSitesForImport(encodeSchoolSites([site]));
      expect(imported.sites.single.id, site.id);
    });

    test('built-in content must carry explicit stable identities', () {
      expect(
        () => decodeSchoolSitesStrict(
          '[{"name":"Campus","loginUrl":"https://campus.test"}]',
          requireStableIds: true,
        ),
        throwsFormatException,
      );
      final sites = decodeSchoolSitesStrict(
        '[{"id":"builtin-campus","name":"Campus","loginUrl":"https://campus.test"}]',
        requireStableIds: true,
      );
      expect(sites.single.id, 'builtin-campus');
    });
  });
}
