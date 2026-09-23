import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/settings_page.dart';
import 'package:sked/services/desktop_window_bridge.dart';

import '../support/workspace_harness.dart';

Future<void> _pumpEmptyHome(
  WidgetTester tester, {
  required double width,
  bool collapsed = false,
  double textScale = 1,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final data = buildInitialAppData(
    buildDefaultPeriodTimes(),
    localeCode: 'en',
  ).copyWith(homeWorkspaceNavigationCollapsed: collapsed);
  final provider = await workspaceProvider(
    storage: WorkspaceMemoryStorage(data),
  );
  addTearDown(provider.dispose);
  await tester.pumpWidget(
    WorkspaceHarness(provider: provider, textScale: textScale),
  );
  await tester.pumpAndSettle();
  expect(provider.timetables, isEmpty);
  expect(find.text('No timetable yet'), findsOneWidget);
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

  for (final (name, width, collapsed, textScale, hasResources) in [
    ('expanded resources', 1440.0, false, 1.0, true),
    ('collapsed resources', 800.0, true, 1.0, true),
    ('narrow window', 600.0, false, 1.0, false),
    ('large text', 1920.0, false, 2.0, true),
  ]) {
    testWidgets(
      'Windows empty timetable keeps native toolbar gestures with $name',
      (tester) async {
        await _pumpEmptyHome(
          tester,
          width: width,
          collapsed: collapsed,
          textScale: textScale,
        );

        final toolbar = find.byKey(const ValueKey('student-workspace-toolbar'));
        expect(toolbar, findsOneWidget);
        // The sidebar owns the app name when expanded; the canvas supplies it
        // only when that label is absent, without removing the drag surface.
        expect(find.text('Sked').hitTestable(), findsOneWidget);
        final toolbarRect = tester.getRect(toolbar);
        final captionRect = tester.getRect(find.bySemanticsLabel('Minimize'));
        expect(toolbarRect.top, captionRect.top);
        expect(toolbarRect.height, captionRect.height);
        final dragPoint = Offset(
          (toolbarRect.left + captionRect.left) / 2,
          toolbarRect.center.dy,
        );

        calls.clear();
        await tester.dragFrom(
          dragPoint,
          const Offset(80, 0),
          kind: PointerDeviceKind.mouse,
        );
        await tester.pump();
        expect(calls.where((call) => call == 'startDrag'), hasLength(1));

        calls.clear();
        await tester.tapAt(dragPoint, kind: PointerDeviceKind.mouse);
        await tester.pump(const Duration(milliseconds: 80));
        await tester.tapAt(dragPoint, kind: PointerDeviceKind.mouse);
        await tester.pump();
        expect(calls, contains('toggleMaximize'));

        calls.clear();
        final secondary = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
          buttons: kSecondaryMouseButton,
        );
        await secondary.down(dragPoint);
        await secondary.up();
        await tester.pump();
        expect(calls, contains('systemMenu'));

        final toolbarSettings = find.byKey(
          const ValueKey('empty-timetable-settings-button'),
        );
        final resourceSettings = find.byKey(
          const ValueKey('workspace-resource-settings'),
        );
        expect(toolbarSettings, hasResources ? findsNothing : findsOneWidget);
        expect(resourceSettings, hasResources ? findsOneWidget : findsNothing);
        calls.clear();
        await tester.tap(hasResources ? resourceSettings : toolbarSettings);
        await tester.pumpAndSettle();
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is SettingsPage && widget.initialDestination == null,
          ),
          findsOneWidget,
        );
        expect(calls, isNot(contains('startDrag')));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }

  testWidgets('empty timetable content is not a window drag region', (
    tester,
  ) async {
    await _pumpEmptyHome(tester, width: 1440);
    calls.clear();
    await tester.dragFrom(
      const Offset(700, 180),
      const Offset(80, 0),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    expect(calls, isNot(contains('startDrag')));

    await tester.tap(
      find.byKey(const ValueKey('empty-timetable-import-button')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('empty-timetable-import-files')),
      findsOneWidget,
    );
    await tester.tapAt(const Offset(700, 180));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'New timetable'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);
    expect(calls, isNot(contains('startDrag')));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
