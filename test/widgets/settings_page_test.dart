import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/l10n/app_locale.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/screens/settings_page.dart';
import 'package:sked/screens/theme_settings_page.dart';
import 'package:sked/services/privacy_service.dart';
import 'package:sked/widgets/expressive_motion.dart';
import 'package:sked/widgets/text_transfer_widgets.dart';

class _MemoryTimetableStorage
    implements TimetableStorage, TimetableRecoveryArtifactReader {
  _MemoryTimetableStorage(
    this.data, {
    this.recoveryStatus = RecoveryStatus.none,
    this.recoverySources = const {},
    this.recoveryReadError,
  });

  AppData? data;
  final RecoveryStatus recoveryStatus;
  final Map<String, String> recoverySources;
  final Object? recoveryReadError;
  bool failSaves = false;
  int saveCount = 0;

  @override
  Future<StorageLoadResult> load() async => StorageLoadResult(
    data: data,
    recoveryStatus: recoveryStatus,
    recoveryArtifacts: recoverySources.keys.toList(),
  );

  @override
  Future<void> save(AppData data) async {
    saveCount += 1;
    if (failSaves) {
      throw StateError('settings save failed');
    }
    this.data = data;
  }

  @override
  Future<String?> filePath() async => 'memory://settings-test';

  @override
  Future<Uint8List?> readRecoveryArtifact(String artifactPath) async {
    final error = recoveryReadError;
    if (error != null) throw error;
    final source = recoverySources[artifactPath];
    return source == null ? null : Uint8List.fromList(utf8.encode(source));
  }
}

class _NoopPrivacyService extends PrivacyService {
  const _NoopPrivacyService();

  @override
  Future<String?> fetchCurrentPrivacyPolicyVersion() async => null;
}

AppData _buildStudentData() {
  final periodTimes = buildDefaultPeriodTimes();
  final timetable = TimetableData(
    id: 'table-1',
    config: TimetableConfig(
      name: 'Settings timetable',
      startDate: DateTime(2026, 5, 25),
      totalWeeks: 18,
      periodTimeSetId: defaultPeriodTimeSetId,
    ),
    courses: const [],
  );
  return buildInitialAppData(
    periodTimes,
    localeCode: defaultLocaleCode,
  ).copyWith(
    activeMode: AppMode.student,
    studentMode: StudentModeData(
      activeTimetableId: timetable.id,
      timetables: [timetable],
      periodTimeSets: [
        PeriodTimeSet(
          id: defaultPeriodTimeSetId,
          name: 'Default',
          periodTimes: periodTimes,
        ),
      ],
    ),
  );
}

AppData _buildGeneralData() {
  return buildInitialAppData(
    buildDefaultPeriodTimes(),
    localeCode: defaultLocaleCode,
  ).copyWith(activeMode: AppMode.general);
}

Future<TimetableProvider> _createProvider(
  AppData data, {
  RecoveryStatus recoveryStatus = RecoveryStatus.none,
  Map<String, String> recoverySources = const {},
  Object? recoveryReadError,
  _MemoryTimetableStorage? storage,
}) async {
  final provider = TimetableProvider(
    storage:
        storage ??
        _MemoryTimetableStorage(
          data,
          recoveryStatus: recoveryStatus,
          recoverySources: recoverySources,
          recoveryReadError: recoveryReadError,
        ),
    systemLocaleCodeResolver: () => defaultLocaleCode,
    privacyService: const _NoopPrivacyService(),
  );
  await provider.load();
  return provider;
}

