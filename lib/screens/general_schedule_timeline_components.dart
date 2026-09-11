part of 'general_schedule_home_screen.dart';

class _AllDayTimeline extends StatefulWidget {
  const _AllDayTimeline({
    required this.timeColumnWidth,
    required this.dayWidth,
    required this.dayCount,
    required this.layout,
    required this.label,
    required this.maxHeight,
    required this.collapsed,
    required this.canCollapse,
    required this.onToggleCollapsed,
    required this.onCollapsedGroupTap,
    required this.onOccurrenceTap,
  });
  final double timeColumnWidth;
  final double dayWidth;
  final int dayCount;
  final _AllDayTimelineLayout layout;
  final String label;
  final double maxHeight;
  final bool collapsed;
  final bool canCollapse;
  final VoidCallback? onToggleCollapsed;
  final ValueChanged<_AllDayCollapsedGroup> onCollapsedGroupTap;
  final ValueChanged<GeneralEventOccurrence> onOccurrenceTap;
  @override
  State<_AllDayTimeline> createState() => _AllDayTimelineState();
}

class _AllDayTimelineState extends State<_AllDayTimeline> {
  final _scroll = ScrollController();
  bool _expanded = false;
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layout = widget.layout;
    final laneHeight = layout.laneHeightFor(context);
    final m = WorkbenchChromeMetrics.of(context);
    final l = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final full = _expanded && !widget.collapsed;
    final contentHeight = layout.heightFor(
      context,
      collapsed: widget.collapsed,
      expanded: full,
    );
    final height = math.min(
      contentHeight,
      math.max(laneHeight, widget.maxHeight),
    );
    final toggleLabel = widget.collapsed
        ? l.expandAllDayTimeline
        : l.collapseAllDayTimeline;
    final hasOverflow = !widget.collapsed && !full && layout.hiddenCount > 0;
    return SizedBox(
      key: ValueKey(
        widget.collapsed
            ? 'general-all-day-collapsed-state'
            : 'general-all-day-expanded-state',
      ),
      height: height,
      child: Stack(
        key: const ValueKey('general-all-day-timeline'),
        children: [
          PositionedDirectional(
            start: widget.timeColumnWidth,
            top: 0,
            bottom: 0,
            width: widget.dayWidth * widget.dayCount,
            child: SizedBox(
              width: widget.dayWidth * widget.dayCount,
              child: Scrollbar(
                controller: _scroll,
                thumbVisibility: full,
                child: SingleChildScrollView(
                  key: const ValueKey('general-all-day-expanded-scroll'),
                  controller: _scroll,
                  primary: false,
                  child: SizedBox(
                    height: contentHeight,
                    child: Stack(
                      children: [
                        for (var i = 1; i < widget.dayCount; i++)
                          PositionedDirectional(
                            start: i * widget.dayWidth,
                            top: 0,
                            bottom: 0,
                            width: 1,
                            child: ColoredBox(
                              color: colors.outlineVariant.withValues(
                                alpha: .55,
                              ),
                            ),
                          ),
                        if (widget.collapsed)
                          for (final group in layout.collapsedGroups)
                            PositionedDirectional(
                              start: group.dayIndex * widget.dayWidth,
                              top: 0,
                              width: widget.dayWidth,
                              height: contentHeight,
                              child: _AllDayCollapsedChip(
                                count: group.occurrences.length,
                                keySuffix: widget.dayCount > 1
                                    ? group.dayIndex.toString()
                                    : null,
                                onTap: () => widget.onCollapsedGroupTap(group),
                              ),
                            )
                        else
                          for (final segment
                              in full
                                  ? layout.segments
                                  : layout.visibleSegments)
                            PositionedDirectional(
                              start: segment.startIndex * widget.dayWidth,
                              top:
                                  _AllDayTimelineLayout.verticalPadding +
                                  segment.lane *
                                      (laneHeight +
                                          _AllDayTimelineLayout.laneGap),
                              width:
                                  (segment.endIndex - segment.startIndex + 1) *
                                  widget.dayWidth,
                              height: laneHeight,
                              child: _AllDayChip(
                                occurrence: segment.occurrence,
                                narrow: widget.dayWidth < 64,
                                onTap: () =>
                                    widget.onOccurrenceTap(segment.occurrence),
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          _PinnedTimelineRail(
            width: widget.timeColumnWidth,
            child: SizedBox(
              width: widget.timeColumnWidth,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surface,
                  border: BorderDirectional(
                    end: BorderSide(color: colors.outlineVariant),
                  ),
                ),
                child: SingleChildScrollView(
                  primary: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tooltip(
                        message: toggleLabel,
                        child: TextButton(
                          key: const ValueKey('general-all-day-toggle'),
                          style: TextButton.styleFrom(
                            minimumSize: Size(m.iconTarget, m.iconTarget),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: full
                              ? () => setState(() => _expanded = false)
                              : widget.onToggleCollapsed,
                          child: Text(
                            widget.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                      ),
                      if (hasOverflow)
                        SizedBox(
                          width: m.desktop ? 36 : 48,
                          height: m.desktop ? 28 : 48,
                          child: _AllDayMoreChip(
                            count: layout.hiddenCount,
                            onTap: () => setState(() => _expanded = true),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
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
    final selection = WorkspaceSelectionScope.of(context);
    final selected =
        selection == occurrence.occurrenceKey ||
        selection == 'event:${occurrence.event.id}';
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(
        WorkbenchChromeMetrics.of(context).desktop ? 4 : 8,
      ),
      side: BorderSide(
        color: accentColor.withValues(alpha: 0.42),
        width: selected ? 2 : 0.8,
      ),
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
            selected: selected,
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
  const _AllDayMoreChip({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

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
          key: ValueKey('general-all-day-more-occurrences'),
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
    final lineColor = colors.outlineVariant.withValues(alpha: 0.42);
    final columnColor = colors.outlineVariant.withValues(alpha: 0.65);
    final minorColor = colors.outlineVariant.withValues(alpha: 0.18);
    final gridStep = gridMinutes.clamp(15, 60).toInt();
    return Stack(
      children: [
        for (var hour = startHour; hour <= endHour; hour++)
          PositionedDirectional(
            start: timeColumnWidth,
            end: 0,
            top: topOffset + (hour - startHour) * hourHeight,
            child: Divider(height: 1, color: lineColor),
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
            child: VerticalDivider(width: 1, color: columnColor),
          ),
      ],
    );
  }
}

/// The time scale stays in the same vertical scroll view as the event grid,
/// but counter-translates the horizontal calendar offset through its rail.
class _TimelineTimeRuler extends StatelessWidget {
  const _TimelineTimeRuler({
    required this.startHour,
    required this.endHour,
    required this.hourHeight,
    required this.topOffset,
  });
  final int startHour, endHour;
  final double hourHeight, topOffset;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeLabelColor = theme.colorScheme.onSurfaceVariant;
    return Stack(
      children: [
        for (var hour = startHour; hour <= endHour; hour++)
          PositionedDirectional(
            start: 0,
            top:
                topOffset +
                (hour - startHour) * hourHeight -
                12 *
                    WorkbenchLayoutPolicy.textFactor(
                      MediaQuery.textScalerOf(context).scale(14) / 14,
                    ),
            end: 0,
            height:
                24 *
                WorkbenchLayoutPolicy.textFactor(
                  MediaQuery.textScalerOf(context).scale(14) / 14,
                ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Text(
                  '${hour.toString().padLeft(2, '0')}:00',
                  textAlign: TextAlign.right,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: timeLabelColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
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
    final detailColor = accentColor;
    final selection = WorkspaceSelectionScope.of(context);
    final selected =
        selection == occurrence.occurrenceKey ||
        selection == 'event:${occurrence.event.id}';
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(
        compactStrip ? 2 : (WorkbenchChromeMetrics.of(context).desktop ? 4 : 8),
      ),
      side: BorderSide(
        color: overlapping
            ? accentColor.withValues(alpha: 0.74)
            : accentColor.withValues(alpha: 0.46),
        width: selected
            ? 2.4
            : overlapping
            ? 1.1
            : 0.9,
      ),
    );
    final titleText = occurrence.event.title;
    final titleStyle =
        (narrow ? theme.textTheme.labelMedium : theme.textTheme.bodyMedium)
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
        selected: selected,
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
                        textScaler: MediaQuery.textScalerOf(context),
                        detailLines: occurrence.event.location.isEmpty ? 1 : 2,
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
    required this.compactStrip,
    required this.onTap,
  });
  final GeneralEventOccurrence occurrence;
  final int count;
  final bool compactStrip;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = AppLocalizations.of(context).moreEvents(count);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(4),
    );
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: Material(
        key: ValueKey(
          'general-timed-more-occurrences-'
          '${occurrence.event.id}-${occurrence.start.toIso8601String()}',
        ),
        color: theme.colorScheme.surfaceContainerHigh,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: Semantics(
          label: label,
          button: true,
          onTap: onTap,
          excludeSemantics: true,
          child: InkWell(
            customBorder: shape,
            onTap: onTap,
            child: Center(
              child: compactStrip
                  ? const SizedBox.shrink()
                  : Text(
                      '+$count',
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
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
    TextScaler textScaler = TextScaler.noScaling,
    int detailLines = 1,
  }) {
    final safeWidth = maxWidth.isFinite && maxWidth > 0 ? maxWidth : 1.0;
    final safeHeight = maxHeight.isFinite && maxHeight > 0 ? maxHeight : 28.0;
    final fontSize = style?.fontSize ?? 12.0;
    final lineHeight = textScaler.scale(fontSize) * (style?.height ?? 1.15);
    final possibleLines = math.max(1, (safeHeight / lineHeight).floor());
    final cappedPossibleLines = possibleLines.clamp(1, narrow ? 10 : 5).toInt();

    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textScaler: textScaler,
      strutStyle: _timelineTitleStrutStyle(style, narrow),
      textDirection: textDirection,
      maxLines: 8,
    )..layout(maxWidth: safeWidth);
    final neededLines = math.max(1, painter.computeLineMetrics().length);
    final titleFits = neededLines <= cappedPossibleLines;
    final detailsHeight = lineHeight * detailLines + 4;

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
  double minimumContrast = 4.5,
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
