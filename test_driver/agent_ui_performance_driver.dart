import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:integration_test/integration_test_driver.dart';

import '../benchmark/src/ui_performance_metrics.dart';
import 'support/report_output_directory.dart';

const _windowsActions = [
  'agent.entry.open',
  'agent.pane.scroll_older',
  'agent.pane_to_workspace',
  'agent.workspace.scroll_older',
  'agent.workspace_to_pane',
  'agent.pane.jump_latest',
  'agent.pane.close',
];
const _androidActions = [
  'agent.entry.open',
  'agent.page.scroll_older',
  'agent.page.close_reading',
  'agent.page.reopen_reading',
  'agent.page.jump_latest',
  'agent.page.close_latest',
];
const _sources = [
  'integration_test/agent_ui_performance_benchmark_test.dart',
  'integration_test/support/agent_native_session.dart',
  'benchmark/src/agent_ui_performance_scenarios.dart',
  'benchmark/src/ui_performance_metrics.dart',
  'benchmark/src/native_semantics_probe.dart',
  'test_driver/agent_ui_performance_driver.dart',
  'benchmark/AGENT_UI_PERFORMANCE.md',
  'lib/app_runtime.dart',
  'lib/providers/app_scope.dart',
  'lib/screens/app_home_screen.dart',
  'lib/screens/agent_page.dart',
  'lib/widgets/assistant_pane.dart',
  'lib/agent/agent_application.dart',
  'lib/agent/conversations/conversation_models.dart',
  'lib/agent/conversations/conversation_repository.dart',
  'lib/agent/ui/agent_conversation_view.dart',
  'lib/agent/ui/agent_transcript.dart',
];

Future<void> main() => integrationDriver(
  timeout: const Duration(minutes: 8),
  writeResponseOnFailure: true,
  responseDataCallback: (data) async {
    final output = createDriverReportOutputDirectory(label: 'agent-ui-profile');
    final manifest = <String, String>{};
    for (final path in _sources) {
      final file = File(path);
      manifest[path] = await file.exists()
          ? sha256.convert(await file.readAsBytes()).toString()
          : 'missing';
    }
    final raw = File(
      '${output.path}${Platform.pathSeparator}agent-ui-profile-raw.json',
    );
    final assessment = File(
      '${output.path}${Platform.pathSeparator}agent-ui-profile-assessment.json',
    );
    await _writeNew(raw, {
      'response': data,
      'driverSourceManifest': {
        'scope': 'relevant source files in the driver checkout; not all tracked files or binary attestation',
        'sha256': manifest,
      },
    });
    try {
      _validate(data?['agentUiPerformance']);
      _require(
        !manifest.containsValue('missing'),
        'A required source-manifest file is missing.',
      );
      await _writeNew(assessment, {
        'status': 'passed',
        'protocol': 'agent-ui-frames-v1',
        'rawReport': raw.absolute.path,
        'scope': 'one independent Profile process; comparisons require three matched processes per side/platform/configuration',
        'nativeLogs': 'review full stdout/stderr separately; AXTree/fatal errors invalidate the run',
      });
    } catch (error, stack) {
      await _writeNew(assessment, {
        'status': 'failed',
        'error': '$error',
        'stack': '$stack',
        'rawReport': raw.absolute.path,
      });
      rethrow;
    }
    stdout.writeln('Agent Profile frame report: ${raw.absolute.path}');
  },
);

Future<void> _writeNew(File file, Object? value) async {
  _require(
    !await file.exists(),
    'Use a new output directory; refusing to replace ${file.absolute.path}.',
  );
  await file.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(value)}\n',
    flush: true,
  );
}

void _require(bool value, String message) {
  if (!value) throw StateError(message);
}

Map _map(Object? value, String name) {
  _require(value is Map, '$name must be an object.');
  return value as Map;
}

List _list(Object? value, String name) {
  _require(value is List, '$name must be a list.');
  return value as List;
}

num _number(Object? value, String name) {
  _require(value is num && value.isFinite, '$name must be a finite number.');
  return value as num;
}

int _integer(Object? value, String name) {
  _require(value is int, '$name must be an integer.');
  return value as int;
}

bool _sha256(Object? value) =>
    value is String && RegExp(r'^[0-9a-f]{64}$').hasMatch(value);

