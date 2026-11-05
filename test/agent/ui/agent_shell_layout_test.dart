import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/agent_settings.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/agent_page.dart';
import 'package:sked/services/desktop_window_bridge.dart';
import 'package:sked/widgets/desktop_window_host.dart';
import 'package:sked/widgets/workspace_frame.dart';

import '../../support/agent_workspace_navigation.dart';
import '../../support/workspace_harness.dart';
import 'agent_ui_test_support.dart';

typedef _ShellLayout = ({String name, TargetPlatform platform, Size size});

const _layouts = <_ShellLayout>[
  (
    name: 'Windows 1200dp',
    platform: TargetPlatform.windows,
    size: Size(1200, 900),
  ),
  (
    name: 'Windows 600dp',
    platform: TargetPlatform.windows,
    size: Size(600, 900),
  ),
  (
    name: 'Android 320dp',
    platform: TargetPlatform.android,
    size: Size(320, 740),
  ),
  (
    name: 'Android 390dp',
    platform: TargetPlatform.android,
    size: Size(390, 844),
  ),
];

const _longTitle =
    'Planning every part of the timetable and the calendar while keeping '
    'all saved drafts, conversations, and reading positions available '
    'when the main workspace changes';
const _windowChannel = MethodChannel('com.mashiro.sked/window');

Finder _key(String value, {bool skipOffstage = true}) =>
    find.byKey(ValueKey(value), skipOffstage: skipOffstage);

Finder _nearestAncestor<T extends Widget>(Finder descendant) {
  Element? owner;
  descendant.evaluate().single.visitAncestorElements((element) {
    if (element.widget is T) {
      owner = element;
      return false;
    }
    return true;
  });
  expect(owner, isNotNull, reason: '$descendant must have a $T ancestor.');
  return find.byElementPredicate((element) => identical(element, owner));
}

Finder _header() => _nearestAncestor<Row>(_key('agent-conversation-menu'));

Finder _title(String title) => find.descendant(
  of: _header(),
  matching: find.byWidgetPredicate(
    (widget) => widget is Text && widget.data == title,
  ),
);

bool _belongsTo(RenderObject owner, Object target) {
  if (target is! RenderObject) return false;
  RenderObject? current = target;
  while (current != null) {
    if (identical(current, owner)) return true;
    current = current.parent;
  }
  return false;
}

void _expectTarget(WidgetTester tester, Finder control, {bool touch = false}) {
  expect(control.hitTestable(), findsOneWidget);
  final rect = tester.getRect(control);
  final screen = Offset.zero & tester.view.physicalSize;
  expect(rect.left, greaterThanOrEqualTo(screen.left - 0.5));
  expect(rect.right, lessThanOrEqualTo(screen.right + 0.5));
  expect(rect.top, greaterThanOrEqualTo(screen.top - 0.5));
  expect(rect.bottom, lessThanOrEqualTo(screen.bottom + 0.5));
  if (touch) {
    expect(rect.width, greaterThanOrEqualTo(48));
    expect(rect.height, greaterThanOrEqualTo(48));
  }
  final render = tester.renderObject(control);
  for (final x in [rect.left + 2, rect.center.dx, rect.right - 2]) {
    for (final y in [rect.top + 2, rect.center.dy, rect.bottom - 2]) {
      final hit = tester.hitTestOnBinding(Offset(x, y));
      expect(
        hit.path.any((entry) => _belongsTo(render, entry.target)),
        isTrue,
        reason:
            '$control must receive input at ($x, $y) in $rect. '
            'Hit path: ${hit.path.map((entry) => entry.target.runtimeType).join(", ")}',
      );
    }
  }
}

class _ShellFixture {
  const _ShellFixture({
    required this.app,
    required this.storage,
    required this.conversationId,
    required this.windowCalls,
  });

  final AppRuntime app;
  final UiMemoryStorage storage;
  final String conversationId;
  final List<String> windowCalls;

