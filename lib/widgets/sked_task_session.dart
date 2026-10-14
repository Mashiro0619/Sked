import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../controllers/app_data_maintenance.dart';
import '../controllers/workspace_commands.dart';
import '../controllers/workspace_view_state.dart';
import '../models/app_mode.dart';
import '../providers/timetable_provider.dart';

/// A task lifetime, independent of route type, draft, persistence and layout.
/// Invalidity is latched: becoming available again never revives an old task.
class SkedTaskSession extends ChangeNotifier {
  /// [targetChanges] publishes the domain read by [isTargetCurrent]. The
  /// provider bridge supplies that notification source for existing callers.
  SkedTaskSession({
    this.provider,
    AppDataMaintenance? maintenance,
    WorkspaceViewState? workspaceView,
    WorkspaceCommands? workspaces,
    Listenable? targetChanges,
    this.workspace,
    this.parent,
    this.ownerRoute,
    this.isOwnerActive,
    this.isTargetCurrent,
  }) : maintenance = maintenance ?? provider?.maintenance,
       workspaceView = workspaceView ?? provider?.workspaceView,
       workspaces = workspaces ?? provider?.workspaces,
       _dataSession = (maintenance ?? provider?.maintenance)?.dataSessionToken,
       _resumeBoundary = (workspaceView ?? provider?.workspaceView)
           ?.data
           .workspaceReminderNotBefore[workspace] {
    _changes = Listenable.merge([
      this.maintenance,
      this.workspaceView,
      targetChanges ?? provider,
      parent,
    ])..addListener(check);
    final weak = WeakReference(this);
    unawaited(ownerRoute?.completed.then((_) => weak.target?.check()));
    check();
  }

  /// Legacy construction bridge while callers move to domain dependencies.
  final TimetableProvider? provider;
  final AppDataMaintenance? maintenance;
  final WorkspaceViewState? workspaceView;
  final WorkspaceCommands? workspaces;
  final AppMode? workspace;
  final SkedTaskSession? parent;
  final ModalRoute<dynamic>? ownerRoute;
  final bool Function()? isOwnerActive;
  final bool Function()? isTargetCurrent;
  final Object? _dataSession;
  final Object? _resumeBoundary;
  late final Listenable _changes;
  bool _invalidated = false;
  bool _disposed = false;

  bool get isCurrent {
    if (_disposed || _invalidated) return false;
    if (ownerRoute?.isActive == false ||
        parent?.isCurrent == false ||
        !identical(_dataSession, maintenance?.dataSessionToken) ||
        _resumeBoundary !=
            workspaceView?.data.workspaceReminderNotBefore[workspace] ||
        (workspace != null && workspaceView?.isEnabled(workspace!) == false) ||
        isOwnerActive?.call() == false ||
        isTargetCurrent?.call() == false) {
      invalidate();
      return false;
    }
    return true;
  }

  void check() {
    isCurrent;
  }

  void invalidate() {
    if (_invalidated || _disposed) return;
    _invalidated = true;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    invalidate();
    _disposed = true;
    _changes.removeListener(check);
    super.dispose();
  }
}

class SkedTaskSessionScope extends InheritedWidget {
  const SkedTaskSessionScope({
    super.key,
    required this.session,
    required super.child,
  });
  final SkedTaskSession session;
  static SkedTaskSessionScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SkedTaskSessionScope>();
  static bool isCurrent(BuildContext context) =>
      context.mounted && (maybeOf(context)?.session.isCurrent ?? true);
  @override
  bool updateShouldNotify(SkedTaskSessionScope oldWidget) =>
      session != oldWidget.session;
}

/// Owns a child session and retires only the route containing this guard.
/// User-requested exits still go through the route's existing PopScope guards.
class SkedTaskRouteGuard extends StatefulWidget {
  const SkedTaskRouteGuard({
    super.key,
    this.provider,
    this.maintenance,
    this.workspaceView,
    this.workspaces,
    this.targetChanges,
    this.workspace,
    this.parent,
    this.isOwnerActive,
    this.isTargetCurrent,
    required this.child,
  });
  final TimetableProvider? provider;
  final AppDataMaintenance? maintenance;
  final WorkspaceViewState? workspaceView;
  final WorkspaceCommands? workspaces;
  final Listenable? targetChanges;
  final AppMode? workspace;
  final SkedTaskSession? parent;
  final bool Function()? isOwnerActive;
  final bool Function()? isTargetCurrent;
  final Widget child;
  @override
  State<SkedTaskRouteGuard> createState() => _SkedTaskRouteGuardState();
}

class _SkedTaskRouteGuardState extends State<SkedTaskRouteGuard> {
  late final SkedTaskSession _session;
  ModalRoute<dynamic>? _route;
  bool _scheduled = false;
  @override
  void initState() {
    super.initState();
    _session = SkedTaskSession(
      provider: widget.provider,
      maintenance: widget.maintenance,
      workspaceView: widget.workspaceView,
      workspaces: widget.workspaces,
      targetChanges: widget.targetChanges,
      workspace: widget.workspace,
      parent: widget.parent,
      isOwnerActive: () =>
          mounted &&
          (_route?.isActive ?? true) &&
          widget.isOwnerActive?.call() != false,
      isTargetCurrent: () => widget.isTargetCurrent?.call() != false,
    )..addListener(_check);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
    _check();
  }

  @override
  void didUpdateWidget(SkedTaskRouteGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A guard belongs to one data owner and one task. Replacing that identity
    // invalidates it rather than silently capturing a fresh data session.
    if (oldWidget.provider != widget.provider ||
        oldWidget.maintenance != widget.maintenance ||
        oldWidget.workspaceView != widget.workspaceView ||
        oldWidget.workspaces != widget.workspaces ||
        oldWidget.targetChanges != widget.targetChanges ||
        oldWidget.workspace != widget.workspace ||
        oldWidget.parent != widget.parent) {
      _session.invalidate();
    }
    _check();
  }

  void _check() {
    if (!mounted || _scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || _session.isCurrent) return;
      final route = _route;
      if (route?.isActive == true) route!.navigator?.removeRoute(route);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  Widget build(BuildContext context) =>
      SkedTaskSessionScope(session: _session, child: widget.child);
  @override
  void dispose() {
    _session.removeListener(_check);
    _session.dispose();
    super.dispose();
  }
}
