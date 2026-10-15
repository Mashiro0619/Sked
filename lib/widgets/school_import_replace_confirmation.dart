import 'sked_confirmation_dialog.dart';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/app_mode.dart';
import '../controllers/app_data_maintenance.dart';
import '../controllers/student_view_state.dart';
import '../controllers/workspace_commands.dart';
import '../controllers/workspace_view_state.dart';
import 'expressive_dialog.dart';
import 'sked_task_route.dart';
import 'sked_task_session.dart';

/// Confirms replacement only while the original data and target remain current.
/// The caller keeps its submission gate closed until the dialog finishes exiting.
Future<bool> confirmSchoolImportReplacement(BuildContext context) async {
  if (!context.mounted) return false;
  final student = context.read<StudentViewState?>();
  final replacementId = student?.activeTimetableOrNull?.id;
  final session = SkedTaskSession(
    maintenance: context.read<AppDataMaintenance?>(),
    workspaceView: context.read<WorkspaceViewState?>(),
    workspaces: context.read<WorkspaceCommands?>(),
    targetChanges: student,
    workspace: AppMode.student,
    parent: SkedTaskSessionScope.maybeOf(context)?.session,
    ownerRoute: ModalRoute.of(context),
    isOwnerActive: () => context.mounted,
    isTargetCurrent: () => replacementId == student?.activeTimetableOrNull?.id,
  );
  var completed = false;
  try {
    final confirmed = await showExpressiveDialog<bool>(
      context: context,
      session: session,
      barrierDismissible: false,
      waitForTransitionComplete: true,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext);
        void finish(bool result) {
          if (completed || !session.isCurrent) return;
          completed = true;
          completeSkedTaskRoute(dialogContext, result);
        }

        return SkedConfirmationDialog(
          title: Text(l10n.replaceCurrentTimetableConfirmTitle),
          content: Text(l10n.replaceCurrentTimetableConfirmMessage),
          actions: [
            TextButton(
              onPressed: () => finish(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => finish(true),
              child: Text(l10n.confirm),
            ),
          ],
        );
      },
    );
    return context.mounted && session.isCurrent && confirmed == true;
  } finally {
    session.dispose();
  }
}
