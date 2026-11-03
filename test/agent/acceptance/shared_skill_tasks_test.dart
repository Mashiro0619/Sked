import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/skills/shared_skill_loader.dart';
import 'package:sked/agent/tools/agent_control_tool_adapters.dart';
import 'package:sked/models/agent_settings.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/agenda_notification_service.dart';
import 'package:sked/services/desktop_layout_preferences.dart';

import '../../support/data_transfer_codec.dart';
import 'acceptance_harness.dart';

typedef SkillTask = Future<void> Function(AcceptanceHarness);

// These are deterministic task executions, not model-quality evaluations.
// The real Skill is loaded before each task, and the real application tools
// determine all IDs, candidates, saved state and operation receipts.
final sharedSkillTasks = <String, SkillTask>{
  'locate-and-navigate': _locate,
  'read-agenda': _readAgenda,
  'find-free-time': _findFreeTime,
  'manage-semester': _semester,
  'edit-courses': _courses,
  'manage-period-times': _periods,
  'resolve-course-conflicts': _conflictDisplay,
  'organize-calendars': _calendars,
  'edit-events': _events,
  'edit-recurring-events': _recurring,
  'manage-reminders': _reminders,
  'batch-change': _batch,
  'import-school-web': _webImport,
  'import-pasted-content': _pastedImport,
  'import-structured-files': _structuredImport,
  'export-and-backup': _export,
  'restore-and-clear': _restore,
  'configure-appearance': _appearance,
  'configure-display': _display,
  'configure-workspaces': _workspaces,
  'troubleshoot-notifications': _notifications,
  'manage-school-access': _schoolSites,
  'configure-agent-connection': _connection,
  'recover-and-undo': _undo,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every published Skill has an executable domain task', () async {
    final manifest = jsonDecode(
      await rootBundle.loadString(SharedSkillLoader.manifestAsset),
    ) as Map;
    expect(
      (manifest['skills'] as List).map((entry) => entry['id']).toSet(),
      sharedSkillTasks.keys.toSet(),
      reason:
          'Add a task with a domain-state assertion when publishing a Skill.',
    );
  });

  for (final entry in sharedSkillTasks.entries) {
    test('shared Skill task: ${entry.key}', () async {
      final h = AcceptanceHarness();
      await h.initialize();
      addTearDown(h.close);
      await h.run(() => entry.value(h), skill: entry.key);
    });
  }
}

List<Map> _items(Map result) => (result['items'] as List).cast<Map>();

Future<Map<String, Object?>> _mutate(
  AcceptanceHarness h,
  List<Map<String, Object?>> commands,
) async => h.commit(await h.call('mutation.prepare', {'commands': commands}));

Map<String, Object?> _patch(
  String kind,
  String id,
  Map<String, Object?> values, {
  String? parent,
}) => {
  'kind': kind,
  'action': 'patch',
  'target': {'id': id, 'parentId': ?parent},
  'values': values,
};

Future<void> _locate(AcceptanceHarness h) async {
  final matches = _items(await h.call('courses.list', {'query': 'Algebra'}));
  expect(matches, hasLength(2));
  final target = matches.singleWhere(
    (row) => row['ref']['parentId'] == 'other',
  );
  final before = h.saved.studentMode.activeTimetableId;
  final plan = await h.call('navigation.open', {
    'workspace': 'student',
    'ref': target['ref'],
    'week': 2,
  });
  expect(h.navigationTargets, isEmpty);
  final result = await h.externalCommit(plan);
  expect(result['effectStatus'], 'applied');
  expect(h.navigationTargets.single.ref!.id, 'other-algebra');
  expect(h.navigationTargets.single.ref!.parentId, 'other');
  expect(h.navigationTargets.single.week, 2);
  // The fake navigation sink observes the exact real target. It does not claim
  // to mount a widget or change the actual native application's selection.
  expect(h.saved.studentMode.activeTimetableId, before);
}

