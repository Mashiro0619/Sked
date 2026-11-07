import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

import 'support/report_output_directory.dart';

Future<void> main() => integrationDriver(
  timeout: const Duration(minutes: 6),
  writeResponseOnFailure: true,
  responseDataCallback: (data) async {
    final output = createDriverReportOutputDirectory(
      label: 'agent-native-states',
    );
    final report = data?['agentRunStates'];
    final file = File(
      '${output.path}${Platform.pathSeparator}agent-native-states.json',
    );
    if (await file.exists()) throw StateError('Use a fresh report directory.');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
    if (report is! Map ||
        report['status'] != 'passed' ||
        report['httpAttempts'] != 0 ||
        !RegExp(r'^[a-f0-9]{40}$').hasMatch('${report['sourceSha']}')) {
      throw StateError(
        'Native state acceptance did not complete; the returned evidence was retained.',
      );
    }
    final states = report['states'];
    final names = states is List
        ? states.map((state) => state is Map ? state['state'] : null).toSet()
        : <Object?>{};
    if (names.length != 6 ||
        !names.containsAll(const {
          'running',
          'approval',
          'question',
          'completed',
          'error',
          'recovery',
        })) {
      throw StateError(
        'Native state evidence does not contain all six states.',
      );
    }
    stdout.writeln('Agent native-state report: ${file.path}');
  },
);
