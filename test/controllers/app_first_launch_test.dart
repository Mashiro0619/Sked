import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/main.dart' hide main;
import 'package:sked/models/timetable_models.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/controllers/app_lifecycle.dart'
    show bundledPrivacyPolicyVersion;
import 'package:sked/services/secret_store.dart';
import 'package:sked/screens/app_home_screen.dart';

import '../support/data_transfer_codec.dart';

class _NoopSecretStore implements SecretStore {
  const _NoopSecretStore();

  @override
  Future<String> readCustomSchoolImportApiKey() async => '';

  @override
  Future<void> writeCustomSchoolImportApiKey(String value) async {}
}

class _ControllableStorage implements TimetableStorage {
  _ControllableStorage(this.data);

  AppData? data;
  Object? nextSaveError;
  var saveCount = 0;

  @override
  Future<String?> filePath() async => 'memory://provider-first-launch-test';

  @override
  Future<StorageLoadResult> load() async =>
      StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);

  @override
  Future<void> save(AppData next) async {
    saveCount += 1;
    final error = nextSaveError;
    nextSaveError = null;
    if (error != null) throw error;
    data = next;
  }
}

Future<AppRuntime> _providerFor(_ControllableStorage storage) async {
  final provider = AppRuntime(
    dataTransferCodec: inlineDataTransferCodec,
    storage: storage,
    systemLocaleCodeResolver: () => 'en',
    secretStore: const _NoopSecretStore(),
    appVersionLoader: () async => '2.3.0',
  );
  addTearDown(provider.dispose);
  await provider.lifecycle.load();
  storage.saveCount = 0;
  return provider;
}