  ConversationRepository get repository => app.agent.conversations;

  (String, double) reading(WidgetTester tester) {
    final viewport = tester.getRect(_key('agent-transcript-$conversationId'));
    final visible = <(String, Rect)>[];
    for (final message in repository.find(conversationId)!.messages) {
      final item = _key('agent-message-group-${message.id}');
      if (item.evaluate().isEmpty) continue;
      final rect = tester.getRect(item);
      if (rect.bottom > viewport.top && rect.top < viewport.bottom) {
        visible.add((message.id, rect));
      }
    }
    expect(visible, isNotEmpty);
    visible.sort((a, b) => a.$2.top.compareTo(b.$2.top));
    final first = visible.first;
    return (first.$1, (viewport.top - first.$2.top) / first.$2.height);
  }
}

Future<void> _finishWithFrames(WidgetTester tester, Future<void> work) async {
  var completed = false;
  Object? failure;
  StackTrace? trace;
  unawaited(
    work.then<void>(
      (_) {
        completed = true;
      },
      onError: (Object error, StackTrace stack) {
        failure = error;
        trace = stack;
        completed = true;
      },
    ),
  );
  // UI commands can enqueue in FakeAsync while storage was initialized in the
  // real zone. Drive both queues until the actual operation reports completion.
  for (var frame = 0; frame < 180 && !completed; frame++) {
    await tester.runAsync(() => Future<void>.microtask(() {}));
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(completed, isTrue, reason: 'The accepted operation must complete.');
  if (failure != null) Error.throwWithStackTrace(failure!, trace!);
}

Future<void> _settleWrites(WidgetTester tester, AppRuntime app) async {
  await tester.pumpAndSettle();
  await _finishWithFrames(
    tester,
    app.session.repository.waitForPendingWrites(),
  );
  await _finishWithFrames(
    tester,
    app.agent.conversations.waitForPendingWrites(),
  );
  await tester.pumpAndSettle();
  await _finishWithFrames(tester, app.persistence.flushPendingUiStateSaves());
  await tester.pumpAndSettle();
}

Future<_ShellFixture> _mountShell(
  WidgetTester tester,
  _ShellLayout layout, {
  double scale = 1,
  TextDirection direction = TextDirection.ltr,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = layout.size;
  addTearDown(tester.view.reset);
  final window = DesktopWindowBridge.instance;
  window.available = false;
  window.prepareClose = null;
  final calls = <String>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  addTearDown(() {
    window.available = false;
    window.prepareClose = null;
    messenger.setMockMethodCallHandler(_windowChannel, null);
  });
  if (layout.platform == TargetPlatform.windows) {
    messenger.setMockMethodCallHandler(_windowChannel, (call) async {
      calls.add(call.method);
      return switch (call.method) {
        'initialize' => {'maximized': false, 'focused': true},
        'configureChrome' ||
        'startDrag' ||
        'toggleMaximize' ||
        'systemMenu' ||
        'minimize' ||
        'confirmClose' => null,
        _ => throw MissingPluginException(
          'Unexpected window method: ${call.method}',
        ),
      };
    });
    await tester.runAsync(window.initialize);
    expect(window.available, isTrue);
  }

  final storage = UiMemoryStorage();
  // Repository initialization and its queued fixture saves must share a real
  // async zone; their completion is independent of widget frames.
  final app = (await tester.runAsync(
    () => workspaceProvider(agentConversationStorage: storage),
  ))!;
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await _settleWrites(tester, app);
    try {
      await _finishWithFrames(tester, app.shutdown.quiesce());
    } finally {
      app.dispose();
      await _finishWithFrames(tester, app.session.close());
    }
  });
  final conversation = (await tester.runAsync(() async {
    await app.agent.configure(
      const AgentSettings(
        enabled: true,
        endpoint: 'https://shell.example.invalid/v1',
        model: 'shell-model',
        models: [
          AgentModelConfig(
            id: 'shell-model',
            reasoningEfforts: [AgentReasoningEffort.medium],
            defaultReasoningEffort: AgentReasoningEffort.medium,
          ),
        ],
      ),
    );
    final conversation = await app.agent.conversations.create(
      title: _longTitle,
    );
    await app.agent.conversations.update(
      conversation.id,
      (value) => value.copyWith(
        messages: [
          for (var index = 0; index < 40; index++)
            ConversationMessage(
              id: 'shell-message-$index',
              role: ConversationRole.assistant,
              text:
                  'Answer $index. Preserve this saved explanation when changing '
                  'workspace.\n\nRead the plan, keep the draft, and return to '
                  'this message.',
              createdAt: DateTime.utc(2026, 11, 5, 9, index),
            ),
        ],
      ),
    );
    return conversation;
  }))!;
  await tester.pumpWidget(
    WorkspaceHarness(provider: app, textScale: scale, textDirection: direction),
  );
  await tester.pumpAndSettle();
  await selectAgentShellDestination(tester, 'agent');
  await tester.pumpAndSettle();
  expect(tester.widget<AgentPage>(find.byType(AgentPage)).embedded, isTrue);
  expect(
    tester.widget<WorkspaceFrame>(_key('agent-workspace-frame')).active,
    isTrue,
  );
  expect(find.byType(BackButton).hitTestable(), findsNothing);
  expect(app.workspaceView.activeMode, AppMode.student);
  expect(app.agent.conversations.selectedId, conversation.id);
  return _ShellFixture(
    app: app,
    storage: storage,
    conversationId: conversation.id,
    windowCalls: calls,
  );
}

