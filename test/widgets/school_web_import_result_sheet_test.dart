import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/l10n/app_locale.dart';
import 'package:sked/models/school_import_models.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/widgets/app_modal_sheet.dart';
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

Future<void> _pumpPreviewSheet(
  WidgetTester tester, {
  required TimetableProvider provider,
  required SchoolImportResponse response,
  bool canReplaceCurrent = false,
  TextScaler textScaler = TextScaler.noScaling,
  EdgeInsets viewInsets = EdgeInsets.zero,
  Locale locale = const Locale('en'),
  ValueChanged<SchoolImportApplyRequest?>? onResult,
}) {
  final periodTimeSets = provider.periodTimeSets;
  final initialPeriodTimeSetId = periodTimeSets.isEmpty
      ? ''
      : periodTimeSets.first.id;

  return tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Applied through MaterialApp.builder so it sits above the Navigator.
      // Wrapping `home` instead leaves modal routes — which is what this sheet
      // is — on the unscaled app-level MediaQuery.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: textScaler, viewInsets: viewInsets),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async {
                final result =
                    await showAppModalSheet<SchoolImportApplyRequest>(
                      context: context,
                      builder: (_) => SchoolWebImportResultSheet(
                        response: response,
                        canReplaceCurrent: canReplaceCurrent,
                        periodTimeSets: periodTimeSets,
                        initialPeriodTimeSetId: initialPeriodTimeSetId,
                        provider: provider,
                      ),
                    );
                onResult?.call(result);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _openPreviewSheet(WidgetTester tester) async {
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

AppLocalizations _sheetL10n(WidgetTester tester) {
  return AppLocalizations.of(
    tester.element(find.byType(SchoolWebImportResultSheet)),
  );
}

void main() {
  testWidgets('compact preview keeps its fixed primary action visible', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final provider = await _createProvider();
    final response = _buildResponse(
      name:
          'An unusually long imported timetable name for a program and cohort',
      meta: const SchoolImportMeta(
        sourceUrl: '',
        pageTitle: 'A very long school portal page title for preview layout verification',
        parser: 'Custom parser configuration with a verbose model and provider name',
        warnings: [
          'One imported row had an unusually long note and was normalized before it could be added to the timetable.',
          'Another warning intentionally contains enough content to exercise line wrapping at two times text scale.',
        ],
      ),
    );

    await _pumpPreviewSheet(
      tester,
      provider: provider,
      response: response,
      canReplaceCurrent: true,
      textScaler: const TextScaler.linear(2),
    );

    await _openPreviewSheet(tester);

    expect(find.byType(SchoolWebImportResultSheet), findsOneWidget);
    expect(find.byType(AppSheetScaffold), findsOneWidget);

    final l10n = _sheetL10n(tester);
    final primaryAction = find.widgetWithText(
      FilledButton,
      l10n.importAsNewTimetable,
    );
    final cancelAction = find.widgetWithText(TextButton, l10n.cancel);
    expect(primaryAction, findsOneWidget);
    expect(cancelAction, findsOneWidget);
    expect(tester.getRect(primaryAction).bottom, lessThanOrEqualTo(568));
    expect(tester.getRect(primaryAction).height, greaterThanOrEqualTo(48));
    expect(tester.getRect(cancelAction).height, greaterThanOrEqualTo(48));
    expect(
      find.text(
        'Another warning intentionally contains enough content to exercise line wrapping at two times text scale.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow footer pairs cancel and replace when both still fit', (
    tester,
  ) async {
    // Wide enough that cancel and replace still share a row, but not wide
    // enough for all three (the test font renders every glyph a full em wide,
    // so labels measure far wider here than with a real font).
    await tester.binding.setSurfaceSize(const Size(700, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final provider = await _createProvider();
    await _pumpPreviewSheet(
      tester,
      provider: provider,
      response: _buildResponse(),
      canReplaceCurrent: true,
    );
    await _openPreviewSheet(tester);

    final l10n = _sheetL10n(tester);
    final cancel = find.widgetWithText(TextButton, l10n.cancel);
    final replace = find.widgetWithText(
      OutlinedButton,
      l10n.replaceCurrentTimetable,
    );
    final addAsNew = find.widgetWithText(
      FilledButton,
      l10n.importAsNewTimetable,
    );

    final cancelRect = tester.getRect(cancel);
    final replaceRect = tester.getRect(replace);

    // Primary action on its own row, the other two sharing the row below it.
    expect(tester.getRect(addAsNew).bottom, lessThanOrEqualTo(cancelRect.top));
    expect(cancelRect.center.dy, closeTo(replaceRect.center.dy, 1));
    expect(cancelRect.right, lessThanOrEqualTo(replaceRect.left));
    // Replace takes the whole remainder rather than half of it.
    expect(replaceRect.right, closeTo(tester.getRect(addAsNew).right, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow footer stacks every action when the pair cannot fit', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final provider = await _createProvider();
    await _pumpPreviewSheet(
      tester,
      provider: provider,
      response: _buildResponse(),
      canReplaceCurrent: true,
      textScaler: const TextScaler.linear(1.6),
    );
    await _openPreviewSheet(tester);

    final l10n = _sheetL10n(tester);
    final cancelRect = tester.getRect(
      find.widgetWithText(TextButton, l10n.cancel),
    );
    final replaceRect = tester.getRect(
      find.widgetWithText(OutlinedButton, l10n.replaceCurrentTimetable),
    );

    // Each on its own row, and nothing spills past the sheet.
    expect(replaceRect.bottom, lessThanOrEqualTo(cancelRect.top));
    expect(replaceRect.left, greaterThanOrEqualTo(0));
    expect(replaceRect.right, lessThanOrEqualTo(320));
    expect(tester.takeException(), isNull);
  });

  testWidgets('parser details are collapsed by default and retain name draft', (
    tester,
  ) async {
    final provider = await _createProvider();
    const pageTitle = 'Student portal timetable export';
    const parser = 'Configured school parser';
    await _pumpPreviewSheet(
      tester,
      provider: provider,
      response: _buildResponse(
        meta: const SchoolImportMeta(
          sourceUrl: '',
          pageTitle: pageTitle,
          parser: parser,
          warnings: [],
        ),
      ),
    );
    await _openPreviewSheet(tester);

    final l10n = _sheetL10n(tester);
    final nameField = find.byType(TextField);
    final detailsHeader = find.text(l10n.schoolWebImportParserDetails);
    expect(nameField, findsOneWidget);
    expect(detailsHeader, findsOneWidget);
    expect(find.text(pageTitle), findsNothing);
    expect(find.text(parser), findsNothing);
    // The title is the accessible name and `expanded` carries the state, so the
    // expand/collapse wording is exposed as a hint instead of a second label.
    expect(
      tester.getSemantics(detailsHeader),
      matchesSemantics(
        label: l10n.schoolWebImportParserDetails,
        hint: l10n.schoolWebImportExpandParserDetails,
        isButton: true,
        hasExpandedState: true,
        isExpanded: false,
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
      ),
    );

    await tester.enterText(nameField, 'Edited imported timetable');
    await tester.tap(detailsHeader);
    await tester.pumpAndSettle();

    expect(find.text(pageTitle), findsOneWidget);
    expect(find.text(parser), findsOneWidget);
    expect(
      tester.getSemantics(detailsHeader),
      matchesSemantics(
        label: l10n.schoolWebImportParserDetails,
        hint: l10n.schoolWebImportCollapseParserDetails,
        isButton: true,
        hasExpandedState: true,
        isExpanded: true,
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
      ),
    );
    expect(
      tester.widget<TextField>(nameField).controller!.text,
      'Edited imported timetable',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('primary import action stays above the keyboard inset', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final provider = await _createProvider();
    await _pumpPreviewSheet(
      tester,
      provider: provider,
      response: _buildResponse(),
      canReplaceCurrent: true,
      viewInsets: const EdgeInsets.only(bottom: 220),
    );
    await _openPreviewSheet(tester);

    final primaryAction = find.widgetWithText(
      FilledButton,
      _sheetL10n(tester).importAsNewTimetable,
    );
    expect(primaryAction, findsOneWidget);
    expect(tester.getRect(primaryAction).bottom, lessThanOrEqualTo(624));
    expect(tester.takeException(), isNull);
  });

  testWidgets('double-tap on import only emits a single apply request', (
    tester,
  ) async {
    final provider = await _createProvider();
    final response = _buildResponse();

    final results = <SchoolImportApplyRequest?>[];
    await _pumpPreviewSheet(
      tester,
      provider: provider,
      response: response,
      onResult: results.add,
    );

    await _openPreviewSheet(tester);

    final importButton = find.widgetWithText(
      FilledButton,
      _sheetL10n(tester).importAsNewTimetable,
    );
    expect(importButton, findsOneWidget);
    expect((tester.widget(importButton) as FilledButton).onPressed, isNotNull);

    await tester.tap(importButton);
    await tester.tap(importButton, warnIfMissed: false);
    await tester.pump();

    expect(
      (tester.widget(importButton) as FilledButton).onPressed,
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
    final response = _buildResponse();

    final results = <SchoolImportApplyRequest?>[];
    await _pumpPreviewSheet(
      tester,
      provider: provider,
      response: response,
      onResult: results.add,
    );

    await _openPreviewSheet(tester);

    final cancelButton = find.widgetWithText(
      TextButton,
      _sheetL10n(tester).cancel,
    );
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
    await tester.binding.setSurfaceSize(const Size(840, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final provider = await _createProvider();
    final response = _buildResponse(withCourses: false);

    await _pumpPreviewSheet(
      tester,
      provider: provider,
      response: response,
      canReplaceCurrent: true,
    );

    await _openPreviewSheet(tester);

    final l10n = _sheetL10n(tester);
    final importButton = find.widgetWithText(
      FilledButton,
      l10n.importAsNewTimetable,
    );
    expect(importButton, findsOneWidget);
    expect(
      (tester.widget(importButton) as FilledButton).onPressed,
      isNull,
      reason: 'Import button must be disabled when the response has 0 courses.',
    );

    final replaceButton = find.widgetWithText(
      OutlinedButton,
      l10n.replaceCurrentTimetable,
    );
    expect(replaceButton, findsOneWidget);
    expect(
      (tester.widget(replaceButton) as OutlinedButton).onPressed,
      isNull,
      reason: 'Replace button must also be disabled when 0 courses.',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('start date picker ignores rapid duplicate taps', (tester) async {
    final provider = await _createProvider();
    final response = _buildResponse();

    await _pumpPreviewSheet(tester, provider: provider, response: response);

    await _openPreviewSheet(tester);

    final l10n = _sheetL10n(tester);
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
