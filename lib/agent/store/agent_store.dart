import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as path;

import '../conversations/conversation_models.dart';
import '../conversations/conversation_storage.dart';
import '../history/conversation_history.dart';
import '../knowledge/knowledge_models.dart';
import '../knowledge/knowledge_storage.dart';
import 'agent_database.dart';
import 'agent_store_executor.dart';
import 'agent_store_cutover.dart';

export 'agent_database.dart';
export 'agent_store_cutover.dart' show LegacyAgentCutoverEvidence;

AgentStore Function()? _debugAgentStoreFactory;

@visibleForTesting
void debugSetAgentStoreFactory(AgentStore Function()? factory) {
  assert(() {
    _debugAgentStoreFactory = factory;
    return true;
  }());
}

class AgentConversationSummary {
  const AgentConversationSummary({
    required this.id,
    required this.title,
    required this.updatedAt,
    required this.archived,
    required this.hasPendingWork,
  });
  final String id, title;
  final DateTime updatedAt;
  final bool archived, hasPendingWork;
}

/// The application owns one store. All Agent repositories share its SQL
/// transaction boundary; AppData remains owned by the business repository.
class AgentStore {
  AgentStore(this._database)
    : _reopen = null,
      _persistent = false,
      _directoryPath = null;
  AgentStore._managed(this._database, this._reopen, this._directoryPath)
    : _persistent = true;
  factory AgentStore.open({String? filePath}) {
    if (filePath == null) {
      final factory = _debugAgentStoreFactory;
      if (factory != null) return factory();
    }
    AgentDatabase create() =>
        AgentDatabase(openAgentStoreExecutor(filePath: filePath));
    return AgentStore._managed(
      create(),
      create,
      filePath == null ? null : path.dirname(filePath),
    );
  }
  AgentDatabase _database;
  final AgentDatabase Function()? _reopen;
  final bool _persistent;
  final String? _directoryPath;
  Future<void>? _closing;
  AgentDatabase get database => _database;

  late final conversations = SqliteConversationStorage(this);
  late final knowledge = SqliteKnowledgeStorage(this);

  Future<T> transaction<T>(Future<T> Function() action) =>
      database.transaction(action);
  Future<void> close() => _closing ??= database.close();

  Future<void> finishLegacyCutover({
    required Future<List<LegacyAgentPendingOperation>> Function(
      LegacyAgentCutoverEvidence evidence,
    )
    reconcilePendingWrites,
    String? directoryPath,
  }) async {
    final phase = await readMetadata('legacy_cutover');
    if (phase == 'complete') return;
    final location = directoryPath ?? _directoryPath;
    if (phase != 'retiring') {
      final evidence = await _readLegacyEvidence(location);
      final unresolved = await listRecords(
        'legacy_pending_operation',
        'legacy_cutover',
      );
      final pending = await reconcilePendingWrites(
        phase == 'pending'
            ? LegacyAgentCutoverEvidence(
                archives: evidence.archives,
                knowledgeArchives: evidence.knowledgeArchives,
                mirrored: evidence.mirrored,
                pendingHistoryBatch: null,
                pendingOperations: unresolved
                    .map(LegacyAgentPendingOperation.fromJson)
                    .toList(),
              )
            : evidence,
      );
      // After this first pass the new Agent can own files in this directory.
      // Delayed receipt reconciliation must never delete those new attachments.
      if (phase == null && _persistent) {
        await retireLegacyAgentAttachments(directoryPath: location);
      }
      await transaction(() async {
        await clearRecords('legacy_pending_operation', 'legacy_cutover');
        for (final operation in pending) {
          await putRecord(
            'legacy_pending_operation',
            'legacy_cutover',
            operation.operationId,
            operation.toJson(),
          );
        }
        await writeMetadata(
          'legacy_cutover',
          pending.isEmpty ? 'retiring' : 'pending',
        );
      });
      if (pending.isNotEmpty) return;
    }
    if (_persistent) await retireLegacyAgentData(directoryPath: location);
    await writeMetadata('legacy_cutover', 'complete');
  }

  Future<LegacyAgentCutoverEvidence?> readLegacyOperationEvidence(
    String operationId,
  ) async {
    if (await readRecord(
          'legacy_pending_operation',
          'legacy_cutover',
          operationId,
        ) ==
        null) {
      return null;
    }
    return _readLegacyEvidence(_directoryPath);
  }

