part of 'general_schedule_home_screen.dart';

class _TimelineTimeRailLabel extends StatelessWidget {
  const _TimelineTimeRailLabel({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow.withValues(alpha: 0.72),
        border: Border(
          right: BorderSide(
            color: colors.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: FittedBox(fit: BoxFit.scaleDown, child: child),
    );
  }
}

class _AllDayColumn extends StatelessWidget {
  const _AllDayColumn({
    required this.date,
    required this.width,
    required this.occurrences,
    required this.onTap,
  });

  final DateTime date;
  final double width;
  final List<GeneralEventOccurrence> occurrences;
  final ValueChanged<GeneralEventOccurrence> onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: width,
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
      ),
      padding: const EdgeInsets.all(4),
      child: occurrences.isEmpty
          ? const SizedBox.shrink()
          : ListView(
              physics: const NeverScrollableScrollPhysics(),
              children: <Widget>[
                for (final occurrence in occurrences.take(2))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: _AllDayChip(
                      occurrence: occurrence,
                      onTap: () => onTap(occurrence),
                    ),
                  ),
                if (occurrences.length > 2)
                  Text(
                    l10n.moreEvents(occurrences.length - 2),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
              ],
            ),
    );
  }
}

class _AllDayChip extends StatelessWidget {
  const _AllDayChip({required this.occurrence, required this.onTap});