void _expectAlignedConversation(WidgetTester tester, _ShellFixture fixture) {
  final (messageId, _) = fixture.reading(tester);
  final messageRect = tester.getRect(_key('agent-message-group-$messageId'));
  final composerRect = tester.getRect(
    _nearestAncestor<Material>(_key('agent-composer')),
  );
  expect(messageRect.left, closeTo(composerRect.left, 0.5));
  expect(messageRect.right, closeTo(composerRect.right, 0.5));
}

Future<void> _expectHeader(
  WidgetTester tester,
  _ShellFixture fixture,
  _ShellLayout layout,
  String title, {
  bool ellipsized = false,
}) async {
  final titleFinder = _title(title);
  expect(titleFinder, findsOneWidget);
  final paragraph = tester.renderObject<RenderParagraph>(titleFinder);
  expect(paragraph.didExceedMaxLines, ellipsized);
  expect(_key('agent-new', skipOffstage: false), findsNothing);
  _expectTarget(
    tester,
    _key('agent-conversation-menu'),
    touch: layout.platform == TargetPlatform.android,
  );
  if (layout.platform != TargetPlatform.windows) return;

  final l = AppLocalizations.of(tester.element(titleFinder));
  final captions = [
    find.bySemanticsLabel(l.minimizeWindow),
    find.bySemanticsLabel(l.maximizeWindow),
    find.bySemanticsLabel(l.closeWindow),
  ];
  for (final caption in captions) {
    _expectTarget(tester, caption);
  }
  final captionRects = captions.map(tester.getRect).toList();
  final captionRect = captionRects.reduce((a, b) => a.expandToInclude(b));
  final titleRect = tester.getRect(titleFinder);
  final menuRect = tester.getRect(_key('agent-conversation-menu'));
  expect(captionRects.last.right, closeTo(layout.size.width, 0.5));
  expect(titleRect.right, lessThanOrEqualTo(captionRect.left + 0.5));
  expect(menuRect.right, lessThanOrEqualTo(captionRect.left + 0.5));
  expect(menuRect.top, greaterThanOrEqualTo(captionRect.top - 0.5));
  expect(menuRect.bottom, lessThanOrEqualTo(captionRect.bottom + 0.5));
  expect(titleRect.overlaps(menuRect), isFalse);

  var reachedDragRegion = false;
  titleFinder.evaluate().single.visitAncestorElements((element) {
    expect(
      element.widget,
      isNot(isA<Tooltip>()),
      reason: 'The Windows title must accept window gestures on its text.',
    );
    if (element.widget is DesktopDragRegion) {
      reachedDragRegion = true;
      return false;
    }
    return true;
  });
  expect(reachedDragRegion, isTrue);
  fixture.windowCalls.clear();
  await tester.dragFrom(
    titleRect.center,
    const Offset(36, 0),
    kind: PointerDeviceKind.mouse,
  );
  await tester.pump();
  await tester.runAsync(() => Future<void>.microtask(() {}));
  await tester.pump();
  expect(
    fixture.windowCalls.where((method) => method == 'startDrag'),
    hasLength(1),
  );
}

