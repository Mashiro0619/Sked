part of 'general_schedule_home_screen.dart';

class _CalendarManagerSheet extends StatefulWidget {
  const _CalendarManagerSheet({this.createOnOpen = false});
  final bool createOnOpen;

  @override
  State<_CalendarManagerSheet> createState() => _CalendarManagerSheetState();
}

class _CalendarManagerSheetState extends State<_CalendarManagerSheet>
    with WorkspaceRouteLifecycle<_CalendarManagerSheet> {
  var _actionInProgress = false;
  String? _initialSelection;
  @override
  void initState() {
    super.initState();
    if (widget.createOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(
            _addCalendar(
              context.read<TimetableProvider>(),
              AppLocalizations.of(context),
            ),
          );
        }
      });
    }
  }

  @override
  AppMode get routeWorkspace => AppMode.general;
  @override
  Future<bool> prepareWorkspaceDisable() async => !_actionInProgress;
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TimetableProvider>();
    final l10n = AppLocalizations.of(context);
    return PopScope(
      canPop: !_actionInProgress,
      child: AdaptiveCollectionScaffold(
        title: l10n.calendars,
        initialSelection: _initialSelection,
        busy: _actionInProgress,
        actions: [
          _CalendarManagerAddAction(
            disabled: _actionInProgress,
            onPressed: () => unawaited(_addCalendar(provider, l10n)),
          ),
          PopupMenuButton<SettingsTransferDirection>(
            tooltip: l10n.importExport,
            enabled: !_actionInProgress,
            icon: const Icon(Icons.import_export),
            onSelected: (direction) => openWorkspaceTransfer(
              context,
              AppMode.general,
              direction: direction,
            ),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: SettingsTransferDirection.import,
                child: Text(l10n.importAction),
              ),
              PopupMenuItem(
                value: SettingsTransferDirection.export,
                child: Text(l10n.exportAction),
              ),
            ],
          ),
        ],
        items: [
          for (final schedule in provider.generalSchedules)
            CollectionItem(
              id: schedule.id,
              title: schedule.name,
              tileBuilder: (selected, openDetail) => _CalendarManagerTile(
                selected: selected,
                schedule: schedule,
                eventCountLabel: l10n.generalScheduleEventCount(
                  schedule.events.length,
                ),
                disabled: _actionInProgress,
                onToggleVisibility: () => unawaited(
                  _runCalendarAction(
                    debugLabel: 'Update general calendar visibility',
                    action: () => provider.updateGeneralScheduleVisibility(
                      schedule.id,
                      !schedule.isVisible,
                    ),
                  ),
                ),
                onRename: openDetail,
                onDelete: () => unawaited(_deleteCalendar(schedule)),
              ),
            ),
        ],
        detailBuilder: (id) => _RenameCalendarDialog(
          provider: provider,
          schedule: provider.generalSchedules.firstWhere(
            (item) => item.id == id,
          ),
        ),
      ),
    );
  }

  Future<void> _addCalendar(
    TimetableProvider provider,
    AppLocalizations l10n,
  ) async {
    final before = provider.generalSchedules.map((s) => s.id).toSet();
    await _runCalendarAction(
      debugLabel: 'Add general calendar',
      action: () => provider.addGeneralSchedule(
        name: l10n.newCalendar,
        colorValue: _nextCalendarColor(provider.generalSchedules),
      ),
    );
    final created = provider.generalSchedules
        .where((s) => !before.contains(s.id))
        .firstOrNull;
    if (mounted && created != null) {
      setState(() => _initialSelection = created.id);
    }
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

class _RenameCalendarDialogState extends State<_RenameCalendarDialog>
    with EditorExitGuard<_RenameCalendarDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.schedule.name,
  );
  var _busy = false;
  var _popped = false;
  @override
  String get draftFingerprint => _controller.text;
  @override
  bool get exitBlocked => _busy || _popped;
  @override
  AppMode get editorWorkspace => AppMode.general;
  @override
  void initState() {
    super.initState();
    initializeDraftGuard();
  }

  @override
  void closeEditor() {
    if (_popped || !mounted) return;
    setState(() => _popped = true);
    Navigator.of(context).pop();
  }

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
      closeEditor();
    } else {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = _controller.text.trim();
    return PopScope<void>(
      canPop: _popped,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(requestEditorExit());
      },
      child: Scaffold(
        appBar: WorkbenchAppBar(title: Text(l10n.renameCalendar)),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  l10n.generalScheduleEventCount(widget.schedule.events.length),
                ),
                const SizedBox(height: 16),
                Column(
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
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _busy || _popped
                          ? null
                          : () => unawaited(requestEditorExit()),
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
              ],
            ),
          ),
        ),
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
      dimension: WorkbenchChromeMetrics.of(context).iconTarget,
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
    required this.selected,
    required this.eventCountLabel,
    required this.disabled,
    required this.onToggleVisibility,
    required this.onRename,
    required this.onDelete,
  });

  final GeneralSchedule schedule;
  final bool selected;
  final String eventCountLabel;
  final bool disabled;
  final VoidCallback onToggleVisibility;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      key: ValueKey('calendar-manager-tile-${schedule.id}'),
      container: true,
      explicitChildNodes: true,
      button: true,
      enabled: !disabled,
      selected: selected,
      label: '${schedule.name}, $eventCountLabel',
      hint: l10n.rename,
      onTap: disabled ? null : onRename,
      child: Material(
        color: selected
            ? Theme.of(context).colorScheme.secondaryContainer
            : Colors.transparent,
        child: InkWell(
          excludeFromSemantics: true,
          onTap: disabled ? null : onRename,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: WorkbenchChromeMetrics.of(context).desktop ? 40 : 64,
            ),
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
          dimension: WorkbenchChromeMetrics.of(context).iconTarget,
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
          dimension: WorkbenchChromeMetrics.of(context).iconTarget,
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
