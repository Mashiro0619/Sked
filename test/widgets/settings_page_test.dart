import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/l10n/app_locale.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/screens/settings_page.dart';
import 'package:sked/screens/theme_settings_page.dart';
import 'package:sked/services/privacy_service.dart';
import 'package:sked/widgets/expressive_motion.dart';
import 'package:sked/widgets/settings_list.dart';
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
  Locale locale = const Locale('en'),
  TextScaler textScaler = TextScaler.noScaling,
  EdgeInsets viewPadding = EdgeInsets.zero,
  EdgeInsets viewInsets = EdgeInsets.zero,
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
        locale: locale,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: textScaler,
              padding: viewPadding,
              viewPadding: viewPadding,
              viewInsets: viewInsets,
            ),
            child: SettingsPage(packageInfoLoader: packageInfoLoader),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _setTestViewport(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
}

void _resetTestViewport(WidgetTester tester) {
  tester.view.resetPhysicalSize();
  tester.view.resetDevicePixelRatio();
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
        localizationsDelegates: appLocalizationsDelegates,
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

const _settingsGroupKeys = <String>[
  'settings-group-workspace',
  'settings-group-timetable',
  'settings-group-general-schedule',
  'settings-group-appearance-language',
  'settings-group-data-security',
  'settings-group-about',
];

void _expectAllSettingsGroups() {
  for (final key in _settingsGroupKeys) {
    expect(find.byKey(ValueKey(key)), findsOneWidget);
  }
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

  testWidgets('student settings page shows all six settings groups', (
    tester,
  ) async {
    final provider = await _createProvider(_buildStudentData());
    await _pumpSettingsPage(tester, provider);

    _expectAllSettingsGroups();
    expect(find.text('Workspace'), findsOneWidget);
    expect(find.text('Timetable'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('settings-group-general-schedule')),
        matching: find.text('General schedule'),
      ),
      findsOneWidget,
    );
    expect(find.text('Appearance & language'), findsOneWidget);
    expect(find.text('Data & security'), findsOneWidget);
    expect(find.text('About Sked'), findsOneWidget);
    expect(find.text('Period time set'), findsOneWidget);
    expect(find.text('Timetable display and interaction'), findsOneWidget);
    expect(
      find.text('Course display, layout, week gestures, and quick add'),
      findsOneWidget,
    );
    expect(find.text('Import and export data'), findsOneWidget);
    expect(find.text('General display settings'), findsOneWidget);
    expect(
      find.text('Views, toolbar, date format, and quick add'),
      findsOneWidget,
    );
    expect(find.text('Schedule import & export'), findsOneWidget);

    final groupTops = _settingsGroupKeys
        .map((key) => tester.getTopLeft(find.byKey(ValueKey(key))).dy)
        .toList();
    for (var index = 1; index < groupTops.length; index++) {
      expect(groupTops[index], greaterThan(groupTops[index - 1]));
    }

    await tester.scrollUntilVisible(find.text('About Sked'), 120);
    expect(find.text('About Sked'), findsOneWidget);
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

  testWidgets('general settings page shows all six settings groups', (
    tester,
  ) async {
    final provider = await _createProvider(_buildGeneralData());
    await _pumpSettingsPage(tester, provider);

    _expectAllSettingsGroups();
    expect(find.text('Workspace'), findsOneWidget);
    expect(find.text('Timetable'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('settings-group-general-schedule')),
        matching: find.text('General schedule'),
      ),
      findsOneWidget,
    );
    expect(find.text('Appearance & language'), findsOneWidget);
    expect(find.text('Data & security'), findsOneWidget);
    expect(find.text('About Sked'), findsOneWidget);
    expect(find.text('Period time set'), findsOneWidget);
    expect(find.text('Timetable display and interaction'), findsOneWidget);
    expect(find.text('Import and export data'), findsOneWidget);
    expect(find.text('General display settings'), findsOneWidget);
    expect(find.text('Schedule import & export'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('About Sked'), 120);
    expect(find.text('About Sked'), findsOneWidget);
  });

  testWidgets('Chinese settings summaries describe the current controls', (
    tester,
  ) async {
    final provider = await _createProvider(_buildStudentData());
    await _pumpSettingsPage(tester, provider, locale: const Locale('zh'));

    expect(find.text('课程显示、横向布局、切周手势和快捷添加'), findsOneWidget);
    expect(find.text('视图、工具栏、日期格式和快捷添加'), findsOneWidget);
    expect(find.text('课程弹窗、空白时间、灰色课程与网格线'), findsNothing);
    expect(find.text('通用日程页面的显示开关'), findsNothing);
  });

  testWidgets(
    'workspace selector saves once and keeps all groups and scroll state',
    (tester) async {
      final data = _buildStudentData();
      final storage = _MemoryTimetableStorage(data);
      final provider = await _createProvider(data, storage: storage);
      await _pumpSettingsPage(tester, provider);

      await tester.tap(find.byKey(const ValueKey('settings-workspace-mode')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MenuItemButton, 'General schedule'));
      await tester.pumpAndSettle();

      expect(provider.activeMode, AppMode.general);
      expect(storage.saveCount, 1);
      expect(find.byType(SettingsPage), findsOneWidget);
      _expectAllSettingsGroups();
      expect(find.text('General display settings'), findsOneWidget);
      expect(find.text('Timetable display and interaction'), findsOneWidget);

      final listFinder = find.byType(ListView).first;
      await tester.drag(listFinder, const Offset(0, -320));
      await tester.pumpAndSettle();
      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      final offsetBeforeSwitch = scrollable.position.pixels;
      expect(offsetBeforeSwitch, greaterThan(0));

      await provider.switchMode(AppMode.student);
      await tester.pumpAndSettle();

      expect(provider.activeMode, AppMode.student);
      expect(storage.saveCount, 2);
      _expectAllSettingsGroups();
      expect(scrollable.position.pixels, closeTo(offsetBeforeSwitch, 0.01));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('home workspace navigation setting rolls back and can retry', (
    tester,
  ) async {
    final data = _buildStudentData();
    final storage = _MemoryTimetableStorage(data)..failSaves = true;
    final provider = await _createProvider(data, storage: storage);
    await _pumpSettingsPage(tester, provider);

    await tester.tap(find.text('Hide workspace navigation'));
    await tester.pumpAndSettle();
    expect(provider.hideHomeWorkspaceNavigation, isFalse);
    expect(find.text('Save failed. Please try again later.'), findsOneWidget);

    storage.failSaves = false;
    await tester.tap(find.text('Hide workspace navigation'));
    await tester.pumpAndSettle();
    expect(provider.hideHomeWorkspaceNavigation, isTrue);
    expect(storage.data?.hideHomeWorkspaceNavigation, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings page keeps compact rows reachable at 2x text scale', (
    tester,
  ) async {
    _setTestViewport(tester, const Size(320, 568));
    addTearDown(() => _resetTestViewport(tester));

    final provider = await _createProvider(_buildStudentData());
    await _pumpSettingsPage(
      tester,
      provider,
      textScaler: const TextScaler.linear(2),
      viewPadding: const EdgeInsets.only(bottom: 24),
      viewInsets: const EdgeInsets.only(bottom: 180),
    );

    expect(
      find.byKey(const ValueKey('settings-groups-single-column')),
      findsOneWidget,
    );
    final list = tester.widget<ListView>(find.byType(ListView).first);
    final listPadding = list.padding! as EdgeInsets;
    expect(listPadding.bottom, greaterThanOrEqualTo(208));
    expect(
      tester.getSize(find.byType(SettingsConnectedTile).first).height,
      greaterThanOrEqualTo(48),
    );

    await tester.scrollUntilVisible(find.text('About Sked'), 400);
    expect(find.text('About Sked'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings groups stay single-column across compact widths', (
    tester,
  ) async {
    addTearDown(() => _resetTestViewport(tester));
    final provider = await _createProvider(_buildGeneralData());

    for (final scenario in const [
      (Size(390, 844), Locale('de'), TextScaler.linear(1.3)),
      (Size(600, 900), Locale('en'), TextScaler.linear(1.8)),
    ]) {
      _setTestViewport(tester, scenario.$1);
      await _pumpSettingsPage(
        tester,
        provider,
        locale: scenario.$2,
        textScaler: scenario.$3,
      );

      _expectAllSettingsGroups();
      expect(
        find.byKey(const ValueKey('settings-groups-single-column')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'settings page uses two columns only when text comfortably fits',
    (tester) async {
      _setTestViewport(tester, const Size(1024, 768));
      addTearDown(() => _resetTestViewport(tester));

      final provider = await _createProvider(_buildStudentData());
      await _pumpSettingsPage(tester, provider);
      expect(
        find.byKey(const ValueKey('settings-groups-two-column')),
        findsOneWidget,
      );

      final workspaceRect = tester.getRect(
        find.byKey(const ValueKey('settings-group-workspace')),
      );
      final timetableRect = tester.getRect(
        find.byKey(const ValueKey('settings-group-timetable')),
      );
      final generalRect = tester.getRect(
        find.byKey(const ValueKey('settings-group-general-schedule')),
      );
      final appearanceRect = tester.getRect(
        find.byKey(const ValueKey('settings-group-appearance-language')),
      );
      final dataRect = tester.getRect(
        find.byKey(const ValueKey('settings-group-data-security')),
      );
      final aboutRect = tester.getRect(
        find.byKey(const ValueKey('settings-group-about')),
      );
      expect(timetableRect.left, closeTo(workspaceRect.left, 0.01));
      expect(generalRect.left, closeTo(workspaceRect.left, 0.01));
      expect(appearanceRect.left, greaterThan(workspaceRect.right));
      expect(dataRect.left, closeTo(appearanceRect.left, 0.01));
      expect(aboutRect.left, closeTo(appearanceRect.left, 0.01));
      expect(timetableRect.top, greaterThan(workspaceRect.top));
      expect(generalRect.top, greaterThan(timetableRect.top));
      expect(dataRect.top, greaterThan(appearanceRect.top));
      expect(aboutRect.top, greaterThan(dataRect.top));

      await _pumpSettingsPage(
        tester,
        provider,
        textScaler: const TextScaler.linear(2),
      );
      expect(
        find.byKey(const ValueKey('settings-groups-single-column')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('settings page switches columns at the real 840dp boundary', (
    tester,
  ) async {
    _setTestViewport(tester, const Size(839, 768));
    addTearDown(() => _resetTestViewport(tester));
    final provider = await _createProvider(_buildStudentData());

    await _pumpSettingsPage(tester, provider);
    expect(
      find.byKey(const ValueKey('settings-groups-single-column')),
      findsOneWidget,
    );

    _setTestViewport(tester, const Size(840, 768));
    await _pumpSettingsPage(tester, provider);
    expect(
      find.byKey(const ValueKey('settings-groups-two-column')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings navigation chevrons point forward', (tester) async {
    _setTestViewport(tester, const Size(430, 776));
    addTearDown(() => _resetTestViewport(tester));
    final provider = await _createProvider(_buildStudentData());
    await _pumpSettingsPage(tester, provider, locale: const Locale('en'));

    final navigationTile = find.ancestor(
      of: find.text('Import from school webpage'),
      matching: find.byType(SettingsConnectedTile),
    );
    final chevron = find.descendant(
      of: navigationTile,
      matching: find.byIcon(Icons.chevron_right),
    );
    final title = find
        .descendant(of: navigationTile, matching: find.byType(Text))
        .first;
    expect(tester.widget<Icon>(chevron).icon?.matchTextDirection, isTrue);
    expect(
      tester.getRect(chevron).center.dx,
      greaterThan(tester.getRect(title).center.dx),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('app backup entry opens restore and export actions', (
    tester,
  ) async {
    final provider = await _createProvider(_buildGeneralData());
    await _pumpSettingsPage(tester, provider);

    final backupEntry = find.text('App backup and restore');
    await tester.ensureVisible(backupEntry);
    await tester.pumpAndSettle();
    await tester.tap(backupEntry);
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

    final backupEntry = find.text('App backup and restore');
    await tester.ensureVisible(backupEntry);
    await tester.pumpAndSettle();
    await tester.tap(backupEntry);
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

    final backupEntry = find.text('App backup and restore');
    await tester.ensureVisible(backupEntry);
    await tester.pumpAndSettle();
    await tester.tap(backupEntry);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -400));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Show recovery files and locations'));
    await tester.pumpAndSettle();

    expect(find.text(artifact), findsOneWidget);
    expect(find.byIcon(Icons.download_outlined), findsNothing);
  });

  testWidgets(
    'zero-timetable settings disable period selection but keep all groups',
    (tester) async {
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
      _expectAllSettingsGroups();
      expect(find.text('Period time set'), findsOneWidget);
      final periodTileFinder = find.byKey(
        const ValueKey('settings-period-time-sets'),
      );
      final periodTile = tester.widget<SettingsConnectedTile>(periodTileFinder);
      expect(periodTile.onTap, isNull);
      expect(
        tester.getSemantics(periodTileFinder),
        matchesSemantics(
          label:
              'Period time set, '
              'No timetable is currently available for settings.',
          hasEnabledState: true,
          isEnabled: false,
        ),
      );

      await tester.tap(periodTileFinder, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.textContaining('previous backup'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('App backup and restore'), 120);
      expect(find.text('App backup and restore'), findsOneWidget);
    },
  );

  testWidgets('theme settings entry ignores rapid duplicate taps', (
    tester,
  ) async {
    final provider = await _createProvider(_buildStudentData());
    await _pumpSettingsPage(tester, provider);

    final themeTile = find.text('Theme');
    expect(themeTile, findsOneWidget);

    await tester.ensureVisible(themeTile);
    await tester.pumpAndSettle();
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

    await tester.ensureVisible(importExportTile);
    await tester.pumpAndSettle();
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

    final importExportTile = find.text('Schedule import & export');
    await tester.ensureVisible(importExportTile);
    await tester.pumpAndSettle();
    await tester.tap(importExportTile);
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

    await tester.ensureVisible(importExportTile);
    await tester.pumpAndSettle();
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

    final importExportTile = find.text('Schedule import & export');
    await tester.ensureVisible(importExportTile);
    await tester.pumpAndSettle();
    await tester.tap(importExportTile);
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

    final importExportTile = find.text('Schedule import & export');
    await tester.ensureVisible(importExportTile);
    await tester.pumpAndSettle();
    await tester.tap(importExportTile);
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
