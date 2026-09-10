part of 'timetable_provider.dart';

mixin _TimetableProviderDeveloper on _TimetableProviderBase {
  Future<void> addDeveloperSampleData(
    DeveloperSampleLanguage language, {
    DateTime? now,
  }) async {
    _ensureAppBackupRestoreMutationAllowed();
    if (!_repository.canWrite) {
      throw RecoveryWriteBlockedException(_repository.lastLoadStatus);
    }
    final result = DeveloperSampleDataService.append(
      current: _appData,
      language: language,
      now: now ?? DateTime.now(),
    );
    final previousSelectedWeek = _selectedWeek;
    _appData = result.data.copyWith(
      studentMode: _appData.isWorkspaceEnabled(AppMode.student)
          ? result.data.studentMode
          : _appData.studentMode,
      generalMode: _appData.isWorkspaceEnabled(AppMode.general)
          ? result.data.generalMode
          : _appData.generalMode,
    );
    if (_appData.isWorkspaceEnabled(AppMode.student)) _selectedWeek = 1;
    try {
      await _saveAndNotify();
    } catch (_) {
      if (_selectedWeek != previousSelectedWeek) {
        _selectedWeek = previousSelectedWeek;
        notifyListeners();
      }
      rethrow;
    }
  }
}
