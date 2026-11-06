import 'dart:convert';

import '../history/conversation_history.dart';

import 'package:crypto/crypto.dart';

import '../../application/operation_contracts.dart';
import '../../models/agent_settings.dart';
import '../../utils/time_utils.dart' show tryParseStrictIsoDateTime;
import '../attachments/attachment_models.dart';
import 'conversation_usage.dart';

export 'conversation_usage.dart';
export '../attachments/attachment_models.dart';

enum ConversationStatus { idle, running, waitingApproval, interrupted }

enum ConversationRole { user, assistant, tool, notice }

class ConversationToolCall {
  const ConversationToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });
  final String id;
  final String name;
  final String arguments;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'arguments': arguments,
  };

  factory ConversationToolCall.fromJson(Map<String, dynamic> json) =>
      ConversationToolCall(
        id: _string(json, 'id', max: 256),
        name: _string(json, 'name', max: 128),
        arguments: _string(json, 'arguments', max: 128 * 1024, empty: true),
      );
}

class ConversationMessage {
  ConversationMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
    Iterable<ConversationToolCall> toolCalls = const [],
    this.toolCallId,
    this.modelSelection,
    this.providerProtocol,
    Iterable<String> attachmentIds = const [],
    this.attachmentDelivery = AttachmentDelivery.local,
    Iterable<Map<String, Object?>> responseItems = const [],
  }) : toolCalls = List.unmodifiable(toolCalls),
       attachmentIds = List.unmodifiable(attachmentIds),
       responseItems = _freezeResponseItems(responseItems) {
    if (this.responseItems.isNotEmpty && role != ConversationRole.assistant) {
      throw const FormatException(
        'Only assistant messages have provider items.',
      );
    }
    if (this.attachmentIds.length > ConversationAttachment.maxPerMessage ||
        this.attachmentIds.any((id) => !validAttachmentId(id)) ||
        this.attachmentIds.toSet().length != this.attachmentIds.length ||
        (this.attachmentIds.isNotEmpty &&
            role != ConversationRole.user &&
            role != ConversationRole.notice)) {
      throw const FormatException('Invalid message attachment references.');
    }
  }

  final String id;
  final ConversationRole role;
  final String text;
  final DateTime createdAt;
  final List<ConversationToolCall> toolCalls;
  final String? toolCallId;
  final AgentModelSelection? modelSelection;
  final AgentModelProtocol? providerProtocol;
  final List<String> attachmentIds;
  final AttachmentDelivery attachmentDelivery;

  ConversationMessage copyWith({
    String? text,
    ConversationRole? role,
    AgentModelSelection? modelSelection,
    AgentModelProtocol? providerProtocol,
    Iterable<Map<String, Object?>>? responseItems,
    Iterable<String>? attachmentIds,
    AttachmentDelivery? attachmentDelivery,
  }) => ConversationMessage(
    id: id,
    role: role ?? this.role,
    text: text ?? this.text,
    createdAt: createdAt,
    toolCalls: toolCalls,
    toolCallId: toolCallId,
    responseItems: responseItems ?? this.responseItems,
    modelSelection: modelSelection ?? this.modelSelection,
    providerProtocol: providerProtocol ?? this.providerProtocol,
    attachmentIds: attachmentIds ?? this.attachmentIds,
    attachmentDelivery: attachmentDelivery ?? this.attachmentDelivery,
  );

  /// Bounded, immutable provider continuation data; never request headers or
  /// credentials. The model endpoint remains bound at conversation level.
  final List<Map<String, Object?>> responseItems;

  Map<String, Object?> toJson() => {
    'id': id,
    'role': role.name,
    'text': text,
    'createdAt': createdAt.toUtc().toIso8601String(),
    if (toolCalls.isNotEmpty)
      'toolCalls': toolCalls.map((call) => call.toJson()).toList(),
    if (toolCallId != null) 'toolCallId': toolCallId,
    if (responseItems.isNotEmpty) 'responseItems': responseItems,
    if (modelSelection != null) 'modelSelection': modelSelection!.toJson(),
    if (providerProtocol != null) 'providerProtocol': providerProtocol!.name,
    if (attachmentIds.isNotEmpty) 'attachmentIds': attachmentIds,
    if (attachmentIds.isNotEmpty) 'attachmentDelivery': attachmentDelivery.name,
  };

  factory ConversationMessage.fromJson(Map<String, dynamic> json) {
    final role = _enumValue(ConversationRole.values, json['role']);
    final calls = _objects(
      json,
      'toolCalls',
      max: 32,
    ).map(ConversationToolCall.fromJson).toList();
    final toolCallId = _optionalString(json, 'toolCallId', max: 256);
    if ((role == ConversationRole.tool) != (toolCallId != null) ||
        (calls.isNotEmpty && role != ConversationRole.assistant) ||
        calls.map((call) => call.id).toSet().length != calls.length) {
      throw const FormatException('Invalid conversation tool message.');
    }
    return ConversationMessage(
      id: _string(json, 'id', max: 256),
      role: role,
      text: _string(json, 'text', max: 512 * 1024, empty: true),
      createdAt: _date(json, 'createdAt'),
      toolCalls: calls,
      toolCallId: toolCallId,
      responseItems: _objects(json, 'responseItems', max: 64),
      modelSelection: json['modelSelection'] == null
          ? null
          : AgentModelSelection.fromJson(json['modelSelection']),
      providerProtocol: json['providerProtocol'] == null
          ? null
          : _enumValue(AgentModelProtocol.values, json['providerProtocol']),
      attachmentIds: _attachmentIds(json['attachmentIds']),
      attachmentDelivery: json['attachmentDelivery'] == null
          ? AttachmentDelivery.local
          : _enumValue(AttachmentDelivery.values, json['attachmentDelivery']),
    );
  }
}

