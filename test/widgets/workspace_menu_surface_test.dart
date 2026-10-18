import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/desktop_window_bridge.dart';

import '../support/workspace_harness.dart';

const workspaceMenuSurfaceCaptureKey = ValueKey(
  'workspace-menu-surface-capture',
);

typedef WorkspaceMenuSurfaceCapture = Future<void> Function(
  WidgetTester tester,
  String scene,
);

class _WorkspacePixels {
  const _WorkspacePixels(this.width, this.height, this.bytes);

  final int width, height;
  final Uint8List bytes;

  Color at(Offset point) {
    final x = point.dx.floor(), y = point.dy.floor();
    expect(x, inInclusiveRange(0, width - 1));
    expect(y, inInclusiveRange(0, height - 1));
    final offset = (y * width + x) * 4;
    return Color.fromARGB(
      bytes[offset + 3],
      bytes[offset],
      bytes[offset + 1],
      bytes[offset + 2],
    );
  }
}

Future<_WorkspacePixels> _pixels(WidgetTester tester) async =>
    (await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(workspaceMenuSurfaceCaptureKey),
      );
      final image = await boundary.toImage(pixelRatio: 1);
      try {
        final data = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        return _WorkspacePixels(
          image.width,
          image.height,
          Uint8List.fromList(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          ),
        );
      } finally {
        image.dispose();
      }
    }))!;

List<Offset> _gutterPoints(Rect rect) => [
  // Stay inside the outline and away from rounded corners. These gutters lie
  // outside menu items, so text, checkmarks and hover feedback cannot mask a
  // missing background. The vertical strips also cross timetable grid lines.
  for (var y = rect.top + 12; y < rect.bottom - 12; y += 2) ...[
    Offset(rect.left + 3, y),
    Offset(rect.right - 3, y),
  ],
  for (var x = rect.left + 12; x < rect.right - 12; x += 2) ...[
    Offset(x, rect.top + 3),
    Offset(x, rect.bottom - 3),
  ],
];

bool _sameRgb(Color a, Color b) =>
    (a.r - b.r).abs() <= 2 / 255 &&
    (a.g - b.g).abs() <= 2 / 255 &&
    (a.b - b.b).abs() <= 2 / 255;

Finder _menuOption(String text) => find
    .ancestor(
      of: find.byWidgetPredicate(
        (widget) => widget is Text && widget.data == text,
      ),
      // CheckedPopupMenuItem ignores pointer hits on its text. Target the
      // entry itself, which also excludes matching weekday labels behind it.
      matching: find.byWidgetPredicate((widget) => widget is PopupMenuItem),
    )
    .hitTestable();

Finder _menuSurface(Finder option) => find
    .ancestor(
      of: option,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Material && widget.color != null && widget.color!.a > 0,
      ),
    )
    .first;

