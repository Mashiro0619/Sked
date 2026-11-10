import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/bridge/rust_agent_ui_delegate.dart';
import 'package:sked/agent/ui/agent_ui_delegate.dart';
import 'package:sked/models/agent_settings.dart';

import '../../support/agent_native_fixture.dart';

const _id = 'failed-chat';
const _failure = ViewProviderFailure(
  code: 'provider.authentication',
  statusCode: 401,
  responseCode: 'invalid_api_key',
  responseMessage: 'Key [redacted] was rejected.',
  responseBody: '{"error":{"code":"invalid_api_key","message":"Key [redacted] was rejected."}}',
  requestId: 'failed-request-401',
);

ViewConversationSnapshot _snapshot({
  ViewProviderFailure? failure,
  String runId = 'run',
  int sequence = 1,
}) => ViewConversationSnapshot(
  conversation: copyNativeConversation(
    nativeConversationFixture(id: _id).conversation,
    status: ViewConversationStatus.interrupted,
    runId: runId,
  ),
  sequence: sequence,
  messages: const [],
  runs: [
    ViewRun(
      id: runId,
      startedAt: 1793664000000,
      settledAt: 1793664000001,
      kind: ViewRunKind.model,
      status: ViewRunStatus.interrupted,
      requests: const [],
      tools: const [],
      errorCode: failure?.code,
      providerFailure: failure,
      environment: const JsonPayload(json: '{}'),
    ),
  ],
  turns: const [],
  operations: const [],
  queuedInputs: const [],
  queuedControls: const [],
  contextFailures: const [],
  historyVersions: const [],
  replyRevisions: const [],
  redoBatches: const [],
  attachments: const [],
  attachmentReferences: const [],
  sources: const [],
  handoffs: const [],
  providerHistory: const [],
  extensions: const {},
);

class _FailureCore extends MemoryAgentCore {
  _FailureCore() : super(snapshots: [_snapshot()]);
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
  Future<void> shutdown() async {
    unawaited(_source.close());
    await super.shutdown();
  }
}

void main() {
  late _FailureCore core;
  late RustAgentUiDelegate delegate;

  RustAgentUiDelegate openDelegate() => RustAgentUiDelegate(
    client: core.client,
    readSettings: () => const AgentSettings(),
    readApiKey: (_) async => '',
    onOpenSettings: () {},
  );

  setUp(() async {
    core = _FailureCore();
    delegate = openDelegate();
    await delegate.loadConversation(_id);
  });

  tearDown(() async {
    await delegate.dispose();
    await core.client.shutdown();
  });

  AgentUiRunState state() => delegate.state.value.runFor(_id);

  void expectFailure() {
    expect(state().phase, AgentUiPhase.failed);
    expect(state().errorMessage, 'provider.authentication');
    expect(state().providerErrorDetails, _failure.responseMessage);
    expect(state().providerErrorResponseBody, _failure.responseBody);
    expect(jsonDecode(state().providerErrorMetadata!), {
      'statusCode': 401,
      'responseCode': 'invalid_api_key',
      'requestId': 'failed-request-401',
    });
  }

  test('settled provider diagnostics reach UI state and restore from the saved run', () async {
    final view = delegate.watchConversation(_id);
    final changed = Completer<void>();
    void onChange() {
      if (view.value.phase == AgentUiPhase.failed && !changed.isCompleted) {
        changed.complete();
      }
    }

    view.addListener(onChange);
    core.emit(
      const AgentEvent(
        kind: EventKind.runSettled,
        conversationId: _id,
        runId: 'run',
        outcome: HostOutcome.error,
        errorCode: 'provider.authentication',
        text: 'provider.authentication',
        providerFailure: _failure,
      ),
    );
    await changed.future;
    view.removeListener(onChange);
    expectFailure();

    core.snapshots[_id] = _snapshot(failure: _failure, sequence: 2);
    await delegate.dispose();
    delegate = openDelegate();
    await delegate.loadConversation(_id);
    expectFailure();

    core.snapshots[_id] = _snapshot(runId: 'next-run', sequence: 3);
    await delegate.loadConversation(_id);
    expect(state().errorMessage, isNull);
    expect(state().providerErrorDetails, isNull);
    expect(state().providerErrorResponseBody, isNull);
    expect(state().providerErrorMetadata, isNull);
  });
}
