part of 'general_schedule_home_screen.dart';

class _ListCalendarView extends StatelessWidget {
  const _ListCalendarView({
    required this.date,
    required this.provider,
    required this.filter,
    required this.onToday,
    required this.onPickDate,
    required this.onOccurrenceTap,
  });

  final DateTime date;
  final TimetableProvider provider;
  final _GeneralOccurrenceFilter filter;
  final VoidCallback onToday;
  final VoidCallback onPickDate;
  final ValueChanged<GeneralEventOccurrence> onOccurrenceTap;

  @override
  Widget build(BuildContext context) {
    final start = normalizeDateOnly(date);
    final occurrences = provider.generalOccurrencesForQuery(
      filter.toQuery(
        startInclusive: start,
        endExclusive: start.add(const Duration(days: 180)),
      ),
    );
    if (occurrences.isEmpty) {
      return _GeneralEmptyListState(
        onToday: onToday,
        filtered: filter.isActive,
      );
    }
    final groups = <String, List<GeneralEventOccurrence>>{};
    for (final occurrence in occurrences) {
      final key = _dateKey(occurrence.start);
      groups.putIfAbsent(key, () => []).add(occurrence);
    }
    final entries = groups.entries.toList();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 88),
      itemCount: entries.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _ListJumpBar(onToday: onToday, onPickDate: onPickDate);
        }
        final group = entries[index - 1];
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

class _ListJumpBar extends StatelessWidget {
  const _ListJumpBar({required this.onToday, required this.onPickDate});

  final VoidCallback onToday;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 2),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: onToday,
            icon: const Icon(Icons.today_outlined),
            label: Text(l10n.today),
          ),
          OutlinedButton.icon(
            onPressed: onPickDate,
            icon: const Icon(Icons.event_outlined),
            label: Text(l10n.pickDate),
          ),
        ],
      ),
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
    final repeatIcon = occurrence.event.recurrenceRule.isRepeating
        ? Icon(Icons.repeat, color: colors.primary, size: 20)
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
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
                  height: 44,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
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
  const _GeneralEmptyListState({required this.onToday, required this.filtered});

  final VoidCallback onToday;
  final bool filtered;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ExpressiveEmptyState(
      icon: Icons.event_available_outlined,
      title: filtered ? l10n.noMatchingEvents : l10n.noUpcomingEvents,
      actions: [
        OutlinedButton.icon(
          onPressed: onToday,
          icon: const Icon(Icons.today_outlined),
          label: Text(l10n.today),
        ),
      ],
    );
  }
}
