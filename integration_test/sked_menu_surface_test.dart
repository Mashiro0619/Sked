import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sked/services/desktop_window_bridge.dart';

import '../test/widgets/sked_menu_surface_test.dart';
import '../test/widgets/sked_menu_style_test.dart';
import '../test/widgets/workspace_menu_surface_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const outputPath = String.fromEnvironment('SKED_MENU_CAPTURE_DIR');
  final captures = <Map<String, Object?>>[];

  setUpAll(() async {
    if (!Platform.isWindows) {
      throw UnsupportedError('This regression uses the Windows engine.');
    }
    await DesktopWindowBridge.instance.initialize();
    if (outputPath.isNotEmpty) {
      await Directory(outputPath).create(recursive: true);
    }
  });

  Future<void> capture(WidgetTester tester, Key key, String scene) async {
    final file = File('$outputPath/$scene.png');
    if (await file.exists()) {
      throw StateError('Preserve the existing capture: ${file.path}');
    }
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(key),
    );
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await file.writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
      captures.add({
        'scene': scene,
        'file': file.path,
        'width': image.width,
        'height': image.height,
      });
    } finally {
      image.dispose();
    }
  }

  runSkedMenuSurfaceTests(
    capture: outputPath.isEmpty
        ? null
        : (tester, scene) => capture(tester, skedMenuSurfaceCaptureKey, scene),
  );
  runWorkspaceMenuSurfaceTests(
    capture: outputPath.isEmpty
        ? null
        : (tester, scene) =>
              capture(tester, workspaceMenuSurfaceCaptureKey, scene),
  );
  runSkedMenuStyleTests(
    capture: outputPath.isEmpty
        ? null
        : (tester, scene) => capture(tester, skedMenuStyleCaptureKey, scene),
  );

  tearDownAll(() async {
    final report = <String, Object?>{
      'host': Platform.operatingSystem,
      'scope': 'Windows engine menu rendering and interaction regression',
      'captures': captures,
    };
    binding.reportData = report;
    if (outputPath.isEmpty) return;
    final file = File('$outputPath/manifest.json');
    if (await file.exists()) {
      throw StateError('Preserve the existing capture manifest.');
    }
    await file.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(report)}\n',
      flush: true,
    );
  });
}
