import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../application/operation_contracts.dart';
import '../../models/agent_settings.dart';
import '../references/agent_composer_reference.dart';
import '../history/conversation_history.dart';
import 'conversation_models.dart';
import 'conversation_storage.dart';

export 'conversation_models.dart';
export 'conversation_storage.dart';

class ConversationRepository extends ChangeNotifier {
  ConversationRepository({
    ConversationStorage? storage,
    DateTime Function()? clock,
    String Function()? idGenerator,
  }) : _storage = storage ?? ConversationStorage(),
       _clock = clock ?? DateTime.now,
       _id = idGenerator ?? _randomId;

  final ConversationStorage _storage;
  final DateTime Function() _clock;
  final String Function() _id;
  ConversationArchive _archive = ConversationArchive();
  final Set<String> _unloadedIds = {};
  final _visibleMessages = <String, List<ConversationMessage>>{};
  final _visibleStarts = <String, int>{};
  final _turnIndexes = <String, List<ConversationTurn>>{};
  AgentConversation? _draftConversation;
  bool _draftSelected = false;
  Future<void> _tail = Future<void>.value();
  final _deleting = <String>{};
  bool _loaded = false;
  bool _blocked = false;
  bool _disposed = false;
  bool _frozen = false;
  final _shutdownRunIds = <String>{};
  bool recovered = false;
  static final _historyZoneKey = Object();
  String? _historyOwner;

  bool get isLoaded => _loaded;
  bool get isArchiveLoaded => _loaded && _unloadedIds.isEmpty;
  bool get supportsRestoreMarkers => _storage is StructuredConversationStorage;
  Future<int> readStorageRevision() =>
      (_storage as StructuredConversationStorage).readRevision();
  Future<String?> readRestoreMarker(String restoreId) =>
      (_storage as StructuredConversationStorage).readRestoreMarker(restoreId);
  bool get blocked => _blocked;
  bool get canWrite =>
      _loaded && !_blocked && !_frozen && !_disposed && _historyOwner == null;

  Future<String?> pendingHistoryBatch() => _storage.pendingHistoryBatch();
  Future<void> writePendingHistoryBatch(String? value) =>
      _storage.writePendingHistoryBatch(value);

  Future<void> reserveHistoryUndo(String batchId) async {
    if (_historyOwner != null && _historyOwner != batchId) {
      throw const ConversationStorageException(
        'Another history batch owns storage.',
      );
    }
    _historyOwner = batchId;
    await _tail;
    _notify();
  }

  Future<T> withHistoryUndo<T>(String batchId, Future<T> Function() action) {
    if (_historyOwner != batchId) {
      throw const ConversationStorageException('History reservation is stale.');
    }
    return runZoned(action, zoneValues: {_historyZoneKey: batchId});
  }

  void releaseHistoryUndo(String batchId) {
    if (_historyOwner != batchId) {
      throw const ConversationStorageException('History reservation is stale.');
    }
    _historyOwner = null;
    _notify();
  }

  /// Validates eventual publication before any participant changes live data.
  void validateHistoryCandidate(AgentConversation candidate) {
    AgentConversation.fromJson(candidate.toJson());
  }

  /// A failed clear may have removed some files. Explicit load/recovery must
  /// establish the surviving archive before any in-memory content can be saved.
  void resumeAfterFailedDataClear() {
    if (_disposed) return;
    _discardDraft();
    _frozen = false;
    _blocked = true;
    _notify();
  }

  /// Restore/clear owners call this after draining old work at a real data
  /// boundary. Ordinary navigation, settings and backup reads retain input.
  void discardDraftAfterDataBoundary() {
    if (_disposed || _draftConversation == null) return;
    _discardDraft();
    _notify();
  }

  String? get selectedId =>
      _draftSelected ? _draftConversation?.id : _archive.selectedId;

  /// Durable history only. Unsent conversations do not appear in exports,
  /// backups, management tools or the history sidebar.
  List<AgentConversation> get conversations => _archive.conversations;

  /// The application also owns one unsent conversation for this repository's
  /// lifetime. Runtime state and attachment collection include that draft.
  List<AgentConversation> get ownedConversations =>
      List.unmodifiable([...conversations, ?_draftConversation]);
  AgentConversation? get draftConversation => _draftConversation;
  bool isDraft(String? id) => id != null && _draftConversation?.id == id;
  AgentConversation? get selected => find(selectedId);

