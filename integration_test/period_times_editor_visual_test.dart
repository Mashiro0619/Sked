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
import 'package:sked/widgets/sked_time_picker.dart';

import '../test/support/workspace_harness.dart';

Finder k(String id) => find.byKey(ValueKey(id));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('compact period editor actual fonts, errors, saving and picker', (
    t,
  ) async {
    await DesktopWindowBridge.instance.initialize();
    final output = Directory(
      const String.fromEnvironment(
        'SKED_VISUAL_OUTPUT',
        defaultValue: '.scratch/period-editor-visual',
      ),
    );
    await output.create(recursive: true);
    final captures = <Map<String, Object?>>[];
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetPadding);
    addTearDown(t.view.resetViewPadding);
    try {
      for (final (name, size, scale, brightness, platform, locale, direction)
          in [
            (
              'desktop-light',
              const Size(1280, 900),
              1.0,
              Brightness.light,
              TargetPlatform.windows,
              'zh',
              TextDirection.ltr,
            ),
            (
              'desktop-dark',
              const Size(1440, 900),
              1.3,
              Brightness.dark,
              TargetPlatform.windows,
              'en',
              TextDirection.ltr,
            ),
            (
              'desktop-large',
              const Size(1280, 900),
              2.0,
              Brightness.light,
              TargetPlatform.windows,
              'en',
              TextDirection.ltr,
            ),
            (
              'tablet',
              const Size(800, 1000),
              1.0,
              Brightness.light,
              TargetPlatform.android,
              'zh',
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
              'phone-large',
              const Size(320, 640),
              2.0,
              Brightness.dark,
              TargetPlatform.android,
              'en',
              TextDirection.rtl,
            ),
          ]) {
        debugDefaultTargetPlatformOverride = platform;
        DesktopWindowBridge.instance.available =
            platform == TargetPlatform.windows;
        t.view.physicalSize = size;
        final safe = platform == TargetPlatform.android
            ? const FakeViewPadding(top: 24, bottom: 24)
            : const FakeViewPadding();
        t.view.padding = safe;
        t.view.viewPadding = safe;
        final storage = WorkspaceMemoryStorage(
          buildInitialAppData(buildDefaultPeriodTimes(), localeCode: locale),
        );
        final p = await workspaceProvider(
          storage: storage,
          mode: AppMode.student,
          locale: locale,
        );
        final boundary = GlobalKey();
        await t.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: WorkspaceHarness(
              provider: p,
              locale: Locale(locale),
              brightness: brightness,
              textScale: scale,
              textDirection: direction,
              home: PeriodTimesPage(periodTimeSetId: p.periodTimeSets.first.id),
            ),
          ),
        );
        await t.pumpAndSettle();
        final l = AppLocalizations.of(t.element(find.byType(PeriodTimesPage)));
        final list = t
            .widget<ListView>(k('period-times-editor-scroll-view'))
            .controller!;
        Future<void> capture(String scene) async {
          expect(t.takeException(), isNull, reason: '$name $scene');
          for (final id in [
            'period-start-time-action',
            'period-end-time-action',
          ]) {
            final values = find.descendant(
              of: k(id),
              matching: find.byType(Text),
            );
            for (final element in values.evaluate()) {
              final paragraph = element.renderObject! as RenderParagraph;
              expect(
                paragraph.didExceedMaxLines,
                isFalse,
                reason: '$name $scene time text',
              );
              expect(
                paragraph.getMaxIntrinsicWidth(double.infinity),
                lessThanOrEqualTo(paragraph.size.width + .5),
                reason: '$name $scene complete time value',
              );
            }
          }

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
              'widthDp': size.width,
              'heightDp': size.height,
              'scale': scale,
              'brightness': brightness.name,
              'platformStyle': platform.name,
              'locale': locale,
              'direction': direction.name,
            });
          } finally {
            image.dispose();
          }
        }

        if (name == 'desktop-light') {
          expect(k('period-times-table-header'), findsOneWidget);
          expect(t.getSize(k('period-row-1')).height, lessThanOrEqualTo(56));
        }
        if (name == 'phone') {
          expect(k('period-times-table-header'), findsNothing);
          expect(t.getSize(k('period-row-1')).height, lessThanOrEqualTo(84));
        }
        await capture('list');
        list.jumpTo(list.position.maxScrollExtent);
        await t.pumpAndSettle();
        await capture('last-periods');
        list.jumpTo(0);
        await t.pumpAndSettle();
        final start = find.descendant(
          of: k('period-row-1'),
          matching: k('period-start-time-action'),
        );
        await t.ensureVisible(start);
        await t.tap(start);
        await t.pumpAndSettle();
        await capture('time-picker');
        await t.tap(k('sked-time-cancel'));
        await t.pumpAndSettle();
        list.jumpTo(0);
        await t.pumpAndSettle();
        final rowBefore = t.getTopLeft(k('period-row-1')).dy;
        final statusBefore = t.getSize(k('period-times-save-status'));
        storage.saveError = StateError('visual save failure');
        await t.enterText(
          k('period-times-name'),
          locale == 'zh' ? '夏季作息' : 'Summer timetable',
        );
        await t.pump(const Duration(milliseconds: 500));
        await t.pumpAndSettle();
        expect(find.text(l.periodTimesSaveFailed), findsOneWidget);
        expect(t.getTopLeft(k('period-row-1')).dy, rowBefore);
        expect(t.getSize(k('period-times-save-status')), statusBefore);
        await capture('save-failure');
        await t.tap(k('period-times-retry-save'));
        await t.pumpAndSettle();
        expect(find.text(l.periodTimesSaved), findsOneWidget);
        await t.ensureVisible(start);
        await t.tap(start);
        await t.pumpAndSettle();
        final picker = find.byType(SkedTimePicker);
        var fields = find.descendant(
          of: picker,
          matching: find.byType(TextField),
        );
        if (fields.evaluate().isEmpty) {
          await t.tap(
            find.descendant(
              of: picker,
              matching: find.byIcon(Icons.keyboard_outlined),
            ),
          );
          await t.pumpAndSettle();
          fields = find.descendant(
            of: picker,
            matching: find.byType(TextField),
          );
        }
        expect(fields, findsNWidgets(2));
        await t.enterText(fields.at(0), '08');
        await t.enterText(fields.at(1), '50');
        await t.pumpAndSettle();
        await t.tap(k('sked-time-confirm'));
        await t.pumpAndSettle();
        expect(k('period-error-1'), findsOneWidget);
        expect(find.text(l.periodTimesInvalidStatus), findsOneWidget);
        list.jumpTo(0);
        await t.pumpAndSettle();
        await capture('invalid-time');
        await t.pumpWidget(const SizedBox.shrink());
        await t.pumpAndSettle();
        p.dispose();
      }
      await File('${output.path}/manifest.json').writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'evidence': 'Actual Flutter rendering on Windows; Android geometry, safe areas and platform styling are simulated.',
          'captures': captures,
        }),
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
      DesktopWindowBridge.instance.available = true;
    }
  });
}
