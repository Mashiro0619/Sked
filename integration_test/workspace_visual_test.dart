import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/settings_page.dart';
import 'package:sked/widgets/course_details_sheet.dart';
import 'package:sked/widgets/course_editor_sheet.dart';

import '../test/support/workspace_harness.dart';

/// Native Flutter rendering with isolated in-memory sample data. These captures
/// exercise logical window sizes; desktop captures do not certify Android
/// tablet behavior, OEM WebView, notification delivery, or hardware rotation.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('capture adaptive workspaces without touching user storage', (
    tester,
  ) async {
    const configuredOutput = String.fromEnvironment('SKED_VISUAL_OUTPUT');
    final output = Directory(
      configuredOutput.isEmpty
          ? '${Directory.systemTemp.path}/sked-workspace-visuals'
          : configuredOutput,
    );
    await output.create(recursive: true);
    final boundary = GlobalKey();
    final captures = <Map<String, Object?>>[];
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    Future<void> capture(String name, Size size, double scale) async {
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('${output.path}/$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
      captures.add({
        'file': '$name.png',
        'widthDp': size.width,
        'heightDp': size.height,
        'textScale': scale,
        'platform': defaultTargetPlatform.name,
      });
    }

    const scenarios = <(String, AppMode, Size, double, Brightness, bool)>[
      (
        'student-360-light',
        AppMode.student,
        Size(360, 800),
        1,
        Brightness.light,
        false,
      ),
      (
        'schedule-360-light',
        AppMode.general,
        Size(360, 800),
        1,
        Brightness.light,
        false,
      ),
      (
        'student-800-portrait',
        AppMode.student,
        Size(800, 1280),
        1,
        Brightness.light,
        false,
      ),
      (
        'schedule-800-portrait',
        AppMode.general,
        Size(800, 1280),
        1,
        Brightness.light,
        false,
      ),
      (
        'student-1280-landscape',
        AppMode.student,
        Size(1280, 800),
        1.3,
        Brightness.light,
        false,
      ),
      (
        'schedule-1280-landscape',
        AppMode.general,
        Size(1280, 800),
        1,
        Brightness.light,
        false,
      ),
      (
        'student-1440-desktop',
        AppMode.student,
        Size(1440, 900),
        1,
        Brightness.light,
        false,
      ),
      (
        'schedule-1440-month-dark',
        AppMode.general,
        Size(1440, 900),
        1,
        Brightness.dark,
        true,
      ),
      (
        'schedule-1920-desktop',
        AppMode.general,
        Size(1920, 1080),
        1,
        Brightness.light,
        false,
      ),
      (
        'schedule-1280-text-2',
        AppMode.general,
        Size(1280, 800),
        2,
        Brightness.dark,
        false,
      ),
    ];
    for (final (name, mode, size, scale, brightness, month) in scenarios) {
      final provider = await workspaceProvider(mode: mode, locale: 'zh');
      if (month) {
        await provider.updateGeneralDisplaySettings(
          defaultView: generalViewMonth,
        );
      }
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: WorkspaceHarness(
            provider: provider,
            locale: const Locale('zh'),
            textScale: scale,
            brightness: brightness,
          ),
        ),
      );
      await capture(name, size, scale);
      if (name == 'student-1440-desktop') {
        final course = find
            .byWidgetPredicate(
              (widget) =>
                  widget.key is ValueKey<String> &&
                  (widget.key! as ValueKey<String>).value.startsWith(
                    'timetable-course-hit-',
                  ),
            )
            .hitTestable();
        expect(course, findsWidgets);
        await tester.tap(course.first);
        await tester.pumpAndSettle();
        expect(find.byType(CourseDetailsSheet), findsOneWidget);
        await capture('student-1440-detail', size, scale);
        await tester.tap(
          find
              .descendant(
                of: find.byType(CourseDetailsSheet),
                matching: find.byIcon(Icons.edit),
              )
              .first,
        );
        await tester.pumpAndSettle();
        expect(find.byType(CourseEditorSheet), findsOneWidget);
        await capture('student-1440-editor', size, scale);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      provider.dispose();
    }
    for (final size in [const Size(360, 800), const Size(1440, 900)]) {
      final provider = await workspaceProvider(locale: 'zh');
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: WorkspaceHarness(
            provider: provider,
            locale: const Locale('zh'),
            home: const SettingsPage(),
          ),
        ),
      );
      await capture('settings-${size.width.toInt()}', size, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      provider.dispose();
    }
    final onlySchedule = await workspaceProvider(
      mode: AppMode.general,
      locale: 'zh',
    );
    await onlySchedule.setWorkspaceEnabled(AppMode.student, false);
    tester.view.physicalSize = const Size(360, 800);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: WorkspaceHarness(
          provider: onlySchedule,
          locale: const Locale('zh'),
        ),
      ),
    );
    await capture('schedule-only-360', const Size(360, 800), 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    onlySchedule.dispose();
    await File('${output.path}/manifest.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'capturedAt': DateTime.now().toUtc().toIso8601String(),
        'host': Platform.operatingSystem,
        'hostVersion': Platform.operatingSystemVersion,
        'data': 'isolated in-memory sample; no user storage or credentials',
        'scope': 'native Flutter render at configured logical viewports; not Android device acceptance',
        'captures': captures,
      }),
    );
  }, timeout: const Timeout(Duration(minutes: 8)));
}