  /// Only local handoff records bind an original request to its source digest.
  /// Portable history and source metadata alone cannot manufacture this link.
  ConversationHandoff? handoffForMessage(
    String conversationId,
    String? messageId,
  ) {
    final matches = _archive.handoffs
        .where(
          (handoff) =>
              handoff.conversationId == conversationId &&
              handoff.messageId == messageId,
        )
        .toList();
    return matches.length == 1 ? matches.single : null;
  }

  AgentConversation? find(String? id) => isDraft(id)
      ? _draftConversation
      : conversations
            .where((conversation) => conversation.id == id)
            .firstOrNull;

  bool isConversationLoaded(String id) => !_unloadedIds.contains(id);

  List<ConversationMessage> visibleMessages(String id) {
    final current = find(id);
    if (current == null) return const [];
    if (!_visibleMessages.containsKey(id)) {
      if (_unloadedIds.contains(id)) return const [];
      _refreshVisibleWindow(current);
    }
    return _visibleMessages[id]!;
  }

  List<ConversationTurn> visibleTurns(String id) =>
      _turnIndexes[id] ?? find(id)?.turns ?? const [];
  bool hasEarlierMessages(String id) => (_visibleStarts[id] ?? 0) > 0;

  Future<void> loadEarlierMessages(String id) => _enqueue(() async {
    await _ensureConversationPage(id);
    final start = _visibleStarts[id] ?? 0;
    if (start == 0) return;
    final current = _requireConversation(id);
    if (!_unloadedIds.contains(id)) {
      _refreshVisibleWindow(
        current,
        start: _groupStart(current.messages, start > 50 ? start - 50 : 0),
      );
    } else {
      final page = await (_storage as StructuredConversationStorage).readPage(
        id,
        before: start,
      );
      final messages = List<ConversationMessage>.unmodifiable([
        ...page.conversation.messages,
        ...visibleMessages(id),
      ]);
      final attachments = {
        for (final item in [
          ...page.conversation.attachments,
          ...current.attachments,
        ])
          item.id: item,
      };
      final view = current.copyWith(
        messages: messages,
        attachments: attachments.values,
        executionHistoryStart: current.executionHistoryStart > 0
            ? page.conversation.messages.length + current.executionHistoryStart
            : page.conversation.executionHistoryStart,
      );
      _replaceCachedConversation(view);
      _visibleStarts[id] = page.start;
      _visibleMessages[id] = messages;
      _turnIndexes[id] ??= page.turns;
    }
    _notify();
  });

  static int _groupStart(List<ConversationMessage> messages, int target) {
    if (messages.isEmpty) return 0;
    var start = target < 0
        ? 0
        : (target < messages.length ? target : messages.length - 1);
    while (start > 0 && messages[start].role != ConversationRole.user) {
      start--;
    }
    return start;
  }

  void _refreshVisibleWindow(AgentConversation current, {int? start}) {
    final previous = _visibleMessages[current.id];
    final anchor = previous?.firstOrNull?.id;
    final oldStart = _visibleStarts[current.id] ?? -1;
    final retained = anchor == null
        ? -1
        : (oldStart >= 0 &&
                  oldStart < current.messages.length &&
                  current.messages[oldStart].id == anchor
              ? oldStart
              : current.messages.indexWhere((item) => item.id == anchor));
    final index =
        start ??
        (retained >= 0
            ? retained
            : _groupStart(current.messages, current.messages.length - 50));
    final messages = current.messages.sublist(index);
    _visibleStarts[current.id] = index;
    if (previous == null || !listEquals(previous, messages)) {
      _visibleMessages[current.id] = List.unmodifiable(messages);
    }
    _turnIndexes[current.id] = current.turns;
  }

  void _replaceCachedConversation(AgentConversation value) {
    _archive = ConversationArchive(
      revision: _archive.revision,
      selectedId: _archive.selectedId,
      conversations: [
        for (final item in conversations)
          if (item.id == value.id) value else item,
      ],
      handoffs: _archive.handoffs,
      terminatedIds: _archive.terminatedIds,
    );
  }

