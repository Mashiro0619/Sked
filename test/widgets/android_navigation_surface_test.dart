import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/theme/sked_surface.dart';

import '../support/workspace_harness.dart';

Finder _key(String value) => find.byKey(ValueKey(value));
Finder get _bar => _key('adaptive-shell-navigation-bar');
Finder get _systemSurface => _key('adaptive-shell-system-navigation-surface');
Finder get _systemStyle => _key('adaptive-shell-system-navigation-style');

void _viewport(WidgetTester t, double width, double inset) {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = Size(width, 850);
  t.view.padding = FakeViewPadding(top: 24, bottom: inset);
  t.view.viewPadding = FakeViewPadding(top: 24, bottom: inset);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetPadding);
  addTearDown(t.view.resetViewPadding);
  addTearDown(t.view.resetViewInsets);
}

Future<List<Color>> _pixels(
  WidgetTester t,
  GlobalKey boundary,
  List<Offset> points,
) async => (await t.runAsync(() async {
  final render =
      boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await render.toImage(pixelRatio: 1);
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

void _samePaint(Color actual, Color expected) {
  expect(actual.r, closeTo(expected.r, 2 / 255));
  expect(actual.g, closeTo(expected.g, 2 / 255));
  expect(actual.b, closeTo(expected.b, 2 / 255));
  expect(actual.a, closeTo(expected.a, 2 / 255));
}

void main() {
  for (final brightness in Brightness.values) {
    for (final inset in [0.0, 16.0, 24.0, 34.0, 48.0]) {
      for (final (width, scale, language) in [
        (393.0, 1.0, 'zh'),
        (320.0, 2.0, 'en'),
      ]) {
        testWidgets(
          'Android surface $brightness/$inset/$width/$scale is continuous and preserves one safe inset',
          (t) async {
            _viewport(t, width, inset);
            final p = await workspaceProvider(locale: language);
            addTearDown(p.dispose);
            final boundary = GlobalKey();
            await t.pumpWidget(
              RepaintBoundary(
                key: boundary,
                child: WorkspaceHarness(
                  provider: p,
                  brightness: brightness,
                  locale: Locale(language),
                  textScale: scale,
                ),
              ),
            );
            await t.pumpAndSettle();
            final barRect = t.getRect(_bar);
            final contentHeight = t.widget<NavigationBar>(_bar).height!;
            final colors = Theme.of(t.element(_bar)).colorScheme;
            expect(barRect.height, contentHeight + inset);
            expect(barRect.bottom, 850);
            if (language == 'zh') expect(contentHeight, 64);
            final pixels = await _pixels(t, boundary, [
              Offset(2, barRect.top + contentHeight / 2),
              if (inset > 0) Offset(2, barRect.bottom - inset / 2),
            ]);
            _samePaint(pixels.first, SkedSurfaceRole.frame.resolve(colors));
            if (inset > 0) {
              // Assert actual pixels, not just the widget's color or height.
              _samePaint(pixels.last, SkedSurfaceRole.frame.resolve(colors));
              expect(pixels.last, pixels.first);
              expect(_systemSurface, findsNothing);
              await t.tapAt(Offset(width * .75, 850 - inset / 2));
              await t.pumpAndSettle();
              expect(
                p.activeMode,
                AppMode.student,
                reason: 'The system inset is not a destination target.',
              );
            } else {
              expect(_systemSurface, findsNothing);
            }
            final style = t
                .widget<AnnotatedRegion<SystemUiOverlayStyle>>(_systemStyle)
                .value;
            expect(
              style.systemNavigationBarColor,
              SkedSurfaceRole.frame.resolve(colors),
            );
            expect(
              style.systemNavigationBarIconBrightness,
              brightness == Brightness.dark
                  ? Brightness.light
                  : Brightness.dark,
            );
            expect(style.systemNavigationBarContrastEnforced, isFalse);
            expect(
              style.statusBarColor,
              isNull,
              reason:
                  'Only bottom system navigation belongs to this component.',
            );
            for (final id in ['student', 'general']) {
              final destination = _key('adaptive-shell-$id-destination');
              final indicator = find.descendant(
                of: destination,
                matching: find.byType(NavigationIndicator),
              );
              expect(
                t.widget<NavigationBar>(_bar).indicatorColor,
                Colors.transparent,
              );
              final icon = find
                  .descendant(of: destination, matching: find.byType(Icon))
                  .first;
              expect(
                t.getCenter(icon).dy,
                closeTo(t.getCenter(indicator).dy + 4, .01),
              );
              final label = find
                  .descendant(of: destination, matching: find.byType(Text))
                  .first;
              final group = t
                  .getRect(indicator)
                  .expandToInclude(t.getRect(label));
              expect(
                group.center.dy,
                closeTo(barRect.top + contentHeight / 2, .5),
              );
              expect(t.getRect(destination).bottom, closeTo(850 - inset, .01));
              expect(t.getRect(destination).height, greaterThanOrEqualTo(48));
            }
            await t.tap(_key('adaptive-shell-general-destination'));
            await t.pumpAndSettle();
            expect(p.activeMode, AppMode.general);
            expect(t.getRect(_bar), barRect);
            expect(t.takeException(), isNull);
          },
          variant: TargetPlatformVariant.only(TargetPlatform.android),
        );
      }
    }
  }

  testWidgets(
    'keyboard and runtime inset changes never invent a second system band',
    (t) async {
      _viewport(t, 393, 24);
      final p = await workspaceProvider(locale: 'zh');
      addTearDown(p.dispose);
      await t.pumpWidget(
        WorkspaceHarness(provider: p, locale: const Locale('zh')),
      );
      await t.pumpAndSettle();
      expect(_systemSurface, findsNothing);
      expect(t.getSize(_bar).height, 88);
      t.view.padding = const FakeViewPadding(top: 24);
      t.view.viewInsets = const FakeViewPadding(bottom: 280);
      await t.pumpAndSettle();
      expect(_systemSurface, findsNothing);
      expect(t.getSize(_bar).height, 64);
      t.view.viewInsets = const FakeViewPadding();
      t.view.padding = const FakeViewPadding(top: 24, bottom: 48);
      t.view.viewPadding = const FakeViewPadding(top: 24, bottom: 48);
      await t.pumpAndSettle();
      expect(_systemSurface, findsNothing);
      expect(t.getSize(_bar).height, 112);
      t.view.physicalSize = const Size(850, 393);
      await t.pumpAndSettle();
      expect(_bar, findsNothing);
      expect(_systemSurface, findsNothing);
      expect(_systemStyle, findsNothing);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'iOS bottom inset keeps the existing continuous navigation surface',
    (t) async {
      _viewport(t, 393, 34);
      final p = await workspaceProvider(locale: 'zh');
      addTearDown(p.dispose);
      final boundary = GlobalKey();
      await t.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: WorkspaceHarness(provider: p, locale: const Locale('zh')),
        ),
      );
      await t.pumpAndSettle();
      expect(t.getSize(_bar).height, 98);
      expect(_systemSurface, findsNothing);
      expect(_systemStyle, findsNothing);
      final colors = Theme.of(t.element(_bar)).colorScheme;
      _samePaint(
        (await _pixels(t, boundary, [const Offset(2, 840)])).single,
        colors.surfaceContainerLow,
      );
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