void _validate(Object? value) {
  final report = _map(value, 'Agent Profile report');
  _require(
    report['schemaVersion'] == 1 &&
        report['harnessVersion'] == 1 &&
        report['measurement'] == 'profile-engine-frames' &&
        report['validation'] == 'passed',
    'The Agent Profile run failed or used another measurement protocol; raw failure evidence was retained.',
  );
  _require(
    report['revision'] is String &&
        RegExp(r'^[0-9a-f]{40}$').hasMatch(report['revision'] as String),
    'A full source revision is required.',
  );
  _require(
    report['label'] is String &&
        RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$')
            .hasMatch(report['label'] as String),
    'Invalid report label.',
  );
  final protocol = _map(report['protocol'], 'Protocol');
  final scroll = _map(protocol['scrollTargeting'], 'Scroll protocol');
  _require(
    protocol['id'] == 'agent-ui-frames-v1' &&
        protocol['version'] == 1 &&
        protocol['nativeSemanticsHarnessVersion'] == 2 &&
        protocol['iterations'] == 2 &&
        protocol['requiredIndependentProcesses'] == 3 &&
        protocol['deliveryWaitMs'] == 1200 &&
        scroll['id'] == 'agent-transcript-scroll-v1' &&
        scroll['version'] == 1 &&
        scroll['scope'] == 'agent-transcript' &&
        scroll['key'] == 'agent-transcript-native-long-history',
    'The report must use the fixed Agent transcript population and native semantics protocol.',
  );
  final config = _map(report['configuration'], 'Configuration');
  _require(
    const ['baseline', 'accessible'].contains(config['name']),
    'Unknown configuration.',
  );
  final accessible = config['name'] == 'accessible';
  _require(
    config['brightness'] == (accessible ? 'dark' : 'light') &&
        config['textScale'] == (accessible ? 2 : 1) &&
        config['reduceMotion'] == accessible &&
        config['disableAnimations'] == false,
    'The requested framework configuration is inconsistent.',
  );
  final runtime = _map(report['runtime'], 'Native runtime');
  final platform = runtime['os'];
  _require(
    const ['windows', 'android'].contains(platform) &&
        runtime['profile'] == true &&
        runtime['surfaceOverrides'] == false &&
        _integer(runtime['pid'], 'PID') > 0 &&
        runtime['executable'] is String &&
        !(runtime['executable'] as String).toLowerCase().contains(
          'flutter_tester',
        ),
    'Native Profile process provenance is missing.',
  );
  final dpr = _number(runtime['dpr'], 'DPR').toDouble();
  final refresh = _number(runtime['refreshRateHz'], 'Refresh rate').toDouble();
  _require(dpr > 0 && refresh > 0, 'DPR and refresh rate must be positive.');
  final nativeSize = _map(runtime['nativeLogicalSize'], 'Native logical size');
  final physical = _map(runtime['nativePhysicalSize'], 'Native physical size');
  final width = _number(nativeSize['width'], 'Native width').toDouble();
  final height = _number(nativeSize['height'], 'Native height').toDouble();
  _require(
    width > 0 &&
        height > 0 &&
        (_number(physical['width'], 'Physical width') / dpr - width).abs() <
            0.001 &&
        (_number(physical['height'], 'Physical height') / dpr - height).abs() <
            0.001,
    'The native dimensions do not match the reported DPR.',
  );
  if (platform == 'windows') {
    _require(
      width >= 1100 && height >= 600,
      'The Windows window is below the required native size.',
    );
  } else {
    final properties = _map(runtime['androidProperties'], 'Android properties');
    _require(
      properties['ro.build.version.sdk'] is String &&
          int.tryParse(properties['ro.build.version.sdk'] as String) != null &&
          properties['ro.product.cpu.abi'] is String &&
          (properties['ro.product.cpu.abi'] as String).isNotEmpty,
      'The Android API/ABI provenance is incomplete.',
    );
    if (runtime['deviceKind'] == 'emulator') {
      _require(
        properties['ro.kernel.qemu'] == '1',
        'Emulator classification lacks its recorded QEMU flag.',
      );
    }
  }
  final semantics = _map(runtime['semantics'], 'Native semantics');
  final start = semantics['nativeStart'];
  _require(
    start is bool &&
        semantics['frameworkStart'] == start &&
        semantics['nativeEnd'] == start &&
        semantics['frameworkEnd'] == start &&
        _list(semantics['observedChanges'], 'Semantics changes').isEmpty,
    'Native/framework semantics changed or disagreed during preparation, work, cleanup or delivery.',
  );
  final fixture = _map(report['fixture'], 'Fixed fixture');
  _require(
    fixture['longMessageCount'] == 512 &&
        fixture['shortMessageCount'] == 2 &&
        fixture['conversationCount'] == 2 &&
        _sha256(fixture['mainSha256']) &&
        _sha256(fixture['archiveSha256']) &&
        _sha256(fixture['longHistorySha256']),
    'The fixed 512-message input and its source hashes are required.',
  );
  final history = _map(report['historyAfterActions'], 'Final history');
  _require(
    history['longMessageCount'] == 512 &&
        history['longHistorySha256'] == fixture['longHistorySha256'] &&
        history['selectedId'] == 'native-long-history' &&
        history['draftsUnchanged'] == true,
    'The Profile actions changed the input history, draft or selected conversation.',
  );
  _idleProvider(_map(report['providerBeforeCleanup'], 'Idle provider'));
  final beforeStore = _map(report['storageBeforeActions'], 'Initial storage');
  final afterStore = _map(report['storageAfterActions'], 'Final storage');
  _require(
    beforeStore['conversationLoads'] == 0 &&
        afterStore['conversationLoads'] == 1,
    'The first/warm sequence did not share a single archive load.',
  );
  final actions = platform == 'windows' ? _windowsActions : _androidActions;
  _require(
    jsonEncode(report['expectedActions']) == jsonEncode(actions),
    'The required action list differs.',
  );
  final results = _list(report['results'], 'Action windows');
  _require(
    results.length == actions.length * 2,
    'The complete cold and warm action population is missing.',
  );
  var previousEnd = 0;
  var assignedFrameCount = 0;
  Map? closedAndroidReading;
  for (var index = 0; index < results.length; index++) {
    final row = _map(results[index], 'Action window');
    final iteration = index ~/ actions.length;
    final scenario = actions[index % actions.length];
    _require(
      row['scenario'] == scenario &&
          row['iteration'] == iteration &&
          row['phase'] == (iteration == 0 ? 'cold' : 'warm') &&
          row['status'] == 'passed' &&
          row['actionStatus'] == 'passed' &&
          row['frameValidation'] == 'present',
      'An ordered cold/warm action failed or is missing.',
    );
    final start = _integer(row['startUs'], 'Window start');
    final end = _integer(row['endUs'], 'Window end');
    _require(
      start >= previousEnd && end > start && row['elapsedUs'] == end - start,
      'Action windows overlap or have invalid monotonic bounds.',
    );
    previousEnd = end;
    _require(
      row['providerRequestsBefore'] == 0 && row['providerRequestsAfter'] == 0,
      'An action sampled an active model request.',
    );
    final rowSize = _map(row['nativeLogicalSize'], 'Action native size');
    _require(
      rowSize['width'] == width &&
          rowSize['height'] == height &&
          row['dpr'] == dpr,
      'The native dimensions/DPR changed between actions.',
    );
    final rssBefore = _integer(row['rssBeforeBytes'], 'RSS before');
    final rssAfter = _integer(row['rssAfterBytes'], 'RSS after');
    _require(
      rssBefore > 0 &&
          rssAfter > 0 &&
          row['rssDeltaBytes'] == rssAfter - rssBefore,
      'RSS observations are incomplete.',
    );
    final frames = [
      for (final raw in _list(row['frames'], 'Engine frames')) _frame(raw),
    ];
    _require(
      frames.isNotEmpty && row['frameCount'] == frames.length,
      'A required action has no engine frames.',
    );
    for (final frame in frames) {
      _require(
        frame.vsyncStart >= start && frame.vsyncStart < end,
        'A frame was assigned by callback arrival instead of its vsync timestamp.',
      );
    }
    assignedFrameCount += frames.length;
    final summary = summarizeUiFrames(frames, frameBudgetUs: 1000000 / refresh);
    for (final entry in summary.entries) {
      _require(
        jsonEncode(row[entry.key]) == jsonEncode(entry.value),
        'Frame summary ${entry.key} does not match the retained raw observations.',
      );
    }
    final details = _map(row['details'], 'Action details');
    _require(
      details['sameApplicationAndRepository'] == true,
      'The shared product host was not verified.',
    );
    final observed = _map(
      details['observedConfiguration'],
      'Observed host configuration',
    );
    _require(
      observed['brightness'] == config['brightness'] &&
          observed['textScale'] == config['textScale'] &&
          observed['reduceMotion'] == accessible &&
          observed['disableAnimations'] == false,
      'The actual host configuration differs from the requested input.',
    );
    final checkpoints = [
      for (final raw in _list(details['checkpoints'], 'Reading checkpoints'))
        _checkpoint(raw),
    ];
    _require(
      checkpoints.isNotEmpty,
      'An action lacks actual visible transcript evidence.',
    );
    switch (scenario) {
      case 'agent.entry.open':
        _require(
          details['conversationLoadsBefore'] == (iteration == 0 ? 0 : 1) &&
              details['conversationLoadsAfter'] == 1 &&
              details['processFirstAgentOpen'] == (iteration == 0) &&
              details['runtimeWasInitialized'] == (iteration != 0),
          'Cold/warm entry state does not match the same-runtime protocol.',
        );
        _latest(checkpoints.single);
      case 'agent.pane.scroll_older' ||
          'agent.workspace.scroll_older' ||
          'agent.page.scroll_older':
        _require(
          details['gestureCount'] == 3 &&
              details['scrollStatus'] == 'scrolled' &&
              checkpoints.length == 5 &&
              checkpoints.first['firstMessageId'] !=
                  checkpoints.last['firstMessageId'] &&
              checkpoints.last['followLatest'] == false &&
              _number(
                    checkpoints.last['extentAfter'],
                    'Scrolled remaining extent',
                  ) >
                  72,
          'The action did not scroll actual long-history content.',
        );
      case 'agent.pane_to_workspace' || 'agent.workspace_to_pane':
        _require(
          checkpoints.length == 2 && details['readingPreserved'] == true,
          'The pane/workspace reading checkpoints are incomplete.',
        );
        _sameReading(checkpoints.first, checkpoints.last);
      case 'agent.pane.jump_latest' || 'agent.page.jump_latest':
        _require(
          checkpoints.length == 2 &&
              checkpoints.first['followLatest'] == false &&
              details['latestConfirmed'] == true,
          'Jump-to-latest lacks its earlier-reading start.',
        );
        _latest(checkpoints.last);
      case 'agent.page.close_reading':
        _require(
          checkpoints.single['followLatest'] == false &&
              details['returnedHome'] == true,
          'Android close did not start from earlier reading.',
        );
        closedAndroidReading = checkpoints.single;
      case 'agent.page.reopen_reading':
        _require(
          closedAndroidReading != null &&
              details['readingPreserved'] == true &&
              details['conversationLoadsBefore'] == 1 &&
              details['conversationLoadsAfter'] == 1,
          'Android reopen did not retain the existing conversation repository.',
        );
        _sameReading(closedAndroidReading!, checkpoints.single);
        closedAndroidReading = null;
      case 'agent.pane.close' || 'agent.page.close_latest':
        _require(
          details['returnedHome'] == true &&
              details['conversationLoadsAfter'] == 1,
          'The sequence did not return to the same prepared home.',
        );
        _latest(checkpoints.single);
    }
  }
  final waitStart = _integer(
    report['frameDeliveryWaitStartUs'],
    'Frame delivery start',
  );
  final waitEnd = _integer(
    report['frameDeliveryWaitEndUs'],
    'Frame delivery end',
  );
  _require(
    waitStart >= previousEnd && waitEnd > waitStart,
    'The engine batch-delivery wait overlapped a measured action.',
  );
  final unassigned = [
    for (final raw in _list(report['unassignedFrames'], 'Unassigned frames'))
      _frame(raw),
  ];
  for (final frame in unassigned) {
    _require(
      !results.any((value) {
        final row = value as Map;
        return frame.vsyncStart >= (row['startUs'] as int) &&
            frame.vsyncStart < (row['endUs'] as int);
      }),
      'An unassigned frame belongs to a measured action.',
    );
  }
  final listener = _map(report['listener'], 'Timing listener');
  _require(
    listener['attachments'] == 1 &&
        listener['detachments'] == 1 &&
        listener['observedFrameCount'] ==
            assignedFrameCount + unassigned.length,
    'The raw frame population or single-listener lifetime is incomplete.',
  );
  final cleanup = _map(report['cleanup'], 'Cleanup');
  _require(
    cleanup['unmount'] == 'complete' &&
        cleanup['httpGuardRestored'] == true &&
        cleanup['httpOperationAttempts'] == 0 &&
        _map(cleanup['owners'], 'Owner cleanup')['status'] == 'complete',
    'Cleanup failed.',
  );
  final disposedProvider = _map(cleanup['provider'], 'Disposed provider');
  _idleProvider(disposedProvider);
  _require(disposedProvider['closed'] == true, 'The provider was not closed.');
  const phases = [
    'prepare',
    'actions',
    'cleanup',
    'frame-delivery',
    'semantics-validation',
    'frame-validation',
  ];
  final actualPhases = _list(report['phases'], 'Protocol phases');
  _require(
    actualPhases.length == phases.length &&
        _list(report['failures'], 'Failures').isEmpty,
    'A required preparation/cleanup/validation phase is missing or failed.',
  );
  for (var index = 0; index < phases.length; index++) {
    final phase = _map(actualPhases[index], 'Phase');
    _require(
      phase['name'] == phases[index] && phase['status'] == 'passed',
      'A protocol phase did not pass in order.',
    );
  }
}

