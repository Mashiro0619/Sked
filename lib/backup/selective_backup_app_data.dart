import 'dart:convert';
import 'dart:typed_data';

import '../agent/conversations/conversation_models.dart';
import '../agent/conversations/conversation_portable_history.dart';
import '../agent/knowledge/knowledge_models.dart';
import '../application/operation_contracts.dart' show AgentPermissionMode;
import '../data/migrations/migration.dart'
    show UnsupportedSchemaVersionException;
import '../l10n/app_locale.dart' show defaultLocaleCode;
import '../models/application_ledger.dart';
import '../models/school_site_models.dart';
import '../models/timetable_models.dart';
import 'selective_backup_models.dart';
import 'selective_backup_planner.dart';

enum BackupSettingsGroup {
  application,
  workspaces,
  student,
  general,
  notifications,
  agentConnection,
  agentPreferences,
}

const _settingsFields = <BackupSettingsGroup, Set<String>>{
  BackupSettingsGroup.application: {
    'localeCode',
    'hideHomeBottomNavigationBar',
    'homeWorkspaceNavigationCollapsed',
    'workspacePanelDisplayMode',
    'includePrereleaseUpdates',
    'ignoredUpdateVersion',
  },
  BackupSettingsGroup.workspaces: {'activeMode', 'enabledWorkspaces'},
  BackupSettingsGroup.student: {
    'closeCoursePopupOnOutsideTap',
    'preserveTimetableGaps',
    'showPastEndedCourses',
    'showFutureCourses',
    'showTimetableGridLines',
    'showAddCourseFab',
    'enableLongPressAddCourse',
    'fitDaySelectorToWidth',
    'fitWeekColumnsToWidth',
    'enableWeekSwipeNavigation',
    'toolbarNavigationOrder',
    'hiddenToolbarNavigationIds',
    'toolbarHiddenItemsBehavior',
    'themeMode',
    'themeColorMode',
    'themeSeedColorValue',
    'colorfulUiColorValues',
    'colorfulCourseTextColorMode',
    'courseNameColorValues',
    'liveCourseOutlineColorValue',
    'liveCourseOutlineEnabled',
    'liveCourseOutlineFollowTheme',
    'liveCourseOutlineCustomColorInitialized',
    'liveCourseOutlineMode',
    'liveCourseOutlineWidth',
  },
  BackupSettingsGroup.general: {
    'defaultView',
    'customDateRange',
    'viewSwitchBehavior',
    'toolbarWidthPolicy',
    'dateLabelFormat',
    'fitWeekColumnsToWidth',
    'customDayMinWidth',
    'showWeekends',
    'showLunarCalendar',
    'dayStartHour',
    'dayEndHour',
    'timeGridMinutes',
    'timeGridHourHeight',
    'closeEventPopupOnOutsideTap',
    'showAddEventFab',
    'enableLongPressAddEvent',
    'allDayTimelineCollapsed',
    'toolbarNavigationOrder',
    'hiddenToolbarNavigationIds',
    'toolbarHiddenItemsBehavior',
    'themeMode',
    'themeColorMode',
    'themeSeedColorValue',
    'colorfulUiColorValues',
  },
  BackupSettingsGroup.notifications: {
    'enabled',
    'courseDefaultMinutesBefore',
    'generalDefaultMinutesBefore',
    'lockScreenShowTitles',
    'remindHiddenGeneralCalendars',
  },
  BackupSettingsGroup.agentConnection: {
    'protocol',
    'endpoint',
    'model',
    'models',
  },
  BackupSettingsGroup.agentPreferences: {
    'systemInstructions',
    'maxModelRounds',
    'maxToolCalls',
    'maxTotalTokens',
    'historyRetentionDays',
  },
};

