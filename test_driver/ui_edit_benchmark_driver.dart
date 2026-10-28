import 'package:integration_test/integration_test_driver.dart';

import 'support/report_output_directory.dart';

Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    final report = data?['uiEdit'];
    if (report is! Map<String, dynamic> ||
        report['measurement'] != 'native-ui-edit-profile' ||
        report['validation'] != 'passed') {
      throw StateError(
        'The editor benchmark did not return validated Profile data.',
      );
    }
    final label = report['label'];
    if (label is! String ||
        !RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$').hasMatch(label)) {
      throw StateError('SKED_UI_EDIT_LABEL must be a filename-safe label.');
    }
    await writeResponseData(
      report,
      testOutputFilename: 'ui-edit-$label',
      destinationDirectory: createDriverReportOutputDirectory(
        label: 'ui-edit-benchmark',
      ).path,
    );
  },
);
