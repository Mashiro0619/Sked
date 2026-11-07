import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ffi' show Abi;
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/conversations/conversation_models.dart';

import '../../integration_test/support/agent_native_session.dart';
import '../../test/support/agent_workspace_navigation.dart';
import 'native_semantics_probe.dart';
import 'ui_performance_metrics.dart';

const agentStreamPerformanceProtocol = 'agent-stream-frames-v1';
final _chunks = List<String>.unmodifiable(
  List.generate(
    96,
    (index) =>
        'Fragment ${index.toString().padLeft(3, '0')}: stable synthetic **Markdown** with a short schedule note.\n\n',
  ),
);

class AgentStreamPerformanceFailure implements Exception {
  AgentStreamPerformanceFailure(this.report, this.cause, this.stack);
  final Map<String, Object?> report;
  final Object cause;
  final StackTrace stack;
}

class _NoHttp extends http.BaseClient {
  var attempts = 0;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    attempts++;
    throw StateError('The stream workload must use controlled events.');
  }
}

class _StreamProvider extends ProviderClient {
  _StreamProvider(this.transport) : super(client: transport);
  final _NoHttp transport;
  final emissions = <int>[];
  var requests = 0, closeCount = 0;
  @override
  Stream<ProviderEvent> stream(
    ProviderRequest request, {
    required String apiKey,
    ProviderCancellationToken? cancellation,
  }) async* {
    expect(apiKey, isEmpty);
    expect(++requests, 1);
    for (final chunk in _chunks) {
      await Future<void>.delayed(const Duration(milliseconds: 16));
      if (cancellation!.isCancelled) {
        throw const ProviderException(ProviderError.cancelled);
      }
      emissions.add(developer.Timeline.now);
      yield ProviderTextDelta(chunk);
    }
    yield ProviderCompleted(
      ProviderResponse(
        text: _chunks.join(),
        toolCalls: const [],
        finishReason: 'stop',
      ),
    );
  }

  @override
  void close() {
    closeCount++;
    super.close();
  }
}

