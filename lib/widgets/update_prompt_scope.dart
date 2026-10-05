import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../services/desktop_window_bridge.dart';

/// Read-only eligibility for unsolicited update prompts. Never exits a task.
class UpdatePromptController {
  UpdatePromptController({this.isForeground}) {
    observer = _UpdatePromptNavigatorObserver(this);
  }
  final bool Function()? isForeground;
  late final NavigatorObserver observer;
  final _blockers = <Object, bool Function()>{};
  final _routes = <Route<dynamic>>{};
  bool _started = false;
  bool _disposed = false;

  bool get canPrompt {
    if (_disposed) return false;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final bridge = DesktopWindowBridge.instance;
    final foreground =
        isForeground?.call() ??
        ((lifecycle == null || lifecycle == AppLifecycleState.resumed) &&
            (!bridge.available || bridge.focused));
    return foreground &&
        _routes.length <= 1 &&
        !_routes.any(
          (r) =>
              r is TransitionRoute &&
              r.animation?.status != AnimationStatus.completed,
        ) &&
        !_blockers.values.any((blocked) => blocked());
  }

  VoidCallback register(bool Function() blocked) {
    if (_disposed) return () {};
    final key = Object();
    _blockers[key] = blocked;
    return () => _blockers.remove(key);
  }

  /// One attempt per application host, not per workspace or page rebuild.
  Future<void> startOnce(Future<void> Function() check) async {
    if (_started || _disposed) return;
    _started = true;
    await check();
  }

  void dispose() {
    _disposed = true;
    _blockers.clear();
    _routes.clear();
  }
}

class _UpdatePromptNavigatorObserver extends NavigatorObserver {
  _UpdatePromptNavigatorObserver(this.controller);
  final UpdatePromptController controller;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      controller._routes.add(route);
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is TransitionRoute<dynamic>) {
      unawaited(route.completed.then((_) => controller._routes.remove(route)));
    } else {
      controller._routes.remove(route);
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      controller._routes.remove(route);
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) controller._routes.remove(oldRoute);
    if (newRoute != null) controller._routes.add(newRoute);
  }
}

class UpdatePromptScope extends InheritedWidget {
  const UpdatePromptScope({
    super.key,
    required this.controller,
    required super.child,
  });
  final UpdatePromptController controller;
  static UpdatePromptController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<UpdatePromptScope>()
      ?.controller;
  @override
  bool updateShouldNotify(UpdatePromptScope oldWidget) =>
      controller != oldWidget.controller;
}

/// Re-queries current task state at result time, including non-route overlays.
class UpdatePromptBlocker extends StatefulWidget {
  const UpdatePromptBlocker({
    super.key,
    required this.blocked,
    required this.child,
  });
  final bool Function() blocked;
  final Widget child;
  @override
  State<UpdatePromptBlocker> createState() => _UpdatePromptBlockerState();
}

class _UpdatePromptBlockerState extends State<UpdatePromptBlocker> {
  UpdatePromptController? _owner;
  VoidCallback? _unregister;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final owner = UpdatePromptScope.maybeOf(context);
    if (identical(owner, _owner)) return;
    _unregister?.call();
    _owner = owner;
    _unregister = owner?.register(() => mounted && widget.blocked());
  }

  @override
  void dispose() {
    _unregister?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
