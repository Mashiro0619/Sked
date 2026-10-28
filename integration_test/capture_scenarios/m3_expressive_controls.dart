import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/desktop_window_bridge.dart';
import 'package:sked/theme/app_theme.dart';
import 'package:sked/widgets/sked_compact_color_picker.dart';
import 'package:sked/widgets/sked_date_picker.dart';
import 'package:sked/widgets/sked_expressive_loading_indicator.dart';
import 'package:sked/widgets/sked_week_picker.dart';

import '../support/visual_capture_session.dart';

Finder _key(String value) => find.byKey(ValueKey(value));

void registerCaptureScenarios() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'M3 marker feedback, keyboard color controls and static loading',
    (tester) async {
      await DesktopWindowBridge.instance.initialize();
      final bridge = DesktopWindowBridge.instance;
      final wasAvailable = bridge.available;
      final originalStrategy = FocusManager.instance.highlightStrategy;
      final boundary = GlobalKey();
      final captures = VisualCaptureSession(label: 'm3-expressive-controls');
      const cases = [
        ('phone-360-zh', Size(360, 850), 1.0, 'zh', Brightness.light),
        ('phone-320-en-2x', Size(320, 900), 2.0, 'en', Brightness.light),
        ('phone-412-zh-dark', Size(412, 915), 1.3, 'zh', Brightness.dark),
      ];
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      try {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        bridge.available = false;
        for (final (name, size, scale, locale, brightness) in cases) {
          tester.view.physicalSize = size;
          FocusManager.instance.highlightStrategy =
              FocusHighlightStrategy.alwaysTouch;
          Future<void> pump(Widget content, {Color? seed}) async {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
            await tester.pumpWidget(
              RepaintBoundary(
                key: boundary,
                child: MaterialApp(
                  locale: Locale(locale),
                  localizationsDelegates: appLocalizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  theme: buildAppTheme(
                    seedColor: seed ?? const Color(0xff6750a4),
                    brightness: brightness,
                    themeColorMode: 'solid',
                    colorfulUiColorValues: const {},
                  ),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(scale),
                      disableAnimations: true,
                    ),
                    child: child!,
                  ),
                  home: Scaffold(
                    body: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: content,
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
          }

          Future<void> capture(String scene) => captures.capture(
            tester,
            boundary: find.byKey(boundary),
            name: '$name-$scene',
            pixelRatio: 2,
            metadata: {
              'locale': locale,
              'textScale': scale,
              'brightness': brightness.name,
              'disableAnimations': true,
              'evidence':
                  'Windows Flutter renderer, actual shared components in isolated '
                  'fixtures; Android size, input and platform style simulated.',
            },
          );

          await pump(
            SkedDatePicker(
              initialDate: DateTime(2026, 10, 21),
              firstDate: DateTime(2020),
              lastDate: DateTime(2040),
              currentDate: DateTime(2026, 10, 21),
              onSelected: (_) {},
              onCancel: () {},
            ),
          );
          await capture('date-idle');
          for (final date in [21, 22]) {
            final day = _key('sked-date-2026-10-$date');
            final press = await tester.startGesture(
              tester.getRect(day).bottomLeft + const Offset(1, -1),
              kind: PointerDeviceKind.touch,
            );
            await tester.pump(const Duration(milliseconds: 150));
            await capture('date-$date-pressed');
            await press.cancel();
            await tester.pumpAndSettle();
          }
          await capture('date-cancelled');
          FocusManager.instance.highlightStrategy =
              FocusHighlightStrategy.alwaysTraditional;
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
          await tester.pumpAndSettle();
          await capture('date-keyboard');
          FocusManager.instance.highlightStrategy =
              FocusHighlightStrategy.alwaysTouch;

          await pump(
            SkedWeekPicker(
              config: TimetableConfig(
                name: 'Semester',
                startDate: DateTime(2026, 10, 19),
                totalWeeks: 18,
                periodTimeSetId: defaultPeriodTimeSetId,
              ),
              selectedWeek: 1,
              currentDate: DateTime(2026, 10, 21),
              onSelected: (_) {},
              onCancel: () {},
            ),
          );
          await capture('week-idle');
          for (final week in [1, 2]) {
            final cell = _key('student-week-option-$week');
            final press = await tester.startGesture(
              tester.getRect(cell).bottomLeft + const Offset(1, -1),
              kind: PointerDeviceKind.touch,
            );
            await tester.pump(const Duration(milliseconds: 150));
            await capture('week-$week-pressed');
            await press.cancel();
            await tester.pumpAndSettle();
          }
          await capture('week-cancelled');
          FocusManager.instance.highlightStrategy =
              FocusHighlightStrategy.alwaysTraditional;
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
          await tester.pumpAndSettle();
          await capture('week-keyboard');

          var color = 0xff804040;
          await pump(
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: StatefulBuilder(
                builder: (context, update) => SkedCompactColorPicker(
                  colorValue: color,
                  onColorChanged: (next) => update(() => color = next),
                  invalidHexMessage: AppLocalizations.of(context)
                      .colorHexInvalid,
                ),
              ),
            ),
          );
          await capture('color-hex-label');
          tester
              .widget<Focus>(_key('compact-color-picker-spectrum-focus'))
              .focusNode!
              .requestFocus();
          await tester.pumpAndSettle();
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
          await tester.pumpAndSettle();
          await capture('color-spectrum-keyboard');
          tester
              .widget<Focus>(_key('compact-color-picker-hue-focus'))
              .focusNode!
              .requestFocus();
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
          await tester.pumpAndSettle();
          await capture('color-hue-keyboard');

          await pump(
            SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: StatefulBuilder(
                builder: (context, update) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioGroup<int>(
                      groupValue: 1,
                      onChanged: (_) {},
                      child: const Radio<int>(value: 1),
                    ),
                    Slider(value: .6, onChanged: (_) {}),
                    const LinearProgressIndicator(value: .6),
                    const SizedBox(height: 24),
                    const CircularProgressIndicator(value: .6),
                    const SizedBox(height: 24),
                    const SkedExpressiveLoadingIndicator(),
                  ],
                ),
              ),
            ),
            seed: brightness == Brightness.light
                ? const Color(0xfffcfcfc)
                : const Color(0xff101010),
          );
          await capture('readable-controls-static-loading');
          await tester.pump(const Duration(seconds: 2));
          await capture('static-loading-after-two-seconds');
        }
        await captures.writeManifest(expectedCount: cases.length * 15);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        FocusManager.instance.highlightStrategy = originalStrategy;
        debugDefaultTargetPlatformOverride = null;
        bridge.available = wasAvailable;
      }
    },
  );
}
