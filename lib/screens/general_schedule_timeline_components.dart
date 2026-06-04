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
    required this.onTap,
  });

  final GeneralEventOccurrence occurrence;
  final bool dense;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = effectiveGeneralOccurrenceColor(context, occurrence);
    final textColor = _readableColor(color);
    final title = Text(
      occurrence.event.title,
      maxLines: dense ? 1 : 2,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.labelMedium?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w700,
      ),
    );
    return Material(
      color: color.withAlpha(210),
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        button: true,
        label: occurrence.event.title,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 8,
              vertical: dense ? 3 : 6,
            ),
            child: dense
                ? Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: title,
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      title,
                      const SizedBox(height: 2),
                      Text(
                        _formatOccurrenceTime(context, occurrence),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: textColor.withAlpha(220),
                        ),
                      ),
                      if (occurrence.event.location.isNotEmpty)
                        Text(
                          occurrence.event.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: textColor.withAlpha(220),
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
