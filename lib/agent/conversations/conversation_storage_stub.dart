import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/app_storage_keys.dart';
import 'conversation_storage.dart';
import 'conversation_storage_codec.dart';

class PlatformConversationStorage extends ConversationStorage {
  PlatformConversationStorage({
    Future<SharedPreferences> Function()? preferences,
  }) : _preferences = preferences ?? SharedPreferences.getInstance,
       super.base();

  static const storageKeyPrefix = agentConversationsWebStorageKeyPrefix;
  final Future<SharedPreferences> Function() _preferences;

  @override
  Future<ConversationStorageLoad> load() async {
    final prefs = await _preferences();
    await prefs.reload();
    final slots = <String?>[];
    for (var i = 0; i < 2; i++) {
      final value = prefs.get('$storageKeyPrefix$i');
      if (value != null && value is! String) {
        throw const ConversationStorageException(
          'Conversation storage has an invalid type.',
        );
      }
      slots.add(value as String?);
    }
    return decodeConversationSlots(slots);
  }

  @override
  Future<void> save(String source, {required int revision}) async {
    final encoded = encodeConversationSlot(source, revision);
    final prefs = await _preferences();
    final keys = [
      '$storageKeyPrefix${revision % 2}',
      '$storageKeyPrefix${(revision + 1) % 2}',
    ];
    try {
      for (final key in keys) {
        if (!await prefs.setString(key, encoded)) {
          throw StateError('write rejected');
        }
        await prefs.reload();
        if (prefs.get(key) != encoded) throw StateError('readback failed');
      }
      return;
    } catch (_) {
      try {
        await prefs.reload();
        if (keys.every((key) => prefs.get(key) == encoded)) return;
        if (keys.any((key) => prefs.get(key) == encoded)) {
          throw const ConversationStorageException(
            'Conversation write is partially confirmed; reload before retrying.',
            outcomeUnknown: true,
          );
        }
      } catch (_) {
        throw const ConversationStorageException(
          'Conversation write outcome is unknown; reload before retrying.',
          outcomeUnknown: true,
        );
      }
    }
    throw const ConversationStorageException(
      'Conversation write failed; reload before retrying.',
    );
  }
}
