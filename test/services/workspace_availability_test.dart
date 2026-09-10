import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/models/workspace_availability.dart';
import 'package:sked/services/agenda_action_router.dart';
import 'package:sked/services/agenda_notification_service.dart';
import 'package:sked/services/agenda_notification_runtime_store.dart';
import 'package:sked/services/agenda_projection_service.dart';
import 'package:sked/services/developer_sample_data_service.dart';
import 'package:sked/services/notification_planner.dart';

import '../support/workspace_harness.dart';

AppData _sample() =>
    DeveloperSampleDataService.append(
      current: buildInitialAppData(buildDefaultPeriodTimes()),
      language: DeveloperSampleLanguage.english,
      now: DateTime(2026, 9, 8),
    ).data.copyWith(
      notificationSettings: const NotificationSettings(
        enabled: true,
        courseDefaultMinutesBefore: 10,
      ),
    );

class _FailingCleanupGateway extends MemoryAgendaNotificationGateway {
  bool fail = false;
  @override
  Future<void> cancel(String key) async {
    if (fail) throw StateError('platform cancellation failed');
    await super.cancel(key);
  }

  @override
  Future<void> cancelNotificationId(int id, {String? tag}) async {
    if (fail) throw StateError('platform cancellation failed');
    await super.cancelNotificationId(id, tag: tag);
  }
}

