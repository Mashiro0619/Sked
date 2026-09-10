import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/services/desktop_window_bridge.dart';
import 'package:sked/widgets/general_event_details_sheet.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';

import '../test/support/workspace_harness.dart';
import '../test/support/workbench_dense_data.dart';

import 'package:sked/services/developer_ui_preferences.dart';
import 'package:sked/widgets/workbench_chrome_metrics.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Real Win32 mouse input must reach Flutter instead of the test inspector.
  binding.shouldPropagateDevicePointerEvents = true;
  testWidgets('real Windows chrome and independent task panels', (
    tester,
  ) async {
    await DesktopWindowBridge.instance.initialize();
    expect(DesktopWindowBridge.instance.available, isTrue);
    final output = Directory(
      const String.fromEnvironment(
        'SKED_VISUAL_OUTPUT',
        defaultValue: '.scratch/fusion-window',
      ),
    );
    await output.create(recursive: true);
    final script = File('tool/capture_workbench_window.ps1').absolute.path;
    final evidence = <Map<String, dynamic>>[];
    Future<Map<String, dynamic>> window(
      String action, {
      String? name,
      double width = 1440,
      double height = 860,
      Offset? point,
    }) async {
      const chrome = WorkbenchChromeMetrics(desktop: true, textScale: 1);
      final result = await tester.runAsync(
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
          '$height',
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
      final geometry =
          jsonDecode('${result.stdout}'.trim()) as Map<String, dynamic>;
      if (action == 'capture' || action == 'snap') {
        expect(
          geometry['maximizeHit'],
          9,
          reason: 'Native maximize region must report HTMAXBUTTON.',
        );
      }
      return geometry;
    }

    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      evidence.add(await window('capture', name: name));
    }

    final provider = await denseWorkbenchProvider(
      mode: AppMode.general,
      locale: 'zh',
    );
    await provider.updateHomeWorkspaceNavigationCollapsed(false);
    final preferences = DeveloperUiPreferences.memory();
    await window('resize');
    await tester.pumpWidget(
      WorkspaceHarness(
        provider: provider,
        locale: const Locale('zh'),
        developerUiPreferences: preferences,
      ),
    );
    DesktopWindowBridge.instance.prepareClose = provider.prepareForWindowClose;
    await provider.switchMode(AppMode.student);
    await capture('windows-student-no-modal');
    await tester.tap(find.byKey(const ValueKey('student-week-picker-button')));
    await tester.pumpAndSettle();
    final weekPickerContext = tester.element(
      find.byKey(const ValueKey('student-workspace-toolbar')),
    );
    final jumpLabel = AppLocalizations.of(weekPickerContext).jumpToWeek;
    expect(find.text(jumpLabel), findsOneWidget);
    expect(
      tester
          .widget<ColoredBox>(
            find.byKey(const ValueKey('desktop-window-modal-scrim')),
          )
          .color
          .a,
      greaterThan(0),
    );
    await capture('windows-student-week-modal');
    final modalMinimize = await window('minimize');
    expect(modalMinimize['minimized'], isTrue);
    evidence.add(modalMinimize);
    await window('restore');
    await tester.pumpAndSettle();
    expect(find.text(jumpLabel), findsOneWidget);
    Navigator.of(tester.element(find.text(jumpLabel))).pop();
    await capture('windows-student-modal-closed');
    expect(
      tester
          .widget<ColoredBox>(
            find.byKey(const ValueKey('desktop-window-modal-scrim')),
          )
          .color
          .a,
      0,
    );
    await provider.switchMode(AppMode.general);
    await capture('windows-week');
    final next = tester.getRect(
      find.byKey(const ValueKey('general-date-picker')),
    );
    final view = tester.getRect(
      find.byKey(const ValueKey('general-view-switcher')),
    );
    final drag = await window(
      'drag',
      point: Offset((next.right + view.left) / 2, next.center.dy),
    );
    expect(
      (drag['movedX'] as num).abs(),
      greaterThan(20),
      reason: 'Real native pointer drag must move the window.',
    );
    evidence.add(drag);
    await window('resize');
    evidence.add(await window('snap', name: 'windows-snap-menu'));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await preferences.setAssistantVisible(true);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('assistant-draft')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('assistant-draft')),
      '请帮我安排下周的学习计划',
    );
    await capture('windows-week-ai');
    await window('resize', width: 1920, height: 1000);
    await tester.pumpAndSettle();
    await capture('windows-week-ai-wide');
    await tester.tap(find.text('设计评审').first);
    await tester.pumpAndSettle();
    expect(find.byType(GeneralEventDetailsSheet), findsOneWidget);
    await capture('windows-week-ai-detail');
    await tester.tap(find.byKey(const ValueKey('general-event-edit-action')));
    await tester.pumpAndSettle();
    expect(find.byType(GeneralEventEditorSheet), findsOneWidget);
    final title = find.byType(TextFormField).first;
    await tester.enterText(title, '窗口缩放后保留的草稿');
    await capture('windows-week-ai-editor');
    await window('resize', width: 800, height: 1020);
    await capture('windows-narrow-editor');
    expect(tester.widget<TextFormField>(title).controller!.text, '窗口缩放后保留的草稿');
    await window('maximize');
    await capture('windows-maximized-editor');
    await window('restore');
    await window('close-request');
    await tester.pumpAndSettle();
    final l = AppLocalizations.of(
      tester.element(find.byType(GeneralEventEditorSheet)),
    );
    expect(find.text(l.unsavedChangesMessage), findsOneWidget);
    await capture('windows-close-draft-guard');
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(l.cancel),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(title).controller!.text, '窗口缩放后保留的草稿');
    final minimized = await window('minimize');
    expect(minimized['minimized'], isTrue);
    evidence.add(minimized);
    await window('restore');
    DesktopWindowBridge.instance.prepareClose = null;
    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
    preferences.dispose();
    await File('${output.path}/manifest.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'capturedAt': DateTime.now().toUtc().toIso8601String(),
        'kind': 'real native Windows window capture; isolated in-memory data',
        'notVerified': [
          'Android hardware',
          'Windows hover snap-menu interaction',
          'multiple monitors',
        ],
        'captures': evidence,
      }),
    );
  });
}
