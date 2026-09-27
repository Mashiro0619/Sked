import '../theme/sked_surface.dart';
import '../theme/sked_expressive_theme.dart';

import 'dart:async';
import 'dart:math' as math;

import 'package:provider/provider.dart';

import '../services/developer_ui_preferences.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import 'ui_command.dart';
import 'assistant_pane.dart';
import 'workbench_layout_policy.dart';
import '../models/workspace_context_snapshot.dart';
import '../services/desktop_window_bridge.dart';
import 'desktop_window_host.dart';
import 'workbench_chrome_metrics.dart';
import 'app_layout_tokens.dart';

export 'assistant_pane.dart' show AssistantPaneToggle, aiLayoutPreviewEnabled;
export 'workbench_layout_policy.dart';

/// Marks a task container whose host already handles height and keyboard insets.
class WorkspaceTaskScope extends InheritedWidget {
  const WorkspaceTaskScope({super.key, required super.child});
  static bool contains(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<WorkspaceTaskScope>() != null;
  @override
  bool updateShouldNotify(WorkspaceTaskScope oldWidget) => false;
}

/// Separate from DismissIntent so text fields and ModalRoute cannot consume Esc
/// merely by hiding their selection toolbar. The visible task still decides pop.
class WorkspaceTaskDismissIntent extends Intent {
  const WorkspaceTaskDismissIntent();
}

/// Owns routes independently of the pane presentation and window dimensions.
class WorkspacePaneController extends ChangeNotifier {
  final navigatorKey = GlobalKey<NavigatorState>();
  final focusScope = FocusScopeNode(debugLabel: 'Workspace inspector');
  final List<_WorkspaceTaskRoute> _tasks = [];
  bool _closing = false;
  int _activationRevision = 0;
  int get activationRevision => _activationRevision;
  final _disposedSignal = Completer<void>();
  bool _disposed = false;
  bool get isOpen => _tasks.isNotEmpty;
  bool get hasPaneTasks => _tasks.any((task) => !task.modal);
  bool get hasModalTasks => _tasks.any((task) => task.modal);
  bool get dismissOnCanvasTap => _tasks.lastOrNull?.dismissible ?? false;
  String? get selectedId => _tasks.lastOrNull?.selectionId;

  Future<T?> show<T>(
    WidgetBuilder builder, {
    String? selectionId,
    bool dismissOnCanvasTap = true,
  }) async {
    final navigator = navigatorKey.currentState;
    if (navigator == null || _disposed) return null;
    return _showRoute<T>(
      navigator,
      MaterialPageRoute<T>(
        builder: (context) => SkedSurface(
          child: WorkspaceTaskScope(
            child: UiCommandFeedbackHost(builder: builder),
          ),
        ),
      ),
      modal: false,
      selectionId: selectionId,
      dismissible: dismissOnCanvasTap,
    );
  }

  /// Tracks a phone task without mounting the desktop inspector behind it.
  /// The route is constructed by the adaptive sheet host, before it is pushed.
  Future<T?> showModal<T>(
    NavigatorState navigator,
    Route<T> route, {
    String? selectionId,
    bool dismissible = true,
  }) => _showRoute<T>(
    navigator,
    route,
    modal: true,
    selectionId: selectionId,
    dismissible: dismissible,
  );

  Future<T?> _showRoute<T>(
    NavigatorState navigator,
    Route<T> route, {
    required bool modal,
    required String? selectionId,
    required bool dismissible,
  }) async {
    if (_disposed || !navigator.mounted) return null;
    final task = _WorkspaceTaskRoute(route, modal, selectionId, dismissible);
    _tasks.add(task);
    if (!modal) _activationRevision += 1;
    notifyListeners();
    try {
      if (!modal) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_disposed && hasPaneTasks) focusScope.requestFocus();
        });
      }
      return await Future.any<T?>([
        navigator.push<T>(route),
        _disposedSignal.future.then((_) => null),
      ]);
    } finally {
      _tasks.remove(task);
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> close() async {
    if (_closing) return;
    // Never pop a picker or confirmation stacked above the requested task.
    final route = _tasks.lastOrNull?.route;
    if (route == null || !route.isCurrent) return;
    _closing = true;
    try {
      await route.navigator?.maybePop();
    } finally {
      _closing = false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    final modalRoutes = [
      for (final task in _tasks)
        if (task.modal) task.route,
    ];
    _disposedSignal.complete();
    // Disposal may occur while Navigator is building. Retire only our routes,
    // not another task or a selector which happens to be current at that time.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final route in modalRoutes) {
        if (route.isActive) route.navigator?.removeRoute(route);
      }
    });
    focusScope.dispose();
    super.dispose();
  }
}