  Future<void> _ensureConversationPage(String id) async {
    if (_visibleMessages.containsKey(id)) return;
    if (!_unloadedIds.contains(id)) {
      _refreshVisibleWindow(_requireConversation(id));
      return;
    }
    final page = await (_storage as StructuredConversationStorage).readPage(id);
    _replaceCachedConversation(page.conversation);
    _visibleMessages[id] = page.conversation.messages;
    _visibleStarts[id] = page.start;
    _turnIndexes[id] = page.turns;
  }

  /// Loads one transcript on demand. History lists can use metadata without
  /// fetching every other conversation's messages and protocol payloads.
  Future<AgentConversation> read(String id) => _enqueue(() async {
    await _ensureConversationLoaded(id);
    _notify();
    return _requireConversation(id);
  });

  Future<ConversationStatistics> statistics(String id) => _enqueue(() async {
    final current = _requireConversation(id);
    if (_unloadedIds.contains(id)) {
      return (_storage as StructuredConversationStorage).readStatistics(id);
    }
    return ConversationStatistics.fromConversation(current);
  });

  Future<List<AgentConversation>> readAll() => _enqueue(() async {
    for (final id in _unloadedIds.toList()) {
      await _ensureConversationLoaded(id);
    }
    return conversations;
  });

  Future<Set<String>> referencedAttachmentIds() => _enqueue(() async {
    final storage = _storage;
    return {
      if (storage is StructuredConversationStorage)
        ...await (storage as StructuredConversationStorage)
            .referencedAttachmentIds()
      else
        for (final conversation in conversations)
          ...conversationAttachmentIds(conversation),
      if (_draftConversation case final draft?)
        ...conversationAttachmentIds(draft),
    };
  });

  Future<void> _ensureConversationLoaded(String id) async {
    if (!_unloadedIds.contains(id)) return;
    final storage = _storage as StructuredConversationStorage;
    final full = await storage.readConversation(id);
    if (full == null) throw StateError('The conversation no longer exists.');
    _replaceCachedConversation(full);
    _unloadedIds.remove(id);
    if (_visibleMessages.containsKey(id) || id == selectedId) {
      _refreshVisibleWindow(full);
    }
  }

  Future<ConversationStorageLoad> _readCurrentView() async {
    final storage = _storage;
    final index = storage is StructuredConversationStorage
        ? await (storage as StructuredConversationStorage).readIndex()
        : null;
    final result = index == null
        ? await storage.load()
        : ConversationStorageLoad(archive: index.archive);
    _unloadedIds.clear();
    _visibleMessages.clear();
    _visibleStarts.clear();
    _turnIndexes.clear();
    if (index == null) return result;
    _unloadedIds.addAll(index.unloadedIds);
    for (final entry in index.pages.entries) {
      _visibleMessages[entry.key] = entry.value.conversation.messages;
      _visibleStarts[entry.key] = entry.value.start;
      _turnIndexes[entry.key] = entry.value.turns;
    }
    return result;
  }

  Future<void> refreshFrozenView({required void Function() validateOwner}) =>
      _enqueue(() async {
        if (!_frozen || _disposed) {
          throw StateError('Restore refresh requires frozen storage.');
        }
        validateOwner();
        final result = await _readCurrentView();
        validateOwner();
        _archive =
            result.archive ??
            (result.source == null
                ? ConversationArchive()
                : ConversationArchive.decode(result.source!));
        _loaded = true;
        _blocked = false;
        recovered = result.recovered;
        _notify();
      });

