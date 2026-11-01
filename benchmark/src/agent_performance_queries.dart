import 'dart:convert';

import 'package:sked/agent/conversations/conversation_models.dart';
import 'package:sked/agent/provider/provider_models.dart';
import 'package:sked/agent/tools/application_tool_host.dart';
import 'package:sked/application/operation_contracts.dart';

import 'agent_performance_fixtures.dart';

void requireAgentPerformance(bool condition, String description) {
  if (!condition) throw StateError(description);
}

void sameAgentPerformance(
  Object? actual,
  Object? expected,
  String description,
) {
  if (agentPerformanceDigest(actual) != agentPerformanceDigest(expected)) {
    throw StateError('$description changed its complete result.');
  }
}

Future<Map<String, Object?>> readAgentPerformanceTool(
  ApplicationToolHost host,
  OperationScope scope,
  String name,
  Map<String, Object?> arguments,
) => host.execute(
  ProviderToolCall(
    id: 'benchmark-read-$name',
    name: name,
    arguments: jsonEncode(arguments),
  ),
  scope,
  (_) async => throw StateError('A read workload requested mutation approval.'),
);

Future<List<Map<String, Object?>>> readAgentPerformanceHistory(
  ApplicationToolHost host,
  OperationScope scope,
) async {
  final pages = <Map<String, Object?>>[];
  var offset = 0;
  while (true) {
    final page = await readAgentPerformanceTool(
      host,
      scope,
      'conversation.history',
      {'offset': offset, 'limit': agentPerformanceHistoryPageSize},
    );
    pages.add(page);
    if (page['hasMore'] == false) return pages;
    final next = page['nextOffset'];
    if (next is! int || next <= offset || pages.length > 100) {
      throw StateError(
        'History paging did not advance within its fixed bound.',
      );
    }
    offset = next;
  }
}

void verifyAgentPerformanceHistory(
  List<Map<String, Object?>> pages,
  AgentConversation conversation,
) {
  final expected = <Map<String, Object?>>[];
  final messages = conversation.messages;
  for (
    var offset = 0;
    offset < messages.length;
    offset += agentPerformanceHistoryPageSize
  ) {
    final end = (offset + agentPerformanceHistoryPageSize).clamp(
      0,
      messages.length,
    );
    expected.add({
      'messages': [
        for (final message in messages.sublist(offset, end))
          {
            'id': message.id,
            'role': message.role.name,
            'createdAt': message.createdAt.toUtc().toIso8601String(),
            if (message.toolCallId != null) 'toolCallId': message.toolCallId,
            'toolNames': [for (final call in message.toolCalls) call.name],
          },
      ],
      'offset': offset,
      'total': messages.length,
      'nextOffset': end < messages.length ? end : null,
      'hasMore': end < messages.length,
    });
  }
  sameAgentPerformance(pages, expected, 'All history pages and their order');
}

Future<List<Map<String, Object?>>> readAgentPerformanceMessage(
  ApplicationToolHost host,
  OperationScope scope,
  String messageId,
) async {
  final pages = <Map<String, Object?>>[];
  var offset = 0;
  while (true) {
    final page = await readAgentPerformanceTool(
      host,
      scope,
      'conversation.read',
      {
        'id': messageId,
        'offset': offset,
        'limit': agentPerformanceReadPageSize,
      },
    );
    pages.add(page);
    if (page['hasMore'] == false) return pages;
    final next = page['nextOffset'];
    if (next is! int || next <= offset || pages.length > 100) {
      throw StateError(
        'Message paging did not advance within its fixed bound.',
      );
    }
    offset = next;
  }
}

