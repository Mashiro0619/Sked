import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/general_occurrence_cache.dart';
import 'package:sked/services/general_occurrence_service.dart';

final _minute = DateTime.utc(2026, 6, 1, 9);
const _longLead = 129 * 24 * 60;
const _service = GeneralOccurrenceService();

GeneralEvent _event(
  String id, {
  List<GeneralEventReminder>? reminders,
  List<String>? exceptions,
}) => GeneralEvent(
  id: id,
  calendarId: 'calendar',
  title: 'Match $id',
  startDateTimeIso: '2026-06-01T09:00:20.000Z',
  endDateTimeIso: '2026-06-01T09:00:40.000Z',
  recurrenceRule: const GeneralEventRecurrenceRule(
    type: GeneralEventRecurrence.daily,
    count: 200,
  ),
  reminderBehavior: GeneralEventReminderBehavior.custom,
  reminders:
      reminders ?? const [GeneralEventReminder(minutesBefore: _longLead)],
  recurrenceExceptionDateIso: exceptions ?? const [],
);

GeneralScheduleData _data(List<GeneralEvent> events) => GeneralScheduleData(
  activeScheduleId: 'calendar',
  schedules: [
    GeneralSchedule(id: 'calendar', name: 'Calendar', events: events),
  ],
);

List<Object> _snapshot(List<GeneralReminderItem> items) => [
  for (final item in items)
    (
      item.status,
      item.occurrence.occurrenceKey,
      item.occurrence.end.microsecondsSinceEpoch,
      item.occurrence.sequence,
      item.occurrence.calendar,
      item.occurrence.event,
    ),
];

List<GeneralReminderItem> _check(
  GeneralOccurrenceCache cache,
  GeneralScheduleData data, {
  DateTime? now,
  Duration horizon = const Duration(hours: 24),
  Duration lookback = defaultGeneralReminderOverdueWindow,
  NotificationSettings settings = const NotificationSettings(),
  GeneralOccurrenceQuery? filter,
}) {
  final actual = cache.reminderItems(
    data,
    now: now ?? _minute,
    upcomingHorizon: horizon,
    overdueWindow: lookback,
    notificationSettings: settings,
    occurrenceFilter: filter,
  );
  final expected = _service.reminderItems(
    data,
    now: now ?? _minute,
    upcomingHorizon: horizon,
    overdueWindow: lookback,
    notificationSettings: settings,
    occurrenceFilter: filter,
  );
  expect(_snapshot(actual), _snapshot(expected));
  return actual;
}

