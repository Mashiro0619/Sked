import 'package:flutter/foundation.dart' show VoidCallback;

import '../data/app_repository.dart';
import '../models/timetable_models.dart';
import '../services/developer_sample_data_service.dart';
import 'app_persistence.dart';
import 'app_session.dart';
import 'student_view_state.dart';

/// Applies developer sample data through the ordinary session write boundary.
class DeveloperCommands {
  DeveloperCommands({
    required this._session,
    required this._student,
    required this._persistence,
    required this._notifyViewChanged,
  });

  final AppSession _session;
  final StudentViewState _student;
  final AppPersistence _persistence;
  final VoidCallback _notifyViewChanged;

  Future<void> addSampleData(
    DeveloperSampleLanguage language, {
    DateTime? now,
  }) async {
    _session.ensureMutationAllowed();
    if (!_session.canWrite) {
      throw RecoveryWriteBlockedException(_session.repository.lastLoadStatus);
    }
    final previous = _session.data;
    final result = DeveloperSampleDataService.append(
      current: previous,
      language: language,
      now: now ?? DateTime.now(),
    );
    final previousSelectedWeek = _student.selectedWeek;
    _session.replaceData(
      result.data.copyWith(
        studentMode: previous.isWorkspaceEnabled(AppMode.student)
            ? result.data.studentMode
            : previous.studentMode,
        generalMode: previous.isWorkspaceEnabled(AppMode.general)
            ? result.data.generalMode
            : previous.generalMode,
      ),
    );
    if (previous.isWorkspaceEnabled(AppMode.student)) _student.selectedWeek = 1;
    try {
      await _persistence.saveAndNotify();
    } catch (_) {
      if (_student.selectedWeek != previousSelectedWeek) {
        _student.selectedWeek = previousSelectedWeek;
        _notifyViewChanged();
      }
      rethrow;
    }
  }
}
