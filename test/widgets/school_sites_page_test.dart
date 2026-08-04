import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/l10n/app_locale.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/school_site_models.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/screens/school_html_import_page.dart';
import 'package:sked/screens/school_sites_page.dart';
import 'package:sked/services/export_service.dart';
import 'package:sked/services/privacy_service.dart';
import 'package:sked/services/school_site_service.dart';
import 'package:sked/services/school_site_store.dart';

class _MemorySchoolSiteStore extends SchoolSiteStore {
  _MemorySchoolSiteStore(this.source) : super.base();

  String? source;

  @override
  Future<String?> load() async => source;

  @override
  Future<void> save(String source) async {
    this.source = source;
  }

  @override
  Future<String?> filePath() async => 'memory://school-sites';
}

class _RecoverySchoolSiteStore extends SchoolSiteStore {
  _RecoverySchoolSiteStore(
    this.result, {
    this.isolatedArtifacts = const <String>[],
    this.recoveryArtifactBytes,
  }) : super.base();

  SchoolSiteStoreLoadResult result;
  final List<String> isolatedArtifacts;
  final Uint8List? recoveryArtifactBytes;
  var saveCount = 0;

  @override
  Future<String?> load() async {
    return result.candidates.firstOrNull?.source;
  }

  @override
  Future<SchoolSiteStoreLoadResult> loadResult() async => result;

  @override
  Future<List<String>> isolateForRecovery() async {
    result = SchoolSiteStoreLoadResult(
      candidates: const [],
      hasArtifacts: false,
      recoveryArtifacts: isolatedArtifacts,
    );
    return isolatedArtifacts;
  }

  @override
  Future<void> save(String source) async {
    saveCount += 1;
    result = SchoolSiteStoreLoadResult(
      candidates: [SchoolSiteStoreCandidate(source: source)],
      hasArtifacts: true,
    );
  }

  @override
  Future<String?> filePath() async => 'memory://school-sites';

  @override
  Future<Uint8List?> readRecoveryArtifact(String artifactPath) async {
    return recoveryArtifactBytes;
  }
}

class _MemoryTimetableStorage implements TimetableStorage {
  _MemoryTimetableStorage(this.data);

  AppData? data;

  @override
  Future<StorageLoadResult> load() async =>
      StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);

  @override
  Future<void> save(AppData data) async {
    this.data = data;
  }

  @override
  Future<String?> filePath() async => 'memory://school-sites-test';
}

class _NoopPrivacyService extends PrivacyService {
  const _NoopPrivacyService();

  @override
  Future<String?> fetchCurrentPrivacyPolicyVersion() async => null;
}

class _CompletingExportService extends ExportService {
  final started = Completer<void>();
  final result = Completer<ExportSaveResult>();

  @override
  Future<ExportSaveResult> saveFile(ExportPayload payload) {
    if (!started.isCompleted) {
      started.complete();
    }
    return result.future;
  }
}

class _RecordingBytesExportService extends ExportService {
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
      path: 'memory://school-sites-recovery.json',
    );
  }
}

Future<TimetableProvider> _createProvider() async {
  final provider = TimetableProvider(
    storage: _MemoryTimetableStorage(
      buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: defaultLocaleCode,
      ).copyWith(activeMode: AppMode.student),
    ),
    systemLocaleCodeResolver: () => defaultLocaleCode,
    privacyService: const _NoopPrivacyService(),
  );
  await provider.load();
  return provider;
}

