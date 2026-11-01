import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/conversations/conversation_models.dart';
import 'package:sked/agent/knowledge/knowledge_models.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/backup/selective_backup_app_data.dart';
import 'package:sked/backup/selective_backup_models.dart';
import 'package:sked/backup/selective_backup_planner.dart';
import 'package:sked/models/agent_settings.dart';
import 'package:sked/models/school_site_models.dart';
import 'package:sked/models/timetable_models.dart';

AppData _base() => buildInitialAppData(buildDefaultPeriodTimes());
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
        ),
        localeCode: 'zh',
      );
      final incoming = _base().copyWith(
        agentSettings: const AgentSettings(
          systemInstructions: 'New preference',
          maxModelRounds: 12,
        ),
      );
      final plan = _prepare(incoming, current, const [
        BackupObjectKey(BackupObjectKind.settings, 'agentPreferences'),
      ]);
      final result = prepareMainBackupRestore(current, plan);
      expect(result.target.agentSettings.systemInstructions, 'New preference');
      expect(result.target.agentSettings.maxModelRounds, 12);
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

  test('restored transcript remains readable but has no executable history, credential destination or continuation', () {
    final conversation = AgentConversation(
      id: 'chat',
      title: 'Chat',
      createdAt: DateTime.utc(2026, 10, 31),
      updatedAt: DateTime.utc(2026, 10, 31),
      mode: AgentPermissionMode.full,
      status: ConversationStatus.waitingApproval,
      runId: 'old-run',
      connectionFingerprint: 'old-destination',
      messages: [
        ConversationMessage(
          id: 'request',
          role: ConversationRole.user,
          text: 'Request',
          createdAt: DateTime.utc(2026, 10, 31),
        ),
        ConversationMessage(
          id: 'queued',
          role: ConversationRole.notice,
          text: '{"kind":"agent_pending_input","version":1,"mode":"followUp","text":"Old request"}',
          createdAt: DateTime.utc(2026, 10, 31),
        ),
        ConversationMessage(
          id: 'reply',
          role: ConversationRole.assistant,
          text: 'Reply',
          createdAt: DateTime.utc(2026, 10, 31),
          responseItems: const [
            {'type': 'message', 'id': 'opaque-provider-item'},
          ],
        ),
      ],
    );
    final record = buildSelectiveBackupInventory(
      appData: _base(),
      conversations: [conversation],
    ).byKey[const BackupObjectKey(BackupObjectKind.conversation, 'chat')]!;
    expect(jsonEncode(record.data), isNot(contains('opaque-provider-item')));
    final restored = restorePortableConversation(
      record,
      currentMode: AgentPermissionMode.plan,
    );
    expect(
      restored.messages.map((message) => message.text),
      conversation.messages.map((message) => message.text),
    );
    expect(restored.executionMessages, isEmpty);
    expect(restored.mode, AgentPermissionMode.plan);
    expect(restored.status, ConversationStatus.idle);
    expect(restored.runId, isNull);
    expect(restored.connectionFingerprint, isNull);
    expect(restored.runs, isEmpty);
    expect(restored.turns, isEmpty);
    expect(restored.redoBatches, isEmpty);
  });

  test('selected files are read only when their bytes are explicitly included and checksum verified', () async {
    final bytes = Uint8List.fromList([1, 2, 3]);
    final attachment = ConversationAttachment(
      id: 'file',
      name: 'data.bin',
      mediaType: 'application/octet-stream',
      byteLength: 3,
      digest: backupDigest(bytes),
    );
    final chat = AgentConversation(
      id: 'chat',
      title: 'Chat',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      attachments: [attachment],
    );
    final inventory = buildSelectiveBackupInventory(
      appData: _base(),
      conversations: [chat],
    );
    var reads = 0;
    Future<Uint8List> read(
      ConversationAttachment _,
      BackupCancellation? cancellation,
    ) async {
      reads++;
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

  test('portable knowledge includes effective text and enabled state without local receipts or revisions', () {
    final memory = KnowledgeRecord(
      kind: KnowledgeKind.memory,
      id: 'preference',
      title: 'Preference',
      body: 'Mornings',
      revision: 21,
      enabled: false,
    );
    final inventory = buildSelectiveBackupInventory(
      appData: _base(),
      knowledge: [memory],
    );
    final record = inventory
        .byKey[const BackupObjectKey(BackupObjectKind.memory, 'preference')]!;
    expect(record.data['revision'], 0);
    expect(record.data['enabled'], isFalse);
    expect(record.data['body'], 'Mornings');
    expect(record.data, isNot(contains('receipts')));
  });
}
