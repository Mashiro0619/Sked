import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/general_schedule_home_screen.dart';
import 'package:sked/screens/settings_page.dart';
import 'package:sked/services/desktop_window_bridge.dart';

import '../support/workspace_harness.dart';

Finder _key(String value) => find.byKey(ValueKey(value));
Finder get _bar => _key('adaptive-shell-navigation-bar');
void _viewport(WidgetTester t, Size size) {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = size;
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.view.resetPhysicalSize);
}

Future<Uint8List> _barPixels(WidgetTester t, GlobalKey boundary) async {
  final rect = t.getRect(_bar);
  return (await t.runAsync(() async {
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await render.toImage(pixelRatio: 1);
    try {
      final data = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      return Uint8List.fromList(
        bytes.sublist(
          rect.top.ceil() * image.width * 4,
          rect.bottom.floor() * image.width * 4,
        ),
      );
    } finally {
      image.dispose();
    }
  }))!;
}

void main() {
  const channel = MethodChannel('com.mashiro.sked/window');
  final nativeCalls = <String>[];
  setUp(() {
    nativeCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          nativeCalls.add(call.method);
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      'bottom workspace presses and pointer hover paint no pill or ripple in $brightness',
      (t) async {
        _viewport(t, const Size(393, 850));
        final p = await workspaceProvider();
        addTearDown(p.dispose);
        final boundary = GlobalKey();
        await t.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: WorkspaceHarness(provider: p, brightness: brightness),
          ),
        );
        await t.pumpAndSettle();
        final before = await _barPixels(t, boundary);
        final inkTheme = Theme.of(t.element(_bar));
        expect(inkTheme.splashFactory, same(NoSplash.splashFactory));
        final overlay = t.widget<NavigationBar>(_bar).overlayColor!;
        for (final states in [
          <WidgetState>{},
          {WidgetState.pressed},
          {WidgetState.selected, WidgetState.pressed},
          {WidgetState.hovered},
          {WidgetState.selected, WidgetState.hovered},
          {WidgetState.disabled},
        ]) {
          expect(overlay.resolve(states), Colors.transparent);
        }
        expect(overlay.resolve({WidgetState.focused}), inkTheme.focusColor);
        expect(inkTheme.focusColor.a, greaterThan(0));
        for (final mode in ['student', 'general']) {
          final destination = _key('adaptive-shell-$mode-destination');
          final gesture = await t.startGesture(t.getCenter(destination));
          for (final duration in [60, 120]) {
            await t.pump(Duration(milliseconds: duration));
            expect(
              listEquals(await _barPixels(t, boundary), before),
              isTrue,
              reason: 'No painted press effect on $mode.',
            );
          }
          await gesture.cancel();
          await t.pumpAndSettle();
          expect(listEquals(await _barPixels(t, boundary), before), isTrue);
        }
        final mouse = await t.createGesture(
          kind: ui.PointerDeviceKind.mouse,
          pointer: 7,
        );
        await mouse.addPointer(location: const Offset(2, 2));
        await mouse.moveTo(
          t.getCenter(_key('adaptive-shell-student-destination')),
        );
        await t.pump(const Duration(milliseconds: 180));
        expect(listEquals(await _barPixels(t, boundary), before), isTrue);
        await mouse.down(
          t.getCenter(_key('adaptive-shell-student-destination')),
        );
        await t.pump(const Duration(milliseconds: 80));
        expect(listEquals(await _barPixels(t, boundary), before), isTrue);
        await mouse.up();
        await t.pump(const Duration(milliseconds: 80));
        expect(listEquals(await _barPixels(t, boundary), before), isTrue);
        await mouse.removePointer();
        await t.pumpAndSettle();
        await t.tap(_key('adaptive-shell-general-destination'));
        await t.pumpAndSettle();
        expect(p.activeMode, AppMode.general);
        // The no-ink policy is local: calendar buttons retain Material feedback.
        final canvas = find.byType(GeneralScheduleHomeScreen);
        expect(
          Theme.of(t.element(canvas)).splashFactory,
          isNot(same(NoSplash.splashFactory)),
        );
        expect(t.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }

  testWidgets(
    'bottom navigation retains a visible keyboard focus state and Enter activation',
    (t) async {
      _viewport(t, const Size(393, 850));
      final p = await workspaceProvider();
      addTearDown(p.dispose);
      final boundary = GlobalKey();
      final previous = FocusManager.instance.highlightStrategy;
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => FocusManager.instance.highlightStrategy = previous);
      await t.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: WorkspaceHarness(provider: p),
        ),
      );
      await t.pumpAndSettle();
      final before = await _barPixels(t, boundary);
      final general = _key('adaptive-shell-general-destination');
      final label = find.descendant(of: general, matching: find.byType(Text));
      Focus.of(t.element(label)).requestFocus();
      await t.pumpAndSettle();
      expect(Focus.of(t.element(label)).hasFocus, isTrue);
      expect(
        listEquals(await _barPixels(t, boundary), before),
        isFalse,
        reason: 'Keyboard users must still see which destination has focus.',
      );
      final semantics = t.ensureSemantics();
      expect(t.getSemantics(general).label, contains('General schedule'));
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(p.activeMode, AppMode.general);
      semantics.dispose();
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  for (final direction in TextDirection.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'day agenda close keeps 8dp outer padding across desktop resizes at $direction/$scale',
        (t) async {
          _viewport(t, const Size(2400, 900));
          final previousNative = DesktopWindowBridge.instance.available;
          DesktopWindowBridge.instance.available = true;
          addTearDown(
            () => DesktopWindowBridge.instance.available = previousNative,
          );
          final p = await workspaceProvider(mode: AppMode.general);
          addTearDown(p.dispose);
          await p.updateGeneralDisplaySettings(defaultView: generalViewWeek);
          await t.pumpWidget(
            WorkspaceHarness(
              provider: p,
              textScale: scale,
              home: Directionality(
                textDirection: direction,
                child: const GeneralScheduleHomeScreen(),
              ),
            ),
          );
          await t.pumpAndSettle();
          await t.tap(_key('general-day-agenda-toggle'));
          await t.pumpAndSettle();
          for (final width in [2400.0, 1000.0, 660.0, 330.0, 1440.0]) {
            t.view.physicalSize = Size(width, 900);
            await t.pumpAndSettle();
            final header = t.getRect(_key('workspace-inspector-header'));
            final button = t.getRect(_key('workspace-inspector-close'));
            expect(button.top - header.top, closeTo(8, .01));
            expect(header.bottom - button.bottom, closeTo(8, .01));
            final edge = direction == TextDirection.ltr
                ? header.right - button.right
                : button.left - header.left;
            expect(edge, closeTo(8, .01));
            expect(button.top, greaterThanOrEqualTo(48 + 8));
            expect(
              _key('workspace-inspector-close').hitTestable(),
              findsOneWidget,
            );
            expect(_key('general-selected-day-agenda'), findsOneWidget);
            expect(t.takeException(), isNull);
          }
          await t.tap(_key('workspace-inspector-close'));
          await t.pumpAndSettle();
          expect(_key('general-selected-day-agenda'), findsNothing);
          expect(nativeCalls, isNot(contains('close')));
          expect(p.activeMode, AppMode.general);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.windows),
      );
    }
  }

  testWidgets(
    'category sidebar drops its redundant More button but keeps management, add, and settings transfer',
    (t) async {
      _viewport(t, const Size(1440, 900));
      final p = await workspaceProvider(mode: AppMode.general);
      addTearDown(p.dispose);
      await t.pumpWidget(WorkspaceHarness(provider: p));
      await t.pumpAndSettle();
      expect(_key('general-resource-menu'), findsNothing);
      expect(_key('general-resource-add').hitTestable(), findsOneWidget);
      expect(
        t.widget<IconButton>(_key('general-resource-add')).onPressed,
        isNotNull,
      );
      await t.tap(_key('workspace-resource-open'));
      await t.pumpAndSettle();
      expect(
        _key('calendar-manager-tile-${p.generalMode.activeScheduleId}'),
        findsOneWidget,
      );
      await t.tap(find.byType(BackButton).hitTestable().first);
      await t.pumpAndSettle();
      await t.tap(_key('workspace-resource-settings'));
      await t.pumpAndSettle();
      await t.ensureVisible(_key('settings-general-transfer'));
      await t.pumpAndSettle();
      await t.tap(_key('settings-general-transfer'));
      await t.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is SettingsPage &&
              w.initialDestination == SettingsDestination.general,
        ),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
