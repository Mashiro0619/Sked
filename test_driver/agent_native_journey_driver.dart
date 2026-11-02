import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:integration_test/integration_test_driver.dart';

import 'support/report_output_directory.dart';

const _checkpoints = [
  'environment',
  'runtime-loaded',
  'product-entry',
  'long-history-scroll',
  'stream-and-draft',
  'host-continuity',
  'completion-and-history',
  'cleanup',
];

const _relevantSources = [
  'integration_test/agent_native_journey_test.dart',
  'integration_test/support/agent_native_session.dart',
  'integration_test/support/agent_native_journey.dart',
  'test_driver/agent_native_journey_driver.dart',
  'lib/app_runtime.dart',
  'lib/providers/app_scope.dart',
  'lib/screens/app_home_screen.dart',
  'lib/screens/agent_page.dart',
  'lib/widgets/assistant_pane.dart',
  'lib/agent/agent_application.dart',
  'lib/agent/conversations/conversation_repository.dart',
  'lib/agent/ui/agent_conversation_view.dart',
  'lib/agent/ui/agent_conversation_list.dart',
  'lib/agent/ui/agent_transcript.dart',
  'lib/agent/runtime/agent_runtime_controller.dart',
];

Future<void> main() => integrationDriver(
  timeout: const Duration(minutes: 5),
  writeResponseOnFailure: true,
  responseDataCallback: (data) async {
    final output = createDriverReportOutputDirectory(
      label: 'agent-native-journey',
    );
    final manifest = <String, Object?>{};
    for (final path in _relevantSources) {
      final file = File(path);
      manifest[path] = await file.exists()
          ? sha256.convert(await file.readAsBytes()).toString()
          : 'missing';
    }
    final report = data?['agentNativeJourney'];
    final rawFile = File(
      '${output.path}${Platform.pathSeparator}agent-native-journey-raw.json',
    );
    // Preserve failed/malformed reports before checking any success contract.
    await _writeNew(rawFile, {
      'response': data,
      'driverSourceManifest': {
        'scope': 'relevant files read from the driver checkout; not all tracked files or binary attestation',
        'sha256': manifest,
      },
    });
    final assessmentFile = File(
      '${output.path}${Platform.pathSeparator}agent-native-journey-assessment.json',
    );
    try {
      _validate(report);
      _require(
        !manifest.containsValue('missing'),
        'A required driver source-manifest file is missing.',
      );
      await _writeNew(assessmentFile, {
        'status': 'passed',
        'protocol': 'agent-native-journey-v1',
        'rawReport': rawFile.absolute.path,
        'scope': 'native functional checkpoints; native process logs require separate review',
      });
    } catch (error, stack) {
      await _writeNew(assessmentFile, {
        'status': 'failed',
        'error': '$error',
        'stack': '$stack',
        'rawReport': rawFile.absolute.path,
      });
      rethrow;
    }
    stdout.writeln('Agent native functional report: ${rawFile.absolute.path}');
  },
);

Future<void> _writeNew(File file, Object? value) async {
  if (await file.exists()) {
    throw StateError(
      'Use a new output directory; refusing to replace ${file.absolute.path}.',
    );
  }
  await file.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(value)}\n',
    flush: true,
  );
}

void _require(bool value, String message) {
  if (!value) throw StateError(message);
}

Map _map(Object? value, String description) {
  _require(value is Map, '$description is missing or invalid.');
  return value as Map;
}