  final GeneralEventOccurrence occurrence;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = effectiveGeneralOccurrenceColor(context, occurrence);
    return Material(
      color: color.withAlpha(36),
      borderRadius: BorderRadius.circular(8),
      child: Semantics(
        button: true,
        label: occurrence.event.title,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            child: Text(
              occurrence.event.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: _readableColor(color),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GridBackground extends StatelessWidget {
  const _GridBackground({
    required this.timeColumnWidth,
    required this.dayWidth,
    required this.dayCount,
    required this.startHour,
    required this.endHour,
    required this.gridMinutes,
    required this.hourHeight,
  });

  final double timeColumnWidth;
  final double dayWidth;
  final int dayCount;
  final int startHour;
  final int endHour;
  final int gridMinutes;
  final double hourHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final totalHeight = (endHour - startHour) * hourHeight;
    final lineColor = colors.outlineVariant.withValues(alpha: 0.56);
    final minorColor = colors.outlineVariant.withValues(alpha: 0.28);
    final timeLabelColor = colors.onSurfaceVariant;
    final gridStep = gridMinutes.clamp(15, 60).toInt();
    return Stack(
      children: [
        Positioned.fill(
          right: null,
          child: Container(
            width: timeColumnWidth,
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow.withValues(alpha: 0.72),
              border: Border(right: BorderSide(color: lineColor)),
            ),
          ),
        ),
        for (var hour = startHour; hour <= endHour; hour++)
          Positioned(
            left: timeColumnWidth,
            right: 0,
            top: (hour - startHour) * hourHeight,
            child: Divider(height: 1, color: lineColor),
          ),
        for (var hour = startHour; hour <= endHour; hour++)
          Positioned(
            left: 0,
            top: math.max(0, (hour - startHour) * hourHeight - 9),
            width: timeColumnWidth,
            height: 18,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${hour.toString().padLeft(2, '0')}:00',
                    textAlign: TextAlign.right,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: timeLabelColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        for (
          var minute = gridStep;
          minute < (endHour - startHour) * 60;
          minute += gridStep
        )
          if (minute % 60 != 0)
            Positioned(
              left: timeColumnWidth,
              right: 0,
              top: minute / 60 * hourHeight,
              child: Divider(height: 1, color: minorColor),
            ),
        for (var day = 0; day <= dayCount; day++)
          Positioned(
            top: 0,
            bottom: 0,
            left: timeColumnWidth + day * dayWidth,
            child: VerticalDivider(width: 1, color: lineColor),
          ),
        Positioned(
          left: timeColumnWidth,
          right: 0,
          top: totalHeight - 1,
          child: Divider(height: 1, color: lineColor),
        ),
      ],
    );
  }
}

class _OccurrenceCard extends StatelessWidget {
  const _OccurrenceCard({
    required this.occurrence,
    required this.dense,
    required this.narrow,
    required this.overlapping,
    required this.onTap,
  });

  final GeneralEventOccurrence occurrence;
  final bool dense;
  final bool narrow;
  final bool overlapping;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final color = effectiveGeneralOccurrenceColor(context, occurrence);
    final fillColor = _timelineOccurrenceFillColor(color, colorScheme);
    final accentColor = _timelineOccurrenceAccentColor(
      color,
      colorScheme,
      fillColor,
    );
    final detailColor = accentColor.withValues(
      alpha: colorScheme.brightness == Brightness.dark ? 0.78 : 0.72,
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(narrow ? 7 : 8),
      side: BorderSide(
        color: overlapping
            ? accentColor.withValues(alpha: 0.74)
            : accentColor.withValues(alpha: 0.46),
        width: overlapping ? 1.1 : 0.9,
      ),
    );
    final titleText = occurrence.event.title;
    final titleStyle =
        (narrow ? theme.textTheme.labelSmall : theme.textTheme.labelMedium)
            ?.copyWith(
              color: accentColor,
              fontWeight: FontWeight.w700,
              height: narrow ? 1.08 : 1.1,
            );
    final detailStyle = theme.textTheme.labelSmall?.copyWith(
      color: detailColor,
      fontWeight: FontWeight.w600,
      height: 1.05,
    );
    final locationStyle = theme.textTheme.labelSmall?.copyWith(
      color: detailColor,
      height: 1.05,
    );
    return Material(
      key: ValueKey(
        'general-timed-occurrence-'
        '${occurrence.event.id}-${occurrence.start.toIso8601String()}',
      ),
      color: fillColor,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        button: true,
        label: occurrence.event.title,
        child: InkWell(
          customBorder: shape,
          overlayColor: _timelineOccurrenceOverlayColor(accentColor),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: narrow ? 3 : 7,
              vertical: dense ? 4 : 6,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final title = _TimelineOccurrenceTitleLayout(
                  text: titleText,
                  style: titleStyle,
                  maxWidth: constraints.maxWidth,
                  maxHeight: constraints.maxHeight,
                  textDirection: Directionality.of(context),
                  narrow: narrow,
                );
                final titleWidget = Text(
                  titleText,
                  maxLines: title.maxLines,
                  overflow: TextOverflow.ellipsis,
                  softWrap: true,
                  strutStyle: _timelineTitleStrutStyle(titleStyle, narrow),
                  textAlign: TextAlign.start,
                  style: titleStyle,
                );

                if (dense || narrow || !title.showDetails) {
                  return Align(
                    alignment: AlignmentDirectional.topStart,
                    child: titleWidget,
                  );
                }

                final details = <Widget>[
                  Text(
                    _formatOccurrenceTime(context, occurrence),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: detailStyle,
                  ),
                  if (occurrence.event.location.isNotEmpty)
                    Text(
                      occurrence.event.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: locationStyle,
                    ),
                ];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleWidget,
                    const SizedBox(height: 2),
                    ...details,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _MoreOccurrencesCard extends StatelessWidget {
  const _MoreOccurrencesCard({
    required this.occurrence,
    required this.count,
    required this.dense,
    required this.narrow,
    required this.overlapping,
    required this.onTap,
  });

  final GeneralEventOccurrence occurrence;
  final int count;
  final bool dense;
  final bool narrow;
  final bool overlapping;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final color = effectiveGeneralOccurrenceColor(context, occurrence);
    final fillColor = _timelineOccurrenceFillColor(color, colorScheme);
    final accentColor = _timelineOccurrenceAccentColor(
      color,
      colorScheme,
      fillColor,
    );
    final label = l10n.moreEvents(count);
    final visualLabel = narrow ? '+$count' : label;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(narrow ? 7 : 8),
      side: BorderSide(
        color: accentColor.withValues(alpha: overlapping ? 0.70 : 0.50),
        width: overlapping ? 1.1 : 0.9,
      ),
    );
    final text = Text(
      visualLabel,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      textAlign: TextAlign.center,
      style: (narrow ? theme.textTheme.labelSmall : theme.textTheme.labelMedium)
          ?.copyWith(
            color: accentColor,
            fontWeight: FontWeight.w800,
            height: 1.08,
          ),
    );

    return Material(
      key: ValueKey(
        'general-timed-more-occurrences-'
        '${occurrence.event.id}-${occurrence.start.toIso8601String()}',
      ),
      color: fillColor,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        button: true,
        label: label,
        child: InkWell(
          customBorder: shape,
          overlayColor: _timelineOccurrenceOverlayColor(accentColor),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: narrow ? 3 : 7,
              vertical: dense ? 4 : 6,
            ),
            child: Center(
              child: narrow
                  ? FittedBox(
                      fit: BoxFit.scaleDown,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 1),
                        child: text,
                      ),
                    )
                  : text,
            ),
          ),
        ),
      ),
    );
  }
}

