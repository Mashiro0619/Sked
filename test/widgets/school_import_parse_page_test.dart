import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/l10n/app_locale.dart';
import 'package:sked/models/school_import_models.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/screens/school_import_parse_page.dart';
import 'package:sked/services/school_import_api.dart';

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
  Future<String?> filePath() async => 'memory://parse-page-test';
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

const _rawResponse = '''{
  "name": "Parsed timetable",
  "startDate": "2026-05-25",
  "totalWeeks": 18,
  "periodTimeSet": {
    "name": "Default",
    "periodTimes": [
      {"index": 1, "startMinutes": 480, "endMinutes": 525}
    ]
  },
  "courses": [
    {
      "name": "Mathematics",
      "dayOfWeek": 1,
      "semesterWeeks": [1],
      "periods": [1],
      "startMinutes": 480,
      "endMinutes": 525
    }
  ],
  "unknownField": {"kept": true}
}''';

SchoolImportResponse _response() {
  return SchoolImportResponse(
    meta: const SchoolImportMeta(
      sourceUrl: 'https://school.example',
      pageTitle: 'School portal',
      parser: 'Test parser',
      warnings: ['Check the imported week range.'],
    ),
    timetable: SchoolImportTimetableDraft(
      name: 'Parsed timetable',
      startDate: DateTime(2026, 5, 25),
      totalWeeks: 18,
      periodTimeSet: const ImportedPeriodTimeSetDraft(
        name: 'Default',
        periodTimes: [
          ImportedPeriodTimeDraft(index: 1, startMinutes: 480, endMinutes: 525),
        ],
      ),
      courses: const [
        ImportedCourseDraft(
          name: 'Mathematics',
          teacher: '',
          location: '',
          dayOfWeek: 1,
          semesterWeeks: [1],
          periods: [1],
          startMinutes: 480,
          endMinutes: 525,
          credit: 0,
          remarks: '',
          customFields: <String, dynamic>{},
        ),
      ],
    ),
  );
}

SchoolImportResponse _responseWithMaxCourseWeek(int week) {
  final base = _response();
  final course = base.timetable.courses.single;
  return base.copyWith(
    timetable: base.timetable.copyWith(
      courses: [
        ImportedCourseDraft(
          name: course.name,
          teacher: course.teacher,
          location: course.location,
          dayOfWeek: course.dayOfWeek,
          semesterWeeks: [1, week],
          periods: course.periods,
          startMinutes: course.startMinutes,
          endMinutes: course.endMinutes,
          credit: course.credit,
          remarks: course.remarks,
          customFields: course.customFields,
        ),
      ],
    ),
  );
}

Future<void> _pumpPage(
  WidgetTester tester,
  StreamController<SchoolImportStreamEvent> controller,
) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SchoolImportParsePage(stream: controller.stream),
    ),
  );
  await tester.pump();
}

