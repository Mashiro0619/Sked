import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/desktop_window_bridge.dart';
import 'package:sked/widgets/sked_week_picker.dart';

import '../test/support/workspace_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'compact semester week tasks on Windows and simulated touch layouts',
    (tester) async {
      await DesktopWindowBridge.instance.initialize();
      final output = Directory(
        const String.fromEnvironment(
          'SKED_VISUAL_OUTPUT',
          defaultValue: '.scratch/week-picker-visual',
        ),
      );
      await output.create(recursive: true);
      final manifest = <Map<String, Object?>>[];
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      addTearDown(() => DesktopWindowBridge.instance.available = false);
      final cases =
          <(String, Size, double, Brightness, TargetPlatform, String)>[
            (
              'windows-1366-zh',
              const Size(1366, 768),
              1,
              Brightness.light,
              TargetPlatform.windows,
              'zh',
            ),
            (
              'windows-1440-en',
              const Size(1440, 900),
              1,
              Brightness.dark,
              TargetPlatform.windows,
              'en',
            ),
            (
              'windows-800-zh',
              const Size(800, 800),
              1,
              Brightness.light,
              TargetPlatform.windows,
              'zh',
            ),
            (
              'windows-640-short',
              const Size(640, 360),
              1,
              Brightness.dark,
              TargetPlatform.windows,
              'en',
            ),
            (
              'windows-large-de',
              const Size(1440, 900),
              2,
              Brightness.dark,
              TargetPlatform.windows,
              'de',
            ),
            (
              'phone-en-simulated',
              const Size(360, 800),
              1,
              Brightness.light,
              TargetPlatform.android,
              'en',
            ),
            (
              'phone-large-zh-simulated',
              const Size(360, 800),
              2,
              Brightness.dark,
              TargetPlatform.android,
              'zh',
            ),
            (
              'tablet-portrait-zh-simulated',
              const Size(800, 1280),
              1,
              Brightness.light,
              TargetPlatform.android,
              'zh',
            ),
            (
              'tablet-landscape-en-simulated',
              const Size(1280, 800),
              1.3,
              Brightness.dark,
              TargetPlatform.android,
              'en',
            ),
          ];
      try {
        for (final (name, size, scale, brightness, platform, language)
            in cases) {
          debugDefaultTargetPlatformOverride = platform;
          DesktopWindowBridge.instance.available =
              platform == TargetPlatform.windows;
          tester.view.physicalSize = size;
          for (final count in [1, 18, 100]) {
            final initial = buildInitialAppData(
              buildDefaultPeriodTimes(),
              localeCode: language,
            );
            final data = initial.copyWith(
              activeMode: AppMode.student,
              studentMode: initial.studentMode.copyWith(
                activeTimetableId: 'weeks',
                timetables: [
                  TimetableData(
                    id: 'weeks',
                    config: TimetableConfig(
                      name: language == 'zh' ? '新课表' : 'Timetable',
                      startDate: DateTime(2026, 9, 7),
                      totalWeeks: count,
                      periodTimeSetId: defaultPeriodTimeSetId,
                    ),
                    courses: const [],
                  ),
                ],
              ),
            );
            final provider = await workspaceProvider(
              locale: language,
              storage: WorkspaceMemoryStorage(data),
            );
            final selected = count == 100
                ? 95
                : count == 18
                ? 5
                : 1;
            await provider.setSelectedWeek(selected);
            final boundary = GlobalKey();
            await tester.pumpWidget(
              RepaintBoundary(
                key: boundary,
                child: WorkspaceHarness(
                  provider: provider,
                  locale: Locale(language),
                  brightness: brightness,
                  textScale: scale,
                ),
              ),
            );
            await tester.pumpAndSettle();
            Future<void> capture(String state) async {
              expect(
                tester.takeException(),
                isNull,
                reason: '$name $count $state',
              );
              final render =
                  boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final image = await render.toImage(pixelRatio: 1);
              try {
                final bytes = (await image.toByteData(
                  format: ui.ImageByteFormat.png,
                ))!;
                final file = '$name-$count-weeks-$state.png';
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
                  'weeks': count,
                  'evidence': 'Actual Windows Flutter rendering; phone/tablet layouts are simulated, not hardware',
                });
              } finally {
                image.dispose();
              }
            }

            final trigger = find.byKey(
              const ValueKey('student-week-picker-button'),
            );
            await tester.ensureVisible(trigger);
            await tester.tap(trigger);
            await tester.pumpAndSettle();
            expect(find.byType(SkedWeekPicker), findsOneWidget);
            expect(find.byType(AlertDialog), findsNothing);
            final grid = tester.getRect(
              find.byKey(const ValueKey('sked-week-picker-grid')),
            );
            final option = tester.getRect(
              find.byKey(ValueKey('student-week-option-$selected')),
            );
            expect(grid.contains(option.center), isTrue);
            await capture('open');
            if (count == 100) {
              await tester.sendKeyEvent(LogicalKeyboardKey.end);
              await tester.pumpAndSettle();
              await capture('last-focused');
            }
            await tester.sendKeyEvent(LogicalKeyboardKey.enter);
            await tester.pumpAndSettle();
            expect(provider.selectedWeek, count == 100 ? 100 : selected);
            expect(find.byType(SkedWeekPicker), findsNothing);
            if (count == 18) await capture('closed');
            if (count == 18 &&
                platform == TargetPlatform.android &&
                size.width < 600) {
              await provider.updateStudentToolbarNavigationHiddenIds(const [
                'week',
              ]);
              await provider.updateStudentToolbarHiddenItemsBehavior(
                toolbarHiddenItemsBehaviorMore,
              );
              await tester.pumpAndSettle();
              await tester.tap(
                find.byKey(const ValueKey('student-toolbar-more-button')),
              );
              await tester.pumpAndSettle();
              await tester.tap(
                find.byWidgetPredicate(
                  (w) => w is PopupMenuItem<String> && w.value == 'week',
                ),
              );
              await tester.pumpAndSettle();
              expect(find.byType(SkedWeekPicker), findsOneWidget);
              await capture('more-entry');
              await tester.tap(
                find.byKey(const ValueKey('sked-week-picker-close')),
              );
              await tester.pumpAndSettle();
            }
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
            provider.dispose();
          }
        }
        await File(
          '${output.path}/manifest.json',
        ).writeAsString(const JsonEncoder.withIndent('  ').convert(manifest));
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        debugDefaultTargetPlatformOverride = null;
        DesktopWindowBridge.instance.available = false;
      }
    },
  );
}
