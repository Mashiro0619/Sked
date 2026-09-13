import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/theme_settings_page.dart';
import 'package:sked/services/desktop_window_bridge.dart';
import 'package:sked/widgets/course_details_sheet.dart';
import 'package:sked/widgets/sked_date_picker.dart';
import 'package:sked/widgets/course_editor_sheet.dart';
import 'package:sked/widgets/general_event_details_sheet.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';

import '../test/support/mobile_layout_data.dart';
import '../test/support/workspace_harness.dart';

Finder key(String key) => find.byKey(ValueKey(key));
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('mobile tasks from actual home entries and themed setting menus', (
    t,
  ) async {
    await DesktopWindowBridge.instance.initialize();
    final out = Directory(
      const String.fromEnvironment(
        'SKED_VISUAL_OUTPUT',
        defaultValue: '.scratch/mobile-tasks-after',
      ),
    );
    await out.create(recursive: true);
    const baseline = bool.fromEnvironment('SKED_VISUAL_BASELINE');
    final manifest = <Map<String, Object?>>[];
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
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
        'windows-1440-en',
        const Size(1440, 1000),
        1,
        Brightness.dark,
        TargetPlatform.windows,
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
      if (!baseline) ...[
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
      ],
    ];
    try {
      for (final (name, size, scale, brightness, platform, language) in cases) {
        debugDefaultTargetPlatformOverride = platform;
        DesktopWindowBridge.instance.available =
            platform == TargetPlatform.windows;
        t.view.physicalSize = size;
        final insets = platform == TargetPlatform.android
            ? const FakeViewPadding(top: 24, bottom: 24)
            : const FakeViewPadding();
        t.view.padding = insets;
        t.view.viewPadding = insets;
        final p = await workspaceProvider(
          locale: language,
          storage: WorkspaceMemoryStorage(mobileLayoutData(locale: language)),
        );
        final boundary = GlobalKey();
        Future<void> pump({Widget? home}) async {
          await t.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: WorkspaceHarness(
                provider: p,
                locale: Locale(language),
                textScale: scale,
                brightness: brightness,
                home: home,
              ),
            ),
          );
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
              'evidence': 'Windows Flutter rendering. Android phone/tablet geometry and IME simulated, not device acceptance.',
            });
          } finally {
            image.dispose();
          }
        }

        Future<void> tap(Finder f) async {
          await t.ensureVisible(f);
          await t.pumpAndSettle();
          await t.tap(f);
          await t.pumpAndSettle();
        }

        Future<void> dismiss(Finder f) async {
          await Navigator.of(t.element(f)).maybePop();
          await t.pumpAndSettle();
        }

        await pump();
        for (final mode in [AppMode.general, AppMode.student]) {
          await p.switchMode(mode);
          await t.pumpAndSettle();
          final details = find.byType(
            mode == AppMode.student
                ? CourseDetailsSheet
                : GeneralEventDetailsSheet,
          );
          final editor = find.byType(
            mode == AppMode.student
                ? CourseEditorSheet
                : GeneralEventEditorSheet,
          );
          await tap(
            mode == AppMode.student
                ? key(
                    'timetable-course-hit-${p.activeTimetable.courses.first.id}',
                  )
                : key(
                    'general-timed-occurrence-mobile-day-21-2026-09-21T08:10:00.000',
                  ),
          );
          await capture('${mode.value}-details');
          final l = AppLocalizations.of(t.element(details));
          await tap(
            find.descendant(
              of: details,
              matching: find.byTooltip(
                mode == AppMode.student ? l.editCourseTooltip : l.editEvent,
              ),
            ),
          );
          await capture('${mode.value}-edit');
          if (platform == TargetPlatform.android &&
              size.width < 600 &&
              !baseline) {
            t.view.viewInsets = const FakeViewPadding(bottom: 300);
            t.view.padding = const FakeViewPadding(top: 24);
            await t.pumpAndSettle();
            await capture('${mode.value}-edit-ime');
            t.view.viewInsets = const FakeViewPadding();
            t.view.padding = insets;
            await t.pumpAndSettle();
          }
          await dismiss(editor);
          if (details.evaluate().isNotEmpty) await dismiss(details);
          if (!baseline && mode == AppMode.general && size.width < 600) {
            final original = GeneralDateRange(
              DateTime(2026, 9, 21),
              DateTime(2026, 9, 27),
            );
            await p.setGeneralDateRange(original);
            await t.pumpAndSettle();
            await tap(key('general-date-title-button'));
            expect(find.byType(SkedDatePicker), findsOneWidget);
            final gesture = await t.startGesture(
              t.getCenter(key('sked-date-2026-09-22')),
              kind: PointerDeviceKind.touch,
            );
            await gesture.moveBy(const Offset(25, 0));
            await gesture.moveTo(t.getCenter(key('sked-date-2026-09-26')));
            await t.pumpAndSettle();
            expect(p.customGeneralDateRange, original);
            await capture('general-range-touch-preview');
            await gesture.up();
            await t.pumpAndSettle();
            expect(p.customGeneralDateRange!.dayCount, 5);
            await capture('general-range-touch-applied');
            await p.clearGeneralDateRange();
            await p.setSelectedGeneralDate(DateTime(2026, 9, 23));
            await t.pumpAndSettle();
          }

          final add = find.byType(FloatingActionButton);
          if (add.evaluate().isNotEmpty) {
            await tap(add.first);
            await capture('${mode.value}-new');
            await dismiss(editor);
          }
        }
        await pump(home: ThemeSettingsPage(initialWorkspace: AppMode.general));
        for (final menu in ['workspace', 'brightness', 'color']) {
          final field = key('theme-$menu-mode-choice-list');
          await tap(field);
          await capture('theme-$menu-menu');
          await t.tapAt(const Offset(5, 28));
          await t.pumpAndSettle();
        }
        await t.pumpWidget(const SizedBox.shrink());
        p.dispose();
      }
      await File('${out.path}/manifest.json')
          .writeAsString(const JsonEncoder.withIndent('  ').convert(manifest));
    } finally {
      debugDefaultTargetPlatformOverride = null;
      DesktopWindowBridge.instance.available = false;
    }
  });
}
