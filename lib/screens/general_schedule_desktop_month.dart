part of 'general_schedule_home_screen.dart';

// Header and summary budgets are measured once per grid. They must not switch
// to the phone date-picker presentation just because a task narrows the canvas.
class _DesktopMonthCellMetrics {
  const _DesktopMonthCellMetrics({
    required this.dateStyle,
    required this.summaryStyle,
    required this.countStyle,
    required this.dateDiameter,
    required this.horizontalPadding,
    required this.contentWidth,
    required this.lunarHeight,
    required this.stackLunar,
    required this.headerHeight,
    required this.summaryHeight,
    required this.countHeight,
    required this.showTitles,
  });

  final TextStyle dateStyle, summaryStyle, countStyle;
  final double dateDiameter, horizontalPadding, lunarHeight, headerHeight;
  final double summaryHeight, countHeight, contentWidth;
  final bool stackLunar, showTitles;
  static const verticalPadding = 6.0;
  static const contentGap = 6.0;
  static const summaryGap = 2.0;

  static TextStyle _dateStyle(BuildContext context) =>
      (Theme.of(context).textTheme.titleSmall ?? const TextStyle(fontSize: 14))
          .copyWith(fontSize: 16, height: 1.2, fontWeight: FontWeight.w600);

  static Size _measure(BuildContext context, String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: DefaultTextStyle.of(context).style.merge(style),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final size = painter.size;
    painter.dispose();
    return size;
  }

  static double _dateDiameter(BuildContext context) {
    final size = _measure(context, '28', _dateStyle(context));
    return math.max(28, math.max(size.width, size.height) + 6);
  }

  // Only an extremely narrow window/large font needs horizontal scrolling.
  // Reserve enough width for the unchanged date font rather than clipping it.
  static double minimumWidth(BuildContext context) =>
      _dateDiameter(context) + 8;

  factory _DesktopMonthCellMetrics.forGrid(
    BuildContext context, {
    required double cellWidth,
    required List<DateTime> days,
    required bool lunar,
    required String locale,
  }) {
    final theme = Theme.of(context);
    final dateStyle = _dateStyle(context);
    final summaryStyle =
        (theme.textTheme.bodySmall ?? const TextStyle(fontSize: 12)).copyWith(
          height: 1.25,
        );
    final countStyle =
        (theme.textTheme.labelSmall ?? const TextStyle(fontSize: 11)).copyWith(
          height: 1.2,
          fontWeight: FontWeight.w500,
        );
    final dateDiameter = _dateDiameter(context);
    final padding = math.min(
      8.0,
      math.max(4.0, (cellWidth - dateDiameter) / 2),
    );
    var lunarWidth = 0.0;
    var lunarHeight = 0.0;
    if (lunar) {
      const style = TextStyle(
        fontSize: 11,
        height: 1.05,
        fontWeight: FontWeight.w500,
      );
      for (final text
          in days
              .map((day) => _cachedLunarLabelFor(day, locale).text)
              .toSet()) {
        final size = _measure(context, text, style);
        lunarWidth = math.max(lunarWidth, size.width);
        lunarHeight = math.max(lunarHeight, size.height);
      }
    }
    final innerWidth = cellWidth - 2 * padding;
    final stackLunar = lunar && innerWidth < dateDiameter + 6 + lunarWidth;
    final headerHeight = stackLunar
        ? dateDiameter + 2 + lunarHeight
        : math.max(dateDiameter, lunarHeight);
    final summaryHeight = math.max(
      20.0,
      _measure(context, 'Ag日程', summaryStyle).height + 4,
    );
    final countHeight = math.max(
      18.0,
      _measure(context, 'Ag更多', countStyle).height + 2,
    );
    return _DesktopMonthCellMetrics(
      dateStyle: dateStyle,
      summaryStyle: summaryStyle,
      countStyle: countStyle,
      dateDiameter: dateDiameter,
      horizontalPadding: padding,
      contentWidth: innerWidth,
      lunarHeight: lunarHeight,
      stackLunar: stackLunar,
      headerHeight: headerHeight,
      summaryHeight: summaryHeight,
      countHeight: countHeight,
      showTitles:
          innerWidth >= _measure(context, '0000', summaryStyle).width + 12,
    );
  }

  double get minimumHeight =>
      2 * verticalPadding + headerHeight + contentGap + countHeight;

  String countText(BuildContext context, int count) {
    final label = AppLocalizations.of(context).moreEvents(count);
    if (_measure(context, label, countStyle).width <= contentWidth) {
      return label;
    }
    // Keep the number legible when the localized phrase cannot fit. The full
    // phrase remains available through the tooltip and the cell's semantics.
    final short = '+$count';
    return _measure(context, short, countStyle).width <= contentWidth
        ? short
        : '$count';
  }

  int titleLimit(double height, int count) {
    if (!showTitles || count == 0) return 0;
    final available = height - 2 * verticalPadding - headerHeight - contentGap;
    final capacity = math.max(
      0,
      ((available + summaryGap) / (summaryHeight + summaryGap)).floor(),
    );
    final limit = math.min(4, math.min(capacity, count));
    if (limit == count) return limit;
    // If anything is hidden, its count gets a real line box, not an overlay.
    return math.min(
      limit,
      math.max(
        0,
        ((available - countHeight) / (summaryHeight + summaryGap)).floor(),
      ),
    );
  }
}