List<Map<String, Object?>> _freezeResponseItems(
  Iterable<Map<String, Object?>> source,
) {
  final items = source.toList();
  if (items.length > 64) {
    throw const FormatException('Provider continuation has too many items.');
  }
  var nodes = 0;
  Object? freeze(Object? value, int depth) {
    if (depth > 20 || ++nodes > 20000) {
      throw const FormatException('Provider continuation is too complex.');
    }
    if (value is Map) {
      final result = <String, Object?>{};
      for (final entry in value.entries) {
        final key = entry.key;
        if (key is! String ||
            key.length > 128 ||
            const {
              'authorization',
              'api_key',
              'apikey',
              'access_token',
              'cookie',
              'set-cookie',
              'password',
            }.contains(key.toLowerCase())) {
          throw const FormatException('Invalid provider continuation field.');
        }
        result[key] = freeze(entry.value, depth + 1);
      }
      return Map<String, Object?>.unmodifiable(result);
    }
    if (value is List) {
      return List<Object?>.unmodifiable(
        value.map((item) => freeze(item, depth + 1)),
      );
    }
    if (value is String && value.length > 512 * 1024) {
      throw const FormatException('Provider continuation text is too large.');
    }
    if (value == null ||
        value is String ||
        value is bool ||
        (value is num && value.isFinite)) {
      return value;
    }
    throw const FormatException('Invalid provider continuation value.');
  }

  final result = List<Map<String, Object?>>.unmodifiable(
    items.map((item) => freeze(item, 0)! as Map<String, Object?>),
  );
  if (utf8.encode(jsonEncode(result)).length > 512 * 1024) {
    throw const FormatException(
      'Provider continuation exceeds its byte budget.',
    );
  }
  return result;
}

/// Immutable user-selected material. It contains no browser session state.
class ConversationSource {
  const ConversationSource({
    required this.id,
    required this.text,
    required this.kind,
    this.url,
    this.targetId,
    this.truncated = false,
    this.provenance,
    this.attachedAfterRunId,
    this.attachedAfterMessageId,
  });

  final String id;
  final String text;
  final String kind;
  final String? url;
  final String? targetId;
  final bool truncated;
  final ConversationSourceProvenance? provenance;
  final String? attachedAfterRunId;
  final String? attachedAfterMessageId;

