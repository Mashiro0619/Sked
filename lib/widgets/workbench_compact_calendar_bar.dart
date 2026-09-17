import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_motion.dart';
import '../theme/sked_expressive_theme.dart';
import 'workbench_chrome_metrics.dart';

/// One command can live inline or in overflow without changing its callback,
/// disabled state, label, or the live anchor used by a subsequent picker.
class WorkbenchOverflowAction {
  const WorkbenchOverflowAction({
    required this.id,
    required this.label,
    this.icon,
    this.tooltip,
    this.onSelected,
    this.selected,
    this.dividerBefore = false,
  });

  final String id;
  final String label;
  final IconData? icon;
  final String? tooltip;
  final ValueChanged<BuildContext>? onSelected;
  final bool? selected;
  final bool dividerBefore;
}

/// A compact desktop calendar row, inside the native-caption-safe width.
/// Keep a readable date/week command first; move complete commands to More
/// instead of hiding half a button in a horizontal scroll viewport.
class WorkbenchCompactCalendarBar extends StatelessWidget {
  const WorkbenchCompactCalendarBar({
    super.key,
    required this.id,
    required this.date,
    required this.shortDateLabel,
    required this.previous,
    required this.next,
    required this.today,
    required this.actions,
    this.enabled = true,
    this.onDateLongPress,
    this.moreFocusNode,
    this.badgeCount = 0,
  });

  final String id;
  final WorkbenchOverflowAction date;
  final String shortDateLabel;
  final WorkbenchOverflowAction previous;
  final WorkbenchOverflowAction next;
  final WorkbenchOverflowAction today;
  final List<WorkbenchOverflowAction> actions;
  final bool enabled;
  final VoidCallback? onDateLongPress;
  final FocusNode? moreFocusNode;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final m = WorkbenchChromeMetrics.of(context);
    final theme = Theme.of(context);
    final base = DefaultTextStyle.of(context).style;
    final dateStyle = base.merge(theme.textTheme.titleMedium);
    final commandStyle = base.merge(theme.textTheme.labelLarge);
    double measure(String label, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      final width = painter.width.ceilToDouble();
      painter.dispose();
      return width;
    }

