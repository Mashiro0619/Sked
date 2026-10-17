part of 'general_schedule_home_screen.dart';

class _ListCalendarSource extends StatefulWidget {
  const _ListCalendarSource({
    required this.date,
    required this.view,
    required this.filter,
    required this.onOccurrenceTap,
  });

  final DateTime date;
  final GeneralViewState view;
  final _GeneralOccurrenceFilter filter;
  final _GeneralOccurrenceTap onOccurrenceTap;

  @override
  State<_ListCalendarSource> createState() => _ListCalendarSourceState();
}

class _ListCalendarSourceState extends State<_ListCalendarSource> {
  final _projection = GeneralListProjectionCache();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.view,
    builder: (context, _) => _buildSnapshot(context),
  );

  Widget _buildSnapshot(BuildContext context) {
    final start = normalizeDateOnly(widget.date);
    final occurrences = widget.view.occurrencesForQuery(
      widget.filter.toQuery(
        startInclusive: start,
        endExclusive: addCalendarDays(start, 180),
      ),
    );
    return _ListCalendarView(
      snapshot: _projection.project(occurrences),
      filtered: widget.filter.isActive,
      onOccurrenceTap: widget.onOccurrenceTap,
    );
  }
}

class _ListCalendarView extends StatelessWidget {
  const _ListCalendarView({
    required this.snapshot,
    required this.filtered,
    required this.onOccurrenceTap,
  });

  final GeneralListSnapshot snapshot;
  final bool filtered;
  final _GeneralOccurrenceTap onOccurrenceTap;

  @override
  Widget build(BuildContext context) {
    if (snapshot.isEmpty) {
      return _GeneralEmptyListState(filtered: filtered);
    }
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        16,
        6,
        16,
        WorkbenchChromeMetrics.of(context).desktop ? 24 : 88,
      ),
      itemCount: snapshot.rowCount,
      addSemanticIndexes: false,
      semanticChildCount: snapshot.occurrenceCount,
      findChildIndexCallback: (key) => key is ValueKey<GeneralListRowKey>
          ? snapshot.rowIndexOf(key.value)
          : null,
      itemBuilder: (context, index) {
        final row = snapshot.rowAt(index);
        final key = ValueKey(row.key);
        final occurrence = row.occurrence;
        if (occurrence == null) {
          return Padding(
            key: key,
            padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
            child: Semantics(
              header: true,
              child: Text(
                '${_formatDate(row.date)}  ${_weekdayLabel(context, row.date)}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          );
        }
        return IndexedSemantics(
          key: key,
          index: row.semanticIndex!,
          child: Builder(
            builder: (anchor) => _GeneralListOccurrenceTile(
              occurrence: occurrence,
              onTap: () => onOccurrenceTap(occurrence, anchor),
            ),
          ),
        );
      },
    );
  }
}

class _GeneralListOccurrenceTile extends StatelessWidget {
  const _GeneralListOccurrenceTile({
    this.compactPanel = false,
    required this.occurrence,
    required this.onTap,
  });

  final GeneralEventOccurrence occurrence;
  final VoidCallback onTap;
  final bool compactPanel;

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
        ? Icon(
            Icons.repeat,
            color: skedReadableAccent(
              colors,
              surface: SkedSurface.colorOf(context),
            ),
            size: 20,
          )
        : null;

    if (WorkbenchChromeMetrics.of(context).desktop) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final inline =
              !compactPanel &&
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
                  padding: EdgeInsets.symmetric(
                    vertical: compactPanel ? 6 : 8,
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
                        width: inline ? 132 : (compactPanel ? 88 : 104),
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
                      SizedBox(width: compactPanel ? 8 : 12),
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
