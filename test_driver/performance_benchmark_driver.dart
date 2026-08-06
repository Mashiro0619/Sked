import 'dart:async';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() {
  return integrationDriver(
    responseDataCallback: (data) async {
      final performance = data?['performance'];
      if (performance is! Map<String, dynamic>) {
        throw StateError('Android benchmark did not return performance data.');
      }
      await writeResponseData(
        performance,
        testOutputFilename: 'phase8_android_profile',
      );
    },
  );
}
