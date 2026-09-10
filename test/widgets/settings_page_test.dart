import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
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
import 'package:sked/services/app_data_clear_coordinator.dart';
import 'package:sked/services/school_site_service.dart';
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
  Completer<void>? _pendingSave;

  void blockNextSave() {
    _pendingSave = Completer<void>();
  }

  void completePendingSave() {
    final pending = _pendingSave;
    _pendingSave = null;
    if (pending != null && !pending.isCompleted) pending.complete();
  }

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
    final pending = _pendingSave;
    if (pending != null) await pending.future;
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

class _FakeDataClearCoordinator extends AppDataClearCoordinator {
  var calls = 0;
  Object? failure;

  @override
  Future<void> clearAndExit(TimetableProvider provider) async {
    calls += 1;
    final error = failure;
    if (error != null) throw error;
  }
}

class _CommittedDataClearCoordinator extends AppDataClearCoordinator {
  @override
  Future<void> clearAndExit(TimetableProvider provider) {
    return provider.runExclusiveDataClear(
      clear: () async {},
      exit: () async => throw StateError('exit failed'),
    );
  }
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

GeneralSchedule _generalSchedule({
  required String id,
  required String name,
  bool isVisible = true,
  int sortOrder = 0,
  List<GeneralEvent> events = const [],
}) {
  return GeneralSchedule(
    id: id,
    name: name,
    isVisible: isVisible,
    sortOrder: sortOrder,
    events: events,
  );
}

AppData _buildGeneralDataWithSchedules(
  List<GeneralSchedule> schedules, {
  required String activeScheduleId,
}) {
  final data = _buildGeneralData();
  return data.copyWith(
    generalMode: data.generalMode.copyWith(
      activeScheduleId: activeScheduleId,
      schedules: schedules,
    ),
  );
}

String _buildGeneralImportSource() {
  const sourceId = 'import-source';
  return encodeGeneralScheduleDataEnvelope(
    GeneralScheduleExportData(
      schedules: [
        _generalSchedule(
          id: sourceId,
          name: 'Imported category',
          events: [
            GeneralEvent(
              id: 'imported-event',
              calendarId: sourceId,
              title: 'Imported event',
              startDateTimeIso: '2026-08-15T09:00:00.000',
              endDateTimeIso: '2026-08-15T10:00:00.000',
            ),
          ],
        ),
      ],
    ),
  );
}

Future<TimetableProvider> _createProvider(
  AppData data, {
  RecoveryStatus recoveryStatus = RecoveryStatus.none,
  Map<String, String> recoverySources = const {},
  Object? recoveryReadError,
  _MemoryTimetableStorage? storage,
  SchoolSiteService? schoolSiteService,
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
    schoolSiteService: schoolSiteService,
  );
  await provider.load();
  return provider;
}

Future<void> _pumpSettingsPage(
  WidgetTester tester,
  TimetableProvider provider, {
  Future<PackageInfo> Function()? packageInfoLoader,
  AppDataClearCoordinator? dataClearCoordinator,
  SettingsUrlLauncher? urlLauncher,
  SettingsDestination? destination,
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
            child: SettingsPage(
              packageInfoLoader: packageInfoLoader,
              dataClearCoordinator: dataClearCoordinator,
              urlLauncher: urlLauncher,
              initialDestination: destination,
            ),
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
                                child: SettingsPage(
                                  initialDestination: provider.isStudentMode
                                      ? SettingsDestination.student
                                      : SettingsDestination.general,
                                ),
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

Future<void> _openGeneralDataActions(
  WidgetTester tester,
  TimetableProvider provider,
) async {
  await _pumpSettingsPage(
    tester,
    provider,
    destination: SettingsDestination.general,
  );
  expect(find.text('Import JSON file'), findsOneWidget);
  expect(find.byType(BottomSheet), findsNothing);
}

Finder _generalSelectionTile(String name) {
  return find.ancestor(
    of: find.text(name),
    matching: find.byType(ExpressiveTap),
  );
}

void main() {
  testWidgets('clear data requires confirmation and runs once', (tester) async {
    final provider = await _createProvider(_buildStudentData());
    final coordinator = _FakeDataClearCoordinator();
    await _pumpSettingsPage(
      tester,
      provider,
      destination: SettingsDestination.data,
      dataClearCoordinator: coordinator,
    );

    final tile = find.byKey(const ValueKey('settings-clear-app-data'));
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.text('Clear all Sked data?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(coordinator.calls, 0);

    await tester.tap(tile);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear data and exit'));
    await tester.pumpAndSettle();
    expect(coordinator.calls, 1);
  });

  testWidgets('clear data failure keeps settings open for retry', (
    tester,
  ) async {
    final provider = await _createProvider(_buildStudentData());
    final coordinator = _FakeDataClearCoordinator()
      ..failure = StateError('clear failed');
    await _pumpSettingsPage(
      tester,
      provider,
      destination: SettingsDestination.data,
      dataClearCoordinator: coordinator,
    );
    final tile = find.byKey(const ValueKey('settings-clear-app-data'));
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear data and exit'));
    await tester.pumpAndSettle();
    expect(coordinator.calls, 1);
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(
      find.textContaining('Unable to clear all local data'),
      findsOneWidget,
    );
  });

  testWidgets('a completed clear stays blocked when exit fails', (
    tester,
  ) async {
    final provider = await _createProvider(
      _buildStudentData(),
      schoolSiteService: SchoolSiteService(
        coordinator: SchoolSiteStorageCoordinator(),
      ),
    );
    await _pumpSettingsPage(
      tester,
      provider,
      destination: SettingsDestination.data,
      dataClearCoordinator: _CommittedDataClearCoordinator(),
    );
    final tile = find.byKey(const ValueKey('settings-clear-app-data'));
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear data and exit'));
    await tester.pump(const Duration(seconds: 1));

    expect(provider.isDataClearCommitted, isTrue);
    expect(find.textContaining('Your local data was cleared'), findsOneWidget);
    expect(find.byType(AbsorbPointer), findsWidgets);

    // Remove the indeterminate progress indicator before the test binding
    // verifies that no frame callbacks remain.
    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
  });

  testWidgets('clear data confirmation stays reachable on a scaled phone', (
    tester,
  ) async {
    _setTestViewport(tester, const Size(320, 568));
    addTearDown(() => _resetTestViewport(tester));
    final provider = await _createProvider(_buildStudentData());
    await _pumpSettingsPage(
      tester,
      provider,
      destination: SettingsDestination.data,
      textScaler: const TextScaler.linear(2),
    );

    final tile = find.byKey(const ValueKey('settings-clear-app-data'));
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();

    final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
    expect(dialog.scrollable, isTrue);
    expect(find.text('Clear data and exit').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('clear data is not offered on iOS', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final provider = await _createProvider(_buildStudentData());

      await _pumpSettingsPage(
        tester,
        provider,
        destination: SettingsDestination.data,
      );

      expect(
        find.byKey(const ValueKey('settings-clear-app-data')),
        findsNothing,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Google Play falls back from the Android market URI', (
    tester,
  ) async {
    final provider = await _createProvider(_buildStudentData());
    final urls = <Uri>[];
    await _pumpSettingsPage(
      tester,
      provider,
      destination: SettingsDestination.about,
      urlLauncher: (uri, _) async {
        urls.add(uri);
        return urls.length > 1;
      },
    );
    final entry = find.text('Google Play');
    await tester.ensureVisible(entry);
    await tester.pumpAndSettle();
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(urls, hasLength(2));
    expect(urls.first.scheme, 'market');
    expect(urls.last.toString(), contains('play.google.com/store/apps'));
  });

  testWidgets(
    'GitHub repository launcher failures are contained and reported',
    (tester) async {
      final provider = await _createProvider(_buildStudentData());
      Uri? launchedUri;
      await _pumpSettingsPage(
        tester,
        provider,
        destination: SettingsDestination.about,
        urlLauncher: (uri, _) async {
          launchedUri = uri;
          throw StateError('launcher unavailable');
        },
      );
      final entry = find.text('GitHub repository');
      await tester.ensureVisible(entry);
      await tester.pumpAndSettle();
      expect(find.text('Star Sked on GitHub!'), findsOneWidget);
      await tester.tap(entry);
      await tester.pumpAndSettle();

      expect(launchedUri, Uri.parse('https://github.com/Mashiro0619/Sked'));
      expect(
        find.text('Unable to open the GitHub repository link'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('background package info failure is contained', (tester) async {
    final provider = await _createProvider(_buildStudentData());
    await _pumpSettingsPage(
      tester,
      provider,
      destination: SettingsDestination.about,
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

    await _pumpSettingsPage(
      tester,
      provider,
      destination: SettingsDestination.about,
    );

    expect(storage.saveCount, 1);
    expect(provider.availableUpdateVersion, '0.9.0');
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'settings root has six categories rather than workspace controls',
    (tester) async {
      final p = await _createProvider(_buildStudentData());
      await _pumpSettingsPage(tester, p);
      for (final key in [
        'appearance',
        'notifications',
        'language',
        'data',
        'features',
        'about',
      ]) {
        expect(find.byKey(ValueKey('settings-category-$key')), findsOneWidget);
      }
      expect(find.text('Timetable display and interaction'), findsNothing);
      expect(find.text('Category import & export'), findsNothing);
    },
  );

  testWidgets('period manager assignment rolls back after save failure', (
    tester,
  ) async {
    final base = _buildStudentData();
    final other = PeriodTimeSet(
      id: 'alternative-period-set',
      name: 'Alternative',
      periodTimes: buildDefaultPeriodTimes(),
    );
    final data = base.copyWith(
      studentMode: base.studentMode.copyWith(
        periodTimeSets: [...base.studentMode.periodTimeSets, other],
      ),
    );
    final storage = _MemoryTimetableStorage(data)..failSaves = true;
    final p = await _createProvider(data, storage: storage);
    await _pumpSettingsPage(
      tester,
      p,
      destination: SettingsDestination.periods,
    );
    final select = find.byTooltip('Choose period time set').last;
    await tester.tap(select);
    await tester.pumpAndSettle();
    expect(storage.saveCount, 1);
    expect(p.activeTimetable.config.periodTimeSetId, defaultPeriodTimeSetId);
    storage.failSaves = false;
    await tester.tap(select);
    await tester.pumpAndSettle();
    expect(p.activeTimetable.config.periodTimeSetId, other.id);
    expect(tester.takeException(), isNull);
  });

  testWidgets('global categories do not depend on the current workspace', (
    tester,
  ) async {
    final p = await _createProvider(_buildGeneralData());
    await _pumpSettingsPage(tester, p);
    for (final key in [
      'appearance',
      'notifications',
      'language',
      'data',
      'features',
      'about',
    ]) {
      expect(find.byKey(ValueKey('settings-category-$key')), findsOneWidget);
    }
    await p.switchMode(AppMode.student);
    await tester.pumpAndSettle();
    for (final key in [
      'appearance',
      'notifications',
      'language',
      'data',
      'features',
      'about',
    ]) {
      expect(find.byKey(ValueKey('settings-category-$key')), findsOneWidget);
    }
  });

  testWidgets('appearance opens the current theme without changing workspace', (
    tester,
  ) async {
    final p = await _createProvider(_buildGeneralData());
    await _pumpSettingsPage(tester, p);
    await tester.tap(
      find.byKey(const ValueKey('settings-category-appearance')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ThemeSettingsPage), findsOneWidget);
    expect(p.activeMode, AppMode.general);
  });

  testWidgets(
    'Chinese transfer task shows import choices without display intermediaries',
    (tester) async {
      final p = await _createProvider(_buildStudentData());
      await _pumpSettingsPage(
        tester,
        p,
        locale: const Locale('zh'),
        destination: SettingsDestination.student,
      );
      final l = AppLocalizations.of(tester.element(find.byType(SettingsPage)));
      expect(find.text(l.importTimetableTextDesc), findsOneWidget);
      expect(find.text(l.schoolImportParserSettingsTitle), findsOneWidget);
      expect(find.text('课程显示、横向布局、切周手势和快捷添加'), findsNothing);
      expect(find.text('视图、工具栏、日期格式和快捷添加'), findsNothing);
    },
  );

  testWidgets(
    'category navigation survives a workspace switch without settings search or extra writes',
    (tester) async {
      final data = _buildStudentData();
      final storage = _MemoryTimetableStorage(data);
      final p = await _createProvider(data, storage: storage);
      await _pumpSettingsPage(tester, p);
      await tester.tap(
        find.byKey(const ValueKey('settings-category-appearance')),
      );
      await tester.pumpAndSettle();
      final state = tester.state(find.byType(ThemeSettingsPage));
      expect(find.byKey(const ValueKey('settings-search')), findsNothing);
      await p.switchMode(AppMode.general);
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(ThemeSettingsPage)), same(state));
      expect(find.byKey(const ValueKey('settings-search')), findsNothing);
      expect(storage.saveCount, 1);
    },
  );

  testWidgets('home workspace navigation setting rolls back and can retry', (
    tester,
  ) async {
    final data = _buildStudentData();
    final storage = _MemoryTimetableStorage(data)..failSaves = true;
    final provider = await _createProvider(data, storage: storage);
    await _pumpSettingsPage(
      tester,
      provider,
      destination: SettingsDestination.features,
    );

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

  testWidgets(
    'home navigation save blocks duplicate input without dimming its switch',
    (tester) async {
      final data = _buildStudentData();
      final storage = _MemoryTimetableStorage(data)..blockNextSave();
      final provider = await _createProvider(data, storage: storage);
      addTearDown(() {
        storage.completePendingSave();
        provider.dispose();
      });
      await _pumpSettingsPage(
        tester,
        provider,
        destination: SettingsDestination.features,
      );

      final title = find.text('Hide workspace navigation');
      final tile = find.ancestor(
        of: title,
        matching: find.byType(SettingsSwitchTile),
      );
      final toggle = find.descendant(of: tile, matching: find.byType(Switch));
      final initialTitleColor = tester.widget<Text>(title).style?.color;

      await tester.tap(toggle);
      await tester.pump();

      expect(storage.saveCount, 1);
      expect(provider.hideHomeWorkspaceNavigation, isTrue);
      expect(tester.widget<Switch>(toggle).onChanged, isNotNull);
      expect(tester.widget<Text>(title).style?.color, initialTitleColor);
      expect(
        tester
            .widgetList<SettingsInteractionBlocker>(
              find.ancestor(
                of: tile,
                matching: find.byType(SettingsInteractionBlocker),
              ),
            )
            .any((blocker) => blocker.blocked),
        isTrue,
      );

      await tester.tap(toggle, warnIfMissed: false);
      await tester.pump();
      expect(storage.saveCount, 1);

      storage.completePendingSave();
      await tester.pumpAndSettle();
      expect(provider.hideHomeWorkspaceNavigation, isTrue);
      expect(tester.widget<Switch>(toggle).onChanged, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'compact category navigation remains reachable at 2x text scale',
    (tester) async {
      _setTestViewport(tester, const Size(320, 568));
      addTearDown(() => _resetTestViewport(tester));
      final p = await _createProvider(_buildStudentData());
      await _pumpSettingsPage(
        tester,
        p,
        textScaler: const TextScaler.linear(2),
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('settings-category-about')),
        160,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('settings-category-about')));
      await tester.pumpAndSettle();
      expect(find.text('Check for updates'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('compact settings starts with categories and no open editor', (
    tester,
  ) async {
    for (final width in [320.0, 360.0, 600.0, 744.0]) {
      _setTestViewport(tester, Size(width, 900));
      final p = await _createProvider(_buildStudentData());
      await _pumpSettingsPage(tester, p);
      for (final key in [
        'appearance',
        'notifications',
        'language',
        'data',
        'features',
        'about',
      ]) {
        expect(find.byKey(ValueKey('settings-category-$key')), findsOneWidget);
      }
      expect(find.byType(ThemeSettingsPage), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      p.dispose();
    }
    _resetTestViewport(tester);
  });

  testWidgets(
    'large text turns the settings split view back into page navigation',
    (tester) async {
      _setTestViewport(tester, const Size(1000, 900));
      addTearDown(() => _resetTestViewport(tester));
      final p = await _createProvider(_buildStudentData());
      await _pumpSettingsPage(
        tester,
        p,
        textScaler: const TextScaler.linear(2),
      );
      expect(find.byType(ThemeSettingsPage), findsNothing);
      for (final key in [
        'appearance',
        'notifications',
        'language',
        'data',
        'features',
        'about',
      ]) {
        expect(find.byKey(ValueKey('settings-category-$key')), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'settings opens its content pane at the measured 745dp form budget',
    (tester) async {
      _setTestViewport(tester, const Size(744, 1000));
      addTearDown(() => _resetTestViewport(tester));
      final p = await _createProvider(_buildStudentData());
      await _pumpSettingsPage(tester, p);
      expect(find.byType(ThemeSettingsPage), findsNothing);
      _setTestViewport(tester, const Size(745, 1000));
      await tester.pumpAndSettle();
      expect(find.byType(ThemeSettingsPage), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(ThemeSettingsPage)).dx,
        greaterThanOrEqualTo(224),
      );
    },
  );

  testWidgets(
    'category links use forward navigation chevrons on compact screens',
    (tester) async {
      _setTestViewport(tester, const Size(360, 900));
      addTearDown(() => _resetTestViewport(tester));
      final p = await _createProvider(_buildStudentData());
      await _pumpSettingsPage(tester, p);
      expect(find.byIcon(Icons.chevron_right), findsNWidgets(6));
    },
  );

  testWidgets('app backup entry opens restore and export actions', (
    tester,
  ) async {
    final provider = await _createProvider(_buildGeneralData());
    await _pumpSettingsPage(
      tester,
      provider,
      destination: SettingsDestination.data,
    );

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
    await _pumpSettingsPage(
      tester,
      provider,
      destination: SettingsDestination.data,
    );

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
    await _pumpSettingsPage(
      tester,
      provider,
      destination: SettingsDestination.data,
    );

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

  testWidgets('period templates stay manageable without an active timetable', (
    tester,
  ) async {
    final base = _buildStudentData();
    final data = base.copyWith(
      studentMode: base.studentMode.copyWith(
        timetables: [],
        activeTimetableId: '',
      ),
    );
    final p = await _createProvider(data);
    await _pumpSettingsPage(
      tester,
      p,
      destination: SettingsDestination.periods,
    );
    expect(find.text(p.periodTimeSets.first.name), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('appearance category ignores rapid duplicate taps', (
    tester,
  ) async {
    final p = await _createProvider(_buildStudentData());
    await _pumpSettingsPage(tester, p);
    final entry = find.byKey(const ValueKey('settings-category-appearance'));
    await tester.tap(entry);
    await tester.tap(entry, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(ThemeSettingsPage), findsOneWidget);
  });

  testWidgets('student import/export actions ignore rapid duplicate taps', (
    tester,
  ) async {
    final provider = await _createProvider(_buildStudentData());
    await _pumpSettingsPage(
      tester,
      provider,
      destination: SettingsDestination.student,
    );

    final importExportTile = find.text('Import timetable from JSON text');
    expect(importExportTile, findsOneWidget);

    await tester.ensureVisible(importExportTile);
    await tester.pumpAndSettle();
    await tester.tap(importExportTile);
    await tester.tap(importExportTile, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.byType(TextImportPage), findsOneWidget);
    expect(find.byType(TextImportPage, skipOffstage: false), findsOneWidget);
  });

  testWidgets('student data sheet action ignores rapid duplicate taps', (
    tester,
  ) async {
    final provider = await _createProvider(_buildStudentData());
    await _pumpSettingsHostPage(tester, provider);

    await tester.tap(find.text('Open settings host'));
    await _pumpRouteTransition(tester);

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
    await _pumpSettingsPage(
      tester,
      provider,
      destination: SettingsDestination.general,
    );

    final importExportTile = find.text('Paste JSON');
    expect(importExportTile, findsOneWidget);

    await tester.ensureVisible(importExportTile);
    await tester.pumpAndSettle();
    await tester.tap(importExportTile);
    await tester.tap(importExportTile, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.byType(TextImportPage), findsOneWidget);
    expect(find.byType(TextImportPage, skipOffstage: false), findsOneWidget);
  });

  testWidgets('general data action chevrons are vertically centered', (
    tester,
  ) async {
    final provider = await _createProvider(_buildGeneralData());
    await _pumpSettingsPage(
      tester,
      provider,
      destination: SettingsDestination.general,
    );

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
        find.ancestor(of: titleFinder, matching: find.byType(ListTile)),
      );
      final chevronFinder = find.descendant(
        of: find.ancestor(of: titleFinder, matching: find.byType(ListTile)),
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

    final importExportTile = find.text('Category import & export');
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

  testWidgets('JSON replacement target cancellation does not import or save', (
    tester,
  ) async {
    final data = _buildGeneralDataWithSchedules([
      _generalSchedule(id: 'existing-a', name: 'Existing Alpha'),
      _generalSchedule(id: 'existing-b', name: 'Existing Beta', sortOrder: 1),
    ], activeScheduleId: 'existing-a');
    final storage = _MemoryTimetableStorage(data);
    final provider = await _createProvider(data, storage: storage);
    addTearDown(provider.dispose);

    await _openGeneralDataActions(tester, provider);
    await tester.tap(find.text('Paste JSON'));
    await _pumpRouteTransition(tester);
    await tester.enterText(find.byType(TextField), _buildGeneralImportSource());
    await tester.tap(find.widgetWithText(FilledButton, 'Import'));
    await _pumpRouteTransition(tester);

    expect(find.text('Select categories to import'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await _pumpRouteTransition(tester);
    expect(
      find.text(
        'Add the import as a new category or replace an existing category?',
      ),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Replace category'));
    await _pumpRouteTransition(tester);
    expect(find.text('Choose category to replace'), findsOneWidget);
    expect(find.text('Existing Alpha'), findsOneWidget);
    expect(find.text('Existing Beta'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await _pumpRouteTransition(tester);

    expect(find.byType(TextImportPage), findsOneWidget);
    expect(storage.saveCount, 0);
    expect(provider.generalSchedules.map((schedule) => schedule.name), [
      'Existing Alpha',
      'Existing Beta',
    ]);
    expect(
      provider.generalSchedules.every((schedule) => schedule.events.isEmpty),
      isTrue,
    );
  });

  testWidgets('JSON replacement uses the explicitly selected category', (
    tester,
  ) async {
    final data = _buildGeneralDataWithSchedules([
      _generalSchedule(id: 'existing-a', name: 'Existing Alpha'),
      _generalSchedule(id: 'existing-b', name: 'Existing Beta', sortOrder: 1),
    ], activeScheduleId: 'existing-a');
    final storage = _MemoryTimetableStorage(data);
    final provider = await _createProvider(data, storage: storage);
    addTearDown(provider.dispose);

    await _openGeneralDataActions(tester, provider);
    await tester.tap(find.text('Paste JSON'));
    await _pumpRouteTransition(tester);
    await tester.enterText(find.byType(TextField), _buildGeneralImportSource());
    await tester.tap(find.widgetWithText(FilledButton, 'Import'));
    await _pumpRouteTransition(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await _pumpRouteTransition(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Replace category'));
    await _pumpRouteTransition(tester);

    await tester.tap(find.text('Existing Beta'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Replace category'));
    await _pumpRouteTransition(tester);

    expect(find.byType(TextImportPage), findsNothing);
    expect(storage.saveCount, 1);
    final alpha = provider.generalSchedules.singleWhere(
      (schedule) => schedule.id == 'existing-a',
    );
    final beta = provider.generalSchedules.singleWhere(
      (schedule) => schedule.id == 'existing-b',
    );
    expect(alpha.name, 'Existing Alpha');
    expect(alpha.events, isEmpty);
    expect(beta.name, 'Imported category');
    expect(beta.events.single.title, 'Imported event');
  });

  testWidgets('copy JSON defaults to all visible categories', (tester) async {
    final data = _buildGeneralDataWithSchedules([
      _generalSchedule(id: 'visible-a', name: 'Visible Alpha'),
      _generalSchedule(
        id: 'hidden-b',
        name: 'Hidden Beta',
        isVisible: false,
        sortOrder: 1,
      ),
      _generalSchedule(id: 'visible-c', name: 'Visible Gamma', sortOrder: 2),
    ], activeScheduleId: 'visible-a');
    final provider = await _createProvider(data);
    addTearDown(provider.dispose);

    await _openGeneralDataActions(tester, provider);
    final copyJson = find.text('Copy JSON');
    await tester.ensureVisible(copyJson);
    await tester.pumpAndSettle();
    await tester.tap(copyJson);
    await tester.pumpAndSettle();

    expect(find.text('Select categories to export'), findsOneWidget);
    expect(find.text('2 / 3'), findsOneWidget);
    expect(
      find.descendant(
        of: _generalSelectionTile('Visible Alpha'),
        matching: find.byIcon(Icons.check_circle),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _generalSelectionTile('Hidden Beta'),
        matching: find.byIcon(Icons.radio_button_unchecked),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _generalSelectionTile('Visible Gamma'),
        matching: find.byIcon(Icons.check_circle),
      ),
      findsOneWidget,
    );
  });

  testWidgets('copy ICS falls back to the first category when all are hidden', (
    tester,
  ) async {
    final data = _buildGeneralDataWithSchedules([
      _generalSchedule(id: 'hidden-a', name: 'Hidden Alpha', isVisible: false),
      _generalSchedule(
        id: 'hidden-b',
        name: 'Hidden Beta',
        isVisible: false,
        sortOrder: 1,
      ),
      _generalSchedule(
        id: 'hidden-c',
        name: 'Hidden Gamma',
        isVisible: false,
        sortOrder: 2,
      ),
    ], activeScheduleId: 'hidden-a');
    final provider = await _createProvider(data);
    addTearDown(provider.dispose);

    await _openGeneralDataActions(tester, provider);
    final copyIcs = find.text('Copy ICS');
    await tester.ensureVisible(copyIcs);
    await tester.pumpAndSettle();
    await tester.tap(copyIcs);
    await tester.pumpAndSettle();

    expect(find.text('Select calendars to copy as ICS'), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);
    expect(
      find.descendant(
        of: _generalSelectionTile('Hidden Alpha'),
        matching: find.byIcon(Icons.check_circle),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _generalSelectionTile('Hidden Beta'),
        matching: find.byIcon(Icons.radio_button_unchecked),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _generalSelectionTile('Hidden Gamma'),
        matching: find.byIcon(Icons.radio_button_unchecked),
      ),
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
    await _pumpSettingsPage(
      tester,
      provider,
      destination: SettingsDestination.general,
    );

    final importExportTile = find.text('Category import & export');
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
    await tester.tap(find.widgetWithText(TextButton, 'Add as new category'));
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
    await _pumpSettingsPage(
      tester,
      provider,
      destination: SettingsDestination.general,
    );

    final importExportTile = find.text('Category import & export');
    await tester.ensureVisible(importExportTile);
    await tester.pumpAndSettle();
    await tester.tap(importExportTile);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paste ICS'));
    await _pumpRouteTransition(tester);
    await tester.enterText(find.byType(TextField), source);
    await tester.tap(find.widgetWithText(FilledButton, 'Import'));
    await _pumpRouteTransition(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Add as new category'));
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