void main() {
  test('one preparation serves exact statuses throughout a minute', () {
    final cache = GeneralOccurrenceCache();
    final data = _data([_event('event')]);
    for (final micros in [
      0,
      19999999,
      20000000,
      39999999,
      40000000,
      59999999,
    ]) {
      final now = _minute.add(Duration(microseconds: micros));
      final actual = _check(cache, data, now: now);
      expect(cache.reminderItems(data, now: now), same(actual));
      expect(cache.indexedPreparationBuildCount, 1);
    }
    _check(cache, data, now: _minute.add(const Duration(minutes: 1)));
    expect(cache.indexedPreparationBuildCount, 2);
    _check(cache, data);
    expect(cache.indexedPreparationBuildCount, 3);
    _check(cache, data, now: _minute.toLocal());
    expect(cache.indexedPreparationBuildCount, 4);
    cache.clear();
    _check(cache, data, now: _minute.toLocal());
    expect(cache.indexedPreparationBuildCount, 5);
  });

  test('negative epoch minutes and clock rollback use the right bucket', () {
    final cache = GeneralOccurrenceCache();
    final data = _data([
      _event('event').copyWith(
        startDateTimeIso: '1969-12-31T23:59:20Z',
        endDateTimeIso: '1969-12-31T23:59:40Z',
      ),
    ]);
    for (final seconds in [0, 20, 40, 59, 20]) {
      _check(cache, data, now: DateTime.utc(1969, 12, 31, 23, 59, seconds));
      expect(cache.indexedPreparationBuildCount, 1);
    }
    _check(cache, data, now: DateTime.utc(1970));
    expect(cache.indexedPreparationBuildCount, 2);
  });

  test('source aliases invalidate before an exact-time result can hit', () {
    final reminders = [const GeneralEventReminder(minutesBefore: _longLead)];
    final exceptions = <String>[];
    final events = [
      _event('event', reminders: reminders, exceptions: exceptions),
    ];
    final calendars = [
      GeneralSchedule(id: 'calendar', name: 'Calendar', events: events),
    ];
    final history = <GeneralReminderAcknowledgement>[];
    final data = GeneralScheduleData(
      activeScheduleId: 'calendar',
      schedules: calendars,
      reminderAcknowledgements: history,
    );
    final cache = GeneralOccurrenceCache();
    var count = 0;
    void changed() {
      _check(cache, data);
      expect(cache.indexedPreparationBuildCount, ++count);
    }

    changed();
    reminders[0] = const GeneralEventReminder(minutesBefore: _longLead + 1440);
    changed();
    exceptions.add('2026-06-02');
    changed();
    exceptions[0] = '2026-06-03';
    changed();
    history.add(
      GeneralReminderAcknowledgement(
        occurrenceKey: buildGeneralOccurrenceKey(
          'calendar',
          'event',
          events.first.startDateTimeIso,
        ),
        updatedAtIso: _minute.toIso8601String(),
      ),
    );
    changed();
    history[0] = GeneralReminderAcknowledgement(
      occurrenceKey: history.first.occurrenceKey,
      updatedAtIso: _minute.toIso8601String(),
      isHandled: false,
    );
    changed();
    events.add(_event('new'));
    changed();
    events[0] = events.first.copyWith(title: 'Renamed');
    changed();
    events.removeLast();
    changed();
    calendars[0] = calendars.first.copyWith(name: 'Renamed calendar');
    changed();
    _check(cache, data);
    expect(cache.indexedPreparationBuildCount, count);
  });

  test(
    'configuration changes and leaving indexed mode drop prepared inputs',
    () {
      final cache = GeneralOccurrenceCache();
      final event = _event('event')
          .copyWith(reminderBehavior: GeneralEventReminderBehavior.inherit);
      final data = _data([event]);
      const settings = NotificationSettings(
        generalDefaultMinutesBefore: _longLead,
      );
      _check(cache, data, settings: settings);
      expect(cache.indexedPreparationBuildCount, 1);
      _check(
        cache,
        data,
        settings: settings,
        horizon: const Duration(hours: 12),
      );
      expect(cache.indexedPreparationBuildCount, 2);
      _check(
        cache,
        data,
        settings: settings,
        lookback: const Duration(hours: 12),
      );
      expect(cache.indexedPreparationBuildCount, 3);
      _check(
        cache,
        data,
        settings: const NotificationSettings(
          generalDefaultMinutesBefore: _longLead + 1,
          remindHiddenGeneralCalendars: true,
        ),
      );
      expect(cache.indexedPreparationBuildCount, 4);
      final filter = GeneralOccurrenceQuery(
        startInclusive: _minute,
        endExclusive: _minute,
        searchQuery: 'missing',
        colorValue: 0xff123456,
      );
      expect(_check(cache, data, settings: settings, filter: filter), isEmpty);
      expect(cache.indexedPreparationBuildCount, 5);
      _check(
        cache,
        data,
        settings: const NotificationSettings(generalDefaultMinutesBefore: 15),
      );
      expect(cache.indexedPreparationBuildCount, 5);
      _check(cache, data, settings: settings, filter: filter);
      expect(cache.indexedPreparationBuildCount, 6);
    },
  );

  test('an injected service keeps its precise indexed entry point', () {
    final service = _RecordingService();
    final cache = GeneralOccurrenceCache(service: service);
    final data = _data([_event('event')]);
    _check(cache, data);
    _check(cache, data, now: _minute.add(const Duration(seconds: 1)));
    _check(cache, data, now: _minute.add(const Duration(seconds: 1)));
    expect(service.calls, 2);
    expect(cache.indexedPreparationBuildCount, 0);
  });
}

class _RecordingService extends GeneralOccurrenceService {
  var calls = 0;

  @override
  GeneralReminderItems indexedReminderItems(
    GeneralScheduleData general, {
    required DateTime now,
    Duration upcomingHorizon = const Duration(hours: 24),
    Duration overdueWindow = defaultGeneralReminderOverdueWindow,
    GeneralOccurrenceQuery? occurrenceFilter,
    NotificationSettings notificationSettings = const NotificationSettings(),
  }) {
    calls++;
    return super.indexedReminderItems(
      general,
      now: now,
      upcomingHorizon: upcomingHorizon,
      overdueWindow: overdueWindow,
      occurrenceFilter: occurrenceFilter,
      notificationSettings: notificationSettings,
    );
  }
}
