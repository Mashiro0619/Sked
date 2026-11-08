import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/sked_expressive_theme.dart';
import '../../widgets/sked_popup_menu.dart';
import '../../theme/sked_menu_style.dart';
import 'agent_ui_delegate.dart';
import 'agent_ui_style.dart';

class AgentContextControl extends StatelessWidget {
  const AgentContextControl({
    super.key,
    required this.usage,
    this.onCompact,
    this.moreMenu = false,
    this.attachLabel,
    this.onAttach,
    this.enabled = true,
    this.canAttach = true,
    this.canCompact = true,
  });
  final AgentContextUsage? usage;
  final VoidCallback? onCompact;
  final bool moreMenu;
  final String? attachLabel;
  final VoidCallback? onAttach;
  final bool enabled;
  final bool canAttach;
  final bool canCompact;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ui = AgentUiStyle.of(context);
    final estimated = usage?.estimatedTokens;
    final window = usage?.maxContextTokens;
    final compacting = usage?.isCompacting == true;
    final queued = usage?.isCompactionQueued == true;
    final failed = usage?.errorMessage != null;
    final description =
        '${l.agentContextEstimated}: ${estimated ?? l.agentContextUnset}'
        ' / ${window ?? l.agentContextUnset} Token';
    return SkedPopupMenuButton<String>(
      key: ValueKey(moreMenu ? 'agent-composer-more' : 'agent-context-control'),
      padding: EdgeInsets.all(SkedMenuStyle.of(context).desktop ? 6 : 8),
      style: ui.controlStyle,
      enabled: enabled && (moreMenu || onCompact != null),
      tooltip: moreMenu
          ? l.more
          : compacting
          ? l.agentCompactingContext
          : queued
          ? l.agentCompactionQueued
          : failed
          ? l.agentOperationFailed
          : description,
      icon: moreMenu
          ? const Icon(Icons.add_rounded)
          : SizedBox.square(
              dimension: 18,
              child: compacting
                  ? const CircularProgressIndicator(strokeWidth: 2)
                  : failed
                  ? Icon(
                      Icons.error_outline_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.error,
                    )
                  : window != null && estimated != null
                  ? CircularProgressIndicator(
                      value: (estimated / window).clamp(0.0, 1.0),
                      strokeWidth: 2,
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .outlineVariant,
                    )
                  : const Icon(Icons.data_usage_rounded, size: 18),
            ),
      onSelected: (value) {
        if (value == 'attach') onAttach?.call();
        if (value == 'compact') onCompact?.call();
      },
      itemBuilder: (context) => [
        if (attachLabel case final label?) ...[
          PopupMenuItem<String>(
            key: const ValueKey('agent-attach-file'),
            value: 'attach',
            enabled: onAttach != null && canAttach,
            child: Text(label),
          ),
          const PopupMenuDivider(),
        ],
        if (usage?.modelId case final model?)
          PopupMenuItem<String>(
            enabled: false,
            child: Text('${l.agentModel}: $model'),
          ),
        PopupMenuItem<String>(enabled: false, child: Text(description)),
        if (usage?.reportedInputTokens case final reported?)
          PopupMenuItem<String>(
            enabled: false,
            child: Text('${l.agentContextReported}: $reported Token'),
          ),
        PopupMenuItem<String>(
          enabled: false,
          child: Text(
            '${l.agentContextThreshold}: '
            '${usage?.autoCompactAtTokens ?? l.agentContextUnset} Token',
          ),
        ),
        if (usage?.errorMessage != null)
          PopupMenuItem<String>(
            enabled: false,
            child: Text(l.agentOperationFailed),
          ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          key: const ValueKey('agent-compact-context'),
          value: 'compact',
          enabled: onCompact != null && canCompact && !compacting && !queued,
          child: Text(
            compacting
                ? l.agentCompactingContext
                : queued
                ? l.agentCompactionQueued
                : l.agentCompactContext,
          ),
        ),
      ],
    );
  }
}

