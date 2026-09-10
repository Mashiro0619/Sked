import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

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

/// Mouse calendar navigator only; touch platforms use a properly sized date picker.
class WorkbenchMonthNavigator extends StatelessWidget {
  const WorkbenchMonthNavigator({
    super.key,
    required this.date,
    required this.onDate,
    required this.onMonth,
    required this.onToday,
  });
  final DateTime date;
  final ValueChanged<DateTime> onDate;
  final ValueChanged<int> onMonth;
  final VoidCallback onToday;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), c = Theme.of(context).colorScheme;
    final m = WorkbenchChromeMetrics.of(context);
    final first = DateTime(date.year, date.month);
    final start = first.subtract(Duration(days: first.weekday - 1));
    final today = DateTime.now();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat.yMMM(l.localeName).format(date),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              IconButton(
                key: const ValueKey('general-resource-previous-month'),
                style: m.iconStyle,
                tooltip: l.previousMonth,
                onPressed: () => onMonth(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                key: const ValueKey('general-resource-next-month'),
                style: m.iconStyle,
                tooltip: l.nextMonth,
                onPressed: () => onMonth(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      DateFormat.E(l.localeName)
                          .format(DateTime(2024, 1, 1 + i)),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ),
            ],
          ),
          for (var row = 0; row < 6; row++)
            Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final day = start.add(Duration(days: row * 7 + col));
                        final selected = DateUtils.isSameDay(day, date),
                            now = DateUtils.isSameDay(day, today);
                        return SizedBox(
                          height: 28 * m.textScale,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              minimumSize: Size.zero,
                              padding: EdgeInsets.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              backgroundColor: selected
                                  ? c.secondaryContainer
                                  : null,
                              foregroundColor: day.month == date.month
                                  ? c.onSurface
                                  : c.onSurfaceVariant,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                                side: now
                                    ? BorderSide(color: c.primary)
                                    : BorderSide.none,
                              ),
                            ),
                            onPressed: () => onDate(day),
                            child: Text(
                              '${day.day}',
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
