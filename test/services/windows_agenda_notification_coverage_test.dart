import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/agenda_notification_payload.dart';
import 'package:sked/services/agenda_notification_runtime_store.dart';
import 'package:sked/services/agenda_notification_service.dart';
import 'package:sked/services/agenda_projection_service.dart';

final _anchor = DateTime(2026, 10, 24, 9);

GeneralEvent _event({
  String id = 'event',
  Duration startsAfter = const Duration(days: 15),
  List<int> leads = const [2880],
  GeneralEventReminderBehavior behavior = GeneralEventReminderBehavior.custom,
  GeneralEventRecurrenceRule recurrence = const GeneralEventRecurrenceRule(),
}) {
  final start = _anchor.add(startsAfter);
  final original = GeneralEvent(
    id: id,
    calendarId: 'calendar',
    title: id,
    startDateTimeIso: start.toIso8601String(),
    endDateTimeIso: start.add(const Duration(hours: 1)).toIso8601String(),
    reminderBehavior: behavior,
    reminders: [
      for (final lead in leads) GeneralEventReminder(minutesBefore: lead),
    ],
    recurrenceRule: recurrence,
  );
  // Keep the fixture inside the actual JSON contract, including large leads.
  return GeneralEvent.fromJson(
    jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
  );
}

AppData _data(
  List<GeneralEvent> events, {
  NotificationSettings settings = const NotificationSettings(enabled: true),
  bool visible = true,
  List<GeneralReminderAcknowledgement> acknowledgements = const [],
}) {
  final base = buildInitialAppData(buildDefaultPeriodTimes());
  return base.copyWith(
    activeMode: AppMode.general,
    enabledWorkspaces: {AppMode.general},
    notificationSettings: settings,
    generalMode: base.generalMode.copyWith(
      activeScheduleId: 'calendar',
      schedules: [
        GeneralSchedule(
          id: 'calendar',
          name: 'Calendar',
          isVisible: visible,
          events: events,
        ),
      ],
      reminderAcknowledgements: acknowledgements,
    ),
  );
}

AgendaNotificationService _service(MemoryAgendaNotificationGateway gateway) {
  final service = AgendaNotificationService(
    enabled: true,
    gateway: gateway,
    now: () => _anchor,
    runtimeStore: MemoryAgendaNotificationRuntimeStore(clock: () => _anchor),
  );
  addTearDown(service.dispose);
  return service;
}

class _ChannelGateway extends MemoryAgendaNotificationGateway {
  bool channelEnabled = true;

  @override
  Future<bool> notificationChannelEnabled(String channelId) async =>
      channelEnabled;
}

class _OwnedCardGateway extends MemoryAgendaNotificationGateway {
  final activeCards = <String, AgendaNotificationRequest>{};

  void deliverPending() {
    activeCards.addAll(scheduled);
    scheduled.clear();
  }

  @override
  Future<Set<String>> ownedNotificationKeys() async => {
    ...scheduled.keys,
    ...activeCards.keys,
  };

  @override
  Future<void> cancel(String key) async {
    activeCards.remove(key);
    await super.cancel(key);
  }

