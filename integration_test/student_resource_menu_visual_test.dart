import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/desktop_window_bridge.dart';

import '../test/support/workspace_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('student sidebar more icon stays centered with real icon fonts', (
    t,
  ) async {
    await DesktopWindowBridge.instance.initialize();
    final output = Directory(
      const String.fromEnvironment(
        'SKED_VISUAL_OUTPUT',
        defaultValue: '.scratch/student-resource-menu-visual',
      ),
    );
    await output.create(recursive: true);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.view.resetPhysicalSize);
    final wasAvailable = DesktopWindowBridge.instance.available;
    try {
      for (final (name, scale, empty, platform) in [
        ('desktop-empty', 1.0, true, TargetPlatform.windows),
        ('desktop-populated', 1.0, false, TargetPlatform.windows),
        ('desktop-rtl', 1.3, true, TargetPlatform.windows),
        ('desktop-large-dark', 2.0, true, TargetPlatform.windows),
        ('tablet-simulated', 1.0, true, TargetPlatform.android),
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        DesktopWindowBridge.instance.available =
            platform == TargetPlatform.windows;
        t.view.physicalSize = const Size(1920, 1080);
        final p = await workspaceProvider(
          locale: 'zh',
          storage: empty
              ? WorkspaceMemoryStorage(
                  buildInitialAppData(
                    buildDefaultPeriodTimes(),
                    localeCode: 'zh',
                  ),
                )
              : null,
        );
        final boundary = GlobalKey();
        await t.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: WorkspaceHarness(
              provider: p,
              locale: const Locale('zh'),
              textScale: scale,
              textDirection: scale == 1.3
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              brightness: scale == 2 ? Brightness.dark : Brightness.light,
            ),
          ),
        );
        await t.pumpAndSettle();
        final menu = find
            .byKey(const ValueKey('student-resource-menu'))
            .hitTestable();
        final icon = find.descendant(
          of: menu,
          matching: find.byIcon(Icons.more_horiz),
        );
        final glyph = find.descendant(
          of: icon,
          matching: find.byType(RichText),
        );
        final paragraph = t.renderObject<RenderParagraph>(glyph);
        final glyphBox = paragraph
            .getBoxesForSelection(
              const TextSelection(baseOffset: 0, extentOffset: 1),
            )
            .single
            .toRect();
        expect(
          (paragraph.localToGlobal(glyphBox.center) - t.getCenter(menu))
              .distance,
          lessThan(0.01),
        );
        final panel = t.getRect(
          find.byKey(const ValueKey('workspace-resource-panel')).hitTestable(),
        );
        final cropRect = Rect.fromLTRB(
          panel.left,
          panel.top,
          panel.right,
          t.getRect(menu).bottom + 32,
        );
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: 1);
        try {
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder);
          canvas.drawImageRect(
            image,
            cropRect,
            Rect.fromLTWH(0, 0, cropRect.width, cropRect.height),
            Paint(),
          );
          final picture = recorder.endRecording();
          final crop = await picture.toImage(
            cropRect.width.ceil(),
            cropRect.height.ceil(),
          );
          picture.dispose();
          try {
            final data = (await crop.toByteData(
              format: ui.ImageByteFormat.png,
            ))!;
            await File('${output.path}/$name.png')
                .writeAsBytes(data.buffer.asUint8List());
          } finally {
            crop.dispose();
          }
        } finally {
          image.dispose();
        }
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
        await t.pumpAndSettle();
        p.dispose();
      }
    } finally {
      debugDefaultTargetPlatformOverride = null;
      DesktopWindowBridge.instance.available = wasAvailable;
    }
  });
}
