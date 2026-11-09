import 'dart:convert';

import '../history/conversation_history.dart';

import 'package:crypto/crypto.dart';

import '../../application/operation_contracts.dart';
import '../../models/agent_settings.dart';
import '../../utils/time_utils.dart' show tryParseStrictIsoDateTime;
import '../attachments/attachment_models.dart';
import '../interactions/agent_question.dart';
import '../operations/tool_outcome.dart';
import '../references/agent_composer_reference.dart';
import 'conversation_usage.dart';
import 'conversation_title.dart';

export 'conversation_usage.dart';
export 'conversation_title.dart';
export '../attachments/attachment_models.dart';

enum ConversationStatus {
  idle,
  running,
  stopping,
  waitingApproval,
  waitingUser,
  interrupted,
}

enum ConversationRole { user, assistant, tool, system, notice }

enum ConversationQueuedInputMode { followUp, steering }

enum ConversationControlKind { compactContext }

enum ConversationControlStatus { queued, failed, cancelled }

class ConversationControlCommand {
  ConversationControlCommand({
    required this.id,
    required this.kind,
    required this.createdAt,
    this.status = ConversationControlStatus.queued,
    this.errorMessage,
  }) {
    if (id.isEmpty) {
      throw const FormatException('Invalid conversation control identity.');
    }
  }

  final String id;
  final ConversationControlKind kind;
  final DateTime createdAt;
  final ConversationControlStatus status;
  final String? errorMessage;

  ConversationControlCommand copyWith({
    ConversationControlStatus? status,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) => ConversationControlCommand(
    id: id,
    kind: kind,
    createdAt: createdAt,
    status: status ?? this.status,
    errorMessage: clearErrorMessage ? null : errorMessage ?? this.errorMessage,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'status': status.name,
    if (errorMessage != null) 'errorMessage': errorMessage,
  };

  factory ConversationControlCommand.fromJson(Map<String, dynamic> json) =>
      ConversationControlCommand(
        id: _string(json, 'id'),
        kind: _enumValue(ConversationControlKind.values, json['kind']),
        createdAt: _date(json, 'createdAt'),
        status: _enumValue(ConversationControlStatus.values, json['status']),
        errorMessage: json['errorMessage'] == null
            ? null
            : _string(json, 'errorMessage', empty: true),
      );
}

class ConversationQueuedInput {
  ConversationQueuedInput({
    required this.id,
    required this.text,
    required this.createdAt,
    this.mode = ConversationQueuedInputMode.followUp,
    this.modelSelection,
    Iterable<String> attachmentIds = const [],
    Iterable<AgentComposerReference> contextReferences = const [],
  }) : attachmentIds = List.unmodifiable(attachmentIds),
       contextReferences = AgentComposerReference.validatedList(
         contextReferences,
       ) {
    if (id.isEmpty ||
        this.attachmentIds.toSet().length != this.attachmentIds.length ||
        this.attachmentIds.any((id) => !validAttachmentId(id)) ||
        (text.trim().isEmpty &&
            this.attachmentIds.isEmpty &&
            this.contextReferences.isEmpty)) {
      throw const FormatException('Invalid queued Agent input.');
    }
  }
  final String id, text;
  final DateTime createdAt;
  final ConversationQueuedInputMode mode;
  final AgentModelSelection? modelSelection;
  final List<String> attachmentIds;
  final List<AgentComposerReference> contextReferences;

  ConversationQueuedInput copyWith({
    String? text,
    ConversationQueuedInputMode? mode,
    AgentModelSelection? modelSelection,
    Iterable<String>? attachmentIds,
    Iterable<AgentComposerReference>? contextReferences,
  }) => ConversationQueuedInput(
    id: id,
    text: text ?? this.text,
    createdAt: createdAt,
    mode: mode ?? this.mode,
    modelSelection: modelSelection ?? this.modelSelection,
    attachmentIds: attachmentIds ?? this.attachmentIds,
    contextReferences: contextReferences ?? this.contextReferences,
  );

  ConversationMessage asUserMessage() => ConversationMessage(
    id: id,
    role: ConversationRole.user,
    text: text,
    createdAt: createdAt,
    modelSelection: modelSelection,
    attachmentIds: attachmentIds,
    contextReferences: contextReferences,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'text': text,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'mode': mode.name,
    if (modelSelection != null) 'modelSelection': modelSelection!.toJson(),
    'attachmentIds': attachmentIds,
    'contextReferences': contextReferences
        .map((item) => item.toJson())
        .toList(),
  };

