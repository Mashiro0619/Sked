import 'sked_task_session.dart';
import 'workspace_editor.dart';
export 'workspace_editor.dart' show WorkspaceEditorConfiguration;
export 'sked_task_actions.dart' show SkedEditorActions, SkedActionArea;
import '../theme/sked_surface.dart';

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/app_mode.dart';
import '../providers/timetable_provider.dart';
import '../services/desktop_layout_preferences.dart';
import 'workbench_chrome_metrics.dart';
import 'sked_guarded_bottom_sheet_route.dart';
import 'sked_task_actions.dart';
import 'sked_task_body.dart';
import 'sked_task_header.dart';

import '../theme/app_motion.dart';
import '../theme/sked_expressive_theme.dart';
import 'ui_command.dart';
import 'workspace_frame.dart';

const double appSheetWidthCompact = 560;
const double appSheetWidthMedium = 680;
const double appSheetWidthExpanded = 920;

Future<T?> showAppModalSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double maxWidth = appSheetWidthMedium,
  bool isDismissible = true,
  bool enableDrag = true,
  bool showDragHandle = false,
  bool useRootNavigator = false,
  bool useSafeArea = false,
  RouteSettings? routeSettings,
  WorkspacePaneController? workspacePane,
  WorkspacePanePresentation panePresentation =
      WorkspacePanePresentation.standard,
  WorkspaceEditorConfiguration? editor,
  DesktopLayoutRegion? layoutKey,
  BuildContext? anchorContext,
  Rect? anchorRect,
  String? selectionId,
  AppMode? workspace,
  bool Function()? isSessionCurrent,
  SkedTaskSession? session,
}) async {
  final compact = WorkbenchChromeMetrics.compactTouch(context);
  // An editor opened from a phone details task must stay above that modal
  // even if the window was widened while the details were open.
  final bottomTask = compact || workspacePane?.hasModalTasks == true;
  final provider = Provider.of<TimetableProvider?>(context, listen: false);
  final ownerRoute = ModalRoute.of(context);
  final focus = FocusManager.instance.primaryFocus;
  final taskSession = SkedTaskSession(
    provider: provider,
    workspace: workspace,
    parent: session ?? SkedTaskSessionScope.maybeOf(context)?.session,
    ownerRoute: ownerRoute,
    isOwnerActive: () => context.mounted,
    isTargetCurrent: isSessionCurrent,
  );
  bool isCurrent() => taskSession.isCurrent;
  if (!isCurrent()) {
    taskSession.dispose();
    return null;
  }
  Widget content(BuildContext sheetContext) => SkedTaskRouteGuard(
    parent: taskSession,
    child: Builder(builder: builder),
  );
  if (workspacePane != null && !bottomTask) {
    try {
      final result = await workspacePane.show<T>(
        content,
        presentation: editor == null
            ? panePresentation
            : WorkspacePanePresentation.editor,
        editor: editor,
        layoutKey: layoutKey,
        anchorContext: anchorContext,
        anchorRect: anchorRect,
        selectionId: selectionId,
        dismissOnCanvasTap: isDismissible,
      );
      if (editor != null &&
          isCurrent() &&
          (ownerRoute?.isCurrent ?? true) &&
          focus?.context?.mounted == true &&
          focus!.canRequestFocus &&
          (workspacePane.focusScope.hasFocus ||
              FocusManager.instance.primaryFocus?.context?.mounted != true)) {
        focus.requestFocus();
      }
      return isCurrent() ? result : null;
    } finally {
      taskSession.dispose();
    }
  }

  final navigator = Navigator.of(
    context,
    rootNavigator: useRootNavigator || workspacePane != null,
  );
  final l = MaterialLocalizations.of(context);
  final route = SkedGuardedBottomSheetRoute<T>(
    capturedThemes: InheritedTheme.capture(
      from: context,
      to: navigator.context,
    ),
    barrierLabel: l.scrimLabel,
    barrierOnTapHint: l.scrimOnTapHint(l.bottomSheetLabel),
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    showDragHandle: showDragHandle,
    useSafeArea: bottomTask || useSafeArea,
    settings: routeSettings,
    constraints: BoxConstraints(maxWidth: maxWidth),
    modalBarrierColor: Theme.of(context).bottomSheetTheme.modalBarrierColor,
    clipBehavior: Clip.antiAlias,
    sheetAnimationStyle: SkedMotionPolicy.of(context)
        .routeStyle(AppMotion.sheetAnimationStyle),
    builder: (sheetContext) {
      final media = MediaQuery.of(sheetContext);
      final colors = Theme.of(sheetContext).colorScheme;
      final task = _AppBottomSheetScope(
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            systemNavigationBarColor: colors.surface,
            systemNavigationBarDividerColor: Colors.transparent,
            systemNavigationBarIconBrightness:
                colors.brightness == Brightness.dark
                ? Brightness.light
                : Brightness.dark,
            systemNavigationBarContrastEnforced: false,
          ),
          // Keep IME handling outside the content: fractional editor heights
          // refer to the actual remaining area, not the obscured whole screen.
          child: Padding(
            padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
            child: SkedSurface(
              key: const ValueKey('app-bottom-task-surface'),
              role: SkedSurfaceRole.content,
              child: UiCommandFeedbackHost(builder: content),
            ),
          ),
        ),
      );
      return provider == null
          ? task
          : ChangeNotifierProvider<TimetableProvider>.value(
              value: provider,
              child: task,
            );
    },
  );
  T? result;
  try {
    result = await (workspacePane == null
        ? navigator.push<T>(route)
        : workspacePane.showModal<T>(
            navigator,
            route,
            selectionId: selectionId,
            dismissible: isDismissible,
          ));
  } catch (_) {
    taskSession.dispose();
    rethrow;
  }
  unawaited(
    route.completed.then((_) {
      try {
        if (isCurrent() &&
            (ownerRoute?.isCurrent ?? true) &&
            focus?.context?.mounted == true &&
            focus!.canRequestFocus) {
          focus.requestFocus();
        }
      } finally {
        taskSession.dispose();
      }
    }),
  );
  return isCurrent() ? result : null;
}

