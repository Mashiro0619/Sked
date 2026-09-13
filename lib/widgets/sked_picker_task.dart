import '../theme/sked_surface.dart';

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/app_mode.dart';
import '../providers/timetable_provider.dart';
import 'workbench_chrome_metrics.dart';

typedef SkedPickerTaskBuilder<T> = Widget Function(
  BuildContext context,
  ValueChanged<T?> finish,
  bool Function() isSessionCurrent,
);

/// A single, adaptive picker route with owner/session validity and focus restore.
/// Content owns its draft and validation; resize and IME changes only reposition it.
Future<T?> showSkedPickerTask<T>({
  required BuildContext context,
  required String routeName,
  required Size Function(BuildContext) preferredSize,
  required SkedPickerTaskBuilder<T> builder,
  BuildContext? anchorContext,
  AppMode? workspace,
  Key? surfaceKey,
  bool Function()? isSessionCurrent,
}) async {
  final parent = ModalRoute.of(context);
  final focus =
      _anchorFocus(anchorContext) ?? FocusManager.instance.primaryFocus;
  final provider = Provider.of<TimetableProvider?>(context, listen: false);
  if (workspace != null && provider?.isWorkspaceEnabled(workspace) == false) {
    return null;
  }
  final dataSession = provider?.dataSessionToken;
  final resumeBoundary =
      provider?.appData.workspaceReminderNotBefore[workspace];
  var sessionInvalidated = false;
  bool sessionAvailable() {
    sessionInvalidated =
        sessionInvalidated ||
        !identical(dataSession, provider?.dataSessionToken) ||
        resumeBoundary !=
            provider?.appData.workspaceReminderNotBefore[workspace] ||
        isSessionCurrent?.call() == false;
    return !sessionInvalidated;
  }

  if (!sessionAvailable()) return null;
  final desktop = WorkbenchChromeMetrics.of(context).desktop;
  final navigator = Navigator.of(context, rootNavigator: true);
  final themes = InheritedTheme.capture(from: context, to: navigator.context);
  final route = RawDialogRoute<T>(
    settings: RouteSettings(name: routeName),
    barrierDismissible: true,
    barrierColor: desktop ? Colors.transparent : Colors.black54,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    transitionDuration: const Duration(milliseconds: 120),
    traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
    pageBuilder: (routeContext, animation, secondaryAnimation) => themes.wrap(
      _PickerTaskHost<T>(
        builder: builder,
        preferredSize: preferredSize,
        surfaceKey: surfaceKey,
        ownerContext: context,
        isSessionCurrent: sessionAvailable,
        ownerRoute: parent,
        anchorContext: anchorContext,
        provider: provider,
        workspace: workspace,
      ),
    ),
  );
  final result = await navigator.push(route);
  if (context.mounted &&
      sessionAvailable() &&
      (parent?.isActive ?? true) &&
      (workspace == null || provider?.isWorkspaceEnabled(workspace) != false)) {
    unawaited(
      route.completed.then((_) {
        if (context.mounted &&
            sessionAvailable() &&
            (parent?.isActive ?? true) &&
            focus?.context?.mounted == true &&
            focus!.canRequestFocus) {
          focus.requestFocus();
        }
      }),
    );
    return result;
  }
  return null;
}

FocusNode? _anchorFocus(BuildContext? anchor) {
  if (anchor == null || !anchor.mounted) return null;
  final outer = Focus.maybeOf(anchor, createDependency: false);
  FocusNode? result;
  void visit(Element element) {
    if (result != null) return;
    final node = Focus.maybeOf(element, createDependency: false);
    if (node != null && !identical(node, outer) && node.canRequestFocus) {
      result = node;
    } else {
      element.visitChildElements(visit);
    }
  }

  anchor.visitChildElements(visit);
  return result;
}

class _PickerTaskHost<T> extends StatefulWidget {
  const _PickerTaskHost({
    required this.builder,
    required this.preferredSize,
    required this.surfaceKey,
    required this.ownerContext,
    required this.isSessionCurrent,
    required this.ownerRoute,
    required this.anchorContext,
    required this.provider,
    required this.workspace,
  });
  final SkedPickerTaskBuilder<T> builder;
  final Size Function(BuildContext) preferredSize;
  final Key? surfaceKey;
  final BuildContext ownerContext;
  final bool Function() isSessionCurrent;
  final ModalRoute<dynamic>? ownerRoute;
  final BuildContext? anchorContext;
  final TimetableProvider? provider;
  final AppMode? workspace;
  @override
  State<_PickerTaskHost<T>> createState() => _PickerTaskHostState<T>();
}

class _PickerTaskHostState<T> extends State<_PickerTaskHost<T>> {
  bool _finished = false;
  bool get _ownerAvailable =>
      widget.ownerContext.mounted &&
      widget.isSessionCurrent() &&
      (widget.ownerRoute?.isActive ?? true) &&
      (widget.workspace == null ||
          widget.provider?.isWorkspaceEnabled(widget.workspace!) != false);
  @override
  void initState() {
    super.initState();
    widget.provider?.addListener(_checkOwner);
    final owner = widget.ownerRoute;
    if (owner != null) {
      // A home route can outlive hundreds of picker sessions. Do not retain
      // each disposed picker until that route eventually completes.
      final host = WeakReference(this);
      unawaited(
        owner.completed.then((_) {
          final state = host.target;
          if (state?.mounted == true) state!._finish(null);
        }),
      );
    }
  }

