import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/school_import_models.dart';
import 'package:sked/services/school_import_api.dart';
import 'package:sked/screens/school_import_parse_page.dart';
import 'package:sked/screens/school_import_result_editor_page.dart';
import 'package:sked/widgets/school_import_stream_dialog.dart';

const _validEditableJson = '''{
  "name": "Sample",
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
  ]
}''';

SchoolImportResponse _buildResponse() {
  return SchoolImportResponse(
    meta: const SchoolImportMeta(
      sourceUrl: '',
      pageTitle: '',
      parser: 'test',
      warnings: [],
    ),
    timetable: SchoolImportTimetableDraft(
      name: 'Sample',
      startDate: DateTime(2026, 5, 25),
      totalWeeks: 18,
      periodTimeSet: const ImportedPeriodTimeSetDraft(
        name: '',
        periodTimes: [],
      ),
      courses: const [],
    ),
  );
}

void main() {
  testWidgets('stream dialog lays out on narrow screens', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = StreamController<SchoolImportStreamEvent>();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                unawaited(
                  showDialog<SchoolImportResponse>(
                    context: context,
                    builder: (_) =>
                        SchoolImportStreamDialog(stream: controller.stream),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pump();
    controller.add(
      const ParseDelta(
        '{"timetable":{"name":"Sample","courses":[]},'
        '"meta":{"parser":"test","warnings":[]}}',
      ),
    );
    await tester.pump();

    expect(find.byType(SchoolImportParsePage), findsOneWidget);
    expect(tester.takeException(), isNull);

    unawaited(controller.close());
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('done confirm cannot pop the parent route on rapid tap', (
    tester,
  ) async {
    final controller = StreamController<SchoolImportStreamEvent>();
    final response = _buildResponse();
    final results = <SchoolImportResponse?>[];

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                unawaited(
                  showDialog<SchoolImportResponse>(
                    context: context,
                    builder: (_) =>
                        SchoolImportStreamDialog(stream: controller.stream),
                  ).then(results.add),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    controller.add(ParseDone(response: response));
    await tester.pump();

    final confirmButton = find.byType(FilledButton);
    expect(confirmButton, findsOneWidget);
    expect(tester.widget<FilledButton>(confirmButton).onPressed, isNotNull);

    await tester.tap(confirmButton);
    await tester.tap(confirmButton, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(results, [same(response)]);
    expect(find.text('Open'), findsOneWidget);

    unawaited(controller.close());
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'stream preview is bounded while full-screen edit keeps content',
    (tester) async {
      final controller = StreamController<SchoolImportStreamEvent>();
      final fullContent = 'BEGIN-${'x' * 10000}-TAIL';
      final results = <SchoolImportResponse?>[];

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () {
                  unawaited(
                    showDialog<SchoolImportResponse>(
                      context: context,
                      builder: (_) =>
                          SchoolImportStreamDialog(stream: controller.stream),
                    ).then(results.add),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump();
      for (final chunk in [
        fullContent.substring(0, 3500),
        fullContent.substring(3500, 7000),
        fullContent.substring(7000),
      ]) {
        controller.add(ParseDelta(chunk));
        await tester.pump();
        final currentPreview = tester.widget<SelectableText>(
          find.byType(SelectableText),
        );
        expect(
          currentPreview.data!.length,
          lessThanOrEqualTo(SchoolImportStreamDialog.maxPreviewCodeUnits),
        );
      }

      final preview = tester.widget<SelectableText>(
        find.byType(SelectableText),
      );
      expect(preview.data, endsWith('-TAIL'));
      expect(preview.data, isNot(contains('BEGIN-')));

      controller.add(ParseDone(response: _buildResponse()));
      await tester.pump();
      await tester.tap(find.byType(OutlinedButton));
      await tester.pump();

      expect(find.byType(SchoolImportResultEditorPage), findsOneWidget);
      final editor = tester.widget<TextField>(find.byType(TextField));
      expect(editor.controller!.text, fullContent);

      await tester.enterText(
        find.byType(TextField),
        '\u{1f600}' * (SchoolImportStreamDialog.maxEditableCodeUnits ~/ 2 + 1),
      );
      expect(
        editor.controller!.text.length,
        SchoolImportStreamDialog.maxEditableCodeUnits,
      );
      expect(
        editor.controller!.text.runes.length,
        SchoolImportStreamDialog.maxEditableCodeUnits ~/ 2,
      );

      await tester.enterText(find.byType(TextField), _validEditableJson);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.check));
      await tester.pumpAndSettle();

      expect(results, hasLength(1));
      expect(results.single?.timetable.name, 'Sample');

      unawaited(controller.close());
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('full-screen result editor keeps draft when validation fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SchoolImportResultEditorPage(initialText: '{'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.check));
    await tester.pump();
    expect(
      find.text('Import failed. Please check the file content.'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField), '{}');
    await tester.tap(find.byIcon(Icons.check));
    await tester.pump();
    expect(
      find.text('No usable timetables were found in the imported file.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byType(TextField),
      '{"name":"Sample","courses":[]}',
    );
    await tester.tap(find.byIcon(Icons.check));
    await tester.pump();
    expect(
      find.textContaining('Import failed. Please check the file content.'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.byIcon(Icons.check));
    await tester.pump();
    expect(find.text('Paste JSON content first.'), findsOneWidget);
  });

  testWidgets(
    'oversized raw content disables editing but keeps validated confirmation',
    (tester) async {
      final controller = StreamController<SchoolImportStreamEvent>();
      final response = _buildResponse();
      final results = <SchoolImportResponse?>[];

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () {
                  unawaited(
                    showDialog<SchoolImportResponse>(
                      context: context,
                      builder: (_) =>
                          SchoolImportStreamDialog(stream: controller.stream),
                    ).then(results.add),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump();
      controller.add(
        ParseDelta('x' * (SchoolImportStreamDialog.maxEditableCodeUnits + 1)),
      );
      controller.add(ParseDone(response: response));
      await tester.pump();

      final editButton = find.byType(OutlinedButton);
      expect(tester.widget<OutlinedButton>(editButton).onPressed, isNull);
      final confirmButton = find.byType(FilledButton);
      expect(tester.widget<FilledButton>(confirmButton).onPressed, isNotNull);

      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      expect(results, [same(response)]);
      expect(find.text('Open'), findsOneWidget);

      unawaited(controller.close());
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
