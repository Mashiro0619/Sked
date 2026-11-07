import 'dart:convert';

import '../conversations/conversation_models.dart';
import '../history/conversation_history.dart';
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
  Iterable<ConversationOperationBinding> operationBindings = const [],
}) async {
  final bindings = {
    for (final binding in operationBindings) binding.toolCallId: binding,
  };
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
    final binding = bindings[call.id];
    if (binding == null && previous == null) {
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
    final operationId = binding?.operationId;
    final toolName = binding?.store == ConversationOperationStore.main
        ? 'mutation.commit'
        : 'external.commit';
    Map<String, Object?>? recoveryError;
    Map<String, Object?>? verified;
    if (operationId != null && readReceipt != null) {
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
      } catch (error) {
        recoveryError = {
          'code': 'receiptReadFailed',
          'message': error.toString(),
        };
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
          'operationId': ?operationId,
          if (binding == null)
            'recoveryError': {'code': 'missingOperationBinding'},
          'recoveryError': ?recoveryError,
          'recovery':
              'Only a host-verified durable receipt can allow further writes. '
              'Do not replay this operation or replace it with a new operation ID.',
        };
    final encoded = jsonEncode(payload);
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
/// Business actions, credentials and model probes remain unavailable.
bool isAgentRecoveryRead(String name) => const {
  'ask_user',
  'update_plan',
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
