import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/timetable_models.dart';
import '../utils/general_schedule_colors.dart';
import 'ui_command.dart';

class GeneralEventDetailsSheet extends StatefulWidget {
  const GeneralEventDetailsSheet({
    super.key,
    required this.occurrence,
    this.onEdit,
    this.onDuplicate,
    this.isReminderHandled = false,
    this.onDismissReminder,
    this.onRestoreReminder,
    this.onDeleteThis,
    this.onDeleteFuture,
    this.onDeleteAll,
  });

  final GeneralEventOccurrence occurrence;
  final FutureOr<void> Function()? onEdit;
  final FutureOr<void> Function()? onDuplicate;
  final bool isReminderHandled;
  final FutureOr<void> Function()? onDismissReminder;
  final FutureOr<void> Function()? onRestoreReminder;
  final FutureOr<void> Function()? onDeleteThis;
  final FutureOr<void> Function()? onDeleteFuture;
  final FutureOr<void> Function()? onDeleteAll;

  @override
  State<GeneralEventDetailsSheet> createState() =>
      _GeneralEventDetailsSheetState();
}

class _GeneralEventDetailsSheetState extends State<GeneralEventDetailsSheet> {
  var _actionTriggered = false;

  Future<void> _runAction(FutureOr<void> Function()? action) async {
    if (_actionTriggered || action == null) {
      return;
    }
    setState(() => _actionTriggered = true);
    final succeeded = await runUiCommandWithFeedback(
      context: context,
      debugLabel: 'Run general event action',
      command: () async => action(),
    );
    if (!succeeded && mounted) {
      setState(() => _actionTriggered = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final event = widget.occurrence.event;
    final color = effectiveGeneralOccurrenceColor(context, widget.occurrence);
    final isRepeating = event.recurrenceRule.isRepeating;

    final content = SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            UiCommandBusyIndicator(busy: _actionTriggered),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.only(top: 7),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.occurrence.calendar.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _InfoRow(
              icon: Icons.access_time,
              value: _formatOccurrenceTime(widget.occurrence, l10n),
            ),
            if (isRepeating)
              _InfoRow(
                icon: Icons.repeat,
                value: _repeatSummary(event.recurrenceRule, l10n),
              ),
            if (event.reminders.isNotEmpty)
              _InfoRow(
                icon: Icons.notifications_outlined,
                value: event.reminders
                    .map((item) => _reminderLabel(item.minutesBefore, l10n))
                    .join(', '),
              ),
            if (event.location.isNotEmpty)
              _InfoRow(icon: Icons.location_on_outlined, value: event.location),
            if (event.notes.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                l10n.eventNotes,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(180),
                ),
              ),
              const SizedBox(height: 6),
              Text(event.notes),
            ],
            const SizedBox(height: 24),
            _EventActionSection(
              primaryActions: [
                if (widget.onEdit != null)
                  FilledButton.icon(
                    onPressed: _actionTriggered
                        ? null
                        : () {
                            unawaited(_runAction(widget.onEdit));
                          },
                    icon: const Icon(Icons.edit_outlined),
                    label: _ActionLabel(l10n.editEvent),
                    style: _filledActionStyle(theme),
                  ),
              ],
              secondaryActions: [
                if (widget.onDuplicate != null)
                  FilledButton.tonalIcon(
                    onPressed: _actionTriggered
                        ? null
                        : () {
                            unawaited(_runAction(widget.onDuplicate));
                          },
                    icon: const Icon(Icons.content_copy_outlined),
                    label: _ActionLabel(l10n.duplicateEvent),
                    style: _filledActionStyle(theme),
                  ),
                if (event.reminders.isNotEmpty &&
                    !widget.isReminderHandled &&
                    widget.onDismissReminder != null)
                  OutlinedButton.icon(
                    onPressed: _actionTriggered
                        ? null
                        : () {
                            unawaited(_runAction(widget.onDismissReminder));
                          },
                    icon: const Icon(Icons.check_circle_outline),
                    label: _ActionLabel(l10n.markReminderHandled),
                    style: _outlinedActionStyle(theme),
                  ),
                if (event.reminders.isNotEmpty &&
                    widget.isReminderHandled &&
                    widget.onRestoreReminder != null)
                  OutlinedButton.icon(
                    onPressed: _actionTriggered
                        ? null
                        : () {
                            unawaited(_runAction(widget.onRestoreReminder));
                          },
                    icon: const Icon(Icons.restore_outlined),
                    label: _ActionLabel(l10n.restoreReminder),
                    style: _outlinedActionStyle(theme),
                  ),
              ],
              destructiveActions: [
                if (widget.onDeleteThis != null)
                  OutlinedButton.icon(
                    onPressed: _actionTriggered
                        ? null
                        : () {
                            unawaited(_runAction(widget.onDeleteThis));
                          },
                    icon: const Icon(Icons.delete_outline),
                    label: _ActionLabel(
                      isRepeating ? l10n.deleteThisOccurrence : l10n.delete,
                    ),
                    style: _outlinedActionStyle(
                      theme,
                      foregroundColor: theme.colorScheme.error,
                    ),
                  ),
                if (isRepeating && widget.onDeleteFuture != null)
                  OutlinedButton.icon(
                    onPressed: _actionTriggered
                        ? null
                        : () {
                            unawaited(_runAction(widget.onDeleteFuture));
                          },
                    icon: const Icon(Icons.delete_sweep_outlined),
                    label: _ActionLabel(l10n.deleteFutureOccurrences),
                    style: _outlinedActionStyle(
                      theme,
                      foregroundColor: theme.colorScheme.error,
                    ),
                  ),
                if (isRepeating && widget.onDeleteAll != null)
                  OutlinedButton.icon(
                    onPressed: _actionTriggered
                        ? null
                        : () {
                            unawaited(_runAction(widget.onDeleteAll));
                          },
                    icon: const Icon(Icons.delete_forever_outlined),
                    label: _ActionLabel(l10n.deleteAllOccurrences),
                    style: _outlinedActionStyle(
                      theme,
                      foregroundColor: theme.colorScheme.error,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
    return PopScope<void>(canPop: !_actionTriggered, child: content);
  }
}

class _EventActionSection extends StatelessWidget {
  const _EventActionSection({
    required this.primaryActions,
    required this.secondaryActions,
    required this.destructiveActions,
  });

  static const _spacing = 12.0;
  static const _height = 52.0;
  static const _singleColumnBreakpoint = 340.0;

  final List<Widget> primaryActions;
  final List<Widget> secondaryActions;
  final List<Widget> destructiveActions;

  @override
  Widget build(BuildContext context) {
    if (primaryActions.isEmpty &&
        secondaryActions.isEmpty &&
        destructiveActions.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (primaryActions.isNotEmpty)
          _ActionWrap(actions: primaryActions, maxColumns: 1),
        if (secondaryActions.isNotEmpty) ...[
          if (primaryActions.isNotEmpty)
            const SizedBox(height: _EventActionSection._spacing),
          _ActionWrap(actions: secondaryActions, maxColumns: 2),
        ],
        if (destructiveActions.isNotEmpty) ...[
          if (primaryActions.isNotEmpty || secondaryActions.isNotEmpty)
            const SizedBox(height: _EventActionSection._spacing),
          _ActionWrap(actions: destructiveActions, maxColumns: 1),
        ],
      ],
    );
  }
}

class _ActionWrap extends StatelessWidget {
  const _ActionWrap({required this.actions, required this.maxColumns});

  final List<Widget> actions;
  final int maxColumns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            constraints.maxWidth <
                    _EventActionSection._singleColumnBreakpoint ||
                maxColumns <= 1 ||
                actions.length == 1
            ? 1
            : maxColumns;
        final itemWidth = columns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth -
                      _EventActionSection._spacing * (columns - 1)) /
                  columns;
        return Wrap(
          spacing: _EventActionSection._spacing,
          runSpacing: _EventActionSection._spacing,
          children: [
            for (final action in actions)
              SizedBox(
                width: itemWidth,
                height: _EventActionSection._height,
                child: action,
              ),
          ],
        );
      },
    );
  }
}

