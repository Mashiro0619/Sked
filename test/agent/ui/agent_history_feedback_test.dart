import 'dart:async';

import 'package:flutter/semantics.dart' show SemanticsNode, SemanticsOwner;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/ui/agent_conversation_list.dart';
import 'package:sked/agent/ui/agent_conversation_view.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/agent_settings.dart';
import 'package:sked/screens/agent_page.dart';
import 'package:sked/widgets/workspace_frame.dart';
import 'package:sked/widgets/workspace_navigation.dart';

import '../../support/workspace_harness.dart';
import 'agent_ui_test_support.dart';

const _currentId = 'feedback-current';
const _firstArchivedId = 'feedback-archived-first';
const _secondArchivedId = 'feedback-archived-second';
const _restoreCall = 'archive:$_firstArchivedId:false';

class _HistoryFixture {
  _HistoryFixture._(this.storage, this.repository)
    : delegate = UiDelegate(repository);

  final UiMemoryStorage storage;
  final ConversationRepository repository;
  final UiDelegate delegate;
  int recoverCalls = 0;
  Completer<void>? _saveEntered;
  Completer<void>? _allowSave;

  static Future<_HistoryFixture> create({String prefix = '原宿主'}) async {
    final storage = UiMemoryStorage();
    var tick = 0;
    final repository = ConversationRepository(
      storage: storage,
      clock: () => DateTime.utc(2026, 11, 5).add(Duration(seconds: tick++)),
    );
    final fixture = _HistoryFixture._(storage, repository);
    await repository.load();
    for (final entry in const <String, String>{
      _currentId: '当前会话',
      _firstArchivedId: '第一条归档',
      _secondArchivedId: '第二条归档',
    }.entries) {
      await repository.create(id: entry.key, title: '$prefix ${entry.value}');
      await repository.update(
        entry.key,
        (conversation) => conversation.copyWith(
          archived: entry.key != _currentId,
          messages: [
            ConversationMessage(
              id: '${entry.key}-answer',
              role: ConversationRole.assistant,
              text: '$prefix 的合成回复',
              createdAt: DateTime.utc(2026, 11, 5),
            ),
          ],
        ),
      );
    }
    await repository.select(_currentId);
    return fixture;
  }

  Future<void> recover() async {
    recoverCalls++;
    await repository.load();
  }

  AgentConversation stored(String id) =>
      ConversationArchive.decode(storage.source!).conversations
          .singleWhere((conversation) => conversation.id == id);

  void pauseSave({required bool fail}) {
    expect(_allowSave, isNull);
    final entered = _saveEntered = Completer<void>();
    final allow = _allowSave = Completer<void>();
    storage.fail = fail;
    storage.beforeSave = () async {
      if (!entered.isCompleted) entered.complete();
      await allow.future;
    };
  }

  bool get saveEntered => _saveEntered?.isCompleted == true;

  void releaseSave() {
    storage.beforeSave = null;
    final allow = _allowSave;
    _allowSave = null;
    if (allow != null && !allow.isCompleted) allow.complete();
  }

  Future<void> dispose() async {
    releaseSave();
    await repository.waitForPendingWrites();
    repository.dispose();
    delegate.state.dispose();
  }
}

abstract interface class _HistoryDrawerHost {
  bool get embedded;
}

