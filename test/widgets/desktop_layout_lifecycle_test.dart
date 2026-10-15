import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/main.dart' hide main;
import 'package:sked/screens/app_home_screen.dart';
import 'package:sked/services/desktop_layout_preferences.dart';
import 'package:sked/services/desktop_window_bridge.dart';

import '../support/workspace_harness.dart';

void main() {
  testWidgets('startup applies stored geometry before mounting the workspace', (
    t,
  ) async {
    final read = Completer<Object?>();
    final layout = DesktopLayoutPreferences(read: () => read.future);
    addTearDown(layout.dispose);
    final provider = await workspaceProvider();
    addTearDown(provider.dispose);
    await t.pumpWidget(
      MyApp(provider: provider, desktopLayoutPreferences: layout),
    );
    expect(find.byType(AppHomeScreen), findsNothing);
    read.complete('''{"version":1,"regions":{"resources":{"width":300}}}''');
    await t.pumpAndSettle();
    expect(find.byType(AppHomeScreen), findsOneWidget);
    expect(layout.preferenceFor(DesktopLayoutRegion.resources)?.width, 300);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
  });

  testWidgets('unsaved geometry never blocks normal window close', (t) async {
    var writes = 0;
    final layout = DesktopLayoutPreferences(
      read: () async => null,
      write: (_) async {
        writes++;
        return false;
      },
      saveDelay: const Duration(days: 1),
    );
    addTearDown(layout.dispose);
    final provider = await workspaceProvider();
    addTearDown(provider.dispose);
    await t.pumpWidget(
      MyApp(provider: provider, desktopLayoutPreferences: layout),
    );
    await t.pumpAndSettle();
    layout.setPreferredSize(
      DesktopLayoutRegion.resources,
      const PreferredRegionSize(width: 320),
    );
    expect(await DesktopWindowBridge.instance.prepareClose!(), isTrue);
    expect(writes, 1);
    expect(layout.hasError, isTrue);
    expect(layout.hasUnsavedChanges, isTrue);
    expect(layout.preferenceFor(DesktopLayoutRegion.resources)?.width, 320);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
  });

  testWidgets(
    'save failure shows one nonmodal retry and retains the latest size',
    (t) async {
      var writes = 0;
      var writable = false;
      final layout = DesktopLayoutPreferences(
        read: () async => null,
        write: (_) async {
          writes++;
          return writable;
        },
        saveDelay: const Duration(days: 1),
      );
      addTearDown(layout.dispose);
      final provider = await workspaceProvider();
      addTearDown(provider.dispose);
      await provider.lifecycle.acceptPrivacyPolicyCurrentVersion();
      await t.pumpWidget(
        MyApp(provider: provider, desktopLayoutPreferences: layout),
      );
      await t.pumpAndSettle();
      layout.setPreferredSize(
        DesktopLayoutRegion.resources,
        const PreferredRegionSize(width: 300),
      );
      expect(await layout.flush(), isFalse);
      await t.pumpAndSettle();
      final message = find.byKey(const ValueKey('desktop-layout-save-error'));
      expect(message, findsOneWidget);
      layout.setPreferredSize(
        DesktopLayoutRegion.resources,
        const PreferredRegionSize(width: 340),
      );
      expect(await layout.flush(), isFalse);
      await t.pumpAndSettle();
      expect(message, findsOneWidget);
      writable = true;
      await t.tap(find.byKey(const ValueKey('desktop-layout-save-retry')));
      await t.pumpAndSettle();
      expect(writes, 3);
      expect(layout.hasError, isFalse);
      expect(layout.hasUnsavedChanges, isFalse);
      expect(layout.preferenceFor(DesktopLayoutRegion.resources)?.width, 340);
      await t.pump(const Duration(seconds: 5));
      await t.pumpAndSettle();
      expect(message, findsNothing);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump();
    },
  );
}
