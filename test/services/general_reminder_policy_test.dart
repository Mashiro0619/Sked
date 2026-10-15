import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/services/agenda_action_router.dart';
import 'package:sked/services/agenda_notification_runtime_store.dart';
import 'package:sked/services/agenda_notification_service.dart';
import 'package:sked/services/agenda_projection_service.dart';
import 'package:sked/services/general_calendar_ics_service.dart';
import 'package:sked/services/general_occurrence_cache.dart';
import 'package:sked/services/general_occurrence_service.dart';
import 'package:sked/services/import_export_service.dart';
import 'package:sked/services/notification_occurrence_resolver.dart';

GeneralEvent _event({
  String id = 'event',
  GeneralEventReminderBehavior? behavior,
  List<GeneralEventReminder> reminders = const [],
  GeneralEventRecurrenceRule rule = const GeneralEventRecurrenceRule(),
}) => GeneralEvent(
  id: id,
  calendarId: 'calendar',
  title: 'Appointment',
  startDateTimeIso: '2026-08-03T10:00:00.000',
  endDateTimeIso: '2026-08-03T11:00:00.000',
  reminderBehavior: behavior,
  reminders: reminders,
  recurrenceRule: rule,
);

AppData _data({
  List<GeneralEvent>? events,
  bool visible = true,
  NotificationSettings settings = const NotificationSettings(
    enabled: true,
    generalDefaultMinutesBefore: 15,
  ),
}) {
  final base = buildInitialAppData(buildDefaultPeriodTimes());
  return base.copyWith(
    activeMode: AppMode.general,
    notificationSettings: settings,
    generalMode: base.generalMode.copyWith(
      activeScheduleId: 'calendar',
      schedules: [
        GeneralSchedule(
          id: 'calendar',
          name: 'Personal',
          isVisible: visible,
          events:
              events ??
              [_event(behavior: GeneralEventReminderBehavior.inherit)],
        ),
      ],
    ),
  );
}

List<int> _minutes(GeneralEvent event, int? minutes) =>
    event.resolveReminders(minutes).map((item) => item.minutesBefore).toList();

class _MemoryStorage implements TimetableStorage {
  _MemoryStorage(this.data);
  AppData data;
  @override
  Future<String?> filePath() async => 'memory://general-reminder-policy';
  @override
  Future<StorageLoadResult> load() async =>
      StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);
  @override
  Future<void> save(AppData value) async => data = value;
}