class _WorkspaceTaskRoute {
  const _WorkspaceTaskRoute(
    this.route,
    this.modal,
    this.selectionId,
    this.dismissible,
  );
  final Route<dynamic> route;
  final bool modal, dismissible;
  final String? selectionId;
}

typedef WorkspaceLayout = WorkbenchLayoutPolicy;

/// The time canvas is never width-capped. Only task panes have a readable
/// measure. The navigator stays in one Stack slot across all window sizes.
class WorkspaceSelectionScope extends InheritedWidget {
  const WorkspaceSelectionScope({
    super.key,
    required this.selectedId,
    required super.child,
  });
  final String? selectedId;
  static String? of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<WorkspaceSelectionScope>()
      ?.selectedId;
  @override
  bool updateShouldNotify(WorkspaceSelectionScope oldWidget) =>
      selectedId != oldWidget.selectedId;
}

class WorkspaceCanvasScope extends InheritedWidget {
  const WorkspaceCanvasScope({
    super.key,
    required this.layout,
    required super.child,
    this.bodyKey,
    this.onBodyLayout,
  });
  final WorkspaceLayout layout;
  final GlobalKey? bodyKey;
  final VoidCallback? onBodyLayout;
  static WorkspaceLayout? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<WorkspaceCanvasScope>()
      ?.layout;
  @override
  bool updateShouldNotify(WorkspaceCanvasScope oldWidget) =>
      layout.resources != oldWidget.layout.resources ||
      layout.supporting != oldWidget.layout.supporting ||
      layout.dockedDetail != oldWidget.layout.dockedDetail ||
      layout.resourceWidth != oldWidget.layout.resourceWidth ||
      layout.dockedAssistant != oldWidget.layout.dockedAssistant ||
      layout.canvasObscured != oldWidget.layout.canvasObscured;
}

