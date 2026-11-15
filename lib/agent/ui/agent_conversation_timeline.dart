import '../conversations/conversation_models.dart';
import '../delivery/agent_delivery.dart';
import '../history/conversation_history.dart';
import '../interactions/agent_task_plan.dart';
import '../operations/operation_executor.dart';
import '../operations/tool_outcome.dart';

/// A presentation projection only. Grouping never changes the executable
/// message sequence, operation ownership, or stored conversation history.
sealed class AgentTimelineEntry {
  const AgentTimelineEntry();
}

class AgentTimelineMessage extends AgentTimelineEntry {
  const AgentTimelineMessage(
    this.message, {
    this.isFinalResponse = false,
    this.turnId,
  });

  final ConversationMessage message;
  final bool isFinalResponse;
  final String? turnId;
}

class AgentTimelineQueuedInput extends AgentTimelineEntry {
  const AgentTimelineQueuedInput(this.message, this.text);
  final ConversationMessage message;
  final String text;
}

enum AgentToolActivityStatus {
  running,
  completed,
  failed,
  uncertain,
  notStarted,
  corrected,
}

class AgentToolActivity {
  factory AgentToolActivity({
    required String id,
    required String name,
    required String arguments,
    required AgentToolActivityStatus status,
    String? result,
    String? resultMessageId,
    bool receipt = false,
  }) => AgentToolActivity._(
    id: id,
    name: name,
    arguments: arguments,
    status: status,
    result: result,
    resultMessageId: resultMessageId,
    receipt: receipt,
    argumentsObject: decodeConversationToolObject(arguments),
    outcome: result == null ? null : conversationToolOutcome(result),
  );

  AgentToolActivity._({
    required this.id,
    required this.name,
    required this.arguments,
    required this.status,
    this.result,
    this.resultMessageId,
    this.receipt = false,
    required this.argumentsObject,
    required this.outcome,
  });

  final String id;
  final String name;
  final String arguments;
  final AgentToolActivityStatus status;
  final String? result;
  final String? resultMessageId;
  final Map<String, Object?>? argumentsObject;
  final ToolOutcome? outcome;

  /// Such results also remain visible as host-owned operation cards.
  final bool receipt;
}

class AgentTimelineActivity extends AgentTimelineEntry {
  AgentTimelineActivity({
    required this.id,
    required this.anchorMessageId,
    required Iterable<AgentToolActivity> tools,
    this.turnId,
  }) : tools = List.unmodifiable(tools);

  final String id;
  final String anchorMessageId;
  final String? turnId;
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

/// One business operation keeps the first call's reading anchor while its
/// receipt and interaction advance. Protocol messages remain unchanged.
class AgentTimelineOperation extends AgentTimelineEntry {
  AgentTimelineOperation({
    required this.id,
    required this.anchorMessageId,
    required this.turnId,
    required Iterable<AgentToolActivity> tools,
    this.operationId,
    this.outcome,
    this.waitingApproval = false,
    this.phase,
  }) : tools = List.unmodifiable(tools);

  final String id;
  final String anchorMessageId;
  final String turnId;
  final String? operationId;
  final List<AgentToolActivity> tools;
  final ToolOutcome? outcome;
  Map<String, Object?>? get receipt => outcome?.payload;
  final bool waitingApproval;
  final AgentOperationPhase? phase;

  bool get reminderSchedulingFailed {
    final effect = receipt?['notificationEffect'];
    return effect is Map && effect['state'] == 'failed';
  }

  AgentTimelineOperation withOutcome(ToolOutcome value) =>
      AgentTimelineOperation(
        id: id,
        anchorMessageId: anchorMessageId,
        turnId: turnId,
        operationId: operationId,
        tools: tools,
        outcome: value,
        waitingApproval: waitingApproval,
        phase: phase,
      );

