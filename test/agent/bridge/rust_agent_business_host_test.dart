import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/bridge/rust_agent_business_host.dart';

import '../../support/agent_native_fixture.dart';
import '../tools/core_tool_test_support.dart';

const _conversationId = 'business-host-chat';
const _runId = 'business-host-run';

ViewConversationSnapshot _snapshot(ViewPermissionMode mode) =>
    nativeConversationFixture(id: _conversationId, mode: mode);

class _HostCore extends MemoryAgentCore {
  _HostCore() : super(snapshots: [_snapshot(ViewPermissionMode.ask)]);

  final _results = <String, Completer<HostResult>>{};
  final _approvals = <String, Completer<AgentHostProgress>>{};
  Future<void> Function(AgentQuery)? afterRead;
  List<ViewConversationSource> sources = const [];
  late final StreamController<AgentEvent> _source =
      StreamController<AgentEvent>.broadcast(
        onListen: () => scheduleMicrotask(
          () => _source.add(
            const AgentEvent(kind: EventKind.ready, conversationId: ''),
          ),
        ),
      );

  @override
  Stream<AgentEvent> watchEvents() => _source.stream;

  @override
  void emit(AgentEvent event) => _source.add(event);

  @override
  Future<QueryResult> query({required AgentQuery query}) async {
    final result = await super.query(query: query);
    await afterRead?.call(query);
    if (query.kind == QueryKind.businessContext) {
      return QueryResult(
        conversations: const [],
        messages: const [],
        total: 0,
        knowledge: const [],
        historyVersions: const [],
        replyRevisions: const [],
        state: result.state,
        run: result.run,
        sources: sources,
        attachments: result.attachments,
      );
    }
    return result;
  }

  @override
  Future<void> submitHostResult({required HostResult result}) async {
    (_results[result.requestId] ??= Completer<HostResult>()).complete(result);
  }

  @override
  Future<void> submitHostProgress({required AgentHostProgress progress}) async {
    if (progress.phase == HostPhase.approvalRequired) {
      (_approvals[progress.requestId] ??= Completer<AgentHostProgress>())
          .complete(progress);
    }
  }

  Future<HostResult> result(String id) =>
      (_results[id] ??= Completer<HostResult>()).future;

  Future<AgentHostProgress?> approvalOrResult(String id) => Future.any([
    (_approvals[id] ??= Completer<AgentHostProgress>()).future,
    result(id).then<AgentHostProgress?>((_) => null),
  ]);

  Future<HostResult> send(HostRequest request) {
    final response = result(request.id);
    emit(
      AgentEvent(
        kind: EventKind.hostRequest,
        conversationId: request.conversationId,
        hostRequest: request,
      ),
    );
    return response;
  }

  Future<void> setMode(ViewPermissionMode mode, String requestId) async {
    snapshots[_conversationId] = _snapshot(mode);
    await send(
      HostRequest(
        id: requestId,
        kind: HostRequestKind.setMode,
        conversationId: _conversationId,
        mode: mode,
        operationIds: const [],
      ),
    );
  }

  Future<HostResult> createCalendar() => send(
    const HostRequest(
      id: 'create-calendar',
      kind: HostRequestKind.execute,
      conversationId: _conversationId,
      runId: _runId,
      toolCallId: 'create-calendar-call',
      toolName: 'mutation.apply',
      mode: ViewPermissionMode.ask,
      operationIds: [],
      arguments: JsonPayload(
        json:
            '{"commands":[{"kind":"calendar","action":"create",'
            '"values":{"name":"Business host permission test"}}]}',
      ),
    ),
  );

  Future<void> reject() async {
    await send(
      const HostRequest(
        id: 'reject-calendar',
        kind: HostRequestKind.resolveApproval,
        conversationId: _conversationId,
        runId: _runId,
        toolCallId: 'create-calendar-call',
        approved: false,
        operationIds: [],
      ),
    );
  }

