import '../theme/sked_surface.dart';

import 'dart:async';

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
  int _depth = 0;
  final Map<Object, String?> _selections = {};
  final Map<Object, bool> _dismissible = {};
  bool get dismissOnCanvasTap => _dismissible.values.lastOrNull ?? false;
  String? get selectedId =>
      _selections.isEmpty ? null : _selections.values.last;
  bool _closing = false;
  final _disposedSignal = Completer<void>();
  bool _disposed = false;
  bool get isOpen => _depth > 0;

  Future<T?> show<T>(
    WidgetBuilder builder, {
    String? selectionId,
    bool dismissOnCanvasTap = true,
  }) async {
    final navigator = navigatorKey.currentState;
    if (navigator == null || _disposed) return null;
    final token = Object();
    _selections[token] = selectionId;
    _dismissible[token] = dismissOnCanvasTap;
    _depth++;
    notifyListeners();
    try {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_disposed && isOpen) focusScope.requestFocus();
      });
      final route = navigator.push<T>(
        MaterialPageRoute<T>(
          builder: (context) => SkedSurface(
            child: WorkspaceTaskScope(
              child: UiCommandFeedbackHost(builder: builder),
            ),
          ),
        ),
      );
      return await Future.any<T?>([
        route,
        _disposedSignal.future.then((_) => null),
      ]);
    } finally {
      _selections.remove(token);
      _dismissible.remove(token);
      _depth--;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> close() async {
    if (_closing) return;
    _closing = true;
    try {
      await navigatorKey.currentState?.maybePop();
    } finally {
      _closing = false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _disposedSignal.complete();
    focusScope.dispose();
    super.dispose();
  }
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
  });
  final WorkspaceLayout layout;
  static WorkspaceLayout? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<WorkspaceCanvasScope>()
      ?.layout;
  @override
  bool updateShouldNotify(WorkspaceCanvasScope oldWidget) =>
      layout.resources != oldWidget.layout.resources ||
      layout.supporting != oldWidget.layout.supporting ||
      layout.dockedDetail != oldWidget.layout.dockedDetail ||
      layout.resourceWidth != oldWidget.layout.resourceWidth ||
      layout.dockedAssistant != oldWidget.layout.dockedAssistant;
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
  double _detailWidth = 360;
  bool _assistantLast = false;
  bool _wasDetailOpen = false;
  bool _wasAssistantOpen = false;
  String? _selection;
  DeveloperUiPreferences? _developerUi;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = Provider.of<DeveloperUiPreferences?>(context, listen: false);
    if (identical(next, _developerUi)) return;
    _developerUi?.removeListener(_syncAssistantPreference);
    _developerUi = next;
    next?.addListener(_syncAssistantPreference);
    _syncAssistantPreference();
  }

  void _syncAssistantPreference() {
    if (!mounted) return;
    final p = _developerUi;
    if (p != null) _assistant.setOpen(p.assistantVisible);
    setState(() {});
  }

  Future<void> _setAssistantOpen(bool visible) async {
    final p = _developerUi;
    if (p?.busy == true) return;
    if (p == null) {
      _assistant.setOpen(visible);
      return;
    }
    if (!await p.setAssistantVisible(visible) && mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).saveFailedRetry),
          action: SnackBarAction(
            label: AppLocalizations.of(context).dataRecoveryRetryAction,
            onPressed: () => unawaited(_setAssistantOpen(visible)),
          ),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_detailChanged);
    _assistant.addListener(_assistantChanged);
  }

  void _detailChanged() {
    if (widget.controller.isOpen &&
        (!_wasDetailOpen || widget.controller.selectedId != _selection)) {
      _assistantLast = false;
    }
    _wasDetailOpen = widget.controller.isOpen;
    _selection = widget.controller.selectedId;
  }

  void _assistantChanged() {
    if (_assistant.isOpen && !_wasAssistantOpen) _assistantLast = true;
    _wasAssistantOpen = _assistant.isOpen;
  }

  @override
  void didUpdateWidget(WorkspaceFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_detailChanged);
      widget.controller.addListener(_detailChanged);
    }
  }

  @override
  void dispose() {
    _developerUi?.removeListener(_syncAssistantPreference);
    widget.controller.removeListener(_detailChanged);
    _assistant.removeListener(_assistantChanged);
    if (widget.assistantController == null) _assistant.dispose();
    super.dispose();
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
          final policy = WorkspaceLayout.resolve(
            constraints.maxWidth,
            MediaQuery.textScalerOf(context).scale(14) / 14,
            detailOpen: controller.isOpen,
            hasSupporting: widget.supporting != null,
            assistantOpen: assistantOpen,
            pointer: WorkbenchLayoutPolicy.pointerLayout(context),
            minimumCanvas: widget.minimumCanvas,
            preferredDetailWidth: _detailWidth,
            preferredAssistantWidth: _assistant.width,
            resourcesCollapsed:
                widget.resourcesCollapsed || constraints.maxHeight < 480,
          );
          final assistantOverlay = assistantOpen && !policy.dockedAssistant;
          final detailOverlay = controller.isOpen && !policy.dockedDetail;
          final assistantVisible =
              assistantOpen && (!detailOverlay || _assistantLast);
          final detailVisible =
              controller.isOpen && (!assistantOverlay || !_assistantLast);
          final obscured =
              (assistantOverlay && assistantVisible) ||
              (detailOverlay && detailVisible);
          final assistantSpace = policy.dockedAssistant
              ? policy.assistantWidth + 1
              : 0.0;
          final detailSpace = policy.dockedDetail || policy.supporting
              ? policy.detailWidth + 1
              : 0.0;
          // Native controls occupy this row, not a second application title bar.
          final pointer = WorkbenchLayoutPolicy.pointerLayout(context);
          final resizeExtent = pointer ? 9.0 : 48.0;
          final metrics = WorkbenchChromeMetrics.of(context);
          final captionInset = DesktopWindowBridge.instance.available
              ? metrics.toolbarHeight
              : 0.0;
          final captionWidth = metrics.captionWidth;
          Future<void> dismiss() async {
            if (assistantVisible && (!detailVisible || _assistantLast)) {
              await _setAssistantOpen(false);
            } else if (detailVisible) {
              await controller.close();
            }
          }

          return AssistantPaneScope(
            controller: _assistant,
            enabled: previewEnabled,
            interactive: _developerUi?.busy != true,
            onToggle: () => unawaited(_setAssistantOpen(!_assistant.isOpen)),
            child: PopScope(
              canPop: !active || (!controller.isOpen && !assistantOpen),
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
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              width: policy.resources
                                  ? policy.resourceWidth
                                  : 0,
                              child: Offstage(
                                offstage: !policy.resources,
                                child: ExcludeFocus(
                                  excluding:
                                      !active || !policy.resources || obscured,
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
                                excluding: !active || obscured,
                                child: WorkspaceCanvasScope(
                                  layout: policy,
                                  child: WorkspaceSelectionScope(
                                    key: const ValueKey('workspace-canvas'),
                                    selectedId: controller.selectedId,
                                    child: ExcludeSemantics(
                                      excluding: obscured,
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.translucent,
                                        onTap:
                                            active &&
                                                controller.isOpen &&
                                                controller.dismissOnCanvasTap
                                            ? () =>
                                                  unawaited(controller.close())
                                            : null,
                                        child: widget.canvas,
                                      ),
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
                          assistantSpace + detailSpace > captionWidth)
                        PositionedDirectional(
                          end: captionWidth,
                          top: 0,
                          width: assistantSpace + detailSpace - captionWidth,
                          height: captionInset,
                          child: const SkedSurface(
                            key: ValueKey('workspace-caption-fill'),
                            role: SkedSurfaceRole.frame,
                            child: DesktopDragRegion(child: SizedBox.expand()),
                          ),
                        ),
                      if (policy.supporting)
                        PositionedDirectional(
                          end: assistantSpace,
                          top: captionInset,
                          bottom: 0,
                          width: policy.detailWidth,
                          child: _PaneSurface(child: widget.supporting!),
                        ),
                      // Keep both slots mounted at a stable address across dock/overlay changes.
                      PositionedDirectional(
                        end: detailOverlay ? 0 : assistantSpace,
                        top: captionInset,
                        bottom: 0,
                        width: policy.detailWidth,
                        child: Offstage(
                          offstage: !detailVisible,
                          child: ExcludeFocus(
                            excluding: !active || !detailVisible,
                            child: Listener(
                              onPointerDown: (_) {
                                _assistantLast = false;
                              },
                              child: _PaneSurface(
                                role: policy.dockedDetail
                                    ? SkedSurfaceRole.frame
                                    : SkedSurfaceRole.content,
                                child: Column(
                                  children: [
                                    Align(
                                      alignment: AlignmentDirectional.centerEnd,
                                      child: IconButton(
                                        tooltip: MaterialLocalizations.of(
                                          context,
                                        ).closeButtonTooltip,
                                        icon: const Icon(Icons.close),
                                        onPressed: controller.close,
                                      ),
                                    ),
                                    Expanded(
                                      child: FocusScope(
                                        key: const ValueKey(
                                          'workspace-inspector',
                                        ),
                                        node: controller.focusScope,
                                        canRequestFocus:
                                            active && detailVisible,
                                        descendantsAreFocusable:
                                            active && detailVisible,
                                        descendantsAreTraversable:
                                            active && detailVisible,
                                        child: Semantics(
                                          container: true,
                                          explicitChildNodes: true,
                                          child: Navigator(
                                            key: controller.navigatorKey,
                                            requestFocus: false,
                                            onGenerateRoute: (_) =>
                                                MaterialPageRoute<void>(
                                                  builder: (_) =>
                                                      const SizedBox.shrink(),
                                                ),
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
                      PositionedDirectional(
                        end: 0,
                        top: captionInset,
                        bottom: 0,
                        width: policy.assistantWidth,
                        child: Offstage(
                          offstage: !assistantVisible,
                          child: ExcludeFocus(
                            excluding: !active || !assistantVisible,
                            child: Listener(
                              onPointerDown: (_) {
                                _assistantLast = true;
                              },
                              child: _PaneSurface(
                                role: policy.dockedAssistant
                                    ? SkedSurfaceRole.frame
                                    : SkedSurfaceRole.content,
                                child: !previewEnabled
                                    ? const SizedBox.shrink()
                                    : AssistantPreviewPane(
                                        closeEnabled:
                                            _developerUi?.busy != true,
                                        onClose: () =>
                                            unawaited(_setAssistantOpen(false)),
                                        controller: _assistant,
                                        snapshot: widget.contextSnapshot
                                            ?.withSelection(
                                              controller.selectedId,
                                            ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (policy.dockedDetail && detailVisible && !obscured)
                        PositionedDirectional(
                          end:
                              assistantSpace +
                              policy.detailWidth -
                              resizeExtent,
                          top: captionInset,
                          bottom: pointer ? 0 : null,
                          height: pointer ? null : 48,
                          width: resizeExtent,
                          child: _PaneResizeHandle(
                            onResize: (dx) => setState(
                              () => _detailWidth = (_detailWidth - dx).clamp(
                                320,
                                600,
                              ),
                            ),
                          ),
                        ),
                      if (policy.dockedAssistant &&
                          assistantVisible &&
                          !obscured)
                        PositionedDirectional(
                          end: policy.assistantWidth - resizeExtent,
                          top: captionInset,
                          bottom: pointer ? 0 : null,
                          height: pointer ? null : 48,
                          width: resizeExtent,
                          child: _PaneResizeHandle(
                            onResize: (dx) =>
                                _assistant.resize(_assistant.width - dx),
                          ),
                        ),
                    ],
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
  const _PaneSurface({required this.child, this.role = SkedSurfaceRole.frame});
  final Widget child;
  final SkedSurfaceRole role;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: BorderDirectional(
        start: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
    ),
    child: SkedSurface(role: role, child: child),
  );
}

class _PaneResizeHandle extends StatelessWidget {
  const _PaneResizeHandle({required this.onResize});
  final ValueChanged<double> onResize;
  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    explicitChildNodes: true,
    label: AppLocalizations.of(context).resizePanel,
    onIncrease: () => onResize(-24),
    onDecrease: () => onResize(24),
    child: Focus(
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          onResize(-24);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          onResize(24);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (details) => onResize(
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
