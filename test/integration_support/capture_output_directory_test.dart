import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import '../../integration_test/support/capture_output_directory.dart';

void main() {
  test(
    'default destinations are unique retained directories in system temp',
    () {
      final outputs = [
        createCaptureOutputDirectory(label: 'capture-test', configuredPath: ''),
        createCaptureOutputDirectory(label: 'capture-test', configuredPath: ''),
      ];
      addTearDown(() {
        for (final output in outputs) {
          output.deleteSync(recursive: true);
        }
      });
      final root = Directory.systemTemp.resolveSymbolicLinksSync();
      expect(outputs[0].path, isNot(outputs[1].path));
      for (final output in outputs) {
        expect(path.isWithin(root, output.resolveSymbolicLinksSync()), isTrue);
        final manifest = File(path.join(output.path, 'manifest.json'));
        manifest.writeAsStringSync('{"captures":[]}');
        expect(manifest.readAsStringSync(), '{"captures":[]}');
        expect(output.existsSync(), isTrue);
      }
    },
  );

  test(
    'an absolute override keeps its exact destination and existing evidence',
    () {
      final root = Directory.systemTemp.createTempSync(
        'sked-capture-override-',
      );
      addTearDown(() => root.deleteSync(recursive: true));
      final configured = path.join(root.path, 'nested', 'evidence');
      final first = createCaptureOutputDirectory(
        label: 'capture-test',
        configuredPath: configured,
      );
      File(path.join(first.path, 'first.png')).writeAsBytesSync([1, 2, 3]);
      final second = createCaptureOutputDirectory(
        label: 'capture-test',
        configuredPath: configured,
      );
      expect(second.path, Directory(configured).absolute.path);
      expect(File(path.join(second.path, 'first.png')).readAsBytesSync(), [
        1,
        2,
        3,
      ]);
    },
  );

  test('relative overrides and path-like labels are rejected', () {
    expect(
      () => createCaptureOutputDirectory(
        label: 'capture-test',
        configuredPath: 'relative-capture',
      ),
      throwsArgumentError,
    );
    expect(
      () =>
          createCaptureOutputDirectory(label: '../capture', configuredPath: ''),
      throwsArgumentError,
    );
  });

  test(
    'the log identifies the retained absolute destination unambiguously',
    () {
      final lines = <String>[];
      final output = createCaptureOutputDirectory(
        label: 'capture-log',
        configuredPath: '',
        report: lines.add,
      );
      addTearDown(() => output.deleteSync(recursive: true));
      expect(lines, [
        'SKED_CAPTURE_OUTPUT capture-log ${jsonEncode(output.path)}',
      ]);
      expect(
        path.isAbsolute(
          jsonDecode(lines.single.split(' ').skip(2).join(' ')) as String,
        ),
        isTrue,
      );
    },
  );
}
