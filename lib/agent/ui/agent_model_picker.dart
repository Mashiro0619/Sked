import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../models/agent_settings.dart';
import '../../theme/sked_expressive_theme.dart';
import '../../theme/sked_menu_style.dart';
import '../../widgets/sked_menu_item_content.dart';
import '../../widgets/sked_menu_anchor.dart';
import '../../widgets/expressive_motion.dart';
import 'agent_effort_slider.dart';
import 'agent_model_labels.dart';
import 'agent_ui_delegate.dart';
import 'agent_ui_style.dart';

typedef AgentModelPickerLayoutBuilder = Widget Function(
  Widget control,
  Widget status,
);

typedef _ModelMenuGeometry = ({
  Size size,
  double pixelRatio,
  EdgeInsets padding,
  EdgeInsets insets,
});

/// Keeps horizontal menu placement tied to the composer surface while the
/// trigger's label and width change. Vertical placement still uses the trigger.
class AgentModelPickerAnchorScope extends InheritedWidget {
  const AgentModelPickerAnchorScope({
    super.key,
    required this.composerKey,
    required super.child,
  });

  final GlobalKey composerKey;

  static AgentModelPickerAnchorScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AgentModelPickerAnchorScope>();

  Rect? _anchorRect(BuildContext context, Rect triggerRect) {
    final composer = composerKey.currentContext?.findRenderObject();
    final overlay = Overlay.maybeOf(context)?.context.findRenderObject();
    if (composer is! RenderBox ||
        overlay is! RenderBox ||
        !overlay.attached ||
        !overlay.hasSize) {
      return null;
    }
    var reachesOverlay = false;
    for (
      RenderObject? current = composer;
      current != null;
      current = current.parent
    ) {
      if (!current.attached || current is RenderBox && !current.hasSize) {
        return null;
      }
      if (identical(current, overlay)) {
        reachesOverlay = true;
        break;
      }
    }
    if (!reachesOverlay) return null;
    final bounds = MatrixUtils.transformRect(
      composer.getTransformTo(overlay),
      Offset.zero & composer.size,
    );
    if (!bounds.isFinite || bounds.isEmpty) return null;
    return Rect.fromLTRB(
      bounds.left - 16,
      triggerRect.top,
      bounds.right + 16,
      triggerRect.bottom,
    );
  }

  @override
  bool updateShouldNotify(AgentModelPickerAnchorScope oldWidget) =>
      oldWidget.composerKey != composerKey;
}

bool agentConversationModelReady(AgentUiState state, String conversationId) {
  final selection = state.selectionFor(conversationId);
  return selection != null &&
      state.availableModels.any(
        (model) =>
            model.id == selection.modelId &&
            model.reasoningEfforts.contains(selection.reasoningEffort),
      );
}

/// Persists a model/effort pair for the next request. Dragging only previews;
/// the runtime continues to own every active request snapshot.
class AgentModelPicker extends StatefulWidget {
  const AgentModelPicker({
    super.key,
    required this.conversationId,
    required this.delegate,
    this.enabled = true,
    this.active = true,
    this.interactive = true,
    this.layoutBuilder,
  });
  final String conversationId;
  final AgentUiDelegate delegate;
  final bool enabled;
  final bool active;
  final bool interactive;
  final AgentModelPickerLayoutBuilder? layoutBuilder;
  @override
  State<AgentModelPicker> createState() => _AgentModelPickerState();
}

