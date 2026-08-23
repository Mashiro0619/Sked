import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/main.dart' hide main;
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/services/privacy_service.dart';
import 'package:sked/services/secret_store.dart';

class _NoopSecretStore implements SecretStore {
  const _NoopSecretStore();

  @override
  Future<String> readCustomSchoolImportApiKey() async => '';

  @override
  Future<void> writeCustomSchoolImportApiKey(String value) async {}
}

class _NoopPrivacyService extends PrivacyService {
  const _NoopPrivacyService();

  @override
  Future<String?> fetchCurrentPrivacyPolicyVersion() async => null;
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

Future<TimetableProvider> _providerFor(_ControllableStorage storage) async {
  final provider = TimetableProvider(
    storage: storage,
    systemLocaleCodeResolver: () => 'en',
    privacyService: const _NoopPrivacyService(),
    secretStore: const _NoopSecretStore(),
  );
  addTearDown(provider.dispose);
  await provider.load();
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

  test('new app data uses light theme without changing legacy fallbacks', () {
    final data = buildInitialAppData(buildDefaultPeriodTimes());

    expect(defaultThemeMode, 'system');
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

  testWidgets('fresh launch stays light when the system is dark', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final storage = _ControllableStorage(null);
    final provider = await _providerFor(storage);

    await tester.pumpWidget(MyApp(provider: provider));
    await tester.pumpAndSettle();

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.themeMode, ThemeMode.light);
    expect(
      Theme.of(
        tester.element(find.byKey(const ValueKey('first-launch-onboarding'))),
      ).brightness,
      Brightness.light,
    );
  });

  test('first launch commits mode and privacy acceptance once', () async {
    final storage = _ControllableStorage(_initialApp());
    final provider = await _providerFor(storage);
    await provider.completeFirstLaunch(
      AppMode.student,
      hideWorkspaceNavigation: true,
    );

    final acceptedAt = provider.privacyPolicyAcceptedAt;
    expect(storage.saveCount, 1);
    expect(provider.activeMode, AppMode.student);
    expect(provider.hideHomeWorkspaceNavigation, isTrue);
    expect(provider.homeWorkspaceNavigationCollapsed, isTrue);
    expect(provider.acceptedPrivacyPolicyVersion, bundledPrivacyPolicyVersion);
    expect(acceptedAt, isNotNull);
    expect(storage.data!.activeMode, AppMode.student);
    expect(storage.data!.hideHomeWorkspaceNavigation, isTrue);
    expect(storage.data!.homeWorkspaceNavigationCollapsed, isTrue);
    expect(
      storage.data!.privacyPolicyAcceptedVersion,
      bundledPrivacyPolicyVersion,
    );
    expect(
      storage.data!.privacyPolicyAcceptedAtIso,
      acceptedAt!.toIso8601String(),
    );

    await provider.completeFirstLaunch(
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

      await provider.completeFirstLaunch(
        AppMode.student,
        hideWorkspaceNavigation: false,
      );

      expect(storage.saveCount, 1);
      expect(provider.activeMode, AppMode.student);
      expect(provider.hideHomeWorkspaceNavigation, isFalse);
      expect(provider.homeWorkspaceNavigationCollapsed, isTrue);
      expect(provider.acceptedPrivacyPolicyVersion, acceptedVersion);
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
      provider.injectRemotePrivacyPolicyVersion('invalid');

      await expectLater(
        provider.completeFirstLaunch(
          AppMode.student,
          hideWorkspaceNavigation: true,
        ),
        throwsStateError,
      );

      expect(storage.saveCount, 0);
      expect(provider.activeMode, initial.activeMode);
      expect(provider.acceptedPrivacyPolicyVersion, isNull);
      expect(provider.privacyPolicyAcceptedAt, isNull);
      expect(provider.hideHomeWorkspaceNavigation, isFalse);
      expect(provider.homeWorkspaceNavigationCollapsed, isFalse);
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
      provider.completeFirstLaunch(
        AppMode.student,
        hideWorkspaceNavigation: true,
      ),
      throwsStateError,
    );

    expect(storage.saveCount, 1);
    expect(provider.activeMode, initial.activeMode);
    expect(provider.acceptedPrivacyPolicyVersion, acceptedVersion);
    expect(provider.privacyPolicyAcceptedAt?.toIso8601String(), acceptedAtIso);
    expect(provider.hideHomeWorkspaceNavigation, isFalse);
    expect(provider.homeWorkspaceNavigationCollapsed, isFalse);
    expect(storage.data!.toJson(), initial.toJson());
  });
}
