import 'app_data_json_values.dart';

import 'dart:convert';

import '../l10n/app_locale.dart';
import '../utils/unique_id.dart';
import 'import_count_limits.dart';

const schoolSiteStorageSchema = 'school-site-storage';
const schoolSiteStorageVersion = 2;

class UnsupportedSchoolSiteStorageVersionException implements Exception {
  const UnsupportedSchoolSiteStorageVersionException(this.version);

  final int version;

  @override
  String toString() => 'School-site storage version $version is not supported.';
}

class SchoolSite {
  const SchoolSite({this.id = '', required this.name, required this.loginUrl});

  /// An empty ID is an unpersisted legacy value, never a restore target.
  final String id;

  final String name;
  final String loginUrl;

  factory SchoolSite.create({required String name, required String loginUrl}) =>
      SchoolSite(id: generateUuidV4(), name: name, loginUrl: loginUrl);

  factory SchoolSite.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    if (json.containsKey('id') &&
        (rawId is! String || !validSchoolSiteId(rawId))) {
      throw const FormatException('School site ID is invalid.');
    }
    return SchoolSite(
      id: rawId as String? ?? '',
      name: appDataStringValue(json['name']).trim(),
      loginUrl: appDataStringValue(json['loginUrl']).trim(),
    );
  }

  Map<String, dynamic> toJson() => {
    if (id.isNotEmpty) 'id': id,
    'name': name.trim(),
    'loginUrl': loginUrl.trim(),
  };

  SchoolSite copyWith({String? id, String? name, String? loginUrl}) {
    return SchoolSite(
      id: id ?? this.id,
      name: name ?? this.name,
      loginUrl: loginUrl ?? this.loginUrl,
    );
  }

  /// Copying is a new object even when its name and URL remain identical.
  SchoolSite duplicate() => copyWith(id: generateUuidV4());

  bool get isValid {
    final uri = Uri.tryParse(loginUrl.trim());
    return (id.isEmpty || validSchoolSiteId(id)) &&
        name.trim().isNotEmpty &&
        uri != null &&
        uri.hasScheme &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.trim().isNotEmpty;
  }
}

bool validSchoolSiteId(String value) =>
    RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$').hasMatch(value);

/// Resolves legacy objects once at a concrete import/write boundary. Callers
/// must retain this result through retries; a name or URL is never identity.
List<SchoolSite> assignSchoolSiteIdentities(
  List<SchoolSite> sites, {
  Set<String> occupiedIds = const {},
  bool copyConflicts = false,
  String Function()? idGenerator,
}) {
  final generate = idGenerator ?? generateUuidV4;
  final used = {...occupiedIds};
  final reserved = {
    ...occupiedIds,
    for (final site in sites)
      if (site.id.isNotEmpty) site.id,
  };
  final result = <SchoolSite>[];
  for (final site in sites) {
    if (!site.isValid) {
      throw const FormatException('School site is invalid.');
    }
    var id = site.id;
    if (id.isNotEmpty && used.contains(id) && !copyConflicts) {
      throw const FormatException('School site IDs must be unique.');
    }
    if (id.isEmpty || used.contains(id)) {
      var assigned = false;
      for (var attempt = 0; attempt < 32; attempt++) {
        final candidate = generate();
        if (!validSchoolSiteId(candidate)) {
          throw const FormatException('Generated school site ID is invalid.');
        }
        if (reserved.add(candidate)) {
          id = candidate;
          assigned = true;
          break;
        }
      }
      if (!assigned) {
        throw const FormatException('Could not allocate a school site ID.');
      }
    }
    used.add(id);
    result.add(id == site.id ? site : site.copyWith(id: id));
  }
  return List.unmodifiable(result);
}

enum SchoolSiteImportIssueType {
  notAnObject,
  missingOrInvalidName,
  missingOrInvalidLoginUrl,
}

class SchoolSiteImportIssue {
  const SchoolSiteImportIssue({required this.index, required this.type});

  final int index;
  final SchoolSiteImportIssueType type;
}

class SchoolSiteImportPreview {
  const SchoolSiteImportPreview({required this.sites, required this.issues});

  final List<SchoolSite> sites;
  final List<SchoolSiteImportIssue> issues;
}

