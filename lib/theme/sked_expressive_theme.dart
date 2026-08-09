import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'app_motion.dart';

/// The six shape families used to give Sked a consistent expressive grammar.
///
/// Semantic getters deliberately map multiple components to the same families
/// so the app does not grow a one-off shape token for every widget.
@immutable
class SkedShapeScheme extends ThemeExtension<SkedShapeScheme> {
  const SkedShapeScheme({
    required this.compact,
    required this.control,
    required this.container,
    required this.prominent,
    required this.selection,
    required this.hero,
  });

  static const standard = SkedShapeScheme(
    compact: RoundedSuperellipseBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
    ),
    control: RoundedSuperellipseBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
    ),
    container: RoundedSuperellipseBorder(
      borderRadius: BorderRadius.all(Radius.circular(24)),
    ),
    prominent: RoundedSuperellipseBorder(
      borderRadius: BorderRadius.all(Radius.circular(28)),
    ),
    // Keep selection in the same rounded-superellipse family as controls so
    // ButtonStyle can interpolate the radius instead of snapping shapes.
    selection: RoundedSuperellipseBorder(
      borderRadius: BorderRadius.all(Radius.circular(24)),
    ),
    hero: RoundedSuperellipseBorder(
      borderRadius: BorderRadius.all(Radius.circular(36)),
    ),
  );

  final OutlinedBorder compact;
  final OutlinedBorder control;
  final OutlinedBorder container;
  final OutlinedBorder prominent;
  final OutlinedBorder selection;
  final OutlinedBorder hero;

  OutlinedBorder get pageContainer => container;
  OutlinedBorder get card => container;
  OutlinedBorder get field => control;
  OutlinedBorder get menu => control;
  OutlinedBorder get dialog => prominent;
  OutlinedBorder get bottomSheet => const RoundedSuperellipseBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
  );
  OutlinedBorder get selectionIndicator => selection;
  OutlinedBorder get fab => prominent;
  OutlinedBorder get toolbar => container;

  BorderRadius get fieldRadius {
    final shape = field;
    return shape is RoundedSuperellipseBorder &&
            shape.borderRadius is BorderRadius
        ? shape.borderRadius as BorderRadius
        : const BorderRadius.all(Radius.circular(16));
  }

  @override
  SkedShapeScheme copyWith({
    OutlinedBorder? compact,
    OutlinedBorder? control,
    OutlinedBorder? container,
    OutlinedBorder? prominent,
    OutlinedBorder? selection,
    OutlinedBorder? hero,
  }) {
    return SkedShapeScheme(
      compact: compact ?? this.compact,
      control: control ?? this.control,
      container: container ?? this.container,
      prominent: prominent ?? this.prominent,
      selection: selection ?? this.selection,
      hero: hero ?? this.hero,
    );
  }

  @override
  SkedShapeScheme lerp(
    covariant ThemeExtension<SkedShapeScheme>? other,
    double t,
  ) {
    if (other is! SkedShapeScheme) return this;
    return SkedShapeScheme(
      compact: _lerpOutlinedBorder(compact, other.compact, t),
      control: _lerpOutlinedBorder(control, other.control, t),
      container: _lerpOutlinedBorder(container, other.container, t),
      prominent: _lerpOutlinedBorder(prominent, other.prominent, t),
      selection: _lerpOutlinedBorder(selection, other.selection, t),
      hero: _lerpOutlinedBorder(hero, other.hero, t),
    );
  }
}

enum SkedMotionSpeed { fast, standard, slow }

/// Motion tokens separate spatial spring movement from non-bouncy effects.
@immutable
class SkedMotionScheme extends ThemeExtension<SkedMotionScheme> {
  const SkedMotionScheme({
    required this.fastSpatial,
    required this.defaultSpatial,
    required this.slowSpatial,
    required this.fastEffects,
    required this.defaultEffects,
    required this.slowEffects,
    required this.standardCurve,
    required this.enterCurve,
    required this.exitCurve,
  });

  static final standard = SkedMotionScheme(
    fastSpatial: SpringDescription.withDurationAndBounce(
      duration: const Duration(milliseconds: 350),
      bounce: 0.08,
    ),
    defaultSpatial: SpringDescription.withDurationAndBounce(
      duration: const Duration(milliseconds: 500),
      bounce: 0.16,
    ),
    slowSpatial: SpringDescription.withDurationAndBounce(
      duration: const Duration(milliseconds: 700),
      bounce: 0.18,
    ),
    fastEffects: AppMotion.short,
    defaultEffects: AppMotion.medium,
    slowEffects: AppMotion.long,
    standardCurve: AppMotion.standard,
    enterCurve: AppMotion.enter,
    exitCurve: AppMotion.exit,
  );

  final SpringDescription fastSpatial;
  final SpringDescription defaultSpatial;
  final SpringDescription slowSpatial;
  final Duration fastEffects;
  final Duration defaultEffects;
  final Duration slowEffects;
  final Curve standardCurve;
  final Curve enterCurve;
  final Curve exitCurve;

  SpringDescription spatial(SkedMotionSpeed speed) {
    return switch (speed) {
      SkedMotionSpeed.fast => fastSpatial,
      SkedMotionSpeed.standard => defaultSpatial,
      SkedMotionSpeed.slow => slowSpatial,
    };
  }

  Duration effects(SkedMotionSpeed speed) {
    return switch (speed) {
      SkedMotionSpeed.fast => fastEffects,
      SkedMotionSpeed.standard => defaultEffects,
      SkedMotionSpeed.slow => slowEffects,
    };
  }