  AgentToolActivityStatus get status => switch (phase) {
    AgentOperationPhase.preparing ||
    AgentOperationPhase.executing ||
    AgentOperationPhase.waitingApproval => AgentToolActivityStatus.running,
    AgentOperationPhase.previewed ||
    AgentOperationPhase.completed => AgentToolActivityStatus.completed,
    AgentOperationPhase.cancelled => AgentToolActivityStatus.notStarted,
    AgentOperationPhase.failed => AgentToolActivityStatus.failed,
    AgentOperationPhase.unresolved => AgentToolActivityStatus.uncertain,
    null => tools.last.status,
  };
}

class AgentTimelinePlan extends AgentTimelineEntry {
  const AgentTimelinePlan({
    required this.id,
    required this.anchorMessageId,
    required this.plan,
    this.turnId,
  });
  final String id;
  final String anchorMessageId;
  final AgentTaskPlan plan;
  final String? turnId;
}

/// Matches the host receipt view's boundary. A receipt, failure, or uncertain
/// external result never disappears into a collapsed activity group.
bool isAgentVisibleToolResult(ConversationMessage message) =>
    message.toolOutcome?.operationId != null;

AgentToolActivityStatus? _resultStatus(ConversationMessage? message) =>
    switch (message?.toolOutcome?.kind) {
      ToolOutcomeKind.needsReconciliation => AgentToolActivityStatus.uncertain,
      ToolOutcomeKind.cancelled => AgentToolActivityStatus.notStarted,
      ToolOutcomeKind.correctableError => AgentToolActivityStatus.failed,
      ToolOutcomeKind.query ||
      ToolOutcomeKind.preview ||
      ToolOutcomeKind.saved => AgentToolActivityStatus.completed,
      null => null,
    };

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
  Map<String, Object?>? pendingOperation,
  Iterable<AgentOperationUpdate> operationUpdates = const [],
  List<ConversationMessage>? visibleMessages,
  List<ConversationTurn>? visibleTurns,
}) {
  final messages = visibleMessages ?? conversation.messages;
  final turns = visibleTurns ?? conversation.turns;
  if (messages.isEmpty) {
    return [
      for (final input in conversation.queuedInputs)
        AgentTimelineQueuedInput(input.asUserMessage(), input.text),
    ];
  }
  final turnsByMessage = <String, String>{};
  final turnsByRun = <String, String>{};
  final requestByTurn = <String, String>{};
  for (final turn in turns) {
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
          conversation.status == ConversationStatus.waitingApproval ||
          conversation.status == ConversationStatus.waitingUser);
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
    for (final turn in turns)
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
        turnId: first.group,
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
            ConversationAttemptOutcome.cancelled =>
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
          return AgentToolActivity._(
            id: source.id,
            name: call?.name ?? usage?.name ?? '',
            arguments: call?.arguments ?? '',
            argumentsObject: call?.argumentsObject,
            outcome: result?.toolOutcome,
            status: resultStatus ?? accountedStatus,
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
    final visible =
        message.role != ConversationRole.tool &&
        (message.role != ConversationRole.assistant ||
            message.text.isNotEmpty ||
            message.toolCalls.isEmpty);
    if (visible) {
      flushActivity();
      timeline.add(
        AgentTimelineMessage(
          message,
          isFinalResponse: finalResponseIds.contains(message.id),
          turnId: groupByMessage[message.id],
        ),
      );
    }
    if (message.role != ConversationRole.tool) appendSources(message.id);
  }
  flushActivity();
  timeline.addAll([
    for (final input in conversation.queuedInputs)
      AgentTimelineQueuedInput(input.asUserMessage(), input.text),
  ]);
  return _projectPlans(
    _projectOperations(
      timeline,
      pendingOperation: pendingOperation,
      operationUpdates: operationUpdates,
    ),
    conversation,
    turns,
  );
}

List<AgentTimelineEntry> _projectPlans(
  List<AgentTimelineEntry> source,
  AgentConversation conversation,
  List<ConversationTurn> turns,
) {
  final plans = <String, AgentTaskPlan>{};
  final planKeys = <String, String>{};
  final runs = conversation.runs.map((run) => run.id).toSet();
  for (final activity in source.whereType<AgentTimelineActivity>()) {
    for (final tool in activity.tools) {
      if (tool.name != 'update_plan' || tool.result == null) continue;
      try {
        final result = tool.outcome?.payload;
        if (result == null) continue;
        final plan = AgentTaskPlan.fromToolResult(result);
        if (!runs.contains(plan.runId)) continue;
        final turn = turns
            .where((turn) => turn.runIds.contains(plan.runId))
            .firstOrNull;
        if (turn != null && activity.turnId != turn.id) continue;
        final group = activity.turnId ?? activity.id;
        if (plans[group] == null ||
            plans[group]!.runId != plan.runId ||
            plans[group]!.revision < plan.revision) {
          plans[group] = plan;
        }
        planKeys[tool.id] = group;
      } on FormatException {
        // Invalid tool output stays available as an ordinary activity.
      }
    }
  }
  final emitted = <String>{};
  final result = <AgentTimelineEntry>[];
  for (final entry in source) {
    if (entry is! AgentTimelineActivity) {
      result.add(entry);
      continue;
    }
    final remaining = <AgentToolActivity>[];
    void flush() {
      if (remaining.isEmpty) return;
      result.add(
        AgentTimelineActivity(
          id: remaining.first.id == entry.tools.first.id
              ? entry.id
              : '${entry.id}-${remaining.first.id}',
          anchorMessageId: entry.anchorMessageId,
          turnId: entry.turnId,
          tools: remaining,
        ),
      );
      remaining.clear();
    }

    for (final tool in entry.tools) {
      final group = planKeys[tool.id];
      if (group == null) {
        remaining.add(tool);
        continue;
      }
      flush();
      if (emitted.add(group) && plans[group]!.steps.isNotEmpty) {
        result.add(
          AgentTimelinePlan(
            id: 'plan-$group',
            anchorMessageId: entry.anchorMessageId,
            plan: plans[group]!,
            turnId: group,
          ),
        );
      }
    }
    flush();
  }
  return List.unmodifiable(result);
}

