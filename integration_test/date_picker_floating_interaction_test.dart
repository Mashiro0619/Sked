import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show Key, ValueKey;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sked/services/desktop_window_bridge.dart';

import '../test/widgets/date_picker_floating_interaction_test.dart';
import '../test/widgets/new_timetable_date_picker_position_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const outputPath = String.fromEnvironment('SKED_DATE_PICKER_CAPTURE_DIR');
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
      final surfaces = <String, Object?>{};
      for (final name in [
        'sked-date-picker-surface',
        'workspace-detail-surface',
      ]) {
        final finder = find.byKey(ValueKey(name));
        if (finder.evaluate().length != 1) continue;
        final rect = tester.getRect(finder);
        surfaces[name] = [rect.left, rect.top, rect.width, rect.height];
      }
      captures.add({
        'scene': scene,
        'file': file.path,
        'width': image.width,
        'height': image.height,
        'surfaces': surfaces,
      });
    } finally {
      image.dispose();
    }
  }

  runDatePickerFloatingInteractionTests(
    capture: outputPath.isEmpty
        ? null
        : (tester, scene) =>
              capture(tester, datePickerFloatingCaptureKey, scene),
  );
  runNewTimetableDatePickerPositionTests(
    capture: outputPath.isEmpty
        ? null
        : (tester, scene) =>
              capture(tester, newTimetableDatePickerPositionCaptureKey, scene),
  );

  tearDownAll(() async {
    final report = <String, Object?>{
      'host': Platform.operatingSystem,
      'scope': 'Windows engine interaction and rendering regression',
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
