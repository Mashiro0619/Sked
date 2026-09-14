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
import 'package:sked/widgets/sked_date_picker.dart';

import '../test/support/mobile_layout_data.dart';
import '../test/support/workspace_harness.dart';

Finder key(String value) => find.byKey(ValueKey(value));
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('mobile vertical rhythm and month/year layers through real homes', (
    t,
  ) async {
    await DesktopWindowBridge.instance.initialize();
    final out = Directory(
      const String.fromEnvironment(
        'SKED_VISUAL_OUTPUT',
        defaultValue: '.scratch/mobile-calendar-spacing-after',
      ),
    );
    await out.create(recursive: true);
    final manifest = <Map<String, Object?>>[];
    final today = normalizeDateOnly(DateTime.now());
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
        'phone-320-zh',
        const Size(320, 850),
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
        'phone-412-en',
        const Size(412, 915),
        1,
        Brightness.light,
        TargetPlatform.android,
        'en',
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
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetPadding);
    addTearDown(t.view.resetViewPadding);
    try {
      for (final (name, size, scale, brightness, platform, language) in cases) {
        debugDefaultTargetPlatformOverride = platform;
        DesktopWindowBridge.instance.available =
            platform == TargetPlatform.windows;
        t.view.physicalSize = size;
        final padding = platform == TargetPlatform.android
            ? const FakeViewPadding(top: 44, bottom: 24)
            : const FakeViewPadding();
        t.view.padding = padding;
        t.view.viewPadding = padding;
        final base = mobileLayoutData(locale: language);
        final data = base.copyWith(
          generalMode: base.generalMode.copyWith(
            selectedDateIso: '2026-09-23',
            viewSwitchBehavior: generalViewSwitchBehaviorMenu,
            customDateRange: GeneralDateRange(
              DateTime(2026, 9, 22),
              DateTime(2026, 9, 24),
            ),
            schedules: [
              for (final cal in base.generalMode.schedules)
                cal.copyWith(name: scale == 1 ? 'My calendar' : cal.name),
            ],
          ),
          studentMode: base.studentMode.copyWith(
            timetables: [
              for (final table in base.studentMode.timetables)
                table.copyWith(
                  config: table.config.copyWith(
                    startDate: startOfWeekMonday(today),
                  ),
                ),
            ],
          ),
        );
        final p = await workspaceProvider(
          locale: language,
          storage: WorkspaceMemoryStorage(data),
        );
        final boundary = GlobalKey();
        Future<void> capture(String scene) async {
          if (const bool.fromEnvironment('SKED_VISUAL_CATEGORY_PRIORITY') &&
              name == 'phone-360-zh' &&
              scene == 'general-home') {
            final category = find.descendant(
              of: key('general-calendar-selector'),
              matching: find.text('My calendar'),
            );
            final paragraph = t.renderObject<RenderParagraph>(category);
            expect(paragraph.didExceedMaxLines, isFalse);
            expect(
              paragraph.getMaxIntrinsicWidth(double.infinity),
              lessThanOrEqualTo(paragraph.size.width + .01),
            );
            expect(
              find.descendant(
                of: key('general-date-title-button'),
                matching: find.text('9/22–24'),
              ),
              findsOneWidget,
            );
          }
          const verify = bool.fromEnvironment('SKED_VISUAL_VERIFY');
          if (verify &&
              platform == TargetPlatform.android &&
              size.shortestSide < 600 &&
              scale == 1 &&
              (scene.startsWith('months-') || scene.startsWith('years-'))) {
            final ids = scene.startsWith('months-')
                ? [for (var i = 1; i <= 12; i++) 'sked-date-month-2026-$i']
                : [for (var i = 2016; i < 2028; i++) 'sked-date-year-$i'];
            final firstY = t.getRect(key(ids.first)).center.dy;
            expect(
              ids.where(
                (id) => (t.getRect(key(id)).center.dy - firstY).abs() < .1,
              ),
              hasLength(4),
              reason:
                  'Actual platform fonts must fit the planned four columns: $name $scene',
            );
            expect(t.getSize(key('sked-date-choice-grid')).height, 152);
            expect(
              t.getSize(key('sked-date-picker-surface')).height,
              lessThan(300),
            );
            for (final id in ids) {
              final text = find.descendant(
                of: key(id),
                matching: find.byType(Text),
              );
              final paragraph = t.renderObject<RenderParagraph>(text);
              expect(paragraph.didExceedMaxLines, isFalse);
              expect(t.widget<Text>(text).style!.fontSize, 18);
            }
          }

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
            final file = '$name-$scene.png';
            await File('${out.path}/$file')
                .writeAsBytes(bytes.buffer.asUint8List());
            manifest.add({
              'file': file,
              'widthDp': size.width,
              'heightDp': size.height,
              'textScale': scale,
              'brightness': brightness.name,
              'platformStyle': platform.name,
              'locale': language,
              'today': today.toIso8601String(),
              'evidence': 'Actual homepage on Windows Flutter; Android safe areas and geometry simulated, not device acceptance.',
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
        Future<void> tap(String value) async {
          final target = key(value).last;
          await t.ensureVisible(target);
          await t.tap(target);
          await t.pumpAndSettle();
        }

        await capture('general-home');
        await tap(
          platform == TargetPlatform.windows
              ? 'general-date-picker'
              : 'general-date-title-button',
        );
        await tap('sked-date-month-year');
        await capture('months-from-range');
        await tap('sked-date-month-year');
        await capture('years-from-range');
        await tap('sked-date-picker-close');
        await tap('general-view-switcher');
        await t.tap(
          find
              .byWidgetPredicate(
                (w) =>
                    w is PopupMenuItem<String> && w.value == generalViewMonth,
              )
              .last,
        );
        await t.pumpAndSettle();
        await tap(
          platform == TargetPlatform.windows
              ? 'general-date-picker'
              : 'general-date-title-button',
        );
        expect(
          t
              .widget<SkedDatePicker>(find.byType(SkedDatePicker).last)
              .selectionUnit,
          DateSelectionUnit.month,
        );
        await capture('months-direct');
        await tap('sked-date-month-year');
        await capture('years-direct');
        await tap('sked-date-picker-close');
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
    await File('${out.path}/manifest.json')
        .writeAsString(const JsonEncoder.withIndent('  ').convert(manifest));
  });
}
