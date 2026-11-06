import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/ui/agent_effort_slider.dart';
import 'package:sked/theme/sked_expressive_theme.dart';

const _boundaryKey = ValueKey('slider-pixels');

Future<({int width, int height, ByteData pixels})> _capture(
  WidgetTester tester,
) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_boundaryKey),
  );
  final image = (await tester.runAsync(() => boundary.toImage(pixelRatio: 1)))!;
  try {
    final pixels = (await tester.runAsync(
      () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
    ))!;
    return (width: image.width, height: image.height, pixels: pixels);
  } finally {
    image.dispose();
  }
}

/// Read the actual white thumb on the rendered center line. Tick marks are
/// translucent, so they cannot be mistaken for the opaque thumb.
Future<double> _thumbX(WidgetTester tester) async {
  final image = await _capture(tester);
  final pixels = image.pixels;
  final white = <int>[];
  final row = image.height ~/ 2;
  for (var x = 0; x < image.width; x++) {
    final offset = (row * image.width + x) * 4;
    if (pixels.getUint8(offset) >= 254 &&
        pixels.getUint8(offset + 1) >= 254 &&
        pixels.getUint8(offset + 2) >= 254 &&
        pixels.getUint8(offset + 3) == 255) {
      white.add(x);
    }
  }
  expect(white, isNotEmpty);
  return (white.first + white.last) / 2;
}

void main() {
  late void Function(VoidCallback) update;
  late FocusNode focus;
  double value = 0;
  bool saving = false;
  final changes = <double>[];

  setUp(() {
    value = 0;
    saving = false;
    changes.clear();
    focus = FocusNode();
  });
  tearDown(() => focus.dispose());

  Future<void> mount(
    WidgetTester tester, {
    bool reducedMotion = false,
    bool disabledAnimations = false,
    TextDirection direction = TextDirection.ltr,
  }) => tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disabledAnimations),
        child: SkedMotionPolicyScope(
          disableAnimations: disabledAnimations,
          reduceMotion: reducedMotion,
          child: Directionality(
            textDirection: direction,
            child: Scaffold(
              body: Center(
                child: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RepaintBoundary(
                          key: _boundaryKey,
                          child: SizedBox(
                            width: 280,
                            child: AgentEffortSlider(
                              slider: Slider(
                                focusNode: focus,
                                min: 0,
                                max: 6,
                                divisions: 6,
                                value: value,
                                semanticFormatterCallback: (value) =>
                                    'tier ${value.round()}',
                                onChanged: saving
                                    ? null
                                    : (next) {
                                        changes.add(next);
                                        setState(() => value = next);
                                      },
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('paint follows a spring while the native value stays discrete', (
    tester,
  ) async {
    await mount(tester);
    expect(tester.getSize(find.byKey(_boundaryKey)).height, 48);
    final start = await _thumbX(tester);
    update(() => value = 6);
    await tester.pump();
    expect(tester.widget<Slider>(find.byType(Slider)).value, 6);
    expect(tester.widget<Slider>(find.byType(Slider)).divisions, 6);
    expect(await _thumbX(tester), closeTo(start, 1));
    await tester.pump(const Duration(milliseconds: 40));
    final middle = await _thumbX(tester);
    await tester.pumpAndSettle();
    final end = await _thumbX(tester);
    expect(middle, greaterThan(start + 1));
    expect(middle, lessThan(end - 1));
    expect(changes, isEmpty);
  });

  for (final elapsed in [Duration.zero, const Duration(milliseconds: 40)]) {
    testWidgets('reversal after $elapsed retains the painted position', (
      tester,
    ) async {
      await mount(tester);
      final start = await _thumbX(tester);
      update(() => value = 6);
      await tester.pump();
      await tester.pump(elapsed);
      final beforeReverse = await _thumbX(tester);
      update(() => value = 0);
      await tester.pump();
      expect(await _thumbX(tester), closeTo(beforeReverse, 1));
      expect(tester.widget<Slider>(find.byType(Slider)).value, 0);
      await tester.pumpAndSettle();
      expect(await _thumbX(tester), closeTo(start, 1));
    });
  }

  for (final reducedMotion in [true, false]) {
    testWidgets(
      'motion policy settles painted position immediately: $reducedMotion',
      (tester) async {
        await mount(
          tester,
          reducedMotion: reducedMotion,
          disabledAnimations: !reducedMotion,
        );
        update(() => value = 6);
        await tester.pump();
        final immediate = await _thumbX(tester);
        await tester.pumpAndSettle();
        expect(immediate, greaterThan(250));
        expect(await _thumbX(tester), immediate);
      },
    );
  }

  testWidgets('keyboard and semantics retain native discrete selection', (
    tester,
  ) async {
    await mount(tester);
    final semantics = tester.ensureSemantics();
    try {
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(focus.hasFocus, isTrue);
      expect(changes, [1]);
      expect(value, 1);
      final owner = tester.binding.renderViews.single.owner!.semanticsOwner!;
      final sliders = <SemanticsNode>[];
      void visit(SemanticsNode node) {
        final data = node.getSemanticsData();
        if (!node.isMergedIntoParent &&
            data.hasAction(ui.SemanticsAction.increase) &&
            data.hasAction(ui.SemanticsAction.decrease)) {
          sliders.add(node);
        }
        node.visitChildren((child) {
          visit(child);
          return true;
        });
      }

      visit(owner.rootSemanticsNode!);
      expect(sliders, hasLength(1));
      expect(sliders.single.getSemanticsData().value, 'tier 1');
    } finally {
      focus.unfocus();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      semantics.dispose();
    }
  });

  testWidgets('saving keeps its painted size and colors with input gated', (
    tester,
  ) async {
    value = 3;
    await mount(tester);
    final before = await _thumbX(tester);
    final beforePixels = (await _capture(tester)).pixels.buffer.asUint8List();
    final size = tester.getSize(find.byKey(_boundaryKey));
    update(() => saving = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(
      (await _capture(tester)).pixels.buffer.asUint8List(),
      orderedEquals(beforePixels),
    );
    await tester.pumpAndSettle();
    expect(
      (await _capture(tester)).pixels.buffer.asUint8List(),
      orderedEquals(beforePixels),
    );
    final slider = tester.widget<Slider>(find.byType(Slider));
    final theme = SliderTheme.of(tester.element(find.byType(Slider)));
    expect(slider.onChanged, isNull);
    expect(tester.getSize(find.byKey(_boundaryKey)), size);
    expect(await _thumbX(tester), before);
    expect(theme.disabledActiveTrackColor, theme.activeTrackColor);
    expect(theme.disabledInactiveTrackColor, theme.inactiveTrackColor);
    expect(theme.disabledThumbColor, theme.thumbColor);
    expect(theme.disabledActiveTickMarkColor, theme.activeTickMarkColor);
    expect(theme.disabledInactiveTickMarkColor, theme.inactiveTickMarkColor);
  });

  testWidgets('RTL paints increasing effort toward the left', (tester) async {
    await mount(tester, direction: TextDirection.rtl);
    final start = await _thumbX(tester);
    update(() => value = 6);
    await tester.pumpAndSettle();
    expect(await _thumbX(tester), lessThan(start));
  });
}
