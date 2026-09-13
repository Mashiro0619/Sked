import '../theme/sked_surface.dart';

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/app_mode.dart';
import '../providers/timetable_provider.dart';
import 'workbench_chrome_metrics.dart';

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
  bool useRootNavigator = false,
  bool useSafeArea = false,
  RouteSettings? routeSettings,
  WorkspacePaneController? workspacePane,
  String? selectionId,
  AppMode? workspace,
  bool Function()? isSessionCurrent,
}) async {
  final compact = WorkbenchChromeMetrics.compactTouch(context);
  // An editor opened from a phone details task must stay above that modal
  // even if the window was widened while the details were open.
  final bottomTask = compact || workspacePane?.hasModalTasks == true;
  final provider = Provider.of<TimetableProvider?>(context, listen: false);
  final ownerRoute = ModalRoute.of(context);
  final dataSession = provider?.dataSessionToken;
  final boundary = provider?.appData.workspaceReminderNotBefore[workspace];
  final focus = FocusManager.instance.primaryFocus;
  var invalidated = false;
  bool isCurrent() {
    invalidated =
        invalidated ||
        !context.mounted ||
        !(ownerRoute?.isActive ?? true) ||
        !identical(dataSession, provider?.dataSessionToken) ||
        boundary != provider?.appData.workspaceReminderNotBefore[workspace] ||
        (workspace != null &&
            provider?.isWorkspaceEnabled(workspace) == false) ||
        isSessionCurrent?.call() == false;
    return !invalidated;
  }

  if (!isCurrent()) return null;
  Widget content(BuildContext sheetContext) => _AppTaskSession(
    provider: provider,
    ownerRoute: ownerRoute,
    isCurrent: isCurrent,
    child: Builder(builder: builder),
  );
  if (workspacePane != null && !bottomTask) {
    return workspacePane.show<T>(
      content,
      selectionId: selectionId,
      dismissOnCanvasTap: isDismissible,
    );
  }

  final navigator = Navigator.of(
    context,
    rootNavigator: useRootNavigator || workspacePane != null,
  );
  final l = MaterialLocalizations.of(context);
  final route = ModalBottomSheetRoute<T>(
    capturedThemes: InheritedTheme.capture(
      from: context,
      to: navigator.context,
    ),
    barrierLabel: l.scrimLabel,
    barrierOnTapHint: l.scrimOnTapHint(l.bottomSheetLabel),
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    showDragHandle: enableDrag,
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
  final result = await (workspacePane == null
      ? navigator.push<T>(route)
      : workspacePane.showModal<T>(
          navigator,
          route,
          selectionId: selectionId,
          dismissible: isDismissible,
        ));
  unawaited(
    route.completed.then((_) {
      if (isCurrent() &&
          (ownerRoute?.isCurrent ?? true) &&
          focus?.context?.mounted == true &&
          focus!.canRequestFocus) {
        focus.requestFocus();
      }
    }),
  );
  return isCurrent() ? result : null;
}

/// A modal route can outlive its home widget or its backing data. Invalidation
/// retires this exact route; a nested date/time picker observes its owner close.
class _AppTaskSession extends StatefulWidget {
  const _AppTaskSession({
    required this.provider,
    required this.ownerRoute,
    required this.isCurrent,
    required this.child,
  });
  final TimetableProvider? provider;
  final ModalRoute<dynamic>? ownerRoute;
  final bool Function() isCurrent;
  final Widget child;
  @override
  State<_AppTaskSession> createState() => _AppTaskSessionState();
}

class _AppTaskSessionState extends State<_AppTaskSession> {
  bool _retiring = false;
  @override
  void initState() {
    super.initState();
    widget.provider?.addListener(_check);
    final weak = WeakReference(this);
    unawaited(widget.ownerRoute?.completed.then((_) => weak.target?._check()));
    _check();
  }

  void _check() {
    if (!mounted || _retiring || widget.isCurrent()) return;
    _retiring = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      if (route?.isActive == true) route!.navigator?.removeRoute(route);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    widget.provider?.removeListener(_check);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _check();
    return ExcludeFocus(
      excluding: _retiring,
      child: AbsorbPointer(absorbing: _retiring, child: widget.child),
    );
  }
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
    this.actions = const [],
    this.footer,
    this.subtitle,
    this.heightFactor,
    this.contentPadding = const EdgeInsets.fromLTRB(16, 0, 16, 12),
    this.actionPadding,
  });

  final Widget title;
  final Widget? subtitle;
  final Widget child;
  final Widget? leading;
  final List<Widget> actions;

  /// A custom fixed footer that replaces the standard leading/actions layout.
  ///
  /// The footer uses the same safe-area and keyboard-aware placement as the
  /// standard action area, so callers only provide its responsive contents.
  /// When it is present, [leading] and [actions] are ignored.
  final Widget? footer;
  final double? heightFactor;
  final EdgeInsetsGeometry contentPadding;
  final EdgeInsetsGeometry? actionPadding;

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final inTaskPane = WorkspaceTaskScope.contains(context);
    final keyboardHandled =
        inTaskPane || _AppBottomSheetScope.contains(context);
    final body = SafeArea(
      top: false,
      child: Column(
        mainAxisSize: inTaskPane ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            fit: inTaskPane ? FlexFit.tight : FlexFit.loose,
            child: SingleChildScrollView(
              padding: contentPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  DefaultTextStyle.merge(
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                    child: title,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    DefaultTextStyle.merge(
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      child: subtitle!,
                    ),
                  ],
                  const SizedBox(height: 16),
                  child,
                ],
              ),
            ),
          ),
          Padding(
            padding:
                actionPadding ??
                // The hosting Scaffold already removes the IME from a task
                // pane's constraints. Only modal sheets need a second inset.
                EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  (keyboardHandled ? 0 : viewInsets.bottom) + 16,
                ),
            child:
                footer ?? _AppSheetActions(leading: leading, actions: actions),
          ),
        ],
      ),
    );

    if (inTaskPane || heightFactor == null) {
      return body;
    }
    return FractionallySizedBox(heightFactor: heightFactor, child: body);
  }
}

class _AppSheetActions extends StatelessWidget {
  const _AppSheetActions({required this.actions, this.leading});

  final Widget? leading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final actionWrap = Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: actions,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (leading != null && constraints.maxWidth >= 420) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              leading!,
              const Spacer(),
              Flexible(child: actionWrap),
            ],
          );
        }
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [?leading, ...actions],
        );
      },
    );
  }
}
