import 'package:package_info_plus/package_info_plus.dart';
import 'package:sked/models/timetable_models.dart';

const _privacyVersion = '2026-08-07';
const _privacyAcceptedAt = '2026-08-07T00:00:00.000Z';

/// UI-only setup; shared data-operation fixtures retain their original bytes.
/// These fixed metadata values let the actual AppHomeScreen show a ready shell.
/// Event/course records, selections, preferences and production codecs remain
/// unchanged. Both UI suites prepare this data before mounting or timing work.
AppData prepareUiPerformanceData(AppData source) => source.copyWith(
  privacyPolicyAcceptedVersion: _privacyVersion,
  privacyPolicyAcceptedAtIso: _privacyAcceptedAt,
);

/// SettingsPage is opened by the real AppHomeScreen route. Seed the package's
/// public test cache so its default loader retains the old isolated metadata
/// boundary without replacing either production screen or its callbacks.
void prepareUiPerformanceHost() {
  // This library belongs to the benchmark target, not the shipped application.
  // ignore: invalid_use_of_visible_for_testing_member
  PackageInfo.setMockInitialValues(
    appName: 'Sked',
    packageName: 'com.mashiro.sked.ui_performance',
    version: '2.3.0',
    buildNumber: '0',
    buildSignature: '',
    installerStore: '',
  );
}

const uiPerformanceHostProtocol = <String, Object>{
  'setupVersion': 1,
  'root': 'production AppHomeScreen',
  'privacyPolicyAcceptedVersion': _privacyVersion,
  'privacyPolicyAcceptedAtIso': _privacyAcceptedAt,
  'packageMetadata': 'isolated PackageInfo cache; Sked/2.3.0/0',
  'startupUpdates': 'no UpdatePromptScope; production early return',
  'notifications': 'disabled memory gateway and runtime store',
  'preparation':
      'package metadata and UI-only privacy seed before measured work',
};