  Future<void> load() => _enqueue(() async {
    if (_disposed || _frozen) {
      throw StateError('Conversation storage is closed.');
    }
    try {
      final result = await _readCurrentView();
      final next =
          result.archive ??
          (result.source == null
              ? ConversationArchive()
              : ConversationArchive.decode(result.source!));
      _archive = next;
      _reconcileDraft();
      _loaded = true;
      _blocked = false;
      recovered = result.recovered;
      final interrupted = next.conversations.map((item) {
        final interruptedRun = item.runs.any(
          (run) => run.status == ConversationRunStatus.running,
        );
        final interruptedAttachment = item.messages.any(
          (message) =>
              message.attachmentDelivery == AttachmentDelivery.preparing ||
              message.attachmentDelivery == AttachmentDelivery.sending,
        );
        return item.status == ConversationStatus.running ||
                item.status == ConversationStatus.waitingApproval ||
                item.status == ConversationStatus.waitingUser ||
                interruptedRun ||
                interruptedAttachment
            ? item.copyWith(
                status: ConversationStatus.interrupted,
                messages: item.messages.map(
                  (message) =>
                      message.attachmentDelivery ==
                              AttachmentDelivery.preparing ||
                          message.attachmentDelivery ==
                              AttachmentDelivery.sending
                      ? message.copyWith(
                          attachmentDelivery: AttachmentDelivery.unknown,
                        )
                      : message,
                ),
                runs: item.runs.map(
                  (run) => run.status == ConversationRunStatus.running
                      ? run.interrupt()
                      : run,
                ),
              )
            : item;
      }).toList();
      if (interrupted.asMap().entries.any(
        (entry) => !identical(entry.value, next.conversations[entry.key]),
      )) {
        await _save(_next(conversations: interrupted));
      }
      _notify();
    } catch (_) {
      _blocked = true;
      _notify();
      rethrow;
    }
  });

  Future<AgentConversation> create({
    required String title,
    bool titleWasEdited = false,
    AgentPermissionMode mode = AgentPermissionMode.ask,
    AgentModelSelection? modelSelection,
    String? id,
    void Function()? validate,
  }) => _enqueue(() async {
    _checkWritable();
    validate?.call();
    final conversation = _newConversation(
      title,
      mode,
      id: id,
      modelSelection: modelSelection,
      titleWasEdited: titleWasEdited,
    );
    await _save(
      _next(
        conversations: [...conversations, conversation],
        selectedId: conversation.id,
      ),
      selectDurable: true,
    );
    return conversation;
  });

  /// Opening New chat is an in-memory action. Repeated clicks reuse its unsent
  /// input; selecting saved history or another workspace does not discard it.
  /// The first accepted user message promotes it in the runtime's normal save.
  Future<AgentConversation> createDraft({
    required String title,
    AgentPermissionMode mode = AgentPermissionMode.ask,
    AgentModelSelection? modelSelection,
    String? id,
    void Function()? validate,
  }) => _enqueue(() async {
    _checkWritable();
    validate?.call();
    final draft =
        _draftConversation ??
        _newConversation(title, mode, id: id, modelSelection: modelSelection);
    _validateDraft(draft);
    _draftConversation = draft;
    _draftSelected = true;
    _notify();
    return draft;
  });

  Future<void> select(String id) => _enqueue(() async {
    _checkWritable();
    await _ensureConversationPage(id);
    _requireConversation(id);
    if (isDraft(id)) {
      if (!_draftSelected) {
        _draftSelected = true;
        _notify();
      }
      return;
    }
    if (_archive.selectedId != id) {
      await _save(_next(selectedId: id), selectDurable: true);
    } else if (_draftSelected) {
      _draftSelected = false;
      _notify();
    }
  });

  /// Retention removes only completed, inactive conversations. Tombstones keep
  /// old handoffs and late callbacks from recreating their content.
  Future<int> pruneHistory({
    required int days,
    required bool Function(String id) canRemove,
  }) => _enqueue(() async {
    _checkWritable();
    if (days == 0) return 0;
    if (days < 0) {
      throw const FormatException('History retention must not be negative.');
    }
    final now = _clock().toUtc();
    bool hasExpired(DateTime updatedAt) {
      final elapsed = now.difference(updatedAt);
      return elapsed.inDays > days ||
          (elapsed.inDays == days &&
              elapsed.inMicroseconds.remainder(Duration.microsecondsPerDay) >
                  0);
    }

    final removed = conversations
        .where(
          (item) =>
              !item.pinned &&
              item.status == ConversationStatus.idle &&
              item.pendingRedo == null &&
              item.pendingQuestion == null &&
              item.queuedInputs.isEmpty &&
              !item.hasPendingControls &&
              item.draft.isEmpty &&
              item.draftAttachmentIds.isEmpty &&
              item.draftReferences.isEmpty &&
              hasExpired(item.updatedAt) &&
              canRemove(item.id),
        )
        .map((item) => item.id)
        .toSet();
    if (removed.isEmpty) return 0;
    final replacementId = removed.contains(_archive.selectedId)
        ? conversations
              .where((item) => !removed.contains(item.id))
              .lastOrNull
              ?.id
        : _archive.selectedId;
    if (replacementId != null) await _ensureConversationPage(replacementId);
    final remaining = conversations
        .where((item) => !removed.contains(item.id))
        .toList();
    await _save(
      ConversationArchive(
        revision: _archive.revision + 1,
        selectedId: replacementId,
        conversations: remaining,
        handoffs: _archive.handoffs,
        terminatedIds: {..._archive.terminatedIds, ...removed},
      ),
    );
    return removed.length;
  });