  @override
  Future<void> cancelNotificationId(int id, {String? tag}) async {
    activeCards.removeWhere((_, request) => request.id == id);
    await super.cancelNotificationId(id, tag: tag);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    final previous = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = previous);
  });

  test(
    'exposes Windows policy before reconciliation without a checked window',
    () {
      final service = _service(MemoryAgendaNotificationGateway());
      expect(service.schedulingWindowDays, 14);
      expect(service.planner.maxScheduledNotifications, 200);
      expect(service.status.schedulingWindowEndExclusive, isNull);
    },
  );

  for (final (start, lead, fire) in [
    (const Duration(days: 15), 2880, const Duration(days: 13)),
    (
      const Duration(days: 14, hours: 12),
      1440,
      const Duration(days: 13, hours: 12),
    ),
  ]) {
    test(
      'includes later start $start when its reminder enters the window',
      () async {
        final gateway = MemoryAgendaNotificationGateway();
        final status = await _service(gateway).reconcile(
          _data([
            _event(startsAfter: start, leads: [lead]),
          ]),
          anchor: _anchor,
        );
        expect(gateway.scheduled.values.single.fireAt, _anchor.add(fire));
        expect(status.directCapacity, 200);
        expect(status.nextRenewalAt, isNull);
        expect(
          status.schedulingWindowEndExclusive,
          _anchor.add(const Duration(days: 14)),
        );
      },
    );
  }

  test(
    'keeps the exclusive 14 day fire-time boundary and deduplicates leads',
    () async {
      final gateway = MemoryAgendaNotificationGateway();
      await _service(gateway).reconcile(
        _data([
          _event(
            startsAfter: const Duration(days: 14, hours: 12),
            leads: [0, 720, 1440, 2880, 2880],
          ),
        ]),
        anchor: _anchor,
      );
      final times = gateway.scheduled.values.map((item) => item.fireAt).toList()
        ..sort();
      expect(times, [
        _anchor.add(const Duration(days: 12, hours: 12)),
        _anchor.add(const Duration(days: 13, hours: 12)),
      ]);
      for (final request in gateway.scheduled.values) {
        expect(
          agendaNotificationPayloadMatchesProjection(
            payload: AgendaNotificationPayload.tryDecode(request.payload)!,
            data: _data([
              _event(
                startsAfter: const Duration(days: 14, hours: 12),
                leads: [0, 720, 1440, 2880, 2880],
              ),
            ]),
            projection: const AgendaProjectionService(),
          ),
          isTrue,
        );
      }
    },
  );

  for (final ongoing in [true, false]) {
    test('keeps a snoozed old card eligible ongoing=$ongoing', () async {
      final start = _anchor.add(Duration(days: ongoing ? -3 : 1));
      final lead = ongoing ? 0 : 7 * 1440;
      final event = _event(leads: [lead]).copyWith(
        startDateTimeIso: start.toIso8601String(),
        endDateTimeIso: start
            .add(Duration(days: ongoing ? 7 : 1))
            .toIso8601String(),
      );
      final data = _data([event]);
      var current = start.subtract(Duration(minutes: lead + 1));
      final store = MemoryAgendaNotificationRuntimeStore(clock: () => current);
      final gateway = MemoryAgendaNotificationGateway();
      final service = AgendaNotificationService(
        enabled: true,
        gateway: gateway,
        now: () => current,
        runtimeStore: store,
      );
      addTearDown(service.dispose);
      await service.reconcile(data, anchor: current);
      final oldPayload = gateway.scheduled.values.single.payload;
      current = _anchor;
      await service.handleAction(oldPayload, 'snooze_10m');
      expect(gateway.scheduled, hasLength(1));
      expect(
        gateway.scheduled.values.single.fireAt,
        current.add(const Duration(minutes: 10)),
      );
      final restarted = AgendaNotificationService(
        enabled: true,
        gateway: gateway,
        now: () => current,
        runtimeStore: store,
      );
      addTearDown(restarted.dispose);
      await restarted.reconcile(data, anchor: current);
      expect(
        gateway.scheduled.values.single.fireAt,
        current.add(const Duration(minutes: 10)),
      );
    });
  }

  test('uses default lead and keeps disabled events disabled', () async {
    final gateway = MemoryAgendaNotificationGateway();
    await _service(gateway).reconcile(
      _data(
        [
          _event(id: 'default', behavior: GeneralEventReminderBehavior.inherit),
          _event(
            id: 'disabled',
            behavior: GeneralEventReminderBehavior.disabled,
          ),
        ],
        settings: const NotificationSettings(
          enabled: true,
          generalDefaultMinutesBefore: 2880,
        ),
      ),
      anchor: _anchor,
    );
    expect(
      AgendaNotificationPayload.tryDecode(
        gateway.scheduled.values.single.payload,
      )?.target.eventId,
      'default',
    );
  });

  for (final ongoing in [true, false]) {
    test(
      'preserves valid owned old cards and removes stale ones ongoing=$ongoing',
      () async {
        final start = _anchor.add(Duration(days: ongoing ? -3 : 1));
        final lead = ongoing ? 0 : 7 * 1440;
        final event = _event(leads: [lead]).copyWith(
          startDateTimeIso: start.toIso8601String(),
          endDateTimeIso: start
              .add(Duration(days: ongoing ? 7 : 1))
              .toIso8601String(),
        );
        final original = _data([event]);
        var current = start.subtract(Duration(minutes: lead + 1));
        final gateway = _OwnedCardGateway();
        final service = AgendaNotificationService(
          enabled: true,
          gateway: gateway,
          now: () => current,
          runtimeStore: MemoryAgendaNotificationRuntimeStore(
            clock: () => current,
          ),
        );
        addTearDown(service.dispose);
        await service.reconcile(original, anchor: current);
        final card = gateway.scheduled.values.single;
        gateway.deliverPending();
        current = _anchor;
        await service.reconcile(
          _data([event, _event(id: 'unrelated')]),
          anchor: current,
        );
        expect(gateway.activeCards.keys, contains(card.key));

        for (final change in [
          'deleted',
          'hidden',
          'disabled',
          'handled',
          'ended',
        ]) {
          gateway.activeCards[card.key] = card;
          current = change == 'ended'
              ? DateTime.parse(event.endDateTimeIso)
                    .add(const Duration(days: 3))
              : _anchor;
          final changed = switch (change) {
            'deleted' => _data(const []),
            'hidden' => _data([event], visible: false),
            'disabled' => _data([
              event.copyWith(
                reminderBehavior: GeneralEventReminderBehavior.disabled,
              ),
            ]),
            'handled' => _data(
              [event],
              acknowledgements: [
                GeneralReminderAcknowledgement(
                  occurrenceKey: buildGeneralOccurrenceKey(
                    'calendar',
                    event.id,
                    event.startDateTimeIso,
                  ),
                  updatedAtIso: current.toIso8601String(),
                ),
              ],
            ),
            _ => original,
          };
          await service.reconcile(changed, anchor: current);
          expect(
            gateway.activeCards.keys,
            isNot(contains(card.key)),
            reason: change,
          );
        }
      },
    );
  }

  test('respects hidden calendars and persistent handled markers', () async {
    final event = _event();
    final gateway = MemoryAgendaNotificationGateway();
    final service = _service(gateway);
    await service.reconcile(_data([event], visible: false), anchor: _anchor);
    expect(gateway.scheduled, isEmpty);
    final visibleToReminders = _data(
      [event],
      visible: false,
      settings: const NotificationSettings(
        enabled: true,
        remindHiddenGeneralCalendars: true,
      ),
    );
    await service.reconcile(visibleToReminders, anchor: _anchor);
    expect(gateway.scheduled, hasLength(1));
    final handled = visibleToReminders.copyWith(
      generalMode: visibleToReminders.generalMode.copyWith(
        reminderAcknowledgements: [
          GeneralReminderAcknowledgement(
            occurrenceKey: buildGeneralOccurrenceKey(
              'calendar',
              'event',
              event.startDateTimeIso,
            ),
            updatedAtIso: _anchor.toIso8601String(),
          ),
        ],
      ),
    );
    await service.reconcile(handled, anchor: _anchor);
    expect(gateway.scheduled, isEmpty);
  });

  test(
    'reaches shifted repeating starts without expanding the intervening years',
    () async {
      final gateway = MemoryAgendaNotificationGateway();
      final start = _anchor.toUtc().subtract(const Duration(days: 600));
      await _service(gateway).reconcile(
        _data([
          _event(
            startsAfter: const Duration(days: -600),
            leads: const [600 * 1440],
            recurrence: const GeneralEventRecurrenceRule(
              type: GeneralEventRecurrence.daily,
            ),
          ).copyWith(
            startDateTimeIso: start.toIso8601String(),
            endDateTimeIso: start
                .add(const Duration(hours: 1))
                .toIso8601String(),
          ),
        ]),
        anchor: _anchor,
      );
      expect(gateway.scheduled, hasLength(14));
      final times = gateway.scheduled.values.map((item) => item.fireAt).toList()
        ..sort();
      expect(times.first.toUtc(), _anchor.toUtc());
      expect(times.last.toUtc(), _anchor.toUtc().add(const Duration(days: 13)));
    },
  );

  test(
    'ignores impossible huge lead without overflow or losing a valid lead',
    () async {
      final gateway = MemoryAgendaNotificationGateway();
      await _service(gateway).reconcile(
        _data([
          _event(
            startsAfter: const Duration(days: 14, hours: 12),
            leads: const [9223372036854775807, 1440],
            recurrence: const GeneralEventRecurrenceRule(
              type: GeneralEventRecurrence.daily,
            ),
          ),
        ]),
        anchor: _anchor,
      );
      expect(gateway.scheduled, hasLength(1));
      expect(
        gateway.scheduled.values.single.fireAt,
        _anchor.add(const Duration(days: 13, hours: 12)),
      );
    },
  );

  test('projects repeated leads once without changing the reminder data', () {
    final data = _data([
      _event(
        startsAfter: const Duration(days: 13),
        leads: List.filled(512, 1440),
        recurrence: const GeneralEventRecurrenceRule(
          type: GeneralEventRecurrence.daily,
        ),
      ),
    ]);
    final candidates = GeneralAgendaSource()
        .occurrences(
          data,
          AgendaProjectionQuery(
            startInclusive: _anchor,
            endExclusive: _anchor.add(const Duration(days: 14)),
            includeReminderCandidates: true,
          ),
        )
        .toList();

    expect(candidates, hasLength(2));
    expect(candidates.map((item) => item.stableId).toSet(), hasLength(2));
    for (final candidate in candidates) {
      expect(candidate.reminders, hasLength(512));
      expect(
        candidate.reminders.every((reminder) => reminder.minutesBefore == 1440),
        isTrue,
      );
    }
  });

  test('skips a long-duration overlap prefix by index', () async {
    // Isolate prefix size from the local expander's historical skipped-date
    // stop rule; named-timezone tests cover that separate civil-time contract.
    final anchor = DateTime.utc(2026, 10, 24, 9);
    final long = _event(leads: const [0]).copyWith(
      startDateTimeIso: DateTime.utc(1900, 1, 1, 9).toIso8601String(),
      endDateTimeIso: DateTime.utc(2000, 1, 1, 9).toIso8601String(),
      recurrenceRule: const GeneralEventRecurrenceRule(
        type: GeneralEventRecurrence.daily,
      ),
    );
    final gateway = MemoryAgendaNotificationGateway();
    await _service(gateway).reconcile(_data([long]), anchor: anchor);
    expect(gateway.scheduled, hasLength(14));
    expect(gateway.scheduled.values.first.fireAt, anchor);
  });

  for (final utc in [true, false]) {
    test(
      'keeps a valid very large lead near the supported date limit utc=$utc',
      () async {
        final start = utc
            ? DateTime.utc(9999, 12, 31, 23)
            : DateTime(9999, 12, 31, 23);
        final lead = start.difference(_anchor).inMinutes - 13 * 1440;
        final event = _event(leads: [lead]).copyWith(
          startDateTimeIso: start.toIso8601String(),
          endDateTimeIso: start
              .add(const Duration(minutes: 30))
              .toIso8601String(),
        );
        final gateway = MemoryAgendaNotificationGateway();
        await _service(gateway).reconcile(_data([event]), anchor: _anchor);
        expect(gateway.scheduled, hasLength(1));
        expect(
          gateway.scheduled.values.single.fireAt.isAtSameMomentAs(
            _anchor.add(const Duration(days: 13)),
          ),
          isTrue,
        );
      },
    );
  }

  test('reminder arithmetic preserves ordinary offsets and saturates instead of wrapping', () {
    for (final utc in [true, false]) {
      final start = utc ? _anchor.toUtc() : _anchor;
      for (final minutes in [0, 1, 1440, -60]) {
        expect(
          AgendaReminder(minutesBefore: minutes).fireAt(start),
          start.subtract(Duration(minutes: minutes)),
        );
      }
      final earliest = const AgendaReminder(minutesBefore: 9223372036854775807)
          .fireAt(start);
      expect(earliest.microsecondsSinceEpoch, -8640000000000000000);
      expect(earliest.isUtc, start.isUtc);
      final nearMinimum = DateTime.fromMicrosecondsSinceEpoch(
        -8640000000000000000 + 1000000,
        isUtc: utc,
      );
      expect(
        const AgendaReminder(minutesBefore: 1)
            .fireAt(nearMinimum)
            .microsecondsSinceEpoch,
        -8640000000000000000,
      );
      final latest = DateTime.fromMicrosecondsSinceEpoch(
        8640000000000000000,
        isUtc: utc,
      );
      final exact = const AgendaReminder(minutesBefore: 200000000000)
          .fireAt(latest);
      expect(exact.microsecondsSinceEpoch, -3360000000000000000);
      expect(exact.isUtc, utc);
    }
  });

  test(
    'passes fire-time intent to injected sources without widening their bounds',
    () async {
      AgendaProjectionQuery? received;
      final source = CallbackAgendaSource(
        id: AgendaSourceType.generalEvent,
        builder: (_, query) {
          received = query;
          return [
            AgendaOccurrence(
              stableId: 'injected',
              sourceType: AgendaSourceType.generalEvent,
              start: _anchor.add(const Duration(days: 15)),
              end: _anchor.add(const Duration(days: 15, hours: 1)),
              title: 'Injected reminder',
              target: const AgendaTarget(
                sourceType: AgendaSourceType.generalEvent,
              ),
              reminders: const [AgendaReminder(minutesBefore: 2880)],
            ),
          ];
        },
      );
      final gateway = MemoryAgendaNotificationGateway();
      final service = AgendaNotificationService(
        enabled: true,
        projection: AgendaProjectionService(
          registry: AgendaSourceRegistry(sources: [source]),
        ),
        gateway: gateway,
        now: () => _anchor,
        runtimeStore: MemoryAgendaNotificationRuntimeStore(
          clock: () => _anchor,
        ),
      );
      addTearDown(service.dispose);
      await service.reconcile(_data(const []), anchor: _anchor);
      expect(received?.includeReminderCandidates, isTrue);
      expect(
        received?.startInclusive,
        _anchor.subtract(const Duration(days: 2)),
      );
      expect(received?.endExclusive, _anchor.add(const Duration(days: 14)));
      expect(
        gateway.scheduled.values.single.fireAt,
        _anchor.add(const Duration(days: 13)),
      );
    },
  );

  test('keeps the 200 request cap and reports omitted reminders', () async {
    final gateway = MemoryAgendaNotificationGateway();
    final status = await _service(gateway).reconcile(
      _data([for (var i = 0; i < 205; i++) _event(id: 'event-$i')]),
      anchor: _anchor,
    );
    expect(gateway.scheduled, hasLength(200));
    expect(status.hasCapacityOverflow, isTrue);
    expect(status.coverage, AgendaNotificationCoverage.capacityLimited);
    expect(
      status.schedulingWindowEndExclusive,
      _anchor.add(const Duration(days: 14)),
    );
  });

  test('clears the successful window after disabled permissions, failure and clear', () async {
    final gateway = _ChannelGateway();
    final service = _service(gateway);
    final data = _data([_event()]);
    await service.reconcile(data, anchor: _anchor);
    expect(service.status.schedulingWindowEndExclusive, isNotNull);
    gateway.channelEnabled = false;
    await service.reconcile(data, anchor: _anchor);
    expect(service.status.coverage, AgendaNotificationCoverage.blocked);
    expect(service.status.schedulingWindowEndExclusive, isNull);
    gateway.channelEnabled = true;
    await service.reconcile(data, anchor: _anchor);
    expect(service.status.schedulingWindowEndExclusive, isNotNull);
    gateway.permissionGranted = false;
    await service.reconcile(data, anchor: _anchor);
    expect(service.status.schedulingWindowEndExclusive, isNull);
    gateway.permissionGranted = true;
    await service.reconcile(data, anchor: _anchor);
    await service.recordExternalReconcileFailure(
      error: StateError('test failure'),
      mode: AgendaNotificationReconcileMode.recovery,
      origin: AgendaNotificationReconcileOrigin.foreground,
    );
    expect(service.status.schedulingWindowEndExclusive, isNull);
    await service.reconcile(data, anchor: _anchor);
    await service.clearRuntime();
    expect(service.status.schedulingWindowEndExclusive, isNull);
    await service.reconcile(
      data.copyWith(notificationSettings: const NotificationSettings()),
      anchor: _anchor,
    );
    expect(service.status.schedulingWindowEndExclusive, isNull);
  });

  test(
    'keeps Android scheduling policy and omits the Windows-only summary',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final gateway = MemoryAgendaNotificationGateway();
      final service = _service(gateway);
      final status = await service.reconcile(
        _data([_event()]),
        anchor: _anchor,
      );
      expect(gateway.scheduled, hasLength(1));
      expect(status.directCapacity, 450);
      expect(service.schedulingWindowDays, isNull);
      expect(status.schedulingWindowEndExclusive, isNull);
    },
  );

  test(
    'includes course defaults and overrides outside the original window',
    () async {
      final base = buildInitialAppData(buildDefaultPeriodTimes());
      final timetable = TimetableData(
        id: 'table',
        config: TimetableConfig(
          name: 'Term',
          startDate: DateTime(2026, 10, 19),
          totalWeeks: 6,
          periodTimeSetId: 'periods',
        ),
        courses: const [],
      );
      CourseItem course(String id, CourseReminderSettings reminder) =>
          CourseItem.fromJson({
            'id': id,
            'name': id,
            'dayOfWeek': 7,
            'semesterWeeks': [3],
            'periods': [],
            'startMinutes': 9 * 60,
            'endMinutes': 10 * 60,
            'reminderSettings': reminder.toJson(),
          });
      final data = base.copyWith(
        enabledWorkspaces: {AppMode.student},
        notificationSettings: const NotificationSettings(
          enabled: true,
          courseDefaultMinutesBefore: 10080,
        ),
        studentMode: base.studentMode.copyWith(
          activeTimetableId: timetable.id,
          timetables: [
            timetable.copyWith(
              config: timetable.config.copyWith(
                startDate: DateTime(2026, 10, 19),
                totalWeeks: 6,
              ),
              courses: [
                course('default', const CourseReminderSettings()),
                course(
                  'override',
                  const CourseReminderSettings(
                    behavior: CourseReminderBehavior.custom,
                    minutesBefore: 4320,
                  ),
                ),
                course(
                  'off',
                  const CourseReminderSettings(
                    behavior: CourseReminderBehavior.disabled,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
      final gateway = MemoryAgendaNotificationGateway();
      var current = _anchor;
      final service = AgendaNotificationService(
        enabled: true,
        gateway: gateway,
        now: () => current,
        runtimeStore: MemoryAgendaNotificationRuntimeStore(
          clock: () => current,
        ),
      );
      addTearDown(service.dispose);
      await service.reconcile(data, anchor: current);
      final courseIds = gateway.scheduled.values
          .map(
            (item) =>
                AgendaNotificationPayload.tryDecode(item.payload)
                    ?.target
                    .courseId,
          )
          .toSet();
      expect(courseIds, {'default', 'override'});
      final oldCard = gateway.scheduled.values.firstWhere(
        (item) =>
            AgendaNotificationPayload.tryDecode(item.payload)
                ?.target
                .courseId ==
            'default',
      );
      current = _anchor.add(const Duration(days: 14));
      await service.handleAction(oldCard.payload, 'snooze_10m');
      expect(
        gateway.scheduled.values.single.fireAt,
        current.add(const Duration(minutes: 10)),
      );
    },
  );

  test('keeps sub-minute ranges at the supported year boundary', () {
    final start = DateTime.utc(9999, 12, 31, 23, 59, 59);
    final event = _event(leads: const [0]).copyWith(
      startDateTimeIso: start.toIso8601String(),
      endDateTimeIso: start
          .add(const Duration(milliseconds: 500))
          .toIso8601String(),
    );
    final values = const AgendaProjectionService().project(
      _data([event]),
      startInclusive: start.subtract(const Duration(seconds: 1)),
      endExclusive: DateTime.utc(10000),
      includeReminderCandidates: true,
    );
    expect(values.single.start, start);
    expect(values.single.reminders.single.minutesBefore, 0);
  });
}