  @override
  SkedMotionScheme copyWith({
    SpringDescription? fastSpatial,
    SpringDescription? defaultSpatial,
    SpringDescription? slowSpatial,
    Duration? fastEffects,
    Duration? defaultEffects,
    Duration? slowEffects,
    Curve? standardCurve,
    Curve? enterCurve,
    Curve? exitCurve,
  }) {
    return SkedMotionScheme(
      fastSpatial: fastSpatial ?? this.fastSpatial,
      defaultSpatial: defaultSpatial ?? this.defaultSpatial,
      slowSpatial: slowSpatial ?? this.slowSpatial,
      fastEffects: fastEffects ?? this.fastEffects,
      defaultEffects: defaultEffects ?? this.defaultEffects,
      slowEffects: slowEffects ?? this.slowEffects,
      standardCurve: standardCurve ?? this.standardCurve,
      enterCurve: enterCurve ?? this.enterCurve,
      exitCurve: exitCurve ?? this.exitCurve,
    );
  }

  @override
  SkedMotionScheme lerp(
    covariant ThemeExtension<SkedMotionScheme>? other,
    double t,
  ) {
    if (other is! SkedMotionScheme) return this;
    return SkedMotionScheme(
      fastSpatial: _lerpSpring(fastSpatial, other.fastSpatial, t),
      defaultSpatial: _lerpSpring(defaultSpatial, other.defaultSpatial, t),
      slowSpatial: _lerpSpring(slowSpatial, other.slowSpatial, t),
      fastEffects: _lerpDuration(fastEffects, other.fastEffects, t),
      defaultEffects: _lerpDuration(defaultEffects, other.defaultEffects, t),
      slowEffects: _lerpDuration(slowEffects, other.slowEffects, t),
      standardCurve: t < 0.5 ? standardCurve : other.standardCurve,
      enterCurve: t < 0.5 ? enterCurve : other.enterCurve,
      exitCurve: t < 0.5 ? exitCurve : other.exitCurve,
    );
  }
}

/// Runtime motion decision derived from theme, accessibility, and TickerMode.
@immutable
class SkedMotionPolicy {
  const SkedMotionPolicy({
    required this.scheme,
    required this.animationsEnabled,
    required this.tickerEnabled,
    required this.disableAnimations,
    required this.reduceMotion,
  });

  factory SkedMotionPolicy.of(BuildContext context) {
    final mediaQueryDisables = MediaQuery.maybeDisableAnimationsOf(context);
    final features =
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures;
    final disableAnimations = mediaQueryDisables ?? features.disableAnimations;
    final tickerEnabled = TickerMode.valuesOf(context).enabled;
    return SkedMotionPolicy(
      scheme: skedMotionSchemeOf(context),
      animationsEnabled: !disableAnimations && tickerEnabled,
      tickerEnabled: tickerEnabled,
      disableAnimations: disableAnimations,
      reduceMotion: features.reduceMotion,
    );
  }

  final SkedMotionScheme scheme;
  final bool animationsEnabled;
  final bool tickerEnabled;
  final bool disableAnimations;
  final bool reduceMotion;

  bool get spatialAnimationsEnabled => animationsEnabled && !reduceMotion;

  Duration effects(SkedMotionSpeed speed) {
    return animationsEnabled ? scheme.effects(speed) : Duration.zero;
  }

  SpringDescription spatial(SkedMotionSpeed speed) {
    // Spatial callers should consult [spatialAnimationsEnabled] first. Keep
    // this accessor total for callers that need a token even when motion is
    // reduced; the zero-bounce fallback is intentionally non-expressive.
    if (!reduceMotion) return scheme.spatial(speed);
    final duration = scheme.effects(speed);
    return SpringDescription.withDurationAndBounce(
      duration: duration,
      bounce: 0,
    );
  }

  AnimationStyle routeStyle(AnimationStyle enabledStyle) {
    // Dialogs, sheets and menus use spatial transitions internally. Reduced
    // motion opts out of those route transitions; local non-spatial fades can
    // still use the effects tokens.
    return spatialAnimationsEnabled ? enabledStyle : AnimationStyle.noAnimation;
  }

  static bool get systemAnimationsDisabled {
    final features =
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures;
    return features.disableAnimations;
  }

  static bool get systemReducedMotion {
    final features =
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures;
    return features.reduceMotion;
  }

  static AnimationStyle systemAwareStyle(AnimationStyle enabledStyle) {
    return systemAnimationsDisabled || systemReducedMotion
        ? AnimationStyle.noAnimation
        : enabledStyle;
  }
}

SkedShapeScheme skedShapeSchemeOf(BuildContext context) {
  return Theme.of(context).extension<SkedShapeScheme>() ??
      SkedShapeScheme.standard;
}

SkedMotionScheme skedMotionSchemeOf(BuildContext context) {
  return Theme.of(context).extension<SkedMotionScheme>() ??
      SkedMotionScheme.standard;
}

OutlinedBorder _lerpOutlinedBorder(
  OutlinedBorder begin,
  OutlinedBorder end,
  double t,
) {
  return OutlinedBorder.lerp(begin, end, t) ?? (t < 0.5 ? begin : end);
}

SpringDescription _lerpSpring(
  SpringDescription begin,
  SpringDescription end,
  double t,
) {
  return SpringDescription(
    mass: lerpDouble(begin.mass, end.mass, t) ?? begin.mass,
    stiffness: lerpDouble(begin.stiffness, end.stiffness, t) ?? begin.stiffness,
    damping: lerpDouble(begin.damping, end.damping, t) ?? begin.damping,
  );
}

Duration _lerpDuration(Duration begin, Duration end, double t) {
  final microseconds = lerpDouble(
    begin.inMicroseconds.toDouble(),
    end.inMicroseconds.toDouble(),
    t,
  );
  return Duration(microseconds: (microseconds ?? begin.inMicroseconds).round());
}