  Future<LegacyAgentCutoverEvidence> _readLegacyEvidence(
    String? location,
  ) async => _persistent
      ? await readLegacyAgentCutoverEvidence(directoryPath: location)
      : LegacyAgentCutoverEvidence(
          archives: [],
          mirrored: false,
          pendingHistoryBatch: null,
        );

  /// Drained application owners call this before the platform deletes files.
  /// The next read opens the surviving or cleared database at the same path.
  Future<void> suspendForDataClear() async {
    final reopen = _reopen;
    if (reopen == null) {
      await clear();
      return;
    }
    await close();
    _database = reopen();
    _closing = null;
    knowledge._previous = KnowledgeArchive();
  }

  Future<String?> readMetadata(String key) async => (await (database.select(
    database.agentMetadata,
  )..where((row) => row.key.equals(key))).getSingleOrNull())?.value;

  Future<void> writeMetadata(String key, String? value) async {
    if (value == null) {
      await (database.delete(
        database.agentMetadata,
      )..where((row) => row.key.equals(key))).go();
    } else {
      await database
          .into(database.agentMetadata)
          .insertOnConflictUpdate(
            AgentMetadataCompanion.insert(key: key, value: value),
          );
    }
  }

  Future<void> putRecord(
    String collection,
    String owner,
    String id,
    Map<String, Object?> value, {
    int position = 0,
  }) => _putJson(collection, owner, id, jsonEncode(value), position);

  Future<void> _putJson(
    String collection,
    String owner,
    String id,
    String payload,
    int position,
  ) async {
    await database.customUpdate(
      'INSERT INTO agent_items(collection, owner, id, position, payload) '
      'VALUES (?, ?, ?, ?, ?) ON CONFLICT(collection, owner, id) DO UPDATE '
      'SET position = excluded.position, payload = excluded.payload '
      'WHERE agent_items.position != excluded.position OR agent_items.payload != excluded.payload',
      variables: [
        Variable(collection),
        Variable(owner),
        Variable(id),
        Variable(position),
        Variable(payload),
      ],
      updates: {database.agentItems},
    );
  }

  Future<Map<String, Object?>?> readRecord(
    String collection,
    String owner,
    String id,
  ) async {
    final query = database.select(database.agentItems)
      ..where(
        (row) =>
            row.collection.equals(collection) &
            row.owner.equals(owner) &
            row.id.equals(id),
      );
    final row = await query.getSingleOrNull();
    return row == null ? null : _object(row.payload);
  }

  SimpleSelectStatement<$AgentItemsTable, StoredAgentItem> _records(
    String collection,
    String owner, {
    int offset = 0,
    int? limit,
    bool descending = false,
  }) {
    final query = database.select(database.agentItems)
      ..where(
        (row) => row.collection.equals(collection) & row.owner.equals(owner),
      )
      ..orderBy([
        (row) => OrderingTerm(
          expression: row.position,
          mode: descending ? OrderingMode.desc : OrderingMode.asc,
        ),
        (row) => OrderingTerm.asc(row.id),
      ]);
    if (limit != null) query.limit(limit, offset: offset);
    return query;
  }

  Future<List<Map<String, Object?>>> listRecords(
    String collection,
    String owner, {
    int offset = 0,
    int? limit,
    bool descending = false,
  }) async => [
    for (final row in await _records(
      collection,
      owner,
      offset: offset,
      limit: limit,
      descending: descending,
    ).get())
      _object(row.payload),
  ];

  Stream<List<Map<String, Object?>>> watchRecords(
    String collection,
    String owner, {
    int? limit,
  }) => _records(
    collection,
    owner,
    limit: limit,
  ).watch().map((rows) => [for (final row in rows) _object(row.payload)]);

  Future<void> deleteRecord(String collection, String owner, String id) async {
    await (database.delete(database.agentItems)..where(
          (row) =>
              row.collection.equals(collection) &
              row.owner.equals(owner) &
              row.id.equals(id),
        ))
        .go();
  }

  Future<void> clearRecords(String collection, String owner) async {
    await (database.delete(database.agentItems)..where(
          (row) => row.collection.equals(collection) & row.owner.equals(owner),
        ))
        .go();
  }

