import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/widgets/floating_panel_anchor_regression_test.dart' as anchors;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Keep the two workspace families in separate native runner processes:
  // --dart-define=SKED_VISUAL_GROUP=student (default) or =general.
  final group = anchors.FloatingAnchorVisualGroup.values.byName(
    const String.fromEnvironment('SKED_VISUAL_GROUP', defaultValue: 'student'),
  );
  anchors.runFloatingAnchorRegressionTests(
    group: group,
    capture: (tester, scene) async {
      final output = Directory(
        const String.fromEnvironment(
          'SKED_VISUAL_OUTPUT',
          defaultValue: '.scratch/floating-panel-anchor',
        ),
      );
      await output.create(recursive: true);
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(anchors.floatingAnchorCaptureKey),
      );
      final image = await boundary.toImage(pixelRatio: 1);
      try {
        final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        await File('${output.path}/$scene.png')
            .writeAsBytes(bytes.buffer.asUint8List());
      } finally {
        image.dispose();
      }
    },
  );
}