  String get digest =>
      sha256.convert(utf8.encode(jsonEncode(toJson()))).toString();

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind,
    'text': text,
    if (url != null) 'url': url,
    if (targetId != null) 'targetId': targetId,
    'truncated': truncated,
    if (provenance != null) 'provenance': provenance!.toJson(),
    if (attachedAfterRunId != null) 'attachedAfterRunId': attachedAfterRunId,
    if (attachedAfterMessageId != null)
      'attachedAfterMessageId': attachedAfterMessageId,
  };

  factory ConversationSource.fromJson(Map<String, dynamic> json) {
    final url = _optionalString(json, 'url', max: 4096);
    if (url != null) {
      final uri = Uri.tryParse(url);
      if (uri == null ||
          !['http', 'https'].contains(uri.scheme) ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty) {
        throw const FormatException('Invalid source URL.');
      }
    }
    if (json['truncated'] is! bool) {
      throw const FormatException('Invalid source truncation state.');
    }
    if ((json['attachedAfterRunId'] != null ||
            json['attachedAfterMessageId'] != null) &&
        json['kind'] != 'structured_file') {
      throw const FormatException(
        'Only structured file attachments carry unused-source markers.',
      );
    }
    return ConversationSource(
      id: _string(json, 'id', max: 256),
      kind: _string(json, 'kind', max: 64),
      text: _string(json, 'text', max: 512 * 1024, empty: true),
      url: url,
      targetId: _optionalString(json, 'targetId', max: 256),
      truncated: json['truncated'] as bool,
      attachedAfterRunId: _optionalString(json, 'attachedAfterRunId', max: 256),
      attachedAfterMessageId: _optionalString(
        json,
        'attachedAfterMessageId',
        max: 256,
      ),
      provenance: json['provenance'] == null
          ? null
          : ConversationSourceProvenance.fromJson(_object(json['provenance'])),
    );
  }
}

/// Bounded provenance for a reviewed source, separate from its data body.
/// Its absence preserves the exact JSON and digest of historical sources.
class ConversationSourceProvenance {
  const ConversationSourceProvenance({
    required this.title,
    required this.capturedAt,
    required this.reviewedAt,
    required this.datasetGeneration,
    required this.localeCode,
    this.revision = 1,
  });

  final String title;
  final DateTime capturedAt;
  final DateTime reviewedAt;
  final String datasetGeneration;
  final String localeCode;
  final int revision;

  Map<String, Object?> toJson() => {
    'title': title,
    'capturedAt': capturedAt.toUtc().toIso8601String(),
    'reviewedAt': reviewedAt.toUtc().toIso8601String(),
    'datasetGeneration': datasetGeneration,
    'localeCode': localeCode,
    'revision': revision,
  };

  factory ConversationSourceProvenance.fromJson(Map<String, dynamic> json) {
    const keys = {
      'title',
      'capturedAt',
      'reviewedAt',
      'datasetGeneration',
      'localeCode',
      'revision',
    };
    if (json.keys.any((key) => !keys.contains(key)) ||
        json['revision'] is! int ||
        (json['revision'] as int) < 1 ||
        (json['revision'] as int) > 2147483647) {
      throw const FormatException('Invalid source provenance.');
    }
    return ConversationSourceProvenance(
      title: _string(json, 'title', max: 256, empty: true),
      capturedAt: _date(json, 'capturedAt'),
      reviewedAt: _date(json, 'reviewedAt'),
      datasetGeneration: _string(json, 'datasetGeneration', max: 256),
      localeCode: _string(json, 'localeCode', max: 32),
      revision: json['revision'] as int,
    );
  }
}