  Future<void> appendContextCheckpoint(
    Map<String, Object?> checkpoint, {
    void Function()? validate,
  }) async {
    final owner = checkpoint['conversationId'] as String;
    await transaction(() async {
      final existing = await readRecord(
        'context',
        owner,
        checkpoint['id'] as String,
      );
      if (existing != null) {
        if (jsonEncode(existing) != jsonEncode(checkpoint)) {
          throw StateError(
            'A context checkpoint identity already has different content.',
          );
        }
        if (checkpoint['sourceKey'] case final String sourceKey) {
          await deleteRecord('context_failure', owner, sourceKey);
        }
        validate?.call();
        return;
      }
      final last = await _records(
        'context',
        owner,
        limit: 1,
        descending: true,
      ).getSingleOrNull();
      await putRecord(
        'context',
        owner,
        checkpoint['id'] as String,
        checkpoint,
        position: (last?.position ?? -1) + 1,
      );
      if (checkpoint['sourceKey'] case final String sourceKey) {
        await deleteRecord('context_failure', owner, sourceKey);
      }
      validate?.call();
    });
  }

  Future<Map<String, Object?>?> latestContextCheckpoint(
    String conversationId,
  ) async => (await listRecords(
    'context',
    conversationId,
    limit: 1,
    descending: true,
  )).firstOrNull;

  Future<void> clearContextCheckpoints(String conversationId) =>
      transaction(() async {
        await clearRecords('context', conversationId);
        await clearRecords('context_failure', conversationId);
      });

  Future<List<AgentConversationSummary>> listConversations({
    int offset = 0,
    int limit = 50,
    bool? archived,
    String query = '',
  }) async {
    final statement = database.select(database.agentConversations)
      ..orderBy([
        (row) => OrderingTerm.desc(row.updatedAt),
        (row) => OrderingTerm.asc(row.id),
      ])
      ..limit(limit, offset: offset);
    if (archived != null) {
      statement.where((row) => row.archived.equals(archived));
    }
    if (query.isNotEmpty) statement.where((row) => row.title.contains(query));
    return [
      for (final row in await statement.get())
        AgentConversationSummary(
          id: row.id,
          title: row.title,
          updatedAt: row.updatedAt,
          archived: row.archived,
          hasPendingWork: row.hasPendingWork,
        ),
    ];
  }

  Future<List<ConversationMessage>> readMessagePage(
    String conversationId, {
    int offset = 0,
    int limit = 50,
  }) => transaction(() async {
    final messages = await listRecords(
      'message',
      conversationId,
      offset: offset,
      limit: limit,
    );
    final expanded = await _expandMessages(conversationId, messages);
    return [
      for (final message in expanded) ConversationMessage.fromJson(message),
    ];
  });

  Future<ConversationPage> readConversationPage(
    String id, {
    int? before,
    int pageSize = 50,
  }) => transaction(() async {
    final row = await (database.select(
      database.agentConversations,
    )..where((row) => row.id.equals(id))).getSingle();
    final count = database.agentItems.id.count();
    final counts = database.selectOnly(database.agentItems)
      ..addColumns([count])
      ..where(
        database.agentItems.collection.equals('message') &
            database.agentItems.owner.equals(id),
      );
    final total = (await counts.getSingle()).read(count)!;
    final end = before ?? total;
    var start = end > pageSize ? end - pageSize : 0;
    final boundary =
        await (database.select(database.agentItems)
              ..where(
                (item) =>
                    item.collection.equals('message_boundary') &
                    item.owner.equals(id) &
                    item.position.isSmallerOrEqualValue(start),
              )
              ..orderBy([(item) => OrderingTerm.desc(item.position)])
              ..limit(1))
            .getSingleOrNull();
    start = boundary?.position ?? 0;
    final messages = await readMessagePage(
      id,
      offset: start,
      limit: end - start,
    );
    final metadata = _object(row.metadata);
    final attachmentIds = <String>{
      ...(metadata['draftAttachmentIds'] as List).cast<String>(),
      for (final message in messages) ...message.attachmentIds,
    };
    final attachments = <Map<String, Object?>>[];
    for (final attachmentId in attachmentIds) {
      attachments.add((await readRecord('attachment', id, attachmentId))!);
    }
    final view = AgentConversation.fromJson({
      ...metadata,
      'executionHistoryStart':
          ((metadata['executionHistoryStart'] as int) - start).clamp(
            0,
            messages.length,
          ),
      'messages': messages.map((message) => message.toJson()).toList(),
      'attachments': attachments,
    });
    final turns = (await listRecords(
      'turn',
      id,
    )).map(ConversationTurn.fromJson).toList();
    return ConversationPage(
      conversation: view,
      start: start,
      total: total,
      turns: turns,
    );
  });

