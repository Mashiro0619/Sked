import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test_driver.dart';
import 'package:path/path.dart' as path;

import '../../test_driver/support/report_output_directory.dart';

void main() {
  test(
    'the driver writes a retained JSON report in its temporary default',
    () async {
      final output = createDriverReportOutputDirectory(
        label: 'driver-report-test',
        environment: {},
      );
      addTearDown(() => output.deleteSync(recursive: true));
      expect(
        path.isWithin(
          Directory.systemTemp.resolveSymbolicLinksSync(),
          output.resolveSymbolicLinksSync(),
        ),
        isTrue,
      );
      const report = {
        'validation': 'passed',
        'results': [1, 2],
      };
      await writeResponseData(
        report,
        testOutputFilename: 'sample-report',
        destinationDirectory: output.path,
      );
      final file = File(path.join(output.path, 'sample-report.json'));
      expect(jsonDecode(await file.readAsString()), report);
      expect(output.existsSync(), isTrue);
    },
  );

  test(
    'the driver honors the absolute environment override without clearing it',
    () {
      final root = Directory.systemTemp.createTempSync('sked-driver-override-');
      addTearDown(() => root.deleteSync(recursive: true));
      final existing = File(path.join(root.path, 'earlier.json'))
        ..writeAsStringSync('{"retained":true}');
      final output = createDriverReportOutputDirectory(
        label: 'driver-report-test',
        environment: {'FLUTTER_TEST_OUTPUTS_DIR': root.path},
      );
      expect(output.path, root.absolute.path);
      expect(existing.readAsStringSync(), '{"retained":true}');
      expect(
        () => createDriverReportOutputDirectory(
          label: 'driver-report-test',
          environment: {'FLUTTER_TEST_OUTPUTS_DIR': 'relative-output'},
        ),
        throwsArgumentError,
      );
    },
  );
}