class _HistoryFeedbackHost extends ChangeNotifier
    implements _HistoryDrawerHost {
  _HistoryFeedbackHost(this.owner, {required this.embedded}) : owners = [owner];

  _HistoryFixture owner;
  @override
  final bool embedded;
  final List<_HistoryFixture> owners;
  final controller = WorkspacePaneController();
  bool active = true;
  bool interactive = true;

  void update({_HistoryFixture? owner, bool? active, bool? interactive}) {
    if (owner != null) {
      this.owner = owner;
      if (!owners.contains(owner)) owners.add(owner);
    }
    this.active = active ?? this.active;
    this.interactive = interactive ?? this.interactive;
    notifyListeners();
  }

  Widget build() => ListenableBuilder(
    listenable: this,
    builder: (context, _) => AgentConversationView(
      key: const ValueKey('feedback-conversation-view'),
      repository: owner.repository,
      delegate: owner.delegate,
      fullWorkspace: true,
      embedded: embedded,
      active: active,
      interactive: interactive,
      recoverConversations: owner.recover,
      workspaceLayoutBuilder: embedded
          ? (_, canvas, history) => WorkspaceFrame(
              controller: controller,
              canvas: canvas,
              resources: Builder(
                builder: (context) {
                  final resources = WorkspaceResourceScope.maybeOf(context);
                  return WorkspaceResourcePanel(
                    title: AppLocalizations.of(context).agentConversations,
                    resourceIcon: Icons.history,
                    contentBuilder: history,
                    onOpenResources:
                        resources?.canExpandInline == false &&
                            resources?.drawerOpen != true
                        ? resources?.open
                        : null,
                    children: const [],
                  );
                },
              ),
              active: active && interactive,
              resourcesCollapsed: true,
              assistantPreview: false,
            )
          : null,
    ),
  );

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

class _RealRecoveryStorage extends UiMemoryStorage {
  int loadCalls = 0;
  int saveCalls = 0;
  Completer<void>? _loadEntered;
  Completer<void>? _allowLoad;
  Completer<void>? _saveEntered;
  Completer<void>? _allowSave;

  @override
  Future<ConversationStorageLoad> load() async {
    loadCalls++;
    final allow = _allowLoad;
    if (allow != null) {
      if (_loadEntered?.isCompleted == false) _loadEntered!.complete();
      await allow.future;
    }
    return super.load();
  }

  @override
  Future<void> save(String value, {required int revision}) async {
    saveCalls++;
    await super.save(value, revision: revision);
  }

  void pauseRecovery() {
    expect(_allowLoad, isNull);
    expect(_allowSave, isNull);
    _loadEntered = Completer<void>();
    _allowLoad = Completer<void>();
    final entered = _saveEntered = Completer<void>();
    final allow = _allowSave = Completer<void>();
    beforeSave = () async {
      if (!entered.isCompleted) entered.complete();
      await allow.future;
    };
  }

  bool get loadEntered => _loadEntered?.isCompleted == true;
  bool get saveEntered => _saveEntered?.isCompleted == true;

  void releaseLoad() {
    final allow = _allowLoad;
    _allowLoad = null;
    if (allow != null && !allow.isCompleted) allow.complete();
  }

  void releaseSave() {
    beforeSave = null;
    final allow = _allowSave;
    _allowSave = null;
    if (allow != null && !allow.isCompleted) allow.complete();
  }
}

class _RealRecoveryFixture {
  const _RealRecoveryFixture(this.app, this.storage);

  final AppRuntime app;
  final _RealRecoveryStorage storage;

  ConversationRepository get repository => app.agent.conversations;
  ConversationArchive get archive =>
      ConversationArchive.decode(storage.source!);

  static Future<_RealRecoveryFixture> create() async {
    final seed = await _HistoryFixture.create();
    final storage = _RealRecoveryStorage()..source = seed.storage.source;
    await seed.dispose();
    final app = await workspaceProvider(
      locale: 'zh',
      agentConversationStorage: storage,
    );
    final fixture = _RealRecoveryFixture(app, storage);
    try {
      await app.agent.configure(
        const AgentSettings(
          enabled: true,
          endpoint: 'https://history-feedback.example.invalid/v1',
          model: 'feedback-model',
          historyRetentionDays: 0,
          models: [
            AgentModelConfig(
              id: 'feedback-model',
              reasoningEfforts: [AgentReasoningEffort.medium],
              defaultReasoningEffort: AgentReasoningEffort.medium,
            ),
          ],
        ),
      );
      return fixture;
    } catch (_) {
      await fixture.dispose();
      rethrow;
    }
  }

  Future<void> dispose() async {
    storage.releaseLoad();
    storage.releaseSave();
    try {
      await app.persistence.flushPendingUiStateSaves();
      await app.shutdown.quiesce();
    } finally {
      app.dispose();
      await app.session.close();
    }
  }
}

class _RealRecoveryHost extends ChangeNotifier implements _HistoryDrawerHost {
  _RealRecoveryHost(this.owner, {required this.embedded});

  final _RealRecoveryFixture owner;
  @override
  final bool embedded;
  bool active = true;

  void update({required bool active}) {
    this.active = active;
    notifyListeners();
  }

  Widget build() => ListenableBuilder(
    listenable: this,
    builder: (context, _) => AgentPage(
      key: const ValueKey('real-recovery-agent-page'),
      embedded: embedded,
      active: active,
      interactive: active,
    ),
  );
}

Finder _key(String value) => find.byKey(ValueKey(value));

class _RepositoryFeedbackHost extends ChangeNotifier {
  _RepositoryFeedbackHost(this.repository, this.delegate);

  ConversationRepository repository;
  final UiDelegate delegate;

  void replaceRepository(ConversationRepository repository) {
    this.repository = repository;
    notifyListeners();
  }

  Widget build() => ListenableBuilder(
    listenable: this,
    builder: (context, _) => AgentConversationView(
      key: const ValueKey('frozen-source-conversation-view'),
      repository: repository,
      delegate: delegate,
      fullWorkspace: true,
    ),
  );
}

Future<({ConversationRepository repository, _RealRecoveryStorage storage})>
_frozenRepository() async {
  final storage = _RealRecoveryStorage();
  final repository = ConversationRepository(
    storage: storage,
    clock: () => DateTime.utc(2026, 11, 5),
  );
  await repository.load();
  repository.freeze();
  return (repository: repository, storage: storage);
}

bool _semanticsContainsLabel(SemanticsOwner owner, String label) {
  final root = owner.rootSemanticsNode;
  if (root == null) return false;
  var found = false;
  final visited = <int>{};
  void visit(SemanticsNode node) {
    if (!visited.add(node.id)) return;
    if (node.getSemanticsData().label.contains(label)) found = true;
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(root);
  return found;
}

Future<({FocusNode focus, SemanticsOwner semanticsOwner, String restoreLabel})>
_focusHistoryDuringSave(WidgetTester tester, _HistoryFixture owner) async {
  await tester.runAsync(() async {
    owner.pauseSave(fail: false);
  });
  await _tap(tester, _inHistory('agent-restore-$_firstArchivedId'));
  await _until(
    tester,
    () => owner.saveEntered,
    reason: 'The archive save must be accepted before retiring its history.',
  );
  await _tap(tester, _inHistory('agent-history-search-toggle'));
  await _until(
    tester,
    () => _inHistory('agent-history-search').evaluate().length == 1,
    reason: 'History search must be rendered while its save remains pending.',
  );
  final search = _inHistory('agent-history-search');
  final focus = tester.widget<TextField>(search).focusNode!;
  await tester.enterText(search, '原宿主');
  await _until(
    tester,
    () => focus.hasFocus,
    reason: 'The old history must own real input focus before retirement.',
  );
  await tester.pump();
  final semanticsOwner = tester
      .renderObject(_visibleHistory())
      .owner!
      .semanticsOwner!;
  final label = AppLocalizations.of(tester.element(_visibleHistory()))
      .agentRestoreConversation;
  expect(
    _semanticsContainsLabel(semanticsOwner, label),
    isTrue,
    reason:
        'Current history semantics: ${semanticsOwner.rootSemanticsNode?.toStringDeep()}',
  );
  expect(owner.repository.find(_firstArchivedId)!.archived, isTrue);
  expect(
    tester
        .widget<IconButton>(_inHistory('agent-restore-$_firstArchivedId'))
        .onPressed,
    isNull,
  );
  return (focus: focus, semanticsOwner: semanticsOwner, restoreLabel: label);
}

Finder _visibleHistory() => find.byType(AgentConversationList).hitTestable();

Finder _inHistory(String value) =>
    find.descendant(of: _visibleHistory(), matching: _key(value));

Future<void> _until(
  WidgetTester tester,
  bool Function() ready, {
  required String reason,
}) async {
  for (var frame = 0; frame < 180 && !ready(); frame++) {
    await tester.runAsync(() => Future<void>.microtask(() {}));
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(ready(), isTrue, reason: reason);
}

// Pending persistence must not be awaited through pumpAndSettle: a current
// restore is allowed to animate its busy state until the real save completes.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  if (finder.hitTestable().evaluate().isEmpty) {
    await tester.ensureVisible(finder);
    await tester.pump();
  }
  expect(finder.hitTestable(), findsOneWidget);
  await tester.runAsync(() => tester.tap(finder.hitTestable()));
  await tester.pump();
}

Future<void> _mount(WidgetTester tester, _HistoryFeedbackHost host) async {
  final app = (await tester.runAsync(() => workspaceProvider(locale: 'zh')))!;
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(620, 820);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.runAsync(() async {
      for (final owner in host.owners) {
        await owner.dispose();
      }
      try {
        await app.shutdown.quiesce();
      } finally {
        app.dispose();
        await app.session.close();
      }
    });
    host.dispose();
    tester.view.reset();
  });
  await tester.pumpWidget(
    WorkspaceHarness(
      provider: app,
      home: host.build(),
      locale: const Locale('zh'),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openHistory(
  WidgetTester tester,
  _HistoryDrawerHost host, {
  String expectedArchivedId = _firstArchivedId,
}) async {
  if (_visibleHistory().evaluate().isEmpty) {
    final trigger =
        host.embedded && _key('workspace-main-navigation').evaluate().isEmpty
        ? _key('workspace-resource-open')
        : _key(host.embedded ? 'workspace-main-navigation' : 'agent-history');
    await _tap(tester, trigger);
  }
  await _until(
    tester,
    () => _visibleHistory().evaluate().length == 1,
    reason: 'The current history drawer must be visible.',
  );
  if (_inHistory('agent-history-$expectedArchivedId').evaluate().isEmpty) {
    await _tap(tester, _inHistory('agent-history-more'));
    await _until(
      tester,
      () => _key('agent-history-archived').hitTestable().evaluate().length == 1,
      reason: 'The current More menu must offer the archive filter.',
    );
    final menuRoute = ModalRoute.of(
      tester.element(_key('agent-history-archived')),
    )!;
    var menuCompleted = false;
    unawaited(menuRoute.completed.then((_) => menuCompleted = true));
    await _tap(tester, _key('agent-history-archived'));
    await _until(
      tester,
      () => menuCompleted && !menuRoute.isActive,
      reason: 'The archive menu must retire its overlay before using history.',
    );
  }
  await _until(
    tester,
    () =>
        _inHistory('agent-history-$expectedArchivedId')
            .hitTestable()
            .evaluate()
            .length ==
        1,
    reason:
        'The requested archived conversation must be in the current drawer.',
  );
}

Future<void> _closeHistory(WidgetTester tester, _HistoryDrawerHost host) async {
  if (host.embedded) {
    await tester.runAsync(tester.binding.handlePopRoute);
    await tester.pump();
  } else {
    await _tap(tester, _inHistory('agent-history-close'));
  }
  await _until(
    tester,
    () => _visibleHistory().evaluate().isEmpty,
    reason: 'Closing history must retire its interactive drawer.',
  );
}

Future<void> _mountRealRecovery(
  WidgetTester tester,
  _RealRecoveryHost host,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(620, 820);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    try {
      await tester.runAsync(host.owner.dispose);
    } finally {
      host.dispose();
      tester.view.reset();
    }
  });
  await tester.pumpWidget(
    WorkspaceHarness(
      provider: host.owner.app,
      home: host.build(),
      locale: const Locale('zh'),
    ),
  );
  await tester.pumpAndSettle();
  expect(host.owner.app.agent.isInitialized, isTrue);
  expect(host.owner.app.agent.runtime.state.value.enabled, isTrue);
  expect(host.owner.repository.selectedId, _currentId);
  expect(find.byType(AgentConversationHost), findsOneWidget);
}