void verifyAgentPerformanceMessage(
  List<Map<String, Object?>> pages,
  ConversationMessage message,
) {
  final original = jsonEncode(message.toJson());
  final characters = original.runes.toList();
  final expected = <Map<String, Object?>>[];
  for (
    var offset = 0;
    offset < characters.length;
    offset += agentPerformanceReadPageSize
  ) {
    final end = (offset + agentPerformanceReadPageSize).clamp(
      0,
      characters.length,
    );
    expected.add({
      'id': message.id,
      'encoding': 'json',
      'text': String.fromCharCodes(characters.sublist(offset, end)),
      'offset': offset,
      'totalCharacters': characters.length,
      'nextOffset': end < characters.length ? end : null,
      'hasMore': end < characters.length,
    });
  }
  sameAgentPerformance(pages, expected, 'Every Unicode message slice');
  final rebuilt = pages.map((page) => page['text'] as String).join();
  requireAgentPerformance(
    rebuilt == original,
    'The full message was truncated.',
  );
  sameAgentPerformance(
    jsonDecode(rebuilt),
    message.toJson(),
    'Reassembled message',
  );
}

Future<List<Map<String, Object?>>> readAgentPerformanceResources(
  ApplicationToolHost host,
  OperationScope scope, {
  required bool courses,
}) async {
  final pages = <Map<String, Object?>>[];
  String? cursor;
  final seenCursors = <String>{};
  while (true) {
    final page = await readAgentPerformanceTool(
      host,
      scope,
      courses ? 'courses.list' : 'timetables.list',
      {
        'limit': courses ? 100 : 2,
        'fields': courses
            ? agentPerformanceCourseFields
            : agentPerformanceTimetableFields,
        'cursor': ?cursor,
      },
    );
    pages.add(page);
    if (page['hasMore'] == false) return pages;
    final next = page['nextCursor'];
    if (next is! String || !seenCursors.add(next) || pages.length > 100) {
      throw StateError('Resource paging repeated or exceeded its fixed bound.');
    }
    cursor = next;
  }
}

void verifyAgentPerformanceResources(
  List<Map<String, Object?>> pages,
  List<Map<String, Object?>> expected,
) {
  final records = <Object?>[];
  Object? revision;
  for (var index = 0; index < pages.length; index++) {
    final page = pages[index];
    requireAgentPerformance(
      page['schemaVersion'] == 1,
      'Resource schema changed.',
    );
    requireAgentPerformance(
      page['datasetGeneration'] == agentPerformanceGeneration,
      'Resource generation changed.',
    );
    requireAgentPerformance(
      page['snapshotRevision'] is int && (page['snapshotRevision'] as int) >= 0,
      'Resource revision is missing.',
    );
    revision ??= page['snapshotRevision'];
    requireAgentPerformance(
      page['snapshotRevision'] == revision,
      'Paging crossed snapshots.',
    );
    requireAgentPerformance(
      page['totalMatches'] == expected.length,
      'Resource total changed.',
    );
    requireAgentPerformance(
      page['hasMore'] == (index < pages.length - 1),
      'Resource paging ended early.',
    );
    requireAgentPerformance(
      (page['nextCursor'] != null) == (index < pages.length - 1),
      'Resource cursor is inconsistent.',
    );
    records.addAll(page['items'] as List);
  }
  sameAgentPerformance(
    records,
    expected,
    'Every resource, field and result order',
  );
}

Future<List<Map<String, Object?>>> readAgentPerformanceCatalog(
  ApplicationToolHost host,
  OperationScope scope,
) async {
  final pages = <Map<String, Object?>>[];
  var offset = 0;
  while (true) {
    final page = await readAgentPerformanceTool(
      host,
      scope,
      'capabilities.describe',
      {'offset': offset, 'limit': 8},
    );
    pages.add(page);
    if (page['hasMore'] == false) return pages;
    final next = page['nextOffset'];
    if (next is! int || next <= offset || pages.length > 100) {
      throw StateError('Capability paging did not advance.');
    }
    offset = next;
  }
}