Future<void> _readAgenda(AcceptanceHarness h) async {
  final before = h.saved.encode();
  final page = await h.call('agenda.query', {
    'start': '2026-09-07T08:00:00',
    'end': '2026-09-07T12:00:00',
  });
  expect(page['hasMore'], isFalse);
  expect(page['totalMatches'], 4);
  final owners = _items(page).map((row) => row['ref']['parentId']).toSet();
  expect(owners, {'current', 'other', 'hidden'});
  expect(h.saved.encode(), before);
}

Future<void> _findFreeTime(AcceptanceHarness h) async {
  final slots = await h.call('agenda.free_slots', {
    'start': '2026-09-07T08:00:00',
    'end': '2026-09-07T12:00:00',
    'minimumMinutes': 60,
  });
  final slot = _items(slots).single;
  expect(slot['start'], '2026-09-07T11:00:00.000');
  expect(slot['end'], '2026-09-07T12:00:00.000');
  await _mutate(h, [
    {
      'kind': 'event',
      'action': 'create',
      'destinationParentId': 'visible',
      'values': {
        'title': 'One hour revision',
        'start': slot['start'],
        'end': slot['end'],
        'reminderBehavior': 'custom',
        'reminders': [
          {'minutesBefore': 10},
        ],
      },
    },
  ]);
  final event = h.saved.generalMode.schedules.first.events.single;
  expect(event.startDateTimeIso, slot['start']);
  expect(event.endDateTimeIso, slot['end']);
  expect(event.reminders.single.minutesBefore, 10);
  final after = await h.call('agenda.free_slots', {
    'start': '2026-09-07T08:00:00',
    'end': '2026-09-07T12:00:00',
    'minimumMinutes': 60,
  });
  expect(_items(after), isEmpty);
}

Future<void> _semester(AcceptanceHarness h) async {
  final timeSets = _items(await h.call('period_sets.list'));
  final id = timeSets.single['ref']['id'];
  await _mutate(h, [
    {
      'kind': 'timetable',
      'action': 'create',
      'values': {
        'name': 'Spring semester',
        'startDate': '2027-03-01',
        'totalWeeks': 16,
        'periodTimeSetId': id,
      },
    },
  ]);
  final added = h.saved.studentMode.timetables.last;
  expect(added.config.name, 'Spring semester');
  expect(added.config.startDate, DateTime(2027, 3, 1));
  expect(added.config.totalWeeks, 16);
  expect(added.config.periodTimeSetId, id);
  expect(h.saved.studentMode.activeTimetableId, 'current');
}

Future<void> _courses(AcceptanceHarness h) async {
  final original = h.saved.studentMode.timetables.last.courses.single;
  await _mutate(h, [
    _patch('course', original.id, {'teacher': 'New teacher'}, parent: 'other'),
  ]);
  final changed = h.saved.studentMode.timetables.last.courses.single;
  expect(changed.teacher, 'New teacher');
  expect(
    changed.copyWith(teacher: original.teacher).toJson(),
    original.toJson(),
  );
  expect(
    h.saved.studentMode.timetables.first.courses.first.teacher,
    'Original teacher',
  );
}

Future<void> _periods(AcceptanceHarness h) async {
  final references = await h.call('period_sets.references', {'id': 'periods'});
  expect(_items(references).map((row) => row['ref']['id']).toSet(), {
    'current',
    'other',
  });
  await _mutate(h, [
    {
      'kind': 'periodTimeSet',
      'action': 'create',
      'values': {
        'name': 'Late start',
        'periodTimes': [
          {'index': 1, 'startMinutes': 510, 'endMinutes': 570},
          {'index': 2, 'startMinutes': 580, 'endMinutes': 640},
        ],
      },
    },
  ]);
  final newId = h.saved.studentMode.periodTimeSets.last.id;
  await _mutate(h, [
    _patch('timetable', 'other', {'periodTimeSetId': newId}),
  ]);
  expect(h.saved.studentMode.timetables.last.config.periodTimeSetId, newId);
  expect(
    h.saved.studentMode.timetables.first.config.periodTimeSetId,
    'periods',
  );
  expect(h.saved.studentMode.timetables.last.courses.single.periods, [2]);
  expect(
    h.saved.studentMode.periodTimeSets.last.periodTimes.last.endMinutes,
    640,
  );
}