  Future<List<Map<String, Object?>>> _expandMessages(
    String owner,
    List<Map<String, Object?>> values,
  ) async {
    if (values.isEmpty) return [];
    final owners = [for (final value in values) '$owner/${value['id']}'];
    final grouped = <String, List<Map<String, Object?>>>{};
    // Bound SQL bind parameters per query while traversing the entire result.
    for (var offset = 0; offset < owners.length; offset += 500) {
      final calls =
          await (database.select(database.agentItems)
                ..where(
                  (row) =>
                      row.collection.equals('tool_call') &
                      row.owner.isIn(owners.skip(offset).take(500)),
                )
                ..orderBy([(row) => OrderingTerm.asc(row.position)]))
              .get();
      for (final call in calls) {
        (grouped[call.owner] ??= []).add(_object(call.payload));
      }
    }
    return [
      for (final value in values)
        {
          ...value,
          'toolCalls': grouped['$owner/${value['id']}'] ?? <Object?>[],
        },
    ];
  }

  Future<AgentConversation?> readConversation(String id) =>
      transaction(() async {
        final row = await (database.select(
          database.agentConversations,
        )..where((row) => row.id.equals(id))).getSingleOrNull();
        if (row == null) return null;
        final json = _object(row.metadata);
        for (final entry in _conversationCollections.entries) {
          json[entry.key] = await listRecords(entry.value, id);
        }
        final versions = await listRecords('history', id);
        for (final version in versions) {
          final owner = _historyOwner(id, version['id'] as String);
          version['messages'] = await _expandMessages(
            owner,
            await listRecords('message', owner),
          );
          version['runs'] = await listRecords('run', owner);
          version['turns'] = await listRecords('turn', owner);
        }
        json['historyVersions'] = versions;
        json['messages'] = await _expandMessages(
          id,
          await listRecords('message', id),
        );
        final question = await readRecord('pending_question', id, 'current');
        if (question != null) json['pendingQuestion'] = question;
        return AgentConversation.fromJson(Map<String, dynamic>.from(json));
      });

  Future<void> _syncObjects<T>(
    String collection,
    String owner,
    Iterable<T> values,
    Iterable<T> previous,
    String Function(T) identity,
    Map<String, Object?> Function(T) encode,
  ) async {
    final before = {for (final item in previous) identity(item): item};
    // Position belongs to the collection, never to a timestamp sort heuristic.
    final positions = <String, int>{};
    var oldPosition = 0;
    for (final item in previous) {
      positions[identity(item)] = oldPosition++;
    }
    var position = 0;
    for (final item in values) {
      final id = identity(item);
      final old = before.remove(id);
      if (!identical(item, old) || positions[id] != position) {
        await putRecord(
          collection,
          owner,
          id,
          encode(item),
          position: position,
        );
      }
      position++;
    }
    for (final id in before.keys) {
      await deleteRecord(collection, owner, id);
    }
  }