/// Produces metadata without reading binary files. Built-in Skills must be
/// passed as effective records from AgentKnowledgeService.exportSelected.
SelectiveBackupBundle buildSelectiveBackupInventory({
  required AppData appData,
  Iterable<SchoolSite> schoolSites = const [],
  Iterable<KnowledgeRecord> knowledge = const [],
  Iterable<AgentConversation> conversations = const [],
  Iterable<BackupRecord> devicePreferences = const [],
  bool includeAgentSettings = true,
  DateTime? createdAt,
}) {
  final records = <BackupRecord>[];
  for (final timetable in appData.studentMode.timetables) {
    records.add(
      BackupRecord(
        key: BackupObjectKey(BackupObjectKind.timetable, timetable.id),
        label: timetable.config.name,
        data: {
          'entity': timetable.toJson(),
          'displayChoices': {
            for (final entry
                in appData.studentMode.conflictDisplayCourseIds.entries)
              if (parseConflictKey(entry.key)?.timetableId == timetable.id)
                entry.key: entry.value,
          },
        },
        dependencies: [
          BackupObjectKey(
            BackupObjectKind.periodTimeSet,
            timetable.config.periodTimeSetId,
          ),
        ],
      ),
    );
  }
  for (final set in appData.studentMode.periodTimeSets) {
    records.add(
      BackupRecord(
        key: BackupObjectKey(BackupObjectKind.periodTimeSet, set.id),
        label: set.name,
        data: set.toJson(),
      ),
    );
  }
  for (final calendar in appData.generalMode.schedules) {
    records.add(
      BackupRecord(
        key: BackupObjectKey(BackupObjectKind.calendar, calendar.id),
        label: calendar.name,
        data: {
          'entity': calendar.toJson(),
          'reminderAcknowledgements': [
            for (final acknowledgement
                in appData.generalMode.reminderAcknowledgements)
              if (parseGeneralOccurrenceKey(acknowledgement.occurrenceKey)
                      ?.calendarId ==
                  calendar.id)
                acknowledgement.toJson(),
          ],
        },
      ),
    );
  }
  for (final site in schoolSites) {
    if (site.id.isEmpty) {
      backupInvalid('School-site identities must be migrated before backup.');
    }
    records.add(
      BackupRecord(
        key: BackupObjectKey(BackupObjectKind.schoolSite, site.id),
        label: site.name,
        data: site.toJson(),
      ),
    );
  }
  for (final record in knowledge) {
    if (record.usesOriginal && record.body.isEmpty) {
      backupInvalid('Read the effective built-in Skill before exporting it.');
    }
    final data = record.toJson()..['revision'] = 0;
    records.add(
      BackupRecord(
        key: BackupObjectKey(
          record.kind == KnowledgeKind.skill
              ? BackupObjectKind.skill
              : BackupObjectKind.memory,
          record.id,
        ),
        label: record.title,
        data: data,
      ),
    );
  }
  final attachmentRecords = <String, BackupRecord>{};
  for (final conversation in conversations) {
    for (final attachment in conversation.attachments) {
      final record = BackupRecord(
        key: BackupObjectKey(BackupObjectKind.attachment, attachment.id),
        label: attachment.name,
        data: attachment.toJson(),
      );
      final previous = attachmentRecords[attachment.id];
      if (previous != null && previous.fingerprint != record.fingerprint) {
        backupInvalid('Shared attachment identities conflict.');
      }
      attachmentRecords[attachment.id] = record;
    }
    records.add(
      BackupRecord(
        key: BackupObjectKey(BackupObjectKind.conversation, conversation.id),
        label: conversation.title,
        data: portableConversationData(conversation),
        dependencies: conversation.attachments.map(
          (item) => BackupObjectKey(BackupObjectKind.attachment, item.id),
        ),
      ),
    );
  }
  records.addAll(attachmentRecords.values);
  final appJson = appData.toJson();
  for (final group in BackupSettingsGroup.values) {
    if (!includeAgentSettings &&
        (group == BackupSettingsGroup.agentConnection ||
            group == BackupSettingsGroup.agentPreferences)) {
      continue;
    }
    final Map<String, dynamic> source = switch (group) {
      BackupSettingsGroup.student => appData.studentMode.toJson(),
      BackupSettingsGroup.general => appData.generalMode.toJson(),
      BackupSettingsGroup.notifications =>
        appData.notificationSettings.toJson(),
      BackupSettingsGroup.agentConnection ||
      BackupSettingsGroup.agentPreferences => appData.agentSettings.toJson(),
      _ => appJson,
    };
    records.add(
      BackupRecord(
        key: BackupObjectKey(BackupObjectKind.settings, group.name),
        label: group.name,
        data: {
          for (final field in _settingsFields[group]!) field: source[field],
        },
      ),
    );
  }
  for (final record in devicePreferences) {
    if (record.key.kind != BackupObjectKind.deviceSettings) {
      backupInvalid('Invalid device preference inventory.');
    }
    records.add(record);
  }
  return SelectiveBackupBundle(
    records: records,
    roots: records.map((record) => record.key),
    createdAt: createdAt,
  );
}