class AgentConversation {
  AgentConversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.mode = AgentPermissionMode.ask,
    this.status = ConversationStatus.idle,
    this.archived = false,
    this.draft = '',
    this.connectionFingerprint,
    this.runId,
    this.modelSelection,
    this.executionHistoryStart = 0,
    Iterable<ConversationMessage> messages = const [],
    Iterable<ConversationSource> sources = const [],
    Iterable<ConversationRunUsage> runs = const [],
    Iterable<ConversationAttachment> attachments = const [],
    Iterable<String> draftAttachmentIds = const [],
    Iterable<ConversationTurn> turns = const [],
    Iterable<ConversationHistoryVersion> historyVersions = const [],
    Iterable<ConversationReplyRevision> replyRevisions = const [],
    Iterable<ConversationRedoBatch> redoBatches = const [],
  }) : messages = List.unmodifiable(messages),
       sources = List.unmodifiable(sources),
       runs = List.unmodifiable(runs),
       attachments = List.unmodifiable(attachments),
       draftAttachmentIds = List.unmodifiable(draftAttachmentIds),
       turns = List.unmodifiable(turns),
       historyVersions = List.unmodifiable(historyVersions),
       replyRevisions = List.unmodifiable(replyRevisions),
       redoBatches = List.unmodifiable(redoBatches) {
    if (executionHistoryStart < 0 ||
        executionHistoryStart > this.messages.length) {
      throw const FormatException('Invalid executable history boundary.');
    }
    validateConversationTurns(this.messages, this.runs, this.turns);
  }

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final AgentPermissionMode mode;
  final ConversationStatus status;
  final bool archived;
  final String draft;
  final String? connectionFingerprint;
  final String? runId;
  final AgentModelSelection? modelSelection;
  final int executionHistoryStart;
  Iterable<ConversationMessage> get executionMessages =>
      messages.skip(executionHistoryStart);
  final List<ConversationMessage> messages;
  final List<ConversationSource> sources;
  final List<ConversationRunUsage> runs;
  final List<ConversationAttachment> attachments;
  final List<String> draftAttachmentIds;
  final List<ConversationTurn> turns;
  final List<ConversationHistoryVersion> historyVersions;
  final List<ConversationReplyRevision> replyRevisions;
  final List<ConversationRedoBatch> redoBatches;
  ConversationRedoBatch? get pendingRedo =>
      redoBatches.where((batch) => !batch.isComplete).firstOrNull;

  AgentConversation copyWith({
    String? title,
    DateTime? updatedAt,
    AgentPermissionMode? mode,
    ConversationStatus? status,
    bool? archived,
    String? draft,
    String? connectionFingerprint,
    String? runId,
    AgentModelSelection? modelSelection,
    int? executionHistoryStart,
    bool clearRunId = false,
    bool clearConnectionFingerprint = false,
    Iterable<ConversationMessage>? messages,
    Iterable<ConversationSource>? sources,
    Iterable<ConversationRunUsage>? runs,
    Iterable<ConversationAttachment>? attachments,
    Iterable<String>? draftAttachmentIds,
    Iterable<ConversationTurn>? turns,
    Iterable<ConversationHistoryVersion>? historyVersions,
    Iterable<ConversationReplyRevision>? replyRevisions,
    Iterable<ConversationRedoBatch>? redoBatches,
  }) => AgentConversation(
    id: id,
    title: title ?? this.title,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    mode: mode ?? this.mode,
    status: status ?? this.status,
    archived: archived ?? this.archived,
    draft: draft ?? this.draft,
    connectionFingerprint: clearConnectionFingerprint
        ? null
        : connectionFingerprint ?? this.connectionFingerprint,
    runId: clearRunId ? null : runId ?? this.runId,
    modelSelection: modelSelection ?? this.modelSelection,
    executionHistoryStart: executionHistoryStart ?? this.executionHistoryStart,
    messages: messages ?? this.messages,
    sources: sources ?? this.sources,
    runs: runs ?? this.runs,
    attachments: attachments ?? this.attachments,
    draftAttachmentIds: draftAttachmentIds ?? this.draftAttachmentIds,
    turns: turns ?? this.turns,
    historyVersions: historyVersions ?? this.historyVersions,
    replyRevisions: replyRevisions ?? this.replyRevisions,
    redoBatches: redoBatches ?? this.redoBatches,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'mode': mode.name,
    'status': status.name,
    'archived': archived,
    'draft': draft,
    if (connectionFingerprint != null)
      'connectionFingerprint': connectionFingerprint,
    if (runId != null) 'runId': runId,
    if (modelSelection != null) 'modelSelection': modelSelection!.toJson(),
    'executionHistoryStart': executionHistoryStart,
    'messages': messages.map((message) => message.toJson()).toList(),
    'sources': sources.map((source) => source.toJson()).toList(),
    'runs': runs.map((run) => run.toJson()).toList(),
    if (attachments.isNotEmpty)
      'attachments': attachments
          .map((attachment) => attachment.toJson())
          .toList(),
    if (draftAttachmentIds.isNotEmpty) 'draftAttachmentIds': draftAttachmentIds,
    'turns': turns.map((item) => item.toJson()).toList(),
    'historyVersions': historyVersions.map((item) => item.toJson()).toList(),
    'replyRevisions': replyRevisions.map((item) => item.toJson()).toList(),
    'redoBatches': redoBatches.map((item) => item.toJson()).toList(),
  };

  factory AgentConversation.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('archived') && json['archived'] is! bool) {
      throw const FormatException('Invalid archived conversation state.');
    }
    final messages = _objects(
      json,
      'messages',
      max: 1000,
    ).map(ConversationMessage.fromJson).toList();
    final sources = _objects(
      json,
      'sources',
      max: 20,
    ).map(ConversationSource.fromJson).toList();
    final runs = _objects(
      json,
      'runs',
      max: 1000,
    ).map(ConversationRunUsage.fromJson).toList();
    final attachments = _objects(
      json,
      'attachments',
      max: 1000,
    ).map(ConversationAttachment.fromJson).toList();
    final draftAttachmentIds = _attachmentIds(json['draftAttachmentIds']);
    final turns = _objects(
      json,
      'turns',
      max: 1000,
    ).map(ConversationTurn.fromJson).toList();
    final historyVersions = _objects(
      json,
      'historyVersions',
      max: 32,
    ).map(ConversationHistoryVersion.fromJson).toList();
    final replyRevisions = _objects(
      json,
      'replyRevisions',
      max: 1000,
    ).map(ConversationReplyRevision.fromJson).toList();
    final redoBatches = _objects(
      json,
      'redoBatches',
      max: 32,
    ).map(ConversationRedoBatch.fromJson).toList();
    final executionHistoryStart = json['executionHistoryStart'] ?? 0;
    if (executionHistoryStart is! int ||
        executionHistoryStart < 0 ||
        executionHistoryStart > messages.length ||
        historyVersions.map((item) => item.id).toSet().length !=
            historyVersions.length ||
        replyRevisions.map((item) => item.id).toSet().length !=
            replyRevisions.length ||
        redoBatches.map((item) => item.id).toSet().length !=
            redoBatches.length ||
        redoBatches.where((item) => !item.isComplete).length > 1 ||
        redoBatches.any((item) => item.conversationId != json['id'])) {
      throw const FormatException('Invalid conversation history references.');
    }
    final attachmentIds = attachments.map((a) => a.id).toSet();
    if (attachmentIds.length != attachments.length ||
        [
          ...draftAttachmentIds,
          ...messages.expand((m) => m.attachmentIds),
          ...historyVersions
              .expand((v) => v.messages)
              .expand((m) => m.attachmentIds),
          ...redoBatches.expand((batch) => batch.attachmentIds),
        ].any((id) => !attachmentIds.contains(id))) {
      throw const FormatException(
        'Missing or duplicate attachment references.',
      );
    }
    if (messages.map((message) => message.id).toSet().length !=
            messages.length ||
        sources.map((source) => source.id).toSet().length != sources.length ||
        runs.map((run) => run.id).toSet().length != runs.length ||
        runs
                .expand((run) => run.requests)
                .map((request) => request.id)
                .toSet()
                .length !=
            runs.fold<int>(0, (count, run) => count + run.requests.length)) {
      throw const FormatException('Duplicate conversation item ID.');
    }
    return AgentConversation(
      id: _string(json, 'id', max: 256),
      title: _string(json, 'title', max: 256),
      createdAt: _date(json, 'createdAt'),
      updatedAt: _date(json, 'updatedAt'),
      mode: _enumValue(AgentPermissionMode.values, json['mode']),
      status: _enumValue(ConversationStatus.values, json['status']),
      archived: json['archived'] as bool? ?? false,
      draft: _string(json, 'draft', max: 128 * 1024, empty: true),
      connectionFingerprint: _optionalString(
        json,
        'connectionFingerprint',
        max: 256,
      ),
      runId: _optionalString(json, 'runId', max: 256),
      modelSelection: json['modelSelection'] == null
          ? null
          : AgentModelSelection.fromJson(json['modelSelection']),
      messages: messages,
      sources: sources,
      runs: runs,
      attachments: attachments,
      draftAttachmentIds: draftAttachmentIds,
      executionHistoryStart: executionHistoryStart,
      turns: turns,
      historyVersions: historyVersions,
      replyRevisions: replyRevisions,
      redoBatches: redoBatches,
    );
  }
}

