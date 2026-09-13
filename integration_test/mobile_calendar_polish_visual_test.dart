import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/desktop_window_bridge.dart';

import '../test/support/mobile_layout_data.dart';
import '../test/support/workspace_harness.dart';

Finder key(String value) => find.byKey(ValueKey(value));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('phone calendar from the ordinary week title and home toolbars', (
    t,
  ) async {
    await DesktopWindowBridge.instance.initialize();
    final output = Directory(
      const String.fromEnvironment(
        'SKED_VISUAL_OUTPUT',
        defaultValue: '.scratch/mobile-calendar-polish-after',
      ),
    );
    await output.create(recursive: true);
    const baseline = bool.fromEnvironment('SKED_VISUAL_BASELINE');
    final manifest = <Map<String, Object?>>[];
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetPadding);
    addTearDown(t.view.resetViewPadding);
    final cases = <(String, Size, double, Brightness, TargetPlatform, String)>[
      (
        'phone-360-zh',
        const Size(360, 850),
        1,
        Brightness.light,
        TargetPlatform.android,
        'zh',
      ),
      (
        'phone-393-zh',
        const Size(393, 852),
        1.3,
        Brightness.dark,
        TargetPlatform.android,
        'zh',
      ),
      (
        'phone-320-zh',
        const Size(320, 850),
        1,
        Brightness.light,
        TargetPlatform.android,
        'zh',
      ),
      (
        'phone-320-2x-zh',
        const Size(320, 900),
        2,
        Brightness.dark,
        TargetPlatform.android,
        'zh',
      ),
      (
        'phone-412-en',
        const Size(412, 915),
        1,
        Brightness.light,
        TargetPlatform.android,
        'en',
      ),
      (
        'phone-360-2x-zh',
        const Size(360, 900),
        2,
        Brightness.dark,
        TargetPlatform.android,
        'zh',
      ),
      (
        'phone-landscape-en',
        const Size(852, 393),
        1,
        Brightness.light,
        TargetPlatform.android,
        'en',
      ),
      (
        'tablet-1280-en',
        const Size(1280, 1000),
        1,
        Brightness.light,
        TargetPlatform.android,
        'en',
      ),
      (
        'windows-1440-en',
        const Size(1440, 1000),
        1,
        Brightness.dark,
        TargetPlatform.windows,
        'en',
      ),
    ];
    try {
      for (final (name, size, scale, brightness, platform, language) in cases) {
        debugDefaultTargetPlatformOverride = platform;
        DesktopWindowBridge.instance.available =
            platform == TargetPlatform.windows;
        t.view.physicalSize = size;
        final padding = platform == TargetPlatform.android
            ? const FakeViewPadding(top: 24, bottom: 24)
            : const FakeViewPadding();
        t.view.padding = padding;
        t.view.viewPadding = padding;
        final base = mobileLayoutData(locale: language);
        final calendar = base.generalMode.schedules.single;
        final data = base.copyWith(
          generalMode: base.generalMode.copyWith(
            schedules: [calendar.copyWith(name: 'My calendar')],
          ),
        );
        final p = await workspaceProvider(
          locale: language,
          storage: WorkspaceMemoryStorage(data),
        );
        final boundary = GlobalKey();
        Future<void> capture(String scene) async {
          expect(t.takeException(), isNull, reason: '$name $scene');
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
            manifest.add({
              'file': filename,
              'widthDp': size.width,
              'heightDp': size.height,
              'textScale': scale,
              'brightness': brightness.name,
              'platformStyle': platform.name,
              'locale': language,
              'baseline': baseline,
              'evidence': 'Actual home entry in Windows Flutter rendering. Android geometry simulated, not device acceptance.',
            });
          } finally {
            image.dispose();
          }
        }

        await t.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: WorkspaceHarness(
              provider: p,
              locale: Locale(language),
              textScale: scale,
              brightness: brightness,
            ),
          ),
        );
        await t.pumpAndSettle();
        await capture('general-home');
        final title = key(
          platform == TargetPlatform.windows
              ? 'general-date-picker'
              : 'general-date-title-button',
        );
        await t.tap(title);
        await t.pumpAndSettle();
        await capture('week-picker');
        if (!baseline &&
            platform == TargetPlatform.android &&
            size.width < 600) {
          if (language == 'zh') {
            final heading = t.renderObject<RenderParagraph>(
              find.descendant(
                of: key('sked-date-month-year'),
                matching: find.byType(RichText),
              ),
            );
            final value = heading.text.toPlainText();
            final month = value.indexOf('9');
            final unit = value.indexOf('月');
            final numberBox = heading
                .getBoxesForSelection(
                  TextSelection(baseOffset: month, extentOffset: month + 1),
                )
                .first;
            final unitBox = heading
                .getBoxesForSelection(
                  TextSelection(baseOffset: unit, extentOffset: unit + 1),
                )
                .first;
            expect(
              (numberBox.top - unitBox.top).abs(),
              lessThan((numberBox.bottom - numberBox.top) / 2),
              reason: '$name must not split 9 and 月 across lines',
            );
          }
          // Check actual rendered glyphs, not just nominal font sizes: the
          // selected circle must not clip two-digit dates at 320dp / 2x text.
          for (final day in [22, 23]) {
            final text = find.descendant(
              of: key('sked-date-2026-09-$day'),
              matching: find.text('$day'),
            );
            final paragraph = t.renderObject<RenderParagraph>(text);
            expect(paragraph.didExceedMaxLines, isFalse, reason: '$name $day');
            expect(
              paragraph.getMaxIntrinsicWidth(double.infinity),
              lessThanOrEqualTo(paragraph.size.width + .01),
              reason: '$name day $day must not be clipped',
            );
            expect(
              paragraph.getMaxIntrinsicHeight(paragraph.size.width),
              lessThanOrEqualTo(paragraph.size.height + .01),
              reason: '$name day $day must not be clipped vertically',
            );
          }
          final gesture = await t.startGesture(
            t.getCenter(key('sked-date-2026-09-22')),
            kind: PointerDeviceKind.touch,
          );
          await gesture.moveBy(const Offset(25, 0));
          await gesture.moveTo(t.getCenter(key('sked-date-2026-09-26')));
          await t.pump();
          await capture('week-drag-preview');
          expect(p.customGeneralDateRange, isNull);
          await gesture.up();
          await t.pumpAndSettle();
          expect(
            p.customGeneralDateRange,
            GeneralDateRange(DateTime(2026, 9, 22), DateTime(2026, 9, 26)),
          );
          await capture('week-drag-applied');
          await p.clearGeneralDateRange();
          await p.setSelectedGeneralDate(DateTime(2026, 9, 23));
          await t.pumpAndSettle();
        } else {
          await t.tap(key('sked-date-picker-close'));
          await t.pumpAndSettle();
        }
        await p.setGeneralDateRange(
          GeneralDateRange(DateTime(2026, 9, 21), DateTime(2026, 9, 27)),
        );
        await t.pumpAndSettle();
        await t.tap(title);
        await t.pumpAndSettle();
        await capture('custom-picker');
        await t.tap(key('sked-date-picker-close'));
        await t.pumpAndSettle();
        await p.clearGeneralDateRange();
        await p.setSelectedGeneralDate(DateTime(2026, 9, 23));
        await p.switchMode(AppMode.student);
        await t.pumpAndSettle();
        await capture('student-home');
        await t.pumpWidget(const SizedBox.shrink());
        await t.pumpAndSettle();
        p.dispose();
      }
    } finally {
      debugDefaultTargetPlatformOverride = null;
      DesktopWindowBridge.instance.available = false;
    }
    await File('${output.path}/manifest.json')
        .writeAsString(const JsonEncoder.withIndent('  ').convert(manifest));
  });
}
