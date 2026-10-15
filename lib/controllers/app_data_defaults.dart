import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/timetable_models.dart';
import '../services/data_transfer_codec.dart';
import 'app_session.dart';

/// Builds the initial/recovery snapshot without owning the live application.
class AppDataDefaults {
  AppDataDefaults({
    required this._session,
    required this._localeCodeResolver,
    this._codec = const DataTransferCodec(),
  });

  final AppSession _session;
  final String Function() _localeCodeResolver;
  final DataTransferCodec _codec;

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
    return _codec.normalize(
      buildInitialAppData(periods, localeCode: localeCode),
      localeCode: localeCode,
    );
  }
}
