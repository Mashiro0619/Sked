import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/services/desktop_window_bridge.dart';
import 'package:sked/widgets/adaptive_navigation_scope.dart';
import 'package:sked/widgets/desktop_window_host.dart';
import 'package:sked/widgets/settings_page_header.dart';
import 'package:sked/widgets/workbench_chrome_metrics.dart';

const _windowChannel = MethodChannel('com.mashiro.sked/window');
const _title = '设置';
const _saveKey = ValueKey('settings-caption-save');

class _Clicks {
  int back = 0;
  int save = 0;
}

Widget _harness({
  required DesktopWindowModalObserver observer,
  required double scale,
  required TextDirection direction,
  required bool toolbar,
  required bool wide,
  required bool withSave,
  required _Clicks clicks,
}) => MaterialApp(
  theme: ThemeData(
    platform: TargetPlatform.windows,
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff6750a4)),
  ),
  locale: const Locale('en'),
  localizationsDelegates: appLocalizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  navigatorObservers: [observer],
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: Directionality(
      textDirection: direction,
      child: DesktopWindowHost(modalObserver: observer, child: child!),
    ),
  ),
  home: AdaptiveNavigationScope(
    wide: wide,
    child: Builder(
      builder: (context) {
        final header = SettingsPageHeader(
          title: _title,
          toolbar: toolbar,
          onBack: () => clicks.back++,
          actions: [
            if (withSave)
              TextButton(
                key: _saveKey,
                onPressed: () => clicks.save++,
                child: const Text('保存'),
              ),
          ],
        );
        return Scaffold(
          body: toolbar
              ? Column(
                  children: [
                    SizedBox(
                      height: WorkbenchChromeMetrics.of(context).toolbarHeight,
                      child: header,
                    ),
                    const Expanded(child: SizedBox.expand()),
                  ],
                )
              : CustomScrollView(
                  slivers: [
                    header,
                    const SliverToBoxAdapter(child: SizedBox(height: 1400)),
                  ],
                ),
        );
      },
    ),
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

Iterable<Offset> _ninePoints(Rect rect) sync* {
  for (final x in [rect.left + 2, rect.center.dx, rect.right - 2]) {
    for (final y in [rect.top + 2, rect.center.dy, rect.bottom - 2]) {
      yield Offset(x, y);
    }
  }
}

Rect _expectTarget(WidgetTester tester, Finder target) {
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
  for (final point in _ninePoints(rect)) {
    final hit = tester.hitTestOnBinding(point);
    expect(
      hit.path.any((entry) => _belongsTo(owner, entry.target)),
      isTrue,
      reason:
          '$target must receive $point in $rect; hit path: '
          '${hit.path.map((entry) => entry.target.runtimeType).join(", ")}',
    );
  }
  return rect;
}

Future<void> _tapNine(WidgetTester tester, Finder target) async {
  for (final point in _ninePoints(tester.getRect(target))) {
    await tester.tapAt(point, kind: PointerDeviceKind.mouse);
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void _expectContentRect(Rect rect, Rect toolbar, Rect caption) {
  expect(rect.top, greaterThanOrEqualTo(toolbar.top - 0.5));
  expect(rect.bottom, lessThanOrEqualTo(toolbar.bottom + 0.5));
  expect(rect.left, greaterThanOrEqualTo(toolbar.left - 0.5));
  expect(rect.right, lessThanOrEqualTo(caption.left + 0.5));
  expect(rect.overlaps(caption), isFalse);
}

Future<void> _checkLayout(
  WidgetTester tester, {
  required double width,
  required TextDirection direction,
  required bool wide,
  required bool withSave,
  required _Clicks clicks,
  required List<String> windowCalls,
}) async {
  final header = find.byType(SettingsPageHeader);
  expect(header, findsOneWidget);
  expect(find.byType(DesktopWindowHost), findsOneWidget);
  final metrics = WorkbenchChromeMetrics.of(tester.element(header));
  final appBar = find.descendant(
    of: header,
    matching: find.byWidgetPredicate((widget) => widget is AppBar),
  );
  expect(appBar, findsOneWidget);
  final barRect = tester.getRect(appBar);
  expect(barRect, Rect.fromLTWH(0, 0, width, metrics.toolbarHeight));
  final l = AppLocalizations.of(tester.element(header));
  final captions = [
    find.bySemanticsLabel(l.minimizeWindow),
    find.bySemanticsLabel(l.maximizeWindow),
    find.bySemanticsLabel(l.closeWindow),
  ];
  final captionRects = [
    for (final caption in captions) _expectTarget(tester, caption),
  ];
  final captionRect = captionRects.reduce((a, b) => a.expandToInclude(b));
  expect(captionRect.right, closeTo(width, 0.5));
  expect(captionRect.width, closeTo(metrics.captionWidth, 0.5));
  expect(captionRect.top, closeTo(barRect.top, 0.5));
  expect(captionRect.height, closeTo(metrics.toolbarHeight, 0.5));
  for (var index = 0; index < captionRects.length; index++) {
    expect(
      captionRects[index].left,
      closeTo(captionRect.left + index * metrics.captionButtonWidth, 0.5),
    );
  }
  final spacer = find.descendant(
    of: header,
    matching: find.byType(DesktopCaptionSpacer),
  );
  expect(spacer, findsOneWidget);
  expect(tester.getRect(spacer).right, closeTo(captionRect.right, 0.5));
  expect(tester.getSize(spacer).width, closeTo(metrics.captionWidth, 0.5));

  final title = find.descendant(of: header, matching: find.text(_title));
  expect(title, findsOneWidget);
  expect(Directionality.of(tester.element(title)), direction);
  expect(tester.renderObject<RenderParagraph>(title).textDirection, direction);
  final titleViewport = find.descendant(
    of: header,
    matching: find.byKey(const ValueKey('settings-compact-title-scroll')),
  );
  expect(titleViewport, findsOneWidget);
  final titleRect = tester.getRect(titleViewport);
  _expectContentRect(titleRect, barRect, captionRect);
  expect(titleRect.contains(tester.getRect(title).center), isTrue);
  final titleScroll = find.descendant(
    of: titleViewport,
    matching: find.byType(Scrollable),
  );
  expect(titleScroll, findsOneWidget);
  expect(
    tester.state<ScrollableState>(titleScroll).position.maxScrollExtent,
    0,
    reason: 'The short title must leave its drag gesture available.',
  );

  final back = find.descendant(of: header, matching: find.byType(BackButton));
  if (wide) {
    expect(back, findsNothing);
  } else {
    final backRect = _expectTarget(tester, back);
    _expectContentRect(backRect, barRect, captionRect);
    expect(backRect.overlaps(titleRect), isFalse);
    expect(Directionality.of(tester.element(back)), direction);
    final backIcon = find.descendant(
      of: back,
      matching: find.byType(BackButtonIcon),
    );
    expect(backIcon, findsOneWidget);
    expect(Directionality.of(tester.element(backIcon)), direction);
    final icon = find.descendant(of: backIcon, matching: find.byType(Icon));
    expect(icon, findsOneWidget);
    expect(tester.widget<Icon>(icon).icon!.matchTextDirection, isTrue);
    windowCalls.clear();
    await _tapNine(tester, back);
    expect(clicks.back, 9);
    expect(windowCalls, isNot(contains('startDrag')));
  }

  final save = find.byKey(_saveKey);
  if (withSave) {
    final saveRect = _expectTarget(tester, save);
    _expectContentRect(saveRect, barRect, captionRect);
    expect(saveRect.overlaps(titleRect), isFalse);
    expect(Directionality.of(tester.element(save)), direction);
    windowCalls.clear();
    await _tapNine(tester, save);
    expect(clicks.save, 9);
    expect(windowCalls, isNot(contains('startDrag')));
  } else {
    expect(save, findsNothing);
    expect(clicks.save, 0);
  }

  windowCalls.clear();
  // Short and long titles retain their horizontal reading host. Drag through
  // the toolbar's title spacing, outside that host and all action targets.
  final dragPoint = Offset(
    direction == TextDirection.ltr ? titleRect.left - 8 : titleRect.right + 8,
    barRect.center.dy,
  );
  expect(barRect.contains(dragPoint), isTrue);
  expect(titleRect.contains(dragPoint), isFalse);
  expect(captionRect.contains(dragPoint), isFalse);
  await tester.dragFrom(
    dragPoint,
    const Offset(36, 0),
    kind: PointerDeviceKind.mouse,
  );
  await tester.pumpAndSettle();
  expect(windowCalls.where((method) => method == 'startDrag'), hasLength(1));
  expect(clicks.back, wide ? 0 : 9);
  expect(clicks.save, withSave ? 9 : 0);
  expect(tester.takeException(), isNull);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final width in [600.0, 1200.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final direction in TextDirection.values) {
        for (final toolbar in [true, false]) {
          testWidgets(
            'Windows ${width}dp ${scale}x $direction ${toolbar ? "toolbar" : "compact sliver"} reserves physical captions for Back and optional Save',
            (tester) async {
              tester.view.devicePixelRatio = 1;
              tester.view.physicalSize = Size(width, 900);
              addTearDown(tester.view.reset);
              final semantics = tester.ensureSemantics();
              try {
                final bridge = DesktopWindowBridge.instance;
                bridge.available = false;
                bridge.prepareClose = null;
                final windowCalls = <String>[];
                final observer = DesktopWindowModalObserver();
                final messenger = TestDefaultBinaryMessengerBinding
                    .instance
                    .defaultBinaryMessenger;
                messenger.setMockMethodCallHandler(_windowChannel, (
                  call,
                ) async {
                  windowCalls.add(call.method);
                  return switch (call.method) {
                    'initialize' => {
                      'maximized': false,
                      'focused': true,
                      'maximizeHovered': false,
                    },
                    'configureChrome' ||
                    'startDrag' ||
                    'toggleMaximize' ||
                    'systemMenu' ||
                    'minimize' ||
                    'confirmClose' => null,
                    _ => throw StateError(
                      'Unexpected window method: ${call.method}',
                    ),
                  };
                });
                addTearDown(() async {
                  try {
                    await tester.pumpWidget(const SizedBox.shrink());
                    await tester.pumpAndSettle();
                  } finally {
                    observer.dispose();
                    bridge.available = false;
                    bridge.prepareClose = null;
                    messenger.setMockMethodCallHandler(_windowChannel, null);
                  }
                });
                await bridge.initialize();
                expect(bridge.available, isTrue);
                // Wide is the caller's navigation state, not a header breakpoint.
                for (final wide in [false, true]) {
                  for (final withSave in [false, true]) {
                    final clicks = _Clicks();
                    await tester.pumpWidget(
                      _harness(
                        observer: observer,
                        scale: scale,
                        direction: direction,
                        toolbar: toolbar,
                        wide: wide,
                        withSave: withSave,
                        clicks: clicks,
                      ),
                    );
                    await tester.pumpAndSettle();
                    await _checkLayout(
                      tester,
                      width: width,
                      direction: direction,
                      wide: wide,
                      withSave: withSave,
                      clicks: clicks,
                      windowCalls: windowCalls,
                    );
                  }
                }
              } finally {
                semantics.dispose();
              }
            },
            variant: TargetPlatformVariant.only(TargetPlatform.windows),
          );
        }
      }
    }
  }
}
