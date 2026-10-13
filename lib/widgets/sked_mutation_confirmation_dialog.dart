import 'sked_confirmation_dialog.dart';

import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../models/app_mode.dart';
import 'sked_task_route.dart';
import 'sked_task_submission_controller.dart';
import 'ui_command.dart';

/// Keeps a destructive confirmation open until its write succeeds. The task
/// owns its submission gate and completes only the route containing this widget.
class SkedMutationConfirmationDialog extends StatefulWidget {
  const SkedMutationConfirmationDialog({
    super.key,
    required this.workspace,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.debugLabel,
    required this.onConfirm,
    this.filledConfirmButton = true,
    this.insetPadding,
  });

  final AppMode workspace;
  final String title, message, confirmLabel, debugLabel;
  final Future<void> Function()? onConfirm;
  final bool filledConfirmButton;
  final EdgeInsets? insetPadding;

  @override
  State<SkedMutationConfirmationDialog> createState() =>
      _SkedMutationConfirmationDialogState();
}

class _SkedMutationConfirmationDialogState
    extends State<SkedMutationConfirmationDialog>
    with SkedTaskSubmissionHost<SkedMutationConfirmationDialog> {
  bool _completed = false;

  @override
  AppMode get submissionWorkspace => widget.workspace;

  bool get _blocked => _completed || taskSubmission.blocked;

  void _finish(bool result) {
    if (!mounted || _blocked) return;
    setState(() => _completed = true);
    completeSkedTaskRoute(context, result);
  }

  Future<void> _confirm() async {
    if (_blocked) return;
    final command = widget.onConfirm;
    if (command == null ||
        await taskSubmission.run(
          context: context,
          debugLabel: widget.debugLabel,
          command: command,
        )) {
      _finish(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final confirm = _blocked ? null : () => unawaited(_confirm());
    return PopScope(
      canPop: !_blocked,
      child: SkedConfirmationDialog(
        insetPadding: widget.insetPadding,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            UiCommandBusyIndicator(busy: taskSubmission.busy),
            const SizedBox(height: 16),
            Text(widget.title),
          ],
        ),
        content: Text(widget.message),
        actions: [
          TextButton(
            onPressed: _blocked ? null : () => _finish(false),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          if (widget.filledConfirmButton)
            FilledButton(onPressed: confirm, child: Text(widget.confirmLabel))
          else
            TextButton(onPressed: confirm, child: Text(widget.confirmLabel)),
        ],
      ),
    );
  }
}
