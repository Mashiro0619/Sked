import '../support/capture_output_directory.dart';

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/period_times_page.dart';
import 'package:sked/services/desktop_window_bridge.dart';
import 'package:sked/widgets/desktop_window_host.dart';
import 'package:sked/widgets/period_time_set_manager.dart';
import 'package:sked/widgets/text_transfer_widgets.dart';

import '../../test/support/workspace_harness.dart';

Finder _key(String value) => find.byKey(ValueKey(value));

void registerCaptureScenarios() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'period management has one toolbar across desktop and touch layouts',
    (t) async {
      final bridge = DesktopWindowBridge.instance;
      await bridge.initialize();
      final originalAvailable = bridge.available;
      final originalPlatform = debugDefaultTargetPlatformOverride;
      final output = createCaptureOutputDirectory(label: 'period-time-sets');
      await output.create(recursive: true);
      final captures = <Map<String, Object?>>[];
      final periods = decodePeriodTimesEnvelope(
        await File('assets/default_period_times.json').readAsString(),
      );
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetPadding);
      addTearDown(t.view.resetViewPadding);
      try {
        for (final (name, size, scale, brightness, platform, locale, direction)
            in [
              (
                'desktop',
                const Size(1372, 768),
                1.0,
                Brightness.light,
                TargetPlatform.windows,
                'zh',
                TextDirection.ltr,
              ),
              (
                'desktop-dark',
                const Size(1280, 800),
                1.0,
                Brightness.dark,
                TargetPlatform.windows,
                'en',
                TextDirection.ltr,
              ),
              (
                'desktop-large',
                const Size(1280, 800),
                2.0,
                Brightness.light,
                TargetPlatform.windows,
                'zh',
                TextDirection.ltr,
              ),
              (
                'narrow-desktop',
                const Size(620, 800),
                1.3,
                Brightness.light,
                TargetPlatform.windows,
                'en',
                TextDirection.ltr,
              ),
              (
                'phone',
                const Size(393, 852),
                1.0,
                Brightness.light,
                TargetPlatform.android,
                'zh',
                TextDirection.ltr,
              ),
              (
                'phone-large-rtl',
                const Size(320, 720),
                2.0,
                Brightness.dark,
                TargetPlatform.android,
                'en',
                TextDirection.rtl,
              ),
            ]) {
          debugDefaultTargetPlatformOverride = platform;
          bridge.available =
              originalAvailable && platform == TargetPlatform.windows;
          t.view.physicalSize = size;
          final safe = platform == TargetPlatform.android
              ? const FakeViewPadding(top: 24, bottom: 24)
              : const FakeViewPadding();
          t.view.padding = safe;
          t.view.viewPadding = safe;
          final storage = WorkspaceMemoryStorage(
            buildInitialAppData(periods, localeCode: locale),
          );
          final p = await workspaceProvider(storage: storage, locale: locale);
          final boundary = GlobalKey();
          try {
            await t.pumpWidget(
              RepaintBoundary(
                key: boundary,
                child: WorkspaceHarness(
                  provider: p,
                  locale: Locale(locale),
                  textScale: scale,
                  textDirection: direction,
                  brightness: brightness,
                  home: Builder(
                    builder: (context) => Scaffold(
                      body: TextButton(
                        onPressed: () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => const PeriodTimeSetManagerPage(),
                          ),
                        ),
                        child: const Text('Open manager'),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await t.pumpAndSettle();
            await t.tap(find.text('Open manager'));
            await t.pumpAndSettle();
            final set = p.studentView.periodTimeSets.first;
            await t.tap(_key('period-time-set-${set.id}'));
            await t.pumpAndSettle();
            final l = AppLocalizations.of(
              t.element(find.byType(PeriodTimesPage)),
            );

            Future<void> capture(String scene) async {
              expect(t.takeException(), isNull, reason: '$name $scene');
              expect(find.byType(WorkbenchAppBar), findsOneWidget);
              expect(find.byType(BackButton), findsOneWidget);
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
                final filename = '$name-$scene.png';
                await File('${output.path}/$filename')
                    .writeAsBytes(bytes.buffer.asUint8List());
                captures.add({
                  'file': filename,
                  'size': [size.width, size.height],
                  'textScale': scale,
                  'platformStyle': platform.name,
                  'locale': locale,
                  'direction': direction.name,
                });
              } finally {
                image.dispose();
              }
            }

            expect(_key('period-time-set-menu').hitTestable(), findsOneWidget);
            expect(
              t.widget<WorkbenchAppBar>(find.byType(WorkbenchAppBar)).bottom,
              isNull,
            );
            await capture('editor');
            if (name == 'desktop' || name == 'phone-large-rtl') {
              await t.tap(_key('period-time-set-menu'));
              await t.pumpAndSettle();
              await capture('menu');
              await t.tap(find.text(l.importPeriodTemplateText));
              await t.pumpAndSettle();
              expect(find.byType(TextImportPage), findsOneWidget);
              await capture('template-import');
              await t.tap(find.byType(BackButton));
              await t.pumpAndSettle();
            }
            final controller = t
                .widget<ListView>(_key('period-times-editor-scroll-view'))
                .controller!;
            controller.jumpTo(controller.position.maxScrollExtent);
            await t.pumpAndSettle();
            await capture('last-periods');
          } finally {
            await t.pumpWidget(const SizedBox.shrink());
            await t.pumpAndSettle();
            p.dispose();
          }
        }
        await File('${output.path}/manifest.json').writeAsString(
          const JsonEncoder.withIndent('  ').convert({
            'evidence': 'Actual Windows Flutter rendering with memory data; Android layout and input are simulated.',
            'captures': captures,
          }),
        );
      } finally {
        debugDefaultTargetPlatformOverride = originalPlatform;
        bridge.available = originalAvailable;
      }
    },
  );
}
