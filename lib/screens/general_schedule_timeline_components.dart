part of 'general_schedule_home_screen.dart';

class _TimelineTimeRailLabel extends StatelessWidget {
  const _TimelineTimeRailLabel({
    required this.width,
    required this.child,
    this.onTap,
    this.tooltip,
    this.expanded = false,
  });

  final double width;
  final Widget child;
  final VoidCallback? onTap;
  final String? tooltip;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final content = SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Align(
          alignment: Alignment.center,
          child: FittedBox(fit: BoxFit.scaleDown, child: child),
        ),
      ),
    );
    final border = BoxDecoration(
      border: BorderDirectional(
        end: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.55)),
      ),
    );
    final background = colors.surfaceContainerLow.withValues(alpha: 0.72);
    final onTap = this.onTap;
    if (onTap == null) {
      return DecoratedBox(
        decoration: border.copyWith(color: background),
        child: content,
      );
    }
    final interactive = Semantics(
      button: true,
      expanded: expanded,
      label: tooltip,
      onTap: onTap,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: border,
        child: Material(
          color: background,
          child: InkWell(onTap: onTap, child: content),
        ),
      ),
    );
    return tooltip == null
        ? interactive
        : Tooltip(
            message: tooltip!,
            excludeFromSemantics: true,
            child: interactive,
          );
  }
}

class _AllDayTimeline extends StatelessWidget {
  const _AllDayTimeline({
    required this.timeColumnWidth,
    required this.dayWidth,
    required this.dayCount,
    required this.layout,
    required this.label,
    required this.collapsed,
    required this.canCollapse,
    required this.onToggleCollapsed,
    required this.onCollapsedGroupTap,
    required this.onOccurrenceTap,
    required this.onMoreOccurrencesTap,
  });

  final double timeColumnWidth;
  final double dayWidth;
  final int dayCount;
  final _AllDayTimelineLayout layout;
  final String label;
  final bool collapsed;
  final bool canCollapse;
  final VoidCallback? onToggleCollapsed;
  final ValueChanged<_AllDayCollapsedGroup> onCollapsedGroupTap;
  final ValueChanged<GeneralEventOccurrence> onOccurrenceTap;
  final ValueChanged<List<GeneralEventOccurrence>> onMoreOccurrencesTap;

