import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/school_import_models.dart';
import 'package:sked/screens/school_import_parse_page.dart';
import 'package:sked/services/school_import_api.dart';

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
    expect(find.text(l10n.schoolImportParsePageComplete), findsOneWidget);
    expect(find.text('Parsed timetable'), findsOneWidget);
    expect(find.textContaining('late mutation'), findsNothing);
    expect(find.text(l10n.schoolImportParsePageRawContent), findsOneWidget);
    expect(find.text('unknownField'), findsNothing);
    expect(
      find.widgetWithText(FilledButton, l10n.schoolImportParsePageContinue),
      findsOneWidget,
    );

    final rawHeader = find.text(l10n.schoolImportParsePageRawContent);
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(rawHeader);
    await tester.pumpAndSettle();
    expect(find.textContaining('unknownField'), findsOneWidget);
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
      final preview = tester.widget<SelectableText>(
        find.byType(SelectableText),
      );
      expect(preview.data!.length, lessThanOrEqualTo(4096));

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pump();
      expect(canceled, isTrue);
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
}