  factory ConversationQueuedInput.fromJson(Map<String, dynamic> json) =>
      ConversationQueuedInput(
        id: _string(json, 'id'),
        text: _string(json, 'text', empty: true),
        createdAt: _date(json, 'createdAt'),
        mode: _enumValue(ConversationQueuedInputMode.values, json['mode']),
        modelSelection: json['modelSelection'] == null
            ? null
            : AgentModelSelection.fromJson(json['modelSelection']),
        attachmentIds: _attachmentIds(json['attachmentIds']),
        contextReferences: AgentComposerReference.decodeList(
          json['contextReferences'],
        ),
      );
}

Map<String, Object?>? decodeConversationToolObject(String source) {
  try {
    final value = jsonDecode(source);
    return value is Map<String, dynamic> ? Map.unmodifiable(value) : null;
  } on FormatException {
    return null;
  }
}

ToolOutcome? conversationToolOutcome(String source) {
  final value = decodeConversationToolObject(source);
  return value == null ? null : ToolOutcome.fromResult(value);
}

class ConversationToolCall {
  const ConversationToolCall({
    required this.id,
    required this.name,
    required this.arguments,
    this.wireName,
  });
  final String id;
  final String name;
  final String arguments;
  final String? wireName;

  static final _decodedArguments = Expando<({Map<String, Object?>? value})>();
  Map<String, Object?>? get argumentsObject => (_decodedArguments[this] ??= (
    value: decodeConversationToolObject(arguments),
  )).value;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'arguments': arguments,
    'wireName': ?wireName,
  };

