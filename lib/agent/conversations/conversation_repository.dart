import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../application/operation_contracts.dart';
import '../../models/agent_settings.dart';
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
    ConversationArchive.decode(
      _next(
        conversations: [
          for (final item in conversations)
            if (item.id == candidate.id) candidate else item,
        ],
      ).encode(),
    );
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
  AgentConversation? find(String? id) => isDraft(id)
      ? _draftConversation
      : conversations
            .where((conversation) => conversation.id == id)
            .firstOrNull;

  Future<void> load() => _enqueue(() async {
    if (_disposed || _frozen) {
      throw StateError('Conversation storage is closed.');
    }
    try {
      final result = await _storage.load();
      final next = result.source == null
          ? ConversationArchive()
          : ConversationArchive.decode(result.source!);
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
    if (days < 7 || days > 3650) {
      throw const FormatException(
        'History retention must be 0 or 7–3650 days.',
      );
    }
    final cutoff = _clock().toUtc().subtract(Duration(days: days));
    final removed = conversations
        .where(
          (item) =>
              item.status == ConversationStatus.idle &&
              item.pendingRedo == null &&
              item.draft.isEmpty &&
              item.draftAttachmentIds.isEmpty &&
              item.updatedAt.isBefore(cutoff) &&
              canRemove(item.id),
        )
        .map((item) => item.id)
        .toSet();
    if (removed.isEmpty) return 0;
    final remaining = conversations
        .where((item) => !removed.contains(item.id))
        .toList();
    await _save(
      ConversationArchive(
        revision: _archive.revision + 1,
        selectedId: removed.contains(_archive.selectedId)
            ? remaining.lastOrNull?.id
            : _archive.selectedId,
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
  }) => _enqueue(() async {
    _checkWritable(expectedRunId: expectedRunId);
    final current = _requireConversation(id);
    if (expectedRunId != null && current.runId != expectedRunId) {
      throw const OperationProblem(
        OperationErrorCode.expired,
        'This conversation run is no longer current.',
      );
    }
    final next = transform(current).copyWith(updatedAt: _clock().toUtc());
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

  /// Callers cancel network/operation scopes as soon as deletion is requested.
  /// The tombstone and removal of all owned content are one persisted update.
  Future<void> delete(String id, {void Function(AgentConversation)? validate}) {
    _deleting.add(id);
    return _enqueue(() async {
      try {
        _checkWritable();
        if (_archive.terminatedIds.contains(id)) return;
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
        final remaining = conversations.where((item) => item.id != id).toList();
        await _save(
          ConversationArchive(
            revision: _archive.revision + 1,
            selectedId: _archive.selectedId == id
                ? remaining.lastOrNull?.id
                : _archive.selectedId,
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
    ).copyWith(messages: [message], sources: [source]);
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
      final archive = loaded.source == null
          ? ConversationArchive()
          : ConversationArchive.decode(loaded.source!);
      _archive = archive;
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
      await _save(target, reconcileDraft: false);
      final confirmed = await _storage.load();
      validateOwner();
      if (confirmed.source != target.encode()) {
        throw const ConversationStorageException(
          'The conversation restore could not be read back.',
        );
      }
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
        draft.archived ||
        draft.status != ConversationStatus.idle ||
        draft.runId != null ||
        draft.connectionFingerprint != null) {
      throw const OperationProblem(
        OperationErrorCode.invalidArgument,
        'Unsent input cannot contain executable conversation history.',
      );
    }
    ConversationArchive.decode(
      ConversationArchive(
        selectedId: draft.id,
        conversations: [draft],
      ).encode(),
    );
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
  }) async {
    final source = candidate.encode();
    // Every writer observes the same strict quotas and relationship checks as
    // restart decoding, before any persistent state is modified.
    ConversationArchive.decode(source);
    try {
      await _storage.save(source, revision: candidate.revision);
    } catch (_) {
      _blocked = true;
      _notify();
      rethrow;
    }
    _archive = candidate;
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