Future<Map<String, Object?>> runAgentStreamPerformance(
  WidgetTester tester, {
  required AgentNativeConfig config,
}) async {
  config.validate();
  if (!kProfileMode ||
      !(Platform.isWindows || Platform.isAndroid) ||
      Platform.resolvedExecutable.toLowerCase().contains('flutter_tester')) {
    throw StateError(
      'Stream frames require the Windows or Android Profile runner.',
    );
  }
  final frames = <UiPerformanceFrame>[];
  void onFrames(List<ui.FrameTiming> values) {
    for (final frame in values) {
      frames.add(
        UiPerformanceFrame(
          vsyncStart: frame.timestampInMicroseconds(ui.FramePhase.vsyncStart),
          build: frame.buildDuration.inMicroseconds,
          raster: frame.rasterDuration.inMicroseconds,
          total: frame.totalSpan.inMicroseconds,
          vsyncOverhead: frame.vsyncOverhead.inMicroseconds,
        ),
      );
    }
  }

  final semantics = NativeSemanticsProbe(requireStableNative: true);
  final transport = _NoHttp();
  final provider = _StreamProvider(transport);
  AgentNativeSession? session;
  var listenerInstalled = false;
  final report = <String, Object?>{
    'protocol': agentStreamPerformanceProtocol,
    'sourceSha': config.revision,
    'configuration': config.toJson(),
    'requiredIndependentProcesses': 3,
    'scope': 'first text reply after native Agent entry; one controlled 96-delta request',
    'emissionIntervalMs': 16,
    'deltaCount': _chunks.length,
    'replySha256': agentNativeDigest(_chunks.join()),
    'backend': 'drift-sqlite',
    'platform': Platform.operatingSystem,
    'operatingSystemVersion': Platform.operatingSystemVersion,
    'dartVersion': Platform.version,
    'abi': Abi.current().toString(),
    'pid': pid,
    'buildMode': 'profile',
    'status': 'running',
  };
  Object? failure;
  StackTrace? failureStack;
  try {
    final native = session = await AgentNativeSession.create(
      provider: provider,
    );
    report['fixture'] = native.fixtureReport();
    await native.app.lifecycle.load();
    await tester.pumpWidget(AgentNativeApp(session: native, config: config));
    await tester.pumpAndSettle();
    await selectAgentShellDestination(tester, 'agent');
    await tester.pumpAndSettle();
    expect(native.app.agent.isInitialized, isTrue);
    expect(native.app.agent.conversations.selectedId, agentNativeLongId);
    final viewSize = tester.view.physicalSize;
    final dpr = tester.view.devicePixelRatio;
    report['surface'] = {
      'physicalWidth': viewSize.width,
      'physicalHeight': viewSize.height,
      'logicalWidth': viewSize.width / dpr,
      'logicalHeight': viewSize.height / dpr,
      'devicePixelRatio': dpr,
      'overrides': false,
    };
    final runtime = native.app.agent.runtime;
    final watch = runtime.watchConversation(agentNativeLongId);
    final publications = <Map<String, int>>[];
    var previousLength = 0;
    void onPublication() {
      final length = watch.value.streamingText.length;
      if (length > previousLength) {
        publications.add({
          'timestampUs': developer.Timeline.now,
          'textLength': length,
        });
      }
      previousLength = length;
    }

    watch.addListener(onPublication);
    SchedulerBinding.instance.addTimingsCallback(onFrames);
    listenerInstalled = true;
    final rssBefore = ProcessInfo.currentRss;
    final start = developer.Timeline.now;
    var done = false;
    final execution = runtime.send(
      agentNativeLongId,
      'Reply with the fixed synthetic Markdown stream.',
    );
    final observed = execution.whenComplete(() => done = true);
    observed.ignore();
    try {
      final timeout = Stopwatch()..start();
      while (!done) {
        if (timeout.elapsed > const Duration(seconds: 60)) {
          throw StateError('The controlled stream did not finish.');
        }
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.takeException(), isNull);
      }
      await observed;
      await runtime.waitForIdle();
      await native.app.agent.conversations.waitForPendingWrites();
      await tester.pumpAndSettle();
    } finally {
      report['startUs'] = start;
      report['endUs'] = developer.Timeline.now;
      report['wallTimeUs'] = (report['endUs']! as int) - start;
      report['rssBeforeBytes'] = rssBefore;
      report['rssAfterBytes'] = ProcessInfo.currentRss;
      report['publications'] = publications;
      watch.removeListener(onPublication);
    }
    expect(provider.requests, 1);
    expect(provider.emissions, hasLength(96));
    expect(publications, isNotEmpty);
    expect(transport.attempts, 0);
    expect(tester.view.physicalSize, viewSize);
    expect(tester.view.devicePixelRatio, dpr);
    final saved = ConversationArchive.decode(await native.readChatSource())
        .conversations
        .singleWhere((conversation) => conversation.id == agentNativeLongId);
    expect(saved.messages, hasLength(agentNativeMessageCount + 2));
    expect(saved.messages.last.text, _chunks.join());
    expect(
      AgentNativeSession.historyDigest(
        saved.messages.take(agentNativeMessageCount),
      ),
      native.originalHistoryDigest,
    );
    report['storage'] = await native.storageReport();
    report['savedReplySha256'] = agentNativeDigest(saved.messages.last.text);
    report['status'] = 'passed';
  } catch (error, stack) {
    failure = error;
    failureStack = stack;
    report['status'] = 'failed';
    report['failure'] = '$error';
  } finally {
    try {
      await tester.pumpWidget(const SizedBox.shrink());
    } catch (error, stack) {
      failure ??= error;
      failureStack ??= stack;
      report['unmountFailure'] = '$error';
      report['status'] = 'failed';
    }
    try {
      if (session != null) {
        report['cleanup'] = await session.close();
      } else {
        provider.close();
      }
    } catch (error, stack) {
      failure ??= error;
      failureStack ??= stack;
      report['cleanup'] = {'status': 'failed', 'error': '$error'};
      report['status'] = 'failed';
    }
    // Frame batches arrive after the measured window; classify by vsync time.
    await tester.pump(const Duration(milliseconds: 1200));
    if (listenerInstalled) {
      SchedulerBinding.instance.removeTimingsCallback(onFrames);
    }
    semantics.close();
    try {
      report['semantics'] = semantics.toJson();
    } catch (error, stack) {
      failure ??= error;
      failureStack ??= stack;
      report['semanticsFailure'] = '$error';
      report['status'] = 'failed';
    }
    report['providerRequests'] = provider.requests;
    report['providerCloseCount'] = provider.closeCount;
    report['httpAttempts'] = transport.attempts;
    report['emissionsUs'] = provider.emissions;
    final start = report['startUs'] as int?, end = report['endUs'] as int?;
    final measured = frames
        .where(
          (frame) =>
              start != null &&
              end != null &&
              frame.vsyncStart >= start &&
              frame.vsyncStart < end,
        )
        .toList();
    final reportedRate = tester.view.display.refreshRate;
    final refreshRate = reportedRate > 0 ? reportedRate : 60.0;
    report['refreshRate'] = refreshRate;
    report['refreshRateFallback'] = reportedRate <= 0;
    report['frames'] = measured.map((frame) => frame.toJson()).toList();
    report['frameSummary'] = summarizeUiFrames(
      measured,
      frameBudgetUs: 1000000 / refreshRate,
    );
    if (measured.isEmpty ||
        (session != null &&
            (report['cleanup']! as Map)['status'] != 'complete')) {
      failure ??= StateError(
        'Frame delivery or native session cleanup did not complete.',
      );
      failureStack ??= StackTrace.current;
      report['status'] = 'failed';
    }
  }
  if (failure != null) {
    throw AgentStreamPerformanceFailure(report, failure, failureStack!);
  }
  return report;
}
