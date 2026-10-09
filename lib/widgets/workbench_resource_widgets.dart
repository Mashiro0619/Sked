import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import 'workbench_chrome_metrics.dart';

class CalendarResourceRow extends StatelessWidget {
  const CalendarResourceRow({
    super.key,
    required this.name,
    required this.color,
    required this.visible,
    required this.onChanged,
  });
  final String name;
  final Color color;
  final bool visible;
  final VoidCallback? onChanged;
  @override
  Widget build(BuildContext context) {
    final m = WorkbenchChromeMetrics.of(context);
    final c = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    return Tooltip(
      message: name,
      child: Semantics(
        label: name,
        checked: visible,
        enabled: onChanged != null,
        onTap: onChanged,
        hint: visible ? l.hideCalendar : l.showCalendar,
        child: ExcludeSemantics(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onChanged,
              borderRadius: BorderRadius.circular(6),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: m.resourceRowHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: visible ? color : null,
                          border: Border.all(
                            color: visible ? color : c.outline,
                            width: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: visible ? c.onSurface : c.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (!visible) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.visibility_off_outlined,
                          size: 14,
                          color: c.onSurfaceVariant,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Resource-row actions are quiet until the row is pointed at or focused.
/// Opacity preserves the trailing slot and keyboard traversal while hidden.
class TimetableResourceRow extends StatefulWidget {
  const TimetableResourceRow({
    super.key,
    required this.timetableId,
    required this.name,
    required this.selected,
    required this.onSelected,
    this.onEdit,
    this.onEditAt,
  });

  final String timetableId;
  final String name;
  final bool selected;
  final VoidCallback? onSelected;
  final VoidCallback? onEdit;
  final ValueChanged<BuildContext>? onEditAt;

  @override
  State<TimetableResourceRow> createState() => _TimetableResourceRowState();
}

class _TimetableResourceRowState extends State<TimetableResourceRow> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final showEdit =
        !WorkbenchChromeMetrics.of(context).desktop ||
        MediaQuery.accessibleNavigationOf(context) ||
        _hovered ||
        _focused;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        includeSemantics: false,
        onFocusChange: (focused) => setState(() => _focused = focused),
        child: ListTile(
          title: Text(widget.name),
          selected: widget.selected,
          onTap: widget.onSelected,
          trailing: Opacity(
            key: ValueKey(
              'resource-timetable-edit-visibility-${widget.timetableId}',
            ),
            opacity: showEdit ? 1 : 0,
            child: IgnorePointer(
              ignoring: !showEdit,
              child: ExcludeSemantics(
                excluding: !showEdit,
                child: Builder(
                  builder: (anchor) => IconButton(
                    key: ValueKey(
                      'resource-timetable-edit-${widget.timetableId}',
                    ),
                    tooltip: AppLocalizations.of(context).editTimetable,
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: widget.onEditAt == null
                        ? widget.onEdit
                        : () => widget.onEditAt!(anchor),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
