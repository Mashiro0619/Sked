import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../provider/provider.dart';

/// An original message and its stable archive identity. System instructions are
/// rebuilt for each request and therefore never become summary source content.
class ContextEntry {
  const ContextEntry(this.id, this.message);
  final String id;
  final ProviderMessage message;

  Map<String, Object?> toJson() => {
    'id': id,
    'role': message.role.name,
    'text': message.text,
    'toolCallId': message.toolCallId,
    'toolCalls': [
      for (final call in message.toolCalls)
        {'id': call.id, 'name': call.name, 'arguments': call.arguments},
    ],
    'responseItems': message.responseItems,
    'attachments': [
      for (final file in message.attachments)
        {
          'id': file.id,
          'name': file.filename,
          'digest': file.digest,
          'mediaType': file.mediaType,
          'byteLength': file.byteLength,
        },
    ],
  };
}

String contextSourceDigest(Iterable<ContextEntry> entries) => sha256
    .convert(
      utf8.encode(jsonEncode(entries.map((entry) => entry.toJson()).toList())),
    )
    .toString();

class ContextCheckpoint {
  ContextCheckpoint({
    required this.id,
    required this.conversationId,
    required this.modelId,
    required this.protocol,
    required this.sourceDigest,
    required List<String> sourceMessageIds,
    required this.summary,
    required this.createdAt,
    required this.tokensBefore,
    required this.estimatedTokensAfter,
    this.summaryUsage,
    this.sourceKey,
  }) : sourceMessageIds = List.unmodifiable(sourceMessageIds);

  final String id, conversationId, modelId, protocol, sourceDigest, summary;
  final List<String> sourceMessageIds;
  final DateTime createdAt;
  final int tokensBefore, estimatedTokensAfter;
  final ProviderUsage? summaryUsage;
  final String? sourceKey;

  bool matches(
    String model,
    ProviderProtocol wire,
    List<ContextEntry> entries,
  ) =>
      modelId == model &&
      protocol == wire.name &&
      sourceMessageIds.length <= entries.length &&
      contextSourceDigest(entries.take(sourceMessageIds.length)) ==
          sourceDigest;

  Map<String, Object?> toJson() => {
    'id': id,
    'conversationId': conversationId,
    'modelId': modelId,
    'protocol': protocol,
    'sourceDigest': sourceDigest,
    'sourceMessageIds': sourceMessageIds,
    'summary': summary,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'tokensBefore': tokensBefore,
    'estimatedTokensAfter': estimatedTokensAfter,
    if (sourceKey != null) 'sourceKey': sourceKey,
    if (summaryUsage case final usage?)
      'summaryUsage': {
        'inputTokens': usage.inputTokens,
        'outputTokens': usage.outputTokens,
        'totalTokens': usage.totalTokens,
        'cachedInputTokens': usage.cachedInputTokens,
        'reasoningTokens': usage.reasoningTokens,
      },
  };

  factory ContextCheckpoint.fromJson(Map<String, Object?> json) =>
      ContextCheckpoint(
        id: json['id'] as String,
        conversationId: json['conversationId'] as String,
        modelId: json['modelId'] as String,
        protocol: json['protocol'] as String,
        sourceDigest: json['sourceDigest'] as String,
        sourceMessageIds: (json['sourceMessageIds'] as List).cast<String>(),
        summary: json['summary'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        tokensBefore: json['tokensBefore'] as int,
        estimatedTokensAfter: json['estimatedTokensAfter'] as int,
        sourceKey: json['sourceKey'] as String?,
        summaryUsage: switch (json['summaryUsage']) {
          final Map usage => ProviderUsage(
            inputTokens: usage['inputTokens'] as int,
            outputTokens: usage['outputTokens'] as int,
            totalTokens: usage['totalTokens'] as int,
            cachedInputTokens: usage['cachedInputTokens'] as int?,
            reasoningTokens: usage['reasoningTokens'] as int?,
          ),
          _ => null,
        },
      );
}

abstract interface class ContextCheckpointStore {
  Future<ContextCheckpoint?> latest(String conversationId);
  Future<void> append(
    ContextCheckpoint checkpoint, {
    void Function()? validate,
  });
  Future<void> clear(String conversationId);
  Future<ContextCompactionFailure?> failedSource(
    String conversationId,
    String sourceKey,
  );
  Future<void> saveFailure(ContextCompactionFailure failure);
  Future<void> clearFailure(String conversationId, String sourceKey);
}

class ContextCompactionFailure {
  const ContextCompactionFailure({
    required this.sourceKey,
    required this.conversationId,
    required this.modelId,
    required this.protocol,
    required this.sourceDigest,
    required this.errorCode,
    required this.createdAt,
  });
  final String sourceKey,
      conversationId,
      modelId,
      protocol,
      sourceDigest,
      errorCode;
  final DateTime createdAt;
  Map<String, Object?> toJson() => {
    'sourceKey': sourceKey,
    'conversationId': conversationId,
    'modelId': modelId,
    'protocol': protocol,
    'sourceDigest': sourceDigest,
    'errorCode': errorCode,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };
  factory ContextCompactionFailure.fromJson(Map<String, Object?> value) =>
      ContextCompactionFailure(
        sourceKey: value['sourceKey'] as String,
        conversationId: value['conversationId'] as String,
        modelId: value['modelId'] as String,
        protocol: value['protocol'] as String,
        sourceDigest: value['sourceDigest'] as String,
        errorCode: value['errorCode'] as String,
        createdAt: DateTime.parse(value['createdAt'] as String),
      );
}
