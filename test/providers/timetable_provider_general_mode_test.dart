import 'package:flutter_test/flutter_test.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/l10n/app_locale.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/services/general_calendar_ics_service.dart';

class _MemoryTimetableStorage implements TimetableStorage {
  _MemoryTimetableStorage(this.data);

  AppData? data;
  int saveCount = 0;
  Object? nextSaveError;

  @override
  Future<StorageLoadResult> load() async =>
      StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);

  @override
  Future<void> save(AppData data) async {
    saveCount += 1;
    final error = nextSaveError;
    nextSaveError = null;
    if (error != null) throw error;
    this.data = data;
  }

  @override
  Future<String?> filePath() async => 'memory://provider-general-test';
}

void main() {
  test(
    'toolbar navigation settings persist independently with one save each',
    () async {
      final storage = _MemoryTimetableStorage(
        buildInitialAppData(buildDefaultPeriodTimes()),
      );
      final provider = TimetableProvider(
        storage: storage,
        systemLocaleCodeResolver: () => defaultLocaleCode,
      );
      addTearDown(provider.dispose);
      await provider.load();

      await provider.updateGeneralToolbarNavigationOrder([
        'view',
        'settings',
        'category',
        'date',
        'more',
      ]);
      expect(storage.saveCount, 1);
      expect(provider.generalToolbarNavigationOrder, [
        'view',
        'settings',
        'category',
        'date',
        'more',
      ]);

      await provider.updateGeneralToolbarNavigationVisibility(
        'category',
        false,
      );
      expect(storage.saveCount, 2);
      expect(provider.generalHiddenToolbarNavigationIds, ['category']);

      await provider.updateGeneralToolbarHiddenItemsBehavior('more');
      expect(storage.saveCount, 3);
      expect(provider.generalToolbarHiddenItemsBehavior, 'more');
      expect(storage.data!.generalMode.toolbarNavigationOrder, [
        'view',
        'settings',
        'category',
        'date',
        'more',
      ]);
      expect(storage.data!.generalMode.hiddenToolbarNavigationIds, [
        'category',
      ]);
    },
  );

  test('saved general events survive strict storage decoding', () async {
    final storage = _MemoryTimetableStorage(
      buildInitialAppData(buildDefaultPeriodTimes()),
    );
    final provider = TimetableProvider(
      storage: storage,
      systemLocaleCodeResolver: () => defaultLocaleCode,
    );

    await provider.load();
    await provider.saveGeneralEvent(
      GeneralEvent(
        id: 'strict_round_trip',
        calendarId: provider.activeGeneralSchedule.id,
        title: 'Strict round trip',
        startDateTimeIso: '2026-05-25T09:00:00.000',
        endDateTimeIso: '2026-05-25T10:00:00.000',
        recurrenceRule: const GeneralEventRecurrenceRule(
          type: GeneralEventRecurrence.daily,
          interval: 1200,
          unit: GeneralEventRecurrenceUnit.month,
          untilDateIso: '2026-05-01',
          count: 0,
        ),
        recurrenceExceptionDateIso: const ['invalid', '2026-05-26'],
        createdAtIso: 'invalid',
      ),
    );

    expect(
      () => AppData.decodeStorageSnapshot(storage.data!.encode()),
      returnsNormally,
    );
  });

  test('new events remember their category while edits preserve it', () async {
    final storage = _MemoryTimetableStorage(
      buildInitialAppData(buildDefaultPeriodTimes()).copyWith(
        generalMode: const GeneralScheduleData(
          activeScheduleId: 'work',
          schedules: [
            GeneralSchedule(id: 'work', name: 'Work', events: []),
            GeneralSchedule(id: 'home', name: 'Home', events: []),
          ],
        ),
      ),
    );
    final provider = TimetableProvider(
      storage: storage,
      systemLocaleCodeResolver: () => defaultLocaleCode,
    );
    addTearDown(provider.dispose);
    await provider.load();

    final created = GeneralEvent(
      id: 'new_event',
      calendarId: 'home',
      title: 'Created',
      startDateTimeIso: '2026-05-25T09:00:00.000',
      endDateTimeIso: '2026-05-25T10:00:00.000',
    );
    await provider.saveGeneralEvent(created);

    expect(provider.activeGeneralSchedule.id, 'home');
    expect(storage.data!.generalMode.activeScheduleId, 'home');

    await provider.switchGeneralSchedule('work');
    await provider.saveGeneralEvent(created.copyWith(title: 'Edited'));

    expect(provider.activeGeneralSchedule.id, 'work');
    expect(storage.data!.generalMode.activeScheduleId, 'work');
    expect(
      provider.generalSchedules
          .singleWhere((item) => item.id == 'home')
          .events
          .single
          .title,
      'Edited',
    );
  });

  test(
    'category visibility and deletion persist remembered fallbacks',
    () async {
      final storage = _MemoryTimetableStorage(
        buildInitialAppData(buildDefaultPeriodTimes()).copyWith(
          generalMode: const GeneralScheduleData(
            activeScheduleId: 'remembered',
            schedules: [
              GeneralSchedule(
                id: 'hidden',
                name: 'Hidden',
                isVisible: false,
                events: [],
              ),
              GeneralSchedule(id: 'remembered', name: 'Remembered', events: []),
              GeneralSchedule(id: 'visible', name: 'Visible', events: []),
            ],
          ),
        ),
      );
      final provider = TimetableProvider(
        storage: storage,
        systemLocaleCodeResolver: () => defaultLocaleCode,
      );
      addTearDown(provider.dispose);
      await provider.load();

      await provider.updateGeneralScheduleVisibility('remembered', false);

      expect(provider.activeGeneralSchedule.id, 'visible');
      expect(storage.data!.generalMode.activeScheduleId, 'visible');

      await provider.deleteGeneralSchedule('visible');

      expect(provider.visibleGeneralSchedules, isEmpty);
      expect(provider.activeGeneralSchedule.id, 'hidden');
      expect(storage.data!.generalMode.activeScheduleId, 'hidden');
    },
  );

  test(
    'failed new-event save rolls back event and remembered category',
    () async {
      final initial = buildInitialAppData(buildDefaultPeriodTimes()).copyWith(
        generalMode: const GeneralScheduleData(
          activeScheduleId: 'work',
          schedules: [
            GeneralSchedule(id: 'work', name: 'Work', events: []),
            GeneralSchedule(id: 'home', name: 'Home', events: []),
          ],
        ),
      );
      final storage = _MemoryTimetableStorage(initial);
      final provider = TimetableProvider(
        storage: storage,
        systemLocaleCodeResolver: () => defaultLocaleCode,
      );
      addTearDown(provider.dispose);
      await provider.load();
      storage.nextSaveError = StateError('save failed');

      await expectLater(
        provider.saveGeneralEvent(
          GeneralEvent(
            id: 'unsaved',
            calendarId: 'home',
            title: 'Unsaved',
            startDateTimeIso: '2026-05-25T09:00:00.000',
            endDateTimeIso: '2026-05-25T10:00:00.000',
          ),
        ),
        throwsStateError,
      );

      expect(provider.activeGeneralSchedule.id, 'work');
      expect(provider.generalSchedules.expand((item) => item.events), isEmpty);
      expect(storage.data!.generalMode.activeScheduleId, 'work');
      expect(
        storage.data!.generalMode.schedules.expand((item) => item.events),
        isEmpty,
      );
    },
  );

  test(
    'selected general date notifies immediately and defers persistence',
    () async {
      final storage = _MemoryTimetableStorage(
        buildInitialAppData(buildDefaultPeriodTimes()),
      );
      final provider = TimetableProvider(
        storage: storage,
        systemLocaleCodeResolver: () => defaultLocaleCode,
      );

      await provider.load();
      storage.saveCount = 0;
      var notifications = 0;
      provider.addListener(() => notifications += 1);

      await provider.setSelectedGeneralDate(DateTime(2026, 6, 1, 14));

      expect(provider.selectedGeneralDate, DateTime(2026, 6));
      expect(notifications, 1);
      expect(storage.saveCount, 0);

      await provider.flushPendingUiStateSaves();

      expect(storage.saveCount, 1);
      expect(storage.data!.generalMode.selectedDateIso, '2026-06-01');
    },
  );

  test(
    'rapid selected general date changes persist only the last date',
    () async {
      final storage = _MemoryTimetableStorage(
        buildInitialAppData(buildDefaultPeriodTimes()),
      );
      final provider = TimetableProvider(
        storage: storage,
        systemLocaleCodeResolver: () => defaultLocaleCode,
      );

      await provider.load();
      storage.saveCount = 0;

      await provider.setSelectedGeneralDate(DateTime(2026, 6, 1));
      await provider.setSelectedGeneralDate(DateTime(2026, 6, 2));
      await provider.setSelectedGeneralDate(DateTime(2026, 6, 3));

      expect(storage.saveCount, 0);

      await provider.flushPendingUiStateSaves();

      expect(storage.saveCount, 1);
      expect(provider.selectedGeneralDate, DateTime(2026, 6, 3));
      expect(storage.data!.generalMode.selectedDateIso, '2026-06-03');
    },
  );

  test('filters occurrences by visible calendars by default', () async {
    final visibleCalendar = GeneralSchedule(
      id: 'visible',
      name: 'Visible',
      events: [
        GeneralEvent(
          id: 'evt_visible',
          calendarId: 'visible',
          title: 'Visible event',
          startDateTimeIso: '2026-05-25T09:00:00.000',
          endDateTimeIso: '2026-05-25T10:00:00.000',
        ),
      ],
    );
    final hiddenCalendar = GeneralSchedule(
      id: 'hidden',
      name: 'Hidden',
      isVisible: false,
      events: [
        GeneralEvent(
          id: 'evt_hidden',
          calendarId: 'hidden',
          title: 'Hidden event',
          startDateTimeIso: '2026-05-25T11:00:00.000',
          endDateTimeIso: '2026-05-25T12:00:00.000',
        ),
      ],
    );
    final provider = TimetableProvider(
      storage: _MemoryTimetableStorage(
        buildInitialAppData(buildDefaultPeriodTimes()).copyWith(
          generalMode: GeneralScheduleData(
            activeScheduleId: 'visible',
            schedules: [visibleCalendar, hiddenCalendar],
            selectedDateIso: '2026-05-25',
          ),
        ),
      ),
      systemLocaleCodeResolver: () => defaultLocaleCode,
    );

    await provider.load();
    final visibleOnly = provider.generalOccurrencesForRange(
      startInclusive: DateTime(2026, 5, 25),
      endExclusive: DateTime(2026, 5, 26),
    );
    final allCalendars = provider.generalOccurrencesForRange(
      startInclusive: DateTime(2026, 5, 25),
      endExclusive: DateTime(2026, 5, 26),
      onlyVisibleCalendars: false,
    );

    expect(visibleOnly.map((item) => item.event.id), ['evt_visible']);
    expect(allCalendars.map((item) => item.event.id), [
      'evt_visible',
      'evt_hidden',
    ]);
  });

  test('deleting the last calendar creates a default calendar', () async {
    final provider = TimetableProvider(
      storage: _MemoryTimetableStorage(
        buildInitialAppData(buildDefaultPeriodTimes()),
      ),
      systemLocaleCodeResolver: () => defaultLocaleCode,
    );

    await provider.load();
    final onlyCalendarId = provider.activeGeneralSchedule.id;
    await provider.deleteGeneralSchedule(onlyCalendarId);

    expect(provider.generalSchedules, hasLength(1));
    expect(
      provider.activeGeneralSchedule.id,
      provider.generalSchedules.single.id,
    );
    expect(provider.activeGeneralSchedule.events, isEmpty);
  });

  test('duplicates the selected occurrence as a one-time event', () async {
    final initial = buildInitialAppData(buildDefaultPeriodTimes());
    final provider = TimetableProvider(
      storage: _MemoryTimetableStorage(initial),
      systemLocaleCodeResolver: () => defaultLocaleCode,
    );

    await provider.load();
    final calendarId = provider.activeGeneralSchedule.id;
    await provider.saveGeneralEvent(
      GeneralEvent(
        id: 'repeat1',
        calendarId: calendarId,
        title: 'Standup',
        startDateTimeIso: '2026-05-18T09:00:00.000',
        endDateTimeIso: '2026-05-18T09:30:00.000',
        recurrenceRule: const GeneralEventRecurrenceRule(
          type: GeneralEventRecurrence.weekly,
          unit: GeneralEventRecurrenceUnit.week,
          count: 4,
        ),
        recurrenceExceptionDateIso: const ['2026-06-01'],
        location: 'Room A',
        notes: 'Bring notes',
        colorValue: 0xFF123456,
        reminders: const [GeneralEventReminder(minutesBefore: 10)],
      ),
    );

    final occurrence = provider
        .generalOccurrencesForRange(
          startInclusive: DateTime(2026, 5, 25),
          endExclusive: DateTime(2026, 5, 26),
        )
        .single;

    final duplicated = await provider.duplicateGeneralOccurrence(occurrence);

    expect(duplicated.id, isNot('repeat1'));
    expect(duplicated.title, 'Standup');
    expect(duplicated.startDateTimeIso, startsWith('2026-05-25T09:00:00'));
    expect(duplicated.endDateTimeIso, startsWith('2026-05-25T09:30:00'));
    expect(duplicated.recurrenceRule.isRepeating, false);
    expect(duplicated.recurrenceExceptionDateIso, isEmpty);
    expect(duplicated.location, 'Room A');
    expect(duplicated.notes, 'Bring notes');
    expect(duplicated.colorValue, 0xFF123456);
    expect(duplicated.reminders.single.minutesBefore, 10);
    expect(duplicated.calendarId, calendarId);

    final sameDay = provider.generalOccurrencesForRange(
      startInclusive: DateTime(2026, 5, 25),
      endExclusive: DateTime(2026, 5, 26),
    );
    expect(sameDay.map((item) => item.event.id), contains(duplicated.id));
    expect(sameDay.map((item) => item.event.id), contains('repeat1'));
  });

  test('dismisses and restores general reminder occurrences', () async {
    final initial = buildInitialAppData(buildDefaultPeriodTimes());
    final provider = TimetableProvider(
      storage: _MemoryTimetableStorage(initial),
      systemLocaleCodeResolver: () => defaultLocaleCode,
    );

    await provider.load();
    final calendarId = provider.activeGeneralSchedule.id;
    await provider.saveGeneralEvent(
      GeneralEvent(
        id: 'reminder1',
        calendarId: calendarId,
        title: 'Reminder event',
        startDateTimeIso: '2026-05-25T10:00:00.000',
        endDateTimeIso: '2026-05-25T11:00:00.000',
        reminders: const [GeneralEventReminder(minutesBefore: 10)],
      ),
    );

    final now = DateTime(2026, 5, 25, 9, 55);
    final initialItems = provider.generalReminderItems(now: now);

    expect(initialItems, hasLength(1));
    expect(initialItems.single.status, GeneralReminderStatus.upcoming);

    await provider.dismissGeneralReminder(initialItems.single.occurrence);

    expect(
      provider.isGeneralReminderHandled(initialItems.single.occurrence),
      true,
    );
    expect(provider.generalReminderItems(now: now), isEmpty);

    await provider.restoreGeneralReminder(initialItems.single.occurrence);

    expect(
      provider.isGeneralReminderHandled(initialItems.single.occurrence),
      false,
    );
    expect(provider.generalReminderItems(now: now), hasLength(1));
  });

  test(
    'general reminder items exclude events without configured reminders',
    () async {
      final initial = buildInitialAppData(buildDefaultPeriodTimes());
      final provider = TimetableProvider(
        storage: _MemoryTimetableStorage(initial),
        systemLocaleCodeResolver: () => defaultLocaleCode,
      );

      await provider.load();
      final calendarId = provider.activeGeneralSchedule.id;
      await provider.saveGeneralEvent(
        GeneralEvent(
          id: 'overdue1',
          calendarId: calendarId,
          title: 'Overdue event',
          startDateTimeIso: '2026-05-25T08:00:00.000',
          endDateTimeIso: '2026-05-25T09:00:00.000',
        ),
      );

      final now = DateTime(2026, 5, 25, 10);
      final items = provider.generalReminderItems(now: now);

      expect(items, isEmpty);
    },
  );

  test('deleting a calendar removes its handled reminder records', () async {
    final schedule = GeneralSchedule(
      id: 'cal1',
      name: 'Work',
      events: [
        GeneralEvent(
          id: 'event1',
          calendarId: 'cal1',
          title: 'Reminder event',
          startDateTimeIso: '2026-05-25T09:00:00.000',
          endDateTimeIso: '2026-05-25T10:00:00.000',
        ),
      ],
    );
    final storage = _MemoryTimetableStorage(
      buildInitialAppData(buildDefaultPeriodTimes()).copyWith(
        generalMode: GeneralScheduleData(
          activeScheduleId: 'cal1',
          schedules: [schedule],
          reminderAcknowledgements: const [
            GeneralReminderAcknowledgement(
              occurrenceKey: 'cal1|event1|2026-05-25T09:00:00.000',
              updatedAtIso: '2026-05-25T08:55:00.000',
            ),
          ],
        ),
      ),
    );
    final provider = TimetableProvider(
      storage: storage,
      systemLocaleCodeResolver: () => defaultLocaleCode,
    );

    await provider.load();
    await provider.deleteGeneralSchedule('cal1');

    expect(storage.data!.generalMode.reminderAcknowledgements, isEmpty);
    expect(provider.generalSchedules, hasLength(1));
  });

  test(
    'replacing active calendar clears old handled reminder records',
    () async {
      final active = GeneralSchedule(
        id: 'active',
        name: 'Active',
        events: [
          GeneralEvent(
            id: 'event1',
            calendarId: 'active',
            title: 'Old event',
            startDateTimeIso: '2026-05-25T09:00:00.000',
            endDateTimeIso: '2026-05-25T10:00:00.000',
            reminders: const [GeneralEventReminder(minutesBefore: 10)],
          ),
        ],
      );
      final storage = _MemoryTimetableStorage(
        buildInitialAppData(buildDefaultPeriodTimes()).copyWith(
          generalMode: GeneralScheduleData(
            activeScheduleId: 'active',
            schedules: [active],
            reminderAcknowledgements: const [
              GeneralReminderAcknowledgement(
                occurrenceKey: 'active|event1|2026-05-25T09:00:00.000',
                updatedAtIso: '2026-05-25T08:55:00.000',
              ),
            ],
          ),
        ),
      );
      final provider = TimetableProvider(
        storage: storage,
        systemLocaleCodeResolver: () => defaultLocaleCode,
      );
      final source = encodeGeneralScheduleDataEnvelope(
        GeneralScheduleExportData(
          schedules: [
            GeneralSchedule(
              id: 'replacement',
              name: 'Replacement',
              events: [
                GeneralEvent(
                  id: 'event1',
                  calendarId: 'replacement',
                  title: 'Replacement event',
                  startDateTimeIso: '2026-05-25T09:00:00.000',
                  endDateTimeIso: '2026-05-25T10:00:00.000',
                  reminders: const [GeneralEventReminder(minutesBefore: 10)],
                ),
              ],
            ),
          ],
        ),
      );

      await provider.load();
      await provider.importSelectedGeneralSchedulesJson(
        source,
        scheduleIds: const ['replacement'],
        mode: GeneralScheduleImportMode.replaceActive,
        replacementScheduleId: 'active',
      );

      final items = provider.generalReminderItems(
        now: DateTime(2026, 5, 25, 8, 55),
      );
      expect(storage.data!.generalMode.reminderAcknowledgements, isEmpty);
      expect(items, hasLength(1));
      expect(items.single.occurrence.event.title, 'Replacement event');
    },
  );

  test(
    'deleting future recurrence clears future handled reminder records',
    () async {
      final schedule = GeneralSchedule(
        id: 'cal1',
        name: 'Work',
        events: [
          GeneralEvent(
            id: 'repeat1',
            calendarId: 'cal1',
            title: 'Weekly',
            startDateTimeIso: '2026-05-18T09:00:00.000',
            endDateTimeIso: '2026-05-18T10:00:00.000',
            recurrenceRule: const GeneralEventRecurrenceRule(
              type: GeneralEventRecurrence.weekly,
              unit: GeneralEventRecurrenceUnit.week,
              count: 4,
            ),
            reminders: const [GeneralEventReminder(minutesBefore: 10)],
          ),
        ],
      );
      final storage = _MemoryTimetableStorage(
        buildInitialAppData(buildDefaultPeriodTimes()).copyWith(
          generalMode: GeneralScheduleData(
            activeScheduleId: 'cal1',
            schedules: [schedule],
            reminderAcknowledgements: const [
              GeneralReminderAcknowledgement(
                occurrenceKey: 'cal1|repeat1|2026-05-18T09:00:00.000',
                updatedAtIso: '2026-05-18T08:55:00.000',
              ),
              GeneralReminderAcknowledgement(
                occurrenceKey: 'cal1|repeat1|2026-05-25T09:00:00.000',
                updatedAtIso: '2026-05-25T08:55:00.000',
              ),
              GeneralReminderAcknowledgement(
                occurrenceKey: 'cal1|repeat1|2026-06-01T09:00:00.000',
                updatedAtIso: '2026-06-01T08:55:00.000',
              ),
            ],
          ),
        ),
      );
      final provider = TimetableProvider(
        storage: storage,
        systemLocaleCodeResolver: () => defaultLocaleCode,
      );

      await provider.load();
      final occurrence = provider
          .generalOccurrencesForRange(
            startInclusive: DateTime(2026, 5, 25),
            endExclusive: DateTime(2026, 5, 26),
          )
          .single;

      await provider.deleteFutureGeneralOccurrences(occurrence);

      expect(storage.data!.generalMode.reminderAcknowledgements, hasLength(1));
      expect(
        generalOccurrenceKeyMatches(
          storage
              .data!
              .generalMode
              .reminderAcknowledgements
              .single
              .occurrenceKey,
          calendarId: 'cal1',
          eventId: 'repeat1',
          startDateTimeIso: '2026-05-18T09:00:00.000',
        ),
        isTrue,
      );
    },
  );

  test(
    'general JSON import returns structured result for selected calendars',
    () async {
      final provider = TimetableProvider(
        storage: _MemoryTimetableStorage(
          buildInitialAppData(buildDefaultPeriodTimes()),
        ),
        systemLocaleCodeResolver: () => defaultLocaleCode,
      );
      final source = encodeGeneralScheduleDataEnvelope(
        GeneralScheduleExportData(
          schedules: [
            GeneralSchedule(id: 'import_a', name: 'Import A', events: const []),
            GeneralSchedule(id: 'import_b', name: 'Import B', events: const []),
          ],
        ),
      );

      await provider.load();
      final result = await provider.importSelectedGeneralSchedulesJson(
        source,
        scheduleIds: const ['import_a', 'import_b'],
        mode: GeneralScheduleImportMode.addAsNew,
      );

      expect(result.importedCount, 2);
      expect(result.scheduleNames, ['Import A', 'Import B']);
      expect(result.hasWarnings, false);
      expect(
        provider.generalSchedules.map((item) => item.name),
        contains('Import A'),
      );
      expect(
        provider.generalSchedules.map((item) => item.name),
        contains('Import B'),
      );
    },
  );

  test('general JSON import can replace the active calendar', () async {
    final provider = TimetableProvider(
      storage: _MemoryTimetableStorage(
        buildInitialAppData(buildDefaultPeriodTimes()),
      ),
      systemLocaleCodeResolver: () => defaultLocaleCode,
    );
    final source = encodeGeneralScheduleDataEnvelope(
      GeneralScheduleExportData(
        schedules: [
          GeneralSchedule(
            id: 'replacement',
            name: 'Replacement',
            events: [
              GeneralEvent(
                id: 'replacement_event',
                calendarId: 'replacement',
                title: 'Replacement Event',
                startDateTimeIso: '2026-05-25T09:00:00.000',
                endDateTimeIso: '2026-05-25T10:00:00.000',
              ),
            ],
          ),
        ],
      ),
    );

    await provider.load();
    final activeId = provider.activeGeneralSchedule.id;
    final result = await provider.importSelectedGeneralSchedulesJson(
      source,
      scheduleIds: const ['replacement'],
      mode: GeneralScheduleImportMode.replaceActive,
      replacementScheduleId: activeId,
    );

    expect(result.importedCount, 1);
    expect(provider.activeGeneralSchedule.id, activeId);
    expect(provider.activeGeneralSchedule.name, 'Replacement');
    expect(
      provider.activeGeneralSchedule.events.single.title,
      'Replacement Event',
    );
  });

  test('replacement imports reject invalid targets without mutation', () async {
    final storage = _MemoryTimetableStorage(
      buildInitialAppData(buildDefaultPeriodTimes()),
    );
    final provider = TimetableProvider(
      storage: storage,
      systemLocaleCodeResolver: () => defaultLocaleCode,
    );
    addTearDown(provider.dispose);
    final source = encodeGeneralScheduleDataEnvelope(
      const GeneralScheduleExportData(
        schedules: [
          GeneralSchedule(id: 'replacement', name: 'Replacement', events: []),
        ],
      ),
    );
    const icsSource = '''
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:replacement-event
DTSTART:20260525T090000
DTEND:20260525T100000
SUMMARY:Replacement
END:VEVENT
END:VCALENDAR
''';

    await provider.load();
    storage.saveCount = 0;
    final before = storage.data!.generalMode.toJson();

    for (final replacementId in <String?>[null, 'missing']) {
      await expectLater(
        provider.importSelectedGeneralSchedulesJson(
          source,
          scheduleIds: const ['replacement'],
          mode: GeneralScheduleImportMode.replaceActive,
          replacementScheduleId: replacementId,
        ),
        throwsFormatException,
      );
      await expectLater(
        provider.importGeneralSchedulesIcs(
          icsSource,
          mode: GeneralScheduleImportMode.replaceActive,
          replacementScheduleId: replacementId,
        ),
        throwsFormatException,
      );
    }

    expect(storage.saveCount, 0);
    expect(storage.data!.generalMode.toJson(), before);
    expect(provider.generalSchedules, hasLength(1));
    expect(provider.activeGeneralSchedule.name, isNot('Replacement'));
  });

  test(
    'malformed general JSON import fails before mutating calendars',
    () async {
      final provider = TimetableProvider(
        storage: _MemoryTimetableStorage(
          buildInitialAppData(buildDefaultPeriodTimes()),
        ),
        systemLocaleCodeResolver: () => defaultLocaleCode,
      );

      await provider.load();
      final before = provider.generalSchedules.length;

      await expectLater(
        provider.importSelectedGeneralSchedulesJson(
          '{not-json',
          scheduleIds: const ['missing'],
          mode: GeneralScheduleImportMode.addAsNew,
        ),
        throwsFormatException,
      );
      expect(provider.generalSchedules, hasLength(before));
    },
  );

  test(
    'general ICS import returns structured localized-warning data',
    () async {
      final provider = TimetableProvider(
        storage: _MemoryTimetableStorage(
          buildInitialAppData(buildDefaultPeriodTimes()),
        ),
        systemLocaleCodeResolver: () => defaultLocaleCode,
      );
      const source = '''
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:test-warning
DTSTART:20260525T090000
DTEND:20260525T100000
SUMMARY:Imported
X-SKED-UNKNOWN:kept
END:VEVENT
END:VCALENDAR
''';

      await provider.load();
      final result = await provider.importGeneralSchedulesIcs(
        source,
        mode: GeneralScheduleImportMode.addAsNew,
      );

      expect(result.importedCount, 1);
      expect(result.hasWarnings, true);
      expect(
        result.icsWarnings.single.code,
        GeneralCalendarIcsWarningCode.unsupportedFields,
      );
    },
  );

  test(
    'general ICS import failures are localized by provider locale',
    () async {
      final provider = TimetableProvider(
        storage: _MemoryTimetableStorage(
          buildInitialAppData(buildDefaultPeriodTimes())
              .copyWith(localeCode: 'zh'),
        ),
        systemLocaleCodeResolver: () => 'zh',
      );

      await provider.load();

      expect(
        () => provider.previewImportGeneralSchedulesIcs(
          'BEGIN:VCALENDAR\nEND:VCALENDAR',
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            '导入文件中没有分类。',
          ),
        ),
      );
    },
  );

  test(
    'general popup dismiss setting does not mutate student setting',
    () async {
      final initial = buildInitialAppData(buildDefaultPeriodTimes());
      final provider = TimetableProvider(
        storage: _MemoryTimetableStorage(initial),
        systemLocaleCodeResolver: () => defaultLocaleCode,
      );

      await provider.load();
      final studentValue = provider.closeCoursePopupOnOutsideTap;

      await provider.updateGeneralDisplaySettings(
        closeEventPopupOnOutsideTap: false,
      );

      expect(provider.closeGeneralEventPopupOnOutsideTap, false);
      expect(provider.closeCoursePopupOnOutsideTap, studentValue);
    },
  );

  test('general view switch behavior persists independently', () async {
    final initial = buildInitialAppData(buildDefaultPeriodTimes());
    final storage = _MemoryTimetableStorage(initial);
    final provider = TimetableProvider(
      storage: storage,
      systemLocaleCodeResolver: () => defaultLocaleCode,
    );
    addTearDown(provider.dispose);

    await provider.load();
    expect(provider.generalViewSwitchBehavior, generalViewSwitchBehaviorCycle);

    await provider.updateGeneralDisplaySettings(
      viewSwitchBehavior: generalViewSwitchBehaviorMenu,
    );

    expect(provider.generalViewSwitchBehavior, generalViewSwitchBehaviorMenu);
    expect(
      storage.data!.generalMode.viewSwitchBehavior,
      generalViewSwitchBehaviorMenu,
    );
    expect(
      storage.data!.studentMode.fitDaySelectorToWidth,
      initial.studentMode.fitDaySelectorToWidth,
    );
  });

  test(
    'general toolbar width policy persists all values independently',
    () async {
      final initial = buildInitialAppData(buildDefaultPeriodTimes());
      final storage = _MemoryTimetableStorage(initial);
      final provider = TimetableProvider(
        storage: storage,
        systemLocaleCodeResolver: () => defaultLocaleCode,
      );
      addTearDown(provider.dispose);

      await provider.load();
      expect(
        provider.generalToolbarWidthPolicy,
        generalToolbarWidthPolicyContent,
      );

      const policies = [
        generalToolbarWidthPolicyContent,
        generalToolbarWidthPolicyBalanced,
        generalToolbarWidthPolicyCalendarPriority,
        generalToolbarWidthPolicyDatePriority,
      ];
      for (final policy in policies) {
        await provider.updateGeneralDisplaySettings(toolbarWidthPolicy: policy);

        expect(provider.generalToolbarWidthPolicy, policy);
        expect(storage.data!.generalMode.toolbarWidthPolicy, policy);
      }

      expect(
        storage.data!.generalMode.viewSwitchBehavior,
        initial.generalMode.viewSwitchBehavior,
      );
      expect(storage.data!.studentMode.toJson(), initial.studentMode.toJson());
    },
  );

  test('general date label format persists all values independently', () async {
    final initial = buildInitialAppData(buildDefaultPeriodTimes());
    final storage = _MemoryTimetableStorage(initial);
    final provider = TimetableProvider(
      storage: storage,
      systemLocaleCodeResolver: () => defaultLocaleCode,
    );
    addTearDown(provider.dispose);

    await provider.load();
    expect(provider.generalDateLabelFormat, generalDateLabelFormatSlash);

    const formats = [
      generalDateLabelFormatLocalized,
      generalDateLabelFormatIso,
      generalDateLabelFormatSlash,
    ];
    for (final format in formats) {
      await provider.updateGeneralDisplaySettings(dateLabelFormat: format);

      expect(provider.generalDateLabelFormat, format);
      expect(storage.data!.generalMode.dateLabelFormat, format);
    }

    expect(
      storage.data!.generalMode.toolbarWidthPolicy,
      initial.generalMode.toolbarWidthPolicy,
    );
    expect(storage.data!.studentMode.toJson(), initial.studentMode.toJson());
  });

  test(
    'general time grid hour height persists independently in one save',
    () async {
      final initial = buildInitialAppData(buildDefaultPeriodTimes());
      final storage = _MemoryTimetableStorage(initial);
      final provider = TimetableProvider(
        storage: storage,
        systemLocaleCodeResolver: () => defaultLocaleCode,
      );
      addTearDown(provider.dispose);

      await provider.load();
      storage.saveCount = 0;
      expect(
        provider.generalTimeGridHourHeight,
        generalTimeGridHourHeightDefault,
      );

      await provider.updateGeneralDisplaySettings(
        timeGridHourHeight: generalTimeGridHourHeightMax,
      );

      expect(provider.generalTimeGridHourHeight, generalTimeGridHourHeightMax);
      expect(
        storage.data!.generalMode.timeGridHourHeight,
        generalTimeGridHourHeightMax,
      );
      expect(storage.saveCount, 1);
      expect(
        provider.generalTimeGridMinutes,
        initial.generalMode.timeGridMinutes,
      );
      expect(storage.data!.studentMode.toJson(), initial.studentMode.toJson());
    },
  );

  test('failed general time grid hour height save rolls back', () async {
    final initial = buildInitialAppData(buildDefaultPeriodTimes());
    final storage = _MemoryTimetableStorage(initial);
    final provider = TimetableProvider(
      storage: storage,
      systemLocaleCodeResolver: () => defaultLocaleCode,
    );
    addTearDown(provider.dispose);

    await provider.load();
    storage.nextSaveError = StateError('save failed');

    await expectLater(
      provider.updateGeneralDisplaySettings(
        timeGridHourHeight: generalTimeGridHourHeightMin,
      ),
      throwsStateError,
    );

    expect(
      provider.generalTimeGridHourHeight,
      generalTimeGridHourHeightDefault,
    );
    expect(
      storage.data!.generalMode.timeGridHourHeight,
      generalTimeGridHourHeightDefault,
    );
  });

  test('failed general date label format save rolls back', () async {
    final initial = buildInitialAppData(buildDefaultPeriodTimes());
    final storage = _MemoryTimetableStorage(initial);
    final provider = TimetableProvider(
      storage: storage,
      systemLocaleCodeResolver: () => defaultLocaleCode,
    );
    addTearDown(provider.dispose);

    await provider.load();
    storage.nextSaveError = StateError('save failed');

    await expectLater(
      provider.updateGeneralDisplaySettings(
        dateLabelFormat: generalDateLabelFormatLocalized,
      ),
      throwsStateError,
    );

    expect(provider.generalDateLabelFormat, generalDateLabelFormatSlash);
    expect(
      storage.data!.generalMode.dateLabelFormat,
      generalDateLabelFormatSlash,
    );
  });

  test('event FAB setting persists and rolls back on failure', () async {
    final initial = buildInitialAppData(buildDefaultPeriodTimes());
    final storage = _MemoryTimetableStorage(initial);
    final provider = TimetableProvider(
      storage: storage,
      systemLocaleCodeResolver: () => defaultLocaleCode,
    );
    addTearDown(provider.dispose);
    await provider.load();

    await provider.updateGeneralDisplaySettings(showAddEventFab: false);
    expect(provider.showAddEventFab, isFalse);
    expect(storage.data!.generalMode.showAddEventFab, isFalse);

    storage.nextSaveError = StateError('save failed');
    await expectLater(
      provider.updateGeneralDisplaySettings(showAddEventFab: true),
      throwsStateError,
    );

    expect(provider.showAddEventFab, isFalse);
    expect(storage.data!.generalMode.showAddEventFab, isFalse);
  });

  test('long-press event add persists and rolls back on failure', () async {
    final initial = buildInitialAppData(buildDefaultPeriodTimes());
    final storage = _MemoryTimetableStorage(initial);
    final provider = TimetableProvider(
      storage: storage,
      systemLocaleCodeResolver: () => defaultLocaleCode,
    );
    addTearDown(provider.dispose);
    await provider.load();

    await provider.updateGeneralDisplaySettings(enableLongPressAddEvent: false);
    expect(provider.enableLongPressAddEvent, isFalse);
    expect(storage.data!.generalMode.enableLongPressAddEvent, isFalse);

    storage.nextSaveError = StateError('save failed');
    await expectLater(
      provider.updateGeneralDisplaySettings(enableLongPressAddEvent: true),
      throwsStateError,
    );

    expect(provider.enableLongPressAddEvent, isFalse);
    expect(storage.data!.generalMode.enableLongPressAddEvent, isFalse);
  });

  test(
    'all-day timeline collapse persists once and rolls back on failure',
    () async {
      final initial = buildInitialAppData(buildDefaultPeriodTimes());
      final storage = _MemoryTimetableStorage(initial);
      final provider = TimetableProvider(
        storage: storage,
        systemLocaleCodeResolver: () => defaultLocaleCode,
      );
      addTearDown(provider.dispose);
      await provider.load();
      storage.saveCount = 0;

      await provider.updateGeneralDisplaySettings(
        allDayTimelineCollapsed: true,
      );
      expect(provider.allDayTimelineCollapsed, isTrue);
      expect(storage.data!.generalMode.allDayTimelineCollapsed, isTrue);
      expect(storage.saveCount, 1);

      storage.nextSaveError = StateError('save failed');
      await expectLater(
        provider.updateGeneralDisplaySettings(allDayTimelineCollapsed: false),
        throwsStateError,
      );

      expect(provider.allDayTimelineCollapsed, isTrue);
      expect(storage.data!.generalMode.allDayTimelineCollapsed, isTrue);
      expect(storage.saveCount, 2);
    },
  );
}