  void _checkOwner() {
    // Evaluate immediately so a transient invalidation cannot revive this task.
    // Check again after the owner's widgets have observed the same notification.
    if (_finished) return;
    final available = _ownerAvailable;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && (!available || !_ownerAvailable)) _finish(null);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _finish(T? value) {
    if (!mounted || _finished) return;
    _finished = true;
    final route = ModalRoute.of(context)!;
    final result = _ownerAvailable ? value : null;
    if (route.isCurrent) {
      Navigator.of(context).pop(result);
    } else if (route.isActive) {
      route.navigator?.removeRoute(route, result);
    }
  }

  @override
  void dispose() {
    widget.provider?.removeListener(_checkOwner);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final media = MediaQuery.of(context);
      final metrics = WorkbenchChromeMetrics.of(context);
      final preferred = widget.preferredSize(context);
      final top =
          media.padding.top + (metrics.desktop ? metrics.toolbarHeight : 0);
      final bottomSheet = WorkbenchChromeMetrics.compactTouch(
        context,
        width: constraints.maxWidth,
      );
      // A bottom task paints its own navigation-bar safe area. With an IME it
      // ends above the keyboard instead; never reserve the same inset twice.
      final safeBottom = bottomSheet && media.viewInsets.bottom == 0
          ? media.viewPadding.bottom
          : 0.0;
      final bottom = bottomSheet
          ? media.viewInsets.bottom
          : math.max(media.padding.bottom, media.viewInsets.bottom);
      final margin = bottomSheet ? 0.0 : 8.0;
      final bounds = Rect.fromLTRB(
        media.padding.left + margin,
        top + margin,
        constraints.maxWidth - media.padding.right - margin,
        math.max(top + margin, constraints.maxHeight - bottom - margin),
      );
      Rect? anchor;
      final anchorContext = widget.anchorContext;
      if (metrics.desktop && anchorContext?.mounted == true) {
        final render = anchorContext!.findRenderObject();
        if (render is RenderBox && render.attached && render.hasSize) {
          final rect = render.localToGlobal(Offset.zero) & render.size;
          if (rect.overlaps(Offset.zero & media.size)) anchor = rect;
        }
      }
      return CustomSingleChildLayout(
        delegate: _PickerTaskPosition(
          bounds: bounds,
          anchor: anchor,
          bottomSheet: bottomSheet,
          width: math.min(bounds.width, preferred.width),
        ),
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            systemNavigationBarColor: Theme.of(context).colorScheme.surface,
            systemNavigationBarDividerColor: Colors.transparent,
            systemNavigationBarIconBrightness:
                Theme.of(context).brightness == Brightness.dark
                ? Brightness.light
                : Brightness.dark,
            systemNavigationBarContrastEnforced: false,
          ),
          child: SkedSurface(
            key: widget.surfaceKey,
            role: SkedSurfaceRole.content,
            elevation: 8,
            clipBehavior: Clip.antiAlias,
            borderRadius: bottomSheet
                ? const BorderRadius.vertical(top: Radius.circular(16))
                : BorderRadius.circular(12),
            child: Padding(
              padding: EdgeInsets.only(bottom: safeBottom),
              child: MediaQuery.removePadding(
                context: context,
                removeBottom: true,
                child: Builder(
                  builder: (context) =>
                      widget.builder(context, _finish, () => _ownerAvailable),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _PickerTaskPosition extends SingleChildLayoutDelegate {
  const _PickerTaskPosition({
    required this.bounds,
    required this.anchor,
    required this.width,
    required this.bottomSheet,
  });
  final Rect bounds;
  final Rect? anchor;
  final double width;
  final bool bottomSheet;
  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        minWidth: bottomSheet ? bounds.width : width,
        maxWidth: bottomSheet ? bounds.width : width,
        minHeight: 0,
        maxHeight: bounds.height,
      );
  @override
  Offset getPositionForChild(Size size, Size childSize) {
    if (bottomSheet) {
      return Offset(bounds.left, bounds.bottom - childSize.height);
    }
    var x = bounds.center.dx - childSize.width / 2;
    var y = bounds.center.dy - childSize.height / 2;
    if (anchor != null) {
      x = anchor!.left;
      y = anchor!.bottom + 6;
      if (y + childSize.height > bounds.bottom) {
        y = anchor!.top - childSize.height - 6;
      }
    }
    return Offset(
      x.clamp(
        bounds.left,
        math.max(bounds.left, bounds.right - childSize.width),
      ),
      y.clamp(
        bounds.top,
        math.max(bounds.top, bounds.bottom - childSize.height),
      ),
    );
  }

  @override
  bool shouldRelayout(_PickerTaskPosition oldDelegate) =>
      bounds != oldDelegate.bounds ||
      anchor != oldDelegate.anchor ||
      width != oldDelegate.width ||
      bottomSheet != oldDelegate.bottomSheet;
}
