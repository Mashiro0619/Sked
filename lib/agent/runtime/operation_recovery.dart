import 'dart:convert';

import '../conversations/conversation_models.dart';
import 'operation_outcome.dart';

typedef AgentOperationReceiptReader = Future<Map<String, Object?>?> Function(
  String toolName,
  String operationId,
);

/// Only the host's durable operation store can resolve a lost write reply.
/// Model text and a new user message cannot discharge this recovery barrier.
Future<({List<ConversationMessage> messages, bool blocked, bool changed})>
recoverAgentOperationHistory(
  List<ConversationMessage> source, {
  required AgentOperationReceiptReader? readReceipt,
  required String Function() id,
  required DateTime Function() clock,
  required int maxResultCharacters,
}) async {
  final bindings = <String, ({String operationId, String toolName})>{};
  final hostBindings = <String, ({String operationId, String toolName})>{};
  final calls = <String, ConversationToolCall>{};
  for (final message in source) {
    for (final call in message.toolCalls) {
      calls[call.id] = call;
    }
    if (message.role == ConversationRole.notice) {
      final record = _object(message.text);
      if (record?['kind'] == 'agent_host_operation' &&
          record?['version'] == 1 &&
          record?['toolCallId'] is String &&
          record?['operationId'] is String &&
          const {
            'mutation.commit',
            'external.commit',
          }.contains(record?['toolName']) &&
          calls[record?['toolCallId']]?.name == 'host.action') {
        hostBindings[record!['toolCallId'] as String] = (
          operationId: record['operationId'] as String,
          toolName: record['toolName'] as String,
        );
      }
      continue;
    }
    if (message.role != ConversationRole.tool) continue;
    final result = _object(message.text), call = calls[message.toolCallId];
    if (result == null ||
        call == null ||
        result['planId'] is! String ||
        result['operationId'] is! String) {
      continue;
    }
    // Main-store preparation has no external action name in its summary.
    final type = result['action'] is String
        ? 'external.commit'
        : 'mutation.commit';
    bindings[result['planId'] as String] = (
      operationId: result['operationId'] as String,
      toolName: type,
    );
  }
  final result = <ConversationMessage>[];
  final pending = <String, ConversationToolCall>{};
  var blocked = false, changed = false;
  Future<ConversationMessage> reply(
    ConversationToolCall call,
    ConversationMessage? existing,
  ) async {
    final previous = existing == null ? null : _object(existing.text);
    if (existing != null &&
        (previous == null || !requiresAgentOutcomeReview(previous))) {
      return existing;
    }
    final isWrite = const {
      'mutation.commit',
      'external.commit',
      'host.action',
    }.contains(call.name);
    if (!isWrite) {
      if (existing != null) return existing;
      changed = true;
      return ConversationMessage(
        id: id(),
        role: ConversationRole.tool,
        text: jsonEncode({
          'status': 'not_executed',
          'error': {'code': 'interrupted_before_result'},
        }),
        toolCallId: call.id,
        createdAt: clock().toUtc(),
      );
    }
    final args = _object(call.arguments) ?? const <String, Object?>{};
    final binding = call.name == 'host.action'
        ? hostBindings[call.id]
        : bindings[args['planId'] ?? previous?['planId']];
    final operationId =
        previous?['operationId'] ?? args['operationId'] ?? binding?.operationId;
    String? toolName = call.name;
    if (call.name == 'host.action') {
      toolName = previous != null && previous['kind'] == 'external'
          ? 'external.commit'
          : binding?.toolName;
    }
    Map<String, Object?>? verified;
    if (operationId is String &&
        toolName is String &&
        readReceipt != null &&
        (binding == null || binding.toolName == toolName)) {
      try {
        final receipt = await readReceipt(toolName, operationId);
        if (receipt != null &&
            receipt['operationId'] == operationId &&
            !requiresAgentOutcomeReview(receipt) &&
            (toolName == 'mutation.commit'
                ? const {'committed', 'notRecorded'}.contains(receipt['status'])
                : const {
                    'applied',
                    'failed',
                    'notRecorded',
                  }.contains(receipt['status']))) {
          verified = {...receipt, 'recoveredFromOperationReceipt': true};
        }
      } catch (_) {
        // Expired IDs and unavailable stores are not proof of nonexecution.
      }
    }
    if (verified == null) blocked = true;
    final payload =
        verified ??
        <String, Object?>{
          ...?previous,
          'status': 'outcome_unknown',
          'error': {'code': 'operationRecoveryRequired'},
          'toolName': call.name,
          if (operationId is String) 'operationId': operationId,
          if (args['planId'] is String) 'planId': args['planId'],
          'recovery':
              'Only a host-verified durable receipt can allow further writes. '
              'Do not replay this operation or replace it with a new operation ID.',
        };
    var encoded = jsonEncode(payload);
    if (encoded.length > maxResultCharacters) {
      encoded = jsonEncode({
        for (final key in const [
          'status',
          'kind',
          'operationId',
          'generation',
          'sequence',
          'effectStatus',
          'dataStatus',
          'recoveryRequired',
          'receiptFinalized',
          'recoveredFromOperationReceipt',
        ])
          if (payload.containsKey(key)) key: payload[key],
        'detailsOmitted': true,
      });
    }
    if (existing != null && existing.text == encoded) return existing;
    changed = true;
    return ConversationMessage(
      id: existing?.id ?? id(),
      role: ConversationRole.tool,
      text: encoded,
      toolCallId: call.id,
      createdAt: existing?.createdAt ?? clock().toUtc(),
    );
  }

  Future<void> closeMissing() async {
    for (final call in pending.values) {
      result.add(await reply(call, null));
    }
    pending.clear();
  }

  for (final message in source) {
    if (message.role == ConversationRole.notice) {
      result.add(message);
      continue;
    }
    if (message.role == ConversationRole.tool) {
      final call = pending.remove(message.toolCallId);
      // The ordinary protocol validator still rejects unmatched tool replies.
      result.add(call == null ? message : await reply(call, message));
    } else {
      await closeMissing();
      result.add(message);
      for (final call in message.toolCalls) {
        pending[call.id] = call;
      }
    }
  }
  await closeMissing();
  return (messages: result, blocked: blocked, changed: changed);
}

