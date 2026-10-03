import 'package:material_ui/material_ui.dart';

import 'sked_popup_menu.dart';
import 'workbench_chrome_metrics.dart';

enum CalendarManagementAction { rename, delete }

class CalendarVisibilityButton extends StatelessWidget {
  const CalendarVisibilityButton({
    super.key,
    required this.id,
    required this.visible,
    required this.enabled,
    required this.showTooltip,
    required this.hideTooltip,
    required this.onPressed,
    this.compact = false,
  });
  final String id, showTooltip, hideTooltip;
  final bool visible, enabled, compact;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    final metrics = WorkbenchChromeMetrics.of(context);
    final button = IconButton(
      key: ValueKey('calendar-visibility-$id'),
      tooltip: visible ? hideTooltip : showTooltip,
      onPressed: enabled ? onPressed : null,
      style: compact
          ? IconButton.styleFrom(
              minimumSize: Size.square(metrics.commandHeight),
              maximumSize: Size.square(metrics.commandHeight),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.all(8),
              foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
            )
          : null,
      icon: Icon(
        visible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        size: compact ? 18 : null,
      ),
    );
    return MergeSemantics(
      child: Semantics(
        toggled: visible,
        child: compact
            ? button
            : SizedBox.square(dimension: metrics.iconTarget, child: button),
      ),
    );
  }
}

class CalendarManagementMenu extends StatelessWidget {
  const CalendarManagementMenu({
    super.key,
    required this.id,
    required this.enabled,
    required this.tooltip,
    required this.renameLabel,
    required this.deleteLabel,
    required this.onRename,
    required this.onDelete,
    this.compact = false,
  });
  final String id, tooltip, renameLabel, deleteLabel;
  final bool enabled, compact;
  final ValueChanged<BuildContext> onRename;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    Widget label(String text, IconData icon, {bool danger = false}) {
      if (compact) {
        return Text(text, style: danger ? TextStyle(color: error) : null);
      }
      final row = Row(
        children: [
          Icon(icon),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      );
      return danger
          ? IconTheme.merge(
              data: IconThemeData(color: error),
              child: DefaultTextStyle.merge(
                style: TextStyle(color: error),
                child: row,
              ),
            )
          : row;
    }

    final menu = Builder(
      builder: (anchor) => SkedPopupMenuButton<CalendarManagementAction>(
        key: ValueKey('calendar-actions-$id'),
        enabled: enabled,
        tooltip: tooltip,
        icon: Icon(compact ? Icons.more_horiz : Icons.more_vert),
        onSelected: (action) {
          switch (action) {
            case CalendarManagementAction.rename:
              onRename(anchor);
            case CalendarManagementAction.delete:
              onDelete();
          }
        },
        itemBuilder: (_) => [
          SkedPopupMenuItem(
            value: CalendarManagementAction.rename,
            child: label(renameLabel, Icons.edit_outlined),
          ),
          const SkedPopupMenuDivider<CalendarManagementAction>(),
          SkedPopupMenuItem(
            value: CalendarManagementAction.delete,
            child: label(deleteLabel, Icons.delete_outline, danger: true),
          ),
        ],
      ),
    );
    return compact
        ? menu
        : SizedBox.square(
            dimension: WorkbenchChromeMetrics.of(context).iconTarget,
            child: menu,
          );
  }
}
