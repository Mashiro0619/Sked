import 'dart:async';
import 'dart:convert';

enum ProviderProtocol { chatCompletions, responses }

enum ProviderRole { system, user, assistant, tool }

/// Credentials deliberately do not belong to any serializable provider DTO.
class ProviderRequest {
  ProviderRequest({
    required this.endpoint,
    required this.model,
    required List<ProviderMessage> messages,
    this.protocol = ProviderProtocol.chatCompletions,
    List<ToolDefinition> tools = const [],
    this.limits = const ProviderLimits(),
    this.allowInsecureHttp = false,
    this.reasoningEffort,
  }) : messages = List.unmodifiable(messages),
       tools = List.unmodifiable(tools);

  /// Exact user-selected API URL, including /chat/completions or /responses.
  final Uri endpoint;
  final String model;
  final ProviderProtocol protocol;
  final List<ProviderMessage> messages;
  final List<ToolDefinition> tools;
  final ProviderLimits limits;
  final bool allowInsecureHttp;

  /// Null omits the parameter, leaving the model/service default untouched.
  final String? reasoningEffort;
}

class ProviderLimits {
  const ProviderLimits({
    this.totalTimeout = const Duration(minutes: 5),
    this.idleTimeout = const Duration(minutes: 2),
    this.maxRequestBytes = 1024 * 1024,
    this.maxAttachmentBytes = 48 * 1000 * 1000,
    this.maxResponseBytes = 8 * 1024 * 1024,
    this.maxEventBytes = 512 * 1024,
    this.maxToolArgumentBytes = 128 * 1024,
    this.maxToolCalls = 32,
    this.maxOutputTokens = 4096,
    this.maxTotalTokens = 32768,
  });

  final Duration totalTimeout;
  final Duration idleTimeout;
  final int maxRequestBytes;

  /// Raw binary input budget, independent from the text/tool JSON budget.
  final int maxAttachmentBytes;
  final int maxResponseBytes;
  final int maxEventBytes;
  final int maxToolArgumentBytes;
  final int maxToolCalls;
  final int maxOutputTokens;
  final int maxTotalTokens;
}

class ProviderMessage {
  ProviderMessage({
    required this.role,
    this.text = '',
    List<ProviderToolCall> toolCalls = const [],
    this.toolCallId,
    List<Map<String, Object?>> responseItems = const [],
    List<ProviderAttachment> attachments = const [],
  }) : toolCalls = List.unmodifiable(toolCalls),
       attachments = List.unmodifiable(attachments),
       responseItems = List.unmodifiable(responseItems.map(freezeProviderMap));

  final ProviderRole role;
  final String text;
  final List<ProviderToolCall> toolCalls;
  final String? toolCallId;
  final List<ProviderAttachment> attachments;

  /// Protocol continuation items, e.g. Responses reasoning and function calls.
  /// Only assistant messages may contain these; they never confer authority.
  final List<Map<String, Object?>> responseItems;
}

/// A lazy immutable file reference. Bytes are read only after request budgets
/// and cancellation have been installed, and never serialized in chat JSON.
class ProviderAttachment {
  const ProviderAttachment({
    required this.id,
    required this.filename,
    required this.mediaType,
    required this.byteLength,
    required this.digest,
    required this.openRead,
  });
  final String id;
  final String filename;
  final String mediaType;
  final int byteLength;
  final String digest;
  final Stream<List<int>> Function() openRead;
}

/// Internal JSON value expanded by the asynchronous request encoder.
class ProviderBinaryEncoding {
  const ProviderBinaryEncoding(this.attachment, {this.dataUrl = true});
  final ProviderAttachment attachment;
  final bool dataUrl;
  String get prefix => dataUrl ? 'data:${attachment.mediaType};base64,' : '';
  int get encodedLength =>
      prefix.length + ((attachment.byteLength + 2) ~/ 3) * 4;
}

enum ProviderUploadPhase { encoding, sending, accepted }

class ProviderUploadProgress extends ProviderEvent {
  const ProviderUploadProgress(
    this.phase, {
    required this.completedBytes,
    required this.totalBytes,
  });
  final ProviderUploadPhase phase;
  final int completedBytes;
  final int totalBytes;
}

class ProviderToolCall {
  ProviderToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });

  final String id;
  final String name;
  final String arguments;

  Map<String, Object?> get decodedArguments {
    final value = jsonDecode(arguments);
    if (value is! Map<String, dynamic>) {
      throw const ProviderException(ProviderError.invalidToolArguments);
    }
    return freezeProviderMap(value);
  }
}

class ToolDefinition {
  ToolDefinition({
    required this.name,
    required this.description,
    required Map<String, Object?> parameters,
    this.strict = false,
  }) : parameters = freezeProviderMap(parameters);

  final String name;
  final String description;
  final Map<String, Object?> parameters;
  final bool strict;
}

class ProviderUsage {
  const ProviderUsage({
    required this.inputTokens,
    required this.outputTokens,
    required this.totalTokens,
    this.cachedInputTokens,
    this.reasoningTokens,
  });

  final int inputTokens;
  final int outputTokens;
  final int totalTokens;
  final int? cachedInputTokens;
  final int? reasoningTokens;
}

class ProviderResponse {
  ProviderResponse({
    required this.text,
    required List<ProviderToolCall> toolCalls,
    required this.finishReason,
    this.usage,
    List<Map<String, Object?>> responseItems = const [],
  }) : toolCalls = List.unmodifiable(toolCalls),
       responseItems = List.unmodifiable(responseItems.map(freezeProviderMap));

  final String text;
  final List<ProviderToolCall> toolCalls;
  final String finishReason;
  final ProviderUsage? usage;
  final List<Map<String, Object?>> responseItems;

