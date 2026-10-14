import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Captures Flutter client content; simulated platforms do not imply hardware
/// acceptance. A manifest is published only after every expected scene succeeds.
class VisualCaptureSession {
  VisualCaptureSession({required String defaultOutput})
    : _output = Directory(
        const String.fromEnvironment('SKED_VISUAL_OUTPUT').isEmpty
            ? defaultOutput
            : const String.fromEnvironment('SKED_VISUAL_OUTPUT'),
      );

  final Directory _output;
  final _captures = <Map<String, Object?>>[];

  Future<void> capture(
    WidgetTester tester, {
    required Finder boundary,
    required String name,
    double pixelRatio = 1,
    Map<String, Object?> metadata = const {},
  }) async {
    expect(tester.takeException(), isNull, reason: name);
    final filename = '$name.png';
    expect(
      _captures.any((capture) => capture['file'] == filename),
      isFalse,
      reason: 'Each scene must have a distinct filename: $filename',
    );
    final render = tester.renderObject<RenderRepaintBoundary>(boundary);
    final image = await render.toImage(pixelRatio: pixelRatio);
    try {
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      await _output.create(recursive: true);
      await File('${_output.path}/$filename')
          .writeAsBytes(bytes.buffer.asUint8List());
      _captures.add({
        ...metadata,
        'file': filename,
        'widthDp': render.size.width,
        'heightDp': render.size.height,
        'widthPx': image.width,
        'heightPx': image.height,
        'pixelRatio': pixelRatio,
        'platformStyle': defaultTargetPlatform.name,
      });
    } finally {
      image.dispose();
    }
  }

  Future<void> writeManifest({required int expectedCount}) async {
    expect(_captures, hasLength(expectedCount));
    await File('${_output.path}/manifest.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'schemaVersion': 1,
        'capturedAtUtc': DateTime.now().toUtc().toIso8601String(),
        'host': Platform.operatingSystem,
        'evidence':
            'Flutter client rendering with isolated fixtures; target '
            'platform geometry may be simulated, not hardware acceptance.',
        'captures': _captures,
      }),
    );
  }
}