AppData _initialApp({
  AppMode activeMode = AppMode.general,
  String? acceptedVersion,
  String? acceptedAtIso,
}) {
  return buildInitialAppData(buildDefaultPeriodTimes()).copyWith(
    activeMode: activeMode,
    privacyPolicyAcceptedVersion: acceptedVersion,
    privacyPolicyAcceptedAtIso: acceptedAtIso,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('new app data follows system without changing legacy fallbacks', () {
    final data = buildInitialAppData(buildDefaultPeriodTimes());

    expect(defaultThemeMode, 'system');
    expect(newUserDefaultThemeMode, 'system');
    expect(data.studentMode.themeMode, newUserDefaultThemeMode);
    expect(data.generalMode.themeMode, newUserDefaultThemeMode);
    expect(
      StudentModeData(
        activeTimetableId: '',
        timetables: const [],
        periodTimeSets: data.studentMode.periodTimeSets,
      ).themeMode,
      defaultThemeMode,
    );
    expect(GeneralScheduleData.createDefault().themeMode, defaultThemeMode);
  });

  testWidgets('fresh launch follows changes to system brightness', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final storage = _ControllableStorage(null);
    final provider = await _providerFor(storage);

    await tester.pumpWidget(MyApp(app: provider));
    await tester.pumpAndSettle();

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.themeMode, ThemeMode.system);
    expect(
      Theme.of(
        tester.element(find.byKey(const ValueKey('first-launch-onboarding'))),
      ).brightness,
      Brightness.dark,
    );
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpAndSettle();
    expect(
      Theme.of(
        tester.element(find.byKey(const ValueKey('first-launch-onboarding'))),
      ).brightness,
      Brightness.light,
    );
    expect(storage.data!.studentMode.themeMode, 'system');
    expect(storage.data!.generalMode.themeMode, 'system');
    expect(storage.data!.studentMode.themeColorMode, themeColorModeColorful);
    expect(storage.data!.generalMode.themeColorMode, themeColorModeSingle);
    final reopened = await _providerFor(storage);
    expect(
      reopened.session.data.studentMode.themeColorMode,
      themeColorModeColorful,
    );
    expect(
      reopened.session.data.generalMode.themeColorMode,
      themeColorModeSingle,
    );
  });

  for (final selected in [themeColorModeSingle, themeColorModeColorful]) {
    test(
      'existing $selected course preference and exact colors survive loading',
      () async {
        final initial = _initialApp();
        final saved = initial.copyWith(
          studentMode: initial.studentMode.copyWith(
            themeColorMode: selected,
            activeTimetableId: 'saved-table',
            timetables: [
              TimetableData(
                id: 'saved-table',
                config: TimetableConfig(
                  name: 'Saved timetable',
                  startDate: DateTime(2026, 9, 1),
                  totalWeeks: 18,
                  periodTimeSetId: defaultPeriodTimeSetId,
                ),
                courses: [
                  for (final name in ['Physics', 'Chemistry'])
                    CourseItem(
                      id: name,
                      name: name,
                      teacher: '',
                      location: '',
                      dayOfWeek: 1,
                      semesterWeeks: const [1],
                      periods: const [1],
                      startMinutes: 480,
                      endMinutes: 525,
                      timeRange: '08:00-08:45',
                      credit: 0,
                      remarks: '',
                      customFields: const {},
                    ),
                ],
              ),
            ],
            courseNameColorValues: const {
              'Physics': 0xFF123456,
              'Chemistry': 0xFF123456,
            },
          ),
          generalMode: initial.generalMode.copyWith(
            themeColorMode: themeColorModeColorful,
            colorfulUiColorValues: const {colorfulUiPrimaryKey: 0xFF234567},
          ),
        );
        final storage = _ControllableStorage(saved);
        final provider = await _providerFor(storage);
        expect(provider.session.data.studentMode.themeColorMode, selected);
        expect(
          provider.session.data.studentMode.courseNameColorValues,
          saved.studentMode.courseNameColorValues,
        );
        expect(
          provider.session.data.generalMode.themeColorMode,
          themeColorModeColorful,
        );
        expect(
          provider.session.data.generalMode.colorfulUiColorValues,
          saved.generalMode.colorfulUiColorValues,
        );
        expect(storage.saveCount, 0);
      },
    );
  }

  test(
    'legacy missing course color preference keeps its single fallback',
    () async {
      final source = _initialApp().toJson();
      (source['studentMode'] as Map<String, dynamic>).remove('themeColorMode');
      final storage = _ControllableStorage(AppData.fromJson(source));
      final provider = await _providerFor(storage);
      expect(
        provider.session.data.studentMode.themeColorMode,
        themeColorModeSingle,
      );
      expect(storage.saveCount, 0);
    },
  );

  for (final (themeMode, seed, onboarding) in [
    ('light', defaultThemeSeedColorValue, true),
    ('system', defaultThemeSeedColorValue, true),
    ('dark', defaultThemeSeedColorValue, false),
    ('light', 0xFF00695C, false),
  ]) {
    testWidgets('stored $themeMode/$seed theme keeps onboarding=$onboarding', (
      tester,
    ) async {
      final initial = _initialApp(activeMode: AppMode.student);
      final storage = _ControllableStorage(
        initial.copyWith(
          studentMode: initial.studentMode.copyWith(
            themeMode: themeMode,
            themeSeedColorValue: seed,
          ),
          generalMode: initial.generalMode.copyWith(
            themeMode: themeMode,
            themeSeedColorValue: seed,
          ),
        ),
      );
      final provider = await _providerFor(storage);
      await tester.pumpWidget(MyApp(app: provider));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('first-launch-onboarding')),
        onboarding ? findsOneWidget : findsNothing,
      );
      expect(storage.data!.studentMode.themeMode, themeMode);
      expect(storage.data!.generalMode.themeMode, themeMode);
      expect(storage.data!.studentMode.themeSeedColorValue, seed);
      expect(storage.data!.generalMode.themeSeedColorValue, seed);
    });
  }

  testWidgets(
    'saved themes and custom colors remain independent across workspaces',
    (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final initial = _initialApp(
        activeMode: AppMode.student,
        acceptedVersion: bundledPrivacyPolicyVersion,
        acceptedAtIso: '2026-01-02T03:04:05.000Z',
      );
      final student = initial.studentMode.copyWith(
        themeMode: 'light',
        themeSeedColorValue: 0xFF00695C,
        colorfulUiColorValues: const {colorfulUiPrimaryKey: 0xFF00695C},
      );
      final general = initial.generalMode.copyWith(
        themeMode: 'dark',
        themeSeedColorValue: 0xFF6A1B9A,
        colorfulUiColorValues: const {colorfulUiPrimaryKey: 0xFF6A1B9A},
      );
      final storage = _ControllableStorage(
        initial.copyWith(studentMode: student, generalMode: general),
      );
      final provider = await _providerFor(storage);
      await tester.pumpWidget(MyApp(app: provider));
      await tester.pumpAndSettle();

      Brightness brightness() =>
          Theme.of(tester.element(find.byType(AppHomeScreen))).brightness;
      expect(brightness(), Brightness.light);
      expect(
        find.byKey(const ValueKey('first-launch-onboarding')),
        findsNothing,
      );
      await provider.workspaces.switchMode(AppMode.general);
      await tester.pumpAndSettle();
      expect(brightness(), Brightness.dark);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpAndSettle();
      expect(brightness(), Brightness.dark);

      await provider.settingsCommands.updateThemeMode('system');
      await tester.pumpAndSettle();
      expect(brightness(), Brightness.light);
      await provider.workspaces.switchMode(AppMode.student);
      await tester.pumpAndSettle();
      expect(brightness(), Brightness.light);
      expect(storage.data!.studentMode.themeMode, 'light');
      expect(storage.data!.generalMode.themeMode, 'system');
      expect(
        storage.data!.studentMode.themeSeedColorValue,
        student.themeSeedColorValue,
      );
      expect(
        storage.data!.generalMode.themeSeedColorValue,
        general.themeSeedColorValue,
      );
      expect(
        storage.data!.studentMode.colorfulUiColorValues,
        student.colorfulUiColorValues,
      );
      expect(
        storage.data!.generalMode.colorfulUiColorValues,
        general.colorfulUiColorValues,
      );

      final reopened = await _providerFor(storage);
      expect(reopened.session.data.studentMode.themeMode, 'light');
      expect(reopened.session.data.generalMode.themeMode, 'system');
      expect(
        reopened.session.data.studentMode.colorfulUiColorValues,
        student.colorfulUiColorValues,
      );
      expect(
        reopened.session.data.generalMode.colorfulUiColorValues,
        general.colorfulUiColorValues,
      );
    },
  );

  test('first launch commits mode and privacy acceptance once', () async {
    final storage = _ControllableStorage(_initialApp());
    final provider = await _providerFor(storage);
    await provider.lifecycle.completeFirstLaunch(
      AppMode.student,
      hideWorkspaceNavigation: true,
    );

    final acceptedAt = provider.lifecycle.privacyPolicyAcceptedAt;
    expect(storage.saveCount, 1);
    expect(provider.workspaceView.activeMode, AppMode.student);
    expect(provider.settingsView.hideHomeWorkspaceNavigation, isTrue);
    expect(provider.settingsView.homeWorkspaceNavigationCollapsed, isFalse);
    expect(
      provider.lifecycle.acceptedPrivacyPolicyVersion,
      bundledPrivacyPolicyVersion,
    );
    expect(acceptedAt, isNotNull);
    expect(storage.data!.activeMode, AppMode.student);
    expect(storage.data!.hideHomeWorkspaceNavigation, isTrue);
    expect(storage.data!.homeWorkspaceNavigationCollapsed, isFalse);
    expect(
      storage.data!.privacyPolicyAcceptedVersion,
      bundledPrivacyPolicyVersion,
    );
    expect(
      storage.data!.privacyPolicyAcceptedAtIso,
      acceptedAt!.toIso8601String(),
    );

    await provider.lifecycle.completeFirstLaunch(
      AppMode.student,
      hideWorkspaceNavigation: true,
    );
    expect(storage.saveCount, 1);
  });

  test(
    'first launch preserves a newer valid acceptance and timestamp',
    () async {
      const acceptedVersion = '2099-12-31';
      const acceptedAtIso = '2026-01-02T03:04:05.000Z';
      final storage = _ControllableStorage(
        _initialApp(
          acceptedVersion: acceptedVersion,
          acceptedAtIso: acceptedAtIso,
        ),
      );
      final provider = await _providerFor(storage);

      await provider.lifecycle.completeFirstLaunch(
        AppMode.student,
        hideWorkspaceNavigation: false,
      );

      expect(storage.saveCount, 1);
      expect(provider.workspaceView.activeMode, AppMode.student);
      expect(provider.settingsView.hideHomeWorkspaceNavigation, isFalse);
      expect(provider.settingsView.homeWorkspaceNavigationCollapsed, isFalse);
      expect(provider.lifecycle.acceptedPrivacyPolicyVersion, acceptedVersion);
      expect(storage.data!.privacyPolicyAcceptedVersion, acceptedVersion);
      expect(storage.data!.privacyPolicyAcceptedAtIso, acceptedAtIso);
    },
  );

  test(
    'invalid active privacy version rejects before mutation or save',
    () async {
      final initial = _initialApp();
      final storage = _ControllableStorage(initial);
      final provider = await _providerFor(storage);
      provider.lifecycle.injectPrivacyPolicyVersionForTesting('invalid');

      await expectLater(
        provider.lifecycle.completeFirstLaunch(
          AppMode.student,
          hideWorkspaceNavigation: true,
        ),
        throwsStateError,
      );

      expect(storage.saveCount, 0);
      expect(provider.workspaceView.activeMode, initial.activeMode);
      expect(provider.lifecycle.acceptedPrivacyPolicyVersion, isNull);
      expect(provider.lifecycle.privacyPolicyAcceptedAt, isNull);
      expect(provider.settingsView.hideHomeWorkspaceNavigation, isFalse);
      expect(provider.settingsView.homeWorkspaceNavigationCollapsed, isFalse);
      expect(storage.data!.toJson(), initial.toJson());
    },
  );

  test('failed first launch save rolls back all fields together', () async {
    const acceptedVersion = '2025-01-01';
    const acceptedAtIso = '2025-01-01T00:00:00.000Z';
    final initial = _initialApp(
      acceptedVersion: acceptedVersion,
      acceptedAtIso: acceptedAtIso,
    );
    final storage = _ControllableStorage(initial);
    final provider = await _providerFor(storage);
    storage.nextSaveError = StateError('save failed');

    await expectLater(
      provider.lifecycle.completeFirstLaunch(
        AppMode.student,
        hideWorkspaceNavigation: true,
      ),
      throwsStateError,
    );

    expect(storage.saveCount, 1);
    expect(provider.workspaceView.activeMode, initial.activeMode);
    expect(provider.lifecycle.acceptedPrivacyPolicyVersion, acceptedVersion);
    expect(
      provider.lifecycle.privacyPolicyAcceptedAt?.toIso8601String(),
      acceptedAtIso,
    );
    expect(provider.settingsView.hideHomeWorkspaceNavigation, isFalse);
    expect(provider.settingsView.homeWorkspaceNavigationCollapsed, isFalse);
    expect(storage.data!.toJson(), initial.toJson());
  });
}