  ProviderMessage toAssistantMessage() => ProviderMessage(
    role: ProviderRole.assistant,
    text: text,
    toolCalls: toolCalls,
    responseItems: responseItems,
  );
}

sealed class ProviderEvent {
  const ProviderEvent();
}

class ProviderTextDelta extends ProviderEvent {
  const ProviderTextDelta(this.text);
  final String text;
}

/// Display-only fragments. Only ProviderCompleted contains executable calls.
class ProviderToolCallDelta extends ProviderEvent {
  const ProviderToolCallDelta({
    required this.index,
    required this.argumentsDelta,
  });
  final int index;
  final String argumentsDelta;
}

class ProviderUsageEvent extends ProviderEvent {
  const ProviderUsageEvent(this.usage);
  final ProviderUsage usage;
}

class ProviderCompleted extends ProviderEvent {
  const ProviderCompleted(this.response);
  final ProviderResponse response;
}

enum ProviderError {
  invalidRequest,
  unsupportedAttachment,
  attachmentMissing,
  attachmentChanged,
  insecureEndpoint,
  cancelled,
  timeout,
  requestBudgetExceeded,
  responseBudgetExceeded,
  eventBudgetExceeded,
  toolBudgetExceeded,
  tokenBudgetExceeded,
  redirectRejected,
  authentication,
  rateLimited,
  httpFailure,
  transportFailure,
  invalidResponse,
  incompleteResponse,
  unknownTool,
  duplicateToolCall,
  invalidToolArguments,
}

/// Stable failure classification with bounded API response diagnostics.
/// Only explicit response messages/codes enter the display fields. Request
/// credentials are redacted, and transport exceptions remain classification-only.
class ProviderException implements Exception {
  const ProviderException(
    this.code, {
    this.statusCode,
    this.responseTerminated = false,
    this.responseMessage,
    this.responseCode,
  });

  factory ProviderException.fromResponse(
    ProviderError code,
    Object? body, {
    int? statusCode,
    String apiKey = '',
    bool responseTerminated = false,
  }) {
    final error = body is Map ? body['error'] ?? body : body;
    final message = error is Map ? error['message'] : error;
    final responseCode = error is Map ? error['code'] ?? error['type'] : null;
    return ProviderException(
      code,
      statusCode: statusCode,
      responseTerminated: responseTerminated,
      responseMessage: _providerDiagnostic(message, apiKey, 8192),
      responseCode: _providerDiagnostic(responseCode, apiKey, 256),
    );
  }

  final ProviderError code;
  final int? statusCode;
  final String? responseMessage;
  final String? responseCode;

  /// Display-only plain text. The stable [toString] remains safe for logs.
  String? get displayDetails {
    final metadata = [
      if (statusCode != null) 'HTTP $statusCode',
      ?responseCode,
    ];
    final parts = [
      ?responseMessage,
      if (metadata.isNotEmpty) metadata.join(' · '),
    ];
    return parts.isEmpty ? null : parts.join('\n');
  }

  /// A validated terminal response was received, even though its content could
  /// not complete this request. A disconnected or truncated stream is unknown.
  final bool responseTerminated;

  @override
  String toString() =>
      'ProviderException(${code.name}'
      '${statusCode == null ? '' : ', HTTP $statusCode'})';
}

String? _providerDiagnostic(Object? value, String apiKey, int limit) {
  if (value is! String && value is! num) return null;
  var text = value.toString();
  if (apiKey.isNotEmpty) {
    final encodedKey = jsonEncode(apiKey);
    text = text
        .replaceAll(
          encodedKey.substring(1, encodedKey.length - 1),
          '[redacted]',
        )
        .replaceAll(apiKey, '[redacted]');
  }
  text = text.replaceAll(
    RegExp(r'(Bearer|Basic)\s+[^\s,;"<>]+', caseSensitive: false),
    '[redacted authorization]',
  );
  text = text.replaceAllMapped(
    RegExp(
      r'''["']?(api[_-]?key|access[_-]?token|cookie)["']?\s*[:=]\s*(?:"(?:\\.|[^"\\])*(?:"|$)|'(?:\\.|[^'\\])*(?:'|$)|[^\s,;"'<>]+)''',
      caseSensitive: false,
    ),
    (match) => '${match[1]}=[redacted]',
  );
  text = text
      .replaceAll(RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]'), '')
      .trim();
  if (text.isEmpty) return null;
  final runes = text.runes;
  return runes.length <= limit
      ? text
      : '${String.fromCharCodes(runes.take(limit))}…';
}

class ProviderCancellationToken {
  final Completer<void> _cancelled = Completer<void>();
  bool get isCancelled => _cancelled.isCompleted;
  Future<void> get whenCancelled => _cancelled.future;

  void cancel() {
    if (!_cancelled.isCompleted) _cancelled.complete();
  }
}

Map<String, Object?> freezeProviderMap(Map<String, Object?> value) =>
    _freeze(value, 0) as Map<String, Object?>;

Object? _freeze(Object? value, int depth) {
  if (depth > 64) throw const ProviderException(ProviderError.invalidRequest);
  if (value is Map && value.keys.every((key) => key is String)) {
    return Map<String, Object?>.unmodifiable({
      for (final entry in value.entries)
        entry.key as String: _freeze(entry.value, depth + 1),
    });
  }
  if (value is List) {
    return List<Object?>.unmodifiable(
      value.map((item) => _freeze(item, depth + 1)),
    );
  }
  if (value == null ||
      value is String ||
      value is bool ||
      (value is num && value.isFinite)) {
    return value;
  }
  throw const ProviderException(ProviderError.invalidRequest);
}