  Future<AgentConversation> update(
    String id,
    AgentConversation Function(AgentConversation current) transform, {
    String? expectedRunId,
  }) => _update(id, transform, expectedRunId: expectedRunId);

  Future<AgentConversation> setPinned(String id, bool pinned) =>
      _update(id, (current) {
        if (isDraft(id)) {
          throw const OperationProblem(
            OperationErrorCode.invalidArgument,
            'Only saved conversations can be pinned.',
          );
        }
        return current.copyWith(pinned: pinned);
      }, updateTimestamp: false);

  Future<AgentConversation> _update(
    String id,
    AgentConversation Function(AgentConversation current) transform, {
    String? expectedRunId,
    bool updateTimestamp = true,
  }) => _enqueue(() async {
    _checkWritable(expectedRunId: expectedRunId);
    await _ensureConversationLoaded(id);
    final current = _requireConversation(id);
    if (expectedRunId != null && current.runId != expectedRunId) {
      throw const OperationProblem(
        OperationErrorCode.expired,
        'This conversation run is no longer current.',
      );
    }
    final transformed = transform(current);
    final next = updateTimestamp
        ? transformed.withUpdatedAt(_clock().toUtc())
        : transformed;
    if (_frozen) _validateShutdownRunUpdate(current, next, expectedRunId!);
    if (next.id != current.id || next.createdAt != current.createdAt) {
      throw const OperationProblem(
        OperationErrorCode.invalidArgument,
        'Conversation identity cannot be changed.',
      );
    }
    if (isDraft(id)) {
      if (next.messages.isEmpty) {
        _validateDraft(next);
        _draftConversation = next;
        _notify();
        return next;
      }
      if (!next.messages.any(
        (message) => message.role == ConversationRole.user,
      )) {
        throw const OperationProblem(
          OperationErrorCode.invalidArgument,
          'An unsent conversation must begin with an accepted user message.',
        );
      }
      await _save(
        _next(
          conversations: [...conversations, next],
          selectedId: _draftSelected ? next.id : _archive.selectedId,
        ),
      );
      return next;
    }
    await _save(
      _next(
        conversations: [
          for (final item in conversations)
            if (item.id == id) next else item,
        ],
      ),
    );
    return next;
  });

  Future<AgentConversation> updateDraftReferences(
    String id,
    Iterable<AgentComposerReference> references, {
    void Function(AgentConversation current)? validate,
  }) async {
    final frozen = AgentComposerReference.validatedList(references);
    return update(id, (current) {
      validate?.call(current);
      final attachmentIds = <String>{
        ...current.draftAttachmentIds,
        for (final reference in frozen)
          if (reference.kind == AgentComposerReferenceKind.attachment)
            reference.attachmentId!,
      };
      return current.copyWith(
        draftReferences: frozen,
        draftAttachmentIds: attachmentIds,
      );
    });
  }

