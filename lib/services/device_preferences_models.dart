/// Portable device choices are identified by platform. They never contain
/// native permissions, window handles, credentials, or runtime state.
enum DevicePreferencePlatform {
  android,
  ios,
  windows,
  macos,
  linux,
  web,
  fuchsia,
}

enum DevicePreferenceGroup { desktopLayout, developerUi }

String devicePreferencePlatformLabel(DevicePreferencePlatform platform) =>
    switch (platform) {
      DevicePreferencePlatform.android => 'Android',
      DevicePreferencePlatform.ios => 'iOS',
      DevicePreferencePlatform.windows => 'Windows',
      DevicePreferencePlatform.macos => 'macOS',
      DevicePreferencePlatform.linux => 'Linux',
      DevicePreferencePlatform.web => 'Web',
      DevicePreferencePlatform.fuchsia => 'Fuchsia',
    };

/// Stable presentation roles. Keep this set in sync with DesktopLayoutRegion;
/// accepting a future role would silently discard part of a selected group.
const deviceLayoutRegionNames = {
  'resources',
  'settingsNavigation',
  'periodTimeSets',
  'schoolSites',
  'importPreview',
  'themePreview',
  'monthAgenda',
  'monthAgendaBottom',
  'allDayTimeline',
  'courseEditor',
  'timetableEditor',
  'eventEditor',
  'courseDetails',
  'eventDetails',
  'reminderList',
  'dayAgenda',
  'occurrenceList',
  'calendarManager',
  'categoryManager',
  'categoryNameEditor',
  'assistant',
};

Map<String, Object?> validateDevicePreferenceValues(
  DevicePreferenceGroup group,
  Object? value,
) {
  final values = _fields(value, switch (group) {
    DevicePreferenceGroup.desktopLayout => {'regions'},
    DevicePreferenceGroup.developerUi => {'assistantPreviewEnabled'},
  });
  switch (group) {
    case DevicePreferenceGroup.desktopLayout:
      final raw = values['regions'];
      if (raw is! Map ||
          raw.keys.any((key) => !deviceLayoutRegionNames.contains(key))) {
        throw const FormatException('Unknown device layout region.');
      }
      final regions = <String, Object?>{};
      for (final entry in raw.entries) {
        if (entry.value is! Map || (entry.value as Map).isEmpty) {
          throw const FormatException('Invalid device layout dimensions.');
        }
        final dimensions = entry.value as Map;
        final result = <String, Object?>{};
        for (final dimension in dimensions.entries) {
          final number = dimension.value;
          if (!const {
                'width',
                'height',
                'dockedWidth',
              }.contains(dimension.key) ||
              number is! num ||
              !number.isFinite ||
              number <= 0) {
            throw const FormatException('Invalid device layout dimension.');
          }
          result[dimension.key as String] = number.toDouble();
        }
        regions[entry.key as String] = Map<String, Object?>.unmodifiable(
          result,
        );
      }
      return Map.unmodifiable({
        'regions': Map<String, Object?>.unmodifiable(regions),
      });
    case DevicePreferenceGroup.developerUi:
      final enabled = values['assistantPreviewEnabled'];
      if (enabled != null && enabled is! bool) {
        throw const FormatException('Invalid developer preview preference.');
      }
      return Map.unmodifiable({'assistantPreviewEnabled': enabled});
  }
}

class PortableDevicePreferences {
  PortableDevicePreferences({
    required this.platform,
    required this.group,
    required Object? values,
  }) : values = validateDevicePreferenceValues(group, values);

  static const version = 1;
  final DevicePreferencePlatform platform;
  final DevicePreferenceGroup group;
  final Map<String, Object?> values;
  String get id => '${platform.name}.${group.name}';
  String get label => switch (group) {
    DevicePreferenceGroup.desktopLayout => 'Panel dimensions',
    DevicePreferenceGroup.developerUi => 'Developer preview preferences',
  };

  Map<String, Object?> toJson() => {
    'version': version,
    'platform': platform.name,
    'group': group.name,
    'values': values,
  };

  factory PortableDevicePreferences.fromJson(Object? value) {
    final json = _fields(value, {'version', 'platform', 'group', 'values'});
    final platform = DevicePreferencePlatform.values
        .where((platform) => platform.name == json['platform'])
        .firstOrNull;
    final group = DevicePreferenceGroup.values
        .where((group) => group.name == json['group'])
        .firstOrNull;
    if (json['version'] != version || platform == null || group == null) {
      throw const FormatException('Unsupported device preference group.');
    }
    return PortableDevicePreferences(
      platform: platform,
      group: group,
      values: json['values'],
    );
  }
}

Map<String, Object?> _fields(Object? value, Set<String> keys) {
  if (value is! Map ||
      value.length != keys.length ||
      value.keys.any((key) => !keys.contains(key))) {
    throw const FormatException('Invalid device preference fields.');
  }
  return Map<String, Object?>.from(value);
}
