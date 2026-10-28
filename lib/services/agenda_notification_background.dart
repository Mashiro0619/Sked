import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/workspace_availability.dart';
import 'agenda_background_data.dart';
import 'agenda_notification_contract.dart';
import 'agenda_notification_identity.dart';
import 'agenda_notification_payload.dart';
import 'agenda_notification_presentation.dart';
import 'agenda_notification_runtime_actions.dart';
import 'agenda_notification_runtime_store.dart';
import 'agenda_runtime_mutation_lock.dart';

Future<void> handleAgendaNotificationBackgroundAction(
  NotificationResponse response, {
  required AgendaBackgroundDataLoader loadData,
  required void Function(NotificationResponse) backgroundCallback,
}) async {
  if (response.notificationResponseType ==
      NotificationResponseType.notificationDismissed) {
    return;
  }
  final actionId = response.actionId?.trim();
  final payload = response.payload?.trim();
  final decoded = payload == null
      ? null
      : AgendaNotificationPayload.tryDecode(payload);
  if (actionId == null ||
      payload == null ||
      payload.isEmpty ||
      !backgroundNotificationActionIds.contains(actionId) ||
      decoded == null ||
      !agendaNotificationPayloadHasRuntimeIdentity(decoded)) {
    return;
  }
  try {
    await withAgendaRuntimeMutationLock(() async {
      final snapshot = await loadData();
      if (!snapshot.canWrite ||
          snapshot.data == null ||
          !snapshot.data!.allowsAgendaSource(decoded.target.sourceType)) {
        return;
      }
      await _persistBackgroundNotificationAction(
        decoded,
        payload,
        actionId,
        backgroundCallback: backgroundCallback,
      );
    });
  } catch (error, stackTrace) {
    debugPrint(
      'Checking background workspace availability failed: $error\n$stackTrace',
    );
  }
}

Future<void> _persistBackgroundNotificationAction(
  AgendaNotificationPayload decoded,
  String payload,
  String actionId, {
  required void Function(NotificationResponse) backgroundCallback,
}) async {
  try {
    final store = SharedPreferencesAgendaNotificationRuntimeStore();
    final runtimeFence = await store.captureWritableRuntimeFence();
    if (runtimeFence == null) {
      // A data clear has started. Do not let a late background isolate revive
      // snooze/handled/action state after the foreground has removed it.
      return;
    }
    switch (actionId) {
      case 'snooze_10m':
        final current = DateTime.now();
        final request = await store.readBackgroundRequestForRuntimeFence(
          decoded.key,
          runtimeFence,
        );
        final scheduledPayload = request == null
            ? null
            : AgendaNotificationPayload.tryDecode(request.payload);
        // A current background request with a different revision means this
        // card predates an edit. It must not recreate a snooze for the new
        // occurrence just because planner keys intentionally remain stable.
        if (request != null &&
            (scheduledPayload == null ||
                !agendaNotificationPayloadMatchesScheduledRequest(
                  action: decoded,
                  scheduled: scheduledPayload,
                ))) {
          return;
        }
        final runtimeKey = agendaRuntimeKeyForPayload(decoded);
        if (runtimeKey == null) return;
        final fireAt = await resolveAgendaSnoozeFireAt(
          store,
          runtimeFence,
          decoded,
          current,
        );
        if (fireAt == null || !fireAt.isAfter(current)) return;
        await store.setSnoozeForRuntimeFence(
          agendaSnoozeRuntimeKey(runtimeKey, decoded.key),
          fireAt,
          runtimeFence,
        );
        if (request != null &&
            scheduledPayload != null &&
            await store.isRuntimeFenceCurrent(runtimeFence) &&
            await _scheduleBackgroundSnooze(
              backgroundCallback: backgroundCallback,
              request: request,
              payload: scheduledPayload,
              fireAt: fireAt,
              registrationStore: store,
              registrationFence: runtimeFence,
              isRuntimeFenceCurrent: () =>
                  store.isRuntimeFenceCurrent(runtimeFence),
              saveRequest: (updatedRequest) =>
                  store.saveBackgroundRequestForRuntimeFence(
                    updatedRequest,
                    runtimeFence,
                  ),
            )) {
          return;
        }
        if (!await store.isRuntimeFenceCurrent(runtimeFence)) return;
        // Retain a fallback action if the platform plugin could not schedule
        // from this short-lived isolate. A later headless/foreground pass can
        // still recover the snooze from its durable runtime state.
        await store.enqueueActionForRuntimeFence(
          payload: payload,
          actionId: actionId,
          fence: runtimeFence,
        );
        return;
      case 'handled':
        final runtimeKey = agendaRuntimeKeyForPayload(decoded);
        if (runtimeKey == null) return;
        await store.addHandledOccurrenceForRuntimeFence(
          runtimeKey,
          runtimeFence,
        );
        if (!await store.isRuntimeFenceCurrent(runtimeFence)) return;
        // General-event acknowledgement is provider-owned, so preserve the
        // action for the next projection even though device notification
        // suppression has already completed here.
        await store.enqueueActionForRuntimeFence(
          payload: payload,
          actionId: actionId,
          fence: runtimeFence,
        );
        return;
    }
  } catch (error, stackTrace) {
    // A background action must never crash the callback dispatcher. The
    // notification remains visible and can be acted on again if persistence
    // was interrupted by the OS.
    debugPrint(
      'Persisting background notification action failed: '
      '$error\n$stackTrace',
    );
  }
}

