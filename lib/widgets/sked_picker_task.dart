import 'sked_task_route.dart';
import 'sked_task_session.dart';
import '../theme/sked_surface.dart';

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/app_mode.dart';
import '../providers/timetable_provider.dart';
import 'workbench_chrome_metrics.dart';
import 'sked_floating_surface.dart';

/// Only compact touch windows opt into a task-specific presentation.
/// Desktop anchoring and wide-tablet dialogs retain their existing behavior.
enum SkedPickerCompactPresentation { bottomSheet, centered, anchored }

typedef SkedPickerTaskBuilder<T> = Widget Function(
  BuildContext context,
  ValueChanged<T?> finish,
  bool Function() isSessionCurrent,
);

/// A single, adaptive picker route with owner/session validity and focus restore.
/// Content owns its draft and validation; resize and IME changes only reposition it.
/// Opt into [waitForTransitionComplete] when the caller must keep its re-entry
/// guard until the exiting route is removed, not just until its result is popped.
Future<T?> showSkedPickerTask<T>({
  required BuildContext context,
  required String routeName,
  required Size Function(BuildContext) preferredSize,
  required SkedPickerTaskBuilder<T> builder,
  BuildContext? anchorContext,
  SkedFloatingPlacement placement = SkedFloatingPlacement.automatic,
  AppMode? workspace,
  Key? surfaceKey,
  bool Function()? isSessionCurrent,
  SkedTaskSession? session,
  bool waitForTransitionComplete = false,
  SkedPickerCompactPresentation compactPresentation =
      SkedPickerCompactPresentation.bottomSheet,
}) async {
  final parent = ModalRoute.of(context);
  // Capture while the trigger is active. A closing/reflowing parent can leave
  // its Element mounted but inactive; never query that Element during layout.
  final anchorRenderObject = anchorContext?.mounted == true
      ? anchorContext!.findRenderObject()
      : null;
  final focus =
      skedFloatingAnchorFocus(anchorContext) ??
      FocusManager.instance.primaryFocus;
  final provider = Provider.of<TimetableProvider?>(context, listen: false);
  if (workspace != null && provider?.isWorkspaceEnabled(workspace) == false) {
    return null;
  }
  final taskSession = SkedTaskSession(
    provider: provider,
    workspace: workspace,
    parent: session ?? SkedTaskSessionScope.maybeOf(context)?.session,
    ownerRoute: parent,
    isOwnerActive: () => context.mounted,
    isTargetCurrent: isSessionCurrent,
  );
  bool sessionAvailable() => taskSession.isCurrent;
  if (!sessionAvailable()) {
    taskSession.dispose();
    return null;
  }
  final navigator = Navigator.of(context, rootNavigator: true);
  final themes = InheritedTheme.capture(from: context, to: navigator.context);
  final route = _PickerTaskRoute<T>(
    compactPresentation: compactPresentation,
    settings: RouteSettings(name: routeName),
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    transitionDuration: const Duration(milliseconds: 120),
    traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
    pageBuilder: (routeContext, animation, secondaryAnimation) => themes.wrap(
      SkedTaskRouteGuard(
        parent: taskSession,
        child: Builder(
          builder: (guardContext) => _PickerTaskHost<T>(
            builder: builder,
            preferredSize: preferredSize,
            compactPresentation: compactPresentation,
            surfaceKey: surfaceKey,
            session: SkedTaskSessionScope.maybeOf(guardContext)!.session,
            anchorBox: anchorRenderObject is RenderBox
                ? anchorRenderObject
                : null,
            placement: placement,
          ),
        ),
      ),
    ),
  );
  T? result;
  try {
    result = await navigator.push(route);
  } catch (_) {
    taskSession.dispose();
    rethrow;
  }
  if (waitForTransitionComplete) await route.completed;
  final current =
      context.mounted && sessionAvailable() && (parent?.isActive ?? true);
  unawaited(
    route.completed.then((_) async {
      try {
        if (waitForTransitionComplete) await WidgetsBinding.instance.endOfFrame;
        if (current &&
            context.mounted &&
            sessionAvailable() &&
            (parent?.isCurrent ?? true) &&
            focus?.context?.mounted == true &&
            focus!.canRequestFocus) {
          focus.requestFocus();
        }
      } finally {
        taskSession.dispose();
      }
    }),
  );
  return current ? result : null;
}

