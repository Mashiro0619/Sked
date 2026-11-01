import 'package:sked/agent/conversations/conversation_storage.dart';

/// Explicit ephemeral conversation storage for synthetic native/VM entries.
class MemoryConversationStorage extends ConversationStorage {
  MemoryConversationStorage() : super.base();

  String? source;

  @override
  Future<ConversationStorageLoad> load() async =>
      ConversationStorageLoad(source: source);

  @override
  Future<void> save(String value, {required int revision}) async {
    source = value;
  }
}
