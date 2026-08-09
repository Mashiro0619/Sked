import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/theme/app_theme.dart';
import 'package:sked/theme/sked_expressive_theme.dart';
import 'package:sked/utils/constants.dart';

void main() {
  test(
    'shape scheme exposes semantic families and interpolates same-family shapes',
    () {
      final shapes = SkedShapeScheme.standard;

      expect(shapes.card, same(shapes.container));
      expect(shapes.field, same(shapes.control));
      expect(shapes.bottomSheet, isA<RoundedSuperellipseBorder>());
      final sheetRadius = (shapes.bottomSheet as RoundedSuperellipseBorder)
          .borderRadius
          .resolve(TextDirection.ltr);
      expect(sheetRadius.bottomLeft.x, 0);
      expect(sheetRadius.bottomRight.x, 0);

      final mid = shapes.lerp(
        shapes.copyWith(
          control: const RoundedSuperellipseBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
        0.5,
      );
      expect(mid.control, isA<RoundedSuperellipseBorder>());
      expect(
        (mid.control as RoundedSuperellipseBorder).borderRadius
            .resolve(TextDirection.ltr)
            .topLeft
            .x,
        closeTo(12, 0.001),
      );
    },
  );

  test(
    'shape scheme copy, fallback radius, and semantic getters stay coherent',
    () {
      final shapes = SkedShapeScheme.standard;

      expect(shapes.pageContainer, same(shapes.container));
      expect(shapes.card, same(shapes.container));
      expect(shapes.field, same(shapes.control));
      expect(shapes.menu, same(shapes.control));
      expect(shapes.dialog, same(shapes.prominent));
      expect(shapes.selectionIndicator, same(shapes.selection));
      expect(shapes.fab, same(shapes.prominent));
      expect(shapes.toolbar, same(shapes.container));
      expect(shapes.copyWith().control, same(shapes.control));
      expect(shapes.lerp(null, 0.5), same(shapes));

      const compact = CircleBorder();
      const control = StadiumBorder();
      const container = BeveledRectangleBorder();
      const prominent = ContinuousRectangleBorder();
      const selection = RoundedRectangleBorder();
      const hero = StarBorder(points: 5);
      final changed = shapes.copyWith(
        compact: compact,
        control: control,
        container: container,
        prominent: prominent,
        selection: selection,
        hero: hero,
      );
      expect(changed.compact, compact);
      expect(changed.control, control);
      expect(changed.container, container);
      expect(changed.prominent, prominent);
      expect(changed.selection, selection);
      expect(changed.hero, hero);
      expect(changed.fieldRadius, const BorderRadius.all(Radius.circular(16)));
    },
  );

  test('motion scheme separates spatial springs from effects durations', () {
    final motion = SkedMotionScheme.standard;
    expect(
      motion.spatial(SkedMotionSpeed.fast).duration,
      lessThan(motion.spatial(SkedMotionSpeed.slow).duration),
    );
    expect(
      motion.effects(SkedMotionSpeed.fast),
      lessThan(motion.effects(SkedMotionSpeed.slow)),
    );
    expect(
      motion.copyWith(defaultEffects: Duration.zero).defaultEffects,
      Duration.zero,
    );
  });

  test('motion scheme copies and interpolates every token family', () {
    final motion = SkedMotionScheme.standard;
    final changed = motion.copyWith(
      fastSpatial: const SpringDescription(
        mass: 2,
        stiffness: 240,
        damping: 24,
      ),
      defaultSpatial: const SpringDescription(
        mass: 3,
        stiffness: 180,
        damping: 18,
      ),
      slowSpatial: const SpringDescription(
        mass: 4,
        stiffness: 120,
        damping: 12,
      ),
      fastEffects: const Duration(milliseconds: 40),
      defaultEffects: const Duration(milliseconds: 80),
      slowEffects: const Duration(milliseconds: 120),
      standardCurve: Curves.linear,
      enterCurve: Curves.easeIn,
      exitCurve: Curves.easeOut,
    );

    expect(motion.copyWith().fastSpatial, same(motion.fastSpatial));
    expect(changed.spatial(SkedMotionSpeed.fast), changed.fastSpatial);
    expect(changed.spatial(SkedMotionSpeed.standard), changed.defaultSpatial);
    expect(changed.spatial(SkedMotionSpeed.slow), changed.slowSpatial);
    expect(changed.effects(SkedMotionSpeed.fast), changed.fastEffects);
    expect(changed.effects(SkedMotionSpeed.standard), changed.defaultEffects);
    expect(changed.effects(SkedMotionSpeed.slow), changed.slowEffects);
    expect(motion.lerp(null, 0.5), same(motion));

    final early = motion.lerp(changed, 0.25);
    final late = motion.lerp(changed, 0.75);
    expect(early.fastSpatial.mass, closeTo(1.25, 0.001));
    expect(
      early.fastEffects.inMicroseconds,
      allOf(
        greaterThan(changed.fastEffects.inMicroseconds),
        lessThan(motion.fastEffects.inMicroseconds),
      ),
    );
    expect(early.standardCurve, same(motion.standardCurve));
    expect(early.enterCurve, same(motion.enterCurve));
    expect(early.exitCurve, same(motion.exitCurve));
    expect(late.fastSpatial.mass, closeTo(1.75, 0.001));
    expect(
      late.fastEffects.inMicroseconds,
      allOf(
        greaterThan(changed.fastEffects.inMicroseconds),
        lessThan(motion.fastEffects.inMicroseconds),
      ),
    );
    expect(late.standardCurve, same(changed.standardCurve));
    expect(late.enterCurve, same(changed.enterCurve));
    expect(late.exitCurve, same(changed.exitCurve));
  });

  testWidgets('motion policy snaps under local disabled animations', (
    tester,
  ) async {
    SkedMotionPolicy? policy;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) {
              policy = SkedMotionPolicy.of(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(policy!.disableAnimations, isTrue);
    expect(policy!.animationsEnabled, isFalse);
    expect(policy!.effects(SkedMotionSpeed.standard), Duration.zero);
  });

  testWidgets('motion policy keeps reduced motion separate from ticker mode', (
    tester,
  ) async {
    SkedMotionPolicy? policy;
    await tester.pumpWidget(
      MaterialApp(
        home: TickerMode(
          enabled: false,
          child: Builder(
            builder: (context) {
              policy = SkedMotionPolicy.of(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(policy!.tickerEnabled, isFalse);
    expect(policy!.animationsEnabled, isFalse);
    expect(policy!.spatialAnimationsEnabled, isFalse);
  });

  testWidgets('motion policy scope publishes runtime accessibility changes', (
    tester,
  ) async {
    var reduceMotion = false;
    SkedMotionPolicy? policy;
    late void Function(void Function()) rebuild;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          rebuild = setState;
          return SkedMotionPolicyScope(
            disableAnimations: false,
            reduceMotion: reduceMotion,
            child: Builder(
              builder: (context) {
                policy = SkedMotionPolicy.of(context);
                return const SizedBox();
              },
            ),
          );
        },
      ),
    );
    expect(policy!.reduceMotion, isFalse);

    rebuild(() => reduceMotion = true);
    await tester.pump();
    expect(policy!.reduceMotion, isTrue);
    expect(policy!.spatialAnimationsEnabled, isFalse);
  });

  testWidgets('motion policy reads platform fallback without a MediaQuery', (
    tester,
  ) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );
    SkedMotionPolicy? policy;
    await tester.pumpWidget(
      Theme(
        data: ThemeData(),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              policy = SkedMotionPolicy.of(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(policy!.disableAnimations, isTrue);
    expect(policy!.animationsEnabled, isFalse);
    expect(SkedMotionPolicy.systemAnimationsDisabled, isTrue);
  });

  testWidgets('reduced motion keeps effects but disables spatial routes', (
    tester,
  ) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );
    SkedMotionPolicy? policy;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            policy = SkedMotionPolicy.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    const enabledStyle = AnimationStyle(
      duration: Duration(milliseconds: 200),
      reverseDuration: Duration(milliseconds: 100),
    );
    expect(policy!.animationsEnabled, isTrue);
    expect(policy!.reduceMotion, isTrue);
    expect(policy!.spatialAnimationsEnabled, isFalse);
    expect(policy!.effects(SkedMotionSpeed.fast), policy!.scheme.fastEffects);
    expect(
      policy!.spatial(SkedMotionSpeed.fast).duration,
      policy!.scheme.fastEffects,
    );
    expect(policy!.routeStyle(enabledStyle), AnimationStyle.noAnimation);
    expect(SkedMotionPolicy.systemReducedMotion, isTrue);
    expect(
      SkedMotionPolicy.systemAwareStyle(enabledStyle),
      AnimationStyle.noAnimation,
    );
  });

  testWidgets('normal motion and theme lookup preserve custom extensions', (
    tester,
  ) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures();
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );
    final customMotion = SkedMotionScheme.standard.copyWith(
      fastEffects: const Duration(milliseconds: 77),
    );
    final customShapes = SkedShapeScheme.standard.copyWith(
      hero: const CircleBorder(),
    );
    SkedMotionPolicy? policy;
    SkedMotionScheme? motion;
    SkedShapeScheme? shapes;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [customMotion, customShapes]),
        home: Builder(
          builder: (context) {
            policy = SkedMotionPolicy.of(context);
            motion = skedMotionSchemeOf(context);
            shapes = skedShapeSchemeOf(context);
            return const SizedBox();
          },
        ),
      ),
    );
    const enabledStyle = AnimationStyle(duration: Duration(milliseconds: 200));
    expect(motion, same(customMotion));
    expect(shapes, same(customShapes));
    expect(policy!.spatialAnimationsEnabled, isTrue);
    expect(policy!.spatial(SkedMotionSpeed.fast), customMotion.fastSpatial);
    expect(policy!.routeStyle(enabledStyle), enabledStyle);
    expect(SkedMotionPolicy.systemAnimationsDisabled, isFalse);
    expect(SkedMotionPolicy.systemReducedMotion, isFalse);
    expect(SkedMotionPolicy.systemAwareStyle(enabledStyle), enabledStyle);

    SkedMotionScheme? fallbackMotion;
    SkedShapeScheme? fallbackShapes;
    await tester.pumpWidget(
      Theme(
        data: ThemeData(),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              fallbackMotion = skedMotionSchemeOf(context);
              fallbackShapes = skedShapeSchemeOf(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(fallbackMotion, same(SkedMotionScheme.standard));
    expect(fallbackShapes, same(SkedShapeScheme.standard));
  });

  test('buildAppTheme preserves exact primary color in both brightnesses', () {
    const primary = Color(0xff123456);
    final light = buildAppTheme(
      seedColor: primary,
      brightness: Brightness.light,
      themeColorMode: themeColorModeSingle,
      colorfulUiColorValues: const {},
    );
    final dark = buildAppTheme(
      seedColor: primary,
      brightness: Brightness.dark,
      themeColorMode: themeColorModeSingle,
      colorfulUiColorValues: const {},
    );
    expect(light.colorScheme.primary, primary);
    expect(dark.colorScheme.primary, primary);
    expect(light.extension<SkedShapeScheme>(), isNotNull);
    expect(light.extension<SkedMotionScheme>(), isNotNull);
  });
}
