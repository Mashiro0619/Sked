import 'dart:convert';

import '../conversations/conversation_models.dart';
import '../runtime/operation_outcome.dart';

/// A presentation projection only. Grouping never changes the executable
/// message sequence, operation ownership, or stored conversation history.
sealed class AgentTimelineEntry {
  const AgentTimelineEntry();
}

class AgentTimelineMessage extends AgentTimelineEntry {
  const AgentTimelineMessage(this.message, {this.isFinalResponse = false});

  final ConversationMessage message;
  final bool isFinalResponse;
}

enum AgentToolActivityStatus {
  running,
  completed,
  failed,
  uncertain,
  notStarted,
}

class AgentToolActivity {
  const AgentToolActivity({
    required this.id,
    required this.name,
    required this.arguments,
    required this.status,
    this.result,
    this.resultMessageId,
    this.receipt = false,
  });

  final String id;
  final String name;
  final String arguments;
  final AgentToolActivityStatus status;
  final String? result;
  final String? resultMessageId;

  /// Such results also remain visible as host-owned operation cards.
  final bool receipt;
}

class AgentTimelineActivity extends AgentTimelineEntry {
  AgentTimelineActivity({
    required this.id,
    required this.anchorMessageId,
    required Iterable<AgentToolActivity> tools,
  }) : tools = List.unmodifiable(tools);

  final String id;
  final String anchorMessageId;
  final List<AgentToolActivity> tools;

  AgentToolActivityStatus get status {
    if (tools.any((tool) => tool.status == AgentToolActivityStatus.uncertain)) {
      return AgentToolActivityStatus.uncertain;
    }
    if (tools.any((tool) => tool.status == AgentToolActivityStatus.failed)) {
      return AgentToolActivityStatus.failed;
    }
    if (tools.any((tool) => tool.status == AgentToolActivityStatus.running)) {
      return AgentToolActivityStatus.running;
    }
    if (tools.any(
      (tool) => tool.status == AgentToolActivityStatus.notStarted,
    )) {
      return AgentToolActivityStatus.notStarted;
    }
    return AgentToolActivityStatus.completed;
  }
}

/// Matches the host receipt view's boundary. A receipt, failure, or uncertain
/// external result never disappears into a collapsed activity group.
bool isAgentVisibleToolResult(ConversationMessage message) {
  if (message.role != ConversationRole.tool) return false;
  try {
    final value = jsonDecode(message.text);
    return value is Map<String, dynamic> &&
        (value.containsKey('operationId') ||
            value.containsKey('planId') ||
            value.containsKey('error'));
  } on FormatException {
    return false;
  }
}

AgentToolActivityStatus? _resultStatus(ConversationMessage? message) {
  if (message == null) return null;
  try {
    final value = jsonDecode(message.text);
    if (value is! Map<String, dynamic>) return null;
    if (requiresAgentOutcomeReview(value) ||
        value['effectStatus'] == 'unknown' ||
        value['effectStatus'] == 'pending' ||
        value['status'] == 'partial') {
      return AgentToolActivityStatus.uncertain;
    }
    if (value['status'] == 'not_executed') {
      return AgentToolActivityStatus.notStarted;
    }
    if (value['error'] != null || value['status'] == 'failed') {
      return AgentToolActivityStatus.failed;
    }
  } on FormatException {
    // Plain historical text cannot establish an operation outcome.
  }
  return null;
}

class _ActivitySource {
  _ActivitySource({
    required this.id,
    required this.rawId,
    required this.group,
    required this.anchor,
    required this.occurredAt,
    this.call,
    this.result,
    this.usage,
    this.runId,
  });

  final String id;
  final String rawId;
  final String group;
  final String anchor;
  final DateTime occurredAt;
  final ConversationToolCall? call;
  ConversationMessage? result;
  ConversationToolUsage? usage;
  String? runId;
}

typedef _RecordedUsage = ({
  ConversationRunUsage run,
  ConversationToolUsage tool,
  String group,
  String anchor,
});

