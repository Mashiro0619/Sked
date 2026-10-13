import 'sked_detail_row.dart';
import 'sked_task_actions.dart';
import 'sked_task_body.dart';
import 'sked_task_header.dart';
import 'sked_confirmation_dialog.dart';
import '../theme/sked_surface.dart';

import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../models/timetable_models.dart';
import '../utils/general_schedule_colors.dart';
import 'expressive_dialog.dart';
import 'general_event_edit_flow.dart';
import 'ui_command.dart';
import 'workbench_chrome_metrics.dart';
import 'workspace_view_panel.dart';

class GeneralEventDetailsSheet extends StatefulWidget {
  const GeneralEventDetailsSheet({
    super.key,
    required this.occurrence,
    this.onEdit,
    this.onEditScoped,
    this.onEditAnchor,
    this.onDuplicate,
    this.isReminderHandled = false,
    this.onDismissReminder,
    this.onRestoreReminder,
    this.onDeleteThis,
    this.onDeleteFuture,
    this.onDeleteAll,
    this.onBeforeAction,
    this.canEdit,
    this.onBusyChanged,
    this.onChildRouteChanged,
    this.headerAction,
    this.notificationSettings = const NotificationSettings(),
    this.onShowCalendar,
  });

  final GeneralEventOccurrence occurrence;
  final NotificationSettings notificationSettings;
  final FutureOr<void> Function()? onShowCalendar;

  /// Optional host promotion/validity guard, before any busy state or write.
  final bool Function()? onBeforeAction;
  final bool Function()? canEdit;
  final ValueChanged<bool>? onBusyChanged;
  final ValueChanged<ModalRoute<dynamic>?>? onChildRouteChanged;
  final Widget? headerAction;
  final ValueChanged<BuildContext>? onEditAnchor;
  final FutureOr<void> Function()? onEdit;
  final FutureOr<void> Function(GeneralEventEditScope)? onEditScoped;
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
  var _editScopeOpen = false;
  bool get _blocked => _actionTriggered || _editScopeOpen;

  void _setEditScopeOpen(bool value) {
    setState(() => _editScopeOpen = value);
    widget.onBusyChanged?.call(_blocked);
  }

  void _setBusy(bool value) {
    setState(() => _actionTriggered = value);
    widget.onBusyChanged?.call(_blocked);
  }

  Future<void> _edit(BuildContext anchor) async {
    // The background may already own another editor. Refuse before promotion,
    // busy state or dismissal, including callbacks invoked before a rebuild.
    if (_blocked || widget.canEdit?.call() == false) return;
    widget.onEditAnchor?.call(anchor);
    final scoped = widget.onEditScoped;
    if (scoped == null) {
      await _runAction(widget.onEdit);
      return;
    }
    _setEditScopeOpen(true);
    GeneralEventEditScope? scope;
    try {
      scope = await showGeneralEventEditScopeDialog(
        context,
        widget.occurrence,
        onChildRouteChanged: widget.onChildRouteChanged,
      );
    } finally {
      if (mounted) _setEditScopeOpen(false);
    }
    if (!mounted || scope == null || widget.canEdit?.call() == false) return;
    await _runAction(() => scoped(scope!));
  }

  Future<void> _runAction(FutureOr<void> Function()? action) async {
    if (_blocked || action == null) {
      return;
    }
    if (widget.onBeforeAction?.call() == false) return;
    _setBusy(true);
    await runUiCommandWithFeedback(
      context: context,
      debugLabel: 'Run general event action',
      command: () async => action(),
    );
    if (mounted) {
      _setBusy(false);
    }
  }

  Future<void> _confirmDelete() async {
    if (_blocked) {
      return;
    }
    if (widget.onBeforeAction?.call() == false) return;
    _setBusy(true);
    final choice = await _showDeleteDialog();
    if (mounted) widget.onChildRouteChanged?.call(null);
    if (!mounted) {
      return;
    }
    final action = switch (choice) {
      _DeleteEventAction.thisOccurrence => widget.onDeleteThis,
      _DeleteEventAction.thisAndFollowing => widget.onDeleteFuture,
      _DeleteEventAction.entireSeries => widget.onDeleteAll,
      null => null,
    };
    if (action == null) {
      _setBusy(false);
      return;
    }
    final succeeded = await runUiCommandWithFeedback(
      context: context,
      debugLabel: 'Delete general event',
      command: () async => action(),
    );
    if (!succeeded && mounted) {
      _setBusy(false);
    }
  }

