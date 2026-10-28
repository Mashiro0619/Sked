import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import '../../integration_test/support/visual_capture_session.dart';

const _boundary = ValueKey('output-capture');

Future<void> _mount(WidgetTester tester) => tester.pumpWidget(
  const Center(
    child: RepaintBoundary(
      key: _boundary,
      child: SizedBox(
        width: 20,
        height: 10,
        child: ColoredBox(color: Color(0xff123456)),
      ),
    ),
  ),
);

void main() {
  testWidgets('capture and manifest share the retained explicit directory', (
    tester,
  ) async {
    final output = Directory.systemTemp.createTempSync('sked-session-test-');
    addTearDown(() => output.deleteSync(recursive: true));
    final session = VisualCaptureSession(
      label: 'session-test',
      configuredPath: output.path,
    );
    await _mount(tester);
    await tester.runAsync(() async {
      await session.capture(
        tester,
        boundary: find.byKey(_boundary),
        name: 'sample',
        pixelRatio: 2,
        metadata: {'case': 'sample'},
      );
      await session.writeManifest(expectedCount: 1);
    });
    final image = File(path.join(output.path, 'sample.png'));
    expect(image.readAsBytesSync().take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
    final manifest = jsonDecode(
      File(path.join(output.path, 'manifest.json')).readAsStringSync(),
    ) as Map<String, dynamic>;
    final record = (manifest['captures'] as List).single as Map;
    expect(record['file'], 'sample.png');
    expect(record['case'], 'sample');
    expect(record['widthDp'], 20);
    expect(record['heightDp'], 10);
    expect(record['widthPx'], 40);
    expect(record['heightPx'], 20);
    expect(DateTime.parse(manifest['capturedAtUtc'] as String).isUtc, isTrue);
    expect(image.existsSync(), isTrue);
  });

  testWidgets(
    'duplicate or incomplete capture keeps the image without a success manifest',
    (tester) async {
      final output = Directory.systemTemp.createTempSync(
        'sked-session-failure-',
      );
      addTearDown(() => output.deleteSync(recursive: true));
      final session = VisualCaptureSession(
        label: 'session-test',
        configuredPath: output.path,
      );
      await _mount(tester);
      await tester.runAsync(() async {
        await session.capture(
          tester,
          boundary: find.byKey(_boundary),
          name: 'sample',
        );
        final original = File(path.join(output.path, 'sample.png'))
            .readAsBytesSync();
        await expectLater(
          session.capture(
            tester,
            boundary: find.byKey(_boundary),
            name: 'sample',
          ),
          throwsA(isA<TestFailure>()),
        );
        await expectLater(
          session.writeManifest(expectedCount: 2),
          throwsA(isA<TestFailure>()),
        );
        expect(
          File(path.join(output.path, 'sample.png')).readAsBytesSync(),
          original,
        );
        expect(
          File(path.join(output.path, 'manifest.json')).existsSync(),
          isFalse,
        );
      });
    },
  );
}
