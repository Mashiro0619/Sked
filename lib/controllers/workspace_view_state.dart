import '../models/timetable_models.dart';
import 'app_session.dart';
import 'general_view_state.dart';

/// Keeps workspace selection and availability visible as one committed view
/// while their transaction prepares a new snapshot in the shared session.
class WorkspaceViewState {
  WorkspaceViewState(this._session, this._general);

  final AppSession _session;
  final GeneralViewState _general;
  AppMode? _previousMode;
  Set<AppMode>? _previousAvailability;

  AppMode get activeMode => _previousMode ?? _session.data.activeMode;
  bool get isGeneralMode => activeMode == AppMode.general;
  bool get isStudentMode => activeMode == AppMode.student;
  Set<AppMode> get enabledWorkspaces =>
      _previousAvailability ?? _session.data.enabledWorkspaces;
  bool isEnabled(AppMode mode) => enabledWorkspaces.contains(mode);

  AppData get data {
    final current = _session.data;
    if (_previousMode == null &&
        _previousAvailability == null &&
        !_general.hasNavigationOverride) {
      return current;
    }
    return current.copyWith(
      activeMode: _previousMode,
      enabledWorkspaces: _previousAvailability,
      generalMode: _general.visibleData,
    );
  }

  void keepPreviousMode(AppMode mode) => _previousMode = mode;

  void keepPreviousAvailability(AppData previous) {
    _previousMode = previous.activeMode;
    _previousAvailability = previous.enabledWorkspaces;
  }

  void completeChange() {
    _previousMode = null;
    _previousAvailability = null;
  }
}
