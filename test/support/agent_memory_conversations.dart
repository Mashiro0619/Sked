import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sked/agent/conversations/conversation_view_repository.dart';
import 'package:sked/agent/history/conversation_history.dart';
import 'package:sked/agent/references/agent_composer_reference.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/models/agent_settings.dart';

export 'package:sked/agent/conversations/conversation_view_repository.dart';
export 'package:sked/models/agent_settings.dart';

/// Typed UI fixture state; no archive encoding or production store is involved.
class MemoryConversationSnapshot {
  const MemoryConversationSnapshot({
    this.conversations = const [],
    this.selectedId,
    this.handoffs = const [],
    this.revision = 0,
  });
  final List<AgentConversation> conversations;
  final String? selectedId;
  final List<ConversationHandoff> handoffs;
  final int revision;
}

class UiMemoryStorage {
  MemoryConversationSnapshot? source;
  bool fail = false;
  Future<void> Function()? beforeSave;
  Future<MemoryConversationSnapshot?> load() async => source;
  Future<void> save(
    MemoryConversationSnapshot value, {
    required int revision,
  }) async {
    await beforeSave?.call();
    if (fail) throw StateError('synthetic UI publication failure');
    source = value;
  }
}

class MemoryConversationRepository extends ChangeNotifier
    implements ConversationViewRepository {
  MemoryConversationRepository({
    UiMemoryStorage? storage,
    String Function()? idGenerator,
    DateTime Function()? clock,
    this.pageSize = 50,
  }) : storage = storage ?? UiMemoryStorage(),
       _id = idGenerator,
       _clock = clock ?? DateTime.now;

  final UiMemoryStorage storage;
  final String Function()? _id;
  final DateTime Function() _clock;
  final int pageSize;
  final _records = <String, AgentConversation>{};
  final _visible = <String, int>{};
  final _handoffs = <String, ConversationHandoff>{};
  Future<void> _tail = SynchronousFuture<void>(null);
  int _sequence = 0, _revision = 0;
  String? _selectedId, _draftId;
  bool _loaded = false, _blocked = false, _frozen = false, _disposed = false;

  @override
  bool get isLoaded => _loaded;
  @override
  bool get blocked => _blocked;
  @override
  bool get canWrite => _loaded && !_blocked && !_frozen && !_disposed;
  @override
  String? get selectedId => _selectedId;
  @override
  AgentConversation? get selected => find(_selectedId);
  @override
  AgentConversation? get draftConversation => find(_draftId);
  @override
  List<AgentConversation> get ownedConversations =>
      List.unmodifiable(_records.values);
  @override
  List<AgentConversation> get conversations {
    final values = _records.values
        .where((value) => value.id != _draftId)
        .toList();
    values.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return List.unmodifiable(values);
  }

  @override
  AgentConversation? find(String? id) => _records[id];
  @override
  bool isDraft(String? id) => id != null && id == _draftId;
  @override
  bool isConversationLoaded(String id) =>
      (_visible[id] ?? 0) >= (find(id)?.messages.length ?? 0);
  @override
  List<ConversationMessage> visibleMessages(String id) {
    final messages = find(id)?.messages ?? const <ConversationMessage>[];
    final count = _visible[id] ?? pageSize;
    return List.unmodifiable(
      messages.skip((messages.length - count).clamp(0, messages.length)),
    );
  }

  @override
  List<ConversationTurn> visibleTurns(String id) {
    final visible = visibleMessages(id).map((message) => message.id).toSet();
    return List.unmodifiable(
      find(id)?.turns.where(
            (turn) =>
                visible.contains(turn.requestMessageId) ||
                turn.messageIds.any(visible.contains),
          ) ??
          const <ConversationTurn>[],
    );
  }

  @override
  bool hasEarlierMessages(String id) =>
      (find(id)?.messages.length ?? 0) > (_visible[id] ?? pageSize);
  @override
  ConversationHandoff? handoffForMessage(
    String conversationId,
    String? messageId,
  ) => _handoffs.values
      .where(
        (value) =>
            value.conversationId == conversationId &&
            value.messageId == messageId,
      )
      .firstOrNull;

  @override
  Future<void> load() => _enqueue(() async {
    final snapshot = await storage.load();
    if (_disposed) return;
    _records
      ..clear()
      ..addEntries(
        (snapshot?.conversations ?? const <AgentConversation>[]).map(
          (value) => MapEntry(value.id, value),
        ),
      );
    _handoffs
      ..clear()
      ..addEntries(
        (snapshot?.handoffs ?? const <ConversationHandoff>[]).map(
          (value) => MapEntry(value.id, value),
        ),
      );
    _selectedId = snapshot?.selectedId;
    _revision = snapshot?.revision ?? 0;
    _draftId = null;
    _visible.clear();
    if (_selectedId != null) _visible[_selectedId!] = pageSize;
    _loaded = true;
    _blocked = false;
    notifyListeners();
  });

  void seed(
    Iterable<AgentConversation> values, {
    String? selectedId,
    String? draftId,
  }) {
    _records
      ..clear()
      ..addEntries(values.map((value) => MapEntry(value.id, value)));
    _selectedId = selectedId;
    _draftId = draftId;
    _visible.clear();
    for (final value in values) {
      _visible[value.id] = value.messages.length;
    }
    _loaded = true;
    _blocked = false;
    notifyListeners();
  }

  @override
  Future<void> select(String id) => _enqueue(() async {
    if (find(id) == null) _missing();
    _selectedId = id;
    _visible.putIfAbsent(id, () => pageSize);
    if (!isDraft(id)) await _save();
    _notify();
  });
  @override
  Future<AgentConversation> read(String id) async {
    final value = find(id) ?? _missing();
    _visible.putIfAbsent(id, () => pageSize);
    return value;
  }

  @override
  Future<void> loadEarlierMessages(String id) async {
    _visible[id] = (_visible[id] ?? pageSize) + pageSize;
    _notify();
  }

  Future<AgentConversation> create({
    required String title,
    AgentPermissionMode mode = AgentPermissionMode.ask,
    AgentModelSelection? modelSelection,
    String? id,
  }) => _enqueue(() async {
    _check();
    final value = _newConversation(
      id ?? _nextId(),
      title,
      mode,
      modelSelection,
    );
    _records[value.id] = value;
    _visible[value.id] = 0;
    _selectedId = value.id;
    await _save();
    _notify();
    return value;
  });

  @override
  Future<AgentConversation> createDraft({
    required String title,
    AgentPermissionMode mode = AgentPermissionMode.ask,
    AgentModelSelection? modelSelection,
    String? id,
    VoidCallback? validate,
  }) => _enqueue(() async {
    _check();
    validate?.call();
    final existing = draftConversation;
    if (existing != null) {
      _selectedId = existing.id;
      _notify();
      return existing;
    }
    final value = _newConversation(
      id ?? _nextId(),
      title,
      mode,
      modelSelection,
    );
    _records[value.id] = value;
    _draftId = _selectedId = value.id;
    _visible[value.id] = 0;
    _notify();
    return value;
  });

  Future<AgentConversation> update(
    String id,
    AgentConversation Function(AgentConversation current) change, {
    String? expectedRunId,
    void Function(AgentConversation current)? validate,
    bool updateTime = true,
  }) => _enqueue(() async {
    _check();
    final before = find(id) ?? _missing();
    validate?.call(before);
    if (expectedRunId != null && before.runId != expectedRunId) _conflict();
    final changed = change(before);
    final after = updateTime ? changed.copyWith(updatedAt: _clock()) : changed;
    final promoting =
        isDraft(id) &&
        after.messages.any((message) => message.role == ConversationRole.user);
    if (!isDraft(id) || promoting) {
      await _save(
        values: [
          for (final record in _records.values)
            if (record.id == id) after else if (record.id != _draftId) record,
        ],
        promoting: promoting,
      );
    }
    if (promoting) _draftId = null;
    _records[id] = after;
    _visible[id] = after.messages.length;
    _notify();
    return after;
  });

  @override
  Future<AgentConversation> updateDraftText(String id, String text) =>
      update(id, (current) => current.copyWith(draft: text));
  @override
  Future<AgentConversation> updateDraftReferences(
    String id,
    Iterable<AgentComposerReference> references, {
    void Function(AgentConversation current)? validate,
  }) => update(
    id,
    (current) => current.copyWith(
      draftReferences: references,
      draftAttachmentIds: {
        ...current.draftAttachmentIds,
        for (final reference in references)
          if (reference.kind == AgentComposerReferenceKind.attachment)
            reference.attachmentId!,
      },
    ),
    validate: validate,
  );
  @override
  Future<AgentConversation> rename(String id, String title) => update(
    id,
    (current) => current.copyWith(title: title, titleWasEdited: true),
  );
  @override
  Future<AgentConversation> setPinned(String id, bool pinned) => update(
    id,
    (current) => current.copyWith(pinned: pinned),
    updateTime: false,
  );
  @override
  Future<void> delete(
    String id, {
    void Function(AgentConversation)? validate,
  }) => _enqueue(() async {
    _check();
    final value = find(id);
    if (value == null) return;
    validate?.call(value);
    final draft = isDraft(id);
    _records.remove(id);
    _visible.remove(id);
    if (_draftId == id) _draftId = null;
    if (_selectedId == id) _selectedId = conversations.firstOrNull?.id;
    if (!draft) await _save();
    _notify();
  });
  @override
  Future<AgentConversation> addSource(
    String id,
    ConversationSource source, {
    void Function(AgentConversation current)? validate,
  }) => update(
    id,
    (current) => current.copyWith(
      sources: [
        ...current.sources.where((value) => value.id != source.id),
        source,
      ],
    ),
    validate: validate,
  );
  @override
  Future<AgentConversation> removeSource(
    String id,
    String sourceId, {
    void Function(AgentConversation current)? validate,
  }) => update(
    id,
    (current) => current.copyWith(
      sources: current.sources.where((value) => value.id != sourceId),
    ),
    validate: validate,
  );

  @override
  Future<({AgentConversation conversation, bool created})> handoff({
    required String handoffId,
    required ConversationSource source,
    required String title,
    required String prompt,
    AgentPermissionMode mode = AgentPermissionMode.ask,
    AgentModelSelection? modelSelection,
  }) => _enqueue(() async {
    _check();
    final previous = _handoffs[handoffId];
    if (previous != null) {
      return (conversation: find(previous.conversationId)!, created: false);
    }
    final conversation = _newConversation(
      _nextId(),
      title,
      mode,
      modelSelection,
    );
    final message = ConversationMessage(
      id: _nextId(),
      role: ConversationRole.user,
      text: prompt,
      createdAt: _clock(),
    );
    final saved = conversation.copyWith(messages: [message], sources: [source]);
    _handoffs[handoffId] = ConversationHandoff(
      id: handoffId,
      conversationId: saved.id,
      sourceDigest: sha256
          .convert(utf8.encode(jsonEncode(source.toJson())))
          .toString(),
      messageId: message.id,
    );
    final previousSelection = _selectedId;
    _selectedId = saved.id;
    try {
      await _save(values: [...conversations, saved]);
    } catch (_) {
      _selectedId = previousSelection;
      _handoffs.remove(handoffId);
      rethrow;
    }
    _records[saved.id] = saved;
    _visible[saved.id] = saved.messages.length;
    _notify();
    return (conversation: saved, created: true);
  });

  Future<Set<String>> referencedAttachmentIds() async => {
    for (final conversation in _records.values)
      ...conversation.draftAttachmentIds,
    for (final conversation in _records.values)
      for (final message in conversation.messages) ...message.attachmentIds,
    for (final conversation in _records.values)
      for (final input in conversation.queuedInputs) ...input.attachmentIds,
  };
  @override
  Future<void> waitForPendingWrites() async => _tail;
  Future<void> freezeAndDrain() async {
    _frozen = true;
    await _tail;
  }

  void freeze() {
    _frozen = true;
  }

  void resume() {
    _frozen = false;
  }

  Future<void> _save({
    List<AgentConversation>? values,
    bool promoting = false,
  }) async {
    try {
      await storage.save(
        MemoryConversationSnapshot(
          conversations: values ?? conversations,
          selectedId: !promoting && isDraft(_selectedId) ? null : _selectedId,
          handoffs: _handoffs.values.toList(),
          revision: ++_revision,
        ),
        revision: _revision,
      );
    } catch (_) {
      _blocked = true;
      _notify();
      rethrow;
    }
  }

  AgentConversation _newConversation(
    String id,
    String title,
    AgentPermissionMode mode,
    AgentModelSelection? model,
  ) => AgentConversation(
    id: id,
    title: title,
    createdAt: _clock(),
    updatedAt: _clock(),
    mode: mode,
    modelSelection: model,
  );
  String _nextId() => _id?.call() ?? 'ui-conversation-${++_sequence}';
  void _check() {
    if (!canWrite) throw StateError('UI fixture is unavailable.');
  }

  Never _missing() => throw const OperationProblem(
    OperationErrorCode.notFound,
    'The UI conversation does not exist.',
  );
  Never _conflict() => throw const OperationProblem(
    OperationErrorCode.conflict,
    'The UI conversation changed.',
  );
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    late final Future<void> pending;
    void settled() {
      if (identical(_tail, pending)) {
        // Completed work must not retain a previous FakeAsync zone.
        _tail = SynchronousFuture<void>(null);
      }
    }

    pending = result.then<void>(
      (_) => settled(),
      onError: (Object _, StackTrace _) => settled(),
    );
    _tail = pending;
    return result;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
