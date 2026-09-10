import 'agenda.dart';
import 'app_data.dart';
import 'app_mode.dart';

AppMode? workspaceForAgendaSource(String source) => switch (source) {
  AgendaSourceType.course => AppMode.student,
  AgendaSourceType.generalEvent => AppMode.general,
  _ => null,
};

extension WorkspaceAvailability on AppData {
  bool allowsAgendaSource(String source) {
    final mode = workspaceForAgendaSource(source);
    return mode == null || isWorkspaceEnabled(mode);
  }

  bool sameWorkspaceAvailability(AppData other) =>
      enabledWorkspaces.length == other.enabledWorkspaces.length &&
      enabledWorkspaces.every(other.enabledWorkspaces.contains) &&
      workspaceReminderNotBefore.length ==
          other.workspaceReminderNotBefore.length &&
      workspaceReminderNotBefore.entries.every(
        (entry) => other.workspaceReminderNotBefore[entry.key] == entry.value,
      );
}