class ConversationHandoff {
  const ConversationHandoff({
    required this.id,
    required this.conversationId,
    required this.sourceDigest,
    required this.messageId,
  });
  final String id;
  final String conversationId;
  final String sourceDigest;
  final String messageId;

  Map<String, Object?> toJson() => {
    'id': id,
    'conversationId': conversationId,
    'sourceDigest': sourceDigest,
    'messageId': messageId,
  };

  factory ConversationHandoff.fromJson(Map<String, dynamic> json) =>
      ConversationHandoff(
        id: _string(json, 'id', max: 256),
        conversationId: _string(json, 'conversationId', max: 256),
        sourceDigest: _string(json, 'sourceDigest', max: 64),
        messageId: _string(json, 'messageId', max: 256),
      );
}

/// One durable unit includes the handoff mapping, conversation and first message.
class ConversationArchive {
  ConversationArchive({
    this.revision = 0,
    this.selectedId,
    Iterable<AgentConversation> conversations = const [],
    Iterable<ConversationHandoff> handoffs = const [],
    Iterable<String> terminatedIds = const [],
  }) : conversations = List.unmodifiable(conversations),
       handoffs = List.unmodifiable(handoffs),
       terminatedIds = Set.unmodifiable(terminatedIds);

  static const maxBytes = 16 * 1024 * 1024;
  static const currentVersion = 5;
  final int revision;
  final String? selectedId;
  final List<AgentConversation> conversations;
  final List<ConversationHandoff> handoffs;
  final Set<String> terminatedIds;

