import 'package:integration_test/integration_test_driver.dart';

import 'support/report_output_directory.dart';

Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    final report = data?['uiPerformance'];
    if (report is! Map<String, dynamic> ||
        report['measurement'] != 'profile-engine-frames') {
      throw StateError(
        'The UI benchmark did not return profile engine-frame evidence.',
      );
    }
    final protocol = report['protocol'];
    final scrollTargeting = protocol is Map
        ? protocol['scrollTargeting']
        : null;
    if (scrollTargeting is! Map ||
        scrollTargeting['version'] != 1 ||
        scrollTargeting['id'] != 'workspace-canvas-scroll-v1' ||
        scrollTargeting['scope'] != 'workspace-canvas') {
      throw StateError('The UI benchmark must scroll its primary canvas.');
    }
    final label = report['label'];
    if (label is! String ||
        !RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$').hasMatch(label)) {
      throw StateError(
        'SKED_UI_PERF_LABEL must be a short filename-safe label.',
      );
    }
    await writeResponseData(
      report,
      testOutputFilename: 'ui-performance-$label',
      destinationDirectory: createDriverReportOutputDirectory(
        label: 'ui-performance-benchmark',
      ).path,
    );
  },
);
