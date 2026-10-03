import 'package:provider/provider.dart';

import '../providers/timetable_provider.dart';
import 'sked_task_session.dart';
import 'sked_floating_surface.dart';

import 'package:material_ui/material_ui.dart';

import '../models/app_mode.dart';
import 'expressive_dialog.dart';
import 'sked_picker_task.dart';
import 'sked_task_dialog.dart';
import 'ui_command.dart';
import 'workbench_chrome_metrics.dart';

/// A desktop picker opts into inline content; mobile still uses AlertDialog.
Future<T?> showSkedAdaptivePickerDialog<T>({
  required BuildContext context,
  required String routeName,
  required WidgetBuilder builder,
  BuildContext? anchorContext,
  SkedFloatingPlacement placement = SkedFloatingPlacement.automatic,
  double preferredWidth = 360,
  AppMode? workspace,
  bool Function()? isSessionCurrent,
  SkedTaskSession? session,
  bool waitForTransitionComplete = false,
}) async {
  if (!WorkbenchChromeMetrics.of(context).desktop) {
    final provider = Provider.of<TimetableProvider?>(context, listen: false);
    final parentSession =
        session ?? SkedTaskSessionScope.maybeOf(context)?.session;
    final task = SkedTaskSession(
      provider: provider,
      workspace: workspace,
      parent: parentSession,
      ownerRoute: ModalRoute.of(context),
      isOwnerActive: () => context.mounted,
      isTargetCurrent: isSessionCurrent,
    );
    try {
      if (!task.isCurrent) return null;
      final result = await showExpressiveDialog<T>(
        context: context,
        session: task,
        builder: (_) => SkedStableTaskBody(builder: builder),
        waitForTransitionComplete: waitForTransitionComplete,
      );
      return task.isCurrent ? result : null;
    } finally {
      task.dispose();
    }
  }
  return showSkedPickerTask<T>(
    context: context,
    routeName: routeName,
    anchorContext: anchorContext,
    placement: placement,
    workspace: workspace,
    isSessionCurrent: isSessionCurrent,
    session: session,
    waitForTransitionComplete: waitForTransitionComplete,
    // These dialogs already wrap their text and choices. Keep their existing
    // reading widths instead of multiplying empty space with the text scale.
    preferredSize: (_) => Size(preferredWidth, 600),
    builder: (context, finish, isCurrent) => Focus(
      // A previously restored trigger can otherwise win focus when opening
      // another secondary task immediately after its predecessor retires.
      autofocus: waitForTransitionComplete,
      skipTraversal: true,
      includeSemantics: false,
      child: SkedTaskDialogScope(
        onClose: () => Navigator.of(context).maybePop(),
        child: UiCommandFeedbackHost(
          builder: (context) => SkedStableTaskBody(builder: builder),
        ),
      ),
    ),
  );
}
