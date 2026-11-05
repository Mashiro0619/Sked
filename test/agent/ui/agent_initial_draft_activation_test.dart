import 'dart:async';
import 'dart:ui' show SemanticsAction, Tristate;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/ui/agent_conversation_view.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/models/agent_settings.dart';

import 'agent_ui_test_support.dart';

class _DraftStorage extends UiMemoryStorage {
  int loads = 0;
  int saves = 0;
  Completer<void>? _loadEntered;
  Completer<void>? _allowLoad;

  @override
  Future<ConversationStorageLoad> load() async {
    loads++;
    final allow = _allowLoad;
    if (allow != null) {
      if (_loadEntered?.isCompleted == false) _loadEntered!.complete();
      await allow.future;
    }
    return super.load();
  }

  @override
  Future<void> save(String value, {required int revision}) async {
    saves++;
    await super.save(value, revision: revision);
  }

  void pauseLoad() {
    expect(_allowLoad, isNull);
    _loadEntered = Completer<void>();
    _allowLoad = Completer<void>();
  }

  bool get loadEntered => _loadEntered?.isCompleted == true;

  void releaseLoad() {
    final allow = _allowLoad;
    _allowLoad = null;
    if (allow != null && !allow.isCompleted) allow.complete();
  }
}

class _DraftRepository extends ConversationRepository {
  _DraftRepository(_DraftStorage storage, String prefix)
    : super(
        storage: storage,
        clock: () => DateTime.utc(2026, 11, 5),
        idGenerator: () => '$prefix-draft',
      );

  int draftRequests = 0;
  int completedDraftRequests = 0;

  @override
  Future<AgentConversation> createDraft({
    required String title,
    AgentPermissionMode mode = AgentPermissionMode.ask,
    AgentModelSelection? modelSelection,
    String? id,
    void Function()? validate,
  }) {
    draftRequests++;
    return super
        .createDraft(
          title: title,
          mode: mode,
          modelSelection: modelSelection,
          id: id,
          validate: validate,
        )
        .whenComplete(() {
          completedDraftRequests++;
        });
  }
}

typedef _DraftOwner = ({_DraftStorage storage, _DraftRepository repository});

Future<_DraftOwner> _owner({String prefix = 'initial', String? source}) async {
  final storage = _DraftStorage()..source = source;
  final repository = _DraftRepository(storage, prefix);
  await repository.load();
  return (storage: storage, repository: repository);
}

String _savedSource() {
  final date = DateTime.utc(2026, 11, 5);
  final saved = AgentConversation(
    id: 'saved-conversation',
    title: '已有会话',
    createdAt: date,
    updatedAt: date,
    draft: '保留已有输入',
    messages: [
      ConversationMessage(
        id: 'saved-message',
        role: ConversationRole.user,
        text: '已保存的消息',
        createdAt: date,
      ),
    ],
  );
  return ConversationArchive(
    selectedId: saved.id,
    conversations: [saved],
  ).encode();
}

class _ActivationHost extends ChangeNotifier {
  _ActivationHost(
    this.repository, {
    required this.active,
    required this.interactive,
  }) : delegate = UiDelegate(repository);

  _DraftRepository repository;
  final UiDelegate delegate;
  bool active;
  bool interactive;

  void update({_DraftRepository? repository, bool? active, bool? interactive}) {
    this.repository = repository ?? this.repository;
    this.active = active ?? this.active;
    this.interactive = interactive ?? this.interactive;
    notifyListeners();
  }

  Widget build() => ListenableBuilder(
    listenable: this,
    builder: (_, _) => AgentConversationView(
      key: const ValueKey('initial-draft-view'),
      repository: repository,
      delegate: delegate,
      active: active,
      interactive: interactive,
      showTitle: true,
    ),
  );
}

Finder _key(String value) => find.byKey(ValueKey(value));

Future<void> _mount(
  WidgetTester tester,
  _ActivationHost host,
  List<_DraftOwner> owners,
) async {
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.runAsync(() async {
      for (final owner in owners) {
        owner.storage.releaseLoad();
      }
    });
    await _until(
      tester,
      () => owners.every(
        (owner) =>
            owner.repository.completedDraftRequests ==
            owner.repository.draftRequests,
      ),
      reason: 'Unmounted sources must finish every accepted draft callback.',
    );
    for (final owner in owners) {
      await _finishWithFrames(tester, owner.repository.waitForPendingWrites());
      owner.repository.dispose();
    }
    host.delegate.state.dispose();
    host.dispose();
    tester.view.reset();
  });
  // Every test starts unavailable, before introducing a pending storage gate.
  await mountAgentUi(tester, host.build());
}

