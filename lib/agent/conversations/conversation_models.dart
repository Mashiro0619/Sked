import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../application/operation_contracts.dart';
import '../../models/agent_settings.dart';
import '../../utils/time_utils.dart' show tryParseStrictIsoDateTime;
import 'conversation_usage.dart';

export 'conversation_usage.dart';

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
    Iterable<Map<String, Object?>> responseItems = const [],
  }) : toolCalls = List.unmodifiable(toolCalls),
       responseItems = _freezeResponseItems(responseItems) {
    if (this.responseItems.isNotEmpty && role != ConversationRole.assistant) {
      throw const FormatException(
        'Only assistant messages have provider items.',
      );
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

  /// Bounded, immutable Responses continuation data; never request headers or
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
    Iterable<ConversationMessage> messages = const [],
    Iterable<ConversationSource> sources = const [],
    Iterable<ConversationRunUsage> runs = const [],
  }) : messages = List.unmodifiable(messages),
       sources = List.unmodifiable(sources),
       runs = List.unmodifiable(runs);

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
  final List<ConversationMessage> messages;
  final List<ConversationSource> sources;
  final List<ConversationRunUsage> runs;

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
    Iterable<ConversationMessage>? messages,
    Iterable<ConversationSource>? sources,
    Iterable<ConversationRunUsage>? runs,
  }) => AgentConversation(
    id: id,
    title: title ?? this.title,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    mode: mode ?? this.mode,
    status: status ?? this.status,
    archived: archived ?? this.archived,
    draft: draft ?? this.draft,
    connectionFingerprint: connectionFingerprint ?? this.connectionFingerprint,
    runId: runId ?? this.runId,
    modelSelection: modelSelection ?? this.modelSelection,
    messages: messages ?? this.messages,
    sources: sources ?? this.sources,
    runs: runs ?? this.runs,
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
    'messages': messages.map((message) => message.toJson()).toList(),
    'sources': sources.map((source) => source.toJson()).toList(),
    'runs': runs.map((run) => run.toJson()).toList(),
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
  static const currentVersion = 3;
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
    if ((!const [1, 2, currentVersion].contains(json['version'])) ||
        json['revision'] is! int ||
        (json['revision'] as int) < 0) {
      throw const FormatException('Unsupported conversation archive version.');
    }
    final conversations = _objects(
      json,
      'conversations',
      max: 200,
    ).map(AgentConversation.fromJson).toList();
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
          (!conversation.messages.any((m) => m.id == handoff.messageId) ||
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
