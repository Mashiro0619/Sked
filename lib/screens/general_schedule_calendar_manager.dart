part of 'general_schedule_home_screen.dart';

class _CalendarManagerSheet extends StatefulWidget {
  const _CalendarManagerSheet();

  @override
  State<_CalendarManagerSheet> createState() => _CalendarManagerSheetState();
}

class _CalendarManagerSheetState extends State<_CalendarManagerSheet> {
  var _actionInProgress = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TimetableProvider>();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compactHeader = constraints.maxWidth < 420;
                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.calendars,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _CalendarManagerAddAction(
                      compact: compactHeader,
                      disabled: _actionInProgress,
                      onPressed: () => _addCalendar(provider, l10n),
                    ),
                  ],
                );
              },
            ),
          ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              itemCount: provider.generalSchedules.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final schedule = provider.generalSchedules[index];
                final active = schedule.id == provider.activeGeneralSchedule.id;
                return _CalendarManagerTile(
                  schedule: schedule,
                  active: active,
                  eventCountLabel: l10n.generalScheduleEventCount(
                    schedule.events.length,
                  ),
                  disabled: _actionInProgress,
                  onSelect: () => _runCalendarAction(
                    () => provider.switchGeneralSchedule(schedule.id),
                  ),
                  onToggleVisibility: () => _runCalendarAction(
                    () => provider.updateGeneralScheduleVisibility(
                      schedule.id,
                      !schedule.isVisible,
                    ),
                  ),
                  onRename: () => _renameCalendar(context, schedule),
                  onDelete: () => _deleteCalendar(context, schedule),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addCalendar(TimetableProvider provider, AppLocalizations l10n) {
    return _runCalendarAction(
      () => provider.addGeneralSchedule(
        name: l10n.newCalendar,
        colorValue: _nextCalendarColor(provider.generalSchedules),
      ),
    );
  }

  Future<void> _runCalendarAction(Future<void> Function() action) async {
    if (_actionInProgress) {
      return;
    }
    setState(() => _actionInProgress = true);
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() => _actionInProgress = false);
      } else {
        _actionInProgress = false;
      }
    }
  }

  Future<void> _renameCalendar(
    BuildContext context,
    GeneralSchedule schedule,
  ) async {
    await _runCalendarAction(() async {
      final provider = context.read<TimetableProvider>();
      final controller = TextEditingController(text: schedule.name);
      final name = await showExpressiveDialog<String>(
        context: context,
        builder: (dialogContext) {
          final l10n = AppLocalizations.of(dialogContext);
          var popped = false;
          void popWith(String? value) {
            if (popped) return;
            popped = true;
            Navigator.of(dialogContext).pop(value);
          }

          return AlertDialog(
            title: Text(l10n.renameCalendar),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.name,
                prefixIcon: const Icon(Icons.edit_outlined),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => popWith(null),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => popWith(controller.text.trim()),
                child: Text(l10n.save),
              ),
            ],
          );
        },
      );
      controller.dispose();
      if (name != null && name.trim().isNotEmpty) {
        await provider.renameGeneralSchedule(schedule.id, name);
      }
    });
  }

  Future<void> _deleteCalendar(
    BuildContext context,
    GeneralSchedule schedule,
  ) async {
    await _runCalendarAction(() async {
      final provider = context.read<TimetableProvider>();
      final l10n = AppLocalizations.of(context);
      final confirmed = await showExpressiveDialog<bool>(
        context: context,
        builder: (dialogContext) {
          var popped = false;
          void popWith(bool value) {
            if (popped) return;
            popped = true;
            Navigator.of(dialogContext).pop(value);
          }

          return AlertDialog(
            title: Text(l10n.deleteCalendar),
            content: Text(l10n.deleteCalendarMessage(schedule.name)),
            actions: [
              TextButton(
                onPressed: () => popWith(false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => popWith(true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(dialogContext).colorScheme.error,
                ),
                child: Text(l10n.delete),
              ),
            ],
          );
        },
      );
      if (confirmed == true) {
        await provider.deleteGeneralSchedule(schedule.id);
      }
    });
  }
}

