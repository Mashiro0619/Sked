import 'package:flutter/foundation.dart';

import '../../application/operation_contracts.dart';

import '../../models/agent_settings.dart';
import '../history/conversation_history.dart';
import '../references/agent_composer_reference.dart';
import 'conversation_models.dart';

export 'conversation_models.dart';

/// The view cache and explicit local editing operations used by Agent screens.
/// Runs, tool results, history versions and checkpoints are owned by Rust.
abstract interface class ConversationViewRepository implements Listenable {
  bool get isLoaded;
  bool get blocked;
  bool get canWrite;
  String? get selectedId;
  AgentConversation? get selected;
  AgentConversation? get draftConversation;
  List<AgentConversation> get conversations;
  List<AgentConversation> get ownedConversations;

  AgentConversation? find(String? id);
  bool isDraft(String? id);
  bool isConversationLoaded(String id);
  List<ConversationMessage> visibleMessages(String id);
  List<ConversationTurn> visibleTurns(String id);
  bool hasEarlierMessages(String id);
  ConversationHandoff? handoffForMessage(
    String conversationId,
    String? messageId,
  );

  Future<void> load();
  Future<void> select(String id);
  Future<AgentConversation> read(String id);
  Future<void> loadEarlierMessages(String id);
  Future<AgentConversation> createDraft({
    required String title,
    AgentPermissionMode mode = AgentPermissionMode.ask,
    AgentModelSelection? modelSelection,
    String? id,
    VoidCallback? validate,
  });

  Future<AgentConversation> updateDraftText(String id, String text);
  Future<AgentConversation> updateDraftReferences(
    String id,
    Iterable<AgentComposerReference> references, {
    void Function(AgentConversation current)? validate,
  });
  Future<AgentConversation> rename(String id, String title);
  Future<AgentConversation> setPinned(String id, bool pinned);
  Future<void> delete(String id, {void Function(AgentConversation)? validate});

  Future<AgentConversation> addSource(
    String id,
    ConversationSource source, {
    void Function(AgentConversation current)? validate,
  });
  Future<AgentConversation> removeSource(
    String id,
    String sourceId, {
    void Function(AgentConversation current)? validate,
  });
  Future<({AgentConversation conversation, bool created})> handoff({
    required String handoffId,
    required ConversationSource source,
    required String title,
    required String prompt,
    AgentPermissionMode mode = AgentPermissionMode.ask,
    AgentModelSelection? modelSelection,
  });

  Future<void> waitForPendingWrites();
}
