import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/agent_application.dart';
import 'package:sked/agent/connection/agent_credential_store.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/references/agent_composer_reference.dart';
import 'package:sked/agent/references/agent_composer_reference_search.dart';
import 'package:sked/agent/runtime/agent_runtime_controller.dart';
import 'package:sked/agent/ui/agent_ui_delegate.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/models/agent_settings.dart';

import '../../support/workspace_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<_Harness> fixture() async {
    final h = await _Harness.create();
    addTearDown(h.close);
    return h;
  }

  test('expired queued references return to an editable draft and can be corrected before sending', () async {
    final h = await fixture();
    final reference = await h.resource();
    final initial = h.start();
    await h.provider.entered.future;
    await h.app.agent.updateComposerReferences(h.id, [reference]);
    await h.app.agent.runtime.queueFollowUp(h.id, 'Inspect this timetable');
    final queued = h.queued.single;
    await h.removeResource(reference);
    h.provider.release();
    await initial;
    await h.waitUntil(
      () =>
          !h.app.agent.runtime.isRunning(h.id) &&
          h.app.agent.runtime.state.value.runFor(h.id).errorMessage ==
              'invalidReference',
    );

    await h.app.agent.runtime.restoreQueuedInput(h.id, queued);
    expect(h.queued, isEmpty);
    expect(h.current.draft, 'Inspect this timetable');
    expect(h.current.draftReferences.single.toJson(), reference.toJson());
    expect(h.provider.requests, hasLength(1));
    await h.app.agent.updateComposerReferences(h.id, []);
    await h.app.agent.runtime.send(h.id, h.current.draft);
    expect(h.provider.requests, hasLength(2));
    expect(h.current.draft, isEmpty);
    expect(
      h.app.agent.runtime.state.value.runFor(h.id).phase,
      AgentUiPhase.idle,
    );
  });

  test('cancelling an expired queue head preserves later input until explicit Continue', () async {
    final h = await fixture();
    final reference = await h.resource();
    final initial = h.start();
    await h.provider.entered.future;
    await h.app.agent.updateComposerReferences(h.id, [reference]);
    await h.app.agent.runtime.queueFollowUp(h.id, 'Expired target');
    await h.app.agent.runtime.queueFollowUp(h.id, 'Later independent request');
    final head = h.queued.first;
    await h.removeResource(reference);
    h.provider.release();
    await initial;
    await h.waitUntil(
      () =>
          !h.app.agent.runtime.isRunning(h.id) &&
          h.app.agent.runtime.state.value.runFor(h.id).errorMessage ==
              'invalidReference',
    );
    await h.app.agent.runtime.cancelQueuedInput(h.id, head);
    expect(h.queued, hasLength(1));
    expect(h.provider.requests, hasLength(1));
    await h.app.agent.runtime.continueConversation(h.id);
    expect(h.queued, isEmpty);
    expect(h.provider.requests, hasLength(2));
    expect(
      h.provider.requests.last.messages
          .lastWhere((message) => message.role == ProviderRole.user)
          .text,
      'Later independent request',
    );
  });

  test('restoring queued input during an active run pauses later automatic consumption', () async {
    final h = await fixture();
    final initial = h.start();
    await h.provider.entered.future;
    await h.app.agent.runtime.queueFollowUp(h.id, 'Edit this queued request');
    await h.app.agent.runtime.queueFollowUp(h.id, 'Keep this later request');
    final first = h.queued.first;
    expect(h.app.agent.runtime.canManageQueuedInput(h.id, first.id), isTrue);
    await h.app.agent.runtime.restoreQueuedInput(h.id, first);
    expect(h.app.agent.runtime.isRunning(h.id), isTrue);
    expect(h.current.draft, 'Edit this queued request');
    h.provider.release();
    await initial;
    await h.app.agent.runtime.waitForIdle();
    expect(h.provider.requests, hasLength(1));
    expect(h.queued, hasLength(1));
    expect(h.current.draft, 'Edit this queued request');
  });

  for (final draftKind in ['text', 'reference', 'attachment']) {
    test(
      'restoring protects an existing $draftKind draft while cancel preserves it',
      () async {
        final h = await fixture();
        final reference = await h.resource();
        final initial = h.start();
        await h.provider.entered.future;
        await h.app.agent.runtime.queueFollowUp(h.id, 'Queued original');
        final queued = h.queued.single;
        final attachment = _attachment();
        await h.app.agent.conversations.update(
          h.id,
          (current) => current.copyWith(
            draft: draftKind == 'text' ? 'Keep my current draft' : '',
            draftReferences: draftKind == 'reference' ? [reference] : [],
            attachments: draftKind == 'attachment' ? [attachment] : [],
            draftAttachmentIds: draftKind == 'attachment'
                ? [attachment.id]
                : [],
          ),
        );
        final before = h.current;
        await expectLater(
          h.app.agent.runtime.restoreQueuedInput(h.id, queued),
          throwsA(_busy),
        );
        expect(h.queued.single.id, queued.id);
        expect(h.current.draft, before.draft);
        expect(
          h.current.draftReferences.map((item) => item.toJson()),
          before.draftReferences.map((item) => item.toJson()),
        );
        expect(h.current.draftAttachmentIds, before.draftAttachmentIds);
        expect(
          h.app.agent.runtime.canManageQueuedInput(h.id, queued.id),
          isTrue,
        );
        await h.app.agent.runtime.cancelQueuedInput(h.id, queued);
        expect(h.queued, isEmpty);
        expect(h.current.draft, before.draft);
        expect(
          h.current.draftReferences.map((item) => item.toJson()),
          before.draftReferences.map((item) => item.toJson()),
        );
        expect(h.current.draftAttachmentIds, before.draftAttachmentIds);
        h.provider.release();
        await initial;
      },
    );
  }

  test(
    'restored text references attachments and model choice survive reopening',
    () async {
      final h = await fixture();
      final reference = await h.resource();
      final file = _attachment();
      final initial = h.start();
      await h.provider.entered.future;
      await h.app.agent.conversations.update(
        h.id,
        (current) => current.copyWith(
          attachments: [file],
          draftAttachmentIds: [file.id],
        ),
      );
      await h.app.agent.updateComposerReferences(h.id, [
        reference,
        AgentComposerReference.attachment(
          attachment: file,
          conversationId: h.id,
        ),
      ]);
      await h.app.agent.runtime.queueFollowUp(
        h.id,
        'Original text and selections',
      );
      final queued = h.queued.single;
      await h.app.agent.runtime.restoreQueuedInput(h.id, queued);
      h.provider.release();
      await initial;
      await h.restart();
      expect(h.provider.requests, isEmpty);
      expect(h.queued, isEmpty);
      expect(h.current.draft, 'Original text and selections');
      expect(
        h.current.draftReferences.map((item) => item.toJson()),
        queued.contextReferences.map((item) => item.toJson()),
      );
      expect(h.current.draftAttachmentIds, queued.attachmentIds);
      expect(h.current.modelSelection, queued.modelSelection);
    },
  );

  test('management rejects stale snapshots and owner callbacks without retaining its lease', () async {
    final h = await fixture();
    final initial = h.start();
    await h.provider.entered.future;
    await h.app.agent.runtime.queueFollowUp(h.id, 'Original queued text');
    final previous = h.queued.single;
    await h.app.agent.conversations.update(
      h.id,
      (current) => current.copyWith(
        messages: current.messages.map(
          (message) => message.id == previous.id
              ? message.copyWith(
                  text: jsonEncode({
                    'kind': 'agent_pending_input',
                    'version': 1,
                    'mode': 'followUp',
                    'text': 'Changed queued text',
                  }),
                )
              : message,
        ),
      ),
    );
    await expectLater(
      h.app.agent.runtime.restoreQueuedInput(h.id, previous),
      throwsA(_busy),
    );
    final changed = h.queued.single;
    await expectLater(
      h.app.agent.runtime.cancelQueuedInput(
        h.id,
        changed,
        validate: () => throw StateError('Owner changed'),
      ),
      throwsStateError,
    );
    expect(h.app.agent.runtime.canManageQueuedInput(h.id, changed.id), isTrue);
    expect(h.queued.single.text, changed.text);
    await h.app.agent.runtime.cancelQueuedInput(h.id, changed);
    expect(h.queued, isEmpty);
    h.provider.release();
    await initial;
  });

  test(
    'Continue cannot consume the old queue while restoration is saving',
    () async {
      final h = await fixture();
      final initial = h.start();
      await h.provider.entered.future;
      await h.app.agent.runtime.queueFollowUp(h.id, 'Restore after Stop');
      await h.app.agent.runtime.stop(h.id);
      h.provider.release();
      await initial;
      final queued = h.queued.single;
      final entered = Completer<void>();
      final release = Completer<void>();
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      h.chats.beforeSave = () {
        if (!entered.isCompleted) entered.complete();
        return release.future;
      };
      final restoring = h.app.agent.runtime.restoreQueuedInput(h.id, queued);
      await entered.future;
      expect(
        h.app.agent.runtime.canManageQueuedInput(h.id, queued.id),
        isFalse,
      );
      await expectLater(
        h.app.agent.runtime.continueConversation(h.id),
        throwsA(_busy),
      );
      await expectLater(
        h.app.agent.runtime.send(h.id, 'Concurrent request'),
        throwsA(_busy),
      );
      var hostInvoked = false;
      await expectLater(
        h.app.agent.runtime.runHostAction(h.id, (_, _) async {
          hostInvoked = true;
          return {'status': 'completed'};
        }),
        throwsA(_busy),
      );
      expect(hostInvoked, isFalse);
      release.complete();
      await restoring;
      h.chats.beforeSave = null;
      expect(h.queued, isEmpty);
      expect(h.current.draft, 'Restore after Stop');
      expect(h.provider.requests, hasLength(1));
      await h.app.agent.runtime.send(h.id, h.current.draft);
      expect(h.provider.requests, hasLength(2));
    },
  );

  test('failed restoration retains the queued input and releases the management lease', () async {
    final h = await fixture();
    final initial = h.start();
    await h.provider.entered.future;
    await h.app.agent.runtime.queueFollowUp(h.id, 'Keep on failed save');
    await h.app.agent.runtime.stop(h.id);
    h.provider.release();
    await initial;
    final queued = h.queued.single;
    h.chats.fail = true;
    await expectLater(
      h.app.agent.runtime.restoreQueuedInput(h.id, queued),
      throwsStateError,
    );
    expect(h.current.draft, isEmpty);
    expect(h.queued.single.id, queued.id);
    h.chats.fail = false;
    await h.app.agent.conversations.load();
    expect(h.app.agent.runtime.canManageQueuedInput(h.id, queued.id), isTrue);
    await h.app.agent.runtime.restoreQueuedInput(h.id, h.queued.single);
    expect(h.current.draft, 'Keep on failed save');
    expect(h.queued, isEmpty);
    expect(h.provider.requests, hasLength(1));
  });

  test('a pending run admission protects every queue item from a stale history snapshot', () async {
    final h = await fixture();
    await h.app.agent.configure(
      h.app.agent.settings,
      credentialAction: AgentCredentialAction.replace,
      rawKey: 'synthetic-queued-input-key',
    );
    final initial = h.start();
    await h.provider.entered.future;
    await h.app.agent.runtime.queueFollowUp(h.id, 'First queued request');
    await h.app.agent.runtime.queueFollowUp(h.id, 'Later queued request');
    await h.app.agent.runtime.stop(h.id);
    h.provider.release();
    await initial;
    final pending = h.queued;
    final entered = Completer<void>();
    final release = Completer<void>();
    addTearDown(() {
      if (!release.isCompleted) release.complete();
    });
    h.credentials.beforeRead = () {
      if (!entered.isCompleted) entered.complete();
      return release.future;
    };
    final continuation = h.app.agent.runtime.continueConversation(h.id);
    await entered.future;
    expect(
      h.app.agent.runtime.canManageQueuedInput(h.id, pending.first.id),
      isFalse,
    );
    expect(
      h.app.agent.runtime.canManageQueuedInput(h.id, pending.last.id),
      isFalse,
    );
    await expectLater(
      h.app.agent.runtime.restoreQueuedInput(h.id, pending.first),
      throwsA(_busy),
    );
    await expectLater(
      h.app.agent.runtime.cancelQueuedInput(h.id, pending.last),
      throwsA(_busy),
    );
    release.complete();
    await continuation;
    h.credentials.beforeRead = null;
    expect(h.queued, isEmpty);
    expect(h.provider.requests, hasLength(3));
  });
}

