import 'dart:convert';

import '../../models/agent_settings.dart';
import '../../utils/time_utils.dart' show tryParseStrictIsoDateTime;
import '../conversations/conversation_models.dart';

/// The host records a binding before accepting a write. A model's summary or
/// a timestamp cannot establish which conversation owns an operation.
enum ConversationOperationStore { main, external }

class ConversationOperationBinding {
  ConversationOperationBinding({
    required this.operationId,
    required this.store,
    required this.runId,
    required this.toolCallId,
  }) {
    for (final value in [operationId, runId, toolCallId]) {
      historyText(value);
    }
  }

  final String operationId;
  final ConversationOperationStore store;
  final String runId;
  final String toolCallId;

  Map<String, Object?> toJson() => {
    'operationId': operationId,
    'store': store.name,
    'runId': runId,
    'toolCallId': toolCallId,
  };

  factory ConversationOperationBinding.fromJson(Object? value) {
    final json = historyObject(value, {
      'operationId',
      'store',
      'runId',
      'toolCallId',
    });
    return ConversationOperationBinding(
      operationId: historyText(json['operationId']),
      store: historyEnum(ConversationOperationStore.values, json['store']),
      runId: historyText(json['runId']),
      toolCallId: historyText(json['toolCallId']),
    );
  }
}

/// An explicit, ordered interaction. Steering and resumed runs remain inside
/// the same turn; an accepted follow-up starts another turn. Old chats have no
/// reliable turn table and remain readable without invented undo ownership.
class ConversationTurn {
  ConversationTurn({
    required this.id,
    required this.requestMessageId,
    required this.ownershipComplete,
    required Iterable<String> messageIds,
    required Iterable<String> runIds,
    Iterable<ConversationOperationBinding> operations = const [],
  }) : messageIds = historyIds(messageIds, max: 1000),
       runIds = historyIds(runIds, max: 1000),
       operations = List.unmodifiable(operations) {
    historyText(id);
    historyText(requestMessageId);
    if (this.messageIds.isEmpty ||
        this.messageIds.first != requestMessageId ||
        this.runIds.isEmpty ||
        this.operations.length > 128 ||
        this.operations.any((item) => !this.runIds.contains(item.runId)) ||
        this.operations.map((item) => item.operationId).toSet().length !=
            this.operations.length) {
      throw const FormatException('Invalid conversation turn ownership.');
    }
  }

  final String id;
  final String requestMessageId;
  final bool ownershipComplete;
  final List<String> messageIds;
  final List<String> runIds;
  final List<ConversationOperationBinding> operations;

  ConversationTurn copyWith({
    bool? ownershipComplete,
    Iterable<String>? messageIds,
    Iterable<String>? runIds,
    Iterable<ConversationOperationBinding>? operations,
  }) => ConversationTurn(
    id: id,
    requestMessageId: requestMessageId,
    ownershipComplete: ownershipComplete ?? this.ownershipComplete,
    messageIds: messageIds ?? this.messageIds,
    runIds: runIds ?? this.runIds,
    operations: operations ?? this.operations,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'requestMessageId': requestMessageId,
    'ownershipComplete': ownershipComplete,
    'messageIds': messageIds,
    'runIds': runIds,
    'operations': operations.map((item) => item.toJson()).toList(),
  };

  factory ConversationTurn.fromJson(Object? value) {
    final json = historyObject(value, {
      'id',
      'requestMessageId',
      'ownershipComplete',
      'messageIds',
      'runIds',
      'operations',
    });
    if (json['ownershipComplete'] is! bool) {
      throw const FormatException('Missing conversation ownership marker.');
    }
    return ConversationTurn(
      id: historyText(json['id']),
      requestMessageId: historyText(json['requestMessageId']),
      ownershipComplete: json['ownershipComplete'] as bool,
      messageIds: historyIdList(json['messageIds'], max: 1000),
      runIds: historyIdList(json['runIds'], max: 1000),
      operations: historyList(
        json['operations'],
        max: 128,
      ).map(ConversationOperationBinding.fromJson),
    );
  }
}

