import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/physics.dart';

import '../theme/sked_expressive_theme.dart';

class ExpressiveTap extends StatefulWidget {
  const ExpressiveTap({
    super.key,
    required this.child,
    required this.onTap,
    this.borderRadius,
    this.scale = 0.985,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final double scale;
  final bool enabled;

  @override
  State<ExpressiveTap> createState() => _ExpressiveTapState();
}

class _ExpressiveTapState extends State<ExpressiveTap> {
  var _pressed = false;

  bool get _enabled => widget.enabled && widget.onTap != null;

  void _setPressed(bool value) {
    if (!_enabled || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  void didUpdateWidget(covariant ExpressiveTap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_enabled && _pressed) {
      _pressed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final motion = SkedMotionPolicy.of(context);
    final borderRadius = widget.borderRadius ?? BorderRadius.circular(16);
    if (!motion.spatialAnimationsEnabled) {
      return Material(
        type: MaterialType.transparency,
        shape: RoundedRectangleBorder(borderRadius: borderRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: borderRadius,
          onTap: _enabled ? widget.onTap : null,
          child: widget.child,
        ),
      );
    }
    return AnimatedScale(
      scale: _pressed ? widget.scale : 1,
      duration: motion.effects(SkedMotionSpeed.fast),
      curve: motion.scheme.enterCurve,
      child: Material(
        type: MaterialType.transparency,
        shape: RoundedRectangleBorder(borderRadius: borderRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: borderRadius,
          onTap: _enabled ? widget.onTap : null,
          onTapDown: (_) => _setPressed(true),
          onTapCancel: () => _setPressed(false),
          onTapUp: (_) => _setPressed(false),
          child: widget.child,
        ),
      ),
    );
  }
}

class ExpressiveSwitcher extends StatelessWidget {
  const ExpressiveSwitcher({super.key, required this.child, this.duration});

  final Widget child;
  final Duration? duration;

  @override
  Widget build(BuildContext context) {
    final motion = SkedMotionPolicy.of(context);
    if (!motion.animationsEnabled) {
      return child;
    }
    return AnimatedSwitcher(
      duration: duration ?? motion.effects(SkedMotionSpeed.standard),
      reverseDuration: motion.effects(SkedMotionSpeed.fast),
      switchInCurve: motion.scheme.enterCurve,
      switchOutCurve: motion.scheme.exitCurve,
      // Outgoing children stay alive during the transition. Keep them out of
      // the accessibility tree so a state change is announced only once.
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.center,
          children: [
            for (final previousChild in previousChildren)
              ExcludeSemantics(child: previousChild),
            ?currentChild,
          ],
        );
      },
      transitionBuilder: (child, animation) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: motion.scheme.enterCurve,
          reverseCurve: motion.scheme.exitCurve,
        );
        if (motion.reduceMotion) {
          return FadeTransition(opacity: curved, child: child);
        }
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// Moves an already-mounted workspace surface into place when its logical
/// period changes. The child is deliberately kept in the same element tree so
/// page controllers, scroll positions, and editor state survive the motion.
///
/// A positive direction means the logical value moved forward; the visual
/// direction is mirrored for RTL layouts. Reduced-motion users receive an
/// opacity-only transition and users who disable animations get the settled
/// child immediately.
class SkedDirectionalTransition extends StatefulWidget {
  const SkedDirectionalTransition({
    super.key,
    required this.trigger,
    required this.child,
    this.direction = 0,
    this.axis = Axis.horizontal,
    this.distance = 24,
    this.fade = true,
    this.scale = true,
  }) : assert(distance >= 0);

  final Object trigger;
  final Widget child;
  final int direction;
  final Axis axis;

  /// The entrance distance in logical pixels.
  final double distance;

  /// Whether the transition uses a short opacity ramp in addition to motion.
  final bool fade;

  /// Whether the transition uses the small depth cue around its translation.
  final bool scale;

  @override
  State<SkedDirectionalTransition> createState() =>
      _SkedDirectionalTransitionState();
}

class _SkedDirectionalTransitionState extends State<SkedDirectionalTransition>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const _settledPositionTolerance = 0.01;
  static const _settledVelocityTolerance = 0.01;

  late final AnimationController _effectsController;
  late final AnimationController _spatialController;
  late final Listenable _animation;
  SkedMotionPolicy? _policy;
  var _spatialGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _effectsController = AnimationController(
      vsync: this,
      value: 1,
      debugLabel: 'SkedDirectionalTransition.effects',
    );
    _spatialController = AnimationController.unbounded(
      vsync: this,
      value: 0,
      debugLabel: 'SkedDirectionalTransition.spatial',
    );
    _animation = Listenable.merge([_effectsController, _spatialController]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _applyPolicy(SkedMotionPolicy.of(context));
  }

  @override
  void didChangeAccessibilityFeatures() {
    if (!mounted) return;
    _applyPolicy(SkedMotionPolicy.of(context));
    setState(() {});
  }

  @override
  void didUpdateWidget(covariant SkedDirectionalTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trigger == widget.trigger &&
        oldWidget.direction == widget.direction) {
      return;
    }

    final policy = SkedMotionPolicy.of(context);
    _applyPolicy(policy);

    // A direction of zero is an explicit request to settle immediately. This
    // is useful when a view changes without a date/period navigation event:
    // the view's own switcher owns that transition and this wrapper must not
    // add a second fade or spatial movement.
    if (widget.direction == 0 ||
        !policy.animationsEnabled ||
        !policy.tickerEnabled) {
      _settleAll();
      return;
    }

    _startEffects(policy);
    if (policy.spatialAnimationsEnabled &&
        widget.distance > 0 &&
        widget.distance.isFinite) {
      _retargetSpatial(_entrancePosition(), policy);
    } else {
      _settleSpatial();
    }
  }

  void _applyPolicy(SkedMotionPolicy nextPolicy) {
    final previousPolicy = _policy;
    _policy = nextPolicy;
    if (!nextPolicy.animationsEnabled || !nextPolicy.tickerEnabled) {
      _settleAll();
      return;
    }
    if (!nextPolicy.spatialAnimationsEnabled ||
        (previousPolicy != null && !previousPolicy.spatialAnimationsEnabled)) {
      // Never keep a hidden translation around while spatial motion is off.
      // Otherwise re-enabling motion could reveal stale position state.
      _settleSpatial();
    }
  }

  void _startEffects(SkedMotionPolicy policy) {
    final effectsNeeded =
        widget.fade || (widget.scale && policy.spatialAnimationsEnabled);
    if (!effectsNeeded) {
      _settleEffects();
      return;
    }

    if (!_effectsController.isAnimating && _effectsController.value >= 0.999) {
      _effectsController.value = 0;
    }
    final remaining = (1 - _effectsController.value).clamp(0.0, 1.0);
    if (remaining <= 0) return;
    final baseDuration = policy.effects(SkedMotionSpeed.standard);
    if (baseDuration == Duration.zero) {
      _settleEffects();
      return;
    }
    final duration = Duration(
      microseconds: (baseDuration.inMicroseconds * remaining).round().clamp(
        1,
        baseDuration.inMicroseconds,
      ),
    );
    unawaited(
      _effectsController.animateTo(
        1,
        duration: duration,
        curve: policy.scheme.enterCurve,
      ),
    );
  }

  double _entrancePosition() {
    final rtlFactor =
        widget.axis == Axis.horizontal &&
            Directionality.of(context) == TextDirection.rtl
        ? -1
        : 1;
    return widget.direction.sign * widget.distance * rtlFactor;
  }

  void _retargetSpatial(double entrance, SkedMotionPolicy policy) {
    final generation = ++_spatialGeneration;
    final settled =
        !_spatialController.isAnimating &&
        _spatialController.value.abs() <= _settledPositionTolerance;
    if (settled) {
      _spatialController.value = entrance;
      _animateSpatialTo(0, policy, generation);
      return;
    }

    // A repeated or reversed navigation starts from the currently rendered
    // position and velocity. It first reaches the new direction's entrance
    // side, then returns to rest, so direction changes remain continuous and
    // legible instead of resetting to a canned tween.
    _animateSpatialTo(
      entrance,
      policy,
      generation,
      onSettled: () => _animateSpatialTo(0, policy, generation),
    );
  }

  void _animateSpatialTo(
    double target,
    SkedMotionPolicy policy,
    int generation, {
    VoidCallback? onSettled,
  }) {
    if (!mounted ||
        generation != _spatialGeneration ||
        !policy.spatialAnimationsEnabled ||
        !policy.tickerEnabled) {
      return;
    }
    final alreadySettled =
        (_spatialController.value - target).abs() <=
            _settledPositionTolerance &&
        _spatialController.velocity.abs() <= _settledVelocityTolerance;
    if (alreadySettled) {
      _spatialController.value = target;
      onSettled?.call();
      return;
    }
    final simulation = SpringSimulation(
      policy.spatial(SkedMotionSpeed.standard),
      _spatialController.value,
      target,
      _spatialController.velocity,
      snapToEnd: true,
    );
    _spatialController.animateWith(simulation).whenCompleteOrCancel(() {
      if (!mounted || generation != _spatialGeneration) return;
      final currentPolicy = _policy ?? SkedMotionPolicy.of(context);
      if (!currentPolicy.spatialAnimationsEnabled ||
          !currentPolicy.tickerEnabled) {
        _settleSpatial();
        return;
      }
      _spatialController.value = target;
      onSettled?.call();
    });
  }

  void _settleEffects() {
    _effectsController
      ..stop(canceled: true)
      ..value = 1;
  }

  void _settleSpatial() {
    _spatialGeneration++;
    _spatialController
      ..stop(canceled: true)
      ..value = 0;
  }

  void _settleAll() {
    _settleEffects();
    _settleSpatial();
  }

  @override
  Widget build(BuildContext context) {
    final policy = SkedMotionPolicy.of(context);
    return ClipRect(
      child: AnimatedBuilder(
        animation: _animation,
        child: widget.child,
        builder: (context, child) {
          final progress = _effectsController.value.clamp(0.0, 1.0);
          final spatial = policy.spatialAnimationsEnabled;
          final position = spatial ? _spatialController.value : 0.0;
          final offset = widget.axis == Axis.horizontal
              ? Offset(position, 0)
              : Offset(0, position);
          final opacity = widget.fade && policy.animationsEnabled
              ? 0.72 + 0.28 * progress
              : 1.0;
          final scale = widget.scale && spatial
              ? 0.985 + 0.015 * progress
              : 1.0;
          return Opacity(
            key: const ValueKey('sked-directional-transition-opacity'),
            opacity: opacity,
            child: Transform.translate(
              key: const ValueKey('sked-directional-transition-offset'),
              offset: offset,
              child: Transform.scale(scale: scale, child: child),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _spatialGeneration++;
    _effectsController.dispose();
    _spatialController.dispose();
    super.dispose();
  }
}
