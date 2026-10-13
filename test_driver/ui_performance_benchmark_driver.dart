import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    final report = data?['uiPerformance'];
    if (report is! Map<String, dynamic> ||
        report['measurement'] != 'profile-engine-frames') {
      throw StateError(
        'The UI benchmark did not return profile engine-frame evidence.',
      );
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
    );
  },
);
