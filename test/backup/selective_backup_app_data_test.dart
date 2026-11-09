import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/attachments/attachment_models.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/backup/selective_backup_agent_data.dart';
import 'package:sked/backup/selective_backup_app_data.dart';
import 'package:sked/backup/selective_backup_models.dart';
import 'package:sked/backup/selective_backup_planner.dart';
import 'package:sked/models/agent_settings.dart';
import 'package:sked/models/school_site_models.dart';
import 'package:sked/models/timetable_models.dart';

AppData _base() => buildInitialAppData(buildDefaultPeriodTimes());
Map<String, Object?> _nativeConversation({
  List<Map<String, Object?>> attachments = const [],
}) => {
  'conversation': {
    'id': 'chat',
    'title': 'Chat',
    'mode': 'ask',
    'status': 'idle',
    'createdAt': 1793404800000,
    'updatedAt': 1793404800000,
    'draft': '',
    'draftOnly': false,
    'archived': false,
    'pinned': false,
    'titleWasEdited': false,
    'modelSelection': null,
    'connectionFingerprint': null,
    'runId': null,
    'executionHistoryStart': 2,
    'draftAttachmentIds': <String>[],
    'draftReferences': <Object?>[],
    'titleGeneration': null,
  },
  'sequence': 0,
  'messages': [
    {
      'id': 'request',
      'role': 'user',
      'text': 'Request',
      'createdAt': 1793404800000,
      'toolCalls': <Object?>[],
      'responseItems': <Object?>[],
      'attachmentIds': attachments.map((value) => value['id']).toList(),
      'contextReferences': <Object?>[],
    },
    {
      'id': 'reply',
      'role': 'assistant',
      'text': 'Reply',
      'createdAt': 1793404800000,
      'toolCalls': <Object?>[],
      'responseItems': <Object?>[],
      'attachmentIds': <String>[],
      'contextReferences': <Object?>[],
    },
  ],
  'attachments': attachments,
  'runs': <Object?>[],
  'turns': <Object?>[],
  'operations': <Object?>[],
  'queuedInputs': <Object?>[],
  'queuedControls': <Object?>[],
  'currentQuestion': null,
  'plan': null,
  'checkpoint': null,
  'contextFailures': <Object?>[],
  'historyVersions': <Object?>[],
  'replyRevisions': <Object?>[],
  'redoBatches': <Object?>[],
  'attachmentReferences': <Object?>[],
  'sources': <Object?>[],
  'handoffs': <Object?>[],
  'providerHistory': <Object?>[],
  'extensions': <String, Object?>{},
};

BackupRestorePlan _prepare(
  AppData source,
  AppData current,
  List<BackupObjectKey> keys,
) => const SelectiveBackupPlanner().prepare(
  source: buildSelectiveBackupInventory(appData: source),
  current: buildSelectiveBackupInventory(appData: current),
  selection: BackupSelection(objects: keys),
);
CourseItem _course(String id, String name) => CourseItem.fromJson({
  'id': id,
  'name': name,
  'dayOfWeek': 1,
  'semesterWeeks': [1],
  'periods': [1],
  'startMinutes': 480,
  'endMinutes': 525,
  'timeRange': '08:00 - 08:45',
});
GeneralEvent _event(String id, String calendarId, String title) => GeneralEvent(
  id: id,
  calendarId: calendarId,
  title: title,
  startDateTimeIso: '2026-10-31T08:00:00.000',
  endDateTimeIso: '2026-10-31T09:00:00.000',
  reminders: const [GeneralEventReminder(minutesBefore: 10)],
);

