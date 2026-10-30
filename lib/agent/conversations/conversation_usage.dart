import '../../utils/time_utils.dart' show tryParseStrictIsoDateTime;

enum ConversationRunKind { model, host }

enum ConversationRunStatus { running, completed, interrupted }

/// A pending attempt is recorded before invocation. It may have reached the
/// provider/tool if the process stops before a result is saved.
enum ConversationAttemptOutcome {
  pending,
  notStarted,
  completed,
  failed,
  unknown,
}

/// Counts reported by the provider, never local estimates or a price quote.
class ConversationTokenUsage {
  const ConversationTokenUsage({
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

  Map<String, Object?> toJson() => {
    'inputTokens': inputTokens,
    'outputTokens': outputTokens,
    'totalTokens': totalTokens,
    'cachedInputTokens': cachedInputTokens,
    'reasoningTokens': reasoningTokens,
  };

  factory ConversationTokenUsage.fromJson(Map<String, dynamic> json) {
    final input = _count(json, 'inputTokens');
    final output = _count(json, 'outputTokens');
    final total = _count(json, 'totalTokens');
    final cached = _optionalCount(json, 'cachedInputTokens');
    final reasoning = _optionalCount(json, 'reasoningTokens');
    if (total < input + output ||
        (cached != null && cached > input) ||
        (reasoning != null && reasoning > output)) {
      throw const FormatException('Invalid reported token usage.');
    }
    return ConversationTokenUsage(
      inputTokens: input,
      outputTokens: output,
      totalTokens: total,
      cachedInputTokens: cached,
      reasoningTokens: reasoning,
    );
  }
}

class ConversationRequestUsage {
  const ConversationRequestUsage({
    required this.id,
    required this.startedAt,
    this.outcome = ConversationAttemptOutcome.pending,
    this.usage,
    this.errorCode,
  });

  final String id;
  final DateTime startedAt;
  final ConversationAttemptOutcome outcome;
  final ConversationTokenUsage? usage;
  final String? errorCode;

  ConversationRequestUsage settle({
    required ConversationAttemptOutcome outcome,
    ConversationTokenUsage? usage,
    String? errorCode,
  }) => ConversationRequestUsage(
    id: id,
    startedAt: startedAt,
    outcome: outcome,
    usage: usage ?? this.usage,
    errorCode: errorCode,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'outcome': outcome.name,
    'usage': usage?.toJson(),
    if (errorCode != null) 'errorCode': errorCode,
  };

  factory ConversationRequestUsage.fromJson(Map<String, dynamic> json) =>
      ConversationRequestUsage(
        id: _text(json, 'id'),
        startedAt: _date(json, 'startedAt'),
        outcome: _enum(ConversationAttemptOutcome.values, json['outcome']),
        usage: json['usage'] == null
            ? null
            : ConversationTokenUsage.fromJson(_map(json['usage'])),
        errorCode: _optionalText(json, 'errorCode'),
      );
}

class ConversationToolUsage {
  const ConversationToolUsage({
    required this.id,
    required this.name,
    this.outcome = ConversationAttemptOutcome.pending,
  });

  final String id;
  final String name;
  final ConversationAttemptOutcome outcome;

  ConversationToolUsage settle(ConversationAttemptOutcome outcome) =>
      ConversationToolUsage(id: id, name: name, outcome: outcome);

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'outcome': outcome.name,
  };

  factory ConversationToolUsage.fromJson(Map<String, dynamic> json) =>
      ConversationToolUsage(
        id: _text(json, 'id'),
        name: _text(json, 'name'),
        outcome: _enum(ConversationAttemptOutcome.values, json['outcome']),
      );
}

/// Immutable, bounded accounting for one accepted runtime scope. Explicit
/// continuation creates another run linked to this one; it never re-adds the
/// old requests. There are no automatic provider retries in this runtime.
class ConversationRunUsage {
  ConversationRunUsage({
    required this.id,
    required this.startedAt,
    required this.kind,
    this.protocol,
    this.model,
    this.continuedFromRunId,
    this.status = ConversationRunStatus.running,
    this.settledAt,
    Iterable<ConversationRequestUsage> requests = const [],
    Iterable<ConversationToolUsage> tools = const [],
  }) : requests = List.unmodifiable(requests),
       tools = List.unmodifiable(tools);