  @override
  Future<void> shutdown() async => unawaited(_source.close());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CoreToolHarness business;
  late _HostCore core;
  late RustAgentBusinessHost host;

  setUp(() async {
    business = CoreToolHarness();
    await business.initialize(
      conversationForScope: (scope) => host.conversationForScope(scope),
    );
    core = _HostCore();
    host = RustAgentBusinessHost(
      client: core.client,
      tools: business.tools,
      readEnvironment: (_) => const {},
    );
    await core.client.ensureInitialized();
  });

  tearDown(() async {
    await core.client.shutdown();
    await host.dispose();
    business.tools.dispose();
    await business.close();
  });

  test(
    'business tools receive requested source material without reading history',
    () async {
      core.sources = const [
        ViewConversationSource(
          id: 'import-source',
          kind: 'text',
          text: 'Material needed by the business tool.',
          truncated: false,
        ),
      ];
      final result = await core.send(
        const HostRequest(
          id: 'read-source',
          kind: HostRequestKind.execute,
          conversationId: _conversationId,
          runId: _runId,
          toolCallId: 'read-source-call',
          toolName: 'sources.read',
          mode: ViewPermissionMode.ask,
          operationIds: [],
          arguments: JsonPayload(json: '{"id":"import-source"}'),
        ),
      );
      expect(
        result.outcome,
        HostOutcome.success,
        reason: result.modelPayload?.json ?? result.errorMessage,
      );
      final payload = jsonDecode(result.modelPayload!.json) as Map;
      expect(payload['text'], 'Material needed by the business tool.');
      expect(core.queries.map((query) => query.kind), [
        QueryKind.businessContext,
      ]);
    },
  );

  test(
    'restored Ask history does not inherit a deleted Full permission',
    () async {
      await core.setMode(ViewPermissionMode.full, 'old-full');
      core.snapshots.remove(_conversationId);
      core.emit(const AgentEvent(kind: EventKind.resync, conversationId: ''));
      core.snapshots[_conversationId] = _snapshot(ViewPermissionMode.ask);
      final before =
          business.session.committedData.generalMode.schedules.length;

      final saved = core.createCalendar();
      expect(await core.approvalOrResult('create-calendar'), isNotNull);
      expect(
        business.session.committedData.generalMode.schedules.length,
        before,
      );
      await core.reject();
      expect((await saved).outcome, HostOutcome.cancelled);
      expect(
        business.session.committedData.generalMode.schedules.length,
        before,
      );
    },
  );

  test(
    'a mode change during initial context reading uses a fresh native mode',
    () async {
      core.snapshots[_conversationId] = _snapshot(ViewPermissionMode.full);
      final captured = Completer<void>();
      final release = Completer<void>();
      core.afterRead = (query) async {
        if (query.kind == QueryKind.businessContext && !captured.isCompleted) {
          captured.complete();
          await release.future;
        }
      };
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });

      final saved = core.createCalendar();
      await captured.future;
      await core.setMode(ViewPermissionMode.ask, 'changed-to-ask');
      release.complete();
      expect(await core.approvalOrResult('create-calendar'), isNotNull);
      expect(
        core.queries.where((query) => query.kind == QueryKind.businessContext),
        hasLength(2),
      );
      await core.reject();
      expect((await saved).outcome, HostOutcome.cancelled);
    },
  );

  test(
    'tightening an active approval retires its permission before saving',
    () async {
      final before =
          business.session.committedData.generalMode.schedules.length;
      final saved = core.createCalendar();
      expect(await core.approvalOrResult('create-calendar'), isNotNull);
      await core.setMode(ViewPermissionMode.plan, 'changed-to-plan');
      final result = await saved;
      expect(result.outcome, HostOutcome.error);
      final payload = jsonDecode(result.modelPayload!.json) as Map;
      expect(payload['status'], 'failed');
      expect(payload['error']['code'], 'readOnly');
      expect(
        business.session.committedData.generalMode.schedules.length,
        before,
      );
    },
  );
}
