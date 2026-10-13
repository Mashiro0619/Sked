import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';

/// Shared command layout; the caller retains ownership of every action.
class SkedActionArea extends StatelessWidget {
  const SkedActionArea({
    super.key,
    this.leading,
    required this.actions,
    this.spacing = 8,
    this.runSpacing = 8,
  });

  final Widget? leading;
  final List<Widget> actions;
  final double spacing, runSpacing;

  @override
  Widget build(BuildContext context) {
    final trailing = Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: actions,
    );
    // A trailing-only group also participates in native dialog intrinsic
    // sizing. Its Wrap needs no layout-time breakpoint to choose its rows.
    if (leading == null) return trailing;
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        if (constraints.maxWidth >= 420 * scale) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              leading!,
              const Spacer(),
              Flexible(child: trailing),
            ],
          );
        }
        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [leading!, ...actions],
        );
      },
    );
  }
}

/// A form's command intent, independent of sheet, dialog or pane presentation.
/// Callbacks perform validation, persistence and guarded exits themselves.
class SkedEditorActions {
  const SkedEditorActions({
    required this.onCancel,
    required this.onSubmit,
    this.onDelete,
    this.submitLabel,
    this.enabled = true,
    this.showDelete = false,
    this.busy = false,
  });

  final VoidCallback? onCancel, onSubmit, onDelete;
  final String? submitLabel;
  final bool enabled, showDelete, busy;
  bool get _enabled => enabled && !busy;

  Widget? leading(BuildContext context) => !showDelete && onDelete == null
      ? null
      : TextButton.icon(
          onPressed: _enabled ? onDelete : null,
          icon: const Icon(Icons.delete_outline),
          label: Text(AppLocalizations.of(context).delete),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
        );

  List<Widget> trailing(BuildContext context) {
    final l = AppLocalizations.of(context);
    return [
      TextButton(onPressed: _enabled ? onCancel : null, child: Text(l.cancel)),
      FilledButton.icon(
        onPressed: _enabled ? onSubmit : null,
        icon: const Icon(Icons.check),
        label: Text(submitLabel ?? l.save),
      ),
    ];
  }

  Widget build(BuildContext context) =>
      SkedActionArea(leading: leading(context), actions: trailing(context));
}