Future<void> _cancelMenu(
  WidgetTester tester,
  _ShellFixture fixture, {
  bool systemBack = false,
}) async {
  final selected = fixture.repository.selectedId;
  final archive = fixture.storage.source;
  await tester.tap(_key('agent-conversation-menu'));
  await tester.pumpAndSettle();
  expect(_key('agent-settings').hitTestable(), findsOneWidget);
  if (systemBack) {
    await tester.binding.handlePopRoute();
  } else {
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  }
  await tester.pumpAndSettle();
  expect(_key('agent-settings').hitTestable(), findsNothing);
  expect(_key('agent-composer').hitTestable(), findsOneWidget);
  expect(fixture.repository.selectedId, selected);
  expect(fixture.storage.source, archive);
}

Future<void> _newDraftFromResources(
  WidgetTester tester,
  _ShellFixture fixture,
  _ShellLayout layout,
) async {
  final archive = fixture.storage.source;
  final saved = fixture.repository.conversations
      .map((value) => value.id)
      .toList();
  await openAgentShellHistory(tester);
  final newChat = _key('agent-history-new');
  await tester.ensureVisible(newChat);
  await tester.pumpAndSettle();
  _expectTarget(
    tester,
    newChat,
    touch: layout.platform == TargetPlatform.android,
  );
  await tester.tap(newChat.hitTestable());
  await _settleWrites(tester, fixture.app);
  final draftId = fixture.repository.selectedId!;
  expect(draftId, isNot(fixture.conversationId));
  expect(fixture.repository.isDraft(draftId), isTrue);
  expect(fixture.repository.selected!.messages, isEmpty);
  expect(_key('agent-composer').hitTestable(), findsOneWidget);
  expect(_key('agent-history-$draftId', skipOffstage: false), findsNothing);
  expect(
    fixture.repository.conversations.map((value) => value.id).toList(),
    saved,
  );
  expect(fixture.storage.source, archive);
  final l = AppLocalizations.of(tester.element(_key('agent-composer')));
  await _expectHeader(tester, fixture, layout, l.agentTitle);
  await tester.enterText(_key('agent-composer'), 'Keep this unsent draft');
  await _settleWrites(tester, fixture.app);
  expect(fixture.repository.selected!.draft, 'Keep this unsent draft');
  expect(fixture.storage.source, archive);
  expect(fixture.storage.source, isNot(contains(draftId)));
  for (final key in [
    'workspace-main-navigation',
    'agent-attach-file',
    'agent-mode-picker',
    'agent-model-picker',
    'agent-send',
  ]) {
    final control = _key(key);
    // An expanded desktop resource pane already supplies the main navigation.
    if (key == 'workspace-main-navigation' && control.evaluate().isEmpty) {
      continue;
    }
    await tester.ensureVisible(control);
    await tester.pumpAndSettle();
    _expectTarget(
      tester,
      control,
      touch: layout.platform == TargetPlatform.android,
    );
  }
}

