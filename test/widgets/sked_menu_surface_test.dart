import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/theme/app_theme.dart';
import 'package:sked/utils/constants.dart';
import 'package:sked/widgets/sked_dropdown_menu.dart';
import 'package:sked/widgets/sked_popup_menu.dart';

const skedMenuSurfaceCaptureKey = ValueKey('sked-menu-surface-capture');
typedef SkedMenuSurfaceCapture = Future<void> Function(
  WidgetTester tester,
  String scene,
);

Future<List<Color>> _pixels(
  WidgetTester tester,
  List<Offset> points,
) async => (await tester.runAsync(() async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(skedMenuSurfaceCaptureKey),
  );
  final image = await boundary.toImage(pixelRatio: 1);
  try {
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    return points.map((point) {
      final offset = (point.dy.floor() * image.width + point.dx.floor()) * 4;
      return Color.fromARGB(
        bytes.getUint8(offset + 3),
        bytes.getUint8(offset),
        bytes.getUint8(offset + 1),
        bytes.getUint8(offset + 2),
      );
    }).toList();
  } finally {
    image.dispose();
  }
}))!;

void _expectPaint(Color actual, Color expected) {
  expect(
    actual.r,
    closeTo(expected.r, 2 / 255),
    reason: '$actual != $expected',
  );
  expect(
    actual.g,
    closeTo(expected.g, 2 / 255),
    reason: '$actual != $expected',
  );
  expect(
    actual.b,
    closeTo(expected.b, 2 / 255),
    reason: '$actual != $expected',
  );
  expect(actual.a, closeTo(1, 1 / 255));
}

void main() => runSkedMenuSurfaceTests();

void runSkedMenuSurfaceTests({SkedMenuSurfaceCapture? capture}) {
  for (final brightness in Brightness.values) {
    for (final dropdown in [false, true]) {
      testWidgets(
        '${dropdown ? 'dropdown' : 'popup'} paints an opaque surface: $brightness',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(640, 480);
          addTearDown(tester.view.reset);
          final theme = buildAppTheme(
            seedColor: const Color(defaultThemeSeedColorValue),
            brightness: brightness,
            themeColorMode: themeColorModeSingle,
            colorfulUiColorValues: const {},
          );
          final backdrop = ValueNotifier(const Color(0xffff00ff));
          addTearDown(backdrop.dispose);
          const trigger = ValueKey('menu-trigger');
          await tester.pumpWidget(
            RepaintBoundary(
              key: skedMenuSurfaceCaptureKey,
              child: MaterialApp(
                theme: theme,
                home: Scaffold(
                  body: Stack(
                    fit: StackFit.expand,
                    children: [
                      ValueListenableBuilder(
                        valueListenable: backdrop,
                        builder: (context, color, _) =>
                            ColoredBox(color: color),
                      ),
                      Positioned(
                        left: 160,
                        top: 64,
                        width: 200,
                        child: dropdown
                            ? const SkedDropdownMenu<String>(
                                key: trigger,
                                initialSelection: 'week',
                                dropdownMenuEntries: [
                                  DropdownMenuEntry(
                                    value: 'week',
                                    label: 'Week',
                                  ),
                                  DropdownMenuEntry(value: 'day', label: 'Day'),
                                ],
                              )
                            : SkedPopupMenuButton<String>(
                                key: trigger,
                                itemBuilder: (_) => const [
                                  SkedCheckedPopupMenuItem(
                                    value: 'week',
                                    checked: true,
                                    label: 'Week',
                                  ),
                                  SkedCheckedPopupMenuItem(
                                    value: 'day',
                                    checked: false,
                                    label: 'Day',
                                  ),
                                ],
                                child: const Text('View'),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(trigger));
          await tester.pumpAndSettle();
          final surface = find.byWidgetPredicate(
            (widget) => widget is Material && widget.elevation == 3,
          );
          expect(surface, findsOneWidget);
          final rect = tester.getRect(surface);
          final points = [
            rect.topCenter + const Offset(0, 3),
            rect.centerRight + const Offset(-3, 0),
            rect.bottomCenter + const Offset(0, -3),
          ];
          if (capture != null) {
            await capture(
              tester,
              '${dropdown ? 'dropdown' : 'popup'}-${brightness.name}',
            );
          }
          for (final pixel in await _pixels(tester, points)) {
            _expectPaint(pixel, theme.colorScheme.surface);
          }
          backdrop.value = Colors.green;
          await tester.pumpAndSettle();
          for (final pixel in await _pixels(tester, points)) {
            _expectPaint(pixel, theme.colorScheme.surface);
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        },
        variant: TargetPlatformVariant.only(TargetPlatform.windows),
      );
    }
  }
}