  Future<void> _saveConversation(
    AgentConversation value,
    AgentConversation? previous,
  ) async {
    final metadata = <String, Object?>{
      'id': value.id,
      'title': value.title,
      'titleWasEdited': value.titleWasEdited,
      'pinned': value.pinned,
      'titleGeneration': value.titleGeneration?.toJson(),
      'createdAt': value.createdAt.toUtc().toIso8601String(),
      'updatedAt': value.updatedAt.toUtc().toIso8601String(),
      'mode': value.mode.name,
      'status': value.status.name,
      'archived': value.archived,
      'draft': value.draft,
      'connectionFingerprint': value.connectionFingerprint,
      'runId': value.runId,
      'modelSelection': value.modelSelection?.toJson(),
      'executionHistoryStart': value.executionHistoryStart,
      'draftAttachmentIds': value.draftAttachmentIds,
      'draftReferences': [
        for (final ref in value.draftReferences) ref.toJson(),
      ],
    };
    await database
        .into(database.agentConversations)
        .insertOnConflictUpdate(
          AgentConversationsCompanion.insert(
            id: value.id,
            title: value.title,
            updatedAt: value.updatedAt,
            archived: value.archived,
            hasPendingWork:
                value.queuedInputs.isNotEmpty ||
                value.hasPendingControls ||
                value.pendingRedo != null ||
                value.pendingQuestion != null ||
                value.status != ConversationStatus.idle ||
                value.draftAttachmentIds.isNotEmpty ||
                value.draftReferences.isNotEmpty ||
                value.runs.any(
                  (run) => run.status == ConversationRunStatus.running,
                ) ||
                value.messages.any(
                  (message) =>
                      message.attachmentDelivery ==
                          AttachmentDelivery.preparing ||
                      message.attachmentDelivery == AttachmentDelivery.sending,
                ),
            metadata: jsonEncode(metadata),
          ),
        );
    await _saveMessages(value.id, value.messages, previous?.messages ?? []);
    await _syncObjects(
      'queue',
      value.id,
      value.queuedInputs,
      previous?.queuedInputs ?? [],
      (value) => value.id,
      (value) => value.toJson(),
    );
    await _syncObjects(
      'control',
      value.id,
      value.queuedControls,
      previous?.queuedControls ?? [],
      (value) => value.id,
      (value) => value.toJson(),
    );
    await _syncObjects(
      'source',
      value.id,
      value.sources,
      previous?.sources ?? [],
      (v) => v.id,
      (v) => v.toJson(),
    );
    await _syncObjects(
      'run',
      value.id,
      value.runs,
      previous?.runs ?? [],
      (v) => v.id,
      (v) => v.toJson(),
    );
    await _syncObjects(
      'attachment',
      value.id,
      value.attachments,
      previous?.attachments ?? [],
      (v) => v.id,
      (v) => v.toJson(),
    );
    await _syncObjects(
      'attachment_reference',
      value.id,
      conversationAttachmentIds(value),
      previous == null ? const <String>[] : conversationAttachmentIds(previous),
      (v) => v,
      (v) => {'id': v},
    );
    await _syncObjects(
      'turn',
      value.id,
      value.turns,
      previous?.turns ?? [],
      (v) => v.id,
      (v) => v.toJson(),
    );
    await _syncObjects(
      'history',
      value.id,
      value.historyVersions,
      previous?.historyVersions ?? [],
      (v) => v.id,
      (v) => {
        'id': v.id,
        'batchId': v.batchId,
        'createdAt': v.createdAt.toUtc().toIso8601String(),
      },
    );
    final oldVersions = {
      for (final version
          in previous?.historyVersions ?? <ConversationHistoryVersion>[])
        version.id: version,
    };
    for (final version in value.historyVersions) {
      final old = oldVersions.remove(version.id);
      if (identical(version, old)) continue;
      final owner = _historyOwner(value.id, version.id);
      await _saveMessages(owner, version.messages, old?.messages ?? []);
      await _syncObjects(
        'run',
        owner,
        version.runs,
        old?.runs ?? [],
        (v) => v.id,
        (v) => v.toJson(),
      );
      await _syncObjects(
        'turn',
        owner,
        version.turns,
        old?.turns ?? [],
        (v) => v.id,
        (v) => v.toJson(),
      );
    }
    for (final version in oldVersions.values) {
      await _deleteOwner(_historyOwner(value.id, version.id));
    }
    await _syncObjects(
      'reply',
      value.id,
      value.replyRevisions,
      previous?.replyRevisions ?? [],
      (v) => v.id,
      (v) => v.toJson(),
    );
    await _syncObjects(
      'redo',
      value.id,
      value.redoBatches,
      previous?.redoBatches ?? [],
      (v) => v.id,
      (v) => v.toJson(),
    );
    if (value.pendingQuestion == null) {
      await deleteRecord('pending_question', value.id, 'current');
    } else if (!identical(value.pendingQuestion, previous?.pendingQuestion)) {
      await putRecord(
        'pending_question',
        value.id,
        'current',
        value.pendingQuestion!.toJson(),
      );
    }
  }