Future<bool> _scheduleBackgroundSnooze({
  required void Function(NotificationResponse) backgroundCallback,
  required AgendaNotificationBackgroundRequest request,
  required AgendaNotificationPayload payload,
  required DateTime fireAt,
  required AgendaNotificationRegistrationStore registrationStore,
  required AgendaNotificationProjectionFence registrationFence,
  required Future<bool> Function() isRuntimeFenceCurrent,
  required Future<void> Function(AgendaNotificationBackgroundRequest request)
  saveRequest,
}) async {
  AgendaNotificationRegistration? claim;
  try {
    if (!await isRuntimeFenceCurrent()) return false;
    final snapshot = await registrationStore.readRegistrationSnapshot(
      registrationFence,
      now: DateTime.now(),
    );
    final prior = snapshot.forReminder(request.key, fireAt);
    if (prior != null &&
        prior.state != AgendaNotificationRegistrationState.rejected) {
      return true;
    }
    tz_data.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
    final plugin = FlutterLocalNotificationsPlugin();
    final initialized = await withAgendaRuntimeMutationLock(
      () => plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_notification'),
        ),
        onDidReceiveBackgroundNotificationResponse: backgroundCallback,
      ),
    );
    if (initialized != true) return false;
    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null ||
        !await _backgroundExactDeliveryAllowed(
          android,
          channelId: request.channelId ?? 'sked_agenda_reminders',
        )) {
      return false;
    }
    final copy = notificationText(request.localeCode);
    var updatedPayload = payload.copyWith(fireAt: fireAt).encode();
    final channelId = request.channelId ?? 'sked_agenda_reminders';
    final channelName = request.channelName ?? 'Sked reminders';
    final channelDescription =
        request.channelDescription ?? 'Sked agenda reminders';
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: 'ic_stat_notification',
        autoCancel: true,
        tag: agendaNotificationTag(payload.key),
        visibility: request.lockScreenShowTitles
            ? NotificationVisibility.public
            : NotificationVisibility.private,
        actions: [
          AndroidNotificationAction(
            'snooze_10m',
            copy.snoozeAction,
            showsUserInterface: false,
          ),
          AndroidNotificationAction(
            'handled',
            copy.handledAction,
            showsUserInterface: false,
          ),
        ],
      ),
    );
    updatedPayload = payload
        .copyWith(fireAt: fireAt, scheduleExact: true)
        .encode();
    claim = AgendaNotificationRegistration(
      key: request.key,
      originalFireAt: fireAt,
      fireAt: fireAt,
      recordedAt: DateTime.now(),
      notificationId: request.notificationId,
      state: AgendaNotificationRegistrationState.pending,
      kind: AgendaNotificationRegistrationKind.snooze,
    );
    if (!await registrationStore.writeRegistration(claim, registrationFence)) {
      return false;
    }
    await withAgendaRuntimeMutationLock(
      () => plugin.zonedSchedule(
        id: request.notificationId,
        title: request.title,
        body: request.body,
        notificationDetails: details,
        scheduledDate: tz.TZDateTime.from(fireAt.toLocal(), tz.local),
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        payload: updatedPayload,
      ),
    );
    if (!await isRuntimeFenceCurrent()) {
      await withAgendaRuntimeMutationLock(
        () => plugin.cancel(
          id: request.notificationId,
          tag: payload.hasStableTag ? agendaNotificationTag(request.key) : null,
        ),
      );
      return false;
    }
    await registrationStore.writeRegistration(
      claim.copyWith(state: AgendaNotificationRegistrationState.accepted),
      registrationFence,
    );
    await saveRequest(
      request.copyWith(payload: updatedPayload, fireAt: fireAt),
    );
    if (!await isRuntimeFenceCurrent()) {
      await withAgendaRuntimeMutationLock(
        () => plugin.cancel(
          id: request.notificationId,
          tag: payload.hasStableTag ? agendaNotificationTag(request.key) : null,
        ),
      );
      return false;
    }
    return true;
  } catch (error, stackTrace) {
    if (claim != null &&
        error is PlatformException &&
        error.code == agendaExactAlarmPermissionErrorCode) {
      try {
        await registrationStore.writeRegistration(
          claim.copyWith(state: AgendaNotificationRegistrationState.rejected),
          registrationFence,
        );
      } catch (_) {
        /* Keep ambiguous evidence if recording rejection failed. */
      }
    }
    debugPrint(
      'Scheduling background notification snooze failed: '
      '$error\n$stackTrace',
    );
    return false;
  }
}

Future<bool> _backgroundExactDeliveryAllowed(
  AndroidFlutterLocalNotificationsPlugin android, {
  required String channelId,
}) async {
  try {
    if (await android.areNotificationsEnabled() != true ||
        await android.canScheduleExactNotifications() != true) {
      return false;
    }
    final channels = await android.getNotificationChannels();
    AndroidNotificationChannel? channel;
    for (final item in channels ?? const <AndroidNotificationChannel>[]) {
      if (item.id == channelId) {
        channel = item;
        break;
      }
    }
    return channel == null || channel.importance != Importance.none;
  } on PlatformException {
    return false;
  } on MissingPluginException {
    return false;
  }
}
