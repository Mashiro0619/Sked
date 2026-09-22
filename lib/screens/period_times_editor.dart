part of 'period_times_page.dart';

enum _PeriodEditorSaveState { invalid, failed, saving, pending, saved }

class _PeriodEditorHeading extends StatelessWidget {
  const _PeriodEditorHeading({
    required this.controller,
    required this.periodCount,
    required this.saveState,
    required this.onChanged,
    required this.onSubmitted,
    required this.onRetry,
  });

  final TextEditingController controller;
  final int periodCount;
  final _PeriodEditorSaveState saveState;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final nameMinimum = math.max(
          280.0,
          _periodTextSize(
                context,
                l.periodTimeSetName,
                theme.textTheme.bodyLarge,
              ).width +
              48,
        );
        final statusMinimum = math.max(
          220.0,
          _periodTextSize(
                context,
                l.savingChanges,
                theme.textTheme.bodySmall,
              ).width +
              56,
        );
        final sideBySide =
            constraints.maxWidth >= nameMinimum + statusMinimum + 24;
        final name = TextField(
          key: const ValueKey('period-times-name'),
          controller: controller,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(labelText: l.periodTimeSetName),
        );
        final count = Text(
          l.periodTimesCount(periodCount),
          key: const ValueKey('period-times-count'),
          style: theme.textTheme.bodyMedium,
        );
        final status = _PeriodEditorSaveStatus(
          state: saveState,
          onRetry: onRetry,
        );
        final countWidth = _periodTextSize(
          context,
          l.periodTimesCount(periodCount),
          theme.textTheme.bodyMedium,
        ).width;
        final inlineSummary =
            !sideBySide &&
            constraints.maxWidth >= countWidth + statusMinimum + 16;
        final summary = inlineSummary
            ? Row(
                children: [
                  count,
                  const SizedBox(width: 16),
                  Expanded(child: status),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [count, const SizedBox(height: 2), status],
              );
        if (!sideBySide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [name, const SizedBox(height: 12), summary],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: math.min(360.0, constraints.maxWidth - statusMinimum - 24),
              child: name,
            ),
            const SizedBox(width: 24),
            Expanded(child: summary),
          ],
        );
      },
    );
  }
}

