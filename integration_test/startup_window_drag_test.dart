import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/app_home_screen.dart';
import 'package:sked/services/desktop_window_bridge.dart';
import 'package:sked/widgets/workbench_chrome_metrics.dart';

import '../test/support/workspace_harness.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Native pointer events, not tester-generated gestures, must reach the app.
  binding.shouldPropagateDevicePointerEvents = true;
  testWidgets('fresh launch supports real Win32 caption dragging', (t) async {
    final bridge = DesktopWindowBridge.instance;
    await bridge.initialize();
    expect(bridge.available, isTrue);
    final output = Directory(
      const String.fromEnvironment(
        'SKED_VISUAL_OUTPUT',
        defaultValue: '.scratch/startup-window-drag',
      ),
    );
    await output.create(recursive: true);
    final evidence = <Map<String, dynamic>>[];
    const chrome = WorkbenchChromeMetrics(desktop: true, textScale: 1);
    Future<Map<String, dynamic>> window(
      String action, {
      Size size = const Size(1280, 800),
      Offset? point,
      String? name,
    }) async {
      final result = await t.runAsync(
        () => Process.run('powershell', [
          '-NoProfile',
          '-WindowStyle',
          'Hidden',
          '-ExecutionPolicy',
          'Bypass',
          '-File',
          File('tool/capture_workbench_window.ps1').absolute.path,
          '-ProcessId',
          '$pid',
          '-Action',
          action,
          '-WidthDp',
          '${size.width}',
          '-HeightDp',
          '${size.height}',
          '-CaptionHeightDp',
          '${chrome.toolbarHeight}',
          '-CaptionButtonWidthDp',
          '${chrome.captionButtonWidth}',
          if (point != null) ...[
            '-PointXDp',
            '${point.dx}',
            '-PointYDp',
            '${point.dy}',
          ],
          if (name != null) ...[
            '-OutputPath',
            '${output.absolute.path}/$name.png',
          ],
        ]),
      );
      expect(result!.exitCode, 0, reason: '${result.stderr}');
      return jsonDecode('${result.stdout}'.trim()) as Map<String, dynamic>;
    }

    // This is synthetic fresh-install state. No user settings or calendar files
    // are opened, reset or written in order to exercise the startup page.
    final provider = await workspaceProvider(
      locale: 'zh',
      storage: WorkspaceMemoryStorage(
        buildInitialAppData(buildDefaultPeriodTimes(), localeCode: 'zh'),
      ),
    );
    try {
      await window('resize');
      await t.pumpWidget(
        WorkspaceHarness(
          provider: provider,
          locale: const Locale('zh'),
          home: const AppHomeScreen(),
        ),
      );
      await t.pumpAndSettle();
      final onboarding = find.byKey(const ValueKey('first-launch-onboarding'));
      final toolbar = find.byKey(const ValueKey('startup-window-toolbar'));
      for (final (name, size) in [
        ('desktop', const Size(1280, 800)),
        ('narrow', const Size(640, 560)),
      ]) {
        await window('resize', size: size);
        await t.pumpAndSettle();
        expect(onboarding, findsOneWidget);
        final rect = t.getRect(toolbar);
        final l = AppLocalizations.of(t.element(toolbar));
        final caption = t.getRect(find.bySemanticsLabel(l.minimizeWindow));
        final point = Offset(caption.left / 2, rect.center.dy);
        final dragged = await window('drag', point: point);
        await t.pumpAndSettle();
        expect((dragged['movedX'] as num).abs(), greaterThan(10));
        expect((dragged['movedY'] as num).abs(), greaterThan(5));
        evidence.add({...dragged, 'case': '$name-caption-drag'});
        expect(onboarding, findsOneWidget);
        expect(provider.acceptedPrivacyPolicyVersion, isNull);
        final captured = await window('capture', name: '$name-onboarding');
        expect(captured['maximizeHit'], 9);
        evidence.add(captured);
        final bodyDrag = await window(
          'drag',
          point: Offset(12, rect.bottom + 80),
        );
        await t.pumpAndSettle();
        expect(bodyDrag['movedX'], 0);
        expect(bodyDrag['movedY'], 0);
        evidence.add({...bodyDrag, 'case': '$name-body-not-draggable'});
        expect(t.takeException(), isNull);
      }
      await File('${output.path}/evidence.json')
          .writeAsString(const JsonEncoder.withIndent('  ').convert(evidence));
    } finally {
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpAndSettle();
      provider.dispose();
      binding.shouldPropagateDevicePointerEvents = false;
    }
  });
}