Future<void> _failRealRestore(
  WidgetTester tester,
  _RealRecoveryFixture owner,
) async {
  final saved = owner.storage.source;
  owner.storage.fail = true;
  await _tap(tester, _inHistory('agent-restore-$_firstArchivedId'));
  await tester.runAsync(owner.repository.waitForPendingWrites);
  await _until(
    tester,
    () =>
        owner.repository.blocked &&
        _inHistory('agent-history-error').hitTestable().evaluate().length == 1,
    reason: 'The real runtime restore must expose its failed save in history.',
  );
  await tester.pumpAndSettle();
  _expectSafeHistoryError(tester);
  expect(owner.storage.source, saved);
  expect(owner.repository.find(_firstArchivedId)!.archived, isTrue);
  owner.storage.fail = false;
}

void _expectSafeHistoryError(WidgetTester tester) {
  expect(_visibleHistory(), findsOneWidget);
  expect(_inHistory('agent-history-error').hitTestable(), findsOneWidget);
  final l = AppLocalizations.of(tester.element(_visibleHistory()));
  expect(
    find.descendant(
      of: _visibleHistory(),
      matching: find.text(l.agentOperationFailed),
    ),
    findsOneWidget,
  );
  expect(
    find.descendant(
      of: _visibleHistory(),
      matching: find.textContaining('raw-secret-must-not-be-shown'),
    ),
    findsNothing,
  );
}