void _validate(Object? value) {
  final report = _map(value, 'Agent native journey report');
  _require(
    report['protocol'] == 'agent-native-journey-v1' &&
        report['measurement'] == 'native-functional',
    'This is not the native functional journey protocol.',
  );
  _require(
    report['status'] == 'passed',
    'The native journey failed; its checkpoints and cleanup were retained.',
  );
  final source = _map(report['source'], 'Source provenance');
  _require(
    source['revision'] is String &&
        RegExp(r'^[0-9a-f]{40}$').hasMatch(source['revision'] as String),
    'The native build must declare a full source SHA.',
  );
  _require(
    report['label'] is String &&
        RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$')
            .hasMatch(report['label'] as String),
    'The report label is invalid.',
  );
  final environment = _map(report['environment'], 'Native environment');
  final platform = environment['platform'];
  _require(
    const ['windows', 'android'].contains(platform),
    'The report did not run on a supported native platform.',
  );
  _require(
    environment['surfaceOverrides'] == false &&
        environment['executable'] is String &&
        !(environment['executable'] as String).toLowerCase().contains(
          'flutter_tester',
        ) &&
        environment['pid'] is int &&
        (environment['pid'] as int) > 0,
    'The report lacks actual native process and surface evidence.',
  );
  for (final dimension in [
    'physicalWidth',
    'physicalHeight',
    'logicalWidth',
    'logicalHeight',
    'devicePixelRatio',
  ]) {
    final value = environment[dimension];
    _require(
      value is num && value.isFinite && value > 0,
      'Native $dimension is invalid.',
    );
  }
  if (platform == 'windows') {
    _require(
      (environment['logicalWidth'] as num) >= 1100 &&
          (environment['logicalHeight'] as num) >= 600,
      'Windows did not use the required native desktop window.',
    );
  } else {
    _require(
      environment['androidApi'] is String &&
          int.tryParse(environment['androidApi'] as String) != null &&
          environment['androidAbi'] is String &&
          (environment['androidAbi'] as String).isNotEmpty,
      'Android API/ABI provenance is incomplete.',
    );
  }
  final config = _map(report['configuration'], 'Framework configuration');
  _require(
    const ['baseline', 'accessible'].contains(config['name']),
    'The configuration name is invalid.',
  );
  final accessible = config['name'] == 'accessible';
  _require(
    config['brightness'] == (accessible ? 'dark' : 'light') &&
        config['textScale'] == (accessible ? 2 : 1) &&
        config['reduceMotion'] == accessible &&
        config['disableAnimations'] == false,
    'The theme, text or reduced-motion configuration does not match the selected run.',
  );
  final fixture = _map(report['fixture'], 'Synthetic fixture');
  _require(
    fixture['longMessageCount'] == 512 &&
        fixture['shortMessageCount'] == 2 &&
        fixture['conversationCount'] == 2,
    'The required long and short history fixture was not used.',
  );
  for (final digest in ['mainSha256', 'archiveSha256', 'longHistorySha256']) {
    _require(
      fixture[digest] is String &&
          RegExp(r'^[0-9a-f]{64}$').hasMatch(fixture[digest] as String),
      'Fixture $digest is missing.',
    );
  }
  final steps = report['checkpoints'];
  _require(
    steps is List && steps.length == _checkpoints.length,
    'The required native checkpoint sequence is incomplete.',
  );
  final observations = <String, Map>{};
  for (var index = 0; index < _checkpoints.length; index++) {
    final step = _map((steps as List)[index], 'Checkpoint $index');
    _require(
      step['name'] == _checkpoints[index] && step['status'] == 'complete',
      'Checkpoint ${_checkpoints[index]} did not complete in order.',
    );
    observations[_checkpoints[index]] = _map(
      step['observations'],
      'Checkpoint observations',
    );
  }
  final loaded = observations['runtime-loaded']!;
  _require(
    loaded['agentInitialized'] == false &&
        _map(loaded['storage'], 'Initial storage')['conversationLoads'] == 0,
    'Agent history must remain dormant until the real home entry is used.',
  );
  final entry = observations['product-entry']!;
  _require(
    entry['historyMessageCount'] == 512 &&
        entry['sameApplicationAndRepository'] == true &&
        entry['host'] ==
            (platform == 'windows' ? 'AgentAssistantPane' : 'AgentPage'),
    'The formal product entry did not open its platform host and full history.',
  );
  final scroll = observations['long-history-scroll']!;
  final before = _map(scroll['before'], 'Initial reading anchor');
  final after = _map(scroll['after'], 'Scrolled reading anchor');
  _require(
    before['messageId'] != after['messageId'] &&
        after['followLatest'] == false &&
        after['extentAfter'] is num &&
        (after['extentAfter'] as num) > 72,
    'The transcript did not visibly scroll to earlier messages.',
  );
  final streaming = observations['stream-and-draft']!;
  _require(
    streaming['draftAndFocusPreserved'] == true &&
        streaming['latestActionVisible'] == true &&
        _map(streaming['provider'], 'Active streaming provider')['cancelled'] ==
            false,
    'The streaming input and reading continuity checkpoint is incomplete.',
  );
  final host = observations['host-continuity']!;
  _require(
    host['sameApplicationAndRepository'] == true &&
        _map(host['provider'], 'Provider during host return')['cancelled'] ==
            false &&
        host['route'] ==
            (platform == 'windows'
                ? 'pane → full AgentPage → pane'
                : 'full AgentPage → home → More / Agent'),
    'The platform host transition is missing.',
  );
  final completed = observations['completion-and-history']!;
  _require(
    completed['savedLongMessageCount'] == 514 &&
        completed['savedShortMessageCount'] == 2 &&
        completed['savedRunStatus'] == 'completed' &&
        completed['savedRequestOutcome'] == 'completed' &&
        completed['savedLongHistorySha256'] == fixture['longHistorySha256'] &&
        completed['independentDrafts'] == true &&
        completed['mainSnapshotUnchanged'] == true,
    'The completed persisted history, separate drafts or unchanged main workspace was not confirmed.',
  );
  final provider = _map(
    report['providerBeforeCleanup'],
    'Provider completion counters',
  );
  _require(
    provider['requests'] == 1 &&
        provider['deltas'] == 1 &&
        provider['completedReplies'] == 1 &&
        provider['cancelled'] is bool &&
        provider['transportAttempts'] == 0,
    'Provider counts, token observation or transport violated the controlled run.',
  );
  final storage = _map(
    report['storageBeforeCleanup'],
    'Final storage counters',
  );
  _require(
    storage['conversationLoads'] == 1 &&
        storage['conversationWrites'] is num &&
        (storage['conversationWrites'] as num) > 0,
    'The report did not load and save its synthetic archive.',
  );
  final cleanup = _map(report['cleanup'], 'Cleanup report');
  _require(
    cleanup['unmount'] == 'complete' &&
        cleanup['httpGuardRestored'] == true &&
        cleanup['httpOperationAttempts'] == 0 &&
        _map(cleanup['owners'], 'Runtime cleanup')['status'] == 'complete' &&
        _map(cleanup['provider'], 'Disposed provider')['closed'] == true,
    'Unmount, runtime closure, repository drains or HTTP restoration failed.',
  );
}
