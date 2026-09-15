import 'dart:convert';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/agenda_notification_runtime_store.dart';
import 'package:sked/services/agenda_notification_service.dart';
import 'package:sked/services/agenda_projection_service.dart';
import 'package:sked/services/windows_notification_backend.dart';
import 'package:sked/services/notification_planner.dart';
import 'package:timezone/timezone.dart' as tz;

/// Never shares production AUMID, runtime preferences, ids or activation GUID.
class IsolatedWindowsBackend extends FlutterAgendaWindowsNotificationBackend {
  IsolatedWindowsBackend();
  int scheduleCalls = 0;
  @override
  Future<bool> initialize({
    required WindowsInitializationSettings settings,
    required DidReceiveNotificationResponseCallback onResponse,
  }) => super.initialize(
    settings: const WindowsInitializationSettings(
      appName: 'Sked notification QA',
      appUserModelId: 'Mashiro.Sked.NotificationQA',
      guid: '8cd4074a-c9c5-4d31-a9d3-afec84fa25ee',
    ),
    onResponse: onResponse,
  );
  @override
  Future<void> zonedSchedule({
    required int id,
    String? title,
    String? body,
    required tz.TZDateTime scheduledDate,
    String? payload,
    WindowsNotificationDetails? notificationDetails,
  }) async {
    scheduleCalls++;
    await super.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      payload: payload,
      notificationDetails: notificationDetails,
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'isolated unpackaged Windows queue removes duplicate schedules and never replays after due',
    (t) async {
      expect(
        MsixUtils.hasPackageIdentity(),
        isFalse,
        reason: 'This isolated AUMID test must run unpackaged, not under a production package identity.',
      );
      SharedPreferences.setMockInitialValues({});
      final backend = IsolatedWindowsBackend();
      final runtime = SharedPreferencesAgendaNotificationRuntimeStore();
      final gateway = FlutterAgendaNotificationGateway(
        windowsBackend: backend,
        runtimeStore: runtime,
      );
      final fireAt = DateTime.now().add(const Duration(seconds: 35));
      final occurrence = AgendaOccurrence(
        stableId: 'native-queue-probe',
        sourceType: 'test',
        start: fireAt.add(const Duration(minutes: 5)),
        end: fireAt.add(const Duration(minutes: 65)),
        title: 'Sked isolated notification test',
        target: const AgendaTarget(sourceType: 'test'),
        reminders: const [AgendaReminder(minutesBefore: 5)],
      );
      final projection = AgendaProjectionService(
        registry: AgendaSourceRegistry(
          sources: [
            CallbackAgendaSource(id: 'test', builder: (_, _) => [occurrence]),
          ],
        ),
      );
      final data = buildInitialAppData(buildDefaultPeriodTimes()).copyWith(
        notificationSettings: const NotificationSettings(enabled: true),
      );
      var service = AgendaNotificationService(
        enabled: true,
        gateway: gateway,
        runtimeStore: runtime,
        projection: projection,
      );
      final ids = <int>{};
      final report = <String, Object?>{
        'evidence': 'Real Windows OS pending-toast queue. Registration calls are not proof of visible banner delivery.',
        'hasPackageIdentity': MsixUtils.hasPackageIdentity(),
        'isolation': 'Mashiro.Sked.NotificationQA; test-only preferences',
        'observedBannerCount': null,
        'bannerAcceptance': 'manual verification still required',
      };
      try {
        await gateway.initialize(onTap: (_) {});
        ids.add(
          notificationIdForKey(
            buildNotificationPlanKey('test', occurrence.stableId, 5),
          ),
        );
        ids.add(2000000207);
        for (final id in ids) {
          await cancelWindowsNotificationCopies(backend, id);
        }
        await service.reconcile(data);
        final first = await backend.pendingNotificationRequests();
        final owned = first.single.id;
        ids.add(owned);
        const other = 2000000207;
        ids.add(other);
        for (var i = 0; i < 2; i++) {
          await backend.zonedSchedule(
            id: owned,
            title: 'Sked duplicate queue probe',
            scheduledDate: tz.TZDateTime.from(fireAt, tz.local),
          );
        }
        await backend.zonedSchedule(
          id: other,
          title: 'Sked independent test',
          scheduledDate: tz.TZDateTime.from(
            fireAt.add(const Duration(minutes: 5)),
            tz.local,
          ),
        );
        final before = await backend.pendingNotificationRequests();
        expect(before.where((item) => item.id == owned), hasLength(3));
        report['beforeManagedCopies'] = 3;
        await service.reconcile(data);
        final after = await backend.pendingNotificationRequests();
        expect(after.where((item) => item.id == owned), hasLength(1));
        expect(after.where((item) => item.id == other), hasLength(1));
        report['afterManagedCopies'] = 1;
        report['independentRequestRetained'] = true;
        final callsBeforeDue = backend.scheduleCalls;
        final wait = fireAt
            .add(const Duration(seconds: 6))
            .difference(DateTime.now());
        if (wait > Duration.zero) await Future<void>.delayed(wait);
        final afterDue = await backend.pendingNotificationRequests();
        expect(afterDue.where((item) => item.id == owned), isEmpty);
        service.dispose();
        service = AgendaNotificationService(
          enabled: true,
          gateway: gateway,
          runtimeStore: SharedPreferencesAgendaNotificationRuntimeStore(),
          projection: projection,
        );
        for (var i = 0; i < 3; i++) {
          await service.reconcile(
            data,
            mode: AgendaNotificationReconcileMode.recovery,
          );
        }
        await service.reconcile(data);
        expect(backend.scheduleCalls, callsBeforeDue);
        report['newRegistrationsAfterDueAndRecreation'] = 0;
        report['pendingRemovedByOSAfterDue'] = true;
        report['result'] = 'PASS';
      } catch (error) {
        report['result'] = 'FAIL';
        report['error'] = error.toString();
        rethrow;
      } finally {
        service.dispose();
        for (final id in ids) {
          await cancelWindowsNotificationCopies(backend, id);
        }
        final out = Directory('.scratch/notification-native-windows');
        await out.create(recursive: true);
        await File('${out.path}/queue-report.json')
            .writeAsString(const JsonEncoder.withIndent('  ').convert(report));
      }
    },
    skip:
        !Platform.isWindows ||
        !const bool.fromEnvironment('SKED_NOTIFICATION_NATIVE_TEST'),
  );
}
