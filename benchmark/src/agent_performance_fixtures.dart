import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:sked/agent/conversations/conversation_models.dart';
import 'package:sked/agent/provider/provider_models.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/models/agent_settings.dart';
import 'package:sked/models/application_ledger.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/import_export_service.dart';

import 'benchmark_fixtures.dart';

const agentPerformanceDatasetVersion = 1;
const agentPerformanceProtocol = 'agent-host-jit-v1';
const agentPerformanceLongConversationId = 'agent-benchmark-long';
const agentPerformanceBulkConversationId = 'agent-benchmark-bulk';
const agentPerformanceGeneration = '00000000-0000-4000-8000-000000000001';
const agentPerformanceLongTurns = 128;
const agentPerformanceHistoryPageSize = 50;
const agentPerformanceReadPageSize = 512;
const agentPerformanceContextMessages = 48;
const agentPerformanceContextCharacters = 12000;
const agentPerformanceTimetableFields = [
  'courseCount',
  'name',
  'workspaceEnabled',
];
const agentPerformanceCourseFields = [
  'location',
  'name',
  'teacher',
  'workspaceEnabled',
];

/// The existing performance records remain intact. Local feature flags,
/// workspace, locale, preferences and the initially empty ledger are fixed.
/// The disabled student workspace deliberately still owns all five timetables.
class AgentPerformanceFixtures {
  AgentPerformanceFixtures._(
    this.data,
    this.archive,
    this.context,
    this.sourceReminderAcknowledgementCount,
  );

  factory AgentPerformanceFixtures.build() {
    final source = PerformanceFixtures.build().appData;
    final seeded = AppData.decodeStorageSnapshot(
      source
          .copyWith(
            activeMode: AppMode.general,
            enabledWorkspaces: {AppMode.general},
            localeCode: 'en',
            agentSettings: const AgentSettings(
              enabled: true,
              permissionMode: AgentPermissionMode.full,
            ),
            applicationLedger: ApplicationLedger(
              generation: agentPerformanceGeneration,
            ),
          )
          .encode(),
    );
    // Prepare canonical preferences before timing, using the same normalizer
    // as AppLifecycle. The raw fixture contains synthetic conflict choices and
    // only two course colors; loading it otherwise schedules a migration save.
    final data = const ImportExportService().normalizeAppData(
      seeded,
      localeCode: 'en',
    );
    Map<String, Object?> records(AppData value) => {
      'timetables': [
        for (final table in value.studentMode.timetables) table.toJson(),
      ],
      'calendars': [
        for (final calendar in value.generalMode.schedules) calendar.toJson(),
      ],
    };
    if (agentPerformanceDigest(records(data)) !=
            agentPerformanceDigest(records(source)) ||
        agentPerformanceDigest(data.generalMode.toJson()) !=
            agentPerformanceDigest(seeded.generalMode.toJson())) {
      throw StateError(
        'Agent fixture preparation changed performance records.',
      );
    }
    final date = DateTime.utc(2026, 1, 1);
    final messages = <ConversationMessage>[];
    for (var turn = 0; turn < agentPerformanceLongTurns; turn++) {
      final callId = 'query-$turn';
      final time = date.add(Duration(minutes: turn));
      messages.addAll([
        ConversationMessage(
          id: 'long-$turn-request',
          role: ConversationRole.user,
          text: 'Preserve requirement $turn exactly.',
          createdAt: time,
        ),
        ConversationMessage(
          id: 'long-$turn-call',
          role: ConversationRole.assistant,
          text: '',
          createdAt: time,
          toolCalls: [
            ConversationToolCall(
              id: callId,
              name: 'timetables.list',
              arguments: '{"limit":2}',
            ),
          ],
        ),
        ConversationMessage(
          id: 'long-$turn-result',
          role: ConversationRole.tool,
          createdAt: time,
          toolCallId: callId,
          text: jsonEncode({
            'fixture': 'synthetic-read-only-history',
            'items': [
              for (var item = 0; item < 32; item++)
                {
                  'id': 'history-$turn-$item',
                  'name': 'Synthetic query result $turn / $item',
                },
            ],
            'hasMore': false,
          }),
        ),
        ConversationMessage(
          id: 'long-$turn-reply',
          role: ConversationRole.assistant,
          createdAt: time,
          text: List.generate(
            64,
            (line) =>
                'Explanation $turn/$line: synthetic read-only context, '
                'with fixed Unicode text 江南 🙂.\n',
          ).join(),
        ),
      ]);
    }
    final long = AgentConversation(
      id: agentPerformanceLongConversationId,
      title: 'Fixed long conversation',
      createdAt: date,
      updatedAt: date,
      messages: messages,
    );
    final archive = ConversationArchive(
      revision: 1,
      selectedId: long.id,
      conversations: [
        long,
        for (var index = 0; index < 30; index++)
          AgentConversation(
            id: 'agent-benchmark-short-$index',
            title: 'Fixed conversation $index',
            createdAt: date,
            updatedAt: date,
            messages: [
              for (var message = 0; message < 8; message++)
                ConversationMessage(
                  id: 'short-$index-$message',
                  role: message.isEven
                      ? ConversationRole.user
                      : ConversationRole.assistant,
                  text: 'Fixed message $index / $message',
                  createdAt: date,
                ),
            ],
          ),
        AgentConversation(
          id: agentPerformanceBulkConversationId,
          title: 'Fixed host command conversation',
          mode: AgentPermissionMode.full,
          createdAt: date,
          updatedAt: date,
          messages: [
            ConversationMessage(
              id: 'bulk-request',
              role: ConversationRole.user,
              text: 'Apply the declared synthetic benchmark batch.',
              createdAt: date,
            ),
          ],
        ),
      ],
    );
    // Exercise the owning archive decoder before any measured work. These
    // fixtures contain read-only tool data, never manufactured write receipts.
    final restored = ConversationArchive.decode(archive.encode());
    final context = <ProviderMessage>[
      ProviderMessage(
        role: ProviderRole.system,
        text: 'Fixed benchmark system guidance. No operation is authorized.',
      ),
      for (final message in restored.conversations.first.messages)
        ProviderMessage(
          role: switch (message.role) {
            ConversationRole.user => ProviderRole.user,
            ConversationRole.assistant => ProviderRole.assistant,
            ConversationRole.tool => ProviderRole.tool,
            ConversationRole.notice => throw StateError('Unexpected notice'),
          },
          text: message.text,
          toolCallId: message.toolCallId,
          toolCalls: [
            for (final call in message.toolCalls)
              ProviderToolCall(
                id: call.id,
                name: call.name,
                arguments: call.arguments,
              ),
          ],
        ),
      ProviderMessage(
        role: ProviderRole.user,
        text: 'Summarize while preserving every previous requirement.',
      ),
    ];
    return AgentPerformanceFixtures._(
      data,
      restored,
      context,
      source.generalMode.reminderAcknowledgements.length,
    );
  }

