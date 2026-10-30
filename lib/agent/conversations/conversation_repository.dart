import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../application/operation_contracts.dart';
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
  Future<void> _tail = Future<void>.value();
  final _deleting = <String>{};
  bool _loaded = false;
  bool _blocked = false;
  bool _disposed = false;
  bool _frozen = false;
  bool recovered = false;

  bool get isLoaded => _loaded;
  bool get canWrite => _loaded && !_blocked && !_frozen && !_disposed;

  /// A failed clear may have removed some files. Explicit load/recovery must
  /// establish the surviving archive before any in-memory content can be saved.
  void resumeAfterFailedDataClear() {
    if (_disposed) return;
    _frozen = false;
    _blocked = true;
    _notify();
  }

  String? get selectedId => _archive.selectedId;
  List<AgentConversation> get conversations => _archive.conversations;
  AgentConversation? get selected => find(selectedId);
  AgentConversation? find(String? id) =>
      conversations.where((conversation) => conversation.id == id).firstOrNull;

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
      _loaded = true;
      _blocked = false;
      recovered = result.recovered;
      final interrupted = next.conversations.map((item) {
        final interruptedRun = item.runs.any(
          (run) => run.status == ConversationRunStatus.running,
        );
        return item.status == ConversationStatus.running ||
                item.status == ConversationStatus.waitingApproval ||
                interruptedRun
            ? item.copyWith(
                status: ConversationStatus.interrupted,
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
    String? id,
    void Function()? validate,
  }) => _enqueue(() async {
    _checkWritable();
    validate?.call();
    final conversation = _newConversation(title, mode, id: id);
    await _save(
      _next(
        conversations: [...conversations, conversation],
        selectedId: conversation.id,
      ),
    );
    return conversation;
  });

  Future<void> select(String id) => _enqueue(() async {
    _checkWritable();
    _requireConversation(id);
    if (selectedId != id) await _save(_next(selectedId: id));
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
              item.draft.isEmpty &&
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
        selectedId: removed.contains(selectedId)
            ? remaining.lastOrNull?.id
            : selectedId,
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
    _checkWritable();
    final current = _requireConversation(id);
    if (expectedRunId != null && current.runId != expectedRunId) {
      throw const OperationProblem(
        OperationErrorCode.expired,
        'This conversation run is no longer current.',
      );
    }
    final next = transform(current).copyWith(updatedAt: _clock().toUtc());
    if (next.id != current.id || next.createdAt != current.createdAt) {
      throw const OperationProblem(
        OperationErrorCode.invalidArgument,
        'Conversation identity cannot be changed.',
      );
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
        final remaining = conversations.where((item) => item.id != id).toList();
        await _save(
          ConversationArchive(
            revision: _archive.revision + 1,
            selectedId: selectedId == id
                ? remaining.lastOrNull?.id
                : selectedId,
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
      final message = conversation.messages
          .where((item) => item.id == existing.messageId)
          .first;
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
    );
    final conversation = _newConversation(
      title,
      mode,
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
    );
    return (conversation: conversation, created: true);
  });

  Future<void> waitForPendingWrites() => _tail;

  /// Used before app-wide clear/shutdown; late callbacks cannot recreate files.
  void freeze() => _frozen = true;

  AgentConversation _newConversation(
    String title,
    AgentPermissionMode mode, {
    String? id,
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

  Future<void> _save(ConversationArchive candidate) async {
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
    _notify();
  }

  void _checkWritable() {
    if (!canWrite) {
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