Future<void> _conflictDisplay(AcceptanceHarness h) async {
  final before = h.saved.studentMode.timetables.first.toJson();
  final groups = await h.call('courses.display.list', {
    'timetableId': 'current',
    'week': 1,
  });
  final group = (groups['rows'] as List).single as Map;
  expect(group['selectableCourseIds'], ['algebra', 'physics']);
  await h.commit(
    await h.call('courses.display.prepare', {
      'action': 'set',
      'timetableId': 'current',
      'week': 1,
      'conflictKey': group['conflictKey'],
      'courseId': 'physics',
    }),
  );
  expect(
    h.saved.studentMode.conflictDisplayCourseIds[group['conflictKey']],
    'physics',
  );
  expect(h.saved.studentMode.timetables.first.toJson(), before);
}

Future<void> _calendars(AcceptanceHarness h) async {
  await _mutate(h, [
    {
      'kind': 'calendar',
      'action': 'create',
      'values': {'name': 'Private studies', 'isVisible': false},
    },
  ]);
  final created = h.saved.generalMode.schedules.last;
  expect(created.name, 'Private studies');
  expect(created.isVisible, isFalse);
  expect(created.events, isEmpty);
  expect(h.saved.generalMode.activeScheduleId, 'visible');
  final listed = await h.call('calendars.list', {'query': 'Private studies'});
  expect(_items(listed).single['ref']['id'], created.id);
}

Future<void> _events(AcceptanceHarness h) async {
  await _mutate(h, [
    _patch('event', 'appointment', {
      'title': 'Rescheduled appointment',
    }, parent: 'hidden'),
    {
      'kind': 'event',
      'action': 'move',
      'target': {'id': 'appointment', 'parentId': 'hidden'},
      'destinationParentId': 'visible',
    },
  ]);
  final moved = h.saved.generalMode.schedules.first.events.single;
  expect(moved.id, 'appointment');
  expect(moved.calendarId, 'visible');
  expect(moved.title, 'Rescheduled appointment');
  expect(moved.notes, 'Preserve private note');
  expect(h.saved.generalMode.schedules.last.events.map((e) => e.id), [
    'weekly',
  ]);
}

Future<void> _recurring(AcceptanceHarness h) async {
  final page = await h.call('occurrences.list', {
    'sourceIds': ['weekly'],
    'start': '2026-09-14T00:00:00',
    'end': '2026-09-15T00:00:00',
  });
  final ref = _items(page).single['ref'] as Map;
  await _mutate(h, [
    {
      'kind': 'occurrence',
      'action': 'patch',
      'target': {'id': ref['id'], 'parentId': ref['parentId']},
      'scope': 'thisAndFollowing',
      'values': {'title': 'New review series'},
    },
  ]);
  final events = h.saved.generalMode.schedules.last.events;
  final prefix = events.singleWhere((e) => e.id == 'weekly');
  final suffix = events.singleWhere((e) => e.title == 'New review series');
  expect(prefix.recurrenceRule.count, 1);
  expect(suffix.recurrenceRule.count, 3);
  expect(suffix.startDateTimeIso, '2026-09-14T13:00:00.000');
  expect(h.saved.generalMode.schedules.last.isVisible, isFalse);
  expect(h.saved.generalMode.activeScheduleId, 'visible');
}

Future<void> _reminders(AcceptanceHarness h) async {
  await h.commit(
    await h.call('settings.prepare', {
      'edits': [
        {
          'key': 'app.notifications.generalDefaultMinutesBefore',
          'action': 'set',
          'value': 15,
        },
      ],
    }),
  );
  await _mutate(h, [
    _patch('event', 'appointment', {
      'reminderBehavior': 'inherit',
    }, parent: 'hidden'),
  ]);
  final settings = await h.call('notifications.status');
  expect((settings['preferences'] as Map)['generalDefaultMinutesBefore'], 15);
  expect(
    h.saved.generalMode.schedules.last.events.first.reminderBehavior,
    GeneralEventReminderBehavior.inherit,
  );
  expect(h.saved.generalMode.schedules.last.events.first.reminders, isEmpty);
}

