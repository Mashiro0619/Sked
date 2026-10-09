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
import 'package:sked/screens/app_home_screen.dart';
import 'package:sked/screens/settings_page.dart';
import 'package:sked/screens/theme_settings_page.dart';
import 'package:sked/widgets/expressive_motion.dart';
import 'package:sked/widgets/settings_list.dart';

import '../support/workspace_harness.dart';

class _BackupPicker extends FileSelectorPlatform {
  _BackupPicker(this.source);
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

class _Storage extends WorkspaceMemoryStorage {
  _Storage(super.data);
  var writes = 0;

  @override
  Future<void> save(AppData value) async {
    writes++;
    await super.save(value);
  }
}

class _RestoreGate {
  final ready = Completer<void>();
  var blocked = false;

  Future<void> run(Future<void> Function() action) async {
    if (blocked) await ready.future;
    await action();
  }

  void release() {
    if (!ready.isCompleted) ready.complete();
  }
}

Finder _key(String key) => find.byKey(ValueKey(key));
Finder get _hex => _key('compact-color-picker-hex-field');
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

void _viewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1100, 1000);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

AppData _colorData(AppData source, int color, String colorMode) =>
    source.copyWith(
      privacyPolicyAcceptedVersion: bundledPrivacyPolicyVersion,
      privacyPolicyAcceptedAtIso: '2026-10-01T00:00:00.000',
      studentMode: source.studentMode.copyWith(
        themeColorMode: colorMode,
        themeSeedColorValue: color,
        colorfulUiColorValues: {
          for (final key in [
            colorfulUiPrimaryKey,
            colorfulUiSecondaryKey,
            colorfulUiTertiaryKey,
            colorfulCourseTextColorKey,
          ])
            key: color,
        },
        colorfulCourseTextColorMode: colorfulCourseTextColorModeCustom,
        courseNameColorValues: {
          for (final timetable in source.studentMode.timetables)
            for (final course in timetable.courses) course.name: color,
        },
        liveCourseOutlineColorValue: color,
        liveCourseOutlineFollowTheme: false,
        liveCourseOutlineCustomColorInitialized: true,
      ),
      generalMode: source.generalMode.copyWith(
        themeColorMode: colorMode,
        themeSeedColorValue: color,
        colorfulUiColorValues: {
          for (final key in [
            colorfulUiPrimaryKey,
            colorfulUiSecondaryKey,
            colorfulUiTertiaryKey,
            ...colorfulGeneralMonthTextColorKeys,
          ])
            key: color,
        },
        schedules: [
          for (final schedule in source.generalMode.schedules)
            schedule.copyWith(colorValue: color),
        ],
      ),
    );

Future<(TimetableProvider, _Storage, _RestoreGate)> _fixture({
  AppMode mode = AppMode.student,
  String colorMode = themeColorModeColorful,
}) async {
  final seed = await workspaceProvider(mode: mode);
  final storage = _Storage(_colorData(seed.appData, 0xff112233, colorMode));
  seed.dispose();
  final gate = _RestoreGate();
  final provider = await workspaceProvider(
    storage: storage,
    workspaceMutationLock: gate.run,
  );
  addTearDown(() {
    gate.release();
    provider.dispose();
  });
  return (provider, storage, gate);
}

List<String> _colorRowKeys(TimetableProvider provider, AppMode mode) => [
  for (final key in [
    colorfulUiPrimaryKey,
    colorfulUiSecondaryKey,
    colorfulUiTertiaryKey,
    if (mode == AppMode.student) colorfulCourseTextColorKey,
  ])
    'theme-ui-color-$key',
  if (mode == AppMode.student)
    for (final name in provider.courseNameColorValues.keys)
      'theme-course-color-$name',
  if (mode == AppMode.general) ...[
    for (final schedule in provider.generalSchedules)
      'theme-general-calendar-color-${schedule.id}',
    for (final key in colorfulGeneralMonthTextColorKeys)
      'theme-general-month-text-color-$key',
  ],
];

SettingsConnectedTile _colorTile(WidgetTester tester, Finder row) =>
    tester.widget<SettingsConnectedTile>(
      find.descendant(of: row, matching: find.byType(SettingsConnectedTile)),
    );

