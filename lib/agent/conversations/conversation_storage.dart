import 'conversation_storage_stub.dart'
    if (dart.library.io) 'conversation_storage_io.dart';

class ConversationStorageLoad {
  const ConversationStorageLoad({this.source, this.recovered = false});
  final String? source;
  final bool recovered;
}

class ConversationStorageException implements Exception {
  const ConversationStorageException(
    this.message, {
    this.outcomeUnknown = false,
  });
  final String message;
  final bool outcomeUnknown;
  @override
  String toString() => message;
}

abstract class ConversationStorage {
  factory ConversationStorage() = PlatformConversationStorage;
  ConversationStorage.base();

  Future<ConversationStorageLoad> load();
  Future<void> save(String source, {required int revision});
}