/// The current request estimate stays beside the model; its actions share More.
class AgentContextIndicator extends StatelessWidget {
  const AgentContextIndicator({
    super.key,
    required this.usage,
    this.enabled = true,
  });
  final AgentContextUsage? usage;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final current = usage;
    final l = AppLocalizations.of(context);
    final estimated = current?.estimatedTokens;
    final window = current?.maxContextTokens;
    final knownEstimate = estimated != null && estimated >= 0;
    final knownWindow = window != null && window > 0;
    final ratio =
        estimated != null && estimated >= 0 && window != null && window > 0
        ? estimated / window
        : null;
    final usedPercent = ratio == null ? null : (ratio * 100).round();
    final remainingPercent = usedPercent == null
        ? null
        : (100 - usedPercent).clamp(0, 100);
    final compacting = current?.isCompacting == true;
    final queued = current?.isCompactionQueued == true;
    final failed = current?.errorMessage != null;
    final status = compacting
        ? l.agentCompactingContext
        : queued
        ? l.agentCompactionQueued
        : failed
        ? l.agentOperationFailed
        : null;
    final utilization = usedPercent == null || remainingPercent == null
        ? null
        : l.agentContextUtilization('$usedPercent', '$remainingPercent');
    final tokenUsage = knownWindow
        ? '${l.agentContextEstimated}: ${l.agentContextTokenUsage(knownEstimate ? '$estimated' : l.agentContextUnset, '$window')}'
        : '${l.agentContextEstimated}: ${knownEstimate ? '$estimated Token' : l.agentContextUnset}';
    final capacity = knownWindow
        ? null
        : '${l.agentContextWindow}: ${l.agentContextUnset}';
    final description = [
      l.agentContextTitle,
      ?status,
      ?utilization,
      tokenUsage,
      ?capacity,
    ].join('\n');
    final desktop = SkedMenuStyle.of(context).desktop;
    final motion = SkedMotionPolicy.of(context);
    final ui = AgentUiStyle.of(context);
    final bounds = SkedMenuStyle.availableRectOf(context);
    final indicator = SizedBox(
      width: desktop ? 24 : 32,
      height: desktop ? 32 : 48,
      child: Center(
        child: ExcludeSemantics(
          child: SizedBox.square(
            key: const ValueKey('agent-context-ring'),
            dimension: 14,
            child: failed && !compacting
                ? Icon(
                    Icons.error_outline_rounded,
                    size: 14,
                    color: ui.colors.error,
                  )
                : CircularProgressIndicator(
                    value: compacting
                        ? (motion.spatialAnimationsEnabled ? null : 0.75)
                        : (ratio ?? 0).clamp(0.0, 1.0),
                    strokeWidth: 2,
                    padding: EdgeInsets.zero,
                    trackGap: 0,
                    color: ui.muted,
                    backgroundColor: ui.muted.withValues(alpha: .45),
                  ),
          ),
        ),
      ),
    );
    final active =
        enabled &&
        TickerMode.valuesOf(context).enabled &&
        ModalRoute.isCurrentOf(context) != false;
    // Keep the overlay traversal anchor in its own semantics container.
    return Semantics(
      key: const ValueKey('agent-context-indicator'),
      container: true,
      child: !active
          ? indicator
          : _ContextCardAnchor(
              description: description,
              duration: motion.effects(SkedMotionSpeed.fast),
              bounds: bounds,
              cardBuilder: (scroll) => ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: math.min(272, bounds.width),
                  maxHeight: bounds.height,
                ),
                child: Material(
                  key: const ValueKey('agent-context-card'),
                  color: ui.popover,
                  elevation: 2,
                  shadowColor: ui.colors.shadow.withValues(alpha: .14),
                  surfaceTintColor: Colors.transparent,
                  shape: ui.popoverShape,
                  clipBehavior: Clip.antiAlias,
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context)
                        .copyWith(scrollbars: false),
                    child: Scrollbar(
                      controller: scroll,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: scroll,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              l.agentContextTitle,
                              textAlign: TextAlign.center,
                              style: ui.caption.copyWith(color: ui.muted),
                            ),
                            const SizedBox(height: 4),
                            if (utilization != null) ...[
                              Text(
                                utilization,
                                textAlign: TextAlign.center,
                                style: ui.label.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                            ],
                            Text(
                              tokenUsage,
                              textAlign: TextAlign.center,
                              style: ui.caption.copyWith(color: ui.muted),
                            ),
                            if (capacity != null)
                              Text(
                                capacity,
                                textAlign: TextAlign.center,
                                style: ui.caption.copyWith(color: ui.muted),
                              ),
                            if (status != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                status,
                                textAlign: TextAlign.center,
                                style: ui.caption.copyWith(
                                  color: failed ? ui.colors.error : ui.muted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              child: indicator,
            ),
    );
  }
}

/// A readable card keeps touch interaction inside its own tap region. Hover
/// remains transient, while an explicit tap keeps it open until an outside tap.
class _ContextCardAnchor extends StatefulWidget {
  const _ContextCardAnchor({
    required this.description,
    required this.duration,
    required this.bounds,
    required this.cardBuilder,
    required this.child,
  });

  final String description;
  final Duration duration;
  final Rect bounds;
  final Widget Function(ScrollController) cardBuilder;
  final Widget child;