/// Recovery reads may inspect history, sources and authoritative receipts.
/// Preparation, credentials, model probes and commits remain unavailable.
bool isAgentRecoveryRead(String name) => const {
  'capabilities.describe',
  'skills.search',
  'skills.load',
  'resources.describe',
  'agenda.query',
  'agenda.free_slots',
  'courses.conflicts',
  'period_sets.references',
  'settings.describe',
  'settings.get',
  'conversation.get',
  'conversation.history',
  'conversation.read',
  'conversations.describe',
  'conversations.list',
  'conversations.get',
  'sources.describe',
  'sources.read',
  'operations.status',
  'external.status',
  'external.reconcile',
  'runs.status',
  'workspaces.describe',
  'navigation.status',
  'backups.describe',
  'connection.describe',
  'agent.connection.get',
  'agent_settings.describe',
  'notifications.status',
  'notifications.reminders',
  'school_session.status',
  'school_sites.list',
  'school_sites.get',
  'device.layout.describe',
  'device.preferences.describe',
  'platform.status',
  'window.status',
  'file_imports.inspect',
  'selection.get',
  'timetables.list',
  'timetables.get',
  'courses.list',
  'courses.get',
  'period_sets.list',
  'period_sets.get',
  'calendars.list',
  'calendars.get',
  'events.list',
  'events.get',
  'occurrences.list',
  'occurrences.get',
}.contains(name);

Map<String, Object?>? _object(String text) {
  try {
    final decoded = jsonDecode(text);
    return decoded is Map<String, Object?> ? decoded : null;
  } on FormatException {
    return null;
  }
}
