import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/l10n/app_locale.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/screens/app_home_screen.dart';
import 'package:sked/screens/home_screen.dart';
import 'package:sked/screens/school_sites_page.dart';
import 'package:sked/screens/settings_page.dart';
import 'package:sked/services/export_service.dart';
import 'package:sked/services/privacy_service.dart';
import 'package:sked/services/secret_store.dart';
import 'package:sked/widgets/course_editor_sheet.dart';
import 'package:sked/widgets/text_transfer_widgets.dart';

const _urlLauncherChannel = MethodChannel('plugins.flutter.io/url_launcher');

class _MemoryTimetableStorage implements TimetableStorage {
  _MemoryTimetableStorage(this.data);

  AppData? data;
  bool failSaves = false;
  int saveCount = 0;

  @override
  Future<StorageLoadResult> load() async =>
      StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);

  @override
  Future<void> save(AppData data) async {
    saveCount += 1;
    if (failSaves) {
      throw StateError('retryable home save failed');
    }
    this.data = data;
  }

  @override
  Future<String?> filePath() async => 'memory://home-timetable-test';
}

class _BlockingTimetableStorage implements TimetableStorage {
  _BlockingTimetableStorage(this.data);

  AppData? data;
  int saveCount = 0;

  final Completer<void> _firstSaveStarted = Completer<void>();
  final Completer<void> _releaseSave = Completer<void>();

  Future<void> get firstSaveStarted => _firstSaveStarted.future;

  void completeSave() {
    if (!_releaseSave.isCompleted) {
      _releaseSave.complete();
    }
  }

  @override
  Future<StorageLoadResult> load() async =>
      StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);

  @override
  Future<void> save(AppData data) async {
    saveCount += 1;
    this.data = data;
    if (!_firstSaveStarted.isCompleted) {
      _firstSaveStarted.complete();
    }
    await _releaseSave.future;
  }

  @override
  Future<String?> filePath() async => 'memory://blocking-home-timetable-test';
}

class _FailingTimetableStorage implements TimetableStorage {
  _FailingTimetableStorage(this.data);

  AppData data;
  var saveCount = 0;

  @override
  Future<StorageLoadResult> load() async =>
      StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);

  @override
  Future<void> save(AppData data) async {
    saveCount += 1;
    throw const StorageWriteException('storage unavailable');
  }

  @override
  Future<String?> filePath() async => 'memory://failing-home-timetable-test';
}

class _NoopPrivacyService extends PrivacyService {
  const _NoopPrivacyService();

  @override
  Future<String?> fetchCurrentPrivacyPolicyVersion() async => null;
}

class _RecordingPrivacyService extends PrivacyService {
  var fetchCount = 0;

  @override
  Future<String?> fetchCurrentPrivacyPolicyVersion() async {
    fetchCount += 1;
    return null;
  }
}

class _MutablePrivacyService extends PrivacyService {
  String? version;

  @override
  Future<String?> fetchCurrentPrivacyPolicyVersion() async => version;
}

class _NoopSecretStore implements SecretStore {
  const _NoopSecretStore();

  @override
  Future<String> readCustomSchoolImportApiKey() async => '';

  @override
  Future<void> writeCustomSchoolImportApiKey(String value) async {}
}

class _RecoveryTimetableProvider extends TimetableProvider {
  _RecoveryTimetableProvider({
    required TimetableStorage storage,
    required this._status,
    required this._recoveryStatus,
    List<String> recoveryArtifacts = const [],
    this._recoveryArtifactBytes,
    this._recoveryArtifactReadError,
    this._canWrite = false,
    PrivacyService privacyService = const _NoopPrivacyService(),
  }) : _recoveryArtifacts = List.unmodifiable(recoveryArtifacts),
       super(
         storage: storage,
         systemLocaleCodeResolver: () => defaultLocaleCode,
         privacyService: privacyService,
         secretStore: const _NoopSecretStore(),
       );

  StorageLoadStatus _status;
  RecoveryStatus _recoveryStatus;
  final List<String> _recoveryArtifacts;
  final Uint8List? _recoveryArtifactBytes;
  final Object? _recoveryArtifactReadError;
  bool _canWrite;
  int retryCount = 0;
  int startFreshCount = 0;

  @override
  bool get isLoaded => true;

  @override
  bool get canWrite => _canWrite;

  @override
  StorageLoadStatus get storageLoadStatus => _status;

  @override
  RecoveryStatus get lastRecoveryStatus => _recoveryStatus;

  @override
  List<String> get recoveryArtifacts => _recoveryArtifacts;

  @override
  bool get canStartFreshAfterRecovery =>
      !_canWrite &&
      _status == StorageLoadStatus.corrupt &&
      _recoveryArtifacts.isNotEmpty;

  @override
  Future<void> retryStorageLoad() async {
    retryCount += 1;
    _canWrite = true;
    _status = StorageLoadStatus.success;
    _recoveryStatus = RecoveryStatus.none;
    notifyListeners();
  }

  @override
  Future<void> startFreshAfterRecovery() async {
    startFreshCount += 1;
    _canWrite = true;
    _status = StorageLoadStatus.success;
    _recoveryStatus = RecoveryStatus.none;
    notifyListeners();
  }

  @override
  Future<Uint8List?> readRecoveryArtifact(String artifactPath) async {
    final error = _recoveryArtifactReadError;
    if (error != null) throw error;
    return _recoveryArtifactBytes;
  }
}

class _RecordingRecoveryExportService extends ExportService {
  String? fileName;
  Uint8List? bytes;

  @override
  Future<ExportSaveResult> saveBytes({
    required String fileName,
    required Uint8List bytes,
    String mimeType = 'application/octet-stream',
  }) async {
    this.fileName = fileName;
    this.bytes = Uint8List.fromList(bytes);
    return const ExportSaveResult(
      status: ExportSaveStatus.saved,
      path: 'memory://exported-recovery.json',
    );
  }
}

class _BlockingPrivacyService extends PrivacyService {
  final Completer<String?> _completer = Completer<String?>();
  var fetchCount = 0;

  @override
  Future<String?> fetchCurrentPrivacyPolicyVersion() {
    fetchCount += 1;
    return _completer.future;
  }
}

