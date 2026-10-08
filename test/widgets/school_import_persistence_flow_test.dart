import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/school_import_models.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/screens/app_home_screen.dart';
import 'package:sked/screens/school_html_import_page.dart';
import 'package:sked/screens/school_import_parse_page.dart';
import 'package:sked/screens/settings_page.dart';
import 'package:sked/services/privacy_service.dart';
import 'package:sked/services/school_import_api.dart';
import 'package:sked/widgets/app_modal_sheet.dart';
import 'package:sked/widgets/school_web_import_result_sheet.dart';

class _Storage implements TimetableStorage {
  _Storage(this.data);
  AppData data;
  int attempts = 0;
  int failures = 0;
  Object failure = const StorageWriteException('Temporary storage failure');
  Completer<void>? gate;
  StorageLoadResult? loadResult;

  @override
  Future<StorageLoadResult> load() async =>
      loadResult ??
      StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);

  @override
  Future<void> save(AppData data) async {
    attempts += 1;
    await gate?.future;
    if (failures > 0) {
      failures -= 1;
      throw failure;
    }
    this.data = AppData.decodeStorageSnapshot(data.encode());
  }

  @override
  Future<String?> filePath() async => 'memory://school-import-persistence';
}

class _NoPrivacyRequest extends PrivacyService {
  const _NoPrivacyRequest();
  @override
  Future<String?> fetchCurrentPrivacyPolicyVersion() async => null;
}

class _Provider extends TimetableProvider {
  _Provider({required super.storage})
    : super(
        systemLocaleCodeResolver: () => 'en',
        privacyService: const _NoPrivacyRequest(),
      );

  bool writable = true;
  bool restoring = false;
  Object? replacementDataSession;
  @override
  bool get canWrite => writable && super.canWrite;
  @override
  bool get isRestoringAppBackup => restoring || super.isRestoringAppBackup;
  @override
  Object get dataSessionToken =>
      replacementDataSession ?? super.dataSessionToken;

  void replaceDataSession() {
    replacementDataSession = Object();
    notifyListeners();
  }

  void setWriteAvailability({required bool writable, required bool restoring}) {
    this.writable = writable;
    this.restoring = restoring;
    notifyListeners();
  }
}

final _rawResult = jsonEncode({
  'name': 'Parsed timetable',
  'startDate': '2026-05-25',
  'totalWeeks': 18,
  'periodTimeSet': {
    'name': 'Imported periods',
    'periodTimes': [
      {'index': 1, 'startMinutes': 480, 'endMinutes': 525},
    ],
  },
  'courses': [
    {
      'name': 'Mathematics',
      'dayOfWeek': 1,
      'semesterWeeks': [1],
      'periods': [1],
      'startMinutes': 480,
      'endMinutes': 525,
    },
  ],
});

SchoolImportResponse _response() => SchoolImportApi.buildResponseFromDoneEvent(
  jsonDecode(_rawResult) as Map<String, dynamic>,
);

class _Api extends SchoolImportApi {
  int calls = 0;
  @override
  Stream<SchoolImportStreamEvent> importCurrentPageStream(
    SchoolImportPagePayload payload, {
    SchoolImportParserSettings? parserSettings,
    http.Client? client,
  }) {
    calls += 1;
    return Stream.fromIterable([
      ParseDelta(_rawResult),
      ParseDone(response: _response()),
    ]);
  }
}

Future<(_Provider, _Storage)> _provider() async {
  final initial = buildInitialAppData(
    buildDefaultPeriodTimes(),
    localeCode: 'en',
  );
  final periodSetId = initial.studentMode.periodTimeSets.first.id;
  final storage = _Storage(
    initial.copyWith(
      privacyPolicyAcceptedVersion: bundledPrivacyPolicyVersion,
      privacyPolicyAcceptedAtIso: '2026-10-01T00:00:00.000',
      aiApiSettings: const AiApiSettings(
        source: schoolImportParserSourceCustomOpenAi,
        customBaseUrl: 'https://api.example/v1',
        customApiKey: 'test-key',
        customModel: 'test-model',
      ),
      studentMode: initial.studentMode.copyWith(
        activeTimetableId: 'existing',
        timetables: [
          TimetableData(
            id: 'existing',
            config: TimetableConfig(
              name: 'Existing timetable',
              startDate: DateTime(2026, 5, 25),
              totalWeeks: 18,
              periodTimeSetId: periodSetId,
            ),
            courses: const [],
          ),
        ],
      ),
    ),
  );
  final provider = _Provider(storage: storage);
  await provider.load();
  return (provider, storage);
}

