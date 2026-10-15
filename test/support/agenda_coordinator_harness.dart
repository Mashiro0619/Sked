import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/services/agenda_action_router.dart';
import 'package:sked/services/agenda_coordinator.dart';
import 'package:sked/services/agenda_notification_service.dart';
import 'package:sked/services/agenda_projection_service.dart';
import 'package:sked/services/android_productivity_bridge.dart';

/// Composes the same domain instances for notification and UI behavior tests.
AgendaCoordinator buildTestAgendaCoordinator({
  required TimetableProvider provider,
  AgendaNotificationService? notificationService,
  AgendaProjectionService? projection,
  AgendaActionRouter? actionRouter,
  AgendaTargetCallback? onTarget,
  AndroidProductivityBridge? productivityBridge,
  DateTime Function()? clock,
  Duration startupTimeout = const Duration(seconds: 15),
  void Function(Object error, StackTrace stackTrace)? onError,
}) => AgendaCoordinator(
  session: provider.session,
  dataClear: provider.dataClear,
  general: provider.generalView,
  generalCommands: provider.generalCommands,
  settings: provider.settingsView,
  actionRouter:
      actionRouter ??
      AgendaActionRouter(
        workspace: provider.workspaceView,
        workspaces: provider.workspaces,
        student: provider.studentView,
        studentCommands: provider.studentCommands,
        general: provider.generalView,
        generalNavigation: provider.generalNavigation,
        settings: provider.settingsView,
        onTarget: onTarget,
        projection: projection,
      ),
  notificationService: notificationService,
  projection: projection,
  productivityBridge: productivityBridge,
  clock: clock,
  startupTimeout: startupTimeout,
  onError: onError,
);
