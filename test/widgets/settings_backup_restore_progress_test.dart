import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/screens/language_settings_page.dart';
import 'package:sked/screens/settings_data_transfer_controller.dart';
import 'package:sked/screens/settings_page.dart';
import 'package:sked/screens/theme_settings_page.dart';
import 'package:sked/screens/workspace_features_page.dart';
import 'package:sked/widgets/sked_dropdown_menu.dart';
import 'package:sked/widgets/ui_command.dart';

import '../support/workspace_harness.dart';

class _Storage extends WorkspaceMemoryStorage {
  _Storage(super.data);

  Completer<void>? pending;
  int writes = 0;

  @override
  Future<void> save(AppData value) async {
    writes++;
    await pending?.future;
    await super.save(value);
  }
}

class _FilePicker extends FileSelectorPlatform {
  _FilePicker(this.source);
  final String source;

  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async => XFile.fromData(
    Uint8List.fromList(utf8.encode(source)),
    name: 'backup.json',
    mimeType: 'application/json',
  );
}

Future<(TimetableProvider, _Storage)> _fixture() async {
  final seed = await workspaceProvider();
  final storage = _Storage(seed.appData);
  seed.dispose();
  return (await workspaceProvider(storage: storage), storage);
}

void _viewport(WidgetTester tester, [Size size = const Size(393, 900)]) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Finder _key(String key) => find.byKey(ValueKey(key));
Finder get _status => _key('settings-backup-restore-status');

