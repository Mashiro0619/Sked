import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/school_import_models.dart';
import 'package:sked/services/school_import_api.dart';
import 'package:sked/widgets/school_import_stream_dialog.dart';

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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
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

    expect(find.byType(AlertDialog), findsOneWidget);
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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
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
}
