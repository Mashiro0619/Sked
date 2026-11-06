import 'dart:math' as math;
import 'dart:ui' show SemanticsRole;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/sked_expressive_theme.dart';
import '../theme/sked_menu_style.dart';
import 'sked_menu_surface.dart';

/// An anchored menu with one interruptible transition for its entire surface.
class SkedMenuAnchor extends StatefulWidget {
  const SkedMenuAnchor({
    super.key,
    this.controller,
    this.childFocusNode,
    this.onOpen,
    this.onClose,
    this.onAnimationStatusChanged,
    this.style,
    this.alignmentOffset = Offset.zero,
    this.crossAxisUnconstrained = true,
    this.clipBehavior = Clip.antiAlias,
    this.manageRouteHistory = true,
    required this.menuChildren,
    this.child,
    this.builder,
  });

  final MenuController? controller;
  final FocusNode? childFocusNode;
  final VoidCallback? onOpen;
  final VoidCallback? onClose;
  final ValueChanged<AnimationStatus>? onAnimationStatusChanged;
  final MenuStyle? style;
  final Offset alignmentOffset;
  final bool crossAxisUnconstrained;
  final Clip clipBehavior;
  final bool manageRouteHistory;
  final List<Widget> menuChildren;
  final Widget? child;
  final RawMenuAnchorChildBuilder? builder;

  @override
  State<SkedMenuAnchor> createState() => _SkedMenuAnchorState();
}

