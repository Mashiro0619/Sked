import 'dart:io';

import '../../integration_test/support/capture_output_directory.dart';

/// Keeps driver reports outside the checkout unless an absolute destination is
/// explicitly configured. The directory remains available after the driver exits.
Directory createDriverReportOutputDirectory({
  required String label,
  Map<String, String>? environment,
}) => createCaptureOutputDirectory(
  label: label,
  configuredPath:
      (environment ?? Platform.environment)['FLUTTER_TEST_OUTPUTS_DIR'] ?? '',
);