Future<GlobalKey<NavigatorState>> _openHtmlReview(
  WidgetTester tester,
  TimetableProvider provider,
  _Api api, {
  TargetPlatform platform = TargetPlatform.windows,
  bool appHome = false,
}) async {
  final navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    ChangeNotifierProvider<TimetableProvider>.value(
      value: provider,
      child: MaterialApp(
        navigatorKey: navigator,
        locale: const Locale('en'),
        theme: ThemeData(platform: platform),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: appHome
            ? const AppHomeScreen()
            : Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => SchoolHtmlImportPage(
                          initialContent: 'Monday period 1 Mathematics',
                          showReturnToWebPageButton: true,
                          api: api,
                        ),
                      ),
                    ),
                    child: const Text('Open import'),
                  ),
                ),
              ),
      ),
    ),
  );
  if (appHome) {
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined).hitTestable());
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
    unawaited(
      navigator.currentState!.push<void>(
        MaterialPageRoute(
          builder: (_) => SchoolHtmlImportPage(
            initialContent: 'Monday period 1 Mathematics',
            showReturnToWebPageButton: true,
            api: api,
          ),
        ),
      ),
    );
  } else {
    await tester.tap(find.text('Open import'));
  }
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Parse and import'));
  await tester.tap(find.text('Parse and import'));
  await tester.pumpAndSettle();
  expect(find.byType(SchoolImportParsePage), findsOneWidget);
  return navigator;
}

Finder get _name =>
    find.byKey(const ValueKey('school-import-parse-timetable-name'));
Finder get _weeks =>
    find.byKey(const ValueKey('school-import-parse-total-weeks'));
Finder get _add => find.widgetWithText(FilledButton, 'Import as new timetable');
Finder get _replace =>
    find.widgetWithText(OutlinedButton, 'Replace current timetable');

Future<void> _tapImport(WidgetTester tester, {bool replace = false}) async {
  await tester.tap(replace ? _replace : _add);
  await tester.pump();
  if (replace) {
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }
}

