import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../utils/semester_helpers.dart';
import 'workbench_chrome_metrics.dart';

/// The timetable's existing weekday/date label, also used by phone schedules.
/// Selection remains a semantic state owned by the caller; today is the only
/// filled date badge, never a different background for the entire column.
class SkedCalendarDayLabel extends StatelessWidget {
  const SkedCalendarDayLabel({
    super.key,
    required this.date,
    required this.compact,
    required this.localeCode,
  });
  final DateTime date;
  final bool compact;
  final String localeCode;

  static double _verticalPadding(BuildContext context) =>
      WorkbenchChromeMetrics.compactTouch(context) ? 4 : 6;

  static double measuredHeight(
    BuildContext context, {
    required bool compact,
    String? localeCode,
  }) {
    final theme = Theme.of(context);
    final painter = TextPainter(
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    );
    final locale =
        localeCode ?? Localizations.localeOf(context).toLanguageTag();
    var weekdayHeight = 0.0;
    for (var weekday = 1; weekday <= 7; weekday++) {
      painter.text = TextSpan(
        text: formatWeekdayShortLabel(weekday, localeCode: locale),
        style: theme.textTheme.labelMedium,
      );
      painter.layout();
      weekdayHeight = math.max(weekdayHeight, painter.height);
    }
    painter.text = TextSpan(
      text: '28',
      style: compact ? theme.textTheme.labelLarge : theme.textTheme.titleMedium,
    );
    painter.layout();
    // Match the painted label: outer padding, 2dp label gap, 2dp badge padding.
    final height =
        _verticalPadding(context) * 2 + 4 + weekdayHeight + painter.height;
    painter.dispose();
    return math.max(48, height).ceilToDouble();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final today = DateUtils.isSameDay(date, DateTime.now());
    final dateStyle =
        (compact ? theme.textTheme.labelLarge : theme.textTheme.titleMedium)
            ?.copyWith(
              color: today ? colors.onPrimary : colors.onSurface,
              fontWeight: today ? FontWeight.w700 : FontWeight.w500,
            );
    final painter = TextPainter(
      text: TextSpan(text: '28', style: dateStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final badgeHeight = painter.height + 2;
    painter.dispose();
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 1 : 4,
        vertical: _verticalPadding(context),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            formatWeekdayShortLabel(date.weekday, localeCode: localeCode),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          // Reserve the line height so weekdays stay aligned. Only scale a
          // date badge when a very narrow column cannot fit all its digits;
          // ellipsizing a date can otherwise leave an empty today badge.
          SizedBox(
            height: badgeHeight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 3 : 6,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: today ? colors.primary : null,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  date.day.toString(),
                  maxLines: 1,
                  softWrap: false,
                  style: dateStyle,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