/// Legacy complete JSON enters the same object selector. It never synthesizes
/// a new Agent connection/preferences selection from decoder defaults.
SelectiveBackupBundle decodeLegacySelectiveBackup(
  String source, {
  String localeCode = defaultLocaleCode,
}) {
  if (utf8.encode(source).length > 20000000) {
    backupLimit('The legacy backup exceeds its import byte budget.');
  }
  final envelope = ImportExportEnvelope.decode(source);
  if (isImportExportSchema(envelope.schema, appBackupSchema) &&
          envelope.version > appBackupVersion ||
      isImportExportSchema(envelope.schema, appDataSchema) &&
          envelope.version > importExportVersion) {
    throw const SelectiveBackupException(
      SelectiveBackupError.unsupportedVersion,
      'The legacy backup uses a newer format.',
    );
  }
  final AppBackupData backup;
  try {
    backup = decodeAppBackup(source, localeCode: localeCode);
  } on UnsupportedSchemaVersionException {
    throw const SelectiveBackupException(
      SelectiveBackupError.unsupportedVersion,
      'The legacy backup contains a newer data schema.',
    );
  }
  final digest = backupDigest(utf8.encode(source)).substring(0, 24);
  var index = 0;
  final sites = assignSchoolSiteIdentities(
    backup.schoolSites,
    idGenerator: () => 'legacy-$digest-${index++}',
  );
  return buildSelectiveBackupInventory(
    appData: backup.appData,
    schoolSites: sites,
    includeAgentSettings: false,
  );
}

Future<SelectiveBackupBundle> exportSelectiveBackup({
  required SelectiveBackupBundle inventory,
  required BackupSelection selection,
  required Future<Uint8List> Function(
    ConversationAttachment attachment,
    BackupCancellation? cancellation,
  )
  readAttachment,
  BackupCancellation? cancellation,
}) async {
  final selected = inventory.select(selection);
  final records = <BackupRecord>[];
  final binaries = <String, Uint8List>{};
  var total = 0;
  for (final record in selected.records) {
    cancellation?.check();
    if (record.key.kind != BackupObjectKind.attachment ||
        !selection.attachmentBytes.contains(record.key.id)) {
      records.add(record);
      continue;
    }
    final attachment = ConversationAttachment.fromJson(record.data);
    if (!binaries.containsKey(attachment.digest)) {
      final bytes = await readAttachment(attachment, cancellation);
      cancellation?.check();
      if (bytes.length != attachment.byteLength ||
          backupDigest(bytes) != attachment.digest) {
        backupInvalid('An attachment changed while the backup was prepared.');
      }
      total += bytes.length;
      if (total > SelectiveBackupLimits.expandedBytes) {
        backupLimit('The selected files exceed the backup byte budget.');
      }
      binaries[attachment.digest] = bytes;
    }
    records.add(record.withBinary(attachment.digest));
  }
  return SelectiveBackupBundle(
    records: records,
    roots: selected.roots,
    binaries: binaries,
    createdAt: selected.createdAt,
  );
}

Map<String, Object?> portableConversationData(AgentConversation conversation) {
  final history = conversationAsPortableHistory(conversation);
  final raw = history.toJson();
  return {
    'id': history.id,
    'title': history.title,
    'createdAt': history.createdAt.toUtc().toIso8601String(),
    'updatedAt': history.updatedAt.toUtc().toIso8601String(),
    'archived': history.archived,
    'draft': history.draft,
    'messages': history.messages.map((item) => item.toJson()).toList(),
    'sources': history.sources.map((item) => item.toJson()).toList(),
    'attachments': history.attachments.map((item) => item.toJson()).toList(),
    'draftAttachmentIds': history.draftAttachmentIds,
    if (raw['historyVersions'] case final List versions)
      'historyVersions': versions,
    if (raw['replyRevisions'] case final List revisions)
      'replyRevisions': revisions,
  };
}

