import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/settings_page.dart';
import 'package:sked/services/desktop_window_bridge.dart';
import 'package:sked/theme/app_theme.dart';
import 'package:sked/theme/sked_surface.dart';
import 'package:sked/widgets/desktop_window_host.dart';
import 'package:sked/widgets/expressive_dialog.dart';
import 'package:sked/widgets/workspace_frame.dart';

import '../support/workspace_harness.dart';

Finder _key(String value) => find.byKey(ValueKey(value));
void _size(WidgetTester t, Size value) {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = value;
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.view.resetPhysicalSize);
}

Future<List<Color>> _pixels(
  WidgetTester t,
  GlobalKey key,
  List<Offset> points,
) async => (await t.runAsync(() async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1);
  try {
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    return points.map((point) {
      final offset = (point.dy.floor() * image.width + point.dx.floor()) * 4;
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

void _samePaint(Color actual, Color expected) {
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'one continuous chrome surface across agenda and caption gaps: $brightness',
      (t) async {
        _size(t, const Size(1440, 900));
        final p = await workspaceProvider(mode: AppMode.general);
        final boundary = GlobalKey();
        await p.updateHomeWorkspaceNavigationCollapsed(true);
        await t.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: WorkspaceHarness(provider: p, brightness: brightness),
          ),
        );
        await t.pumpAndSettle();
        await t.tap(_key('general-day-agenda-toggle'));
        await t.pumpAndSettle();
        final fill = t.getRect(_key('workspace-caption-fill'));
        final agenda = t.getRect(_key('general-selected-day-agenda'));
        final bar = t.getRect(find.byType(WorkbenchCommandBar));
        final colors = Theme.of(t.element(_key('general-selected-day-agenda')))
            .colorScheme;
        final points = [
          bar.topLeft + const Offset(2, 4),
          Offset(fill.center.dx, fill.top + 4),
          const Offset(1436, 4),
          Offset(agenda.left + 2, 54),
          agenda.topLeft + const Offset(2, 20),
          agenda.bottomLeft + const Offset(2, -4),
          const Offset(3, 600),
        ];
        for (final color in await _pixels(t, boundary, points)) {
          _samePaint(color, colors.surfaceContainerLow);
        }
        await t.dragFrom(
          Offset(fill.center.dx, fill.top + 15),
          const Offset(60, 0),
        );
        await t.pumpAndSettle();
        expect(calls, contains('startDrag'));
        await p.updateHomeWorkspaceNavigationCollapsed(false);
        await t.pumpAndSettle();
        expect(
          SkedSurface.colorOf(t.element(_key('general-selected-day-agenda'))),
          colors.surfaceContainerLow,
        );
        t.view.physicalSize = const Size(700, 900);
        await t.pumpAndSettle();
        expect(
          SkedSurface.colorOf(t.element(_key('general-selected-day-agenda'))),
          colors.surface,
        );
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
        p.dispose();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }

  testWidgets(
    'nested task follows docking role without changing draft or semantic colors',
    (t) async {
      _size(t, const Size(1600, 900));
      final pane = WorkspacePaneController();
      final observer = DesktopWindowModalObserver();
      final text = TextEditingController();
      final base = buildAppTheme(
        seedColor: Colors.teal,
        brightness: Brightness.dark,
        themeColorMode: themeColorModeSingle,
        colorfulUiColorValues: const {},
      );
      await t.pumpWidget(
        MaterialApp(
          theme: base,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          navigatorObservers: [observer],
          builder: (context, child) =>
              DesktopWindowHost(modalObserver: observer, child: child!),
          home: Scaffold(
            body: WorkspaceFrame(
              controller: pane,
              resources: const SkedSurface(
                role: SkedSurfaceRole.frame,
                child: SizedBox.expand(),
              ),
              canvas: const Column(
                children: [
                  WorkbenchCommandBar(navigation: []),
                  Expanded(child: SizedBox.expand()),
                ],
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      unawaited(
        pane.show<void>(
          (context) => Scaffold(
            key: const ValueKey('nested-task'),
            body: Column(
              children: [
                TextField(key: const ValueKey('draft'), controller: text),
                Builder(
                  builder: (context) => TextButton(
                    key: const ValueKey('open-dialog'),
                    onPressed: () => unawaited(
                      showExpressiveDialog<void>(
                        context: context,
                        builder: (context) => const AlertDialog(
                          content: Material(
                            key: ValueKey('independent-dialog'),
                            child: Text('Dialog'),
                          ),
                        ),
                      ),
                    ),
                    child: const Text('Dialog'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final taskState = t.state(_key('draft'));
      await t.enterText(_key('draft'), 'Keep this draft');
      final docked = t.element(_key('draft'));
      expect(SkedSurface.roleOf(docked), SkedSurfaceRole.frame);
      expect(
        Theme.of(docked).scaffoldBackgroundColor,
        base.colorScheme.surfaceContainerLow,
      );
      expect(Theme.of(docked).colorScheme, base.colorScheme);
      await t.tap(_key('open-dialog'));
      await t.pumpAndSettle();
      final dialog = t.element(_key('independent-dialog'));
      expect(SkedSurface.roleOf(dialog), SkedSurfaceRole.content);
      expect(Theme.of(dialog).canvasColor, base.colorScheme.surface);
      expect(find.byType(AnimatedModalBarrier), findsOneWidget);
      Navigator.of(dialog).pop();
      await t.pumpAndSettle();
      t.view.physicalSize = const Size(700, 900);
      await t.pumpAndSettle();
      expect(t.state(_key('draft')), same(taskState));
      expect(text.text, 'Keep this draft');
      expect(
        SkedSurface.roleOf(t.element(_key('draft'))),
        SkedSurfaceRole.content,
      );
      expect(
        Theme.of(t.element(_key('draft'))).scaffoldBackgroundColor,
        base.colorScheme.surface,
      );
      t.view.physicalSize = const Size(1600, 900);
      await t.pumpAndSettle();
      expect(
        SkedSurface.roleOf(t.element(_key('draft'))),
        SkedSurfaceRole.frame,
      );
      expect(text.text, 'Keep this draft');
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      pane.dispose();
      observer.dispose();
      text.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'settings sidebar inherits frame while independent navigation is content',
    (t) async {
      _size(t, const Size(1000, 1000));
      final p = await workspaceProvider();
      await t.pumpWidget(
        WorkspaceHarness(provider: p, home: const SettingsPage()),
      );
      await t.pumpAndSettle();
      expect(
        SkedSurface.roleOf(t.element(_key('settings-category-language'))),
        SkedSurfaceRole.frame,
      );
      final theme = Theme.of(t.element(_key('settings-category-language')));
      expect(theme.appBarTheme.scrolledUnderElevation, 0);
      expect(theme.appBarTheme.surfaceTintColor, Colors.transparent);
      expect(
        theme.navigationBarTheme.backgroundColor,
        theme.colorScheme.surfaceContainerLow,
      );
      expect(theme.dialogTheme.backgroundColor, theme.colorScheme.surface);
      expect(theme.dialogTheme.surfaceTintColor, Colors.transparent);
      expect(theme.bottomSheetTheme.surfaceTintColor, Colors.transparent);
      expect(
        theme.inputDecorationTheme.fillColor,
        theme.colorScheme.surfaceContainerLow,
      );
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      p.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
