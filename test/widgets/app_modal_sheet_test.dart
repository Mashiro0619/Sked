import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sked/controllers/app_session.dart';
import 'package:sked/controllers/settings_commands.dart';
import 'package:sked/controllers/settings_view_state.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/providers/app_scope.dart';
import 'package:sked/widgets/app_modal_sheet.dart';
import 'package:sked/widgets/expressive_dialog.dart';
import 'package:sked/widgets/ui_command.dart';
import 'package:sked/widgets/workspace_editor.dart';
import 'package:sked/widgets/workspace_frame.dart';

import '../support/workspace_harness.dart';

Widget _localizedApp(Widget home) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}

void main() {
  for (final (platform, size) in [
    (TargetPlatform.windows, const Size(1280, 850)),
    (TargetPlatform.android, const Size(390, 844)),
  ]) {
    testWidgets(
      'a modal task retains the nearest domain across its $platform host',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.reset);
        final outer = await workspaceProvider(locale: 'en');
        final inner = await workspaceProvider(locale: 'ja');
        final pane = WorkspacePaneController();
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox());
          pane.dispose();
          inner.dispose();
          outer.dispose();
        });

        await tester.pumpWidget(
          AppScope(
            app: outer,
            child: _localizedApp(
              Scaffold(
                body: WorkspaceFrame(
                  controller: pane,
                  resources: const SizedBox.shrink(),
                  resourcesCollapsed: true,
                  canvas: AppScope(
                    app: inner,
                    child: Builder(
                      builder: (context) => Center(
                        child: TextButton(
                          onPressed: () => unawaited(
                            showAppModalSheet<void>(
                              context: context,
                              workspacePane: pane,
                              panePresentation: WorkspacePanePresentation.view,
                              builder: (taskContext) {
                                expect(
                                  taskContext.read<AppSession>(),
                                  same(inner.session),
                                );
                                final close = TextButton(
                                  onPressed: () =>
                                      Navigator.of(taskContext).pop(),
                                  child: const Text('Close task'),
                                );
                                final setting = TextButton(
                                  onPressed: () => unawaited(
                                    taskContext
                                        .read<SettingsCommands>()
                                        .updateLocaleCode('zh'),
                                  ),
                                  child: Text(
                                    taskContext
                                        .watch<SettingsViewState>()
                                        .localeCode,
                                  ),
                                );
                                if (platform == TargetPlatform.windows) {
                                  return WorkspaceViewPanel(
                                    title: const Text('Scoped settings'),
                                    headerAction: close,
                                    child: setting,
                                  );
                                }
                                return AppSheetScaffold(
                                  title: const Text('Scoped settings'),
                                  actions: [close],
                                  child: setting,
                                );
                              },
                            ),
                          ),
                          child: const Text('Open scoped task'),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open scoped task'));
        await tester.pumpAndSettle();
        expect(pane.hasPaneTasks, platform == TargetPlatform.windows);
        expect(pane.hasModalTasks, platform == TargetPlatform.android);
        expect(find.text('ja').hitTestable(), findsOneWidget);
        await tester.tap(find.text('ja'));
        await tester.pumpAndSettle();
        expect(find.text('zh'), findsOneWidget);
        expect(inner.settingsView.localeCode, 'zh');
        expect(outer.settingsView.localeCode, 'en');

        expect(find.text('Close task').hitTestable(), findsOneWidget);
        await tester.tap(find.text('Close task'));
        await tester.pumpAndSettle();
        expect(pane.isOpen, isFalse);
        expect(find.text('Scoped settings'), findsNothing);
        await inner.settingsCommands.updateLocaleCode('en');
        await tester.pump();
        expect(inner.settingsView.localeCode, 'en');
        expect(find.text('Open scoped task'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(platform),
    );
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'a 101dp editor viewport retains complete commands and its draft at $scale text',
      (tester) async {
        final height = ValueNotifier(600.0);
        final input = TextEditingController(
          text: 'Retained short-window draft',
        );
        addTearDown(height.dispose);
        addTearDown(input.dispose);
        await tester.pumpWidget(
          _localizedApp(
            MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: Center(
                  child: ValueListenableBuilder<double>(
                    valueListenable: height,
                    builder: (_, value, child) =>
                        SizedBox(width: 320, height: value, child: child),
                    child: AppSheetScaffold.editor(
                      compact: true,
                      title: const Text('A full editor title'),
                      onClose: () {},
                      editorActions: SkedEditorActions(
                        onCancel: () {},
                        onSubmit: () {},
                      ),
                      child: TextField(controller: input),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final field = find.byType(TextField);
        final original = tester.element(field);
        height.value = 101;
        await tester.pumpAndSettle();
        expect(tester.element(field), same(original));
        expect(input.text, 'Retained short-window draft');
        final footer = find.byKey(const ValueKey('app-sheet-actions'));
        final viewport = find
            .ancestor(of: footer, matching: find.byType(SingleChildScrollView))
            .first;
        for (final label in ['Cancel', 'Save']) {
          final button = find
              .ancestor(
                of: find.text(label),
                matching: find.byWidgetPredicate(
                  (widget) => widget is ButtonStyleButton,
                ),
              )
              .first;
          await tester.ensureVisible(button);
          await tester.pumpAndSettle();
          final bounds = tester.getRect(button);
          final visible = tester.getRect(viewport);
          expect(bounds.height, greaterThanOrEqualTo(48));
          expect(bounds.top, greaterThanOrEqualTo(visible.top));
          expect(bounds.bottom, lessThanOrEqualTo(visible.bottom));
          expect(button.hitTestable(), findsOneWidget);
        }
        expect(
          tester
              .getSize(find.byKey(const PageStorageKey('app-sheet-body')))
              .height,
          greaterThanOrEqualTo(24),
        );
        height.value = 600;
        await tester.pumpAndSettle();
        expect(tester.element(field), same(original));
        expect(input.text, 'Retained short-window draft');
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }

  testWidgets(
    'desktop editor without a workspace host retains subtitle and custom commands',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1100, 850);
      addTearDown(tester.view.reset);
      var closes = 0;
      var imports = 0;
      await tester.pumpWidget(
        _localizedApp(
          Scaffold(
            body: Center(
              child: SizedBox(
                width: 640,
                height: 700,
                child: AppSheetScaffold.editor(
                  title: const Text('Edit imported course'),
                  subtitle: const Text('Imported draft, not saved yet'),
                  onClose: () => closes++,
                  editorActions: SkedEditorActions(
                    onCancel: () => closes++,
                    onSubmit: () => imports++,
                  ),
                  footer: FilledButton(
                    onPressed: () => imports++,
                    child: const Text('Import as new timetable'),
                  ),
                  child: const SizedBox(
                    height: 1400,
                    child: Text('Imported fields'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final editor = find.byType(WorkspaceEditorScaffold);
      expect(editor, findsOneWidget);
      expect(WorkspaceEditorScope.maybeOf(tester.element(editor)), isNull);
      expect(find.text('Imported draft, not saved yet'), findsOneWidget);
      expect(find.text('Cancel'), findsNothing);
      expect(find.text('Save'), findsNothing);
      final footer = find.text('Import as new timetable');
      final footerBounds = tester.getRect(footer);
      await tester.drag(
        find.byKey(const PageStorageKey('workspace-editor-body')),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(footer), footerBounds);
      expect(footer.hitTestable(), findsOneWidget);
      await tester.tap(footer);
      await tester.tap(find.byKey(const ValueKey('workspace-editor-close')));
      expect(imports, 1);
      expect(closes, 1);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets('custom footer stays fixed while the sheet body scrolls', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _localizedApp(
        Scaffold(
          body: AppSheetScaffold(
            title: const Text('Import preview'),
            subtitle: const Text('Keep import options visible'),
            leading: const Text('Legacy leading action'),
            actions: const [Text('Legacy trailing action')],
            footer: const FilledButton(
              onPressed: null,
              child: Text('Import as new timetable'),
            ),
            child: const SizedBox(
              height: 1200,
              child: Align(
                alignment: Alignment.topLeft,
                child: Text('Scrollable import content'),
              ),
            ),
          ),
        ),
      ),
    );

    final footer = find.text('Import as new timetable');
    expect(footer, findsOneWidget);
    expect(find.text('Legacy leading action'), findsNothing);
    expect(find.text('Legacy trailing action'), findsNothing);
    final body = find.byKey(const PageStorageKey('app-sheet-body'));
    expect(body, findsOneWidget);
    expect(find.text('Keep import options visible'), findsOneWidget);

    final beforeScroll = tester.getRect(footer);
    final heading = tester.getRect(find.text('Import preview'));
    await tester.drag(body, const Offset(0, -320));
    await tester.pumpAndSettle();

    expect(tester.getRect(footer), beforeScroll);
    expect(tester.getRect(find.text('Import preview')), heading);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disabling sheet drag also removes the draggable handle', (
    tester,
  ) async {
    await tester.pumpWidget(
      _localizedApp(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                unawaited(
                  showAppModalSheet<void>(
                    context: context,
                    enableDrag: false,
                    builder: (_) => const SizedBox(height: 160),
                  ),
                );
              },
              child: const Text('Open sheet'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open sheet'));
    await tester.pumpAndSettle();

    final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
    expect(sheet.enableDrag, isFalse);
    expect(sheet.showDragHandle, isFalse);
    expect(sheet.clipBehavior, Clip.antiAlias);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sheet command failures render above the modal route', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _localizedApp(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                unawaited(
                  showAppModalSheet<void>(
                    context: context,
                    enableDrag: false,
                    builder: (sheetContext) => SizedBox(
                      height: 240,
                      child: Center(
                        child: FilledButton(
                          onPressed: () {
                            unawaited(
                              runUiCommandWithFeedback(
                                context: sheetContext,
                                debugLabel: 'Test sheet command',
                                command: () async {
                                  throw StateError('sheet failure');
                                },
                              ),
                            );
                          },
                          child: const Text('Fail in sheet'),
                        ),
                      ),
                    ),
                  ),
                );
              },
              child: const Text('Open sheet'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open sheet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fail in sheet'));
    await tester.pumpAndSettle();

    final notice = find.byKey(const ValueKey('ui-command-failure-notice'));
    final dismiss = find.byKey(const ValueKey('ui-command-failure-dismiss'));
    expect(notice, findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(dismiss.hitTestable(), findsOneWidget);

    final sheetRect = tester.getRect(find.byType(BottomSheet));
    final noticeRect = tester.getRect(notice);
    expect(sheetRect.contains(noticeRect.topLeft), isTrue);
    expect(
      sheetRect.contains(noticeRect.bottomRight - const Offset(1, 1)),
      isTrue,
    );
    expect(
      tester.getSemantics(
        find.byKey(const ValueKey('ui-command-failure-live-region-1')),
      ),
      matchesSemantics(
        label: 'Save failed. Please try again later.',
        isLiveRegion: true,
      ),
    );

    await tester.tap(dismiss);
    await tester.pump();
    expect(notice, findsNothing);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('dialog command failures stay above the modal barrier', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _localizedApp(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                unawaited(
                  showExpressiveDialog<void>(
                    context: context,
                    barrierDismissible: false,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Test dialog'),
                      actions: [
                        FilledButton(
                          onPressed: () {
                            unawaited(
                              runUiCommandWithFeedback(
                                context: dialogContext,
                                debugLabel: 'Test dialog command',
                                command: () async {
                                  throw StateError('dialog failure');
                                },
                              ),
                            );
                          },
                          child: const Text('Fail in dialog'),
                        ),
                      ],
                    ),
                  ),
                );
              },
              child: const Text('Open dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fail in dialog'));
    await tester.pumpAndSettle();

    final notice = find.byKey(const ValueKey('ui-command-failure-notice'));
    final dismiss = find.byKey(const ValueKey('ui-command-failure-dismiss'));
    expect(notice, findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(dismiss.hitTestable(), findsOneWidget);
    expect(
      tester.getSemantics(
        find.byKey(const ValueKey('ui-command-failure-live-region-1')),
      ),
      matchesSemantics(
        label: 'Save failed. Please try again later.',
        isLiveRegion: true,
      ),
    );

    await tester.tap(dismiss);
    await tester.pump();
    expect(notice, findsNothing);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