class _AgentModelPickerState extends State<AgentModelPicker>
    with WidgetsBindingObserver {
  final _menu = MenuController();
  final _focus = FocusNode(debugLabel: 'Agent model and effort');
  final _sliderFocus = FocusNode(debugLabel: 'Agent thinking effort');
  bool _saving = false, _failed = false, _modelsVisible = false;
  int _generation = 0;
  int _panelGeneration = 0;
  int? _openGeneration;
  Object? _openToken;
  List<AgentModelConfig>? _openModels;
  AgentReasoningEffort? _preview;
  LocalHistoryEntry? _menuHistory;
  ModalRoute<dynamic>? _openRoute;
  _ModelMenuGeometry? _menuGeometry;
  int _menuGeneration = 0;
  bool _ownerCurrent = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _generation++;
    _endMenuSession();
    _focus.dispose();
    _sliderFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    final previous = _menuGeometry;
    if (previous == null) return;
    final current = _readGeometry();
    // Taking menu focus can hide the IME over several native frames. Reduced
    // obstruction keeps the old bounds safe and must not cancel that choice.
    if (current.size == previous.size &&
        current.pixelRatio == previous.pixelRatio &&
        current.padding == previous.padding &&
        current.insets.left <= previous.insets.left &&
        current.insets.top <= previous.insets.top &&
        current.insets.right <= previous.insets.right &&
        current.insets.bottom <= previous.insets.bottom) {
      _menuGeometry = current;
      return;
    }
    _invalidateMenu();
  }

  _ModelMenuGeometry _readGeometry() {
    final view = View.of(context);
    return (
      size: view.physicalSize,
      pixelRatio: view.devicePixelRatio,
      padding: EdgeInsets.fromViewPadding(view.viewPadding, 1),
      insets: EdgeInsets.fromViewPadding(view.viewInsets, 1),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ownerCurrent =
        (ModalRoute.isCurrentOf(context) ?? true) &&
        TickerMode.valuesOf(context).enabled &&
        FocusScope.of(context).canRequestFocus;
    if (_openToken != null && !_ownerCurrent) _invalidateMenu();
  }

  @override
  void didUpdateWidget(AgentModelPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversationId != widget.conversationId ||
        oldWidget.delegate != widget.delegate) {
      _generation++;
      _saving = false;
      _failed = false;
      _invalidateMenu();
    } else if (!widget.enabled || !widget.active || !widget.interactive) {
      _invalidateMenu();
    }
  }

  void _endMenuSession() {
    _menuGeneration++;
    _openGeneration = null;
    _openToken = null;
    _openModels = null;
    _openRoute = null;
    _menuGeometry = null;
    _preview = null;
    final history = _menuHistory;
    _menuHistory = null;
    history?.remove();
  }

  void _menuClosed() {
    _endMenuSession();
    if (mounted) setState(() {});
  }

  void _menuAnimationChanged(AnimationStatus status) {
    if (_openToken != null &&
        (status == AnimationStatus.reverse ||
            status == AnimationStatus.dismissed)) {
      // Internal Escape and ancestor scrolling close MenuAnchor directly.
      // onClose waits for the animation, but their old callbacks expire now.
      _endMenuSession();
      if (mounted) setState(() {});
    }
  }

  void _dismissMenu() {
    if (_openToken == null && !_menu.isOpen) return;
    // Invalidate before the close animation so a cancelled drag cannot save.
    _endMenuSession();
    if (_menu.isOpen) _menu.close();
    if (mounted) setState(() {});
  }

  void _invalidateMenu() {
    _endMenuSession();
    final generation = _menuGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _menuGeneration) return;
      if (_menu.isOpen) _menu.close();
      setState(() {});
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _registerMenuHistory(Object token) {
    final route = ModalRoute.of<dynamic>(context);
    _openRoute = route;
    if (route == null) return;
    final entry = LocalHistoryEntry(
      impliesAppBarDismissal: false,
      onRemove: () {
        if (mounted && identical(token, _openToken)) {
          _menuHistory = null;
          _dismissMenu();
        }
      },
    );
    _menuHistory = entry;
    route.addLocalHistoryEntry(entry);
  }

  bool get _sessionCurrent {
    final state = widget.delegate.state.value;
    return mounted &&
        _ownerCurrent &&
        _openRoute?.isCurrent != false &&
        widget.enabled &&
        widget.active &&
        widget.interactive &&
        state.enabled &&
        !state.maintenance &&
        _openGeneration == _generation &&
        listEquals(_openModels, state.availableModels);
  }

  bool _isOpenSession(Object? token) =>
      token != null &&
      identical(token, _openToken) &&
      _menu.isOpen &&
      _sessionCurrent;

  void _showModels(bool visible) {
    if (_modelsVisible == visible) return;
    _modelsVisible = visible;
    _preview = null;
    _panelGeneration++;
  }

  Future<void> _select(
    AgentModelSelection selection, {
    required Object? openToken,
    required int panelGeneration,
    bool returnToCard = false,
  }) async {
    if (_saving ||
        panelGeneration != _panelGeneration ||
        !_isOpenSession(openToken)) {
      return;
    }
    final state = widget.delegate.state.value;
    if (!state.availableModels.any(
      (m) =>
          m.id == selection.modelId &&
          m.reasoningEfforts.contains(selection.reasoningEffort),
    )) {
      return;
    }
    if (state.selectionFor(widget.conversationId) == selection &&
        !state.runFor(widget.conversationId).requiresModelSelection) {
      setState(() {
        _preview = null;
        _failed = false;
        if (returnToCard) _showModels(false);
      });
      return;
    }
    final generation = _generation;
    final delegate = widget.delegate;
    final id = widget.conversationId;
    setState(() {
      _saving = true;
      _failed = false;
    });
    var saved = false;
    try {
      await delegate.setModelSelection(id, selection);
      saved = true;
    } catch (_) {
      if (mounted && generation == _generation) setState(() => _failed = true);
    } finally {
      if (mounted && generation == _generation) {
        setState(() {
          _saving = false;
          _preview = null;
          if (saved &&
              returnToCard &&
              panelGeneration == _panelGeneration &&
              _isOpenSession(openToken)) {
            _showModels(false);
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<AgentUiState>(
    valueListenable: widget.delegate.state,
    builder: (context, state, _) {
      final anchorScope = AgentModelPickerAnchorScope.maybeOf(context);
      final l = AppLocalizations.of(context);
      final ui = AgentUiStyle.of(context);
      final selection = state.selectionFor(widget.conversationId);
      final defaultSelection = state.defaultModelSelection;
      final model = state.availableModels
          .where((m) => m.id == selection?.modelId)
          .firstOrNull;
      final ready = agentConversationModelReady(state, widget.conversationId);
      final enabled =
          widget.enabled &&
          widget.active &&
          widget.interactive &&
          state.enabled &&
          !state.maintenance &&
          !_saving;
      if (_openGeneration != null && !_sessionCurrent) _invalidateMenu();
      final menuToken = _openToken;
      final panelGeneration = _panelGeneration;
      bool panelCurrent() =>
          panelGeneration == _panelGeneration && _isOpenSession(menuToken);
      final menuStyle = SkedMenuStyle.of(context);
      final bounds = SkedMenuStyle.constraintsFor(
        context,
        requested: const BoxConstraints(maxWidth: 244),
      );
      final width = bounds.maxWidth;
      final height = bounds.maxHeight;
      final efforts = [
        for (final effort in AgentReasoningEffort.values)
          if (model?.reasoningEfforts.contains(effort) == true) effort,
      ];
      final effort = _preview ?? selection?.reasoningEffort;
      final effortLabel = effort == null
          ? l.agentThinkingEffort
          : agentReasoningEffortLabel(l, effort);
      final modelLabel = selection?.modelId ?? l.agentChooseModel;
      final triggerLabel = selection == null
          ? modelLabel
          : '$modelLabel · $effortLabel';
      final effortStyle = ui.title.copyWith(color: ui.foreground);
      final modelHeading = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            label: l.agentThinkingEffort,
            child: Text(
              effortLabel,
              key: const ValueKey('agent-effort-value'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: effortStyle,
            ),
          ),
          Row(
            key: const ValueKey('agent-model-name'),
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  modelLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: ui.label.copyWith(color: ui.muted),
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 16, color: ui.muted),
            ],
          ),
        ],
      );
      final control = SkedMenuAnchor(
        controller: _menu,
        childFocusNode: _focus,
        anchorRectBuilder: anchorScope?._anchorRect,
        manageRouteHistory: false,
        style: menuStyle.compactPanelStyle.copyWith(
          backgroundColor: WidgetStatePropertyAll(ui.popover),
          shape: WidgetStatePropertyAll(ui.popoverShape),
          side: WidgetStatePropertyAll(ui.popoverShape.side),
          elevation: const WidgetStatePropertyAll(2),
          shadowColor: WidgetStatePropertyAll(
            ui.colors.shadow.withValues(alpha: .14),
          ),
          alignment: AlignmentDirectional.bottomEnd,
          maximumSize: WidgetStatePropertyAll(Size(width, height)),
        ),
        crossAxisUnconstrained: false,
        clipBehavior: Clip.antiAlias,
        onClose: _menuClosed,
        onAnimationStatusChanged: _menuAnimationChanged,
        menuChildren: [
          SizedBox(
            // The panel budget includes MenuAnchor's own surface padding.
            // Reserving it here keeps the full border inside the overlay clip.
            width: math.max(0, width - menuStyle.padding.horizontal),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: math.max(0, height - menuStyle.padding.vertical),
              ),
              child: _ModelPanelTransition(
                child: SingleChildScrollView(
                  key: ValueKey(
                    _modelsVisible
                        ? 'agent-model-list-scroll'
                        : 'agent-model-card-scroll',
                  ),
                  primary: false,
                  child: _modelsVisible
                      ? Column(
                          key: const ValueKey('agent-model-list'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  key: const ValueKey('agent-model-list-back'),
                                  tooltip: MaterialLocalizations.of(context)
                                      .backButtonTooltip,
                                  constraints: BoxConstraints.tight(
                                    Size.square(menuStyle.desktop ? 32 : 48),
                                  ),
                                  padding: EdgeInsets.zero,
                                  iconSize: menuStyle.iconSize,
                                  onPressed: _saving
                                      ? null
                                      : () {
                                          if (panelCurrent()) {
                                            setState(() => _showModels(false));
                                          }
                                        },
                                  icon: const Icon(Icons.arrow_back_rounded),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Semantics(
                                    header: true,
                                    child: Text(
                                      l.agentModelSelection,
                                      key: const ValueKey(
                                        'agent-model-list-title',
                                      ),
                                      style: ui.caption.copyWith(
                                        color: ui.muted,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            for (final item in state.availableModels)
                              MenuItemButton(
                                overflowAxis: Axis.vertical,
                                key: ValueKey('agent-model-choice-${item.id}'),
                                style: ui.controlStyle.copyWith(
                                  minimumSize: WidgetStatePropertyAll(
                                    Size.fromHeight(
                                      menuStyle.desktop ? 32 : 48,
                                    ),
                                  ),
                                  padding: WidgetStatePropertyAll(
                                    menuStyle.itemPadding,
                                  ),
                                  backgroundColor:
                                      WidgetStateProperty.resolveWith((states) {
                                        if (states.contains(
                                          WidgetState.disabled,
                                        )) {
                                          return Colors.transparent;
                                        }
                                        if (states.contains(
                                              WidgetState.hovered,
                                            ) ||
                                            states.contains(
                                              WidgetState.focused,
                                            ) ||
                                            states.contains(
                                              WidgetState.pressed,
                                            )) {
                                          return ui.controlStyle.backgroundColor
                                              ?.resolve(states);
                                        }
                                        return item.id == selection?.modelId
                                            ? ui.selected
                                            : Colors.transparent;
                                      }),
                                ),
                                closeOnActivate: false,
                                onPressed: enabled
                                    ? () {
                                        if (!panelCurrent()) return;
                                        unawaited(
                                          _select(
                                            AgentModelSelection(
                                              modelId: item.id,
                                              reasoningEffort:
                                                  selection != null &&
                                                      item.reasoningEfforts
                                                          .contains(
                                                            selection
                                                                .reasoningEffort,
                                                          )
                                                  ? selection.reasoningEffort
                                                  : item.defaultReasoningEffort,
                                            ),
                                            openToken: menuToken,
                                            panelGeneration: panelGeneration,
                                            returnToCard: true,
                                          ),
                                        );
                                      }
                                    : null,
                                child: Semantics(
                                  selected: item.id == selection?.modelId,
                                  child: SkedMenuItemContent(
                                    selected: item.id == selection?.modelId,
                                    child: Text(item.id),
                                  ),
                                ),
                              ),
                            if (_failed)
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    l.agentOperationFailed,
                                    key: const ValueKey(
                                      'agent-model-list-error',
                                    ),
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .error,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        )
                      : Padding(
                          key: const ValueKey('agent-model-panel'),
                          padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _ModelCardHeader(
                                availableWidth: math.max(
                                  0,
                                  width - menuStyle.padding.horizontal - 16,
                                ),
                                resetExtent: menuStyle.desktop ? 32 : 48,
                                effortLabel: effortLabel,
                                effortStyle: effortStyle,
                                heading: Tooltip(
                                  message: '${l.agentModel}: $modelLabel',
                                  child: TextButton(
                                    key: const ValueKey('agent-model-switch'),
                                    style: ui.controlStyle.copyWith(
                                      minimumSize: const WidgetStatePropertyAll(
                                        Size(0, 48),
                                      ),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      padding: const WidgetStatePropertyAll(
                                        EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 2,
                                        ),
                                      ),
                                    ),
                                    onPressed: enabled
                                        ? () {
                                            if (panelCurrent()) {
                                              setState(() => _showModels(true));
                                            }
                                          }
                                        : null,
                                    child: modelHeading,
                                  ),
                                ),
                                reset: IconButton(
                                  key: const ValueKey('agent-effort-reset'),
                                  tooltip: defaultSelection == null
                                      ? l.agentDefaultModel
                                      : '${l.agentDefaultModel} · ${defaultSelection.modelId} · ${agentReasoningEffortLabel(l, defaultSelection.reasoningEffort)}',
                                  constraints: BoxConstraints.tightFor(
                                    width: menuStyle.desktop ? 32 : 48,
                                    height: menuStyle.desktop ? 32 : 48,
                                  ),
                                  padding: EdgeInsets.zero,
                                  iconSize: 20,
                                  style: ui.controlStyle.copyWith(
                                    padding: const WidgetStatePropertyAll(
                                      EdgeInsets.zero,
                                    ),
                                  ),
                                  color: ui.muted,
                                  onPressed:
                                      enabled &&
                                          defaultSelection != null &&
                                          (selection != defaultSelection ||
                                              _preview != null ||
                                              state
                                                  .runFor(widget.conversationId)
                                                  .requiresModelSelection)
                                      ? () {
                                          final currentState =
                                              widget.delegate.state.value;
                                          if (currentState
                                                      .defaultModelSelection !=
                                                  defaultSelection ||
                                              currentState.selectionFor(
                                                    widget.conversationId,
                                                  ) !=
                                                  selection) {
                                            return;
                                          }
                                          unawaited(
                                            _select(
                                              defaultSelection,
                                              openToken: menuToken,
                                              panelGeneration: panelGeneration,
                                            ),
                                          );
                                        }
                                      : null,
                                  icon: const Icon(Icons.restart_alt_rounded),
                                ),
                              ),
                              if (efforts.length > 1)
                                MergeSemantics(
                                  child: Semantics(
                                    label: l.agentThinkingEffort,
                                    child: AgentEffortSlider(
                                      key: ValueKey(model?.id),
                                      slider: Slider(
                                        key: const ValueKey(
                                          'agent-effort-slider',
                                        ),
                                        focusNode: _sliderFocus,
                                        value: math
                                            .max(
                                              0,
                                              efforts.indexOf(
                                                effort ?? efforts.first,
                                              ),
                                            )
                                            .toDouble(),
                                        min: 0,
                                        max: (efforts.length - 1).toDouble(),
                                        divisions: efforts.length - 1,
                                        label: effortLabel,
                                        semanticFormatterCallback: (value) =>
                                            agentReasoningEffortLabel(
                                              l,
                                              efforts[value.round()],
                                            ),
                                        onChanged: enabled && model != null
                                            ? (value) {
                                                if (panelCurrent()) {
                                                  setState(
                                                    () => _preview =
                                                        efforts[value.round()],
                                                  );
                                                }
                                              }
                                            : null,
                                        onChangeEnd: enabled && model != null
                                            ? (value) => unawaited(
                                                _select(
                                                  AgentModelSelection(
                                                    modelId: model.id,
                                                    reasoningEffort:
                                                        efforts[value.round()],
                                                  ),
                                                  openToken: menuToken,
                                                  panelGeneration:
                                                      panelGeneration,
                                                ),
                                              )
                                            : null,
                                      ),
                                    ),
                                  ),
                                ),
                              if (efforts.length == 1 &&
                                  (!ready ||
                                      state
                                          .runFor(widget.conversationId)
                                          .requiresModelSelection) &&
                                  model != null)
                                MenuItemButton(
                                  overflowAxis: Axis.vertical,
                                  key: ValueKey(
                                    'agent-effort-choice-${efforts.single.name}',
                                  ),
                                  style: menuStyle.itemStyle(),
                                  closeOnActivate: false,
                                  onPressed: enabled
                                      ? () => unawaited(
                                          _select(
                                            AgentModelSelection(
                                              modelId: model.id,
                                              reasoningEffort: efforts.single,
                                            ),
                                            openToken: menuToken,
                                            panelGeneration: panelGeneration,
                                          ),
                                        )
                                      : null,
                                  child: Text(
                                    agentReasoningEffortLabel(
                                      l,
                                      efforts.single,
                                    ),
                                  ),
                                ),
                              if (!ready)
                                Text(
                                  l.agentModelSelectionRequired,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              if (_failed)
                                Text(
                                  l.agentOperationFailed,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                            ],
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
        builder: (context, controller, _) => Tooltip(
          message: triggerLabel,
          child: TextButton(
            key: const ValueKey('agent-model-picker'),
            focusNode: _focus,
            style: ui.controlStyle.copyWith(
              minimumSize: WidgetStatePropertyAll(
                Size.square(menuStyle.desktop ? 32 : 48),
              ),
              maximumSize: const WidgetStatePropertyAll(
                Size(320, double.infinity),
              ),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              ),
            ),
            onPressed: enabled && state.availableModels.isNotEmpty
                ? () {
                    if (controller.isOpen) {
                      _dismissMenu();
                      return;
                    }
                    _menuGeneration++;
                    _openGeneration = _generation;
                    final token = _openToken = Object();
                    _openModels = List.of(state.availableModels);
                    _menuGeometry = _readGeometry();
                    _registerMenuHistory(token);
                    setState(() {
                      _showModels(model == null);
                      _preview = null;
                    });
                    controller.open();
                  }
                : null,
            child: Semantics(
              label: '${l.agentModelSelection}: $triggerLabel',
              expanded: controller.isOpen,
              excludeSemantics: true,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final style = ui.label;
                  final textScaler = MediaQuery.textScalerOf(context);
                  double labelWidth(String label) {
                    final measure = TextPainter(
                      text: TextSpan(text: label, style: style),
                      textDirection: Directionality.of(context),
                      textScaler: textScaler,
                    )..layout();
                    final width = measure.width;
                    measure.dispose();
                    return width;
                  }

                  final effortWidth = labelWidth(effortLabel);
                  final minimumModelWidth = math.min(
                    labelWidth(modelLabel),
                    textScaler.scale(32),
                  );
                  // Reserve a readable part of the model before retaining
                  // the inline effort. The full choice stays in the menu,
                  // tooltip and semantic label when this row is narrow.
                  final showEffort =
                      selection != null &&
                      constraints.maxWidth >=
                          minimumModelWidth + effortWidth + 11 + 4 + 16;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        fit: FlexFit.loose,
                        child: Text(
                          modelLabel,
                          textDirection: selection == null
                              ? Directionality.of(context)
                              : TextDirection.ltr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (showEffort) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.circle, size: 3),
                        const SizedBox(width: 4),
                        Text(
                          effortLabel,
                          key: const ValueKey('agent-model-effort-label'),
                          maxLines: 1,
                        ),
                      ],
                      const SizedBox(width: 4),
                      const Icon(Icons.expand_more_rounded, size: 16),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
      final run = state.runFor(widget.conversationId);
      final status = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (run.isActive &&
              run.modelSelection != null &&
              selection != run.modelSelection)
            Text(
              l.agentModelNextRunHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if ((!ready && selection != null) ||
              state.runFor(widget.conversationId).requiresModelSelection)
            Text(
              l.agentModelSelectionRequired,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (_failed)
            Text(
              l.agentOperationFailed,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      );
      return widget.layoutBuilder?.call(control, status) ??
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: control,
              ),
              status,
            ],
          );
    },
  );
}

class _ModelCardHeader extends StatelessWidget {
  const _ModelCardHeader({
    required this.availableWidth,
    required this.resetExtent,
    required this.effortLabel,
    required this.effortStyle,
    required this.heading,
    required this.reset,
  });

  final double availableWidth;
  final double resetExtent;
  final String effortLabel;
  final TextStyle? effortStyle;
  final Widget heading;
  final Widget reset;

  @override
  Widget build(BuildContext context) {
    final measure = TextPainter(
      text: TextSpan(
        text: effortLabel,
        style: DefaultTextStyle.of(context).style.merge(effortStyle),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
      maxLines: 1,
    )..layout();
    // The centered row reserves a reset target on each side and 8dp
    // of horizontal padding inside the model-switch button.
    final stackReset = measure.width > availableWidth - resetExtent * 2 - 8;
    measure.dispose();
    final headingInset = stackReset ? 0.0 : resetExtent;
    return Stack(
      children: [
        Padding(
          padding: EdgeInsets.only(
            top: stackReset ? resetExtent : 0,
            left: headingInset,
            right: headingInset,
          ),
          child: SizedBox(
            width: math.max(0, availableWidth - headingInset * 2),
            child: heading,
          ),
        ),
        PositionedDirectional(top: 0, end: 0, child: reset),
      ],
    );
  }
}

/// Only the current page determines height and receives interaction. Previous
/// pages can fade out without retaining focus, semantic actions or hit targets.
class _ModelPanelTransition extends StatelessWidget {
  const _ModelPanelTransition({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final motion = SkedMotionPolicy.of(context);
    return SkedAnimatedSize(
      key: const ValueKey('agent-model-content-transition'),
      duration: motion.spatialAnimationsEnabled
          ? const Duration(milliseconds: 180)
          : Duration.zero,
      alignment: Alignment.topCenter,
      curve: Curves.easeInOutCubic,
      child: AnimatedSwitcher(
        duration: motion.animationsEnabled
            ? const Duration(milliseconds: 120)
            : Duration.zero,
        reverseDuration: motion.animationsEnabled
            ? const Duration(milliseconds: 120)
            : Duration.zero,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: motion.animationsEnabled
              ? animation
              : const AlwaysStoppedAnimation(1),
          child: child,
        ),
        layoutBuilder: (current, previous) => Stack(
          clipBehavior: Clip.none,
          children: [
            for (final outgoing in previous)
              Positioned.fill(
                key: outgoing.key,
                child: ExcludeSemantics(
                  child: ExcludeFocus(
                    child: IgnorePointer(
                      child: Offstage(
                        offstage: !motion.animationsEnabled,
                        child: outgoing,
                      ),
                    ),
                  ),
                ),
              ),
            ?current,
          ],
        ),
        child: child,
      ),
    );
  }
}