AgentConversation restorePortableConversation(
  BackupRecord record, {
  required AgentPermissionMode currentMode,
}) {
  if (record.key.kind != BackupObjectKind.conversation) {
    backupInvalid('This backup object is not a conversation.');
  }
  final data = _mutable(record.data);
  const required = {
    'id',
    'title',
    'createdAt',
    'updatedAt',
    'archived',
    'draft',
    'messages',
    'sources',
    'attachments',
    'draftAttachmentIds',
  };
  const optional = {'historyVersions', 'replyRevisions'};
  if (!required.every(data.containsKey) ||
      data.keys.any(
        (key) => !required.contains(key) && !optional.contains(key),
      )) {
    backupInvalid('Unexpected or missing portable conversation fields.');
  }
  if (data['id'] != record.key.id) {
    backupInvalid('Conversation identity mismatch.');
  }
  final messages = backupList(data['messages'], max: 1000);
  for (final raw in messages) {
    if (raw is! Map || raw.containsKey('responseItems')) {
      backupInvalid(
        'Provider continuation cannot be restored from a portable backup.',
      );
    }
  }
  data.addAll({
    'mode': currentMode.name,
    'status': ConversationStatus.idle.name,
    'runs': const [],
    'turns': const [],
    'executionHistoryStart': messages.length,
  });
  final restored = conversationAsPortableHistory(
    AgentConversation.fromJson(data),
  ).copyWith(mode: currentMode);
  if (restored.executionHistoryStart != messages.length) {
    throw StateError('The host did not isolate imported conversation history.');
  }
  return restored;
}

List<KnowledgeRecord> selectedKnowledgeRestoreRecords(
  BackupRestorePlan plan,
) => [
  for (final change in plan.changes)
    if (change.needsWrite && change.after.key.owner == BackupOwner.knowledge)
      _knowledgeRecord(change.after),
];

KnowledgeRecord _knowledgeRecord(BackupRecord record) {
  if (record.data['revision'] != 0) {
    backupInvalid('Portable knowledge cannot supply a local revision.');
  }
  final parsed = KnowledgeRecord.fromJson(_mutable(record.data));
  if (record.key.id != parsed.id ||
      (record.key.kind == BackupObjectKind.skill) !=
          (parsed.kind == KnowledgeKind.skill)) {
    backupInvalid('Knowledge identity mismatch.');
  }
  return parsed;
}

List<SchoolSite> mergeSelectedSchoolSites(
  List<SchoolSite> current,
  BackupRestorePlan plan,
) {
  final replacements = <String, SchoolSite>{};
  for (final change in plan.changes) {
    if (change.after.key.kind != BackupObjectKind.schoolSite ||
        !change.needsWrite) {
      continue;
    }
    final data = _mutable(change.after.data);
    backupMap(data, {'id', 'name', 'loginUrl'});
    final site = SchoolSite.fromJson(data);
    if (site.id != change.after.key.id || !site.isValid) {
      backupInvalid('Invalid restored school site.');
    }
    replacements[site.id] = site;
  }
  return [
    for (final site in current) replacements.remove(site.id) ?? site,
    ...replacements.values,
  ];
}

class PreparedMainBackupRestore {
  const PreparedMainBackupRestore({
    required this.target,
    required this.connectionReplacementRequired,
    required this.copiedChildIds,
  });
  final AppData target;
  final bool connectionReplacementRequired;
  final Map<String, String> copiedChildIds;
}

