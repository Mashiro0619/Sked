import 'dart:async';

import 'package:material_ui/material_ui.dart';

WidgetBuilder _retainedSheetBuilder(WidgetBuilder builder) {
  final contentKey = GlobalKey(debugLabel: 'guarded-bottom-sheet-content');
  // The native sheet inserts/removes a Stack around its content with the
  // handle. Retain the whole task, including controller ownership and guards,
  // across that reparenting when a landscape keyboard leaves too little room.
  return (context) => KeyedSubtree(
    key: contentKey,
    child: Builder(builder: builder),
  );
}

/// Storage recovery invalidates ordinary tasks. The caller supplies the exact
/// retained boundary (for example a recoverable import draft), so a blocked
/// sheet must not make Navigator.popUntil retry the same route indefinitely.
void retireSkedTaskRoutesUntil(
  NavigatorState navigator,
  RoutePredicate retain,
) {
  navigator.popUntil((route) {
    if (retain(route)) return true;
    if (route is SkedGuardedBottomSheetRoute<dynamic>) {
      route._authorizedCompletion = true;
    }
    return false;
  });
}

/// Native sheet dragging and the handle's accessibility action call pop
/// directly. Route-level gating also covers those paths, not just maybePop.
class SkedGuardedBottomSheetRoute<T> extends ModalBottomSheetRoute<T> {
  SkedGuardedBottomSheetRoute({
    required WidgetBuilder builder,
    required super.isScrollControlled,
    super.capturedThemes,
    super.barrierLabel,
    super.barrierOnTapHint,
    super.backgroundColor,
    super.elevation,
    super.shape,
    super.clipBehavior,
    super.constraints,
    super.modalBarrierColor,
    super.isDismissible,
    super.enableDrag,
    super.showDragHandle,
    super.useSafeArea,
    super.settings,
    super.sheetAnimationStyle,
  }) : super(builder: _retainedSheetBuilder(builder));

  bool _authorizedCompletion = false;
  bool _exitNotificationPending = false;
  bool _keyboardOccupiesWindow = false;

  @override
  bool? get showDragHandle =>
      _keyboardOccupiesWindow ? false : super.showDragHandle;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final media = MediaQuery.of(context);
    // The native handle reserves 48dp even when its line is only 4dp high.
    // A landscape IME can leave less than that plus one accessible command.
    // Keep body dragging and Back available, and return the handle as soon as
    // the keyboard leaves enough room for the form and its fixed actions.
    _keyboardOccupiesWindow =
        media.viewInsets.bottom > 0 &&
        media.size.height - media.viewInsets.bottom - media.padding.top < 144;
    return super.buildPage(context, animation, secondaryAnimation);
  }

  /// Only call after validation/persistence or the user's guarded exit.
  void complete(T? result) {
    final owner = navigator;
    if (!isActive || owner == null) return;
    _authorizedCompletion = true;
    try {
      if (isCurrent) {
        owner.pop<T>(result);
      } else {
        owner.removeRoute(this, result);
      }
    } finally {
      _authorizedCompletion = false;
    }
  }

  @override
  bool didPop(T? result) {
    if (_authorizedCompletion ||
        popDisposition != RoutePopDisposition.doNotPop) {
      return super.didPop(result);
    }
    // A drag starts reversing before asking to pop. Keep the original route
    // visible while a draft confirmation or a pending write blocks the exit.
    unawaited(controller?.forward());
    if (!_exitNotificationPending) {
      _exitNotificationPending = true;
      scheduleMicrotask(() {
        _exitNotificationPending = false;
        if (isActive && isCurrent) onPopInvokedWithResult(false, result);
      });
    }
    return false;
  }
}
