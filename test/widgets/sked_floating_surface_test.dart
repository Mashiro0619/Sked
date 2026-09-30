import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/widgets/sked_floating_surface.dart';

void main() {
  const bounds = Rect.fromLTRB(8, 56, 792, 592);
  const size = Size(300, 200);
  test('anchors below, above, or centered without clipping the trigger', () {
    expect(
      positionSkedFloatingPanel(
        bounds: bounds,
        size: size,
        anchor: const Rect.fromLTWH(100, 100, 80, 32),
      ),
      const Offset(100, 138),
    );
    expect(
      positionSkedFloatingPanel(
        bounds: bounds,
        size: size,
        anchor: const Rect.fromLTWH(100, 500, 80, 32),
      ),
      const Offset(100, 294),
    );
    expect(
      positionSkedFloatingPanel(
        bounds: bounds,
        size: const Size(300, 480),
        anchor: const Rect.fromLTWH(100, 300, 80, 32),
      ),
      const Offset(250, 84),
    );
    expect(
      positionSkedFloatingPanel(
        bounds: bounds,
        size: size,
        anchor: const Rect.fromLTWH(100, -100, 80, 32),
      ),
      const Offset(250, 224),
    );
    expect(
      positionSkedFloatingPanel(
        bounds: bounds,
        size: size,
        anchor: const Rect.fromLTWH(600, 100, 80, 32),
        rtl: true,
      ),
      const Offset(380, 138),
    );
  });
  test('toolbar anchors remain valid above the safe body boundary', () {
    expect(
      positionSkedFloatingPanel(
        bounds: bounds,
        size: size,
        anchor: const Rect.fromLTWH(100, 10, 80, 38),
      ),
      const Offset(100, 56),
    );
  });
  for (final brightness in Brightness.values) {
    testWidgets(
      'floating surface has one shadow and theme content color: $brightness',
      (t) async {
        final theme = ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.orange,
            brightness: brightness,
          ),
        );
        await t.pumpWidget(
          MaterialApp(
            theme: theme,
            home: const Center(
              child: SkedFloatingSurface(
                child: SizedBox(width: 300, height: 180),
              ),
            ),
          ),
        );
        final surface = find.byType(SkedFloatingSurface);
        final decoration =
            t
                    .widget<DecoratedBox>(
                      find
                          .descendant(
                            of: surface,
                            matching: find.byType(DecoratedBox),
                          )
                          .first,
                    )
                    .decoration
                as BoxDecoration;
        expect(decoration.borderRadius, SkedFloatingStyle.radius);
        expect(decoration.boxShadow, hasLength(1));
        final material = t.widget<Material>(
          find.descendant(of: surface, matching: find.byType(Material)).first,
        );
        expect(material.elevation, 0);
        expect(material.color, theme.colorScheme.surface);
      },
    );
  }
}
