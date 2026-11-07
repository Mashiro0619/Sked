import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/references/agent_composer_reference.dart';
import 'package:sked/agent/runtime/agent_runtime_controller.dart';
import 'package:sked/agent/ui/agent_conversation_view.dart';
import 'package:sked/agent/ui/agent_ui_delegate.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/application/resource_contracts.dart';
import 'package:sked/models/agent_settings.dart';

import 'agent_ui_test_support.dart';

void main() {
  final restore = find.byKey(const ValueKey('agent-restore-queued-queued'));
  final cancel = find.byKey(const ValueKey('agent-cancel-queued-queued'));
  final composer = find.byKey(const ValueKey('agent-composer'));

  Future<_Harness> fixture() async {
    final h = await _Harness.create();
    addTearDown(h.close);
    return h;
  }

  Future<void> reveal(WidgetTester tester, Finder target) async {
    final scroll = find
        .descendant(
          of: find.byKey(const ValueKey('agent-transcript-conversation')),
          matching: find.byType(Scrollable),
        )
        .first;
    if (target.evaluate().isEmpty) {
      await tester.scrollUntilVisible(target, -120, scrollable: scroll);
    }
    for (
      var attempt = 0;
      attempt < 6 && target.hitTestable().evaluate().isEmpty;
      attempt++
    ) {
      await tester.drag(scroll, const Offset(0, 120));
      await tester.pumpAndSettle();
    }
    expect(target.hitTestable(), findsOneWidget);
  }

  testWidgets(
    'moving a queued input restores its original text and references without sending',
    (tester) async {
      addTearDown(tester.view.reset);
      final h = await fixture();
      await mountAgentUi(tester, h.view());
      await reveal(tester, restore);
      await tester.tap(restore.hitTestable());
      await tester.pumpAndSettle();
      expect(restore, findsNothing);
      expect(h.current.draft, 'Original queued text');
      expect(h.current.draftReferences.single.label, 'Selected timetable');
      final field = tester.widget<TextField>(composer);
      expect(field.controller!.text, 'Original queued text');
      expect(field.focusNode!.hasFocus, isTrue);
      expect(field.enabled, isTrue);
      expect(h.runtime.pendingInputCount(h.id), 0);
      expect(h.provider.requests, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'an existing draft disables restore and cancellation preserves it',
    (tester) async {
      addTearDown(tester.view.reset);
      final h = await fixture();
      await h.repository.update(
        h.id,
        (current) => current.copyWith(draft: 'Keep this draft'),
      );
      await mountAgentUi(tester, h.view());
      await reveal(tester, cancel);
      expect(tester.widget<TextButton>(restore).onPressed, isNull);
      expect(tester.widget<TextButton>(cancel).onPressed, isNotNull);
      await tester.tap(cancel.hitTestable());
      await tester.pumpAndSettle();
      expect(cancel, findsNothing);
      expect(h.current.draft, 'Keep this draft');
      expect(
        tester.widget<TextField>(composer).controller!.text,
        'Keep this draft',
      );
      expect(h.runtime.pendingInputCount(h.id), 0);
      expect(h.provider.requests, isEmpty);
    },
  );

  testWidgets(
    'restoration locks the composer until the atomic save completes',
    (tester) async {
      addTearDown(tester.view.reset);
      final h = await fixture();
      await mountAgentUi(tester, h.view());
      await reveal(tester, restore);
      final entered = Completer<void>();
      final release = Completer<void>();
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      h.storage.beforeSave = () {
        if (!entered.isCompleted) entered.complete();
        return release.future;
      };
      await tester.tap(restore.hitTestable());
      await tester.pump();
      expect(entered.isCompleted, isTrue);
      expect(tester.widget<TextField>(composer).enabled, isFalse);
      expect(h.runtime.pendingInputCount(h.id), 1);
      release.complete();
      await tester.pumpAndSettle();
      h.storage.beforeSave = null;
      expect(tester.widget<TextField>(composer).enabled, isTrue);
      expect(
        tester.widget<TextField>(composer).controller!.text,
        'Original queued text',
      );
      expect(h.runtime.pendingInputCount(h.id), 0);
      expect(h.provider.requests, isEmpty);
    },
  );

  testWidgets(
    'a delayed action cannot move input after switching conversations',
    (tester) async {
      addTearDown(tester.view.reset);
      final h = await fixture();
      await mountAgentUi(tester, h.view());
      await reveal(tester, restore);
      final release = Completer<void>();
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      h.delegate.beforeAction = () => release.future;
      await tester.tap(restore.hitTestable());
      await tester.pump();
      final other = await h.repository.create(title: 'Other conversation');
      await h.repository.update(
        other.id,
        (current) => current.copyWith(draft: 'Other draft'),
      );
      await tester.pumpAndSettle();
      release.complete();
      await tester.pumpAndSettle();
      expect(h.runtime.pendingInputCount(h.id), 1);
      expect(h.repository.find(h.id)!.draft, isEmpty);
      expect(h.repository.selected!.draft, 'Other draft');
      expect(
        tester.widget<TextField>(composer).controller!.text,
        'Other draft',
      );
      expect(h.provider.requests, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a stale card callback cannot target another repository with equal IDs',
    (tester) async {
      addTearDown(tester.view.reset);
      final first = await fixture();
      final second = await fixture();
      await mountAgentUi(tester, first.view());
      await reveal(tester, restore);
      final callback = tester.widget<TextButton>(restore).onPressed!;
      await mountAgentUi(tester, second.view());
      callback();
      await tester.pumpAndSettle();
      expect(first.delegate.actions, isEmpty);
      expect(second.delegate.actions, isEmpty);
      expect(first.runtime.pendingInputCount(first.id), 1);
      expect(second.runtime.pendingInputCount(second.id), 1);
      expect(second.current.draft, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'queued editing and cancellation remain usable at 320px with 2x text',
    (tester) async {
      addTearDown(tester.view.reset);
      final h = await fixture();
      await mountAgentUi(
        tester,
        h.view(),
        size: const Size(320, 480),
        scale: 2,
      );
      await reveal(tester, cancel);
      await tester.tap(cancel.hitTestable());
      await tester.pumpAndSettle();
      expect(h.runtime.pendingInputCount(h.id), 0);
      expect(h.provider.requests, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}

class _Harness {
  _Harness(
    this.storage,
    this.repository,
    this.provider,
    this.runtime,
    this.delegate,
    this.id,
  );
  final UiMemoryStorage storage;
  final ConversationRepository repository;
  final _Provider provider;
  final AgentRuntimeController runtime;
  final _Delegate delegate;
  final String id;
  AgentConversation get current => repository.find(id)!;
  AgentConversationView view() =>
      AgentConversationView(repository: repository, delegate: delegate);

  static Future<_Harness> create() async {
    final storage = UiMemoryStorage();
    var sequence = 0;
    final repository = ConversationRepository(
      storage: storage,
      idGenerator: () =>
          sequence++ == 0 ? 'conversation' : 'conversation-$sequence',
    );
    await repository.load();
    final conversation = await repository.create(title: 'Queue editing');
    final reference = AgentComposerReference.resource(
      ref: const ResourceRef(kind: ResourceKind.timetable, id: 'table'),
      datasetGeneration: 'fixture-generation',
      label: 'Selected timetable',
    );
    await repository.update(
      conversation.id,
      (current) => current.copyWith(
        messages: [
          ConversationMessage(
            id: 'request',
            role: ConversationRole.user,
            text: 'Initial request',
            createdAt: DateTime.utc(2026, 11, 7),
          ),
          ConversationMessage(
            id: 'queued',
            role: ConversationRole.notice,
            text: jsonEncode({
              'kind': 'agent_pending_input',
              'version': 1,
              'mode': 'followUp',
              'text': 'Original queued text',
            }),
            createdAt: DateTime.utc(2026, 11, 7),
            contextReferences: [reference],
          ),
        ],
      ),
    );
    final provider = _Provider();
    final runtime = AgentRuntimeController(
      repository: repository,
      provider: provider,
      readSettings: () => const AgentSettings(
        enabled: true,
        endpoint: 'https://fixture.example/v1',
        model: 'fixture',
        models: [
          AgentModelConfig(
            id: 'fixture',
            reasoningEfforts: [AgentReasoningEffort.medium],
            defaultReasoningEffort: AgentReasoningEffort.medium,
          ),
        ],
      ),
      readApiKey: (_) async => '',
      readTools: (_) => const [],
      executeTool: (_, _, _) async => throw StateError('Unexpected tool'),
      onOpenSettings: () {},
    );
    return _Harness(
      storage,
      repository,
      provider,
      runtime,
      _Delegate(runtime),
      conversation.id,
    );
  }

  Future<void> close() async {
    storage.beforeSave = null;
    runtime.dispose();
    await runtime.waitForIdle();
    repository.dispose();
  }
}

class _Provider extends ProviderClient {
  final requests = <ProviderRequest>[];
  @override
  Stream<ProviderEvent> stream(
    ProviderRequest request, {
    required String apiKey,
    ProviderCancellationToken? cancellation,
  }) async* {
    requests.add(request);
    yield ProviderCompleted(
      ProviderResponse(
        text: 'Completed',
        toolCalls: const [],
        finishReason: 'stop',
      ),
    );
  }
}

class _Delegate extends AgentUiDelegate {
  _Delegate(this.runtime);
  final AgentRuntimeController runtime;
  final actions = <String>[];
  Future<void> Function()? beforeAction;
  @override
  ValueListenable<AgentUiState> get state => runtime.state;
  @override
  Future<void> send(String id, String text) => runtime.send(id, text);
  @override
  Future<void> stop(String id) => runtime.stop(id);
  @override
  Future<void> approve(String id, String planId) => runtime.approve(id, planId);
  @override
  Future<void> reject(String id, String planId) => runtime.reject(id, planId);
  @override
  Future<void> setMode(String id, AgentPermissionMode mode) =>
      runtime.setMode(id, mode);
  @override
  void openSettings() {}
  @override
  bool canManageQueuedInput(String id, String inputId) =>
      runtime.canManageQueuedInput(id, inputId);
  @override
  int pendingInputCount(String id) => runtime.pendingInputCount(id);
  @override
  Future<void> restoreQueuedInput(
    String id,
    ConversationMessage input, {
    void Function()? validate,
  }) async {
    actions.add('restore:$id:${input.id}');
    await beforeAction?.call();
    await runtime.restoreQueuedInput(id, input, validate: validate);
  }

  @override
  Future<void> cancelQueuedInput(
    String id,
    ConversationMessage input, {
    void Function()? validate,
  }) async {
    actions.add('cancel:$id:${input.id}');
    await beforeAction?.call();
    await runtime.cancelQueuedInput(id, input, validate: validate);
  }
}
