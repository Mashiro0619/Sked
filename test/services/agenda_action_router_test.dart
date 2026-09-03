import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/services/agenda_action_router.dart';
import 'package:sked/services/agenda_projection_service.dart';

class _MemoryStorage implements TimetableStorage {
  _MemoryStorage(this.data);

  AppData? data;

  @override
  Future<StorageLoadResult> load() async =>
      StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);

  @override
  Future<void> save(AppData value) async => data = value;

  @override
  Future<String?> filePath() async => 'memory://agenda-action-router';
}

Future<TimetableProvider> _loadProvider(AppData data) async {
  final provider = TimetableProvider(
    storage: _MemoryStorage(data),
    systemLocaleCodeResolver: () => 'en',
    uiStateSaveDelay: Duration.zero,
  );
  await provider.load();
  return provider;
}

AppData _dataWithCourse() {
  final base = buildInitialAppData(buildDefaultPeriodTimes());
  final timetable = TimetableData(
    id: 'table',
    config: TimetableConfig(
      name: 'Term',
      startDate: DateTime(2026, 8, 3),
      totalWeeks: 18,
      periodTimeSetId: 'default',
    ),
    courses: const [
      CourseItem(
        id: 'course',
        name: 'Mathematics',
        teacher: '',
        location: 'Room 1',
        dayOfWeek: DateTime.monday,
        semesterWeeks: [1],
        periods: [1],
        startMinutes: 8 * 60,
        endMinutes: 9 * 60,
        timeRange: '08:00 - 09:00',
        credit: 0,
        remarks: '',
        customFields: {},
      ),
    ],
  );
  return base.copyWith(
    activeMode: AppMode.general,
    studentMode: base.studentMode.copyWith(
      activeTimetableId: timetable.id,
      timetables: [timetable],
    ),
  );
}

AppData _dataWithGeneralEvent({bool isVisible = true}) {
  final base = _dataWithCourse();
  return base.copyWith(
    activeMode: AppMode.student,
    generalMode: base.generalMode.copyWith(
      schedules: [
        GeneralSchedule(
          id: 'calendar',
          name: 'Personal',
          isVisible: isVisible,
          events: [
            GeneralEvent(
              id: 'event',
              calendarId: 'calendar',
              title: 'Appointment',
              startDateTimeIso: '2026-08-03T10:00:00.000',
              endDateTimeIso: '2026-08-03T11:00:00.000',
            ),
          ],
        ),
      ],
    ),
  );
}

