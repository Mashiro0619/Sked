import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/services/desktop_window_bridge.dart';
import 'package:sked/widgets/desktop_window_host.dart';
import 'package:sked/widgets/sked_expressive_components.dart';

Widget _modalHarness({
  required DesktopWindowModalObserver observer,
  required GlobalKey<NavigatorState> navigatorKey,
  GlobalKey? boundaryKey,
  Brightness brightness = Brightness.light,
  double textScale = 1,
  Widget? body,
}) => RepaintBoundary(
  key: boundaryKey,
  child: MaterialApp(
    navigatorKey: navigatorKey,
    navigatorObservers: [observer],
    theme: ThemeData(
      platform: TargetPlatform.windows,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff6750a4),
        brightness: brightness,
      ),
    ),
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: DesktopWindowHost(modalObserver: observer, child: child!),
    ),
    home: Scaffold(
      appBar: WorkbenchAppBar(title: const Text('Workspace')),
      body: body ?? const Text('Calendar'),
    ),
  ),
);

Future<List<Color>> _pixels(
  WidgetTester tester,
  GlobalKey boundary,
  List<Offset> positions,
) async => (await tester.runAsync(() async {
  final render =
      boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await render.toImage(pixelRatio: 1);
  try {
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    return positions.map((p) {
      final offset = (p.dy.floor() * image.width + p.dx.floor()) * 4;
      return Color.fromARGB(
        bytes.getUint8(offset + 3),
        bytes.getUint8(offset),
        bytes.getUint8(offset + 1),
        bytes.getUint8(offset + 2),
      );
    }).toList();
  } finally {
    image.dispose();
  }
}))!;