class _ActionLabel extends StatelessWidget {
  const _ActionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
    );
  }
}

ButtonStyle _filledActionStyle(ThemeData theme) {
  return FilledButton.styleFrom(
    minimumSize: const Size.fromHeight(_EventActionSection._height),
    padding: const EdgeInsets.symmetric(horizontal: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    textStyle: theme.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w700,
    ),
  );
}

ButtonStyle _outlinedActionStyle(ThemeData theme, {Color? foregroundColor}) {
  return OutlinedButton.styleFrom(
    foregroundColor: foregroundColor,
    minimumSize: const Size.fromHeight(_EventActionSection._height),
    padding: const EdgeInsets.symmetric(horizontal: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    textStyle: theme.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w700,
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 19,
            color: theme.colorScheme.onSurface.withAlpha(160),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

String _formatOccurrenceTime(
  GeneralEventOccurrence occurrence,
  AppLocalizations l10n,
) {
  if (occurrence.isAllDay) {
    final end = previousCalendarDate(occurrence.end);
    if (_sameDay(occurrence.start, end)) {
      return '${_fmtDate(occurrence.start)}  ${l10n.allDay}';
    }
    return '${_fmtDate(occurrence.start)} - ${_fmtDate(end)}  ${l10n.allDay}';
  }
  final displayStart = occurrence.calendarDisplayStart;
  final displayEnd = occurrence.calendarDisplayEnd;
  if (_sameDay(displayStart, displayEnd)) {
    return '${_fmtDate(displayStart)} ${_fmtTime(displayStart)} - ${_fmtTime(displayEnd)}';
  }
  return '${_fmtDate(displayStart)} ${_fmtTime(displayStart)} - ${_fmtDate(displayEnd)} ${_fmtTime(displayEnd)}';
}

String _repeatSummary(GeneralEventRecurrenceRule rule, AppLocalizations l10n) {
  final base = switch (rule.type) {
    GeneralEventRecurrence.daily => l10n.repeatsDaily,
    GeneralEventRecurrence.weekly => l10n.repeatsWeekly,
    GeneralEventRecurrence.monthly => l10n.repeatsMonthly,
    GeneralEventRecurrence.custom => l10n.repeatsEvery(
      rule.normalizedInterval,
      _unitLabel(rule.unit, l10n),
    ),
    GeneralEventRecurrence.none => l10n.recurrenceNone,
  };
  final suffix = [
    if (rule.untilDateIso != null) l10n.recurrenceUntil(rule.untilDateIso!),
    if (rule.count != null && rule.count! > 0)
      l10n.recurrenceCountTimes(rule.count!),
  ].join(', ');
  return suffix.isEmpty ? base : '$base, $suffix';
}

String _unitLabel(GeneralEventRecurrenceUnit unit, AppLocalizations l10n) {
  return switch (unit) {
    GeneralEventRecurrenceUnit.day => l10n.recurrenceDays,
    GeneralEventRecurrenceUnit.week => l10n.recurrenceWeeks,
    GeneralEventRecurrenceUnit.month => l10n.recurrenceMonths,
  };
}

String _reminderLabel(int minutes, AppLocalizations l10n) {
  return switch (minutes) {
    0 => l10n.reminderAtStart,
    60 => l10n.reminderHourBefore,
    1440 => l10n.reminderDayBefore,
    _ => l10n.reminderMinutesBefore(minutes),
  };
}

String _fmtDate(DateTime dt) {
  return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}

String _fmtTime(DateTime dt) {
  return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

bool _sameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
