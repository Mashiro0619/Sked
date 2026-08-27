import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/l10n/app_locale.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
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
import 'package:sked/widgets/sked_expressive_components.dart';
import 'package:sked/widgets/text_transfer_widgets.dart';
import 'package:sked/widgets/timetable_grid.dart';

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

AppData _buildMultiPeriodTimeSetStudentData() {
  final data = _buildPopulatedStudentData();
  return data.copyWith(
    studentMode: data.studentMode.copyWith(
      periodTimeSets: [
        ...data.studentMode.periodTimeSets,
        PeriodTimeSet(
          id: 'period-set-2',
          name: 'Evening periods',
          periodTimes: const [
            CoursePeriodTime(
              index: 1,
              startMinutes: 18 * 60,
              endMinutes: 18 * 60 + 45,
            ),
          ],
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
        name: 'Advanced interdisciplinary seminar with an extremely long course name',
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
  TimetableProvider provider, {
  TextScaler textScaler = TextScaler.noScaling,
  Locale locale = const Locale('en'),
  TextDirection? textDirection,
  bool active = true,
  bool interactive = true,
  bool showSettingsAction = true,
  bool settle = true,
}) async {
  await _resetWidgetTree(tester);
  await tester.pumpWidget(
    ChangeNotifierProvider<TimetableProvider>.value(
      value: provider,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) {
          Widget result = MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: child ?? const SizedBox.shrink(),
          );
          if (textDirection != null) {
            result = Directionality(
              textDirection: textDirection,
              child: result,
            );
          }
          return result;
        },
        home: HomeScreen(
          key: UniqueKey(),
          active: active,
          interactive: interactive,
          showSettingsAction: showSettingsAction,
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
        localizationsDelegates: appLocalizationsDelegates,
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

Future<void> _openTimetablePicker(WidgetTester tester) async {
  await tester.tap(
    find.byKey(const ValueKey('student-timetable-picker-button')),
  );
  await tester.pumpAndSettle();
}

Future<void> _saveTimetableDialog(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Save'));
}

String _selectedWeekTitle(TimetableProvider provider) {
  return 'Week ${provider.selectedWeek}';
}

Rect _emptyTimetableImportMenuRect(WidgetTester tester) {
  final itemRects = [
    tester.getRect(find.byKey(const ValueKey('empty-timetable-import-files'))),
    tester.getRect(find.byKey(const ValueKey('empty-timetable-import-text'))),
    tester.getRect(find.byKey(const ValueKey('empty-timetable-import-web'))),
  ];
  return itemRects.skip(1).fold(itemRects.first, (rect, itemRect) {
    return rect.expandToInclude(itemRect);
  });
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
      find.text('Manage categories, events, reminders, and JSON / ICS data.'),
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

  testWidgets('custom timetable layout settings skip first-launch onboarding', (
    tester,
  ) async {
    final data = _buildDefaultFirstLaunchData();
    final provider = TimetableProvider(
      storage: _MemoryTimetableStorage(
        data.copyWith(
          studentMode: data.studentMode.copyWith(
            enableWeekSwipeNavigation: false,
          ),
        ),
      ),
      systemLocaleCodeResolver: () => defaultLocaleCode,
      privacyService: const _NoopPrivacyService(),
      secretStore: const _NoopSecretStore(),
    );
    await provider.load();

    await _pumpAppHomeScreenWithProvider(tester, provider);

    expect(find.byKey(const ValueKey('first-launch-onboarding')), findsNothing);
    expect(find.byKey(const ValueKey('student-home')), findsOneWidget);
  });

  for (final scenario in <({String name, AppData Function(AppData) update})>[
    (
      name: 'course',
      update: (data) => data.copyWith(
        studentMode: data.studentMode.copyWith(enableLongPressAddCourse: false),
      ),
    ),
    (
      name: 'event',
      update: (data) => data.copyWith(
        generalMode: data.generalMode.copyWith(enableLongPressAddEvent: false),
      ),
    ),
  ]) {
    testWidgets(
      'disabled long-press ${scenario.name} add skips first-launch onboarding',
      (tester) async {
        final data = scenario.update(_buildDefaultFirstLaunchData());
        final provider = TimetableProvider(
          storage: _MemoryTimetableStorage(data),
          systemLocaleCodeResolver: () => defaultLocaleCode,
          privacyService: const _NoopPrivacyService(),
          secretStore: const _NoopSecretStore(),
        );
        await provider.load();

        await _pumpAppHomeScreenWithProvider(tester, provider);

        expect(
          find.byKey(const ValueKey('first-launch-onboarding')),
          findsNothing,
        );
        expect(find.byKey(const ValueKey('student-home')), findsOneWidget);
      },
    );
  }

  testWidgets('collapsed all-day timeline skips first-launch onboarding', (
    tester,
  ) async {
    final data = _buildDefaultFirstLaunchData();
    final provider = TimetableProvider(
      storage: _MemoryTimetableStorage(
        data.copyWith(
          generalMode: data.generalMode.copyWith(allDayTimelineCollapsed: true),
        ),
      ),
      systemLocaleCodeResolver: () => defaultLocaleCode,
      privacyService: const _NoopPrivacyService(),
      secretStore: const _NoopSecretStore(),
    );
    await provider.load();

    await _pumpAppHomeScreenWithProvider(tester, provider);

    expect(provider.allDayTimelineCollapsed, isTrue);
    expect(find.byKey(const ValueKey('first-launch-onboarding')), findsNothing);
    expect(find.byKey(const ValueKey('student-home')), findsOneWidget);
  });

  testWidgets('collapsed workspace navigation skips first-launch onboarding', (
    tester,
  ) async {
    final data = _buildDefaultFirstLaunchData();
    final provider = TimetableProvider(
      storage: _MemoryTimetableStorage(
        data.copyWith(homeWorkspaceNavigationCollapsed: true),
      ),
      systemLocaleCodeResolver: () => defaultLocaleCode,
      privacyService: const _NoopPrivacyService(),
      secretStore: const _NoopSecretStore(),
    );
    await provider.load();

    await _pumpAppHomeScreenWithProvider(tester, provider);

    expect(provider.homeWorkspaceNavigationCollapsed, isTrue);
    expect(find.byKey(const ValueKey('first-launch-onboarding')), findsNothing);
    expect(find.byKey(const ValueKey('student-home')), findsOneWidget);
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
        expect(storage.data?.hideHomeWorkspaceNavigation, isFalse);
        expect(storage.data?.homeWorkspaceNavigationCollapsed, isTrue);
        expect(
          storage.data?.privacyPolicyAcceptedVersion,
          bundledPrivacyPolicyVersion,
        );
        expect(
          DateTime.tryParse(storage.data?.privacyPolicyAcceptedAtIso ?? ''),
          isNotNull,
        );
        expect(provider.activeMode, scenario.mode);
        expect(provider.hideHomeWorkspaceNavigation, isFalse);
        expect(provider.homeWorkspaceNavigationCollapsed, isTrue);
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

  testWidgets(
    'first launch derives navigation defaults from the current window width',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final scenario in <({double width, bool hidden})>[
        (width: 599, hidden: true),
        (width: 600, hidden: false),
        (width: 1199, hidden: false),
        (width: 1200, hidden: false),
      ]) {
        final storage = _MemoryTimetableStorage(_buildDefaultFirstLaunchData());
        final provider = TimetableProvider(
          storage: storage,
          systemLocaleCodeResolver: () => defaultLocaleCode,
          privacyService: const _NoopPrivacyService(),
          secretStore: const _NoopSecretStore(),
        );
        addTearDown(provider.dispose);
        await provider.load();
        storage.saveCount = 0;

        await _pumpAppHomeScreenWithProvider(tester, provider);
        tester.view.physicalSize = Size(scenario.width, 800);
        await tester.pumpAndSettle();
        expect(
          MediaQuery.sizeOf(
            tester.element(
              find.byKey(const ValueKey('first-launch-onboarding')),
            ),
          ).width,
          scenario.width,
          reason: 'width=${scenario.width}',
        );
        await tester.tap(
          find.byKey(const ValueKey('first-launch-student-card')),
        );
        await tester.pumpAndSettle();

        expect(storage.saveCount, 1, reason: 'width=${scenario.width}');
        expect(
          provider.hideHomeWorkspaceNavigation,
          scenario.hidden,
          reason: 'width=${scenario.width}',
        );
        expect(
          provider.homeWorkspaceNavigationCollapsed,
          isTrue,
          reason: 'width=${scenario.width}',
        );
      }
    },
  );

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
    expect(provider.hideHomeWorkspaceNavigation, isFalse);
    expect(provider.homeWorkspaceNavigationCollapsed, isFalse);
    expect(storage.data.activeMode, AppMode.student);
    expect(storage.data.privacyPolicyAcceptedVersion, isNull);
    expect(storage.data.privacyPolicyAcceptedAtIso, isNull);
    expect(storage.data.hideHomeWorkspaceNavigation, isFalse);
    expect(storage.data.homeWorkspaceNavigationCollapsed, isFalse);
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

  testWidgets('first launch onboarding fits narrow scaled localized layouts', (
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
      locale: const Locale('de'),
      textScaler: TextScaler.linear(1.8),
    );

    final onboarding = find.byKey(const ValueKey('first-launch-onboarding'));
    expect(onboarding, findsOneWidget);
    expect(tester.getSize(onboarding).width, 320);
    expect(Directionality.of(tester.element(onboarding)), TextDirection.ltr);
    final l10n = lookupAppLocalizations(const Locale('de'));
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

    await _openTimetablePicker(tester);

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

    await _openTimetablePicker(tester);
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
    expect(find.text('Switch timetables'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('timetable edit success updates the row and keeps picker open', (
    tester,
  ) async {
    final storage = _MemoryTimetableStorage(_buildMultiTimetableStudentData());
    final provider = TimetableProvider(
      storage: storage,
      systemLocaleCodeResolver: () => defaultLocaleCode,
      privacyService: const _NoopPrivacyService(),
      secretStore: const _NoopSecretStore(),
    );
    await provider.load();
    await _pumpHomeScreenWithProvider(tester, provider);

    await _openTimetablePicker(tester);
    await tester.tap(find.byTooltip('Edit timetable').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Renamed timetable');
    await _saveTimetableDialog(tester);
    await tester.pumpAndSettle();

    expect(storage.saveCount, 1);
    expect(find.text('Switch timetables'), findsOneWidget);
    expect(find.text('Renamed timetable'), findsOneWidget);
    expect(provider.timetables.last.config.name, 'Renamed timetable');
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

    await _openTimetablePicker(tester);
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
    expect(find.text('Switch timetables'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('deleting the last timetable closes the empty picker', (
    tester,
  ) async {
    final storage = _MemoryTimetableStorage(_buildPopulatedStudentData());
    final provider = TimetableProvider(
      storage: storage,
      systemLocaleCodeResolver: () => defaultLocaleCode,
      privacyService: const _NoopPrivacyService(),
      secretStore: const _NoopSecretStore(),
    );
    await provider.load();
    await _pumpHomeScreenWithProvider(tester, provider);

    await _openTimetablePicker(tester);
    await tester.tap(find.byTooltip('Edit timetable'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(storage.saveCount, 1);
    expect(provider.timetables, isEmpty);
    expect(find.text('Switch timetables'), findsNothing);
    expect(find.text('No timetable yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('add course entry ignores rapid duplicate taps', (tester) async {
    await _pumpHomeScreen(tester);

    final addCourseButton = find.byTooltip('Add course');
    expect(addCourseButton, findsOneWidget);
    expect(find.byType(SkedPrimaryFab), findsOneWidget);
    expect(
      tester
          .widgetList<TimetableGrid>(find.byType(TimetableGrid))
          .map((grid) => grid.bottomContentInset),
      everyElement(80),
    );

    await tester.tap(addCourseButton);
    await tester.tap(addCourseButton, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.byType(CourseEditorSheet), findsOneWidget);
    expect(find.byType(SkedPrimaryFab), findsNothing);
    expect(
      tester
          .widgetList<TimetableGrid>(find.byType(TimetableGrid))
          .map((grid) => grid.bottomContentInset),
      everyElement(0),
    );
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

  testWidgets('student workspace opens in week view and keeps selection once', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 776));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final provider = await _createProvider();
    await _pumpHomeScreenWithProvider(tester, provider);

    expect(find.byKey(const ValueKey('student-day-strip')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('student-view-toggle-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('student-day-strip')), findsOneWidget);

    await tester.binding.setSurfaceSize(const Size(1120, 680));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('student-day-strip')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide student workspace initially uses week view', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1120, 680));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final provider = await _createProvider();
    await _pumpHomeScreenWithProvider(tester, provider);

    expect(find.byKey(const ValueKey('student-day-strip')), findsNothing);
    expect(find.byType(SkedPrimaryFab), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'wide timetable toolbar anchors the selector to the leading edge',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final provider = await _createProvider();
      addTearDown(provider.dispose);
      await _pumpHomeScreenWithProvider(tester, provider);

      final toolbar = tester.getRect(
        find.byKey(const ValueKey('student-workspace-toolbar')),
      );
      final selector = tester.getRect(
        find.byKey(const ValueKey('student-timetable-picker-button')),
      );
      final settings = tester.getRect(
        find.byKey(const ValueKey('student-settings-button')),
      );

      expect(selector.left, lessThan(toolbar.center.dx));
      expect(selector.left, lessThanOrEqualTo(toolbar.left + 32));
      expect(settings.right, greaterThan(toolbar.center.dx));
      expect(selector.center.dy, closeTo(settings.center.dy, 1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('compact timetable selector uses the remaining toolbar width', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(581, 776));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final base = _buildPopulatedStudentData();
    final provider = TimetableProvider(
      storage: _MemoryTimetableStorage(
        base.copyWith(
          studentMode: base.studentMode.copyWith(
            hiddenToolbarNavigationIds: const ['week'],
          ),
        ),
      ),
      systemLocaleCodeResolver: () => defaultLocaleCode,
      privacyService: const _NoopPrivacyService(),
      secretStore: const _NoopSecretStore(),
    );
    await provider.load();
    addTearDown(provider.dispose);
    await _pumpHomeScreenWithProvider(tester, provider);

    final selector = tester.getRect(
      find.byKey(const ValueKey('student-timetable-picker-button')),
    );
    final view = tester.getRect(
      find.byKey(const ValueKey('student-view-toggle-button')),
    );
    final settings = tester.getRect(
      find.byKey(const ValueKey('student-settings-button')),
    );

    expect(selector.width, greaterThan(400));
    expect(selector.right, closeTo(view.left - 4, 0.01));
    expect(view.right, closeTo(settings.left - 4, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('large text does not change the initial week view', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final provider = await _createProvider();
    await _pumpHomeScreenWithProvider(
      tester,
      provider,
      textScaler: const TextScaler.linear(1.8),
    );

    expect(find.byKey(const ValueKey('student-day-strip')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact large-text toolbar keeps every primary action visible', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final provider = await _createProvider();
    await _pumpHomeScreenWithProvider(
      tester,
      provider,
      locale: const Locale('de'),
      textScaler: const TextScaler.linear(1.8),
    );

    final viewport = Offset.zero & const Size(320, 568);
    for (final key in const [
      'student-timetable-picker-button',
      'student-view-toggle-button',
      'student-week-picker-button',
      'student-settings-button',
    ]) {
      final rect = tester.getRect(find.byKey(ValueKey(key)));
      expect(viewport.contains(rect.topLeft), isTrue, reason: key);
      expect(viewport.contains(rect.bottomRight), isTrue, reason: key);
      expect(rect.height, greaterThanOrEqualTo(48), reason: key);
    }
    for (final removedKey in const [
      'student-day-week-selector',
      'student-previous-week',
      'student-today-button',
      'student-next-week',
    ]) {
      expect(find.byKey(ValueKey(removedKey)), findsNothing);
    }
    expect(
      find.byKey(const ValueKey('student-display-settings-button')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('student-settings-button')),
      findsOneWidget,
    );
    final timetablePicker = find.byKey(
      const ValueKey('student-timetable-picker-button'),
    );
    expect(
      find.descendant(
        of: timetablePicker,
        matching: find.byIcon(Icons.keyboard_arrow_down_rounded),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  Future<void> switchStudentToDayView(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('student-view-toggle-button')));
    await tester.pumpAndSettle();
  }

  testWidgets('student toolbar and day strip use compact phone metrics', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 776));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final provider = await _createProvider();
    await _pumpHomeScreenWithProvider(tester, provider);
    await switchStudentToDayView(tester);

    final selectorRect = tester.getRect(
      find.byKey(const ValueKey('student-view-toggle-button')),
    );
    final stripRect = tester.getRect(
      find.byKey(const ValueKey('student-day-strip')),
    );
    final mondayRect = tester.getRect(
      find.byKey(const ValueKey('student-day-1')),
    );
    final tuesdayRect = tester.getRect(
      find.byKey(const ValueKey('student-day-2')),
    );

    expect(selectorRect.size, const Size.square(48));
    expect(stripRect.height, closeTo(60, 0.01));
    expect(mondayRect.width, closeTo((stripRect.width - 12) / 7, 0.01));
    expect(tuesdayRect.left - mondayRect.right, closeTo(2, 0.01));
    expect(
      find.byKey(const ValueKey('student-display-settings-button')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('student navigation adapts across target window sizes', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final provider = await _createProvider();
    addTearDown(provider.dispose);
    final scenarios = [
      (size: const Size(390, 844), locale: const Locale('zh'), scale: 1.0),
      (size: const Size(575, 776), locale: const Locale('de'), scale: 1.3),
      (size: const Size(576, 776), locale: const Locale('en'), scale: 1.0),
      (size: const Size(900, 360), locale: const Locale('de'), scale: 1.0),
      (size: const Size(1120, 680), locale: const Locale('en'), scale: 1.0),
    ];

    for (final scenario in scenarios) {
      await tester.binding.setSurfaceSize(scenario.size);
      await _pumpHomeScreenWithProvider(
        tester,
        provider,
        locale: scenario.locale,
        textScaler: TextScaler.linear(scenario.scale),
      );

      final viewport = Offset.zero & scenario.size;
      for (final key in const [
        'student-timetable-picker-button',
        'student-view-toggle-button',
        'student-week-picker-button',
        'student-settings-button',
      ]) {
        final rect = tester.getRect(find.byKey(ValueKey(key)));
        expect(
          viewport.contains(rect.topLeft),
          true,
          reason: '$key ${scenario.size}',
        );
        expect(
          viewport.contains(rect.bottomRight),
          true,
          reason: '$key ${scenario.size}',
        );
        expect(rect.height, greaterThanOrEqualTo(48), reason: key);
      }

      final timetablePicker = tester.getRect(
        find.byKey(const ValueKey('student-timetable-picker-button')),
      );
      final settings = tester.getRect(
        find.byKey(const ValueKey('student-settings-button')),
      );
      expect(timetablePicker.center.dy, closeTo(settings.center.dy, 0.01));
      final viewToggle = tester.getRect(
        find.byKey(const ValueKey('student-view-toggle-button')),
      );
      final weekPicker = tester.getRect(
        find.byKey(const ValueKey('student-week-picker-button')),
      );
      expect(viewToggle.center.dy, closeTo(weekPicker.center.dy, 0.01));
      expect(
        weekPicker.right,
        lessThanOrEqualTo(viewToggle.left),
        reason: 'week picker should precede the view toggle',
      );
      for (final removedKey in const [
        'student-day-week-selector',
        'student-previous-week',
        'student-today-button',
        'student-next-week',
      ]) {
        expect(find.byKey(ValueKey(removedKey)), findsNothing);
      }
      expect(
        find.byKey(const ValueKey('student-display-settings-button')),
        findsNothing,
      );
      expect(tester.takeException(), isNull, reason: '${scenario.size}');
    }
  });

  testWidgets('student pager stays full height and FAB has no backing layer', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 776));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final provider = await _createProvider();
    await _pumpHomeScreenWithProvider(tester, provider);

    final pagerRect = tester.getRect(
      find.byKey(const ValueKey('student-week-pager')),
    );
    final fabFinder = find.byType(FloatingActionButton);
    final fabRect = tester.getRect(fabFinder);
    final fab = tester.widget<FloatingActionButton>(fabFinder);
    final colors = Theme.of(tester.element(fabFinder)).colorScheme;

    expect(pagerRect.bottom, closeTo(776, 0.01));
    expect(fabRect.size, const Size.square(56));
    expect(fabRect.right, closeTo(pagerRect.right - 12, 0.01));
    expect(fabRect.bottom, closeTo(760, 0.01));
    expect(fab.backgroundColor, colors.primary);
    expect(fab.foregroundColor, colors.onPrimary);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keyboard and inactive workspace clear FAB avoidance', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 776));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final provider = await _createProvider();

    final physicalKeyboardInset = 280 * tester.view.devicePixelRatio;
    tester.view.viewInsets = FakeViewPadding(bottom: physicalKeyboardInset);
    addTearDown(tester.view.reset);
    await _pumpHomeScreenWithProvider(tester, provider);
    expect(find.byType(SkedPrimaryFab), findsNothing);
    expect(
      tester
          .widgetList<TimetableGrid>(find.byType(TimetableGrid))
          .map((grid) => grid.bottomContentInset),
      everyElement(0),
    );

    tester.view.reset();
    await _pumpHomeScreenWithProvider(tester, provider, active: false);
    expect(find.byType(SkedPrimaryFab), findsNothing);
    expect(
      tester
          .widgetList<TimetableGrid>(find.byType(TimetableGrid))
          .map((grid) => grid.bottomContentInset),
      everyElement(0),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('course FAB preference immediately updates grid avoidance', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 776));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final provider = await _createProvider();
    addTearDown(provider.dispose);
    await _pumpHomeScreenWithProvider(tester, provider);

    expect(find.byType(SkedPrimaryFab), findsOneWidget);
    expect(
      tester
          .widgetList<TimetableGrid>(find.byType(TimetableGrid))
          .map((grid) => grid.bottomContentInset),
      everyElement(80),
    );

    await provider.updateShowAddCourseFab(false);
    await tester.pumpAndSettle();

    expect(find.byType(SkedPrimaryFab), findsNothing);
    expect(
      tester
          .widgetList<TimetableGrid>(find.byType(TimetableGrid))
          .map((grid) => grid.bottomContentInset),
      everyElement(0),
    );

    await provider.updateShowAddCourseFab(true);
    await tester.pumpAndSettle();

    expect(find.byType(SkedPrimaryFab), findsOneWidget);
    expect(
      tester
          .widgetList<TimetableGrid>(find.byType(TimetableGrid))
          .map((grid) => grid.bottomContentInset),
      everyElement(80),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('rapid keyboard week commands settle on the latest request', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1120, 680));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final provider = await _createProvider();
    await provider.setSelectedWeek(5);
    await _pumpHomeScreenWithProvider(tester, provider);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();

    expect(provider.selectedWeek, 6);
    expect(find.text('Week 6'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('RTL week shortcuts follow the visible spatial direction', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1120, 680));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final provider = await _createProvider();
    await provider.setSelectedWeek(5);
    await _pumpHomeScreenWithProvider(
      tester,
      provider,
      textDirection: TextDirection.rtl,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(provider.selectedWeek, 6);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(provider.selectedWeek, 5);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long pressing the week picker jumps to the current week', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 776));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final provider = await _createProvider();
    await provider.setSelectedWeek(1);
    await _pumpHomeScreenWithProvider(tester, provider);

    final expectedWeek = currentWeekFor(provider.activeTimetable.config);
    await tester.longPress(
      find.byKey(const ValueKey('student-week-picker-button')),
    );
    await tester.pumpAndSettle();

    expect(provider.selectedWeek, expectedWeek);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long-press add setting rebuilds the active timetable grid', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 776));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final provider = await _createProvider();
    addTearDown(provider.dispose);
    await provider.updateEnableLongPressAddCourse(false);
    await _pumpHomeScreenWithProvider(tester, provider);

    final dayGesture = find
        .byKey(const ValueKey('timetable-day-column-long-press-1'))
        .hitTestable();
    expect(dayGesture, findsOneWidget);
    expect(tester.widget<GestureDetector>(dayGesture).onLongPressStart, isNull);

    await provider.updateEnableLongPressAddCourse(true);
    await tester.pumpAndSettle();

    expect(
      tester.widget<GestureDetector>(dayGesture).onLongPressStart,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('day view edge swipe changes week when enabled', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 776));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final provider = await _createProvider();
    await provider.setSelectedWeek(5);
    await _pumpHomeScreenWithProvider(tester, provider);
    await switchStudentToDayView(tester);

    final pager = tester.widget<PageView>(
      find.byKey(const ValueKey('student-week-pager')),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('student-day-strip'))),
    );
    await gesture.moveBy(const Offset(-180, 0));
    await tester.pump();

    expect(pager.controller!.page, greaterThan(4));
    expect(pager.controller!.page, lessThan(5));
    expect(provider.selectedWeek, 5);
    expect(find.byKey(const ValueKey('student-week-page-6')), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();

    expect(provider.selectedWeek, 6);

    await tester.drag(
      find.byKey(const ValueKey('student-day-strip')),
      const Offset(-180, 0),
    );
    await tester.pumpAndSettle();
    expect(provider.selectedWeek, 7);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'day pager can start from the timetable body in fixed-width mode',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final provider = await _createProvider();
      await provider.setSelectedWeek(5);
      await provider.updateFitDaySelectorToWidth(false);
      await _pumpHomeScreenWithProvider(tester, provider);
      await switchStudentToDayView(tester);

      final gesture = await tester.startGesture(
        tester.getCenter(
          find.byKey(const ValueKey('timetable-grid-vertical-scroll')),
        ),
      );
      await gesture.moveBy(const Offset(-180, 0));
      await tester.pumpAndSettle();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(provider.selectedWeek, 6);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('disabled week swipe leaves day view on the same week', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 776));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final provider = await _createProvider();
    await provider.setSelectedWeek(5);
    await provider.updateEnableWeekSwipeNavigation(false);
    await _pumpHomeScreenWithProvider(tester, provider);
    await switchStudentToDayView(tester);

    await tester.drag(
      find.byKey(const ValueKey('student-day-strip')),
      const Offset(-180, 0),
    );
    await tester.pumpAndSettle();

    expect(provider.selectedWeek, 5);
    expect(tester.takeException(), isNull);
  });

  testWidgets('short week swipe previews then returns without changing week', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 776));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final provider = await _createProvider();
    await provider.setSelectedWeek(5);
    await _pumpHomeScreenWithProvider(tester, provider);
    await switchStudentToDayView(tester);

    final pager = tester.widget<PageView>(
      find.byKey(const ValueKey('student-week-pager')),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('student-day-strip'))),
    );
    await gesture.moveBy(const Offset(-90, 0));
    await tester.pump();

    expect(pager.controller!.page, greaterThan(4));
    expect(pager.controller!.page, lessThan(4.5));
    expect(provider.selectedWeek, 5);
    await gesture.up();
    await tester.pumpAndSettle();

    expect(pager.controller!.page, closeTo(4, 0.01));
    expect(provider.selectedWeek, 5);
    expect(tester.takeException(), isNull);
  });

  testWidgets('slow mouse week drag stays stable while held', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 680));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final provider = await _createProvider();
    await provider.setSelectedWeek(5);
    await _pumpHomeScreenWithProvider(tester, provider);

    final pager = tester.widget<PageView>(
      find.byKey(const ValueKey('student-week-pager')),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('timetable-time-rail'))),
      kind: PointerDeviceKind.mouse,
    );
    final pageSamples = <double>[];
    for (var step = 0; step < 20; step += 1) {
      await gesture.moveBy(const Offset(-4, 0));
      await tester.pump(const Duration(milliseconds: 40));
      pageSamples.add(pager.controller!.page!);
    }

    for (var index = 1; index < pageSamples.length; index += 1) {
      expect(pageSamples[index], greaterThanOrEqualTo(pageSamples[index - 1]));
    }
    expect(pageSamples.last, greaterThan(4));
    expect(provider.selectedWeek, 5);

    final heldPage = pager.controller!.page!;
    await tester.pump(const Duration(milliseconds: 300));
    expect(pager.controller!.page, closeTo(heldPage, 0.001));
    expect(provider.selectedWeek, 5);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(pager.controller!.page, closeTo(4, 0.01));
    expect(provider.selectedWeek, 5);
    expect(tester.takeException(), isNull);
  });

  testWidgets('RTL week swipe follows the physical page direction', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 776));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final provider = await _createProvider();
    await provider.setSelectedWeek(5);
    await _pumpHomeScreenWithProvider(
      tester,
      provider,
      textDirection: TextDirection.rtl,
    );
    await switchStudentToDayView(tester);

    await tester.drag(
      find.byKey(const ValueKey('student-day-strip')),
      const Offset(-180, 0),
    );
    await tester.pumpAndSettle();

    expect(provider.selectedWeek, 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets('week view swipe changes week when columns fit the screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 776));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final provider = await _createProvider();
    await provider.setSelectedWeek(5);
    await _pumpHomeScreenWithProvider(tester, provider);

    await tester.drag(
      find.byKey(const ValueKey('timetable-grid-horizontal-scroll')),
      const Offset(-180, 0),
    );
    await tester.pumpAndSettle();

    expect(provider.selectedWeek, 6);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fixed week pager can start from the time rail', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 776));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final provider = await _createProvider();
    await provider.setSelectedWeek(5);
    await provider.updateFitWeekColumnsToWidth(false);
    await _pumpHomeScreenWithProvider(tester, provider);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('timetable-time-rail'))),
    );
    await gesture.moveBy(const Offset(-180, 0));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(provider.selectedWeek, 6);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fixed week columns scroll before an edge swipe changes week', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 776));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final provider = await _createProvider();
    await provider.setSelectedWeek(5);
    await provider.updateFitWeekColumnsToWidth(false);
    await _pumpHomeScreenWithProvider(tester, provider);

    final horizontal = find.byKey(
      const ValueKey('timetable-grid-horizontal-scroll'),
    );
    final position = tester
        .state<ScrollableState>(
          find.descendant(of: horizontal, matching: find.byType(Scrollable)),
        )
        .position;
    await tester.drag(horizontal, const Offset(-120, 0));
    await tester.pumpAndSettle();
    expect(provider.selectedWeek, 5);
    expect(position.pixels, greaterThan(0));

    final currentPosition = tester
        .state<ScrollableState>(
          find.descendant(of: horizontal, matching: find.byType(Scrollable)),
        )
        .position;
    currentPosition.jumpTo(currentPosition.maxScrollExtent);
    await tester.pump();
    await tester.drag(horizontal, const Offset(-180, 0));
    await tester.pumpAndSettle();
    expect(provider.selectedWeek, 6);
    expect(tester.takeException(), isNull);
  });

  testWidgets('slow mouse edge handoff stays stable while held', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 776));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final provider = await _createProvider();
    await provider.setSelectedWeek(5);
    await provider.updateFitWeekColumnsToWidth(false);
    await _pumpHomeScreenWithProvider(tester, provider);

    final pager = tester.widget<PageView>(
      find.byKey(const ValueKey('student-week-pager')),
    );
    final horizontal = find.byKey(
      const ValueKey('timetable-grid-horizontal-scroll'),
    );
    final position = tester
        .state<ScrollableState>(
          find.descendant(of: horizontal, matching: find.byType(Scrollable)),
        )
        .position;
    position.jumpTo(position.maxScrollExtent);
    await tester.pump();

    final gesture = await tester.startGesture(
      tester.getCenter(horizontal),
      kind: PointerDeviceKind.mouse,
    );
    for (var step = 0; step < 25; step += 1) {
      await gesture.moveBy(const Offset(-4, 0));
      await tester.pump(const Duration(milliseconds: 40));
    }

    expect(pager.controller!.page, greaterThan(4));
    expect(provider.selectedWeek, 5);
    final heldPage = pager.controller!.page!;
    await tester.pump(const Duration(milliseconds: 300));
    expect(pager.controller!.page, closeTo(heldPage, 0.001));
    expect(provider.selectedWeek, 5);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(pager.controller!.page, closeTo(4, 0.01));
    expect(provider.selectedWeek, 5);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'reduced motion week swipe commits without spatial drag preview',
    (tester) async {
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(reduceMotion: true);
      addTearDown(
        tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.binding.setSurfaceSize(const Size(430, 776));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final provider = await _createProvider();
      await provider.setSelectedWeek(5);
      await _pumpHomeScreenWithProvider(tester, provider);
      await switchStudentToDayView(tester);

      final strip = find.byKey(const ValueKey('student-day-strip'));
      final gesture = await tester.startGesture(tester.getCenter(strip));
      await gesture.moveBy(const Offset(-180, 0));
      await tester.pump();

      final pager = tester.widget<PageView>(
        find.byKey(const ValueKey('student-week-pager')),
      );
      expect(pager.controller!.page, closeTo(4, 0.01));
      expect(provider.selectedWeek, 5);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(provider.selectedWeek, 6);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('trackpad pan preview commits the adjacent week', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 680));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final provider = await _createProvider();
    await provider.setSelectedWeek(5);
    await _pumpHomeScreenWithProvider(tester, provider);

    final pager = tester.widget<PageView>(
      find.byKey(const ValueKey('student-week-pager')),
    );
    final pointer = TestPointer(7, PointerDeviceKind.trackpad);
    final center = tester.getCenter(
      find.byKey(const ValueKey('student-week-pager')),
    );
    await tester.sendEventToBinding(pointer.panZoomStart(center));
    await tester.sendEventToBinding(
      pointer.panZoomUpdate(center, pan: const Offset(-360, 0)),
    );
    await tester.pump();

    expect(pager.controller!.page, greaterThan(4));
    expect(pager.controller!.page, lessThan(5));
    expect(provider.selectedWeek, 5);

    await tester.sendEventToBinding(pointer.panZoomEnd());
    await tester.pumpAndSettle();

    expect(provider.selectedWeek, 6);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion reveals the selected day without scrolling', (
    tester,
  ) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final provider = await _createProvider();
    await provider.updateFitDaySelectorToWidth(false);

    await _pumpHomeScreenWithProvider(tester, provider, settle: false);
    await switchStudentToDayView(tester);
    await tester.tap(find.byKey(const ValueKey('student-day-4')));
    await tester.pump();
    await tester.pump();

    final scrollable = find.descendant(
      of: find.byKey(const ValueKey('student-day-strip')),
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(scrollable).position;
    const selectedCenter = 4 + (3 * 58) + 27;
    final expectedTarget = (selectedCenter - position.viewportDimension / 2)
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    expect(position.pixels, closeTo(expectedTarget, 0.01));
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
    await switchStudentToDayView(tester);

    expect(find.byType(HomeScreen), findsOneWidget);
    final monday = find.byKey(const ValueKey('student-day-1'));
    if (monday.evaluate().isEmpty) {
      await tester.drag(
        find.byKey(const ValueKey('student-day-strip')),
        const Offset(600, 0),
      );
      await tester.pumpAndSettle();
    }
    expect(monday, findsOneWidget);
    await tester.tap(monday);
    await tester.pumpAndSettle();
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

  testWidgets('week picker exposes the selected week to semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final provider = await _createProvider();
    await provider.setSelectedWeek(5);
    await _pumpHomeScreenWithProvider(tester, provider);

    await tester.tap(find.byKey(const ValueKey('student-week-picker-button')));
    await tester.pumpAndSettle();

    final data = tester
        .getSemantics(find.byKey(const ValueKey('student-week-option-5')))
        .getSemanticsData();
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.flagsCollection.isSelected, ui.Tristate.isTrue);
    expect(data.label, 'Week 5');
    semantics.dispose();
  });

  testWidgets('week picker exposes tap and long-press semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final provider = await _createProvider();
    await _pumpHomeScreenWithProvider(tester, provider);

    final data = tester
        .getSemantics(
          find.byKey(const ValueKey('student-week-picker-semantics')),
        )
        .getSemanticsData();
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    expect(data.hasAction(SemanticsAction.longPress), isTrue);
    semantics.dispose();
  });

  testWidgets('empty state new timetable opens one draft before saving', (
    tester,
  ) async {
    final storage = _BlockingTimetableStorage(null);
    final provider = await _createEmptyProvider(storage);

    await _pumpHomeScreenWithProvider(tester, provider);

    expect(provider.timetables, isEmpty);
    expect(find.text('No timetable yet'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'New timetable'), findsOneWidget);
    expect(
      find.widgetWithText(OutlinedButton, 'Import timetable'),
      findsOneWidget,
    );
    expect(find.byType(MenuItemButton), findsNothing);

    final createButton = find.widgetWithText(FilledButton, 'New timetable');
    expect(createButton, findsOneWidget);

    await tester.tap(createButton);
    await tester.tap(createButton, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(storage.saveCount, 0);
    expect(provider.timetables, isEmpty);
    expect(find.text('Semester start date'), findsOneWidget);
    expect(find.text('Period time set'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Delete'), findsNothing);

    await tester.enterText(find.byType(TextField).at(0), 'Created timetable');
    await tester.enterText(find.byType(TextField).at(1), '20');
    await _saveTimetableDialog(tester);
    await storage.firstSaveStarted;

    expect(storage.saveCount, 1);
    expect(provider.timetables, hasLength(1));
    expect(provider.activeTimetable.config.name, 'Created timetable');
    expect(provider.activeTimetable.config.totalWeeks, 20);

    storage.completeSave();
    await tester.pumpAndSettle();

    expect(storage.saveCount, 1);
    expect(provider.timetables, hasLength(1));
    expect(find.text(_selectedWeekTitle(provider)), findsOneWidget);
  });

  testWidgets('cancelling a new timetable draft does not persist it', (
    tester,
  ) async {
    final storage = _MemoryTimetableStorage(_buildDefaultFirstLaunchData());
    final provider = TimetableProvider(
      storage: storage,
      systemLocaleCodeResolver: () => defaultLocaleCode,
      privacyService: const _NoopPrivacyService(),
      secretStore: const _NoopSecretStore(),
    );
    await provider.load();
    await _pumpHomeScreenWithProvider(tester, provider);

    await tester.tap(find.widgetWithText(FilledButton, 'New timetable'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Discarded draft');
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(storage.saveCount, 0);
    expect(provider.timetables, isEmpty);
    expect(find.text('No timetable yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('new timetable requires a non-empty name before saving', (
    tester,
  ) async {
    final storage = _BlockingTimetableStorage(null);
    final provider = await _createEmptyProvider(storage);

    await _pumpHomeScreenWithProvider(tester, provider);
    await tester.tap(find.widgetWithText(FilledButton, 'New timetable'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), '   ');
    await _saveTimetableDialog(tester);
    await tester.pump();

    expect(find.text('Timetable name is required'), findsOneWidget);
    expect(storage.saveCount, 0);
    expect(provider.timetables, isEmpty);
    expect(find.text('New timetable'), findsWidgets);
    expect(tester.takeException(), isNull);
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

  testWidgets('empty timetable toolbar stays on one row with large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final storage = _BlockingTimetableStorage(null);
    final provider = await _createEmptyProvider(storage);
    addTearDown(provider.dispose);

    await _pumpHomeScreenWithProvider(
      tester,
      provider,
      textScaler: const TextScaler.linear(2),
    );

    final toolbar = find.byKey(const ValueKey('student-workspace-toolbar'));
    final title = find.descendant(of: toolbar, matching: find.text('Sked'));
    final settings = find.byKey(
      const ValueKey('empty-timetable-settings-button'),
    );
    final toolbarRect = tester.getRect(toolbar);
    final titleRect = tester.getRect(title);
    final settingsRect = tester.getRect(settings);
    final viewport = Offset.zero & const Size(320, 568);

    expect(settingsRect.size, const Size.square(48));
    expect(titleRect.center.dy, closeTo(settingsRect.center.dy, 0.01));
    expect(titleRect.right, lessThanOrEqualTo(settingsRect.left));
    expect(viewport.contains(toolbarRect.topLeft), isTrue);
    expect(viewport.contains(toolbarRect.bottomRight), isTrue);
    expect(viewport.contains(settingsRect.topLeft), isTrue);
    expect(viewport.contains(settingsRect.bottomRight), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty timetable import menu follows its anchor and viewport', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final storage = _BlockingTimetableStorage(null);
    final provider = await _createEmptyProvider(storage);
    addTearDown(provider.dispose);

    for (final scenario in const [
      (size: Size(430, 900), opensBelow: true),
      (size: Size(430, 568), opensBelow: false),
    ]) {
      await tester.binding.setSurfaceSize(scenario.size);
      await _pumpHomeScreenWithProvider(tester, provider);

      final anchor = find.byKey(
        const ValueKey('empty-timetable-import-button'),
      );
      final anchorRect = tester.getRect(anchor);
      await tester.tap(anchor);
      await tester.tap(anchor, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('empty-timetable-import-files')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('empty-timetable-import-text')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('empty-timetable-import-web')),
        findsOneWidget,
      );
      final menuRect = _emptyTimetableImportMenuRect(tester);
      expect(menuRect.width, lessThanOrEqualTo(320));
      expect(menuRect.center.dx, closeTo(anchorRect.center.dx, 1));
      expect(menuRect.left, greaterThanOrEqualTo(16));
      expect(menuRect.right, lessThanOrEqualTo(scenario.size.width - 16));
      if (scenario.opensBelow) {
        expect(menuRect.top - anchorRect.bottom, greaterThanOrEqualTo(8));
      } else {
        expect(anchorRect.top - menuRect.bottom, greaterThanOrEqualTo(8));
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('reduced motion shows the empty import menu immediately', (
    tester,
  ) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final storage = _BlockingTimetableStorage(null);
    final provider = await _createEmptyProvider(storage);
    addTearDown(provider.dispose);
    await _pumpHomeScreenWithProvider(tester, provider);

    await tester.tap(
      find.byKey(const ValueKey('empty-timetable-import-button')),
    );
    await tester.pump();

    final firstItem = find.byKey(
      const ValueKey('empty-timetable-import-files'),
    );
    expect(firstItem, findsOneWidget);
    final menuRoute = ModalRoute.of(tester.element(firstItem));
    expect(menuRoute, isNotNull);
    expect(menuRoute!.animation!.value, 1);
    expect(firstItem.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty timetable import menu tracks layout changes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final storage = _BlockingTimetableStorage(null);
    final provider = await _createEmptyProvider(storage);
    addTearDown(provider.dispose);
    await _pumpHomeScreenWithProvider(tester, provider);

    final anchor = find.byKey(const ValueKey('empty-timetable-import-button'));
    await tester.tap(anchor);
    await tester.pumpAndSettle();
    final initialMenuRect = _emptyTimetableImportMenuRect(tester);

    await tester.binding.setSurfaceSize(const Size(320, 568));
    await tester.pumpAndSettle();

    final updatedAnchorRect = tester.getRect(anchor);
    final updatedMenuRect = _emptyTimetableImportMenuRect(tester);
    expect(updatedMenuRect, isNot(initialMenuRect));
    expect(updatedMenuRect.center.dx, closeTo(updatedAnchorRect.center.dx, 1));
    expect(updatedMenuRect.left, greaterThanOrEqualTo(8));
    expect(updatedMenuRect.right, lessThanOrEqualTo(312));
    expect(updatedMenuRect.bottom, lessThanOrEqualTo(560));
    expect(tester.takeException(), isNull);
  });

  testWidgets('new timetable failure keeps its draft and can be retried', (
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

    final nameField = find.byType(TextField).at(0);
    final weeksField = find.byType(TextField).at(1);
    await tester.enterText(nameField, 'Draft timetable');
    await tester.enterText(weeksField, '20');
    await _saveTimetableDialog(tester);
    await tester.pumpAndSettle();

    expect(storage.saveCount, 1);
    expect(provider.timetables, isEmpty);
    expect(find.text('Save failed. Please try again later.'), findsOneWidget);
    expect(
      tester.widget<TextField>(nameField).controller?.text,
      'Draft timetable',
    );
    expect(tester.widget<TextField>(weeksField).controller?.text, '20');
    expect(tester.takeException(), isNull);

    storage.failSaves = false;
    await _saveTimetableDialog(tester);
    await tester.pumpAndSettle();

    expect(storage.saveCount, 2);
    expect(provider.timetables, hasLength(1));
    expect(provider.activeTimetable.config.name, 'Draft timetable');
    expect(provider.activeTimetable.config.totalWeeks, 20);
    expect(find.widgetWithText(FilledButton, 'Save'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('timetable picker new action opens one draft and saves once', (
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

    await _openTimetablePicker(tester);

    final createButton = find.widgetWithText(FilledButton, 'New timetable');
    expect(createButton, findsOneWidget);

    await tester.tap(createButton);
    await tester.tap(createButton, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(storage.saveCount, 0);
    expect(provider.timetables, hasLength(1));
    expect(find.text('Semester start date'), findsOneWidget);
    expect(tester.widget<FilledButton>(createButton).onPressed, isNull);

    await tester.enterText(find.byType(TextField).at(0), 'Second draft');
    await _saveTimetableDialog(tester);
    await storage.firstSaveStarted;
    await tester.pump();

    expect(storage.saveCount, 1);
    expect(provider.timetables, hasLength(2));
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
          .onPressed,
      isNull,
    );

    storage.completeSave();
    await tester.pumpAndSettle();

    expect(storage.saveCount, 1);
    expect(provider.timetables, hasLength(2));
    expect(find.text('Switch timetables'), findsOneWidget);
    expect(provider.activeTimetable.config.name, 'Second draft');
  });

  testWidgets('new timetable saves the selected period time set', (
    tester,
  ) async {
    final storage = _MemoryTimetableStorage(
      _buildMultiPeriodTimeSetStudentData(),
    );
    final provider = TimetableProvider(
      storage: storage,
      systemLocaleCodeResolver: () => defaultLocaleCode,
      privacyService: const _NoopPrivacyService(),
      secretStore: const _NoopSecretStore(),
    );
    await provider.load();
    await _pumpHomeScreenWithProvider(tester, provider);
    await _openTimetablePicker(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'New timetable'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Period time set'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Evening periods'));
    await tester.pumpAndSettle();

    expect(find.text('Evening periods · 1 periods'), findsOneWidget);
    await _saveTimetableDialog(tester);
    await tester.pumpAndSettle();

    expect(storage.saveCount, 1);
    expect(provider.activeTimetable.config.periodTimeSetId, 'period-set-2');
    expect(find.text('Switch timetables'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed timetable creation reports inside the picker', (
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
    await _openTimetablePicker(tester);

    final createButton = find.widgetWithText(FilledButton, 'New timetable');
    await tester.tap(createButton);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Picker draft');
    await _saveTimetableDialog(tester);
    await tester.pumpAndSettle();

    expect(storage.saveCount, 1);
    expect(provider.timetables, hasLength(1));
    expect(find.text('Switch timetables'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('ui-command-failure-notice')),
      findsOneWidget,
    );

    storage.failSaves = false;
    await _saveTimetableDialog(tester);
    await tester.pumpAndSettle();

    expect(storage.saveCount, 2);
    expect(provider.timetables, hasLength(2));
    // Creating a timetable keeps the picker open so the new selection is
    // visible and the user can continue managing timetables.
    expect(find.text('Switch timetables'), findsOneWidget);
    expect(provider.activeTimetable.config.name, 'Picker draft');
    final newTimetableKey = ValueKey(
      'timetable-picker-item-${provider.activeTimetable.id}',
    );
    expect(find.byKey(newTimetableKey), findsOneWidget);
    expect(
      tester
          .getSemantics(find.byKey(newTimetableKey))
          .getSemanticsData()
          .flagsCollection
          .isSelected,
      ui.Tristate.isTrue,
    );

    await tester.tap(
      find.byKey(const ValueKey('timetable-picker-item-table-1')),
    );
    await tester.pumpAndSettle();

    expect(storage.saveCount, 3);
    expect(provider.activeTimetable.id, 'table-1');
    expect(find.text('Switch timetables'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('timetable picker switch ignores rapid duplicate taps', (
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

    await _openTimetablePicker(tester);

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

  testWidgets('compact timetable picker cannot close while saving', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 776));
    addTearDown(() => tester.binding.setSurfaceSize(null));
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
    await _openTimetablePicker(tester);

    final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
    expect(sheet.enableDrag, isFalse);
    await tester.tap(find.text('Second timetable'));
    await storage.firstSaveStarted;
    await tester.pump();

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(BottomSheet), findsOneWidget);
    await tester.tapAt(const Offset(8, 8));
    await tester.pump();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Switch timetables'), findsOneWidget);

    storage.completeSave();
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(provider.activeTimetable.config.name, 'Second timetable');
  });

  testWidgets('timetable picker exposes its selected item to semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final storage = _MemoryTimetableStorage(_buildMultiTimetableStudentData());
    final provider = TimetableProvider(
      storage: storage,
      systemLocaleCodeResolver: () => defaultLocaleCode,
      privacyService: const _NoopPrivacyService(),
      secretStore: const _NoopSecretStore(),
    );
    await provider.load();
    await _pumpHomeScreenWithProvider(tester, provider);
    await _openTimetablePicker(tester);

    final data = tester
        .getSemantics(
          find.byKey(const ValueKey('timetable-picker-item-table-1')),
        )
        .getSemanticsData();
    expect(data.flagsCollection.isSelected, ui.Tristate.isTrue);
    expect(data.flagsCollection.isEnabled, ui.Tristate.isTrue);
    expect(data.label, contains('First timetable'));
    semantics.dispose();
  });

  testWidgets('failed timetable switch keeps the picker open for retry', (
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

    await _openTimetablePicker(tester);
    final secondTimetable = find.text('Second timetable');
    await tester.tap(secondTimetable);
    await tester.pumpAndSettle();

    expect(storage.saveCount, 1);
    expect(provider.activeTimetable.config.name, 'First timetable');
    expect(find.text('Switch timetables'), findsOneWidget);
    expect(find.text('Save failed. Please try again later.'), findsOneWidget);
    expect(tester.takeException(), isNull);

    storage.failSaves = false;
    await tester.tap(secondTimetable);
    await tester.pumpAndSettle();

    expect(storage.saveCount, 2);
    expect(provider.activeTimetable.config.name, 'Second timetable');
    expect(find.text('Switch timetables'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('picker current timetable tap cannot pop parent route', (
    tester,
  ) async {
    final provider = await _createProvider();
    await _pumpHomeScreenHostPage(tester, provider);

    await tester.tap(find.text('Open home host'));
    await _pumpRouteTransition(tester);

    expect(find.text(_selectedWeekTitle(provider)), findsOneWidget);

    await _openTimetablePicker(tester);

    final currentTimetable = find.text('Test timetable').last;
    expect(currentTimetable, findsOneWidget);

    await tester.tap(currentTimetable);
    await tester.tap(currentTimetable, warnIfMissed: false);
    await _pumpRouteTransition(tester);

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Switch timetables'), findsNothing);
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

    await tester.tap(
      find.byKey(const ValueKey('empty-timetable-import-button')),
    );
    await tester.pumpAndSettle();
    final textImportButton = find.byKey(
      const ValueKey('empty-timetable-import-text'),
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

    await tester.tap(
      find.byKey(const ValueKey('empty-timetable-import-button')),
    );
    await tester.pumpAndSettle();
    final webImportButton = find.byKey(
      const ValueKey('empty-timetable-import-web'),
    );
    expect(webImportButton, findsOneWidget);

    await tester.tap(webImportButton);
    await tester.tap(webImportButton, warnIfMissed: false);
    await _pumpRouteTransition(tester);

    expect(find.byType(SchoolSitesPage, skipOffstage: false), findsOneWidget);
  });

  testWidgets(
    'student toolbar follows custom order and keeps settings reachable',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final data = _buildPopulatedStudentData().copyWith(
        studentMode: _buildPopulatedStudentData().studentMode.copyWith(
          toolbarNavigationOrder: const [
            'view',
            'settings',
            'week',
            'timetable',
          ],
        ),
      );
      final provider = TimetableProvider(
        storage: _MemoryTimetableStorage(data),
        systemLocaleCodeResolver: () => defaultLocaleCode,
        privacyService: const _NoopPrivacyService(),
        secretStore: const _NoopSecretStore(),
      );
      await provider.load();
      addTearDown(provider.dispose);
      await _pumpHomeScreenWithProvider(tester, provider);

      final view = tester.getRect(
        find.byKey(const ValueKey('student-view-toggle-button')),
      );
      final settings = tester.getRect(
        find.byKey(const ValueKey('student-settings-button')),
      );
      final week = tester.getRect(
        find.byKey(const ValueKey('student-week-picker-button')),
      );
      final timetable = tester.getRect(
        find.byKey(const ValueKey('student-timetable-picker-button')),
      );
      expect(view.left, lessThan(settings.left));
      expect(settings.left, lessThan(week.left));
      expect(week.left, lessThan(timetable.left));
      expect(
        find.byKey(const ValueKey('student-settings-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('student-toolbar-more-button')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('student timetable selector stays leading on wide screens', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final provider = await _createProvider();
    addTearDown(provider.dispose);
    await _pumpHomeScreenWithProvider(tester, provider);

    final selector = tester.getRect(
      find.byKey(const ValueKey('student-timetable-picker-button')),
    );
    final week = tester.getRect(
      find.byKey(const ValueKey('student-week-picker-button')),
    );
    final view = tester.getRect(
      find.byKey(const ValueKey('student-view-toggle-button')),
    );
    final settings = tester.getRect(
      find.byKey(const ValueKey('student-settings-button')),
    );

    expect(selector.left, lessThan(week.left));
    expect(selector.right, lessThan(week.left));
    expect(week.left, lessThan(view.left));
    expect(view.left, lessThan(settings.left));
    expect(tester.takeException(), isNull);
  });

  testWidgets('student toolbar removes hidden items or exposes them in More', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final base = _buildPopulatedStudentData();
    final provider = TimetableProvider(
      storage: _MemoryTimetableStorage(
        base.copyWith(
          studentMode: base.studentMode.copyWith(
            hiddenToolbarNavigationIds: const ['week', 'view', 'timetable'],
          ),
        ),
      ),
      systemLocaleCodeResolver: () => defaultLocaleCode,
      privacyService: const _NoopPrivacyService(),
      secretStore: const _NoopSecretStore(),
    );
    await provider.load();
    addTearDown(provider.dispose);
    await _pumpHomeScreenWithProvider(tester, provider);

    expect(
      find.byKey(const ValueKey('student-week-picker-button')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('student-toolbar-more-button')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('student-settings-button')),
      findsOneWidget,
    );

    await provider.updateStudentToolbarHiddenItemsBehavior(
      toolbarHiddenItemsBehaviorMore,
    );
    expect(
      provider.studentToolbarHiddenItemsBehavior,
      toolbarHiddenItemsBehaviorMore,
    );
    expect(provider.studentHiddenToolbarNavigationIds, [
      'week',
      'view',
      'timetable',
    ]);
    await tester.pumpAndSettle();
    final more = find.byKey(const ValueKey('student-toolbar-more-button'));
    expect(more, findsOneWidget);
    expect(
      find.byKey(const ValueKey('student-week-picker-button')),
      findsNothing,
    );

    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(find.text('Week ${provider.selectedWeek}').last, findsOneWidget);
    expect(find.text('View switcher').last, findsOneWidget);
    expect(find.text('Timetable').last, findsOneWidget);

    await tester.tap(find.text('View switcher').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('student-day-strip')), findsOneWidget);

    await tester.tap(more);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Week ${provider.selectedWeek}').last);
    await tester.pumpAndSettle();
    expect(find.text('Jump to week'), findsOneWidget);
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();

    await tester.tap(more);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Timetable').last);
    await tester.pumpAndSettle();
    expect(find.text('Switch timetables'), findsOneWidget);
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(find.text('Week ${provider.selectedWeek}'), findsNothing);

    await provider.updateStudentToolbarNavigationVisibility('more', false);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('student-toolbar-more-button')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('student-week-picker-button')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('student-settings-button')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'student toolbar scrolls horizontally when all actions cannot fit',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(200, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final provider = await _createProvider();
      await _pumpHomeScreenWithProvider(tester, provider);

      final toolbar = find.byKey(const ValueKey('student-workspace-toolbar'));
      expect(
        find.descendant(
          of: toolbar,
          matching: find.byType(SingleChildScrollView),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