  @override
  State<_ContextCardAnchor> createState() => _ContextCardAnchorState();
}

class _ContextCardAnchorState extends State<_ContextCardAnchor>
    with SingleTickerProviderStateMixin {
  final _overlay = OverlayPortalController();
  final _tapRegion = Object();
  final _scroll = ScrollController();
  final _cardPointers = <int>{};
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..addStatusListener(_animationChanged);
  Timer? _hoverTimer;
  Timer? _dismissTimer;
  bool _visible = false;
  bool _pinned = false;
  bool _triggerHovered = false;
  bool _cardHovered = false;

  @override
  void didUpdateWidget(_ContextCardAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    _animation.duration = widget.duration;
  }

  void _animationChanged(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && !_visible) _overlay.hide();
  }

  void _show({bool pinned = false}) {
    if (!mounted) return;
    _hoverTimer?.cancel();
    _dismissTimer?.cancel();
    _pinned = _pinned || pinned;
    setState(() => _visible = true);
    _overlay.show();
    _animation.forward();
  }

  void _dismiss() {
    _hoverTimer?.cancel();
    _dismissTimer?.cancel();
    _pinned = false;
    if (!_visible) return;
    setState(() => _visible = false);
    if (_animation.isDismissed) {
      _overlay.hide();
    } else {
      _animation.reverse();
    }
  }

  void _enter({required bool card}) {
    if (card) {
      _cardHovered = true;
    } else {
      _triggerHovered = true;
    }
    _dismissTimer?.cancel();
    _hoverTimer?.cancel();
    if (_overlay.isShowing) {
      _show();
    } else {
      _hoverTimer = Timer(const Duration(milliseconds: 600), _show);
    }
  }

  void _exit({required bool card}) {
    if (card) {
      _cardHovered = false;
    } else {
      _triggerHovered = false;
    }
    _scheduleHoverDismiss();
  }

  void _scheduleHoverDismiss() {
    if (_triggerHovered ||
        _cardHovered ||
        _pinned ||
        _cardPointers.isNotEmpty) {
      return;
    }
    _hoverTimer?.cancel();
    _dismissTimer?.cancel();
    _dismissTimer = Timer(const Duration(milliseconds: 200), _dismiss);
  }

  void _endCardPointer(int pointer) {
    _cardPointers.remove(pointer);
    _scheduleHoverDismiss();
  }

  Widget _region({required bool card, required Widget child}) => TapRegion(
    groupId: _tapRegion,
    onTapOutside: card ? null : (_) => _dismiss(),
    child: MouseRegion(
      onEnter: (_) => _enter(card: card),
      onExit: (_) => _exit(card: card),
      child: card
          ? Listener(
              onPointerDown: (event) {
                _cardPointers.add(event.pointer);
                _dismissTimer?.cancel();
              },
              onPointerUp: (event) => _endCardPointer(event.pointer),
              onPointerCancel: (event) => _endCardPointer(event.pointer),
              child: child,
            )
          : child,
    ),
  );

  @override
  void dispose() {
    _hoverTimer?.cancel();
    _dismissTimer?.cancel();
    _animation.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OverlayPortal.overlayChildLayoutBuilder(
    controller: _overlay,
    overlayChildBuilder: (context, layout) {
      if (layout.childPaintTransform.determinant() == 0) {
        return const SizedBox.shrink();
      }
      final target = MatrixUtils.transformRect(
        layout.childPaintTransform,
        Offset.zero & layout.childSize,
      );
      return Positioned.fill(
        bottom: MediaQuery.maybeViewInsetsOf(context)?.bottom ?? 0,
        child: CustomSingleChildLayout(
          delegate: _ContextCardPosition(target: target, bounds: widget.bounds),
          child: IgnorePointer(
            ignoring: !_visible,
            child: ExcludeSemantics(
              excluding: !_visible,
              child: FadeTransition(
                opacity: _animation,
                child: _region(
                  card: true,
                  child: SelectionContainer.disabled(
                    child: widget.cardBuilder(_scroll),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
    child: _region(
      card: false,
      child: Semantics(
        button: true,
        expanded: _visible,
        tooltip: widget.description,
        onTap: () => _show(pinned: true),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: () => _show(pinned: true),
          child: widget.child,
        ),
      ),
    ),
  );
}

class _ContextCardPosition extends SingleChildLayoutDelegate {
  const _ContextCardPosition({required this.target, required this.bounds});
  final Rect target;
  final Rect bounds;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(
        Size(
          math.min(constraints.maxWidth, bounds.width),
          math.min(constraints.maxHeight, bounds.height),
        ),
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final top = target.top - 6 - childSize.height;
    final y = top >= bounds.top ? top : target.bottom + 6;
    return Offset(
      (target.center.dx - childSize.width / 2).clamp(
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
  bool shouldRelayout(_ContextCardPosition oldDelegate) =>
      target != oldDelegate.target || bounds != oldDelegate.bounds;
}