  @override
  Widget build(BuildContext context) {
    final laneHeight = layout.laneHeightFor(context);
    final dayAreaWidth = dayWidth * dayCount;
    final lineColor = Theme.of(context).colorScheme.outlineVariant
        .withValues(alpha: 0.55);
    final l10n = AppLocalizations.of(context);
    final toggleLabel = collapsed
        ? l10n.expandAllDayTimeline
        : l10n.collapseAllDayTimeline;
    return Row(
      key: const ValueKey('general-all-day-timeline'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TimelineTimeRailLabel(
          width: timeColumnWidth,
          onTap: canCollapse ? onToggleCollapsed : null,
          tooltip: canCollapse ? toggleLabel : null,
          expanded: !collapsed,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
        SizedBox(
          width: dayAreaWidth,
          child: ClipRect(
            child: Stack(
              children: [
                for (var index = 1; index <= dayCount; index++)
                  PositionedDirectional(
                    start: index * dayWidth,
                    top: 0,
                    bottom: 0,
                    width: 1,
                    child: ColoredBox(color: lineColor),
                  ),
                if (collapsed)
                  for (final group in layout.collapsedGroups)
                    PositionedDirectional(
                      start: group.dayIndex * dayWidth,
                      top: 0,
                      width: dayWidth,
                      height: math.max(48, laneHeight),
                      child: _AllDayCollapsedChip(
                        count: group.occurrences.length,
                        keySuffix: dayCount > 1
                            ? group.dayIndex.toString()
                            : null,
                        onTap: () => onCollapsedGroupTap(group),
                      ),
                    )
                else ...[
                  for (final segment in layout.visibleSegments)
                    PositionedDirectional(
                      start: segment.startIndex * dayWidth,
                      top:
                          _AllDayTimelineLayout.verticalPadding +
                          segment.lane *
                              (laneHeight + _AllDayTimelineLayout.laneGap),
                      width:
                          (segment.endIndex - segment.startIndex + 1) *
                          dayWidth,
                      height: laneHeight,
                      child: _AllDayChip(
                        occurrence: segment.occurrence,
                        narrow:
                            (segment.endIndex - segment.startIndex + 1) *
                                dayWidth <
                            64,
                        onTap: () => onOccurrenceTap(segment.occurrence),
                      ),
                    ),
                  for (final group in layout.overflowGroups)
                    PositionedDirectional(
                      start: group.startIndex * dayWidth,
                      top:
                          _AllDayTimelineLayout.verticalPadding +
                          layout.visibleLaneCount *
                              (laneHeight + _AllDayTimelineLayout.laneGap),
                      width: (group.endIndex - group.startIndex + 1) * dayWidth,
                      height: laneHeight,
                      child: _AllDayMoreChip(
                        count: group.occurrences.length,
                        keySuffix: layout.overflowGroups.length > 1
                            ? '${group.startIndex}-${group.endIndex}'
                            : null,
                        onTap: () => onMoreOccurrencesTap(group.occurrences),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AllDayChip extends StatelessWidget {
  const _AllDayChip({
    required this.occurrence,
    required this.narrow,
    required this.onTap,
  });

  final GeneralEventOccurrence occurrence;
  final bool narrow;
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
      minimumContrast: 4.5,
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(color: accentColor.withValues(alpha: 0.42), width: 0.8),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Tooltip(
        message: occurrence.event.title,
        excludeFromSemantics: true,
        child: Material(
          key: ValueKey(
            'general-all-day-occurrence-'
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
                padding: EdgeInsets.symmetric(horizontal: narrow ? 3 : 8),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    occurrence.event.title,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: accentColor,
                      fontWeight: FontWeight.w700,
                    ),
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

class _AllDayCollapsedChip extends StatelessWidget {
  const _AllDayCollapsedChip({
    required this.count,
    required this.onTap,
    this.keySuffix,
  });

  final int count;
  final VoidCallback onTap;
  final String? keySuffix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    );
    final label = count.toString();
    final semanticLabel = AppLocalizations.of(context).allDayEventsCount(count);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 3,
        vertical: _AllDayTimelineLayout.verticalPadding,
      ),
      child: Tooltip(
        message: semanticLabel,
        excludeFromSemantics: true,
        child: Material(
          key: ValueKey(
            'general-all-day-collapsed${keySuffix == null ? '' : '-$keySuffix'}',
          ),
          color: colors.secondaryContainer,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: Semantics(
            button: true,
            label: semanticLabel,
            onTap: onTap,
            excludeSemantics: true,
            child: InkWell(
              customBorder: shape,
              onTap: onTap,
              child: Center(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSecondaryContainer,
                    fontWeight: FontWeight.w700,
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

class _AllDayMoreChip extends StatelessWidget {
  const _AllDayMoreChip({
    required this.count,
    required this.onTap,
    this.keySuffix,
  });

  final int count;
  final VoidCallback onTap;
  final String? keySuffix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final semanticLabel = AppLocalizations.of(context).moreEvents(count);
    final label = '+$count';
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Tooltip(
        message: semanticLabel,
        excludeFromSemantics: true,
        child: Material(
          key: ValueKey(
            'general-all-day-more-occurrences${keySuffix == null ? '' : '-$keySuffix'}',
          ),
          color: colors.secondaryContainer,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: Semantics(
            button: true,
            label: semanticLabel,
            onTap: onTap,
            excludeSemantics: true,
            child: InkWell(
              customBorder: shape,
              onTap: onTap,
              child: Center(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSecondaryContainer,
                    fontWeight: FontWeight.w700,
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

class _GridBackground extends StatelessWidget {
  const _GridBackground({
    required this.timeColumnWidth,
    required this.dayWidth,
    required this.dayCount,
    required this.startHour,
    required this.endHour,
    required this.gridMinutes,
    required this.hourHeight,
    required this.topOffset,
  });

  final double timeColumnWidth;
  final double dayWidth;
  final int dayCount;
  final int startHour;
  final int endHour;
  final int gridMinutes;
  final double hourHeight;
  final double topOffset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final lineColor = colors.outlineVariant.withValues(alpha: 0.56);
    final minorColor = colors.outlineVariant.withValues(alpha: 0.28);
    final timeLabelColor = colors.onSurfaceVariant;
    final gridStep = gridMinutes.clamp(15, 60).toInt();
    return Stack(
      children: [
        PositionedDirectional(
          start: 0,
          top: 0,
          bottom: 0,
          child: Container(
            width: timeColumnWidth,
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow.withValues(alpha: 0.72),
              border: BorderDirectional(end: BorderSide(color: lineColor)),
            ),
          ),
        ),
        for (var hour = startHour; hour <= endHour; hour++)
          PositionedDirectional(
            start: timeColumnWidth,
            end: 0,
            top: topOffset + (hour - startHour) * hourHeight,
            child: Divider(height: 1, color: lineColor),
          ),
        for (var hour = startHour; hour <= endHour; hour++)
          PositionedDirectional(
            start: 0,
            top: topOffset + (hour - startHour) * hourHeight - 9,
            width: timeColumnWidth,
            height: 18,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
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
            PositionedDirectional(
              start: timeColumnWidth,
              end: 0,
              top: topOffset + minute / 60 * hourHeight,
              child: Divider(height: 1, color: minorColor),
            ),
        for (var day = 0; day <= dayCount; day++)
          PositionedDirectional(
            top: topOffset,
            bottom: topOffset,
            start: timeColumnWidth + day * dayWidth,
            child: VerticalDivider(width: 1, color: lineColor),
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
    required this.compactStrip,
    required this.overlapping,
    required this.onTap,
  });

  final GeneralEventOccurrence occurrence;
  final bool dense;
  final bool narrow;
  final bool compactStrip;
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
      borderRadius: BorderRadius.circular(compactStrip ? 2 : (narrow ? 7 : 8)),
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
          child: compactStrip
              ? const SizedBox.expand()
              : Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: narrow ? 2 : 7,
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
                        strutStyle: _timelineTitleStrutStyle(
                          titleStyle,
                          narrow,
                        ),
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
    required this.compactStrip,
    required this.overlapping,
    required this.onTap,
  });

  final GeneralEventOccurrence occurrence;
  final int count;
  final bool dense;
  final bool narrow;
  final bool compactStrip;
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
      borderRadius: BorderRadius.circular(compactStrip ? 2 : (narrow ? 7 : 8)),
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
          child: compactStrip
              ? const SizedBox.expand()
              : Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: narrow ? 2 : 7,
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
    final cappedPossibleLines = possibleLines.clamp(1, narrow ? 10 : 5).toInt();

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
  Color fillColor, {
  double minimumContrast = 3.0,
}) {
  var candidate = color.withValues(alpha: 1);
  if (_contrastRatio(candidate, fillColor) >= minimumContrast) {
    return candidate;
  }

  final target = colorScheme.brightness == Brightness.dark
      ? Colors.white
      : Colors.black;
  for (final alpha in const [0.18, 0.32, 0.46, 0.60, 0.76, 0.88]) {
    candidate = Color.alphaBlend(target.withValues(alpha: alpha), color);
    if (_contrastRatio(candidate, fillColor) >= minimumContrast) {
      return candidate;
    }
  }
  return colorScheme.onSurface;
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