  /// Callers cancel network/operation scopes as soon as deletion is requested.
  /// The tombstone and removal of all owned content are one persisted update.
  Future<void> delete(String id, {void Function(AgentConversation)? validate}) {
    _deleting.add(id);
    return _enqueue(() async {
      try {
        _checkWritable();
        if (_archive.terminatedIds.contains(id)) return;
        await _ensureConversationLoaded(id);
        if (find(id) == null) {
          throw const OperationProblem(
            OperationErrorCode.notFound,
            'Conversation does not exist.',
          );
        }
        validate?.call(find(id)!);
        if (isDraft(id)) {
          _discardDraft();
          _notify();
          return;
        }
        if (find(id)!.pendingRedo != null) {
          throw const ConversationStorageException(
            'Finish or cancel the pending history redo before deleting this conversation.',
          );
        }
        final replacementId = _archive.selectedId == id
            ? conversations.where((item) => item.id != id).lastOrNull?.id
            : _archive.selectedId;
        if (replacementId != null) {
          await _ensureConversationPage(replacementId);
        }
        final remaining = conversations.where((item) => item.id != id).toList();
        await _save(
          ConversationArchive(
            revision: _archive.revision + 1,
            selectedId: replacementId,
            conversations: remaining,
            handoffs: _archive.handoffs,
            terminatedIds: {..._archive.terminatedIds, id},
          ),
        );
      } finally {
        _deleting.remove(id);
      }
    });
  }

  Future<({AgentConversation conversation, bool created})> handoff({
    required String handoffId,
    required ConversationSource source,
    required String title,
    required String prompt,
    AgentPermissionMode mode = AgentPermissionMode.ask,
    AgentModelSelection? modelSelection,
  }) => _enqueue(() async {
    _checkWritable();
    final existing = _archive.handoffs
        .where((item) => item.id == handoffId)
        .firstOrNull;
    if (existing != null) {
      if (existing.sourceDigest != source.digest) {
        throw const OperationProblem(
          OperationErrorCode.duplicateMismatch,
          'This handoff ID belongs to different source material.',
        );
      }
      await _ensureConversationLoaded(existing.conversationId);
      final conversation = _requireConversation(existing.conversationId);
      final message = [
        ...conversation.messages,
        ...conversation.historyVersions.expand((version) => version.messages),
      ].where((item) => item.id == existing.messageId).first;
      if (message.text != prompt) {
        throw const OperationProblem(
          OperationErrorCode.duplicateMismatch,
          'This handoff ID belongs to a different request.',
        );
      }
      return (conversation: conversation, created: false);
    }
    final message = ConversationMessage(
      id: _id(),
      role: ConversationRole.user,
      text: prompt,
      createdAt: _clock().toUtc(),
      modelSelection: modelSelection,
    );
    final conversation = _newConversation(
      title,
      mode,
      modelSelection: modelSelection,
    ).copyWith(messages: [message], sources: [source], titleWasEdited: true);
    await _save(
      _next(
        conversations: [...conversations, conversation],
        selectedId: conversation.id,
        handoffs: [
          ..._archive.handoffs,
          ConversationHandoff(
            id: handoffId,
            conversationId: conversation.id,
            sourceDigest: source.digest,
            messageId: message.id,
          ),
        ],
      ),
      selectDurable: true,
    );
    return (conversation: conversation, created: true);
  });

  Future<void> waitForPendingWrites() => _tail;

  /// The application restore owner has drained writes and holds its maintenance
  /// lease. Read actual storage without reopening the ordinary chat write gate.
  Future<ConversationArchive> readFrozenForRestore({
    required void Function() validateOwner,
  }) => _enqueue(() async {
    if (!_frozen || _disposed) {
      throw StateError('Conversation restore requires a frozen repository.');
    }
    validateOwner();
    try {
      final loaded = await _storage.load();
      validateOwner();
      final archive =
          loaded.archive ??
          (loaded.source == null
              ? ConversationArchive()
              : ConversationArchive.decode(loaded.source!));
      _archive = archive;
      _unloadedIds.clear();
      // This is one participant of a larger restore. Keep the volatile input
      // even if an incoming durable chat has the same ID until the owner has
      // confirmed every participant and cleared its recovery journal.
      _loaded = true;
      _blocked = false;
      recovered = loaded.recovered;
      _notify();
      return archive;
    } catch (_) {
      _blocked = true;
      _notify();
      rethrow;
    }
  });