void main() {
  test(
    'strict notification payloads round trip and reject malformed envelopes',
    () {
      const target = AgendaTarget(
        sourceType: AgendaSourceType.course,
        timetableId: 'table',
        courseId: 'course',
        dateIso: '2026-08-03',
      );
      final envelope = AgendaNotificationPayload(
        key: 'course|table|course|2026-08-03|10',
        fireAt: DateTime.utc(2026, 8, 3, 7, 50),
        target: target,
        occurrenceId: 'course|table|course|2026-08-03',
        fingerprint: 'fingerprint',
        actionId: 'handled',
      );

      final decoded = AgendaNotificationPayload.tryDecode(envelope.encode());

      expect(decoded, isNotNull);
      expect(decoded!.key, envelope.key);
      expect(decoded.fireAt, envelope.fireAt);
      expect(decoded.target, target);
      expect(decoded.actionId, 'handled');

      String encodeMap(Map<String, dynamic> value) =>
          agendaNotificationPayloadPrefix + jsonEncode(value);
      final valid = envelope.toJson();
      expect(
        AgendaNotificationPayload.tryDecode(encodeMap({...valid, 'v': 2})),
        isNull,
      );
      expect(
        AgendaNotificationPayload.tryDecode(
          encodeMap({...valid, 'sourceType': 'another-source'}),
        ),
        isNull,
      );
      expect(
        AgendaNotificationPayload.tryDecode(
          encodeMap({
            ...valid,
            'target': {...target.toJson(), 'courseId': 42},
          }),
        ),
        isNull,
      );
      expect(
        AgendaNotificationPayload.tryDecode(
          '$agendaNotificationPayloadPrefix{not-json}',
        ),
        isNull,
      );
    },
  );

  test(
    'target decoding accepts one source alias and rejects ambiguous fields',
    () {
      expect(
        decodeAgendaTarget({'source': ' exam ', 'eventId': ' event '}),
        const AgendaTarget(sourceType: 'exam', eventId: 'event'),
      );
      expect(
        decodeAgendaTarget({'sourceType': 'course', 'source': 'exam'}),
        isNull,
      );
      expect(
        decodeAgendaTarget({'sourceType': 'course', 'courseId': 3}),
        isNull,
      );
      expect(
        () => AgendaAction.fromJson({
          'target': {'sourceType': 'course'},
          'actionId': '',
        }),
        throwsFormatException,
      );

      final topLevel = AgendaAction.fromJson({
        'sourceType': 'exam',
        'eventId': 'midterm',
        'key': 'exam-key',
        'actionId': 'open',
      });
      expect(
        topLevel.target,
        const AgendaTarget(sourceType: 'exam', eventId: 'midterm'),
      );
      expect(topLevel.key, 'exam-key');
      expect(topLevel.actionId, 'open');
    },
  );

  test(
    'notification payload copyWith preserves identity and accepts integral num',
    () {
      const target = AgendaTarget(sourceType: 'exam', eventId: 'midterm');
      final original = AgendaNotificationPayload(
        key: 'exam-key',
        fireAt: DateTime.utc(2026, 8, 3, 7),
        target: target,
        occurrenceId: 'occurrence',
        fingerprint: 'fingerprint',
        actionId: 'handled',
        scheduleExact: true,
      );
      final copied = original.copyWith(
        fireAt: DateTime.utc(2026, 8, 3, 7, 10),
        fingerprint: 'new-fingerprint',
        scheduleExact: false,
      );
      expect(copied.key, original.key);
      expect(copied.target, original.target);
      expect(copied.occurrenceId, original.occurrenceId);
      expect(copied.actionId, original.actionId);
      expect(copied.fireAt, DateTime.utc(2026, 8, 3, 7, 10));
      expect(copied.fingerprint, 'new-fingerprint');
      expect(copied.scheduleExact, isFalse);

      final retained = original.copyWith();
      expect(retained.fireAt, original.fireAt);
      expect(retained.fingerprint, original.fingerprint);
      expect(retained.scheduleExact, original.scheduleExact);

      final json = original.toJson()..['v'] = 1.0;
      final decoded = AgendaNotificationPayload.tryDecode(
        agendaNotificationPayloadPrefix + jsonEncode(json),
      );
      expect(decoded, isNotNull);
      expect(decoded!.version, 1);
    },
  );

  test(
    'routes a current course and rejects a stale timetable target',
    () async {
      final provider = await _loadProvider(_dataWithCourse());
      addTearDown(provider.dispose);
      final opened = <AgendaTarget>[];
      final router = AgendaActionRouter(
        provider: provider,
        onTarget: (target) async => opened.add(target),
      );
      const target = AgendaTarget(
        sourceType: AgendaSourceType.course,
        timetableId: 'table',
        courseId: 'course',
        dateIso: '2026-08-03',
      );

      expect(await router.route(const AgendaAction(target: target)), isTrue);
      expect(provider.activeMode, AppMode.student);
      expect(provider.activeTimetableOrNull?.id, 'table');
      expect(provider.selectedWeek, 1);
      expect(opened, [target]);

      expect(
        await router.route(
          const AgendaAction(
            target: AgendaTarget(
              sourceType: AgendaSourceType.course,
              timetableId: 'deleted-table',
              courseId: 'course',
              dateIso: '2026-08-03',
            ),
          ),
        ),
        isFalse,
      );
      expect(opened, [target]);
    },
  );

  test(
    'switches to the explicitly targeted timetable before routing',
    () async {
      final base = _dataWithCourse();
      final original = base.studentMode.timetables.single;
      final other = original.copyWith(id: 'other-table');
      final data = base.copyWith(
        activeMode: AppMode.general,
        studentMode: base.studentMode.copyWith(
          activeTimetableId: 'other-table',
          timetables: [original, other],
        ),
      );
      final provider = await _loadProvider(data);
      addTearDown(provider.dispose);
      const target = AgendaTarget(
        sourceType: AgendaSourceType.course,
        timetableId: 'table',
        courseId: 'course',
        dateIso: '2026-08-03',
      );

      expect(
        await AgendaActionRouter(provider: provider)
            .route(const AgendaAction(target: target)),
        isTrue,
      );
      expect(provider.activeTimetableOrNull?.id, 'table');
      expect(provider.activeMode, AppMode.student);
    },
  );

  test(
    'routes a live general occurrence but does not resolve hidden targets',
    () async {
      final data = _dataWithGeneralEvent();
      final target = const AgendaProjectionService()
          .occurrencesForRange(
            data,
            startInclusive: DateTime(2026, 8, 3),
            endExclusive: DateTime(2026, 8, 4),
          )
          .singleWhere(
            (item) => item.sourceType == AgendaSourceType.generalEvent,
          )
          .target;
      final provider = await _loadProvider(data);
      addTearDown(provider.dispose);
      AgendaTarget? opened;
      final router = AgendaActionRouter(
        provider: provider,
        onTarget: (value) async => opened = value,
      );

      expect(await router.route(AgendaAction(target: target)), isTrue);
      expect(provider.activeMode, AppMode.general);
      expect(provider.selectedGeneralDate, DateTime(2026, 8, 3));
      expect(opened, target);

      final hiddenProvider = await _loadProvider(
        _dataWithGeneralEvent(isVisible: false),
      );
      addTearDown(hiddenProvider.dispose);
      final hiddenRouter = AgendaActionRouter(provider: hiddenProvider);
      expect(await hiddenRouter.route(AgendaAction(target: target)), isFalse);
      expect(hiddenProvider.activeMode, AppMode.student);
    },
  );

  test(
    'rejects malformed general occurrence targets and unknown sources',
    () async {
      final provider = await _loadProvider(_dataWithGeneralEvent());
      addTearDown(provider.dispose);
      final router = AgendaActionRouter(provider: provider);

      expect(
        await router.route(
          const AgendaAction(
            target: AgendaTarget(
              sourceType: AgendaSourceType.generalEvent,
              calendarId: 'calendar',
              eventId: 'event',
              occurrenceKey: 'occurrence-without-date',
            ),
          ),
        ),
        isFalse,
      );
      expect(
        await router.route(
          const AgendaAction(
            target: AgendaTarget(
              sourceType: AgendaSourceType.generalEvent,
              calendarId: 'calendar',
              eventId: 'event',
              dateIso: 'not-a-date',
            ),
          ),
        ),
        isFalse,
      );
      expect(
        await router.route(
          const AgendaAction(target: AgendaTarget(sourceType: 'future-source')),
        ),
        isFalse,
      );
    },
  );

  test(
    'registered source handlers route custom targets without a source switch',
    () async {
      final provider = await _loadProvider(_dataWithCourse());
      addTearDown(provider.dispose);
      AgendaTarget? handled;
      final router = AgendaActionRouter(
        provider: provider,
        sourceHandlers: {'exam': (target) async => handled = target},
      );
      const target = AgendaTarget(sourceType: 'exam', eventId: 'exam-1');

      expect(
        await router.routePayload(jsonEncode({'target': target.toJson()})),
        isTrue,
      );
      expect(handled, target);
    },
  );

  test(
    'platform payload delivery is de-duplicated and malformed data is ignored',
    () async {
      final provider = await _loadProvider(_dataWithCourse());
      addTearDown(provider.dispose);
      var current = DateTime(2026, 8, 3, 7);
      final opened = <AgendaTarget>[];
      final router = AgendaActionRouter(
        provider: provider,
        clock: () => current,
        onTarget: (target) async => opened.add(target),
      );
      const target = AgendaTarget(
        sourceType: AgendaSourceType.course,
        timetableId: 'table',
        courseId: 'course',
        dateIso: '2026-08-03',
      );
      final payload = AgendaNotificationPayload(
        key: 'route-once',
        fireAt: current,
        target: target,
      ).encode();

      expect(await router.routePayload(payload), isTrue);
      expect(await router.routePayload(payload), isFalse);
      expect(opened, [target]);
      expect(await router.routePayload('not-json'), isFalse);
      expect(
        await router.routePayload('$agendaNotificationPayloadPrefix{bad-json}'),
        isFalse,
      );

      current = current.add(const Duration(seconds: 3));
      expect(await router.routePayload(payload), isTrue);
      expect(opened, [target, target]);
    },
  );

  test(
    'platform payload errors are contained without invoking navigation',
    () async {
      final provider = await _loadProvider(_dataWithCourse());
      addTearDown(provider.dispose);
      final router = AgendaActionRouter(
        provider: provider,
        sourceHandlers: {
          'failing-source': (_) async => throw StateError('synthetic failure'),
        },
      );
      const target = AgendaTarget(
        sourceType: 'failing-source',
        eventId: 'event',
      );

      expect(
        await router.routePayload(jsonEncode({'target': target.toJson()})),
        isFalse,
      );
      expect(provider.activeMode, AppMode.general);
    },
  );
}
