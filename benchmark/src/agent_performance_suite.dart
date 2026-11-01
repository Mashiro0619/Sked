import 'dart:convert';

import 'package:sked/agent/provider/provider_models.dart';
import 'package:sked/agent/runtime/conversation_context.dart';
import 'package:sked/agent/tools/application_tool_host.dart';
import 'package:sked/application/operation_contracts.dart';

import 'agent_performance_fixtures.dart';
import 'agent_performance_queries.dart';
import 'agent_performance_runtime.dart';
import 'benchmark_runner.dart';

const agentPerformanceCaseNames = [
  'load-agent-disabled',
  'load-entry-enabled-unopened',
  'load-chat-opened',
  'long-context-compaction',
  'long-history-all-pages',
  'long-message-all-slices',
  'all-timetable-pages',
  'all-course-pages',
  'complete-tool-catalog',
  'rename-one-timetable',
  'batch-one-hundred-course-locations',
];

class AgentPerformanceFailure implements Exception {
  const AgentPerformanceFailure({required this.cause, required this.report});

  final Object cause;
  final Map<String, Object?> report;

  @override
  String toString() => cause.toString();
}

class _AgentSample {
  const _AgentSample({
    required this.elapsedUs,
    required this.result,
    this.details = const {},
    this.memory,
    this.inspection,
  });

  final double elapsedUs;
  final Object result;
  final Map<String, Object?> details;
  final Map<String, Object?>? memory;
  final Object? inspection;
}

class _AgentRecorder {
  _AgentRecorder({required this.verifyOnly, required this.expected});
  final bool verifyOnly;
  final Map<String, String> expected;
  final cases = <Map<String, Object?>>[];

  Future<void> record(
    String name,
    Future<_AgentSample> Function() operation,
  ) async {
    final warmups = verifyOnly ? 0 : 5;
    final observations = verifyOnly ? 1 : 11;
    final samples = <Map<String, Object?>>[];
    final durations = <double>[];
    String? checksum;
    Object? inspection;
    Map<String, Object?>? pendingObservation;
    final record = <String, Object?>{
      'name': name,
      'status': 'running',
      'measurement': verifyOnly ? 'verification-only' : 'timed',
      'unit': 'us/declared-workload',
      'operationsPerSample': 1,
      'warmupBatches': warmups,
      'sampleBatches': observations,
      'completedWarmupBatches': 0,
      'completedSampleBatches': 0,
      'samples': samples,
    };
    cases.add(record);
    try {
      for (var index = 0; index < warmups + observations; index++) {
        final warmingUp = index < warmups;
        pendingObservation = {
          'phase': warmingUp ? 'warmup' : 'sample',
          'index': warmingUp ? index + 1 : index - warmups + 1,
        };
        final sample = await operation();
        final observation = <String, Object?>{
          'elapsedUs': sample.elapsedUs,
          ...sample.details,
          if (sample.memory != null) 'memory': sample.memory,
        };
        pendingObservation.addAll(observation);
        final digest = agentPerformanceDigest(sample.result);
        observation['resultSha256'] = digest;
        pendingObservation['resultSha256'] = digest;
        inspection ??= sample.inspection;
        if (verifyOnly && inspection != null) {
          record['verificationPayload'] = inspection;
        }
        checksum ??= digest;
        requireAgentPerformance(
          digest == checksum,
          '$name changed result between repetitions.',
        );
        if (expected[name] case final frozen?) {
          pendingObservation['expectedResultSha256'] = frozen;
          requireAgentPerformance(
            digest == frozen,
            '$name differs from the frozen verification contract.',
          );
        }
        if (warmingUp) {
          record['completedWarmupBatches'] = index + 1;
        } else {
          durations.add(sample.elapsedUs);
          samples.add(observation);
          record['completedSampleBatches'] = samples.length;
        }
        pendingObservation = null;
      }
      final median = benchmarkMedian(durations);
      record.addAll({
        'status': 'complete',
        'resultSha256': checksum,
        if (!verifyOnly)
          'summary': {
            'median': median,
            'mad': benchmarkMedian(
              durations.map((value) => (value - median).abs()).toList(),
            ),
            'minimum': durations.reduce(
              (left, right) => left < right ? left : right,
            ),
          },
      });
    } catch (error) {
      record.addAll({
        'status': 'failed',
        'error': error.toString(),
        'failedObservation': ?pendingObservation,
      });
      rethrow;
    }
  }
}

