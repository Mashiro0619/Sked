import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

/// Mirrors only the root Navigator's scrim paint onto native window chrome.
/// Pane-local dialogs do not dim the whole window. No second modal route,
/// barrier gesture or focus scope is created for the window buttons.
class DesktopWindowModalObserver extends NavigatorObserver with ChangeNotifier {
  final _routes = <Route<dynamic>>[];
  final _animations = <Route<dynamic>, Animation<double>>{};
  final _popping = <Route<dynamic>>{};
  bool _disposed = false;
  bool _notificationScheduled = false;

  Color get scrimColor {
    var result = Colors.transparent;
    for (final route in _routes) {
      // A fully opaque page above a popup hides its barrier as well. During
      // transitions, use the Overlay's actual opacity rather than route type.
      if (route.overlayEntries.any((entry) => entry.opaque)) {
        result = Colors.transparent;
        continue;
      }
      if (route is! ModalRoute<dynamic> || route.offstage) continue;
      final color = route.barrierColor;
      final animation = route.animation;
      if (color == null || color.a == 0 || animation == null) continue;
      // This is the same color/curve sequence used by ModalRoute's barrier,
      // including its reverse animation. Do not guess a fixed black opacity.
      final paint = ColorTween(
        begin: color.withValues(alpha: 0),
        end: color,
      ).chain(CurveTween(curve: route.barrierCurve)).transform(animation.value);
      result = Color.alphaBlend(paint!, result);
    }
    return result;
  }

  void _watch(Route<dynamic> route) {
    if (route is TransitionRoute<dynamic> && route.animation != null) {
      _animations[route] = route.animation!;
      route.animation!.addListener(_changed);
    }
  }

  void _changed() {
    if (_disposed) return;
    // Navigator installs its initial routes during build. Notify the host
    // after that frame rather than rebuilding an ancestor during layout.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (_notificationScheduled) return;
      _notificationScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _notificationScheduled = false;
        if (!_disposed) notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }

  void _forget(Route<dynamic> route) {
    _animations.remove(route)?.removeListener(_changed);
    _popping.remove(route);
    _routes.remove(route);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.add(route);
    _watch(route);
    _changed();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is TransitionRoute<dynamic>) {
      if (!_popping.add(route)) return;
      // didPop starts the reverse transition; its barrier is still visible.
      unawaited(
        route.completed.then((_) {
          if (_disposed || !_routes.contains(route)) return;
          _forget(route);
          _changed();
        }),
      );
    } else {
      _forget(route);
      _changed();
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _forget(route);
    _changed();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (oldRoute != null) _forget(oldRoute);
    if (newRoute != null) {
      _routes.insert(index < 0 ? _routes.length : index, newRoute);
      _watch(newRoute);
    }
    _changed();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final animation in _animations.values) {
      animation.removeListener(_changed);
    }
    _animations.clear();
    _routes.clear();
    _popping.clear();
    super.dispose();
  }
}