/// The barrier follows the same window policy as the content without replacing
/// the route on resize. Navigator rebuilds it when MediaQuery/Theme changes.
class _PickerTaskRoute<T> extends RawDialogRoute<T> {
  _PickerTaskRoute({
    required this.compactPresentation,
    required super.settings,
    required super.barrierDismissible,
    required super.barrierLabel,
    required super.transitionDuration,
    required super.traversalEdgeBehavior,
    required super.pageBuilder,
  });
  final SkedPickerCompactPresentation compactPresentation;

  @override
  Color get barrierColor {
    final context = navigator!.context;
    if (WorkbenchChromeMetrics.of(context).desktop) return Colors.transparent;
    if (!WorkbenchChromeMetrics.compactTouch(context)) return Colors.black54;
    return switch (compactPresentation) {
      SkedPickerCompactPresentation.bottomSheet => Colors.black54,
      SkedPickerCompactPresentation.centered => const Color(0x3D000000),
      SkedPickerCompactPresentation.anchored => Colors.transparent,
    };
  }
}

class _PickerTaskHost<T> extends StatefulWidget {
  const _PickerTaskHost({
    required this.builder,
    required this.preferredSize,
    required this.compactPresentation,
    required this.surfaceKey,
    required this.session,
    required this.anchorBox,
    required this.placement,
  });
  final SkedPickerTaskBuilder<T> builder;
  final Size Function(BuildContext) preferredSize;
  final SkedPickerCompactPresentation compactPresentation;
  final Key? surfaceKey;
  final SkedTaskSession session;
  final RenderBox? anchorBox;
  final SkedFloatingPlacement placement;

  @override
  State<_PickerTaskHost<T>> createState() => _PickerTaskHostState<T>();
}

