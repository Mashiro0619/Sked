import '../services/device_preferences_models.dart';
import 'selective_backup_models.dart';

export '../services/device_preferences_models.dart';

List<BackupRecord> buildDeviceBackupRecords(
  DevicePreferencePlatform platform,
  Map<DevicePreferenceGroup, Map<String, Object?>> groups,
) => [
  for (final entry in groups.entries)
    deviceBackupRecord(
      PortableDevicePreferences(
        platform: platform,
        group: entry.key,
        values: entry.value,
      ),
    ),
];

BackupRecord deviceBackupRecord(PortableDevicePreferences preferences) =>
    BackupRecord(
      key: BackupObjectKey(BackupObjectKind.deviceSettings, preferences.id),
      label: preferences.label,
      data: preferences.toJson(),
    );

PortableDevicePreferences readDeviceBackupRecord(BackupRecord record) {
  if (record.key.kind != BackupObjectKind.deviceSettings) {
    backupInvalid('Expected a device preference group.');
  }
  try {
    final result = PortableDevicePreferences.fromJson(record.data);
    if (result.id != record.key.id) {
      backupInvalid('Device preference identity mismatch.');
    }
    return result;
  } on FormatException {
    backupInvalid('Invalid device preference group.');
  }
}

DevicePreferenceGroup devicePreferenceGroup(BackupRecord record) =>
    readDeviceBackupRecord(record).group;
DevicePreferencePlatform devicePreferencePlatform(BackupRecord record) =>
    readDeviceBackupRecord(record).platform;
