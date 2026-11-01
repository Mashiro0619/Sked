import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/backup/selective_backup_codec.dart';
import 'package:sked/backup/selective_backup_models.dart';
import 'package:sked/controllers/app_backup_controller.dart' show AppImportMode;
import 'package:sked/controllers/app_data_maintenance.dart'
    show AppBackupRestoreInProgressException;
import 'package:sked/screens/selective_backup_page.dart';
import 'package:sked/screens/settings_data_transfer_controller.dart';
import 'package:sked/screens/settings_page.dart';
import 'package:sked/screens/theme_settings_page.dart';
import 'package:sked/widgets/sked_dropdown_menu.dart';
import 'package:sked/widgets/ui_command.dart';
import 'package:sked/widgets/text_transfer_widgets.dart';

import '../support/workspace_harness.dart';

class _Storage extends WorkspaceMemoryStorage {
  _Storage(super.data);
  Completer<void>? pending;
  Completer<void>? saveStarted;
  int writes = 0;
  @override
  Future<void> save(AppData value) async {
    writes++;
    if (saveStarted case final signal? when !signal.isCompleted) {
      signal.complete();
    }
    await pending?.future;
    await super.save(value);
  }
}

class _FilePicker extends FileSelectorPlatform {
  _FilePicker(this.source, {this.file});
  final String source;
  final XFile? file;
  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async =>
      file ??
      XFile.fromData(
        Uint8List.fromList(utf8.encode(source)),
        path: 'backup.json',
        name: 'backup.json',
        mimeType: 'application/json',
      );
}

class _PendingFilePicker extends _FilePicker {
  _PendingFilePicker(super.source);
  final started = Completer<void>(), release = Completer<void>();
  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async {
    started.complete();
    await release.future;
    return super.openFile(acceptedTypeGroups: acceptedTypeGroups);
  }
}

class _OversizedBackupFile extends XFile {
  _OversizedBackupFile() : super('oversized.zip');
  @override
  Future<int> length() async => SelectiveBackupLimits.archiveBytes + 1;
  @override
  Stream<Uint8List> openRead([int? start, int? end]) =>
      throw StateError('Oversized backup bytes must not be read.');
}

Future<(AppRuntime, _Storage)> _fixture() async {
  final seed = await workspaceProvider();
  final storage = _Storage(seed.workspaceView.data);
  seed.dispose();
  final result = (await workspaceProvider(storage: storage), storage);
  await result.$1.backups.selective.inventory();
  return result;
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
  await tester.runAsync(() => tester.tap(finder));
  await _pump(tester);
}

void _pickBackup(String source, {FileSelectorPlatform? picker}) {
  final previousPicker = FileSelectorPlatform.instance;
  FileSelectorPlatform.instance = picker ?? _FilePicker(source);
  addTearDown(() => FileSelectorPlatform.instance = previousPicker);
}

Future<void> _selectApplicationAndReview(WidgetTester tester) async {
  final page = tester.widget<SelectiveBackupPage>(
    find.byType(SelectiveBackupPage),
  );
  await tester.runAsync(() => page.service.inventory());
  final l = AppLocalizations.of(
    tester.element(find.byType(SelectiveBackupPage)),
  );
  final scrollable = find
      .descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(Scrollable),
      )
      .first;
  await tester.scrollUntilVisible(
    find.text(l.selectiveBackupClearSelection),
    300,
    scrollable: scrollable,
  );
  await _open(tester, find.text(l.selectiveBackupClearSelection));
  await tester.scrollUntilVisible(
    find.byType(TextField),
    -200,
    scrollable: scrollable,
  );
  await tester.enterText(
    find.byType(TextField),
    l.selectiveBackupApplicationSettings,
  );
  await _pump(tester);
  await tester.scrollUntilVisible(
    _key('backup-object-settings:application'),
    250,
    scrollable: scrollable,
  );
  await _open(tester, _key('backup-object-settings:application'));
  expect(
    tester
        .widget<CheckboxListTile>(_key('backup-object-settings:application'))
        .value,
    isTrue,
  );
  final primary = _key('selective-backup-primary');
  await tester.scrollUntilVisible(
    primary,
    350,
    scrollable: find
        .descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.runAsync(() async {
    final prepared = Completer<void>();
    var preparing = false;
    void preparationChanged() {
      if (page.service.isBusy) {
        preparing = true;
      } else if (preparing && !prepared.isCompleted) {
        prepared.complete();
      }
    }

    page.service.addListener(preparationChanged);
    try {
      await tester.tap(primary);
      await prepared.future.timeout(const Duration(seconds: 15));
    } finally {
      page.service.removeListener(preparationChanged);
    }
  });
  await tester.pumpAndSettle();
  expect(find.text(l.selectiveBackupConfirmTitle), findsOneWidget);
  expect(find.byType(LinearProgressIndicator), findsNothing);
}

