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
