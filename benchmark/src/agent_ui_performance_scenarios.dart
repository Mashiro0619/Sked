import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:ffi' show Abi;
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sked/agent/agent_application.dart';
import 'package:sked/agent/conversations/conversation_models.dart';
import 'package:sked/agent/ui/agent_conversation_view.dart';
import 'package:sked/agent/ui/agent_transcript.dart';
import 'package:sked/controllers/app_session.dart';
import 'package:sked/screens/agent_page.dart';
import 'package:sked/screens/app_home_screen.dart';
import 'package:sked/theme/sked_expressive_theme.dart';

import '../../integration_test/support/agent_native_session.dart';
import 'native_semantics_probe.dart';
import 'ui_performance_metrics.dart';

const agentUiPerformanceProtocolId = 'agent-ui-frames-v2';
const agentUiPerformanceScrollId = 'agent-transcript-scroll-v1';
const agentUiPerformanceIterations = 2;
const agentUiPerformanceWindowsActions = agentUiPerformanceAndroidActions;
const agentUiPerformanceAndroidActions = [
  'agent.entry.open',
  'agent.page.scroll_older',
  'agent.page.close_reading',
  'agent.page.reopen_reading',
  'agent.page.jump_latest',
  'agent.page.close_latest',
];

class AgentUiPerformanceFailure implements Exception {
  const AgentUiPerformanceFailure(this.report, this.cause, this.stackTrace);
  final Map<String, Object?> report;
  final Object cause;
  final StackTrace stackTrace;
  @override
  String toString() => 'Agent Profile journey failed: $cause';
}

class _ActionWindow {
  _ActionWindow({
    required this.scenario,
    required this.iteration,
    required this.start,
    required this.rssBefore,
    required this.requestsBefore,
    required this.nativeSize,
    required this.dpr,
  });
  final String scenario;
  final int iteration, start, rssBefore, requestsBefore;
  final Size nativeSize;
  final double dpr;
  final details = <String, Object?>{};
  int? end, rssAfter, requestsAfter;
  String status = 'running';
  Object? error;
  StackTrace? stack;
}

/// One listener for this entire process journey. Delayed engine batches retain
/// their vsync timestamps; callback arrival never determines action ownership.
class _Recorder {
  _Recorder(this.tester, this.session);
  final WidgetTester tester;
  final AgentNativeSession session;
  final frames = <UiPerformanceFrame>[];
  final windows = <_ActionWindow>[];
  var attachments = 0;
  var detachments = 0;
  var _attached = false;

  void _onFrames(List<ui.FrameTiming> values) {
    for (final value in values) {
      frames.add(
        UiPerformanceFrame(
          vsyncStart: value.timestampInMicroseconds(ui.FramePhase.vsyncStart),
          build: value.buildDuration.inMicroseconds,
          raster: value.rasterDuration.inMicroseconds,
          total: value.totalSpan.inMicroseconds,
          vsyncOverhead: value.vsyncOverhead.inMicroseconds,
        ),
      );
    }
  }

  void attach() {
    _require(
      !_attached && attachments == 0,
      'Only one timing listener may be installed.',
    );
    SchedulerBinding.instance.addTimingsCallback(_onFrames);
    _attached = true;
    attachments++;
  }

  void detach() {
    if (!_attached) return;
    SchedulerBinding.instance.removeTimingsCallback(_onFrames);
    _attached = false;
    detachments++;
  }

  Future<void> record(
    String scenario,
    int iteration,
    Future<void> Function(Map<String, Object?> details) action,
  ) async {
    final rssBefore = ProcessInfo.currentRss;
    final window = _ActionWindow(
      scenario: scenario,
      iteration: iteration,
      start: developer.Timeline.now,
      rssBefore: rssBefore,
      requestsBefore: session.controlledProvider.requests.length,
      nativeSize: tester.view.physicalSize / tester.view.devicePixelRatio,
      dpr: tester.view.devicePixelRatio,
    );
    windows.add(window);
    try {
      _assertIdle(session);
      _require(
        tester.element(find.byType(AgentNativeApp)).mounted,
        'The production Agent host is no longer mounted.',
      );
      await action(window.details);
      await _settle(tester);
      _assertIdle(session);
      _checkFramework(tester);
      _require(
        tester.view.devicePixelRatio == window.dpr &&
            tester.view.physicalSize / tester.view.devicePixelRatio ==
                window.nativeSize,
        'The native surface changed during the action.',
      );
      window.status = 'passed';
    } catch (error, stack) {
      window.status = 'failed';
      window.error = error;
      window.stack = stack;
      rethrow;
    } finally {
      window.end = developer.Timeline.now;
      window.rssAfter = ProcessInfo.currentRss;
      window.requestsAfter = session.controlledProvider.requests.length;
    }
  }