void main() {
  test(
    'failed platform cleanup remains retryable without re-enabling a domain',
    () async {
      final data = _sample();
      final gateway = _FailingCleanupGateway();
      final service = AgendaNotificationService(
        gateway: gateway,
        runtimeStore: MemoryAgendaNotificationRuntimeStore(),
        enabled: true,
        now: () => DateTime(2026, 9, 7, 6),
      );
      addTearDown(service.dispose);
      await service.reconcile(data);
      expect(
        gateway.scheduled.values.any(
          (r) => r.occurrence.sourceType == AgendaSourceType.course,
        ),
        isTrue,
      );
      final disabled = data.copyWith(
        activeMode: AppMode.general,
        enabledWorkspaces: {AppMode.general},
      );
      gateway.fail = true;
      await expectLater(service.reconcile(disabled), throwsStateError);
      expect(service.status.lastError, isNotNull);
      expect(disabled.enabledWorkspaces, {AppMode.general});
      gateway.fail = false;
      await service.reconcile(disabled);
      expect(service.status.lastError, isNull);
      expect(
        gateway.scheduled.values.any(
          (r) => r.occurrence.sourceType == AgendaSourceType.course,
        ),
        isFalse,
      );
    },
  );

  TestWidgetsFlutterBinding.ensureInitialized();
  const projection = AgendaProjectionService();
  final now = DateTime(2026, 9, 7, 6);
  for (final mode in AppMode.values) {
    test(
      'only ${mode.name} contributes to projections and direct source adapters',
      () {
        final data = _sample().copyWith(
          activeMode: mode,
          enabledWorkspaces: {mode},
        );
        final occurrences = projection.project(
          data,
          startInclusive: now,
          endExclusive: now.add(const Duration(days: 7)),
        );
        expect(occurrences, isNotEmpty);
        expect(
          occurrences.every(
            (item) => workspaceForAgendaSource(item.sourceType) == mode,
          ),
          isTrue,
        );
        final source = mode == AppMode.general
            ? const StudentAgendaSource()
            : const GeneralAgendaSource();
        expect(
          source.occurrences(
            data,
            AgendaProjectionQuery(
              startInclusive: now,
              endExclusive: now.add(const Duration(days: 7)),
            ),
          ),
          isEmpty,
        );
      },
    );
  }
  test('re-enable retains schedule data but excludes reminders from the disabled interval', () {
    final base = _sample();
    final before = projection.project(
      base,
      startInclusive: now,
      endExclusive: now.add(const Duration(days: 7)),
    );
    final first = before.firstWhere(
      (item) =>
          item.sourceType == AgendaSourceType.course &&
          item.reminders.isNotEmpty,
    );
    final boundary = first.start.add(const Duration(minutes: 1));
    final data = base.copyWith(
      workspaceReminderNotBefore: {AppMode.student: boundary.toUtc()},
    );
    final after = projection.project(
      data,
      startInclusive: now,
      endExclusive: now.add(const Duration(days: 7)),
    );
    expect(after.length, before.length);
    expect(
      after.firstWhere((item) => item.stableId == first.stableId).reminders,
      isEmpty,
    );
    expect(
      after
          .where((item) => item.sourceType == AgendaSourceType.course)
          .expand((item) => item.reminders.map((r) => r.fireAt(item.start))),
      everyElement(
        isA<DateTime>().having(
          (date) => date.isBefore(boundary),
          'pre-enable reminder',
          false,
        ),
      ),
    );
  });
  test('recovery cancels disabled-domain notifications even after permission is revoked', () async {
    final data = _sample();
    final gateway = MemoryAgendaNotificationGateway();
    final runtime = MemoryAgendaNotificationRuntimeStore();
    final service = AgendaNotificationService(
      gateway: gateway,
      runtimeStore: runtime,
      enabled: true,
      now: () => now,
    );
    addTearDown(service.dispose);
    await service.reconcile(data);
    expect(
      gateway.scheduled.values.any(
        (request) => request.occurrence.sourceType == AgendaSourceType.course,
      ),
      isTrue,
    );
    final course = gateway.scheduled.values.firstWhere(
      (request) => request.occurrence.sourceType == AgendaSourceType.course,
    );
    await service.handleAction(course.payload, 'snooze_10m');
    expect(runtime.snoozes, isNotEmpty);
    gateway.permissionGranted = false;
    final disabled = data.copyWith(
      activeMode: AppMode.general,
      enabledWorkspaces: {AppMode.general},
    );
    await service.reconcile(
      disabled,
      mode: AgendaNotificationReconcileMode.recovery,
    );
    expect(
      gateway.scheduled.keys.where(
        (key) =>
            parseNotificationPlanKey(key)?.sourceType ==
            AgendaSourceType.course,
      ),
      isEmpty,
    );
    expect(
      runtime.snoozes.keys.where((key) => key.startsWith('course|')),
      isEmpty,
    );
  });
  test(
    'a stale action cannot snooze or navigate into a disabled workspace',
    () async {
      final data = _sample();
      final provider = await workspaceProvider(
        storage: WorkspaceMemoryStorage(data),
      );
      addTearDown(provider.dispose);
      final gateway = MemoryAgendaNotificationGateway();
      final runtime = MemoryAgendaNotificationRuntimeStore();
      final service = AgendaNotificationService(
        gateway: gateway,
        runtimeStore: runtime,
        enabled: true,
        now: () => now,
      )..committedDataReader = () => provider.committedAppData;
      addTearDown(service.dispose);
      await service.reconcile(data);
      final request = gateway.scheduled.values.firstWhere(
        (item) => item.occurrence.sourceType == AgendaSourceType.course,
      );
      await provider.setWorkspaceEnabled(AppMode.student, false);
      await service.handleAction(request.payload, 'snooze_10m');
      expect(runtime.snoozes, isEmpty);
      final router = AgendaActionRouter(provider: provider);
      expect(
        await router.route(AgendaAction(target: request.occurrence.target)),
        isFalse,
      );
      expect(provider.activeMode, AppMode.general);
      await service.reconcile(
        data,
      ); // Even an explicitly queued old snapshot is fenced.
      expect(
        gateway.scheduled.values.every(
          (r) => r.occurrence.sourceType != AgendaSourceType.course,
        ),
        isTrue,
      );
    },
  );
  test(
    'disabled unbounded calendars do not cause background renewal work',
    () async {
      final base = _sample();
      final recurring = GeneralEvent(
        id: 'repeat',
        calendarId: 'repeat-cal',
        title: 'Hidden',
        startDateTimeIso: '2026-09-07T12:00:00.000',
        endDateTimeIso: '2026-09-07T13:00:00.000',
        recurrenceRule: const GeneralEventRecurrenceRule(
          type: GeneralEventRecurrence.daily,
        ),
        reminders: const [GeneralEventReminder(minutesBefore: 0)],
      );
      final data = base.copyWith(
        activeMode: AppMode.student,
        enabledWorkspaces: {AppMode.student},
        generalMode: base.generalMode.copyWith(
          schedules: [
            GeneralSchedule(
              id: 'repeat-cal',
              name: 'Hidden',
              events: [recurring],
            ),
          ],
        ),
      );
      final service = AgendaNotificationService(
        gateway: MemoryAgendaNotificationGateway(),
        runtimeStore: MemoryAgendaNotificationRuntimeStore(),
        enabled: true,
        now: () => now,
      );
      addTearDown(service.dispose);
      final status = await service.reconcile(data);
      expect(status.hasUnboundedRecurrence, isFalse);
      expect(status.nextRenewalAt, isNull);
    },
  );
}
