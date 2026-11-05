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
    try {
      await TimetableImportFlow.openTextImportPage(context);
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