/// Groups adjacent tool traffic in message order while retaining recorded turn
/// ownership for result matching. Legacy conversations use user boundaries.
List<AgentTimelineEntry> projectAgentConversationTimeline(
  AgentConversation conversation, {
  String? activeRunId,
  bool currentRunActive = false,
  String? replyTargetMessageId,
}) {
  final messages = conversation.messages;
  if (messages.isEmpty) return const [];
  final turnsByMessage = <String, String>{};
  final turnsByRun = <String, String>{};
  final requestByTurn = <String, String>{};
  for (final turn in conversation.turns) {
    requestByTurn[turn.id] = turn.requestMessageId;
    for (final id in turn.messageIds) {
      turnsByMessage[id] = turn.id;
    }
    for (final id in turn.runIds) {
      turnsByRun[id] = turn.id;
    }
  }
  var fallback = 'legacy-${messages.first.id}';
  final groupByMessage = <String, String>{};
  for (final message in messages) {
    if (message.role == ConversationRole.user) fallback = message.id;
    final group = turnsByMessage[message.id] ?? fallback;
    groupByMessage[message.id] = group;
  }
  final lastGroup = groupByMessage[messages.last.id]!;
  final recordedActive =
      replyTargetMessageId == null &&
      (conversation.status == ConversationStatus.running ||
          conversation.status == ConversationStatus.waitingApproval);
  final effectiveRunId = replyTargetMessageId == null
      ? activeRunId ?? (recordedActive ? conversation.runId : null)
      : null;
  final activeGroups = <String>{};
  if (effectiveRunId != null) {
    if (turnsByRun[effectiveRunId] case final owned?) {
      activeGroups.add(owned);
    } else if (effectiveRunId == conversation.runId) {
      activeGroups.addAll([lastGroup, 'legacy-run-$effectiveRunId']);
    }
  } else if (recordedActive || currentRunActive) {
    activeGroups.add(lastGroup);
  }
  final sources = <_ActivitySource>[];
  final displayIds = <String>{};
  final callCounts = <String, int>{};
  for (final message in messages) {
    for (final call in message.toolCalls) {
      callCounts.update(call.id, (count) => count + 1, ifAbsent: () => 1);
    }
  }
  String displayId(String preferred, String fallback) {
    if (displayIds.add(preferred)) return preferred;
    var candidate = fallback;
    var suffix = 0;
    while (!displayIds.add(candidate)) {
      candidate = '$fallback-${++suffix}';
    }
    return candidate;
  }

  void add(_ActivitySource source) {
    sources.add(source);
  }

  final pending = <String, List<_ActivitySource>>{};
  for (final message in messages) {
    final group = groupByMessage[message.id]!;
    for (var index = 0; index < message.toolCalls.length; index++) {
      final call = message.toolCalls[index];
      final occurrence = 'call-${message.id}-$index';
      final source = _ActivitySource(
        id: displayId(
          callCounts[call.id] == 1 ? call.id : occurrence,
          occurrence,
        ),
        rawId: call.id,
        group: group,
        anchor: message.id,
        occurredAt: message.createdAt,
        call: call,
      );
      add(source);
      pending.putIfAbsent(call.id, () => []).add(source);
    }
    if (message.role != ConversationRole.tool) continue;
    final rawId = message.toolCallId ?? 'result-${message.id}';
    final preceding = pending[rawId] ?? const <_ActivitySource>[];
    final matching = preceding.reversed
        .where((source) => source.result == null && source.group == group)
        .firstOrNull;
    // A legacy steering message may separate a call from its result. Scan
    // only preceding calls; a later turn can never claim an earlier result.
    final source =
        matching ??
        (turnsByMessage.containsKey(message.id)
            ? null
            : preceding.reversed
                  .where((source) => source.result == null)
                  .firstOrNull);
    if (source != null) {
      source.result = message;
    } else {
      add(
        _ActivitySource(
          id: displayId(rawId, 'result-${message.id}'),
          rawId: rawId,
          group: group,
          anchor: message.id,
          occurredAt: message.createdAt,
          result: message,
        ),
      );
    }
  }
  final candidates = <_ActivitySource, List<_RecordedUsage>>{};
  final independent = <_RecordedUsage>[];
  final ownedGroups = requestByTurn.keys.toSet();
  for (final run in conversation.runs) {
    final ownedGroup = turnsByRun[run.id];
    String? legacyRequest;
    if (ownedGroup == null) {
      for (final message in messages) {
        if (message.role == ConversationRole.user &&
            !turnsByMessage.containsKey(message.id) &&
            !message.createdAt.isAfter(run.startedAt)) {
          legacyRequest = message.id;
        }
      }
    }
    final group = ownedGroup ?? 'legacy-run-${run.id}';
    final anchor = requestByTurn[group] ?? legacyRequest ?? messages.first.id;
    final candidateGroup =
        ownedGroup ??
        (legacyRequest == null ? null : groupByMessage[legacyRequest]);
    for (final tool in run.tools) {
      final usage = (run: run, tool: tool, group: group, anchor: anchor);
      final matching = sources
          .where(
            (source) =>
                source.rawId == tool.id &&
                (ownedGroup != null
                    ? source.group == ownedGroup
                    : candidateGroup != null &&
                          !ownedGroups.contains(source.group) &&
                          source.group == candidateGroup &&
                          !source.occurredAt.isBefore(run.startedAt) &&
                          (run.settledAt == null ||
                              !source.occurredAt.isAfter(run.settledAt!))),
          )
          .toList();
      if (matching.length == 1) {
        candidates.putIfAbsent(matching.single, () => []).add(usage);
      } else {
        // A raw ID alone cannot bind multiple historical occurrences to a run.
        independent.add((
          run: run,
          tool: tool,
          group: matching.isEmpty ? group : 'legacy-run-${run.id}',
          anchor: anchor,
        ));
      }
    }
  }
  for (final entry in candidates.entries) {
    if (entry.value.length == 1) {
      final usage = entry.value.single;
      entry.key
        ..usage = usage.tool
        ..runId = usage.run.id;
    } else {
      for (final usage in entry.value) {
        independent.add((
          run: usage.run,
          tool: usage.tool,
          group: 'legacy-run-${usage.run.id}',
          anchor: usage.anchor,
        ));
      }
    }
  }
  for (final usage in independent) {
    add(
      _ActivitySource(
        id: displayId(usage.tool.id, 'usage-${usage.run.id}-${usage.tool.id}'),
        rawId: usage.tool.id,
        group: usage.group,
        anchor: usage.anchor,
        occurredAt: usage.run.startedAt,
        usage: usage.tool,
        runId: usage.run.id,
      ),
    );
  }
  final lastResponseByGroup = <String, ConversationMessage>{};
  for (final message in messages) {
    if (message.role == ConversationRole.assistant ||
        message.role == ConversationRole.tool) {
      lastResponseByGroup[groupByMessage[message.id]!] = message;
    }
  }
  final runsById = {for (final run in conversation.runs) run.id: run};
  final completedTurns = {
    for (final turn in conversation.turns)
      if (runsById[turn.runIds.lastOrNull]?.status ==
          ConversationRunStatus.completed)
        turn.id,
  };
  final finalResponseIds = <String>{};
  for (final entry in lastResponseByGroup.entries) {
    final group = entry.key;
    final message = entry.value;
    if (message.role != ConversationRole.assistant ||
        message.text.trim().isEmpty ||
        message.toolCalls.isNotEmpty ||
        activeGroups.contains(group) ||
        (group == lastGroup &&
            replyTargetMessageId == null &&
            (currentRunActive ||
                conversation.status != ConversationStatus.idle))) {
      continue;
    }
    if (!ownedGroups.contains(group) || completedTurns.contains(group)) {
      finalResponseIds.add(message.id);
    }
  }
  final sourcesByAnchor = <String, List<_ActivitySource>>{};
  for (final source in sources) {
    sourcesByAnchor.putIfAbsent(source.anchor, () => []).add(source);
  }
  final timeline = <AgentTimelineEntry>[];
  final emittedGroups = <String>{};
  final activityIds = {for (final source in sources) source.group};
  final segment = <_ActivitySource>[];
  void flushActivity() {
    if (segment.isEmpty) return;
    final first = segment.first;
    var id = first.group;
    if (!emittedGroups.add(first.group)) {
      final base = '${first.group}-activity-${first.anchor}';
      id = base;
      var suffix = 0;
      while (!activityIds.add(id)) {
        id = '$base-${++suffix}';
      }
    }
    timeline.add(
      AgentTimelineActivity(
        id: id,
        anchorMessageId: first.anchor,
        tools: segment.map((source) {
          final call = source.call;
          final result = source.result;
          final usage = source.usage;
          final active = source.runId == null
              ? activeGroups.contains(source.group)
              : source.runId == effectiveRunId;
          final accountedStatus = switch (usage?.outcome) {
            ConversationAttemptOutcome.completed =>
              AgentToolActivityStatus.completed,
            ConversationAttemptOutcome.failed => AgentToolActivityStatus.failed,
            ConversationAttemptOutcome.unknown =>
              AgentToolActivityStatus.uncertain,
            ConversationAttemptOutcome.notStarted =>
              AgentToolActivityStatus.notStarted,
            ConversationAttemptOutcome.pending =>
              active
                  ? AgentToolActivityStatus.running
                  : AgentToolActivityStatus.uncertain,
            null =>
              result != null
                  ? AgentToolActivityStatus.completed
                  : active
                  ? AgentToolActivityStatus.running
                  : AgentToolActivityStatus.uncertain,
          };
          final resultStatus = _resultStatus(result);
          return AgentToolActivity(
            id: source.id,
            name: call?.name ?? usage?.name ?? '',
            arguments: call?.arguments ?? '',
            status:
                accountedStatus == AgentToolActivityStatus.uncertain ||
                    resultStatus == AgentToolActivityStatus.uncertain
                ? AgentToolActivityStatus.uncertain
                : accountedStatus == AgentToolActivityStatus.notStarted
                ? accountedStatus
                : resultStatus ?? accountedStatus,
            result: result?.text,
            resultMessageId: result?.id,
            receipt: result != null && isAgentVisibleToolResult(result),
          );
        }),
      ),
    );
    segment.clear();
  }

  void appendSources(String anchor) {
    for (final source in sourcesByAnchor[anchor] ?? const <_ActivitySource>[]) {
      if (segment.isNotEmpty && segment.first.group != source.group) {
        flushActivity();
      }
      segment.add(source);
    }
  }

  for (final message in messages) {
    // Orphan results precede their independently visible receipt. Calls in an
    // assistant message follow that message's explanatory text.
    if (message.role == ConversationRole.tool) appendSources(message.id);
    final visible = message.role == ConversationRole.tool
        ? isAgentVisibleToolResult(message)
        : message.role != ConversationRole.assistant ||
              message.text.isNotEmpty ||
              message.toolCalls.isEmpty;
    if (visible) {
      flushActivity();
      timeline.add(
        AgentTimelineMessage(
          message,
          isFinalResponse: finalResponseIds.contains(message.id),
        ),
      );
    }
    if (message.role != ConversationRole.tool) appendSources(message.id);
  }
  flushActivity();
  return List.unmodifiable(timeline);
}
