import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/general_schedule_home_screen.dart';
import 'package:sked/services/desktop_window_bridge.dart';
import 'package:sked/widgets/sked_time_picker.dart';

import '../support/workspace_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.mashiro.sked/window');
  final commands = <String>[];
  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          commands.add(call.method);
          return call.method == 'initialize'
              ? {'maximized': false, 'focused': true}
              : null;
        });
    await DesktopWindowBridge.instance.initialize();
    debugDefaultTargetPlatformOverride = null;
  });
  tearDown(() {
    DesktopWindowBridge.instance.available = false;
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  testWidgets(
    'range dragging never moves the window; time-list wheel does not scroll the background',
    (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(1440, 1000);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.view.resetPhysicalSize);
      final p = await workspaceProvider(mode: AppMode.general);
      addTearDown(p.dispose);
      await p.setSelectedGeneralDate(DateTime(2026, 9, 10));
      await t.pumpWidget(WorkspaceHarness(provider: p));
      await t.pumpAndSettle();
      final sidebar = find.byKey(
        const ValueKey('general-resource-date-picker'),
      );
      Finder date(String id) =>
          find.descendant(of: sidebar, matching: find.byKey(ValueKey(id)));
      commands.clear();
      final drag = await t.startGesture(
        t.getCenter(date('sked-date-2026-09-09')),
        kind: PointerDeviceKind.mouse,
      );
      await drag.moveTo(t.getCenter(date('sked-date-2026-09-13')));
      await t.pump();
      await drag.up();
      await t.pumpAndSettle();
      expect(
        p.customGeneralDateRange,
        GeneralDateRange(DateTime(2026, 9, 9), DateTime(2026, 9, 13)),
      );
      expect(commands, isNot(contains('startDrag')));
      await t.tap(find.byKey(const ValueKey('general-add-event')));
      await t.pumpAndSettle();
      final time = find.byTooltip('Pick time').first;
      await t.ensureVisible(time);
      await t.tap(time);
      await t.pumpAndSettle();
      expect(find.byType(SkedTimePicker), findsOneWidget);
      final background = t
          .stateList<ScrollableState>(
            find.descendant(
              of: find.byType(GeneralScheduleHomeScreen),
              matching: find.byType(Scrollable),
            ),
          )
          .toList();
      final positions = [
        for (final scroll in background) scroll.position.pixels,
      ];
      final minutes = find.descendant(
        of: find.byKey(const ValueKey('sked-time-minutes')),
        matching: find.byType(ListWheelScrollView),
      );
      await t.sendEventToBinding(
        PointerScrollEvent(
          kind: PointerDeviceKind.mouse,
          position: t.getCenter(minutes),
          scrollDelta: const Offset(0, 100),
        ),
      );
      await t.pumpAndSettle();
      expect([
        for (final scroll in background) scroll.position.pixels,
      ], positions);
      expect(commands, isNot(contains('startDrag')));
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
