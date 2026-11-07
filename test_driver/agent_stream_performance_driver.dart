import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

import 'support/report_output_directory.dart';

Future<void> main() => integrationDriver(
  timeout: const Duration(minutes: 5),
  writeResponseOnFailure: true,
  responseDataCallback: (data) async {
    final output = createDriverReportOutputDirectory(
      label: 'agent-stream-profile',
    );
    final file = File(
      '${output.path}${Platform.pathSeparator}agent-stream-profile.json',
    );
    if (await file.exists()) throw StateError('Use a fresh report directory.');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
    final report = data?['agentStreamPerformance'];
    if (report is! Map ||
        report['status'] != 'passed' ||
        report['protocol'] != 'agent-stream-frames-v1' ||
        report['buildMode'] != 'profile' ||
        report['providerRequests'] != 1 ||
        report['providerCloseCount'] != 1 ||
        report['httpAttempts'] != 0 ||
        report['deltaCount'] != 96 ||
        report['requiredIndependentProcesses'] != 3 ||
        !const ['legacy-json', 'drift-sqlite'].contains(report['backend']) ||
        (report['frames'] as List?)?.isNotEmpty != true ||
        (report['publications'] as List?)?.isNotEmpty != true ||
        report['savedReplySha256'] != report['replySha256']) {
      throw StateError(
        'The native stream sample is incomplete; raw evidence was retained.',
      );
    }
    stdout.writeln('Agent stream Profile report: ${file.path}');
  },
);
