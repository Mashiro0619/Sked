import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../models/agent_settings.dart';
import '../../theme/sked_expressive_theme.dart';
import '../../theme/sked_menu_style.dart';
import '../../theme/sked_surface.dart';
import '../../widgets/sked_menu_item_content.dart';
import 'agent_model_labels.dart';
import 'agent_ui_delegate.dart';

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

  Future<void> _select(
    AgentModelSelection selection, {
    required Object? openToken,
  }) async {
    if (_saving || !_isOpenSession(openToken)) return;
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
      setState(() => _preview = null);
      return;
    }
    final generation = _generation;
    final delegate = widget.delegate;
    final id = widget.conversationId;
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await delegate.setModelSelection(id, selection);
    } catch (_) {
      if (mounted && generation == _generation) setState(() => _failed = true);
    } finally {
      if (mounted && generation == _generation) {
        setState(() {
          _saving = false;
          _preview = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<AgentUiState>(
    valueListenable: widget.delegate.state,
    builder: (context, state, _) {
      final l = AppLocalizations.of(context);
      final selection = state.selectionFor(widget.conversationId);
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
      final menuStyle = SkedMenuStyle.of(context);
      final bounds = SkedMenuStyle.constraintsFor(
        context,
        requested: const BoxConstraints(maxWidth: 280),
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
      final canSwitchModel = state.availableModels.length > 1 || model == null;
      final modelHeading = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            label: l.agentThinkingEffort,
            child: Text(
              effortLabel,
              key: const ValueKey('agent-effort-value'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: menuStyle.selectedForeground,
                fontWeight: FontWeight.w600,
              ),
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
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (canSwitchModel)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ],
      );
      final control = MenuAnchor(
        controller: _menu,
        childFocusNode: _focus,
        animated: SkedMotionPolicy.of(context).spatialAnimationsEnabled,
        style: menuStyle.menuStyle.copyWith(
          maximumSize: WidgetStatePropertyAll(Size(width, height)),
          backgroundColor: WidgetStatePropertyAll(
            Theme.of(context).colorScheme.surfaceContainerHigh,
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: menuStyle.outline.withValues(alpha: .5)),
            ),
          ),
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
              child: SingleChildScrollView(
                primary: false,
                child: _modelsVisible
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          MenuItemButton(
                            style: menuStyle.itemStyle(),
                            closeOnActivate: false,
                            onPressed: _saving
                                ? null
                                : () {
                                    if (_isOpenSession(menuToken)) {
                                      setState(() => _modelsVisible = false);
                                    }
                                  },
                            leadingIcon: const Icon(Icons.arrow_back_rounded),
                            child: Text(l.agentModelSelection),
                          ),
                          for (final item in state.availableModels)
                            MenuItemButton(
                              key: ValueKey('agent-model-choice-${item.id}'),
                              style: menuStyle.itemStyle(
                                selected: item.id == selection?.modelId,
                              ),
                              closeOnActivate: false,
                              onPressed: enabled
                                  ? () {
                                      if (!_isOpenSession(menuToken)) return;
                                      setState(() => _modelsVisible = false);
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
                        ],
                      )
                    : Padding(
                        key: const ValueKey('agent-model-panel'),
                        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: menuStyle.desktop ? 32 : 48,
                                  height: menuStyle.desktop ? 32 : 48,
                                  child: ExcludeSemantics(
                                    child: Icon(
                                      Icons.bolt_outlined,
                                      size: 20,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Tooltip(
                                    message: '${l.agentModel}: $modelLabel',
                                    child: canSwitchModel
                                        ? TextButton(
                                            key: const ValueKey(
                                              'agent-model-switch',
                                            ),
                                            style: TextButton.styleFrom(
                                              minimumSize: const Size(0, 48),
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 4,
                                                    vertical: 2,
                                                  ),
                                            ),
                                            onPressed: enabled
                                                ? () {
                                                    if (_isOpenSession(
                                                      menuToken,
                                                    )) {
                                                      setState(
                                                        () => _modelsVisible =
                                                            true,
                                                      );
                                                    }
                                                  }
                                                : null,
                                            child: modelHeading,
                                          )
                                        : Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 2,
                                            ),
                                            child: modelHeading,
                                          ),
                                  ),
                                ),
                                IconButton(
                                  key: const ValueKey('agent-effort-reset'),
                                  tooltip: model == null
                                      ? l.agentDefaultEffort
                                      : '${l.agentDefaultEffort}: ${agentReasoningEffortLabel(l, model.defaultReasoningEffort)}',
                                  constraints: BoxConstraints.tightFor(
                                    width: menuStyle.desktop ? 32 : 48,
                                    height: menuStyle.desktop ? 32 : 48,
                                  ),
                                  padding: EdgeInsets.zero,
                                  iconSize: 20,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  onPressed:
                                      enabled &&
                                          model != null &&
                                          (effort !=
                                                  model
                                                      .defaultReasoningEffort ||
                                              _preview != null ||
                                              !ready)
                                      ? () {
                                          if (widget.delegate.state.value
                                                  .selectionFor(
                                                    widget.conversationId,
                                                  )
                                                  ?.modelId !=
                                              model.id) {
                                            return;
                                          }
                                          unawaited(
                                            _select(
                                              model.defaultSelection,
                                              openToken: menuToken,
                                            ),
                                          );
                                        }
                                      : null,
                                  icon: const Icon(Icons.restart_alt_rounded),
                                ),
                              ],
                            ),
                            if (efforts.length > 1)
                              SliderTheme(
                                data: _compactEffortSliderTheme(context),
                                child: MergeSemantics(
                                  child: Semantics(
                                    label: l.agentThinkingEffort,
                                    child: Slider(
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
                                              if (_isOpenSession(menuToken)) {
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
                                        ),
                                      )
                                    : null,
                                child: Text(
                                  agentReasoningEffortLabel(l, efforts.single),
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
        ],
        builder: (context, controller, _) => Tooltip(
          message: triggerLabel,
          child: Semantics(
            button: true,
            enabled: enabled && state.availableModels.isNotEmpty,
            label: '${l.agentModelSelection}: $triggerLabel',
            expanded: controller.isOpen,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                key: const ValueKey('agent-model-picker'),
                focusNode: _focus,
                customBorder: skedShapeSchemeOf(context).selection,
                onTap: enabled && state.availableModels.isNotEmpty
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
                          _modelsVisible = model == null;
                          _preview = null;
                        });
                        controller.open();
                      }
                    : null,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: menuStyle.desktop ? 32 : 48,
                    maxWidth: 320,
                    minHeight: menuStyle.desktop ? 32 : 48,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final style = Theme.of(context).textTheme.labelLarge;
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
                                style: style,
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
                                style: style,
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
            ),
          ),
        ),
      );
      final status = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state.runFor(widget.conversationId).isActive)
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

SliderThemeData _compactEffortSliderTheme(BuildContext context) {
  final colors = Theme.of(context).colorScheme;
  final track = skedReadableAccent(colors, surface: Colors.white);
  return SliderTheme.of(context).copyWith(
    trackHeight: 26,
    trackShape: const RoundedRectSliderTrackShape(),
    trackGap: 0,
    thumbShape: const RoundSliderThumbShape(
      enabledThumbRadius: 14,
      elevation: 1,
      pressedElevation: 2,
    ),
    thumbColor: Colors.white,
    activeTrackColor: track,
    inactiveTrackColor: colors.onSurface.withValues(alpha: .12),
    tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 2),
    activeTickMarkColor: Colors.white.withValues(alpha: .45),
    inactiveTickMarkColor: colors.onSurface.withValues(alpha: .35),
    overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
    padding: const EdgeInsets.symmetric(vertical: 10),
    showValueIndicator: ShowValueIndicator.never,
  );
}