  List<Map<String, Object?>> reports(double budget) => [
    for (final window in windows) _report(window, budget),
  ];

  Map<String, Object?> _report(_ActionWindow window, double budget) {
    final end = window.end ?? window.start;
    final selected =
        frames
            .where(
              (frame) =>
                  frame.vsyncStart >= window.start && frame.vsyncStart < end,
            )
            .toList()
          ..sort((a, b) => a.vsyncStart.compareTo(b.vsyncStart));
    final missing = selected.isEmpty;
    return {
      'scenario': window.scenario,
      'iteration': window.iteration,
      'phase': window.iteration == 0 ? 'cold' : 'warm',
      'status': missing || window.status != 'passed' ? 'failed' : 'passed',
      'actionStatus': window.status,
      'frameValidation': missing ? 'missing-engine-frames' : 'present',
      'startUs': window.start,
      'endUs': end,
      'elapsedUs': end - window.start,
      'nativeLogicalSize': {
        'width': window.nativeSize.width,
        'height': window.nativeSize.height,
      },
      'dpr': window.dpr,
      'rssBeforeBytes': window.rssBefore,
      'rssAfterBytes': window.rssAfter,
      'rssDeltaBytes': window.rssAfter == null
          ? null
          : window.rssAfter! - window.rssBefore,
      'providerRequestsBefore': window.requestsBefore,
      'providerRequestsAfter': window.requestsAfter,
      'details': window.details,
      if (window.error != null) 'error': '${window.error}',
      if (window.stack != null) 'stack': '${window.stack}',
      ...summarizeUiFrames(selected, frameBudgetUs: budget),
      'frames': selected.map((frame) => frame.toJson()).toList(),
    };
  }

  List<Map<String, int>> unassignedFrames() => [
    for (final frame in frames)
      if (!windows.any(
        (window) =>
            frame.vsyncStart >= window.start &&
            frame.vsyncStart < (window.end ?? window.start),
      ))
        frame.toJson(),
  ];
}

