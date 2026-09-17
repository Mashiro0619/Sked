import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/desktop_window_bridge.dart';
import 'package:sked/widgets/workbench_chrome_metrics.dart';

import '../test/support/mobile_layout_data.dart';
import '../test/support/workspace_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Windows compact command bars and centered resource toggle', (
    t,
  ) async {
    await DesktopWindowBridge.instance.initialize();
    expect(DesktopWindowBridge.instance.available, isTrue);
    const baseline = bool.fromEnvironment('SKED_VISUAL_BASELINE');
    final output = Directory(
      const String.fromEnvironment(
        'SKED_VISUAL_OUTPUT',
        defaultValue: '.scratch/windows-toolbar-after',
      ),
    );
    await output.create(recursive: true);
    final manifest = <Map<String, Object?>>[];
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    for (final (width, scale, locale, brightness)
        in <(double, double, String, Brightness)>[
          (330, 1, 'zh', Brightness.light),
          (400, 1, 'zh', Brightness.light),
          (520, 1, 'zh', Brightness.light),
          (660, 1, 'zh', Brightness.light),
          (1100, 1, 'zh', Brightness.light),
          (1440, 1, 'en', Brightness.light),
          (330, 2, 'en', Brightness.light),
          (520, 1.3, 'en', Brightness.dark),
          (1100, 2, 'en', Brightness.dark),
          (1800, 2, 'zh', Brightness.dark),
        ]) {
      final name = 'windows-${width.toInt()}-$locale-${scale}x';
      t.view.physicalSize = Size(width, 900);
      final p = await workspaceProvider(
        storage: WorkspaceMemoryStorage(
          mobileLayoutData(locale: locale).copyWith(
            activeMode: AppMode.student,
            homeWorkspaceNavigationCollapsed: true,
          ),
        ),
        locale: locale,
      );
      final boundary = GlobalKey();
      await t.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: WorkspaceHarness(
            provider: p,
            locale: Locale(locale),
            textScale: scale,
            brightness: brightness,
          ),
        ),
      );
      await t.pumpAndSettle();
      Future<void> capture(String scene) async {
        expect(t.takeException(), isNull, reason: '$name $scene');
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: width <= 660 ? 2 : 1);
        try {
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!;
          final file = '$name-$scene.png';
          await File('${output.path}/$file')
              .writeAsBytes(bytes.buffer.asUint8List());
          manifest.add({
            'file': file,
            'widthDp': width,
            'heightDp': 900,
            'textScale': scale,
            'locale': locale,
            'brightness': brightness.name,
            'baseline': baseline,
            'evidence': 'Actual Windows Flutter renderer and native bridge; image excludes external Win32 frame/hit-testing acceptance.',
          });
        } finally {
          image.dispose();
        }
      }

      for (final mode in [AppMode.student, AppMode.general]) {
        if (p.activeMode != mode) await p.switchMode(mode);
        await t.pumpAndSettle();
        expect(p.activeMode, mode);
        await capture(mode.value);
        if (!baseline) {
          final more = find.byKey(
            ValueKey('${mode.value}-desktop-toolbar-more'),
          );
          if (more.evaluate().isNotEmpty) {
            expect(more.hitTestable(), findsOneWidget);
            expect(t.widget<IconButton>(more).onPressed, isNotNull);
            await t.tap(more);
            await t.pumpAndSettle();
            expect(
              find
                      .byKey(const ValueKey('student-add-course'))
                      .evaluate()
                      .isNotEmpty ||
                  find
                      .byKey(const ValueKey('general-add-event'))
                      .evaluate()
                      .isNotEmpty,
              isTrue,
            );
            final item = find.byKey(
              ValueKey(
                mode == AppMode.student
                    ? 'student-add-course'
                    : 'general-add-event',
              ),
            );
            final menuSurface = find.ancestor(
              of: item,
              matching: find.byWidgetPredicate(
                (w) => w is Material && w.type == MaterialType.card,
              ),
            );
            final menuRect = t.getRect(menuSurface.first);
            expect(
              menuRect.top,
              greaterThanOrEqualTo(
                WorkbenchChromeMetrics.of(t.element(more)).toolbarHeight,
              ),
            );
            expect(
              menuRect.bottom,
              lessThanOrEqualTo(t.view.physicalSize.height - 8),
            );
            await capture('${mode.value}-more');
            await t.sendKeyEvent(LogicalKeyboardKey.escape);
            await t.pumpAndSettle();
            expect(
              find.byKey(const ValueKey('student-add-course')),
              findsNothing,
            );
            expect(
              find.byKey(const ValueKey('general-view-choice-week')),
              findsNothing,
            );
          }
        }
      }
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpAndSettle();
      p.dispose();
    }
    await File('${output.path}/manifest.json')
        .writeAsString(const JsonEncoder.withIndent('  ').convert(manifest));
  });
}
