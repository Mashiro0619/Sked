import 'dart:async';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/l10n/app_locale.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/school_site_models.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/app_scope.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/screens/school_html_import_page.dart';
import 'package:sked/screens/school_sites_page.dart';
import 'package:sked/screens/school_web_import_page.dart';
import 'package:sked/services/export_service.dart';
import 'package:sked/services/privacy_service.dart';
import 'package:sked/services/school_site_service.dart';
import 'package:sked/services/school_site_store.dart';
import 'package:sked/widgets/app_modal_sheet.dart';
import 'package:sked/widgets/expressive_dialog.dart';
import 'package:flutter/services.dart';

import '../support/data_transfer_codec.dart';
import '../support/timetable_storage_fakes.dart';

class _MemorySchoolSiteStore extends SchoolSiteStore {
  _MemorySchoolSiteStore(this.source) : super.base();

  String? source;
  bool failNext = false;

  @override
  Future<String?> load() async => source;

  @override
  Future<void> save(String source) async {
    if (failNext) {
      failNext = false;
      throw StateError('retryable site write');
    }
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

class _VersionedSchoolSiteService extends SchoolSiteService {
  _VersionedSchoolSiteService() : super(store: _MemorySchoolSiteStore('[]'));
  int exports = 0;

  @override
  Future<String> exportSites(List<SchoolSite> sites) async =>
      '{"snapshot":${++exports}}';
}

class _RetryThenShareExportService extends ExportService {
  final saved = <ExportPayload>[];
  final shared = <ExportPayload>[];

  @override
  Future<ExportSaveResult> saveFile(ExportPayload payload) async {
    saved.add(payload);
    return ExportSaveResult(
      status: saved.length == 1
          ? ExportSaveStatus.permissionDenied
          : ExportSaveStatus.failed,
    );
  }

  @override
  Future<void> shareFile(ExportPayload payload) async {
    shared.add(payload);
  }
}

Future<AppRuntime> _createProvider() async {
  final provider = AppRuntime(
    dataTransferCodec: inlineDataTransferCodec,
    storage: WorkspaceMemoryStorage(
      buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: defaultLocaleCode,
      ).copyWith(activeMode: AppMode.student),
      path: 'memory://school-sites-test',
    ),
    systemLocaleCodeResolver: () => defaultLocaleCode,
    privacyService: const _NoopPrivacyService(),
  );
  await provider.lifecycle.load();
  return provider;
}

Finder _recoveryScrollable() => find.descendant(
  of: find.byKey(const ValueKey('school-sites-recovery-view')),
  matching: find.byWidgetPredicate(
    (widget) =>
        widget is Scrollable &&
        (widget.axisDirection == AxisDirection.down ||
            widget.axisDirection == AxisDirection.up),
  ),
);

Future<void> _pumpSchoolSitesPage(
  WidgetTester tester,
  AppRuntime provider, {
  ExportService? exportService,
  SchoolSiteService? siteService,
  Future<String?> Function()? pickJsonSource,
  TargetPlatform platform = TargetPlatform.android,
}) async {
  final resolvedSiteService =
      siteService ?? SchoolSiteService(store: _MemorySchoolSiteStore('[]'));
  await tester.pumpWidget(
    AppScope(
      app: provider,
      child: MaterialApp(
        key: UniqueKey(),
        locale: const Locale('en'),
        theme: ThemeData(platform: platform),
        localizationsDelegates: appLocalizationsDelegates,
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
  for (final platform in [TargetPlatform.android, TargetPlatform.windows]) {
    testWidgets(
      'site selection follows the detail pane and narrow navigation on $platform',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final semantics = tester.ensureSemantics();
        try {
          final provider = await _createProvider();
          addTearDown(provider.dispose);
          const sites = [
            SchoolSite(
              name: 'Original school',
              loginUrl: 'https://original.example/login',
            ),
            SchoolSite(
              name: 'Other school',
              loginUrl: 'https://other.example/login',
            ),
          ];
          await _pumpSchoolSitesPage(
            tester,
            provider,
            platform: platform,
            siteService: SchoolSiteService(
              store: _MemorySchoolSiteStore(encodeSchoolSites(sites)),
            ),
          );
          Finder row(int index) =>
              find.widgetWithText(ExpressiveDialogOption, sites[index].name);
          void expectSelected(int selectedIndex) {
            for (var index = 0; index < sites.length; index++) {
              final selected = index == selectedIndex;
              expect(
                tester.widget<ExpressiveDialogOption>(row(index)).selected,
                selected,
              );
              expect(
                tester
                    .getSemantics(row(index))
                    .getSemanticsData()
                    .flagsCollection
                    .isSelected,
                selected ? ui.Tristate.isTrue : ui.Tristate.isFalse,
              );
              expect(
                find.descendant(
                  of: row(index),
                  matching: find.byIcon(Icons.check_circle),
                ),
                selected ? findsOneWidget : findsNothing,
              );
            }
            expect(
              tester.widget<SelectableText>(find.byType(SelectableText)).data,
              sites[selectedIndex].loginUrl,
            );
          }

          expectSelected(0);
          await tester.tap(
            find.descendant(of: row(1), matching: find.text(sites[1].name)),
          );
          await tester.pumpAndSettle();
          expectSelected(1);

          await tester.binding.setSurfaceSize(const Size(360, 800));
          await tester.pumpAndSettle();
          expect(find.byType(SelectableText), findsNothing);
          expect(find.byIcon(Icons.check_circle), findsNothing);
          await tester.tap(
            find.descendant(of: row(0), matching: find.text(sites[0].name)),
          );
          await tester.pumpAndSettle();
          final opened = tester.widget<SchoolWebImportPage>(
            find.byType(SchoolWebImportPage),
          );
          expect(opened.site.name, sites[0].name);
          expect(opened.site.loginUrl, sites[0].loginUrl);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        } finally {
          semantics.dispose();
        }
      },
    );
  }

  testWidgets(
    'site edit stays beside its list and keeps its draft across rotation',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final semantics = tester.ensureSemantics();
      try {
        final provider = await _createProvider();
        addTearDown(provider.dispose);
        final store = _MemorySchoolSiteStore(
          encodeSchoolSites(const [
            SchoolSite(
              name: 'Original school',
              loginUrl: 'https://original.example/login',
            ),
            SchoolSite(
              name: 'Other school',
              loginUrl: 'https://other.example/login',
            ),
          ]),
        );
        await _pumpSchoolSitesPage(
          tester,
          provider,
          siteService: SchoolSiteService(store: store),
        );
        final l = AppLocalizations.of(
          tester.element(find.byType(SchoolSitesPage)),
        );
        await tester.tap(find.byTooltip(l.schoolSitesEdit).first);
        await tester.pumpAndSettle();
        final fields = find.descendant(
          of: find.byType(AppSheetScaffold),
          matching: find.byType(TextField),
        );
        final titleElement = tester.element(fields.first);
        expect(tester.getTopLeft(fields.first).dx, greaterThan(280));
        expect(find.bySemanticsLabel(RegExp('Other school')), findsWidgets);
        await tester.enterText(fields.first, 'Preserved school draft');
        tester.view.physicalSize = const Size(360, 800);
        await tester.pumpAndSettle();
        expect(tester.element(fields.first), same(titleElement));
        expect(find.bySemanticsLabel(RegExp('Other school')), findsNothing);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text(l.unsavedChangesMessage), findsOneWidget);
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text(l.cancel),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(fields.first).controller!.text,
          'Preserved school draft',
        );
        tester.view.physicalSize = const Size(1280, 800);
        await tester.pumpAndSettle();
        await tester.tap(find.text(l.save));
        await tester.pumpAndSettle();
        expect(
          decodeSchoolSitesStrict(store.source!).first.name,
          'Preserved school draft',
        );
        expect(find.byType(AppSheetScaffold), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        semantics.dispose();
      }
    },
  );

  for (final (platform, size, textScale) in [
    (TargetPlatform.android, const Size(360, 800), 2.0),
    (TargetPlatform.windows, const Size(1280, 800), 1.0),
  ]) {
    testWidgets(
      'site form locates errors and retains its draft after a failed save on $platform',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final store = _MemorySchoolSiteStore('[]');
        final service = SchoolSiteService(store: store);
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            theme: ThemeData(platform: platform),
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
            home: SchoolSitesPage(siteService: service),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Empty school list');
        final l = AppLocalizations.of(
          tester.element(find.byType(SchoolSitesPage)),
        );
        await tester.tap(find.byTooltip(l.schoolSitesAdd));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Opened school editor');
        await tester.tap(find.text(l.save));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Required field errors');
        final fields = find.descendant(
          of: find.byType(AppSheetScaffold),
          matching: find.byType(TextField),
        );
        TextField nameField() => tester.widget<TextField>(fields.at(0));
        TextField urlField() => tester.widget<TextField>(fields.at(1));
        expect(nameField().decoration!.errorText, l.schoolSitesNameRequired);
        expect(urlField().decoration!.errorText, l.schoolSitesLoginUrlRequired);
        expect(nameField().focusNode!.hasFocus, isTrue);
        expect(store.source, '[]');

        await tester.enterText(fields.at(0), 'Retained school');
        await tester.pumpAndSettle();
        expect(nameField().decoration!.errorText, isNull);
        expect(urlField().decoration!.errorText, l.schoolSitesLoginUrlRequired);
        for (final invalidUrl in [
          'school.example/login',
          'https://',
          'ftp://school.example/login',
        ]) {
          await tester.enterText(fields.at(1), invalidUrl);
          await tester.tap(find.text(l.save));
          await tester.pumpAndSettle();
          expect(
            urlField().decoration!.errorText,
            l.schoolWebImportAddressInvalid,
          );
          expect(nameField().decoration!.errorText, isNull);
          expect(urlField().focusNode!.hasFocus, isTrue);
          expect(find.text(l.schoolSitesFormInvalid), findsNothing);
          expect(urlField().controller!.text, invalidUrl);
          expect(store.source, '[]');
          expect(
            tester.takeException(),
            isNull,
            reason: 'URL error: $invalidUrl',
          );
        }

        await tester.enterText(fields.at(1), 'https://school.example/login');
        await tester.pumpAndSettle();
        expect(urlField().decoration!.errorText, isNull);
        store.failNext = true;
        await tester.tap(find.text(l.save));
        await tester.pumpAndSettle();
        expect(find.byType(AppSheetScaffold), findsOneWidget);
        expect(find.text(l.saveFailedRetry), findsOneWidget);
        expect(nameField().controller!.text, 'Retained school');
        expect(urlField().controller!.text, 'https://school.example/login');
        expect(store.source, '[]');
        expect(
          tester.takeException(),
          isNull,
          reason: 'Retryable save failure',
        );
        await tester.tap(find.text(l.save));
        await tester.pumpAndSettle();
        expect(find.byType(AppSheetScaffold), findsNothing);
        final saved = decodeSchoolSitesStrict(store.source!).single;
        expect(saved.name, 'Retained school');
        expect(saved.loginUrl, 'https://school.example/login');
        expect(saved.isValid, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }

  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('add school entry ignores rapid duplicate taps', (tester) async {
    final provider = await _createProvider();
    await _pumpSchoolSitesPage(tester, provider);

    final addButton = find.byTooltip('Add school');
    expect(addButton, findsOneWidget);

    await tester.tap(addButton);
    await tester.tap(addButton, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.byType(AppSheetScaffold), findsOneWidget);
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

  testWidgets('JSON save retry and sharing keep the original site snapshot', (
    tester,
  ) async {
    final provider = await _createProvider();
    final exportService = _RetryThenShareExportService();
    final siteService = _VersionedSchoolSiteService();
    await _pumpSchoolSitesPage(
      tester,
      provider,
      exportService: exportService,
      siteService: siteService,
    );
    final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)));
    await tester.tap(find.byTooltip(l10n.importExport));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.schoolSitesSaveJson));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, l10n.retrySave));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, l10n.switchToShare));
    await tester.pumpAndSettle();

    expect(siteService.exports, 1);
    expect(exportService.saved, hasLength(2));
    expect(exportService.shared, hasLength(1));
    expect(exportService.saved.first.content, '{"snapshot":1}');
    expect(exportService.saved.last, same(exportService.saved.first));
    expect(exportService.shared.single, same(exportService.saved.first));
    expect(find.text(l10n.exportSwitchedToShare), findsOneWidget);
    expect(tester.takeException(), isNull);
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
    await tester.scrollUntilVisible(
      importButton,
      180,
      scrollable: _recoveryScrollable(),
    );
    await tester.pumpAndSettle();
    expect(importButton.hitTestable(), findsOneWidget);
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
      decodeSchoolSitesStrict(store.result.candidates.single.source)
          .single
          .name,
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
    await tester.scrollUntilVisible(
      startFresh,
      180,
      scrollable: _recoveryScrollable(),
    );
    await tester.pumpAndSettle();
    expect(startFresh.hitTestable(), findsOneWidget);
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

    expect(find.text('Existing'), findsNWidgets(2));
    final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)));
    await tester.tap(find.byTooltip(l10n.importExport));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.schoolSitesImportJson));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('school-sites-import-merge')));
    await tester.pumpAndSettle();

    expect(find.text('Existing'), findsNothing);
    expect(find.text('Restored'), findsNWidgets(2));
    expect(decodeSchoolSitesStrict(store.source!).single.name, 'Restored');
  });
}
