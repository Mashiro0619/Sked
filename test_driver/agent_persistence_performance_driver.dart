import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:integration_test/integration_test_driver.dart';

import 'support/report_output_directory.dart';

Future<void> main() => integrationDriver(
  timeout: const Duration(minutes: 5),
  writeResponseOnFailure: true,
  responseDataCallback: (data) async {
    final output = createDriverReportOutputDirectory(
      label: 'agent-persistence-profile',
    );
    final file = File(
      '${output.path}${Platform.pathSeparator}agent-persistence-profile.json',
    );
    if (await file.exists()) throw StateError('Use a fresh report directory.');
    final sources = <String, String>{};
    for (final name in [
      'benchmark/src/agent_persistence_performance.dart',
      'benchmark/src/agent_persistence_backend.dart',
      'integration_test/agent_persistence_performance_benchmark_test.dart',
      'integration_test/support/agent_native_session.dart',
      'lib/agent/conversations/conversation_repository.dart',
      'lib/agent/conversations/conversation_models.dart',
      'lib/agent/conversations/conversation_storage_io.dart',
      'lib/agent/store/agent_store.dart',
    ]) {
      final source = File(name);
      if (await source.exists()) {
        sources[name] = sha256.convert(await source.readAsBytes()).toString();
      }
    }
    await file.writeAsString(
      const JsonEncoder.withIndent('  ')
          .convert({'response': data, 'sourceSha256': sources}),
    );
    final report = data?['agentPersistencePerformance'];
    if (report is! Map ||
        report['status'] != 'passed' ||
        report['protocol'] != 'agent-persistence-v1' ||
        report['buildMode'] != 'profile' ||
        !const ['legacy-json', 'drift-sqlite'].contains(report['backend']) ||
        report['longMessageCount'] != 512 ||
        report['shortMessageCount'] != 2 ||
        report['updateCount'] != 32 ||
        (report['phases'] as List).length != 35 ||
        (report['readback'] as Map)['verified'] != true ||
        report['cleanup'] != 'complete') {
      throw StateError(
        'The persistence sample failed; raw evidence was retained.',
      );
    }
    stdout.writeln('Agent persistence Profile report: ${file.path}');
  },
);
