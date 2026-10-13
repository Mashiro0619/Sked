import 'package:material_ui/material_ui.dart';

/// Keeps each tooltip's OverlayPortal traversal anchor in its own semantics
/// node, including when a ListView item would otherwise merge sibling anchors.
///
/// Flutter 3.47.7 can discard one of those anchors and send an orphaned tooltip
/// node to the native accessibility bridge: flutter/flutter#182444. Retain the
/// Material tooltip's labels, hover behavior and theme while isolating it.
/// Place source widgets that exclude their descendants' semantics inside this
/// tooltip so they do not also exclude its traversal anchor.
class SkedTooltip extends StatelessWidget {
  const SkedTooltip({
    super.key,
    this.message,
    this.richMessage,
    this.constraints,
    this.padding,
    this.margin,
    this.verticalOffset,
    this.preferBelow,
    this.excludeFromSemantics,
    this.decoration,
    this.textStyle,
    this.textAlign,
    this.waitDuration,
    this.showDuration,
    this.exitDuration,
    this.enableTapToDismiss = true,
    this.triggerMode,
    this.enableFeedback,
    this.onTriggered,
    this.mouseCursor,
    this.ignorePointer,
    this.positionDelegate,
    this.child,
  }) : assert((message == null) != (richMessage == null));

  final String? message;
  final InlineSpan? richMessage;
  final BoxConstraints? constraints;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? verticalOffset;
  final bool? preferBelow;
  final bool? excludeFromSemantics;
  final Decoration? decoration;
  final TextStyle? textStyle;
  final TextAlign? textAlign;
  final Duration? waitDuration;
  final Duration? showDuration;
  final Duration? exitDuration;
  final bool enableTapToDismiss;
  final TooltipTriggerMode? triggerMode;
  final bool? enableFeedback;
  final TooltipTriggeredCallback? onTriggered;
  final MouseCursor? mouseCursor;
  final bool? ignorePointer;
  final TooltipPositionDelegate? positionDelegate;
  final Widget? child;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    child: Tooltip(
      message: message,
      richMessage: richMessage,
      constraints: constraints,
      padding: padding,
      margin: margin,
      verticalOffset: verticalOffset,
      preferBelow: preferBelow,
      excludeFromSemantics: excludeFromSemantics,
      decoration: decoration,
      textStyle: textStyle,
      textAlign: textAlign,
      waitDuration: waitDuration,
      showDuration: showDuration,
      exitDuration: exitDuration,
      enableTapToDismiss: enableTapToDismiss,
      triggerMode: triggerMode,
      enableFeedback: enableFeedback,
      onTriggered: onTriggered,
      mouseCursor: mouseCursor,
      ignorePointer: ignorePointer,
      positionDelegate: positionDelegate,
      child: child,
    ),
  );
}
