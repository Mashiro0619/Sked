import 'package:flutter/material.dart';

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