bool _isBusinessTool(String name) =>
    name.endsWith('.apply') ||
    name == 'settings.update' ||
    name == 'agent_settings.update' ||
    name == 'operations.undo' ||
    const {
      'backups.restore',
      'maintenance.clear',
      'exports.write',
      'conversations.create',
      'conversations.rename',
      'conversations.delete',
      'conversations.archive',
      'conversations.export',
      'runs.stop',
      'runs.resume',
      'navigation.open',
      'platform.request_action',
    }.contains(name);

List<AgentTimelineEntry> _projectOperations(
  List<AgentTimelineEntry> source, {
  Map<String, Object?>? pendingOperation,
  Iterable<AgentOperationUpdate> operationUpdates = const [],
}) {
  final updates = {
    for (final update in operationUpdates) update.callId: update,
  };
  final results = <String, ToolOutcome>{};
  for (final activity in source.whereType<AgentTimelineActivity>()) {
    for (final tool in activity.tools) {
      final update = updates[tool.id];
      final result =
          tool.outcome ?? (update == null ? null : _updateOutcome(update));
      if (result == null) continue;
      results[tool.id] = result;
    }
  }
  final pendingCallId = pendingOperation?['toolCallId'];
  final groups = <(String, String), List<AgentToolActivity>>{};
  final keyByTool = <String, (String, String)>{};
  for (final activity in source.whereType<AgentTimelineActivity>()) {
    final turn = activity.turnId ?? activity.id;
    for (final tool in activity.tools) {
      final result = results[tool.id];
      final delivery = result == null
          ? null
          : AgentDelivery.fromToolResult(toolName: tool.name, outcome: result);
      final hasDelivery = delivery?.hasItems == true;
      // A failed read may still have real extracted files. Other rejected
      // invocations remain in the activity trail without a failed save row.
      if (result?.kind == ToolOutcomeKind.correctableError &&
          result?.operationId == null &&
          !hasDelivery) {
        continue;
      }
      if (!_isBusinessTool(tool.name) &&
          !updates.containsKey(tool.id) &&
          result?.operationId == null &&
          !hasDelivery) {
        continue;
      }
      final operationId =
          result?.operationId ??
          (pendingCallId == tool.id
              ? (pendingOperation?['operationId'])
              : null);
      final identity = operationId is String ? operationId : tool.id;
      final key = (turn, identity);
      keyByTool[tool.id] = key;
      groups.putIfAbsent(key, () => []).add(tool);
    }
  }
  final emitted = <(String, String)>{};
  final projected = <AgentTimelineEntry>[];
  for (final entry in source) {
    if (entry is! AgentTimelineActivity) {
      projected.add(entry);
      continue;
    }
    final ordinary = <AgentToolActivity>[];
    void flush() {
      if (ordinary.isEmpty) return;
      projected.add(
        AgentTimelineActivity(
          id: ordinary.first.id == entry.tools.first.id
              ? entry.id
              : '${entry.id}-${ordinary.first.id}',
          anchorMessageId: entry.anchorMessageId,
          turnId: entry.turnId,
          tools: ordinary,
        ),
      );
      ordinary.clear();
    }

    for (final tool in entry.tools) {
      final key = keyByTool[tool.id];
      if (key == null) {
        ordinary.add(tool);
        continue;
      }
      flush();
      if (!emitted.add(key)) continue;
      final stages = groups[key]!;
      ToolOutcome? outcome;
      for (final stage in stages) {
        outcome = results[stage.id] ?? outcome;
      }
      final waiting =
          stages.any((stage) => stage.id == pendingCallId) ||
          (pendingOperation?['operationId'] != null &&
              pendingOperation?['operationId'] == outcome?.operationId);
      projected.add(
        AgentTimelineOperation(
          id: stages.first.id,
          anchorMessageId: entry.anchorMessageId,
          turnId: key.$1,
          operationId:
              outcome?.operationId ??
              (waiting ? (pendingOperation?['operationId'] as String?) : null),
          tools: [
            for (final stage in stages)
              if (outcome?.kind == ToolOutcomeKind.saved &&
                  outcome?.operationId != null &&
                  stage.status == AgentToolActivityStatus.failed)
                AgentToolActivity._(
                  id: stage.id,
                  name: stage.name,
                  arguments: stage.arguments,
                  status: AgentToolActivityStatus.corrected,
                  result: stage.result,
                  resultMessageId: stage.resultMessageId,
                  argumentsObject: stage.argumentsObject,
                  outcome: stage.outcome,
                )
              else
                stage,
          ],
          outcome: waiting ? _pendingOutcome(pendingOperation!) : outcome,
          waitingApproval: waiting,
          phase: stages.last.result == null
              ? updates[stages.last.id]?.phase
              : null,
        ),
      );
    }
    flush();
  }
  return List.unmodifiable(projected);
}

final _updateOutcomes = Expando<ToolOutcome>();
ToolOutcome _updateOutcome(AgentOperationUpdate update) =>
    _updateOutcomes[update] ??= ToolOutcome.fromResult(update.details);

ToolOutcome _pendingOutcome(Map<String, Object?> pending) =>
    ToolOutcome(ToolOutcomeKind.preview, pending);