  Future<void> _saveMessages(
    String owner,
    Iterable<ConversationMessage> messages,
    Iterable<ConversationMessage> previous,
  ) async {
    final before = {for (final message in previous) message.id: message};
    await _syncObjects(
      'message',
      owner,
      messages,
      previous,
      (v) => v.id,
      (v) => v.toJson()..remove('toolCalls'),
    );
    for (final message in messages) {
      final old = before.remove(message.id);
      if (identical(message, old)) continue;
      await _syncObjects(
        'tool_call',
        '$owner/${message.id}',
        message.toolCalls,
        old?.toolCalls ?? [],
        (v) => v.id,
        (v) => v.toJson(),
      );
    }
    for (final id in before.keys) {
      await clearRecords('tool_call', '$owner/$id');
    }
    final oldBoundaries = <String, int>{};
    var index = 0;
    for (final message in previous) {
      if (message.role == ConversationRole.user) {
        oldBoundaries[message.id] = index;
      }
      index++;
    }
    index = 0;
    for (final message in messages) {
      if (message.role == ConversationRole.user &&
          oldBoundaries.remove(message.id) != index) {
        await putRecord('message_boundary', owner, message.id, {
          'id': message.id,
        }, position: index);
      }
      index++;
    }
    for (final id in oldBoundaries.keys) {
      await deleteRecord('message_boundary', owner, id);
    }
  }

  Future<void> _deleteOwner(String owner) async {
    final messages = await _records('message', owner).get();
    for (final message in messages) {
      await clearRecords('tool_call', '$owner/${message.id}');
    }
    await (database.delete(
      database.agentItems,
    )..where((row) => row.owner.equals(owner))).go();
  }

  Future<void> deleteConversation(String id) async {
    await transaction(() async {
      for (final version in await _records('history', id).get()) {
        await _deleteOwner(_historyOwner(id, version.id));
      }
      await _deleteOwner(id);
      await (database.delete(
        database.agentConversations,
      )..where((row) => row.id.equals(id))).go();
    });
  }

  Future<void> clear() async {
    await transaction(() async {
      await database.delete(database.agentItems).go();
      await database.delete(database.agentConversations).go();
      await database.delete(database.agentMetadata).go();
    });
    knowledge._previous = KnowledgeArchive();
  }
}

const _conversationCollections = {
  'sources': 'source',
  'runs': 'run',
  'attachments': 'attachment',
  'turns': 'turn',
  'replyRevisions': 'reply',
  'redoBatches': 'redo',
  'queuedInputs': 'queue',
  'queuedControls': 'control',
};

Map<String, Object?> _object(String json) =>
    Map<String, Object?>.from(jsonDecode(json) as Map);

String _historyOwner(String conversationId, String versionId) =>
    jsonEncode(['history', conversationId, versionId]);