/// Always Profile/native: there is no widget-smoke flag or codec override.
/// The functional entry owns business/streaming tests separately from this
/// idle transcript population.
Future<Map<String, Object?>> runAgentUiPerformanceBenchmarks(
  WidgetTester tester, {
  required AgentNativeConfig config,
}) async {
  final phases = <Map<String, Object?>>[];
  final failures = <Map<String, Object?>>[];
  final runtime = <String, Object?>{};
  final report = <String, Object?>{
    'schemaVersion': 1,
    'harnessVersion': 1,
    'measurement': 'profile-engine-frames',
    'validation': 'running',
    'label': config.label,
    'revision': config.revision,
    'sourceNote': config.sourceNote,
    'configuration': config.toJson(),
    'startedAtUtc': DateTime.now().toUtc().toIso8601String(),
    'runtime': runtime,
    'phases': phases,
    'failures': failures,
    'protocol': {
      'id': agentUiPerformanceProtocolId,
      'version': 2,
      'nativeSemanticsHarnessVersion': 2,
      'scrollTargeting': {
        'id': agentUiPerformanceScrollId,
        'version': 1,
        'scope': 'agent-transcript',
        'key': 'agent-transcript-$agentNativeLongId',
        'fallback': 'none; missing/non-scrollable transcript is failure',
      },
      'iterations': agentUiPerformanceIterations,
      'requiredIndependentProcesses': 3,
      'cold': 'First Agent open and first action sequence in this native process/session, after unmeasured production home preparation; not OS cold start.',
      'warm': 'Second sequence in the same AppRuntime, repository and native process after chat history has loaded; no replacement session.',
      'provider': 'Idle only: zero provider requests before/after every window and cleanup.',
      'host': 'AgentNativeApp / real AppRuntime / AppHomeScreen / side navigation / AgentPage',
      'codec': 'production DataTransferCodec; no override parameter',
      'surface': 'actual native window and DPR, no setSurfaceSize/physicalSize overrides',
      'timestamps': 'Timeline.now action boundaries; engine FramePhase.vsyncStart in [startUs, endUs).',
      'listener': 'One engine FrameTiming listener; delayed callbacks do not change attribution.',
      'deliveryWaitMs': 1200,
      'deliveryWaitScope':
          'after UI unmount/owner cleanup, outside all action windows',
      'gesture': 'three downward 400ms timed drags at the framework default 60 samples/second; distance 72% viewport bounded to 180–520 logical pixels',
      'settle': '50ms pumpAndSettle, 15s deadline; state readiness uses bounded 16ms pumps',
      'readingAnchor': 'First actually visible message group and normalized within-message position, 4 logical pixel tolerance; actual RenderParagraph/RenderEditable text retained.',
      'observationCost': 'Read-only visible-message observations are inside action windows; their cost is not subtracted. Text hashes and frame summaries are computed after measured work.',
      'memory': 'Process RSS before/after each action; not Dart heap or a per-action peak.',
      'percentiles': 'Shared nearest-rank ui_performance_metrics.dart implementation; empty frames fail.',
      'overBudget': 'Build/raster stage exceeds display interval; not FPS or inferred presentation drops.',
    },
  };
  Object? primary;
  StackTrace? primaryStack;
  AgentNativeSession? session;
  _Recorder? recorder;
  NativeSemanticsProbe? semantics;
  final guard = AgentNativeHttpGuard();
  var refreshRate = 60.0;

  void retain(String stage, Object error, StackTrace stack) {
    failures.add({'stage': stage, 'error': '$error', 'stack': '$stack'});
    primary ??= error;
    primaryStack ??= stack;
  }

  Future<void> phase(String name, Future<void> Function() action) async {
    final row = <String, Object?>{'name': name, 'status': 'running'};
    phases.add(row);
    try {
      await action();
      _checkFramework(tester);
      row['status'] = 'passed';
    } catch (error, stack) {
      row.addAll({'status': 'failed', 'error': '$error'});
      retain(name, error, stack);
      rethrow;
    }
  }

  try {
    await phase('prepare', () async {
      _validateConfig(config);
      _require(
        kProfileMode && !kIsWeb && (Platform.isWindows || Platform.isAndroid),
        'Agent engine-frame evidence requires flutter drive --profile on Windows or Android.',
      );
      _require(
        !Platform.resolvedExecutable.toLowerCase().contains('flutter_tester'),
        'A host VM run cannot provide native Agent Profile evidence.',
      );
      runtime['semanticsBeforePreparation'] = _semanticsSnapshot();
      semantics = NativeSemanticsProbe(requireStableNative: true);
      final native = tester.view.physicalSize / tester.view.devicePixelRatio;
      _require(
        native.width > 0 &&
            native.height > 0 &&
            tester.view.devicePixelRatio.isFinite &&
            tester.view.devicePixelRatio > 0,
        'The real native view is unavailable.',
      );
      _require(
        !Platform.isWindows || (native.width >= 1100 && native.height >= 600),
        'Use a real Windows window of at least 1100 by 600 logical pixels.',
      );
      final reportedRate = tester.view.display.refreshRate;
      final validRate = reportedRate.isFinite && reportedRate > 0;
      refreshRate = validRate ? reportedRate : 60.0;
      runtime.addAll({
        'os': Platform.operatingSystem,
        'osVersion': Platform.operatingSystemVersion,
        'pid': pid,
        'executable': Platform.resolvedExecutable,
        'dart': Platform.version,
        'abi': Abi.current().toString(),
        'processors': Platform.numberOfProcessors,
        'profile': kProfileMode,
        'dpr': tester.view.devicePixelRatio,
        'reportedRefreshRateHz': reportedRate.isFinite ? reportedRate : null,
        'refreshRateHz': refreshRate,
        'refreshRateFallback': !validRate,
        'nativeLogicalSize': {'width': native.width, 'height': native.height},
        'nativePhysicalSize': {
          'width': tester.view.physicalSize.width,
          'height': tester.view.physicalSize.height,
        },
        'surfaceOverrides': false,
        'nativeAccessibilityFeatures':
            '${tester.binding.platformDispatcher.accessibilityFeatures}',
      });
      if (Platform.isAndroid) {
        final properties = <String, String>{};
        for (final key in [
          'ro.build.version.sdk',
          'ro.product.cpu.abi',
          'ro.kernel.qemu',
        ]) {
          final value = await Process.run('/system/bin/getprop', [
            key,
          ]).timeout(const Duration(seconds: 5));
          _require(value.exitCode == 0, 'Cannot read Android provenance $key.');
          properties[key] = '${value.stdout}'.trim();
        }
        _require(
          int.tryParse(properties['ro.build.version.sdk']!) != null &&
              properties['ro.product.cpu.abi']!.isNotEmpty,
          'Android API/ABI provenance is incomplete.',
        );
        runtime['androidProperties'] = properties;
        runtime['deviceKind'] = properties['ro.kernel.qemu'] == '1'
            ? 'emulator'
            : 'unclassified Android native surface';
      } else {
        runtime['deviceKind'] = 'Windows native window';
      }
      guard.install();
      // This benchmark target owns an isolated fallback plugin cache.
      // ignore: invalid_use_of_visible_for_testing_member
      SharedPreferences.setMockInitialValues({});
      // Benchmark-only public metadata cache; the real home/settings loader is retained.
      // ignore: invalid_use_of_visible_for_testing_member
      PackageInfo.setMockInitialValues(
        appName: 'Sked',
        packageName: 'com.mashiro.sked.agent_native_journey',
        version: '3.0.0',
        buildNumber: '0',
        buildSignature: '',
        installerStore: '',
      );
      final nativeSession = session = AgentNativeSession();
      recorder = _Recorder(tester, nativeSession)..attach();
      report['fixture'] = nativeSession.fixtureReport();
      report['expectedActions'] = Platform.isWindows
          ? agentUiPerformanceWindowsActions
          : agentUiPerformanceAndroidActions;
      report['runtimeIdentity'] = {
        'application': identityHashCode(nativeSession.app),
        'agent': identityHashCode(nativeSession.app.agent),
        'repository': identityHashCode(nativeSession.app.agent.conversations),
        'scope': 'identity within this process only',
      };
      await nativeSession.app.lifecycle.load().timeout(
        const Duration(seconds: 20),
      );
      _require(
        nativeSession.app.lifecycle.canWrite &&
            !nativeSession.app.agent.isInitialized &&
            nativeSession.conversationLoads == 0,
        'The main load must leave Agent history dormant.',
      );
      await tester.pumpWidget(
        AgentNativeApp(session: nativeSession, config: config),
      );
      await _settle(tester);
      _require(
        find.byType(AppHomeScreen).evaluate().length == 1 &&
            !nativeSession.app.agent.isInitialized &&
            nativeSession.conversationLoads == 0,
        'Home preparation opened Agent before its measured first entry.',
      );
      _assertIdle(nativeSession);
      report['storageBeforeActions'] = nativeSession.storageReport();
      report['preparationScope'] = 'Fixed fixtures, main load and real home mount before action timing. No Agent host or history prewarming.';
    });

    await phase('actions', () async {
      final native = session!;
      final recording = recorder!;
      final journey = _AgentJourney(tester, native, config);
      for (
        var iteration = 0;
        iteration < agentUiPerformanceIterations;
        iteration++
      ) {
        Future<void> measure(
          String name,
          Future<void> Function(Map<String, Object?>) action,
        ) => recording.record(name, iteration, action);
        await measure(
          'agent.entry.open',
          (details) => journey.open(details, iteration: iteration),
        );
        await measure('agent.page.scroll_older', journey.scrollOlder);
        await measure('agent.page.close_reading', journey.closePageReading);
        await measure('agent.page.reopen_reading', journey.reopenReading);
        await measure('agent.page.jump_latest', journey.jumpLatest);
        await measure('agent.page.close_latest', journey.closePageLatest);
      }
      _assertIdle(native);
      await native.app.agent.conversations.waitForPendingWrites().timeout(
        const Duration(seconds: 20),
      );
      await native.app.persistence.flushPendingUiStateSaves().timeout(
        const Duration(seconds: 20),
      );
      await native.app.session.repository
          .waitForPendingWrites(propagateErrors: true)
          .timeout(const Duration(seconds: 20));
      final archive = ConversationArchive.decode(native.chatSource);
      final long = archive.conversations.singleWhere(
        (value) => value.id == agentNativeLongId,
      );
      final short = archive.conversations.singleWhere(
        (value) => value.id == agentNativeShortId,
      );
      _require(
        archive.conversations.length == 2 &&
            archive.selectedId == agentNativeLongId &&
            long.messages.length == agentNativeMessageCount &&
            short.messages.length == 2 &&
            long.draft == agentNativeInitialDraft &&
            short.draft == agentNativeShortDraft &&
            AgentNativeSession.historyDigest(long.messages) ==
                native.originalHistoryDigest,
        'Profile reading changed the seeded archive or independent drafts.',
      );
      report['historyAfterActions'] = {
        'longMessageCount': long.messages.length,
        'longHistorySha256': AgentNativeSession.historyDigest(long.messages),
        'selectedId': archive.selectedId,
        'draftsUnchanged': true,
      };
      report['providerBeforeCleanup'] = native.providerReport();
      report['storageAfterActions'] = native.storageReport();
      _require(
        guard.attempts == 0,
        'An offline Profile action attempted HTTP.',
      );
    });
  } catch (_) {
    // Each phase retained its own failure and any already completed windows.
  } finally {
    try {
      await phase('cleanup', () async {
        final cleanup = <String, Object?>{};
        try {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          _checkFramework(tester);
          cleanup['unmount'] = 'complete';
        } catch (error, stack) {
          cleanup['unmount'] = {
            'status': 'failed',
            'error': '$error',
            'stack': '$stack',
          };
        }
        final native = session;
        if (native != null) {
          cleanup['owners'] = await native.close();
          cleanup['provider'] = native.providerReport();
          cleanup['storage'] = native.storageReport();
        }
        try {
          guard.restore();
          cleanup['httpGuardRestored'] = true;
        } catch (error) {
          cleanup['httpGuardRestored'] = false;
          cleanup['httpGuardError'] = '$error';
        }
        cleanup['httpOperationAttempts'] = guard.attempts;
        cleanup['httpClientsCreated'] = guard.clientsCreated;
        report['cleanup'] = cleanup;
        _require(
          cleanup['unmount'] == 'complete' &&
              cleanup['httpGuardRestored'] == true &&
              guard.attempts == 0 &&
              (native == null ||
                  (cleanup['owners'] as Map)['status'] == 'complete' &&
                      native.controlledProvider.requests.isEmpty),
          'Profile cleanup was not completely confirmed.',
        );
      });
    } catch (_) {
      // Preserve the primary action failure and the independent cleanup result.
    }
    try {
      if (recorder != null) {
        await phase('frame-delivery', () async {
          report['frameDeliveryWaitStartUs'] = developer.Timeline.now;
          await Future<void>.delayed(const Duration(milliseconds: 1200));
          report['frameDeliveryWaitEndUs'] = developer.Timeline.now;
        });
      }
    } catch (_) {
      // The timing listener still must be detached after a failed delivery wait.
    } finally {
      recorder?.detach();
      runtime['semanticsAfterCleanup'] = _semanticsSnapshot();
      final probe = semantics;
      if (probe != null) {
        try {
          await phase('semantics-validation', () async {
            probe.close();
            runtime['semantics'] = probe.toJson();
          });
        } catch (_) {
          // NativeSemanticsProbe reports endpoint/listener disagreement as a
          // failure. The error and the separate endpoint snapshots are kept.
        }
      }
    }
  }

  try {
    await phase('frame-validation', () async {
      final recording = recorder;
      if (recording == null) {
        throw StateError('The Agent frame recorder never started.');
      }
      _hashReadingCheckpoints(recording.windows);
      final results = recording.reports(1000000 / refreshRate);
      report['results'] = results;
      report['unassignedFrames'] = recording.unassignedFrames();
      report['listener'] = {
        'attachments': recording.attachments,
        'detachments': recording.detachments,
        'observedFrameCount': recording.frames.length,
      };
      final actions = Platform.isWindows
          ? agentUiPerformanceWindowsActions
          : agentUiPerformanceAndroidActions;
      _require(
        results.length == actions.length * agentUiPerformanceIterations,
        'The complete cold/warm action population is missing.',
      );
      _require(
        results.every((result) => result['status'] == 'passed'),
        'An action failed or has no engine frames; raw evidence was retained.',
      );
      _require(
        recording.attachments == 1 && recording.detachments == 1,
        'The single timing-listener lifetime was not confirmed.',
      );
    });
  } catch (_) {
    // An empty or failed frame window is retained with null distributions.
  }
  runtime['processMaxRssBytes'] = ProcessInfo.maxRss;
  report['validation'] = primary == null ? 'passed' : 'failed';
  report['finishedAtUtc'] = DateTime.now().toUtc().toIso8601String();
  if (primary != null) {
    throw AgentUiPerformanceFailure(report, primary!, primaryStack!);
  }
  return report;
}