class _CalendarManagerAddAction extends StatelessWidget {
  const _CalendarManagerAddAction({
    required this.compact,
    required this.disabled,
    required this.onPressed,
  });

  final bool compact;
  final bool disabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final callback = disabled ? null : onPressed;
    if (compact) {
      return IconButton(
        tooltip: l10n.addCalendar,
        icon: const Icon(Icons.add),
        onPressed: callback,
      );
    }

    return Tooltip(
      message: l10n.addCalendar,
      child: FilledButton.tonalIcon(
        onPressed: callback,
        icon: const Icon(Icons.add),
        label: Text(l10n.addCalendar),
      ),
    );
  }
}

class _CalendarManagerTile extends StatelessWidget {
  const _CalendarManagerTile({
    required this.schedule,
    required this.active,
    required this.eventCountLabel,
    required this.disabled,
    required this.onSelect,
    required this.onToggleVisibility,
    required this.onRename,
    required this.onDelete,
  });

  final GeneralSchedule schedule;
  final bool active;
  final String eventCountLabel;
  final bool disabled;
  final VoidCallback onSelect;
  final VoidCallback onToggleVisibility;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final borderColor = active
        ? colors.primary.withValues(alpha: 0.44)
        : colors.outlineVariant.withValues(alpha: 0.7);

    return Material(
      color: active
          ? colors.primary.withValues(alpha: 0.10)
          : colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: disabled ? null : onSelect,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 360;
              final titleBlock = _CalendarManagerTileTitle(
                schedule: schedule,
                active: active,
                eventCountLabel: eventCountLabel,
              );
              final actions = _CalendarManagerTileActions(
                visible: schedule.isVisible,
                disabled: disabled,
                showTooltip: l10n.showCalendar,
                hideTooltip: l10n.hideCalendar,
                renameTooltip: l10n.rename,
                deleteTooltip: l10n.delete,
                onToggleVisibility: onToggleVisibility,
                onRename: onRename,
                onDelete: onDelete,
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _ColorDot(color: Color(schedule.colorValue)),
                        const SizedBox(width: 12),
                        Expanded(child: titleBlock),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: actions,
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _ColorDot(color: Color(schedule.colorValue)),
                  const SizedBox(width: 12),
                  Expanded(child: titleBlock),
                  const SizedBox(width: 8),
                  actions,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CalendarManagerTileTitle extends StatelessWidget {
  const _CalendarManagerTileTitle({
    required this.schedule,
    required this.active,
    required this.eventCountLabel,
  });

  final GeneralSchedule schedule;
  final bool active;
  final String eventCountLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                schedule.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: active ? colors.primary : colors.onSurface,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
            if (active) ...[
              const SizedBox(width: 6),
              Icon(Icons.check_circle, size: 18, color: colors.primary),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          eventCountLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: active ? colors.primary : colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _CalendarManagerTileActions extends StatelessWidget {
  const _CalendarManagerTileActions({
    required this.visible,
    required this.disabled,
    required this.showTooltip,
    required this.hideTooltip,
    required this.renameTooltip,
    required this.deleteTooltip,
    required this.onToggleVisibility,
    required this.onRename,
    required this.onDelete,
  });

  final bool visible;
  final bool disabled;
  final String showTooltip;
  final String hideTooltip;
  final String renameTooltip;
  final String deleteTooltip;
  final VoidCallback onToggleVisibility;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 2,
      runSpacing: 2,
      alignment: WrapAlignment.end,
      children: [
        IconButton(
          tooltip: visible ? hideTooltip : showTooltip,
          icon: Icon(
            visible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
          onPressed: disabled ? null : onToggleVisibility,
        ),
        IconButton(
          tooltip: renameTooltip,
          icon: const Icon(Icons.edit_outlined),
          onPressed: disabled ? null : onRename,
        ),
        IconButton(
          tooltip: deleteTooltip,
          icon: const Icon(Icons.delete_outline),
          onPressed: disabled ? null : onDelete,
        ),
      ],
    );
  }
}