Future<Map<String, Object?>> runAgentPerformanceBenchmarks({
  required String label,
  required String revision,
  required bool verifyOnly,
  required Map<String, String> benchmarkSources,
  List<String> caseNames = agentPerformanceCaseNames,
  Map<String, Object?>? reference,
  String sourceNote = '',
}) async {
  requireAgentPerformance(
    RegExp(r'^[0-9a-fA-F]{40}$').hasMatch(revision),
    'Record the full source SHA with SKED_BENCHMARK_REVISION.',
  );
  requireAgentPerformance(
    caseNames.isNotEmpty &&
        caseNames.toSet().length == caseNames.length &&
        caseNames.every(agentPerformanceCaseNames.contains),
    'Select only distinct declared Agent benchmark cases.',
  );
  requireAgentPerformance(
    verifyOnly || reference != null,
    'Timed runs require a frozen verification-only contract.',
  );
  final fixtures = AgentPerformanceFixtures.build();
  requireAgentPerformance(
    fixtures.manifest['timetables'] == 5 &&
        fixtures.manifest['courses'] == 5000 &&
        fixtures.manifest['events'] == 5000 &&
        fixtures.manifest['sourceReminderAcknowledgements'] == 256 &&
        fixtures.manifest['storedReminderAcknowledgements'] == 86,
    'The existing performance fixture population changed.',
  );
  requireAgentPerformance(
    fixtures.archive.conversations.length == 32 &&
        fixtures.longConversation.messages.length == 512,
    'The fixed conversation population changed.',
  );
  final expected = <String, String>{};
  if (reference != null) {
    requireAgentPerformance(
      reference['protocolId'] == agentPerformanceProtocol &&
          reference['status'] == 'complete' &&
          reference['measurement'] == 'verification-only',
      'Use a complete verification-only report from this Agent protocol.',
    );
    sameAgentPerformance(
      reference['dataset'],
      fixtures.manifest,
      'Frozen dataset',
    );
    sameAgentPerformance(
      reference['benchmarkSources'],
      benchmarkSources,
      'Frozen benchmark source files',
    );
    for (final value in reference['cases'] as List) {
      final item = value as Map;
      expected[item['name'] as String] = item['resultSha256'] as String;
    }
    requireAgentPerformance(
      caseNames.every(expected.containsKey),
      'The contract does not cover every selected workload.',
    );
  }
  final recorder = _AgentRecorder(verifyOnly: verifyOnly, expected: expected);
  final network = AgentPerformanceNetworkGuard();
  final protocolClock = Stopwatch()..start();
  Object? failure;
  StackTrace? failureStack;
  String? activeCase;
  try {
    await network.run(() async {
      for (final name in caseNames) {
        activeCase = name;
        if (name.startsWith('load-')) {
          await recorder.record(
            name,
            () => _loadSample(name, fixtures, network, protocolClock),
          );
        } else if (name == 'long-context-compaction') {
          await recorder.record(name, () async {
            final timer = Stopwatch()..start();
            final result = boundConversationContext(
              fixtures.context,
              maxMessages: agentPerformanceContextMessages,
              maxCharacters: agentPerformanceContextCharacters,
            );
            timer.stop();
            verifyAgentPerformanceContext(result, fixtures.context);
            final records = providerMessageRecords(result!);
            return _AgentSample(
              elapsedUs: _microseconds(timer),
              result: records,
              details: {
                'inputMessages': fixtures.context.length,
                'outputMessages': result.length,
              },
            );
          });
        } else if (name == 'rename-one-timetable' ||
            name == 'batch-one-hundred-course-locations') {
          await recorder.record(
            name,
            () => _bulkSample(name, fixtures, network, protocolClock),
          );
        } else {
          await _recordReadCase(name, fixtures, network, recorder);
        }
        network.verify();
        activeCase = null;
      }
    });
  } catch (error, stack) {
    failure = error;
    failureStack = stack;
  } finally {
    protocolClock.stop();
  }
  final report = <String, Object?>{
    'schemaVersion': 1,
    'status': failure == null ? 'complete' : 'failed',
    'failedCase': ?activeCase,
    'protocolId': agentPerformanceProtocol,
    'measurement': verifyOnly ? 'verification-only' : 'timed',
    'label': safeBenchmarkLabel(label),
    'revision': revision,
    'sourceNote': sourceNote,
    'benchmarkSources': benchmarkSources,
    'recordedAtUtc': DateTime.now().toUtc().toIso8601String(),
    'runtime': benchmarkRuntimeMetadata(
      'flutter-test-host-jit-agent-real-disk',
    ),
    'dataset': fixtures.manifest,
    'protocol': {
      'warmupBatches': verifyOnly ? 0 : 5,
      'sampleBatches': verifyOnly ? 1 : 11,
      'independentProcessesRequired': 3,
      'calibration':
          'none; one complete declared async/IO workload per observation',
      'stateLoads': 'new AppRuntime per observation; fixture and disk preparation excluded; initialize only in the opened case',
      'readTools': 'warm caller-owned snapshots; full bounded pages through production tool implementations',
      'bulkTiming': 'mutation.prepare through awaited mutation.commit; enclosing host-run chat persistence excluded',
      'bulkValidation': 'full expected business snapshot and complete independent physical readback after timing',
      'memory': 'whole-process RSS endpoints and process-lifetime max; flutter_tester already running; no heap or phase-peak claim',
      'normalization': 'catalog now omitted; bulk receipt wall time omitted from semantic digest and checked in exact disk readback',
      'nativeEvidence':
          'none; use the independent STARTUP and UI_PERFORMANCE protocols',
    },
    'network': {
      'httpAttempts': network.httpAttempts,
      'modelAttempts': network.modelAttempts,
    },
    'cases': recorder.cases,
  };
  if (failure != null) {
    Error.throwWithStackTrace(
      AgentPerformanceFailure(cause: failure, report: report),
      failureStack!,
    );
  }
  return report;
}