class _AppBottomSheetScope extends InheritedWidget {
  const _AppBottomSheetScope({required super.child});
  static bool contains(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_AppBottomSheetScope>() !=
      null;
  @override
  bool updateShouldNotify(_AppBottomSheetScope oldWidget) => false;
}

class AppSheetScaffold extends StatelessWidget {
  const AppSheetScaffold({
    super.key,
    required this.title,
    required this.child,
    this.leading,
    this.onClose,
    this.closeEnabled = true,
    this.actions = const [],
    this.footer,
    this.subtitle,
    this.heightFactor,
    this.contentPadding = const EdgeInsets.fromLTRB(16, 0, 16, 12),
    this.actionPadding,
    this.busy = false,
  }) : editorActions = null,
       compact = true,
       _editor = false;

  /// Editors share one height, title, field spacing and action contract.
  /// Short forms opt into natural height; long forms retain a scroll viewport.
  const AppSheetScaffold.editor({
    super.key,
    required this.title,
    required this.child,
    required this.onClose,
    required this.editorActions,
    this.closeEnabled = true,
    this.busy = false,
    this.compact = false,
    this.subtitle,
    this.footer,
    this.contentPadding = const EdgeInsets.fromLTRB(16, 0, 16, 12),
    this.actionPadding,
  }) : actions = const [],
       leading = null,
       heightFactor = null,
       _editor = true;

  final Widget title, child;
  final Widget? subtitle, leading;
  final VoidCallback? onClose;
  final bool closeEnabled, busy, compact, _editor;
  final List<Widget> actions;
  final SkedEditorActions? editorActions;

  /// Custom commands, e.g. importing as new/replacing a timetable, retain the
  /// same fixed position and are forwarded intact to desktop hosts.
  final Widget? footer;
  final double? heightFactor;
  final EdgeInsetsGeometry contentPadding;
  final EdgeInsetsGeometry? actionPadding;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final desktop = WorkbenchChromeMetrics.of(context).desktop;
    final editor = WorkspaceEditorScope.maybeOf(context);
    final resolvedActions = editorActions?.trailing(context) ?? actions;
    final resolvedLeading = editorActions?.leading(context) ?? leading;
    final status = busy ? const UiCommandBusyIndicator(busy: true) : null;
    if ((editor?.enabled == true || (_editor && desktop)) && onClose != null) {
      return WorkspaceEditorScaffold(
        title: title,
        subtitle: subtitle,
        onClose: onClose!,
        closeEnabled: closeEnabled,
        actions: resolvedActions,
        leading: resolvedLeading,
        footer: footer,
        status: status,
        child: child,
      );
    }
    final inTaskPane = WorkspaceTaskScope.contains(context);
    final keyboardHandled =
        inTaskPane || _AppBottomSheetScope.contains(context);
    final resolvedPadding = contentPadding.resolve(Directionality.of(context));
    // Outlined touch inputs paint their floating label above the border. Keep
    // that first label inside the independent body viewport, including at 2x.
    final bodyPadding = _editor && !desktop
        ? resolvedPadding.copyWith(
            top: math.max(
              resolvedPadding.top,
              8 * MediaQuery.textScalerOf(context).scale(14) / 14,
            ),
          )
        : contentPadding;
    final body = SafeArea(
      top: false,
      child: SkedTaskBody(
        status: status,
        fillHeight: inTaskPane,
        header: SkedTaskHeader(
          key: const ValueKey('app-sheet-header'),
          title: title,
          subtitle: subtitle,
        ),
        bodyKey: const PageStorageKey('app-sheet-body'),
        headerPadding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        contentPadding: bodyPadding,
        footerPadding:
            actionPadding ??
            EdgeInsets.fromLTRB(
              16,
              8,
              16,
              (keyboardHandled ? 0 : media.viewInsets.bottom) + 16,
            ),
        footer:
            footer != null ||
                resolvedLeading != null ||
                resolvedActions.isNotEmpty
            ? KeyedSubtree(
                key: const ValueKey('app-sheet-actions'),
                child:
                    footer ??
                    SkedActionArea(
                      leading: resolvedLeading,
                      actions: resolvedActions,
                    ),
              )
            : null,
        child: child,
      ),
    );
    final factor = _editor && !compact
        ? media.viewInsets.bottom > 0
              ? 1.0
              : media.size.height < 700
              ? .96
              : .72
        : heightFactor;
    if (inTaskPane || factor == null) return body;
    return FractionallySizedBox(heightFactor: factor, child: body);
  }
}