Future<void> _pumpSettingsPage(
  WidgetTester tester,
  TimetableProvider provider, {
  Future<PackageInfo> Function()? packageInfoLoader,
}) async {
  PackageInfo.setMockInitialValues(
    appName: 'Sked',
    packageName: 'com.example.sked',
    version: '1.0.0',
    buildNumber: '1',
    buildSignature: '',
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<TimetableProvider>.value(
      value: provider,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsPage(packageInfoLoader: packageInfoLoader),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpSettingsHostPage(
  WidgetTester tester,
  TimetableProvider provider,
) async {
  PackageInfo.setMockInitialValues(
    appName: 'Sked',
    packageName: 'com.example.sked',
    version: '1.0.0',
    buildNumber: '1',
    buildSignature: '',
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<TimetableProvider>.value(
      value: provider,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () {
                    unawaited(
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              ChangeNotifierProvider<TimetableProvider>.value(
                                value: provider,
                                child: const SettingsPage(),
                              ),
                        ),
                      ),
                    );
                  },
                  child: const Text('Open settings host'),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpRouteTransition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('background package info failure is contained', (tester) async {
    final provider = await _createProvider(_buildStudentData());
    await _pumpSettingsPage(
      tester,
      provider,
      packageInfoLoader: () async => throw StateError('package info failed'),
    );

    expect(find.byType(SettingsPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('background stale-version cleanup failure is contained', (
    tester,
  ) async {
    final data = _buildStudentData().copyWith(availableUpdateVersion: '0.9.0');
    final storage = _MemoryTimetableStorage(data)..failSaves = true;
    final provider = await _createProvider(data, storage: storage);

    await _pumpSettingsPage(tester, provider);

    expect(storage.saveCount, 1);
    expect(provider.availableUpdateVersion, '0.9.0');
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('student settings page groups entries into sections', (
    tester,
  ) async {
    final provider = await _createProvider(_buildStudentData());
    await _pumpSettingsPage(tester, provider);

    expect(find.text('Timetable'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('General schedule'), findsNothing);
    expect(find.text('Period time set'), findsOneWidget);
    expect(find.text('Timetable display and interaction'), findsOneWidget);
    expect(find.text('Import and export data'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('App'), 120);
    expect(find.text('App'), findsOneWidget);
  });

  testWidgets('period time set selection rolls back after save failure', (
    tester,
  ) async {
    final initial = _buildStudentData();
    final alternative = PeriodTimeSet(
      id: 'alternative-period-set',
      name: 'Alternative',
      periodTimes: buildDefaultPeriodTimes(),
    );
    final data = initial.copyWith(
      studentMode: initial.studentMode.copyWith(
        periodTimeSets: [...initial.studentMode.periodTimeSets, alternative],
      ),
    );
    final storage = _MemoryTimetableStorage(data)..failSaves = true;
    final provider = await _createProvider(data, storage: storage);
    await _pumpSettingsPage(tester, provider);

    await tester.tap(find.text('Period time set'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alternative'));
    await tester.pumpAndSettle();

    expect(storage.saveCount, 1);
    expect(
      provider.activeTimetable.config.periodTimeSetId,
      defaultPeriodTimeSetId,
    );
    expect(find.textContaining('Default'), findsOneWidget);
    expect(find.text('Save failed. Please try again later.'), findsOneWidget);
    expect(find.byType(SettingsPage), findsOneWidget);

    storage.failSaves = false;
    await tester.tap(find.text('Period time set'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alternative'));
    await tester.pumpAndSettle();

    expect(storage.saveCount, 2);
    expect(provider.activeTimetable.config.periodTimeSetId, alternative.id);
    expect(find.textContaining('Alternative'), findsOneWidget);
  });

  testWidgets('general settings page groups entries into sections', (
    tester,
  ) async {
    final provider = await _createProvider(_buildGeneralData());
    await _pumpSettingsPage(tester, provider);

    expect(find.text('General schedule'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Timetable'), findsNothing);
    expect(find.text('General display settings'), findsOneWidget);
    expect(find.text('Schedule import & export'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('App'), 120);
    expect(find.text('App'), findsOneWidget);
  });

  testWidgets('app backup entry opens restore and export actions', (
    tester,
  ) async {
    final provider = await _createProvider(_buildGeneralData());
    await _pumpSettingsPage(tester, provider);

    await tester.scrollUntilVisible(find.text('App backup and restore'), 120);
    await tester.tap(find.text('App backup and restore'));
    await tester.pumpAndSettle();

    expect(find.text('Restore from JSON file'), findsOneWidget);
    expect(find.text('Paste backup JSON'), findsOneWidget);
    expect(find.text('Share backup file'), findsOneWidget);
    expect(find.text('Save backup file'), findsOneWidget);
    expect(find.text('Copy backup text'), findsOneWidget);
    expect(
      find.textContaining('are not written to backup files'),
      findsOneWidget,
    );
  });

  testWidgets('app backup sheet exposes historical recovery artifacts', (
    tester,
  ) async {
    const artifact = 'memory://recovery/historical-journal.json';
    final provider = await _createProvider(
      _buildGeneralData(),
      recoverySources: const {artifact: '{broken-journal'},
    );
    expect(provider.recoveryArtifacts, [artifact]);
    await _pumpSettingsPage(tester, provider);

    await tester.scrollUntilVisible(find.text('App backup and restore'), 120);
    await tester.tap(find.text('App backup and restore'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -400));
    await tester.pumpAndSettle();

    final recoveryEntry = find.text('Show recovery files and locations');
    expect(recoveryEntry, findsOneWidget);
    await tester.tap(recoveryEntry);
    await tester.pumpAndSettle();

    expect(find.text(artifact), findsOneWidget);
    expect(find.byIcon(Icons.download_outlined), findsOneWidget);
  });

  testWidgets('app backup sheet keeps paths when artifact reads fail', (
    tester,
  ) async {
    const artifact = 'memory://recovery/unreadable-journal.json';
    final provider = await _createProvider(
      _buildGeneralData(),
      recoverySources: const {artifact: '{unreadable'},
      recoveryReadError: StateError('recovery storage unavailable'),
    );
    await _pumpSettingsPage(tester, provider);

    await tester.scrollUntilVisible(find.text('App backup and restore'), 120);
    await tester.tap(find.text('App backup and restore'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -400));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Show recovery files and locations'));
    await tester.pumpAndSettle();

    expect(find.text(artifact), findsOneWidget);
    expect(find.byIcon(Icons.download_outlined), findsNothing);
  });

  testWidgets('zero-timetable settings keep recovery and app backup access', (
    tester,
  ) async {
    final provider = await _createProvider(
      buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: defaultLocaleCode,
      ),
      recoveryStatus: RecoveryStatus.restoredFromBackup,
    );
    await _pumpSettingsPage(tester, provider);

    expect(
      find.text('No timetable is currently available for settings.'),
      findsOneWidget,
    );
    expect(find.text('Period time set'), findsNothing);
    expect(find.textContaining('previous backup'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('App backup and restore'), 120);
    expect(find.text('App backup and restore'), findsOneWidget);
  });

  testWidgets('theme settings entry ignores rapid duplicate taps', (
    tester,
  ) async {
    final provider = await _createProvider(_buildStudentData());
    await _pumpSettingsPage(tester, provider);

    final themeTile = find.text('Theme');
    expect(themeTile, findsOneWidget);

    await tester.tap(themeTile);
    await tester.tap(themeTile, warnIfMissed: false);
    await _pumpRouteTransition(tester);

    expect(find.byType(ThemeSettingsPage, skipOffstage: false), findsOneWidget);
  });

  testWidgets('student import/export actions ignore rapid duplicate taps', (
    tester,
  ) async {
    final provider = await _createProvider(_buildStudentData());
    await _pumpSettingsPage(tester, provider);

    final importExportTile = find.text('Import and export data');
    expect(importExportTile, findsOneWidget);

    await tester.tap(importExportTile);
    await tester.tap(importExportTile, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Import timetable'), findsOneWidget);
  });

  testWidgets('student data sheet action ignores rapid duplicate taps', (
    tester,
  ) async {
    final provider = await _createProvider(_buildStudentData());
    await _pumpSettingsHostPage(tester, provider);

    await tester.tap(find.text('Open settings host'));
    await _pumpRouteTransition(tester);

    final importExportTile = find.text('Import and export data');
    expect(importExportTile, findsOneWidget);

    await tester.tap(importExportTile);
    await tester.pumpAndSettle();

    final importTextAction = find.text('Import timetable from JSON text');
    expect(importTextAction, findsOneWidget);

    await tester.tap(importTextAction);
    await tester.tap(importTextAction, warnIfMissed: false);
    await _pumpRouteTransition(tester);

    expect(find.byType(TextImportPage), findsOneWidget);
    expect(find.byType(TextImportPage, skipOffstage: false), findsOneWidget);
    expect(find.text('Open settings host'), findsNothing);
    expect(
      find.text('Open settings host', skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('general import/export actions ignore rapid duplicate taps', (
    tester,
  ) async {
    final provider = await _createProvider(_buildGeneralData());
    await _pumpSettingsPage(tester, provider);

    final importExportTile = find.text('Schedule import & export');
    expect(importExportTile, findsOneWidget);

    await tester.tap(importExportTile);
    await tester.tap(importExportTile, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Import JSON file'), findsOneWidget);
  });

  testWidgets('general data action chevrons are vertically centered', (
    tester,
  ) async {
    final provider = await _createProvider(_buildGeneralData());
    await _pumpSettingsPage(tester, provider);

    await tester.tap(find.text('Schedule import & export'));
    await tester.pumpAndSettle();

    final actionTitles = [
      'Import JSON file',
      'Paste JSON',
      'Import ICS file',
      'Paste ICS',
    ];
    for (final title in actionTitles) {
      final titleFinder = find.text(title);
      expect(titleFinder, findsOneWidget);

      final tileBox = tester.renderObject<RenderBox>(
        find.ancestor(of: titleFinder, matching: find.byType(ExpressiveTap)),
      );
      final chevronFinder = find.descendant(
        of: find.ancestor(
          of: titleFinder,
          matching: find.byType(ExpressiveTap),
        ),
        matching: find.byIcon(Icons.chevron_right),
      );
      final chevronBox = tester.renderObject<RenderBox>(chevronFinder);
      final tileCenterY = tileBox
          .localToGlobal(tileBox.size.center(Offset.zero))
          .dy;
      final chevronCenterY = chevronBox
          .localToGlobal(chevronBox.size.center(Offset.zero))
          .dy;

      expect((chevronCenterY - tileCenterY).abs(), lessThanOrEqualTo(1.0));
    }
  });

  testWidgets('general data sheet action ignores rapid duplicate taps', (
    tester,
  ) async {
    final provider = await _createProvider(_buildGeneralData());
    await _pumpSettingsHostPage(tester, provider);

    await tester.tap(find.text('Open settings host'));
    await _pumpRouteTransition(tester);

    final importExportTile = find.text('Schedule import & export');
    expect(importExportTile, findsOneWidget);

    await tester.tap(importExportTile);
    await tester.pumpAndSettle();

    final pasteJsonAction = find.text('Paste JSON');
    expect(pasteJsonAction, findsOneWidget);

    await tester.tap(pasteJsonAction);
    await tester.tap(pasteJsonAction, warnIfMissed: false);
    await _pumpRouteTransition(tester);

    expect(find.byType(TextImportPage), findsOneWidget);
    expect(find.byType(TextImportPage, skipOffstage: false), findsOneWidget);
    expect(find.text('Open settings host'), findsNothing);
    expect(
      find.text('Open settings host', skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('JSON import storage failure is reported without losing text', (
    tester,
  ) async {
    final storage = _MemoryTimetableStorage(_buildGeneralData());
    final provider = await _createProvider(
      _buildGeneralData(),
      storage: storage,
    );
    addTearDown(provider.dispose);
    final source = provider.exportActiveGeneralScheduleJson();
    storage.failSaves = true;
    await _pumpSettingsPage(tester, provider);

    await tester.tap(find.text('Schedule import & export'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paste JSON'));
    await _pumpRouteTransition(tester);
    await tester.enterText(find.byType(TextField), source);
    await tester.tap(find.widgetWithText(FilledButton, 'Import'));
    await _pumpRouteTransition(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await _pumpRouteTransition(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Add as new'));
    await _pumpRouteTransition(tester);

    expect(find.byType(TextImportPage), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      source,
    );
    expect(find.text('Save failed. Please try again later.'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Import'))
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('ICS import storage failure is reported without losing text', (
    tester,
  ) async {
    final storage = _MemoryTimetableStorage(_buildGeneralData());
    final provider = await _createProvider(
      _buildGeneralData(),
      storage: storage,
    );
    addTearDown(provider.dispose);
    const source =
        'BEGIN:VCALENDAR\r\n'
        'VERSION:2.0\r\n'
        'PRODID:-//Sked//Test//EN\r\n'
        'BEGIN:VEVENT\r\n'
        'UID:settings-import-test@sked.local\r\n'
        'DTSTAMP:20260616T000000Z\r\n'
        'DTSTART:20260616T090000\r\n'
        'DTEND:20260616T100000\r\n'
        'SUMMARY:Imported event\r\n'
        'END:VEVENT\r\n'
        'END:VCALENDAR';
    storage.failSaves = true;
    await _pumpSettingsPage(tester, provider);

    await tester.tap(find.text('Schedule import & export'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paste ICS'));
    await _pumpRouteTransition(tester);
    await tester.enterText(find.byType(TextField), source);
    await tester.tap(find.widgetWithText(FilledButton, 'Import'));
    await _pumpRouteTransition(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Add as new'));
    await _pumpRouteTransition(tester);

    expect(find.byType(TextImportPage), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      source,
    );
    expect(find.text('Save failed. Please try again later.'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Import'))
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });
}
