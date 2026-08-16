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
    final content = SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CalendarManagerBusyIndicator(busy: _actionInProgress),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 8),
            child: Row(
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
                const SizedBox(width: 8),
                _CalendarManagerAddAction(
                  disabled: _actionInProgress,
                  onPressed: () {
                    unawaited(_addCalendar(provider, l10n));
                  },
                ),
              ],
            ),
          ),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: Material(
                color: colors.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: colors.outlineVariant),
                ),
                clipBehavior: Clip.antiAlias,
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: provider.generalSchedules.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    thickness: 1,
                    indent: 12,
                    endIndent: 12,
                    color: colors.outlineVariant,
                  ),
                  itemBuilder: (context, index) {
                    final schedule = provider.generalSchedules[index];
                    void toggleVisibility() {
                      unawaited(
                        _runCalendarAction(
                          debugLabel: 'Update general calendar visibility',
                          action: () =>
                              provider.updateGeneralScheduleVisibility(
                                schedule.id,
                                !schedule.isVisible,
                              ),
                        ),
                      );
                    }

                    return _CalendarManagerTile(
                      schedule: schedule,
                      eventCountLabel: l10n.generalScheduleEventCount(
                        schedule.events.length,
                      ),
                      disabled: _actionInProgress,
                      onToggleVisibility: toggleVisibility,
                      onRename: () {
                        unawaited(_renameCalendar(schedule));
                      },
                      onDelete: () {
                        unawaited(_deleteCalendar(schedule));
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
    return PopScope<void>(canPop: !_actionInProgress, child: content);
  }

  Future<void> _addCalendar(TimetableProvider provider, AppLocalizations l10n) {
    return _runCalendarAction(
      debugLabel: 'Add general calendar',
      action: () => provider.addGeneralSchedule(
        name: l10n.newCalendar,
        colorValue: _nextCalendarColor(provider.generalSchedules),
      ),
    );
  }

  Future<void> _runCalendarAction({
    required String debugLabel,
    required Future<void> Function() action,
  }) async {
    if (_actionInProgress) {
      return;
    }
    setState(() => _actionInProgress = true);
    try {
      await runUiCommandWithFeedback(
        context: context,
        debugLabel: debugLabel,
        command: action,
      );
    } finally {
      if (mounted) {
        setState(() => _actionInProgress = false);
      } else {
        _actionInProgress = false;
      }
    }
  }

  Future<void> _renameCalendar(GeneralSchedule schedule) async {
    await _runCalendarAction(
      debugLabel: 'Rename general calendar',
      action: () async {
        final provider = context.read<TimetableProvider>();
        await showExpressiveDialog<void>(
          context: context,
          builder: (_) =>
              _RenameCalendarDialog(provider: provider, schedule: schedule),
        );
      },
    );
  }

  Future<void> _deleteCalendar(GeneralSchedule schedule) async {
    await _runCalendarAction(
      debugLabel: 'Delete general calendar',
      action: () async {
        final provider = context.read<TimetableProvider>();
        await showExpressiveDialog<void>(
          context: context,
          builder: (_) =>
              _DeleteCalendarDialog(provider: provider, schedule: schedule),
        );
      },
    );
  }
}

class _RenameCalendarDialog extends StatefulWidget {
  const _RenameCalendarDialog({required this.provider, required this.schedule});

  final TimetableProvider provider;
  final GeneralSchedule schedule;

  @override
  State<_RenameCalendarDialog> createState() => _RenameCalendarDialogState();
}

class _RenameCalendarDialogState extends State<_RenameCalendarDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.schedule.name,
  );
  var _busy = false;
  var _popped = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _controller.text.trim();
    if (_busy || _popped || name.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    final saved = await runUiCommandWithFeedback(
      context: context,
      debugLabel: 'Rename general calendar',
      command: () =>
          widget.provider.renameGeneralSchedule(widget.schedule.id, name),
    );
    if (!mounted) return;
    if (saved) {
      _popped = true;
      Navigator.of(context).pop();
    } else {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = _controller.text.trim();
    return PopScope<void>(
      canPop: !_busy && !_popped,
      child: AlertDialog(
        title: Text(l10n.renameCalendar),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            UiCommandBusyIndicator(busy: _busy),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('rename-calendar-field'),
              controller: _controller,
              enabled: !_busy,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.name,
                prefixIcon: const Icon(Icons.edit_outlined),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => unawaited(_save()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _busy || _popped
                ? null
                : () {
                    _popped = true;
                    Navigator.of(context).pop();
                  },
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: _busy || _popped || name.isEmpty
                ? null
                : () => unawaited(_save()),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }
}

class _DeleteCalendarDialog extends StatefulWidget {
  const _DeleteCalendarDialog({required this.provider, required this.schedule});

  final TimetableProvider provider;
  final GeneralSchedule schedule;

  @override
  State<_DeleteCalendarDialog> createState() => _DeleteCalendarDialogState();
}

class _DeleteCalendarDialogState extends State<_DeleteCalendarDialog> {
  var _busy = false;
  var _popped = false;

  Future<void> _delete() async {
    if (_busy || _popped) return;
    setState(() => _busy = true);
    final deleted = await runUiCommandWithFeedback(
      context: context,
      debugLabel: 'Delete general calendar',
      command: () => widget.provider.deleteGeneralSchedule(widget.schedule.id),
    );
    if (!mounted) return;
    if (deleted) {
      _popped = true;
      Navigator.of(context).pop();
    } else {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopScope<void>(
      canPop: !_busy && !_popped,
      child: AlertDialog(
        title: Text(l10n.deleteCalendar),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            UiCommandBusyIndicator(busy: _busy),
            const SizedBox(height: 8),
            Text(l10n.deleteCalendarMessage(widget.schedule.name)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _busy || _popped
                ? null
                : () {
                    _popped = true;
                    Navigator.of(context).pop();
                  },
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: _busy || _popped ? null : () => unawaited(_delete()),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }
}

class _CalendarManagerBusyIndicator extends StatelessWidget {
  const _CalendarManagerBusyIndicator({required this.busy});

  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 4,
      child: busy
          ? Semantics(
              liveRegion: true,
              label: AppLocalizations.of(context).savingChanges,
              child: const ExcludeSemantics(child: LinearProgressIndicator()),
            )
          : const SizedBox.shrink(),
    );
  }
}

class _CalendarManagerAddAction extends StatelessWidget {
  const _CalendarManagerAddAction({
    required this.disabled,
    required this.onPressed,
  });

  final bool disabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final callback = disabled ? null : onPressed;
    return SizedBox.square(
      dimension: 48,
      child: IconButton(
        tooltip: l10n.addCalendar,
        icon: const Icon(Icons.add),
        onPressed: callback,
      ),
    );
  }
}

class _CalendarManagerTile extends StatelessWidget {
  const _CalendarManagerTile({
    required this.schedule,
    required this.eventCountLabel,
    required this.disabled,
    required this.onToggleVisibility,
    required this.onRename,
    required this.onDelete,
  });

  final GeneralSchedule schedule;
  final String eventCountLabel;
  final bool disabled;
  final VoidCallback onToggleVisibility;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final toggleLabel = schedule.isVisible
        ? l10n.hideCalendar
        : l10n.showCalendar;

    return Semantics(
      key: ValueKey('calendar-manager-tile-${schedule.id}'),
      container: true,
      explicitChildNodes: true,
      button: true,
      enabled: !disabled,
      toggled: schedule.isVisible,
      label: '${schedule.name}, $eventCountLabel',
      hint: toggleLabel,
      onTap: disabled ? null : onToggleVisibility,
      child: InkWell(
        excludeFromSemantics: true,
        onTap: disabled ? null : onToggleVisibility,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 4, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ExcludeSemantics(
                  child: _ColorDot(
                    color: effectiveGeneralCalendarColor(context, schedule),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ExcludeSemantics(
                    child: _CalendarManagerTileTitle(
                      schedule: schedule,
                      eventCountLabel: eventCountLabel,
                    ),
                  ),
                ),
                _CalendarManagerTileActions(
                  scheduleId: schedule.id,
                  visible: schedule.isVisible,
                  disabled: disabled,
                  showTooltip: l10n.showCalendar,
                  hideTooltip: l10n.hideCalendar,
                  moreTooltip: l10n.more,
                  renameLabel: l10n.rename,
                  deleteLabel: l10n.delete,
                  onToggleVisibility: onToggleVisibility,
                  onRename: onRename,
                  onDelete: onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarManagerTileTitle extends StatelessWidget {
  const _CalendarManagerTileTitle({
    required this.schedule,
    required this.eventCountLabel,
  });

  final GeneralSchedule schedule;
  final String eventCountLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          schedule.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            color: colors.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          eventCountLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _CalendarManagerTileActions extends StatelessWidget {
  const _CalendarManagerTileActions({
    required this.scheduleId,
    required this.visible,
    required this.disabled,
    required this.showTooltip,
    required this.hideTooltip,
    required this.moreTooltip,
    required this.renameLabel,
    required this.deleteLabel,
    required this.onToggleVisibility,
    required this.onRename,
    required this.onDelete,
  });

  final String scheduleId;
  final bool visible;
  final bool disabled;
  final String showTooltip;
  final String hideTooltip;
  final String moreTooltip;
  final String renameLabel;
  final String deleteLabel;
  final VoidCallback onToggleVisibility;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: 48,
          child: IconButton(
            key: ValueKey('calendar-visibility-$scheduleId'),
            tooltip: visible ? hideTooltip : showTooltip,
            icon: Icon(
              visible
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
            onPressed: disabled ? null : onToggleVisibility,
          ),
        ),
        SizedBox.square(
          dimension: 48,
          child: SkedPopupMenuButton<_CalendarManagerMenuAction>(
            key: ValueKey('calendar-actions-$scheduleId'),
            enabled: !disabled,
            tooltip: moreTooltip,
            icon: const Icon(Icons.more_vert),
            onSelected: (action) {
              switch (action) {
                case _CalendarManagerMenuAction.rename:
                  onRename();
                case _CalendarManagerMenuAction.delete:
                  onDelete();
              }
            },
            itemBuilder: (context) => [
              SkedPopupMenuItem<_CalendarManagerMenuAction>(
                value: _CalendarManagerMenuAction.rename,
                child: Row(
                  children: [
                    const Icon(Icons.edit_outlined),
                    const SizedBox(width: 12),
                    Expanded(child: Text(renameLabel)),
                  ],
                ),
              ),
              SkedPopupMenuDivider<_CalendarManagerMenuAction>(),
              SkedPopupMenuItem<_CalendarManagerMenuAction>(
                value: _CalendarManagerMenuAction.delete,
                child: IconTheme.merge(
                  data: IconThemeData(color: colors.error),
                  child: DefaultTextStyle.merge(
                    style: TextStyle(color: colors.error),
                    child: Row(
                      children: [
                        const Icon(Icons.delete_outline),
                        const SizedBox(width: 12),
                        Expanded(child: Text(deleteLabel)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _CalendarManagerMenuAction { rename, delete }
