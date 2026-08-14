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
    _appData = result.data;
    _selectedWeek = 1;
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