void _validateConfig(AgentNativeConfig config) {
  _require(
    const ['baseline', 'accessible'].contains(config.name),
    'SKED_AGENT_UI_PERF_CONFIG must be baseline or accessible.',
  );
  _require(
    RegExp(r'^[0-9a-f]{40}$').hasMatch(config.revision),
    'SKED_AGENT_UI_PERF_REVISION must identify the full source SHA.',
  );
  _require(
    RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$').hasMatch(config.label),
    'SKED_AGENT_UI_PERF_LABEL must be a short filename-safe label.',
  );
}

Map<String, bool> _semanticsSnapshot() => {
  'native': ui.PlatformDispatcher.instance.semanticsEnabled,
  'framework': SemanticsBinding.instance.semanticsEnabled,
};

void _require(bool condition, String message) {
  if (!condition) throw StateError(message);
}

void _checkFramework(WidgetTester tester) {
  final error = tester.takeException();
  if (error != null) throw StateError('Native Flutter reported: $error');
}

void _assertIdle(AgentNativeSession session) {
  _require(
    session.controlledProvider.requests.isEmpty &&
        !session.app.agent.runtime.state.value
            .runFor(agentNativeLongId)
            .isActive &&
        session.app.agent.runtime.pendingInputCount(agentNativeLongId) == 0,
    'Agent frame sampling requires an idle runtime and zero provider requests.',
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle(
    const Duration(milliseconds: 50),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 15),
  );
  _checkFramework(tester);
}

