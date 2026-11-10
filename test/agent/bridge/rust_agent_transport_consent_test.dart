import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/bridge/rust_agent_ui_delegate.dart';
import 'package:sked/agent/ui/agent_ui_delegate.dart';
import 'package:sked/models/agent_settings.dart';

import '../../support/agent_native_fixture.dart';

const _id = 'transport-chat';
const _key = 'transport-test-key';
const _settings = AgentSettings(
  endpoint: 'http://localhost:8765/v1',
  model: 'test-model',
  models: [
    AgentModelConfig(
      id: 'test-model',
      reasoningEfforts: [AgentReasoningEffort.none],
      defaultReasoningEffort: AgentReasoningEffort.none,
    ),
  ],
);

ViewConversationSnapshot _snapshot({String title = 'Chat'}) {
  final value = nativeConversationFixture(id: _id, title: title);
  return copyNativeSnapshot(
    value,
    conversation: copyNativeConversation(
      value.conversation,
      status: ViewConversationStatus.running,
      runId: 'run',
    ),
  );
}

class _TransportCore extends MemoryAgentCore {
  _TransportCore() : super(snapshots: [_snapshot()]);
  final submitted = <HostResult>[];
  final _results = <String, Completer<HostResult>>{};
  Future<void> Function()? afterRead;
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
    await afterRead?.call();
    return result;
  }

  @override
  Future<void> submitHostResult({required HostResult result}) async {
    submitted.add(result);
    (_results[result.requestId] ??= Completer<HostResult>()).complete(result);
  }

  Future<HostResult> result(String id) =>
      (_results[id] ??= Completer<HostResult>()).future;

  void request(String requestId) => emit(
    AgentEvent(
      kind: EventKind.hostRequest,
      conversationId: _id,
      hostRequest: HostRequest(
        id: requestId,
        kind: HostRequestKind.authorizeConnection,
        conversationId: _id,
        runId: 'run',
        mode: ViewPermissionMode.ask,
        operationIds: const [],
        connection: ConnectionIdentity(
          endpoint: 'http://localhost:8765/v1/chat/completions',
          protocol: ModelProtocol.chatCompletions,
          model: 'test-model',
          fingerprint: sha256.convert(utf8.encode(_key)).toString(),
        ),
      ),
    ),
  );

  @override
  Future<void> shutdown() async => unawaited(_source.close());
}

void main() {
  late _TransportCore core;
  late RustAgentUiDelegate delegate;
  late AgentSettings settings;
  final titles = <String>[];

  setUp(() async {
    core = _TransportCore();
    settings = _settings;
    titles.clear();
    delegate = RustAgentUiDelegate(
      client: core.client,
      readSettings: () => settings,
      readApiKey: (_) async => _key,
      onOpenSettings: () {},
      onState: (snapshot) => titles.add(snapshot.conversation.title),
    );
    await core.client.ensureInitialized();
    await delegate.loadConversation(_id);
  });

  tearDown(() async {
    await delegate.dispose();
    await core.client.shutdown();
  });

  Future<AgentUiApproval?> approvalOrResult(String requestId) async {
    final view = delegate.watchConversation(_id);
    final ready = Completer<AgentUiApproval>();
    void changed() {
      final approval = view.value.pendingApproval;
      if (approval?.id == requestId && !ready.isCompleted) {
        ready.complete(approval);
      }
    }

    view.addListener(changed);
    changed();
    try {
      return await Future.any([
        ready.future,
        core.result(requestId).then<AgentUiApproval?>((_) => null),
      ]);
    } finally {
      view.removeListener(changed);
    }
  }

  Future<void> refreshFromNavigation() async {
    final reading = Completer<void>();
    core.beforeQuery = (query) async {
      if (query.kind == QueryKind.conversationState && !reading.isCompleted) {
        reading.complete();
      }
    };
    core.emit(const AgentEvent(kind: EventKind.resync, conversationId: ''));
    await reading.future;
    await delegate.loadConversation(_id);
    core.beforeQuery = null;
  }

  test(
    'navigation refresh preserves pending and granted HTTP consent',
    () async {
      core.request('first');
      final approval = await approvalOrResult('first');
      expect(approval, isNotNull);
      await refreshFromNavigation();
      expect(core.submitted, isEmpty);
      expect(delegate.state.value.runFor(_id).pendingApproval, same(approval));
      await delegate.approve(_id, approval!.id);
      expect((await core.result('first')).outcome, HostOutcome.success);

      await refreshFromNavigation();
      core.request('same-connection');
      expect(
        (await core.result('same-connection')).outcome,
        HostOutcome.success,
      );
      expect(delegate.state.value.runFor(_id).pendingApproval, isNull);
    },
  );

  test('data restoration and disabling still retire HTTP consent', () async {
    core.request('before-restore');
    final approval = await approvalOrResult('before-restore');
    await delegate.approve(_id, approval!.id);
    expect((await core.result('before-restore')).outcome, HostOutcome.success);

    delegate.invalidateAfterDataBoundary();
    await delegate.loadConversation(_id);
    core.request('after-restore');
    expect(await approvalOrResult('after-restore'), isNotNull);
    delegate.invalidateAfterDataBoundary();
    expect((await core.result('after-restore')).outcome, HostOutcome.cancelled);

    await delegate.loadConversation(_id);
    core.request('before-disable');
    expect(await approvalOrResult('before-disable'), isNotNull);
    settings = settings.copyWith(enabled: false);
    delegate.refreshSettings();
    expect(
      (await core.result('before-disable')).outcome,
      HostOutcome.cancelled,
    );
  });

  test('a pre-restore query cannot replace or remove the new query', () async {
    final captured = Completer<void>();
    final releaseOld = Completer<void>();
    final freshStarted = Completer<void>();
    final releaseFresh = Completer<void>();
    var reads = 0;
    core.afterRead = () async {
      if (reads++ == 0) {
        captured.complete();
        await releaseOld.future;
      } else {
        freshStarted.complete();
        await releaseFresh.future;
      }
    };
    addTearDown(() {
      if (!releaseOld.isCompleted) releaseOld.complete();
      if (!releaseFresh.isCompleted) releaseFresh.complete();
    });

    final old = delegate.loadConversation(_id);
    await captured.future;
    delegate.invalidateAfterDataBoundary();
    core.snapshots[_id] = _snapshot(title: 'Restored chat');
    final fresh = delegate.loadConversation(_id);
    await freshStarted.future;
    releaseOld.complete();
    expect(await old, isNull);
    expect(delegate.loadConversation(_id), same(fresh));
    releaseFresh.complete();
    expect((await fresh)?.conversation.title, 'Restored chat');
    expect(titles.last, 'Restored chat');
  });
}