Future<void> _batch(AcceptanceHarness h) async {
  final rows = _items(await h.call('courses.list', {'query': 'Algebra'}));
  final before = h.saved.studentMode.timetables.first.courses.last.toJson();
  final result = await _mutate(h, [
    for (final row in rows)
      _patch('course', row['ref']['id'] as String, {
        'location': 'Shared lab',
      }, parent: row['ref']['parentId'] as String),
  ]);
  expect(result['operationId'], isNotEmpty);
  final all = h.saved.studentMode.timetables.expand((table) => table.courses);
  expect(all.where((c) => c.name == 'Algebra').map((c) => c.location), [
    'Shared lab',
    'Shared lab',
  ]);
  expect(all.singleWhere((c) => c.id == 'physics').toJson(), before);
  expect(h.saved.studentMode.activeTimetableId, 'current');
}

Map<String, Object?> _importCandidate() => {
  'name': 'Imported term',
  'startDate': '2026-09-07',
  'totalWeeks': 18,
  'courses': [
    {
      'name': 'Source algebra',
      'dayOfWeek': 2,
      'semesterWeeks': [1, 2],
      'periods': [1],
      'teacher': 'Source teacher',
      'location': 'Room 201',
    },
  ],
};

Future<void> _sourceImport(AcceptanceHarness h, String kind) async {
  const material =
      'Term begins 2026-09-07; 18 weeks. Source algebra: '
      'Tuesday, weeks 1 and 2, period 1, Source teacher, Room 201.';
  await h.attach('source', kind, material);
  final source = await h.call('sources.read', {'id': 'source'});
  expect(source['text'], material);
  final existing = h.saved.studentMode.activeTimetableId;
  await h.commit(
    await h.call('imports.prepare', {
      'sourceId': 'source',
      'action': 'create',
      'periodTimeSetId': 'periods',
      'candidate': _importCandidate(),
    }),
  );
  final table = h.saved.studentMode.timetables.last;
  expect(table.config.startDate, DateTime(2026, 9, 7));
  expect(table.config.totalWeeks, 18);
  expect(table.courses.single.name, 'Source algebra');
  expect(table.courses.single.semesterWeeks, [1, 2]);
  expect(table.courses.single.location, 'Room 201');
  expect(h.saved.studentMode.activeTimetableId, existing);
}

Future<void> _webImport(AcceptanceHarness h) =>
    _sourceImport(h, 'reviewed_school_web');
Future<void> _pastedImport(AcceptanceHarness h) =>
    _sourceImport(h, 'pasted_text');

Future<void> _structuredImport(AcceptanceHarness h) async {
  final source = h.saved.generalMode.copyWith(
    schedules: [
      GeneralSchedule(
        id: 'from-file',
        name: 'Imported events',
        events: [
          GeneralEvent(
            id: 'file-event',
            calendarId: 'from-file',
            title: 'From structured data',
            startDateTimeIso: '2026-09-08T15:00:00.000',
            endDateTimeIso: '2026-09-08T16:00:00.000',
          ),
        ],
      ),
    ],
  );
  await h.attach(
    'file',
    'structured_file',
    await inlineDataTransferCodec.encodeSchedules(source, [
      'from-file',
    ], localeCode: 'en'),
  );
  final inspected = await h.call('file_imports.inspect', {
    'sourceId': 'file',
    'format': 'schedules_json',
  });
  expect((inspected['rows'] as List).single['id'], 'from-file');
  await h.commit(
    await h.call('file_imports.prepare', {
      'sourceId': 'file',
      'format': 'schedules_json',
      'action': 'add',
      'ids': ['from-file'],
    }),
  );
  final added = h.saved.generalMode.schedules.last;
  expect(added.name, 'Imported events');
  expect(added.events.single.title, 'From structured data');
  expect(added.events.single.calendarId, added.id);
  expect(h.saved.generalMode.activeScheduleId, 'visible');
}