void _expectNoHistoryError(WidgetTester tester) {
  expect(_visibleHistory(), findsOneWidget);
  expect(_inHistory('agent-history-error'), findsNothing);
  final l = AppLocalizations.of(tester.element(_visibleHistory()));
  expect(
    find.descendant(
      of: _visibleHistory(),
      matching: find.text(l.agentOperationFailed),
    ),
    findsNothing,
  );
}

void main() {
  for (final embedded in [false, true]) {
    group(embedded ? 'embedded resource history' : 'standalone history drawer', () {
      testWidgets(
        'failed restore stays visible and retries through real storage recovery',
        (tester) async {
          final owner = (await tester.runAsync(_HistoryFixture.create))!;
          final host = _HistoryFeedbackHost(owner, embedded: embedded);
          await _mount(tester, host);
          await _openHistory(tester, host);
          final saved = owner.storage.source;

          owner.storage.fail = true;
          await _tap(tester, _inHistory('agent-restore-$_firstArchivedId'));
          await tester.runAsync(owner.repository.waitForPendingWrites);
          await tester.pumpAndSettle();

          _expectSafeHistoryError(tester);
          expect(owner.repository.blocked, isTrue);
          expect(owner.repository.find(_firstArchivedId)!.archived, isTrue);
          expect(owner.storage.source, saved);
          expect(owner.stored(_firstArchivedId).archived, isTrue);
          expect(owner.delegate.calls, [_restoreCall]);
          expect(owner.recoverCalls, 0);
          expect(
            tester
                .widget<IconButton>(
                  _inHistory('agent-restore-$_firstArchivedId'),
                )
                .onPressed,
            isNotNull,
          );

          owner.storage.fail = false;
          await _tap(tester, _inHistory('agent-restore-$_firstArchivedId'));
          await tester.runAsync(owner.repository.waitForPendingWrites);
          await tester.pumpAndSettle();

          expect(owner.recoverCalls, 1);
          expect(owner.delegate.calls, [_restoreCall, _restoreCall]);
          expect(owner.repository.blocked, isFalse);
          expect(owner.repository.find(_firstArchivedId)!.archived, isFalse);
          expect(owner.stored(_firstArchivedId).archived, isFalse);
          expect(_inHistory('agent-history-$_firstArchivedId'), findsNothing);
          expect(
            _inHistory('agent-history-$_secondArchivedId'),
            findsOneWidget,
          );
          _expectNoHistoryError(tester);
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.windows),
      );

      testWidgets(
        'late restore failure cannot contaminate history after hiding and re-entry',
        (tester) async {
          final owner = (await tester.runAsync(_HistoryFixture.create))!;
          final host = _HistoryFeedbackHost(owner, embedded: embedded);
          await _mount(tester, host);
          await _openHistory(tester, host);
          final saved = owner.storage.source;

          await tester.runAsync(() async {
            owner.pauseSave(fail: true);
          });
          await _tap(tester, _inHistory('agent-restore-$_firstArchivedId'));
          await _until(
            tester,
            () => owner.saveEntered,
            reason:
                'Restore must reach the real save before its host is hidden.',
          );
          expect(owner.delegate.calls, [_restoreCall]);
          expect(owner.storage.source, saved);
          expect(
            tester
                .widget<IconButton>(
                  _inHistory('agent-restore-$_firstArchivedId'),
                )
                .onPressed,
            isNull,
          );

          await _closeHistory(tester, host);
          host.update(active: false);
          await tester.pump();
          host.update(active: true);
          await tester.pump();
          await _openHistory(tester, host);
          _expectNoHistoryError(tester);

          await tester.runAsync(() async {
            owner.releaseSave();
            await owner.repository.waitForPendingWrites();
          });
          await tester.pumpAndSettle();

          expect(owner.repository.blocked, isTrue);
          expect(owner.storage.source, saved);
          expect(owner.stored(_firstArchivedId).archived, isTrue);
          expect(owner.delegate.calls, [_restoreCall]);
          expect(owner.recoverCalls, 0);
          expect(_inHistory('agent-history-$_firstArchivedId'), findsOneWidget);
          _expectNoHistoryError(tester);
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.windows),
      );

      testWidgets(
        'late restore failure is isolated from a new archive with the same IDs',
        (tester) async {
          final oldOwner = (await tester.runAsync(_HistoryFixture.create))!;
          final host = _HistoryFeedbackHost(oldOwner, embedded: embedded);
          await _mount(tester, host);
          await _openHistory(tester, host);
          final oldSaved = oldOwner.storage.source;

          await tester.runAsync(() async {
            oldOwner.pauseSave(fail: true);
          });
          await _tap(tester, _inHistory('agent-restore-$_firstArchivedId'));
          await _until(
            tester,
            () => oldOwner.saveEntered,
            reason: 'The old archive must own an accepted pending save.',
          );
          await _closeHistory(tester, host);

          // Selecting within the paused repository would queue behind its save.
          // Replace the real archive instead, deliberately reusing all IDs.
          final nextOwner = (await tester.runAsync(
            () => _HistoryFixture.create(prefix: '新宿主'),
          ))!;
          host.update(owner: nextOwner);
          await tester.pump();
          await _openHistory(tester, host);
          final nextSaved = nextOwner.storage.source;
          _expectNoHistoryError(tester);

          await tester.runAsync(() async {
            oldOwner.releaseSave();
            await oldOwner.repository.waitForPendingWrites();
          });
          await tester.pumpAndSettle();

          expect(oldOwner.repository.blocked, isTrue);
          expect(oldOwner.storage.source, oldSaved);
          expect(oldOwner.delegate.calls, [_restoreCall]);
          expect(oldOwner.recoverCalls, 0);
          expect(nextOwner.repository.blocked, isFalse);
          expect(nextOwner.repository.selectedId, _currentId);
          expect(nextOwner.storage.source, nextSaved);
          expect(nextOwner.stored(_firstArchivedId).archived, isTrue);
          expect(nextOwner.delegate.calls, isEmpty);
          expect(nextOwner.recoverCalls, 0);
          expect(
            find.descendant(
              of: _inHistory('agent-history-$_firstArchivedId'),
              matching: find.text('新宿主 第一条归档'),
            ),
            findsOneWidget,
          );
          _expectNoHistoryError(tester);
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.windows),
      );

      testWidgets(
        'accepted restore persists after its history host becomes noninteractive',
        (tester) async {
          final owner = (await tester.runAsync(_HistoryFixture.create))!;
          final host = _HistoryFeedbackHost(owner, embedded: embedded);
          await _mount(tester, host);
          await _openHistory(tester, host);

          await tester.runAsync(() async {
            owner.pauseSave(fail: false);
          });
          await _tap(tester, _inHistory('agent-restore-$_firstArchivedId'));
          await _until(
            tester,
            () => owner.saveEntered,
            reason: 'The persistent restore must be accepted before hiding.',
          );
          await _closeHistory(tester, host);
          host.update(interactive: false);
          await tester.pump();

          await tester.runAsync(() async {
            owner.releaseSave();
            await owner.repository.waitForPendingWrites();
          });
          await tester.pump();

          expect(owner.repository.blocked, isFalse);
          expect(owner.repository.find(_firstArchivedId)!.archived, isFalse);
          expect(owner.stored(_firstArchivedId).archived, isFalse);
          expect(owner.delegate.calls, [_restoreCall]);
          expect(owner.recoverCalls, 0);

          host.update(interactive: true);
          await tester.pumpAndSettle();
          await _openHistory(
            tester,
            host,
            expectedArchivedId: _secondArchivedId,
          );
          expect(_inHistory('agent-history-$_firstArchivedId'), findsNothing);
          expect(
            _inHistory('agent-history-$_secondArchivedId'),
            findsOneWidget,
          );
          expect(owner.delegate.calls, [_restoreCall]);
          _expectNoHistoryError(tester);
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.windows),
      );

      for (final deactivate in [true, false]) {
        testWidgets(
          'open history retires focus and semantics when ${deactivate ? 'active' : 'interactive'} becomes false',
          (tester) async {
            final semantics = tester.ensureSemantics();
            try {
              final owner = (await tester.runAsync(_HistoryFixture.create))!;
              final host = _HistoryFeedbackHost(owner, embedded: embedded);
              await _mount(tester, host);
              await _openHistory(tester, host);
              final saved = owner.storage.source;
              final oldOwnerCurrent = tester
                  .widget<AgentConversationList>(_visibleHistory())
                  .isOwnerCurrent!;
              final pending = await _focusHistoryDuringSave(tester, owner);
              final historyRoute = embedded
                  ? null
                  : ModalRoute.of(tester.element(_visibleHistory()));
              expect(oldOwnerCurrent(), isTrue);
              expect(owner.delegate.calls, [_restoreCall]);
              expect(owner.storage.source, saved);

              // Leave the history open: source retirement must close or hide
              // its own UI without requiring the user to press Close first.
              host.update(
                active: deactivate ? false : null,
                interactive: deactivate ? null : false,
              );
              await tester.pump();
              await _until(
                tester,
                () =>
                    !pending.focus.hasFocus &&
                    !_semanticsContainsLabel(
                      pending.semanticsOwner,
                      pending.restoreLabel,
                    ) &&
                    _visibleHistory().evaluate().isEmpty,
                reason: 'Retiring an open history must remove its actual focus and semantics.',
              );
              expect(oldOwnerCurrent(), isFalse);
              if (historyRoute != null) {
                expect(historyRoute.isActive, isFalse);
              }
              expect(owner.storage.source, saved);
              expect(owner.repository.find(_firstArchivedId)!.archived, isTrue);

              await tester.runAsync(() async {
                owner.releaseSave();
                await owner.repository.waitForPendingWrites();
              });
              await tester.pump();

              expect(owner.repository.blocked, isFalse);
              expect(
                owner.repository.find(_firstArchivedId)!.archived,
                isFalse,
              );
              expect(owner.stored(_firstArchivedId).archived, isFalse);
              expect(owner.delegate.calls, [_restoreCall]);
              expect(owner.recoverCalls, 0);
              expect(pending.focus.hasFocus, isFalse);
              expect(
                _semanticsContainsLabel(
                  pending.semanticsOwner,
                  pending.restoreLabel,
                ),
                isFalse,
              );

              host.update(active: true, interactive: true);
              await tester.pumpAndSettle();
              await _openHistory(
                tester,
                host,
                expectedArchivedId: _secondArchivedId,
              );
              expect(oldOwnerCurrent(), isFalse);
              expect(
                _inHistory('agent-history-$_firstArchivedId'),
                findsNothing,
              );
              expect(
                _inHistory('agent-history-$_secondArchivedId'),
                findsOneWidget,
              );
              _expectNoHistoryError(tester);
              expect(tester.takeException(), isNull);
            } finally {
              semantics.dispose();
            }
          },
          variant: TargetPlatformVariant.only(TargetPlatform.windows),
        );
      }

      testWidgets(
        'real recovery resumes the current restore and remains busy after re-enabling',
        (tester) async {
          final owner = (await tester.runAsync(_RealRecoveryFixture.create))!;
          final host = _RealRecoveryHost(owner, embedded: embedded);
          await _mountRealRecovery(tester, host);
          await _openHistory(tester, host);
          await _failRealRestore(tester, owner);
          final saved = owner.storage.source;
          final revision = owner.archive.revision;
          final loadCalls = owner.storage.loadCalls;
          final saveCalls = owner.storage.saveCalls;
          final delegate = tester
              .widget<AgentConversationView>(find.byType(AgentConversationView))
              .delegate;
          final repeat = tester
              .widget<IconButton>(_inHistory('agent-restore-$_firstArchivedId'))
              .onPressed!;

          await tester.runAsync(() async {
            owner.storage.pauseRecovery();
          });
          await _tap(tester, _inHistory('agent-restore-$_firstArchivedId'));
          await _until(
            tester,
            () =>
                owner.storage.loadEntered &&
                !owner.app.agent.runtime.state.value.enabled,
            reason: 'The real application recovery must disable its runtime.',
          );
          expect(owner.app.agent.isInitialized, isTrue);
          expect(owner.app.agent.runtime.state.value.maintenance, isFalse);
          expect(owner.storage.loadCalls, loadCalls + 1);
          expect(owner.storage.saveCalls, saveCalls);
          expect(owner.storage.source, saved);
          expect(
            tester
                .widget<IconButton>(
                  _inHistory('agent-restore-$_firstArchivedId'),
                )
                .onPressed,
            isNull,
          );
          await tester.runAsync(() async {
            repeat();
          });
          await tester.pump();
          expect(owner.storage.loadCalls, loadCalls + 1);

          // Re-enable through the actual recovery finally, without inserting a
          // frame first. The list must await availability in its own widget.
          await tester.runAsync(() async {
            owner.storage.releaseLoad();
          });
          await _until(
            tester,
            () =>
                owner.storage.saveEntered &&
                owner.app.agent.runtime.state.value.enabled,
            reason: 'The current restore must follow real recovery completion.',
          );
          expect(
            tester
                .widget<AgentConversationView>(
                  find.byType(AgentConversationView),
                )
                .delegate,
            same(delegate),
          );
          expect(owner.repository.find(_firstArchivedId)!.archived, isTrue);
          expect(owner.storage.source, saved);
          expect(owner.storage.saveCalls, saveCalls + 1);
          expect(
            tester
                .widget<IconButton>(
                  _inHistory('agent-restore-$_firstArchivedId'),
                )
                .onPressed,
            isNull,
          );
          await tester.runAsync(() async {
            repeat();
          });
          await tester.pump();

          await tester.runAsync(() async {
            owner.storage.releaseSave();
            await owner.repository.waitForPendingWrites();
          });
          await tester.pumpAndSettle();

          expect(owner.storage.loadCalls, loadCalls + 1);
          expect(owner.storage.saveCalls, saveCalls + 1);
          expect(owner.archive.revision, revision + 1);
          expect(
            owner.archive.conversations
                .singleWhere(
                  (conversation) => conversation.id == _firstArchivedId,
                )
                .archived,
            isFalse,
          );
          expect(owner.repository.blocked, isFalse);
          expect(owner.app.agent.runtime.state.value.enabled, isTrue);
          expect(owner.repository.selectedId, _currentId);
          expect(_inHistory('agent-history-$_firstArchivedId'), findsNothing);
          expect(
            _inHistory('agent-history-$_secondArchivedId'),
            findsOneWidget,
          );
          _expectNoHistoryError(tester);
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.windows),
      );

      testWidgets(
        'real recovery hidden and re-entered cannot restore for its retired drawer',
        (tester) async {
          final owner = (await tester.runAsync(_RealRecoveryFixture.create))!;
          final host = _RealRecoveryHost(owner, embedded: embedded);
          await _mountRealRecovery(tester, host);
          await _openHistory(tester, host);
          await _failRealRestore(tester, owner);
          final saved = owner.storage.source;
          final revision = owner.archive.revision;
          final loadCalls = owner.storage.loadCalls;
          final saveCalls = owner.storage.saveCalls;

          await tester.runAsync(() async {
            owner.storage.pauseRecovery();
          });
          await _tap(tester, _inHistory('agent-restore-$_firstArchivedId'));
          await _until(
            tester,
            () =>
                owner.storage.loadEntered &&
                !owner.app.agent.runtime.state.value.enabled,
            reason: 'Hide only after the real recovery has begun.',
          );
          await _closeHistory(tester, host);
          host.update(active: false);
          await tester.pump();
          host.update(active: true);
          await tester.pump();
          await _openHistory(tester, host);
          _expectNoHistoryError(tester);
          expect(owner.app.agent.isInitialized, isTrue);
          expect(owner.storage.loadCalls, loadCalls + 1);
          expect(
            tester
                .widget<IconButton>(
                  _inHistory('agent-restore-$_firstArchivedId'),
                )
                .onPressed,
            isNull,
          );

          await tester.runAsync(() async {
            owner.storage.releaseLoad();
          });
          await _until(
            tester,
            () =>
                owner.app.agent.runtime.state.value.enabled &&
                !owner.repository.blocked,
            reason: 'Accepted recovery must finish for the application.',
          );
          await tester.runAsync(owner.repository.waitForPendingWrites);
          await tester.pumpAndSettle();

          expect(owner.storage.loadCalls, loadCalls + 1);
          expect(owner.storage.saveCalls, saveCalls);
          expect(owner.storage.saveEntered, isFalse);
          expect(owner.storage.source, saved);
          expect(owner.archive.revision, revision);
          expect(owner.repository.find(_firstArchivedId)!.archived, isTrue);
          expect(
            owner.archive.conversations
                .singleWhere(
                  (conversation) => conversation.id == _firstArchivedId,
                )
                .archived,
            isTrue,
          );
          expect(owner.repository.selectedId, _currentId);
          expect(_inHistory('agent-history-$_firstArchivedId'), findsOneWidget);
          expect(
            tester
                .widget<IconButton>(
                  _inHistory('agent-restore-$_firstArchivedId'),
                )
                .onPressed,
            isNotNull,
          );
          _expectNoHistoryError(tester);
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.windows),
      );
    });
  }

  testWidgets(
    'retiring standalone history removes only its owned route below a foreign overlay',
    (tester) async {
      final semantics = tester.ensureSemantics();
      DialogRoute<void>? foreign;
      NavigatorState? navigator;
      try {
        final owner = (await tester.runAsync(_HistoryFixture.create))!;
        final host = _HistoryFeedbackHost(owner, embedded: false);
        await _mount(tester, host);
        await _openHistory(tester, host);
        final saved = owner.storage.source;
        final pending = await _focusHistoryDuringSave(tester, owner);
        final historyContext = tester.element(_visibleHistory());
        final historyRoute = ModalRoute.of(historyContext)!;
        navigator = Navigator.of(historyContext);
        late final DialogRoute<void> overlay;
        var historyCompleted = false;
        await tester.runAsync(() async {
          overlay = foreign = DialogRoute<void>(
            context: historyContext,
            builder: (_) => const AlertDialog(
              key: ValueKey('foreign-history-overlay'),
              title: Text('其他页面'),
              content: Text('保留这条较新的路由'),
            ),
          );
          unawaited(
            historyRoute.completed.then((_) {
              historyCompleted = true;
            }),
          );
          unawaited(navigator!.push<void>(overlay));
        });
        await _until(
          tester,
          () => overlay.isCurrent && overlay.animation!.isCompleted,
          reason: 'The newer foreign route must finish covering history.',
        );
        expect(historyRoute.isActive, isTrue);
        expect(historyCompleted, isFalse);
        expect(_visibleHistory(), findsNothing);

        host.update(active: false);
        await tester.pump();
        await _until(
          tester,
          () => !historyRoute.isActive && historyCompleted,
          reason: 'Retirement must complete the owned history route beneath the foreign one.',
        );
        expect(overlay.isActive, isTrue);
        expect(overlay.isCurrent, isTrue);
        expect(_key('foreign-history-overlay').hitTestable(), findsOneWidget);
        expect(pending.focus.hasFocus, isFalse);
        expect(
          _semanticsContainsLabel(pending.semanticsOwner, pending.restoreLabel),
          isFalse,
        );
        expect(owner.storage.source, saved);
        expect(owner.repository.find(_firstArchivedId)!.archived, isTrue);

        await tester.runAsync(() async {
          owner.releaseSave();
          await owner.repository.waitForPendingWrites();
        });
        await tester.pump();

        expect(owner.repository.blocked, isFalse);
        expect(owner.repository.find(_firstArchivedId)!.archived, isFalse);
        expect(owner.stored(_firstArchivedId).archived, isFalse);
        expect(owner.delegate.calls, [_restoreCall]);
        expect(owner.recoverCalls, 0);
        expect(overlay.isCurrent, isTrue);
        await tester.runAsync(() async {
          navigator!.pop();
        });
        await tester.pumpAndSettle();
        await tester.runAsync(() => overlay.completed);
        expect(overlay.isActive, isFalse);
        expect(tester.takeException(), isNull);
      } finally {
        if (foreign?.isCurrent == true) {
          await tester.runAsync(() async {
            navigator!.pop();
          });
          await tester.pump();
        }
        semantics.dispose();
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'frozen repositories with null selections cannot revive an old history source after A to B to A',
    (tester) async {
      final repositories = (await tester.runAsync(() async {
        return (
          first: await _frozenRepository(),
          second: await _frozenRepository(),
        );
      }))!;
      final first = repositories.first;
      final second = repositories.second;
      final firstSaved = first.storage.source;
      final secondSaved = second.storage.source;
      final delegate = UiDelegate(first.repository);
      final host = _RepositoryFeedbackHost(first.repository, delegate);
      final app = (await tester.runAsync(
        () => workspaceProvider(locale: 'zh'),
      ))!;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(620, 820);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.runAsync(() async {
          for (final entry in [first, second]) {
            await entry.repository.waitForPendingWrites();
            entry.repository.dispose();
          }
          try {
            await app.shutdown.quiesce();
          } finally {
            app.dispose();
            await app.session.close();
          }
        });
        delegate.state.dispose();
        host.dispose();
        tester.view.reset();
      });

      void expectFrozenArchivesUnchanged() {
        for (final entry in [first, second]) {
          expect(entry.repository.isLoaded, isTrue);
          expect(entry.repository.blocked, isFalse);
          expect(entry.repository.canWrite, isFalse);
          expect(entry.repository.selectedId, isNull);
          expect(entry.repository.selected, isNull);
          expect(entry.repository.draftConversation, isNull);
          expect(entry.repository.conversations, isEmpty);
          expect(entry.storage.loadCalls, 1);
          expect(entry.storage.saveCalls, 0);
        }
        expect(first.storage.source, firstSaved);
        expect(second.storage.source, secondSaved);
        expect(delegate.calls, isEmpty);
      }

      await tester.pumpWidget(
        WorkspaceHarness(
          provider: app,
          home: host.build(),
          locale: const Locale('zh'),
        ),
      );
      await tester.pumpAndSettle();
      final view = _key('frozen-source-conversation-view');
      final viewState = tester.state(view);
      expectFrozenArchivesUnchanged();
      await _tap(tester, _key('agent-history'));
      await _until(
        tester,
        () => _visibleHistory().evaluate().length == 1,
        reason: 'The frozen empty archive must still expose readable history.',
      );
      final oldList = tester.widget<AgentConversationList>(_visibleHistory());
      final oldOwnerCurrent = oldList.isOwnerCurrent!;
      final oldHistoryRoute = ModalRoute.of(tester.element(_visibleHistory()))!;
      var oldHistoryCompleted = false;
      await tester.runAsync(() async {
        unawaited(
          oldHistoryRoute.completed.then((_) {
            oldHistoryCompleted = true;
          }),
        );
      });
      expect(oldList.repository, same(first.repository));
      expect(oldOwnerCurrent(), isTrue);
      expect(
        tester.widget<AgentConversationView>(view).delegate,
        same(delegate),
      );

      host.replaceRepository(second.repository);
      await tester.pump();
      await _until(
        tester,
        () => !oldHistoryRoute.isActive && oldHistoryCompleted,
        reason:
            'Changing repository identity must retire its standalone history.',
      );
      expect(oldOwnerCurrent(), isFalse);
      expect(tester.state(view), same(viewState));
      expect(
        tester.widget<AgentConversationView>(view).repository,
        same(second.repository),
      );
      expect(
        tester.widget<AgentConversationView>(view).delegate,
        same(delegate),
      );
      expectFrozenArchivesUnchanged();

      host.replaceRepository(first.repository);
      await tester.pumpAndSettle();
      expect(tester.state(view), same(viewState));
      expect(
        tester.widget<AgentConversationView>(view).repository,
        same(first.repository),
      );
      expect(
        tester.widget<AgentConversationView>(view).delegate,
        same(delegate),
      );
      expect(oldOwnerCurrent(), isFalse);
      expect(oldHistoryRoute.isActive, isFalse);
      expect(oldHistoryCompleted, isTrue);
      expectFrozenArchivesUnchanged();
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