/// Keeps the visible toolbar reachable when a narrow overlay covers the body.
/// Also reports the actual body boundary for multi-row and large-text toolbars.
class WorkspaceCanvasBody extends StatelessWidget {
  const WorkspaceCanvasBody({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<WorkspaceCanvasScope>();
    final obscured = scope?.layout.canvasObscured ?? false;
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        scope?.onBodyLayout?.call();
        return false;
      },
      child: SizeChangedLayoutNotifier(
        child: KeyedSubtree(
          key: scope?.bodyKey,
          child: ExcludeFocus(
            excluding: obscured,
            child: ExcludeSemantics(
              excluding: obscured,
              child: IgnorePointer(ignoring: obscured, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class WorkspaceFrame extends StatefulWidget {
  const WorkspaceFrame({
    super.key,
    required this.controller,
    required this.canvas,
    required this.resources,
    this.supporting,
    this.active = true,
    this.resourcesCollapsed = false,
    this.panelDisplayMode = WorkspacePanelDisplayMode.overlay,
    this.minimumCanvas = 600,
    this.assistantController,
    this.assistantPreview = aiLayoutPreviewEnabled,
    this.contextSnapshot,
  });
  final WorkspacePaneController controller;
  final Widget canvas;
  final Widget resources;
  final Widget? supporting;
  final bool active;
  final bool resourcesCollapsed;
  final WorkspacePanelDisplayMode panelDisplayMode;
  final double minimumCanvas;
  final AssistantPaneController? assistantController;
  final bool assistantPreview;
  final WorkspaceContextSnapshot? contextSnapshot;
  @override
  State<WorkspaceFrame> createState() => _WorkspaceFrameState();
}

class _WorkspaceFrameState extends State<WorkspaceFrame> {
  late final AssistantPaneController _assistant =
      widget.assistantController ?? AssistantPaneController();
  final _assistantFocus = FocusScopeNode(debugLabel: 'Workspace assistant');
  final _workspaceFocus = FocusScopeNode(debugLabel: 'Workspace');
  final _stackKey = GlobalKey();
  final _bodyKey = GlobalKey();
  double _detailWidth = AppBreakpoints.detailPane;
  double? _bodyTop;
  bool _geometryScheduled = false;
  bool _assistantLast = false;
  bool _wasDetailOpen = false;
  bool _wasAssistantOpen = false;
  int _detailActivation = -1;
  String? _selection;
  WorkspaceLayout? _layout;
  DeveloperUiPreferences? _developerUi;
  bool? _lastAssistantPreference;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = Provider.of<DeveloperUiPreferences?>(context, listen: false);
    if (identical(next, _developerUi)) return;
    _developerUi?.removeListener(_syncAssistantPreference);
    _developerUi = next;
    _lastAssistantPreference = null;
    next?.addListener(_syncAssistantPreference);
    _syncAssistantPreference();
  }

  void _syncAssistantPreference() {
    if (!mounted) return;
    final enabled = _developerUi?.assistantVisible;
    if (enabled != null && enabled != _lastAssistantPreference) {
      _lastAssistantPreference = enabled;
      // Saving unrelated preferences must not reopen a temporarily closed pane.
      _assistant.setOpen(enabled);
    }
    setState(() {});
  }

  void _setAssistantOpen(bool visible) => _assistant.setOpen(visible);

  void _toggleAssistant() {
    if (_layout?.assistantVisible == true) {
      _setAssistantOpen(false);
    } else {
      setState(() => _assistantLast = true);
      _setAssistantOpen(true);
      _requestAssistantFocus();
    }
  }

  void _requestAssistantFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.active && _layout?.assistantVisible == true) {
        _assistantFocus.requestFocus();
      }
    });
  }

  void _scheduleBodyGeometry() {
    if (_geometryScheduled) return;
    _geometryScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _geometryScheduled = false;
      if (!mounted) return;
      final body = _bodyKey.currentContext?.findRenderObject();
      final stack = _stackKey.currentContext?.findRenderObject();
      if (body is! RenderBox ||
          stack is! RenderBox ||
          !body.attached ||
          !body.hasSize ||
          !stack.hasSize) {
        return;
      }
      final top = body
          .localToGlobal(Offset.zero, ancestor: stack)
          .dy
          .clamp(0.0, stack.size.height);
      if (_bodyTop == null || (top - _bodyTop!).abs() > .5) {
        setState(() => _bodyTop = top);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_detailChanged);
    _assistant.addListener(_assistantChanged);
  }

  void _detailChanged() {
    final controller = widget.controller;
    if (controller.hasPaneTasks &&
        (!_wasDetailOpen ||
            controller.activationRevision != _detailActivation ||
            controller.selectedId != _selection)) {
      _assistantLast = false;
    }
    _wasDetailOpen = controller.hasPaneTasks;
    _detailActivation = controller.activationRevision;
    _selection = controller.selectedId;
  }

  void _assistantChanged() {
    if (_assistant.isOpen && !_wasAssistantOpen) {
      _assistantLast = true;
      _requestAssistantFocus();
    }
    _wasAssistantOpen = _assistant.isOpen;
  }

  @override
  void didUpdateWidget(WorkspaceFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_detailChanged);
      widget.controller.addListener(_detailChanged);
      _detailActivation = -1;
      _detailChanged();
    }
  }

  @override
  void dispose() {
    _developerUi?.removeListener(_syncAssistantPreference);
    widget.controller.removeListener(_detailChanged);
    _assistant.removeListener(_assistantChanged);
    _assistantFocus.dispose();
    _workspaceFocus.dispose();
    if (widget.assistantController == null) _assistant.dispose();
    super.dispose();
  }

