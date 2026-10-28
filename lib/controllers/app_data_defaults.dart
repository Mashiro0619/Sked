import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/timetable_models.dart';
import '../services/data_transfer_codec.dart';
import '../services/app_version_service.dart';
import '../utils/update_version.dart';
import 'app_session.dart';

/// Builds the initial/recovery snapshot without owning the live application.
class AppDataDefaults {
  AppDataDefaults({
    required this._session,
    required this._localeCodeResolver,
    this._codec = const DataTransferCodec(),
    Future<String> Function()? appVersionLoader,
  }) : _appVersionLoader = appVersionLoader ?? loadCurrentAppVersion;

  final AppSession _session;
  final String Function() _localeCodeResolver;
  final DataTransferCodec _codec;
  final Future<String> Function() _appVersionLoader;

  Future<List<CoursePeriodTime>> loadPeriodTimes() async {
    try {
      final source = await rootBundle.loadString(defaultPeriodTimesAssetPath);
      return await _codec.decodePeriodTimes(
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
    final includePrereleaseUpdates = await _newUserPrereleaseDefault();
    return _codec.normalize(
      buildInitialAppData(
        periods,
        localeCode: localeCode,
        includePrereleaseUpdates: includePrereleaseUpdates,
        studentThemeColorMode: newUserDefaultStudentThemeColorMode,
      ),
      localeCode: localeCode,
    );
  }

  Future<bool> _newUserPrereleaseDefault() async {
    try {
      final version = normalizeUpdateVersion(
        await _appVersionLoader().timeout(const Duration(seconds: 3)),
      );
      return version.isNotEmpty && isPrereleaseUpdateVersion(version);
    } catch (_) {
      // Missing package metadata must not block first launch or opt users in.
      return false;
    }
  }
}