AppData _buildPopulatedStudentData() {
  final periodTimes = buildDefaultPeriodTimes();
  final timetable = TimetableData(
    id: 'table-1',
    config: TimetableConfig(
      name: 'Test timetable',
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

AppData _buildMultiTimetableStudentData() {
  final periodTimes = buildDefaultPeriodTimes();
  final firstTimetable = TimetableData(
    id: 'table-1',
    config: TimetableConfig(
      name: 'First timetable',
      startDate: DateTime(2026, 5, 25),
      totalWeeks: 18,
      periodTimeSetId: defaultPeriodTimeSetId,
    ),
    courses: const [],
  );
  final secondTimetable = TimetableData(
    id: 'table-2',
    config: TimetableConfig(
      name: 'Second timetable',
      startDate: DateTime(2026, 6),
      totalWeeks: 16,
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
      activeTimetableId: firstTimetable.id,
      timetables: [firstTimetable, secondTimetable],
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

AppData _buildLongCourseStudentData() {
  final periodTimes = buildDefaultPeriodTimes();
  final timetable = TimetableData(
    id: 'table-long',
    config: TimetableConfig(
      name: 'A very long timetable name that should stay inside the app bar',
      startDate: DateTime(2026, 5, 25),
      totalWeeks: 18,
      periodTimeSetId: defaultPeriodTimeSetId,
    ),
    courses: [
      CourseItem(
        id: 'course-long',
        name:
            'Advanced interdisciplinary seminar with an extremely long course name',
        teacher: 'Professor With A Very Long Display Name',
        location: 'Building Alpha Room 123 With Additional Location Notes',
        dayOfWeek: 1,
        semesterWeeks: buildAllSemesterWeeks(18),
        periods: const [1, 2],
        startMinutes: periodTimes[0].startMinutes,
        endMinutes: periodTimes[1].endMinutes,
        timeRange: buildTimeRange(
          periodTimes[0].startMinutes,
          periodTimes[1].endMinutes,
        ),
        credit: 0,
        remarks: '',
        customFields: const {},
      ),
    ],
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

AppData _buildDefaultFirstLaunchData() {
  return buildInitialAppData(
    buildDefaultPeriodTimes(),
    localeCode: defaultLocaleCode,
  ).copyWith(activeMode: AppMode.student);
}

AppData _buildLegacySystemFirstLaunchData() {
  final data = _buildDefaultFirstLaunchData();
  return data.copyWith(
    studentMode: data.studentMode.copyWith(themeMode: defaultThemeMode),
    generalMode: data.generalMode.copyWith(themeMode: defaultThemeMode),
  );
}

Future<TimetableProvider> _createProvider() async {
  final data = _buildPopulatedStudentData();
  final provider = TimetableProvider(
    storage: _MemoryTimetableStorage(data),
    systemLocaleCodeResolver: () => defaultLocaleCode,
    privacyService: const _NoopPrivacyService(),
    secretStore: const _NoopSecretStore(),
  );
  await provider.load();
  return provider;
}

Future<TimetableProvider> _createEmptyProvider(
  _BlockingTimetableStorage storage,
) async {
  final data = buildInitialAppData(
    buildDefaultPeriodTimes(),
    localeCode: defaultLocaleCode,
  ).copyWith(activeMode: AppMode.student);
  storage.data = data;
  final provider = TimetableProvider(
    storage: storage,
    systemLocaleCodeResolver: () => defaultLocaleCode,
    privacyService: const _NoopPrivacyService(),
    secretStore: const _NoopSecretStore(),
  );
  await provider.load();
  return provider;
}

Future<void> _pumpHomeScreenWithProvider(
  WidgetTester tester,
  TimetableProvider provider,
) async {
  await _resetWidgetTree(tester);
  await tester.pumpWidget(
    ChangeNotifierProvider<TimetableProvider>.value(
      value: provider,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HomeScreen(key: UniqueKey()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpAppHomeScreenWithProvider(
  WidgetTester tester,
  TimetableProvider provider, {
  ExportService recoveryExportService = const ExportService(),
  bool settle = true,
  Locale locale = const Locale('en'),
  TextDirection? textDirection,
  TextScaler? textScaler,
}) async {
  await _resetWidgetTree(tester);
  await tester.pumpWidget(
    ChangeNotifierProvider<TimetableProvider>.value(
      value: provider,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) {
          Widget result = child!;
          if (textScaler != null) {
            result = MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: textScaler),
              child: result,
            );
          }
          if (textDirection != null) {
            result = Directionality(
              textDirection: textDirection,
              child: result,
            );
          }
          return result;
        },
        home: AppHomeScreen(
          key: UniqueKey(),
          recoveryExportService: recoveryExportService,
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

Future<void> _tapInlineText(
  WidgetTester tester,
  Finder paragraphFinder,
  String targetText,
) async {
  final paragraph = tester.renderObject<RenderParagraph>(paragraphFinder);
  final plainText = paragraph.text.toPlainText();
  final start = plainText.indexOf(targetText);
  expect(start, greaterThanOrEqualTo(0));
  final boxes = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: start, extentOffset: start + targetText.length),
  );
  expect(boxes, isNotEmpty);
  final paragraphOrigin = paragraph.localToGlobal(Offset.zero);
  await tester.tapAt(boxes.first.toRect().shift(paragraphOrigin).center);
}

Rect _firstLaunchRect(WidgetTester tester, String key) {
  return tester.getRect(find.byKey(ValueKey<String>(key)));
}

void _expectFirstLaunchCardsSideBySide(WidgetTester tester) {
  final student = _firstLaunchRect(tester, 'first-launch-student-card');
  final general = _firstLaunchRect(tester, 'first-launch-general-card');
  expect((student.top - general.top).abs(), lessThan(1));
  expect(student.right, lessThan(general.left));
  expect((student.width - general.width).abs(), lessThan(1));
}

void _expectFirstLaunchCardsStacked(WidgetTester tester) {
  final student = _firstLaunchRect(tester, 'first-launch-student-card');
  final general = _firstLaunchRect(tester, 'first-launch-general-card');
  expect((student.center.dx - general.center.dx).abs(), lessThan(1));
  expect(student.bottom, lessThan(general.top));
}

Future<void> _pumpHomeScreenHostPage(
  WidgetTester tester,
  TimetableProvider provider,
) async {
  await _resetWidgetTree(tester);
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
                                child: HomeScreen(key: UniqueKey()),
                              ),
                        ),
                      ),
                    );
                  },
                  child: const Text('Open home host'),
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

Future<void> _resetWidgetTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

Future<TimetableProvider> _pumpHomeScreen(WidgetTester tester) async {
  final provider = await _createProvider();
  await _pumpHomeScreenWithProvider(tester, provider);
  return provider;
}

Future<void> _pumpRouteTransition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

String _selectedWeekTitle(TimetableProvider provider) {
  return 'Week ${provider.selectedWeek}';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_urlLauncherChannel, null);
  });

  testWidgets(
    'corrupt recovery gate takes priority over onboarding and startup work',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final storage = _MemoryTimetableStorage(_buildDefaultFirstLaunchData());
      final privacyService = _RecordingPrivacyService();
      final provider = _RecoveryTimetableProvider(
        storage: storage,
        status: StorageLoadStatus.corrupt,
        recoveryStatus: RecoveryStatus.failedBackupRestore,
        recoveryArtifacts: const ['memory://recovery/app-data.corrupt.json'],
        privacyService: privacyService,
      );

      await _pumpAppHomeScreenWithProvider(tester, provider, settle: false);
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.byKey(const ValueKey('data-recovery-screen')),
        findsOneWidget,
      );
      expect(find.text('Your data needs recovery'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('data-recovery-show-artifacts')),
        findsOneWidget,
      );
      expect(find.text('Choose your starting mode'), findsNothing);
      expect(find.byType(HomeScreen), findsNothing);
      expect(privacyService.fetchCount, 0);
      expect(storage.saveCount, 0);
    },
  );

  testWidgets('recovery artifact action exports the protected raw bytes', (
    tester,
  ) async {
    final storage = _MemoryTimetableStorage(_buildDefaultFirstLaunchData());
    final rawBytes = Uint8List.fromList([0, 255, 123, 10]);
    final provider = _RecoveryTimetableProvider(
      storage: storage,
      status: StorageLoadStatus.corrupt,
      recoveryStatus: RecoveryStatus.failedBackupRestore,
      recoveryArtifacts: const ['memory://recovery/app-data.corrupt.json'],
      recoveryArtifactBytes: rawBytes,
    );
    final exports = _RecordingRecoveryExportService();
    await _pumpAppHomeScreenWithProvider(
      tester,
      provider,
      recoveryExportService: exports,
      settle: false,
    );

    await tester.tap(
      find.byKey(const ValueKey('data-recovery-show-artifacts')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.ios_share));
    await tester.pumpAndSettle();

    expect(exports.fileName, 'app-data.corrupt.json');
    expect(exports.bytes, rawBytes);
  });

  testWidgets('recovery artifact paths remain visible when a read fails', (
    tester,
  ) async {
    const artifact = 'memory://recovery/app-data-unreadable.json';
    final provider = _RecoveryTimetableProvider(
      storage: _MemoryTimetableStorage(_buildDefaultFirstLaunchData()),
      status: StorageLoadStatus.ioFailure,
      recoveryStatus: RecoveryStatus.ioFailure,
      recoveryArtifacts: const [artifact],
      recoveryArtifactReadError: StateError('recovery storage unavailable'),
    );
    await _pumpAppHomeScreenWithProvider(tester, provider, settle: false);

    await tester.tap(
      find.byKey(const ValueKey('data-recovery-show-artifacts')),
    );
    await tester.pumpAndSettle();

    expect(find.text(artifact), findsOneWidget);
    expect(find.byIcon(Icons.ios_share), findsNothing);
  });

  for (final scenario in <(StorageLoadStatus, RecoveryStatus, String)>[
    (
      StorageLoadStatus.ioFailure,
      RecoveryStatus.ioFailure,
      'Storage is unavailable',
    ),
    (
      StorageLoadStatus.unsupportedVersion,
      RecoveryStatus.unsupportedVersion,
      'Update Sked to open this data',
    ),
  ]) {
    testWidgets('${scenario.$1.name} recovery cannot force fresh data', (
      tester,
    ) async {
      final storage = _MemoryTimetableStorage(_buildDefaultFirstLaunchData());
      final provider = _RecoveryTimetableProvider(
        storage: storage,
        status: scenario.$1,
        recoveryStatus: scenario.$2,
        recoveryArtifacts: const ['memory://protected/original.json'],
      );

      await _pumpAppHomeScreenWithProvider(tester, provider, settle: false);

      expect(find.text(scenario.$3), findsOneWidget);
      expect(find.byKey(const ValueKey('data-recovery-retry')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('data-recovery-start-fresh')),
        findsNothing,
      );
      expect(storage.saveCount, 0);
    });
  }

  testWidgets('corrupt recovery can start fresh after explicit confirmation', (
    tester,
  ) async {
    final storage = _MemoryTimetableStorage(_buildDefaultFirstLaunchData());
    final provider = _RecoveryTimetableProvider(
      storage: storage,
      status: StorageLoadStatus.corrupt,
      recoveryStatus: RecoveryStatus.failedBackupRestore,
      recoveryArtifacts: const ['memory://recovery/app-data.corrupt.json'],
    );
    await _pumpAppHomeScreenWithProvider(tester, provider, settle: false);

    await tester.tap(find.byKey(const ValueKey('data-recovery-start-fresh')));
    await tester.pumpAndSettle();

    expect(
      find.text('Start with new data?', skipOffstage: false),
      findsOneWidget,
    );
    expect(storage.saveCount, 0);

    await tester.tap(
      find.byKey(const ValueKey('data-recovery-confirm-start-fresh')),
    );
    await tester.pumpAndSettle();

    expect(provider.canWrite, isTrue);
    expect(provider.startFreshCount, 1);
    expect(storage.saveCount, 0);
    expect(find.byKey(const ValueKey('data-recovery-screen')), findsNothing);
    expect(find.text('Choose your starting mode'), findsOneWidget);
  });

  testWidgets('successful recovery retry removes the write gate', (
    tester,
  ) async {
    final storage = _MemoryTimetableStorage(_buildDefaultFirstLaunchData());
    final provider = _RecoveryTimetableProvider(
      storage: storage,
      status: StorageLoadStatus.corrupt,
      recoveryStatus: RecoveryStatus.failedBackupRestore,
      recoveryArtifacts: const ['memory://recovery/app-data.corrupt.json'],
    );
    await _pumpAppHomeScreenWithProvider(tester, provider, settle: false);

    await tester.tap(find.byKey(const ValueKey('data-recovery-retry')));
    await tester.pumpAndSettle();

    expect(provider.retryCount, 1);
    expect(provider.canWrite, isTrue);
    expect(find.byKey(const ValueKey('data-recovery-screen')), findsNothing);
    expect(find.text('Choose your starting mode'), findsOneWidget);
    expect(storage.saveCount, 0);
  });

  testWidgets('write gate transition clears settings child routes', (
    tester,
  ) async {
    final provider = TimetableProvider(
      storage: _FailingTimetableStorage(
        _buildPopulatedStudentData().copyWith(
          privacyPolicyAcceptedVersion: bundledPrivacyPolicyVersion,
          privacyPolicyAcceptedAtIso: '2026-06-02T00:00:00.000',
        ),
      ),
      systemLocaleCodeResolver: () => defaultLocaleCode,
      privacyService: const _NoopPrivacyService(),
      secretStore: const _NoopSecretStore(),
    );
    await provider.load();
    await _pumpAppHomeScreenWithProvider(tester, provider);

    await tester.tap(find.byTooltip('Settings'));
    await _pumpRouteTransition(tester);
    expect(find.byType(SettingsPage), findsOneWidget);

    final settingsContext = tester.element(find.byType(SettingsPage));
    unawaited(
      Navigator.of(settingsContext).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Nested settings route')),
        ),
      ),
    );
    await _pumpRouteTransition(tester);
    expect(find.text('Nested settings route'), findsOneWidget);

    await expectLater(
      provider.switchMode(AppMode.general),
      throwsA(isA<StorageWriteException>()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nested settings route'), findsNothing);
    expect(find.byType(SettingsPage), findsNothing);
    expect(find.byKey(const ValueKey('data-recovery-screen')), findsOneWidget);
  });

  testWidgets('backup recovery shows a dismissible restored banner', (
    tester,
  ) async {
    final storage = _MemoryTimetableStorage(_buildDefaultFirstLaunchData());
    final provider = _RecoveryTimetableProvider(
      storage: storage,
      status: StorageLoadStatus.restored,
      recoveryStatus: RecoveryStatus.restoredFromBackup,
      canWrite: true,
    );

    await _pumpAppHomeScreenWithProvider(tester, provider, settle: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.text(
        'App data was restored from the previous backup because the main file failed to load.',
      ),
      findsOneWidget,
    );
    expect(find.byType(MaterialBanner), findsOneWidget);
  });

  testWidgets('fresh launch with empty storage shows timetable onboarding', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    final storage = _MemoryTimetableStorage(null);
    final provider = TimetableProvider(
      storage: storage,
      systemLocaleCodeResolver: () => defaultLocaleCode,
      privacyService: const _NoopPrivacyService(),
      secretStore: const _NoopSecretStore(),
    );
    await provider.load();

    await _pumpAppHomeScreenWithProvider(tester, provider, settle: false);
    await tester.pump(const Duration(milliseconds: 500));

    expect(provider.isStudentMode, isTrue);
    expect(provider.studentMode.themeMode, newUserDefaultThemeMode);
    expect(provider.generalMode.themeMode, newUserDefaultThemeMode);
    expect(storage.data?.activeMode, AppMode.student);
    expect(provider.acceptedPrivacyPolicyVersion, isNull);
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.text('Choose your starting mode'), findsOneWidget);
    expect(find.text('Student timetable'), findsOneWidget);
    expect(find.text('General schedule'), findsOneWidget);
    expect(find.text('Start with timetable'), findsNothing);
    expect(find.text('Start with schedule'), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(
      find.text(
        'Manage timetables, courses, weeks, period times, and imports.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Manage calendars, events, reminders, and JSON / ICS data.'),
      findsOneWidget,
    );
    final studentSemantics = tester
        .getSemantics(find.byKey(const ValueKey('first-launch-student-card')))
        .getSemanticsData();
    expect(studentSemantics.flagsCollection.isButton, isTrue);
    expect(studentSemantics.hasAction(SemanticsAction.tap), isTrue);
    expect(studentSemantics.label, contains('Student timetable'));
    expect(studentSemantics.label, contains('Manage timetables'));
    expect(find.text('No timetable yet'), findsNothing);
    expect(find.byIcon(Icons.event_available_outlined), findsNothing);
    expect(find.text('Sked'), findsNothing);
    semanticsHandle.dispose();
  });

  testWidgets('legacy system-themed initial data still shows onboarding', (
    tester,
  ) async {
    final provider = TimetableProvider(
      storage: _MemoryTimetableStorage(_buildLegacySystemFirstLaunchData()),
      systemLocaleCodeResolver: () => defaultLocaleCode,
      privacyService: const _NoopPrivacyService(),
      secretStore: const _NoopSecretStore(),
    );
    await provider.load();

    await _pumpAppHomeScreenWithProvider(tester, provider);

    expect(provider.studentMode.themeMode, defaultThemeMode);
    expect(provider.generalMode.themeMode, defaultThemeMode);
    expect(
      find.byKey(const ValueKey('first-launch-onboarding')),
      findsOneWidget,
    );
  });

  for (final scenario
      in <
        ({AppMode mode, ValueKey<String> card, ValueKey<String> destination})
      >[
        (
          mode: AppMode.student,
          card: ValueKey('first-launch-student-card'),
          destination: const ValueKey('student-home'),
        ),
        (
          mode: AppMode.general,
          card: ValueKey('first-launch-general-card'),
          destination: const ValueKey('general-home'),
        ),
      ]) {
    testWidgets(
      'first launch starts ${scenario.mode.name} and accepts privacy in one save',
      (tester) async {
        final storage = _MemoryTimetableStorage(_buildDefaultFirstLaunchData());
        final privacyService = _BlockingPrivacyService();
        final provider = TimetableProvider(
          storage: storage,
          systemLocaleCodeResolver: () => defaultLocaleCode,
          privacyService: privacyService,
          secretStore: const _NoopSecretStore(),
        );
        await provider.load();

        await _pumpAppHomeScreenWithProvider(tester, provider, settle: false);
        await tester.pump();

        expect(find.text('Choose your starting mode'), findsOneWidget);
        expect(find.byType(AlertDialog), findsNothing);
        expect(privacyService.fetchCount, 0);

        await tester.tap(find.byKey(scenario.card));
        await tester.pumpAndSettle();

        expect(storage.saveCount, 1);
        expect(storage.data?.activeMode, scenario.mode);
        expect(
          storage.data?.privacyPolicyAcceptedVersion,
          bundledPrivacyPolicyVersion,
        );
        expect(
          DateTime.tryParse(storage.data?.privacyPolicyAcceptedAtIso ?? ''),
          isNotNull,
        );
        expect(provider.activeMode, scenario.mode);
        expect(
          provider.acceptedPrivacyPolicyVersion,
          bundledPrivacyPolicyVersion,
        );
        expect(provider.privacyPolicyAcceptedAt, isNotNull);
        expect(privacyService.fetchCount, 0);
        expect(find.byType(AlertDialog), findsNothing);
        expect(
          find.text('Please agree to the privacy policy before using the app'),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('first-launch-onboarding')),
          findsNothing,
        );
        expect(find.byKey(scenario.destination), findsOneWidget);
      },
    );
  }

  testWidgets('existing empty general calendars skip first launch onboarding', (
    tester,
  ) async {
    final schedule = createDefaultGeneralSchedule().copyWith(
      name: 'Work',
      colorValue: 0xFF1565C0,
    );
    final extraSchedule = createDefaultGeneralSchedule(name: 'Personal');
    final initialData =
        buildInitialAppData(
          buildDefaultPeriodTimes(),
          localeCode: defaultLocaleCode,
        ).copyWith(
          activeMode: AppMode.general,
          privacyPolicyAcceptedVersion: null,
          privacyPolicyAcceptedAtIso: null,
          generalMode: GeneralScheduleData(
            activeScheduleId: schedule.id,
            schedules: [schedule, extraSchedule],
          ),
        );
    final provider = TimetableProvider(
      storage: _MemoryTimetableStorage(initialData),
      systemLocaleCodeResolver: () => defaultLocaleCode,
      privacyService: const _NoopPrivacyService(),
      secretStore: const _NoopSecretStore(),
    );
    await provider.load();
    provider.injectRemotePrivacyPolicyVersion('2026-06-02');

    await _pumpAppHomeScreenWithProvider(tester, provider, settle: false);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Choose your starting mode'), findsNothing);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets(
    'first launch blocks duplicate workspace choices until its save completes',
    (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      final storage = _BlockingTimetableStorage(_buildDefaultFirstLaunchData());
      final provider = TimetableProvider(
        storage: storage,
        systemLocaleCodeResolver: () => defaultLocaleCode,
        privacyService: const _NoopPrivacyService(),
        secretStore: const _NoopSecretStore(),
      );
      await provider.load();
      await _pumpAppHomeScreenWithProvider(tester, provider);

      final studentCard = find.byKey(
        const ValueKey('first-launch-student-card'),
      );
      final generalCard = find.byKey(
        const ValueKey('first-launch-general-card'),
      );
      final l10n = AppLocalizations.of(tester.element(studentCard));
      final enabledGeneralArrowColor = tester
          .widget<Icon>(
            find.descendant(
              of: generalCard,
              matching: find.byIcon(Icons.arrow_forward),
            ),
          )
          .color!;

      await tester.tap(studentCard);
      await storage.firstSaveStarted;
      await tester.pump();

      expect(storage.saveCount, 1);
      expect(
        find.byKey(const ValueKey('first-launch-onboarding')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<InkWell>(
              find.descendant(of: studentCard, matching: find.byType(InkWell)),
            )
            .onTap,
        isNull,
      );
      expect(
        tester
            .widget<InkWell>(
              find.descendant(of: generalCard, matching: find.byType(InkWell)),
            )
            .onTap,
        isNull,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        find.descendant(
          of: studentCard,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: generalCard,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
      );
      final pendingSemantics = tester
          .getSemantics(studentCard)
          .getSemanticsData();
      expect(pendingSemantics.flagsCollection.isLiveRegion, isTrue);
      expect(pendingSemantics.value, l10n.savingChanges);
      final disabledGeneralSemantics = tester
          .getSemantics(generalCard)
          .getSemanticsData();
      expect(
        disabledGeneralSemantics.flagsCollection.isEnabled,
        ui.Tristate.isFalse,
      );
      final disabledGeneralArrowColor = tester
          .widget<Icon>(
            find.descendant(
              of: generalCard,
              matching: find.byIcon(Icons.arrow_forward),
            ),
          )
          .color!;
      expect(disabledGeneralArrowColor.a, lessThan(enabledGeneralArrowColor.a));

      await tester.tap(generalCard, warnIfMissed: false);
      await tester.tap(studentCard, warnIfMissed: false);
      await tester.pump();
      expect(storage.saveCount, 1);

      storage.completeSave();
      await tester.pumpAndSettle();

      expect(storage.saveCount, 1);
      expect(storage.data?.activeMode, AppMode.student);
      expect(
        storage.data?.privacyPolicyAcceptedVersion,
        bundledPrivacyPolicyVersion,
      );
      expect(find.byKey(const ValueKey('student-home')), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      semanticsHandle.dispose();
    },
  );

  testWidgets('first launch save failure rolls back and reveals recovery', (
    tester,
  ) async {
    final initialData = _buildDefaultFirstLaunchData();
    final storage = _FailingTimetableStorage(initialData);
    final provider = TimetableProvider(
      storage: storage,
      systemLocaleCodeResolver: () => defaultLocaleCode,
      privacyService: const _NoopPrivacyService(),
      secretStore: const _NoopSecretStore(),
    );
    await provider.load();
    await _pumpAppHomeScreenWithProvider(tester, provider);

    await tester.tap(find.byKey(const ValueKey('first-launch-general-card')));
    await tester.pumpAndSettle();

    expect(storage.saveCount, 1);
    expect(provider.activeMode, AppMode.student);
    expect(provider.acceptedPrivacyPolicyVersion, isNull);
    expect(provider.privacyPolicyAcceptedAt, isNull);
    expect(storage.data.activeMode, AppMode.student);
    expect(storage.data.privacyPolicyAcceptedVersion, isNull);
    expect(storage.data.privacyPolicyAcceptedAtIso, isNull);
    expect(provider.canWrite, isFalse);
    expect(find.byKey(const ValueKey('data-recovery-screen')), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'first launch privacy link opens without accepting and reports launch failure',
    (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_urlLauncherChannel, (call) async {
            calls.add(call);
            return true;
          });
      final storage = _MemoryTimetableStorage(_buildDefaultFirstLaunchData());
      final provider = TimetableProvider(
        storage: storage,
        systemLocaleCodeResolver: () => defaultLocaleCode,
        privacyService: const _NoopPrivacyService(),
        secretStore: const _NoopSecretStore(),
      );
      await provider.load();
      await _pumpAppHomeScreenWithProvider(tester, provider);

      final privacyConsent = find.byKey(
        const ValueKey('first-launch-privacy-consent'),
      );
      expect(privacyConsent, findsOneWidget);
      await tester.ensureVisible(privacyConsent);
      await tester.pumpAndSettle();
      final consentText = tester.widget<Text>(privacyConsent);
      final consentSpan = consentText.textSpan! as TextSpan;
      expect(consentSpan.children, everyElement(isA<TextSpan>()));
      final privacyLinkSpan = consentSpan.children![1] as TextSpan;
      expect(privacyLinkSpan.style?.decoration, isNull);
      SemanticsNode? findPrivacyLinkNode(SemanticsNode node) {
        final data = node.getSemanticsData();
        if (data.label == 'Privacy Policy') {
          return node;
        }
        SemanticsNode? result;
        node.visitChildren((child) {
          result = findPrivacyLinkNode(child);
          return result == null;
        });
        return result;
      }

      final privacyLinkNode = findPrivacyLinkNode(
        tester.getSemantics(privacyConsent),
      );
      expect(privacyLinkNode, isNotNull);
      final privacyLinkSemantics = privacyLinkNode!.getSemanticsData();
      expect(privacyLinkSemantics.flagsCollection.isLink, isTrue);
      expect(privacyLinkSemantics.hasAction(SemanticsAction.tap), isTrue);
      expect(
        find.descendant(
          of: privacyConsent,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is TextButton ||
                widget is FilledButton ||
                widget is OutlinedButton ||
                widget is InkWell,
          ),
        ),
        findsNothing,
      );

      await _tapInlineText(
        tester,
        privacyConsent,
        'By choosing a starting workspace',
      );
      await tester.pumpAndSettle();
      expect(calls, isEmpty);

      await _tapInlineText(tester, privacyConsent, 'Privacy Policy');
      await tester.pumpAndSettle();

      expect(
        calls.where(
          (call) => call.arguments.toString().contains(
            'https://sked.mashiro.tech/privacy.html',
          ),
        ),
        hasLength(1),
      );
      expect(storage.saveCount, 0);
      expect(provider.acceptedPrivacyPolicyVersion, isNull);
      expect(provider.privacyPolicyAcceptedAt, isNull);
      expect(
        find.byKey(const ValueKey('first-launch-onboarding')),
        findsOneWidget,
      );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_urlLauncherChannel, (_) async => false);
      await _tapInlineText(tester, privacyConsent, 'Privacy Policy');
      await tester.pumpAndSettle();

      expect(
        find.text('Unable to open the privacy policy link'),
        findsOneWidget,
      );
      expect(storage.saveCount, 0);
      expect(provider.acceptedPrivacyPolicyVersion, isNull);
      semanticsHandle.dispose();
    },
  );

  testWidgets('first launch privacy consent is one inline sentence', (
    tester,
  ) async {
    final provider = TimetableProvider(
      storage: _MemoryTimetableStorage(_buildDefaultFirstLaunchData()),
      systemLocaleCodeResolver: () => defaultLocaleCode,
      privacyService: const _NoopPrivacyService(),
      secretStore: const _NoopSecretStore(),
    );
    await provider.load();
    await _pumpAppHomeScreenWithProvider(
      tester,
      provider,
      locale: const Locale('zh'),
    );

    final privacyConsent = find.byKey(
      const ValueKey('first-launch-privacy-consent'),
    );
    expect(privacyConsent, findsOneWidget);
    final paragraph = tester.renderObject<RenderParagraph>(privacyConsent);
    final plainText = paragraph.text.toPlainText();
    expect(plainText, '选择起始工作区，即表示你已阅读并同意《隐私政策》。');

    final boxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: plainText.length),
    );
    expect(boxes, isNotEmpty);
    expect(boxes.map((box) => box.top.round()).toSet(), hasLength(1));
    expect(find.byIcon(Icons.privacy_tip_outlined), findsNothing);
  });

  testWidgets('first launch centers equal-height cards on a wide window', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1120, 680));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final provider = TimetableProvider(
      storage: _MemoryTimetableStorage(_buildDefaultFirstLaunchData()),
      systemLocaleCodeResolver: () => defaultLocaleCode,
      privacyService: const _NoopPrivacyService(),
      secretStore: const _NoopSecretStore(),
    );
    await provider.load();

    await _pumpAppHomeScreenWithProvider(tester, provider);

    _expectFirstLaunchCardsSideBySide(tester);
    final student = _firstLaunchRect(tester, 'first-launch-student-card');
    final general = _firstLaunchRect(tester, 'first-launch-general-card');
    expect((student.height - general.height).abs(), lessThan(1));

    final viewport = _firstLaunchRect(tester, 'first-launch-scroll-view');
    final content = _firstLaunchRect(tester, 'first-launch-content');
    expect(content.height, lessThan(viewport.height - 48));
    expect((content.center.dy - viewport.center.dy).abs(), lessThan(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('first launch stacks and centers cards on a phone window', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 776));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final provider = TimetableProvider(
      storage: _MemoryTimetableStorage(_buildDefaultFirstLaunchData()),
      systemLocaleCodeResolver: () => defaultLocaleCode,
      privacyService: const _NoopPrivacyService(),
      secretStore: const _NoopSecretStore(),
    );
    await provider.load();

    await _pumpAppHomeScreenWithProvider(
      tester,
      provider,
      locale: const Locale('zh'),
    );

    _expectFirstLaunchCardsStacked(tester);
    final student = _firstLaunchRect(tester, 'first-launch-student-card');
    final general = _firstLaunchRect(tester, 'first-launch-general-card');
    expect((student.width - general.width).abs(), lessThan(1));
    expect(student.left, closeTo(24, 0.1));
    expect(student.right, closeTo(406, 0.1));

    final viewport = _firstLaunchRect(tester, 'first-launch-scroll-view');
    final content = _firstLaunchRect(tester, 'first-launch-content');
    expect(content.height, lessThan(viewport.height - 48));
    expect((content.center.dy - viewport.center.dy).abs(), lessThan(1));

    final privacyConsent = find.byKey(
      const ValueKey('first-launch-privacy-consent'),
    );
    final paragraph = tester.renderObject<RenderParagraph>(privacyConsent);
    final plainText = paragraph.text.toPlainText();
    final boxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: plainText.length),
    );
    expect(boxes.map((box) => box.top.round()).toSet(), hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'first launch switches at 576 without resetting an in-flight choice',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(575, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final storage = _BlockingTimetableStorage(_buildDefaultFirstLaunchData());
      final provider = TimetableProvider(
        storage: storage,
        systemLocaleCodeResolver: () => defaultLocaleCode,
        privacyService: const _NoopPrivacyService(),
        secretStore: const _NoopSecretStore(),
      );
      await provider.load();
      await _pumpAppHomeScreenWithProvider(tester, provider);

      _expectFirstLaunchCardsStacked(tester);
      await tester.tap(find.byKey(const ValueKey('first-launch-student-card')));
      await storage.firstSaveStarted;
      await tester.pump();
      expect(storage.saveCount, 1);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('first-launch-student-card')),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );

      await tester.binding.setSurfaceSize(const Size(576, 1000));
      await tester.pump();
      _expectFirstLaunchCardsSideBySide(tester);
      expect(storage.saveCount, 1);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('first-launch-student-card')),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );

      await tester.binding.setSurfaceSize(const Size(575, 1000));
      await tester.pump();
      _expectFirstLaunchCardsStacked(tester);
      expect(storage.saveCount, 1);

      storage.completeSave();
      await tester.pumpAndSettle();
      expect(storage.saveCount, 1);
      expect(provider.activeMode, AppMode.student);
      expect(find.byKey(const ValueKey('student-home')), findsOneWidget);
    },
  );

  testWidgets('first launch uses compact spacing on a short wide window', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 360));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final provider = TimetableProvider(
      storage: _MemoryTimetableStorage(_buildDefaultFirstLaunchData()),
      systemLocaleCodeResolver: () => defaultLocaleCode,
      privacyService: const _NoopPrivacyService(),
      secretStore: const _NoopSecretStore(),
    );
    await provider.load();

    await _pumpAppHomeScreenWithProvider(tester, provider);

    _expectFirstLaunchCardsSideBySide(tester);
    final l10n = lookupAppLocalizations(const Locale('en'));
    final title = tester.getRect(find.text(l10n.firstLaunchTitle));
    final subtitle = tester.getRect(find.text(l10n.firstLaunchSubtitle));
    final student = _firstLaunchRect(tester, 'first-launch-student-card');
    final privacy = _firstLaunchRect(tester, 'first-launch-privacy-consent');
    expect(title.top, greaterThanOrEqualTo(16));
    expect(student.top - subtitle.bottom, closeTo(20, 0.1));
    expect(privacy.top - student.bottom, closeTo(16, 0.1));

    final scrollView = find.byKey(const ValueKey('first-launch-scroll-view'));
    final scrollable = find.descendant(
      of: scrollView,
      matching: find.byType(Scrollable),
    );
    expect(scrollable, findsOneWidget);
    final position = tester.state<ScrollableState>(scrollable).position;
    expect(position.maxScrollExtent, lessThanOrEqualTo(0.1));
    await tester.ensureVisible(
      find.byKey(const ValueKey('first-launch-privacy-consent')),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('first-launch-privacy-consent')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('large text forces a bounded stacked layout on wide windows', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1120, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final provider = TimetableProvider(
      storage: _MemoryTimetableStorage(_buildDefaultFirstLaunchData()),
      systemLocaleCodeResolver: () => defaultLocaleCode,
      privacyService: const _NoopPrivacyService(),
      secretStore: const _NoopSecretStore(),
    );
    await provider.load();

    await _pumpAppHomeScreenWithProvider(
      tester,
      provider,
      textScaler: TextScaler.linear(1.31),
    );

    _expectFirstLaunchCardsStacked(tester);
    final content = _firstLaunchRect(tester, 'first-launch-content');
    expect(content.width, closeTo(560, 0.1));
    expect(content.center.dx, closeTo(560, 0.1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('576 width keeps 1.3 text in a row with long descriptions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(576, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final provider = TimetableProvider(
      storage: _MemoryTimetableStorage(_buildDefaultFirstLaunchData()),
      systemLocaleCodeResolver: () => defaultLocaleCode,
      privacyService: const _NoopPrivacyService(),
      secretStore: const _NoopSecretStore(),
    );
    await provider.load();

    await _pumpAppHomeScreenWithProvider(
      tester,
      provider,
      locale: const Locale('de'),
      textScaler: TextScaler.linear(1.3),
    );

    _expectFirstLaunchCardsSideBySide(tester);
    final l10n = lookupAppLocalizations(const Locale('de'));
    final studentCard = _firstLaunchRect(tester, 'first-launch-student-card');
    final generalCard = _firstLaunchRect(tester, 'first-launch-general-card');
    expect(find.text(l10n.firstLaunchStartStudent), findsNothing);
    expect(find.text(l10n.firstLaunchStartGeneral), findsNothing);
    expect((studentCard.height - generalCard.height).abs(), lessThan(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('first launch onboarding fits narrow scaled Arabic layouts', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final provider = TimetableProvider(
      storage: _MemoryTimetableStorage(_buildDefaultFirstLaunchData()),
      systemLocaleCodeResolver: () => defaultLocaleCode,
      privacyService: const _NoopPrivacyService(),
      secretStore: const _NoopSecretStore(),
    );
    await provider.load();

    await _pumpAppHomeScreenWithProvider(
      tester,
      provider,
      locale: const Locale('ar'),
      textScaler: TextScaler.linear(1.8),
    );

    final onboarding = find.byKey(const ValueKey('first-launch-onboarding'));
    expect(onboarding, findsOneWidget);
    expect(tester.getSize(onboarding).width, 320);
    expect(Directionality.of(tester.element(onboarding)), TextDirection.rtl);
    final l10n = lookupAppLocalizations(const Locale('ar'));
    expect(find.text(l10n.firstLaunchTitle), findsOneWidget);
    expect(
      tester.getTopLeft(find.text(l10n.firstLaunchTitle)).dy,
      greaterThanOrEqualTo(16),
    );
    expect(find.text(l10n.firstLaunchStartStudent), findsNothing);
    expect(find.text(l10n.firstLaunchStartGeneral), findsNothing);
    _expectFirstLaunchCardsStacked(tester);
    final student = _firstLaunchRect(tester, 'first-launch-student-card');
    expect(student.left, closeTo(16, 0.1));
    expect(student.right, closeTo(304, 0.1));
    expect(
      find.byKey(const ValueKey('first-launch-privacy-consent')),
      findsOneWidget,
    );
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('first-launch-privacy-consent')),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('first-launch-privacy-consent')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('privacy consent waits for save before closing', (tester) async {
    final storage = _BlockingTimetableStorage(
      _buildPopulatedStudentData().copyWith(
        privacyPolicyAcceptedVersion: null,
        privacyPolicyAcceptedAtIso: null,
      ),
    );
    final provider = TimetableProvider(
      storage: storage,
      systemLocaleCodeResolver: () => defaultLocaleCode,
      privacyService: const _NoopPrivacyService(),
      secretStore: const _NoopSecretStore(),
    );
    await provider.load();
    provider.injectRemotePrivacyPolicyVersion('2026-05-25');

    await _pumpAppHomeScreenWithProvider(tester, provider);

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.text('Please agree to the privacy policy before using the app'),
      findsOneWidget,
    );

    final agreeButton = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(FilledButton),
    );
    expect(agreeButton, findsOneWidget);

    await tester.tap(agreeButton);
    await storage.firstSaveStarted;
    await tester.pump();

    expect(storage.saveCount, 1);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(tester.widget<FilledButton>(agreeButton).onPressed, isNull);

    await tester.tap(agreeButton, warnIfMissed: false);
    await tester.pump();

    expect(storage.saveCount, 1);
    expect(find.byType(AlertDialog), findsOneWidget);

    storage.completeSave();
    await tester.pumpAndSettle();

    expect(storage.saveCount, 1);
    expect(provider.hasAcceptedCurrentPrivacyPolicy, isTrue);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('privacy save failure closes its dialog and reveals recovery', (
    tester,
  ) async {
    final storage = _FailingTimetableStorage(
      _buildPopulatedStudentData().copyWith(
        privacyPolicyAcceptedVersion: null,
        privacyPolicyAcceptedAtIso: null,
      ),
    );
    final provider = TimetableProvider(
      storage: storage,
      systemLocaleCodeResolver: () => defaultLocaleCode,
      privacyService: const _NoopPrivacyService(),
      secretStore: const _NoopSecretStore(),
    );
    await provider.load();
    provider.injectRemotePrivacyPolicyVersion('2026-05-25');
    await _pumpAppHomeScreenWithProvider(tester, provider);

    final agreeButton = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(FilledButton),
    );
    await tester.tap(agreeButton);
    await tester.pumpAndSettle();

    expect(storage.saveCount, 1);
    expect(provider.canWrite, isFalse);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byKey(const ValueKey('data-recovery-screen')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('existing launch does not fetch a remote privacy version', (
    tester,
  ) async {
    final privacyService = _BlockingPrivacyService();
    final provider = TimetableProvider(
      storage: _MemoryTimetableStorage(
        _buildPopulatedStudentData().copyWith(
          privacyPolicyAcceptedVersion: bundledPrivacyPolicyVersion,
          privacyPolicyAcceptedAtIso: '2026-06-02T00:00:00.000',
        ),
      ),
      systemLocaleCodeResolver: () => defaultLocaleCode,
      privacyService: privacyService,
      secretStore: const _NoopSecretStore(),
    );
    await provider.load();

    await _pumpAppHomeScreenWithProvider(tester, provider, settle: false);
    await tester.pump(const Duration(milliseconds: 500));

    expect(privacyService.fetchCount, 0);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets(
    'newer persisted privacy acceptance remains valid without networking',
    (tester) async {
      final privacyService = _RecordingPrivacyService();
      final provider = TimetableProvider(
        storage: _MemoryTimetableStorage(
          _buildPopulatedStudentData().copyWith(
            privacyPolicyAcceptedVersion: '2026-09-01',
            privacyPolicyAcceptedAtIso: '2026-09-01T08:30:00.000Z',
          ),
        ),
        systemLocaleCodeResolver: () => defaultLocaleCode,
        privacyService: privacyService,
        secretStore: const _NoopSecretStore(),
      );
      await provider.load();

      await _pumpAppHomeScreenWithProvider(tester, provider, settle: false);
      await tester.pump(const Duration(milliseconds: 500));

      expect(provider.activePrivacyPolicyVersion, bundledPrivacyPolicyVersion);
      expect(provider.hasAcceptedCurrentPrivacyPolicy, isTrue);
      expect(privacyService.fetchCount, 0);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  test(
    'accepting the current policy does not downgrade newer acceptance',
    () async {
      const acceptedVersion = '2026-09-01';
      const acceptedAt = '2026-09-01T08:30:00.000Z';
      final storage = _MemoryTimetableStorage(
        _buildPopulatedStudentData().copyWith(
          privacyPolicyAcceptedVersion: acceptedVersion,
          privacyPolicyAcceptedAtIso: acceptedAt,
        ),
      );
      final provider = TimetableProvider(
        storage: storage,
        systemLocaleCodeResolver: () => defaultLocaleCode,
        privacyService: const _NoopPrivacyService(),
        secretStore: const _NoopSecretStore(),
      );
      await provider.load();

      await provider.acceptPrivacyPolicyCurrentVersion();

      expect(provider.acceptedPrivacyPolicyVersion, acceptedVersion);
      expect(provider.privacyPolicyAcceptedAt?.toIso8601String(), acceptedAt);
      expect(storage.data?.privacyPolicyAcceptedVersion, acceptedVersion);
      expect(storage.data?.privacyPolicyAcceptedAtIso, acceptedAt);
      expect(storage.saveCount, 0);
    },
  );

  test('privacy version comparison fails closed', () async {
    Future<TimetableProvider> providerWithAcceptedVersion(
      String version,
    ) async {
      final provider = TimetableProvider(
        storage: _MemoryTimetableStorage(
          _buildPopulatedStudentData().copyWith(
            privacyPolicyAcceptedVersion: version,
            privacyPolicyAcceptedAtIso: '2026-05-01T00:00:00.000Z',
          ),
        ),
        systemLocaleCodeResolver: () => defaultLocaleCode,
        privacyService: const _NoopPrivacyService(),
        secretStore: const _NoopSecretStore(),
      );
      await provider.load();
      return provider;
    }

    final invalid = await providerWithAcceptedVersion('2026-02-30');
    expect(invalid.hasAcceptedCurrentPrivacyPolicy, isFalse);

    final older = await providerWithAcceptedVersion('2026-05-01');
    expect(older.hasAcceptedCurrentPrivacyPolicy, isFalse);

    final accepted = await providerWithAcceptedVersion('2026-08-07');
    accepted.injectRemotePrivacyPolicyVersion('2026-09-01');
    expect(accepted.hasAcceptedCurrentPrivacyPolicy, isFalse);
  });

  test('active privacy policy version only moves forward', () async {
    final privacyService = _MutablePrivacyService();
    final provider = TimetableProvider(
      storage: _MemoryTimetableStorage(_buildPopulatedStudentData()),
      systemLocaleCodeResolver: () => defaultLocaleCode,
      privacyService: privacyService,
      secretStore: const _NoopSecretStore(),
    );
    await provider.load();

    privacyService.version = '2026-05-01';
    await provider.fetchRemotePrivacyPolicyVersion();
    expect(provider.activePrivacyPolicyVersion, bundledPrivacyPolicyVersion);

    privacyService.version = '2026-09-01';
    await provider.fetchRemotePrivacyPolicyVersion();
    expect(provider.activePrivacyPolicyVersion, '2026-09-01');

    privacyService.version = '2026-08-20';
    await provider.fetchRemotePrivacyPolicyVersion();
    provider.injectRemotePrivacyPolicyVersion('2026-08-15');
    expect(provider.activePrivacyPolicyVersion, '2026-09-01');
  });

  test('invalid active privacy policy version cannot be accepted', () async {
    final storage = _MemoryTimetableStorage(_buildPopulatedStudentData());
    final provider = TimetableProvider(
      storage: storage,
      systemLocaleCodeResolver: () => defaultLocaleCode,
      privacyService: const _NoopPrivacyService(),
      secretStore: const _NoopSecretStore(),
    );
    await provider.load();
    provider.injectRemotePrivacyPolicyVersion('invalid');

    expect(provider.hasAcceptedCurrentPrivacyPolicy, isFalse);
    await expectLater(
      provider.acceptPrivacyPolicyCurrentVersion(),
      throwsA(isA<StateError>()),
    );
    expect(storage.saveCount, 0);
  });

  testWidgets('start date picker ignores rapid duplicate taps', (tester) async {
    await _pumpHomeScreen(tester);

    final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
    scaffoldState.openDrawer();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Edit timetable'));
    await tester.pumpAndSettle();

    final startDateTile = find.text('Semester start date');
    expect(startDateTile, findsOneWidget);

    await tester.tap(startDateTile);
    await tester.tap(startDateTile, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(DatePickerDialog),
        matching: find.widgetWithText(TextButton, 'Cancel'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsNothing);
    expect(find.text('Test timetable'), findsWidgets);
  });

  testWidgets('timetable edit failure preserves its draft and allows retry', (
    tester,
  ) async {
    final storage = _MemoryTimetableStorage(_buildPopulatedStudentData())
      ..failSaves = true;
    final provider = TimetableProvider(
      storage: storage,
      systemLocaleCodeResolver: () => defaultLocaleCode,
      privacyService: const _NoopPrivacyService(),
      secretStore: const _NoopSecretStore(),
    );
    await provider.load();
    await _pumpHomeScreenWithProvider(tester, provider);

    tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit timetable'));
    await tester.pumpAndSettle();

    final nameField = find.byType(TextField).at(0);
    final weeksField = find.byType(TextField).at(1);
    await tester.enterText(nameField, 'Draft timetable');
    await tester.enterText(weeksField, '20');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(storage.saveCount, 1);
    expect(provider.activeTimetable.config.name, 'Test timetable');
    expect(find.text('Save failed. Please try again later.'), findsOneWidget);
    expect(
      tester.widget<TextField>(nameField).controller?.text,
      'Draft timetable',
    );
    expect(tester.widget<TextField>(weeksField).controller?.text, '20');
    expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);
    expect(tester.takeException(), isNull);

    storage.failSaves = false;
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(storage.saveCount, 2);
    expect(provider.activeTimetable.config.name, 'Draft timetable');
    expect(provider.activeTimetable.config.totalWeeks, 20);
    expect(find.widgetWithText(FilledButton, 'Save'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('timetable delete failure keeps confirmation open for retry', (
    tester,
  ) async {
    final storage = _MemoryTimetableStorage(_buildMultiTimetableStudentData())
      ..failSaves = true;
    final provider = TimetableProvider(
      storage: storage,
      systemLocaleCodeResolver: () => defaultLocaleCode,
      privacyService: const _NoopPrivacyService(),
      secretStore: const _NoopSecretStore(),
    );
    await provider.load();
    await _pumpHomeScreenWithProvider(tester, provider);

    tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit timetable').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();

    final confirmDelete = find.widgetWithText(FilledButton, 'Delete');
    await tester.tap(confirmDelete);
    await tester.pumpAndSettle();

    expect(storage.saveCount, 1);
    expect(provider.timetables, hasLength(2));
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Save failed. Please try again later.'), findsOneWidget);
    expect(tester.widget<FilledButton>(confirmDelete).onPressed, isNotNull);
    expect(tester.takeException(), isNull);

    storage.failSaves = false;
    await tester.tap(confirmDelete);
    await tester.pumpAndSettle();

    expect(storage.saveCount, 2);
    expect(provider.timetables, hasLength(1));
    expect(provider.timetables.single.config.name, 'First timetable');
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('add course entry ignores rapid duplicate taps', (tester) async {
    await _pumpHomeScreen(tester);

    final addCourseButton = find.byTooltip('Add course');
    expect(addCourseButton, findsOneWidget);

    await tester.tap(addCourseButton);
    await tester.tap(addCourseButton, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.byType(CourseEditorSheet), findsOneWidget);
    expect(find.text('Add course'), findsWidgets);
    final bottomSheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
    expect(bottomSheet.enableDrag, isFalse);
    expect(bottomSheet.showDragHandle, isFalse);
    final title = find.descendant(
      of: find.byType(CourseEditorSheet),
      matching: find.text('Add course'),
    );
    expect(title, findsOneWidget);
    final sheetRect = tester.getRect(find.byType(BottomSheet));
    expect(
      tester.getTopLeft(title).dy - sheetRect.top,
      greaterThanOrEqualTo(20),
    );
  });

  testWidgets('student timetable fits narrow width with long course text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final provider = TimetableProvider(
      storage: _MemoryTimetableStorage(_buildLongCourseStudentData()),
      systemLocaleCodeResolver: () => defaultLocaleCode,
      privacyService: const _NoopPrivacyService(),
      secretStore: const _NoopSecretStore(),
    );
    await provider.load();

    await _pumpHomeScreenWithProvider(tester, provider);

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(
      find.text(
        'Advanced interdisciplinary seminar with an extremely long course name',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('week picker ignores rapid duplicate title taps', (tester) async {
    final provider = await _pumpHomeScreen(tester);

    final weekTitle = find.text(_selectedWeekTitle(provider));
    expect(weekTitle, findsOneWidget);

    await tester.tap(weekTitle);
    await tester.tap(weekTitle, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Jump to week'), findsOneWidget);
  });

  testWidgets('empty state new timetable ignores rapid duplicate taps', (
    tester,
  ) async {
    final storage = _BlockingTimetableStorage(null);
    final provider = await _createEmptyProvider(storage);

    await _pumpHomeScreenWithProvider(tester, provider);

    expect(provider.timetables, isEmpty);
    expect(find.text('No timetable yet'), findsOneWidget);

    final createButton = find.widgetWithText(FilledButton, 'New timetable');
    expect(createButton, findsOneWidget);

    await tester.tap(createButton);
    await tester.tap(createButton, warnIfMissed: false);
    await storage.firstSaveStarted;

    expect(storage.saveCount, 1);
    expect(provider.timetables, hasLength(1));

    storage.completeSave();
    await tester.pumpAndSettle();

    expect(storage.saveCount, 1);
    expect(provider.timetables, hasLength(1));
    expect(find.text(_selectedWeekTitle(provider)), findsOneWidget);
  });

  testWidgets('empty timetable keeps the settings entry available', (
    tester,
  ) async {
    final storage = _BlockingTimetableStorage(null);
    final provider = await _createEmptyProvider(storage);

    await _pumpHomeScreenWithProvider(tester, provider);

    expect(provider.timetables, isEmpty);
    expect(find.text('No timetable yet'), findsOneWidget);
    final settingsButton = find.byTooltip('Settings');
    expect(settingsButton, findsOneWidget);

    await tester.tap(settingsButton);
    await tester.tap(settingsButton, warnIfMissed: false);
    await _pumpRouteTransition(tester);

    expect(find.byType(SettingsPage, skipOffstage: false), findsOneWidget);
  });

  testWidgets('new timetable failure rolls back and can be retried', (
    tester,
  ) async {
    final storage = _MemoryTimetableStorage(_buildDefaultFirstLaunchData())
      ..failSaves = true;
    final provider = TimetableProvider(
      storage: storage,
      systemLocaleCodeResolver: () => defaultLocaleCode,
      privacyService: const _NoopPrivacyService(),
      secretStore: const _NoopSecretStore(),
    );
    await provider.load();
    await _pumpHomeScreenWithProvider(tester, provider);

    final createButton = find.widgetWithText(FilledButton, 'New timetable');
    await tester.tap(createButton);
    await tester.pumpAndSettle();

    expect(storage.saveCount, 1);
    expect(provider.timetables, isEmpty);
    expect(find.text('Save failed. Please try again later.'), findsOneWidget);
    expect(tester.takeException(), isNull);

    storage.failSaves = false;
    await tester.tap(createButton);
    await tester.pumpAndSettle();

    expect(storage.saveCount, 2);
    expect(provider.timetables, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('drawer new timetable ignores rapid duplicate taps', (
    tester,
  ) async {
    final storage = _BlockingTimetableStorage(_buildPopulatedStudentData());
    final provider = TimetableProvider(
      storage: storage,
      systemLocaleCodeResolver: () => defaultLocaleCode,
      privacyService: const _NoopPrivacyService(),
      secretStore: const _NoopSecretStore(),
    );
    await provider.load();

    await _pumpHomeScreenWithProvider(tester, provider);

    expect(provider.timetables, hasLength(1));

    final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
    scaffoldState.openDrawer();
    await tester.pumpAndSettle();

    final createButton = find.widgetWithText(FilledButton, 'New timetable');
    expect(createButton, findsOneWidget);

    await tester.tap(createButton);
    await tester.tap(createButton, warnIfMissed: false);
    await storage.firstSaveStarted;

    expect(storage.saveCount, 1);
    expect(provider.timetables, hasLength(2));

    storage.completeSave();
    await tester.pumpAndSettle();

    expect(storage.saveCount, 1);
    expect(provider.timetables, hasLength(2));
  });

  testWidgets('drawer timetable switch ignores rapid duplicate taps', (
    tester,
  ) async {
    final storage = _BlockingTimetableStorage(
      _buildMultiTimetableStudentData(),
    );
    final provider = TimetableProvider(
      storage: storage,
      systemLocaleCodeResolver: () => defaultLocaleCode,
      privacyService: const _NoopPrivacyService(),
      secretStore: const _NoopSecretStore(),
    );
    await provider.load();

    await _pumpHomeScreenWithProvider(tester, provider);

    expect(provider.activeTimetable.config.name, 'First timetable');

    final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
    scaffoldState.openDrawer();
    await tester.pumpAndSettle();

    final secondTimetable = find.text('Second timetable');
    expect(secondTimetable, findsOneWidget);

    await tester.tap(secondTimetable);
    await storage.firstSaveStarted;
    await tester.tap(secondTimetable, warnIfMissed: false);

    expect(storage.saveCount, 1);
    expect(provider.activeTimetable.config.name, 'Second timetable');

    storage.completeSave();
    await tester.pumpAndSettle();

    expect(storage.saveCount, 1);
    expect(provider.activeTimetable.config.name, 'Second timetable');
    expect(find.text('Second timetable'), findsOneWidget);
  });

  testWidgets('failed timetable switch keeps the drawer open for retry', (
    tester,
  ) async {
    final storage = _MemoryTimetableStorage(_buildMultiTimetableStudentData())
      ..failSaves = true;
    final provider = TimetableProvider(
      storage: storage,
      systemLocaleCodeResolver: () => defaultLocaleCode,
      privacyService: const _NoopPrivacyService(),
      secretStore: const _NoopSecretStore(),
    );
    await provider.load();
    await _pumpHomeScreenWithProvider(tester, provider);

    tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
    await tester.pumpAndSettle();
    final secondTimetable = find.text('Second timetable');
    await tester.tap(secondTimetable);
    await tester.pumpAndSettle();

    expect(storage.saveCount, 1);
    expect(provider.activeTimetable.config.name, 'First timetable');
    expect(find.byType(Drawer), findsOneWidget);
    expect(find.text('Save failed. Please try again later.'), findsOneWidget);
    expect(tester.takeException(), isNull);

    storage.failSaves = false;
    await tester.tap(secondTimetable);
    await tester.pumpAndSettle();

    expect(storage.saveCount, 2);
    expect(provider.activeTimetable.config.name, 'Second timetable');
    expect(find.byType(Drawer), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('drawer current timetable tap cannot pop parent route', (
    tester,
  ) async {
    final provider = await _createProvider();
    await _pumpHomeScreenHostPage(tester, provider);

    await tester.tap(find.text('Open home host'));
    await _pumpRouteTransition(tester);

    expect(find.text(_selectedWeekTitle(provider)), findsOneWidget);

    final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
    scaffoldState.openDrawer();
    await tester.pumpAndSettle();

    final currentTimetable = find.text('Test timetable').last;
    expect(currentTimetable, findsOneWidget);

    await tester.tap(currentTimetable);
    await tester.tap(currentTimetable, warnIfMissed: false);
    await _pumpRouteTransition(tester);

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(Drawer), findsNothing);
    expect(find.text(_selectedWeekTitle(provider)), findsOneWidget);
    expect(find.text('Open home host'), findsNothing);
    expect(find.text('Open home host', skipOffstage: false), findsOneWidget);
  });

  testWidgets('settings entry ignores rapid duplicate taps', (tester) async {
    await _pumpHomeScreen(tester);

    final settingsButton = find.byTooltip('Settings');
    expect(settingsButton, findsOneWidget);

    await tester.tap(settingsButton);
    await tester.tap(settingsButton, warnIfMissed: false);
    await _pumpRouteTransition(tester);

    expect(find.byType(SettingsPage, skipOffstage: false), findsOneWidget);
  });

  testWidgets('JSON text import entry ignores rapid duplicate taps', (
    tester,
  ) async {
    final storage = _BlockingTimetableStorage(null);
    final provider = await _createEmptyProvider(storage);

    await _pumpHomeScreenWithProvider(tester, provider);

    final textImportButton = find.widgetWithText(
      OutlinedButton,
      'Import timetable from JSON text',
    );
    expect(textImportButton, findsOneWidget);

    await tester.tap(textImportButton);
    await tester.tap(textImportButton, warnIfMissed: false);
    await _pumpRouteTransition(tester);

    expect(find.byType(TextImportPage, skipOffstage: false), findsOneWidget);
  });

  testWidgets('school web import entry ignores rapid duplicate taps', (
    tester,
  ) async {
    final storage = _BlockingTimetableStorage(null);
    final provider = await _createEmptyProvider(storage);

    await _pumpHomeScreenWithProvider(tester, provider);

    final webImportButton = find.widgetWithText(
      OutlinedButton,
      'Import from school webpage',
    );
    expect(webImportButton, findsOneWidget);

    await tester.tap(webImportButton);
    await tester.tap(webImportButton, warnIfMissed: false);
    await _pumpRouteTransition(tester);

    expect(find.byType(SchoolSitesPage, skipOffstage: false), findsOneWidget);
  });
}