StrutStyle? _timelineTitleStrutStyle(TextStyle? style, bool narrow) {
  final fontSize = style?.fontSize;
  if (fontSize == null) {
    return null;
  }
  return StrutStyle(
    fontSize: fontSize,
    height: narrow ? 1.04 : 1.06,
    forceStrutHeight: true,
  );
}

class _TimelineOccurrenceTitleLayout {
  _TimelineOccurrenceTitleLayout({
    required String text,
    required TextStyle? style,
    required double maxWidth,
    required double maxHeight,
    required TextDirection textDirection,
    required bool narrow,
  }) {
    final safeWidth = maxWidth.isFinite && maxWidth > 0 ? maxWidth : 1.0;
    final safeHeight = maxHeight.isFinite && maxHeight > 0 ? maxHeight : 28.0;
    final fontSize = style?.fontSize ?? 12.0;
    final lineHeight = fontSize * (style?.height ?? 1.15);
    final possibleLines = math.max(1, (safeHeight / lineHeight).floor());
    final cappedPossibleLines = possibleLines.clamp(1, narrow ? 4 : 5).toInt();

    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: textDirection,
      maxLines: 8,
    )..layout(maxWidth: safeWidth);
    final neededLines = math.max(1, painter.computeLineMetrics().length);
    final titleFits = neededLines <= cappedPossibleLines;
    final detailsHeight = lineHeight + 4;

    maxLines = titleFits ? neededLines : cappedPossibleLines;
    showDetails =
        !narrow &&
        titleFits &&
        neededLines <= 2 &&
        safeWidth >= 64 &&
        safeHeight >= neededLines * lineHeight + detailsHeight;
  }

  late final int maxLines;
  late final bool showDetails;
}

Color _timelineOccurrenceFillColor(Color color, ColorScheme colorScheme) {
  final surface = colorScheme.brightness == Brightness.dark
      ? colorScheme.surfaceContainerHigh
      : colorScheme.surfaceContainerLow;
  final alpha = colorScheme.brightness == Brightness.dark ? 0.20 : 0.10;
  return Color.alphaBlend(color.withValues(alpha: alpha), surface);
}

Color _timelineOccurrenceAccentColor(
  Color color,
  ColorScheme colorScheme,
  Color fillColor,
) {
  var candidate = color.withValues(alpha: 1);
  if (_contrastRatio(candidate, fillColor) >= 3.0) {
    return candidate;
  }

  final target = colorScheme.brightness == Brightness.dark
      ? Colors.white
      : Colors.black;
  for (final alpha in const [0.18, 0.32, 0.46, 0.60]) {
    candidate = Color.alphaBlend(target.withValues(alpha: alpha), color);
    if (_contrastRatio(candidate, fillColor) >= 3.0) {
      return candidate;
    }
  }
  return colorScheme.brightness == Brightness.dark
      ? colorScheme.primaryContainer
      : colorScheme.primary;
}

WidgetStateProperty<Color?> _timelineOccurrenceOverlayColor(Color accentColor) {
  return WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.pressed)) {
      return accentColor.withValues(alpha: 0.18);
    }
    if (states.contains(WidgetState.hovered) ||
        states.contains(WidgetState.focused)) {
      return accentColor.withValues(alpha: 0.12);
    }
    return null;
  });
}

double _contrastRatio(Color a, Color b) {
  final aLuminance = a.computeLuminance();
  final bLuminance = b.computeLuminance();
  final lighter = math.max(aLuminance, bLuminance);
  final darker = math.min(aLuminance, bLuminance);
  return (lighter + 0.05) / (darker + 0.05);
}