  factory ConversationToolCall.fromJson(Map<String, dynamic> json) =>
      ConversationToolCall(
        id: _string(json, 'id'),
        name: _string(json, 'name', max: 128),
        arguments: _string(json, 'arguments', empty: true),
        wireName: _readWireName(json),
      );
  static String? _readWireName(Map<String, dynamic> json) {
    final value = _optionalString(json, 'wireName', max: 64);
    if (value != null &&
        !RegExp(r'^[A-Za-z][A-Za-z0-9_.-]{0,63}$').hasMatch(value)) {
      throw const FormatException('Invalid tool call wire name.');
    }
    return value;
  }
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
    Iterable<AgentComposerReference> contextReferences = const [],
    this.attachmentDelivery = AttachmentDelivery.local,
    Iterable<Map<String, Object?>> responseItems = const [],
  }) : toolCalls = List.unmodifiable(toolCalls),
       attachmentIds = List.unmodifiable(attachmentIds),
       contextReferences = AgentComposerReference.validatedList(
         contextReferences,
       ),
       responseItems = _freezeResponseItems(responseItems) {
    if (this.responseItems.isNotEmpty && role != ConversationRole.assistant) {
      throw const FormatException(
        'Only assistant messages have provider items.',
      );
    }
    if (this.attachmentIds.any((id) => !validAttachmentId(id)) ||
        this.attachmentIds.toSet().length != this.attachmentIds.length ||
        (this.attachmentIds.isNotEmpty &&
            role != ConversationRole.user &&
            role != ConversationRole.notice)) {
      throw const FormatException('Invalid message attachment references.');
    }
    if (this.contextReferences.isNotEmpty &&
        role != ConversationRole.user &&
        role != ConversationRole.notice) {
      throw const FormatException(
        'Only user input can carry composer references.',
      );
    }
    if (this.contextReferences.any(
      (reference) =>
          reference.kind == AgentComposerReferenceKind.attachment &&
          !this.attachmentIds.contains(reference.attachmentId),
    )) {
      throw const FormatException(
        'Referenced files must be attached to the message.',
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
  final List<String> attachmentIds;
  final List<AgentComposerReference> contextReferences;
  final AttachmentDelivery attachmentDelivery;

  /// Decoding belongs to the immutable protocol record, shared by every view.
  late final ToolOutcome? toolOutcome = role == ConversationRole.tool
      ? conversationToolOutcome(text)
      : null;

  ConversationMessage copyWith({
    String? text,
    ConversationRole? role,
    AgentModelSelection? modelSelection,
    AgentModelProtocol? providerProtocol,
    Iterable<Map<String, Object?>>? responseItems,
    Iterable<String>? attachmentIds,
    Iterable<AgentComposerReference>? contextReferences,
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
    contextReferences:
        contextReferences ??
        _referencesForAttachments(this.contextReferences, attachmentIds),
    attachmentDelivery: attachmentDelivery ?? this.attachmentDelivery,
  );

  /// Immutable provider continuation data; never request headers or
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
    if (contextReferences.isNotEmpty)
      'contextReferences': contextReferences
          .map((reference) => reference.toJson())
          .toList(),
    if (attachmentIds.isNotEmpty) 'attachmentDelivery': attachmentDelivery.name,
  };

  factory ConversationMessage.fromJson(Map<String, dynamic> json) {
    final role = _enumValue(ConversationRole.values, json['role']);
    final calls = _objects(
      json,
      'toolCalls',
    ).map(ConversationToolCall.fromJson).toList();
    final toolCallId = json['toolCallId'] == null
        ? null
        : _string(json, 'toolCallId');
    if ((role == ConversationRole.tool) != (toolCallId != null) ||
        (calls.isNotEmpty && role != ConversationRole.assistant) ||
        calls.map((call) => call.id).toSet().length != calls.length) {
      throw const FormatException('Invalid conversation tool message.');
    }
    return ConversationMessage(
      id: _string(json, 'id', max: 256),
      role: role,
      text: _string(json, 'text', empty: true),
      createdAt: _date(json, 'createdAt'),
      toolCalls: calls,
      toolCallId: toolCallId,
      responseItems: _objects(json, 'responseItems'),
      modelSelection: json['modelSelection'] == null
          ? null
          : AgentModelSelection.fromJson(json['modelSelection']),
      providerProtocol: json['providerProtocol'] == null
          ? null
          : _enumValue(AgentModelProtocol.values, json['providerProtocol']),
      attachmentIds: _attachmentIds(json['attachmentIds']),
      contextReferences: AgentComposerReference.decodeList(
        json['contextReferences'],
      ),
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
  Object? freeze(Object? value) {
    if (value is Map) {
      final result = <String, Object?>{};
      for (final entry in value.entries) {
        final key = entry.key;
        if (key is! String ||
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
        result[key] = freeze(entry.value);
      }
      return Map<String, Object?>.unmodifiable(result);
    }
    if (value is List) {
      return List<Object?>.unmodifiable(value.map(freeze));
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
    items.map((item) => freeze(item)! as Map<String, Object?>),
  );
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
    this.boundInputId,
    this.boundMessageId,
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
  final String? boundInputId;
  final String? boundMessageId;

  String get digest {
    final data = toJson()
      ..remove('boundInputId')
      ..remove('boundMessageId');
    return sha256.convert(utf8.encode(jsonEncode(data))).toString();
  }

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
    if (boundInputId != null) 'boundInputId': boundInputId,
    if (boundMessageId != null) 'boundMessageId': boundMessageId,
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
      text: _string(json, 'text', empty: true),
      url: url,
      targetId: _optionalString(json, 'targetId', max: 256),
      truncated: json['truncated'] as bool,
      attachedAfterRunId: _optionalString(json, 'attachedAfterRunId', max: 256),
      boundInputId: _optionalString(json, 'boundInputId', max: 256),
      boundMessageId: _optionalString(json, 'boundMessageId', max: 256),
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
      title: _string(json, 'title', empty: true),
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
    this.titleWasEdited = false,
    this.pinned = false,
    this.titleGeneration,
    required this.createdAt,
    required this.updatedAt,
    this.mode = AgentPermissionMode.ask,
    this.status = ConversationStatus.idle,
    this.archived = false,
    this.draft = '',
    this.connectionFingerprint,
    this.runId,
    this.modelSelection,
    this.pendingQuestion,
    this.executionHistoryStart = 0,
    Iterable<ConversationMessage> messages = const [],
    Iterable<ConversationSource> sources = const [],
    Iterable<ConversationRunUsage> runs = const [],
    Iterable<ConversationAttachment> attachments = const [],
    Iterable<String> draftAttachmentIds = const [],
    Iterable<AgentComposerReference> draftReferences = const [],
    Iterable<ConversationTurn> turns = const [],
    Iterable<ConversationHistoryVersion> historyVersions = const [],
    Iterable<ConversationReplyRevision> replyRevisions = const [],
    Iterable<ConversationRedoBatch> redoBatches = const [],
    Iterable<ConversationQueuedInput> queuedInputs = const [],
    Iterable<ConversationControlCommand> queuedControls = const [],
  }) : messages = List.unmodifiable(messages),
       sources = List.unmodifiable(sources),
       runs = List.unmodifiable(runs),
       attachments = List.unmodifiable(attachments),
       draftAttachmentIds = List.unmodifiable(draftAttachmentIds),
       draftReferences = AgentComposerReference.validatedList(draftReferences),
       turns = List.unmodifiable(turns),
       historyVersions = List.unmodifiable(historyVersions),
       replyRevisions = List.unmodifiable(replyRevisions),
       redoBatches = List.unmodifiable(redoBatches),
       queuedInputs = List.unmodifiable(queuedInputs),
       queuedControls = List.unmodifiable(queuedControls) {
    if (id.trim().isEmpty || title.trim().isEmpty) {
      throw const FormatException(
        'Conversation identity and title are required.',
      );
    }
    if (executionHistoryStart < 0 ||
        executionHistoryStart > this.messages.length) {
      throw const FormatException('Invalid executable history boundary.');
    }
    _validateStoredReferences();
    validateConversationTurns(this.messages, this.runs, this.turns);
    if (this.queuedInputs.map((item) => item.id).toSet().length !=
            this.queuedInputs.length ||
        this.queuedInputs.any(
          (item) => this.messages.any((message) => message.id == item.id),
        )) {
      throw const FormatException('Duplicate queued input identity.');
    }
    if (this.queuedControls.map((item) => item.id).toSet().length !=
        this.queuedControls.length) {
      throw const FormatException('Duplicate conversation control identity.');
    }
    _validatePendingQuestion();
    _validateReferenceAttachments();
  }

  AgentConversation._withUpdatedAt(AgentConversation source, this.updatedAt)
    : id = source.id,
      title = source.title,
      titleWasEdited = source.titleWasEdited,
      pinned = source.pinned,
      titleGeneration = source.titleGeneration,
      createdAt = source.createdAt,
      mode = source.mode,
      status = source.status,
      archived = source.archived,
      draft = source.draft,
      connectionFingerprint = source.connectionFingerprint,
      runId = source.runId,
      modelSelection = source.modelSelection,
      pendingQuestion = source.pendingQuestion,
      executionHistoryStart = source.executionHistoryStart,
      messages = source.messages,
      sources = source.sources,
      runs = source.runs,
      attachments = source.attachments,
      draftAttachmentIds = source.draftAttachmentIds,
      draftReferences = source.draftReferences,
      turns = source.turns,
      historyVersions = source.historyVersions,
      replyRevisions = source.replyRevisions,
      redoBatches = source.redoBatches,
      queuedInputs = source.queuedInputs,
      queuedControls = source.queuedControls;

  /// Timestamp changes reuse the already validated immutable records.
  AgentConversation withUpdatedAt(DateTime value) =>
      value == updatedAt ? this : AgentConversation._withUpdatedAt(this, value);

  final String id;
  final String title;
  final bool titleWasEdited;
  final bool pinned;
  final ConversationTitleGeneration? titleGeneration;
  final DateTime createdAt;
  final DateTime updatedAt;
  final AgentPermissionMode mode;
  final ConversationStatus status;
  final bool archived;
  final String draft;
  final String? connectionFingerprint;
  final String? runId;
  final AgentModelSelection? modelSelection;
  final AgentQuestionRequest? pendingQuestion;
  final int executionHistoryStart;
  Iterable<ConversationMessage> get executionMessages =>
      messages.skip(executionHistoryStart);
  final List<ConversationMessage> messages;
  final List<ConversationSource> sources;
  final List<ConversationRunUsage> runs;
  final List<ConversationAttachment> attachments;
  final List<String> draftAttachmentIds;
  final List<AgentComposerReference> draftReferences;
  final List<ConversationTurn> turns;
  final List<ConversationHistoryVersion> historyVersions;
  final List<ConversationReplyRevision> replyRevisions;
  final List<ConversationRedoBatch> redoBatches;
  final List<ConversationQueuedInput> queuedInputs;
  final List<ConversationControlCommand> queuedControls;
  bool get hasPendingControls => queuedControls.any(
    (command) => command.status != ConversationControlStatus.cancelled,
  );
  ConversationRedoBatch? get pendingRedo =>
      redoBatches.where((batch) => !batch.isTerminal).firstOrNull;

  AgentConversation copyWith({
    String? title,
    bool? titleWasEdited,
    bool? pinned,
    ConversationTitleGeneration? titleGeneration,
    DateTime? updatedAt,
    AgentPermissionMode? mode,
    ConversationStatus? status,
    bool? archived,
    String? draft,
    String? connectionFingerprint,
    String? runId,
    AgentModelSelection? modelSelection,
    AgentQuestionRequest? pendingQuestion,
    int? executionHistoryStart,
    bool clearRunId = false,
    bool clearConnectionFingerprint = false,
    bool clearPendingQuestion = false,
    Iterable<ConversationMessage>? messages,
    Iterable<ConversationSource>? sources,
    Iterable<ConversationRunUsage>? runs,
    Iterable<ConversationAttachment>? attachments,
    Iterable<String>? draftAttachmentIds,
    Iterable<AgentComposerReference>? draftReferences,
    Iterable<ConversationTurn>? turns,
    Iterable<ConversationHistoryVersion>? historyVersions,
    Iterable<ConversationReplyRevision>? replyRevisions,
    Iterable<ConversationRedoBatch>? redoBatches,
    Iterable<ConversationQueuedInput>? queuedInputs,
    Iterable<ConversationControlCommand>? queuedControls,
  }) => AgentConversation(
    id: id,
    title: title ?? this.title,
    titleWasEdited:
        titleWasEdited ?? (title != null ? true : this.titleWasEdited),
    pinned: pinned ?? this.pinned,
    titleGeneration: titleGeneration ?? this.titleGeneration,
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
    pendingQuestion: clearPendingQuestion
        ? null
        : pendingQuestion ?? this.pendingQuestion,
    executionHistoryStart: executionHistoryStart ?? this.executionHistoryStart,
    messages: messages ?? this.messages,
    sources: sources ?? this.sources,
    runs: runs ?? this.runs,
    attachments: attachments ?? this.attachments,
    draftAttachmentIds: draftAttachmentIds ?? this.draftAttachmentIds,
    draftReferences:
        draftReferences ??
        _referencesForAttachments(this.draftReferences, draftAttachmentIds),
    turns: turns ?? this.turns,
    historyVersions: historyVersions ?? this.historyVersions,
    replyRevisions: replyRevisions ?? this.replyRevisions,
    redoBatches: redoBatches ?? this.redoBatches,
    queuedInputs: queuedInputs ?? this.queuedInputs,
    queuedControls: queuedControls ?? this.queuedControls,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'titleWasEdited': titleWasEdited,
    'pinned': pinned,
    if (titleGeneration != null) 'titleGeneration': titleGeneration!.toJson(),
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
    if (pendingQuestion != null) 'pendingQuestion': pendingQuestion!.toJson(),
    'executionHistoryStart': executionHistoryStart,
    'messages': messages.map((message) => message.toJson()).toList(),
    'sources': sources.map((source) => source.toJson()).toList(),
    'runs': runs.map((run) => run.toJson()).toList(),
    if (attachments.isNotEmpty)
      'attachments': attachments
          .map((attachment) => attachment.toJson())
          .toList(),
    if (draftAttachmentIds.isNotEmpty) 'draftAttachmentIds': draftAttachmentIds,
    if (draftReferences.isNotEmpty)
      'draftReferences': draftReferences
          .map((reference) => reference.toJson())
          .toList(),
    'turns': turns.map((item) => item.toJson()).toList(),
    'historyVersions': historyVersions.map((item) => item.toJson()).toList(),
    'replyRevisions': replyRevisions.map((item) => item.toJson()).toList(),
    'redoBatches': redoBatches.map((item) => item.toJson()).toList(),
    if (queuedInputs.isNotEmpty)
      'queuedInputs': queuedInputs.map((item) => item.toJson()).toList(),
    if (queuedControls.isNotEmpty)
      'queuedControls': queuedControls.map((item) => item.toJson()).toList(),
  };

  factory AgentConversation.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('pinned') && json['pinned'] is! bool) {
      throw const FormatException('Invalid pinned conversation state.');
    }
    if (json.containsKey('archived') && json['archived'] is! bool) {
      throw const FormatException('Invalid archived conversation state.');
    }
    final messages = _objects(
      json,
      'messages',
    ).map(ConversationMessage.fromJson).toList();
    final sources = _objects(
      json,
      'sources',
    ).map(ConversationSource.fromJson).toList();
    final runs = _objects(
      json,
      'runs',
    ).map(ConversationRunUsage.fromJson).toList();
    final attachments = _objects(
      json,
      'attachments',
    ).map(ConversationAttachment.fromJson).toList();
    final draftAttachmentIds = _attachmentIds(json['draftAttachmentIds']);
    final turns = _objects(
      json,
      'turns',
    ).map(ConversationTurn.fromJson).toList();
    final historyVersions = _objects(
      json,
      'historyVersions',
    ).map(ConversationHistoryVersion.fromJson).toList();
    final replyRevisions = _objects(
      json,
      'replyRevisions',
    ).map(ConversationReplyRevision.fromJson).toList();
    final redoBatches = _objects(
      json,
      'redoBatches',
    ).map(ConversationRedoBatch.fromJson).toList();
    final queuedInputs = _objects(
      json,
      'queuedInputs',
    ).map(ConversationQueuedInput.fromJson).toList();
    final queuedControls = _objects(
      json,
      'queuedControls',
    ).map(ConversationControlCommand.fromJson).toList();
    final executionHistoryStart = json['executionHistoryStart'] ?? 0;
    if (executionHistoryStart is! int) {
      throw const FormatException('Invalid executable history boundary.');
    }
    return AgentConversation(
      id: _string(json, 'id', max: 256),
      title: _string(json, 'title'),
      titleWasEdited: json['titleWasEdited'] as bool? ?? false,
      pinned: json['pinned'] as bool? ?? false,
      titleGeneration: json['titleGeneration'] == null
          ? null
          : ConversationTitleGeneration.fromJson(
              _object(json['titleGeneration']),
            ),
      createdAt: _date(json, 'createdAt'),
      updatedAt: _date(json, 'updatedAt'),
      mode: _enumValue(AgentPermissionMode.values, json['mode']),
      status: _enumValue(ConversationStatus.values, json['status']),
      archived: json['archived'] as bool? ?? false,
      draft: _string(json, 'draft', empty: true),
      connectionFingerprint: _optionalString(
        json,
        'connectionFingerprint',
        max: 256,
      ),
      runId: _optionalString(json, 'runId', max: 256),
      modelSelection: json['modelSelection'] == null
          ? null
          : AgentModelSelection.fromJson(json['modelSelection']),
      pendingQuestion: json['pendingQuestion'] == null
          ? null
          : AgentQuestionRequest.fromJson(_object(json['pendingQuestion'])),
      messages: messages,
      sources: sources,
      runs: runs,
      attachments: attachments,
      draftAttachmentIds: draftAttachmentIds,
      draftReferences: AgentComposerReference.decodeList(
        json['draftReferences'],
      ),
      executionHistoryStart: executionHistoryStart,
      turns: turns,
      historyVersions: historyVersions,
      replyRevisions: replyRevisions,
      redoBatches: redoBatches,
      queuedInputs: queuedInputs,
      queuedControls: queuedControls,
    );
  }

  void _validateStoredReferences() {
    if (historyVersions.map((item) => item.id).toSet().length !=
            historyVersions.length ||
        replyRevisions.map((item) => item.id).toSet().length !=
            replyRevisions.length ||
        redoBatches.map((item) => item.id).toSet().length !=
            redoBatches.length ||
        redoBatches.where((item) => !item.isTerminal).length > 1 ||
        redoBatches.any((item) => item.conversationId != id)) {
      throw const FormatException('Invalid conversation history references.');
    }
    if (sources.map((source) => source.id).toSet().length != sources.length ||
        runs
                .expand((run) => run.requests)
                .map((request) => request.id)
                .toSet()
                .length !=
            runs.fold<int>(0, (count, run) => count + run.requests.length)) {
      throw const FormatException('Duplicate conversation item ID.');
    }
  }

  void _validatePendingQuestion() {
    final pending = pendingQuestion;
    if (pending == null) return;
    final requestMessages = executionMessages
        .where((message) => message.id == pending.requestMessageId)
        .toList();
    if (requestMessages.length != 1 ||
        requestMessages.single.role != ConversationRole.assistant ||
        !runs.any((run) => run.id == pending.runId)) {
      throw const FormatException('Invalid pending question owner.');
    }
    final calls = requestMessages.single.toolCalls
        .where(
          (call) => call.id == pending.toolCallId && call.name == 'ask_user',
        )
        .toList();
    if (calls.length != 1) {
      throw const FormatException('Invalid pending question tool call.');
    }
    final questions = parseAgentQuestionPrompts(
      _object(jsonDecode(calls.single.arguments)),
    );
    if (jsonEncode(questions.map((question) => question.toJson()).toList()) !=
        jsonEncode(
          pending.questions.map((question) => question.toJson()).toList(),
        )) {
      throw const FormatException(
        'Pending questions differ from the tool call.',
      );
    }
  }

  void _validateReferenceAttachments() {
    final metadata = <String, ConversationAttachment>{};
    for (final attachment in attachments) {
      if (metadata.containsKey(attachment.id)) {
        throw const FormatException('Duplicate attachment identity.');
      }
      metadata[attachment.id] = attachment;
    }
    void validate(
      Iterable<AgentComposerReference> references,
      Iterable<String> attachedIds,
    ) {
      if (attachedIds.any((id) => !metadata.containsKey(id))) {
        throw const FormatException('Missing attachment references.');
      }
      for (final reference in references) {
        if (reference.kind != AgentComposerReferenceKind.attachment) continue;
        final attachment = metadata[reference.attachmentId];
        if (reference.conversationId != id ||
            attachment == null ||
            attachment.digest != reference.attachmentDigest ||
            !attachedIds.contains(reference.attachmentId)) {
          throw const FormatException(
            'Invalid composer attachment ownership or digest.',
          );
        }
      }
    }

    validate(draftReferences, draftAttachmentIds);
    for (final input in queuedInputs) {
      validate(input.contextReferences, input.attachmentIds);
    }
    for (final message in messages) {
      validate(message.contextReferences, message.attachmentIds);
    }
    for (final version in historyVersions) {
      for (final message in version.messages) {
        validate(message.contextReferences, message.attachmentIds);
      }
    }
    for (final batch in redoBatches) {
      validate(const [], batch.attachmentIds);
    }
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

  static const currentVersion = 9;
  final int revision;
  final String? selectedId;
  final List<AgentConversation> conversations;
  final List<ConversationHandoff> handoffs;
  final Set<String> terminatedIds;

  Map<String, Object?> toJson() => {
    'version': currentVersion,
    'revision': revision,
    'selectedId': selectedId,
    'conversations': conversations.map((item) => item.toJson()).toList(),
    'handoffs': handoffs.map((item) => item.toJson()).toList(),
    'terminatedIds': terminatedIds.toList(),
  };
  String encode() => jsonEncode(toJson());

  factory ConversationArchive.decode(String source) {
    return ConversationArchive.fromJson(_object(jsonDecode(source)));
  }

  factory ConversationArchive.fromJson(Map<String, dynamic> json) {
    if (json['version'] != currentVersion ||
        json['revision'] is! int ||
        (json['revision'] as int) < 0) {
      throw const FormatException('Unsupported conversation archive version.');
    }
    final rawConversations = _objects(json, 'conversations');
    final conversations = rawConversations
        .map(AgentConversation.fromJson)
        .toList();
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
    ).map(ConversationHandoff.fromJson).toList();
    final rawTerminated = json['terminatedIds'];
    if (rawTerminated is! List ||
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
  ...conversation.queuedInputs.expand((input) => input.attachmentIds),
};

Iterable<AgentComposerReference> _referencesForAttachments(
  Iterable<AgentComposerReference> references,
  Iterable<String>? attachmentIds,
) {
  if (attachmentIds == null) return references;
  final remaining = attachmentIds.toSet();
  return references.where(
    (reference) =>
        reference.kind != AgentComposerReferenceKind.attachment ||
        remaining.contains(reference.attachmentId),
  );
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
  int? max,
}) {
  final raw = json.containsKey(key) ? json[key] : const [];
  if (raw is! List || (max != null && raw.length > max)) {
    throw FormatException('Invalid $key list.');
  }
  return raw.map(_object).toList();
}

String _string(
  Map<String, dynamic> json,
  String key, {
  int? max,
  bool empty = false,
}) {
  final raw = json[key];
  if (raw is! String ||
      (max != null && raw.length > max) ||
      (!empty && raw.trim().isEmpty)) {
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