/// Replaced transcript suffixes are immutable history. Viewing them never
/// changes active model context or replays tools. Full message serialization
/// preserves attachment references and protocol metadata owned by the chat.
class ConversationHistoryVersion {
  ConversationHistoryVersion({
    required this.id,
    required this.batchId,
    required this.createdAt,
    required Iterable<ConversationMessage> messages,
    required Iterable<ConversationRunUsage> runs,
    required Iterable<ConversationTurn> turns,
  }) : messages = List.unmodifiable(messages),
       runs = List.unmodifiable(runs),
       turns = List.unmodifiable(turns) {
    historyText(id);
    historyText(batchId);
    historyDate(createdAt.toUtc().toIso8601String());
    if (this.messages.isEmpty ||
        this.messages.length > 1000 ||
        this.runs.length > 1000 ||
        this.turns.length > 1000) {
      throw const FormatException('Conversation history exceeds its budget.');
    }
    validateConversationTurns(this.messages, this.runs, this.turns);
  }

  final String id;
  final String batchId;
  final DateTime createdAt;
  final List<ConversationMessage> messages;
  final List<ConversationRunUsage> runs;
  final List<ConversationTurn> turns;

  Map<String, Object?> toJson() => {
    'id': id,
    'batchId': batchId,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'messages': messages.map((item) => item.toJson()).toList(),
    'runs': runs.map((item) => item.toJson()).toList(),
    'turns': turns.map((item) => item.toJson()).toList(),
  };

  factory ConversationHistoryVersion.fromJson(Object? value) {
    final json = historyObject(value, {
      'id',
      'batchId',
      'createdAt',
      'messages',
      'runs',
      'turns',
    });
    return ConversationHistoryVersion(
      id: historyText(json['id']),
      batchId: historyText(json['batchId']),
      createdAt: historyDate(json['createdAt']),
      messages: historyList(json['messages'], max: 1000).map(
        (item) => ConversationMessage.fromJson(
          Map<String, dynamic>.from(historyObject(item)),
        ),
      ),
      runs: historyList(json['runs'], max: 1000).map(
        (item) => ConversationRunUsage.fromJson(
          Map<String, dynamic>.from(historyObject(item)),
        ),
      ),
      turns: historyList(
        json['turns'],
        max: 1000,
      ).map(ConversationTurn.fromJson),
    );
  }
}

/// Text-only alternatives for one assistant reply. Regenerating a reply does
/// not replace its tool calls, erase their receipts, or create a business turn.
/// The host selects the current text separately from browsing old alternatives.
class ConversationReplyRevision {
  ConversationReplyRevision({
    required this.id,
    required this.messageId,
    required this.runId,
    required this.createdAt,
    required this.text,
    required this.modelSelection,
    required this.providerProtocol,
  }) {
    for (final value in [id, messageId, runId]) {
      historyText(value);
    }
    historyDate(createdAt.toUtc().toIso8601String());
    historyText(text, max: 512 * 1024, empty: true);
  }

  final String id;
  final String messageId;
  final String runId;
  final DateTime createdAt;
  final String text;
  final AgentModelSelection modelSelection;
  final AgentModelProtocol providerProtocol;

  Map<String, Object?> toJson() => {
    'id': id,
    'messageId': messageId,
    'runId': runId,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'text': text,
    'modelSelection': modelSelection.toJson(),
    'providerProtocol': providerProtocol.name,
  };