Matcher get _busy => isA<AgentRuntimeException>().having(
  (error) => error.code,
  'code',
  AgentRuntimeError.busy,
);

ConversationAttachment _attachment() => ConversationAttachment(
  id: 'queued-file',
  name: 'queued.txt',
  mediaType: 'text/plain',
  byteLength: 1,
  digest: 'a' * 64,
);

ProviderResponse _done() => ProviderResponse(
  text: 'Completed',
  toolCalls: const [],
  finishReason: 'stop',
);

class _Provider extends ProviderClient {
  _Provider({this.blockFirst = true});
  final bool blockFirst;
  final entered = Completer<void>();
  final response = Completer<ProviderResponse>();
  final requests = <ProviderRequest>[];
  void release() {
    if (!response.isCompleted) response.complete(_done());
  }

  @override
  Stream<ProviderEvent> stream(
    ProviderRequest request, {
    required String apiKey,
    ProviderCancellationToken? cancellation,
  }) async* {
    requests.add(request);
    if (!entered.isCompleted) entered.complete();
    yield ProviderCompleted(
      blockFirst && requests.length == 1 ? await response.future : _done(),
    );
  }
}

class _Chats extends ConversationStorage {
  _Chats() : super.base();
  String? source;
  bool fail = false;
  Future<void> Function()? beforeSave;
  @override
  Future<ConversationStorageLoad> load() async =>
      ConversationStorageLoad(source: source);
  @override
  Future<void> save(String value, {required int revision}) async {
    await beforeSave?.call();
    if (fail) throw StateError('Synthetic chat save failure');
    source = value;
  }
}

