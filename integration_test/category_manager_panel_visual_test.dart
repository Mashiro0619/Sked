import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/desktop_window_bridge.dart';

import '../test/support/category_manager_harness.dart';
import '../test/support/workspace_harness.dart';

Finder k(String id) => find.byKey(ValueKey(id));
Finder inside(Finder parent, String key) =>
    find.descendant(of: parent, matching: k(key));

class _VisibilitySaveStorage extends WorkspaceMemoryStorage {
  _VisibilitySaveStorage(super.data);
  Completer<void>? pending;
  @override
  Future<void> save(AppData data) async {
    await pending?.future;
    await super.save(data);
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('category management and color panels Windows font screenshots', (
    t,
  ) async {
    final output = Directory(
      const String.fromEnvironment(
        'SKED_VISUAL_OUTPUT',
        defaultValue: '.scratch/category-manager-panel-visual',
      ),
    );
    await output.create(recursive: true);
    final captures = <String>[];
    addTearDown(t.view.reset);
    for (final locale in ['zh', 'en']) {
      for (final scale in [1.0, 1.5, 2.0]) {
        for (final rtl in [false, true]) {
          t.view.devicePixelRatio = 1;
          t.view.physicalSize = const Size(1440, 900);
          final storage = _VisibilitySaveStorage(
            categoryManagerStorage(
              locale: locale,
              count: scale == 2 ? 16 : 4,
              longNames: scale == 2,
            ).data,
          );
          final p = await workspaceProvider(
            mode: AppMode.general,
            storage: storage,
          );
          if (scale == 2) await p.updateThemeSeedColorValue(0xff008577);
          final key = GlobalKey();
          await t.pumpWidget(
            RepaintBoundary(
              key: key,
              child: categoryManagerHarness(
                p,
                locale: locale,
                scale: scale,
                direction: rtl ? TextDirection.rtl : TextDirection.ltr,
                brightness: scale == 1.5 ? Brightness.dark : Brightness.light,
              ),
            ),
          );
          await t.pumpAndSettle();
          await t.tap(k('workspace-resource-open'));
          await t.pumpAndSettle();
          Future<void> capture(String state) async {
            await t.pumpAndSettle();
            expect(t.takeException(), isNull);
            final image =
                await (key.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: 1);
            try {
              final bytes = (await image.toByteData(
                format: ui.ImageByteFormat.png,
              ))!;
              final file = '$locale-$scale-${rtl ? 'rtl' : 'ltr'}-$state.png';
              await File('${output.path}/$file')
                  .writeAsBytes(bytes.buffer.asUint8List());
              captures.add(file);
            } finally {
              image.dispose();
            }
          }

          expect(k('category-manager-panel'), findsOneWidget);
          await capture('manager');
          final save = Completer<void>();
          storage.pending = save;
          try {
            await t.tap(k('calendar-visibility-category-1'));
            await t.pump();
            await t.pump(const Duration(seconds: 1));
            expect(
              find.descendant(
                of: k('category-manager-panel'),
                matching: find.byType(LinearProgressIndicator),
              ),
              findsNothing,
            );
            expect(
              t
                  .widget<IconButton>(k('calendar-visibility-category-1'))
                  .onPressed,
              isNull,
            );
            await capture('visibility-saving');
          } finally {
            save.complete();
            storage.pending = null;
            await t.pumpAndSettle();
          }
          await t.tap(k('calendar-color-category-1'));
          await t.pumpAndSettle();
          expect(k('category-color-dialog'), findsOneWidget);
          await capture('theme-color');
          await t.enterText(
            find.descendant(
              of: k('category-color-dialog'),
              matching: find.byType(TextField),
            ),
            '#197A86',
          );
          await capture('custom-color');
          await t.tap(k('category-color-save'));
          await t.pumpAndSettle();
          await t.tap(k('calendar-name-category-1'));
          await t.pumpAndSettle();
          await capture('rename');
          await t.tap(inside(k('calendar-name-dialog'), 'floating-form-close'));
          await t.pumpAndSettle();
          await t.drag(
            inside(k('category-manager-panel'), 'floating-form-drag-handle'),
            Offset(rtl ? -45 : 45, 55),
          );
          await capture('dragged');
          t.view.physicalSize = const Size(850, 620);
          await capture('resized');
          t.view.physicalSize = const Size(700, 320);
          await t.pumpAndSettle();
          expect(
            find
                .descendant(
                  of: k('category-manager-panel'),
                  matching: find.widgetWithText(
                    TextButton,
                    locale == 'en' ? 'Add category' : '添加分类',
                  ),
                )
                .hitTestable(),
            findsOneWidget,
          );
          expect(
            inside(
              k('category-manager-panel'),
              'floating-form-close',
            ).hitTestable(),
            findsOneWidget,
          );
          await capture('short-header');
          await t.pumpWidget(const SizedBox());
          await t.pumpAndSettle();
          p.dispose();
        }
      }
    }
    await File('${output.path}/manifest.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'captures': captures,
        'evidence': 'Actual Windows fonts, synthetic pointer. Native evidence is separate.',
      }),
    );
  });
  testWidgets(
    'native category manager drag with foreground ownership protection',
    (t) async {
      if (!const bool.fromEnvironment('SKED_NATIVE_POINTER_CHECK')) return;
      binding.shouldPropagateDevicePointerEvents = true;
      await DesktopWindowBridge.instance.initialize();
      final output = Directory(
        const String.fromEnvironment(
          'SKED_VISUAL_OUTPUT',
          defaultValue: '.scratch/category-manager-panel-visual',
        ),
      );
      await output.create(recursive: true);
      final evidence = <Map<String, dynamic>>[];
      Map<String, dynamic>? cursor;
      final p = await workspaceProvider(
        mode: AppMode.general,
        storage: categoryManagerStorage(),
      );
      Future<Map<String, dynamic>> command(
        String action, {
        Offset? point,
        Offset? end,
      }) async {
        final result = await t.runAsync(
          () => Process.run('powershell', [
            '-NoProfile',
            '-WindowStyle',
            'Hidden',
            '-ExecutionPolicy',
            'Bypass',
            '-File',
            File('tool/reminder_pointer_session.ps1').absolute.path,
            '-ProcessId',
            '$pid',
            '-Action',
            action,
            if (point != null) ...['-X', '${point.dx}', '-Y', '${point.dy}'],
            if (end != null) ...['-EndX', '${end.dx}', '-EndY', '${end.dy}'],
            if (action == 'restore') ...[
              '-SavedX',
              '${cursor!['savedX']}',
              '-SavedY',
              '${cursor['savedY']}',
            ],
          ]),
        );
        final text = result!.stdout.toString().trim();
        final report = text.startsWith('{')
            ? jsonDecode(text) as Map<String, dynamic>
            : {'status': 'blocked', 'reason': result.stderr.toString()};
        evidence.add(report);
        return report;
      }

      try {
        t.view.resetPhysicalSize();
        t.view.resetDevicePixelRatio();
        await t.pumpWidget(categoryManagerHarness(p));
        await t.pumpAndSettle();
        await t.tap(k('workspace-resource-open'));
        await t.pumpAndSettle();
        cursor = await command('inspect');
        if (cursor['status'] != 'ok') return;
        await t.runAsync(
          () => Process.run('powershell', [
            '-NoProfile',
            '-WindowStyle',
            'Hidden',
            '-Command',
            '(New-Object -ComObject WScript.Shell).AppActivate($pid)',
          ]),
        );
        final before = t.getRect(k('floating-form-surface'));
        final point = t.getCenter(
          inside(k('category-manager-panel'), 'floating-form-drag-handle'),
        );
        final result = await command(
          'drag',
          point: point,
          end: point + const Offset(45, 35),
        );
        await t.pumpAndSettle();
        if (result['status'] != 'ok') return;
        final after = t.getRect(k('floating-form-surface'));
        expect(after.left - before.left, closeTo(45, 3));
        expect(after.top - before.top, closeTo(35, 3));
        evidence.add({
          'status': 'passed',
          'scenario': 'native manager title drag',
        });
      } finally {
        if (cursor?['status'] == 'ok') await command('restore');
        await File(
          '${output.path}/native.json',
        ).writeAsString(const JsonEncoder.withIndent('  ').convert(evidence));
        await t.pumpWidget(const SizedBox());
        await t.pumpAndSettle();
        p.dispose();
        binding.shouldPropagateDevicePointerEvents = false;
      }
    },
  );
}