Future<_AgentSample> _loadSample(
  String name,
  AgentPerformanceFixtures fixtures,
  AgentPerformanceNetworkGuard network,
  Stopwatch protocolClock,
) async {
  final enabled = name != 'load-agent-disabled';
  final opened = name == 'load-chat-opened';
  final session = await AgentPerformanceDiskSession.prepare(
    fixtures,
    agentEnabled: enabled,
    network: network,
  );
  try {
    final before = observeAgentPerformanceMemory(protocolClock);
    final timer = Stopwatch()..start();
    session.constructRuntime();
    await session.load(openAgent: opened);
    timer.stop();
    final after = observeAgentPerformanceMemory(protocolClock);
    final counters = session.counters;
    sameAgentPerformance(
      session.app.session.committedData.toJson(),
      fixtures.dataWithAgent(enabled).toJson(),
      'Loaded main data',
    );
    requireAgentPerformance(
      counters['mainLoads'] == 1 && counters['mainWrites'] == 0,
      'Load changed the main archive or loaded it twice.',
    );
    requireAgentPerformance(
      counters['chatLoads'] == (opened ? 1 : 0),
      'Dormant chat storage was loaded or an opened archive was skipped.',
    );
    requireAgentPerformance(
      counters['knowledgeLoads'] == 0 && counters['knowledgeWrites'] == 0,
      'Opening or showing the entry unexpectedly loaded knowledge.',
    );
    requireAgentPerformance(
      opened || counters['credentialReads'] == 0,
      'A dormant Agent read credentials.',
    );
    requireAgentPerformance(
      session.app.agent.isInitialized == opened,
      'Agent initialization did not match the declared state.',
    );
    if (opened) {
      sameAgentPerformance(
        session.app.agent.conversations.conversations
            .map((value) => value.toJson())
            .toList(),
        fixtures.archive.conversations.map((value) => value.toJson()).toList(),
        'The complete loaded conversation archive',
      );
    }
    return _AgentSample(
      elapsedUs: _microseconds(timer),
      result: {
        'state': name,
        'agentInitialized': session.app.agent.isInitialized,
        'mainSha256': agentPerformanceDigest(
          session.app.session.committedData.toJson(),
        ),
        'conversations': session.app.agent.conversations.conversations.length,
        'counters': counters,
      },
      details: {'storage': counters},
      memory: _memoryPair(before, after),
    );
  } finally {
    await session.close();
  }
}