  factory ConversationReplyRevision.fromJson(Object? value) {
    final json = historyObject(value, {
      'id',
      'messageId',
      'runId',
      'createdAt',
      'text',
      'modelSelection',
      'providerProtocol',
    });
    return ConversationReplyRevision(
      id: historyText(json['id']),
      messageId: historyText(json['messageId']),
      runId: historyText(json['runId']),
      createdAt: historyDate(json['createdAt']),
      text: historyText(json['text'], max: 512 * 1024, empty: true),
      modelSelection: AgentModelSelection.fromJson(json['modelSelection']),
      providerProtocol: historyEnum(
        AgentModelProtocol.values,
        json['providerProtocol'],
      ),
    );
  }
}

enum ConversationUndoOwner { main, knowledge }

/// A reference to the prepared inverse owned by its storage participant. It
/// deliberately contains no knowledge body, old business snapshot or permit.
class ConversationUndoTicket {
  ConversationUndoTicket({
    required this.owner,
    required this.token,
    required this.digest,
    required Iterable<String> operationIds,
  }) : operationIds = historyIds(operationIds, max: 128) {
    historyText(token);
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(digest) ||
        this.operationIds.isEmpty) {
      throw const FormatException('Invalid history undo ticket.');
    }
  }

  final ConversationUndoOwner owner;
  final String token;
  final String digest;
  final List<String> operationIds;

  Map<String, Object?> toJson() => {
    'owner': owner.name,
    'token': token,
    'digest': digest,
    'operationIds': operationIds,
  };

  factory ConversationUndoTicket.fromJson(Object? value) {
    final json = historyObject(value, {
      'owner',
      'token',
      'digest',
      'operationIds',
    });
    return ConversationUndoTicket(
      owner: historyEnum(ConversationUndoOwner.values, json['owner']),
      token: historyText(json['token']),
      digest: historyText(json['digest'], max: 64),
      operationIds: historyIdList(json['operationIds'], max: 128),
    );
  }
}

/// Interruption is separate from progress: a retry resumes this exact phase
/// and durable batch identity, rather than preparing another inverse.
enum ConversationRedoPhase {
  prepared,
  undoing,
  undone,
  ready,
  running,
  completed,
}

class ConversationRedoBatch {
  ConversationRedoBatch({
    required this.id,
    required this.conversationId,
    required this.sourceTurnId,
    required this.sourceMessageId,
    required this.historyVersionId,
    required this.replayRunId,
    required this.createdAt,
    required this.text,
    required this.contextDigest,
    required Iterable<String> turnIds,
    required Iterable<String> attachmentIds,
    this.modelSelection,
    this.phase = ConversationRedoPhase.prepared,
    this.lastError,
    Iterable<ConversationUndoTicket> tickets = const [],
    Iterable<ConversationUndoOwner> completedOwners = const [],
  }) : turnIds = historyIds(turnIds, max: 1000),
       attachmentIds = historyIds(attachmentIds, max: 20),
       tickets = List.unmodifiable(tickets),
       completedOwners = List.unmodifiable(completedOwners) {
    for (final value in [
      id,
      conversationId,
      sourceTurnId,
      sourceMessageId,
      historyVersionId,
      replayRunId,
    ]) {
      historyText(value);
    }
    historyDate(createdAt.toUtc().toIso8601String());
    historyText(text, max: 128 * 1024, empty: true);
    if (lastError != null) historyText(lastError, max: 128);
    if (this.turnIds.isEmpty ||
        this.turnIds.first != sourceTurnId ||
        text.trim().isEmpty && this.attachmentIds.isEmpty ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(contextDigest) ||
        this.tickets.map((item) => item.owner).toSet().length !=
            this.tickets.length ||
        this.tickets.expand((item) => item.operationIds).toSet().length !=
            this.tickets.fold<int>(
              0,
              (count, item) => count + item.operationIds.length,
            ) ||
        this.completedOwners.toSet().length != this.completedOwners.length ||
        this.completedOwners.any(
          (owner) => !this.tickets.any((ticket) => ticket.owner == owner),
        ) ||
        phase == ConversationRedoPhase.prepared &&
            this.completedOwners.isNotEmpty ||
        phase.index >= ConversationRedoPhase.undone.index &&
            this.completedOwners.length != this.tickets.length) {
      throw const FormatException('Invalid history redo progress.');
    }
  }

