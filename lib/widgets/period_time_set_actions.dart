import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../controllers/app_data_maintenance.dart';
import '../controllers/student_commands.dart';
import '../controllers/student_view_state.dart';
import '../controllers/workspace_commands.dart';
import '../controllers/workspace_view_state.dart';
import '../l10n/app_localizations.dart';
import '../models/timetable_models.dart';
import '../services/export_service.dart';
import 'desktop_context_menu.dart';
import 'export_save_flow.dart';
import 'expressive_dialog.dart';
import 'sked_mutation_confirmation_dialog.dart';
import 'sked_task_session.dart';
import 'text_transfer_widgets.dart';
import 'ui_command.dart';

enum PeriodTimeSetAction { share, saveFile, exportText, delete }

/// The open editor owns its draft flush before a collection action can run.
class PeriodTimeSetActionController {
  Object? _owner;
  String? _editingId;
  Future<void> Function(Future<void> Function())? _run;

  String? get editingId => _editingId;

  void attach(
    Object owner,
    String id,
    Future<void> Function(Future<void> Function()) run,
  ) {
    _owner = owner;
    _editingId = id;
    _run = run;
  }

  void detach(Object owner) {
    if (!identical(_owner, owner)) return;
    _owner = null;
    _editingId = null;
    _run = null;
  }

  Future<void> run(Future<void> Function() action) =>
      _run?.call(action) ?? action();
}

List<DesktopAction> periodTimeSetDesktopActions({
  required BuildContext context,
  required DesktopActionContext invocation,
  required bool enabled,
  required FutureOr<void> Function() onEdit,
  required Future<void> Function(PeriodTimeSetAction) onAction,
}) {
  final l = AppLocalizations.of(context);
  final available = enabled && invocation.isCurrent();
  DesktopAction action(
    PeriodTimeSetAction action,
    String label,
    IconData icon,
  ) => DesktopAction(
    id: 'period-time-set.${action.name}',
    label: label,
    icon: icon,
    shortcut: action == PeriodTimeSetAction.delete
        ? LogicalKeyboardKey.delete
        : null,
    enabled: available,
    onInvoke: () => onAction(action),
  );
  return [
    DesktopAction(
      id: 'period-time-set.edit',
      label: l.editPeriodTimeSet,
      icon: Icons.edit_outlined,
      shortcut: LogicalKeyboardKey.f2,
      enabled: available,
      onInvoke: onEdit,
    ),
    action(
      PeriodTimeSetAction.share,
      l.sharePeriodTemplate,
      Icons.share_outlined,
    ),
    action(PeriodTimeSetAction.saveFile, l.saveTemplateToFile, Icons.save_alt),
    action(
      PeriodTimeSetAction.exportText,
      l.exportPeriodTemplateText,
      Icons.code,
    ),
    action(
      PeriodTimeSetAction.delete,
      l.deletePeriodTimeSet,
      Icons.delete_outline,
    ),
  ];
}

/// Executes against one explicit stored ID. The accepted action owns its result,
/// including a draft flush that replaces the original row's value.
Future<bool> runPeriodTimeSetAction({
  required BuildContext context,
  required PeriodTimeSet target,
  required PeriodTimeSetAction action,
  required bool Function() isOwnerCurrent,
  DesktopActionContext? invocation,
  PeriodTimeSetActionController? controller,
  ExportService exportService = const ExportService(),
}) async {
  if (!context.mounted || invocation?.isCurrent() == false) return false;
  final student = context.read<StudentViewState>();
  if (!identical(student.periodTimeSetForId(target.id), target)) return false;
  final commands = context.read<StudentCommands>();
  final route = ModalRoute.of(context);
  final refreshAfterFlush = controller?.editingId == target.id;
  PeriodTimeSet? accepted;
  var submitted = false;
  var mutating = false;
  var completed = false;
  final session = SkedTaskSession(
    maintenance: context.read<AppDataMaintenance>(),
    workspaceView: context.read<WorkspaceViewState>(),
    workspaces: context.read<WorkspaceCommands>(),
    workspace: AppMode.student,
    ownerRoute: route,
    parent: SkedTaskSessionScope.maybeOf(context)?.session,
    targetChanges: student,
    isOwnerActive: () => context.mounted && isOwnerCurrent(),
    isTargetCurrent: () {
      if (mutating || completed) return true;
      final live = student.periodTimeSetForId(target.id);
      if (live == null) return false;
      return submitted || accepted == null || identical(live, accepted);
    },
  );
  try {
    Future<void> perform() async {
      if (!session.isCurrent) return;
      final live = student.periodTimeSetForId(target.id);
      if (live == null || (!refreshAfterFlush && !identical(live, target))) {
        return;
      }
      accepted = live;
      if (!context.mounted || !session.isCurrent) return;
      final payload = ExportPayload(
        fileName: 'Sked_period_times.json',
        content: encodePeriodTimesEnvelope(live.periodTimes),
      );
      switch (action) {
        case PeriodTimeSetAction.share:
          await exportService.shareFile(payload);
        case PeriodTimeSetAction.saveFile:
          await saveExportWithFeedback(
            context: context,
            service: exportService,
            payload: payload,
            isCurrent: () => session.isCurrent,
          );
        case PeriodTimeSetAction.exportText:
          await showTextExportDialog(
            context,
            title: AppLocalizations.of(context).exportPeriodTemplateText,
            content: payload.content,
          );
        case PeriodTimeSetAction.delete:
          final l = AppLocalizations.of(context);
          String? refusal;
          await showExpressiveDialog<bool>(
            context: context,
            session: session,
            builder: (_) => SkedMutationConfirmationDialog(
              workspace: AppMode.student,
              title: l.deletePeriodTimeSetTitle,
              message: l.deletePeriodTimeSetMessage(live.name),
              confirmLabel: l.delete,
              debugLabel: 'Delete period time set',
              onConfirm: () async {
                if (!session.isCurrent) {
                  throw StateError('The period time set is no longer current.');
                }
                submitted = true;
                mutating = true;
                try {
                  await commands.deletePeriodTimeSet(target.id);
                  completed = true;
                } on FormatException catch (error) {
                  refusal = error.message;
                } finally {
                  mutating = false;
                }
              },
            ),
          );
          if (context.mounted && session.isCurrent && refusal != null) {
            showUiFailureFeedback(context: context, message: refusal!);
          }
      }
    }

    if (controller == null) {
      await perform();
    } else {
      await controller.run(perform);
    }
    return completed;
  } finally {
    session.dispose();
  }
}
