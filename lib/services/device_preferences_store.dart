import 'package:flutter/foundation.dart';

import 'desktop_layout_preferences.dart';
import 'developer_ui_preferences.dart';
import 'device_preferences_models.dart';

export 'device_preferences_models.dart';

/// One binding to the live presentation owners, also available before a UI is
/// mounted so startup recovery can verify the same persisted groups.
class DevicePreferencesStore {
  DevicePreferencesStore({
    DesktopLayoutPreferences? layout,
    DeveloperUiPreferences? developerUi,
    DevicePreferencePlatform? platform,
  }) : _layout = layout ?? DesktopLayoutPreferences(),
       _developerUi = developerUi ?? DeveloperUiPreferences(),
       _ownsLayout = layout == null,
       _ownsDeveloperUi = developerUi == null,
       platform = platform ?? currentDevicePreferencePlatform();

  factory DevicePreferencesStore.memory({DevicePreferencePlatform? platform}) =>
      DevicePreferencesStore(
          layout: DesktopLayoutPreferences.memory(),
          developerUi: DeveloperUiPreferences.memory(),
          platform: platform,
        )
        .._ownsLayout = true
        .._ownsDeveloperUi = true;

  final DevicePreferencePlatform platform;
  DesktopLayoutPreferences _layout;
  DeveloperUiPreferences _developerUi;
  bool _ownsLayout;
  bool _ownsDeveloperUi;
  bool _frozen = false;
  bool _disposed = false;
  DesktopLayoutPreferences get layout => _layout;
  DeveloperUiPreferences get developerUi => _developerUi;
  bool get isFrozen => _frozen;

  /// Bootstrap binds before loading application data. The UI keeps ownership
  /// of its services; this store never constructs a second native owner.
  void bindServices({
    required DesktopLayoutPreferences layout,
    required DeveloperUiPreferences developerUi,
  }) {
    if (identical(_layout, layout) && identical(_developerUi, developerUi)) {
      return;
    }
    if (_disposed || _frozen) throw StateError('Device preferences are in use');
    if (!identical(_layout, layout)) {
      if (_ownsLayout) _layout.dispose();
      _layout = layout;
      _ownsLayout = false;
    }
    if (!identical(_developerUi, developerUi)) {
      if (_ownsDeveloperUi) _developerUi.dispose();
      _developerUi = developerUi;
      _ownsDeveloperUi = false;
    }
  }

  Future<Map<DevicePreferenceGroup, Map<String, Object?>>> readAll() async {
    if (_disposed) throw StateError('Device preferences are unavailable');
    if (!_frozen && !await _layout.flush()) {
      throw StateError('Device layout has an unconfirmed save');
    }
    return {
      for (final group in DevicePreferenceGroup.values)
        group: await readGroup(group),
    };
  }

  Future<Map<String, Object?>> readGroup(DevicePreferenceGroup group) {
    if (_disposed) throw StateError('Device preferences are unavailable');
    return switch (group) {
      DevicePreferenceGroup.desktopLayout => _layout.readBackupSnapshot(),
      DevicePreferenceGroup.developerUi => _developerUi.readBackupSnapshot(),
    };
  }

  Future<void> freezeAndDrain() async {
    if (_disposed) throw StateError('Device preferences are unavailable');
    _frozen = true;
    // Invoke both before awaiting either one: new UI intent must be blocked
    // for both stores throughout the drain, including a stalled older save.
    await Future.wait([
      _layout.freezeAndDrainForRestore(),
      _developerUi.freezeAndDrainForRestore(),
    ]);
  }

  Future<void> restoreGroup(
    DevicePreferenceGroup group,
    Map<String, Object?> target, {
    required void Function() validateOwner,
  }) {
    validateOwner();
    if (!_frozen || _disposed) {
      throw StateError('Device restore has no ownership');
    }
    return switch (group) {
      DevicePreferenceGroup.desktopLayout => _layout.restoreBackupSnapshot(
        target,
        validateOwner: validateOwner,
      ),
      DevicePreferenceGroup.developerUi => _developerUi.restoreBackupSnapshot(
        target,
        validateOwner: validateOwner,
      ),
    };
  }

  void resume() {
    if (_disposed) return;
    _layout.resumeAfterBackupRestore();
    _developerUi.resumeAfterBackupRestore();
    _frozen = false;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (_ownsLayout) _layout.dispose();
    if (_ownsDeveloperUi) _developerUi.dispose();
  }
}

DevicePreferencePlatform currentDevicePreferencePlatform() {
  if (kIsWeb) return DevicePreferencePlatform.web;
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => DevicePreferencePlatform.android,
    TargetPlatform.iOS => DevicePreferencePlatform.ios,
    TargetPlatform.windows => DevicePreferencePlatform.windows,
    TargetPlatform.macOS => DevicePreferencePlatform.macos,
    TargetPlatform.linux => DevicePreferencePlatform.linux,
    TargetPlatform.fuchsia => DevicePreferencePlatform.fuchsia,
  };
}