Future<void> _recordReadCase(
  String name,
  AgentPerformanceFixtures fixtures,
  AgentPerformanceNetworkGuard network,
  _AgentRecorder recorder,
) async {
  final session = await AgentPerformanceDiskSession.prepare(
    fixtures,
    agentEnabled: true,
    network: network,
  );
  ApplicationToolHost? historyHost;
  final scope = OperationScope(
    id: 'benchmark-$name',
    policy: OperationPolicy(enabled: true, mode: AgentPermissionMode.full),
  );
  try {
    session.constructRuntime();
    await session.load(openAgent: true);
    final host = session.app.agent.tools;
    // Prime the actual immutable Skill snapshot before measuring read-only
    // traversal. This is not a model run and creates no chat messages.
    await readAgentPerformanceTool(host, scope, 'capabilities.describe', {
      'names': <String>[],
    });
    final long = session.app.agent.conversations.find(
      agentPerformanceLongConversationId,
    )!;
    historyHost = ApplicationToolHost(
      session: session.app.session,
      mutations: session.app.agent.mutations,
      conversationForScope: (_) => long,
      readSkillSnapshot: session.app.agent.knowledge.captureSkillSnapshot,
    );
    await readAgentPerformanceTool(
      historyHost,
      scope,
      'capabilities.describe',
      {'names': <String>[]},
    );
    final boundHistory = historyHost;
    final message = long.messages.firstWhere(
      (value) => value.id == 'long-0-reply',
    );
    final expectedResources =
        name == 'all-course-pages' || name == 'all-timetable-pages'
        ? fixtures.expectedResourceRecords(courses: name == 'all-course-pages')
        : const <Map<String, Object?>>[];
    final names = host.registeredNames;
    final storageBefore = session.counters;
    await recorder.record(name, () async {
      final timer = Stopwatch()..start();
      final pages = switch (name) {
        'long-history-all-pages' => await readAgentPerformanceHistory(
          boundHistory,
          scope,
        ),
        'long-message-all-slices' => await readAgentPerformanceMessage(
          boundHistory,
          scope,
          message.id,
        ),
        'all-timetable-pages' ||
        'all-course-pages' => await readAgentPerformanceResources(
          host,
          scope,
          courses: name == 'all-course-pages',
        ),
        'complete-tool-catalog' => await readAgentPerformanceCatalog(
          host,
          scope,
        ),
        _ => throw StateError('Unknown Agent read workload.'),
      };
      timer.stop();
      Object fixedResult = pages;
      switch (name) {
        case 'long-history-all-pages':
          verifyAgentPerformanceHistory(pages, long);
        case 'long-message-all-slices':
          verifyAgentPerformanceMessage(pages, message);
        case 'all-timetable-pages' || 'all-course-pages':
          verifyAgentPerformanceResources(pages, expectedResources);
        case 'complete-tool-catalog':
          fixedResult = verifyAgentPerformanceCatalog(pages, names);
      }
      sameAgentPerformance(
        session.counters,
        storageBefore,
        'Read-only storage counters',
      );
      sameAgentPerformance(
        session.app.session.committedData.toJson(),
        fixtures.data.toJson(),
        'Read-only main data',
      );
      sameAgentPerformance(
        session.app.agent.conversations.find(long.id)!.toJson(),
        fixtures.longConversation.toJson(),
        'Read-only conversation data',
      );
      return _AgentSample(
        elapsedUs: _microseconds(timer),
        result: fixedResult,
        details: {
          'toolPages': pages.length,
          if (expectedResources.isNotEmpty)
            'resources': expectedResources.length,
        },
        inspection: name == 'complete-tool-catalog' ? fixedResult : null,
      );
    });
  } finally {
    historyHost?.finishScope(scope);
    historyHost?.dispose();
    if (session.counters['mainLoads'] != 0) {
      session.app.agent.tools.finishScope(scope);
    }
    await session.close();
  }
}