void _hashReadingCheckpoints(List<_ActionWindow> windows) {
  for (final window in windows) {
    final checkpoints = window.details['checkpoints'];
    if (checkpoints is! List<Map<String, Object?>>) continue;
    for (final checkpoint in checkpoints) {
      final messages =
          checkpoint['visibleMessages']! as List<Map<String, Object?>>;
      checkpoint['visibleTextSha256'] = agentNativeDigest(
        jsonEncode([
          for (final message in messages)
            {'id': message['id'], 'text': message['text']},
        ]),
      );
    }
  }
}

class _ReadingSnapshot {
  const _ReadingSnapshot(
    this.data,
    this.messageId,
    this.fraction,
    this.height,
    this.latest,
  );
  final Map<String, Object?> data;
  final String messageId;
  final double fraction, height;
  final bool latest;
  bool matches(_ReadingSnapshot other) =>
      messageId == other.messageId &&
      (fraction - other.fraction).abs() <= 4 / math.min(height, other.height);
}

({String text, int paragraphs, int editables}) _renderedMessageText(
  Element element,
) {
  final fragments = <String>[];
  var paragraphs = 0;
  var editables = 0;
  void visit(RenderObject node) {
    if (!node.attached || node is RenderOffstage && node.offstage) return;
    if (node is RenderBox && !node.hasSize) return;
    final InlineSpan? span;
    if (node is RenderParagraph) {
      paragraphs++;
      span = node.text;
    } else if (node is RenderEditable) {
      // SelectableText and selectable Markdown paint through RenderEditable;
      // collecting RichText widgets alone would omit the actual message body.
      editables++;
      span = node.text;
    } else {
      span = null;
    }
    if (span != null) {
      fragments.add(span.toPlainText(includeSemanticsLabels: false));
    }
    node.visitChildren(visit);
  }

  final root = element.findRenderObject();
  if (root != null) visit(root);
  return (
    text: fragments.join('\n'),
    paragraphs: paragraphs,
    editables: editables,
  );
}

