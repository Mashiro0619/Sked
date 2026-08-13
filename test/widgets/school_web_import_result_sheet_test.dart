import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/l10n/app_locale.dart';
import 'package:sked/models/school_import_models.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/widgets/school_web_import_result_sheet.dart';

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
  Future<String?> filePath() async => 'memory://sheet-test';
}

SchoolImportResponse _buildResponse({
  bool withCourses = true,
  String name = 'Sample',
  SchoolImportMeta meta = const SchoolImportMeta(
    sourceUrl: '',
    pageTitle: '',
    parser: '',
    warnings: [],
  ),
  ImportedPeriodTimeSetDraft periodTimeSet = const ImportedPeriodTimeSetDraft(
    name: '',
    periodTimes: [],
  ),
}) {
  return SchoolImportResponse(
    meta: meta,
    timetable: SchoolImportTimetableDraft(
      name: name,
      startDate: DateTime(2026, 5, 25),
      totalWeeks: 18,
      periodTimeSet: periodTimeSet,
      courses: withCourses
          ? const [
              ImportedCourseDraft(
                name: 'Sample course',
                teacher: '',
                location: '',
                dayOfWeek: 1,
                semesterWeeks: [],
                periods: [1],
                startMinutes: 480,
                endMinutes: 540,
                credit: 0,
                remarks: '',
                customFields: <String, dynamic>{},
              ),
            ]
          : const [],
    ),
  );
}

Future<TimetableProvider> _createProvider() async {
  final provider = TimetableProvider(
    storage: _MemoryTimetableStorage(
      buildInitialAppData(buildDefaultPeriodTimes()),
    ),
    systemLocaleCodeResolver: () => defaultLocaleCode,
  );
  await provider.load();
  return provider;
}