    // Date labels include the disclosure icon, its gap, and real button insets.
    final fullDateWidth = math.max(
      m.iconTarget,
      measure(date.label, dateStyle) + 38,
    );
    final shortDateWidth = math.max(
      m.iconTarget,
      measure(shortDateLabel, dateStyle) + 38,
    );
    final todayWidth = math.max(32.0, measure(today.label, commandStyle) + 22);
    final iconDateWidth = math.max(m.iconTarget, 36.0);
    const gap = 4.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        final showDate = available >= iconDateWidth + gap + m.iconTarget;
        final showSteps =
            available >= shortDateWidth + 3 * (m.iconTarget + gap);
        final stepsWidth = showSteps ? 2 * (m.iconTarget + gap) : 0.0;
        final showToday =
            showDate &&
            available >=
                fullDateWidth +
                    stepsWidth +
                    todayWidth +
                    m.iconTarget +
                    2 * gap;
        final dateBudget =
            available -
            stepsWidth -
            (showToday ? todayWidth + gap : 0) -
            m.iconTarget -
            gap;
        final label = fullDateWidth <= dateBudget
            ? date.label
            : shortDateWidth <= dateBudget
            ? shortDateLabel
            : null;
        final menuItems = <WorkbenchOverflowAction>[
          if (!showDate) date,
          if (!showSteps) ...[previous, next],
          if (!showToday) today,
          ...actions,
        ];
        Widget step(WorkbenchOverflowAction action) => IconButton(
          key: ValueKey(action.id),
          style: m.iconStyle,
          tooltip: action.label,
          onPressed: enabled && action.onSelected != null
              ? () => action.onSelected!(context)
              : null,
          icon: Icon(action.icon),
        );
        return Row(
          children: [
            if (showSteps) ...[
              step(previous),
              const SizedBox(width: gap),
              step(next),
              const SizedBox(width: gap),
            ],
            if (showToday) ...[
              TextButton(
                key: ValueKey(today.id),
                style: TextButton.styleFrom(textStyle: commandStyle),
                onPressed: enabled && today.onSelected != null
                    ? () => today.onSelected!(context)
                    : null,
                child: Text(today.label, maxLines: 1, softWrap: false),
              ),
              const SizedBox(width: gap),
            ],
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: showDate
                    ? Builder(
                        builder: (anchor) {
                          final onPressed = enabled && date.onSelected != null
                              ? () => date.onSelected!(anchor)
                              : null;
                          return Semantics(
                            button: true,
                            enabled: onPressed != null,
                            label: date.tooltip ?? date.label,
                            onTap: onPressed,
                            onLongPress: enabled ? onDateLongPress : null,
                            excludeSemantics: true,
                            child: Tooltip(
                              message: date.tooltip ?? date.label,
                              excludeFromSemantics: true,
                              child: TextButton(
                                key: ValueKey(date.id),
                                onPressed: onPressed,
                                onLongPress: enabled ? onDateLongPress : null,
                                style: TextButton.styleFrom(
                                  minimumSize: Size(
                                    m.iconTarget,
                                    m.commandHeight,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  textStyle: dateStyle,
                                ),
                                child: label == null
                                    ? Icon(
                                        date.icon ?? Icons.date_range_outlined,
                                        size: 20,
                                      )
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            label,
                                            style: dateStyle,
                                            maxLines: 1,
                                            softWrap: false,
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(
                                            Icons.expand_more,
                                            size: 16,
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          );
                        },
                      )
                    : const SizedBox.shrink(),
              ),
            ),
            const SizedBox(width: gap),
            Builder(
              builder: (anchor) => IconButton(
                key: ValueKey('$id-desktop-toolbar-more'),
                focusNode: moreFocusNode,
                style: m.iconStyle,
                tooltip: AppLocalizations.of(context).more,
                onPressed: enabled
                    ? () => unawaited(_showMore(anchor, menuItems))
                    : null,
                icon: Badge(
                  isLabelVisible: badgeCount > 0,
                  label: Text(
                    '$badgeCount',
                    semanticsLabel:
                        '${AppLocalizations.of(context).reminder}: $badgeCount',
                  ),
                  child: const Icon(Icons.more_horiz),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showMore(
    BuildContext anchor,
    List<WorkbenchOverflowAction> items,
  ) async {
    final overlay =
        Navigator.of(anchor).overlay!.context.findRenderObject()! as RenderBox;
    // mounted can remain true while an element is deactivated during resize.
    // Cache the live boxes before pushing, just as PopupMenuButton does.
    final button = anchor.findRenderObject()! as RenderBox;
    final captionHeight = WorkbenchChromeMetrics.of(anchor).toolbarHeight;
    final openingTop = math.max(
      captionHeight,
      button.localToGlobal(Offset(0, button.size.height), ancestor: overlay).dy,
    );
    // Native controls paint above the Navigator. A tall menu must scroll below
    // their row rather than being fitted upward behind the caption buttons.
    final maximumHeight = math.max(
      1.0,
      overlay.size.height -
          openingTop -
          MediaQuery.paddingOf(anchor).bottom -
          8,
    );
    final openingSize = MediaQuery.sizeOf(anchor);
    final openingTextSize = MediaQuery.textScalerOf(anchor).scale(14);
    var retired = false;
    var lastPosition = RelativeRect.fill;
    RelativeRect position() {
      if (!button.attached || !overlay.attached) return lastPosition;
      final origin = button.localToGlobal(
        Offset(0, button.size.height),
        ancestor: overlay,
      );
      return lastPosition = RelativeRect.fromRect(
        Offset(origin.dx, math.max(captionHeight, origin.dy)) &
            Size(button.size.width, 0),
        Offset.zero & overlay.size,
      );
    }

    final selected = await showMenu<WorkbenchOverflowAction>(
      context: anchor,
      requestFocus: true,
      constraints: BoxConstraints(
        minWidth: 112,
        maxWidth: 280,
        maxHeight: maximumHeight,
      ),
      clipBehavior: Clip.antiAlias,
      positionBuilder: (_, _) => position(),
      popUpAnimationStyle: SkedMotionPolicy.of(anchor)
          .routeStyle(AppMotion.menuAnimationStyle),
      items: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0 && items[i].dividerBefore) const PopupMenuDivider(),
          PopupMenuItem<WorkbenchOverflowAction>(
            key: ValueKey(items[i].id),
            value: items[i],
            enabled: items[i].onSelected != null,
            child: Builder(
              builder: (menuContext) {
                // Overflow is not an editor draft. Retire this exact menu when
                // the window/font changes, then reopen with a fresh height budget.
                // This also prevents a disposed compact anchor from opening a task.
                if (i == 0 &&
                    !retired &&
                    (MediaQuery.sizeOf(menuContext) != openingSize ||
                        MediaQuery.textScalerOf(menuContext).scale(14) !=
                            openingTextSize)) {
                  retired = true;
                  final navigator = Navigator.of(menuContext);
                  final route = ModalRoute.of(menuContext);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (navigator.mounted && route?.isActive == true) {
                      navigator.removeRoute(route!);
                    }
                  });
                }
                return Semantics(
                  selected: items[i].selected,
                  child: Row(
                    children: [
                      Icon(
                        items[i].selected == true ? Icons.check : items[i].icon,
                        size: 18,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(items[i].label)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
    if (!retired && anchor.mounted && button.attached && enabled) {
      selected?.onSelected?.call(anchor);
    }
  }
}