class _DesktopMonthDayCell extends StatelessWidget {
  const _DesktopMonthDayCell({
    super.key,
    required this.date,
    required this.month,
    required this.isToday,
    required this.isSelected,
    required this.occurrences,
    required this.locale,
    required this.showLunar,
    required this.height,
    required this.metrics,
    required this.onTap,
  });

  final DateTime date;
  final int month;
  final bool isToday, isSelected, showLunar;
  final List<GeneralEventOccurrence> occurrences;
  final String locale;
  final double height;
  final _DesktopMonthCellMetrics metrics;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    final currentMonth = date.month == month;
    final baseSurface = currentMonth
        ? colors.surface
        : colors.surfaceContainerLow;
    final surface = isSelected
        ? Color.alphaBlend(
            colors.primary.withValues(
              alpha: colors.brightness == Brightness.dark ? .10 : .06,
            ),
            baseSurface,
          )
        : baseSurface;
    final dateColor = currentMonth
        ? colors.onSurface
        : colors.onSurfaceVariant.withValues(alpha: .65);
    final badge = SizedBox.square(
      dimension: metrics.dateDiameter,
      child: DecoratedBox(
        key: const ValueKey('desktop-month-date-badge'),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isToday ? colors.primary : Colors.transparent,
        ),
        child: Center(
          child: Text(
            '${date.day}',
            key: const ValueKey('desktop-month-date-number'),
            maxLines: 1,
            softWrap: false,
            style: metrics.dateStyle.copyWith(
              color: isToday ? colors.onPrimary : dateColor,
            ),
          ),
        ),
      ),
    );
    final lunar = showLunar
        ? Tooltip(
            message: _cachedLunarLabelFor(date, locale).text,
            excludeFromSemantics: true,
            child: _LunarDateLabel(
              date: date,
              colorScheme: colors,
              localeCode: locale,
              enabled: true,
              fontSize: 11,
              overrideColor: currentMonth ? colors.onSurfaceVariant : dateColor,
            ),
          )
        : const SizedBox.shrink();
    final header = SizedBox(
      key: const ValueKey('desktop-month-cell-header'),
      height: metrics.headerHeight,
      child: metrics.stackLunar
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                badge,
                const SizedBox(height: 2),
                SizedBox(
                  key: const ValueKey('desktop-month-lunar-label'),
                  height: metrics.lunarHeight,
                  width: double.infinity,
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: lunar,
                  ),
                ),
              ],
            )
          : Row(
              children: [
                badge,
                if (showLunar) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: Align(
                      key: const ValueKey('desktop-month-lunar-label'),
                      alignment: AlignmentDirectional.centerStart,
                      widthFactor: 1,
                      child: lunar,
                    ),
                  ),
                ],
              ],
            ),
    );
    final titleLimit = metrics.titleLimit(height, occurrences.length);
    final remaining = occurrences.length - titleLimit;
    final dateLabel = MaterialLocalizations.of(context).formatFullDate(date);
    return Semantics(
      button: true,
      selected: isSelected,
      label: occurrences.isEmpty
          ? dateLabel
          : '$dateLabel, ${l.monthDayEvents(date.day, occurrences.length)}',
      child: Material(
        key: const ValueKey('desktop-month-day-surface'),
        color: surface,
        surfaceTintColor: Colors.transparent,
        // Selection uses the surface tint only; shared grid lines stay unchanged.
        shape: const RoundedRectangleBorder(),
        clipBehavior: Clip.hardEdge,
        child: InkWell(
          onTap: onTap,
          hoverColor: colors.onSurface.withValues(alpha: .04),
          focusColor: colors.primary.withValues(alpha: .10),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: metrics.horizontalPadding,
              vertical: _DesktopMonthCellMetrics.verticalPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                if (occurrences.isNotEmpty)
                  const SizedBox(height: _DesktopMonthCellMetrics.contentGap),
                for (var index = 0; index < titleLimit; index++) ...[
                  _DesktopMonthEventSummary(
                    occurrence: occurrences[index],
                    metrics: metrics,
                    surface: surface,
                  ),
                  if (index + 1 < titleLimit || remaining > 0)
                    const SizedBox(height: _DesktopMonthCellMetrics.summaryGap),
                ],
                if (remaining > 0)
                  SizedBox(
                    key: const ValueKey('desktop-month-more'),
                    height: metrics.countHeight,
                    child: Tooltip(
                      message: l.moreEvents(remaining),
                      excludeFromSemantics: true,
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          metrics.countText(context, remaining),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: metrics.countStyle.copyWith(
                            color: skedReadableAccent(colors, surface: surface),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopMonthEventSummary extends StatelessWidget {
  const _DesktopMonthEventSummary({
    required this.occurrence,
    required this.metrics,
    required this.surface,
  });
  final GeneralEventOccurrence occurrence;
  final _DesktopMonthCellMetrics metrics;
  final Color surface;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = effectiveGeneralOccurrenceColor(context, occurrence);
    return Tooltip(
      message:
          '${occurrence.event.title}\n${_formatOccurrenceTime(context, occurrence)}',
      excludeFromSemantics: true,
      child: Ink(
        key: ValueKey('desktop-month-event-${occurrence.occurrenceKey}'),
        height: metrics.summaryHeight,
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            color.withValues(
              alpha: colors.brightness == Brightness.dark ? .18 : .10,
            ),
            surface,
          ),
          borderRadius: BorderRadius.circular(3),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            occurrence.event.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: metrics.summaryStyle.copyWith(color: colors.onSurface),
          ),
        ),
      ),
    );
  }
}
