part of 'general_schedule_home_screen.dart';

enum _CalendarObjectAction { rename, color, visibility, delete }

/// Calendar commands keep the clicked category as their target, independently
/// of the active category used when creating an event.
class _GeneralCalendarContextMenu extends StatefulWidget {
  const _GeneralCalendarContextMenu({
    super.key,
    required this.schedule,
    required this.enabled,
    this.isOwnerCurrent,
    required this.onRename,
    this.onColor,
    required this.onVisibility,
    required this.onDelete,
    required this.child,
  });

  final GeneralSchedule schedule;
  final bool enabled;
  final bool Function()? isOwnerCurrent;
  final ValueChanged<BuildContext> onRename;
  final ValueChanged<BuildContext>? onColor;
  final VoidCallback onVisibility, onDelete;
  final Widget child;

  @override
  State<_GeneralCalendarContextMenu> createState() =>
      _GeneralCalendarContextMenuState();
}

class _GeneralCalendarContextMenuState
    extends State<_GeneralCalendarContextMenu> {
  GeneralViewState? _view;
  WorkspaceViewState? _workspace;
  AppDataMaintenance? _maintenance;
  Listenable? _changes;

  @override
  Widget build(BuildContext context) {
    if (!WorkbenchChromeMetrics.of(context).desktop) return widget.child;
    final view = context.read<GeneralViewState>();
    final workspace = context.read<WorkspaceViewState>();
    final maintenance = context.read<AppDataMaintenance>();
    if (!identical(view, _view) ||
        !identical(workspace, _workspace) ||
        !identical(maintenance, _maintenance)) {
      _view = view;
      _workspace = workspace;
      _maintenance = maintenance;
      _changes = Listenable.merge([view, workspace, maintenance]);
    }
    final schedule = widget.schedule;
    final dataSession = maintenance.dataSessionToken;
    final boundary = workspace.data.workspaceReminderNotBefore[AppMode.general];
    bool current() {
      final latest = view.schedules
          .where((item) => item.id == schedule.id)
          .firstOrNull;
      return mounted &&
          widget.enabled &&
          widget.isOwnerCurrent?.call() != false &&
          !maintenance.isReserved &&
          identical(dataSession, maintenance.dataSessionToken) &&
          workspace.isEnabled(AppMode.general) &&
          boundary ==
              workspace.data.workspaceReminderNotBefore[AppMode.general] &&
          latest?.name == schedule.name &&
          latest?.colorValue == schedule.colorValue &&
          latest?.isVisible == schedule.isVisible;
    }

    final l = AppLocalizations.of(context);
    return DesktopContextMenuRegion(
      target: (
        view,
        schedule.id,
        schedule.name,
        schedule.colorValue,
        schedule.isVisible,
        dataSession,
        boundary,
      ),
      enabled: widget.enabled,
      targetChanges: _changes,
      isOwnerCurrent: current,
      actionsBuilder: (invocation) {
        DesktopAction action(
          String id,
          String label,
          IconData icon,
          VoidCallback invoke, {
          LogicalKeyboardKey? shortcut,
        }) => DesktopAction(
          id: id,
          label: label,
          icon: icon,
          shortcut: shortcut,
          enabled: current() && invocation.isCurrent(),
          onInvoke: () {
            if (current() && invocation.isCurrent()) invoke();
          },
        );
        return [
          action(
            'rename',
            l.rename,
            Icons.edit_outlined,
            () => widget.onRename(invocation.context),
            shortcut: LogicalKeyboardKey.f2,
          ),
          if (widget.onColor case final onColor?)
            action(
              'color',
              l.categoryEditColor,
              Icons.palette_outlined,
              () => onColor(invocation.context),
            ),
          action(
            'visibility',
            schedule.isVisible
                ? l.categoryHideOnCalendar
                : l.categoryShowOnCalendar,
            schedule.isVisible
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            widget.onVisibility,
          ),
          action(
            'delete',
            l.delete,
            Icons.delete_outline,
            widget.onDelete,
            shortcut: LogicalKeyboardKey.delete,
          ),
        ];
      },
      child: widget.child,
    );
  }
}
