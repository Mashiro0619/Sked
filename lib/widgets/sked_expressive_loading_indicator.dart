import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';

import '../theme/sked_expressive_theme.dart';

/// A compact, single-controller loading visual inspired by M3 Expressive
/// shape motion. It is deliberately not named or presented as Flutter's
/// missing Compose `LoadingIndicator` API.
class SkedExpressiveLoadingIndicator extends StatefulWidget {
  const SkedExpressiveLoadingIndicator({
    super.key,
    this.value,
    this.size = 40,
    this.color,
    this.semanticsLabel,
  });

  final double? value;
  final double size;
  final Color? color;
  final String? semanticsLabel;

  @override
  State<SkedExpressiveLoadingIndicator> createState() =>
      _SkedExpressiveLoadingIndicatorState();
}

class _SkedExpressiveLoadingIndicatorState
    extends State<SkedExpressiveLoadingIndicator>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  var _canAnimate = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant SkedExpressiveLoadingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _syncAnimation();
  }

  void _syncAnimation() {
    final policy = SkedMotionPolicy.of(context);
    final canAnimate = widget.value == null && policy.spatialAnimationsEnabled;
    if (canAnimate == _canAnimate) {
      if (canAnimate && _controller != null) {
        _controller!.duration = policy.scheme.effects(SkedMotionSpeed.slow);
      }
      return;
    }
    _canAnimate = canAnimate;
    if (_canAnimate) {
      final controller = _controller ??= AnimationController(
        vsync: this,
        duration: policy.scheme.effects(SkedMotionSpeed.slow),
        debugLabel: 'SkedExpressiveLoadingIndicator',
      );
      controller.duration = policy.scheme.effects(SkedMotionSpeed.slow);
      unawaited(controller.repeat());
    } else {
      _controller?.stop(canceled: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = widget.color ?? colors.primary;
    final value = widget.value;
    if (value != null) {
      // Keep the determinate percentage available to screen readers. The
      // stock indicator exposes a value too, but excluding its nested node
      // avoids duplicate announcements when we provide the localized label.
      final normalizedValue = value.clamp(0.0, 1.0).toDouble();
      final percentage = '${(normalizedValue * 100).round()}%';
      return Semantics(
        container: true,
        label: widget.semanticsLabel,
        role: SemanticsRole.progressBar,
        minValue: '0',
        maxValue: '100',
        value: percentage,
        child: ExcludeSemantics(
          child: SizedBox.square(
            dimension: widget.size,
            child: CircularProgressIndicator(
              value: normalizedValue,
              color: color,
              strokeWidth: 3,
            ),
          ),
        ),
      );
    }

    final visual = _canAnimate && _controller != null
        ? AnimatedBuilder(
            animation: _controller!,
            builder: (context, _) => CustomPaint(
              size: Size.square(widget.size),
              painter: _SkedLoadingPainter(
                phase: _controller!.value,
                color: color,
              ),
            ),
          )
        : CircularProgressIndicator(color: color, strokeWidth: 3);

    return Semantics(
      container: true,
      // The label is announced when this node enters the semantics tree.
      // Keeping a continuously repainting indeterminate visual out of a live
      // region avoids repeating the same announcement on every frame.
      liveRegion: false,
      label: widget.semanticsLabel,
      role: SemanticsRole.loadingSpinner,
      child: ExcludeSemantics(
        child: SizedBox.square(dimension: widget.size, child: visual),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}

class _SkedLoadingPainter extends CustomPainter {
  const _SkedLoadingPainter({required this.phase, required this.color});

  static const shapes = <ShapeBorder>[
    CircleBorder(),
    StarBorder(
      points: 4,
      innerRadiusRatio: 0.72,
      pointRounding: 0.55,
      valleyRounding: 0.4,
    ),
    StarBorder(
      points: 8,
      innerRadiusRatio: 0.82,
      pointRounding: 0.56,
      valleyRounding: 0.38,
    ),
  ];

  final double phase;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final segment = (phase * 3) % 3;
    final index = segment.floor();
    final local = Curves.easeInOut.transform(segment - index);
    final from = shapes[index];
    final to = shapes[(index + 1) % shapes.length];
    final shape = ShapeBorder.lerp(from, to, local) ?? from;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(phase * math.pi * 2);
    canvas.translate(-size.width / 2, -size.height / 2);
    canvas.drawPath(shape.getOuterPath(rect), Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SkedLoadingPainter oldDelegate) {
    return oldDelegate.phase != phase || oldDelegate.color != color;
  }
}