ExpressiveTap _tapIn(WidgetTester tester, Finder row) =>
    tester.widget<ExpressiveTap>(
      find.descendant(of: row, matching: find.byType(ExpressiveTap)).first,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final mode in AppMode.values) {
    for (final fails in [false, true]) {
      testWidgets(
        '$mode color editors wait for file restore and reopen after ${fails ? 'failure' : 'success'}',
        (tester) async {
          _viewport(tester);
          final (provider, storage, gate) = await _fixture(mode: mode);
          final backup = _colorData(
            provider.appData,
            0xffabcdef,
            themeColorModeColorful,
          );
          final previousPicker = FileSelectorPlatform.instance;
          FileSelectorPlatform.instance = _BackupPicker(
            encodeAppBackup(backup, []),
          );
          addTearDown(() => FileSelectorPlatform.instance = previousPicker);
          await tester.pumpWidget(
            WorkspaceHarness(provider: provider, home: const AppHomeScreen()),
          );
          await tester.pumpAndSettle();
          await _open(
            tester,
            find.byIcon(Icons.settings_outlined).hitTestable(),
          );
          final l10n = AppLocalizations.of(
            tester.element(find.byType(SettingsPage)),
          );
          final staleSeedTap = tester
              .widget<SettingsConnectedTile>(_key('settings-theme-seed'))
              .onTap!;
          await _open(tester, _key('settings-app-backup'));
          await _open(tester, find.text(l10n.restoreBackupFileTitle));
          expect(find.text(l10n.restoreBackupConfirmTitle), findsOneWidget);
          gate.blocked = true;
          final writesBeforeRestore = storage.writes;
          if (fails) storage.saveError = StateError('Expected restore failure');
          await _open(
            tester,
            find.widgetWithText(FilledButton, l10n.restoreBackupConfirmAction),
          );
          expect(provider.isRestoringAppBackup, isTrue);
          expect(_status, findsOneWidget);

          staleSeedTap();
          await _pump(tester);
          expect(_hex, findsNothing);
          await _open(tester, _key('settings-appearance-details'));
          final rowKeys = _colorRowKeys(provider, mode);
          expect(rowKeys.length, greaterThan(4));
          for (final rowKey in rowKeys) {
            final row = _key(rowKey);
            await tester.ensureVisible(row);
            await _pump(tester);
            expect(_tapIn(tester, row).onTap, isNull, reason: rowKey);
            await tester.tap(row);
            // Even invoking the supplied callback directly must not create a
            // task in the restore's new data session.
            _colorTile(tester, row).onTap!.call();
            await _pump(tester);
            expect(_hex, findsNothing, reason: rowKey);
          }
          if (mode == AppMode.student) {
            final outline = _key('theme-outline-settings-card');
            await tester.ensureVisible(outline);
            await _pump(tester);
            expect(_tapIn(tester, outline).onTap, isNull);
            await tester.tap(outline);
            await _pump(tester);
            expect(_key('theme-outline-settings-page'), findsNothing);
          }
          expect(storage.writes, writesBeforeRestore);
          expect(
            provider.colorfulUiColorValues[colorfulUiPrimaryKey],
            0xff112233,
          );

          gate.release();
          await tester.pumpAndSettle();
          expect(provider.isRestoringAppBackup, isFalse);
          expect(_status, findsNothing);
          expect(_hex, findsNothing);
          expect(
            find.text(
              fails
                  ? l10n.restoreBackupFailureMessage
                  : l10n.restoreBackupSuccessMessage,
            ),
            findsOneWidget,
          );
          final expected = fails ? 0xff112233 : 0xffabcdef;
          expect(
            provider.studentMode.colorfulUiColorValues.values,
            everyElement(expected),
          );
          expect(
            provider.generalMode.colorfulUiColorValues.values,
            everyElement(expected),
          );
          expect(provider.courseNameColorValues.values, everyElement(expected));
          expect(
            provider.generalSchedules.map((schedule) => schedule.colorValue),
            everyElement(expected),
          );
          expect(provider.liveCourseOutlineColorValue, expected);
          for (final rowKey in rowKeys) {
            expect(
              _tapIn(tester, _key(rowKey)).onTap,
              isNotNull,
              reason: rowKey,
            );
          }

          final writesAfterRestore = storage.writes;
          await _open(tester, _key('theme-ui-color-primary'));
          expect(
            tester.widget<TextField>(_hex).controller!.text,
            fails ? '#112233' : '#ABCDEF',
          );
          await tester.enterText(_hex, '#345678');
          await _pump(tester);
          await _open(
            tester,
            find.widgetWithText(FilledButton, l10n.themeApplySettings),
          );
          await tester.pumpAndSettle();
          expect(_hex, findsNothing);
          expect(
            provider.colorfulUiColorValues[colorfulUiPrimaryKey],
            0xff345678,
          );
          expect(storage.writes, writesAfterRestore + 1);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
        variant: TargetPlatformVariant({
          TargetPlatform.android,
          TargetPlatform.windows,
        }),
      );
    }
  }

  testWidgets(
    'retained seed and outline callbacks cannot open restore-time drafts',
    (tester) async {
      _viewport(tester);
      final (provider, _, gate) = await _fixture(
        colorMode: themeColorModeSingle,
      );
      await tester.pumpWidget(
        WorkspaceHarness(provider: provider, home: const ThemeSettingsPage()),
      );
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(ThemeSettingsPage)),
      );
      final custom = find.widgetWithText(
        SettingsConnectedTile,
        l10n.themeCustomColor,
      );
      final staleSeedTap = tester.widget<SettingsConnectedTile>(custom).onTap!;
      final outline = _key('theme-outline-settings-card');
      final staleOutlineTap = _tapIn(tester, outline).onTap!;
      gate.blocked = true;
      final restoring = provider.importAppDataJson(
        encodeAppBackup(
          _colorData(provider.appData, 0xffabcdef, themeColorModeSingle),
          [],
        ),
        mode: AppImportMode.replaceAll,
      );
      await _pump(tester);
      expect(provider.isRestoringAppBackup, isTrue);
      expect(_tapIn(tester, custom).onTap, isNull);
      expect(_tapIn(tester, outline).onTap, isNull);
      staleSeedTap();
      staleOutlineTap();
      await _pump(tester);
      expect(_hex, findsNothing);
      expect(_key('theme-outline-settings-page'), findsNothing);
      expect(
        find.descendant(
          of: _key('theme-seed-color-palette'),
          matching: find.byType(ExpressiveTap),
        ),
        findsNothing,
      );
      gate.release();
      await tester.pumpAndSettle();
      await restoring;
      expect(provider.studentMode.themeSeedColorValue, 0xffabcdef);
      await _open(tester, custom);
      expect(tester.widget<TextField>(_hex).controller!.text, '#ABCDEF');
      await _open(tester, find.widgetWithText(TextButton, l10n.cancel));
      await _open(tester, outline);
      expect(tester.widget<TextField>(_hex).controller!.text, '#ABCDEF');
      await _open(tester, _key('theme-outline-page-apply'));
      await tester.pumpAndSettle();
      expect(_key('theme-outline-settings-page'), findsNothing);
      expect(provider.liveCourseOutlineColorValue, 0xffabcdef);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.windows,
    }),
  );
}
