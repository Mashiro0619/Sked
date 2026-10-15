part of 'home_screen.dart';

extension _HomeScreenImports on _HomeScreenState {
  Future<void> _importTimetableData(
    BuildContext context,
    TimetableProvider provider,
  ) async {
    if (_fileImportInProgress || !mounted) {
      return;
    }
    _setFileImportInProgress(true);
    try {
      await TimetableImportFlow.importTimetables(context);
    } finally {
      _setFileImportInProgress(false);
    }
  }

  Future<void> _importTimetablesFromText(
    BuildContext context,
    TimetableProvider provider,
  ) async {
    if (_textImportPageOpen || !mounted) {
      return;
    }
    _setTextImportPageOpen(true);
    final l10n = AppLocalizations.of(context);
    final appScope = AppScope.capture(context)!;
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => appScope.wrap(
            TextImportPage(
              title: l10n.importTimetableText,
              onSubmit: (context, content) {
                return TimetableImportFlow.importTimetablesFromSource(
                  context,
                  content,
                );
              },
            ),
          ),
        ),
      );
    } finally {
      _setTextImportPageOpen(false);
    }
  }

  Future<void> _importTimetableFromWeb(
    BuildContext context,
    TimetableProvider provider,
  ) async {
    if (_schoolWebImportPageOpen || !mounted) {
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