  final AppData data;
  final ConversationArchive archive;
  final List<ProviderMessage> context;
  final int sourceReminderAcknowledgementCount;

  AgentConversation get longConversation => archive.conversations.first;

  AppData dataWithAgent(bool enabled) => data.copyWith(
    agentSettings: data.agentSettings.copyWith(enabled: enabled),
  );

  Map<String, Object?> get manifest => {
    'version': agentPerformanceDatasetVersion,
    'sourceDatasetVersion': performanceDatasetVersion,
    'mainEnabledSha256': agentPerformanceDigest(data.toJson()),
    'mainDisabledSha256': agentPerformanceDigest(dataWithAgent(false).toJson()),
    'chatSha256': agentPerformanceDigest(jsonDecode(archive.encode())),
    'contextSha256': agentPerformanceDigest(providerMessageRecords(context)),
    'mainUtf8Bytes': utf8.encode(data.encode()).length,
    'chatUtf8Bytes': utf8.encode(archive.encode()).length,
    'timetables': data.studentMode.timetables.length,
    'courses': data.studentMode.timetables.fold<int>(
      0,
      (sum, table) => sum + table.courses.length,
    ),
    'events': data.generalMode.schedules.fold<int>(
      0,
      (sum, calendar) => sum + calendar.events.length,
    ),
    'sourceReminderAcknowledgements': sourceReminderAcknowledgementCount,
    'storedReminderAcknowledgements':
        data.generalMode.reminderAcknowledgements.length,
    'reminderAcknowledgementNormalization':
        'storage decoder rejects invalid calendar/event occurrence ownership',
    'studentWorkspaceEnabled': false,
    'conversations': archive.conversations.length,
    'longMessages': longConversation.messages.length,
    'contextMessages': context.length,
    'allMessages': archive.conversations.fold<int>(
      0,
      (sum, conversation) => sum + conversation.messages.length,
    ),
    'contextMaxMessages': agentPerformanceContextMessages,
    'contextMaxCharacters': agentPerformanceContextCharacters,
    'knowledgeRecords': 0,
    'binaryAttachments': 0,
    'credentials': 'empty memory store',
    'writeWorkloads': {
      'rename-one-timetable': {
        'timetablesChanged': 1,
        'targetId': data.studentMode.timetables.first.id,
        'otherTimetablesUnchanged': 4,
      },
      'batch-one-hundred-course-locations': {
        'coursesChanged': 100,
        'timetablesTouched': 5,
      },
    },
    'capacityBoundary': {
      'originalDraftCase': 'batch-five-timetable-names',
      'originalDraftCompleted': false,
      'originalDraftFailure': 'receipt structural and byte admission limits',
      'originalDraftUndoChangesJsonBytes': 3707556,
      'receiptMaxJsonBytes': operationReceiptMaxJsonBytes,
      'receiptMaxJsonNodes': operationReceiptMaxJsonNodes,
      'singleTimetableMeasurementValidatesOriginalDraft': false,
    },
  };

