import 'package:material_ui/material_ui.dart';

import '../../theme/sked_expressive_theme.dart';
import '../../theme/sked_surface.dart';
import '../../widgets/sked_spring_builder.dart';

/// Keeps native discrete input and animates only the painted slider position.
class AgentEffortSlider extends StatelessWidget {
  const AgentEffortSlider({super.key, required this.slider});

  final Slider slider;

  @override
  Widget build(BuildContext context) {
    final target = slider.max == slider.min
        ? 0.0
        : (slider.value - slider.min) / (slider.max - slider.min);
    final colors = Theme.of(context).colorScheme;
    final accent = skedReadableAccent(colors, surface: Colors.white);
    final inactiveTrack = colors.onSurface.withValues(alpha: .12);
    final activeTick = Colors.white.withValues(alpha: .45);
    final inactiveTick = colors.onSurface.withValues(alpha: .35);
    return SkedSpringBuilder(
      value: target,
      speed: SkedMotionSpeed.fast,
      child: slider,
      builder: (context, value, child) {
        final position = _SliderPaintPosition(value.clamp(0.0, 1.0));
        return SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 26,
            trackGap: 0,
            trackShape: _SpringTrackShape(position),
            thumbShape: _SpringComponentShape(
              position,
              const RoundSliderThumbShape(
                enabledThumbRadius: 14,
                disabledThumbRadius: 14,
                elevation: 1,
                pressedElevation: 2,
              ),
            ),
            thumbColor: Colors.white,
            disabledThumbColor: Colors.white,
            activeTrackColor: accent,
            disabledActiveTrackColor: accent,
            inactiveTrackColor: inactiveTrack,
            disabledInactiveTrackColor: inactiveTrack,
            tickMarkShape: _SpringTickMarkShape(position),
            activeTickMarkColor: activeTick,
            disabledActiveTickMarkColor: activeTick,
            inactiveTickMarkColor: inactiveTick,
            disabledInactiveTickMarkColor: inactiveTick,
            overlayShape: _SpringComponentShape(
              position,
              const RoundSliderOverlayShape(overlayRadius: 20),
            ),
            overlayColor: accent.withValues(alpha: .12),
            padding: const EdgeInsets.symmetric(vertical: 10),
            showValueIndicator: ShowValueIndicator.never,
          ),
          child: child!,
        );
      },
    );
  }
}

/// material_ui paints the track first, then overlay, ticks and thumb. Sharing
/// its canvas-space center also preserves offsets inside scrolling/transforms.
class _SliderPaintPosition {
  _SliderPaintPosition(this.value);

  final double value;
  late Offset center;
}

class _SpringTrackShape extends RoundedRectSliderTrackShape {
  const _SpringTrackShape(this.position);

  final _SliderPaintPosition position;

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 0,
  }) {
    final track = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final fraction = textDirection == TextDirection.rtl
        ? 1 - position.value
        : position.value;
    // Match material_ui's rounded-track endpoints, including discrete padding.
    final x = isDiscrete
        ? track.left +
              fraction * (track.width - track.height) +
              track.height / 2
        : track.left + fraction * track.width;
    final thumbRadius =
        sliderTheme.thumbShape!.getPreferredSize(isEnabled, isDiscrete).width /
        2;
    final inset = track.height > thumbRadius ? track.height / 2 : 0.0;
    position.center = Offset(
      x.clamp(track.left + inset, track.right - inset),
      track.center.dy,
    );
    super.paint(
      context,
      offset,
      parentBox: parentBox,
      sliderTheme: sliderTheme,
      enableAnimation: enableAnimation,
      textDirection: textDirection,
      thumbCenter: position.center,
      secondaryOffset: secondaryOffset,
      isDiscrete: isDiscrete,
      isEnabled: isEnabled,
      additionalActiveTrackHeight: 0,
    );
  }
}

class _SpringComponentShape extends SliderComponentShape {
  const _SpringComponentShape(this.position, this.delegate);

  final _SliderPaintPosition position;
  final SliderComponentShape delegate;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      delegate.getPreferredSize(isEnabled, isDiscrete);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) => delegate.paint(
    context,
    position.center,
    activationAnimation: activationAnimation,
    enableAnimation: enableAnimation,
    isDiscrete: isDiscrete,
    labelPainter: labelPainter,
    parentBox: parentBox,
    sliderTheme: sliderTheme,
    textDirection: textDirection,
    value: value,
    textScaleFactor: textScaleFactor,
    sizeWithOverflow: sizeWithOverflow,
  );
}

class _SpringTickMarkShape extends RoundSliderTickMarkShape {
  const _SpringTickMarkShape(this.position) : super(tickMarkRadius: 2);

  final _SliderPaintPosition position;

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset thumbCenter,
    required bool isEnabled,
    required TextDirection textDirection,
  }) => super.paint(
    context,
    center,
    parentBox: parentBox,
    sliderTheme: sliderTheme,
    enableAnimation: enableAnimation,
    thumbCenter: position.center,
    isEnabled: isEnabled,
    textDirection: textDirection,
  );
}