SchoolSiteImportPreview decodeSchoolSitesForImport(
  String source, {
  String localeCode = defaultLocaleCode,
}) {
  final decoded = jsonDecode(source);
  if (decoded is! List) {
    throw const FormatException('School site JSON format is invalid.');
  }
  validateImportCounts(
    decoded,
    kind: ImportCountKind.schoolSites,
    localeCode: localeCode,
  );

  final sites = <SchoolSite>[];
  final issues = <SchoolSiteImportIssue>[];
  for (var index = 0; index < decoded.length; index += 1) {
    final value = decoded[index];
    if (value is! Map) {
      issues.add(
        SchoolSiteImportIssue(
          index: index,
          type: SchoolSiteImportIssueType.notAnObject,
        ),
      );
      continue;
    }
    final item = appDataStringKeyedMapOrEmpty(value);
    final name = item['name'];
    if (name is! String || name.trim().isEmpty) {
      issues.add(
        SchoolSiteImportIssue(
          index: index,
          type: SchoolSiteImportIssueType.missingOrInvalidName,
        ),
      );
      continue;
    }
    final loginUrl = item['loginUrl'];
    if (loginUrl is! String) {
      issues.add(
        SchoolSiteImportIssue(
          index: index,
          type: SchoolSiteImportIssueType.missingOrInvalidLoginUrl,
        ),
      );
      continue;
    }
    final site = SchoolSite.fromJson(item);
    if (!site.isValid) {
      issues.add(
        SchoolSiteImportIssue(
          index: index,
          type: SchoolSiteImportIssueType.missingOrInvalidLoginUrl,
        ),
      );
      continue;
    }
    sites.add(site);
  }

  return SchoolSiteImportPreview(
    sites: assignSchoolSiteIdentities(sites),
    issues: List.unmodifiable(issues),
  );
}

List<SchoolSite> decodeSchoolSitesStrict(
  String source, {
  bool requireStableIds = false,
}) => decodeSchoolSiteStorageSnapshot(
  source,
  requireStableIds: requireStableIds,
).sites;

({List<SchoolSite> sites, bool needsIdentityMigration})
decodeSchoolSiteStorageSnapshot(
  String source, {
  bool requireStableIds = false,
}) {
  final decoded = jsonDecode(source);
  if (decoded is Map) {
    final envelope = appDataStringKeyedMapOrEmpty(decoded);
    if (envelope['schema'] == schoolSiteStorageSchema) {
      final version = envelope['version'];
      if (version is! int) {
        throw const FormatException('School site storage version is invalid.');
      }
      if (version > schoolSiteStorageVersion) {
        throw UnsupportedSchoolSiteStorageVersionException(version);
      }
      if (version != 1 && version != schoolSiteStorageVersion) {
        throw FormatException(
          'School site storage version $version is not supported.',
        );
      }
      final rawData = envelope['data'];
      final data = appDataStringKeyedMapOrEmpty(rawData);
      if (rawData is! Map || data['sites'] is! List) {
        throw const FormatException('School site storage data is invalid.');
      }
      final sites = _decodeSchoolSiteListStrict(
        data['sites'],
        requireStableIds: requireStableIds || version >= 2,
      );
      return (
        sites: sites,
        needsIdentityMigration: sites.isNotEmpty && version < 2,
      );
    }
  }
  final sites = _decodeSchoolSiteListStrict(
    decoded,
    requireStableIds: requireStableIds,
  );
  return (sites: sites, needsIdentityMigration: sites.isNotEmpty);
}

List<SchoolSite> _decodeSchoolSiteListStrict(
  Object? decoded, {
  required bool requireStableIds,
}) {
  if (decoded is! List) {
    throw const FormatException('School site JSON format is invalid.');
  }
  final sites = <SchoolSite>[];
  final ids = <String>{};
  for (var index = 0; index < decoded.length; index += 1) {
    final value = decoded[index];
    final item = appDataStringKeyedMapOrEmpty(value);
    if (value is! Map ||
        item['name'] is! String ||
        item['loginUrl'] is! String) {
      throw FormatException('School site entry $index is invalid.');
    }
    final site = SchoolSite.fromJson(item);
    if (!site.isValid ||
        (requireStableIds && site.id.isEmpty) ||
        (site.id.isNotEmpty && !ids.add(site.id))) {
      throw FormatException('School site entry $index is invalid.');
    }
    sites.add(site);
  }
  return sites;
}

String encodeSchoolSites(List<SchoolSite> sites) {
  return const JsonEncoder.withIndent('  ').convert(
    assignSchoolSiteIdentities(sites).map((item) => item.toJson()).toList(),
  );
}

String encodeSchoolSiteStorageSnapshot(List<SchoolSite> sites) {
  return const JsonEncoder.withIndent('  ').convert({
    'schema': schoolSiteStorageSchema,
    'version': schoolSiteStorageVersion,
    'data': {
      'sites': assignSchoolSiteIdentities(sites)
          .map((item) => item.toJson())
          .toList(),
    },
  });
}