Future<List<SchoolImportParseOutcome?>> _pumpDirectPage(
  WidgetTester tester,
  StreamController<SchoolImportStreamEvent> controller,
  TimetableProvider provider, {
  bool canReplaceCurrent = false,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  final results = <SchoolImportParseOutcome?>[];
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              final result = await Navigator.of(context)
                  .push<SchoolImportParseOutcome>(
                    MaterialPageRoute(
                      builder: (_) => SchoolImportParsePage(
                        stream: controller.stream,
                        provider: provider,
                        canReplaceCurrent: canReplaceCurrent,
                        initialPeriodTimeSetId:
                            provider.activePeriodTimeSetOrNull?.id ??
                            provider.periodTimeSets.firstOrNull?.id,
                      ),
                    ),
                  );
              results.add(result);
            },
            child: const Text('Open parse page'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open parse page'));
  await tester.pump();
  return results;
}

void main() {
  testWidgets('shows structured result before continuing import', (
    tester,
  ) async {
    final controller = StreamController<SchoolImportStreamEvent>();
    addTearDown(controller.close);
    await _pumpPage(tester, controller);

    controller.add(const ParseDelta(_rawResponse));
    controller.add(ParseDone(response: _response()));
    controller.add(const ParseDelta('late mutation'));
    await tester.pump();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(SchoolImportParsePage)),
    );
    expect(find.text(l10n.schoolImportParsePageComplete), findsNothing);
    expect(find.text('Parsed timetable'), findsOneWidget);
    expect(find.textContaining('late mutation'), findsNothing);
    expect(find.text(l10n.schoolImportParsePageRawContent), findsNothing);
    expect(find.text('unknownField'), findsNothing);
    expect(find.text('Check the imported week range.'), findsNothing);
    expect(
      find.widgetWithText(FilledButton, l10n.schoolImportParsePageContinue),
      findsOneWidget,
    );

    final warningHeader = find.text(l10n.schoolWebImportWarnings);
    await tester.tap(warningHeader);
    await tester.pumpAndSettle();
    expect(find.text('Check the imported week range.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'streaming preview remains bounded and cancel returns immediately',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var canceled = false;
      final controller = StreamController<SchoolImportStreamEvent>(
        onCancel: () {
          canceled = true;
        },
      );
      addTearDown(controller.close);
      await _pumpPage(tester, controller);

      controller.add(ParseDelta('x' * 10000));
      await tester.pump();
      expect(
        find.widgetWithText(FilledButton, 'Continue import'),
        findsNothing,
      );
      expect(find.widgetWithText(TextButton, 'Cancel'), findsNothing);
      final preview = tester.widget<SelectableText>(
        find.byType(SelectableText),
      );
      expect(preview.data!.length, lessThanOrEqualTo(4096));

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(canceled, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'keeps the completed result pinned when streaming was at bottom',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final controller = StreamController<SchoolImportStreamEvent>();
      addTearDown(controller.close);
      await _pumpPage(tester, controller);

      controller.add(ParseDelta(List<String>.filled(220, 'line').join('\n')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      expect(
        scrollable.position.pixels,
        closeTo(scrollable.position.maxScrollExtent, 1),
      );

      controller.add(ParseDone(response: _response()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        scrollable.position.pixels,
        closeTo(scrollable.position.maxScrollExtent, 1),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('stops following streamed output after the user scrolls up', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = StreamController<SchoolImportStreamEvent>();
    addTearDown(controller.close);
    await _pumpPage(tester, controller);

    controller.add(ParseDelta(List<String>.filled(160, 'line').join('\n')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    await tester.pump(const Duration(milliseconds: 120));

    final list = find.byType(ListView);
    await tester.drag(list, const Offset(0, 10000));
    // The parse page intentionally keeps its status spinner alive while the
    // stream is open, so settling the whole widget tree would never finish.
    await tester.pump(const Duration(milliseconds: 300));
    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    expect(scrollable.position.pixels, 0);

    controller.add(ParseDelta(List<String>.filled(80, 'later').join('\n')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    await tester.pump(const Duration(milliseconds: 120));
    expect(scrollable.position.pixels, 0);

    await tester.drag(list, const Offset(0, -10000));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      scrollable.position.pixels,
      closeTo(scrollable.position.maxScrollExtent, 1),
    );

    controller.add(ParseDelta(List<String>.filled(40, 'tail').join('\n')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    await tester.pump(const Duration(milliseconds: 120));
    expect(
      scrollable.position.pixels,
      closeTo(scrollable.position.maxScrollExtent, 1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('parse errors are terminal and keep the error state', (
    tester,
  ) async {
    final controller = StreamController<SchoolImportStreamEvent>();
    addTearDown(controller.close);
    await _pumpPage(tester, controller);

    controller.add(const ParseDelta('partial response'));
    controller.add(const ParseError('Parser stopped unexpectedly.'));
    controller.add(ParseDone(response: _response()));
    await tester.pump();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(SchoolImportParsePage)),
    );
    expect(find.text(l10n.schoolImportParsePageFailed), findsOneWidget);
    expect(find.text('Parser stopped unexpectedly.'), findsOneWidget);
    expect(find.text(l10n.schoolImportParsePageComplete), findsNothing);
  });

  testWidgets(
    'direct completion keeps metadata editable and warns for a short week range',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final provider = await _createProvider();
      addTearDown(provider.dispose);
      final controller = StreamController<SchoolImportStreamEvent>();
      addTearDown(controller.close);
      await _pumpDirectPage(
        tester,
        controller,
        provider,
        canReplaceCurrent: true,
      );

      controller.add(ParseDone(response: _responseWithMaxCourseWeek(20)));
      await tester.pump();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(SchoolImportParsePage)),
      );
      expect(
        find.byKey(const ValueKey('school-import-parse-total-weeks')),
        findsOneWidget,
      );
      expect(find.text(l10n.schoolImportParsePageComplete), findsNothing);
      expect(find.text(l10n.schoolImportParsePageRawContent), findsNothing);
      expect(find.widgetWithText(TextButton, l10n.cancel), findsNothing);
      expect(find.text('Check the imported week range.'), findsNothing);

      final totalWeeks = find.byKey(
        const ValueKey('school-import-parse-total-weeks'),
      );
      await tester.enterText(totalWeeks, '10');
      await tester.pump();
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Tooltip && widget.message?.contains('week 20') == true,
        ),
        findsOneWidget,
      );

      await tester.enterText(totalWeeks, '20');
      await tester.pump();
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Tooltip && widget.message?.contains('week 20') == true,
        ),
        findsNothing,
      );
      expect(
        find.widgetWithText(FilledButton, l10n.importAsNewTimetable),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(OutlinedButton, l10n.replaceCurrentTimetable),
        findsOneWidget,
      );

      await tester.tap(find.text(l10n.schoolWebImportWarnings));
      await tester.pumpAndSettle();
      expect(find.text('Check the imported week range.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('replacement action asks for confirmation before submitting', (
    tester,
  ) async {
    final provider = await _createProvider();
    addTearDown(provider.dispose);
    final controller = StreamController<SchoolImportStreamEvent>();
    addTearDown(controller.close);
    final results = await _pumpDirectPage(
      tester,
      controller,
      provider,
      canReplaceCurrent: true,
    );

    controller.add(ParseDone(response: _response()));
    await tester.pump();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(SchoolImportParsePage)),
    );
    final replace = find.widgetWithText(
      OutlinedButton,
      l10n.replaceCurrentTimetable,
    );
    expect(replace, findsOneWidget);

    await tester.tap(replace);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text(l10n.replaceCurrentTimetableConfirmTitle), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, l10n.cancel),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SchoolImportParsePage), findsOneWidget);
    expect(results, isEmpty);

    await tester.tap(replace);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, l10n.confirm),
      ),
    );
    await tester.pumpAndSettle();

    expect(results, hasLength(1));
    expect(
      results.single?.applyRequest?.mode,
      TimetableImportMode.replaceActive,
    );
    expect(find.byType(SchoolImportParsePage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('large text uses the compact action layout on a wide page', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(840, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final provider = await _createProvider();
    addTearDown(provider.dispose);
    final controller = StreamController<SchoolImportStreamEvent>();
    addTearDown(controller.close);
    await _pumpDirectPage(
      tester,
      controller,
      provider,
      textScaler: const TextScaler.linear(1.6),
    );

    controller.add(ParseDone(response: _response()));
    await tester.pump();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(SchoolImportParsePage)),
    );
    expect(
      find.widgetWithText(FilledButton, l10n.importAsNewTimetable),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