Future<_AgentSample> _bulkSample(
  String name,
  AgentPerformanceFixtures fixtures,
  AgentPerformanceNetworkGuard network,
  Stopwatch protocolClock,
) async {
  final courses = name == 'batch-one-hundred-course-locations';
  final commands = fixtures.bulkCommands(courses: courses);
  final expected = fixtures.expectedAfterBulk(courses: courses);
  requireAgentPerformance(
    commands.length == (courses ? 100 : 1),
    'The declared mutation workload changed its command count.',
  );
  final operationId = courses
      ? '$agentPerformanceGeneration/1/00000000-0000-4000-8000-000000000002'
      : '$agentPerformanceGeneration/1/00000000-0000-4000-8000-000000000003';
  final session = await AgentPerformanceDiskSession.prepare(
    fixtures,
    agentEnabled: true,
    network: network,
  );
  try {
    session.constructRuntime();
    await session.load(openAgent: true);
    Map<String, Object?>? commit;
    Map<String, Object?>? memory;
    double? elapsed;
    Object? failure;
    StackTrace? failureStack;
    await session.app.agent.runtime.runHostAction(
      agentPerformanceBulkConversationId,
      (scope, approval) async {
        final host = session.app.agent.tools;
        await readAgentPerformanceTool(host, scope, 'capabilities.describe', {
          'names': ['mutation.prepare', 'mutation.commit'],
        });
        session.storage.writes = 0;
        final before = observeAgentPerformanceMemory(protocolClock);
        final timer = Stopwatch()..start();
        try {
          final prepared = await host.execute(
            ProviderToolCall(
              id: 'benchmark-prepare',
              name: 'mutation.prepare',
              arguments: jsonEncode({
                'commands': commands,
                'operationId': operationId,
              }),
            ),
            scope,
            approval,
          );
          commit = await host.execute(
            ProviderToolCall(
              id: 'benchmark-commit',
              name: 'mutation.commit',
              arguments: jsonEncode({'planId': prepared['planId']}),
            ),
            scope,
            approval,
          );
        } catch (error, stack) {
          failure = error;
          failureStack = stack;
        } finally {
          timer.stop();
          elapsed = _microseconds(timer);
          memory = _memoryPair(
            before,
            observeAgentPerformanceMemory(protocolClock),
          );
        }
        return {
          'status': failure == null ? 'complete' : 'failed',
          'operationId': operationId,
        };
      },
    );
    if (failure != null) Error.throwWithStackTrace(failure!, failureStack!);
    requireAgentPerformance(
      commit != null && elapsed != null,
      'The host action did not execute the fixed batch.',
    );
    await session.app.agent.quiesce();
    requireAgentPerformance(
      commit!['status'] == 'committed' && commit!['operationId'] == operationId,
      'The batch did not return a confirmed main-store receipt.',
    );
    requireAgentPerformance(
      session.storage.writes == 1,
      'The atomic batch did not make exactly one physical main save.',
    );
    final actual = session.app.session.committedData;
    sameAgentPerformance(
      agentPerformanceDomain(actual),
      agentPerformanceDomain(expected),
      'All changed and unchanged business data',
    );
    final ledger = actual.applicationLedger!;
    requireAgentPerformance(
      ledger.generation == agentPerformanceGeneration &&
          ledger.nextSequence == 2 &&
          ledger.receipts.length == 1,
      'The batch produced an unexpected ledger history.',
    );
    final receipt = ledger.receipts.single;
    requireAgentPerformance(
      receipt.operationId == operationId &&
          receipt.sequence == 1 &&
          receipt.undo != null,
      'The durable batch is missing its owned inverse.',
    );
    final readback = await session.readBack();
    sameAgentPerformance(
      readback.toJson(),
      actual.toJson(),
      'Complete physical main archive readback including receipt metadata',
    );
    return _AgentSample(
      elapsedUs: elapsed!,
      result: {
        'domain': agentPerformanceDomain(actual),
        'generation': ledger.generation,
        'operationId': receipt.operationId,
        'sequence': receipt.sequence,
        'commandDigest': receipt.commandDigest,
        'status': commit!['status'],
        'commands': commands,
        'writes': session.storage.writes,
      },
      details: {
        'commands': commands.length,
        'mainWrites': session.storage.writes,
        'physicalReadbackSha256': agentPerformanceDigest(readback.toJson()),
        'receiptCompletedAt': receipt.completedAtIso,
      },
      memory: memory,
    );
  } finally {
    await session.close();
  }
}

double _microseconds(Stopwatch timer) =>
    timer.elapsedTicks * Duration.microsecondsPerSecond / timer.frequency;

Map<String, Object?> _memoryPair(
  Map<String, int> before,
  Map<String, int> after,
) => {
  'before': before,
  'after': after,
  'rssDeltaBytes': after['rssBytes']! - before['rssBytes']!,
  'processLifetimePeakGrowthBytes':
      after['processLifetimePeakRssBytes']! -
      before['processLifetimePeakRssBytes']!,
};