  String encode() {
    final encoded = jsonEncode({
      'version': currentVersion,
      'revision': revision,
      'selectedId': selectedId,
      'conversations': conversations.map((item) => item.toJson()).toList(),
      'handoffs': handoffs.map((item) => item.toJson()).toList(),
      'terminatedIds': terminatedIds.toList(),
    });
    if (utf8.encode(encoded).length > maxBytes) {
      throw const FormatException(
        'Conversation archive exceeds its size budget.',
      );
    }
    return encoded;
  }

  factory ConversationArchive.decode(String source) {
    if (utf8.encode(source).length > maxBytes) {
      throw const FormatException(
        'Conversation archive exceeds its size budget.',
      );
    }
    final json = _object(jsonDecode(source));
    if ((!const [1, 2, 3, 4, currentVersion].contains(json['version'])) ||
        json['revision'] is! int ||
        (json['revision'] as int) < 0) {
      throw const FormatException('Unsupported conversation archive version.');
    }
    final conversations = _objects(
      json,
      'conversations',
      max: 200,
    ).map(AgentConversation.fromJson).toList();
    final attachmentDefinitions = <String, String>{};
    for (final attachment in conversations.expand((c) => c.attachments)) {
      final definition = jsonEncode(attachment.toJson());
      final previous = attachmentDefinitions[attachment.id];
      if (previous != null && previous != definition) {
        throw const FormatException('Conflicting shared attachment identity.');
      }
      attachmentDefinitions[attachment.id] = definition;
    }
    final handoffs = _objects(
      json,
      'handoffs',
      max: 10000,
    ).map(ConversationHandoff.fromJson).toList();
    final rawTerminated = json['terminatedIds'];
    if (rawTerminated is! List ||
        rawTerminated.length > 10000 ||
        rawTerminated.any(
          (id) => id is! String || id.isEmpty || id.length > 256,
        )) {
      throw const FormatException(
        'Invalid terminated conversation identities.',
      );
    }
    final terminated = rawTerminated.cast<String>().toSet();
    final ids = conversations.map((item) => item.id).toSet();
    final selected = _optionalString(json, 'selectedId', max: 256);
    if (ids.length != conversations.length ||
        ids.intersection(terminated).isNotEmpty ||
        (selected != null && !ids.contains(selected)) ||
        handoffs.map((item) => item.id).toSet().length != handoffs.length ||
        handoffs.any(
          (item) =>
              !ids.contains(item.conversationId) &&
              !terminated.contains(item.conversationId),
        )) {
      throw const FormatException('Invalid conversation archive references.');
    }
    for (final handoff in handoffs) {
      final conversation = conversations
          .where((c) => c.id == handoff.conversationId)
          .firstOrNull;
      if (conversation != null &&
          (![
                ...conversation.messages,
                ...conversation.historyVersions.expand((v) => v.messages),
              ].any((m) => m.id == handoff.messageId) ||
              !conversation.sources.any(
                (asset) => asset.digest == handoff.sourceDigest,
              ))) {
        throw const FormatException('Incomplete conversation handoff.');
      }
    }
    return ConversationArchive(
      revision: json['revision'] as int,
      selectedId: selected,
      conversations: conversations,
      handoffs: handoffs,
      terminatedIds: terminated,
    );
  }
}

