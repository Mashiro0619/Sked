import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/physics.dart';

import '../theme/sked_expressive_theme.dart';

typedef SkedSpringWidgetBuilder = Widget Function(
  BuildContext context,
  double value,
  Widget? child,
);

/// Drives a scalar spatial transition with a retargetable spring.
///
/// The controller is intentionally unbounded: spatial values may briefly
/// overshoot, while callers decide how to clamp values used for colors or
/// opacity. Retargeting captures the current velocity, which keeps quick
/// reversals from stopping and restarting at an artificial zero velocity.
class SkedSpringBuilder extends StatefulWidget {
  const SkedSpringBuilder({
    super.key,
    required this.value,
    required this.builder,
    this.speed = SkedMotionSpeed.standard,
    this.child,
    this.onEnd,
  });

  final double value;
  final SkedSpringWidgetBuilder builder;
  final SkedMotionSpeed speed;
  final Widget? child;
  final VoidCallback? onEnd;

  @override
  State<SkedSpringBuilder> createState() => _SkedSpringBuilderState();
}

class _SkedSpringBuilderState extends State<SkedSpringBuilder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  SkedMotionPolicy? _policy;
  var _motionGeneration = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(
      vsync: this,
      value: widget.value,
      debugLabel: 'SkedSpringBuilder',
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final previousPolicy = _policy;
    final nextPolicy = SkedMotionPolicy.of(context);
    _policy = nextPolicy;
    if (!nextPolicy.spatialAnimationsEnabled) {
      _snapToTarget();
    } else if (previousPolicy != null &&
        !previousPolicy.spatialAnimationsEnabled &&
        _controller.value != widget.value) {
      _animateTo(widget.value);
    }
  }

  @override
  void didUpdateWidget(covariant SkedSpringBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value || oldWidget.speed != widget.speed) {
      _animateTo(widget.value);
    }
  }

  void _animateTo(double target) {
    final policy = _policy;
    if (policy == null ||
        !policy.spatialAnimationsEnabled ||
        !policy.tickerEnabled) {
      _snapTo(target);
      return;
    }
    if (_controller.value == target) return;

    final generation = ++_motionGeneration;
    // Read velocity before starting the new simulation. `stop` is not needed:
    // animateWith replaces the current simulation and preserves this value.
    final simulation = SpringSimulation(
      policy.spatial(widget.speed),
      _controller.value,
      target,
      _controller.velocity,
      snapToEnd: true,
    );
    _controller.animateWith(simulation).whenCompleteOrCancel(() {
      if (!mounted || generation != _motionGeneration) return;
      _controller.value = target;
      widget.onEnd?.call();
    });
  }

  void _snapToTarget() => _snapTo(widget.value);

  void _snapTo(double target) {
    final changed = _controller.value != target;
    _motionGeneration++;
    _controller.stop(canceled: true);
    _controller.value = target;
    if (!changed || widget.onEnd == null) return;
    final generation = _motionGeneration;
    scheduleMicrotask(() {
      if (mounted && generation == _motionGeneration) widget.onEnd?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    assert(_policy != null);
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) =>
          widget.builder(context, _controller.value, child),
    );
  }

  @override
  void dispose() {
    _motionGeneration++;
    _controller.dispose();
    super.dispose();
  }
}
