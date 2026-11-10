import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../application/operation_contracts.dart';

import '../../models/agent_settings.dart';
import '../conversations/conversation_view_repository.dart';
import '../history/conversation_history.dart';
import '../references/agent_composer_reference.dart';
import 'conversation_projection.dart';
import 'generated/api/contracts.dart' as bridge;
import 'generated/api/management_contracts.dart' as management;
import 'generated/api/models.dart' as native;
import 'rust_agent_client.dart';

/// Caches native projections and sends explicit editing commands.
class RustConversationRepository extends ChangeNotifier
    implements ConversationViewRepository {
  RustConversationRepository(this.client, {int pageSize = 50})
    : _pageSize = pageSize {
    if (pageSize < 1) throw ArgumentError.value(pageSize, 'pageSize');
    _subscription = client.events.listen(_event, onError: _eventError);
  }

  final AgentRustClient client;
  final int _pageSize;
  final _views = <String, AgentConversation>{};
  final _sequence = <String, int>{};
  final _draftIds = <String>{};
  final _details = <String>{};
  final _full = <String>{};
  final _visible = <String, List<ConversationMessage>>{};
  final _before = <String, int?>{};
  final _handoffs = <String, ConversationHandoff>{};
  late final StreamSubscription<bridge.AgentEvent> _subscription;
  Future<void> _tail = Future<void>.value();
  String? _selectedId;
  bool _loaded = false;
  bool _blocked = false;
  bool _maintenance = false;
  bool _disposed = false;
  int _generation = 0;

  @override
  bool get isLoaded => _loaded;
  @override
  bool get blocked => _blocked;
  @override
  bool get canWrite => _loaded && !_blocked && !_maintenance && !_disposed;
  @override
  String? get selectedId => _selectedId;
  @override
  AgentConversation? get selected => find(_selectedId);
  @override
  AgentConversation? get draftConversation =>
      _draftIds.map(find).whereType<AgentConversation>().firstOrNull;
  @override
  List<AgentConversation> get ownedConversations =>
      List.unmodifiable(_views.values);
  @override
  List<AgentConversation> get conversations => List.unmodifiable(
    _views.values.where((view) => !_draftIds.contains(view.id)),
  );
  @override
  AgentConversation? find(String? id) => _views[id];
  @override
  bool isDraft(String? id) => _draftIds.contains(id);
  @override
  bool isConversationLoaded(String id) => _details.contains(id);
  @override
  List<ConversationMessage> visibleMessages(String id) =>
      _visible[id] ?? const [];
  @override
  List<ConversationTurn> visibleTurns(String id) {
    final ids = visibleMessages(id).map((message) => message.id).toSet();
    return List.unmodifiable(
      (find(id)?.turns ?? const <ConversationTurn>[]).where(
        (turn) =>
            ids.contains(turn.requestMessageId) ||
            turn.messageIds.any(ids.contains),
      ),
    );
  }

  @override
  bool hasEarlierMessages(String id) => _before[id] != null;
  @override
  ConversationHandoff? handoffForMessage(String id, String? messageId) =>
      _handoffs.values
          .where(
            (item) => item.conversationId == id && item.messageId == messageId,
          )
          .firstOrNull;

  void ingestSnapshot(native.ViewConversationSnapshot snapshot) {
    if (_disposed ||
        (_sequence[snapshot.conversation.id] ?? -1) > snapshot.sequence) {
      return;
    }
    final id = snapshot.conversation.id;
    final view = conversationFromRust(snapshot);
    final anchor = _visible[id]?.firstOrNull?.id;
    _ingest(snapshot, view, full: true);
    if (_visible.containsKey(id)) {
      final index = anchor == null
          ? -1
          : view.messages.indexWhere((message) => message.id == anchor);
      final start = index < 0
          ? _pageStart(view.messages, view.messages.length)
          : index;
      _visible[id] = List.unmodifiable(view.messages.skip(start));
      _before[id] = start == 0 ? null : start;
    }
    _notify();
  }

  void _ingest(
    native.ViewConversationSnapshot snapshot,
    AgentConversation view, {
    required bool full,
  }) {
    final id = view.id;
    _sequence[id] = snapshot.sequence;
    _views[id] = view;
    _details.add(id);
    if (full) {
      _full.add(id);
    } else {
      _full.remove(id);
    }
    if (snapshot.conversation.draftOnly) {
      _draftIds.add(id);
    } else {
      _draftIds.remove(id);
    }
    _handoffs.removeWhere((_, handoff) => handoff.conversationId == id);
    for (final handoff in snapshot.handoffs) {
      _handoffs[handoff.id] = handoffFromRust(handoff);
    }
  }

  @override
  Future<void> load() => _serialize(() async {
    final generation = _generation;
    try {
      final seen = <String>{};
      int? offset = 0;
      while (offset != null) {
        final result = await client.query(
          bridge.AgentQuery(
            kind: bridge.QueryKind.conversations,
            includeDrafts: true,
            offset: offset,
            limit: 100,
          ),
        );
        if (_disposed || generation != _generation) return;
        for (final summary in result.conversations) {
          seen.add(summary.id);
          if ((_sequence[summary.id] ?? -1) > summary.sequence) continue;
          final current = _views[summary.id];
          _views[summary.id] = current == null
              ? conversationSummaryFromRust(summary)
              : current.copyWith(
                  title: summary.title,
                  titleWasEdited: current.titleWasEdited,
                  pinned: summary.pinned,
                  archived: summary.archived,
                  status: ConversationStatus.values.byName(summary.status.name),
                  updatedAt: DateTime.fromMillisecondsSinceEpoch(
                    summary.updatedAt,
                    isUtc: true,
                  ),
                );
          _sequence[summary.id] = summary.sequence;
          if (summary.draftOnly) {
            _draftIds.add(summary.id);
          } else {
            _draftIds.remove(summary.id);
          }
        }
        offset = result.nextOffset;
      }
      for (final id in _views.keys.where((id) => !seen.contains(id)).toList()) {
        _forget(id);
      }
      final selection = await client.query(
        const bridge.AgentQuery(kind: bridge.QueryKind.conversationSelection),
      );
      if (_disposed || generation != _generation) return;
      _selectedId = selection.selection?.selectedId;
      if (_selectedId case final id?) await _loadPage(id);
      _loaded = true;
      _blocked = false;
      _notify();
    } catch (_) {
      _blocked = true;
      _notify();
      rethrow;
    }
  });

  @override
  Future<void> select(String id) => _serialize(() async {
    _checkWritable();
    final result = await client.dispatch(
      bridge.AgentCommand(
        kind: bridge.CommandKind.selectConversation,
        conversationId: id,
      ),
    );
    _selectedId = result.selection?.selectedId ?? id;
    await _loadPage(id);
    _notify();
  });

  @override
  Future<AgentConversation> read(String id) => _serialize(() => _read(id));

  Future<AgentConversation> _read(String id) async {
    final generation = _generation;
    final result = await client.query(
      bridge.AgentQuery(
        kind: bridge.QueryKind.readConversation,
        conversationId: id,
      ),
    );
    final snapshot = result.snapshot;
    if (snapshot == null) throw StateError('Conversation does not exist.');
    if (generation == _generation) ingestSnapshot(snapshot);
    return conversationFromRust(snapshot);
  }

  Future<void> _loadPage(String id, {int? before}) async {
    final generation = _generation;
    final previous = visibleMessages(id);
    final anchor = previous.firstOrNull?.id;
    final previousTotal = (_before[id] ?? 0) + previous.length;
    final extension = before == null ? 0 : _pageSize;
    var limit = math.max(_pageSize, previous.length + extension);
    while (true) {
      final result = await client.query(
        bridge.AgentQuery(
          kind: bridge.QueryKind.readConversation,
          conversationId: id,
          limit: limit,
        ),
      );
      if (_disposed || generation != _generation) return;
      final snapshot = result.snapshot;
      if (snapshot == null) throw StateError('Conversation does not exist.');
      if ((_sequence[id] ?? -1) > snapshot.sequence) {
        if (_full.contains(id)) {
          final messages = _views[id]!.messages;
          final anchorIndex = messages.indexWhere(
            (message) => message.id == anchor,
          );
          final start = anchorIndex < 0
              ? _pageStart(messages, messages.length)
              : before == null
              ? anchorIndex
              : _pageStart(messages, anchorIndex);
          _visible[id] = List.unmodifiable(messages.skip(start));
          _before[id] = start == 0 ? null : start;
          _notify();
        }
        return;
      }
      // Read one continuous window from the current snapshot. Combining an
      // older page with cached messages can restore a suffix removed by redo.
      final requiredCount = previous.isEmpty
          ? _pageSize
          : previous.length +
                extension +
                math.max<int>(0, result.total - previousTotal);
      if (requiredCount > limit && result.nextOffset != null) {
        limit = requiredCount;
        continue;
      }
      final page = snapshot.messages.map(conversationMessageFromRust).toList();
      final anchorIndex = page.indexWhere((message) => message.id == anchor);
      final offset = anchorIndex < 0
          ? 0
          : before == null
          ? anchorIndex
          : _pageStart(page, anchorIndex);
      final messages = page.sublist(offset);
      final start = (result.pageStart ?? 0) + offset;
      final view = conversationFromRust(
        snapshot,
        projectedMessages: messages,
        messageStart: start,
      );
      _ingest(
        snapshot,
        view,
        full: start == 0 && messages.length == result.total,
      );
      _visible[id] = List.unmodifiable(messages);
      _before[id] = start == 0 ? null : start;
      _notify();
      return;
    }
  }

  @override
  Future<void> loadEarlierMessages(String id) => _serialize(() async {
    if (_before[id] case final before?) await _loadPage(id, before: before);
  });

  @override
  Future<AgentConversation> createDraft({
    required String title,
    AgentPermissionMode mode = AgentPermissionMode.ask,
    AgentModelSelection? modelSelection,
    String? id,
    VoidCallback? validate,
  }) => _serialize(() async {
    _checkWritable();
    validate?.call();
    final result = await client.dispatch(
      bridge.AgentCommand(
        kind: bridge.CommandKind.createConversation,
        conversationId: id,
        text: title,
        mode: native.ViewPermissionMode.values.byName(mode.name),
        selection: modelSelectionToRust(modelSelection),
      ),
    );
    final snapshot = result.snapshot;
    if (snapshot == null) throw StateError('Native draft was not returned.');
    ingestSnapshot(snapshot);
    _selectedId = result.selection?.selectedId ?? snapshot.conversation.id;
    _visible.putIfAbsent(snapshot.conversation.id, () => const []);
    _notify();
    return find(snapshot.conversation.id)!;
  });

  @override
  Future<AgentConversation> updateDraftText(String id, String text) => _edit(
    bridge.AgentCommand(
      kind: bridge.CommandKind.updateDraft,
      conversationId: id,
      text: text,
    ),
  );

  Future<AgentConversation> createManagedConversation({
    required String id,
    required String title,
    required AgentPermissionMode mode,
    AgentModelSelection? modelSelection,
    VoidCallback? validate,
  }) => _serialize(() async {
    _checkWritable();
    validate?.call();
    final result = await client.dispatch(
      bridge.AgentCommand(
        kind: bridge.CommandKind.createManagedConversation,
        targetId: id,
        text: title,
        mode: native.ViewPermissionMode.values.byName(mode.name),
        selection: modelSelectionToRust(modelSelection),
      ),
    );
    final snapshot = result.snapshot;
    if (snapshot == null) {
      throw StateError('Native conversation was not returned.');
    }
    ingestSnapshot(snapshot);
    _selectedId = result.selection?.selectedId ?? id;
    _visible.putIfAbsent(id, () => const []);
    _notify();
    return find(id)!;
  });
  @override
  Future<AgentConversation> updateDraftReferences(
    String id,
    Iterable<AgentComposerReference> references, {
    void Function(AgentConversation current)? validate,
  }) => _edit(
    bridge.AgentCommand(
      kind: bridge.CommandKind.updateDraft,
      conversationId: id,
      references: AgentComposerReference.validatedList(references)
          .map(referenceToRust)
          .toList(),
    ),
    validate: validate,
  );
  @override
  Future<AgentConversation> rename(String id, String title) => _edit(
    bridge.AgentCommand(
      kind: bridge.CommandKind.rename,
      conversationId: id,
      text: title,
    ),
  );
  @override
  Future<AgentConversation> setPinned(String id, bool pinned) => _edit(
    bridge.AgentCommand(
      kind: bridge.CommandKind.pin,
      conversationId: id,
      flag: pinned,
    ),
  );
  @override
  Future<AgentConversation> addSource(
    String id,
    ConversationSource source, {
    void Function(AgentConversation current)? validate,
  }) => _edit(
    bridge.AgentCommand(
      kind: bridge.CommandKind.addSource,
      conversationId: id,
      source: sourceToRust(source),
    ),
    validate: validate,
  );
  @override
  Future<AgentConversation> removeSource(
    String id,
    String sourceId, {
    void Function(AgentConversation current)? validate,
  }) => _edit(
    bridge.AgentCommand(
      kind: bridge.CommandKind.removeSource,
      conversationId: id,
      targetId: sourceId,
    ),
    validate: validate,
  );

  Future<AgentConversation> _edit(
    bridge.AgentCommand command, {
    void Function(AgentConversation current)? validate,
  }) => _serialize(() async {
    _checkWritable();
    final id = command.conversationId!;
    final current = find(id);
    if (current == null) throw StateError('Conversation does not exist.');
    validate?.call(current);
    final result = await client.dispatch(command);
    if (result.snapshot case final snapshot?) {
      ingestSnapshot(snapshot);
      return find(id)!;
    }
    return _read(id);
  });

  @override
  Future<void> delete(
    String id, {
    void Function(AgentConversation)? validate,
  }) => _serialize(() async {
    _checkWritable();
    final current = find(id);
    if (current == null) return;
    validate?.call(current);
    final result = await client.dispatch(
      bridge.AgentCommand(
        kind: bridge.CommandKind.deleteConversation,
        conversationId: id,
      ),
    );
    _forget(id);
    _selectedId = result.selection?.selectedId;
    if (_selectedId case final selected?) await _loadPage(selected);
    _notify();
  });

  Future<int> pruneHistory({required int days}) async {
    _checkWritable();
    if (days < 0) {
      throw const FormatException('History retention must not be negative.');
    }
    if (days == 0) return 0;
    final removed = await (await client.core).pruneHistory(
      cutoffMs: DateTime.now()
          .subtract(Duration(days: days))
          .millisecondsSinceEpoch,
    );
    if (removed.isNotEmpty && !_disposed) await load();
    return removed.length;
  }

  @override
  Future<({AgentConversation conversation, bool created})> handoff({
    required String handoffId,
    required ConversationSource source,
    required String title,
    required String prompt,
    AgentPermissionMode mode = AgentPermissionMode.ask,
    AgentModelSelection? modelSelection,
  }) => _serialize(() async {
    _checkWritable();
    final result = await client.dispatch(
      bridge.AgentCommand(
        kind: bridge.CommandKind.createHandoff,
        handoff: management.HandoffRequest(
          handoffId: handoffId,
          source: sourceToRust(source),
          title: title,
          prompt: prompt,
          mode: native.ViewPermissionMode.values.byName(mode.name),
          selection: modelSelectionToRust(modelSelection),
        ),
      ),
    );
    final snapshot = result.snapshot;
    if (snapshot == null) throw StateError('Native handoff was not returned.');
    ingestSnapshot(snapshot);
    _selectedId = result.selection?.selectedId ?? snapshot.conversation.id;
    _visible.putIfAbsent(
      snapshot.conversation.id,
      () => List.unmodifiable(find(snapshot.conversation.id)!.messages),
    );
    _notify();
    return (
      conversation: find(snapshot.conversation.id)!,
      created: result.created ?? false,
    );
  });

  Future<T> _serialize<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  @override
  Future<void> waitForPendingWrites() => _tail;

  void setMaintenance(bool value) {
    _maintenance = value;
    _notify();
  }

  void invalidateAfterDataBoundary() {
    _generation++;
    for (final id in _views.keys.toList()) {
      _forget(id);
    }
    _selectedId = null;
    _loaded = false;
    _notify();
  }

  int _pageStart(List<ConversationMessage> messages, int end) {
    final start = math.max(0, end - _pageSize);
    if (start >= messages.length) return start;
    final call = messages[start].toolCallId;
    if (call == null) return start;
    final owner = messages.indexWhere(
      (message) => message.toolCalls.any((tool) => tool.id == call),
    );
    return owner < 0 ? start : owner;
  }

  void _forget(String id) {
    _views.remove(id);
    _sequence.remove(id);
    _draftIds.remove(id);
    _details.remove(id);
    _full.remove(id);
    _visible.remove(id);
    _before.remove(id);
    _handoffs.removeWhere((_, handoff) => handoff.conversationId == id);
  }

  void _event(bridge.AgentEvent event) {
    if (_disposed) return;
    if (event.kind == bridge.EventKind.resync) {
      // Selection, deletion and pruning request an ordinary refresh. Clearing
      // here invalidates the in-flight command's page and lets it return with
      // an empty transcript. Restore and clear use the explicit data boundary.
      unawaited(
        load().catchError(
          (Object error, StackTrace stack) => _eventError(error, stack),
        ),
      );
    } else if (event.snapshot case final snapshot?) {
      ingestSnapshot(snapshot);
    }
  }

  void _eventError(Object error, StackTrace stack) {
    _blocked = true;
    _notify();
  }

  void _checkWritable() {
    if (!canWrite) throw StateError('Conversation storage is unavailable.');
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