List<String> _attachmentIds(Object? value) {
  if (value == null) return const [];
  if (value is! List ||
      value.length > ConversationAttachment.maxPerMessage ||
      value.any((id) => id is! String || !validAttachmentId(id)) ||
      value.toSet().length != value.length) {
    throw const FormatException('Invalid attachment references.');
  }
  return value.cast<String>();
}

Set<String> conversationAttachmentIds(AgentConversation conversation) => {
  ...conversation.draftAttachmentIds,
  ...conversation.messages.expand((message) => message.attachmentIds),
  ...conversation.historyVersions
      .expand((version) => version.messages)
      .expand((message) => message.attachmentIds),
  ...conversation.redoBatches.expand((batch) => batch.attachmentIds),
};

Map<String, dynamic> _object(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Expected object.');
  }
  return value;
}

List<Map<String, dynamic>> _objects(
  Map<String, dynamic> json,
  String key, {
  required int max,
}) {
  final raw = json.containsKey(key) ? json[key] : const [];
  if (raw is! List || raw.length > max) {
    throw FormatException('Invalid $key list.');
  }
  return raw.map(_object).toList();
}

String _string(
  Map<String, dynamic> json,
  String key, {
  required int max,
  bool empty = false,
}) {
  final raw = json[key];
  if (raw is! String || raw.length > max || (!empty && raw.trim().isEmpty)) {
    throw FormatException('Invalid $key string.');
  }
  return raw;
}

String? _optionalString(
  Map<String, dynamic> json,
  String key, {
  required int max,
}) => json[key] == null ? null : _string(json, key, max: max);

T _enumValue<T extends Enum>(List<T> values, Object? raw) =>
    values.where((item) => item.name == raw).firstOrNull ??
    (throw const FormatException('Unknown conversation enum value.'));

DateTime _date(Map<String, dynamic> json, String key) {
  final value = _string(json, key, max: 40);
  final parsed = tryParseStrictIsoDateTime(value);
  if (parsed == null ||
      !parsed.isUtc ||
      parsed.year < 1 ||
      parsed.year > 9999) {
    throw FormatException('Invalid $key timestamp.');
  }
  return parsed;
}