  final String id;
  final String conversationId;
  final String sourceTurnId;
  final String sourceMessageId;
  final String historyVersionId;
  final String replayRunId;
  final DateTime createdAt;
  final String text;
  final List<String> attachmentIds;
  final AgentModelSelection? modelSelection;
  final String contextDigest;
  final List<String> turnIds;
  final List<ConversationUndoTicket> tickets;
  final List<ConversationUndoOwner> completedOwners;
  final ConversationRedoPhase phase;
  final String? lastError;

  bool get isComplete => phase == ConversationRedoPhase.completed;

  ConversationRedoBatch copyWith({
    ConversationRedoPhase? phase,
    Iterable<ConversationUndoOwner>? completedOwners,
    String? lastError,
  }) => ConversationRedoBatch(
    id: id,
    conversationId: conversationId,
    sourceTurnId: sourceTurnId,
    sourceMessageId: sourceMessageId,
    historyVersionId: historyVersionId,
    replayRunId: replayRunId,
    createdAt: createdAt,
    text: text,
    attachmentIds: attachmentIds,
    modelSelection: modelSelection,
    contextDigest: contextDigest,
    turnIds: turnIds,
    tickets: tickets,
    phase: phase ?? this.phase,
    completedOwners: completedOwners ?? this.completedOwners,
    lastError: lastError,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'conversationId': conversationId,
    'sourceTurnId': sourceTurnId,
    'sourceMessageId': sourceMessageId,
    'historyVersionId': historyVersionId,
    'replayRunId': replayRunId,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'text': text,
    'attachmentIds': attachmentIds,
    if (modelSelection != null) 'modelSelection': modelSelection!.toJson(),
    'contextDigest': contextDigest,
    'turnIds': turnIds,
    'tickets': tickets.map((item) => item.toJson()).toList(),
    'completedOwners': completedOwners.map((item) => item.name).toList(),
    'phase': phase.name,
    if (lastError != null) 'lastError': lastError,
  };

  factory ConversationRedoBatch.fromJson(Object? value) {
    final json = historyObject(value, {
      'id',
      'conversationId',
      'sourceTurnId',
      'sourceMessageId',
      'historyVersionId',
      'replayRunId',
      'createdAt',
      'text',
      'attachmentIds',
      'modelSelection',
      'contextDigest',
      'turnIds',
      'tickets',
      'completedOwners',
      'phase',
      'lastError',
    });
    return ConversationRedoBatch(
      id: historyText(json['id']),
      conversationId: historyText(json['conversationId']),
      sourceTurnId: historyText(json['sourceTurnId']),
      sourceMessageId: historyText(json['sourceMessageId']),
      historyVersionId: historyText(json['historyVersionId']),
      replayRunId: historyText(json['replayRunId']),
      createdAt: historyDate(json['createdAt']),
      text: historyText(json['text'], max: 128 * 1024, empty: true),
      attachmentIds: historyIdList(json['attachmentIds'], max: 20),
      modelSelection: json['modelSelection'] == null
          ? null
          : AgentModelSelection.fromJson(json['modelSelection']),
      contextDigest: historyText(json['contextDigest'], max: 64),
      turnIds: historyIdList(json['turnIds'], max: 1000),
      tickets: historyList(
        json['tickets'],
        max: 2,
      ).map(ConversationUndoTicket.fromJson),
      completedOwners: historyList(
        json['completedOwners'],
        max: 2,
      ).map((item) => historyEnum(ConversationUndoOwner.values, item)),
      phase: historyEnum(ConversationRedoPhase.values, json['phase']),
      lastError: json['lastError'] == null
          ? null
          : historyText(json['lastError'], max: 128),
    );
  }
}