class _SkedMenuAnchorState extends State<SkedMenuAnchor>
    with SingleTickerProviderStateMixin {
  final _internalMenu = MenuController();
  final _focus = FocusScopeNode(
    debugLabel: 'Sked menu',
    traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
    directionalTraversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
  );
  late final AnimationController _animation;
  late MenuController _menu;
  SkedMotionPolicy? _motion;
  AnimationStatus _reportedStatus = AnimationStatus.dismissed;
  LocalHistoryEntry? _history;
  VoidCallback? _hideOverlay;
  Alignment? _alignment;
  Object _contentSession = Object();
  bool _closing = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _menu = widget.controller ?? _internalMenu;
    _animation = AnimationController(vsync: this)
      ..addStatusListener(_statusChanged);
  }

  @override
  void didUpdateWidget(SkedMenuAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _generation++;
      _animation.stop();
      _animation.value = 0;
      _hideOverlay = null;
      _closing = false;
      _removeHistory();
      _menu = widget.controller ?? _internalMenu;
      _alignment = null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final previousMotion = _motion;
    final motion = SkedMotionPolicy.of(context);
    _motion = motion;
    final motionChanged =
        previousMotion == null ||
        previousMotion.animationsEnabled != motion.animationsEnabled ||
        previousMotion.reduceMotion != motion.reduceMotion;
    if (_menu.isOpen) {
      final generation = _generation;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || generation != _generation || !_menu.isOpen) return;
        if (ModalRoute.isCurrentOf(context) == false || !motion.tickerEnabled) {
          _menu.close();
        } else if (motionChanged) {
          _driveAnimation();
        }
      });
    }
  }

  void _emitStatus(AnimationStatus status) {
    if (_reportedStatus == status) return;
    _reportedStatus = status;
    widget.onAnimationStatusChanged?.call(status);
  }

  void _statusChanged(AnimationStatus status) {
    _emitStatus(status);
  }

  void _opened() {
    if (widget.manageRouteHistory && _history == null) {
      final route = ModalRoute.of(context);
      if (route != null) {
        late final LocalHistoryEntry entry;
        entry = LocalHistoryEntry(
          impliesAppBarDismissal: false,
          onRemove: () {
            if (!mounted || !identical(_history, entry)) return;
            _history = null;
            _menu.close();
          },
        );
        _history = entry;
        route.addLocalHistoryEntry(entry);
      }
    }
    widget.onOpen?.call();
    final generation = _generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _generation || _closing || !_menu.isOpen) {
        return;
      }
      if (_focus.context == null) return;
      // Opening gives the menu keyboard ownership. Item focus starts when the
      // user navigates, so a pointer-opened selection keeps its selected color.
      _focus.requestScopeFocus();
    });
  }

  void _removeHistory() {
    final history = _history;
    _history = null;
    history?.remove();
  }

  void _openRequested(Offset? position, VoidCallback showOverlay) {
    if (ModalRoute.isCurrentOf(context) == false) return;
    final alreadyOpen = _menu.isOpen;
    if (alreadyOpen && !_closing) return;
    _generation++;
    _contentSession = Object();
    _closing = false;
    _hideOverlay = null;
    _focus.descendantsAreFocusable = true;
    _focus.descendantsAreTraversable = true;
    if (alreadyOpen) {
      // Calling showOverlay again would close and recreate the native overlay.
      _opened();
    } else {
      _alignment = null;
      showOverlay();
    }
    setState(() {});
    _emitStatus(AnimationStatus.forward);
    _driveAnimation();
  }

  void _closeRequested(VoidCallback hideOverlay) {
    if (!_menu.isOpen || _closing) return;
    _generation++;
    _closing = true;
    _hideOverlay = hideOverlay;
    _focus.descendantsAreFocusable = false;
    _focus.descendantsAreTraversable = false;
    _removeHistory();
    // Retire business callbacks synchronously, including zero-duration closes.
    _emitStatus(AnimationStatus.reverse);
    setState(() {});
    _driveAnimation();
  }

  void _driveAnimation() {
    final generation = _generation;
    final target = _closing ? 0.0 : 1.0;
    final duration = SkedMenuMotion.duration(_motion!, reverse: _closing);
    final remaining = (target - _animation.value).abs();
    if (duration == Duration.zero || remaining == 0) {
      _animation.value = target;
      if (_closing) _hideOverlay?.call();
      return;
    }
    final scaled = Duration(
      microseconds: math.max(1, (duration.inMicroseconds * remaining).round()),
    );
    final future = _closing
        ? _animation.animateBack(0, duration: scaled, curve: Curves.linear)
        : _animation.animateTo(1, duration: scaled, curve: Curves.linear);
    future.whenCompleteOrCancel(() {
      if (mounted &&
          generation == _generation &&
          _closing &&
          _animation.value == 0) {
        _hideOverlay?.call();
      }
    });
  }

  void _closed() {
    _generation++;
    _hideOverlay = null;
    _closing = false;
    _removeHistory();
    _emitStatus(AnimationStatus.dismissed);
    widget.onClose?.call();
    if (mounted) setState(() {});
  }

  @override
  void deactivate() {
    if (_menu.isOpen) {
      _generation++;
      _emitStatus(AnimationStatus.reverse);
      _removeHistory();
      _menu.close();
    }
    super.deactivate();
  }

  @override
  void dispose() {
    _generation++;
    _removeHistory();
    _animation.dispose();
    _focus.dispose();
    super.dispose();
  }

  BoxConstraints _constraints(BuildContext context) {
    const states = <WidgetState>{};
    final minimum = widget.style?.minimumSize?.resolve(states);
    final maximum = widget.style?.maximumSize?.resolve(states);
    final fixed = widget.style?.fixedSize?.resolve(states);
    final fixedWidth = fixed?.width.isFinite == true ? fixed!.width : null;
    final fixedHeight = fixed?.height.isFinite == true ? fixed!.height : null;
    return SkedMenuStyle.constraintsFor(
      context,
      requested: BoxConstraints(
        minWidth: fixedWidth ?? minimum?.width ?? SkedMenuStyle.minimumWidth,
        maxWidth: fixedWidth ?? maximum?.width ?? SkedMenuStyle.maximumWidth,
        minHeight: fixedHeight ?? minimum?.height ?? 0,
        maxHeight:
            fixedHeight ?? maximum?.height ?? SkedMenuStyle.maximumHeight,
      ),
    );
  }

  Widget _overlay(BuildContext context, RawMenuOverlayInfo info) {
    final generation = _generation;
    final offset = widget.alignmentOffset + (info.position ?? Offset.zero);
    final anchor = info.anchorRect.shift(offset);
    final body = SingleChildScrollView(
      primary: false,
      clipBehavior: widget.clipBehavior,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: widget.menuChildren,
      ),
    );
    return SizedBox.fromSize(
      size: info.overlaySize,
      child: CustomSingleChildLayout(
        delegate: SkedMenuLayoutDelegate(
          anchor: anchor,
          available: SkedMenuStyle.availableRectOf(context),
          textDirection: Directionality.of(context),
          anchorAlignment: widget.style?.alignment,
          constraints: _constraints(context),
          preferredAlignment: _alignment,
          onAlignment: (alignment) {
            if (mounted &&
                generation == _generation &&
                _menu.isOpen &&
                alignment != _alignment) {
              setState(() => _alignment = alignment);
            }
          },
        ),
        child: TapRegion(
          groupId: info.tapRegionGroupId,
          onTapOutside: (_) => _menu.close(),
          child: FocusTraversalGroup(
            policy: ReadingOrderTraversalPolicy(),
            // Keep shortcuts above the scope itself. Removing a focused page
            // control returns focus to this scope, which must still handle keys
            // before a surrounding workspace's shortcuts can consume them.
            child: Shortcuts(
              shortcuts: const {
                SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
                SingleActivator(LogicalKeyboardKey.tab): NextFocusIntent(),
                SingleActivator(LogicalKeyboardKey.tab, shift: true):
                    PreviousFocusIntent(),
                SingleActivator(LogicalKeyboardKey.arrowDown):
                    NextFocusIntent(),
                SingleActivator(LogicalKeyboardKey.arrowUp):
                    PreviousFocusIntent(),
              },
              child: Actions(
                actions: {
                  DismissIntent: CallbackAction<DismissIntent>(
                    onInvoke: (_) {
                      _menu.close();
                      return null;
                    },
                  ),
                },
                child: FocusScope(
                  node: _focus,
                  skipTraversal: true,
                  child: SkedMenuSurface(
                    animation: _animation,
                    motion: _motion!,
                    alignment: _alignment ?? Alignment.topLeft,
                    style: widget.style,
                    closing: _closing,
                    child: Semantics(
                      role: SemanticsRole.menu,
                      explicitChildNodes: true,
                      child: KeyedSubtree(
                        key: ObjectKey(_contentSession),
                        child: IntrinsicWidth(child: body),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => RawMenuAnchor(
    key: ObjectKey(_menu),
    controller: _menu,
    childFocusNode: widget.childFocusNode,
    onOpenRequested: _openRequested,
    onCloseRequested: _closeRequested,
    onOpen: _opened,
    onClose: _closed,
    overlayBuilder: _overlay,
    builder: widget.builder,
    child: widget.child,
  );
}