Future<void> _export(AcceptanceHarness h) async {
  final artifact = await h.call('exports.prepare', {'format': 'backup_json'});
  final plan = await h.call('exports.write', {
    'artifactId': artifact['artifactId'],
  });
  expect(h.writtenArtifacts, isEmpty);
  final result = await h.externalCommit(plan);
  expect(result['effectStatus'], 'applied');
  final backup = decodeAppBackup(h.writtenArtifacts.single.text);
  expect(backup.appData.studentMode.timetables.map((t) => t.id), [
    'current',
    'other',
  ]);
  expect(backup.appData.generalMode.schedules.last.events, hasLength(2));
  expect(backup.appData.agentSettings.endpoint, isEmpty);
  expect(backup.appData.applicationLedger, isNull);
}

Future<void> _restore(AcceptanceHarness h) async {
  final oldGeneration = h.app.agent.mutations.generation;
  final retainedSettings = h.saved.agentSettings;
  final backup = acceptanceData().copyWith(localeCode: 'zh');
  await h.attach(
    'restore',
    'structured_file',
    encodeAppBackup(backup, const []),
  );
  final description = await h.call('backups.describe');
  expect(description['supported'], isTrue);
  final plan = await h.call('backups.prepare_restore', {'sourceId': 'restore'});
  await h.externalCommit(plan);
  // Restoration changes generation, so the old external receipt need not be
  // writable into the new ledger. Assert the actual journal-owned result.
  expect(h.saved.localeCode, 'zh');
  expect(h.saved.agentSettings, retainedSettings);
  expect(h.app.agent.mutations.generation, isNot(oldGeneration));
  expect(h.saved.studentMode.timetables.map((t) => t.id), ['current', 'other']);
  expect(h.app.backups.canStartFreshAfterRecovery, isFalse);
}

Future<void> _appearance(AcceptanceHarness h) async {
  await h.commit(
    await h.call('settings.prepare', {
      'edits': [
        {'key': 'student.themeMode', 'action': 'set', 'value': 'dark'},
        {'key': 'general.themeMode', 'action': 'set', 'value': 'light'},
      ],
    }),
  );
  final plan = await h.call('device.layout.prepare', {
    'region': 'assistant',
    'action': 'set',
    'values': {'width': 480, 'dockedWidth': 420},
  });
  expect((await h.externalCommit(plan))['effectStatus'], 'applied');
  expect(h.saved.studentMode.themeMode, 'dark');
  expect(h.saved.generalMode.themeMode, 'light');
  expect(
    h.layout.preferenceFor(DesktopLayoutRegion.assistant),
    const PreferredRegionSize(width: 480, dockedWidth: 420),
  );
  expect(h.layout.hasUnsavedChanges, isFalse);
}

Future<void> _display(AcceptanceHarness h) async {
  final original = h.saved.generalMode.showWeekends;
  final read = await h.call('settings.get', {
    'keys': ['general.showWeekends'],
  });
  expect((read['values'] as Map)['general.showWeekends'], original);
  await h.commit(
    await h.call('settings.prepare', {
      'edits': [
        {'key': 'general.showWeekends', 'action': 'set', 'value': !original},
        {'key': 'general.customDayMinWidth', 'action': 'set', 'value': 104},
      ],
    }),
  );
  expect(h.saved.generalMode.showWeekends, !original);
  expect(h.saved.generalMode.customDayMinWidth, 104);
  await h.commit(
    await h.call('settings.prepare', {
      'edits': [
        {'key': 'general.customDayMinWidth', 'action': 'reset'},
      ],
    }),
  );
  expect(h.saved.generalMode.customDayMinWidth, isNull);
  expect(h.saved.generalMode.showWeekends, !original);
}

Future<void> _workspaces(AcceptanceHarness h) async {
  final storedCourses = h.saved.studentMode.toJson();
  final plan = await h.call('workspaces.prepare', {
    'workspace': 'student',
    'action': 'disable',
  });
  expect((await h.externalCommit(plan))['effectStatus'], 'applied');
  expect(h.saved.enabledWorkspaces, {AppMode.general});
  expect(h.saved.activeMode, AppMode.general);
  expect(h.saved.studentMode.toJson(), storedCourses);
  final status = await h.call('workspaces.describe');
  expect(status['active'], 'general');
}