void main() {
  test('Agent preferences drop legacy token budgets on restore and export', () {
    const key = BackupObjectKey(BackupObjectKind.settings, 'agentPreferences');
    final current = _base();
    final inventory = buildSelectiveBackupInventory(appData: current);
    final preferences = inventory.byKey[key]!;
    expect(preferences.data, isNot(contains('maxTotalTokens')));
    for (final legacy in <Object?>[100000, 0, -1, 1000001, null, 'obsolete']) {
      final incoming = SelectiveBackupBundle(
        records: [
          BackupRecord(
            key: key,
            label: preferences.label,
            data: {
              ...preferences.data,
              'systemInstructions': 'Restored guidance.',
              'maxTotalTokens': legacy,
              'maxModelRounds': legacy,
              'maxToolCalls': legacy,
            },
          ),
        ],
        roots: const [key],
      );
      final plan = const SelectiveBackupPlanner().prepare(
        source: incoming,
        current: inventory,
        selection: BackupSelection(objects: const [key]),
      );
      final restored = prepareMainBackupRestore(current, plan).target;
      expect(restored.agentSettings.systemInstructions, 'Restored guidance.');
      expect(
        restored.agentSettings.toJson(),
        isNot(contains('maxTotalTokens')),
      );
      expect(
        buildSelectiveBackupInventory(appData: restored).byKey[key]!.data,
        isNot(contains('maxTotalTokens')),
      );
    }
  });

  test('legacy JSON enters object selection without injecting connection defaults or merging site names', () {
    final source = encodeAppBackup(_base(), const [
      SchoolSite(name: 'Same name', loginUrl: 'https://one.example.test'),
      SchoolSite(name: 'Same name', loginUrl: 'https://two.example.test'),
    ]);
    final first = decodeLegacySelectiveBackup(source),
        second = decodeLegacySelectiveBackup(source);
    final sites = first.records
        .where((record) => record.key.kind == BackupObjectKind.schoolSite)
        .toList();
    expect(sites, hasLength(2));
    expect(sites.map((record) => record.key.id).toSet(), hasLength(2));
    expect(
      sites.map((record) => record.key),
      second.records
          .where((record) => record.key.kind == BackupObjectKind.schoolSite)
          .map((record) => record.key),
    );
    expect(
      first.byKey,
      isNot(
        contains(
          const BackupObjectKey(BackupObjectKind.settings, 'agentConnection'),
        ),
      ),
    );
    expect(
      first.byKey,
      isNot(
        contains(
          const BackupObjectKey(BackupObjectKind.settings, 'agentPreferences'),
        ),
      ),
    );
  });

  test('selecting Agent connection preserves local authorization and removes old destination credentials', () {
    final current = _base().copyWith(
      agentSettings: const AgentSettings(
        enabled: false,
        permissionMode: AgentPermissionMode.plan,
        endpoint: 'https://old.example.test/v1',
        model: 'old',
        credentialRef: 'local-secret-reference',
        systemInstructions: 'Keep me',
        models: [
          AgentModelConfig(
            id: 'old',
            reasoningEfforts: [AgentReasoningEffort.medium],
            defaultReasoningEffort: AgentReasoningEffort.medium,
          ),
        ],
      ),
    );
    final incoming = _base().copyWith(
      agentSettings: const AgentSettings(
        enabled: true,
        permissionMode: AgentPermissionMode.full,
        endpoint: 'https://new.example.test/v1',
        model: 'new',
        credentialRef: 'foreign-reference',
        systemInstructions: 'Other instructions',
        models: [
          AgentModelConfig(
            id: 'new',
            reasoningEfforts: [AgentReasoningEffort.medium],
            defaultReasoningEffort: AgentReasoningEffort.medium,
          ),
        ],
      ),
    );
    final inventory = buildSelectiveBackupInventory(appData: incoming);
    final portable = jsonEncode(
      inventory.records.map((record) => record.toJson()).toList(),
    );
    expect(portable, isNot(contains('foreign-reference')));
    expect(portable, isNot(contains('permissionMode')));
    final plan = _prepare(incoming, current, const [
      BackupObjectKey(BackupObjectKind.settings, 'agentConnection'),
    ]);
    final restored = prepareMainBackupRestore(current, plan);
    expect(
      restored.target.agentSettings.endpoint,
      'https://new.example.test/v1',
    );
    expect(restored.target.agentSettings.model, 'new');
    expect(restored.target.agentSettings.enabled, isFalse);
    expect(
      restored.target.agentSettings.permissionMode,
      AgentPermissionMode.plan,
    );
    expect(restored.target.agentSettings.credentialRef, isNull);
    expect(restored.target.agentSettings.systemInstructions, 'Keep me');
    expect(restored.connectionReplacementRequired, isTrue);
    expect(
      plan.owners,
      containsAll([BackupOwner.mainData, BackupOwner.credentials]),
    );
  });

  test(
    'preferences alone preserve connection and unselected settings groups',
    () {
      final current = _base().copyWith(
        agentSettings: const AgentSettings(
          endpoint: 'https://local.example.test',
          model: 'local',
          credentialRef: 'local-key',
          models: [
            AgentModelConfig(
              id: 'local',
              reasoningEfforts: [AgentReasoningEffort.medium],
              defaultReasoningEffort: AgentReasoningEffort.medium,
            ),
          ],
        ),
        localeCode: 'zh',
      );
      final incoming = _base().copyWith(
        agentSettings: const AgentSettings(
          systemInstructions: 'New preference',
          historyRetentionDays: 12,
        ),
      );
      final plan = _prepare(incoming, current, const [
        BackupObjectKey(BackupObjectKind.settings, 'agentPreferences'),
      ]);
      final result = prepareMainBackupRestore(current, plan);
      expect(result.target.agentSettings.systemInstructions, 'New preference');
      expect(result.target.agentSettings.historyRetentionDays, 12);
      expect(
        result.target.agentSettings.endpoint,
        current.agentSettings.endpoint,
      );
      expect(result.target.agentSettings.credentialRef, 'local-key');
      expect(result.target.localeCode, 'zh');
      expect(result.target.studentMode.toJson(), current.studentMode.toJson());
      expect(result.connectionReplacementRequired, isFalse);
    },
  );

  test('selected timetable copies a conflicting dependency and course ID while preserving unselected data', () {
    final base = _base();
    final template = TimetableData(
      id: 'template',
      config: TimetableConfig(
        name: 'Template',
        startDate: DateTime(2026, 9, 7),
        totalWeeks: 18,
        periodTimeSetId: base.studentMode.periodTimeSets.first.id,
      ),
      courses: const [],
    );
    final kept = template.copyWith(
      id: 'kept',
      config: template.config.copyWith(name: 'Kept'),
      courses: [_course('collision', 'Current course')],
    );
    final current = base.copyWith(
      studentMode: base.studentMode.copyWith(
        timetables: [kept],
        activeTimetableId: kept.id,
      ),
    );
    final selected = template.copyWith(
      id: 'selected',
      config: template.config.copyWith(name: 'Imported'),
      courses: [_course('collision', 'Imported course')],
    );
    final importedSet = base.studentMode.periodTimeSets.first.copyWith(
      name: 'Imported time set',
    );
    final incoming = base.copyWith(
      studentMode: base.studentMode.copyWith(
        timetables: [selected],
        activeTimetableId: selected.id,
        periodTimeSets: [
          importedSet,
          ...base.studentMode.periodTimeSets.skip(1),
        ],
      ),
    );
    final plan = _prepare(incoming, current, const [
      BackupObjectKey(BackupObjectKind.timetable, 'selected'),
    ]);
    final result = prepareMainBackupRestore(current, plan);
    expect(result.target.studentMode.timetables.first.toJson(), kept.toJson());
    expect(result.target.studentMode.activeTimetableId, 'kept');
    final restored = result.target.studentMode.timetables.last;
    expect(restored.id, 'selected');
    expect(restored.courses.single.id, isNot('collision'));
    expect(restored.courses.single.name, 'Imported course');
    expect(restored.config.periodTimeSetId, isNot(kept.config.periodTimeSetId));
    expect(result.copiedChildIds, contains('course:selected:collision'));
    expect(result.target.applicationLedger!.generation, plan.dataGeneration);
  });

  test('calendar restore rebinds only selected event and reminder acknowledgement identities', () {
    final base = _base();
    final keptEvent = _event('collision', 'kept', 'Kept event');
    final kept = GeneralSchedule(id: 'kept', name: 'Kept', events: [keptEvent]);
    final current = base.copyWith(
      generalMode: base.generalMode.copyWith(
        schedules: [kept],
        activeScheduleId: 'kept',
      ),
    );
    final importedEvent = _event('collision', 'selected', 'Imported event');
    final selected = GeneralSchedule(
      id: 'selected',
      name: 'Imported',
      events: [importedEvent],
    );
    final acknowledgement = GeneralReminderAcknowledgement(
      occurrenceKey: buildGeneralOccurrenceKey(
        'selected',
        'collision',
        importedEvent.startDateTimeIso,
      ),
      updatedAtIso: '2026-10-31T09:00:00.000Z',
    );
    final incoming = base.copyWith(
      generalMode: base.generalMode.copyWith(
        schedules: [selected],
        activeScheduleId: 'selected',
        reminderAcknowledgements: [acknowledgement],
      ),
    );
    final plan = _prepare(incoming, current, const [
      BackupObjectKey(BackupObjectKind.calendar, 'selected'),
    ]);
    final restored = prepareMainBackupRestore(current, plan).target;
    expect(restored.generalMode.schedules.first.toJson(), kept.toJson());
    expect(restored.generalMode.activeScheduleId, 'kept');
    final event = restored.generalMode.schedules.last.events.single;
    expect(event.id, isNot('collision'));
    expect(
      parseGeneralOccurrenceKey(
        restored.generalMode.reminderAcknowledgements.single.occurrenceKey,
      )!.eventId,
      event.id,
    );
  });

  test(
    'native conversation inventory preserves snapshot identity and payload',
    () {
      final conversation = _nativeConversation();
      final records = nativeAgentBackupRecords({
        'conversations': [conversation],
        'knowledge': <Object?>[],
        'attachments': <Object?>[],
      });
      final record = buildSelectiveBackupInventory(
        appData: _base(),
        agentRecords: records,
      ).byKey[const BackupObjectKey(BackupObjectKind.conversation, 'chat')]!;
      expect(record.label, 'Chat');
      expect(record.data, conversation);
      expect(nativeArchiveParts([record]), {
        'conversations': [conversation],
        'knowledge': <Object?>[],
        'attachments': <Object?>[],
      });
    },
  );

  test('selected files are read only when their bytes are explicitly included and checksum verified', () async {
    final bytes = Uint8List.fromList([1, 2, 3]);
    final attachment = <String, Object?>{
      'id': 'file',
      'name': 'data.bin',
      'mediaType': 'application/octet-stream',
      'byteLength': 3,
      'sha256': backupDigest(bytes),
      'createdAt': 1793404800000,
    };
    final chat = _nativeConversation(attachments: [attachment]);
    final inventory = buildSelectiveBackupInventory(
      appData: _base(),
      agentRecords: nativeAgentBackupRecords({
        'conversations': [chat],
        'knowledge': <Object?>[],
        'attachments': [attachment],
      }),
    );
    expect(
      inventory
          .byKey[const BackupObjectKey(BackupObjectKind.conversation, 'chat')]!
          .dependencies,
      const [BackupObjectKey(BackupObjectKind.attachment, 'file')],
    );
    var reads = 0;
    Future<Uint8List> read(
      ConversationAttachment value,
      BackupCancellation? cancellation,
    ) async {
      reads++;
      expect(value.id, 'file');
      expect(value.digest, attachment['sha256']);
      expect(value.byteLength, bytes.length);
      return bytes;
    }

    final metadata = await exportSelectiveBackup(
      inventory: inventory,
      selection: BackupSelection(
        objects: const [BackupObjectKey(BackupObjectKind.conversation, 'chat')],
      ),
      readAttachment: read,
    );
    expect(metadata.binaries, isEmpty);
    expect(reads, 0);
    final full = await exportSelectiveBackup(
      inventory: inventory,
      selection: BackupSelection(
        objects: const [BackupObjectKey(BackupObjectKind.conversation, 'chat')],
        attachmentBytes: const ['file'],
      ),
      readAttachment: read,
    );
    expect(full.binaries.values.single, bytes);
    expect(reads, 1);
    await expectLater(
      exportSelectiveBackup(
        inventory: inventory,
        selection: BackupSelection(
          objects: const [
            BackupObjectKey(BackupObjectKind.conversation, 'chat'),
          ],
          attachmentBytes: const ['file'],
        ),
        readAttachment: (_, _) async => Uint8List.fromList([3, 2, 1]),
      ),
      throwsA(isA<SelectiveBackupException>()),
    );
  });

  test(
    'native knowledge inventory keeps the portable payload and enabled state',
    () {
      const memory = <String, Object?>{
        'kind': 'memory',
        'id': 'preference',
        'title': 'Preference',
        'body': 'Mornings',
        'summary': '',
        'revision': 0,
        'enabled': false,
        'builtIn': false,
        'usesOriginal': false,
        'baseVersion': null,
        'baseSha256': null,
        'triggers': <String>[],
        'sourceKinds': <String>[],
        'requiredTools': <String>[],
        'optionalTools': <String>[],
        'sourceNote': '',
        'sourceConversationId': null,
        'sourceMessageId': null,
        'references': <Object?>[],
        'expiresAt': null,
      };
      final inventory = buildSelectiveBackupInventory(
        appData: _base(),
        agentRecords: nativeAgentBackupRecords({
          'conversations': <Object?>[],
          'knowledge': [memory],
          'attachments': <Object?>[],
        }),
      );
      final record = inventory
          .byKey[const BackupObjectKey(BackupObjectKind.memory, 'preference')]!;
      expect(record.label, 'Preference');
      expect(record.data, memory);
      expect(nativeArchiveParts([record])['knowledge'], [memory]);
    },
  );
}