class _AgentJourney {
  _AgentJourney(this.tester, this.session, this.config);
  final WidgetTester tester;
  final AgentNativeSession session;
  final AgentNativeConfig config;
  _ReadingSnapshot? _closedReading;

  Finder key(String value) => find.byKey(ValueKey(value));
  Finder get composer => key('agent-composer').hitTestable();
  Finder get transcript =>
      key('agent-transcript-$agentNativeLongId').hitTestable();

  Future<void> until(bool Function() ready, String description) async {
    final watch = Stopwatch()..start();
    while (!ready()) {
      _checkFramework(tester);
      _assertIdle(session);
      _require(
        watch.elapsed < const Duration(seconds: 20),
        'Timed out waiting for $description.',
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    await _settle(tester);
  }

  Future<void> tap(Finder finder, String description) async {
    await until(() => finder.hitTestable().evaluate().length == 1, description);
    await tester.tap(finder.hitTestable());
    await _settle(tester);
  }

  Map<String, Object?> assertHost() {
    _assertIdle(session);
    _require(
      composer.evaluate().length == 1,
      'Exactly one visible Agent composer is required.',
    );
    final context = tester.element(composer);
    final view = tester.widget<AgentConversationView>(
      find.ancestor(of: composer, matching: find.byType(AgentConversationView)),
    );
    _require(
      identical(context.read<AgentApplication>(), session.app.agent) &&
          identical(context.read<AppSession>(), session.app.session) &&
          identical(view.repository, session.app.agent.conversations),
      'A product host replaced the measured runtime or repository.',
    );
    _require(
      session.app.agent.conversations.selectedId == agentNativeLongId &&
          session.app.agent.conversations.selected!.messages.length ==
              agentNativeMessageCount,
      'The active transcript is not the complete 512-message fixture.',
    );
    _require(
      tester.widget<TextField>(composer).controller!.text ==
          agentNativeInitialDraft,
      'Reading/navigating changed the seeded draft.',
    );
    final motion = SkedMotionPolicy.of(context);
    final brightness = Theme.of(context).brightness;
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    _require(
      brightness == config.brightness &&
          (textScale - config.textScale).abs() < 0.001 &&
          motion.reduceMotion == config.accessible &&
          !motion.disableAnimations,
      'The active host does not match its framework configuration.',
    );
    _require(
      find.byType(AgentPage).hitTestable().evaluate().length == 1,
      'The production full Agent page is not visible.',
    );
    return {
      'brightness': brightness.name,
      'textScale': textScale,
      'reduceMotion': motion.reduceMotion,
      'disableAnimations': motion.disableAnimations,
    };
  }

  _ReadingSnapshot observe(Map<String, Object?> details, String phase) {
    final started = developer.Timeline.now;
    details['observedConfiguration'] = assertHost();
    _require(
      transcript.evaluate().length == 1,
      'The real Agent transcript is not uniquely visible.',
    );
    final scroll = tester.widget<CustomScrollView>(transcript).controller!;
    _require(
      scroll.hasClients &&
          scroll.position.hasContentDimensions &&
          !scroll.position.isScrollingNotifier.value,
      'The transcript is not settled.',
    );
    final viewport = tester.getRect(transcript);
    final groups = find.descendant(
      of: transcript,
      matching: find.byWidgetPredicate((widget) {
        final key = widget.key;
        return key is ValueKey<String> &&
            key.value.startsWith('agent-message-group-');
      }),
    );
    final visible = <(String, Rect, Element)>[];
    for (final element in groups.evaluate()) {
      final box = element.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (rect.height <= 0 || !rect.overlaps(viewport)) continue;
      final id = (element.widget.key! as ValueKey<String>).value.substring(
        'agent-message-group-'.length,
      );
      visible.add((id, rect, element));
    }
    _require(
      visible.isNotEmpty,
      'No rendered history message intersects the transcript viewport.',
    );
    visible.sort((a, b) => a.$2.top.compareTo(b.$2.top));
    final messages = <Map<String, Object?>>[];
    for (final item in visible) {
      final rendered = _renderedMessageText(item.$3);
      final text = rendered.text;
      _require(
        item.$1.startsWith('native-message-') &&
            text.contains(
              'Native history ${item.$1.substring('native-message-'.length)}',
            ),
        'Rendered transcript text does not match the fixed message identity.',
      );
      messages.add({
        'id': item.$1,
        'text': text,
        'textSource': 'render-paragraph-and-editable',
        'renderParagraphCount': rendered.paragraphs,
        'renderEditableCount': rendered.editables,
        'topInViewport': item.$2.top - viewport.top,
        'leftInViewport': item.$2.left - viewport.left,
        'width': item.$2.width,
        'height': item.$2.height,
      });
    }
    final first = visible.first;
    final reading = tester
        .widget<AgentTranscript>(
          find.ancestor(of: transcript, matching: find.byType(AgentTranscript)),
        )
        .position;
    final fraction = (viewport.top - first.$2.top) / first.$2.height;
    final checkpoint = <String, Object?>{
      'phase': phase,
      'scrollScope': 'agent-transcript',
      'scrollTarget': 'agent-transcript-$agentNativeLongId',
      'selectedId': session.app.agent.conversations.selectedId,
      'firstMessageId': first.$1,
      'messageFraction': fraction,
      'firstMessageHeight': first.$2.height,
      'viewportWidth': viewport.width,
      'viewportHeight': viewport.height,
      'scrollPixels': scroll.position.pixels,
      'minScrollExtent': scroll.position.minScrollExtent,
      'maxScrollExtent': scroll.position.maxScrollExtent,
      'extentBefore': scroll.position.extentBefore,
      'extentAfter': scroll.position.extentAfter,
      'followLatest': reading.followLatest,
      'unread': reading.unread,
      'visibleMessages': messages,
      'observationUs': developer.Timeline.now - started,
    };
    final checkpoints =
        details.putIfAbsent('checkpoints', () => <Map<String, Object?>>[])!
            as List<Map<String, Object?>>;
    checkpoints.add(checkpoint);
    details['sameApplicationAndRepository'] = true;
    return _ReadingSnapshot(
      checkpoint,
      first.$1,
      fraction,
      first.$2.height,
      reading.followLatest,
    );
  }

  Future<void> open(
    Map<String, Object?> details, {
    required int iteration,
  }) async {
    details['conversationLoadsBefore'] = session.conversationLoads;
    details['processFirstAgentOpen'] = iteration == 0;
    details['runtimeWasInitialized'] = session.app.agent.isInitialized;
    _require(
      session.conversationLoads == (iteration == 0 ? 0 : 1) &&
          session.app.agent.isInitialized == (iteration != 0),
      'Cold/warm history ownership changed.',
    );
    final entryControl = await _openFromHome();
    assertHost();
    final opened = observe(details, 'opened');
    _assertLatest(opened);
    _require(
      session.conversationLoads == 1,
      'Opening a retained Agent reloaded the archive.',
    );
    details['conversationLoadsAfter'] = session.conversationLoads;
    details['entry'] = entryControl;
  }

  Future<String> _tapHomeAgent() async {
    const controls = ['workspace-agent-entry', 'workspace-main-navigation'];
    String? visibleControl() {
      for (final id in controls) {
        if (key(id).hitTestable().evaluate().length == 1) {
          return id;
        }
      }
      return null;
    }

    var control = visibleControl();
    if (control == null) {
      await until(
        () => visibleControl() != null,
        'the visible formal home Agent control',
      );
      control = visibleControl()!;
    }
    final agent = key('workspace-agent-entry');
    if (control != 'workspace-agent-entry') {
      await tap(key(control), 'the visible main navigation drawer');
      if (agent.hitTestable().evaluate().length != 1) {
        await until(
          () => agent.evaluate().length == 1,
          'the actual side navigation Agent entry',
        );
        await tester.ensureVisible(agent).timeout(const Duration(seconds: 20));
      }
    }
    await tap(agent, 'the formal side navigation Agent entry');
    return control == 'workspace-agent-entry'
        ? control
        : '$control / workspace-agent-entry';
  }

  Future<String> _openFromHome() async {
    final control = await _tapHomeAgent();
    await until(
      () => session.app.agent.isInitialized && composer.evaluate().length == 1,
      'the loaded production Agent host',
    );
    return control;
  }

  Future<void> scrollOlder(Map<String, Object?> details) async {
    final before = observe(details, 'before');
    details['gestureCount'] = 3;
    for (var index = 0; index < 3; index++) {
      final distance = (tester.getRect(transcript).height * 0.72).clamp(
        180.0,
        520.0,
      );
      await tester.timedDrag(
        transcript,
        Offset(0, distance),
        const Duration(milliseconds: 400),
      );
      await _settle(tester);
      observe(details, 'drag-${index + 1}');
    }
    final after = observe(details, 'after');
    _require(
      before.messageId != after.messageId &&
          !after.latest &&
          (after.data['extentAfter']! as double) > 72,
      'Timed drags did not move the real transcript to earlier messages.',
    );
    details['scrollStatus'] = 'scrolled';
  }

  Future<void> _closeFullPage() async {
    await tap(
      find.descendant(
        of: find.byType(AgentPage),
        matching: find.byType(BackButton),
      ),
      'the Agent page Back control',
    );
    await until(
      () => find.byType(AgentPage).evaluate().isEmpty,
      'the Agent page to close',
    );
  }

  Future<void> jumpLatest(Map<String, Object?> details) async {
    final before = observe(details, 'before');
    _require(!before.latest, 'Jump-to-latest must start in earlier history.');
    await tap(key('agent-jump-latest'), 'the real Jump to latest action');
    final after = observe(details, 'latest');
    _assertLatest(after);
    details['latestConfirmed'] = true;
  }

  void _assertLatest(_ReadingSnapshot snapshot) {
    final messages =
        snapshot.data['visibleMessages']! as List<Map<String, Object?>>;
    _require(
      snapshot.latest &&
          (snapshot.data['extentAfter']! as double) <= 2 &&
          snapshot.data['unread'] == false &&
          messages.any(
            (item) => item['id'] == session.originalMessages.last.id,
          ),
      'The actual transcript end and final seeded reply are not visible.',
    );
  }

  Future<void> closePageReading(Map<String, Object?> details) async {
    final before = observe(details, 'page');
    _require(
      !before.latest,
      'Full page close must begin while reading earlier history.',
    );
    _closedReading = before;
    await _closeFullPage();
    _require(
      composer.evaluate().isEmpty,
      'A closed full page retained interactive input.',
    );
    details['returnedHome'] = true;
  }

  Future<void> reopenReading(Map<String, Object?> details) async {
    _require(
      _closedReading != null,
      'The full page reading checkpoint is missing.',
    );
    details['conversationLoadsBefore'] = session.conversationLoads;
    details['entry'] = await _openFromHome();
    assertHost();
    final after = observe(details, 'reopened');
    _require(
      _closedReading!.matches(after) && session.conversationLoads == 1,
      'Full page reopening moved the reading anchor or reloaded history.',
    );
    details['readingPreserved'] = true;
    details['conversationLoadsAfter'] = session.conversationLoads;
  }

  Future<void> closePageLatest(Map<String, Object?> details) async {
    _assertLatest(observe(details, 'page'));
    await _closeFullPage();
    _require(
      composer.evaluate().isEmpty,
      'A closed full page retained interactive input.',
    );
    details['returnedHome'] = true;
    details['conversationLoadsAfter'] = session.conversationLoads;
  }
}