void _expectPaint(Color actual, Color expected) {
  expect(actual.r, closeTo(expected.r, 2 / 255));
  expect(actual.g, closeTo(expected.g, 2 / 255));
  expect(actual.b, closeTo(expected.b, 2 / 255));
  expect(actual.a, closeTo(expected.a, 2 / 255));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.mashiro.sked/window');
  final calls = <String>[];
  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return call.method == 'initialize'
              ? {'maximized': false, 'focused': true}
              : null;
        });
    await DesktopWindowBridge.instance.initialize();
    debugDefaultTargetPlatformOverride = null;
  });
  tearDown(() {
    DesktopWindowBridge.instance.available = false;
    DesktopWindowBridge.instance.prepareClose = null;
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  testWidgets(
    'caption buttons share the application row and ordinary actions are not delayed by dragging',
    (tester) async {
      var count = 0;
      final modalObserver = DesktopWindowModalObserver();
      addTearDown(modalObserver.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.windows),
          navigatorObservers: [modalObserver],
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) =>
              DesktopWindowHost(modalObserver: modalObserver, child: child!),
          home: Scaffold(
            appBar: WorkbenchAppBar(
              title: const Text('Workspace'),
              actions: [
                TextButton(
                  onPressed: () => count++,
                  child: const Text('Action'),
                ),
              ],
            ),
            body: const Text('Calendar'),
          ),
        ),
      );
      expect(find.text('Calendar'), findsOneWidget);
      expect(find.bySemanticsLabel('Minimize'), findsOneWidget);
      await tester.tap(find.text('Action'));
      await tester.pump();
      expect(
        count,
        1,
        reason: 'A title-bar drag recognizer must not delay or swallow button taps.',
      );
      await tester.tap(find.bySemanticsLabel('Minimize'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Maximize'));
      await tester.pump();
      DesktopWindowBridge.instance.prepareClose = () async => false;
      await tester.tap(find.bySemanticsLabel('Close window'));
      await tester.pump();
      expect(calls, containsAll(['minimize', 'toggleMaximize']));
      expect(calls, isNot(contains('confirmClose')));
      DesktopWindowBridge.instance.prepareClose = () async => true;
      await tester.tap(find.bySemanticsLabel('Close window'));
      await tester.pump();
      expect(calls, contains('confirmClose'));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'workbench Material surface does not swallow empty toolbar dragging',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                SkedWorkspaceToolbar(
                  title: const SizedBox(width: 80, height: 40),
                  actions: [
                    IconButton(onPressed: () {}, icon: const Icon(Icons.add)),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      await tester.dragFrom(const Offset(400, 28), const Offset(80, 0));
      await tester.pump(const Duration(milliseconds: 600));
      expect(calls, contains('startDrag'));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'empty drag regions route movement, double click and system menu natively',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DesktopDragRegion(child: SizedBox(width: 600, height: 100)),
          ),
        ),
      );
      await tester.drag(find.byType(DesktopDragRegion), const Offset(100, 0));
      await tester.pump();
      expect(calls, contains('startDrag'));
      await tester.tapAt(const Offset(50, 50));
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tapAt(const Offset(50, 50));
      await tester.pump();
      expect(calls, contains('toggleMaximize'));
      final pointer = await tester.createGesture(buttons: 2);
      await pointer.down(const Offset(60, 50));
      await pointer.up();
      await tester.pump();
      expect(calls, contains('systemMenu'));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  final modalStyles = ValueVariant<(Brightness, double)>({
    (Brightness.light, 1),
    (Brightness.dark, 2),
  });
  testWidgets(
    'dialog scrim covers caption and divider without double-dimming the toolbar',
    (tester) async {
      final (brightness, scale) = modalStyles.currentValue!;
      final observer = DesktopWindowModalObserver();
      addTearDown(observer.dispose);
      final navigator = GlobalKey<NavigatorState>();
      final boundary = GlobalKey();
      await tester.pumpWidget(
        _modalHarness(
          observer: observer,
          navigatorKey: navigator,
          boundaryKey: boundary,
          brightness: brightness,
          textScale: scale,
        ),
      );
      await tester.pumpAndSettle();
      final divider = tester.getRect(
        find.byKey(const ValueKey('desktop-window-divider')),
      );
      final points = [
        const Offset(420, 6),
        const Offset(788, 6),
        Offset(420, divider.center.dy),
        Offset(788, divider.center.dy),
      ];
      final before = await _pixels(tester, boundary, points);
      _expectPaint(before[0], before[1]);
      _expectPaint(before[2], before[3]);
      const barrier = Color(0x99330066);
      unawaited(
        showDialog<void>(
          context: navigator.currentContext!,
          barrierColor: barrier,
          builder: (_) => const AlertDialog(title: Text('Modal task')),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 75));
      final midBarrier = tester
          .widget<AnimatedModalBarrier>(find.byType(AnimatedModalBarrier))
          .color
          .value!;
      expect(midBarrier.a, greaterThan(0));
      expect(midBarrier.a, lessThan(barrier.a));
      _expectPaint(observer.scrimColor, midBarrier);
      final middle = await _pixels(tester, boundary, points);
      for (var i = 0; i < points.length; i++) {
        _expectPaint(middle[i], Color.alphaBlend(midBarrier, before[i]));
      }
      await tester.pumpAndSettle();
      final covered = await _pixels(tester, boundary, points);
      for (var i = 0; i < points.length; i++) {
        _expectPaint(covered[i], Color.alphaBlend(barrier, before[i]));
      }
      _expectPaint(covered[0], covered[1]);
      _expectPaint(covered[2], covered[3]);
      expect(
        find.byType(AnimatedModalBarrier),
        findsOneWidget,
        reason: 'Chrome mirrors paint, not a second gesture/semantics barrier',
      );

      await tester.tap(find.bySemanticsLabel('Minimize'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Maximize'));
      await tester.pump();
      DesktopWindowBridge.instance.prepareClose = () async => false;
      await tester.tap(find.bySemanticsLabel('Close window'));
      await tester.pump();
      expect(calls, containsAll(['minimize', 'toggleMaximize']));
      expect(calls, isNot(contains('confirmClose')));
      expect(find.text('Modal task'), findsOneWidget);
      navigator.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final fading = tester
          .widget<AnimatedModalBarrier>(find.byType(AnimatedModalBarrier))
          .color
          .value!;
      expect(fading.a, greaterThan(0));
      _expectPaint(observer.scrimColor, fading);
      await tester.pumpAndSettle();
      expect(observer.scrimColor.a, 0);
      final restored = await _pixels(tester, boundary, points);
      for (var i = 0; i < points.length; i++) {
        _expectPaint(restored[i], before[i]);
      }
      expect(tester.takeException(), isNull);
    },
    variant: modalStyles,
  );

  testWidgets(
    'stacked dialogs retain the lower scrim throughout reverse and removal',
    (tester) async {
      final observer = DesktopWindowModalObserver();
      addTearDown(observer.dispose);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        _modalHarness(observer: observer, navigatorKey: navigator),
      );
      await tester.pumpAndSettle();
      const firstColor = Color(0x66331155);
      const secondColor = Color(0x88003355);
      final first = DialogRoute<void>(
        context: navigator.currentContext!,
        barrierColor: firstColor,
        builder: (_) => const AlertDialog(title: Text('First')),
      );
      final second = DialogRoute<void>(
        context: navigator.currentContext!,
        barrierColor: secondColor,
        builder: (_) => const AlertDialog(title: Text('Second')),
      );
      unawaited(navigator.currentState!.push(first));
      await tester.pumpAndSettle();
      unawaited(navigator.currentState!.push(second));
      await tester.pumpAndSettle();
      _expectPaint(
        observer.scrimColor,
        Color.alphaBlend(secondColor, firstColor),
      );
      navigator.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final fading = second.barrierCurve.transform(second.animation!.value);
      _expectPaint(
        observer.scrimColor,
        Color.alphaBlend(
          Color.lerp(secondColor.withValues(alpha: 0), secondColor, fading)!,
          firstColor,
        ),
      );
      await tester.pumpAndSettle();
      _expectPaint(observer.scrimColor, firstColor);
      navigator.currentState!.removeRoute(first);
      await tester.pumpAndSettle();
      expect(observer.scrimColor.a, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'transparent menus and opaque pages do not leave a stale window scrim',
    (tester) async {
      final observer = DesktopWindowModalObserver();
      addTearDown(observer.dispose);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        _modalHarness(observer: observer, navigatorKey: navigator),
      );
      await tester.pumpAndSettle();
      unawaited(
        showMenu<int>(
          context: navigator.currentContext!,
          position: const RelativeRect.fromLTRB(100, 100, 0, 0),
          items: const [PopupMenuItem(value: 1, child: Text('Menu item'))],
        ),
      );
      await tester.pumpAndSettle();
      expect(observer.scrimColor.a, 0);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      final dialog = DialogRoute<void>(
        context: navigator.currentContext!,
        barrierColor: Colors.black54,
        builder: (_) => const AlertDialog(title: Text('Underlying dialog')),
      );
      unawaited(navigator.currentState!.push(dialog));
      await tester.pumpAndSettle();
      final page = MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: WorkbenchAppBar(title: const Text('Independent page')),
        ),
      );
      unawaited(navigator.currentState!.push(page));
      await tester.pumpAndSettle();
      expect(observer.scrimColor.a, 0);
      navigator.currentState!.replace(
        oldRoute: dialog,
        newRoute: DialogRoute<void>(
          context: navigator.currentContext!,
          barrierColor: Colors.black26,
          builder: (_) => const AlertDialog(title: Text('Replaced dialog')),
        ),
      );
      await tester.pumpAndSettle();
      expect(observer.scrimColor.a, 0);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      _expectPaint(observer.scrimColor, Colors.black26);
      navigator.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'only a root modal, not a pane-local dialog, dims window controls',
    (tester) async {
      final observer = DesktopWindowModalObserver();
      addTearDown(observer.dispose);
      final navigator = GlobalKey<NavigatorState>();
      final pane = GlobalKey<NavigatorState>();
      late BuildContext paneContext;
      await tester.pumpWidget(
        _modalHarness(
          observer: observer,
          navigatorKey: navigator,
          body: Navigator(
            key: pane,
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (context) {
                paneContext = context;
                return const Text('Pane');
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      unawaited(
        showDialog<void>(
          context: paneContext,
          useRootNavigator: false,
          builder: (_) => const AlertDialog(title: Text('Local modal')),
        ),
      );
      await tester.pumpAndSettle();
      expect(observer.scrimColor.a, 0);
      pane.currentState!.pop();
      await tester.pumpAndSettle();
      unawaited(
        showModalBottomSheet<void>(
          context: paneContext,
          useRootNavigator: true,
          barrierColor: const Color(0x77335577),
          builder: (_) =>
              const SizedBox(height: 120, child: Text('Root sheet')),
        ),
      );
      await tester.pumpAndSettle();
      _expectPaint(observer.scrimColor, const Color(0x77335577));
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(observer.scrimColor.a, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