class _PeriodEditorSaveStatus extends StatelessWidget {
  const _PeriodEditorSaveStatus({required this.state, required this.onRetry});
  final _PeriodEditorSaveState state;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final metrics = WorkbenchChromeMetrics.of(context);
    final messages = {
      _PeriodEditorSaveState.invalid: l.periodTimesInvalidStatus,
      _PeriodEditorSaveState.failed: l.periodTimesSaveFailed,
      _PeriodEditorSaveState.saving: l.savingChanges,
      _PeriodEditorSaveState.pending: l.periodTimesSavePending,
      _PeriodEditorSaveState.saved: l.periodTimesSaved,
    };
    final error =
        state == _PeriodEditorSaveState.invalid ||
        state == _PeriodEditorSaveState.failed;
    final style = theme.textTheme.bodySmall?.copyWith(
      color: error
          ? theme.colorScheme.error
          : theme.colorScheme.onSurfaceVariant,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // Reserve the longest localized status and the retry target in every state.
        // Saving, validation and failure feedback must not move the time rows.
        final textWidth = math.max(
          1.0,
          constraints.maxWidth - metrics.iconTarget - 8,
        );
        final height = messages.values.fold<double>(
          metrics.iconTarget,
          (height, message) => math.max(
            height,
            _periodTextSize(
              context,
              message,
              style,
              maxWidth: textWidth,
            ).height,
          ),
        );
        return SizedBox(
          key: const ValueKey('period-times-save-status'),
          height: height,
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Text(messages[state]!, style: style),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox.square(
                dimension: metrics.iconTarget,
                child: state == _PeriodEditorSaveState.failed
                    ? IconButton(
                        key: const ValueKey('period-times-retry-save'),
                        tooltip: l.retrySave,
                        style: metrics.iconStyle,
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh),
                      )
                    : null,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PeriodTableColumns {
  const _PeriodTableColumns({
    required this.period,
    required this.time,
    required this.duration,
    required this.gap,
    required this.action,
  });
  final double period;
  final double time;
  final double duration;
  final double gap;
  final double action;

  static _PeriodTableColumns? resolve(
    BuildContext context,
    double width,
    List<CoursePeriodTime> periods,
  ) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final metrics = WorkbenchChromeMetrics.of(context);
    double measure(String text, TextStyle? style) =>
        _periodTextSize(context, text, style).width;
    final timeStyle = _periodTimeStyle(context);
    final periodWidth =
        periods.fold<double>(
          measure(l.periodTimesPeriodColumn, theme.textTheme.labelMedium),
          (width, period) => math.max(
            width,
            measure(
              l.periodNumberLabel(period.index),
              theme.textTheme.bodyMedium,
            ),
          ),
        ) +
        12;
    final timeWidth = math.max(
      periods.fold<double>(
            measure('88:88', timeStyle),
            (width, period) => math.max(
              width,
              math.max(
                measure(formatMinutes(period.startMinutes), timeStyle),
                measure(formatMinutes(period.endMinutes), timeStyle),
              ),
            ),
          ) +
          24,
      math.max(
            measure(l.startTime, theme.textTheme.labelMedium),
            measure(l.endTime, theme.textTheme.labelMedium),
          ) +
          16,
    );
    var durationWidth = measure(
      l.periodTimesDurationColumn,
      theme.textTheme.labelMedium,
    );
    var gapWidth = measure(l.periodTimesGapColumn, theme.textTheme.labelMedium);
    for (var i = 0; i < periods.length; i++) {
      final duration = periods[i].endMinutes - periods[i].startMinutes;
      final gap = i == 0
          ? null
          : periods[i].startMinutes - periods[i - 1].endMinutes;
      if (duration > 0) {
        durationWidth = math.max(
          durationWidth,
          measure(
            l.periodTimesMinutesShort(duration),
            theme.textTheme.bodySmall,
          ),
        );
      }
      if (gap != null && gap >= 0) {
        gapWidth = math.max(
          gapWidth,
          measure(l.periodTimesMinutesShort(gap), theme.textTheme.bodySmall),
        );
      }
    }
    final columns = _PeriodTableColumns(
      period: periodWidth,
      time: math.max(timeWidth, metrics.iconTarget),
      duration: durationWidth + 16,
      gap: gapWidth + 16,
      action: math.max(
        metrics.iconTarget,
        measure(l.delete, theme.textTheme.labelMedium) + 8,
      ),
    );
    final requiredWidth =
        columns.period +
        columns.time * 2 +
        columns.duration +
        columns.gap +
        columns.action +
        92;
    return width >= requiredWidth ? columns : null;
  }

  Widget row({
    required Widget periodCell,
    required Widget startCell,
    required Widget endCell,
    required Widget durationCell,
    required Widget gapCell,
    required Widget actionCell,
  }) => Row(
    children: [
      SizedBox(width: period, child: periodCell),
      const SizedBox(width: 12),
      SizedBox(width: time, child: startCell),
      const SizedBox(width: 8),
      SizedBox(width: time, child: endCell),
      const Spacer(),
      const SizedBox(width: 24),
      SizedBox(width: duration, child: durationCell),
      const SizedBox(width: 12),
      SizedBox(width: gap, child: gapCell),
      const SizedBox(width: 12),
      SizedBox(width: action, child: actionCell),
    ],
  );
}

class _PeriodTableHeader extends StatelessWidget {
  const _PeriodTableHeader({required this.columns});
  final _PeriodTableColumns columns;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    Widget label(String text, {bool centered = true}) => Text(
      text,
      textAlign: centered ? TextAlign.center : TextAlign.start,
      style: theme.textTheme.labelMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
    return Padding(
      key: const ValueKey('period-times-table-header'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: columns.row(
        periodCell: label(l.periodTimesPeriodColumn, centered: false),
        startCell: label(l.startTime),
        endCell: label(l.endTime),
        durationCell: label(l.periodTimesDurationColumn),
        gapCell: label(l.periodTimesGapColumn),
        actionCell: label(l.delete),
      ),
    );
  }
}

class _PeriodEditorRow extends StatelessWidget {
  const _PeriodEditorRow({
    super.key,
    required this.period,
    required this.previous,
    required this.columns,
    required this.timeEnabled,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onDelete,
  });
  final CoursePeriodTime period;
  final CoursePeriodTime? previous;
  final _PeriodTableColumns? columns;
  final bool timeEnabled;
  final ValueChanged<BuildContext> onPickStart;
  final ValueChanged<BuildContext> onPickEnd;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final metrics = WorkbenchChromeMetrics.of(context);
    final duration = period.endMinutes - period.startMinutes;
    final gap = previous == null
        ? null
        : period.startMinutes - previous!.endMinutes;
    final invalidEnd = duration <= 0;
    final overlap = gap != null && gap < 0;
    final error = invalidEnd
        ? l.endTimeMustBeLater
        : overlap
        ? l.periodOverlapPrevious
        : null;
    final label = l.periodNumberLabel(period.index);
    final ordinal = Text(label, style: theme.textTheme.bodyMedium);
    final remove = SizedBox.square(
      dimension: metrics.iconTarget,
      child: Semantics(
        label: label,
        child: IconButton(
          key: ValueKey('period-delete-${period.index}'),
          tooltip: l.deleteThisPeriod,
          style: metrics.iconStyle,
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline),
        ),
      ),
    );
    final start = _PeriodTimeAction(
      key: const ValueKey('period-start-time-action'),
      periodLabel: label,
      label: l.startTime,
      value: formatMinutes(period.startMinutes),
      enabled: timeEnabled,
      error: overlap,
      onTap: onPickStart,
    );
    final end = _PeriodTimeAction(
      key: const ValueKey('period-end-time-action'),
      periodLabel: label,
      label: l.endTime,
      value: formatMinutes(period.endMinutes),
      enabled: timeEnabled,
      error: invalidEnd,
      onTap: onPickEnd,
    );
    final columns = this.columns;
    Widget body;
    if (columns != null) {
      Widget metadata(String value) => Text(
        value,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          columns.row(
            periodCell: ordinal,
            startCell: start,
            endCell: end,
            durationCell: metadata(
              duration > 0 ? l.periodTimesMinutesShort(duration) : '—',
            ),
            gapCell: metadata(
              gap != null && gap >= 0 ? l.periodTimesMinutesShort(gap) : '—',
            ),
            actionCell: Center(child: remove),
          ),
          if (error != null)
            Padding(
              padding: EdgeInsetsDirectional.only(
                start: columns.period + 12,
                top: 4,
              ),
              child: _PeriodTimeError(period: period.index, message: error),
            ),
        ],
      );
    } else {
      final summary = error == null
          ? Text(
              [
                l.durationMinutes(duration),
                if (gap != null) l.gapFromPrevious(gap),
              ].join(' · '),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : _PeriodTimeError(period: period.index, message: error);
      body = LayoutBuilder(
        builder: (context, constraints) {
          final ordinalWidth = _periodTextSize(
            context,
            label,
            theme.textTheme.bodyMedium,
          ).width;
          final timeWidth = math.max(
            metrics.iconTarget,
            [start.value, end.value, '88:88']
                    .map(
                      (value) => _periodTextSize(
                        context,
                        value,
                        _periodTimeStyle(context),
                      ).width,
                    )
                    .reduce(math.max)
                    .ceilToDouble() +
                24,
          );
          final rangeWidth = timeWidth * 2 + 16;
          final singleLine =
              constraints.maxWidth >=
              ordinalWidth + rangeWidth + metrics.iconTarget + 24;
          final range = _PeriodTimePair(
            start: start,
            end: end,
            timeWidth: timeWidth,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (singleLine)
                Row(
                  children: [
                    ordinal,
                    const SizedBox(width: 12),
                    SizedBox(width: rangeWidth, child: range),
                    const Spacer(),
                    const SizedBox(width: 12),
                    remove,
                  ],
                )
              else ...[
                Row(
                  children: [
                    Expanded(child: ordinal),
                    remove,
                  ],
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: range,
                ),
              ],
              const SizedBox(height: 2),
              summary,
            ],
          );
        },
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: .65),
          ),
        ),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: metrics.desktop ? 52 : 76),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: columns == null ? 4 : 8,
          ),
          child: body,
        ),
      ),
    );
  }
}

