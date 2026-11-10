import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import 'sked_task_session.dart';
import 'workbench_chrome_metrics.dart';

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

  /// The form's fields and commands share one save shortcut and one owner.
  Widget wrapShortcuts(BuildContext context, Widget child) {
    if (!WorkbenchChromeMetrics.of(context).desktop) return child;
    final macOS = Theme.of(context).platform == TargetPlatform.macOS;
    final shortcut = SingleActivator(
      LogicalKeyboardKey.keyS,
      control: !macOS,
      meta: macOS,
    );
    return FocusScope(
      autofocus: true,
      skipTraversal: true,
      includeSemantics: false,
      onKeyEvent: (_, event) {
        if (!shortcut.accepts(event, HardwareKeyboard.instance) ||
            ModalRoute.of(context)?.isCurrent == false ||
            !TickerMode.valuesOf(context).enabled) {
          return KeyEventResult.ignored;
        }
        // An unavailable inner form still owns this key; it must not save an
        // ancestor editor. Repeated keys never repeat the submitted operation.
        if (event is! KeyDownEvent ||
            !_enabled ||
            onSubmit == null ||
            !SkedTaskSessionScope.isCurrent(context)) {
          return KeyEventResult.handled;
        }
        final input = FocusManager.instance.primaryFocus?.context
            ?.findAncestorStateOfType<EditableTextState>();
        final composing = input?.widget.controller.value.composing;
        if (composing != null && composing.isValid && !composing.isCollapsed) {
          return KeyEventResult.handled;
        }
        onSubmit!();
        return KeyEventResult.handled;
      },
      child: child,
    );
  }

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

  Widget wrapSaveTooltip(BuildContext context, Widget child) {
    if (!WorkbenchChromeMetrics.of(context).desktop) return child;
    final label = submitLabel ?? AppLocalizations.of(context).save;
    final shortcut = Theme.of(context).platform == TargetPlatform.macOS
        ? '⌘S'
        : 'Ctrl+S';
    return Tooltip(message: '$label ($shortcut)', child: child);
  }

  List<Widget> trailing(BuildContext context, {bool showSaveShortcut = false}) {
    final l = AppLocalizations.of(context);
    final save = FilledButton.icon(
      onPressed: _enabled ? onSubmit : null,
      icon: const Icon(Icons.check),
      label: Text(submitLabel ?? l.save),
    );
    return [
      TextButton(onPressed: _enabled ? onCancel : null, child: Text(l.cancel)),
      showSaveShortcut ? wrapSaveTooltip(context, save) : save,
    ];
  }

  Widget build(BuildContext context) =>
      SkedActionArea(leading: leading(context), actions: trailing(context));
}
