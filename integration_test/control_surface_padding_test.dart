import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/widgets/expressive_dialog.dart';
import 'package:sked/widgets/workspace_editor_form.dart';

import '../test/widgets/control_surface_padding_test.dart';
import '../test/widgets/date_header_padding_test.dart';
import 'support/capture_output_directory.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const outputPath = String.fromEnvironment('SKED_CONTROL_PADDING_CAPTURE_DIR');
  final captures = <Map<String, Object?>>[];

  setUpAll(() async {
    if (!Platform.isWindows) {
      throw UnsupportedError('This capture uses the Windows engine.');
    }
    if (outputPath.isNotEmpty) {
      createCaptureOutputDirectory(
        label: 'control-surface-padding',
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

  Future<void> capture(WidgetTester tester, Key key, String scene) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(key),
    );
    final date = find.byKey(const ValueKey('sked-date-month-year'));
    final disclosure = find.byType(WorkspaceEditorDisclosure).hitTestable();
    final option = find.byType(ExpressiveDialogOption).hitTestable();
    Rect? control;
    if (key == dateHeaderPaddingCaptureKey && date.evaluate().isNotEmpty) {
      control = tester.getRect(date);
    } else if (disclosure.evaluate().isNotEmpty) {
      final header = find
          .descendant(of: disclosure.last, matching: find.byType(ListTile))
          .first;
      control = tester.getRect(header);
    } else if (option.evaluate().isNotEmpty) {
      control = tester.getRect(option.first);
    }
    final frameFile = '$outputPath/$scene.png';
    await writeImage(await boundary.toImage(pixelRatio: 1), frameFile);
    String? detailFile;
    if (control != null) {
      detailFile = '$outputPath/$scene-control.png';
      final bounds = control
          .shift(-boundary.localToGlobal(Offset.zero))
          .inflate(12)
          .intersect(Offset.zero & boundary.size);
      final layer = boundary.debugLayer! as OffsetLayer;
      await writeImage(
        await layer.toImage(bounds, pixelRatio: 1.5),
        detailFile,
      );
    }
    captures.add({
      'scene': scene,
      'frame': frameFile,
      'detail': ?detailFile,
      if (control != null)
        'controlRect': [
          control.left,
          control.top,
          control.width,
          control.height,
        ],
    });
  }

  runControlSurfacePaddingTests(
    capture: outputPath.isEmpty
        ? null
        : (tester, scene) =>
              capture(tester, controlSurfacePaddingCaptureKey, scene),
  );
  runDateHeaderPaddingTests(
    capture: outputPath.isEmpty
        ? null
        : (tester, scene) =>
              capture(tester, dateHeaderPaddingCaptureKey, scene),
  );

  tearDownAll(() async {
    final report = {
      'scope': 'Windows engine, real controls with synthetic mouse and keyboard input',
      'captures': captures,
    };
    binding.reportData = report;
    if (outputPath.isEmpty) return;
    final file = File('$outputPath/manifest.json');
    if (await file.exists()) throw StateError('Preserve capture manifest');
    await file.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(report)}\n',
      flush: true,
    );
  });
}