void _expectReading(
  WidgetTester tester,
  _ShellFixture fixture,
  (String, double) expected,
) {
  final actual = fixture.reading(tester);
  expect(actual.$1, expected.$1);
  expect(actual.$2, closeTo(expected.$2, 0.03));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final layout in _layouts) {
    for (final scale in [1.0, 2.0]) {
      for (final direction in TextDirection.values) {
        testWidgets(
          '${layout.name} Agent uses the main shell at ${scale}x in $direction',
          (tester) async {
            final semantics = tester.ensureSemantics();
            try {
              final fixture = await _mountShell(
                tester,
                layout,
                scale: scale,
                direction: direction,
              );
              _expectAlignedConversation(tester, fixture);
              await _expectHeader(
                tester,
                fixture,
                layout,
                _longTitle,
                ellipsized: true,
              );
              await _cancelMenu(tester, fixture);
              if (layout.platform == TargetPlatform.android) {
                await _cancelMenu(tester, fixture, systemBack: true);
              }
              await _newDraftFromResources(tester, fixture, layout);
              expect(tester.takeException(), isNull);
              await tester.pumpWidget(const SizedBox.shrink());
              await tester.pumpAndSettle();
            } finally {
              semantics.dispose();
            }
          },
          variant: TargetPlatformVariant.only(layout.platform),
        );
      }
    }
  }

  for (final (wide, narrow) in [
    (_layouts[0], _layouts[1]),
    (_layouts[3], _layouts[2]),
  ]) {
    testWidgets(
      '${wide.platform.name} Agent retains its draft and reading through '
      'workspace changes and ${wide.size.width} to ${narrow.size.width}dp '
      'resizing at 2x in RTL',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          final fixture = await _mountShell(
            tester,
            wide,
            scale: 2,
            direction: TextDirection.rtl,
          );
          final transcript = _key('agent-transcript-${fixture.conversationId}');
          final viewport = tester.getRect(transcript);
          for (var drag = 0; drag < 2; drag++) {
            await tester.drag(transcript, Offset(0, viewport.height * 0.8));
            await tester.pumpAndSettle();
          }
          expect(_key('agent-jump-latest').hitTestable(), findsOneWidget);
          await tester.enterText(
            _key('agent-composer'),
            'Preserve the next question and this reading position',
          );
          await _settleWrites(tester, fixture.app);
          const selection = TextSelection.collapsed(offset: 7);
          tester
                  .widget<TextField>(_key('agent-composer'))
                  .controller!
                  .selection =
              selection;
          await tester.pumpAndSettle();
          final reading = fixture.reading(tester);
          expect(reading.$1, isNot('shell-message-39'));
          final draft = fixture.repository.selected!.draft;

          void expectDraft() {
            expect(fixture.repository.selectedId, fixture.conversationId);
            expect(fixture.repository.selected!.draft, draft);
            final field = tester.widget<TextField>(_key('agent-composer'));
            expect(field.controller!.text, draft);
            expect(field.controller!.selection, selection);
          }

          await selectAgentShellDestination(tester, 'student');
          await tester.pumpAndSettle();
          expect(_key('agent-composer').hitTestable(), findsNothing);
          expect(fixture.repository.selected!.draft, draft);
          tester.view.physicalSize = narrow.size;
          await tester.pumpAndSettle();
          await selectAgentShellDestination(tester, 'agent');
          await tester.pumpAndSettle();
          expectDraft();
          _expectReading(tester, fixture, reading);
          _expectAlignedConversation(tester, fixture);
          await _expectHeader(
            tester,
            fixture,
            narrow,
            _longTitle,
            ellipsized: true,
          );

          tester.view.physicalSize = wide.size;
          await tester.pumpAndSettle();
          expectDraft();
          _expectReading(tester, fixture, reading);
          _expectAlignedConversation(tester, fixture);
          await _expectHeader(
            tester,
            fixture,
            wide,
            _longTitle,
            ellipsized: true,
          );
          await _cancelMenu(tester, fixture);
          expectDraft();
          _expectReading(tester, fixture, reading);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        } finally {
          semantics.dispose();
        }
      },
      variant: TargetPlatformVariant.only(wide.platform),
    );
  }
}