class _Harness {
  _Harness(this.app, this.provider, this.chats, this.credentials, this.id);
  AppRuntime app;
  _Provider provider;
  final _Chats chats;
  final _Credentials credentials;
  final String id;
  AgentConversation get current => app.agent.conversations.find(id)!;
  List<ConversationMessage> get queued => current.executionMessages
      .where(
        (message) =>
            message.role == ConversationRole.notice &&
            jsonDecode(message.text) is Map &&
            (jsonDecode(message.text) as Map)['kind'] == 'agent_pending_input',
      )
      .toList();

  static Future<_Harness> create() async {
    final provider = _Provider();
    final chats = _Chats();
    final credentials = _Credentials();
    final app = await workspaceProvider(
      agentProvider: provider,
      agentConversationStorage: chats,
      agentCredentialStore: credentials,
    );
    await app.agent.configure(
      const AgentSettings(
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
    );
    await app.agent.setEnabled(true);
    final conversation = await app.agent.conversations.create(
      title: 'Queued inputs',
      mode: AgentPermissionMode.plan,
    );
    return _Harness(app, provider, chats, credentials, conversation.id);
  }

  Future<void> start() => app.agent.runtime.send(id, 'Initial request');
  Future<AgentComposerReference> resource() async =>
      (await (await app.agent.createReferenceSearch(id)).search(''))
          .group(AgentComposerReferenceGroup.timetable)
          .candidates
          .first
          .reference;
  Future<void> removeResource(AgentComposerReference reference) async {
    final data = app.session.committedData;
    final tables = data.studentMode.timetables
        .where((table) => table.id != reference.resourceRef!.id)
        .toList();
    final next = data.copyWith(
      studentMode: data.studentMode.copyWith(
        timetables: tables,
        activeTimetableId: tables.firstOrNull?.id ?? '',
      ),
    );
    app.session.replaceData(next);
    await app.session.persist(next);
  }

  Future<void> waitUntil(bool Function() predicate) async {
    final done = Completer<void>();
    void changed() {
      if (!done.isCompleted && predicate()) done.complete();
    }

    app.agent.runtime.state.addListener(changed);
    try {
      changed();
      await done.future.timeout(const Duration(seconds: 5));
    } finally {
      app.agent.runtime.state.removeListener(changed);
    }
  }

  Future<void> restart() async {
    final storage = WorkspaceMemoryStorage(app.session.committedData);
    await app.agent.quiesce();
    app.dispose();
    provider = _Provider(blockFirst: false);
    app = await workspaceProvider(
      storage: storage,
      agentProvider: provider,
      agentConversationStorage: chats,
      agentCredentialStore: credentials,
    );
    await app.agent.initialize();
  }

  Future<void> close() async {
    chats.beforeSave = null;
    chats.fail = false;
    credentials.beforeRead = null;
    provider.release();
    await app.agent.quiesce();
    app.dispose();
  }
}

class _Credentials extends MemoryAgentCredentialStore {
  Future<void> Function()? beforeRead;
  @override
  Future<String?> read(AgentCredentialSlot slot) async {
    await beforeRead?.call();
    return super.read(slot);
  }
}