  final String id;
  final DateTime startedAt;
  final ConversationRunKind kind;
  final String? protocol;
  final String? model;
  final String? continuedFromRunId;
  final ConversationRunStatus status;
  final DateTime? settledAt;
  final List<ConversationRequestUsage> requests;
  final List<ConversationToolUsage> tools;

  ConversationRunUsage copyWith({
    ConversationRunStatus? status,
    DateTime? settledAt,
    Iterable<ConversationRequestUsage>? requests,
    Iterable<ConversationToolUsage>? tools,
  }) => ConversationRunUsage(
    id: id,
    startedAt: startedAt,
    kind: kind,
    protocol: protocol,
    model: model,
    continuedFromRunId: continuedFromRunId,
    status: status ?? this.status,
    settledAt: settledAt ?? this.settledAt,
    requests: requests ?? this.requests,
    tools: tools ?? this.tools,
  );

  ConversationRunUsage withRequest(ConversationRequestUsage request) =>
      copyWith(requests: _replace(requests, request, (item) => item.id));

  ConversationRunUsage withTool(ConversationToolUsage tool) =>
      copyWith(tools: _replace(tools, tool, (item) => item.id));

  /// Recovery records uncertainty. It does not invent completion times,
  /// missing usage, or another request to obtain the old result.
  ConversationRunUsage interrupt({DateTime? settledAt}) => copyWith(
    status: ConversationRunStatus.interrupted,
    settledAt: settledAt,
    requests: requests.map(
      (request) => request.outcome == ConversationAttemptOutcome.pending
          ? request.settle(
              outcome: ConversationAttemptOutcome.unknown,
              errorCode: 'interrupted',
            )
          : request,
    ),
    tools: tools.map(
      (tool) => tool.outcome == ConversationAttemptOutcome.pending
          ? tool.settle(ConversationAttemptOutcome.unknown)
          : tool,
    ),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'kind': kind.name,
    if (protocol != null) 'protocol': protocol,
    if (model != null) 'model': model,
    if (continuedFromRunId != null) 'continuedFromRunId': continuedFromRunId,
    'status': status.name,
    if (settledAt != null) 'settledAt': settledAt!.toUtc().toIso8601String(),
    'requests': requests.map((request) => request.toJson()).toList(),
    'tools': tools.map((tool) => tool.toJson()).toList(),
  };

  Map<String, Object?> summary() => {
    'id': id,
    'kind': kind.name,
    'status': status.name,
    if (continuedFromRunId != null) 'continuedFromRunId': continuedFromRunId,
    ...summarizeConversationUsage([this]),
  };

