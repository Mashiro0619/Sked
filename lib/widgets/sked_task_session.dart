import 'package:material_ui/material_ui.dart';

import '../models/app_mode.dart';
import '../providers/timetable_provider.dart';

/// A task lifetime, independent of route type, draft, persistence and layout.
/// Invalidity is latched: becoming available again never revives an old task.
class SkedTaskSession extends ChangeNotifier {
  SkedTaskSession({
    this.provider,
    this.workspace,
    this.parent,
    this.isOwnerActive,
    this.isTargetCurrent,
  }) : _dataSession = provider?.dataSessionToken,
       _resumeBoundary =
           provider?.appData.workspaceReminderNotBefore[workspace] {
    provider?.addListener(check);
    parent?.addListener(check);
    check();
  }
  final TimetableProvider? provider;
  final AppMode? workspace;
  final SkedTaskSession? parent;
  final bool Function()? isOwnerActive;
  final bool Function()? isTargetCurrent;
  final Object? _dataSession;
  final Object? _resumeBoundary;
  bool _invalidated = false;
  bool _disposed = false;

  bool get isCurrent {
    if (_disposed || _invalidated) return false;
    if (parent?.isCurrent == false ||
        !identical(_dataSession, provider?.dataSessionToken) ||
        _resumeBoundary !=
            provider?.appData.workspaceReminderNotBefore[workspace] ||
        (workspace != null &&
            provider?.isWorkspaceEnabled(workspace!) == false) ||
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
    provider?.removeListener(check);
    parent?.removeListener(check);
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
    this.workspace,
    this.parent,
    this.isOwnerActive,
    this.isTargetCurrent,
    required this.child,
  });
  final TimetableProvider? provider;
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
