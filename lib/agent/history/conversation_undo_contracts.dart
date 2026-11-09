import 'conversation_history.dart';

enum ConversationUndoState { prepared, applied, unknown }

/// Business owners seal exact inverses from their durable operation receipts.
abstract interface class ConversationUndoParticipant {
  ConversationUndoOwner get owner;
  Future<ConversationUndoTicket> prepare({
    required String batchId,
    required List<String> operationIds,
  });
  Future<ConversationUndoState> readState(ConversationUndoTicket ticket);
  Future<void> validate(ConversationUndoTicket ticket);
  Future<void> commit(ConversationUndoTicket ticket);
}
