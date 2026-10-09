import 'update_prompt_scope.dart';
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
import 'workbench_chrome_metrics.dart';
import 'app_layout_tokens.dart';
import 'workspace_view_panel.dart';
import 'sked_floating_surface.dart';
import 'sked_floating_position_controller.dart';
import 'workspace_editor.dart';
import 'desktop_window_drag_guard.dart';

export 'workspace_view_panel.dart'
    show WorkspacePanePresentation, WorkspaceViewPanel;

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
  final List<bool Function()> _priorityDismissHandlers = [];

  /// True means a secondary task consumed the request, including guard refusal.
  VoidCallback registerPriorityDismiss(bool Function() handler) {
    _priorityDismissHandlers.add(handler);
    return () => _priorityDismissHandlers.remove(handler);
  }

  bool dismissPriorityTask() {
    for (final handler in _priorityDismissHandlers.reversed.toList()) {
      if (handler()) return true;
    }
    return false;
  }

  Rect? _lastPointerAnchor;
  DateTime? _pointerAt;
  set lastPointerAnchor(Rect value) {
    _lastPointerAnchor = value;
    _pointerAt = DateTime.now();
  }

  Rect? get lastPointerAnchor =>
      _pointerAt != null &&
          DateTime.now().difference(_pointerAt!) < const Duration(seconds: 1)
      ? _lastPointerAnchor
      : null;
  WorkspaceEditorConfiguration? editorEntry;
  WorkspaceEditorConfiguration takeEditorEntry() {
    final entry =
        editorEntry ??
        WorkspaceEditorConfiguration(anchorRect: lastPointerAnchor);
    editorEntry = null;
    _lastPointerAnchor = null;
    return entry;
  }

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
  bool get hasViewPanel =>
      _tasks.lastOrNull?.presentation == WorkspacePanePresentation.view;
  bool get hasEditorPanel =>
      _tasks.lastOrNull?.presentation == WorkspacePanePresentation.editor;
  bool get floatingEditor => hasEditorPanel && _editorFloating;
  bool _editorFloating = false;
  void _setEditorFloating(bool value) {
    if (_editorFloating == value) return;
    _editorFloating = value;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) notifyListeners();
    });
  }

  double? get viewContentHeight => _tasks.lastOrNull?.contentHeight;

  void _reportContentHeight(Route<dynamic> route, double height) {
    if (_disposed) return;
    final task = _tasks
        .where((task) => identical(task.route, route))
        .firstOrNull;
    if (task == null || task.contentHeight == height) return;
    task.contentHeight = height;
    if (identical(task, _tasks.lastOrNull)) notifyListeners();
  }

  Future<T?> show<T>(
    WidgetBuilder builder, {
    String? selectionId,
    bool dismissOnCanvasTap = true,
    WorkspacePanePresentation presentation = WorkspacePanePresentation.standard,
    WorkspaceEditorConfiguration? editor,
    BuildContext? anchorContext,
    Rect? anchorRect,
  }) async {
    final navigator = navigatorKey.currentState;
    if (navigator == null || _disposed) return null;
    final movingHost = navigator.overlay?.context.findRenderObject();
    late final MaterialPageRoute<T> route;
    route = MaterialPageRoute<T>(
      builder: (context) => WorkspaceTaskScope(
        child: WorkspaceViewTaskScope(
          enabled:
              presentation == WorkspacePanePresentation.view &&
              WorkbenchChromeMetrics.of(context).desktop,
          onClose: close,
          onContentHeight: (height) => _reportContentHeight(route, height),
          child: SkedSurface(child: UiCommandFeedbackHost(builder: builder)),
        ),
      ),
    );
    final viewAnchor = presentation == WorkspacePanePresentation.view
        ? WorkspaceEditorConfiguration(
            anchorContext: anchorContext,
            anchorRect: anchorRect,
          )
        : null;
    if (viewAnchor != null) _lastPointerAnchor = null;
    return _showRoute<T>(
      navigator,
      route,
      presentation: presentation,
      editor: editor?.snapshotIfInside(movingHost),
      viewAnchor: viewAnchor?.snapshotIfInside(movingHost),
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
    WorkspacePanePresentation presentation = WorkspacePanePresentation.standard,
    WorkspaceEditorConfiguration? editor,
    WorkspaceEditorConfiguration? viewAnchor,
  }) async {
    if (_disposed || !navigator.mounted) return null;
    final task = _WorkspaceTaskRoute(
      route,
      modal,
      selectionId,
      dismissible,
      presentation,
      editor,
      viewAnchor,
    );
    _tasks.add(task);
    if (!modal) _activationRevision += 1;
    notifyListeners();
    try {
      if (!modal) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_disposed && hasPaneTasks) focusScope.requestFocus();
        });
      }
      final result = await Future.any<T?>([
        navigator.push<T>(route),
        _disposedSignal.future.then((_) => null),
      ]);
      if (presentation == WorkspacePanePresentation.editor &&
          route is TransitionRoute<T> &&
          !_disposed) {
        await Future.any([route.completed, _disposedSignal.future]);
      }
      return result;
    } finally {
      _tasks.remove(task);
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> close() async {
    // Explicit list/task close owns this route, not an attached preview.
    // Ambient Escape/canvas requests run priority handlers at the frame.
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
    _priorityDismissHandlers.clear();
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
  _WorkspaceTaskRoute(
    this.route,
    this.modal,
    this.selectionId,
    this.dismissible,
    this.presentation,
    this.editor,
    this.viewAnchor,
  );
  final Route<dynamic> route;
  final WorkspacePanePresentation presentation;
  final WorkspaceEditorConfiguration? editor;
  final WorkspaceEditorConfiguration? viewAnchor;
  final position = SkedFloatingPositionController();
  double editorWidth = 600;
  double? contentHeight;
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
      layout.resourcePresentation != oldWidget.layout.resourcePresentation ||
      layout.canExpandResources != oldWidget.layout.canExpandResources ||
      layout.supporting != oldWidget.layout.supporting ||
      layout.dockedDetail != oldWidget.layout.dockedDetail ||
      layout.resourceWidth != oldWidget.layout.resourceWidth ||
      layout.dockedAssistant != oldWidget.layout.dockedAssistant ||
      layout.canvasEndInset != oldWidget.layout.canvasEndInset ||
      layout.canvasObscured != oldWidget.layout.canvasObscured;
}

/// Paint/selection lifetime differs from the runtime save gate.
class WorkspaceVisibilityScope extends InheritedWidget {
  const WorkspaceVisibilityScope({
    super.key,
    required this.visible,
    required super.child,
  });
  final bool visible;
  static bool? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<WorkspaceVisibilityScope>()
      ?.visible;
  @override
  bool updateShouldNotify(WorkspaceVisibilityScope oldWidget) =>
      visible != oldWidget.visible;
}

/// Local, transient resource presentation; never writes a user preference.
class WorkspaceResourceScope extends InheritedWidget {
  const WorkspaceResourceScope({
    super.key,
    required this.drawerOpen,
    required this.canExpandInline,
    required this.open,
    required this.close,
    required super.child,
  });
  final bool drawerOpen;
  final bool canExpandInline;
  final VoidCallback open;
  final VoidCallback close;
  static WorkspaceResourceScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<WorkspaceResourceScope>();
  @override
  bool updateShouldNotify(WorkspaceResourceScope oldWidget) =>
      drawerOpen != oldWidget.drawerOpen ||
      canExpandInline != oldWidget.canExpandInline;
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
    // The command bar above this body always receives the whole work area.
    // Only the calendar gives up space to docked/resized tasks and its agenda.
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          end: scope?.layout.canvasEndInset ?? 0,
        ),
        child: NotificationListener<SizeChangedLayoutNotification>(
          onNotification: (_) {
            scope?.onBodyLayout?.call();
            return false;
          },
          child: SizeChangedLayoutNotifier(
            key: const ValueKey('workspace-canvas-viewport'),
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
  bool _resourceDrawerOpen = false;
  final _resourceFocus = FocusScopeNode(debugLabel: 'Workspace resources');
  FocusNode? _resourceReturnFocus;
  FocusNode? _pendingResourceFocus;
  bool _resourceCloseScheduled = false;
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (WorkspaceVisibilityScope.maybeOf(context) == false) {
      _resourceDrawerOpen = false;
    }
    final next = Provider.of<DeveloperUiPreferences?>(context, listen: false);
    if (identical(next, _developerUi)) return;
    _developerUi?.removeListener(_syncAssistantPreference);
    _developerUi = next;
    next?.addListener(_syncAssistantPreference);
    _syncAssistantPreference();
  }

  void _syncAssistantPreference() {
    if (!mounted) return;
    // This persisted value enables the entry; it is not an open-state restore.
    // Loading/enabling it must never cover the calendar or steal focus.
    // Only an explicit toolbar action opens the session-local panel.
    if (_developerUi?.assistantVisible == false) {
      _assistant.setOpen(false);
    }
    setState(() {});
  }

  void _openResources() {
    if (!mounted || !widget.active || _resourceDrawerOpen) return;
    _resourceReturnFocus = FocusManager.instance.primaryFocus;
    setState(() => _resourceDrawerOpen = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _resourceDrawerOpen && widget.active) {
        _resourceFocus.requestFocus();
      }
    });
  }

  void _closeResources({bool restoreFocus = true}) {
    if (!_resourceDrawerOpen || !mounted) return;
    setState(() => _resourceDrawerOpen = false);
    if (!restoreFocus) return;
    final previous = _resourceReturnFocus;
    final owner = ModalRoute.of(context);
    final activation = widget.controller.activationRevision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !widget.active ||
          _resourceDrawerOpen ||
          owner?.isCurrent == false ||
          activation != widget.controller.activationRevision) {
        return;
      }
      if (previous?.context?.mounted == true && previous!.canRequestFocus) {
        previous.requestFocus();
      } else {
        _workspaceFocus.requestFocus();
      }
    });
  }

  void _scheduleResourceClose() {
    if (_resourceCloseScheduled) return;
    _resourceCloseScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resourceCloseScheduled = false;
      if (mounted) _closeResources();
    });
  }

  void _setAssistantOpen(bool visible) {
    if (visible) _closeResources(restoreFocus: false);
    _assistant.setOpen(visible);
  }

  void _toggleAssistant() {
    if (_layout?.assistantVisible == true) {
      _setAssistantOpen(false);
    } else {
      setState(() => _assistantLast = true);
      _setAssistantOpen(true);
      _requestAssistantFocus();
    }
  }

  double _resizedPaneWidth(
    double preferredWidth,
    double delta, {
    required double minimumWidth,
    required double maximumWidth,
    required double textScale,
  }) {
    final maximum = math.max(minimumWidth, maximumWidth / textScale);
    // Resizing from a temporary viewport cap must respond immediately, not
    // first consume the off-screen portion of an earlier width preference.
    final current = preferredWidth.clamp(minimumWidth, maximum);
    return (current - delta / textScale).clamp(minimumWidth, maximum);
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
    if (controller.hasPaneTasks || controller.hasModalTasks) {
      _closeResources(restoreFocus: false);
    }
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
    if ((WorkspaceVisibilityScope.maybeOf(context) == null && !widget.active) ||
        oldWidget.contextSnapshot?.resourceId !=
            widget.contextSnapshot?.resourceId) {
      _resourceDrawerOpen = false;
    }
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
    _resourceFocus.dispose();
    if (widget.assistantController == null) _assistant.dispose();
    super.dispose();
  }

  Widget _detailPane(
    WorkspaceLayout policy, {
    ValueChanged<Offset>? onViewDragUpdate,
    bool floatingEditor = false,
    ValueChanged<Offset>? onEditorDrag,
  }) {
    final controller = widget.controller;
    final metrics = WorkbenchChromeMetrics.of(context);
    final viewing = metrics.desktop && controller.hasViewPanel;
    final editing = metrics.desktop && controller.hasEditorPanel;
    final editingRoute = controller._tasks.lastOrNull?.route;
    final compact = (viewing && !policy.dockedDetail) || floatingEditor;
    controller.focusScope.traversalEdgeBehavior = floatingEditor
        ? TraversalEdgeBehavior.closedLoop
        : TraversalEdgeBehavior.parentScope;
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
            key: const ValueKey('workspace-detail-surface'),
            compact: compact,
            floating: !policy.dockedDetail,
            role: policy.dockedDetail
                ? SkedSurfaceRole.frame
                : SkedSurfaceRole.content,
            child: Stack(
              children: [
                WorkspaceViewViewport(
                  contentHeight: compact
                      ? controller.viewContentHeight ?? 0
                      : null,
                  child: WorkspaceEditorScope(
                    enabled: editing,
                    floating: floatingEditor,
                    onHeight: (height) {
                      final route = editingRoute;
                      if (route != null) {
                        controller._reportContentHeight(route, height);
                      }
                    },
                    onDrag: onEditorDrag,
                    child: WorkspaceViewLayoutScope(
                      compact: compact,
                      onDragUpdate: onViewDragUpdate,
                      child: Column(
                        children: [
                          if (!viewing && !editing)
                            Padding(
                              key: const ValueKey('workspace-inspector-header'),
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              child: Align(
                                alignment: AlignmentDirectional.centerEnd,
                                child: IconButton(
                                  key: const ValueKey(
                                    'workspace-inspector-close',
                                  ),
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
                if (policy.detailVisible)
                  PositionedDirectional(
                    key: const ValueKey('workspace-detail-resize-position'),
                    start: 0,
                    top: 0,
                    bottom: metrics.desktop ? 0 : null,
                    height: metrics.desktop ? null : 48,
                    width: metrics.desktop ? 9 : 48,
                    child: _PaneResizeHandle(
                      key: const ValueKey('workspace-detail-resize'),
                      onActivate: () => _assistantLast = false,
                      onResize: (dx) => setState(() {
                        if (editing) {
                          final task = controller._tasks.last;
                          task.editorWidth = (task.editorWidth - dx).clamp(
                            320.0,
                            math
                                .min(680.0, policy.maximumDetailWidth)
                                .clamp(320.0, 680.0),
                          );
                          return;
                        }
                        _detailWidth = _resizedPaneWidth(
                          _detailWidth,
                          dx,
                          minimumWidth: AppBreakpoints.minimumDetailPane,
                          maximumWidth: policy.maximumDetailWidth,
                          textScale: metrics.textScale,
                        );
                      }),
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

  void _restoreResourceFocusAfterLayout({required bool settled}) {
    final focus = _pendingResourceFocus;
    if (focus == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(_pendingResourceFocus, focus)) return;
      if (!widget.active ||
          _resourceDrawerOpen ||
          widget.controller.floatingEditor) {
        _pendingResourceFocus = null;
      } else if (focus.context?.mounted == true && focus.canRequestFocus) {
        focus.requestFocus();
        _pendingResourceFocus = null;
      } else if (settled) {
        _pendingResourceFocus = null;
      }
    });
  }

  Widget _resourceHost(
    WorkspaceLayout policy,
    WorkbenchChromeMetrics metrics,
    Widget base,
  ) {
    final drawer = _resourceDrawerOpen;
    _resourceFocus.traversalEdgeBehavior = drawer
        ? TraversalEdgeBehavior.closedLoop
        : TraversalEdgeBehavior.parentScope;
    final visible = drawer || policy.resources;
    final blocked = widget.controller.floatingEditor;
    final motion = SkedMotionPolicy.of(context);
    return WorkspaceResourceScope(
      drawerOpen: drawer,
      canExpandInline: policy.canExpandResources,
      open: _openResources,
      close: () => _closeResources(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final top = drawer && DesktopWindowBridge.instance.available
              ? metrics.toolbarHeight
              : 0.0;
          final width = drawer
              ? math.min(
                  AppBreakpoints.resourcePane * metrics.textScale,
                  constraints.maxWidth,
                )
              : policy.resources
              ? policy.resourceWidth
              : 0.0;
          return Stack(
            children: [
              ExcludeFocus(
                excluding: drawer,
                child: ExcludeSemantics(
                  excluding: drawer,
                  child: AbsorbPointer(absorbing: drawer, child: base),
                ),
              ),
              if (drawer)
                Positioned.fill(
                  top: top,
                  child: ModalBarrier(
                    key: const ValueKey('workspace-resource-scrim'),
                    color: Colors.black.withValues(alpha: .2),
                    dismissible: true,
                    semanticsLabel: MaterialLocalizations.of(context)
                        .modalBarrierDismissLabel,
                    onDismiss: () => _closeResources(),
                  ),
                ),
              PositionedDirectional(
                top: top,
                bottom: 0,
                start: 0,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: width),
                  duration:
                      drawer || !visible || !motion.spatialAnimationsEnabled
                      ? Duration.zero
                      : motion.effects(SkedMotionSpeed.standard),
                  curve: motion.scheme.standardCurve,
                  builder: (context, value, child) {
                    _restoreResourceFocusAfterLayout(
                      settled: (value - width).abs() < .01,
                    );
                    return SizedBox(
                      key: const ValueKey('workspace-resource-surface'),
                      width: value,
                      child: ClipRect(child: child),
                    );
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: blocked
                        ? () {
                            if (widget.controller.dismissOnCanvasTap) {
                              unawaited(widget.controller.close());
                            }
                          }
                        : null,
                    child: AbsorbPointer(
                      absorbing: blocked,
                      child: ExcludeFocus(
                        excluding: blocked,
                        child: ExcludeSemantics(
                          excluding: blocked,
                          child: Offstage(
                            offstage: !visible,
                            child: FocusScope(
                              node: _resourceFocus,
                              canRequestFocus: widget.active && visible,
                              descendantsAreFocusable: widget.active && visible,
                              child: Semantics(
                                scopesRoute: drawer,
                                explicitChildNodes: true,
                                child: WorkspaceCanvasScope(
                                  layout: policy,
                                  child: widget.resources,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = WorkspaceVisibilityScope.maybeOf(context) != false;
    return UpdatePromptBlocker(
      blocked: () =>
          mounted &&
          visible &&
          widget.active &&
          (widget.controller.isOpen ||
              _assistant.isOpen ||
              _resourceDrawerOpen),
      child: _buildFrame(context),
    );
  }

  Widget _buildFrame(BuildContext context) => SafeArea(
    child: AnimatedBuilder(
      animation: Listenable.merge([widget.controller, _assistant]),
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) {
          final controller = widget.controller;
          final active = widget.active;
          final previewEnabled =
              _developerUi?.assistantVisible ?? widget.assistantPreview;
          final editingTask =
              WorkbenchChromeMetrics.of(context).desktop &&
                  controller.hasEditorPanel
              ? controller._tasks.lastOrNull
              : null;
          final metrics = WorkbenchChromeMetrics.of(context);
          WorkspaceLayout resolveLayout(bool assistantOpen) =>
              WorkspaceLayout.resolve(
                constraints.maxWidth,
                metrics.textScale,
                detailOpen: controller.hasPaneTasks,
                hasSupporting: widget.supporting != null,
                assistantOpen: assistantOpen,
                assistantActive: _assistantLast,
                pointer: metrics.desktop,
                captionWidth: DesktopWindowBridge.instance.available
                    ? metrics.captionWidth
                    : 0,
                shortWindow: MediaQuery.sizeOf(context).height < 480,
                panelDisplayMode: editingTask?.position.detached == true
                    ? WorkspacePanelDisplayMode.overlay
                    : widget.panelDisplayMode,
                partialDetailOverlay:
                    metrics.desktop &&
                    (controller.hasViewPanel || controller.hasEditorPanel),
                minimumCanvas: widget.minimumCanvas,
                preferredDetailWidth: editingTask == null
                    ? _detailWidth
                    : editingTask.editorWidth / metrics.textScale,
                preferredAssistantWidth: _assistant.width,
                // Scaffold shortens the body for the IME. Only an actual short
                // window, not typing in a pane, may compact the navigation.
                resourcesCollapsed: widget.resourcesCollapsed,
              );
          final editorLayout = resolveLayout(false);
          final assistantOpen =
              previewEnabled &&
              _assistant.isOpen &&
              (editingTask == null || editorLayout.dockedDetail);
          final policy = assistantOpen ? resolveLayout(true) : editorLayout;
          final floatingEditor =
              editingTask != null &&
              policy.detailVisible &&
              !policy.dockedDetail;
          controller._setEditorFloating(floatingEditor && active);
          final compactView =
              policy.detailVisible &&
              metrics.desktop &&
              controller.hasViewPanel &&
              !policy.dockedDetail;
          if (_resourceDrawerOpen &&
              policy.canExpandResources &&
              _layout?.canExpandResources != true) {
            _scheduleResourceClose();
          }
          if (_layout?.resources != policy.resources &&
              !_resourceDrawerOpen &&
              widget.active) {
            _pendingResourceFocus = FocusManager.instance.primaryFocus;
          }
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
          final captionInset = DesktopWindowBridge.instance.available
              ? metrics.toolbarHeight
              : 0.0;
          final overlayInset = math
              .max(captionInset, _bodyTop ?? metrics.toolbarHeight)
              .clamp(0.0, constraints.maxHeight);
          final viewTask = controller._tasks.lastOrNull;
          final detailWidth = (compactView || floatingEditor)
              ? math.min(
                  policy.detailWidth,
                  math.max(
                    0.0,
                    constraints.maxWidth -
                        (policy.resources ? policy.resourceWidth + 1 : 0) -
                        16,
                  ),
                )
              : policy.detailWidth;
          // Keep full Navigator constraints regardless of the dragged top, so
          // moving a panel never shrinks its list or loses its scroll position.
          final detailMaxHeight = math.min(
            floatingEditor ? 720.0 : double.infinity,
            math.max(
              0.0,
              constraints.maxHeight -
                  overlayInset -
                  ((compactView || floatingEditor) ? 16 : 0),
            ),
          );
          final rtl = Directionality.of(context) == TextDirection.rtl;
          final panelBounds = Rect.fromLTRB(
            policy.resources && !rtl ? policy.resourceWidth + 9 : 8,
            overlayInset + 8,
            constraints.maxWidth -
                (policy.resources && rtl ? policy.resourceWidth + 9 : 8),
            constraints.maxHeight - 8,
          );
          final frameRender =
              _stackKey.currentContext?.findRenderObject() ??
              context.findRenderObject();
          final anchorBounds = Offset.zero & constraints.biggest;
          Rect? localAnchor(WorkspaceEditorConfiguration? config) {
            // The entry can disappear with a menu or resource drawer. Keep its
            // captured rectangle while the panel measures its actual height.
            final local = frameRender is RenderBox
                ? config?.anchorIn(frameRender)
                : null;
            return local != null && local.overlaps(anchorBounds) ? local : null;
          }

          final viewAnchor = localAnchor(viewTask?.viewAnchor);
          final viewSize = Size(
            detailWidth,
            (controller.viewContentHeight ?? detailMaxHeight).clamp(
              0.0,
              detailMaxHeight,
            ),
          );
          var viewOverride = viewTask?.position.positionOverride(
            hasAnchor: viewAnchor != null,
          );
          if (compactView &&
              !rtl &&
              viewTask!.position.detached &&
              viewTask.position.size.width != viewSize.width) {
            // The resize handle is on the leading edge. Keep a manually
            // positioned panel's opposite edge fixed when its width changes.
            viewOverride =
                (viewTask.position.lastPosition ?? viewOverride!) +
                Offset(viewTask.position.size.width - viewSize.width, 0);
            viewTask.position.manualPosition = viewOverride;
          }
          final viewOffset = viewOverride != null
              ? boundSkedFloatingPosition(viewOverride, viewSize, panelBounds)
              : viewAnchor == null
              ? boundSkedFloatingPosition(
                  Offset(
                    rtl ? panelBounds.left : panelBounds.right - detailWidth,
                    panelBounds.top,
                  ),
                  viewSize,
                  panelBounds,
                )
              : positionSkedFloatingPanel(
                  bounds: panelBounds,
                  anchorBounds: anchorBounds,
                  size: viewSize,
                  anchor: viewAnchor,
                  rtl: rtl,
                );
          if (compactView) {
            viewTask!.position.recordLayout(viewOffset, viewSize);
          }
          void dragView(Offset delta) {
            if (!mounted ||
                !widget.active ||
                !compactView ||
                !identical(viewTask, controller._tasks.lastOrNull)) {
              return;
            }
            setState(() => viewTask!.position.drag(delta, panelBounds));
          }

          final config = editingTask?.editor;
          final anchor = localAnchor(config);
          final editorSize = Size(
            detailWidth,
            (editingTask?.contentHeight ?? detailMaxHeight).clamp(
              0,
              detailMaxHeight,
            ),
          );
          final editorOverride = editingTask?.position.positionOverride(
            hasAnchor: anchor != null,
          );
          final editorOffset = editorOverride != null
              ? boundSkedFloatingPosition(
                  editorOverride,
                  editorSize,
                  panelBounds,
                )
              : positionSkedFloatingPanel(
                  bounds: panelBounds,
                  anchorBounds: anchorBounds,
                  size: editorSize,
                  anchor: anchor,
                  rtl: rtl,
                  placement:
                      config?.placement ?? SkedFloatingPlacement.automatic,
                );
          if (floatingEditor) {
            editingTask.position.recordLayout(editorOffset, editorSize);
          }
          void dragEditor(Offset delta) {
            if (!active ||
                !floatingEditor ||
                editingTask.route.isCurrent != true ||
                ModalRoute.of(context)?.isCurrent != true) {
              return;
            }
            setState(() => editingTask.position.drag(delta, panelBounds));
          }

          final resizeExtent = metrics.desktop ? 9.0 : 48.0;
          final motion = SkedMotionPolicy.of(context);
          // Reserve only the calendar's bounded inset. The rest of a wide pane
          // covers the body and can never consume the sidebar's base budget.
          final resourceBudget = math.max(
            // Even rounding at a fractional-scale limit must not shave width
            // off the base sidebar or move the full-width command bar.
            policy.resourceWidth,
            (constraints.maxWidth -
                    policy.minimumCanvasWidth -
                    policy.canvasEndInset -
                    1)
                .clamp(0.0, constraints.maxWidth),
          );
          final overlayVisible =
              (policy.detailVisible && !policy.dockedDetail) ||
              (policy.assistantVisible && !policy.dockedAssistant);
          Future<void> dismiss() async {
            if (!floatingEditor && controller.dismissPriorityTask()) return;
            if (_resourceDrawerOpen) {
              _closeResources();
              return;
            }
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
              canPop:
                  !active ||
                  (!_resourceDrawerOpen &&
                      !controller.hasPaneTasks &&
                      !assistantOpen),
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
                    child: Listener(
                      onPointerDown: (event) {
                        if (!controller.floatingEditor) {
                          controller.lastPointerAnchor =
                              event.position & const Size(1, 1);
                        }
                      },
                      child: _resourceHost(
                        policy,
                        metrics,
                        Stack(
                          key: _stackKey,
                          children: [
                            Positioned.fill(
                              child: IgnorePointer(
                                child: DesktopEditorWindowGuard(
                                  active: floatingEditor && active,
                                  child: const SizedBox.expand(),
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  TweenAnimationBuilder<double>(
                                    tween: Tween(end: policy.resourceWidth),
                                    duration: motion.spatialAnimationsEnabled
                                        ? motion.effects(
                                            SkedMotionSpeed.standard,
                                          )
                                        : Duration.zero,
                                    curve: motion.scheme.standardCurve,
                                    builder: (context, width, child) =>
                                        SizedBox(
                                          key: const ValueKey(
                                            'workspace-resource-width',
                                          ),
                                          width: policy.resources
                                              ? width.clamp(0.0, resourceBudget)
                                              : 0,
                                          child: ClipRect(child: child),
                                        ),
                                  ),
                                  SizedBox(
                                    width: policy.resources ? 1 : 0,
                                    child: const VerticalDivider(width: 1),
                                  ),
                                  Expanded(
                                    child: ExcludeFocus(
                                      excluding: !active || floatingEditor,
                                      child: WorkspaceCanvasScope(
                                        layout: policy,
                                        bodyKey: _bodyKey,
                                        onBodyLayout: _scheduleBodyGeometry,
                                        child: WorkspaceSelectionScope(
                                          key: const ValueKey(
                                            'workspace-canvas',
                                          ),
                                          selectedId: controller.selectedId,
                                          child: GestureDetector(
                                            behavior:
                                                HitTestBehavior.translucent,
                                            onTap:
                                                active &&
                                                    policy.detailVisible &&
                                                    controller
                                                        .dismissOnCanvasTap
                                                ? () {
                                                    // Activation can change without a frame rebuild.
                                                    if (!policy
                                                            .assistantVisible ||
                                                        !_assistantLast) {
                                                      if (controller
                                                          .dismissPriorityTask()) {
                                                        return;
                                                      }
                                                      unawaited(
                                                        controller.close(),
                                                      );
                                                    }
                                                  }
                                                : null,
                                            child: ExcludeSemantics(
                                              excluding: floatingEditor,
                                              child: widget.canvas,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PositionedDirectional(
                              key: const ValueKey('workspace-supporting-pane'),
                              end: 0,
                              top: overlayInset,
                              bottom: 0,
                              width: policy.supportingWidth,
                              child: Offstage(
                                offstage: !policy.supporting,
                                child: ExcludeFocus(
                                  excluding:
                                      !active ||
                                      !policy.supporting ||
                                      (overlayVisible && !compactView),
                                  child: ExcludeSemantics(
                                    excluding: overlayVisible && !compactView,
                                    child: _PaneSurface(
                                      child:
                                          widget.supporting ??
                                          const SizedBox.shrink(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (floatingEditor && active)
                              Positioned.fill(
                                child: ModalBarrier(
                                  key: const ValueKey(
                                    'workspace-editor-barrier',
                                  ),
                                  color: Colors.transparent,
                                  dismissible: controller.dismissOnCanvasTap,
                                  onDismiss: () =>
                                      unawaited(controller.close()),
                                  semanticsLabel: MaterialLocalizations.of(
                                    context,
                                  ).modalBarrierDismissLabel,
                                ),
                              ),
                            // These keyed slots never change identity on a resize,
                            // mode change or activation of a different foreground task.
                            PositionedDirectional(
                              key: const ValueKey('workspace-detail-pane'),
                              end: floatingEditor || compactView
                                  ? (rtl
                                        ? (floatingEditor
                                              ? editorOffset.dx
                                              : viewOffset.dx)
                                        : constraints.maxWidth -
                                              (floatingEditor
                                                  ? editorOffset.dx
                                                  : viewOffset.dx) -
                                              detailWidth)
                                  : policy.dockedDetail
                                  ? assistantSpace
                                  : 0,
                              top: floatingEditor
                                  ? editorOffset.dy
                                  : compactView
                                  ? viewOffset.dy
                                  : overlayInset,
                              width: detailWidth,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight: detailMaxHeight,
                                ),
                                child: _detailPane(
                                  policy,
                                  floatingEditor: floatingEditor,
                                  onEditorDrag: dragEditor,
                                  onViewDragUpdate: compactView && active
                                      ? dragView
                                      : null,
                                ),
                              ),
                            ),
                            PositionedDirectional(
                              key: const ValueKey('workspace-assistant-pane'),
                              end: 0,
                              top: overlayInset,
                              bottom: 0,
                              width: policy.assistantWidth,
                              child: _assistantPane(policy, previewEnabled),
                            ),
                            if (policy.assistantVisible)
                              PositionedDirectional(
                                key: const ValueKey(
                                  'workspace-assistant-resize-position',
                                ),
                                end: policy.assistantWidth - resizeExtent,
                                top: overlayInset,
                                bottom: metrics.desktop ? 0 : null,
                                height: metrics.desktop ? null : 48,
                                width: resizeExtent,
                                child: _PaneResizeHandle(
                                  key: const ValueKey(
                                    'workspace-assistant-resize',
                                  ),
                                  onActivate: () => _assistantLast = true,
                                  onResize: (dx) => _assistant.resize(
                                    _resizedPaneWidth(
                                      _assistant.width,
                                      dx,
                                      minimumWidth:
                                          AppBreakpoints.minimumAssistantPane,
                                      maximumWidth:
                                          policy.maximumAssistantWidth,
                                      textScale: metrics.textScale,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
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
    super.key,
    required this.child,
    this.compact = false,
    this.role = SkedSurfaceRole.frame,
    this.floating = false,
  });
  final Widget child;
  final SkedSurfaceRole role;
  final bool floating;
  final bool compact;
  @override
  Widget build(BuildContext context) => compact
      ? SkedFloatingSurface(child: child)
      : DecoratedBox(
          decoration: BoxDecoration(
            boxShadow: floating
                ? SkedFloatingStyle.shadows(Theme.of(context).colorScheme)
                : null,
            border: BorderDirectional(
              start: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          child: ClipRect(
            child: SkedSurface(role: role, child: child),
          ),
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