void _idleProvider(Map provider) {
  _require(
    provider['requests'] == 0 &&
        provider['deltas'] == 0 &&
        provider['completedReplies'] == 0 &&
        provider['transportAttempts'] == 0 &&
        provider['cancelled'] == false,
    'The Agent frame population includes model activity or HTTP attempts.',
  );
}

UiPerformanceFrame _frame(Object? value) {
  final frame = _map(value, 'Engine frame');
  final values = [
    for (final key in [
      'vsyncStartUs',
      'buildUs',
      'rasterUs',
      'totalSpanUs',
      'vsyncOverheadUs',
    ])
      _integer(frame[key], key),
  ];
  _require(
    values.every((value) => value >= 0),
    'Negative engine timing is invalid.',
  );
  return UiPerformanceFrame(
    vsyncStart: values[0],
    build: values[1],
    raster: values[2],
    total: values[3],
    vsyncOverhead: values[4],
  );
}

Map _checkpoint(Object? value) {
  final checkpoint = _map(value, 'Reading checkpoint');
  _require(
    checkpoint['scrollScope'] == 'agent-transcript' &&
        checkpoint['scrollTarget'] == 'agent-transcript-native-long-history' &&
        checkpoint['selectedId'] == 'native-long-history',
    'The observed scroll surface is not Agent history.',
  );
  _require(
    _number(checkpoint['viewportWidth'], 'Transcript width') > 0 &&
        _number(checkpoint['viewportHeight'], 'Transcript height') > 0 &&
        _number(checkpoint['firstMessageHeight'], 'Message height') > 0,
    'The actual reading viewport is invalid.',
  );
  _number(checkpoint['messageFraction'], 'Message fraction');
  final messages = _list(checkpoint['visibleMessages'], 'Visible messages');
  _require(
    messages.isNotEmpty &&
        (messages.first as Map)['id'] == checkpoint['firstMessageId'],
    'The actual first visible message is missing.',
  );
  for (final value in messages) {
    final message = _map(value, 'Visible message');
    final id = message['id'];
    _require(
      message['textSource'] == 'render-paragraph-and-editable' &&
          _integer(message['renderParagraphCount'], 'RenderParagraph count') +
                  _integer(
                    message['renderEditableCount'],
                    'RenderEditable count',
                  ) >
              0,
      'The message body was not read from its actual rendered text objects.',
    );
    _require(
      id is String &&
          RegExp(r'^native-message-\d{4}$').hasMatch(id) &&
          int.parse(id.substring('native-message-'.length)) < 512 &&
          message['text'] is String &&
          (message['text'] as String).contains(
            'Native history ${id.substring('native-message-'.length)}',
          ),
      'A visible message does not match the fixed rendered input.',
    );
  }
  final expectedHash = sha256
      .convert(
        utf8.encode(
          jsonEncode([
            for (final value in messages)
              {'id': (value as Map)['id'], 'text': value['text']},
          ]),
        ),
      )
      .toString();
  _require(
    checkpoint['visibleTextSha256'] == expectedHash,
    'Visible reading text hash differs from its retained strings.',
  );
  return checkpoint;
}

void _latest(Map checkpoint) {
  _require(
    checkpoint['followLatest'] == true &&
        checkpoint['unread'] == false &&
        _number(checkpoint['extentAfter'], 'Latest remaining extent') <= 2 &&
        _list(
          checkpoint['visibleMessages'],
          'Latest messages',
        ).any((value) => (value as Map)['id'] == 'native-message-0511'),
    'The actual final seeded reply is not visible at the transcript end.',
  );
}

void _sameReading(Map before, Map after) {
  final tolerance =
      4 /
      math.min(
        _number(before['firstMessageHeight'], 'Before height'),
        _number(after['firstMessageHeight'], 'After height'),
      );
  _require(
    before['firstMessageId'] == after['firstMessageId'] &&
        (_number(before['messageFraction'], 'Before fraction') -
                    _number(after['messageFraction'], 'After fraction'))
                .abs() <=
            tolerance,
    'The actual reading anchor moved across product hosts.',
  );
}