  Future<void> replaceFrozenForRestore(
    ConversationArchive target, {
    required void Function() validateOwner,
    String? restoreId,
    String? restoreFingerprint,
    Iterable<String>? replacedConversationIds,
  }) => _enqueue(() async {
    if (!_frozen || _disposed || !_loaded || _blocked) {
      throw StateError('Conversation restore requires known frozen storage.');
    }
    validateOwner();
    if (target.revision <= _archive.revision &&
        target.encode() != _archive.encode()) {
      throw const ConversationStorageException(
        'The restore target is older than current conversations.',
      );
    }
    try {
      await _save(
        target,
        reconcileDraft: false,
        restoreId: restoreId,
        restoreFingerprint: restoreFingerprint,
        replacedConversationIds: replacedConversationIds,
      );
      _unloadedIds.clear();
      validateOwner();
    } catch (_) {
      _blocked = true;
      _notify();
      rethrow;
    }
  });

  void resumeAfterMaintenance() {
    if (_disposed) return;
    _frozen = false;
    _notify();
  }

  /// Closing may finish only the host's already accepted runs. Clear/dispose
  /// pass no run IDs and remain a hard boundary against every later write.
  void freeze({Iterable<String> completingRunIds = const []}) {
    _frozen = true;
    _shutdownRunIds
      ..clear()
      ..addAll(completingRunIds);
  }

  void finishShutdownRun(String runId) => _shutdownRunIds.remove(runId);

  void _validateShutdownRunUpdate(
    AgentConversation current,
    AgentConversation next,
    String runId,
  ) {
    Map<String, Object?> fixedFields(AgentConversation value) => value.toJson()
      ..removeWhere(
        (key, _) => const {
          'updatedAt',
          'status',
          'messages',
          'runs',
          'turns',
        }.contains(key),
      );
    final runIds = current.runs.map((run) => run.id).toList();
    final otherRuns = current.runs
        .where((run) => run.id != runId)
        .map((run) => run.toJson())
        .toList();
    if (jsonEncode(fixedFields(current)) != jsonEncode(fixedFields(next)) ||
        jsonEncode(runIds) !=
            jsonEncode(next.runs.map((run) => run.id).toList()) ||
        jsonEncode(otherRuns) !=
            jsonEncode(
              next.runs
                  .where((run) => run.id != runId)
                  .map((run) => run.toJson())
                  .toList(),
            ) ||
        next.messages.length < current.messages.length) {
      throw const ConversationStorageException(
        'Only accepted run completion may finish during shutdown.',
      );
    }
    for (var index = 0; index < current.messages.length; index++) {
      final before = current.messages[index].toJson()
        ..remove('attachmentDelivery');
      final after = next.messages[index].toJson()..remove('attachmentDelivery');
      if (jsonEncode(before) != jsonEncode(after)) {
        throw const ConversationStorageException(
          'Shutdown cannot edit existing message content.',
        );
      }
    }
    final pendingCalls =
        {
          for (final message in current.messages)
            for (final call in message.toolCalls) call.id,
        }..removeAll(
          current.messages
              .map((message) => message.toolCallId)
              .whereType<String>(),
        );
    for (final message in next.messages.skip(current.messages.length)) {
      if (message.role != ConversationRole.tool ||
          !pendingCalls.remove(message.toolCallId)) {
        throw const ConversationStorageException(
          'Shutdown can only record a pending tool result.',
        );
      }
    }
  }

  AgentConversation _newConversation(
    String title,
    AgentPermissionMode mode, {
    String? id,
    AgentModelSelection? modelSelection,
    bool titleWasEdited = false,
  }) {
    final resolvedId = id ?? _id();
    if (resolvedId.isEmpty || resolvedId.length > 256) {
      throw const OperationProblem(
        OperationErrorCode.invalidArgument,
        'Conversation ID is invalid.',
      );
    }
    if (find(resolvedId) != null ||
        _archive.terminatedIds.contains(resolvedId)) {
      throw const OperationProblem(
        OperationErrorCode.conflict,
        'Conversation ID has already been used.',
      );
    }
    final now = _clock().toUtc();
    return AgentConversation(
      id: resolvedId,
      title: title,
      titleWasEdited: titleWasEdited,
      mode: mode,
      modelSelection: modelSelection,
      createdAt: now,
      updatedAt: now,
    );
  }