List<Map<String, Object?>> verifyAgentPerformanceCatalog(
  List<Map<String, Object?>> pages,
  Set<String> registeredNames,
) {
  final seen = <String>{};
  var offset = 0;
  final normalized = <Map<String, Object?>>[];
  for (var index = 0; index < pages.length; index++) {
    final page = pages[index];
    requireAgentPerformance(
      page['now'] is String && DateTime.tryParse(page['now'] as String) != null,
      'Capability observation time is missing.',
    );
    requireAgentPerformance(
      page['toolApiVersion'] == '1.0.0',
      'Tool API changed.',
    );
    requireAgentPerformance(
      page['permissionMode'] == 'full',
      'Capability scope changed.',
    );
    requireAgentPerformance(
      page['workspace'] == 'general',
      'Capability workspace changed.',
    );
    requireAgentPerformance(
      page['totalMatches'] == registeredNames.length,
      'The catalog omitted tools.',
    );
    final definitions = page['tools'] as List;
    for (final value in definitions) {
      final tool = value as Map;
      final name = tool['name'] as String;
      requireAgentPerformance(
        registeredNames.contains(name) && seen.add(name),
        'A tool is missing, invented or duplicated.',
      );
      requireAgentPerformance(
        (tool['description'] as String).isNotEmpty && tool['parameters'] is Map,
        'A tool omitted its full schema.',
      );
    }
    offset += definitions.length;
    final more = index < pages.length - 1;
    requireAgentPerformance(
      page['hasMore'] == more && page['nextOffset'] == (more ? offset : null),
      'Capability paging ended early.',
    );
    normalized.add({...page}..remove('now'));
  }
  requireAgentPerformance(
    seen.length == registeredNames.length,
    'The full catalog was not returned.',
  );
  // Only the explicitly declared wall-clock observation is removed. Every
  // description, schema, ordering and page boundary remains in the contract.
  return normalized;
}

void verifyAgentPerformanceContext(
  List<ProviderMessage>? result,
  List<ProviderMessage> original,
) {
  requireAgentPerformance(result != null, 'The fixed context did not fit.');
  final messages = result!;
  requireAgentPerformance(
    messages.length < original.length &&
        messages.length <= agentPerformanceContextMessages,
    'The context was not bounded.',
  );
  var characters = 0;
  final users = <String>[];
  final pending = <String>{};
  var checkpointCount = 0;
  for (final message in messages) {
    characters +=
        message.text.length + jsonEncode(message.responseItems).length;
    for (final call in message.toolCalls) {
      characters += call.id.length + call.name.length + call.arguments.length;
      requireAgentPerformance(
        pending.add(call.id),
        'Context duplicated a tool call.',
      );
    }
    if (message.role == ProviderRole.tool) {
      requireAgentPerformance(
        pending.remove(message.toolCallId),
        'Context split a tool result from its call.',
      );
    }
    if (message.role != ProviderRole.user) continue;
    if (message.text.startsWith(
      'Earlier conversation checkpoint, generated by Sked.',
    )) {
      checkpointCount++;
      final checkpoint = jsonDecode(
        message.text.substring(message.text.indexOf('\n') + 1),
      ) as Map;
      users.addAll((checkpoint['userRequests'] as List).cast<String>());
      requireAgentPerformance(
        (checkpoint['operationReferences'] as List).isEmpty,
        'Read-only fixture fabricated operation ownership.',
      );
    } else {
      users.add(message.text);
    }
  }
  requireAgentPerformance(
    checkpointCount == 1 && pending.isEmpty,
    'The compacted protocol groups are incomplete.',
  );
  requireAgentPerformance(
    characters <= agentPerformanceContextCharacters,
    'Context character budget was exceeded.',
  );
  sameAgentPerformance(
    users,
    original
        .where((message) => message.role == ProviderRole.user)
        .map((message) => message.text)
        .toList(),
    'All user requests in original order',
  );
  sameAgentPerformance(
    providerMessageRecords(messages.take(1)),
    providerMessageRecords(original.take(1)),
    'System guidance',
  );
  sameAgentPerformance(
    providerMessageRecords([messages.last]),
    providerMessageRecords([original.last]),
    'Newest complete group',
  );
}
