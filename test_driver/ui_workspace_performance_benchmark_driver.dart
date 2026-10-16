import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    final report = data?['uiWorkspacePerformance'];
    if (report is! Map<String, dynamic> ||
        report['measurement'] != 'profile-workspace-engine-frames' ||
        report['validation'] != 'passed' ||
        report['results'] is! List ||
        (report['results'] as List).length != 60 ||
        report['mounts'] is! List ||
        (report['mounts'] as List).length != 3) {
      throw StateError(
        'The workspace benchmark did not return the complete workspace60-v1 population.',
      );
    }
    final label = report['label'];
    if (label is! String ||
        !RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$').hasMatch(label)) {
      throw StateError(
        'SKED_UI_WORKSPACE_PERF_LABEL must be a short filename-safe label.',
      );
    }
    await writeResponseData(
      report,
      testOutputFilename: 'ui-workspace-performance-$label',
    );
  },
);
