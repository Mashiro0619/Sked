import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/agent_application.dart';
import 'package:sked/agent/conversations/conversation_storage.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/screens/agent_page.dart';
import 'package:sked/screens/agent_settings_page.dart';
import 'package:sked/services/desktop_window_bridge.dart';
import 'package:sked/widgets/desktop_window_host.dart';
import 'package:sked/widgets/workbench_chrome_metrics.dart';
import 'package:sked/widgets/workspace_frame.dart';

import '../../support/agent_workspace_navigation.dart';
import '../../support/workspace_harness.dart';

typedef _Layout = ({String name, TargetPlatform platform, Size size});

const _layouts = <_Layout>[
  (
    name: 'Windows 600dp',
    platform: TargetPlatform.windows,
    size: Size(600, 900),
  ),
  (
    name: 'Windows 1200dp',
    platform: TargetPlatform.windows,
    size: Size(1200, 900),
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

const _windowChannel = MethodChannel('com.mashiro.sked/window');
const _storageError = 'Synthetic initialization archive failure.';

Finder _key(String value) => find.byKey(ValueKey(value));

Finder? _visibleMainNavigation() {
  for (final value in [
    'workspace-main-navigation',
    'workspace-resource-collapse',
    'workspace-resource-open',
    'workspace-resource-mode-general',
    'workspace-resource-mode-student',
  ]) {
    final navigation = _key(value).hitTestable();
    if (navigation.evaluate().length == 1) return navigation;
  }
  return null;
}

class _FailingStorage extends ConversationStorage {
  _FailingStorage() : super.base();

  final release = Completer<void>();
  int loads = 0;
  int saves = 0;

  void failLoad() {
    if (!release.isCompleted) release.complete();
  }

  @override
  Future<ConversationStorageLoad> load() async {
    loads++;
    await release.future;
    throw const ConversationStorageException(_storageError);
  }

  @override
  Future<void> save(String source, {required int revision}) async {
    saves++;
    throw StateError(
      'The initialization fixture must never save a conversation.',
    );
  }
}

class _Fixture {
  _Fixture(this.app, this.storage, this.windowCalls);

  final AppRuntime app;
  final _FailingStorage storage;
  final List<String> windowCalls;
  Future<void>? initialization;
  Object? initializationError;
  StackTrace? initializationTrace;

  void observeInitialization() {
    initialization ??= app.agent.initialize().then<void>(
      (_) {},
      onError: (Object error, StackTrace trace) {
        initializationError = error;
        initializationTrace = trace;
      },
    );
  }

  void expectStorageFailure() {
    final error = initializationError;
    if (error is! ConversationStorageException ||
        error.message != _storageError) {
      if (error != null) Error.throwWithStackTrace(error, initializationTrace!);
      fail('The gated synthetic conversation load must fail explicitly.');
    }
    expect(app.agent.isInitialized, isFalse);
    expect(app.agent.initializationError, isTrue);
    expect(
      app.agent.initializationFailure,
      AgentInitializationFailure.conversationStorage,
    );
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
  for (var frame = 0; frame < 180 && !completed; frame++) {
    await tester.runAsync(() => Future<void>.microtask(() {}));
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(
    completed,
    isTrue,
    reason: 'The actual async operation must complete.',
  );
  if (failure != null) Error.throwWithStackTrace(failure!, trace!);
}

Future<void> _until(
  WidgetTester tester,
  bool Function() ready,
  String description,
) async {
  for (var frame = 0; frame < 180 && !ready(); frame++) {
    await tester.runAsync(() => Future<void>.microtask(() {}));
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(ready(), isTrue, reason: description);
  await tester.pump();
}

Future<_Fixture> _mount(
  WidgetTester tester,
  _Layout layout,
  double scale,
  TextDirection direction,
) async {
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
        _ => throw StateError('Unexpected window method: ${call.method}'),
      };
    });
    await tester.runAsync(window.initialize);
    expect(window.available, isTrue);
  }
  final fixture = (await tester.runAsync(() async {
    final storage = _FailingStorage();
    final app = await workspaceProvider(agentConversationStorage: storage);
    return _Fixture(app, storage, calls);
  }))!;
  addTearDown(() async {
    try {
      if (fixture.storage.loads > 0) fixture.observeInitialization();
      await tester.runAsync(() async => fixture.storage.failLoad());
      if (fixture.initialization case final operation?) {
        await _finishWithFrames(tester, operation);
        fixture.expectStorageFailure();
      }
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      try {
        await _finishWithFrames(tester, fixture.app.shutdown.quiesce());
      } finally {
        await tester.runAsync(() async => fixture.app.dispose());
        await _finishWithFrames(tester, fixture.app.session.close());
      }
    }
  });
  expect(fixture.app.agent.settings.enabled, isTrue);
  expect(fixture.app.agent.isInitialized, isFalse);
  expect(fixture.storage.loads, 0);
  // Opening the actual shell starts lazy initialization. Configuring this Agent
  // first would initialize it and skip the entire header state under test.
  await tester.pumpWidget(
    WorkspaceHarness(
      provider: fixture.app,
      textScale: scale,
      textDirection: direction,
    ),
  );
  await selectAgentShellDestination(tester, 'agent');
  await _until(
    tester,
    () =>
        fixture.storage.loads == 1 &&
        _key('agent-initialization-header').evaluate().length == 1,
    'the real lazy Agent load and its initial header',
  );
  AnimationController? workspaceTransition;
  _key(
    'adaptive-workspace-transition-scale',
  ).evaluate().single.visitAncestorElements((element) {
    final widget = element.widget;
    if (widget is AnimatedBuilder && widget.animation is AnimationController) {
      workspaceTransition = widget.animation as AnimationController;
      return false;
    }
    return true;
  });
  expect(workspaceTransition, isNotNull);
  // The loading indicator keeps ticking; wait only for the workspace entry
  // transition to complete before measuring its effective target geometry.
  await _until(
    tester,
    () => !workspaceTransition!.isAnimating,
    'the Agent workspace entry transition to finish',
  );
  fixture.observeInitialization();
  expect(tester.widget<AgentPage>(find.byType(AgentPage)).embedded, isTrue);
  expect(
    tester.widget<WorkspaceFrame>(_key('agent-workspace-frame')).active,
    isTrue,
  );
  return fixture;
}

bool _belongsTo(RenderObject owner, Object target) {
  if (target is! RenderObject) return false;
  RenderObject? current = target;
  while (current != null) {
    if (identical(current, owner)) return true;
    current = current.parent;
  }
  return false;
}

void _expectHit(WidgetTester tester, Finder target, {required bool touch}) {
  expect(target.hitTestable(), findsOneWidget);
  final rect = tester.getRect(target);
  final screen =
      Offset.zero & (tester.view.physicalSize / tester.view.devicePixelRatio);
  expect(rect.left, greaterThanOrEqualTo(screen.left - 0.5));
  expect(rect.right, lessThanOrEqualTo(screen.right + 0.5));
  expect(rect.top, greaterThanOrEqualTo(screen.top - 0.5));
  expect(rect.bottom, lessThanOrEqualTo(screen.bottom + 0.5));
  if (touch) {
    expect(rect.width, greaterThanOrEqualTo(48));
    expect(rect.height, greaterThanOrEqualTo(48));
  }
  final owner = tester.renderObject(target);
  for (final x in [rect.left + 2, rect.center.dx, rect.right - 2]) {
    for (final y in [rect.top + 2, rect.center.dy, rect.bottom - 2]) {
      final hit = tester.hitTestOnBinding(Offset(x, y));
      expect(
        hit.path.any((entry) => _belongsTo(owner, entry.target)),
        isTrue,
        reason:
            '$target must receive ($x, $y) in $rect; hit path: '
            '${hit.path.map((entry) => entry.target.runtimeType).join(", ")}',
      );
    }
  }
}

Future<void> _expectHeader(
  WidgetTester tester,
  _Fixture fixture,
  _Layout layout,
) async {
  final header = _key('agent-initialization-header');
  final context = tester.element(header);
  final l = AppLocalizations.of(context);
  final metrics = WorkbenchChromeMetrics.of(context);
  final headerRect = tester.getRect(header);
  expect(headerRect.height, closeTo(metrics.toolbarHeight, 0.5));
  final visibleNavigation = _visibleMainNavigation();
  expect(
    visibleNavigation,
    isNotNull,
    reason: 'The current Agent shell must expose reachable main navigation.',
  );
  final navigation = visibleNavigation!;
  final settings = _key('agent-initialization-settings');
  final touch = layout.platform == TargetPlatform.android;
  for (final control in [navigation, settings]) {
    _expectHit(tester, control, touch: touch);
  }
  final navigationInHeader = find
      .descendant(of: header, matching: navigation)
      .evaluate()
      .isNotEmpty;
  for (final control in [settings, if (navigationInHeader) navigation]) {
    final rect = tester.getRect(control);
    expect(rect.top, greaterThanOrEqualTo(headerRect.top - 0.5));
    expect(rect.bottom, lessThanOrEqualTo(headerRect.bottom + 0.5));
  }
  final title = find.descendant(of: header, matching: find.text(l.agentTitle));
  expect(title, findsOneWidget);
  final captions = [
    find.bySemanticsLabel(l.minimizeWindow),
    find.bySemanticsLabel(l.maximizeWindow),
    find.bySemanticsLabel(l.closeWindow),
  ];
  if (layout.platform != TargetPlatform.windows) {
    for (final caption in captions) {
      expect(caption, findsNothing);
    }
    return;
  }
  for (final caption in captions) {
    _expectHit(tester, caption, touch: false);
  }
  final captionRects = captions.map(tester.getRect).toList();
  final captionRect = captionRects.reduce((a, b) => a.expandToInclude(b));
  expect(captionRect.right, closeTo(layout.size.width, 0.5));
  expect(captionRect.width, closeTo(metrics.captionWidth, 0.5));
  expect(captionRect.top, closeTo(headerRect.top, 0.5));
  expect(captionRect.height, closeTo(metrics.toolbarHeight, 0.5));
  for (final control in [title, navigation, settings]) {
    expect(tester.getRect(control).overlaps(captionRect), isFalse);
  }
  expect(
    find.ancestor(of: title, matching: find.byType(DesktopDragRegion)),
    findsOneWidget,
  );
  fixture.windowCalls.clear();
  await tester.dragFrom(
    tester.getRect(title).center,
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

Future<void> _settingsRoundTrip(WidgetTester tester) async {
  final pageState = tester.state(find.byType(AgentPage));
  await tester.tap(_key('agent-initialization-settings').hitTestable());
  await _until(
    tester,
    () => find.byType(AgentSettingsPage).hitTestable().evaluate().length == 1,
    'initialization settings to open its overview',
  );
  final settings = find.byType(AgentSettingsPage).hitTestable();
  final route = ModalRoute.of(tester.element(settings))!;
  expect(route.isCurrent, isTrue);
  await _until(
    tester,
    () => route.animation?.status == AnimationStatus.completed,
    'the settings route entry transition to finish before testing its Back target',
  );
  final back = find
      .descendant(of: settings, matching: find.byType(BackButton))
      .hitTestable();
  expect(back, findsOneWidget);
  await tester.tap(back);
  await _finishWithFrames(tester, route.completed.then<void>((_) {}));
  await _until(
    tester,
    () =>
        find.byType(AgentSettingsPage).evaluate().isEmpty &&
        _visibleMainNavigation() != null &&
        _key('agent-initialization-settings').hitTestable().evaluate().length ==
            1,
    'the same initial Agent shell after the settings route retires',
  );
  expect(tester.state(find.byType(AgentPage)), same(pageState));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final layout in _layouts) {
    for (final scale in [1.0, 2.0]) {
      for (final direction in TextDirection.values) {
        testWidgets(
          '${layout.name} initializing and failed Agent share the main toolbar at ${scale}x in $direction',
          (tester) async {
            final semantics = tester.ensureSemantics();
            try {
              final fixture = await _mount(tester, layout, scale, direction);
              final l = AppLocalizations.of(
                tester.element(find.byType(AgentPage)),
              );
              expect(find.text(l.agentInitializing), findsOneWidget);
              expect(fixture.app.agent.initializationError, isFalse);
              await _expectHeader(tester, fixture, layout);
              await _settingsRoundTrip(tester);
              expect(find.text(l.agentInitializing), findsOneWidget);

              await tester.runAsync(() async => fixture.storage.failLoad());
              await _finishWithFrames(tester, fixture.initialization!);
              fixture.expectStorageFailure();
              await _until(
                tester,
                () =>
                    _key('agent-initialization-reason').evaluate().length == 1,
                'the failed Agent state to publish its redacted storage reason',
              );
              expect(find.text(l.agentInitializationFailed), findsOneWidget);
              expect(
                find.text(l.agentInitializationConversationStorage),
                findsOneWidget,
              );
              expect(find.text(_storageError), findsNothing);
              await _expectHeader(tester, fixture, layout);
              await _settingsRoundTrip(tester);
              await _until(
                tester,
                () => fixture.app.agent.initializationError,
                'settings initialization failure to settle',
              );
              expect(find.text(l.agentInitializationFailed), findsOneWidget);
              expect(fixture.storage.saves, 0);
              expect(tester.takeException(), isNull);
            } finally {
              semantics.dispose();
            }
          },
          variant: TargetPlatformVariant.only(layout.platform),
        );
      }
    }
  }
}
