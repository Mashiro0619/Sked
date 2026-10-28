import 'package:integration_test/integration_test_driver.dart';

import 'support/report_output_directory.dart';

Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    final report = data?['dataOperations'];
    if (report is! Map<String, dynamic> ||
        report['measurement'] != 'native-disk-profile' ||
        report['validation'] != 'passed') {
      throw StateError('The benchmark did not return validated Profile data.');
    }
    final label = report['label'];
    if (label is! String ||
        !RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$').hasMatch(label)) {
      throw StateError(
        'SKED_DATA_PERF_LABEL must be a short filename-safe label.',
      );
    }
    await writeResponseData(
      report,
      testOutputFilename: 'data-operations-$label',
      destinationDirectory: createDriverReportOutputDirectory(
        label: 'data-operations-benchmark',
      ).path,
    );
  },
);
