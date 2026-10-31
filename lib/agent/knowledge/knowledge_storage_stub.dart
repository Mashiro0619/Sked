import 'package:shared_preferences/shared_preferences.dart';

import 'knowledge_models.dart';
import 'knowledge_storage.dart';

class PlatformKnowledgeStorage extends KnowledgeStorage {
  PlatformKnowledgeStorage({Future<SharedPreferences> Function()? preferences})
    : _preferences = preferences ?? SharedPreferences.getInstance,
      super.base();
  static const storageKeyPrefix = 'sked.agent.knowledge.v1.';
  final Future<SharedPreferences> Function() _preferences;
  @override
  Future<KnowledgeStorageLoad> load() async {
    final preferences = await _preferences();
    await preferences.reload();
    final slots = <String?>[];
    for (var index = 0; index < 2; index++) {
      final value = preferences.get('$storageKeyPrefix$index');
      if (value != null && value is! String) {
        throw const KnowledgeException(
          KnowledgeError.unavailable,
          'Invalid knowledge storage type.',
        );
      }
      slots.add(value as String?);
    }
    return decodeKnowledgeSlots(slots);
  }

  @override
  Future<void> save(KnowledgeArchive archive) async {
    final encoded = encodeKnowledgeSlot(archive);
    final preferences = await _preferences();
    final keys = [
      '$storageKeyPrefix${archive.revision % 2}',
      '$storageKeyPrefix${(archive.revision + 1) % 2}',
    ];
    try {
      for (final key in keys) {
        if (!await preferences.setString(key, encoded)) {
          throw StateError('Knowledge write rejected.');
        }
        await preferences.reload();
        if (preferences.get(key) != encoded) {
          throw StateError('Knowledge readback failed.');
        }
      }
    } catch (_) {
      try {
        await preferences.reload();
        if (keys.every((key) => preferences.get(key) == encoded)) return;
      } catch (_) {
        // Preserve uncertain state for explicit recovery.
      }
      throw const KnowledgeException(
        KnowledgeError.unknown,
        'Knowledge write could not be confirmed. Reload before continuing.',
      );
    }
  }
}