class SqliteConversationStorage extends ConversationStorage
    implements StructuredConversationStorage {
  SqliteConversationStorage(this.store) : super.base();
  final AgentStore store;

  Future<void> _writeTransaction(Future<void> Function() action) async {
    Object? actionFailure;
    try {
      await store.transaction(() async {
        try {
          await action();
        } catch (error) {
          actionFailure = error;
          rethrow;
        }
      });
    } catch (error, stack) {
      // Drift returns the original action error only after rollback succeeds.
      // A failed commit, rollback or connection retains its original outcome.
      if (identical(error, actionFailure)) {
        Error.throwWithStackTrace(
          ConversationStorageException(error.toString()),
          stack,
        );
      }
      rethrow;
    }
  }

  @override
  Future<AgentConversation?> readConversation(String id) =>
      store.readConversation(id);

  @override
  Future<ConversationStatistics> readStatistics(String id) => store.transaction(
    () async {
      final items = store.database.agentItems;
      final count = items.id.count();
      final query = store.database.selectOnly(items)
        ..addColumns([items.collection, count])
        ..where(
          items.owner.equals(id) & items.collection.isIn(['message', 'source']),
        )
        ..groupBy([items.collection]);
      final counts = {
        for (final row in await query.get())
          row.read(items.collection)!: row.read(count)!,
      };
      final runs = (await store.listRecords(
        'run',
        id,
      )).map(ConversationRunUsage.fromJson);
      return ConversationStatistics(
        messageCount: counts['message'] ?? 0,
        sourceCount: counts['source'] ?? 0,
        usage: summarizeConversationUsage(runs),
      );
    },
  );

  @override
  Future<int> readRevision() async =>
      int.parse(await store.readMetadata('conversation_revision') ?? '0');
  @override
  Future<String?> readRestoreMarker(String restoreId) =>
      store.readMetadata('restore:conversations:$restoreId');
  @override
  Future<void> writeRestore(
    ConversationArchive archive, {
    required ConversationArchive previous,
    required String restoreId,
    required String fingerprint,
    Iterable<String>? replacedConversationIds,
  }) => _writeTransaction(() async {
    final affected =
        replacedConversationIds?.toSet() ??
        archive.conversations.map((item) => item.id).toSet();
    final old = {for (final item in previous.conversations) item.id: item};
    final value = ConversationArchive(
      revision: archive.revision,
      selectedId: archive.selectedId,
      conversations: [
        for (final item in archive.conversations)
          if (affected.contains(item.id)) item else old[item.id] ?? item,
      ],
      handoffs: archive.handoffs,
      terminatedIds: archive.terminatedIds,
    );
    await writeArchive(value, previous: previous);
    for (final id in affected) {
      for (final collection in const [
        'operation',
        'interaction',
        'context',
        'context_failure',
      ]) {
        await store.clearRecords(collection, id);
      }
    }
    await store.writeMetadata('restore:conversations:$restoreId', fingerprint);
  });

  @override
  Future<ConversationPage> readPage(
    String id, {
    int? before,
    int pageSize = 50,
  }) => store.readConversationPage(id, before: before, pageSize: pageSize);

  @override
  Future<Set<String>> referencedAttachmentIds() async => {
    for (final row in await (store.database.select(
      store.database.agentItems,
    )..where((row) => row.collection.equals('attachment_reference'))).get())
      row.id,
  };

  @override
  Future<
    ({
      ConversationArchive archive,
      Set<String> unloadedIds,
      Map<String, ConversationPage> pages,
    })
  >
  readIndex() => store.transaction(() async {
    final rows = await store.database
        .select(store.database.agentConversations)
        .get();
    final selected = await store.readMetadata('selected_conversation');
    final values = <AgentConversation>[];
    final unloaded = <String>{};
    final pages = <String, ConversationPage>{};
    for (final row in rows) {
      if (row.hasPendingWork) {
        values.add((await store.readConversation(row.id))!);
        if (row.id == selected) pages[row.id] = await readPage(row.id);
      } else if (row.id == selected) {
        final page = await readPage(row.id);
        values.add(page.conversation);
        pages[row.id] = page;
        unloaded.add(row.id);
      } else {
        final json = _object(row.metadata);
        values.add(
          AgentConversation.fromJson({
            ...json,
            'executionHistoryStart': 0,
            'draftAttachmentIds': <String>[],
            'draftReferences': <Object?>[],
            'messages': <Object?>[],
            for (final key in _conversationCollections.keys) key: <Object?>[],
          }),
        );
        unloaded.add(row.id);
      }
    }
    return (
      archive: ConversationArchive(
        revision: int.parse(
          await store.readMetadata('conversation_revision') ?? '0',
        ),
        selectedId: selected,
        conversations: values,
        handoffs: (await store.listRecords('handoff', '')).map(
          (value) =>
              ConversationHandoff.fromJson(Map<String, dynamic>.from(value)),
        ),
        terminatedIds: (await store.listRecords(
          'conversation_deleted',
          '',
        )).map((value) => value['id'] as String),
      ),
      unloadedIds: unloaded,
      pages: pages,
    );
  });

  @override
  Future<ConversationArchive> readArchive() async =>
      store.transaction(() async {
        final records = await store.database
            .select(store.database.agentConversations)
            .get();
        final values = <AgentConversation>[];
        for (final row in records) {
          values.add((await store.readConversation(row.id))!);
        }
        return ConversationArchive(
          revision: int.parse(
            await store.readMetadata('conversation_revision') ?? '0',
          ),
          selectedId: await store.readMetadata('selected_conversation'),
          conversations: values,
          handoffs: (await store.listRecords('handoff', '')).map(
            (value) =>
                ConversationHandoff.fromJson(Map<String, dynamic>.from(value)),
          ),
          terminatedIds: (await store.listRecords(
            'conversation_deleted',
            '',
          )).map((value) => value['id'] as String),
        );
      });

  @override
  Future<void> writeArchive(
    ConversationArchive value, {
    required ConversationArchive previous,
  }) => _writeTransaction(() async {
    final before = {for (final c in previous.conversations) c.id: c};
    for (final conversation in value.conversations) {
      final old = before.remove(conversation.id);
      if (!identical(old, conversation)) {
        await store._saveConversation(conversation, old);
      }
    }
    for (final id in before.keys) {
      await store.deleteConversation(id);
    }
    await store._syncObjects(
      'handoff',
      '',
      value.handoffs,
      previous.handoffs,
      (v) => v.id,
      (v) => v.toJson(),
    );
    await store._syncObjects(
      'conversation_deleted',
      '',
      value.terminatedIds,
      previous.terminatedIds,
      (v) => v,
      (v) => {'id': v},
    );
    await store.writeMetadata('conversation_revision', '${value.revision}');
    await store.writeMetadata('selected_conversation', value.selectedId);
  });

  @override
  Future<ConversationStorageLoad> load() async =>
      ConversationStorageLoad(archive: await readArchive());
  @override
  Future<void> save(String source, {required int revision}) async =>
      writeArchive(
        ConversationArchive.decode(source),
        previous: await readArchive(),
      );
  @override
  Future<String?> pendingHistoryBatch() =>
      store.readMetadata('pending_history_batch');
  @override
  Future<void> writePendingHistoryBatch(String? batchId) =>
      store.writeMetadata('pending_history_batch', batchId);
}

