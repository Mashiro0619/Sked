import 'dart:convert';

const schoolSiteStorageSchema = 'school-site-storage';
const schoolSiteStorageVersion = 1;

class UnsupportedSchoolSiteStorageVersionException implements Exception {
  const UnsupportedSchoolSiteStorageVersionException(this.version);

  final int version;

  @override
  String toString() => 'School-site storage version $version is not supported.';
}

Map<String, dynamic> _asStringKeyedMap(Object? value) {
  if (value is! Map) {
    return const <String, dynamic>{};
  }
  final result = <String, dynamic>{};
  for (final entry in value.entries) {
    final key = entry.key;
    if (key is String) {
      result[key] = entry.value;
    }
  }
  return result;
}

String _stringValue(Object? value) {
  return value is String ? value : '';
}

class SchoolSite {
  const SchoolSite({required this.name, required this.loginUrl});

  final String name;
  final String loginUrl;

  factory SchoolSite.fromJson(Map<String, dynamic> json) {
    return SchoolSite(
      name: _stringValue(json['name']).trim(),
      loginUrl: _stringValue(json['loginUrl']).trim(),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name.trim(),
    'loginUrl': loginUrl.trim(),
  };

  SchoolSite copyWith({String? name, String? loginUrl}) {
    return SchoolSite(
      name: name ?? this.name,
      loginUrl: loginUrl ?? this.loginUrl,
    );
  }

  bool get isValid {
    final uri = Uri.tryParse(loginUrl.trim());
    return name.trim().isNotEmpty &&
        uri != null &&
        uri.hasScheme &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.trim().isNotEmpty;
  }
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

SchoolSiteImportPreview decodeSchoolSitesForImport(String source) {
  final decoded = jsonDecode(source);
  if (decoded is! List) {
    throw const FormatException('School site JSON format is invalid.');
  }

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
    final item = _asStringKeyedMap(value);
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
    sites: List.unmodifiable(sites),
    issues: List.unmodifiable(issues),
  );
}

List<SchoolSite> decodeSchoolSitesStrict(String source) {
  final decoded = jsonDecode(source);
  if (decoded is Map) {
    final envelope = _asStringKeyedMap(decoded);
    if (envelope['schema'] == schoolSiteStorageSchema) {
      final version = envelope['version'];
      if (version is! int) {
        throw const FormatException('School site storage version is invalid.');
      }
      if (version > schoolSiteStorageVersion) {
        throw UnsupportedSchoolSiteStorageVersionException(version);
      }
      if (version != schoolSiteStorageVersion) {
        throw FormatException(
          'School site storage version $version is not supported.',
        );
      }
      final rawData = envelope['data'];
      final data = _asStringKeyedMap(rawData);
      if (rawData is! Map || data['sites'] is! List) {
        throw const FormatException('School site storage data is invalid.');
      }
      return _decodeSchoolSiteListStrict(data['sites']);
    }
  }
  return _decodeSchoolSiteListStrict(decoded);
}

List<SchoolSite> _decodeSchoolSiteListStrict(Object? decoded) {
  if (decoded is! List) {
    throw const FormatException('School site JSON format is invalid.');
  }
  final sites = <SchoolSite>[];
  for (var index = 0; index < decoded.length; index += 1) {
    final value = decoded[index];
    final item = _asStringKeyedMap(value);
    if (value is! Map ||
        item['name'] is! String ||
        item['loginUrl'] is! String) {
      throw FormatException('School site entry $index is invalid.');
    }
    final site = SchoolSite.fromJson(item);
    if (!site.isValid) {
      throw FormatException('School site entry $index is invalid.');
    }
    sites.add(site);
  }
  return sites;
}

String encodeSchoolSites(List<SchoolSite> sites) {
  return const JsonEncoder.withIndent('  ')
      .convert(sites.map((item) => item.toJson()).toList());
}

String encodeSchoolSiteStorageSnapshot(List<SchoolSite> sites) {
  return const JsonEncoder.withIndent('  ').convert({
    'schema': schoolSiteStorageSchema,
    'version': schoolSiteStorageVersion,
    'data': {'sites': sites.map((item) => item.toJson()).toList()},
  });
}
