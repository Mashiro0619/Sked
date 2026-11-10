import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'sked_task_session.dart';
import 'workbench_chrome_metrics.dart';

/// Search belongs to the focused region, below modal and text-editing actions.
class DesktopSearchShortcuts extends StatelessWidget {
  const DesktopSearchShortcuts({
    super.key,
    required this.onFind,
    required this.onDismiss,
    required this.isCurrent,
    this.autofocus = false,
    required this.child,
  });

  final VoidCallback onFind;
  final bool Function() onDismiss;
  final bool Function() isCurrent;
  final bool autofocus;
  final Widget child;

  static String findLabel(BuildContext context) =>
      Theme.of(context).platform == TargetPlatform.macOS ? '⌘F' : 'Ctrl+F';

  static String findTooltip(BuildContext context, String label) =>
      WorkbenchChromeMetrics.of(context).desktop
      ? '$label (${findLabel(context)})'
      : label;

  @override
  Widget build(BuildContext context) {
    if (!WorkbenchChromeMetrics.of(context).desktop) return child;
    final macOS = Theme.of(context).platform == TargetPlatform.macOS;
    final find = SingleActivator(
      LogicalKeyboardKey.keyF,
      control: !macOS,
      meta: macOS,
    );
    const dismiss = SingleActivator(LogicalKeyboardKey.escape);
    return FocusScope(
      autofocus: autofocus,
      skipTraversal: true,
      includeSemantics: false,
      onKeyEvent: (_, event) {
        final keyboard = HardwareKeyboard.instance;
        final finding = find.accepts(event, keyboard);
        if ((!finding && !dismiss.accepts(event, keyboard)) ||
            ModalRoute.of(context)?.isCurrent == false ||
            !TickerMode.valuesOf(context).enabled ||
            !SkedTaskSessionScope.isCurrent(context) ||
            !isCurrent()) {
          return KeyEventResult.ignored;
        }
        final input = FocusManager.instance.primaryFocus?.context
            ?.findAncestorStateOfType<EditableTextState>();
        final composing = input?.widget.controller.value.composing;
        if (composing != null && composing.isValid && !composing.isCollapsed) {
          // Let the platform input method handle the key without letting an
          // outer Escape binding dismiss the page behind the composition.
          return KeyEventResult.skipRemainingHandlers;
        }
        if (event is! KeyDownEvent) return KeyEventResult.handled;
        if (finding) {
          onFind();
          return KeyEventResult.handled;
        }
        return onDismiss() ? KeyEventResult.handled : KeyEventResult.ignored;
      },
      child: child,
    );
  }
}
