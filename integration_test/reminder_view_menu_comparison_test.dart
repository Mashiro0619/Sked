import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';

import '../test/widgets/reminder_view_menu_comparison_test.dart';
import 'support/capture_output_directory.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const outputPath = String.fromEnvironment('SKED_MENU_COMPARISON_CAPTURE_DIR');
  final captures = <Map<String, Object?>>[];

  setUpAll(() async {
    if (!Platform.isWindows) {
      throw UnsupportedError('This regression uses the Windows engine.');
    }
    if (outputPath.isNotEmpty) {
      createCaptureOutputDirectory(
        label: 'reminder-menu-comparison',
        configuredPath: outputPath,
      );
    }
  });

  Future<void> writeImage(ui.Image image, String path) async {
    try {
      final file = File(path);
      if (await file.exists()) throw StateError('Preserve capture: $path');
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await file.writeAsBytes(data!.buffer.asUint8List(), flush: true);
    } finally {
      image.dispose();
    }
  }

  Future<void> capture(WidgetTester tester, String scene) async {
    if (!scene.endsWith('-layout') &&
        !scene.endsWith('-selected-hover') &&
        !scene.endsWith('-selected-focus') &&
        !scene.contains('-rtl-')) {
      return;
    }
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(reminderViewMenuCaptureKey),
    );
    final entry = find
        .byWidgetPredicate(
          (widget) => widget is PopupMenuItem || widget is MenuItemButton,
        )
        .hitTestable()
        .first;
    final surface = find
        .ancestor(
          of: entry,
          matching: find.byWidgetPredicate(
            (widget) => widget is Material && widget.elevation > 0,
          ),
        )
        .first;
    final rect = tester.getRect(surface);
    final origin = boundary.localToGlobal(Offset.zero);
    final bounds = rect
        .shift(-origin)
        .inflate(12)
        .intersect(Offset.zero & boundary.size);
    final frameFile = '$outputPath/$scene.png';
    final menuFile = '$outputPath/$scene-menu.png';
    await writeImage(await boundary.toImage(pixelRatio: 1), frameFile);
    // Render the menu bounds directly from the same frame's layer tree.
    final layer = boundary.debugLayer! as OffsetLayer;
    await writeImage(await layer.toImage(bounds, pixelRatio: 1.5), menuFile);
    captures.add({
      'scene': scene,
      'frame': frameFile,
      'menu': menuFile,
      'menuRect': [rect.left, rect.top, rect.width, rect.height],
    });
  }

  runReminderViewMenuComparisonTests(
    capture: outputPath.isEmpty ? null : capture,
  );

  tearDownAll(() async {
    final report = {
      'host': Platform.operatingSystem,
      'scope': 'Windows engine with in-memory data and synthesized mouse/keyboard input',
      'captures': captures,
    };
    binding.reportData = report;
    if (outputPath.isEmpty) return;
    final file = File('$outputPath/manifest.json');
    if (await file.exists()) throw StateError('Preserve the capture manifest');
    await file.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(report)}\n',
      flush: true,
    );
  });
}
