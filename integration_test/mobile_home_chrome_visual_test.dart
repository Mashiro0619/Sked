import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/desktop_window_bridge.dart';

import '../test/support/mobile_layout_data.dart';
import '../test/support/workspace_harness.dart';
import 'support/visual_capture_session.dart';

Finder key(String value) => find.byKey(ValueKey(value));
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('mobile home chrome and date state in both workspaces', (
    t,
  ) async {
    await DesktopWindowBridge.instance.initialize();
    final captures = VisualCaptureSession(
      defaultOutput: '.scratch/mobile-home-chrome-after',
    );
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
            ? const FakeViewPadding(top: 24, bottom: 24)
            : const FakeViewPadding();
        t.view.padding = padding;
        t.view.viewPadding = padding;
        final base = mobileLayoutData(locale: language);
        final data = base.copyWith(
          generalMode: base.generalMode.copyWith(
            selectedDateIso: today.toIso8601String().split('T').first,
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
          final bar = key('adaptive-shell-navigation-bar');
          await captures.capture(
            t,
            boundary: find.byKey(boundary),
            name: '$name-$scene',
            pixelRatio: size.width < 600 ? 2 : 1,
            metadata: {
              'textScale': scale,
              'brightness': brightness.name,
              'locale': language,
              'today': today.toIso8601String(),
              if (bar.evaluate().isNotEmpty)
                'navigationHeight': t.getSize(bar).height,
            },
          );
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
        await capture('general-today');
        final other = addCalendarDays(
          startOfWeekMonday(today),
          today.weekday == 2 ? 2 : 1,
        );
        await t.tap(
          key('general-week-day-header-${other.toIso8601String()}')
              .hitTestable()
              .first,
        );
        await t.pumpAndSettle();
        await capture('general-selected-other');
        final customStart = addCalendarDays(startOfWeekMonday(today), 3);
        final range = GeneralDateRange(
          customStart,
          addCalendarDays(customStart, 9),
        );
        await p.setGeneralDateRange(range, focusedDate: customStart);
        await t.pumpAndSettle();
        expect(p.customGeneralDateRange, range);
        await capture('general-custom');
        await p.clearGeneralDateRange();
        await t.pumpAndSettle();
        expect(p.customGeneralDateRange, isNull);
        await capture('general-week');
        await p.switchMode(AppMode.student);
        await t.pumpAndSettle();
        expect(p.activeMode, AppMode.student);
        await capture('student-home');
        await t.pumpWidget(const SizedBox.shrink());
        await t.pumpAndSettle();
        p.dispose();
      }
    } finally {
      debugDefaultTargetPlatformOverride = null;
      DesktopWindowBridge.instance.available = false;
    }
    await captures.writeManifest(expectedCount: cases.length * 5);
  });
}