Future<void> _notifications(AcceptanceHarness h) async {
  final before = await h.call('notifications.status');
  expect((before['platform'] as Map)['permission'], 'denied');
  final plan = await h.call('notifications.permission.prepare');
  expect(h.gateway.permission, AgendaNotificationPermissionState.denied);
  final result = await h.externalCommit(plan);
  expect(result['effectStatus'], 'applied');
  expect(h.gateway.permission, AgendaNotificationPermissionState.granted);
  final after = await h.call('notifications.status');
  expect((after['platform'] as Map)['permission'], 'granted');
  expect(h.saved.notificationSettings, acceptanceData().notificationSettings);
}

Future<void> _schoolSites(AcceptanceHarness h) async {
  expect(_items(await h.call('school_sites.list')), isEmpty);
  final plan = await h.call('school_sites.prepare', {
    'action': 'create',
    'site': {
      'name': 'Synthetic campus',
      'loginUrl': 'https://campus.invalid/login',
    },
  });
  expect((await h.externalCommit(plan))['effectStatus'], 'applied');
  final row = _items(await h.call('school_sites.list')).single;
  final detail = await h.call('school_sites.get', {'handle': row['handle']});
  expect(detail['name'], 'Synthetic campus');
  expect(detail['loginUrl'], 'https://campus.invalid/login');
  final patched = await h.call('school_sites.prepare', {
    'action': 'patch',
    'handle': row['handle'],
    'site': {'name': 'Renamed campus'},
  });
  expect((await h.externalCommit(patched))['effectStatus'], 'applied');
  expect(
    _items(await h.call('school_sites.list')).single['name'],
    'Renamed campus',
  );
}

Future<void> _connection(AcceptanceHarness h) async {
  const syntheticSecret = 'synthetic-acceptance-key';
  h.app.agent.controlTools.bindCredentialInput((endpoint) async {
    expect(endpoint.toString(), 'https://new-acceptance.invalid/v1');
    return AgentCredentialInput(syntheticSecret);
  });
  final handle = await h.call('credentials.request_input', {
    'endpoint': 'https://new-acceptance.invalid/v1',
  });
  expect(jsonEncode(handle), isNot(contains(syntheticSecret)));
  final plan = await h.call('connection.prepare', {
    'action': 'set',
    'endpoint': 'https://new-acceptance.invalid/v1',
    'model': 'new-fixture',
    'models': [
      const AgentModelConfig(
        id: 'new-fixture',
        reasoningEfforts: [AgentReasoningEffort.medium],
        defaultReasoningEffort: AgentReasoningEffort.medium,
      ).toJson(),
    ],
    'credentialAction': 'replace',
    'credentialHandle': handle['credentialHandle'],
  });
  expect(jsonEncode(plan), isNot(contains(syntheticSecret)));
  await h.externalCommit(plan);
  expect(h.saved.agentSettings.endpoint, 'https://new-acceptance.invalid/v1');
  expect(h.saved.agentSettings.model, 'new-fixture');
  expect(
    await h.app.agent.connections.readKeyFor(h.saved.agentSettings),
    syntheticSecret,
  );
  expect(h.saved.encode(), isNot(contains(syntheticSecret)));
  expect(h.conversations.source, isNot(contains(syntheticSecret)));
}

Future<void> _undo(AcceptanceHarness h) async {
  final original = h.saved.studentMode.timetables.last.courses.single.toJson();
  final plan = await h.call('mutation.prepare', {
    'commands': [
      _patch('course', 'other-algebra', {
        'location': 'Temporary lab',
      }, parent: 'other'),
    ],
  });
  await h.commit(plan);
  expect(
    h.saved.studentMode.timetables.last.courses.single.location,
    'Temporary lab',
  );
  final inverse = await h.call('undo.prepare', {
    'operationId': plan['operationId'],
  });
  await h.commit(inverse);
  expect(h.saved.studentMode.timetables.last.courses.single.toJson(), original);
  final replay = await h.call('undo.prepare', {
    'operationId': plan['operationId'],
  });
  expect((await h.commit(replay))['replayed'], isTrue);
  expect(h.saved.studentMode.timetables.last.courses.single.toJson(), original);
}
