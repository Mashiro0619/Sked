import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../controllers/app_data_maintenance.dart';
import '../controllers/student_view_state.dart';
import '../controllers/workspace_view_state.dart';
import '../models/app_mode.dart';
import 'desktop_context_menu.dart';

/// A student resource keeps its own identity even when another one is active.
class StudentResourceContextMenu extends StatefulWidget {
  const StudentResourceContextMenu({
    super.key,
    required this.target,
    this.enabled = true,
    this.isOwnerCurrent,
    this.isTargetCurrent,
    required this.actionsBuilder,
    required this.child,
  });

  final Object target;
  final bool enabled;
  final bool Function()? isOwnerCurrent;
  final bool Function()? isTargetCurrent;
  final List<DesktopAction> Function(DesktopActionContext) actionsBuilder;
  final Widget child;

  @override
  State<StudentResourceContextMenu> createState() =>
      _StudentResourceContextMenuState();
}

class _StudentResourceContextMenuState
    extends State<StudentResourceContextMenu> {
  StudentViewState? _student;
  WorkspaceViewState? _workspace;
  AppDataMaintenance? _maintenance;
  Listenable? _changes;

  @override
  Widget build(BuildContext context) {
    final student = context.read<StudentViewState>();
    final workspace = context.read<WorkspaceViewState>();
    final maintenance = context.read<AppDataMaintenance>();
    if (!identical(student, _student) ||
        !identical(workspace, _workspace) ||
        !identical(maintenance, _maintenance)) {
      _student = student;
      _workspace = workspace;
      _maintenance = maintenance;
      _changes = Listenable.merge([student, workspace, maintenance]);
    }
    final dataSession = maintenance.dataSessionToken;
    final boundary = workspace.data.workspaceReminderNotBefore[AppMode.student];
    return DesktopContextMenuRegion(
      target: (widget.target, dataSession, boundary),
      enabled: widget.enabled,
      targetChanges: _changes,
      isOwnerCurrent: () =>
          mounted &&
          !maintenance.isReserved &&
          identical(dataSession, maintenance.dataSessionToken) &&
          workspace.isEnabled(AppMode.student) &&
          boundary ==
              workspace.data.workspaceReminderNotBefore[AppMode.student] &&
          widget.isOwnerCurrent?.call() != false &&
          widget.isTargetCurrent?.call() != false,
      actionsBuilder: widget.actionsBuilder,
      child: widget.child,
    );
  }
}
