import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/general_schedule_home_screen.dart';
import 'package:sked/screens/general_display_settings_page.dart';
import 'package:sked/services/desktop_window_bridge.dart';
import 'package:sked/widgets/sked_date_picker.dart';
import 'package:sked/widgets/sked_time_picker.dart';
import 'package:sked/widgets/sked_week_picker.dart';

import '../test/support/mobile_layout_data.dart';
import '../test/support/workspace_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'mobile layout repair: real Windows rendering, simulated Android geometry',
    (t) async {
      await DesktopWindowBridge.instance.initialize();
      const baseline = bool.fromEnvironment('SKED_VISUAL_BASELINE');
      final output = Directory(
        const String.fromEnvironment(
          'SKED_VISUAL_OUTPUT',
          defaultValue: '.scratch/mobile-layout-visual',
        ),
      );
      await output.create(recursive: true);
      final manifest = <Map<String, Object?>>[];
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.view.resetPadding);
      addTearDown(t.view.resetViewPadding);
      addTearDown(t.view.resetViewInsets);
      final cases =
          <(String, Size, double, Brightness, TargetPlatform, String)>[
            (
              'phone-360-zh',
              const Size(360, 800),
              1,
              Brightness.light,
              TargetPlatform.android,
              'zh',
            ),
            if (!baseline) ...[
              (
                'phone-320-zh',
                const Size(320, 740),
                1,
                Brightness.light,
                TargetPlatform.android,
                'zh',
              ),
              (
                'phone-393-zh',
                const Size(393, 852),
                1,
                Brightness.light,
                TargetPlatform.android,
                'zh',
              ),
              (
                'phone-412-zh',
                const Size(412, 915),
                1,
                Brightness.light,
                TargetPlatform.android,
                'zh',
              ),
              (
                'phone-320-2x-zh-dark',
                const Size(320, 850),
                2,
                Brightness.dark,
                TargetPlatform.android,
                'zh',
              ),
              (
                'phone-393-1_3x-en-dark',
                const Size(393, 852),
                1.3,
                Brightness.dark,
                TargetPlatform.android,
                'en',
              ),
              (
                'phone-360-1_3x-zh-dark',
                const Size(360, 800),
                1.3,
                Brightness.dark,
                TargetPlatform.android,
                'zh',
              ),
              (
                'phone-landscape-zh',
                const Size(852, 393),
                1,
                Brightness.dark,
                TargetPlatform.android,
                'zh',
              ),
              (
                'phone-landscape-2x-en',
                const Size(740, 320),
                2,
                Brightness.light,
                TargetPlatform.android,
                'en',
              ),
              (
                'tablet-800-zh',
                const Size(800, 1280),
                1,
                Brightness.light,
                TargetPlatform.android,
                'zh',
              ),
              (
                'windows-1440-en',
                const Size(1440, 900),
                1,
                Brightness.light,
                TargetPlatform.windows,
                'en',
              ),
              (
                'windows-560-zh',
                const Size(560, 800),
                1,
                Brightness.dark,
                TargetPlatform.windows,
                'zh',
              ),
            ],
          ];
      try {
        for (final (name, size, scale, brightness, platform, language)
            in cases) {
          debugDefaultTargetPlatformOverride = platform;
          DesktopWindowBridge.instance.available =
              platform == TargetPlatform.windows;
          t.view.physicalSize = size;
          t.view.viewInsets = const FakeViewPadding();
          final padding = platform == TargetPlatform.android
              ? const FakeViewPadding(top: 24, bottom: 24)
              : const FakeViewPadding();
          t.view.padding = padding;
          t.view.viewPadding = padding;
          final data = mobileLayoutData(locale: language);
          final p = await workspaceProvider(
            storage: WorkspaceMemoryStorage(data),
            locale: language,
          );
          final boundary = GlobalKey();
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
          Future<void> capture(String state) async {
            expect(t.takeException(), isNull, reason: '$name $state');
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
              final file = '$name-$state.png';
              await File('${output.path}/$file')
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
                'evidence': 'Windows Flutter renderer. Android phone/tablet geometry, IME and safe areas simulated; not device acceptance.',
              });
            } finally {
              image.dispose();
            }
          }

          await capture('general-week');
          final owner = t.element(find.byType(GeneralScheduleHomeScreen));
          unawaited(
            showSkedDatePicker(
              context: owner,
              workspace: AppMode.general,
              initialDate: DateTime(2026, 9, 23),
              firstDate: DateTime(1970),
              lastDate: DateTime(2100),
            ),
          );
          await t.pumpAndSettle();
          await capture('date');
          Navigator.of(owner, rootNavigator: true).pop();
          await t.pumpAndSettle();
          unawaited(
            showSkedTimePicker(
              context: owner,
              workspace: AppMode.general,
              initialTime: const TimeOfDay(hour: 13, minute: 7),
              alwaysUse24HourFormat: true,
            ),
          );
          await t.pumpAndSettle();
          await capture('time');
          if (size.width < 600 && platform == TargetPlatform.android) {
            await t.enterText(
              find.byKey(const ValueKey('sked-time-minute-input')),
              '17',
            );
            t.view.viewInsets = const FakeViewPadding(bottom: 300);
            t.view.padding = const FakeViewPadding(top: 24);
            await t.pumpAndSettle();
            await capture('time-ime');
          }
          Navigator.of(owner, rootNavigator: true).pop();
          t.view.viewInsets = const FakeViewPadding();
          t.view.padding = padding;
          await t.pumpAndSettle();
          if (!baseline) {
            unawaited(
              Navigator.of(owner, rootNavigator: true).push<void>(
                MaterialPageRoute(
                  builder: (_) => const GeneralDisplaySettingsPage(),
                ),
              ),
            );
            await t.pumpAndSettle();
            final setting = find.byKey(
              const ValueKey('general-fit-week-columns-setting'),
            );
            await t.ensureVisible(setting);
            await t.pumpAndSettle();
            await capture('general-settings');
            await t.tap(
              find.descendant(of: setting, matching: find.byType(Switch)),
            );
            await t.pumpAndSettle();
            Navigator.of(owner, rootNavigator: true).pop();
            await t.pumpAndSettle();
            await capture('general-scroll');
          }
          await p.switchMode(AppMode.student);
          await t.pumpAndSettle();
          await capture('student-fit');
          await p.updateFitWeekColumnsToWidth(false);
          await t.pumpAndSettle();
          await capture('student-scroll');
          final studentContext = t.element(
            find.byKey(const ValueKey('student-week-picker-button')),
          );
          unawaited(
            showSkedWeekPicker(
              context: studentContext,
              anchorContext: studentContext,
              config: data.studentMode.timetables.first.config,
              selectedWeek: 5,
            ),
          );
          await t.pumpAndSettle();
          await capture('week');
          Navigator.of(studentContext, rootNavigator: true).pop();
          await t.pumpAndSettle();
          await t.pumpWidget(const SizedBox.shrink());
          p.dispose();
        }
        await File(
          '${output.path}/manifest.json',
        ).writeAsString(const JsonEncoder.withIndent('  ').convert(manifest));
      } finally {
        debugDefaultTargetPlatformOverride = null;
        DesktopWindowBridge.instance.available = false;
      }
    },
  );
}
