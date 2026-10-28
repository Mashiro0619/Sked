import 'app_data_json_values.dart';

import 'dart:convert';

import '../l10n/app_locale.dart';
import '../utils/constants.dart';
import '../utils/localized_names.dart';
import 'app_data.dart';
import 'import_count_limits.dart';
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
}) => _decodeAppBackup(source, localeCode: localeCode, externalImport: true);

/// Reads an already admitted local restore target. New external imports must
/// use [decodeAppBackup], so an older or larger local journal remains readable.
AppBackupData decodeAppBackupForRecovery(
  String source, {
  String localeCode = defaultLocaleCode,
}) => _decodeAppBackup(source, localeCode: localeCode, externalImport: false);

AppBackupData _decodeAppBackup(
  String source, {
  required String localeCode,
  required bool externalImport,
}) {
  final envelope = ImportExportEnvelope.decode(source);
  if (isImportExportSchema(envelope.schema, appBackupSchema)) {
    if (envelope.version > appBackupVersion) {
      throw FormatException(
        importFileVersionUnsupportedMessage(localeCode: localeCode),
      );
    }
    if (externalImport) {
      validateImportCounts(
        envelope.data,
        kind: ImportCountKind.backup,
        localeCode: localeCode,
      );
    }
    final rawAppData = appDataStrictStringKeyedMap(envelope.data['appData']);
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
    if (externalImport) {
      validateImportCounts(
        envelope.data,
        kind: ImportCountKind.appData,
        localeCode: localeCode,
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