Future<void> _pump(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> _open(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await _pump(tester);
  await tester.tap(finder);
  await _pump(tester);
}

void _pickBackup(String source) {
  final previousPicker = FileSelectorPlatform.instance;
  FileSelectorPlatform.instance = _FilePicker(source);
  addTearDown(() => FileSelectorPlatform.instance = previousPicker);
}

Future<void> _startFileRestore(
  WidgetTester tester,
  _Storage storage, {
  bool fails = false,
}) async {
  final l10n = AppLocalizations.of(
    tester.element(find.byType(SettingsPage).first),
  );
  await _open(tester, _key('settings-app-backup'));
  await _open(tester, find.text(l10n.restoreBackupFileTitle));
  expect(find.text(l10n.restoreBackupConfirmTitle), findsOneWidget);
  storage.pending = Completer<void>();
  if (fails) storage.saveError = StateError('disk full');
  await tester.tap(
    find.widgetWithText(FilledButton, l10n.restoreBackupConfirmAction),
  );
  await _pump(tester);
}

Switch _switchIn(WidgetTester tester, Finder row) => tester.widget<Switch>(
  find.descendant(of: row, matching: find.byType(Switch)),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final fails in [false, true]) {
    testWidgets(
      'file restore shows progress, allows browsing and restores writes after ${fails ? 'failure' : 'success'}',
      (tester) async {
        _viewport(tester);
        final (provider, storage) = await _fixture();
        addTearDown(provider.dispose);
        _pickBackup(
          encodeAppBackup(
            provider.appData.copyWith(hideHomeWorkspaceNavigation: true),
            [],
          ),
        );
        await tester.pumpWidget(
          WorkspaceHarness(provider: provider, home: const SettingsPage()),
        );
        await tester.pumpAndSettle();
        final l10n = AppLocalizations.of(
          tester.element(find.byType(SettingsPage)),
        );
        final writesBefore = storage.writes;
        await _startFileRestore(tester, storage, fails: fails);
        expect(provider.isRestoringAppBackup, isTrue);
        expect(_status, findsOneWidget);
        expect(find.text(l10n.backupRestoreInProgressTitle), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        expect(storage.writes, writesBefore + 1);

        await _open(tester, _key('settings-workspace-features'));
        expect(find.byType(WorkspaceFeaturesPage), findsOneWidget);
        expect(_status, findsOneWidget);
        expect(
          _switchIn(tester, _key('workspace-enabled-student')).onChanged,
          isNull,
        );
        await tester.tap(
          _key('workspace-enabled-student'),
          warnIfMissed: false,
        );
        await _pump(tester);
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text(l10n.saveFailedRetry), findsNothing);
        expect(storage.writes, writesBefore + 1);
        await tester.pageBack();
        await _pump(tester);

        await _open(tester, _key('settings-language'));
        expect(find.byType(LanguageSettingsPage), findsOneWidget);
        await tester.enterText(_key('language-search'), 'Deutsch');
        await _pump(tester);
        expect(_key('language-option-de'), findsOneWidget);
        expect(
          tester
              .widget<InkWell>(
                find.descendant(
                  of: _key('language-option-de'),
                  matching: find.byType(InkWell),
                ),
              )
              .onTap,
          isNull,
        );
        expect(_status, findsOneWidget);
        await tester.pageBack();
        await _pump(tester);

        storage.pending!.complete();
        await tester.pumpAndSettle();
        storage.pending = null;
        expect(provider.isRestoringAppBackup, isFalse);
        expect(_status, findsNothing);
        expect(provider.hideHomeWorkspaceNavigation, !fails);
        expect(
          find.text(
            fails
                ? l10n.restoreBackupFailureMessage
                : l10n.restoreBackupSuccessMessage,
          ),
          findsOneWidget,
        );
        await _open(tester, _key('settings-workspace-features'));
        expect(
          _switchIn(tester, _key('workspace-enabled-student')).onChanged,
          isNotNull,
        );
        await tester.tap(find.text(l10n.hideHomeWorkspaceNavigation));
        await tester.pumpAndSettle();
        expect(provider.hideHomeWorkspaceNavigation, fails);
        expect(storage.writes, writesBefore + 2);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.windows,
      }),
    );
  }

  for (final destination in [
    SettingsDestination.student,
    SettingsDestination.general,
  ]) {
    testWidgets('$destination keeps export actions available during restore', (
      tester,
    ) async {
      _viewport(tester, const Size(1100, 1000));
      final (provider, storage) = await _fixture();
      addTearDown(provider.dispose);
      final source = await provider.exportAppDataJson();
      await tester.pumpWidget(
        WorkspaceHarness(
          provider: provider,
          home: SettingsPage(initialDestination: destination),
        ),
      );
      await tester.pumpAndSettle();
      storage.pending = Completer<void>();
      final restoring = provider.importAppDataJson(
        source,
        mode: AppImportMode.replaceAll,
      );
      await _pump(tester);
      expect(_status, findsOneWidget);
      final imports = tester.widgetList<SettingsTransferPageTile>(
        find.descendant(
          of: _key('transfer-import-group'),
          matching: find.byType(SettingsTransferPageTile),
        ),
      );
      final exports = tester.widgetList<SettingsTransferPageTile>(
        find.descendant(
          of: _key('transfer-export-group'),
          matching: find.byType(SettingsTransferPageTile),
        ),
      );
      expect(imports, isNotEmpty);
      expect(exports, isNotEmpty);
      expect(imports.every((tile) => tile.onTap == null), isTrue);
      expect(exports.every((tile) => tile.onTap != null), isTrue);
      storage.pending!.complete();
      await tester.pumpAndSettle();
      await restoring;
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'theme target remains readable while saved theme choices are disabled',
    (tester) async {
      _viewport(tester, const Size(1100, 1000));
      final (provider, storage) = await _fixture();
      addTearDown(provider.dispose);
      final source = await provider.exportAppDataJson();
      await tester.pumpWidget(
        WorkspaceHarness(
          provider: provider,
          home: const ThemeSettingsPage(initialWorkspace: AppMode.student),
        ),
      );
      await tester.pumpAndSettle();
      storage.pending = Completer<void>();
      final restoring = provider.importAppDataJson(
        source,
        mode: AppImportMode.replaceAll,
      );
      await _pump(tester);
      SkedDropdownMenu<String> menuIn(String key) =>
          tester.widget<SkedDropdownMenu<String>>(
            find.descendant(
              of: _key(key),
              matching: find.byType(SkedDropdownMenu<String>),
            ),
          );
      expect(menuIn('theme-workspace-mode-choice-list').enabled, isTrue);
      expect(menuIn('theme-brightness-mode-choice-list').enabled, isFalse);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(ThemeSettingsPage)),
      );
      await _open(tester, _key('theme-workspace-mode-choice-list'));
      await tester.tap(find.text(l10n.themeWorkspaceSchedule).last);
      await _pump(tester);
      expect(provider.activeMode, AppMode.student);
      expect(
        menuIn('theme-workspace-mode-choice-list').initialSelection,
        AppMode.general.value,
      );
      storage.pending!.complete();
      await tester.pumpAndSettle();
      await restoring;
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets('leaving settings does not cancel a confirmed file restore', (
    tester,
  ) async {
    _viewport(tester);
    final (provider, storage) = await _fixture();
    addTearDown(provider.dispose);
    _pickBackup(
      encodeAppBackup(
        provider.appData.copyWith(hideHomeWorkspaceNavigation: true),
        [],
      ),
    );
    await tester.pumpWidget(
      WorkspaceHarness(
        provider: provider,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              ),
              child: const Text('Open settings'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _open(tester, find.text('Open settings'));
    await _startFileRestore(tester, storage);
    expect(provider.isRestoringAppBackup, isTrue);
    await tester.pageBack();
    await _pump(tester);
    expect(find.byType(SettingsPage), findsNothing);
    expect(provider.isRestoringAppBackup, isTrue);
    storage.pending!.complete();
    await tester.pumpAndSettle();
    expect(provider.isRestoringAppBackup, isFalse);
    expect(storage.data.hideHomeWorkspaceNavigation, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a stale write reports restore status instead of generic save failure',
    (tester) async {
      final provider = await workspaceProvider();
      addTearDown(provider.dispose);
      await tester.pumpWidget(
        WorkspaceHarness(
          provider: provider,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => unawaited(
                  runUiCommandWithFeedback(
                    context: context,
                    debugLabel: 'Stale settings command',
                    command: () async =>
                        throw const AppBackupRestoreInProgressException(),
                  ),
                ),
                child: const Text('Save'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(tester.element(find.text('Save')));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text(l10n.backupRestoreInProgressMessage), findsOneWidget);
      expect(find.text(l10n.saveFailedRetry), findsNothing);
    },
  );
}
