part of 'general_schedule_home_screen.dart';

class _ListCalendarView extends StatelessWidget {
  const _ListCalendarView({
    required this.date,
    required this.provider,
    required this.filter,
    required this.onOccurrenceTap,
  });

  final DateTime date;
  final TimetableProvider provider;
  final _GeneralOccurrenceFilter filter;
  final ValueChanged<GeneralEventOccurrence> onOccurrenceTap;

  @override
  Widget build(BuildContext context) {
    final start = normalizeDateOnly(date);
    final occurrences = provider.generalOccurrencesForQuery(
      filter.toQuery(
        startInclusive: start,
        endExclusive: addCalendarDays(start, 180),
      ),
    );
    if (occurrences.isEmpty) {
      return _GeneralEmptyListState(filtered: filter.isActive);
    }
    final groups = <String, List<GeneralEventOccurrence>>{};
    for (final occurrence in occurrences) {
      final key = _calendarDateKey(occurrence.calendarDisplayStart);
      groups.putIfAbsent(key, () => []).add(occurrence);
    }
    final entries = groups.entries.toList();
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        16,
        6,
        16,
        WorkbenchChromeMetrics.of(context).desktop ? 24 : 88,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final group = entries[index];
        final date = DateTime.parse(group.key);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
              child: Text(
                '${_formatDate(date)}  ${_weekdayLabel(context, date)}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            for (final occurrence in group.value)
              _GeneralListOccurrenceTile(
                occurrence: occurrence,
                onTap: () => onOccurrenceTap(occurrence),
              ),
          ],
        );
      },
    );
  }
}

class _GeneralListOccurrenceTile extends StatelessWidget {
  const _GeneralListOccurrenceTile({
    required this.occurrence,
    required this.onTap,
  });

  final GeneralEventOccurrence occurrence;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final color = effectiveGeneralOccurrenceColor(context, occurrence);
    final subtitle = [
      _formatOccurrenceTime(context, occurrence),
      if (occurrence.event.location.isNotEmpty) occurrence.event.location,
      occurrence.calendar.name,
    ].join('  |  ');
    final selected =
        WorkspaceSelectionScope.of(context) == occurrence.occurrenceKey ||
        WorkspaceSelectionScope.of(context) == 'event:${occurrence.event.id}';
    final repeatIcon = occurrence.event.recurrenceRule.isRepeating
        ? Icon(Icons.repeat, color: colors.primary, size: 20)
        : null;

    if (WorkbenchChromeMetrics.of(context).desktop) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final inline =
              constraints.maxWidth >=
              600 * WorkbenchChromeMetrics.of(context).textScale;
          final title = Text(
            occurrence.event.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          );
          return Semantics(
            selected: selected,
            button: true,
            child: Material(
              color: selected
                  ? colors.secondaryContainer.withValues(alpha: .65)
                  : Colors.transparent,
              child: InkWell(
                onTap: onTap,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 10,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: colors.outlineVariant.withValues(alpha: .4),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: inline ? 132 : 104,
                        child: Text(
                          _formatOccurrenceTime(context, occurrence),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: inline
                            ? title
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  title,
                                  Text(
                                    [
                                      if (occurrence.event.location.isNotEmpty)
                                        occurrence.event.location,
                                      occurrence.calendar.name,
                                    ].join(' · '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                      ),
                      if (inline) ...[
                        const SizedBox(width: 20),
                        SizedBox(
                          width: 150,
                          child: Text(
                            occurrence.event.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 120,
                          child: Text(
                            occurrence.calendar.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                      if (repeatIcon != null)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(start: 8),
                          child: repeatIcon,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? colors.secondaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        occurrence.event.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (repeatIcon != null) ...[
                  const SizedBox(width: 8),
                  repeatIcon,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GeneralEmptyListState extends StatelessWidget {
  const _GeneralEmptyListState({required this.filtered});

  final bool filtered;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ExpressiveEmptyState(
      icon: Icons.event_available_outlined,
      title: filtered ? l10n.noMatchingEvents : l10n.noUpcomingEvents,
    );
  }
}
