import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/services/developer_ui_preferences.dart';
import 'package:sked/widgets/assistant_pane.dart';
import 'package:sked/widgets/workspace_frame.dart';

Finder _key(String value) => find.byKey(ValueKey(value));

Future<void> _mount(
  WidgetTester t,
  DeveloperUiPreferences preferences,
  AssistantPaneController assistant,
  WorkspacePaneController workspace,
) async {
  await t.pumpWidget(
    ChangeNotifierProvider<DeveloperUiPreferences>.value(
      value: preferences,
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
        home: Scaffold(
          body: WorkspaceFrame(
            controller: workspace,
            assistantController: assistant,
            resources: const Text('Resources'),
            canvas: const Align(
              alignment: Alignment.topLeft,
              child: AssistantPaneToggle(),
            ),
          ),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  for (final previousSessionOpen in [false, true]) {
    testWidgets(
      'enabled feature starts closed after restart: previous open=$previousSessionOpen',
      (t) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = const Size(1440, 900);
        addTearDown(t.view.reset);
        final writes = <bool>[];
        for (var session = 0; session < 2; session++) {
          final preferences = DeveloperUiPreferences(
            read: () async => true,
            write: (value) async {
              writes.add(value);
              return true;
            },
          );
          await preferences.load();
          final assistant = AssistantPaneController();
          final workspace = WorkspacePaneController();
          await _mount(t, preferences, assistant, workspace);
          expect(preferences.assistantVisible, isTrue);
          expect(_key('assistant-toggle'), findsOneWidget);
          expect(assistant.isOpen, isFalse);
          expect(find.byType(AssistantPreviewPane), findsNothing);
          if (session == 0) {
            await t.tap(_key('assistant-toggle'));
            await t.pumpAndSettle();
            expect(assistant.isOpen, isTrue);
            if (!previousSessionOpen) {
              await t.sendKeyEvent(LogicalKeyboardKey.escape);
              await t.pumpAndSettle();
            }
          }
          await t.pumpWidget(const SizedBox());
          await t.pumpAndSettle();
          assistant.dispose();
          workspace.dispose();
          preferences.dispose();
        }
        expect(writes, isEmpty);
        expect(t.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }

  for (final stored in [true, null]) {
    testWidgets('late preference load only reveals the entry: stored=$stored', (
      t,
    ) async {
      final loaded = Completer<bool?>();
      final preferences = DeveloperUiPreferences(
        read: () => loaded.future,
        previewDefault: true,
      );
      final assistant = AssistantPaneController();
      final workspace = WorkspacePaneController();
      addTearDown(preferences.dispose);
      addTearDown(assistant.dispose);
      addTearDown(workspace.dispose);
      await _mount(t, preferences, assistant, workspace);
      final loading = preferences.load();
      loaded.complete(stored);
      await loading;
      await t.pumpAndSettle();
      expect(_key('assistant-toggle'), findsOneWidget);
      expect(assistant.isOpen, isFalse);
      expect(find.byType(AssistantPreviewPane), findsNothing);
      await t.pumpWidget(const SizedBox());
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  }

  testWidgets('disable closes the panel; enabling or retrying never opens it', (
    t,
  ) async {
    var readFails = true;
    final preferences = DeveloperUiPreferences(
      read: () async {
        if (readFails) throw StateError('read');
        return true;
      },
      write: (_) async => true,
    );
    final assistant = AssistantPaneController();
    final workspace = WorkspacePaneController();
    addTearDown(preferences.dispose);
    addTearDown(assistant.dispose);
    addTearDown(workspace.dispose);
    await _mount(t, preferences, assistant, workspace);
    await preferences.load();
    await t.pumpAndSettle();
    readFails = false;
    expect(await preferences.retry(), isTrue);
    await t.pumpAndSettle();
    expect(assistant.isOpen, isFalse);
    expect(_key('assistant-toggle'), findsOneWidget);
    await t.tap(_key('assistant-toggle'));
    await t.pumpAndSettle();
    assistant.draft.text = 'Keep local draft';
    await preferences.load();
    await t.pumpAndSettle();
    expect(assistant.isOpen, isTrue);
    expect(await preferences.setAssistantVisible(false), isTrue);
    await t.pumpAndSettle();
    expect(assistant.isOpen, isFalse);
    expect(_key('assistant-toggle'), findsNothing);
    expect(await preferences.setAssistantVisible(true), isTrue);
    await t.pumpAndSettle();
    expect(assistant.isOpen, isFalse);
    expect(_key('assistant-toggle'), findsOneWidget);
    await t.tap(_key('assistant-toggle'));
    await t.pumpAndSettle();
    expect(assistant.isOpen, isTrue);
    expect(assistant.draft.text, 'Keep local draft');
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  for (final width in [800.0, 1440.0]) {
    for (final action in ['close', 'escape', 'back']) {
      testWidgets(
        'assistant $action preserves feature, entry and draft at $width',
        (t) async {
          t.view.devicePixelRatio = 1;
          t.view.physicalSize = Size(width, 900);
          addTearDown(t.view.resetDevicePixelRatio);
          addTearDown(t.view.resetPhysicalSize);
          final writes = <bool>[];
          final preferences = DeveloperUiPreferences(
            read: () async => true,
            write: (value) async {
              writes.add(value);
              return false;
            },
          );
          await preferences.load();
          addTearDown(preferences.dispose);
          final assistant = AssistantPaneController();
          final workspace = WorkspacePaneController();
          addTearDown(assistant.dispose);
          addTearDown(workspace.dispose);
          await _mount(t, preferences, assistant, workspace);
          expect(assistant.isOpen, isFalse);
          await t.tap(_key('assistant-toggle'));
          await t.pumpAndSettle();
          expect(assistant.isOpen, isTrue);
          await t.enterText(_key('assistant-draft'), 'Unsent conversation');
          switch (action) {
            case 'close':
              await t.tap(
                find.descendant(
                  of: find.byType(AssistantPreviewPane),
                  matching: find.byTooltip('Close'),
                ),
              );
            case 'escape':
              await t.sendKeyEvent(LogicalKeyboardKey.escape);
            case 'back':
              await t.binding.handlePopRoute();
          }
          await t.pumpAndSettle();
          expect(assistant.isOpen, isFalse);
          expect(preferences.assistantVisible, isTrue);
          expect(preferences.hasError, isFalse);
          expect(writes, isEmpty);
          expect(find.byType(AssistantPreviewPane), findsNothing);
          expect(_key('assistant-toggle'), findsOneWidget);
          t.view.physicalSize = Size(width == 800 ? 1440 : 800, 900);
          await t.pumpAndSettle();
          expect(assistant.isOpen, isFalse);
          await t.tap(_key('assistant-toggle'));
          await t.pumpAndSettle();
          expect(assistant.isOpen, isTrue);
          expect(assistant.draft.text, 'Unsent conversation');
          expect(writes, isEmpty);
          // Preference notifications after a failed feature change must not
          // reopen a panel that the user already dismissed.
          assistant.setOpen(false);
          await t.pumpAndSettle();
          expect(await preferences.setAssistantVisible(false), isFalse);
          await t.pumpAndSettle();
          expect(preferences.assistantVisible, isTrue);
          expect(assistant.isOpen, isFalse);
          expect(_key('assistant-toggle'), findsOneWidget);
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox.shrink());
        },
        variant: TargetPlatformVariant.only(TargetPlatform.windows),
      );
    }
  }

  testWidgets('assistant can close while the feature preference is saving', (
    t,
  ) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(1440, 900);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.view.resetPhysicalSize);
    final write = Completer<bool>();
    addTearDown(() {
      if (!write.isCompleted) write.complete(false);
    });
    var writeCount = 0;
    final preferences = DeveloperUiPreferences(
      read: () async => true,
      write: (_) {
        writeCount++;
        return write.future;
      },
    );
    await preferences.load();
    addTearDown(preferences.dispose);
    final assistant = AssistantPaneController();
    final workspace = WorkspacePaneController();
    addTearDown(assistant.dispose);
    addTearDown(workspace.dispose);
    await _mount(t, preferences, assistant, workspace);
    await t.tap(_key('assistant-toggle'));
    await t.pumpAndSettle();
    final saving = preferences.setAssistantVisible(false);
    await t.pump();
    expect(preferences.busy, isTrue);
    final close = find.descendant(
      of: find.byType(AssistantPreviewPane),
      matching: find.byTooltip('Close'),
    );
    await t.tap(close);
    await t.pumpAndSettle();
    expect(assistant.isOpen, isFalse);
    expect(preferences.assistantVisible, isTrue);
    expect(writeCount, 1);
    write.complete(false);
    expect(await saving, isFalse);
    await t.pumpAndSettle();
    expect(assistant.isOpen, isFalse);
    expect(_key('assistant-toggle'), findsOneWidget);
    await t.tap(_key('assistant-toggle'));
    await t.pumpAndSettle();
    expect(assistant.isOpen, isTrue);
    expect(writeCount, 1);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