/// Construct once inside the restore barrier and persist this exact target.
/// This helper does not write data, credentials, notifications, or a journal.
PreparedMainBackupRestore prepareMainBackupRestore(
  AppData current,
  BackupRestorePlan plan, {
  DateTime? restoredAt,
}) {
  final currentInventory = buildSelectiveBackupInventory(appData: current)
      .byKey;
  final mainChanges = plan.changes
      .where((change) => change.after.key.owner == BackupOwner.mainData)
      .toList();
  for (final change in mainChanges) {
    if (currentInventory[change.after.key]?.fingerprint !=
        change.beforeFingerprint) {
      throw SelectiveBackupException(
        SelectiveBackupError.conflict,
        'A main-data restore target changed.',
        targets: [change.after.key],
      );
    }
  }
  final applying = mainChanges.where((change) => change.needsWrite).toList();
  if (applying.isEmpty) {
    return PreparedMainBackupRestore(
      target: plan.changes.any((change) => change.needsWrite)
          ? current.copyWith(
              applicationLedger: ApplicationLedger(
                generation: plan.dataGeneration,
              ),
            )
          : current,
      connectionReplacementRequired: false,
      copiedChildIds: const {},
    );
  }
  final json = _mutable(current.toJson());
  final student = json['studentMode'] as Map<String, dynamic>;
  final general = json['generalMode'] as Map<String, dynamic>;
  final selectedTimetables = applying
      .where((change) => change.after.key.kind == BackupObjectKind.timetable)
      .map((change) => change.after.key.id)
      .toSet();
  final selectedCalendars = applying
      .where((change) => change.after.key.kind == BackupObjectKind.calendar)
      .map((change) => change.after.key.id)
      .toSet();
  final usedCourseIds = {
    for (final table in current.studentMode.timetables)
      if (!selectedTimetables.contains(table.id))
        ...table.courses.map((course) => course.id),
  };
  final usedEventIds = {
    for (final calendar in current.generalMode.schedules)
      if (!selectedCalendars.contains(calendar.id))
        ...calendar.events.map((event) => event.id),
  };
  final copied = <String, String>{};
  String childId(String kind, String parentId, String id, Set<String> used) {
    if (used.add(id)) return id;
    final source = '$kind:$parentId:$id';
    for (var attempt = 0; attempt < 64; attempt++) {
      final next =
          'restored-${backupDigest(utf8.encode('${plan.id}:$source:$attempt')).substring(0, 32)}';
      if (used.add(next)) {
        copied[source] = next;
        return next;
      }
    }
    backupInvalid('Unable to rebind a conflicting child identity.');
  }

  final timetableChanges = <String, Map<String, dynamic>>{},
      periodChanges = <String, Map<String, dynamic>>{},
      calendarChanges = <String, Map<String, dynamic>>{};
  final choices = Map<String, Object?>.from(
    student['conflictDisplayCourseIds'] as Map,
  );
  choices.removeWhere(
    (key, _) => selectedTimetables.contains(parseConflictKey(key)?.timetableId),
  );
  final acknowledgements = (general['reminderAcknowledgements'] as List)
      .where(
        (item) => !selectedCalendars.contains(
          parseGeneralOccurrenceKey((item as Map)['occurrenceKey'] as String)
              ?.calendarId,
        ),
      )
      .toList();
  var nextCalendarOrder =
      current.generalMode.schedules.fold<int>(
        -1,
        (max, calendar) => calendar.sortOrder > max ? calendar.sortOrder : max,
      ) +
      1;
  for (final change in applying) {
    final record = change.after;
    final data = _mutable(record.data);
    switch (record.key.kind) {
      case BackupObjectKind.timetable:
        backupMap(data, {'entity', 'displayChoices'});
        final entity = _entity(data, record.key);
        _verifyEntityRoundtrip(entity, TimetableData.fromJson(entity).toJson());
        final ids = <String>{}, remapped = <String, String>{};
        for (final raw in backupList(entity['courses'], max: 100000)) {
          final course = raw as Map<String, dynamic>;
          final id = backupText(course['id'], max: 256);
          if (!ids.add(id)) {
            backupInvalid('Duplicate course identity in selected timetable.');
          }
          course['id'] = remapped[id] = childId(
            'course',
            record.key.id,
            id,
            usedCourseIds,
          );
        }
        final display = data['displayChoices'];
        if (display is! Map<String, dynamic>) {
          backupInvalid('Invalid timetable display choices.');
        }
        for (final entry in display.entries) {
          final parts = parseConflictKey(entry.key);
          if (parts == null ||
              parts.timetableId != record.key.id ||
              entry.value is! String ||
              !ids.contains(entry.value)) {
            backupInvalid('Invalid timetable display choice.');
          }
          final changed = parts.courseIds.any((id) => remapped[id] != id);
          final key = changed
              ? [
                  'v2',
                  Uri.encodeComponent(record.key.id),
                  parts.weekday,
                  parts.startMinutes,
                  parts.endMinutes,
                  (parts.courseIds.map((id) => remapped[id] ?? id).toList()
                        ..sort())
                      .map(Uri.encodeComponent)
                      .join(','),
                ].join('|')
              : entry.key;
          choices[key] = remapped[entry.value] ?? entry.value;
        }
        timetableChanges[record.key.id] = entity;
      case BackupObjectKind.periodTimeSet:
        if (data['id'] != record.key.id) {
          backupInvalid('Period-time-set identity mismatch.');
        }
        _verifyEntityRoundtrip(data, PeriodTimeSet.fromJson(data).toJson());
        periodChanges[record.key.id] = data;
      case BackupObjectKind.calendar:
        backupMap(data, {'entity', 'reminderAcknowledgements'});
        final entity = _entity(data, record.key);
        _verifyEntityRoundtrip(
          entity,
          GeneralSchedule.fromJson(entity).toJson(),
        );
        final ids = <String>{}, remapped = <String, String>{};
        for (final raw in backupList(entity['events'], max: 100000)) {
          final event = raw as Map<String, dynamic>;
          final id = backupText(event['id'], max: 256);
          if (!ids.add(id) || event['calendarId'] != record.key.id) {
            backupInvalid('Invalid selected event identity.');
          }
          event['id'] = remapped[id] = childId(
            'event',
            record.key.id,
            id,
            usedEventIds,
          );
        }
        final old = current.generalMode.schedules
            .where((calendar) => calendar.id == record.key.id)
            .firstOrNull;
        entity['sortOrder'] = old?.sortOrder ?? nextCalendarOrder++;
        for (final raw in backupList(
          data['reminderAcknowledgements'],
          max: 100000,
        )) {
          final item = Map<String, dynamic>.from(raw as Map);
          final parts = parseGeneralOccurrenceKey(
            item['occurrenceKey'] as String,
          );
          if (parts == null ||
              parts.calendarId != record.key.id ||
              !ids.contains(parts.eventId)) {
            backupInvalid('Invalid selected reminder acknowledgement.');
          }
          if (remapped[parts.eventId] != parts.eventId) {
            item['occurrenceKey'] = buildGeneralOccurrenceKey(
              record.key.id,
              remapped[parts.eventId]!,
              parts.startDateTimeIso,
            );
          }
          acknowledgements.add(item);
        }
        calendarChanges[record.key.id] = entity;
      case BackupObjectKind.settings:
        final group = BackupSettingsGroup.values
            .where((group) => group.name == record.key.id)
            .firstOrNull;
        if (group == null) backupInvalid('Unknown settings group.');
        backupMap(data, _settingsFields[group]!);
        final Map<String, dynamic> target = switch (group) {
          BackupSettingsGroup.student => student,
          BackupSettingsGroup.general => general,
          BackupSettingsGroup.notifications => json.putIfAbsent(
            'notificationSettings',
            () => <String, dynamic>{},
          ) as Map<String, dynamic>,
          BackupSettingsGroup.agentConnection ||
          BackupSettingsGroup.agentPreferences =>
            json['agentSettings'] as Map<String, dynamic>,
          _ => json,
        };
        for (final entry in data.entries) {
          if (entry.value == null) {
            target.remove(entry.key);
          } else {
            target[entry.key] = entry.value;
          }
        }
      default:
        backupInvalid('Unexpected main-data object kind.');
    }
  }
  List<Object?> merge(
    List original,
    Map<String, Map<String, dynamic>> replacements,
  ) => [
    for (final entity in original)
      replacements.remove((entity as Map)['id']) ?? entity,
    ...replacements.values,
  ];
  student['timetables'] = merge(
    student['timetables'] as List,
    timetableChanges,
  );
  student['periodTimeSets'] = merge(
    student['periodTimeSets'] as List,
    periodChanges,
  );
  student['conflictDisplayCourseIds'] = choices;
  general['schedules'] = merge(general['schedules'] as List, calendarChanges);
  general['reminderAcknowledgements'] = acknowledgements;
  final agent = json['agentSettings'] as Map<String, dynamic>;
  final connectionChanged =
      agent['endpoint'] != current.agentSettings.endpoint ||
      agent['protocol'] != current.agentSettings.protocol.name;
  if (connectionChanged) agent['credentialRef'] = null;
  if (mainChanges.any((change) => change.needsWrite)) {
    json['applicationLedger'] = ApplicationLedger(
      generation: plan.dataGeneration,
    ).toJson();
  }
  var target = AppData.decodeStorageSnapshot(jsonEncode(json));
  final newlyEnabled = target.enabledWorkspaces.difference(
    current.enabledWorkspaces,
  );
  if (newlyEnabled.isNotEmpty) {
    final at = (restoredAt ?? DateTime.now()).toUtc();
    target = target.copyWith(
      workspaceReminderNotBefore: {
        ...current.workspaceReminderNotBefore,
        for (final mode in newlyEnabled) mode: at,
      },
    );
  }
  return PreparedMainBackupRestore(
    target: target,
    connectionReplacementRequired: connectionChanged,
    copiedChildIds: Map.unmodifiable(copied),
  );
}

Map<String, dynamic> _mutable(Map<String, Object?> data) =>
    jsonDecode(jsonEncode(data)) as Map<String, dynamic>;
Map<String, dynamic> _entity(Map<String, dynamic> data, BackupObjectKey key) {
  final entity = data['entity'];
  if (entity is! Map<String, dynamic> || entity['id'] != key.id) {
    backupInvalid('Backup object identity mismatch.');
  }
  return entity;
}

void _verifyEntityRoundtrip(
  Map<String, dynamic> input,
  Map<String, dynamic> decoded,
) {
  if (canonicalBackupJson(input) != canonicalBackupJson(decoded)) {
    backupInvalid(
      'The backup object contains unsupported or non-canonical fields.',
    );
  }
}
