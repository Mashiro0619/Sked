import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';

/// One presentation contract for decisions. It deliberately owns no mutation,
/// route, consent policy or default answer; those belong to the caller.
class SkedConfirmationDialog extends StatelessWidget {
  const SkedConfirmationDialog({
    super.key,
    this.icon,
    this.iconPadding,
    this.iconColor,
    this.title,
    this.titlePadding,
    this.titleTextStyle,
    this.content,
    this.contentPadding,
    this.contentTextStyle,
    this.actions,
    this.actionsPadding,
    this.actionsAlignment = MainAxisAlignment.end,
    this.actionsOverflowAlignment = OverflowBarAlignment.end,
    this.actionsOverflowDirection,
    this.actionsOverflowButtonSpacing = 8,
    this.buttonPadding,
    this.backgroundColor,
    this.elevation,
    this.shadowColor,
    this.surfaceTintColor,
    this.semanticLabel,
    this.insetPadding,
    this.clipBehavior,
    this.shape,
    this.alignment,
    this.constraints,
    this.scrollable = false,
  });

  final Widget? icon, title, content;
  final EdgeInsetsGeometry? iconPadding,
      titlePadding,
      contentPadding,
      actionsPadding,
      buttonPadding;
  final Color? iconColor, backgroundColor, shadowColor, surfaceTintColor;
  final TextStyle? titleTextStyle, contentTextStyle;
  final List<Widget>? actions;
  final MainAxisAlignment? actionsAlignment;
  final OverflowBarAlignment? actionsOverflowAlignment;
  final VerticalDirection? actionsOverflowDirection;
  final double? actionsOverflowButtonSpacing, elevation;
  final String? semanticLabel;
  final EdgeInsets? insetPadding;
  final Clip? clipBehavior;
  final ShapeBorder? shape;
  final AlignmentGeometry? alignment;
  final BoxConstraints? constraints;
  final bool scrollable;

  @override
  Widget build(BuildContext context) => AlertDialog(
    icon: icon,
    iconPadding: iconPadding,
    iconColor: iconColor,
    title: title,
    titlePadding: titlePadding,
    titleTextStyle: titleTextStyle,
    content: content,
    contentPadding: contentPadding,
    contentTextStyle: contentTextStyle,
    actions: actions,
    actionsPadding: actionsPadding,
    actionsAlignment: actionsAlignment,
    actionsOverflowAlignment: actionsOverflowAlignment,
    actionsOverflowDirection: actionsOverflowDirection,
    actionsOverflowButtonSpacing: actionsOverflowButtonSpacing,
    buttonPadding: buttonPadding,
    backgroundColor: backgroundColor,
    elevation: elevation,
    shadowColor: shadowColor,
    surfaceTintColor: surfaceTintColor,
    semanticLabel: semanticLabel,
    insetPadding: insetPadding,
    clipBehavior: clipBehavior,
    shape: shape,
    alignment: alignment,
    constraints: constraints,
    scrollable: scrollable,
  );
}

/// The shared view for abandoning a draft. The owning guard decides when this
/// question is necessary and keeps the dialog in its task's lifetime.
class SkedDiscardDraftDialog extends StatelessWidget {
  const SkedDiscardDraftDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SkedConfirmationDialog(
      title: Text(l.periodTimesUnsavedExitTitle),
      content: Text(l.unsavedChangesMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l.discardChangesAndExit),
        ),
      ],
    );
  }
}
