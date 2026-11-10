import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../application/operation_contracts.dart';

import '../../models/agent_settings.dart';
import '../conversations/conversation_view_repository.dart';
import '../conversations/conversation_browse_repository.dart';
import '../history/conversation_history.dart';
import '../references/agent_composer_reference.dart';
import 'conversation_projection.dart';
import 'generated/api/contracts.dart' as bridge;
import 'generated/api/management_contracts.dart' as management;
import 'generated/api/models.dart' as native;
import 'rust_agent_client.dart';

/// Caches native projections and sends explicit editing commands.
class RustConversationRepository extends ChangeNotifier
    implements ConversationViewRepository, ConversationBrowseRepository {
  RustConversationRepository(this.client, {int pageSize = 50})
    : _pageSize = pageSize {
    if (pageSize < 1) throw ArgumentError.value(pageSize, 'pageSize');
    _subscription = client.events.listen(_event, onError: _eventError);
  }

  final AgentRustClient client;
  final int _pageSize;
  final _views = <String, AgentConversation>{};
  final _sequence = <String, int>{};
  final _conversationEpochs = <String, int>{};
  final _draftIds = <String>{};
  final _states = <String, native.ViewConversationState>{};
  final _pages = <String, native.ViewConversationPage>{};
  final _interactions = <String, native.ViewInteractionDetails>{};
  final _owners = <Object, String>{};
  final _anchors = <String, String>{};
  final _windowSizes = <String, int>{};
  final _refreshing = <String, Future<void>>{};
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
  bool isConversationLoaded(String id) => false;
  @override
  List<ConversationMessage> visibleMessages(String id) =>
      _views[id]?.messages ?? const [];
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

  void ingestState(native.ViewConversationState state) {
    if (_disposed ||
        (_states[state.conversation.id]?.sequence ?? -1) > state.sequence) {
      return;
    }
    final id = state.conversation.id;
    _states[id] = state;
    _sequence[id] = state.sequence;
    _publish(id);
    _notify();
    if (_isVisible(id) && _pages[id]?.sequence != state.sequence) {
      unawaited(_refreshVisible(id).catchError(_eventError));
    }
  }

  void _publish(String id) {
    final state = _states[id];
    if (state == null) return;
    _views[id] = conversationStateFromRust(
      state,
      page: _pages[id],
      interaction: _interactions[id],
    );
    if (state.conversation.draftOnly) {
      _draftIds.add(id);
    } else {
      _draftIds.remove(id);
    }
    _handoffs.removeWhere((_, handoff) => handoff.conversationId == id);
    for (final handoff
        in _pages[id]?.handoffs ?? <management.ViewConversationHandoff>[]) {
      _handoffs[handoff.id] = handoffFromRust(handoff);
    }
  }

  bool _isVisible(String id) => _owners.containsValue(id);

  native.ViewConversationState? stateFor(String id) => _states[id];
  native.ViewInteractionDetails? interactionFor(String id) => _interactions[id];

  Future<AgentConversation> refresh(
    String id, {
    bool interaction = false,
  }) async {
    final generation = _generation;
    final conversationEpoch = _conversationEpochs[id] ?? 0;
    final result = await client.query(
      bridge.AgentQuery(
        kind: interaction
            ? bridge.QueryKind.interactionDetails
            : bridge.QueryKind.conversationState,
        conversationId: id,
      ),
    );
    if (_disposed ||
        generation != _generation ||
        conversationEpoch != (_conversationEpochs[id] ?? 0)) {
      throw StateError('Conversation data changed.');
    }
    final state = result.state;
    if (state == null) throw StateError('Conversation does not exist.');
    if (interaction && (_states[id]?.sequence ?? -1) > state.sequence) {
      return refresh(id, interaction: true);
    }
    if (interaction && result.interactionDetails != null && _isVisible(id)) {
      _interactions[id] = result.interactionDetails!;
    }
    ingestState(state);
    if (interaction && !_isVisible(id)) {
      return conversationStateFromRust(
        state,
        interaction: result.interactionDetails,
      );
    }
    return _views[id]!;
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
      if (_selectedId case final id?) await refresh(id);
      _loaded = true;
      _blocked = false;
      _notify();
    } catch (_) {
      if (_disposed || generation != _generation) return;
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
    await refresh(id);
    if (_isVisible(id)) await _refreshVisible(id);
    _notify();
  });

  @override
  Future<AgentConversation> read(String id) => _serialize(() => _read(id));

  Future<AgentConversation> _read(String id) async {
    final generation = _generation;
    final conversationEpoch = _conversationEpochs[id] ?? 0;
    final result = await client.query(
      bridge.AgentQuery(
        kind: bridge.QueryKind.readConversation,
        conversationId: id,
      ),
    );
    if (_disposed ||
        generation != _generation ||
        conversationEpoch != (_conversationEpochs[id] ?? 0)) {
      throw StateError('Conversation data changed.');
    }
    final snapshot = result.snapshot;
    if (snapshot == null) throw StateError('Conversation does not exist.');
    return conversationFromRust(snapshot);
  }

  Future<void> _refreshVisible(String id, {bool earlier = false}) {
    final existing = _refreshing[id];
    if (existing != null) {
      return earlier
          ? existing.then((_) => _refreshVisible(id, earlier: true))
          : existing;
    }
    late final Future<void> request;
    request = _readVisible(id, earlier: earlier).whenComplete(() {
      if (identical(_refreshing[id], request)) {
        unawaited(_refreshing.remove(id));
      }
    });
    _refreshing[id] = request;
    return request;
  }

  Future<void> _readVisible(String id, {required bool earlier}) async {
    final generation = _generation;
    final conversationEpoch = _conversationEpochs[id] ?? 0;
    bool current() =>
        !_disposed &&
        generation == _generation &&
        conversationEpoch == (_conversationEpochs[id] ?? 0) &&
        _isVisible(id);
    if (!current()) return;
    try {
      var anchor = _anchors[id];
      if (earlier && anchor != null && hasEarlierMessages(id)) {
        final older = await client.query(
          bridge.AgentQuery(
            kind: bridge.QueryKind.conversationPage,
            conversationId: id,
            beforeMessageId: anchor,
            limit: _pageSize,
          ),
        );
        if (!current()) return;
        anchor = older.page?.messages.firstOrNull?.id ?? anchor;
      }
      while (current()) {
        final result = await client.query(
          bridge.AgentQuery(
            kind: bridge.QueryKind.conversationPage,
            conversationId: id,
            fromMessageId: anchor,
            limit: _windowSizes[id] ?? _pageSize,
          ),
        );
        if (!current()) return;
        var state = result.state;
        final page = result.page;
        if (state == null || page == null) {
          throw StateError('Conversation does not exist.');
        }
        if ((_states[id]?.sequence ?? -1) > page.sequence) continue;
        native.ViewInteractionDetails? interaction;
        if (state.question != null ||
            state.planRevision != null ||
            state.pendingOperations.isNotEmpty ||
            state.pendingRedos.isNotEmpty) {
          final details = await client.query(
            bridge.AgentQuery(
              kind: bridge.QueryKind.interactionDetails,
              conversationId: id,
            ),
          );
          if (!current()) return;
          if (details.state == null || details.interactionDetails == null) {
            throw StateError('Conversation interaction is unavailable.');
          }
          state = details.state!;
          interaction = details.interactionDetails;
          if (state.sequence != page.sequence ||
              (_states[id]?.sequence ?? -1) > page.sequence) {
            continue;
          }
        }
        _states[id] = state;
        _sequence[id] = state.sequence;
        _pages[id] = page;
        if (interaction == null) {
          _interactions.remove(id);
        } else {
          _interactions[id] = interaction;
        }
        final first = page.messages.firstOrNull?.id;
        if (first == null) {
          _anchors.remove(id);
        } else {
          _anchors[id] = first;
        }
        _windowSizes[id] = page.messages.length < _pageSize
            ? _pageSize
            : page.messages.length;
        _before[id] = page.nextOffset;
        _publish(id);
        _notify();
        return;
      }
    } catch (_) {
      if (current()) rethrow;
    }
  }

  @override
  Future<void> setViewActive(Object owner, String? id) async {
    final previous = _owners.remove(owner);
    if (id != null) _owners[owner] = id;
    if (previous != null && !_isVisible(previous)) {
      _pages.remove(previous);
      _interactions.remove(previous);
      _publish(previous);
      _notify();
    }
    if (id != null) await _refreshVisible(id);
  }

  @override
  Future<void> loadEarlierMessages(String id) =>
      _serialize(() => _refreshVisible(id, earlier: true));

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
    final state = result.state;
    if (state == null) throw StateError('Native draft was not returned.');
    ingestState(state);
    _selectedId = result.selection?.selectedId ?? state.conversation.id;
    _notify();
    return find(state.conversation.id)!;
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
    final state = result.state;
    if (state == null) {
      throw StateError('Native conversation was not returned.');
    }
    ingestState(state);
    _selectedId = result.selection?.selectedId ?? id;
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
    sourceBodyId: source.id,
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
    String? sourceBodyId,
  }) => _serialize(() async {
    _checkWritable();
    final id = command.conversationId!;
    var current = find(id);
    if (current == null) throw StateError('Conversation does not exist.');
    if (sourceBodyId != null) {
      final source = await readSource(id, sourceBodyId);
      if (source != null) {
        current = current.copyWith(
          sources: [
            ...current.sources.where((item) => item.id != source.id),
            source,
          ],
        );
      }
    }
    validate?.call(current);
    final result = await client.dispatch(command);
    if (result.state case final state?) {
      ingestState(state);
      return find(id)!;
    }
    return refresh(id);
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
    if (_selectedId case final selected?) await refresh(selected);
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
    final state = result.state;
    if (state == null) throw StateError('Native handoff was not returned.');
    ingestState(state);
    _selectedId = result.selection?.selectedId ?? state.conversation.id;
    _notify();
    return (
      conversation: find(state.conversation.id)!,
      created: result.created ?? false,
    );
  });

  @override
  int conversationRevision(String id) => _states[id]?.sequence ?? 0;

  @override
  bool hasVisiblePage(String id) => _pages.containsKey(id);

  @override
  Object historyRevision(String id) => (
    _generation,
    _states[id]?.historyVersionCount,
    _states[id]?.replyRevisionCount,
  );

  @override
  bool hasMessageHistory(String id) =>
      (_states[id]?.historyVersionCount ?? 0) > 0 ||
      (_states[id]?.replyRevisionCount ?? 0) > 0;

  @override
  List<ConversationHistoryEntry> replyVersions(String id, String messageId) => [
    for (final revision
        in _pages[id]?.replyRevisions ?? <native.ViewReplyRevisionSummary>[])
      if (revision.messageId == messageId)
        ConversationHistoryEntry(
          id: revision.id,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            revision.createdAt,
            isUtc: true,
          ),
          messageCount: 1,
          messageId: messageId,
        ),
  ];

  Future<bridge.QueryResult> _detail(bridge.AgentQuery query) async {
    final generation = _generation;
    final conversationEpoch = _conversationEpochs[query.conversationId] ?? 0;
    final result = await client.query(query);
    if (_disposed ||
        generation != _generation ||
        conversationEpoch != (_conversationEpochs[query.conversationId] ?? 0)) {
      throw StateError('Conversation data changed.');
    }
    return result;
  }

  @override
  Future<ConversationMessage?> readMessage(String id, String messageId) async {
    final result = await _detail(
      bridge.AgentQuery(
        kind: bridge.QueryKind.message,
        conversationId: id,
        targetId: messageId,
      ),
    );
    return result.message == null
        ? null
        : conversationMessageFromRust(result.message!);
  }

  @override
  Future<ConversationSource?> readSource(String id, String sourceId) async {
    final result = await _detail(
      bridge.AgentQuery(
        kind: bridge.QueryKind.source,
        conversationId: id,
        targetId: sourceId,
      ),
    );
    return result.source == null ? null : sourceFromRust(result.source!);
  }

  @override
  Future<ConversationReplyRevision?> readReplyVersion(
    String id,
    String revisionId,
  ) async {
    final result = await _detail(
      bridge.AgentQuery(
        kind: bridge.QueryKind.replyRevision,
        conversationId: id,
        targetId: revisionId,
      ),
    );
    return result.replyRevision == null
        ? null
        : replyRevisionFromRust(result.replyRevision!);
  }

  @override
  Future<ConversationRunUsage?> readRun(
    String id,
    String runId, {
    String? versionId,
  }) async {
    final result = await _detail(
      bridge.AgentQuery(
        kind: versionId == null
            ? bridge.QueryKind.run
            : bridge.QueryKind.historyRun,
        conversationId: id,
        targetId: runId,
        versionId: versionId,
      ),
    );
    return result.run == null ? null : runFromRust(result.run!);
  }

  @override
  Future<ConversationHistoryCatalogPage> readHistoryCatalog(
    String id, {
    required bool replies,
    int offset = 0,
  }) async {
    final result = await _detail(
      bridge.AgentQuery(
        kind: replies
            ? bridge.QueryKind.replyRevisions
            : bridge.QueryKind.historyVersions,
        conversationId: id,
        offset: offset,
        limit: _pageSize,
      ),
    );
    return ConversationHistoryCatalogPage(
      entries: [
        if (replies)
          for (final revision in result.replyRevisions)
            ConversationHistoryEntry(
              id: revision.id,
              createdAt: DateTime.fromMillisecondsSinceEpoch(
                revision.createdAt,
                isUtc: true,
              ),
              messageCount: 1,
              messageId: revision.messageId,
            )
        else
          for (final version in result.historyVersions)
            ConversationHistoryEntry(
              id: version.id,
              createdAt: DateTime.fromMillisecondsSinceEpoch(
                version.createdAt,
                isUtc: true,
              ),
              messageCount: version.messageCount,
            ),
      ],
      nextOffset: result.nextOffset,
    );
  }

  @override
  Future<ConversationHistoryPage> readHistoryPage(
    String id,
    String versionId, {
    String? beforeMessageId,
  }) async {
    final result = await _detail(
      bridge.AgentQuery(
        kind: bridge.QueryKind.historyVersionPage,
        conversationId: id,
        targetId: versionId,
        beforeMessageId: beforeMessageId,
        limit: _pageSize,
      ),
    );
    final page = result.historyPage?.page;
    if (page == null) {
      throw StateError('Conversation history no longer exists.');
    }
    return ConversationHistoryPage(
      messages: page.messages
          .map(conversationMessageFromRust)
          .toList(growable: false),
      attachments: page.attachments
          .map(attachmentFromRust)
          .toList(growable: false),
      nextBeforeMessageId: page.nextOffset == null
          ? null
          : page.messages.firstOrNull?.id,
    );
  }

  Future<T> _serialize<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  @override
  Future<void> waitForPendingWrites() async {
    await _tail;
    while (_refreshing.isNotEmpty) {
      await Future.wait(_refreshing.values.toList());
    }
  }

  void setMaintenance(bool value) {
    _maintenance = value;
    _notify();
  }

  void invalidateAfterDataBoundary() {
    _generation++;
    _refreshing.clear();
    for (final id in _views.keys.toList()) {
      _forget(id);
    }
    _selectedId = null;
    _loaded = false;
    _notify();
  }

  void _forget(String id) {
    _conversationEpochs.update(id, (value) => value + 1, ifAbsent: () => 1);
    _owners.removeWhere((_, conversationId) => conversationId == id);
    unawaited(_refreshing.remove(id));
    _views.remove(id);
    _sequence.remove(id);
    _draftIds.remove(id);
    _states.remove(id);
    _pages.remove(id);
    _interactions.remove(id);
    _anchors.remove(id);
    _windowSizes.remove(id);
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
    } else if (event.state case final state?) {
      ingestState(state);
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
