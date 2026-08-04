import 'dart:convert';

import '../l10n/app_locale.dart';
import '../utils/constants.dart';
import '../utils/localized_names.dart';
import 'app_data.dart';
import 'school_site_models.dart';

class AppBackupData {
  const AppBackupData({
    required this.appData,
    required this.schoolSites,
    required this.includesSchoolSites,
  });

  final AppData appData;
  final List<SchoolSite> schoolSites;
  final bool includesSchoolSites;
}

String encodeAppBackup(AppData appData, List<SchoolSite> schoolSites) {
  return ImportExportEnvelope(
    schema: appBackupSchema,
    version: appBackupVersion,
    data: {
      'appData': appData.toJson(),
      'schoolSites': schoolSites.map((site) => site.toJson()).toList(),
    },
  ).encode();
}

AppBackupData decodeAppBackup(
  String source, {
  String localeCode = defaultLocaleCode,
}) {
  final envelope = ImportExportEnvelope.decode(source);
  if (isImportExportSchema(envelope.schema, appBackupSchema)) {
    if (envelope.version > appBackupVersion) {
      throw FormatException(
        importFileVersionUnsupportedMessage(localeCode: localeCode),
      );
    }
    final rawAppData = _stringKeyedMap(envelope.data['appData']);
    final rawSchoolSites = envelope.data['schoolSites'];
    if (rawAppData == null || rawSchoolSites is! List) {
      throw const FormatException('App backup format is invalid.');
    }
    return AppBackupData(
      appData: AppData.decodeStorageSnapshot(jsonEncode(rawAppData)),
      schoolSites: decodeSchoolSitesStrict(jsonEncode(rawSchoolSites)),
      includesSchoolSites: true,
    );
  }

  if (isImportExportSchema(envelope.schema, appDataSchema)) {
    if (envelope.version > importExportVersion) {
      throw FormatException(
        importFileVersionUnsupportedMessage(localeCode: localeCode),
      );
    }
    return AppBackupData(
      appData: AppData.decodeStorageSnapshot(jsonEncode(envelope.data)),
      schoolSites: const [],
      includesSchoolSites: false,
    );
  }

  throw FormatException(importFileTypeMismatchMessage(localeCode: localeCode));
}

Map<String, dynamic>? _stringKeyedMap(Object? value) {
  if (value is! Map) {
    return null;
  }
  final result = <String, dynamic>{};
  for (final entry in value.entries) {
    if (entry.key is! String) {
      return null;
    }
    result[entry.key as String] = entry.value;
  }
  return result;
}
