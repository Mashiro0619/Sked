import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sked/agent/references/agent_composer_reference.dart';
import 'package:sked/agent/ui/agent_conversation_view.dart';
import 'package:sked/application/resource_contracts.dart';

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
      expect(h.delegate.pendingInputCount(h.id), 0);
      expect(h.delegate.calls, isEmpty);
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
      expect(h.delegate.pendingInputCount(h.id), 0);
      expect(h.delegate.calls, isEmpty);
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
      expect(h.delegate.pendingInputCount(h.id), 1);
      release.complete();
      await tester.pumpAndSettle();
      h.storage.beforeSave = null;
      expect(tester.widget<TextField>(composer).enabled, isTrue);
      expect(
        tester.widget<TextField>(composer).controller!.text,
        'Original queued text',
      );
      expect(h.delegate.pendingInputCount(h.id), 0);
      expect(h.delegate.calls, isEmpty);
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
      expect(h.delegate.pendingInputCount(h.id), 1);
      expect(h.repository.find(h.id)!.draft, isEmpty);
      expect(h.repository.selected!.draft, 'Other draft');
      expect(
        tester.widget<TextField>(composer).controller!.text,
        'Other draft',
      );
      expect(h.delegate.calls, isEmpty);
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
      expect(first.delegate.pendingInputCount(first.id), 1);
      expect(second.delegate.pendingInputCount(second.id), 1);
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
      expect(h.delegate.pendingInputCount(h.id), 0);
      expect(h.delegate.calls, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}

class _Harness {
  _Harness(this.storage, this.repository, this.delegate, this.id);
  final UiMemoryStorage storage;
  final MemoryConversationRepository repository;
  final _Delegate delegate;
  final String id;
  AgentConversation get current => repository.find(id)!;
  AgentConversationView view() =>
      AgentConversationView(repository: repository, delegate: delegate);

  static Future<_Harness> create() async {
    final storage = UiMemoryStorage();
    var sequence = 0;
    final repository = MemoryConversationRepository(
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
        ],
        queuedInputs: [
          ConversationQueuedInput(
            id: 'queued',
            text: 'Original queued text',
            createdAt: DateTime.utc(2026, 11, 7),
            contextReferences: [reference],
          ),
        ],
      ),
    );
    return _Harness(
      storage,
      repository,
      _Delegate(repository),
      conversation.id,
    );
  }

  Future<void> close() async {
    storage.beforeSave = null;
    await repository.waitForPendingWrites();
    delegate.state.dispose();
    repository.dispose();
  }
}

class _Delegate extends UiDelegate {
  _Delegate(super.repository);
  final actions = <String>[];
  Future<void> Function()? beforeAction;
  @override
  bool canManageQueuedInput(String id, String inputId) =>
      repository.canWrite &&
      repository.find(id)!.queuedInputs.any((input) => input.id == inputId);
  @override
  int pendingInputCount(String id) =>
      repository.find(id)?.queuedInputs.length ?? 0;
  @override
  Future<void> restoreQueuedInput(
    String id,
    ConversationMessage input, {
    void Function()? validate,
  }) async {
    actions.add('restore:$id:${input.id}');
    await beforeAction?.call();
    validate?.call();
    await repository.update(id, (current) {
      final queued = current.queuedInputs.singleWhere(
        (value) => value.id == input.id,
      );
      return current.copyWith(
        draft: queued.text,
        draftReferences: queued.contextReferences,
        draftAttachmentIds: queued.attachmentIds,
        queuedInputs: current.queuedInputs.where(
          (value) => value.id != input.id,
        ),
      );
    });
  }

  @override
  Future<void> cancelQueuedInput(
    String id,
    ConversationMessage input, {
    void Function()? validate,
  }) async {
    actions.add('cancel:$id:${input.id}');
    await beforeAction?.call();
    validate?.call();
    await repository.update(
      id,
      (current) => current.copyWith(
        queuedInputs: current.queuedInputs.where(
          (value) => value.id != input.id,
        ),
      ),
    );
  }
}
