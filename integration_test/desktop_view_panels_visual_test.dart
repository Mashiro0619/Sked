import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';

import '../test/support/desktop_panel_harness.dart';
import '../test/support/workspace_harness.dart';

Finder k(String value) => find.byKey(ValueKey(value));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('capture desktop viewing panels with isolated sample data', (
    t,
  ) async {
    final output = Directory(
      const String.fromEnvironment(
        'SKED_VISUAL_OUTPUT',
        defaultValue: '.scratch/desktop-view-panels',
      ),
    );
    await output.create(recursive: true);
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(1440, 900);
    addTearDown(t.view.reset);
    final p = await workspaceProvider(
      mode: AppMode.general,
      storage: desktopPanelStorage(locale: 'zh'),
      locale: 'zh',
    );
    final boundary = GlobalKey();
    await t.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: desktopPanelHarness(p, locale: 'zh'),
      ),
    );
    await t.pumpAndSettle();
    Future<void> capture(String name) async {
      await t.pumpAndSettle();
      expect(t.takeException(), isNull, reason: name);
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 1);
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      await File('${output.path}/$name.png')
          .writeAsBytes(bytes.buffer.asUint8List());
      image.dispose();
    }

    await capture('month-permanent-agenda');
    await t.tap(
      find.descendant(
        of: k('general-selected-day-agenda'),
        matching: find.text('复习计划'),
      ),
    );
    await capture('details-overlay');
    await p.updateWorkspacePanelDisplayMode(
      WorkspacePanelDisplayMode.sideBySide,
    );
    await capture('details-side-by-side');
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    await t.tap(k('general-reminders-action'));
    await capture('reminders-side-by-side');
    await p.updateWorkspacePanelDisplayMode(WorkspacePanelDisplayMode.overlay);
    await capture('reminders-overlay');
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    t.view.physicalSize = const Size(1100, 900);
    await t.pumpAndSettle();
    await t.tap(k('general-day-agenda-toggle'));
    await capture('agenda-overlay');
    await p.updateWorkspacePanelDisplayMode(
      WorkspacePanelDisplayMode.sideBySide,
    );
    await capture('agenda-side-by-side');
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    await p.updateWorkspacePanelDisplayMode(WorkspacePanelDisplayMode.overlay);
    await t.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: desktopPanelHarness(
          p,
          locale: 'zh',
          scale: 2,
          brightness: Brightness.dark,
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(k('general-desktop-toolbar-more'));
    await t.pumpAndSettle();
    await t.tap(k('general-reminders-action'));
    await t.pumpAndSettle();
    await t.tap(
      find.descendant(
        of: k('general-reminders-list'),
        matching: find.text('复习计划'),
      ),
    );
    await capture('details-dark-200-percent');
    await t.pumpWidget(const SizedBox());
    p.dispose();
  });
}
