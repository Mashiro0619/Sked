part of 'home_screen.dart';

extension _HomeScreenImports on _HomeScreenState {
  Future<void> _importTimetableData(BuildContext context) async {
    if (_fileImportInProgress || !mounted || !context.mounted) {
      return;
    }
    _setFileImportInProgress(true);
    try {
      await TimetableImportFlow.importTimetables(context);
    } finally {
      _setFileImportInProgress(false);
    }
  }

  Future<void> _importTimetablesFromText(BuildContext context) async {
    if (_textImportPageOpen || !mounted || !context.mounted) {
      return;
    }
    _setTextImportPageOpen(true);
    final l10n = AppLocalizations.of(context);
    final appScope = AppScope.capture(context);
    final maintenance = context.read<AppDataMaintenance>();
    final workspaceView = context.read<WorkspaceViewState>();
    final workspaces = context.read<WorkspaceCommands>();
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) {
            final page = TextImportPage(
              title: l10n.importTimetableText,
              onSubmit: (context, content) {
                if (!SkedTaskSessionScope.isCurrent(context)) {
                  return Future.value(false);
                }
                return TimetableImportFlow.importTimetablesFromSource(
                  context,
                  content,
                );
              },
            );
            final guarded = SkedTaskRouteGuard(
              maintenance: maintenance,
              workspaceView: workspaceView,
              workspaces: workspaces,
              workspace: AppMode.student,
              child: page,
            );
            return appScope?.wrap(guarded) ?? guarded;
          },
        ),
      );
    } finally {
      _setTextImportPageOpen(false);
    }
  }

  Future<void> _importTimetableFromWeb(BuildContext context) async {
    if (_schoolWebImportPageOpen || !mounted || !context.mounted) {
      return;
    }
    _setSchoolWebImportPageOpen(true);
    try {
      await TimetableImportFlow.openSchoolSitesPage(context);
    } finally {
      _setSchoolWebImportPageOpen(false);
    }
  }
}