/// Strict references are also checked on the writer path. Partial legacy
/// ownership is allowed only outside owned turns; it never becomes reliable
/// merely because a recent app opened the archive.
void validateConversationTurns(
  List<ConversationMessage> messages,
  List<ConversationRunUsage> runs,
  List<ConversationTurn> turns,
) {
  final messageMap = {for (final message in messages) message.id: message};
  final runMap = {for (final run in runs) run.id: run};
  final ownedMessages = <String>{};
  final ownedRuns = <String>{};
  final ownedOperations = <String>{};
  var previousEnd = -1;
  if (messageMap.length != messages.length ||
      runMap.length != runs.length ||
      turns.map((item) => item.id).toSet().length != turns.length) {
    throw const FormatException('Duplicate conversation history identity.');
  }
  for (final turn in turns) {
    final request = messageMap[turn.requestMessageId];
    final positions = turn.messageIds
        .map((id) => messages.indexWhere((item) => item.id == id))
        .toList();
    final start = positions.first;
    if (request?.role != ConversationRole.user ||
        start <= previousEnd ||
        Iterable<int>.generate(positions.length - 1)
            .any((index) => positions[index + 1] <= positions[index]) ||
        turn.messageIds.any(
          (id) => !messageMap.containsKey(id) || !ownedMessages.add(id),
        ) ||
        turn.runIds.any(
          (id) => !runMap.containsKey(id) || !ownedRuns.add(id),
        ) ||
        turn.operations.any((item) => !ownedOperations.add(item.operationId))) {
      throw const FormatException('Invalid conversation history references.');
    }
    final calls = {
      for (final id in turn.messageIds)
        for (final call in messageMap[id]!.toolCalls) call.id,
    };
    if (turn.operations.any((item) => !calls.contains(item.toolCallId))) {
      throw const FormatException('An operation has no owning tool call.');
    }
    previousEnd = positions.last;
  }
}

Map<String, Object?> historyObject(Object? value, [Set<String>? fields]) {
  if (value is! Map ||
      value.keys.any((key) => key is! String) ||
      fields != null && value.keys.any((key) => !fields.contains(key))) {
    throw const FormatException('Invalid history object.');
  }
  return Map<String, Object?>.from(value);
}

String historyText(Object? value, {int max = 256, bool empty = false}) {
  if (value is! String ||
      value.length > max ||
      !empty && value.trim().isEmpty) {
    throw const FormatException('Invalid history text.');
  }
  return value;
}

List<Object?> historyList(Object? value, {required int max}) {
  if (value is! List || value.length > max) {
    throw const FormatException('Invalid history list.');
  }
  return List<Object?>.from(value);
}

List<String> historyIdList(Object? value, {required int max}) =>
    historyIds(historyList(value, max: max).map(historyText), max: max);

List<String> historyIds(Iterable<String> value, {required int max}) {
  final items = List<String>.unmodifiable(value);
  if (items.length > max || items.toSet().length != items.length) {
    throw const FormatException('Invalid history identities.');
  }
  for (final item in items) {
    historyText(item);
  }
  return items;
}

T historyEnum<T extends Enum>(List<T> values, Object? value) =>
    values.where((item) => item.name == value).firstOrNull ??
    (throw const FormatException('Invalid history enum.'));

DateTime historyDate(Object? value) {
  final parsed = tryParseStrictIsoDateTime(historyText(value, max: 40));
  if (parsed == null ||
      !parsed.isUtc ||
      parsed.year < 1 ||
      parsed.year > 9999) {
    throw const FormatException('Invalid history timestamp.');
  }
  return parsed;
}

/// Used to reject a stale editor or a changed transcript before its suffix is
/// retired. Array order is significant; no text, item or field is truncated.
String conversationHistorySource(List<ConversationMessage> messages) =>
    jsonEncode(messages.map((message) => message.toJson()).toList());
