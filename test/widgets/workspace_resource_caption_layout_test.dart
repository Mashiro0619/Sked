import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/desktop_window_bridge.dart';
import 'package:sked/widgets/desktop_window_host.dart';
import 'package:sked/widgets/workbench_chrome_metrics.dart';
import 'package:sked/widgets/workspace_frame.dart';

import '../support/mobile_layout_data.dart';
import '../support/agent_workspace_navigation.dart';
import '../support/workspace_harness.dart';

const _windowChannel = MethodChannel('com.mashiro.sked/window');

Finder _key(String value) => find.byKey(ValueKey(value));
Finder get _collapse => _key('workspace-resource-collapse');
Finder get _canvas => _key('workspace-canvas');
Finder get _scrim => _key('workspace-resource-scrim');
Finder get _panel => _key('workspace-resource-panel');

class _Storage extends WorkspaceMemoryStorage {
  _Storage(super.data);

  int writes = 0;

  @override
  Future<void> save(AppData value) async {
    writes++;
    await super.save(value);
  }
}

class _Fixture {
  _Fixture(this.app, this.storage, this.windowCalls);

  final AppRuntime app;
  final _Storage storage;
  final List<String> windowCalls;
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
    reason: 'The actual runtime cleanup must complete.',
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
  await tester.pumpAndSettle();
}