void main() {
  testWidgets('preview cards fit compact phone width with long text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final provider = await _createProvider();
    final periodTimeSets = provider.periodTimeSets;
    final response = _buildResponse(
      name: 'Imported timetable with a very long academic program name and cohort',
      meta: const SchoolImportMeta(
        sourceUrl: '',
        pageTitle: 'Very long school portal page title for preview layout verification',
        parser: 'Custom parser configuration with a verbose model and provider name',
        warnings: [
          'One imported row had an unusually long note and was normalized.',
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  await showModalBottomSheet<SchoolImportApplyRequest>(
                    context: context,
                    isScrollControlled: true,
                    showDragHandle: true,
                    constraints: const BoxConstraints(maxWidth: 680),
                    builder: (_) => SchoolWebImportResultSheet(
                      response: response,
                      canReplaceCurrent: true,
                      periodTimeSets: periodTimeSets,
                      initialPeriodTimeSetId: periodTimeSets.first.id,
                      provider: provider,
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byType(SchoolWebImportResultSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('double-tap on import only emits a single apply request', (
    tester,
  ) async {
    final provider = await _createProvider();
    final periodTimeSets = provider.periodTimeSets;
    expect(periodTimeSets, isNotEmpty);
    final initialPeriodTimeSetId = periodTimeSets.first.id;
    final response = _buildResponse();

    final results = <SchoolImportApplyRequest?>[];
    late String importLabel;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            importLabel = AppLocalizations.of(context).importAsNewTimetable;
            return Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    final outcome =
                        await showModalBottomSheet<SchoolImportApplyRequest>(
                          context: context,
                          isScrollControlled: true,
                          showDragHandle: true,
                          constraints: const BoxConstraints(maxWidth: 680),
                          builder: (_) => SchoolWebImportResultSheet(
                            response: response,
                            canReplaceCurrent: false,
                            periodTimeSets: periodTimeSets,
                            initialPeriodTimeSetId: initialPeriodTimeSetId,
                            provider: provider,
                          ),
                        );
                    results.add(outcome);
                  },
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final importButton = find.widgetWithText(OutlinedButton, importLabel);
    expect(importButton, findsOneWidget);
    expect(
      (tester.widget(importButton) as OutlinedButton).onPressed,
      isNotNull,
    );

    await tester.tap(importButton);
    await tester.tap(importButton, warnIfMissed: false);
    await tester.pump();

    expect(
      (tester.widget(importButton) as OutlinedButton).onPressed,
      isNull,
      reason:
          'After first tap, import button must be disabled to block re-entry.',
    );

    await tester.pumpAndSettle();

    expect(results, hasLength(1));
    expect(results.single, isNotNull);
    expect(results.single!.mode, TimetableImportMode.addAsNew);
  });

  testWidgets('cancel button cannot trigger a second pop', (tester) async {
    final provider = await _createProvider();
    final periodTimeSets = provider.periodTimeSets;
    final initialPeriodTimeSetId = periodTimeSets.isEmpty
        ? ''
        : periodTimeSets.first.id;
    final response = _buildResponse();

    final results = <SchoolImportApplyRequest?>[];
    late String cancelLabel;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            cancelLabel = AppLocalizations.of(context).cancel;
            return Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    final outcome =
                        await showModalBottomSheet<SchoolImportApplyRequest>(
                          context: context,
                          isScrollControlled: true,
                          showDragHandle: true,
                          constraints: const BoxConstraints(maxWidth: 680),
                          builder: (_) => SchoolWebImportResultSheet(
                            response: response,
                            canReplaceCurrent: false,
                            periodTimeSets: periodTimeSets,
                            initialPeriodTimeSetId: initialPeriodTimeSetId,
                            provider: provider,
                          ),
                        );
                    results.add(outcome);
                  },
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final cancelButton = find.widgetWithText(TextButton, cancelLabel);
    expect(cancelButton, findsOneWidget);

    await tester.tap(cancelButton);
    await tester.tap(cancelButton, warnIfMissed: false);
    await tester.pump();

    expect(
      (tester.widget(cancelButton) as TextButton).onPressed,
      isNull,
      reason:
          'Cancel button must be disabled after first tap to block re-entry.',
    );

    await tester.pumpAndSettle();
    expect(results, [isNull]);
  });

  testWidgets('import buttons stay disabled when the response has no courses', (
    tester,
  ) async {
    final provider = await _createProvider();
    final periodTimeSets = provider.periodTimeSets;
    final initialPeriodTimeSetId = periodTimeSets.isEmpty
        ? ''
        : periodTimeSets.first.id;
    final response = _buildResponse(withCourses: false);

    late String importLabel;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            importLabel = AppLocalizations.of(context).importAsNewTimetable;
            return Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    await showModalBottomSheet<SchoolImportApplyRequest>(
                      context: context,
                      isScrollControlled: true,
                      showDragHandle: true,
                      constraints: const BoxConstraints(maxWidth: 680),
                      builder: (_) => SchoolWebImportResultSheet(
                        response: response,
                        canReplaceCurrent: true,
                        periodTimeSets: periodTimeSets,
                        initialPeriodTimeSetId: initialPeriodTimeSetId,
                        provider: provider,
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final importButton = find.widgetWithText(OutlinedButton, importLabel);
    expect(importButton, findsOneWidget);
    expect(
      (tester.widget(importButton) as OutlinedButton).onPressed,
      isNull,
      reason: 'Import button must be disabled when the response has 0 courses.',
    );

    final replaceLabel = AppLocalizations.of(
      tester.element(find.byType(SchoolWebImportResultSheet)),
    ).replaceCurrentTimetable;
    final replaceButton = find.widgetWithText(FilledButton, replaceLabel);
    expect(replaceButton, findsOneWidget);
    expect(
      (tester.widget(replaceButton) as FilledButton).onPressed,
      isNull,
      reason: 'Replace button must also be disabled when 0 courses.',
    );
  });

  testWidgets('start date picker ignores rapid duplicate taps', (tester) async {
    final provider = await _createProvider();
    final periodTimeSets = provider.periodTimeSets;
    final response = _buildResponse();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  await showModalBottomSheet<SchoolImportApplyRequest>(
                    context: context,
                    isScrollControlled: true,
                    showDragHandle: true,
                    constraints: const BoxConstraints(maxWidth: 680),
                    builder: (_) => SchoolWebImportResultSheet(
                      response: response,
                      canReplaceCurrent: false,
                      periodTimeSets: periodTimeSets,
                      initialPeriodTimeSetId: periodTimeSets.first.id,
                      provider: provider,
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(SchoolWebImportResultSheet)),
    );
    final startDateTile = find.byKey(
      const ValueKey('school-import-start-date-tile'),
    );
    expect(startDateTile, findsOneWidget);

    await tester.tap(startDateTile);
    await tester.tap(startDateTile, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(DatePickerDialog),
        matching: find.widgetWithText(TextButton, l10n.cancel),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsNothing);
    expect(find.byType(SchoolWebImportResultSheet), findsOneWidget);
  });
}