  Widget _detailPane(WorkspaceLayout policy) {
    final controller = widget.controller;
    final interactive = widget.active && policy.detailVisible;
    return Offstage(
      offstage: !policy.detailVisible,
      child: FocusScope(
        key: const ValueKey('workspace-inspector'),
        node: controller.focusScope,
        canRequestFocus: interactive,
        descendantsAreFocusable: interactive,
        descendantsAreTraversable: interactive,
        onFocusChange: (focused) {
          if (focused) _assistantLast = false;
        },
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) => _assistantLast = false,
          child: _PaneSurface(
            floating: !policy.dockedDetail,
            role: policy.dockedDetail
                ? SkedSurfaceRole.frame
                : SkedSurfaceRole.content,
            child: Column(
              children: [
                Padding(
                  key: const ValueKey('workspace-inspector-header'),
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: IconButton(
                      key: const ValueKey('workspace-inspector-close'),
                      tooltip: MaterialLocalizations.of(context)
                          .closeButtonTooltip,
                      icon: const Icon(Icons.close),
                      onPressed: controller.close,
                    ),
                  ),
                ),
                Expanded(
                  child: Semantics(
                    container: true,
                    explicitChildNodes: true,
                    child: Navigator(
                      key: controller.navigatorKey,
                      requestFocus: false,
                      onGenerateRoute: (_) => MaterialPageRoute<void>(
                        builder: (_) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _assistantPane(WorkspaceLayout policy, bool previewEnabled) {
    final interactive = widget.active && policy.assistantVisible;
    return Offstage(
      offstage: !policy.assistantVisible,
      child: FocusScope(
        node: _assistantFocus,
        canRequestFocus: interactive,
        descendantsAreFocusable: interactive,
        descendantsAreTraversable: interactive,
        onFocusChange: (focused) {
          if (focused) _assistantLast = true;
        },
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) => _assistantLast = true,
          child: _PaneSurface(
            floating: !policy.dockedAssistant,
            role: policy.dockedAssistant
                ? SkedSurfaceRole.frame
                : SkedSurfaceRole.content,
            child: !previewEnabled
                ? const SizedBox.shrink()
                : AssistantPreviewPane(
                    onClose: () => _setAssistantOpen(false),
                    controller: _assistant,
                    snapshot: widget.contextSnapshot?.withSelection(
                      widget.controller.selectedId,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: AnimatedBuilder(
      animation: Listenable.merge([widget.controller, _assistant]),
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) {
          final controller = widget.controller;
          final active = widget.active;
          final previewEnabled =
              _developerUi?.assistantVisible ?? widget.assistantPreview;
          final assistantOpen = previewEnabled && _assistant.isOpen;
          final metrics = WorkbenchChromeMetrics.of(context);
          final policy = WorkspaceLayout.resolve(
            constraints.maxWidth,
            metrics.textScale,
            detailOpen: controller.hasPaneTasks,
            hasSupporting: widget.supporting != null,
            assistantOpen: assistantOpen,
            assistantActive: _assistantLast,
            pointer: metrics.desktop,
            panelDisplayMode: widget.panelDisplayMode,
            minimumCanvas: widget.minimumCanvas,
            preferredDetailWidth: _detailWidth,
            preferredAssistantWidth: _assistant.width,
            // Scaffold shortens the body for the IME. Only an actual short
            // window, not typing in a pane, may compact the navigation.
            resourcesCollapsed:
                widget.resourcesCollapsed ||
                MediaQuery.sizeOf(context).height < 480,
          );
          _layout = policy;
          // A resize may hide a focused task. Do not steal focus merely because
          // an additional task became visible beside an interactive calendar.
          if (active &&
              ((!policy.detailVisible && controller.focusScope.hasFocus) ||
                  (!policy.assistantVisible && _assistantFocus.hasFocus))) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || !widget.active) return;
              if (_layout?.assistantVisible == true &&
                  (_layout?.detailVisible != true || _assistantLast)) {
                _assistantFocus.requestFocus();
              } else if (_layout?.detailVisible == true) {
                controller.focusScope.requestFocus();
              }
            });
          }
          _scheduleBodyGeometry();
          final assistantSpace = policy.dockedAssistant
              ? policy.assistantWidth + 1
              : 0.0;
          final detailSpace = policy.dockedDetail
              ? policy.detailWidth + 1
              : policy.supporting
              ? policy.supportingWidth + 1
              : 0.0;
          final captionInset = DesktopWindowBridge.instance.available
              ? metrics.toolbarHeight
              : 0.0;
          final overlayInset = math
              .max(captionInset, _bodyTop ?? metrics.toolbarHeight)
              .clamp(0.0, constraints.maxHeight);
          final detailTop = policy.dockedDetail ? captionInset : overlayInset;
          final assistantTop = policy.dockedAssistant
              ? captionInset
              : overlayInset;
          final resizeExtent = metrics.desktop ? 9.0 : 48.0;
          final motion = SkedMotionPolicy.of(context);
          // This budget uses the selected docking floor, never a task-first
          // sidebar compromise. Opening a pane always leaves the base width safe.
          final resourceBudget =
              (constraints.maxWidth -
                      policy.minimumCanvasWidth -
                      detailSpace -
                      assistantSpace -
                      1)
                  .clamp(0.0, constraints.maxWidth);
          final overlayVisible =
              (policy.detailVisible && !policy.dockedDetail) ||
              (policy.assistantVisible && !policy.dockedAssistant);
          Future<void> dismiss() async {
            if (policy.assistantVisible &&
                (!policy.detailVisible || _assistantLast)) {
              _setAssistantOpen(false);
            } else if (policy.detailVisible) {
              await controller.close();
            }
          }

          return AssistantPaneScope(
            controller: _assistant,
            enabled: previewEnabled,
            visible: policy.assistantVisible,
            onToggle: _toggleAssistant,
            child: PopScope(
              canPop: !active || (!controller.hasPaneTasks && !assistantOpen),
              onPopInvokedWithResult: (didPop, _) {
                if (!didPop && active) unawaited(dismiss());
              },
              child: Shortcuts(
                shortcuts: const {
                  SingleActivator(LogicalKeyboardKey.escape):
                      WorkspaceTaskDismissIntent(),
                },
                child: Actions(
                  actions: {
                    WorkspaceTaskDismissIntent:
                        CallbackAction<WorkspaceTaskDismissIntent>(
                          onInvoke: (_) {
                            if (active) unawaited(dismiss());
                            return null;
                          },
                        ),
                  },
                  child: FocusScope(
                    key: const ValueKey('workspace-focus'),
                    node: _workspaceFocus,
                    autofocus: active,
                    canRequestFocus: active,
                    descendantsAreFocusable: active,
                    child: Stack(
                      key: _stackKey,
                      children: [
                        Positioned.fill(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TweenAnimationBuilder<double>(
                                tween: Tween(end: policy.resourceWidth),
                                duration: motion.spatialAnimationsEnabled
                                    ? motion.effects(SkedMotionSpeed.standard)
                                    : Duration.zero,
                                curve: motion.scheme.standardCurve,
                                builder: (context, width, child) => SizedBox(
                                  key: const ValueKey(
                                    'workspace-resource-width',
                                  ),
                                  width: policy.resources
                                      ? width.clamp(0.0, resourceBudget)
                                      : 0,
                                  child: ClipRect(child: child),
                                ),
                                child: Offstage(
                                  offstage: !policy.resources,
                                  child: ExcludeFocus(
                                    excluding: !active || !policy.resources,
                                    child: WorkspaceCanvasScope(
                                      layout: policy,
                                      child: widget.resources,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: policy.resources ? 1 : 0,
                                child: const VerticalDivider(width: 1),
                              ),
                              Expanded(
                                child: ExcludeFocus(
                                  excluding: !active,
                                  child: WorkspaceCanvasScope(
                                    layout: policy,
                                    bodyKey: _bodyKey,
                                    onBodyLayout: _scheduleBodyGeometry,
                                    child: WorkspaceSelectionScope(
                                      key: const ValueKey('workspace-canvas'),
                                      selectedId: controller.selectedId,
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.translucent,
                                        onTap:
                                            active &&
                                                policy.detailVisible &&
                                                controller.dismissOnCanvasTap
                                            ? () {
                                                // Activation can change without a frame rebuild.
                                                if (!policy.assistantVisible ||
                                                    !_assistantLast) {
                                                  unawaited(controller.close());
                                                }
                                              }
                                            : null,
                                        child: widget.canvas,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: detailSpace + assistantSpace),
                            ],
                          ),
                        ),
                        if (captionInset > 0 &&
                            assistantSpace + detailSpace > metrics.captionWidth)
                          PositionedDirectional(
                            end: metrics.captionWidth,
                            top: 0,
                            width:
                                assistantSpace +
                                detailSpace -
                                metrics.captionWidth,
                            height: captionInset,
                            child: const SkedSurface(
                              key: ValueKey('workspace-caption-fill'),
                              role: SkedSurfaceRole.frame,
                              child: DesktopDragRegion(
                                child: SizedBox.expand(),
                              ),
                            ),
                          ),
                        PositionedDirectional(
                          key: const ValueKey('workspace-supporting-pane'),
                          end: 0,
                          top: captionInset,
                          bottom: 0,
                          width: policy.supportingWidth,
                          child: Offstage(
                            offstage: !policy.supporting,
                            child: ExcludeFocus(
                              excluding:
                                  !active ||
                                  !policy.supporting ||
                                  overlayVisible,
                              child: ExcludeSemantics(
                                excluding: overlayVisible,
                                child: _PaneSurface(
                                  child:
                                      widget.supporting ??
                                      const SizedBox.shrink(),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // These keyed slots never change identity on a resize,
                        // mode change or activation of a different foreground task.
                        PositionedDirectional(
                          key: const ValueKey('workspace-detail-pane'),
                          end: policy.dockedDetail ? assistantSpace : 0,
                          top: detailTop,
                          bottom: 0,
                          width: policy.detailWidth,
                          child: _detailPane(policy),
                        ),
                        PositionedDirectional(
                          key: const ValueKey('workspace-assistant-pane'),
                          end: 0,
                          top: assistantTop,
                          bottom: 0,
                          width: policy.assistantWidth,
                          child: _assistantPane(policy, previewEnabled),
                        ),
                        if (policy.detailVisible)
                          PositionedDirectional(
                            end:
                                (policy.dockedDetail ? assistantSpace : 0) +
                                policy.detailWidth -
                                resizeExtent,
                            top: detailTop,
                            bottom: metrics.desktop ? 0 : null,
                            height: metrics.desktop ? null : 48,
                            width: resizeExtent,
                            child: _PaneResizeHandle(
                              key: const ValueKey('workspace-detail-resize'),
                              onActivate: () => _assistantLast = false,
                              onResize: (dx) => setState(
                                () => _detailWidth =
                                    (_detailWidth - dx / metrics.textScale)
                                        .clamp(320, 600),
                              ),
                            ),
                          ),
                        if (policy.assistantVisible)
                          PositionedDirectional(
                            end: policy.assistantWidth - resizeExtent,
                            top: assistantTop,
                            bottom: metrics.desktop ? 0 : null,
                            height: metrics.desktop ? null : 48,
                            width: resizeExtent,
                            child: _PaneResizeHandle(
                              key: const ValueKey('workspace-assistant-resize'),
                              onActivate: () => _assistantLast = true,
                              onResize: (dx) => _assistant.resize(
                                _assistant.width - dx / metrics.textScale,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _PaneSurface extends StatelessWidget {
  const _PaneSurface({
    required this.child,
    this.role = SkedSurfaceRole.frame,
    this.floating = false,
  });
  final Widget child;
  final SkedSurfaceRole role;
  final bool floating;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      boxShadow: floating
          ? [
              BoxShadow(
                color: Theme.of(context).colorScheme.shadow
                    .withValues(alpha: .14),
                blurRadius: 16,
                offset: const Offset(-4, 0),
              ),
            ]
          : null,
      border: BorderDirectional(
        start: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
    ),
    child: SkedSurface(role: role, child: child),
  );
}

class _PaneResizeHandle extends StatelessWidget {
  const _PaneResizeHandle({
    super.key,
    required this.onResize,
    required this.onActivate,
  });
  final ValueChanged<double> onResize;
  final VoidCallback onActivate;
  void _resize(double delta) {
    onActivate();
    onResize(delta);
  }

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    explicitChildNodes: true,
    label: AppLocalizations.of(context).resizePanel,
    onIncrease: () => _resize(-24),
    onDecrease: () => _resize(24),
    child: Focus(
      onFocusChange: (focused) {
        if (focused) onActivate();
      },
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          _resize(-24);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          _resize(24);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragDown: (_) => onActivate(),
          onHorizontalDragUpdate: (details) => _resize(
            Directionality.of(context) == TextDirection.rtl
                ? -details.delta.dx
                : details.delta.dx,
          ),
          child: WorkbenchLayoutPolicy.pointerLayout(context)
              ? null
              : const Center(child: Icon(Icons.drag_indicator, size: 18)),
        ),
      ),
    ),
  );
}
