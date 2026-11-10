part of 'home_screen.dart';

enum _TimetableExportAction { share, save, text }

extension _HomeScreenResourceActions on _HomeScreenState {
  List<DesktopAction> _timetableActions(
    BuildContext context,
    TimetableData timetable,
    DesktopActionContext actionContext, {
    Future<void> Function()? editAction,
  }) {
    final l10n = AppLocalizations.of(context);
    final enabled =
        mounted &&
        widget.active &&
        widget.interactive &&
        !_courseEditorOpen &&
        !_courseDeleteOpen &&
        !_timetableItemDialogOpen &&
        !_timetableResourceActionOpen &&
        actionContext.isCurrent();
    return [
      DesktopAction(
        id: 'timetable.edit',
        label: l10n.editTimetable,
        icon: Icons.edit_outlined,
        shortcut: LogicalKeyboardKey.f2,
        enabled: enabled,
        onInvoke:
            editAction ??
            () async {
              await _openTimetableItemDialog(
                context,
                timetable,
                editor: WorkspaceEditorConfiguration(
                  anchorContext: actionContext.context,
                ),
              );
            },
      ),
      DesktopAction(
        id: 'timetable.export.share',
        label: l10n.shareTimetableFiles,
        icon: Icons.share_outlined,
        enabled: enabled,
        onInvoke: () => _exportTimetableFromMenu(
          context,
          timetable.id,
          actionContext,
          _TimetableExportAction.share,
        ),
      ),
      DesktopAction(
        id: 'timetable.export.save',
        label: l10n.saveTimetableFiles,
        icon: Icons.save_alt_outlined,
        enabled: enabled,
        onInvoke: () => _exportTimetableFromMenu(
          context,
          timetable.id,
          actionContext,
          _TimetableExportAction.save,
        ),
      ),
      DesktopAction(
        id: 'timetable.export.text',
        label: l10n.exportTimetableText,
        icon: Icons.text_snippet_outlined,
        enabled: enabled,
        onInvoke: () => _exportTimetableFromMenu(
          context,
          timetable.id,
          actionContext,
          _TimetableExportAction.text,
        ),
      ),
      DesktopAction(
        id: 'timetable.delete',
        label: l10n.deleteTimetableTitle,
        icon: Icons.delete_outline,
        shortcut: LogicalKeyboardKey.delete,
        enabled: enabled,
        onInvoke: () =>
            _deleteTimetableFromMenu(context, timetable.id, actionContext),
      ),
    ];
  }

  Future<void> _exportTimetableFromMenu(
    BuildContext context,
    String timetableId,
    DesktopActionContext actionContext,
    _TimetableExportAction action,
  ) async {
    if (!mounted ||
        !context.mounted ||
        _timetableResourceActionOpen ||
        !actionContext.isCurrent()) {
      return;
    }
    final transfers = context.read<DataTransferController>();
    final l10n = AppLocalizations.of(context);
    const service = ExportService();
    _setTimetableResourceActionOpen(true);
    try {
      await runUiCommandWithFeedback(
        context: context,
        debugLabel: 'Export timetable',
        command: () async {
          final content = await transfers.exportTimetables([timetableId]);
          if (!context.mounted || !actionContext.isCurrent()) return;
          final payload = ExportPayload(
            fileName: 'Sked_timetables.json',
            content: content,
          );
          switch (action) {
            case _TimetableExportAction.share:
              await service.shareFile(payload);
            case _TimetableExportAction.save:
              await saveExportWithFeedback(
                context: context,
                service: service,
                payload: payload,
                isCurrent: actionContext.isCurrent,
              );
            case _TimetableExportAction.text:
              await showTextExportDialog(
                context,
                title: l10n.exportTimetableText,
                content: content,
              );
          }
        },
      );
    } finally {
      _setTimetableResourceActionOpen(false);
    }
  }

  Future<void> _deleteTimetableFromMenu(
    BuildContext context,
    String timetableId,
    DesktopActionContext actionContext,
  ) async {
    if (!mounted ||
        !context.mounted ||
        _timetableResourceActionOpen ||
        !actionContext.isCurrent()) {
      return;
    }
    final student = context.read<StudentViewState>();
    final timetable = student.timetables
        .where((item) => item.id == timetableId)
        .firstOrNull;
    if (timetable == null) return;
    final commands = context.read<StudentCommands>();
    var submitted = false;
    final session = SkedTaskSession(
      maintenance: context.read<AppDataMaintenance>(),
      workspaceView: context.read<WorkspaceViewState>(),
      workspace: AppMode.student,
      targetChanges: student,
      ownerRoute: ModalRoute.of(context),
      isOwnerActive: () => mounted && widget.active && widget.interactive,
      isTargetCurrent: () => submitted || actionContext.isCurrent(),
    );
    _setTimetableResourceActionOpen(true);
    try {
      await showExpressiveDialog<bool>(
        context: context,
        barrierDismissible: false,
        session: session,
        builder: (dialogContext) {
          final l10n = AppLocalizations.of(dialogContext);
          return SkedMutationConfirmationDialog(
            workspace: AppMode.student,
            title: l10n.deleteTimetableTitle,
            message: l10n.deleteTimetableMessage(timetable.config.name),
            confirmLabel: l10n.delete,
            debugLabel: 'Delete timetable',
            onConfirm: () async {
              if (!session.isCurrent) {
                throw StateError(
                  'The selected timetable is no longer current.',
                );
              }
              // The accepted write owns its original ID through removal,
              // completion, and failure rollback followed by an explicit retry.
              submitted = true;
              await commands.deleteTimetable(timetableId);
            },
          );
        },
      );
    } finally {
      session.dispose();
      _setTimetableResourceActionOpen(false);
    }
  }
}
