import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/settings_page.dart';
import 'package:sked/services/desktop_window_bridge.dart';
import 'package:sked/widgets/workspace_editor_form.dart';

import '../../test/support/mobile_layout_data.dart';
import '../../test/support/workspace_harness.dart';
import '../support/visual_capture_session.dart';

Finder _key(String value) => find.byKey(ValueKey(value));

void registerCaptureScenarios() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('review phone spacing, settings headers and calendar feedback', (
    tester,
  ) async {
    await DesktopWindowBridge.instance.initialize();
    final wasAvailable = DesktopWindowBridge.instance.available;
    final captures = VisualCaptureSession(label: 'mobile-ui-fixes');
    const cases = [
      ('phone-360-zh', Size(360, 850), 1.0, 'zh', Brightness.light),
      ('phone-320-en-2x', Size(320, 900), 2.0, 'en', Brightness.light),
      ('phone-412-zh-dark', Size(412, 915), 1.3, 'zh', Brightness.dark),
    ];
    tester.view.devicePixelRatio = 1;
    const safe = FakeViewPadding(top: 24, bottom: 24);
    addTearDown(tester.view.reset);
    try {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      DesktopWindowBridge.instance.available = false;
      for (final (name, size, scale, language, brightness) in cases) {
        tester.view.physicalSize = size;
        tester.view.padding = safe;
        tester.view.viewPadding = safe;
        final base = mobileLayoutData(locale: language);
        final first = base.studentMode.timetables.first;
        final data = base.copyWith(
          activeMode: AppMode.student,
          studentMode: base.studentMode.copyWith(
            activeTimetableId: first.id,
            timetables: [
              first,
              first.copyWith(
                id: 'phone-review-second',
                courses: const [],
                config: first.config.copyWith(
                  name: language == 'zh'
                      ? '第二学期专业课程与实验安排'
                      : 'Second semester lectures and practical classes',
                ),
              ),
            ],
          ),
        );
        final provider = await workspaceProvider(
          locale: language,
          storage: WorkspaceMemoryStorage(data),
        );
        final boundary = GlobalKey();
        var mount = 0;
        Future<void> pump({Widget? home}) async {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: WorkspaceHarness(
                key: ValueKey('$name-${mount++}'),
                provider: provider,
                locale: Locale(language),
                textScale: scale,
                brightness: brightness,
                home: home,
              ),
            ),
          );
          await tester.pumpAndSettle();
        }

        Future<void> tap(Finder finder) async {
          await tester.ensureVisible(finder);
          await tester.pumpAndSettle();
          await tester.tap(finder);
          await tester.pumpAndSettle();
        }

        Future<void> capture(String scene) => captures.capture(
          tester,
          boundary: find.byKey(boundary),
          name: '$name-$scene',
          pixelRatio: 2,
          metadata: {
            'locale': language,
            'textScale': scale,
            'brightness': brightness.name,
            'evidence':
                'Windows Flutter rendering and platform fonts; Android geometry, '
                'touch and keyboard insets simulated, not Android hardware.',
          },
        );

        try {
          await pump();
          final l = AppLocalizations.of(
            tester.element(_key('student-timetable-picker-button')),
          );
          await tap(_key('student-timetable-picker-button'));
          await capture('two-timetables');
          await tap(_key('timetable-picker-create'));
          await tap(
            find.widgetWithText(SkedEditorValueField, l.semesterStartDate),
          );
          await capture('single-date');
          await tap(_key('sked-date-input-toggle'));
          tester.view.viewInsets = const FakeViewPadding(bottom: 300);
          tester.view.padding = const FakeViewPadding(top: 24);
          await tester.pumpAndSettle();
          await capture('single-date-ime');
          tester.view.viewInsets = const FakeViewPadding();
          tester.view.padding = safe;
          await tester.pumpAndSettle();
          await tap(_key('sked-date-cancel'));

          await pump(home: const SettingsPage());
          await capture('settings-overview');
          await pump(
            home: const SettingsPage(
              initialDestination: SettingsDestination.studentPreferences,
            ),
          );
          await capture('settings-detail-expanded');
          final settingsScroll = _key('timetable-display-settings-list');
          await tester.drag(settingsScroll, const Offset(0, -480));
          await tester.pumpAndSettle();
          expect(find.byType(BackButton).hitTestable(), findsOneWidget);
          await capture('settings-detail-collapsed');
          await pump(
            home: const SettingsPage(
              initialDestination: SettingsDestination.language,
            ),
          );
          await capture('language-header');
          await tester.drag(
            find.byKey(const PageStorageKey('language-settings-scroll')),
            const Offset(0, -440),
          );
          await tester.pumpAndSettle();
          expect(find.byType(BackButton).hitTestable(), findsOneWidget);
          expect(_key('language-search').hitTestable(), findsOneWidget);
          await capture('language-collapsed');

          await pump();
          await tap(find.byTooltip(l.addCourse).hitTestable().first);
          await tap(
            find.descendant(
              of: _key('course-details-section'),
              matching: find.text(l.more),
            ),
          );
          await tester.ensureVisible(_key('course-reminder-behavior'));
          await tester.pumpAndSettle();
          expect(find.text(l.courseReminderDeliveryHint), findsNothing);
          await capture('course-reminder-controls');

          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          await provider.workspaces.switchMode(AppMode.general);
          await provider.generalCommands.updateDisplaySettings(
            defaultView: generalViewMonth,
            showLunarCalendar: true,
          );
          await provider.generalNavigation.setSelectedDate(
            DateTime(2026, 10, 16),
          );
          await pump();
          final day = _key('general-month-day-cell-2026-10-16');
          await tester.ensureVisible(day);
          await tester.pumpAndSettle();
          await capture('month-idle');
          final press = await tester.startGesture(
            tester.getTopLeft(day) + const Offset(2, 2),
            kind: PointerDeviceKind.touch,
          );
          await tester.pump(const Duration(milliseconds: 120));
          await capture('month-pressed');
          await press.up();
          await tester.pumpAndSettle();
          await capture('month-released');
        } finally {
          tester.view.viewInsets = const FakeViewPadding();
          tester.view.padding = safe;
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          provider.dispose();
        }
      }
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      DesktopWindowBridge.instance.available = true;
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.padding = const FakeViewPadding();
      tester.view.viewPadding = const FakeViewPadding();
      final desktopProvider = await workspaceProvider(locale: 'zh');
      final desktopBoundary = GlobalKey();
      try {
        await tester.pumpWidget(
          RepaintBoundary(
            key: desktopBoundary,
            child: WorkspaceHarness(
              provider: desktopProvider,
              locale: const Locale('zh'),
              home: const SettingsPage(
                initialDestination: SettingsDestination.appearance,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final toolbar = tester.getRect(_key('settings-page-app-bar'));
        expect(toolbar.left, 0);
        expect(toolbar.right, 1440);
        expect(
          tester.getTopLeft(_key('theme-workspace-preview')).dy,
          greaterThanOrEqualTo(toolbar.bottom),
        );
        await captures.capture(
          tester,
          boundary: find.byKey(desktopBoundary),
          name: 'windows-1440-appearance',
          metadata: const {
            'locale': 'zh',
            'textScale': 1,
            'evidence':
                'Windows Flutter client rendering with isolated fixtures.',
          },
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        desktopProvider.dispose();
      }
      await captures.writeManifest(expectedCount: cases.length * 12 + 1);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      DesktopWindowBridge.instance.available = wasAvailable;
    }
  });
}