Future<_Fixture> _mount(
  WidgetTester tester, {
  required Size size,
  double scale = 1,
  TextDirection direction = TextDirection.rtl,
  bool native = true,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  final bridge = DesktopWindowBridge.instance;
  bridge.available = false;
  bridge.prepareClose = null;
  final windowCalls = <String>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  AppRuntime? owner;
  messenger.setMockMethodCallHandler(_windowChannel, (call) async {
    windowCalls.add(call.method);
    return switch (call.method) {
      'initialize' =>
        native
            ? {'maximized': false, 'focused': true, 'maximizeHovered': false}
            : null,
      'configureChrome' ||
      'startDrag' ||
      'toggleMaximize' ||
      'systemMenu' ||
      'minimize' ||
      'confirmClose' => null,
      _ => throw StateError('Unexpected window method: ${call.method}'),
    };
  });
  addTearDown(() async {
    try {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    } finally {
      try {
        if (owner case final app?) {
          try {
            await _finishWithFrames(tester, app.shutdown.quiesce());
          } finally {
            await tester.runAsync(() async => app.dispose());
            await _finishWithFrames(tester, app.session.close());
          }
        }
      } finally {
        bridge.available = false;
        bridge.prepareClose = null;
        messenger.setMockMethodCallHandler(_windowChannel, null);
      }
    }
  });
  await tester.runAsync(bridge.initialize);
  expect(bridge.available, native);
  final storage = _Storage(
    mobileLayoutData(locale: 'en').copyWith(
      activeMode: AppMode.student,
      homeWorkspaceNavigationCollapsed: false,
      hideHomeWorkspaceNavigation: false,
    ),
  );
  final app = (await tester.runAsync(
    () => workspaceProvider(storage: storage),
  ))!;
  owner = app;
  await tester.pumpWidget(
    WorkspaceHarness(provider: app, textScale: scale, textDirection: direction),
  );
  await tester.pumpAndSettle();
  expect(find.byType(DesktopWindowHost), findsOneWidget);
  expect(find.byType(WorkspaceFrame).hitTestable(), findsOneWidget);
  expect(app.workspaceView.activeMode, AppMode.student);
  return _Fixture(app, storage, windowCalls);
}

WorkspaceLayout _layout(WidgetTester tester) =>
    WorkspaceCanvasScope.maybeOf(tester.element(_canvas))!;

bool _drawerOpen() => _scrim.evaluate().isNotEmpty;

WorkbenchChromeMetrics _metrics(WidgetTester tester) =>
    WorkbenchChromeMetrics.of(tester.element(_canvas));

bool _belongsTo(RenderObject owner, Object target) {
  if (target is! RenderObject) return false;
  RenderObject? current = target;
  while (current != null) {
    if (identical(current, owner)) return true;
    current = current.parent;
  }
  return false;
}

Rect _expectNineHits(WidgetTester tester, Finder target) {
  expect(target, findsOneWidget);
  expect(target.hitTestable(), findsOneWidget);
  final rect = tester.getRect(target);
  final screen =
      Offset.zero & (tester.view.physicalSize / tester.view.devicePixelRatio);
  expect(rect.width, greaterThanOrEqualTo(32));
  expect(rect.height, greaterThanOrEqualTo(32));
  expect(rect.left, greaterThanOrEqualTo(screen.left - 0.5));
  expect(rect.right, lessThanOrEqualTo(screen.right + 0.5));
  expect(rect.top, greaterThanOrEqualTo(screen.top - 0.5));
  expect(rect.bottom, lessThanOrEqualTo(screen.bottom + 0.5));
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
  return rect;
}

Rect? _captionRect(WidgetTester tester, {required bool native}) {
  final l = AppLocalizations.of(tester.element(_canvas));
  final captions = [
    find.bySemanticsLabel(l.minimizeWindow),
    find.bySemanticsLabel(l.maximizeWindow),
    find.bySemanticsLabel(l.closeWindow),
  ];
  if (!native) {
    for (final caption in captions) {
      expect(caption, findsNothing);
    }
    return null;
  }
  final metrics = _metrics(tester);
  final rects = [
    for (final caption in captions) _expectNineHits(tester, caption),
  ];
  final rect = rects.reduce((a, b) => a.expandToInclude(b));
  final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
  expect(rect.right, closeTo(width, 0.5));
  expect(rect.top, closeTo(0, 0.5));
  expect(rect.width, closeTo(metrics.captionWidth, 0.5));
  expect(rect.height, closeTo(metrics.toolbarHeight, 0.5));
  return rect;
}

Rect _expectHeader(
  WidgetTester tester, {
  required double top,
  bool native = true,
  TextDirection direction = TextDirection.rtl,
}) {
  final button = _expectNineHits(tester, _collapse);
  final header = find.ancestor(
    of: _collapse,
    matching: find.byType(DesktopDragRegion),
  );
  expect(header, findsOneWidget);
  final headerRect = tester.getRect(header);
  final panelRect = tester.getRect(_panel);
  final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
  final metrics = _metrics(tester);
  if (direction == TextDirection.rtl) {
    expect(panelRect.right, closeTo(width, 0.5));
  } else {
    expect(panelRect.left, closeTo(0, 0.5));
  }
  expect(headerRect.top, closeTo(top, 0.5));
  expect(headerRect.height, closeTo(metrics.toolbarHeight, 0.5));
  expect(headerRect.left, closeTo(panelRect.left, 0.5));
  expect(headerRect.right, closeTo(panelRect.right, 0.5));
  expect(button.top, greaterThanOrEqualTo(headerRect.top - 0.5));
  expect(button.bottom, lessThanOrEqualTo(headerRect.bottom + 0.5));
  expect(button.left, greaterThanOrEqualTo(panelRect.left - 0.5));
  expect(button.right, lessThanOrEqualTo(panelRect.right + 0.5));
  expect(Directionality.of(tester.element(_collapse)), direction);
  final caption = _captionRect(tester, native: native);
  if (caption != null) expect(button.overlaps(caption), isFalse);
  return headerRect;
}

Future<void> _tapCollapse(
  WidgetTester tester,
  bool Function() ready,
  String description,
) async {
  _expectNineHits(tester, _collapse);
  await tester.tap(_collapse, kind: PointerDeviceKind.mouse);
  await _until(tester, ready, description);
}

Future<void> _openDrawer(
  WidgetTester tester, {
  bool fromMainNavigation = false,
}) async {
  if (fromMainNavigation) {
    final entry = _key('workspace-main-navigation').hitTestable();
    if (entry.evaluate().isNotEmpty) _expectNineHits(tester, entry);
    await openWorkspaceShellResources(tester);
  } else {
    _expectNineHits(tester, _collapse);
    await tester.tap(_collapse, kind: PointerDeviceKind.mouse);
  }
  await _until(tester, _drawerOpen, 'the actual resource drawer to open');
}

void _expectDrawer(WidgetTester tester, {bool native = true}) {
  expect(_scrim, findsOneWidget);
  final surface = tester.getRect(_key('workspace-resource-surface'));
  final top = native ? _metrics(tester).toolbarHeight : 0.0;
  expect(surface.top, closeTo(top, 0.5));
  final header = _expectHeader(tester, top: top, native: native);
  expect(
    header.top,
    closeTo(surface.top, 0.5),
    reason: 'The drawer owns one caption inset, with none added by its header.',
  );
}

void _expectNoWindowCommands(_Fixture fixture) {
  expect(
    fixture.windowCalls.where(
      (method) => method != 'initialize' && method != 'configureChrome',
    ),
    isEmpty,
    reason:
        'Resource gestures must not close, move or control the native window.',
  );
  expect(fixture.app.workspaceView.activeMode, AppMode.student);
}

Future<void> _resize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'Windows RTL ${scale}x resource controls survive natural pane stages and one drawer inset',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          final fixture = await _mount(
            tester,
            size: const Size(1200, 900),
            scale: scale,
          );
          final app = fixture.app;
          final metrics = _metrics(tester);
          expect(app.settingsView.homeWorkspaceNavigationCollapsed, isFalse);
          expect(
            _layout(tester).resourcePresentation,
            scale == 1
                ? WorkspaceResourcePresentation.expanded
                : WorkspaceResourcePresentation.compact,
          );
          _expectHeader(tester, top: scale == 1 ? 0 : metrics.toolbarHeight);
          if (scale == 1) {
            final writes = fixture.storage.writes;
            await _tapCollapse(
              tester,
              () =>
                  app.settingsView.homeWorkspaceNavigationCollapsed &&
                  _layout(tester).resourcePresentation ==
                      WorkspaceResourcePresentation.compact,
              'the real inline collapse to save its preference',
            );
            expect(_drawerOpen(), isFalse);
            expect(fixture.storage.writes, greaterThan(writes));
            _expectHeader(tester, top: metrics.toolbarHeight);
            await _tapCollapse(
              tester,
              () =>
                  !app.settingsView.homeWorkspaceNavigationCollapsed &&
                  _layout(tester).resourcePresentation ==
                      WorkspaceResourcePresentation.expanded,
              'the real inline expansion to save its preference',
            );
            _expectHeader(tester, top: 0);
          } else {
            final writes = fixture.storage.writes;
            await _openDrawer(tester);
            _expectDrawer(tester);
            await _tapCollapse(
              tester,
              () => !_drawerOpen(),
              'the resource Close action to close only its drawer',
            );
            expect(fixture.storage.writes, writes);
          }

          final writes = fixture.storage.writes;
          await _resize(tester, const Size(600, 900));
          expect(
            _layout(tester).resourcePresentation,
            scale == 1
                ? WorkspaceResourcePresentation.compact
                : WorkspaceResourcePresentation.hidden,
          );
          expect(app.settingsView.homeWorkspaceNavigationCollapsed, isFalse);
          if (scale == 1) {
            _expectHeader(tester, top: metrics.toolbarHeight);
          } else {
            expect(_collapse, findsNothing);
          }
          final canvas = tester.getRect(_canvas);
          await _openDrawer(tester, fromMainNavigation: scale == 2);
          _expectDrawer(tester);
          expect(tester.getRect(_canvas), canvas);
          await _tapCollapse(
            tester,
            () => !_drawerOpen(),
            'the narrowed resource drawer to retire',
          );
          expect(fixture.storage.writes, writes);
          await _resize(tester, Size(scale == 1 ? 1200 : 2400, 900));
          expect(_scrim, findsNothing);
          expect(
            _layout(tester).resourcePresentation,
            WorkspaceResourcePresentation.expanded,
          );
          expect(app.settingsView.homeWorkspaceNavigationCollapsed, isFalse);
          expect(fixture.storage.writes, writes);
          _expectHeader(tester, top: 0);
          _expectNoWindowCommands(fixture);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }

  testWidgets(
    'Windows RTL short resource navigation scrolls below fixed caption clearance',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final fixture = await _mount(tester, size: const Size(600, 300));
        final metrics = _metrics(tester);
        expect(
          _layout(tester).resourcePresentation,
          WorkspaceResourcePresentation.compact,
        );
        _expectHeader(tester, top: metrics.toolbarHeight);
        final navigation = find.byKey(
          const PageStorageKey('workspace-resource-navigation-list'),
        );
        expect(navigation, findsOneWidget);
        final scroll = find.descendant(
          of: navigation,
          matching: find.byType(Scrollable),
        );
        expect(scroll, findsOneWidget);
        final position = tester.state<ScrollableState>(scroll).position;
        expect(position.maxScrollExtent, greaterThan(0));
        final viewport = tester.getRect(navigation);
        expect(viewport.top, closeTo(metrics.toolbarHeight, 0.5));
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: viewport.center,
            scrollDelta: const Offset(0, 80),
          ),
        );
        await tester.pumpAndSettle();
        expect(position.pixels, greaterThan(0));
        expect(tester.getRect(navigation), viewport);
        expect(
          viewport.top,
          closeTo(_captionRect(tester, native: true)!.bottom, 0.5),
        );
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: viewport.center,
            scrollDelta: const Offset(0, -100),
          ),
        );
        await tester.pumpAndSettle();
        expect(position.pixels, closeTo(0, 0.5));
        _expectHeader(tester, top: metrics.toolbarHeight);
        final writes = fixture.storage.writes;
        await _openDrawer(tester);
        _expectDrawer(tester);
        await _tapCollapse(
          tester,
          () => !_drawerOpen(),
          'the short-window drawer to close itself',
        );
        expect(fixture.storage.writes, writes);
        expect(
          fixture.app.settingsView.homeWorkspaceNavigationCollapsed,
          isFalse,
        );
        _expectNoWindowCommands(fixture);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  for (final scenario in [
    (direction: TextDirection.ltr, native: true),
    (direction: TextDirection.rtl, native: false),
  ]) {
    testWidgets(
      'Windows ${scenario.direction} native=${scenario.native} retains resource header geometry',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          final fixture = await _mount(
            tester,
            size: const Size(1200, 900),
            direction: scenario.direction,
            native: scenario.native,
          );
          expect(
            _layout(tester).resourcePresentation,
            WorkspaceResourcePresentation.expanded,
          );
          _expectHeader(
            tester,
            top: 0,
            native: scenario.native,
            direction: scenario.direction,
          );
          final panel = tester.getRect(_panel);
          expect(
            tester.getRect(_collapse).center.dx,
            closeTo(
              scenario.direction == TextDirection.ltr
                  ? panel.left + 28
                  : panel.right - 28,
              0.5,
            ),
          );
          final writes = fixture.storage.writes;
          await _resize(tester, const Size(600, 900));
          expect(
            _layout(tester).resourcePresentation,
            WorkspaceResourcePresentation.compact,
          );
          _expectHeader(
            tester,
            top: 0,
            native: scenario.native,
            direction: scenario.direction,
          );
          await _openDrawer(tester);
          final surface = tester.getRect(_key('workspace-resource-surface'));
          final top = scenario.native ? _metrics(tester).toolbarHeight : 0.0;
          expect(surface.top, closeTo(top, 0.5));
          _expectHeader(
            tester,
            top: top,
            native: scenario.native,
            direction: scenario.direction,
          );
          await _tapCollapse(
            tester,
            () => !_drawerOpen(),
            'the unchanged resource drawer behavior to close itself',
          );
          expect(fixture.storage.writes, writes);
          expect(
            fixture.app.settingsView.homeWorkspaceNavigationCollapsed,
            isFalse,
          );
          _expectNoWindowCommands(fixture);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }
}