class _PeriodTimeError extends StatelessWidget {
  const _PeriodTimeError({required this.period, required this.message});
  final int period;
  final String message;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Text(
      message,
      key: ValueKey('period-error-$period'),
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: Theme.of(context).colorScheme.error),
    ),
  );
}

class _PeriodTimePair extends StatelessWidget {
  const _PeriodTimePair({
    required this.start,
    required this.end,
    required this.timeWidth,
  });
  final _PeriodTimeAction start;
  final _PeriodTimeAction end;
  final double timeWidth;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth >= timeWidth * 2 + 16) {
        return Row(
          key: const ValueKey('period-time-range'),
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: timeWidth, child: start),
            const SizedBox(
              width: 16,
              child: ExcludeSemantics(
                child: Text('–', textAlign: TextAlign.center),
              ),
            ),
            SizedBox(width: timeWidth, child: end),
          ],
        );
      }
      Widget labelled(_PeriodTimeAction action) => Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          Text(action.label, style: Theme.of(context).textTheme.labelMedium),
          action,
        ],
      );
      return Column(
        key: const ValueKey('period-time-range'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [labelled(start), labelled(end)],
      );
    },
  );
}

class _PeriodTimeAction extends StatelessWidget {
  const _PeriodTimeAction({
    super.key,
    required this.periodLabel,
    required this.label,
    required this.value,
    required this.enabled,
    required this.error,
    required this.onTap,
  });
  final String periodLabel;
  final String label;
  final String value;
  final bool enabled;
  final bool error;
  final ValueChanged<BuildContext> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = WorkbenchChromeMetrics.of(context);
    return Semantics(
      button: true,
      enabled: enabled,
      excludeSemantics: true,
      label: '$periodLabel, $label',
      value: value,
      onTap: enabled ? () => onTap(context) : null,
      child: Tooltip(
        message: '$periodLabel, $label',
        excludeFromSemantics: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          excludeFromSemantics: true,
          onTap: enabled ? () => onTap(context) : null,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: metrics.iconTarget,
              minWidth: metrics.iconTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Center(
                widthFactor: 1,
                heightFactor: 1,
                child: Text(
                  value,
                  textDirection: TextDirection.ltr,
                  softWrap: false,
                  maxLines: 1,
                  style: _periodTimeStyle(context).copyWith(
                    color: !enabled
                        ? theme.colorScheme.onSurface.withValues(alpha: .38)
                        : error
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurface,
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

class _PeriodAddAction extends StatelessWidget {
  const _PeriodAddAction({required this.onPressed});
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    final metrics = WorkbenchChromeMetrics.of(context);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton.icon(
        key: const ValueKey('period-times-add'),
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: Size(metrics.iconTarget, metrics.desktop ? 44 : 52),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          tapTargetSize: metrics.desktop
              ? MaterialTapTargetSize.shrinkWrap
              : MaterialTapTargetSize.padded,
        ),
        icon: const Icon(Icons.add, size: 20),
        label: Text(AppLocalizations.of(context).addOnePeriod),
      ),
    );
  }
}

TextStyle _periodTimeStyle(BuildContext context) =>
    (Theme.of(context).textTheme.bodyLarge ?? const TextStyle(fontSize: 16))
        .copyWith(
          fontWeight: FontWeight.w500,
          fontFeatures: const [FontFeature.tabularFigures()],
        );

Size _periodTextSize(
  BuildContext context,
  String text,
  TextStyle? style, {
  double maxWidth = double.infinity,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: DefaultTextStyle.of(context).style.merge(style),
    ),
    textDirection: Directionality.of(context),
    locale: Localizations.maybeLocaleOf(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout(maxWidth: maxWidth);
  final size = painter.size;
  painter.dispose();
  return size;
}

class _PeriodScrollAnchor {
  const _PeriodScrollAnchor(this.key, this.leading);
  final GlobalKey key;
  final double leading;
}