  List<Map<String, Object?>> expectedResourceRecords({required bool courses}) {
    final tables = [...data.studentMode.timetables]
      ..sort((left, right) => left.id.compareTo(right.id));
    return [
      for (final table in tables)
        if (!courses)
          {
            'ref': {'kind': 'timetable', 'id': table.id},
            'view': 'summary',
            'includedFields': agentPerformanceTimetableFields,
            'data': {
              'courseCount': table.courses.length,
              'name': table.config.name,
              'workspaceEnabled': false,
            },
          }
        else
          for (final course in ([
            ...table.courses,
          ]..sort((left, right) => left.id.compareTo(right.id))))
            {
              'ref': {'kind': 'course', 'id': course.id, 'parentId': table.id},
              'view': 'summary',
              'includedFields': agentPerformanceCourseFields,
              'data': {
                'location': course.location,
                'name': course.name,
                'teacher': course.teacher,
                'workspaceEnabled': false,
              },
            },
    ];
  }

  List<Map<String, Object?>> bulkCommands({required bool courses}) => [
    for (final table
        in courses
            ? data.studentMode.timetables
            : data.studentMode.timetables.take(1))
      if (!courses)
        {
          'kind': 'timetable',
          'action': 'patch',
          'target': {'id': table.id},
          'values': {'name': 'Revised benchmark ${table.id}'},
        }
      else
        for (final course in table.courses.take(20))
          {
            'kind': 'course',
            'action': 'patch',
            'target': {'id': course.id, 'parentId': table.id},
            'values': {'location': 'Fixed benchmark laboratory'},
          },
  ];

  AppData expectedAfterBulk({required bool courses}) => data.copyWith(
    studentMode: data.studentMode.copyWith(
      timetables: [
        for (final table in data.studentMode.timetables)
          if (!courses)
            table.id == data.studentMode.timetables.first.id
                ? table.copyWith(
                    config: table.config.copyWith(
                      name: 'Revised benchmark ${table.id}',
                    ),
                  )
                : table
          else
            table.copyWith(
              courses: [
                for (var index = 0; index < table.courses.length; index++)
                  index < 20
                      ? table.courses[index].copyWith(
                          location: 'Fixed benchmark laboratory',
                        )
                      : table.courses[index],
              ],
            ),
      ],
    ),
  );
}

List<Map<String, Object?>> providerMessageRecords(
  Iterable<ProviderMessage> messages,
) => [
  for (final message in messages)
    {
      'role': message.role.name,
      'text': message.text,
      'toolCallId': message.toolCallId,
      'toolCalls': [
        for (final call in message.toolCalls)
          {'id': call.id, 'name': call.name, 'arguments': call.arguments},
      ],
      'responseItems': message.responseItems,
    },
];

Object? canonicalAgentPerformanceValue(Object? value) => switch (value) {
  Map value => {
    for (final key in value.keys.cast<String>().toList()..sort())
      key: canonicalAgentPerformanceValue(value[key]),
  },
  Iterable value => [
    for (final item in value) canonicalAgentPerformanceValue(item),
  ],
  _ => value,
};

String agentPerformanceDigest(Object? value) => sha256
    .convert(utf8.encode(jsonEncode(canonicalAgentPerformanceValue(value))))
    .toString();

Map<String, Object?> agentPerformanceDomain(AppData data) => {
  ...data.toJson(),
  // Full raw ledger equality is checked against physical readback separately.
  // Runtime receipt timestamps are deliberately absent from the fixed digest.
  'applicationLedger': null,
};
