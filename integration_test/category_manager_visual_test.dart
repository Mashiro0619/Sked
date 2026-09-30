import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/desktop_window_bridge.dart';
import 'package:sked/widgets/sked_task_dialog.dart';

import '../test/support/workspace_harness.dart';

Finder k(String id) => find.byKey(ValueKey(id));

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.shouldPropagateDevicePointerEvents = true;
  testWidgets('category list and name dialogs with actual fonts', (t) async {
    await DesktopWindowBridge.instance.initialize();
    final output = Directory(
      const String.fromEnvironment(
        'SKED_VISUAL_OUTPUT',
        defaultValue: '.scratch/category-manager-visual',
      ),
    );
    await output.create(recursive: true);
    final captures = <Map<String, Object?>>[];
    final cases = [
      (
        'desktop-single',
        const Size(1280, 720),
        1.0,
        Brightness.light,
        TargetPlatform.windows,
        1,
      ),
      (
        'desktop-list',
        const Size(1280, 720),
        1.0,
        Brightness.light,
        TargetPlatform.windows,
        5,
      ),
      (
        'desktop-dark',
        const Size(1000, 800),
        1.5,
        Brightness.dark,
        TargetPlatform.windows,
        5,
      ),
      (
        'phone',
        const Size(393, 852),
        1.0,
        Brightness.light,
        TargetPlatform.android,
        5,
      ),
      (
        'phone-large',
        const Size(320, 640),
        2.0,
        Brightness.light,
        TargetPlatform.android,
        5,
      ),
    ];
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetPadding);
    addTearDown(t.view.resetViewPadding);
    addTearDown(t.view.resetViewInsets);
    try {
      for (final (label, size, scale, brightness, platform, count) in cases) {
        debugDefaultTargetPlatformOverride = platform;
        DesktopWindowBridge.instance.available =
            platform == TargetPlatform.windows;
        t.view.physicalSize = size;
        final safe = platform == TargetPlatform.android
            ? const FakeViewPadding(top: 24, bottom: 24)
            : const FakeViewPadding();
        t.view.padding = safe;
        t.view.viewPadding = safe;
        t.view.viewInsets = const FakeViewPadding();
        const names = ['My calendar', '课程与学习', '工作项目', '生活与家人', '旅行计划（暂时隐藏）'];
        const colors = [
          0xff4fb6ac,
          0xff6750a4,
          0xff386a20,
          0xffb3261e,
          0xff006a6a,
        ];
        final categories = List.generate(
          count,
          (i) => GeneralSchedule(
            id: 'category-$i',
            name: names[i],
            colorValue: colors[i],
            isVisible: i != 4,
            events: const [],
          ),
        );
        final base = buildInitialAppData(
          buildDefaultPeriodTimes(),
          localeCode: 'zh',
        );
        final p = await workspaceProvider(
          mode: AppMode.general,
          locale: 'zh',
          storage: WorkspaceMemoryStorage(
            base.copyWith(
              activeMode: AppMode.general,
              generalMode: base.generalMode.copyWith(
                schedules: categories,
                activeScheduleId: categories.first.id,
              ),
            ),
          ),
        );
        final boundary = GlobalKey();
        await t.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: WorkspaceHarness(
              provider: p,
              locale: const Locale('zh'),
              textScale: scale,
              brightness: brightness,
            ),
          ),
        );
        await t.pumpAndSettle();
        final resources = k('workspace-resource-open').hitTestable();
        final selector = k('general-calendar-selector').hitTestable();
        if (resources.evaluate().isNotEmpty) {
          await t.tap(resources);
        } else if (selector.evaluate().isNotEmpty) {
          await t.tap(selector);
        } else {
          final desktopMore = k('general-desktop-toolbar-more').hitTestable();
          await t.tap(
            desktopMore.evaluate().isNotEmpty
                ? desktopMore
                : k('general-toolbar-more-button'),
          );
          await t.pumpAndSettle();
          final entry = k('general-calendar-selector').hitTestable();
          await t.tap(
            entry.evaluate().isNotEmpty
                ? entry
                : k('general-calendar-manager-action'),
          );
        }
        await t.pumpAndSettle();

        Future<void> capture(String scene) async {
          expect(t.takeException(), isNull, reason: '$label $scene');
          final render =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await render.toImage(
            pixelRatio: size.width < 600 ? 2 : 1,
          );
          try {
            final bytes = (await image.toByteData(
              format: ui.ImageByteFormat.png,
            ))!;
            final filename = '$label-$scene.png';
            await File('${output.path}/$filename')
                .writeAsBytes(bytes.buffer.asUint8List());
            captures.add({
              'file': filename,
              'widthDp': size.width,
              'heightDp': size.height,
              'textScale': scale,
              'brightness': brightness.name,
              'platformStyle': platform.name,
            });
          } finally {
            image.dispose();
          }
        }

        expect(find.byType(BackButton), findsOneWidget);
        await capture('list');
        await t.tap(
          find.descendant(
            of: k('calendar-manager-tile-category-0'),
            matching: find.text('My calendar'),
          ),
        );
        await t.pumpAndSettle();
        expect(find.byType(SkedTaskDialog), findsOneWidget);
        expect(find.byType(BackButton), findsOneWidget);
        await capture('rename');
        if (platform == TargetPlatform.windows) {
          final before = t.getRect(k('floating-form-surface'));
          await t.drag(k('floating-form-drag-handle'), const Offset(50, 50));
          await t.pumpAndSettle();
          expect(
            t.getRect(k('floating-form-surface')).top,
            greaterThan(before.top),
          );
          await capture('rename-dragged');
        }
        if (label == 'desktop-single' &&
            const bool.fromEnvironment('SKED_NATIVE_POINTER_CHECK')) {
          t.view.resetPhysicalSize();
          t.view.resetDevicePixelRatio();
          Future<Map<String, dynamic>> native(
            String action, {
            Offset? from,
            Offset? to,
            String? filename,
          }) async {
            final result = await t.runAsync(
              () => Process.run('powershell', [
                '-NoProfile',
                '-WindowStyle',
                'Hidden',
                '-ExecutionPolicy',
                'Bypass',
                '-File',
                File('tool/capture_workbench_window.ps1').absolute.path,
                '-ProcessId',
                '$pid',
                '-Action',
                action,
                '-WidthDp',
                '1280',
                '-HeightDp',
                '800',
                '-CaptionHeightDp',
                '48',
                '-CaptionButtonWidthDp',
                '46',
                if (from != null) ...[
                  '-PointXDp',
                  '${from.dx}',
                  '-PointYDp',
                  '${from.dy}',
                ],
                if (to != null) ...[
                  '-EndPointXDp',
                  '${to.dx}',
                  '-EndPointYDp',
                  '${to.dy}',
                ],
                if (filename != null) ...[
                  '-OutputPath',
                  '${output.absolute.path}/$filename.png',
                ],
              ]),
            );
            expect(result!.exitCode, 0, reason: '${result.stderr}');
            return jsonDecode('${result.stdout}'.trim())
                as Map<String, dynamic>;
          }

          await native('resize');
          await t.pumpAndSettle();
          final before = t.getRect(k('floating-form-surface'));
          final from = t.getCenter(k('floating-form-drag-handle'));
          final dx =
              before.right + 60 <
                  t.view.physicalSize.width / t.view.devicePixelRatio
              ? 50.0
              : -50.0;
          // Request activation by the verified test PID; retain the helper's
          // foreground and unobscured-point guards before any native input.
          await t.runAsync(
            () => Process.run('powershell', [
              '-NoProfile',
              '-WindowStyle',
              'Hidden',
              '-Command',
              '(New-Object -ComObject WScript.Shell).AppActivate($pid)',
            ]),
          );
          final report = await native(
            'range-drag',
            from: from,
            to: from + Offset(dx, 35),
          );
          await t.pumpAndSettle();
          final after = t.getRect(k('floating-form-surface'));
          expect(after.left - before.left, closeTo(dx, 3));
          expect(after.top - before.top, closeTo(35, 3));
          expect(report['movedX'], 0);
          expect(report['movedY'], 0);
          await native('capture', filename: 'native-form-drag');
          await File('${output.path}/native-form-drag.json').writeAsString(
            jsonEncode({
              'input': report,
              'dx': after.left - before.left,
              'dy': after.top - before.top,
            }),
          );
          t.view.devicePixelRatio = 1;
          t.view.physicalSize = size;
          await t.pumpAndSettle();
        }
        if (label == 'phone-large') {
          t.view.viewInsets = const FakeViewPadding(bottom: 240);
          t.view.padding = const FakeViewPadding(top: 24);
          await t.pumpAndSettle();
          await capture('rename-keyboard');
          t.view.viewInsets = const FakeViewPadding();
          t.view.padding = safe;
          await t.pumpAndSettle();
        }
        await t.tap(find.widgetWithText(TextButton, '取消'));
        await t.pumpAndSettle();
        await t.tap(find.byTooltip('添加分类'));
        await t.pumpAndSettle();
        expect(k('add-calendar-field'), findsOneWidget);
        expect(p.generalSchedules, hasLength(count));
        await capture('add');
        await t.pumpWidget(const SizedBox.shrink());
        await t.pumpAndSettle();
        p.dispose();
      }
      await File('${output.path}/manifest.json').writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'kind': 'Actual Flutter client rendering on Windows; Android geometry, safe area and keyboard insets are simulated.',
          'captures': captures,
        }),
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
      DesktopWindowBridge.instance.available = true;
    }
  });
}
