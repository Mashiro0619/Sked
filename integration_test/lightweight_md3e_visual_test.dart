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
import 'package:sked/screens/settings_page.dart';
import 'package:sked/screens/general_display_settings_page.dart';
import 'package:sked/screens/language_settings_page.dart';
import 'package:sked/widgets/period_time_set_picker_dialog.dart';
import 'package:sked/widgets/workbench_chrome_metrics.dart';
import 'package:sked/services/desktop_window_bridge.dart';
import 'package:sked/widgets/course_editor_sheet.dart';

import '../test/support/mobile_layout_data.dart';
import '../test/support/workspace_harness.dart';

Finder k(String value) => find.byKey(ValueKey(value));
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'lightweight expressive UI with real Windows fonts and phone geometry',
    (t) async {
      await DesktopWindowBridge.instance.initialize();
      const baseline = bool.fromEnvironment('SKED_VISUAL_BASELINE');
      final output = Directory(
        const String.fromEnvironment(
          'SKED_VISUAL_OUTPUT',
          defaultValue: '.scratch/md3e-after',
        ),
      );
      await output.create(recursive: true);
      final manifest = <Map<String, Object?>>[];
      final cases =
          <(String, Size, double, Brightness, TargetPlatform, String)>[
            for (final width in [320.0, 360.0, 393.0, 412.0])
              for (final scale in [1.0, 1.3, 2.0])
                for (final brightness in Brightness.values)
                  (
                    'phone-${width.toInt()}-$scale-${brightness.name}',
                    Size(width, 900),
                    scale,
                    brightness,
                    TargetPlatform.android,
                    'zh',
                  ),
            (
              'phone-320-en-2x',
              const Size(320, 900),
              2,
              Brightness.light,
              TargetPlatform.android,
              'en',
            ),
            (
              'phone-412-en',
              const Size(412, 900),
              1,
              Brightness.dark,
              TargetPlatform.android,
              'en',
            ),
            (
              'tablet-800',
              const Size(800, 1000),
              1,
              Brightness.light,
              TargetPlatform.android,
              'zh',
            ),
            (
              'tablet-1280',
              const Size(1280, 900),
              1.3,
              Brightness.dark,
              TargetPlatform.android,
              'en',
            ),
            (
              'windows-330',
              const Size(330, 900),
              1,
              Brightness.light,
              TargetPlatform.windows,
              'zh',
            ),
            (
              'windows-660',
              const Size(660, 900),
              1.3,
              Brightness.dark,
              TargetPlatform.windows,
              'en',
            ),
            (
              'windows-1440',
              const Size(1440, 900),
              1,
              Brightness.light,
              TargetPlatform.windows,
              'zh',
            ),
          ];
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetPadding);
      addTearDown(t.view.resetViewPadding);
      try {
        for (final (name, size, scale, brightness, platform, language)
            in cases) {
          debugDefaultTargetPlatformOverride = platform;
          DesktopWindowBridge.instance.available =
              platform == TargetPlatform.windows;
          t.view.physicalSize = size;
          final inset = platform == TargetPlatform.android
              ? const FakeViewPadding(top: 24, bottom: 24)
              : const FakeViewPadding();
          t.view.padding = inset;
          t.view.viewPadding = inset;
          final base = mobileLayoutData(locale: language);
          final data = base.copyWith(
            activeMode: AppMode.student,
            generalMode: base.generalMode.copyWith(
              selectedDateIso: '2026-09-03',
              defaultView: generalViewMonth,
            ),
          );
          final p = await workspaceProvider(
            storage: WorkspaceMemoryStorage(data),
            locale: language,
          );
          final boundary = GlobalKey();
          Future<void> pump({Widget? home}) async {
            await t.pumpWidget(const SizedBox.shrink());
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
            if (!baseline && scene.startsWith('month-')) {
              final cells = find.byWidgetPredicate(
                (w) =>
                    w.key is ValueKey<String> &&
                    (w.key! as ValueKey<String>).value.startsWith(
                      'general-month-day-cell-',
                    ),
              );
              for (final cell in cells.evaluate()) {
                final date = find
                    .descendant(
                      of: find.byWidget(cell.widget),
                      matching: find.byWidgetPredicate(
                        (w) => w is Text && int.tryParse(w.data ?? '') != null,
                      ),
                    )
                    .first;
                final label = t.widget<Text>(date).data!;
                final paragraph = t.renderObject<RenderParagraph>(date);
                final glyphs = paragraph.getBoxesForSelection(
                  TextSelection(baseOffset: 0, extentOffset: label.length),
                );
                expect(
                  glyphs,
                  isNotEmpty,
                  reason:
                      '$name: date $label must paint, not turn into an empty ellipsis.',
                );
                final width = glyphs.fold<double>(
                  0,
                  (sum, box) => sum + box.right - box.left,
                );
                expect(
                  width,
                  lessThanOrEqualTo(
                    t.getSize(find.byWidget(cell.widget)).width + 1,
                  ),
                  reason:
                      '$name: date $label must not overlap an adjacent day.',
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
              final file = '$name-$scene.png';
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
                'evidence': 'Actual Windows Flutter renderer and system fonts. Android geometry and safe insets are simulated; not Android device acceptance.',
              });
            } finally {
              image.dispose();
            }
          }

          Future<void> captureSidebar(String workspace) async {
            final toggle = k('workspace-resource-collapse').hitTestable();
            if (baseline || toggle.evaluate().isEmpty) return;
            const ids = [
              'workspace-resource-collapse',
              'workspace-resource-mode-student',
              'workspace-resource-mode-general',
              'workspace-resource-open',
              'workspace-resource-settings',
            ];
            final anchors = {
              for (final id in ids)
                id: t.getCenter(
                  find.descendant(
                    of: k(id).hitTestable(),
                    matching: find.byType(Icon),
                  ),
                ),
            };
            void checkAnchors() {
              for (final id in ids) {
                expect(
                  t.getCenter(
                    find.descendant(
                      of: k(id).hitTestable(),
                      matching: find.byType(Icon),
                    ),
                  ),
                  anchors[id],
                );
              }
            }

            await capture('$workspace-sidebar-expanded');
            await t.tap(toggle);
            await t.pump();
            await t.pump(const Duration(milliseconds: 60));
            checkAnchors();
            await capture('$workspace-sidebar-collapsing');
            await t.pumpAndSettle();
            checkAnchors();
            await capture('$workspace-sidebar-collapsed');
            await t.tap(k('workspace-resource-collapse').hitTestable());
            await t.pump();
            await t.pump(const Duration(milliseconds: 60));
            checkAnchors();
            await capture('$workspace-sidebar-expanding');
            await t.pumpAndSettle();
            checkAnchors();
          }

          await pump();
          await capture('student');
          await captureSidebar('student');
          final l = AppLocalizations.of(t.element(find.byType(Scaffold).first));
          final add = find.byTooltip(l.addCourse).hitTestable();
          final addButton = find
              .widgetWithText(FilledButton, l.addCourse)
              .hitTestable();
          if (add.evaluate().isNotEmpty) {
            await t.tap(add.first);
          } else if (addButton.evaluate().isNotEmpty) {
            await t.tap(addButton.first);
          } else {
            await t.tap(k('student-desktop-toolbar-more'));
            await t.pumpAndSettle();
            await t.tap(k('student-add-course'));
          }
          await t.pumpAndSettle();
          expect(find.byType(CourseEditorSheet), findsOneWidget);
          await capture('course');
          final more = find.text(l.more).last;
          await t.ensureVisible(more);
          await t.tap(more);
          await t.pumpAndSettle();
          await t.ensureVisible(k('course-reminder-behavior'));
          await t.pumpAndSettle();
          await capture('course-more');
          await pump(home: const SettingsPage());
          await capture('settings');
          if (!baseline) {
            await t.ensureVisible(k('settings-language'));
            await t.pumpAndSettle();
            await t.tap(k('settings-language'));
            await t.pumpAndSettle();
            expect(find.byType(LanguageSettingsPage), findsOneWidget);
            await capture('settings-language-page');
            await t.tap(find.byType(BackButton).hitTestable().first);
            await t.pumpAndSettle();
            await t.ensureVisible(k('settings-period-times'));
            await t.pumpAndSettle();
            await t.tap(k('settings-period-times'));
            await t.pumpAndSettle();
            expect(find.byType(PeriodTimeSetPickerDialogView), findsOneWidget);
            await capture('settings-period-dialog');
            t
                .widget<PeriodTimeSetPickerDialogView>(
                  find.byType(PeriodTimeSetPickerDialogView),
                )
                .onCancel();
            await t.pumpAndSettle();
            final section = k('settings-overview-general');
            await Scrollable.ensureVisible(t.element(section), alignment: 0);
            await t.pumpAndSettle();
            await capture('settings-general');
            await t.ensureVisible(k('settings-general-display'));
            await t.pumpAndSettle();
            await t.tap(k('settings-general-display'));
            await t.pumpAndSettle();
            expect(find.byType(GeneralDisplaySettingsPage), findsOneWidget);
            await t.ensureVisible(k('general-custom-column-width-mode'));
            await t.pumpAndSettle();
            await t.tap(k('general-custom-column-width-mode'));
            await t.pumpAndSettle();
            final manual = find
                .text(language == 'zh' ? '手动最小列宽' : 'Minimum width')
                .last;
            await t.ensureVisible(manual);
            await t.pumpAndSettle();
            await t.tap(manual);
            await t.pumpAndSettle();
            await t.ensureVisible(k('general-custom-column-width-slider'));
            await t.pumpAndSettle();
            await capture('settings-column-width');
            final slider = find.descendant(
              of: k('general-custom-column-width-slider'),
              matching: find.byType(Slider),
            );
            t.widget<Slider>(slider).onChanged!(160);
            t.widget<Slider>(slider).onChangeEnd!(160);
            await t.pumpAndSettle();
            await p.updateGeneralDisplaySettings(defaultView: generalViewWeek);
            await p.setGeneralDateRange(
              GeneralDateRange(DateTime(2026, 9, 3), DateTime(2026, 9, 12)),
            );
            await p.switchMode(AppMode.general);
            await pump();
            await capture('custom-width');
            await p.clearGeneralDateRange();
            await p.updateGeneralDisplaySettings(defaultView: generalViewMonth);
            await p.setSelectedGeneralDate(DateTime(2026, 9, 3));
          }
          await p.switchMode(AppMode.general);
          await pump();
          await capture('month-empty');
          await p.setSelectedGeneralDate(DateTime(2026, 9, 23));
          await t.pumpAndSettle();
          await capture('month-events');
          await captureSidebar('general');
          await t.pumpWidget(const SizedBox.shrink());
          p.dispose();
        }
      } finally {
        debugDefaultTargetPlatformOverride = null;
        DesktopWindowBridge.instance.available = true;
        await File(
          '${output.path}/manifest.json',
        ).writeAsString(const JsonEncoder.withIndent('  ').convert(manifest));
      }
    },
  );
  testWidgets(
    'settings retains state across real Win32 resizes and keeps caption hit regions clear',
    (t) async {
      await DesktopWindowBridge.instance.initialize();
      final output = Directory(
        const String.fromEnvironment(
          'SKED_VISUAL_OUTPUT',
          defaultValue: '.scratch/md3e-after',
        ),
      );
      await output.create(recursive: true);
      final evidence = <Map<String, dynamic>>[];
      final boundary = GlobalKey();
      final script = File('tool/capture_workbench_window.ps1').absolute.path;
      Future<Map<String, dynamic>> window(
        double width, {
        String action = 'resize',
      }) async {
        const chrome = WorkbenchChromeMetrics(desktop: true, textScale: 1);
        final result = await t.runAsync(
          () => Process.run('powershell', [
            '-NoProfile',
            '-WindowStyle',
            'Hidden',
            '-ExecutionPolicy',
            'Bypass',
            '-File',
            script,
            '-ProcessId',
            '$pid',
            '-Action',
            action,
            '-WidthDp',
            '$width',
            '-HeightDp',
            '900',
            '-CaptionHeightDp',
            '${chrome.toolbarHeight}',
            '-CaptionButtonWidthDp',
            '${chrome.captionButtonWidth}',
          ]),
        );
        expect(result!.exitCode, 0, reason: '${result.stderr}');
        return jsonDecode('${result.stdout}'.trim()) as Map<String, dynamic>;
      }

      Future<void> capture(Map<String, dynamic> geometry, String name) async {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: t.view.devicePixelRatio);
        try {
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!;
          final file = '${output.path}/$name.png';
          await File(file).writeAsBytes(bytes.buffer.asUint8List());
          geometry.addAll({
            'file': file,
            'evidence': 'Real Win32 resize and WM_NCHITTEST; only the app Flutter surface is captured, no desktop pixels.',
            'renderWidthDp': render.size.width,
            'renderHeightDp': render.size.height,
          });
          expect(
            render.size.width,
            closeTo((geometry['clientWidthDp'] as num).toDouble(), 1),
          );
          evidence.add(geometry);
          await File(
            '${output.path}/native-window-evidence.json',
          ).writeAsString(const JsonEncoder.withIndent('  ').convert(evidence));
          expect(geometry['maximizeHit'], 9);
        } finally {
          image.dispose();
        }
      }

      final p = await workspaceProvider(locale: 'zh');
      await t.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: WorkspaceHarness(
            provider: p,
            locale: const Locale('zh'),
            home: const SettingsPage(),
          ),
        ),
      );
      await t.pumpAndSettle();
      final state = t.state(find.byType(SettingsPage));
      for (final width in [360.0, 660.0, 1000.0, 1440.0]) {
        await window(width);
        await t.pumpAndSettle();
        final geometry = await window(width, action: 'inspect');
        expect(t.state(find.byType(SettingsPage)), same(state));
        expect(find.byType(BackButton).hitTestable(), findsOneWidget);
        expect(
          t.getTopLeft(k('settings-overview-appearance')).dy,
          greaterThanOrEqualTo(
            t.getBottomLeft(k('settings-overview-app-bar')).dy,
          ),
        );
        await capture(geometry, 'native-settings-${width.toInt()}');
        expect(t.takeException(), isNull);
      }
      await t.ensureVisible(k('settings-general-display'));
      await t.pumpAndSettle();
      await t.tap(k('settings-general-display'));
      await t.pumpAndSettle();
      final detail = t.state(find.byType(GeneralDisplaySettingsPage));
      for (final width in [360.0, 1000.0]) {
        await window(width);
        await t.pumpAndSettle();
        final geometry = await window(width, action: 'inspect');
        expect(t.state(find.byType(GeneralDisplaySettingsPage)), same(detail));
        expect(find.byType(BackButton).hitTestable(), findsOneWidget);
        await capture(geometry, 'native-display-${width.toInt()}');
        expect(t.takeException(), isNull);
      }
      await t.tap(find.byType(BackButton).hitTestable().first);
      await t.pumpAndSettle();
      expect(t.state(find.byType(SettingsPage)), same(state));
      await File('${output.path}/native-window-evidence.json')
          .writeAsString(const JsonEncoder.withIndent('  ').convert(evidence));
      await t.pumpWidget(const SizedBox.shrink());
      p.dispose();
    },
    skip: const bool.fromEnvironment('SKED_VISUAL_BASELINE'),
  );
}