void main() {
  testWidgets(
    'AppHome retains a reviewed import after a confirmed storage failure',
    (tester) async {
      final (provider, storage) = await _provider();
      addTearDown(provider.dispose);
      final api = _Api();
      await _openHtmlReview(tester, provider, api, appHome: true);
      expect(find.byType(AppHomeScreen, skipOffstage: false), findsOneWidget);
      await tester.enterText(_name, 'Root recovery draft');
      storage.failures = 1;
      await _tapImport(tester);
      await tester.pumpAndSettle();
      expect(provider.canWrite, isFalse);
      expect(find.byType(SchoolImportParsePage), findsOneWidget);
      expect(
        tester.widget<TextField>(_name).controller!.text,
        'Root recovery draft',
      );
      expect(tester.widget<FilledButton>(_add).onPressed, isNull);
      final discardBundled = find.text('Discard bundled sets');
      await tester.ensureVisible(discardBundled);
      await tester.tap(discardBundled);
      await tester.pumpAndSettle();
      final periodSelector = find.byKey(
        const ValueKey('school-import-parse-period-time-set'),
      );
      expect(
        tester
            .widget<InkWell>(
              find.descendant(
                of: periodSelector,
                matching: find.byType(InkWell),
              ),
            )
            .onTap,
        isNull,
        reason: 'A retained read-only draft must not open the period-set mutation tools.',
      );
      await tester.tap(find.widgetWithText(TextButton, 'Retry'));
      await tester.pumpAndSettle();
      expect(provider.canWrite, isTrue);
      await _tapImport(tester);
      await tester.pumpAndSettle();
      expect(find.byType(SchoolImportParsePage), findsNothing);
      expect(
        storage.data.studentMode.timetables.last.config.name,
        'Root recovery draft',
      );
      expect(api.calls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'leaving a protected review while blocked returns to global recovery',
    (tester) async {
      final (provider, storage) = await _provider();
      addTearDown(provider.dispose);
      await _openHtmlReview(tester, provider, _Api(), appHome: true);
      storage.failures = 1;
      await _tapImport(tester);
      await tester.pumpAndSettle();
      expect(find.byType(SchoolImportParsePage), findsOneWidget);
      await tester.tap(find.byTooltip('Cancel'));
      await tester.pumpAndSettle();
      expect(
        find.byType(SchoolImportParsePage, skipOffstage: false),
        findsNothing,
      );
      expect(
        find.byType(SchoolHtmlImportPage, skipOffstage: false),
        findsNothing,
      );
      expect(find.byType(SettingsPage, skipOffstage: false), findsNothing);
      expect(
        find.byKey(const ValueKey('data-recovery-screen')),
        findsOneWidget,
      );
      expect(provider.canWrite, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'an unknown import write outcome still clears all routes for recovery',
    (tester) async {
      final (provider, storage) = await _provider();
      addTearDown(provider.dispose);
      final api = _Api();
      await _openHtmlReview(tester, provider, api, appHome: true);
      storage.failures = 1;
      storage.failure = const StorageWriteStateUnknownException(
        writeError: 'Cannot confirm write',
        rollbackError: 'Cannot confirm rollback',
      );
      await _tapImport(tester);
      await tester.pumpAndSettle();
      expect(provider.canWrite, isFalse);
      expect(provider.isStorageWriteStateUnknown, isTrue);
      expect(
        find.byType(SchoolImportParsePage, skipOffstage: false),
        findsNothing,
      );
      expect(
        find.byType(SchoolHtmlImportPage, skipOffstage: false),
        findsNothing,
      );
      expect(find.byType(SettingsPage, skipOffstage: false), findsNothing);
      expect(
        find.byKey(const ValueKey('data-recovery-screen')),
        findsOneWidget,
      );
      expect(api.calls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  for (final status in [
    RecoveryStatus.failedBackupRestore,
    RecoveryStatus.unsupportedVersion,
  ]) {
    testWidgets(
      'a protected review yields to global recovery if reloading reports $status',
      (tester) async {
        final (provider, storage) = await _provider();
        addTearDown(provider.dispose);
        await _openHtmlReview(tester, provider, _Api(), appHome: true);
        storage.failures = 1;
        await _tapImport(tester);
        await tester.pumpAndSettle();
        expect(find.byType(SchoolImportParsePage), findsOneWidget);
        storage.loadResult = StorageLoadResult(
          data: null,
          recoveryStatus: status,
        );
        await tester.tap(find.widgetWithText(TextButton, 'Retry'));
        await tester.pumpAndSettle();
        expect(provider.canWrite, isFalse);
        expect(
          find.byType(SchoolImportParsePage, skipOffstage: false),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('data-recovery-screen')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'a protected review cannot survive replacement of its data session',
    (tester) async {
      final (provider, storage) = await _provider();
      addTearDown(provider.dispose);
      await _openHtmlReview(tester, provider, _Api(), appHome: true);
      storage.failures = 1;
      await _tapImport(tester);
      await tester.pumpAndSettle();
      expect(find.byType(SchoolImportParsePage), findsOneWidget);
      provider.replaceDataSession();
      await tester.pumpAndSettle();
      expect(
        find.byType(SchoolImportParsePage, skipOffstage: false),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('data-recovery-screen')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    for (final replace in [false, true]) {
      testWidgets(
        'failed $platform import keeps the reviewed draft and retries once (replace: $replace)',
        (tester) async {
          await tester.binding.setSurfaceSize(
            platform == TargetPlatform.windows
                ? const Size(1280, 1000)
                : const Size(393, 844),
          );
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final (provider, storage) = await _provider();
          addTearDown(provider.dispose);
          final api = _Api();
          await _openHtmlReview(tester, provider, api, platform: platform);
          await tester.enterText(_name, 'Corrected timetable');
          await tester.enterText(_weeks, '22');
          final date = find.byKey(
            const ValueKey('school-import-parse-start-date'),
          );
          await tester.ensureVisible(date);
          await tester.tap(date);
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('sked-date-2026-05-27')));
          await tester.tap(find.byKey(const ValueKey('sked-date-confirm')));
          await tester.pumpAndSettle();
          await tester.tap(
            find.widgetWithText(OutlinedButton, 'Edit parsed result'),
          );
          await tester.pumpAndSettle();
          final field = find.byType(TextField);
          final edited = tester
              .widget<TextField>(field)
              .controller!
              .text
              .replaceFirst('Mathematics', 'Physics');
          await tester.enterText(field, edited);
          await tester.tap(find.byTooltip('Confirm'));
          await tester.pumpAndSettle();

          final baseline = storage.attempts;
          storage.failures = 1;
          storage.gate = Completer<void>();
          await _tapImport(tester, replace: replace);
          await tester.pump(const Duration(milliseconds: 100));
          expect(find.text('Saving changes...'), findsOneWidget);
          expect(tester.widget<FilledButton>(_add).onPressed, isNull);
          expect(tester.widget<TextField>(_name).enabled, isFalse);
          await tester.binding.handlePopRoute();
          await tester.pump();
          expect(find.byType(SchoolImportParsePage), findsOneWidget);
          final sourceReturn = find.widgetWithText(
            TextButton,
            'Back to webpage',
            skipOffstage: false,
          );
          expect(tester.widget<TextButton>(sourceReturn).onPressed, isNull);
          expect(storage.attempts, baseline + 1);

          storage.gate!.complete();
          storage.gate = null;
          await tester.pumpAndSettle();
          expect(provider.canWrite, isFalse);
          expect(
            find.textContaining('Sked cannot access local storage right now.'),
            findsOneWidget,
          );
          expect(find.byType(SchoolImportParsePage), findsOneWidget);
          expect(
            tester.widget<TextField>(_name).controller!.text,
            'Corrected timetable',
          );
          expect(tester.widget<TextField>(_weeks).controller!.text, '22');
          expect(find.text('2026-05-27'), findsOneWidget);
          expect(
            storage.data.studentMode.timetables.single.config.name,
            'Existing timetable',
          );
          expect(api.calls, 1);

          await tester.tap(find.widgetWithText(TextButton, 'Retry'));
          await tester.pumpAndSettle();
          expect(provider.canWrite, isTrue);
          expect(
            tester.widget<TextField>(_name).controller!.text,
            'Corrected timetable',
          );
          await _tapImport(tester, replace: replace);
          await tester.pumpAndSettle();
          expect(find.text('Open import'), findsOneWidget);
          expect(find.byType(SchoolImportParsePage), findsNothing);
          expect(find.byType(SchoolHtmlImportPage), findsNothing);
          expect(api.calls, 1);
          expect(storage.attempts, baseline + 2);
          final timetables = storage.data.studentMode.timetables;
          expect(timetables, hasLength(replace ? 1 : 2));
          final imported = timetables.singleWhere(
            (item) => item.config.name == 'Corrected timetable',
          );
          expect(imported.config.totalWeeks, 22);
          expect(imported.config.startDate, DateTime(2026, 5, 27));
          expect(imported.courses.single.name, 'Physics');
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'review retains local corrections while restore and storage gates block import',
    (tester) async {
      final (provider, storage) = await _provider();
      addTearDown(provider.dispose);
      final api = _Api();
      await _openHtmlReview(tester, provider, api);
      await tester.enterText(_name, 'Retained draft');
      final baseline = storage.attempts;
      final l10n = AppLocalizations.of(
        tester.element(find.byType(SchoolImportParsePage)),
      );
      provider.setWriteAvailability(writable: true, restoring: true);
      await tester.pump();
      expect(tester.widget<FilledButton>(_add).onPressed, isNull);
      expect(find.text(l10n.backupRestoreInProgressMessage), findsOneWidget);
      provider.setWriteAvailability(writable: false, restoring: false);
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(_add).onPressed, isNull);
      expect(find.text(l10n.dataRecoveryIoFailureMessage), findsOneWidget);
      expect(storage.attempts, baseline);
      provider.setWriteAvailability(writable: true, restoring: false);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(_name).controller!.text,
        'Retained draft',
      );
      await _tapImport(tester);
      await tester.pumpAndSettle();
      expect(api.calls, 1);
      expect(
        storage.data.studentMode.timetables.last.config.name,
        'Retained draft',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a recoverable apply failure retries the same draft without parsing again',
    (tester) async {
      final (provider, storage) = await _provider();
      addTearDown(provider.dispose);
      final api = _Api();
      await _openHtmlReview(tester, provider, api);
      await tester.enterText(_name, 'Retry this draft');
      storage.failure = StateError('Import write rejected before commit');
      storage.failures = 1;
      final baseline = storage.attempts;
      await _tapImport(tester);
      await tester.pumpAndSettle();
      expect(find.text('Save failed. Please try again later.'), findsOneWidget);
      expect(tester.widget<FilledButton>(_add).onPressed, isNotNull);
      expect(
        tester.widget<TextField>(_name).controller!.text,
        'Retry this draft',
      );
      await _tapImport(tester);
      await tester.pumpAndSettle();
      expect(api.calls, 1);
      expect(storage.attempts, baseline + 2);
      expect(
        storage.data.studentMode.timetables.last.config.name,
        'Retry this draft',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a replacement confirmation cannot switch its target while open',
    (tester) async {
      final (provider, storage) = await _provider();
      addTearDown(provider.dispose);
      await provider.addTimetable(
        TimetableConfig(
          name: 'Another timetable',
          startDate: DateTime(2026, 5, 25),
          totalWeeks: 18,
          periodTimeSetId: provider.periodTimeSets.first.id,
        ),
      );
      final otherId = provider.activeTimetableOrNull!.id;
      await provider.switchTimetable('existing');
      final api = _Api();
      await _openHtmlReview(tester, provider, api);
      await tester.enterText(_name, 'Keep the unsubmitted draft');
      await tester.tap(_replace);
      await tester.pumpAndSettle();
      await provider.switchTimetable(otherId);
      final baseline = storage.attempts;
      await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await tester.pumpAndSettle();
      expect(find.byType(SchoolImportParsePage), findsOneWidget);
      expect(storage.attempts, baseline);
      expect(
        storage.data.studentMode.timetables.map((table) => table.config.name),
        containsAll(['Existing timetable', 'Another timetable']),
      );
      expect(
        tester.widget<TextField>(_name).controller!.text,
        'Keep the unsubmitted draft',
      );
      expect(api.calls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'save completion closes its import routes and preserves a newer route',
    (tester) async {
      final (provider, storage) = await _provider();
      addTearDown(provider.dispose);
      final api = _Api();
      final navigator = await _openHtmlReview(tester, provider, api);
      storage.gate = Completer<void>();
      await _tapImport(tester);
      await tester.pump();
      unawaited(
        navigator.currentState!.push<void>(
          MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('Newer page')),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      storage.gate!.complete();
      storage.gate = null;
      await tester.pumpAndSettle();
      expect(find.text('Newer page'), findsOneWidget);
      expect(
        find.byType(SchoolImportParsePage, skipOffstage: false),
        findsNothing,
      );
      expect(
        find.byType(SchoolHtmlImportPage, skipOffstage: false),
        findsNothing,
      );
      expect(storage.data.studentMode.timetables, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'removing the source route retires its review without importing',
    (tester) async {
      final (provider, storage) = await _provider();
      addTearDown(provider.dispose);
      final api = _Api();
      final navigator = await _openHtmlReview(tester, provider, api);
      final source = tester.element(
        find.byType(SchoolHtmlImportPage, skipOffstage: false),
      );
      navigator.currentState!.removeRoute(ModalRoute.of(source)!);
      await tester.pumpAndSettle();
      expect(
        find.byType(SchoolImportParsePage, skipOffstage: false),
        findsNothing,
      );
      expect(find.text('Open import'), findsOneWidget);
      expect(storage.data.studentMode.timetables, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'legacy preview keeps its draft after failure and blocks dismissals while saving',
    (tester) async {
      final (provider, storage) = await _provider();
      addTearDown(provider.dispose);
      final results = <SchoolImportApplyRequest?>[];
      await tester.pumpWidget(
        ChangeNotifierProvider<TimetableProvider>.value(
          value: provider,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    results.add(
                      await showAppModalSheet<SchoolImportApplyRequest>(
                        context: context,
                        isDismissible: false,
                        enableDrag: false,
                        builder: (_) => SchoolWebImportResultSheet(
                          response: _response(),
                          provider: provider,
                          canReplaceCurrent: true,
                          initialPeriodTimeSetId:
                              provider.periodTimeSets.first.id,
                          onApply: provider.applySchoolImportRequest,
                        ),
                      ),
                    );
                  },
                  child: const Text('Preview'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Legacy correction');
      storage.failures = 1;
      storage.gate = Completer<void>();
      await _tapImport(tester);
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
            .onPressed,
        isNull,
      );
      await tester.binding.handlePopRoute();
      await tester.tapAt(const Offset(2, 2));
      await tester.drag(
        find.text('Import preview'),
        const Offset(0, 600),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(find.byType(SchoolWebImportResultSheet), findsOneWidget);
      expect(results, isEmpty);
      storage.gate!.complete();
      storage.gate = null;
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Sked cannot access local storage right now.'),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Legacy correction',
      );
      await tester.tap(find.widgetWithText(TextButton, 'Retry'));
      await tester.pumpAndSettle();
      await _tapImport(tester);
      await tester.pumpAndSettle();
      expect(results.single!.response.timetable.name, 'Legacy correction');
      expect(storage.data.studentMode.timetables, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );
}