Future<void> _pumpSchoolSitesPage(
  WidgetTester tester,
  TimetableProvider provider, {
  ExportService? exportService,
  SchoolSiteService? siteService,
  Future<String?> Function()? pickJsonSource,
}) async {
  final resolvedSiteService =
      siteService ?? SchoolSiteService(store: _MemorySchoolSiteStore('[]'));
  await tester.pumpWidget(
    ChangeNotifierProvider<TimetableProvider>.value(
      value: provider,
      child: MaterialApp(
        key: UniqueKey(),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SchoolSitesPage(
          key: UniqueKey(),
          siteService: resolvedSiteService,
          exportService: exportService,
          pickJsonSource: pickJsonSource,
        ),
      ),
    ),
  );
  for (var frame = 0; frame < 30; frame += 1) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _pumpRouteTransition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('add school entry ignores rapid duplicate taps', (tester) async {
    final provider = await _createProvider();
    await _pumpSchoolSitesPage(tester, provider);

    final addButton = find.byTooltip('Add school');
    expect(addButton, findsOneWidget);

    await tester.tap(addButton);
    await tester.tap(addButton, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Add school'), findsWidgets);
  });

  testWidgets('text / HTML parsing entry ignores rapid duplicate taps', (
    tester,
  ) async {
    final provider = await _createProvider();
    await _pumpSchoolSitesPage(tester, provider);

    final htmlImportButton = find.byTooltip('Parse timetable from text / HTML');
    expect(htmlImportButton, findsOneWidget);

    await tester.tap(htmlImportButton);
    await tester.tap(htmlImportButton, warnIfMissed: false);
    await _pumpRouteTransition(tester);

    expect(
      find.byType(SchoolHtmlImportPage, skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('JSON save ignores results after the page is disposed', (
    tester,
  ) async {
    final provider = await _createProvider();
    final exportService = _CompletingExportService();
    await _pumpSchoolSitesPage(tester, provider, exportService: exportService);

    final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)));
    await tester.tap(find.byTooltip(l10n.importExport));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.schoolSitesSaveJson));
    await tester.pump();
    await exportService.started.future;

    await tester.pumpWidget(const SizedBox.shrink());
    exportService.result.complete(
      const ExportSaveResult(status: ExportSaveStatus.permissionDenied),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('normal page keeps historical recovery artifacts accessible', (
    tester,
  ) async {
    final provider = await _createProvider();
    const artifact = 'memory://recovery/Sked_school_sites.json';
    final store = _RecoverySchoolSiteStore(
      SchoolSiteStoreLoadResult(
        candidates: [
          SchoolSiteStoreCandidate(
            source: encodeSchoolSites(const [
              SchoolSite(name: 'School', loginUrl: 'https://school.test'),
            ]),
          ),
        ],
        hasArtifacts: true,
        recoveryArtifacts: const ['memory://school-sites', artifact],
        historicalRecoveryArtifacts: const [artifact],
      ),
      recoveryArtifactBytes: Uint8List.fromList([1, 2, 3]),
    );
    await _pumpSchoolSitesPage(
      tester,
      provider,
      siteService: SchoolSiteService(store: store),
    );
    final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)));

    expect(
      find.byKey(const ValueKey('school-sites-recovery-view')),
      findsNothing,
    );
    await tester.tap(find.byTooltip(l10n.importExport));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.dataRecoveryArtifactsAction));
    await tester.pumpAndSettle();

    expect(find.text(artifact), findsOne);
    expect(find.text(l10n.copyText), findsOne);
  });

  testWidgets('JSON import previews invalid entries and merges exact uniques', (
    tester,
  ) async {
    final provider = await _createProvider();
    final store = _MemorySchoolSiteStore('''
[
  {"name":"Existing","loginUrl":"https://existing.example.edu/login"}
]
''');
    await _pumpSchoolSitesPage(
      tester,
      provider,
      siteService: SchoolSiteService(store: store),
      pickJsonSource: () async => '''
[
  {"name":"Existing","loginUrl":"https://existing.example.edu/login"},
  {"name":"New","loginUrl":"https://new.example.edu/login"},
  {"name":"Broken","loginUrl":"javascript:alert(1)"}
]
''',
    );
    final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)));

    await tester.tap(find.byTooltip(l10n.importExport));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.schoolSitesImportJson));
    await tester.pumpAndSettle();

    expect(find.text(l10n.schoolSitesImportPreviewTitle), findsOne);
    expect(find.text(l10n.schoolSitesImportPreviewSummary(2, 1)), findsOne);
    expect(find.text(l10n.schoolSitesImportInvalidEntry(3)), findsOne);

    await tester.tap(find.byKey(const ValueKey('school-sites-import-merge')));
    await tester.pumpAndSettle();

    final saved = decodeSchoolSitesStrict(store.source!);
    expect(saved.map((site) => site.name), ['Existing', 'New']);
  });

  testWidgets('JSON replacement requires a second explicit confirmation', (
    tester,
  ) async {
    final provider = await _createProvider();
    final store = _MemorySchoolSiteStore('''
[
  {"name":"Existing","loginUrl":"https://existing.example.edu/login"}
]
''');
    await _pumpSchoolSitesPage(
      tester,
      provider,
      siteService: SchoolSiteService(store: store),
      pickJsonSource: () async => '''
[
  {"name":"Replacement","loginUrl":"https://replacement.example.edu/login"}
]
''',
    );
    final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)));

    await tester.tap(find.byTooltip(l10n.importExport));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.schoolSitesImportJson));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('school-sites-import-replace')));
    await tester.pumpAndSettle();

    expect(find.text(l10n.schoolSitesImportReplaceConfirmTitle), findsOne);
    expect(decodeSchoolSitesStrict(store.source!).single.name, 'Existing');

    await tester.tap(
      find.byKey(const ValueKey('school-sites-import-confirm-replace')),
    );
    await tester.pumpAndSettle();

    expect(decodeSchoolSitesStrict(store.source!).single.name, 'Replacement');
  });

  testWidgets('corrupt storage shows a blocking recovery view and artifacts', (
    tester,
  ) async {
    final provider = await _createProvider();
    final store = _RecoverySchoolSiteStore(
      const SchoolSiteStoreLoadResult(
        candidates: [SchoolSiteStoreCandidate(source: '{ broken json')],
        hasArtifacts: true,
      ),
      isolatedArtifacts: const ['memory://recovery/Sked_school_sites.json'],
      recoveryArtifactBytes: Uint8List.fromList([0, 255, 91, 10]),
    );
    final exports = _RecordingBytesExportService();
    await _pumpSchoolSitesPage(
      tester,
      provider,
      siteService: SchoolSiteService(store: store),
      exportService: exports,
    );
    final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)));

    expect(find.byKey(const ValueKey('school-sites-recovery-view')), findsOne);
    expect(find.text(l10n.schoolSitesRecoveryCorruptTitle), findsOne);
    expect(find.text(l10n.schoolSitesEmpty), findsNothing);
    expect(
      tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.add))
          .onPressed,
      isNull,
    );
    expect(
      find.byKey(const ValueKey('school-sites-recovery-start-fresh')),
      findsOne,
    );

    await tester.tap(
      find.byKey(const ValueKey('school-sites-recovery-artifacts')),
    );
    await tester.pumpAndSettle();

    expect(find.text('memory://recovery/Sked_school_sites.json'), findsOne);
    expect(find.text(l10n.copyText), findsOne);
    await tester.tap(find.byIcon(Icons.ios_share));
    await tester.pumpAndSettle();
    expect(exports.fileName, 'Sked_school_sites.json');
    expect(exports.bytes, [0, 255, 91, 10]);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('I/O recovery state never offers destructive replacement', (
    tester,
  ) async {
    final provider = await _createProvider();
    final store = _RecoverySchoolSiteStore(
      SchoolSiteStoreLoadResult(
        candidates: const [],
        issues: [
          SchoolSiteStoreIssue(
            artifact: SchoolSiteStoreArtifact.primary,
            type: SchoolSiteStoreIssueType.readFailure,
            error: Exception('read denied'),
          ),
        ],
        hasArtifacts: true,
        recoveryArtifacts: const ['memory://school-sites'],
      ),
    );
    await _pumpSchoolSitesPage(
      tester,
      provider,
      siteService: SchoolSiteService(store: store),
    );
    final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)));

    expect(find.text(l10n.schoolSitesRecoveryIoFailureTitle), findsOne);
    expect(find.byKey(const ValueKey('school-sites-recovery-retry')), findsOne);
    expect(
      find.byKey(const ValueKey('school-sites-recovery-start-fresh')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('school-sites-recovery-import')),
      findsNothing,
    );

    store.result = const SchoolSiteStoreLoadResult(
      candidates: [SchoolSiteStoreCandidate(source: '[]')],
      hasArtifacts: true,
    );
    await tester.tap(find.byKey(const ValueKey('school-sites-recovery-retry')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('school-sites-recovery-view')),
      findsNothing,
    );
    expect(find.text(l10n.schoolSitesEmpty), findsOne);
  });

  testWidgets('recovery import confirms replacing with imported sites', (
    tester,
  ) async {
    final provider = await _createProvider();
    final store = _RecoverySchoolSiteStore(
      const SchoolSiteStoreLoadResult(
        candidates: [SchoolSiteStoreCandidate(source: '{ broken json')],
        hasArtifacts: true,
      ),
      isolatedArtifacts: const ['memory://recovery/Sked_school_sites.json'],
    );
    await _pumpSchoolSitesPage(
      tester,
      provider,
      siteService: SchoolSiteService(store: store),
      pickJsonSource: () async =>
          '[{"name":"Recovered","loginUrl":"https://recovered.test"}]',
    );
    final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)));
    final importButton = find.byKey(
      const ValueKey('school-sites-recovery-import'),
    );
    await tester.scrollUntilVisible(importButton, 180);
    await tester.tap(importButton);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('school-sites-import-replace')));
    await tester.pumpAndSettle();

    expect(find.text(l10n.schoolSitesImportReplaceConfirmTitle), findsOne);
    expect(
      find.text(l10n.schoolSitesRecoveryStartFreshConfirmTitle),
      findsNothing,
    );
    expect(store.saveCount, 0);

    await tester.tap(
      find.byKey(const ValueKey('school-sites-import-confirm-replace')),
    );
    await tester.pumpAndSettle();

    expect(store.saveCount, 1);
    expect(
      decodeSchoolSitesStrict(
        store.result.candidates.single.source,
      ).single.name,
      'Recovered',
    );
  });

  testWidgets('starting fresh requires confirmation and then unlocks editing', (
    tester,
  ) async {
    final provider = await _createProvider();
    final store = _RecoverySchoolSiteStore(
      const SchoolSiteStoreLoadResult(
        candidates: [SchoolSiteStoreCandidate(source: '{ broken json')],
        hasArtifacts: true,
      ),
      isolatedArtifacts: const ['memory://recovery/Sked_school_sites.json'],
    );
    await _pumpSchoolSitesPage(
      tester,
      provider,
      siteService: SchoolSiteService(store: store),
    );
    final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)));

    final startFresh = find.byKey(
      const ValueKey('school-sites-recovery-start-fresh'),
    );
    await tester.scrollUntilVisible(startFresh, 180);
    await tester.tap(startFresh);
    await tester.pumpAndSettle();

    expect(find.text(l10n.schoolSitesRecoveryStartFreshConfirmTitle), findsOne);
    expect(store.saveCount, 0);

    await tester.tap(
      find.byKey(const ValueKey('school-sites-recovery-confirm-start-fresh')),
    );
    await tester.pumpAndSettle();

    expect(store.saveCount, 1);
    expect(
      find.byKey(const ValueKey('school-sites-recovery-view')),
      findsNothing,
    );
    expect(find.text(l10n.schoolSitesEmpty), findsOne);
    expect(
      tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.add).first)
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('stale page mutation reloads sites restored by another service', (
    tester,
  ) async {
    final provider = await _createProvider();
    final coordinator = SchoolSiteStorageCoordinator();
    final store = _MemorySchoolSiteStore('''
[
  {"name":"Existing","loginUrl":"https://existing.test"}
]
''');
    final pageService = SchoolSiteService(
      store: store,
      coordinator: coordinator,
    );
    final restoreService = SchoolSiteService(
      store: store,
      coordinator: coordinator,
    );
    await _pumpSchoolSitesPage(
      tester,
      provider,
      siteService: pageService,
      pickJsonSource: () async => '''
[
  {"name":"Page import","loginUrl":"https://page-import.test"}
]
''',
    );
    await restoreService.loadSitesResult();
    final lease = await restoreService.reserveRestore();
    await lease.loadSitesResult();
    await lease.replaceSitesAfterRecovery(const [
      SchoolSite(name: 'Restored', loginUrl: 'https://restored.test'),
    ]);
    await lease.release();

    expect(find.text('Existing'), findsOneWidget);
    final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)));
    await tester.tap(find.byTooltip(l10n.importExport));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.schoolSitesImportJson));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('school-sites-import-merge')));
    await tester.pumpAndSettle();

    expect(find.text('Existing'), findsNothing);
    expect(find.text('Restored'), findsOneWidget);
    expect(decodeSchoolSitesStrict(store.source!).single.name, 'Restored');
  });
}
