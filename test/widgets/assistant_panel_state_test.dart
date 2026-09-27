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