Future<void> _startFileRestore(
  WidgetTester tester,
  _Storage storage, {
  bool fails = false,
}) async {
  final l = AppLocalizations.of(
    tester.element(find.byType(SettingsPage).first),
  );
  await _open(tester, _key('settings-app-backup'));
  await _open(tester, find.text(l.restoreBackupFileTitle));
  await _selectApplicationAndReview(tester);
  await tester.runAsync(() async {
    storage.pending = Completer<void>();
    storage.saveStarted = Completer<void>();
    if (fails) storage.saveError = StateError('disk full');
    await tester.tap(
      find.widgetWithText(FilledButton, l.selectiveBackupRestore),
    );
    await storage.saveStarted!.future.timeout(const Duration(seconds: 15));
  });
  await _pump(tester);
}

Switch _switchIn(WidgetTester tester, Finder row) => tester.widget<Switch>(
  find.descendant(of: row, matching: find.byType(Switch)),
);

Future<void> _runBackupButton(WidgetTester tester, Finder button) async {
  final service = tester
      .widget<SelectiveBackupPage>(find.byType(SelectiveBackupPage))
      .service;
  await tester.ensureVisible(button);
  await tester.runAsync(() async {
    final done = Completer<void>();
    var started = false;
    void changed() {
      if (service.isBusy) {
        started = true;
      } else if (started && !done.isCompleted) {
        done.complete();
      }
    }

    service.addListener(changed);
    try {
      await tester.tap(button);
      await done.future.timeout(const Duration(seconds: 15));
    } finally {
      service.removeListener(changed);
    }
  });
  await tester.pumpAndSettle();
}