Future<void> _frames(WidgetTester tester, [int count = 4]) async {
  for (var frame = 0; frame < count; frame++) {
    await tester.runAsync(() => Future<void>.microtask(() {}));
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _until(
  WidgetTester tester,
  bool Function() ready, {
  required String reason,
}) async {
  for (var frame = 0; frame < 120 && !ready(); frame++) {
    await _frames(tester, 1);
  }
  expect(ready(), isTrue, reason: reason);
}

Future<void> _finishWithFrames(
  WidgetTester tester,
  Future<void> operation,
) async {
  var completed = false;
  Object? failure;
  StackTrace? trace;
  unawaited(
    operation.then<void>(
      (_) => completed = true,
      onError: (Object error, StackTrace stack) {
        failure = error;
        trace = stack;
        completed = true;
      },
    ),
  );
  await _until(
    tester,
    () => completed,
    reason: 'The actual repository queue must complete while frames advance.',
  );
  if (failure != null) Error.throwWithStackTrace(failure!, trace!);
}

void _expectEmpty(_DraftOwner owner) {
  expect(owner.repository.selectedId, isNull);
  expect(owner.repository.selected, isNull);
  expect(owner.repository.draftConversation, isNull);
  expect(owner.repository.ownedConversations, isEmpty);
  expect(owner.repository.conversations, isEmpty);
  expect(owner.storage.saves, 0);
  expect(owner.storage.source, isNull);
}

Future<void> _expectDraft(WidgetTester tester, _DraftOwner owner) async {
  await _until(
    tester,
    () =>
        owner.repository.draftConversation != null &&
        owner.repository.completedDraftRequests ==
            owner.repository.draftRequests &&
        _key('agent-composer').hitTestable().evaluate().length == 1,
    reason:
        'The active empty owner must actually create a usable memory draft.',
  );
  await _finishWithFrames(tester, owner.repository.waitForPendingWrites());
  await _frames(tester, 1);
  final draft = owner.repository.draftConversation!;
  expect(owner.repository.selected, same(draft));
  expect(owner.repository.isDraft(owner.repository.selectedId), isTrue);
  expect(owner.repository.ownedConversations, [draft]);
  expect(owner.repository.conversations, isEmpty);
  expect(draft.messages, isEmpty);
  expect(draft.draft, isEmpty);
  expect(owner.storage.saves, 0);
  expect(owner.storage.source, isNull);
  final composer = tester.widget<TextField>(_key('agent-composer'));
  expect(composer.enabled, isTrue);
  expect(composer.readOnly, isFalse);
  expect(composer.focusNode!.hasFocus, isFalse);
  final data = tester
      .getSemantics(
        find.descendant(
          of: _key('agent-composer'),
          matching: find.byType(EditableText),
        ),
      )
      .getSemanticsData();
  expect(data.flagsCollection.isTextField, isTrue);
  expect(data.flagsCollection.isMultiline, isTrue);
  expect(data.hasAction(SemanticsAction.focus), isTrue);
  expect(data.hasAction(SemanticsAction.tap), isTrue);
  expect(data.flagsCollection.isEnabled, Tristate.isTrue);
}

Future<void> _queueDraftBehindLoad(
  WidgetTester tester,
  _ActivationHost host,
  _DraftOwner owner,
) async {
  await tester.runAsync(() async {
    owner.storage.pauseLoad();
    unawaited(owner.repository.load());
  });
  await _until(
    tester,
    () => owner.storage.loadEntered,
    reason: 'The actual repository write queue must be paused in storage load.',
  );
  host.update(active: true, interactive: true);
  await tester.pump();
  await _until(
    tester,
    () => owner.repository.draftRequests == 1,
    reason: 'Initial creation must be enqueued behind the actual paused load.',
  );
  expect(owner.repository.completedDraftRequests, 0);
  _expectEmpty(owner);
}

Future<void> _releaseLoad(WidgetTester tester, _DraftOwner owner) async {
  await tester.runAsync(() async {
    owner.storage.releaseLoad();
  });
  await _until(
    tester,
    () => owner.repository.completedDraftRequests >= 1,
    reason: 'The old queued draft must actually finish after load is released.',
  );
  await _finishWithFrames(tester, owner.repository.waitForPendingWrites());
  await _frames(tester, 1);
}

void main() {
  for (final initial in [
    (
      name: 'interactive activation creates the first memory draft',
      active: true,
      interactive: false,
      interactionFirst: false,
    ),
    (
      name: 'active activation creates the first memory draft',
      active: false,
      interactive: true,
      interactionFirst: false,
    ),
    (
      name: 'both availability gates open with activity first',
      active: false,
      interactive: false,
      interactionFirst: false,
    ),
    (
      name: 'both availability gates open with interaction first',
      active: false,
      interactive: false,
      interactionFirst: true,
    ),
  ]) {
    testWidgets(initial.name, (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final owner = (await tester.runAsync(() => _owner()))!;
        final host = _ActivationHost(
          owner.repository,
          active: initial.active,
          interactive: initial.interactive,
        );
        await _mount(tester, host, [owner]);
        final state = tester.state(_key('initial-draft-view'));
        _expectEmpty(owner);
        expect(owner.repository.draftRequests, 0);
        expect(_key('agent-composer'), findsNothing);

        if (!initial.active && !initial.interactive) {
          host.update(
            active: initial.interactionFirst ? null : true,
            interactive: initial.interactionFirst ? true : null,
          );
          await _frames(tester);
          _expectEmpty(owner);
          expect(owner.repository.draftRequests, 0);
          expect(_key('agent-composer'), findsNothing);
        }

        host.update(active: true, interactive: true);
        await tester.pump();
        await _expectDraft(tester, owner);
        expect(owner.repository.draftRequests, 1);
        expect(owner.storage.loads, 1);
        expect(host.delegate.calls, isEmpty);
        expect(tester.state(_key('initial-draft-view')), same(state));
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  }

  for (final hideActive in [true, false]) {
    for (final reactivateBeforeCompletion in [false, true]) {
      testWidgets(
        'initial draft resumes after ${hideActive ? 'activity' : 'interaction'} returns ${reactivateBeforeCompletion ? 'before' : 'after'} the old task completes',
        (tester) async {
          final semantics = tester.ensureSemantics();
          try {
            final owner = (await tester.runAsync(() => _owner()))!;
            final host = _ActivationHost(
              owner.repository,
              active: false,
              interactive: false,
            );
            await _mount(tester, host, [owner]);
            final state = tester.state(_key('initial-draft-view'));
            await _queueDraftBehindLoad(tester, host, owner);

            host.update(
              active: hideActive ? false : null,
              interactive: hideActive ? null : false,
            );
            await tester.pump();
            _expectEmpty(owner);
            if (reactivateBeforeCompletion) {
              host.update(active: true, interactive: true);
              await _frames(tester);
              expect(owner.repository.draftRequests, 1);
              _expectEmpty(owner);
            }

            await _releaseLoad(tester, owner);
            if (!reactivateBeforeCompletion) {
              await _frames(tester);
              _expectEmpty(owner);
              expect(owner.repository.draftRequests, 1);
              expect(_key('agent-composer'), findsNothing);
              host.update(active: true, interactive: true);
              await tester.pump();
            }

            await _expectDraft(tester, owner);
            expect(owner.repository.draftRequests, 2);
            expect(owner.storage.loads, 2);
            expect(host.delegate.calls, isEmpty);
            expect(tester.state(_key('initial-draft-view')), same(state));
            expect(tester.takeException(), isNull);
          } finally {
            semantics.dispose();
          }
        },
        variant: TargetPlatformVariant.only(TargetPlatform.windows),
      );
    }
  }

  for (final returnToFirst in [false, true]) {
    testWidgets(
      'queued initial draft follows ${returnToFirst ? 'A to B to A' : 'A to B'} with the same view and delegate',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          final owners = (await tester.runAsync(
            () async => [
              await _owner(prefix: 'first'),
              await _owner(prefix: 'second'),
            ],
          ))!;
          final first = owners[0];
          final second = owners[1];
          final host = _ActivationHost(
            first.repository,
            active: false,
            interactive: false,
          );
          await _mount(tester, host, owners);
          final state = tester.state(_key('initial-draft-view'));
          final delegate = host.delegate;
          await _queueDraftBehindLoad(tester, host, first);

          host.update(repository: second.repository);
          await _frames(tester);
          _expectEmpty(first);
          _expectEmpty(second);
          expect(first.repository.draftRequests, 1);
          expect(second.repository.draftRequests, 0);
          if (returnToFirst) {
            host.update(repository: first.repository);
            await _frames(tester);
            _expectEmpty(first);
            _expectEmpty(second);
          }

          await _releaseLoad(tester, first);
          final current = returnToFirst ? first : second;
          final old = returnToFirst ? second : first;
          await _expectDraft(tester, current);
          _expectEmpty(old);
          expect(first.repository.draftRequests, returnToFirst ? 2 : 1);
          expect(second.repository.draftRequests, returnToFirst ? 0 : 1);
          expect(first.storage.loads, 2);
          expect(second.storage.loads, 1);
          expect(host.delegate, same(delegate));
          expect(
            tester
                .widget<AgentConversationView>(_key('initial-draft-view'))
                .delegate,
            same(delegate),
          );
          expect(tester.state(_key('initial-draft-view')), same(state));
          expect(host.delegate.calls, isEmpty);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }

  testWidgets(
    'reactivation preserves the selected durable conversation without creating or saving a draft',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final owner = (await tester.runAsync(
          () => _owner(source: _savedSource()),
        ))!;
        final host = _ActivationHost(
          owner.repository,
          active: false,
          interactive: false,
        );
        await _mount(tester, host, [owner]);
        final source = owner.storage.source;
        final selected = owner.repository.selected;
        final state = tester.state(_key('initial-draft-view'));
        host.update(active: true);
        await _frames(tester);
        host.update(interactive: true);
        await _frames(tester);
        await _finishWithFrames(
          tester,
          owner.repository.waitForPendingWrites(),
        );

        expect(owner.repository.selected, same(selected));
        expect(owner.repository.selectedId, 'saved-conversation');
        expect(owner.repository.draftConversation, isNull);
        expect(owner.repository.draftRequests, 0);
        expect(owner.repository.conversations, hasLength(1));
        expect(owner.storage.loads, 1);
        expect(owner.storage.saves, 0);
        expect(owner.storage.source, source);
        expect(_key('agent-composer').hitTestable(), findsOneWidget);
        final composer = tester.widget<TextField>(_key('agent-composer'));
        expect(composer.enabled, isTrue);
        expect(composer.controller!.text, '保留已有输入');
        expect(host.delegate.calls, isEmpty);
        expect(tester.state(_key('initial-draft-view')), same(state));
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'queued initial draft preserves the conversation selected by actual storage recovery',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final owner = (await tester.runAsync(() => _owner()))!;
        final host = _ActivationHost(
          owner.repository,
          active: false,
          interactive: false,
        );
        await _mount(tester, host, [owner]);
        final state = tester.state(_key('initial-draft-view'));
        await _queueDraftBehindLoad(tester, host, owner);
        final source = _savedSource();
        await tester.runAsync(() async {
          owner.storage.source = source;
        });
        await _releaseLoad(tester, owner);
        await _until(
          tester,
          () =>
              owner.repository.selectedId == 'saved-conversation' &&
              _key('agent-composer').hitTestable().evaluate().length == 1,
          reason:
              'The recovered durable selection must become the usable input.',
        );

        expect(owner.repository.draftRequests, 1);
        expect(owner.repository.completedDraftRequests, 1);
        expect(owner.repository.draftConversation, isNull);
        expect(owner.repository.conversations, hasLength(1));
        expect(owner.repository.ownedConversations, hasLength(1));
        expect(owner.repository.selected!.draft, '保留已有输入');
        expect(owner.storage.loads, 2);
        expect(owner.storage.saves, 0);
        expect(owner.storage.source, source);
        expect(
          tester.widget<TextField>(_key('agent-composer')).controller!.text,
          '保留已有输入',
        );
        expect(host.delegate.calls, isEmpty);
        expect(tester.state(_key('initial-draft-view')), same(state));
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
