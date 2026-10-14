import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/timetable_models.dart';
import '../services/import_export_service.dart';
import 'app_session.dart';

/// Builds the initial/recovery snapshot without owning the live application.
class AppDataDefaults {
  AppDataDefaults({
    required this._session,
    required this._localeCodeResolver,
    this._imports = const ImportExportService(),
  });

  final AppSession _session;
  final String Function() _localeCodeResolver;
  final ImportExportService _imports;

  Future<List<CoursePeriodTime>> loadPeriodTimes() async {
    try {
      final source = await rootBundle.loadString(defaultPeriodTimesAssetPath);
      return _imports.importPeriodTimesJson(
        source,
        localeCode: _session.data.localeCode,
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Failed to load default period times from assets: $error\n$stackTrace',
      );
      return buildDefaultPeriodTimes();
    }
  }

  Future<AppData> build() async {
    final periods = await loadPeriodTimes();
    final localeCode = _localeCodeResolver();
    return _imports.normalizeAppData(
      buildInitialAppData(periods, localeCode: localeCode),
      localeCode: localeCode,
    );
  }
}