  factory ConversationRunUsage.fromJson(Map<String, dynamic> json) {
    final requests = _list(
      json,
      'requests',
      100,
    ).map(ConversationRequestUsage.fromJson).toList();
    final tools = _list(
      json,
      'tools',
      500,
    ).map(ConversationToolUsage.fromJson).toList();
    final kind = _enum(ConversationRunKind.values, json['kind']);
    final status = _enum(ConversationRunStatus.values, json['status']);
    final protocol = _optionalText(json, 'protocol');
    final model = _optionalText(json, 'model');
    if (requests.map((item) => item.id).toSet().length != requests.length ||
        tools.map((item) => item.id).toSet().length != tools.length ||
        (kind == ConversationRunKind.host && requests.isNotEmpty) ||
        (kind == ConversationRunKind.model &&
            (protocol == null || model == null)) ||
        (status != ConversationRunStatus.running &&
            (requests.any(
                  (r) => r.outcome == ConversationAttemptOutcome.pending,
                ) ||
                tools.any(
                  (t) => t.outcome == ConversationAttemptOutcome.pending,
                )))) {
      throw const FormatException('Invalid run usage record.');
    }
    return ConversationRunUsage(
      id: _text(json, 'id'),
      startedAt: _date(json, 'startedAt'),
      kind: kind,
      protocol: protocol,
      model: model,
      continuedFromRunId: _optionalText(json, 'continuedFromRunId'),
      status: status,
      settledAt: json['settledAt'] == null ? null : _date(json, 'settledAt'),
      requests: requests,
      tools: tools,
    );
  }
}

Map<String, Object?> summarizeConversationUsage(
  Iterable<ConversationRunUsage> records,
) {
  final runs = records.toList();
  final requests = runs.expand((run) => run.requests).toList();
  final tools = runs.expand((run) => run.tools).toList();
  final usages = requests.map((request) => request.usage).nonNulls.toList();
  final finalUsages = requests
      .where(
        (request) =>
            request.usage != null &&
            request.outcome == ConversationAttemptOutcome.completed,
      )
      .length;
  final cached = usages
      .map((usage) => usage.cachedInputTokens)
      .nonNulls
      .toList();
  final reasoning = usages
      .map((usage) => usage.reasoningTokens)
      .nonNulls
      .toList();
  int sum(Iterable<int> values) =>
      values.fold(0, (total, value) => total + value);
  int count(
    Iterable<ConversationAttemptOutcome> values,
    ConversationAttemptOutcome outcome,
  ) => values.where((value) => value == outcome).length;
  Map<String, int> outcomes(Iterable<ConversationAttemptOutcome> values) => {
    for (final outcome in ConversationAttemptOutcome.values)
      outcome.name: count(values, outcome),
  };
  return {
    'coverage': 'recordedRunsOnly',
    'recordedRuns': runs.length,
    'continuedRuns': runs.where((run) => run.continuedFromRunId != null).length,
    'automaticRetries': 0,
    'modelRequests': requests.length,
    'requestOutcomes': outcomes(requests.map((request) => request.outcome)),
    'toolAttempts': tools.length,
    'toolOutcomes': outcomes(tools.map((tool) => tool.outcome)),
    'reportedUsageRequests': usages.length,
    'completedUsageRequests': finalUsages,
    'unreportedUsageRequests': requests.length - usages.length,
    'tokenUsageStatus': runs.isEmpty
        ? 'unavailable'
        : requests.isEmpty
        ? 'notRequested'
        : usages.isEmpty
        ? 'unreported'
        : finalUsages == requests.length
        ? 'reported'
        : 'partial',
    'reportedTokens': usages.isEmpty
        ? null
        : {
            'inputTokens': sum(usages.map((usage) => usage.inputTokens)),
            'outputTokens': sum(usages.map((usage) => usage.outputTokens)),
            'totalTokens': sum(usages.map((usage) => usage.totalTokens)),
            'cachedInputTokens': cached.isEmpty ? null : sum(cached),
            'reasoningTokens': reasoning.isEmpty ? null : sum(reasoning),
            'cachedInputReportedRequests': cached.length,
            'reasoningReportedRequests': reasoning.length,
          },
    'cost': null,
    'costStatus': 'unknown',
  };
}

List<T> _replace<T>(List<T> items, T next, String Function(T) id) => [
  for (final item in items)
    if (id(item) == id(next)) next else item,
  if (!items.any((item) => id(item) == id(next))) next,
];

Map<String, dynamic> _map(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Invalid usage record.');
  }
  return value;
}

List<Map<String, dynamic>> _list(
  Map<String, dynamic> json,
  String key,
  int max,
) {
  final raw = json[key];
  if (raw is! List || raw.length > max) {
    throw const FormatException('Invalid usage record list.');
  }
  return raw.map(_map).toList();
}

int _count(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int || value < 0 || value > 9007199254740991) {
    throw const FormatException('Invalid usage count.');
  }
  return value;
}

int? _optionalCount(Map<String, dynamic> json, String key) =>
    json[key] == null ? null : _count(json, key);

String _text(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty || value.length > 256) {
    throw const FormatException('Invalid usage identity.');
  }
  return value;
}

String? _optionalText(Map<String, dynamic> json, String key) =>
    json[key] == null ? null : _text(json, key);

T _enum<T extends Enum>(List<T> values, Object? raw) =>
    values.where((item) => item.name == raw).firstOrNull ??
    (throw const FormatException('Invalid usage state.'));

DateTime _date(Map<String, dynamic> json, String key) {
  final value = tryParseStrictIsoDateTime(_text(json, key));
  if (value == null || !value.isUtc || value.year < 1 || value.year > 9999) {
    throw const FormatException('Invalid usage timestamp.');
  }
  return value;
}
