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
import 'package:sked/services/desktop_window_bridge.dart';
import 'package:sked/widgets/general_event_details_sheet.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';

import '../test/support/mobile_layout_data.dart';
import '../test/support/workspace_harness.dart';

Finder key(String value) => find.byKey(ValueKey(value));
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('week jump and single date from the home and event editor', (
    t,
  ) async {
    await DesktopWindowBridge.instance.initialize();
    final out = Directory(
      const String.fromEnvironment(
        'SKED_VISUAL_OUTPUT',
        defaultValue: '.scratch/mobile-secondary-pickers-after',
      ),
    );
    await out.create(recursive: true);
    const baseline = bool.fromEnvironment('SKED_VISUAL_BASELINE');
    final manifest = <Map<String, Object?>>[];
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetPadding);
    addTearDown(t.view.resetViewPadding);
    addTearDown(t.view.resetViewInsets);
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
    try {
      for (final (name, size, scale, brightness, platform, language) in cases) {
        debugDefaultTargetPlatformOverride = platform;
        DesktopWindowBridge.instance.available =
            platform == TargetPlatform.windows;
        t.view.physicalSize = size;
        final safe = platform == TargetPlatform.android
            ? const FakeViewPadding(top: 24, bottom: 24)
            : const FakeViewPadding();
        t.view.padding = safe;
        t.view.viewPadding = safe;
        final base = mobileLayoutData(locale: language);
        final data = base.copyWith(
          studentMode: base.studentMode.copyWith(
            timetables: [
              for (final table in base.studentMode.timetables)
                table.copyWith(config: table.config.copyWith(totalWeeks: 19)),
            ],
          ),
        );
        final p = await workspaceProvider(
          locale: language,
          storage: WorkspaceMemoryStorage(data),
        );
        final boundary = GlobalKey();
        Future<void> tap(Finder f) async {
          await t.ensureVisible(f);
          await t.pumpAndSettle();
          await t.tap(f);
          await t.pumpAndSettle();
        }

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
              'baseline': baseline,
              'evidence': 'Actual home / details / editor entries in Windows Flutter rendering. Android geometry and IME simulated, not device acceptance.',
            });
          } finally {
            image.dispose();
          }
        }

        await p.switchMode(AppMode.student);
        await p.setSelectedWeek(2);
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
        await tap(key('student-week-picker-button'));
        if (!baseline &&
            platform == TargetPlatform.android &&
            size.width < 600) {
          final scroll = t
              .widget<GridView>(key('sked-week-picker-grid'))
              .controller!;
          for (final value in [2, 19]) {
            scroll.jumpTo(value == 2 ? 0 : scroll.position.maxScrollExtent);
            await t.pumpAndSettle();
            final text = find.descendant(
              of: key('student-week-option-$value'),
              matching: find.text('$value'),
            );
            await t.ensureVisible(text);
            await t.pumpAndSettle();
            final paragraph = t.renderObject<RenderParagraph>(text);
            expect(
              paragraph.getMaxIntrinsicWidth(double.infinity),
              lessThanOrEqualTo(paragraph.size.width + .01),
            );
            expect(t.widget<Text>(text).style!.fontSize, 18);
          }
          scroll.jumpTo(0);
          await t.pumpAndSettle();
        }
        await capture('week-jump');
        await tap(key('sked-week-picker-close'));
        await p.switchMode(AppMode.general);
        await t.pumpAndSettle();
        await tap(
          key('general-timed-occurrence-mobile-day-21-2026-09-21T08:10:00.000'),
        );
        final details = find.byType(GeneralEventDetailsSheet);
        final l = AppLocalizations.of(t.element(details));
        await tap(
          find.descendant(of: details, matching: find.byTooltip(l.editEvent)),
        );
        final editor = find.byType(GeneralEventEditorSheet);
        await tap(
          find
              .descendant(of: editor, matching: find.byTooltip(l.pickDate))
              .first,
        );
        if (!baseline &&
            platform == TargetPlatform.android &&
            size.width < 600) {
          for (final value in [21, 22]) {
            final text = find.descendant(
              of: key('sked-date-2026-09-$value'),
              matching: find.text('$value'),
            );
            final paragraph = t.renderObject<RenderParagraph>(text);
            expect(paragraph.didExceedMaxLines, isFalse);
            expect(
              paragraph.getMaxIntrinsicWidth(double.infinity),
              lessThanOrEqualTo(paragraph.size.width + .01),
            );
            expect(t.widget<Text>(text).style!.fontSize, 18);
          }
          expect(key('sked-date-cancel').hitTestable(), findsOneWidget);
          expect(key('sked-date-confirm').hitTestable(), findsOneWidget);
        }
        await capture('single-date');
        if (platform == TargetPlatform.android && size.width < 600) {
          await tap(key('sked-date-input-toggle'));
          t.view.viewInsets = const FakeViewPadding(bottom: 300);
          t.view.padding = const FakeViewPadding(top: 24);
          await t.pumpAndSettle();
          await capture('single-date-input-ime');
          t.view.viewInsets = const FakeViewPadding();
          t.view.padding = safe;
          await t.pumpAndSettle();
        }
        await tap(key('sked-date-cancel'));
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
