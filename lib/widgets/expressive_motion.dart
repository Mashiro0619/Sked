import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

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
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final borderRadius = widget.borderRadius ?? BorderRadius.circular(16);
    if (disableAnimations) {
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
      duration: AppMotion.short,
      curve: AppMotion.enter,
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
    if (MediaQuery.disableAnimationsOf(context)) {
      return child;
    }
    return AnimatedSwitcher(
      duration: duration ?? AppMotion.medium,
      reverseDuration: AppMotion.short,
      switchInCurve: AppMotion.enter,
      switchOutCurve: AppMotion.exit,
      transitionBuilder: (child, animation) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: AppMotion.enter,
          reverseCurve: AppMotion.exit,
        );
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