Future<void> _tap(WidgetTester tester, Finder target) async {
  expect(target.hitTestable(), findsOneWidget);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _initializeWindowBridge(WidgetTester tester) async {
  final bridge = DesktopWindowBridge.instance;
  if (tester.binding is AutomatedTestWidgetsFlutterBinding) {
    const channel = MethodChannel('com.mashiro.sked/window');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final available = bridge.available;
    final maximized = bridge.maximized;
    final focused = bridge.focused;
    final maximizeHovered = bridge.maximizeHovered;
    messenger.setMockMethodCallHandler(channel, (call) async {
      return call.method == 'initialize'
          ? {'maximized': false, 'focused': true}
          : null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      channel.setMethodCallHandler(null);
      bridge.available = available;
      bridge.maximized = maximized;
      bridge.focused = focused;
      bridge.maximizeHovered = maximizeHovered;
    });
  }
  // Native capture uses the real channel; only automated widget tests install
  // the mock above. Both must include the actual DesktopWindowHost chrome.
  await bridge.initialize();
  expect(bridge.available, isTrue);
}

void main() => runWorkspaceMenuSurfaceTests();

void runWorkspaceMenuSurfaceTests({WorkspaceMenuSurfaceCapture? capture}) {
  for (final mode in [AppMode.student, AppMode.general]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        '${mode.name} view menu obscures its workspace in ${brightness.name}',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          // Keep the real desktop view menus visible instead of replacing them
          // with the narrow command bar's overflow navigation.
          tester.view.physicalSize = const Size(1366, 768);
          addTearDown(tester.view.reset);
          await _initializeWindowBridge(tester);
          final provider = await workspaceProvider(mode: mode, locale: 'zh');
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
            provider.dispose();
          });
          if (mode == AppMode.general) {
            await provider.generalCommands.updateDisplaySettings(
              defaultView: generalViewWeek,
            );
          } else {
            await provider.studentCommands.setSelectedWeek(1);
          }
          await tester.pumpWidget(
            RepaintBoundary(
              key: workspaceMenuSurfaceCaptureKey,
              child: WorkspaceHarness(
                provider: provider,
                locale: const Locale('zh'),
                brightness: brightness,
              ),
            ),
          );
          await tester.pumpAndSettle();

          final trigger = find
              .byKey(
                ValueKey(
                  mode == AppMode.student
                      ? 'student-view-toggle'
                      : 'general-view-switcher',
                ),
              )
              .hitTestable();
          expect(trigger, findsOneWidget);
          final context = tester.element(trigger);
          final l10n = AppLocalizations.of(context);
          final expectedSurface = Theme.of(context).colorScheme.surface;
          final weekLabel = find.descendant(
            of: trigger,
            matching: find.byWidgetPredicate(
              (widget) => widget is Text && widget.data == l10n.viewWeek,
            ),
          );
          expect(weekLabel, findsOneWidget);
          final divider = find.byKey(const ValueKey('desktop-window-divider'));
          expect(divider, findsOneWidget);
          final dividerRect = tester.getRect(divider);
          final before = await _pixels(tester);

          await _tap(tester, trigger);
          final dayOption = _menuOption(l10n.viewDay);
          expect(dayOption, findsOneWidget);
          final surface = _menuSurface(dayOption);
          expect(surface, findsOneWidget);
          final menuElement = tester.element(surface);
          final rect = tester.getRect(surface);
          final dividerProbe = Offset(rect.center.dx, dividerRect.center.dy);
          final points = [dividerProbe, ..._gutterPoints(rect)];
          expect(points, isNotEmpty);

          // Capture before checking pixels, retaining native failure evidence.
          await capture?.call(
            tester,
            '${mode.name}-view-menu-${brightness.name}',
          );
          expect(
            rect.deflate(1).contains(dividerProbe),
            isTrue,
            reason:
                'The real toolbar menu must cross the window divider '
                'to exercise the reported paint-order issue: '
                'menu $rect, divider $dividerRect.',
          );
          final opened = await _pixels(tester);
          final coveredPoints = points
              .where((point) => !_sameRgb(before.at(point), expectedSurface))
              .toList();
          expect(
            coveredPoints,
            isNotEmpty,
            reason:
                'At least one sampled gutter must cover visible workspace '
                'content; otherwise a transparent menu could pass this fixture.',
          );
          for (final point in points) {
            final actual = opened.at(point);
            expect(
              _sameRgb(actual, expectedSurface),
              isTrue,
              reason:
                  '${mode.name}/${brightness.name} menu $rect at $point '
                  'must obscure the underlying workspace: before '
                  '${before.at(point)}, opened $actual, expected $expectedSurface.',
            );
            expect(actual.a, closeTo(1, 1 / 255));
          }

          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
          expect(menuElement.mounted, isFalse);
          expect(weekLabel, findsOneWidget);
          if (mode == AppMode.general) {
            expect(provider.generalView.data.defaultView, generalViewWeek);
          }

          await _tap(tester, trigger);
          final selectionMenu = tester.element(
            _menuSurface(_menuOption(l10n.viewDay)),
          );
          await _tap(tester, _menuOption(l10n.viewDay));
          expect(selectionMenu.mounted, isFalse);
          final dayLabel = find.descendant(
            of: trigger,
            matching: find.byWidgetPredicate(
              (widget) => widget is Text && widget.data == l10n.viewDay,
            ),
          );
          expect(dayLabel, findsOneWidget);
          expect(weekLabel, findsNothing);
          if (mode == AppMode.general) {
            expect(
              provider.generalView.data.defaultView,
              generalViewWeek,
              reason: 'Changing the visible view must not rewrite its saved default.',
            );
          }
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.windows),
      );
    }
  }
}