void main() {
  test('legacy reminders remain explicit and inherited defaults stay live', () {
    final oldCustom = _event(
      reminders: const [
        GeneralEventReminder(minutesBefore: 5),
        GeneralEventReminder(minutesBefore: 60),
      ],
    ).toJson()..remove('reminderBehavior');
    final custom = GeneralEvent.fromJson(oldCustom);
    expect(custom.reminderBehavior, GeneralEventReminderBehavior.custom);
    expect(_minutes(custom, 30), [5, 60]);

    final oldOff = _event().toJson()..remove('reminderBehavior');
    final disabled = GeneralEvent.fromJson(oldOff);
    expect(disabled.reminderBehavior, GeneralEventReminderBehavior.disabled);
    expect(_minutes(disabled, 30), isEmpty);

    final inherited = _event(behavior: GeneralEventReminderBehavior.inherit);
    expect(_minutes(inherited, null), isEmpty);
    expect(_minutes(inherited, 0), [0]);
    expect(_minutes(inherited, 30), [30]);
    expect(inherited.reminders, isEmpty);
    expect(inherited.hasReminderConfiguration, isTrue);
    expect(
      inherited.copyWith(title: 'Renamed').reminderBehavior,
      GeneralEventReminderBehavior.inherit,
    );
    expect(
      disabled.copyWith(reminders: custom.reminders).reminderBehavior,
      GeneralEventReminderBehavior.custom,
    );
  });

  test(
    'empty custom reminders normalize to off without changing inheritance',
    () {
      final custom = _event(behavior: GeneralEventReminderBehavior.custom)
          .normalized(fallbackCalendarId: 'calendar');
      expect(custom.reminderBehavior, GeneralEventReminderBehavior.disabled);
      final inherited = _event(
        behavior: GeneralEventReminderBehavior.inherit,
        reminders: const [GeneralEventReminder(minutesBefore: 5)],
      ).normalized(fallbackCalendarId: 'calendar');
      expect(inherited.reminders, isEmpty);
      expect(inherited.reminderBehavior, GeneralEventReminderBehavior.inherit);
    },
  );

  test('schema six preserves policies, month anchors and handled records', () {
    final event = _event(
      behavior: GeneralEventReminderBehavior.inherit,
      rule: const GeneralEventRecurrenceRule(
        type: GeneralEventRecurrence.monthly,
        unit: GeneralEventRecurrenceUnit.month,
        monthlyAnchorDay: 31,
      ),
    );
    final base = _data(events: [event]);
    final data = base.copyWith(
      notificationSettings: base.notificationSettings.copyWith(
        generalDefaultMinutesBefore: null,
        remindHiddenGeneralCalendars: true,
      ),
      generalMode: base.generalMode.copyWith(
        reminderAcknowledgements: [
          GeneralReminderAcknowledgement(
            occurrenceKey: buildGeneralOccurrenceKey(
              'calendar',
              'event',
              event.startDateTimeIso,
            ),
            updatedAtIso: event.startDateTimeIso,
          ),
        ],
      ),
    );
    final decoded = decodeAppBackup(encodeAppBackup(data, const [])).appData;
    expect(decoded.generalMode.toJson()['schemaVersion'], 6);
    expect(decoded.notificationSettings.remindHiddenGeneralCalendars, isTrue);
    expect(
      decoded.generalMode.schedules.single.events.single.reminderBehavior,
      GeneralEventReminderBehavior.inherit,
    );
    expect(
      decoded
          .generalMode
          .schedules
          .single
          .events
          .single
          .recurrenceRule
          .monthlyAnchorDay,
      31,
    );
    expect(decoded.generalMode.reminderAcknowledgements, hasLength(1));
    final normalized = const ImportExportService().normalizeAppData(
      decoded,
      localeCode: 'en',
    );
    expect(normalized.generalMode.reminderAcknowledgements, hasLength(1));

    final legacy = _data(events: [_event()]).toJson();
    final general = legacy['generalMode'] as Map<String, dynamic>;
    general['schemaVersion'] = 5;
    final calendar = (general['schedules'] as List).single as Map;
    ((calendar['events'] as List).single as Map).remove('reminderBehavior');
    final restored = AppData.decodeStorageSnapshot(jsonEncode(legacy));
    expect(
      restored.generalMode.schedules.single.events.single.reminderBehavior,
      GeneralEventReminderBehavior.disabled,
    );
  });

  test('new policy and month anchor values are strictly validated', () {
    for (final invalid in [null, 42, 'default']) {
      final eventJson = _event().toJson()..['reminderBehavior'] = invalid;
      expect(() => GeneralEvent.fromJson(eventJson), throwsFormatException);
    }
    for (final invalid in [0, 32, 1.5, '31']) {
      final snapshot = _data().toJson();
      final general = snapshot['generalMode'] as Map;
      final calendar = (general['schedules'] as List).single as Map;
      final event = (calendar['events'] as List).single as Map;
      (event['recurrenceRule'] as Map)['monthlyAnchorDay'] = invalid;
      expect(
        () => AppData.decodeStorageSnapshot(jsonEncode(snapshot)),
        throwsFormatException,
      );
    }
    final snapshot = _data().toJson();
    (snapshot['notificationSettings'] as Map)['remindHiddenGeneralCalendars'] =
        1;
    expect(
      () => AppData.decodeStorageSnapshot(jsonEncode(snapshot)),
      throwsFormatException,
    );
    final rule = GeneralEventRecurrenceRule.fromJson({
      'type': 'monthly',
      'unit': 'month',
      'monthlyAnchorDay': 31,
    });
    expect(rule.copyWith(monthlyAnchorDay: null).monthlyAnchorDay, isNull);
    expect(
      _event(rule: rule.copyWith(type: GeneralEventRecurrence.weekly))
          .normalized(fallbackCalendarId: 'calendar')
          .recurrenceRule
          .monthlyAnchorDay,
      isNull,
    );
  });

  test(
    'cache resolves changed defaults and visibility after occurrence lookup',
    () {
      final data = _data(visible: false);
      final cache = GeneralOccurrenceCache();
      final now = DateTime(2026, 8, 3, 9, 50);
      const service = GeneralOccurrenceService();
      const settings = NotificationSettings(
        generalDefaultMinutesBefore: 15,
        remindHiddenGeneralCalendars: true,
      );
      expect(cache.reminderItems(data.generalMode, now: now), isEmpty);
      expect(
        cache.reminderItems(
          data.generalMode,
          now: now,
          notificationSettings: settings,
        ),
        hasLength(1),
      );
      expect(
        service.reminderItems(
          data.generalMode,
          now: now,
          notificationSettings: settings,
        ),
        hasLength(1),
      );
      expect(
        cache.reminderItems(
          data.generalMode,
          now: now,
          notificationSettings: settings.copyWith(
            generalDefaultMinutesBefore: 5,
          ),
        ),
        isEmpty,
      );
      expect(
        cache.reminderItems(
          data.generalMode,
          now: now,
          notificationSettings: settings.copyWith(
            generalDefaultMinutesBefore: null,
          ),
        ),
        isEmpty,
      );
      expect(
        cache.reminderItems(
          data.generalMode,
          now: now,
          notificationSettings: settings,
        ),
        hasLength(1),
      );
      expect(
        service.occurrencesForRange(
          data.generalMode,
          startInclusive: now,
          endExclusive: now.add(const Duration(hours: 2)),
        ),
        isEmpty,
      );
    },
  );

  test(
    'projection resolves each event policy without flattening saved data',
    () {
      final data = _data(
        events: [
          _event(id: 'inherit', behavior: GeneralEventReminderBehavior.inherit),
          _event(id: 'off'),
          _event(
            id: 'custom',
            reminders: const [
              GeneralEventReminder(minutesBefore: 5),
              GeneralEventReminder(minutesBefore: 60),
            ],
          ),
        ],
      );
      final projected = const AgendaProjectionService().project(
        data,
        startInclusive: DateTime(2026, 8, 3),
        endExclusive: DateTime(2026, 8, 4),
      );
      final minutes = {
        for (final item in projected)
          item.target.eventId: item.reminders
              .map((r) => r.minutesBefore)
              .toList(),
      };
      expect(minutes['inherit'], [15]);
      expect(minutes['off'], isEmpty);
      expect(minutes['custom'], [5, 60]);
      expect(data.generalMode.schedules.single.events.first.reminders, isEmpty);
    },
  );

  test(
    'JSON deduplication distinguishes inheritance from explicit silence',
    () {
      const service = ImportExportService();
      final original = _data(events: [_event()]).generalMode;
      final incoming = _data(
        events: [_event(behavior: GeneralEventReminderBehavior.inherit)],
      ).generalMode;
      final source = service.exportSelectedGeneralSchedulesJson(incoming, [
        'calendar',
      ], localeCode: 'en');
      final imported = service.importSelectedGeneralSchedulesJson(
        original,
        source,
        scheduleIds: ['calendar'],
        mode: GeneralScheduleImportMode.addAsNew,
        localeCode: 'en',
      );
      expect(imported.result.importedCount, 1);
      expect(
        imported.data.schedules.last.events.single.reminderBehavior,
        GeneralEventReminderBehavior.inherit,
      );
      final repeated = service.importSelectedGeneralSchedulesJson(
        imported.data,
        source,
        scheduleIds: ['calendar'],
        mode: GeneralScheduleImportMode.addAsNew,
        localeCode: 'en',
      );
      expect(repeated.result.importedCount, 0);
    },
  );

  test(
    'ICS imports retain explicit silence instead of inheriting defaults',
    () {
      final imported = const GeneralCalendarIcsService().importSchedules('''
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:external
DTSTART:20260803T100000Z
DTEND:20260803T110000Z
SUMMARY:External appointment
END:VEVENT
END:VCALENDAR
''');
      final event = imported.schedules.single.events.single;
      expect(event.reminderBehavior, GeneralEventReminderBehavior.disabled);
      expect(event.resolveReminders(30), isEmpty);
    },
  );

  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    for (final repeating in [false, true]) {
      test(
        'hidden inherited reminders reconcile on $platform repeating=$repeating',
        () async {
          final previous = debugDefaultTargetPlatformOverride;
          debugDefaultTargetPlatformOverride = platform;
          final gateway = MemoryAgendaNotificationGateway();
          final now = DateTime(2026, 8, 3, 9);
          final service = AgendaNotificationService(
            enabled: true,
            gateway: gateway,
            runtimeStore: MemoryAgendaNotificationRuntimeStore(),
            now: () => now,
          );
          try {
            final data = _data(
              visible: false,
              events: [
                _event(
                  behavior: GeneralEventReminderBehavior.inherit,
                  rule: GeneralEventRecurrenceRule(
                    type: repeating
                        ? GeneralEventRecurrence.daily
                        : GeneralEventRecurrence.none,
                    unit: GeneralEventRecurrenceUnit.day,
                  ),
                ),
              ],
            );
            await service.reconcile(data, anchor: now);
            expect(gateway.scheduled, isEmpty);
            final enabled = data.copyWith(
              notificationSettings: data.notificationSettings.copyWith(
                remindHiddenGeneralCalendars: true,
              ),
            );
            await service.reconcile(enabled, anchor: now);
            expect(gateway.scheduled, isNotEmpty);
            expect(
              gateway.scheduled.values.every(
                (request) =>
                    request.occurrence.reminders.single.minutesBefore == 15,
              ),
              isTrue,
            );
            final changed = enabled.copyWith(
              notificationSettings: enabled.notificationSettings.copyWith(
                generalDefaultMinutesBefore: 30,
              ),
            );
            await service.reconcile(changed, anchor: now);
            expect(
              gateway.scheduled.values.every(
                (request) =>
                    request.occurrence.reminders.single.minutesBefore == 30,
              ),
              isTrue,
            );
            await service.reconcile(data, anchor: now);
            expect(gateway.scheduled, isEmpty);
          } finally {
            service.dispose();
            debugDefaultTargetPlatformOverride = previous;
          }
        },
      );
    }
  }

  test(
    'hidden notification routing follows the preference without unhiding',
    () async {
      final data = _data(
        visible: false,
        settings: const NotificationSettings(
          enabled: true,
          generalDefaultMinutesBefore: 15,
          remindHiddenGeneralCalendars: true,
        ),
      );
      final provider = TimetableProvider(
        storage: _MemoryStorage(data),
        systemLocaleCodeResolver: () => 'en',
        uiStateSaveDelay: Duration.zero,
      );
      await provider.lifecycle.load();
      addTearDown(provider.dispose);
      final gateway = MemoryAgendaNotificationGateway();
      final service = AgendaNotificationService(
        enabled: true,
        gateway: gateway,
        runtimeStore: MemoryAgendaNotificationRuntimeStore(),
      );
      addTearDown(service.dispose);
      await service.reconcile(
        provider.workspaceView.data,
        anchor: DateTime(2026, 8, 3, 9),
      );
      final request = gateway.scheduled.values.first;
      final payload = AgendaNotificationPayload.tryDecode(request.payload)!;
      final router = AgendaActionRouter(
        workspace: provider.workspaceView,
        workspaces: provider.workspaces,
        student: provider.studentView,
        studentCommands: provider.studentCommands,
        general: provider.generalView,
        generalNavigation: provider.generalNavigation,
        settings: provider.settingsView,
        duplicateWindow: Duration.zero,
      );
      expect(
        agendaNotificationPayloadMatchesProjection(
          payload: payload,
          data: provider.workspaceView.data,
          projection: const AgendaProjectionService(),
        ),
        isTrue,
      );
      expect(await router.routePayload(request.payload), isTrue);
      expect(provider.generalView.schedules.single.isVisible, isFalse);
      expect(
        resolveNotificationOccurrence(
          provider.generalView,
          payload.target,
          includeHiddenCalendars:
              provider.settingsView.remindHiddenGeneralCalendars,
        ),
        isNotNull,
      );
      await provider.settingsCommands.updateRemindHiddenGeneralCalendars(false);
      expect(
        resolveNotificationOccurrence(
          provider.generalView,
          payload.target,
          includeHiddenCalendars:
              provider.settingsView.remindHiddenGeneralCalendars,
        ),
        isNull,
      );
      expect(
        agendaNotificationPayloadMatchesProjection(
          payload: payload,
          data: provider.workspaceView.data,
          projection: const AgendaProjectionService(),
        ),
        isFalse,
      );
      expect(await router.route(AgendaAction(target: payload.target)), isFalse);
    },
  );
}