  Future<_DeleteEventAction?> _showDeleteDialog() {
    final event = widget.occurrence.event;
    final isRepeating = event.recurrenceRule.isRepeating;
    return showExpressiveDialog<_DeleteEventAction>(
      context: context,
      waitForTransitionComplete: true,
      builder: (dialogContext) {
        widget.onChildRouteChanged?.call(ModalRoute.of(dialogContext));
        final l10n = AppLocalizations.of(dialogContext);
        var popped = false;
        void popWith([_DeleteEventAction? action]) {
          if (popped) return;
          popped = true;
          Navigator.of(dialogContext).pop(action);
        }

        if (!isRepeating) {
          return SkedConfirmationDialog(
            key: const ValueKey('general-event-delete-dialog'),
            title: Text(l10n.deleteEventTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.deleteEventConfirmation),
                const SizedBox(height: 8),
                Text(
                  event.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(dialogContext).textTheme.titleSmall,
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: popWith, child: Text(l10n.cancel)),
              FilledButton(
                key: const ValueKey('general-event-confirm-delete'),
                onPressed: () => popWith(_DeleteEventAction.thisOccurrence),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(dialogContext).colorScheme.error,
                  foregroundColor: Theme.of(dialogContext).colorScheme.onError,
                ),
                child: Text(l10n.delete),
              ),
            ],
          );
        }
        return SkedConfirmationDialog(
          key: const ValueKey('general-event-delete-scope-dialog'),
          title: Text(l10n.deleteRecurringEventTitle),
          contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          content: ExpressiveDialogContent(
            maxWidth: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: Text(
                    event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(dialogContext).textTheme.bodyMedium,
                  ),
                ),
                if (widget.onDeleteThis != null)
                  ExpressiveDialogOption(
                    key: const ValueKey('general-event-delete-this'),
                    leading: const Icon(Icons.delete_outline),
                    title: Text(l10n.deleteThisOccurrence),
                    onTap: () => popWith(_DeleteEventAction.thisOccurrence),
                  ),
                if (widget.occurrence.sequence > 0 &&
                    widget.onDeleteFuture != null)
                  ExpressiveDialogOption(
                    key: const ValueKey(
                      'general-event-delete-this-and-following',
                    ),
                    leading: const Icon(Icons.delete_sweep_outlined),
                    title: Text(l10n.deleteFutureOccurrences),
                    onTap: () => popWith(_DeleteEventAction.thisAndFollowing),
                  ),
                if (widget.onDeleteAll != null)
                  ExpressiveDialogOption(
                    key: const ValueKey('general-event-delete-entire-series'),
                    leading: const Icon(Icons.delete_forever_outlined),
                    title: Text(l10n.deleteAllOccurrences),
                    onTap: () => popWith(_DeleteEventAction.entireSeries),
                  ),
              ],
            ),
          ),
          actions: [TextButton(onPressed: popWith, child: Text(l10n.cancel))],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final event = widget.occurrence.event;
    final color = effectiveGeneralOccurrenceColor(context, widget.occurrence);
    final reminders = event.resolveReminders(
      widget.notificationSettings.generalDefaultMinutesBefore,
    );
    final isRepeating = event.recurrenceRule.isRepeating;
    final canDelete = isRepeating
        ? widget.onDeleteThis != null ||
              widget.onDeleteAll != null ||
              (widget.occurrence.sequence > 0 && widget.onDeleteFuture != null)
        : widget.onDeleteThis != null;

    final secondaryActions = <Widget>[
      if (widget.onDuplicate != null)
        _EventIconButton(
          key: const ValueKey('general-event-duplicate-action'),
          tooltip: l10n.duplicateEvent,
          onPressed: _blocked
              ? null
              : () => unawaited(_runAction(widget.onDuplicate)),
          icon: Icons.content_copy_outlined,
        ),
      if (reminders.isNotEmpty &&
          !widget.isReminderHandled &&
          widget.onDismissReminder != null)
        _EventIconButton(
          key: const ValueKey('general-event-reminder-action'),
          tooltip: l10n.markReminderHandled,
          onPressed: _blocked
              ? null
              : () => unawaited(_runAction(widget.onDismissReminder)),
          icon: Icons.check_circle_outline,
        ),
      if (reminders.isNotEmpty &&
          widget.isReminderHandled &&
          widget.onRestoreReminder != null)
        _EventIconButton(
          key: const ValueKey('general-event-reminder-action'),
          tooltip: l10n.restoreReminder,
          onPressed: _blocked
              ? null
              : () => unawaited(_runAction(widget.onRestoreReminder)),
          icon: Icons.restore_outlined,
        ),
      if (canDelete)
        _EventIconButton(
          key: const ValueKey('general-event-delete-action'),
          tooltip: l10n.delete,
          color: theme.colorScheme.error,
          onPressed: _blocked ? null : () => unawaited(_confirmDelete()),
          icon: Icons.delete_outline,
        ),
    ];

    final info = <Widget>[
      if (!widget.occurrence.calendar.isVisible) ...[
        _InfoRow(
          icon: Icons.visibility_off_outlined,
          value: l10n.categoryHidden,
        ),
        if (widget.onShowCalendar != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: const ValueKey('general-event-show-calendar'),
              onPressed: _blocked
                  ? null
                  : () => unawaited(_runAction(widget.onShowCalendar)),
              icon: const Icon(Icons.visibility_outlined),
              label: Text(l10n.showCalendar),
            ),
          ),
      ],
      _InfoRow(
        icon: Icons.access_time,
        value: _formatOccurrenceTime(widget.occurrence, l10n),
      ),
      if (isRepeating)
        _InfoRow(
          icon: Icons.repeat,
          value: _repeatSummary(event.recurrenceRule, l10n),
        ),
      if (reminders.isNotEmpty ||
          event.reminderBehavior == GeneralEventReminderBehavior.inherit)
        _InfoRow(
          icon: Icons.notifications_outlined,
          value: event.reminderBehavior == GeneralEventReminderBehavior.inherit
              ? l10n.courseReminderInherit(
                  reminders.isEmpty
                      ? l10n.none
                      : reminders
                            .map(
                              (item) =>
                                  _reminderLabel(item.minutesBefore, l10n),
                            )
                            .join(', '),
                )
              : reminders
                    .map((item) => _reminderLabel(item.minutesBefore, l10n))
                    .join(', '),
        ),
      if (event.location.isNotEmpty)
        _InfoRow(icon: Icons.location_on_outlined, value: event.location),
      if (event.notes.isNotEmpty) ...[
        const SizedBox(height: 10),
        Text(
          l10n.eventNotes,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurface.withAlpha(180),
          ),
        ),
        const SizedBox(height: 4),
        Text(event.notes),
      ],
    ];
    if (WorkspaceViewTaskScope.maybeOf(context)?.enabled == true) {
      return PopScope<void>(
        canPop: !_blocked,
        child: WorkspaceViewPanel(
          status: _actionTriggered
              ? const UiCommandBusyIndicator(busy: true)
              : null,
          prominentTitle: true,
          headerAction: widget.headerAction,
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 10,
                height: 10,
                margin: EdgeInsets.only(
                  top:
                      (18 *
                              1.35 *
                              MediaQuery.textScalerOf(context).scale(18) /
                              18 -
                          10) /
                      2,
                ),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  event.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          subtitle: Text(
            widget.occurrence.calendar.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: skedReadableAccent(
                theme.colorScheme,
                surface: SkedSurface.colorOf(context),
              ),
            ),
          ),
          toolbar: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                key: const ValueKey('general-event-action-bar'),
                spacing: 4,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (widget.onEdit != null || widget.onEditScoped != null)
                    Builder(
                      builder: (anchor) => FilledButton.tonalIcon(
                        key: const ValueKey('general-event-edit-action'),
                        onPressed: _blocked || widget.canEdit?.call() == false
                            ? null
                            : () => _edit(anchor),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: Text(l10n.editEvent),
                      ),
                    ),
                  ...secondaryActions,
                ],
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: info,
          ),
        ),
      );
    }

    final content = SafeArea(
      top: false,
      child: SkedTaskBody(
        status: _actionTriggered
            ? const UiCommandBusyIndicator(busy: true)
            : null,
        header: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 14,
              height: 14,
              margin: const EdgeInsets.only(top: 7),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SkedTaskHeader(
                title: Text(
                  event.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(widget.occurrence.calendar.name),
              ),
            ),
            if (widget.onEdit != null || widget.onEditScoped != null)
              Builder(
                builder: (anchor) => _EventIconButton(
                  key: const ValueKey('general-event-edit-action'),
                  tooltip: l10n.editEvent,
                  onPressed: _blocked || widget.canEdit?.call() == false
                      ? null
                      : () => _edit(anchor),
                  icon: Icons.edit_outlined,
                ),
              ),
          ],
        ),
        footer: secondaryActions.isEmpty
            ? null
            : _EventActionBar(children: secondaryActions),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [...info],
        ),
      ),
    );
    return PopScope<void>(canPop: !_blocked, child: content);
  }
}

enum _DeleteEventAction { thisOccurrence, thisAndFollowing, entireSeries }

class _EventIconButton extends StatelessWidget {
  const _EventIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.color,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: WorkbenchChromeMetrics.of(context).iconTarget,
      child: IconButton(
        tooltip: tooltip,
        style: WorkbenchChromeMetrics.of(context).desktop
            ? WorkbenchChromeMetrics.of(context).iconStyle
            : null,
        onPressed: onPressed,
        color: color,
        icon: Icon(icon),
      ),
    );
  }
}

class _EventActionBar extends StatelessWidget {
  const _EventActionBar({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Material(
        key: const ValueKey('general-event-action-bar'),
        color: SkedSurface.colorOf(context),
        borderRadius: BorderRadius.circular(
          WorkbenchChromeMetrics.of(context).desktop ? 6 : 16,
        ),
        clipBehavior: Clip.antiAlias,
        child: SkedActionArea(actions: children, spacing: 4, runSpacing: 4),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) => SkedDetailRow(icon: icon, value: value);
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