class _PickerTaskHostState<T> extends State<_PickerTaskHost<T>> {
  bool _finished = false;
  Offset? _manualPosition, _lastPosition;
  Size _panelSize = Size.zero;
  Rect _bounds = Rect.zero;
  void _drag(Offset delta) {
    if (!mounted || _finished || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    setState(
      () => _manualPosition = boundSkedFloatingPosition(
        boundSkedFloatingPosition(
              _manualPosition ?? _lastPosition ?? Offset.zero,
              _panelSize,
              _bounds,
            ) +
            delta,
        _panelSize,
        _bounds,
      ),
    );
  }

  bool get _ownerAvailable => widget.session.isCurrent;

  void _finish(T? value) {
    if (!mounted || _finished) return;
    _finished = true;
    final result = _ownerAvailable ? value : null;
    completeSkedTaskRoute(context, result);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final media = MediaQuery.of(context);
      final metrics = WorkbenchChromeMetrics.of(context);
      final preferred = widget.preferredSize(context);
      final top =
          media.padding.top + (metrics.desktop ? metrics.toolbarHeight : 0);
      final compact = WorkbenchChromeMetrics.compactTouch(
        context,
        width: constraints.maxWidth,
      );
      final presentation = widget.compactPresentation;
      final bottomSheet =
          compact && presentation == SkedPickerCompactPresentation.bottomSheet;
      final compactAnchor =
          compact && presentation == SkedPickerCompactPresentation.anchored;
      // A bottom task paints its own navigation-bar safe area. With an IME it
      // ends above the keyboard instead; never reserve the same inset twice.
      final safeBottom = bottomSheet && media.viewInsets.bottom == 0
          ? media.viewPadding.bottom
          : 0.0;
      final bottom = bottomSheet
          ? media.viewInsets.bottom
          : math.max(media.padding.bottom, media.viewInsets.bottom);
      final margin = bottomSheet
          ? 0.0
          : compact && constraints.maxWidth > 336
          ? 12.0
          : 8.0;
      final bounds = Rect.fromLTRB(
        media.padding.left + margin,
        top + margin,
        constraints.maxWidth - media.padding.right - margin,
        math.max(top + margin, constraints.maxHeight - bottom - margin),
      );
      _bounds = bounds;
      Rect? anchor;
      if (metrics.desktop || compactAnchor) {
        final render = widget.anchorBox;
        if (render is RenderBox && render.attached && render.hasSize) {
          final rect = render.localToGlobal(Offset.zero) & render.size;
          if (rect.overlaps(Offset.zero & media.size)) anchor = rect;
          if (compactAnchor &&
              (!rect.overlaps(bounds) ||
                  math.max(
                        rect.top - bounds.top - 6,
                        bounds.bottom - rect.bottom - 6,
                      ) <
                      metrics.iconTarget + 48)) {
            anchor = null;
          }
        }
      }
      final content = Padding(
        padding: EdgeInsets.only(bottom: safeBottom),
        child: MediaQuery.removePadding(
          context: context,
          removeBottom: true,
          child: Builder(
            builder: (context) =>
                widget.builder(context, _finish, () => _ownerAvailable),
          ),
        ),
      );
      return CustomSingleChildLayout(
        delegate: _PickerTaskPosition(
          bounds: bounds,
          anchor: anchor,
          placement: widget.placement,
          bottomSheet: bottomSheet,
          constrainToAnchor: compactAnchor,
          desktop: metrics.desktop,
          rtl: Directionality.of(context) == TextDirection.rtl,
          width: math.min(bounds.width, preferred.width),
          manualPosition: metrics.desktop
              ? _manualPosition ?? (anchor == null ? _lastPosition : null)
              : null,
          onPosition: (position, size) {
            _lastPosition = position;
            _panelSize = size;
          },
        ),
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: compact && !bottomSheet
              ? const SystemUiOverlayStyle()
              : SystemUiOverlayStyle(
                  systemNavigationBarColor: Theme.of(context)
                      .colorScheme
                      .surface,
                  systemNavigationBarDividerColor: Colors.transparent,
                  systemNavigationBarIconBrightness:
                      Theme.of(context).brightness == Brightness.dark
                      ? Brightness.light
                      : Brightness.dark,
                  systemNavigationBarContrastEnforced: false,
                ),
          child: metrics.desktop
              ? SkedFloatingSurface(
                  key: widget.surfaceKey,
                  child: SkedFloatingDragScope(onDrag: _drag, child: content),
                )
              : SkedSurface(
                  key: widget.surfaceKey,
                  role: SkedSurfaceRole.content,
                  elevation: 8,
                  clipBehavior: Clip.antiAlias,
                  borderRadius: bottomSheet
                      ? const BorderRadius.vertical(top: Radius.circular(16))
                      : BorderRadius.circular(
                          compact ? (compactAnchor ? 16 : 24) : 12,
                        ),
                  child: content,
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
    required this.placement,
    required this.width,
    required this.bottomSheet,
    required this.constrainToAnchor,
    required this.desktop,
    required this.rtl,
    required this.manualPosition,
    required this.onPosition,
  });
  final Rect bounds;
  final Offset? manualPosition;
  final void Function(Offset, Size) onPosition;
  final Rect? anchor;
  final SkedFloatingPlacement placement;
  final double width;
  final bool bottomSheet, constrainToAnchor, desktop, rtl;
  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        minWidth: bottomSheet ? bounds.width : width,
        maxWidth: bottomSheet ? bounds.width : width,
        minHeight: 0,
        maxHeight: desktop
            ? skedFloatingHeightLimit(bounds, anchor, width)
            : constrainToAnchor && anchor != null
            ? math
                  .max(
                    anchor!.top - bounds.top - 6,
                    bounds.bottom - anchor!.bottom - 6,
                  )
                  .clamp(0, bounds.height)
            : bounds.height,
      );
  @override
  Offset getPositionForChild(Size size, Size childSize) {
    if (bottomSheet) {
      return Offset(bounds.left, bounds.bottom - childSize.height);
    }
    if (desktop) {
      final position = manualPosition != null
          ? boundSkedFloatingPosition(manualPosition!, childSize, bounds)
          : positionSkedFloatingPanel(
              bounds: bounds,
              size: childSize,
              anchor: anchor,
              rtl: rtl,
              placement: placement,
            );
      onPosition(position, childSize);
      return position;
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
      placement != oldDelegate.placement ||
      manualPosition != oldDelegate.manualPosition ||
      bounds != oldDelegate.bounds ||
      anchor != oldDelegate.anchor ||
      width != oldDelegate.width ||
      bottomSheet != oldDelegate.bottomSheet ||
      constrainToAnchor != oldDelegate.constrainToAnchor ||
      desktop != oldDelegate.desktop ||
      rtl != oldDelegate.rtl;
}