class SqliteKnowledgeStorage extends KnowledgeStorage
    implements TransactionalKnowledgeStorage {
  SqliteKnowledgeStorage(this.store) : super.base();
  final AgentStore store;
  KnowledgeArchive _previous = KnowledgeArchive();
  @override
  Future<int> readRevision() async =>
      int.parse(await store.readMetadata('knowledge_storage_revision') ?? '0');
  @override
  Future<String?> readRestoreMarker(String restoreId) =>
      store.readMetadata('restore:knowledge:$restoreId');
  @override
  Future<void> saveRestore(
    KnowledgeArchive archive, {
    required String restoreId,
    required String fingerprint,
  }) => _saveRecords(archive, restoreId: restoreId, fingerprint: fingerprint);
  @override
  Future<KnowledgeStorageLoad> load() async {
    final result = await store.transaction(
      () async => KnowledgeArchive(
        revision: int.parse(
          await store.readMetadata('knowledge_revision') ?? '0',
        ),
        storageRevision: int.parse(
          await store.readMetadata('knowledge_storage_revision') ?? '0',
        ),
        records: (await store.listRecords(
          'knowledge',
          '',
        )).map(KnowledgeRecord.fromJson),
        receipts: (await store.listRecords(
          'knowledge_receipt',
          '',
        )).map(KnowledgeReceipt.fromJson),
        undoBatches: (await store.listRecords(
          'knowledge_undo',
          '',
        )).map(KnowledgeUndoBatch.fromJson),
        tombstones: {
          for (final item in await store.listRecords('knowledge_deleted', ''))
            item['id'] as String: item['revision'] as int,
        },
      ),
    );
    _previous = result;
    return KnowledgeStorageLoad(result);
  }

  @override
  Future<void> save(KnowledgeArchive archive) => _saveRecords(archive);

  Future<void> _saveRecords(
    KnowledgeArchive archive, {
    String? restoreId,
    String? fingerprint,
  }) async {
    await store.transaction(() async {
      await store._syncObjects(
        'knowledge',
        '',
        archive.records,
        _previous.records,
        (v) => v.key,
        (v) => v.toJson(),
      );
      await store._syncObjects(
        'knowledge_receipt',
        '',
        archive.receipts,
        _previous.receipts,
        (v) => v.operationId,
        (v) => v.toJson(),
      );
      await store._syncObjects(
        'knowledge_undo',
        '',
        archive.undoBatches,
        _previous.undoBatches,
        (v) => v.batchId,
        (v) => v.toJson(),
      );
      await store._syncObjects(
        'knowledge_deleted',
        '',
        archive.tombstones.entries,
        _previous.tombstones.entries,
        (v) => v.key,
        (v) => {'id': v.key, 'revision': v.value},
      );
      await store.writeMetadata('knowledge_revision', '${archive.revision}');
      await store.writeMetadata(
        'knowledge_storage_revision',
        '${archive.storageRevision}',
      );
      if (restoreId != null) {
        await store.writeMetadata('restore:knowledge:$restoreId', fingerprint!);
      }
    });
    _previous = archive;
  }
}
