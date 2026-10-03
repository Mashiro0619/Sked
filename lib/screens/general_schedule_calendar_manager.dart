part of 'general_schedule_home_screen.dart';

class _CalendarManagerPage extends StatefulWidget {
  const _CalendarManagerPage({
    this.createOnOpen = false,
    this.desktopPanel = false,
  });
  final bool desktopPanel;
  final bool createOnOpen;

  @override
  State<_CalendarManagerPage> createState() => _CalendarManagerPageState();
}

class _CalendarManagerPageState extends State<_CalendarManagerPage>
    with WorkspaceRouteLifecycle<_CalendarManagerPage> {
  final _addAnchor = GlobalKey();
  var _actionInProgress = false;
  var _childTaskOpen = false;
  bool get _actionsDisabled => _actionInProgress || _childTaskOpen;

  @override
  void initState() {
    super.initState();
    if (widget.createOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(
            _editCalendarName(anchorContext: _addAnchor.currentContext),
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
    if (widget.desktopPanel) return _buildDesktop(context, provider);
    return PopScope(
      canPop: !_actionsDisabled,
      child: Scaffold(
        appBar: WorkbenchAppBar(
          title: Text(l10n.calendars),
          actions: [
            _CalendarManagerAddAction(
              key: _addAnchor,
              disabled: _actionsDisabled,
              onPressed: () => unawaited(
                _editCalendarName(anchorContext: _addAnchor.currentContext),
              ),
            ),
            PopupMenuButton<SettingsTransferDirection>(
              tooltip: l10n.importExport,
              enabled: !_actionsDisabled,
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
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: UiCommandBusyIndicator(busy: _actionInProgress),
          ),
        ),
        body: SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: ListView.builder(
                key: const PageStorageKey('calendar-manager-list'),
                padding: const EdgeInsets.all(12),
                itemCount: provider.generalSchedules.length,
                itemBuilder: (context, index) {
                  final schedule = provider.generalSchedules[index];
                  return _CalendarManagerTile(
                    schedule: schedule,
                    eventCountLabel: l10n.generalScheduleEventCount(
                      schedule.events.length,
                    ),
                    disabled: _actionsDisabled,
                    onToggleVisibility: () => unawaited(
                      _runCalendarAction(
                        debugLabel: 'Update general calendar visibility',
                        action: () => provider.updateGeneralScheduleVisibility(
                          schedule.id,
                          !schedule.isVisible,
                        ),
                      ),
                    ),
                    onRename: (anchor) => unawaited(
                      _editCalendarName(
                        schedule: schedule,
                        anchorContext: anchor,
                      ),
                    ),
                    onDelete: () => unawaited(_deleteCalendar(schedule)),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktop(BuildContext context, TimetableProvider provider) {
    final l = AppLocalizations.of(context);
    final metrics = WorkbenchChromeMetrics.of(context);
    return PopScope(
      canPop: !_actionsDisabled,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final inline = constraints.maxWidth >= 440 * metrics.textScale;
          final add = TextButton.icon(
            key: _addAnchor,
            autofocus: true,
            onPressed: _actionsDisabled
                ? null
                : () => unawaited(
                    _editCalendarName(anchorContext: _addAnchor.currentContext),
                  ),
            icon: const Icon(Icons.add, size: 18),
            label: Text(l.addCalendar),
          );
          return SkedTaskDialog(
            key: const ValueKey('category-manager-panel'),
            desktopContentOwnsScroll: true,
            title: Text(
              '${l.categoryManagerTitle} · ${provider.generalSchedules.length}',
            ),
            titleAction: inline ? add : null,
            titleBottom: inline
                ? null
                : Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: add,
                  ),
            closeEnabled: !_actionsDisabled,
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 400),
              child: ListView.separated(
                key: const PageStorageKey('calendar-manager-list'),
                shrinkWrap: true,
                primary: false,
                padding: EdgeInsets.zero,
                itemCount: provider.generalSchedules.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final schedule = provider.generalSchedules[index];
                  return _DesktopCalendarManagerRow(
                    schedule: schedule,
                    disabled: _actionsDisabled,
                    onName: (anchor) => unawaited(
                      _editCalendarName(
                        schedule: schedule,
                        anchorContext: anchor,
                      ),
                    ),
                    onColor: (anchor) =>
                        unawaited(_editCalendarColor(schedule.id, anchor)),
                    onVisibility: () => unawaited(
                      _runCalendarAction(
                        debugLabel: 'Update calendar visibility',
                        action: () async {
                          final latest = provider.generalSchedules
                              .where((item) => item.id == schedule.id)
                              .firstOrNull;
                          if (latest != null) {
                            await provider.updateGeneralScheduleVisibility(
                              latest.id,
                              !latest.isVisible,
                            );
                          }
                        },
                      ),
                    ),
                    onDelete: () => unawaited(_deleteCalendar(schedule)),
                  );
                },
              ),
            ),
            actions: [
              for (final direction in SettingsTransferDirection.values)
                TextButton.icon(
                  key: ValueKey('category-manager-${direction.name}'),
                  onPressed: _actionsDisabled
                      ? null
                      : () {
                          if (SkedTaskSessionScope.isCurrent(context)) {
                            completeEditorRoute(context, direction);
                          }
                        },
                  icon: Icon(
                    direction == SettingsTransferDirection.import
                        ? Icons.file_download_outlined
                        : Icons.file_upload_outlined,
                    size: 18,
                  ),
                  label: Text(
                    direction == SettingsTransferDirection.import
                        ? l.importAction
                        : l.exportAction,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _editCalendarColor(String id, BuildContext anchor) async {
    if (_actionsDisabled || !SkedTaskSessionScope.isCurrent(context)) return;
    final provider = context.read<TimetableProvider>();
    final schedule = provider.generalSchedules
        .where((item) => item.id == id)
        .firstOrNull;
    if (schedule == null) return;
    final owner = SkedTaskSessionScope.maybeOf(context);
    setState(() => _childTaskOpen = true);
    try {
      await showSkedAdaptivePickerDialog<void>(
        context: context,
        routeName: 'category-color-picker',
        preferredWidth: 340,
        anchorContext: anchor,
        workspace: AppMode.general,
        waitForTransitionComplete: true,
        isSessionCurrent: () =>
            mounted &&
            owner?.session.isCurrent != false &&
            provider.generalSchedules.any((item) => item.id == id),
        builder: (_) => ChangeNotifierProvider<TimetableProvider>.value(
          value: provider,
          child: SkedTaskRouteGuard(
            workspace: AppMode.general,
            provider: provider,
            isTargetCurrent: () =>
                provider.generalSchedules.any((item) => item.id == id),
            isOwnerActive: () => mounted && owner?.session.isCurrent != false,
            parent: owner?.session,
            child: _CalendarColorDialog(provider: provider, schedule: schedule),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _childTaskOpen = false);
    }
  }

  Future<void> _editCalendarName({
    GeneralSchedule? schedule,
    BuildContext? anchorContext,
  }) async {
    if (_actionsDisabled || !SkedTaskSessionScope.isCurrent(context)) return;
    final provider = context.read<TimetableProvider>();
    setState(() => _childTaskOpen = true);
    try {
      await _showCalendarNameTask(
        context,
        provider,
        schedule: schedule,
        anchorContext: anchorContext,
      );
    } finally {
      if (mounted) setState(() => _childTaskOpen = false);
    }
  }

  Future<void> _runCalendarAction({
    required String debugLabel,
    required Future<void> Function() action,
  }) async {
    if (_actionsDisabled || !SkedTaskSessionScope.isCurrent(context)) {
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
    if (_actionsDisabled || !SkedTaskSessionScope.isCurrent(context)) return;
    final provider = context.read<TimetableProvider>();
    final owner = SkedTaskSessionScope.maybeOf(context);
    setState(() => _childTaskOpen = true);
    try {
      await showExpressiveDialog<void>(
        context: context,
        waitForTransitionComplete: true,
        builder: (_) => ChangeNotifierProvider<TimetableProvider>.value(
          value: provider,
          child: SkedTaskRouteGuard(
            workspace: AppMode.general,
            provider: provider,
            isOwnerActive: () => mounted && owner?.session.isCurrent != false,
            parent: owner?.session,
            child: _DeleteCalendarDialog(
              provider: provider,
              schedule: schedule,
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _childTaskOpen = false);
    }
  }
}

class _CalendarNameDialog extends StatefulWidget {
  const _CalendarNameDialog({required this.provider, this.schedule});

  final TimetableProvider provider;
  final GeneralSchedule? schedule;

  @override
  State<_CalendarNameDialog> createState() => _CalendarNameDialogState();
}

class _CalendarNameDialogState extends State<_CalendarNameDialog>
    with EditorExitGuard<_CalendarNameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.schedule?.name ?? '',
  );
  var _busy = false;
  var _popped = false;
  bool get _canSave {
    final name = _controller.text.trim();
    return name.isNotEmpty && name != widget.schedule?.name;
  }

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
  Widget guardDiscardConfirmation(Widget dialog) {
    final owner = SkedTaskSessionScope.maybeOf(context);
    return SkedTaskRouteGuard(
      workspace: AppMode.general,
      provider: widget.provider,
      isTargetCurrent: () =>
          widget.schedule == null ||
          widget.provider.generalSchedules.any(
            (item) => item.id == widget.schedule!.id,
          ),
      isOwnerActive: () => mounted && owner?.session.isCurrent != false,
      parent: owner?.session,
      child: dialog,
    );
  }

  @override
  void closeEditor() {
    if (_popped || !mounted) return;
    setState(() => _popped = true);
    completeEditorRoute(context);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _controller.text.trim();
    if (_busy ||
        _popped ||
        !_canSave ||
        !SkedTaskSessionScope.isCurrent(context)) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    final saved = await runUiCommandWithFeedback(
      context: context,
      debugLabel: widget.schedule == null
          ? 'Add general calendar'
          : 'Rename general calendar',
      command: () => widget.schedule == null
          ? widget.provider.addGeneralSchedule(
              name: name,
              colorValue: _nextCalendarColor(widget.provider.generalSchedules),
            )
          : widget.provider.renameGeneralSchedule(widget.schedule!.id, name),
    );
    if (!mounted || !SkedTaskSessionScope.isCurrent(context)) return;
    if (saved) {
      closeEditor();
    } else {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final creating = widget.schedule == null;
    return PopScope<void>(
      canPop: _popped,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(requestEditorExit());
      },
      child: SkedTaskDialog(
        key: const ValueKey('calendar-name-dialog'),
        closeEnabled: !_busy && !_popped,
        constraints: const BoxConstraints(maxWidth: 440),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        scrollable: true,
        title: Text(creating ? l10n.addCalendar : l10n.renameCalendar),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_busy) ...[
                const UiCommandBusyIndicator(busy: true),
                const SizedBox(height: 8),
              ],
              TextField(
                key: ValueKey(
                  creating ? 'add-calendar-field' : 'rename-calendar-field',
                ),
                controller: _controller,
                enabled: !_busy && !_popped,
                autofocus: true,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: l10n.name,
                  hintText: creating ? l10n.newCalendar : null,
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => unawaited(_save()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy || _popped
                ? null
                : () => unawaited(requestEditorExit()),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: _busy || _popped || !_canSave
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

class _DeleteCalendarDialogState extends State<_DeleteCalendarDialog>
    with WorkspaceRouteLifecycle<_DeleteCalendarDialog> {
  @override
  AppMode get routeWorkspace => AppMode.general;
  @override
  Future<bool> prepareWorkspaceDisable() async => !_busy;
  var _busy = false;
  var _popped = false;

  Future<void> _delete() async {
    if (_busy ||
        _popped ||
        !SkedTaskSessionScope.isCurrent(context) ||
        !widget.provider.generalSchedules.any(
          (item) => item.id == widget.schedule.id,
        )) {
      return;
    }
    setState(() => _busy = true);
    final deleted = await runUiCommandWithFeedback(
      context: context,
      debugLabel: 'Delete general calendar',
      command: () => widget.provider.deleteGeneralSchedule(widget.schedule.id),
    );
    if (!mounted || !SkedTaskSessionScope.isCurrent(context)) return;
    if (deleted) {
      _popped = true;
      completeEditorRoute(context);
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
                    completeEditorRoute(context);
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
    super.key,
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
  final ValueChanged<BuildContext> onRename;
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
      label: '${schedule.name}, $eventCountLabel',
      hint: l10n.rename,
      onTap: disabled ? null : () => onRename(context),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          excludeFromSemantics: true,
          onTap: disabled ? null : () => onRename(context),
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
  final ValueChanged<BuildContext> onRename;
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
          child: Builder(
            builder: (anchor) =>
                SkedPopupMenuButton<_CalendarManagerMenuAction>(
                  key: ValueKey('calendar-actions-$scheduleId'),
                  enabled: !disabled,
                  tooltip: moreTooltip,
                  icon: const Icon(Icons.more_vert),
                  onSelected: (action) {
                    switch (action) {
                      case _CalendarManagerMenuAction.rename:
                        onRename(anchor);
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
        ),
      ],
    );
  }
}

enum _CalendarManagerMenuAction { rename, delete }

Future<void> _showCalendarNameTask(
  BuildContext context,
  TimetableProvider provider, {
  GeneralSchedule? schedule,
  BuildContext? anchorContext,
  SkedFloatingPlacement placement = SkedFloatingPlacement.below,
  bool Function()? isOwnerActive,
  SkedTaskSession? lifetime,
}) {
  // Capture the scope while the owner is active, not via ancestor lookups after
  // a parent route has been removed but its exit transition is still mounted.
  final owner = SkedTaskSessionScope.maybeOf(context);
  return showExpressiveDialog<void>(
    context: context,
    waitForTransitionComplete: true,
    desktopFloating: SkedDesktopFloatingDialog(
      anchorContext: anchorContext,
      placement: placement,
    ),
    builder: (_) => ChangeNotifierProvider<TimetableProvider>.value(
      value: provider,
      child: SkedTaskRouteGuard(
        workspace: AppMode.general,
        provider: provider,
        isTargetCurrent: () =>
            schedule == null ||
            provider.generalSchedules.any((item) => item.id == schedule.id),
        parent: lifetime ?? owner?.session,
        isOwnerActive:
            isOwnerActive ??
            () => context.mounted && owner?.session.isCurrent != false,
        child: _CalendarNameDialog(provider: provider, schedule: schedule),
      ),
    ),
  );
}

class _DesktopCalendarManagerRow extends StatelessWidget {
  const _DesktopCalendarManagerRow({
    required this.schedule,
    required this.disabled,
    required this.onName,
    required this.onColor,
    required this.onVisibility,
    required this.onDelete,
  });
  final GeneralSchedule schedule;
  final bool disabled;
  final ValueChanged<BuildContext> onName, onColor;
  final VoidCallback onVisibility, onDelete;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final metrics = WorkbenchChromeMetrics.of(context);
    final color = effectiveGeneralCalendarColor(context, schedule);
    return Padding(
      key: ValueKey('calendar-manager-tile-${schedule.id}'),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Builder(
            builder: (anchor) => IconButton(
              key: ValueKey('calendar-color-${schedule.id}'),
              tooltip: l.categoryEditColor,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: disabled ? null : () => onColor(anchor),
              icon: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
              ),
            ),
          ),
          Expanded(
            child: Builder(
              builder: (anchor) => Tooltip(
                message: l.rename,
                child: InkWell(
                  key: ValueKey('calendar-name-${schedule.id}'),
                  onTap: disabled ? null : () => onName(anchor),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 6,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          schedule.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          [
                            l.generalScheduleEventCount(schedule.events.length),
                            if (!schedule.isVisible) l.categoryHidden,
                          ].join(' · '),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          MergeSemantics(
            child: Semantics(
              toggled: schedule.isVisible,
              child: IconButton(
                key: ValueKey('calendar-visibility-${schedule.id}'),
                tooltip: schedule.isVisible
                    ? l.categoryHideOnCalendar
                    : l.categoryShowOnCalendar,
                onPressed: disabled ? null : onVisibility,
                style: IconButton.styleFrom(
                  minimumSize: Size.square(metrics.commandHeight),
                  maximumSize: Size.square(metrics.commandHeight),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.all(8),
                  foregroundColor: theme.colorScheme.onSurfaceVariant,
                ),
                icon: Icon(
                  schedule.isVisible
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 18,
                ),
              ),
            ),
          ),
          Builder(
            builder: (anchor) =>
                SkedPopupMenuButton<_CalendarManagerMenuAction>(
                  key: ValueKey('calendar-actions-${schedule.id}'),
                  enabled: !disabled,
                  tooltip: l.more,
                  icon: const Icon(Icons.more_horiz),
                  onSelected: (value) {
                    if (value == _CalendarManagerMenuAction.rename) {
                      onName(anchor);
                    } else {
                      onDelete();
                    }
                  },
                  itemBuilder: (_) => [
                    SkedPopupMenuItem(
                      value: _CalendarManagerMenuAction.rename,
                      child: Text(l.rename),
                    ),
                    const SkedPopupMenuDivider<_CalendarManagerMenuAction>(),
                    SkedPopupMenuItem(
                      value: _CalendarManagerMenuAction.delete,
                      child: Text(
                        l.delete,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                  ],
                ),
          ),
        ],
      ),
    );
  }
}

class _CalendarColorDialog extends StatefulWidget {
  const _CalendarColorDialog({required this.provider, required this.schedule});
  final TimetableProvider provider;
  final GeneralSchedule schedule;
  @override
  State<_CalendarColorDialog> createState() => _CalendarColorDialogState();
}

class _CalendarColorDialogState extends State<_CalendarColorDialog>
    with WorkspaceRouteLifecycle<_CalendarColorDialog> {
  late int _selected = widget.schedule.colorValue;
  bool _busy = false, _popped = false, _validHex = true;
  int _inputRevision = 0;
  bool get _blocked => _busy || _popped;
  @override
  AppMode get routeWorkspace => AppMode.general;
  @override
  Future<bool> prepareWorkspaceDisable() async => !_busy;
  void _close() {
    if (_blocked) return;
    _popped = true;
    completeEditorRoute(context);
  }

  Future<void> _save() async {
    if (_blocked || !_validHex || !SkedTaskSessionScope.isCurrent(context)) {
      return;
    }
    // Untouched theme slots must not turn into resolved RGB just by confirming.
    if (_selected == widget.schedule.colorValue) {
      _close();
      return;
    }
    setState(() => _busy = true);
    final saved = await runUiCommandWithFeedback(
      context: context,
      debugLabel: 'Update category color',
      command: () => widget.provider.updateGeneralScheduleColor(
        widget.schedule.id,
        _selected,
      ),
    );
    if (!mounted || !SkedTaskSessionScope.isCurrent(context)) return;
    setState(() => _busy = false);
    if (saved) _close();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final latest = context
        .watch<TimetableProvider>()
        .generalSchedules
        .where((item) => item.id == widget.schedule.id)
        .firstOrNull;
    final resolved = effectiveGeneralCalendarColorValue(context, _selected);
    final slot = generalCalendarSlotColorValues.contains(
      normalizeGeneralCalendarColorValue(_selected),
    );
    return PopScope(
      canPop: !_blocked,
      child: SkedTaskDialog(
        key: const ValueKey('category-color-dialog'),
        closeEnabled: !_blocked,
        title: Tooltip(
          message: latest?.name ?? widget.schedule.name,
          child: Text(
            latest?.name ?? widget.schedule.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        content: AbsorbPointer(
          absorbing: _blocked,
          child: ExcludeFocus(
            excluding: _blocked,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UiCommandBusyIndicator(busy: _busy),
                Row(
                  children: [
                    Container(width: 24, height: 24, color: resolved),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        slot ? l.categoryThemePalette : l.categoryCustomColor,
                      ),
                    ),
                    Text(formatSkedColorHex(resolved.toARGB32())),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (
                      var i = 0;
                      i < generalCalendarSlotColorValues.length;
                      i++
                    )
                      IconButton(
                        key: ValueKey('category-color-slot-$i'),
                        tooltip: l.categoryColorSlot(i + 1),
                        isSelected:
                            normalizeGeneralCalendarColorValue(_selected) ==
                            generalCalendarSlotColorValues[i],
                        onPressed: () => setState(() {
                          _selected = generalCalendarSlotColorValues[i];
                          _validHex = true;
                          _inputRevision++;
                        }),
                        icon: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: effectiveGeneralCalendarColorValue(
                              context,
                              generalCalendarSlotColorValues[i],
                            ),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              width: 2,
                              color:
                                  normalizeGeneralCalendarColorValue(
                                        _selected,
                                      ) ==
                                      generalCalendarSlotColorValues[i]
                                  ? Theme.of(context).colorScheme.onSurface
                                  : Colors.transparent,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Center(
                  child: SkedCompactColorPicker(
                    colorValue: resolved.toARGB32(),
                    showPreview: false,
                    paletteValues: const [],
                    resetToken: _inputRevision,
                    invalidHexMessage: l.colorHexInvalid,
                    onValidityChanged: (value) {
                      if (_validHex != value) setState(() => _validHex = value);
                    },
                    onColorChanged: (value) =>
                        setState(() => _selected = value),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _blocked ? null : _close,
            child: Text(l.cancel),
          ),
          FilledButton(
            key: const ValueKey('category-color-save'),
            onPressed: _blocked || !_validHex ? null : _save,
            child: Text(l.save),
          ),
        ],
      ),
    );
  }
}
