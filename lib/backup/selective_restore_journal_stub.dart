import 'package:shared_preferences/shared_preferences.dart';

import 'selective_backup_models.dart';
import 'selective_restore_journal.dart';

class PlatformSelectiveJournalStorage implements SelectiveJournalStorage {
  PlatformSelectiveJournalStorage({
    Future<SharedPreferences> Function()? preferences,
  }) : _preferences = preferences ?? SharedPreferences.getInstance;
  final Future<SharedPreferences> Function() _preferences;
  static const storagePrefix = 'sked.backup.selective.v1.';
  @override
  Future<List<String?>> readSlots() async {
    final preferences = await _preferences();
    await preferences.reload();
    return [
      for (var slot = 0; slot < 2; slot++)
        _read(preferences.get('$storagePrefix$slot')),
    ];
  }

  String? _read(Object? value) {
    if (value == null || value is String) return value as String?;
    throw const SelectiveBackupException(
      SelectiveBackupError.unavailable,
      'The restore journal has an invalid stored type.',
    );
  }

  @override
  Future<void> writeSlot(int slot, String source) async {
    final preferences = await _preferences();
    if (!await preferences.setString('$storagePrefix$slot', source)) {
      throw const SelectiveBackupException(
        SelectiveBackupError.unknown,
        'The restore journal write was rejected.',
      );
    }
  }
}
