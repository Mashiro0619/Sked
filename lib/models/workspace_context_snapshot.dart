import 'timetable_models.dart';

/// Read-only identifiers for a future assistant. Never includes records, secrets
/// or disabled workspace identifiers. Executing changes remains a Provider job.
class WorkspaceContextSnapshot {
  WorkspaceContextSnapshot({
    required Set<AppMode> enabledWorkspaces,
    required this.mode,
    required this.view,
    this.resourceId,
    this.date,
    this.endDate,
    this.selectionId,
  }) : enabledWorkspaces = Set.unmodifiable(enabledWorkspaces) {
    if (!this.enabledWorkspaces.contains(mode)) {
      throw ArgumentError('Context workspace must be enabled.');
    }
  }
  final Set<AppMode> enabledWorkspaces;
  final AppMode mode;
  final String view;
  final String? resourceId;
  final DateTime? date;
  final DateTime? endDate;
  final String? selectionId;
  WorkspaceContextSnapshot withSelection(String? value) =>
      WorkspaceContextSnapshot(
        enabledWorkspaces: enabledWorkspaces,
        mode: mode,
        view: view,
        resourceId: resourceId,
        date: date,
        endDate: endDate,
        selectionId: value,
      );
}