  AgentConversation _requireConversation(String id) {
    if (_deleting.contains(id) || _archive.terminatedIds.contains(id)) {
      throw const OperationProblem(
        OperationErrorCode.expired,
        'Conversation has been terminated.',
      );
    }
    return find(id) ??
        (throw const OperationProblem(
          OperationErrorCode.notFound,
          'Conversation does not exist.',
        ));
  }

  ConversationArchive _next({
    Iterable<AgentConversation>? conversations,
    Iterable<ConversationHandoff>? handoffs,
    String? selectedId,
  }) => ConversationArchive(
    revision: _archive.revision + 1,
    conversations: conversations ?? _archive.conversations,
    handoffs: handoffs ?? _archive.handoffs,
    terminatedIds: _archive.terminatedIds,
    selectedId: selectedId ?? _archive.selectedId,
  );

  void _validateDraft(AgentConversation draft) {
    if (draft.messages.isNotEmpty ||
        draft.runs.isNotEmpty ||
        draft.turns.isNotEmpty ||
        draft.historyVersions.isNotEmpty ||
        draft.replyRevisions.isNotEmpty ||
        draft.redoBatches.isNotEmpty ||
        draft.queuedInputs.isNotEmpty ||
        draft.queuedControls.isNotEmpty ||
        draft.pendingQuestion != null ||
        draft.archived ||
        draft.status != ConversationStatus.idle ||
        draft.runId != null ||
        draft.connectionFingerprint != null) {
      throw const OperationProblem(
        OperationErrorCode.invalidArgument,
        'Unsent input cannot contain executable conversation history.',
      );
    }
  }

  void _discardDraft() {
    _draftConversation = null;
    _draftSelected = false;
  }

  void _reconcileDraft() {
    final draftId = _draftConversation?.id;
    if (draftId != null &&
        (_archive.conversations.any((item) => item.id == draftId) ||
            _archive.terminatedIds.contains(draftId))) {
      _discardDraft();
    }
  }

  Future<void> _save(
    ConversationArchive candidate, {
    bool selectDurable = false,
    bool reconcileDraft = true,
    String? restoreId,
    String? restoreFingerprint,
    Iterable<String>? replacedConversationIds,
  }) async {
    final storage = _storage;
    final source = storage is StructuredConversationStorage
        ? null
        : candidate.encode();
    if (source != null) ConversationArchive.decode(source);
    try {
      if (storage is StructuredConversationStorage) {
        final records = storage as StructuredConversationStorage;
        if (restoreId == null) {
          await records.writeArchive(candidate, previous: _archive);
        } else {
          await records.writeRestore(
            candidate,
            previous: _archive,
            restoreId: restoreId,
            fingerprint: restoreFingerprint!,
            replacedConversationIds: replacedConversationIds,
          );
        }
      } else {
        // Explicit archive adapters are used for portable exports and tests.
        await storage.save(source!, revision: candidate.revision);
      }
    } catch (error) {
      if (error is! ConversationStorageException || error.outcomeUnknown) {
        _blocked = true;
        _notify();
      }
      rethrow;
    }
    _archive = candidate;
    for (final id in _visibleMessages.keys.toList()) {
      final current = find(id);
      if (current == null) {
        _visibleMessages.remove(id);
        _visibleStarts.remove(id);
        _turnIndexes.remove(id);
      } else if (!_unloadedIds.contains(id)) {
        _refreshVisibleWindow(current);
      }
    }
    _unloadedIds.removeWhere(
      (id) => !candidate.conversations.any((item) => item.id == id),
    );
    if (reconcileDraft) _reconcileDraft();
    if (selectDurable) _draftSelected = false;
    _notify();
  }

  void _checkWritable({String? expectedRunId}) {
    if (!canWrite &&
        !(_loaded &&
            !_blocked &&
            !_disposed &&
            ((!_frozen &&
                    _historyOwner != null &&
                    Zone.current[_historyZoneKey] == _historyOwner) ||
                (_frozen &&
                    _historyOwner == null &&
                    expectedRunId != null &&
                    _shutdownRunIds.contains(expectedRunId))))) {
      throw const ConversationStorageException(
        'Conversation storage is unavailable; load or recover it before writing.',
      );
    }
  }

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _frozen = true;
    _discardDraft();
    super.dispose();
  }
}

String _randomId() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}
