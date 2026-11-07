import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

import 'support/report_output_directory.dart';

Future<void> main() => integrationDriver(
  timeout: const Duration(minutes: 35),
  writeResponseOnFailure: true,
  responseDataCallback: (data) async {
    final output = createDriverReportOutputDirectory(label: 'agent-live-model');
    final report = data?['agentLiveModel'];
    final file = File(
      '${output.path}${Platform.pathSeparator}agent-live-model.json',
    );
    if (await file.exists()) throw StateError('Use a fresh report directory.');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
    if (report is! Map ||
        report['outcome'] != 'passed' ||
        report['businessData'] != 'synthetic' ||
        !RegExp(r'^[a-f0-9]{40}$').hasMatch('${report['sourceSha']}')) {
      throw StateError(
        'Real-model acceptance did not complete; the returned evidence was retained.',
      );
    }
    stdout.writeln('Agent live-model report: ${file.path}');
  },
);
