import 'conversation_usage.dart';

/// One independent title request, outside the conversation's task usage.
class ConversationTitleGeneration {
  const ConversationTitleGeneration({
    required this.sourceMessageId,
    required this.sourceDigest,
    required this.model,
    required this.protocol,
    required this.request,
    this.reasoningEffort,
  });

  final String sourceMessageId;
  final String sourceDigest;
  final String model;
  final String protocol;
  final String? reasoningEffort;
  final ConversationRequestUsage request;

  ConversationTitleGeneration settle({
    required ConversationAttemptOutcome outcome,
    ConversationTokenUsage? usage,
    String? errorCode,
  }) => ConversationTitleGeneration(
    sourceMessageId: sourceMessageId,
    sourceDigest: sourceDigest,
    model: model,
    protocol: protocol,
    reasoningEffort: reasoningEffort,
    request: request.settle(
      outcome: outcome,
      usage: usage,
      errorCode: errorCode,
    ),
  );

  Map<String, Object?> toJson() => {
    'sourceMessageId': sourceMessageId,
    'sourceDigest': sourceDigest,
    'model': model,
    'protocol': protocol,
    if (reasoningEffort != null) 'reasoningEffort': reasoningEffort,
    'request': request.toJson(),
  };

  factory ConversationTitleGeneration.fromJson(Map<String, dynamic> json) {
    String text(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) {
        throw const FormatException('Invalid title generation metadata.');
      }
      return value;
    }

    final protocol = text('protocol');
    final digest = text('sourceDigest');
    final reasoning = json['reasoningEffort'];
    if (!const {'chatCompletions', 'responses'}.contains(protocol) ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(digest) ||
        (reasoning != null && reasoning is! String) ||
        json['request'] is! Map) {
      throw const FormatException('Invalid title generation metadata.');
    }
    return ConversationTitleGeneration(
      sourceMessageId: text('sourceMessageId'),
      sourceDigest: digest,
      model: text('model'),
      protocol: protocol,
      reasoningEffort: reasoning as String?,
      request: ConversationRequestUsage.fromJson(
        Map<String, dynamic>.from(json['request'] as Map),
      ),
    );
  }
}
