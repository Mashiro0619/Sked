import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

/// Creates a retained evidence directory and reports its absolute location.
/// Keep the returned directory for the whole case so captures and manifests
/// share one destination. Separate cases get separate default directories.
Directory createCaptureOutputDirectory({
  required String label,
  String configuredPath = const String.fromEnvironment('SKED_VISUAL_OUTPUT'),
  void Function(String) report = _reportCaptureOutput,
}) {
  if (!RegExp(r'^[a-z0-9][a-z0-9-]*$').hasMatch(label)) {
    throw ArgumentError.value(label, 'label', 'Use a lowercase task label.');
  }
  if (configuredPath.isNotEmpty && !path.isAbsolute(configuredPath)) {
    throw ArgumentError.value(
      configuredPath,
      'configuredPath',
      'Capture output overrides must be absolute paths.',
    );
  }
  final output =
      configuredPath.isEmpty
            ? Directory.systemTemp.createTempSync('sked-$label-')
            : Directory(configuredPath)
        ..createSync(recursive: true);
  final absolute = output.absolute;
  // Evidence is intentionally retained for inspection after the test exits.
  // Test-only callers may clean up the directory they created themselves.
  report('SKED_CAPTURE_OUTPUT $label ${jsonEncode(absolute.path)}');
  return absolute;
}

void _reportCaptureOutput(String value) => stdout.writeln(value);