Future<void> _finishBackupWrite(
  WidgetTester tester,
  AppRuntime runtime,
  _Storage storage,
) async {
  final service = runtime.backups.selective;
  await tester.runAsync(() async {
    final done = Completer<void>();
    void changed() {
      if (!service.isBusy && !done.isCompleted) done.complete();
    }

    service.addListener(changed);
    try {
      storage.pending!.complete();
      storage.pending = null;
      await done.future.timeout(const Duration(seconds: 15));
    } finally {
      service.removeListener(changed);
    }
  });
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final scenario in [
    (file: true, locale: const Locale('en'), empty: false),
    (file: false, locale: const Locale('zh'), empty: false),
    (file: true, locale: const Locale('en'), empty: true),
  ]) {
    testWidgets(
      'legacy restore uses object selection, keeps unselected connection and preserves cancelled text: $scenario',
      (tester) async {
        _viewport(tester);
        final (provider, storage) = (await tester.runAsync(_fixture))!;
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox());
          provider.dispose();
        });
        var retainedUrl = scenario.empty
            ? ''
            : 'https://user:local-password@local.example/v1?token=local-token#local-fragment';
        await tester.runAsync(() async {
          await provider.settingsCommands.updateCustomSchoolImportTextSettings(
            baseUrl: retainedUrl,
            model: 'local-model',
            prompt: 'local prompt',
          );
          await provider.schoolImportSecrets.update('local-key');
        });
        final original = provider.session.committedData;
        final source = encodeAppBackup(
          original.copyWith(hideHomeWorkspaceNavigation: true),
          [],
        );
        if (scenario.file) _pickBackup(source);
        await tester.pumpWidget(
          WorkspaceHarness(
            provider: provider,
            home: const SettingsPage(),
            locale: scenario.locale,
            textScale: 2,
          ),
        );
        await tester.pumpAndSettle();
        final l = AppLocalizations.of(
          tester.element(find.byType(SettingsPage)),
        );
        Future<void> openSource({bool retry = false}) async {
          if (!retry || scenario.file) {
            await _open(tester, _key('settings-app-backup'));
            await _open(
              tester,
              find.text(
                scenario.file
                    ? l.restoreBackupFileTitle
                    : l.restoreBackupTextTitle,
              ),
            );
            if (!scenario.file) {
              await tester.enterText(find.byType(TextField), source);
              await _pump(tester);
            }
          }
          if (!scenario.file) {
            await _open(
              tester,
              find.widgetWithText(FilledButton, l.restoreBackupConfirmAction),
            );
          }
          await _selectApplicationAndReview(tester);
        }

        await openSource();
        final summary = tester
            .widget<Text>(_key('restore-backup-agent-settings-summary'))
            .data!;
        expect(summary, l.agentBackupConnectionPreserved);
        for (final secret in [
          'local-password',
          'local-token',
          'local-fragment',
          'local-key',
        ]) {
          expect(summary, isNot(contains(secret)));
        }
        final writesBeforeCancel = storage.writes;
        await _open(tester, find.widgetWithText(TextButton, l.cancel));
        await tester.runAsync(() => tester.binding.handlePopRoute());
        await tester.pumpAndSettle();
        expect(storage.writes, writesBeforeCancel);
        expect(provider.settingsView.hideHomeWorkspaceNavigation, isFalse);
        if (!scenario.file) {
          expect(
            tester.widget<TextField>(find.byType(TextField)).controller!.text,
            source,
          );
        }
        if (scenario.file && !scenario.empty) {
          retainedUrl = 'https://revised.example/v1';
          await tester.runAsync(
            () =>
                provider.settingsCommands.updateCustomSchoolImportTextSettings(
                  baseUrl: retainedUrl,
                  model: 'local-model',
                  prompt: 'local prompt',
                  confirmedEndpointChange: provider.settingsCommands
                      .customSchoolImportEndpointChange(retainedUrl),
                ),
          );
        }
        final retainedKey = provider.schoolImportSecrets.value;
        await openSource(retry: true);
        await _runBackupButton(
          tester,
          find.widgetWithText(FilledButton, l.selectiveBackupRestore),
        );
        await tester.pumpAndSettle();
        expect(provider.settingsView.hideHomeWorkspaceNavigation, isTrue);
        expect(provider.settingsView.customSchoolImportBaseUrl, retainedUrl);
        expect(provider.settingsView.customSchoolImportModel, 'local-model');
        expect(provider.schoolImportSecrets.value, retainedKey);
        expect(
          provider.session.committedData.studentMode.toJson(),
          original.studentMode.toJson(),
        );
        expect(
          provider.session.committedData.generalMode.toJson(),
          original.generalMode.toJson(),
        );
        expect(find.byType(TextImportPage), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final scenario in [
    (kind: 'zip', file: true, locale: const Locale('en')),
    (kind: 'legacy envelope', file: true, locale: const Locale('zh')),
    (
      kind: 'legacy envelope',
      file: false,
      locale: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    ),
    (kind: 'legacy schema', file: true, locale: const Locale('en')),
    (kind: 'legacy schema', file: false, locale: const Locale('zh')),
  ]) {
    testWidgets(
      'newer backup format requests an upgrade and keeps local data: $scenario',
      (tester) async {
        _viewport(tester);
        final (provider, storage) = (await tester.runAsync(_fixture))!;
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox());
          provider.dispose();
        });
        final original = provider.session.committedData.encode();
        final writesBefore = storage.writes;
        final legacy = jsonDecode(
          encodeAppBackup(provider.session.committedData, const []),
        ) as Map<String, dynamic>;
        if (scenario.kind == 'legacy schema') {
          final data = legacy['data']['appData'] as Map<String, dynamic>;
          data['schemaVersion'] = (data['schemaVersion'] as int) + 1;
        } else {
          legacy['version'] = (legacy['version'] as int) + 1;
        }
        final source = jsonEncode(legacy);
        if (scenario.kind == 'zip') {
          final archive = Archive()
            ..add(
              ArchiveFile.string(
                SelectiveBackupCodec.manifestPath,
                jsonEncode({
                  'schema': SelectiveBackupCodec.schema,
                  'version': SelectiveBackupCodec.version + 1,
                }),
              ),
            );
          _pickBackup(
            '',
            picker: _FilePicker(
              '',
              file: XFile.fromData(
                ZipEncoder().encodeBytes(archive),
                name: 'newer-backup.zip',
                mimeType: 'application/zip',
              ),
            ),
          );
        } else if (scenario.file) {
          _pickBackup(source);
        }
        await tester.pumpWidget(
          WorkspaceHarness(
            provider: provider,
            home: const SettingsPage(),
            locale: scenario.locale,
          ),
        );
        await tester.pumpAndSettle();
        final l = AppLocalizations.of(
          tester.element(find.byType(SettingsPage)),
        );
        await _open(tester, _key('settings-app-backup'));
        await _open(
          tester,
          find.text(
            scenario.file ? l.restoreBackupFileTitle : l.restoreBackupTextTitle,
          ),
        );
        if (!scenario.file) {
          await tester.enterText(find.byType(TextField), source);
          await _open(
            tester,
            find.widgetWithText(FilledButton, l.restoreBackupConfirmAction),
          );
          expect(
            tester.widget<TextField>(find.byType(TextField)).controller!.text,
            source,
          );
        }
        expect(find.text(l.selectiveBackupNewerVersion), findsOneWidget);
        expect(find.text(l.selectiveBackupInvalid), findsNothing);
        expect(find.byType(SelectiveBackupPage), findsNothing);
        expect(provider.session.committedData.encode(), original);
        expect(storage.writes, writesBefore);
        expect(provider.maintenance.isReserved, isFalse);
        expect(provider.backups.selective.recoveryPending, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'oversized backup is refused before reading its bytes or opening selection',
    (tester) async {
      _viewport(tester);
      final (provider, storage) = (await tester.runAsync(_fixture))!;
      addTearDown(provider.dispose);
      _pickBackup('', picker: _FilePicker('', file: _OversizedBackupFile()));
      await tester.pumpWidget(
        WorkspaceHarness(provider: provider, home: const SettingsPage()),
      );
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(tester.element(find.byType(SettingsPage)));
      await _open(tester, _key('settings-app-backup'));
      await _open(tester, find.text(l.restoreBackupFileTitle));
      expect(find.text(l.selectiveBackupLimit), findsOneWidget);
      expect(find.byType(SelectiveBackupPage), findsNothing);
      expect(storage.writes, 0);
      expect(provider.maintenance.isReserved, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'text restore resumes its fixed target after an interrupted write',
    (tester) async {
      _viewport(tester);
      final (provider, storage) = (await tester.runAsync(_fixture))!;
      addTearDown(provider.dispose);
      final source = encodeAppBackup(
        provider.session.committedData.copyWith(
          hideHomeWorkspaceNavigation: true,
        ),
        [],
      );
      await tester.pumpWidget(
        WorkspaceHarness(provider: provider, home: const SettingsPage()),
      );
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(tester.element(find.byType(SettingsPage)));
      await _open(tester, _key('settings-app-backup'));
      await _open(tester, find.text(l.restoreBackupTextTitle));
      await tester.enterText(find.byType(TextField), source);
      await _open(
        tester,
        find.widgetWithText(FilledButton, l.restoreBackupConfirmAction),
      );
      await _selectApplicationAndReview(tester);
      storage.saveError = StateError('disk full');
      await _runBackupButton(
        tester,
        find.widgetWithText(FilledButton, l.selectiveBackupRestore),
      );
      await tester.pumpAndSettle();
      expect(provider.session.canWrite, isFalse);
      expect(provider.backups.selective.recoveryPending, isTrue);
      final pending = await provider.backups.selective.journal.read();
      expect(pending, isNotNull);
      expect(find.text(l.selectiveBackupRecoveryPending), findsOneWidget);
      await _runBackupButton(
        tester,
        find.widgetWithText(FilledButton, l.selectiveBackupResume),
      );
      await tester.pumpAndSettle();
      expect(provider.session.canWrite, isTrue);
      expect(provider.settingsView.hideHomeWorkspaceNavigation, isTrue);
      expect(await provider.backups.selective.journal.read(), isNull);
      expect(find.byType(TextImportPage), findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.windows,
    }),
  );

  testWidgets(
    'a file picker from an earlier data session cannot open a restore selection',
    (tester) async {
      _viewport(tester);
      final (provider, storage) = (await tester.runAsync(_fixture))!;
      addTearDown(provider.dispose);
      final original = provider.session.committedData;
      final picker = _PendingFilePicker(encodeAppBackup(original, []));
      _pickBackup('', picker: picker);
      await tester.pumpWidget(
        WorkspaceHarness(provider: provider, home: const SettingsPage()),
      );
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(tester.element(find.byType(SettingsPage)));
      await _open(tester, _key('settings-app-backup'));
      await _open(tester, find.text(l.restoreBackupFileTitle));
      expect(picker.started.isCompleted, isTrue);
      final reservation = provider.maintenance.reserve();
      provider.maintenance.release(reservation);
      picker.release.complete();
      await tester.pumpAndSettle();
      expect(find.byType(SelectiveBackupPage), findsNothing);
      expect(provider.session.committedData, same(original));
      expect(storage.writes, 0);
      expect(tester.takeException(), isNull);
    },
  );

  for (final fails in [false, true]) {
    testWidgets(
      'accepted selective restore remains owned while browsing and ${fails ? 'recovery' : 'completion'} restores editing',
      (tester) async {
        _viewport(tester);
        final (provider, storage) = (await tester.runAsync(_fixture))!;
        addTearDown(provider.dispose);
        _pickBackup(
          encodeAppBackup(
            provider.workspaceView.data.copyWith(
              hideHomeWorkspaceNavigation: true,
            ),
            [],
          ),
        );
        await tester.pumpWidget(
          WorkspaceHarness(provider: provider, home: const SettingsPage()),
        );
        await tester.pumpAndSettle();
        final l = AppLocalizations.of(
          tester.element(find.byType(SettingsPage)),
        );
        await _startFileRestore(tester, storage, fails: fails);
        expect(provider.maintenance.isReserved, isTrue);
        await tester.pageBack();
        await _pump(tester);
        expect(_status, findsOneWidget);
        await _open(tester, _key('settings-workspace-features'));
        expect(
          _switchIn(tester, _key('workspace-enabled-student')).onChanged,
          isNull,
        );
        await tester.pageBack();
        await _pump(tester);
        await _open(tester, _key('settings-language'));
        await tester.enterText(_key('language-search'), 'Deutsch');
        await _pump(tester);
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
        await tester.pageBack();
        await _pump(tester);
        await _finishBackupWrite(tester, provider, storage);
        expect(provider.maintenance.isReserved, isFalse);
        if (fails) {
          expect(provider.session.canWrite, isFalse);
          await _open(tester, _key('settings-app-backup'));
          await _open(tester, find.text(l.selectiveBackupTitle));
          await tester.pumpAndSettle();
          await _runBackupButton(
            tester,
            find.widgetWithText(FilledButton, l.selectiveBackupResume),
          );
          await tester.pumpAndSettle();
          await tester.pageBack();
          await _pump(tester);
        }
        expect(provider.session.canWrite, isTrue);
        expect(provider.settingsView.hideHomeWorkspaceNavigation, isTrue);
        await _open(tester, _key('settings-workspace-features'));
        expect(
          _switchIn(tester, _key('workspace-enabled-student')).onChanged,
          isNotNull,
        );
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
      final (provider, storage) = (await tester.runAsync(_fixture))!;
      addTearDown(provider.dispose);
      final source = (await tester.runAsync(provider.backups.exportJson))!;
      await tester.pumpWidget(
        WorkspaceHarness(
          provider: provider,
          home: SettingsPage(initialDestination: destination),
        ),
      );
      await tester.pumpAndSettle();
      late Future<int> restoring;
      await tester.runAsync(() async {
        storage.pending = Completer<void>();
        storage.saveStarted = Completer<void>();
        restoring = provider.backups.importJson(
          source,
          mode: AppImportMode.replaceAll,
        );
        await storage.saveStarted!.future.timeout(const Duration(seconds: 15));
      });
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
      await tester.runAsync(() async {
        storage.pending!.complete();
        await restoring;
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'theme target remains readable while saved theme choices are disabled',
    (tester) async {
      _viewport(tester, const Size(1100, 1000));
      final (provider, storage) = (await tester.runAsync(_fixture))!;
      addTearDown(provider.dispose);
      final source = (await tester.runAsync(provider.backups.exportJson))!;
      await tester.pumpWidget(
        WorkspaceHarness(
          provider: provider,
          home: const ThemeSettingsPage(initialWorkspace: AppMode.student),
        ),
      );
      await tester.pumpAndSettle();
      late Future<int> restoring;
      await tester.runAsync(() async {
        storage.pending = Completer<void>();
        storage.saveStarted = Completer<void>();
        restoring = provider.backups.importJson(
          source,
          mode: AppImportMode.replaceAll,
        );
        await storage.saveStarted!.future.timeout(const Duration(seconds: 15));
      });
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
      expect(provider.workspaceView.activeMode, AppMode.student);
      expect(
        menuIn('theme-workspace-mode-choice-list').initialSelection,
        AppMode.general.value,
      );
      await tester.runAsync(() async {
        storage.pending!.complete();
        await restoring;
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets('leaving settings does not cancel a confirmed file restore', (
    tester,
  ) async {
    _viewport(tester);
    final (provider, storage) = (await tester.runAsync(_fixture))!;
    addTearDown(provider.dispose);
    _pickBackup(
      encodeAppBackup(
        provider.workspaceView.data.copyWith(hideHomeWorkspaceNavigation: true),
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
    expect(provider.maintenance.isReserved, isTrue);
    await tester.pageBack();
    await _pump(tester);
    await tester.pageBack();
    await _pump(tester);
    expect(find.byType(SettingsPage), findsNothing);
    expect(provider.maintenance.isReserved, isTrue);
    await _finishBackupWrite(tester, provider, storage);
    expect(provider.maintenance.isReserved, isFalse);
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
