import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/screens/school_import_result_editor_page.dart';
import 'package:sked/screens/school_html_import_page.dart';
import 'package:sked/widgets/school_import_summary_preview.dart';

import '../support/workspace_harness.dart';

String _draft(String name) => const JsonEncoder.withIndent('  ').convert({
  'name': name,
  'startDate': '2026-09-07',
  'totalWeeks': 16,
  'periodTimeSet': {
    'name': 'Periods',
    'periodTimes': [
      {'index': 1, 'startMinutes': 480, 'endMinutes': 525},
    ],
  },
  'courses': [
    {
      'name': 'Test course',
      'dayOfWeek': 1,
      'semesterWeeks': [1, 2],
      'periods': [1],
      'startMinutes': 480,
      'endMinutes': 525,
    },
  ],
  'unknownField': {'preserve': true},
});

void main() {
  testWidgets(
    'configured import source keeps its draft and counts the keyboard inset once',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetViewInsets);
      final p = await workspaceProvider();
      await p.updateCustomSchoolImportBaseUrl('https://example.invalid/v1');
      await p.updateCustomSchoolImportApiKey('memory-fixture');
      await p.updateCustomSchoolImportModel('fixture-model');
      await tester.pumpWidget(
        WorkspaceHarness(
          provider: p,
          home: const SchoolHtmlImportPage(initialContent: 'Original source'),
        ),
      );
      await tester.pumpAndSettle();
      final input = find.byType(TextField).first;
      await tester.enterText(input, 'Retained source');
      tester.view.viewInsets = const FakeViewPadding(bottom: 160);
      await tester.pumpAndSettle();
      expect(tester.getSize(input).height, greaterThan(300));
      expect(
        tester.widget<TextField>(input).controller!.text,
        'Retained source',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      p.dispose();
    },
  );

  testWidgets(
    'JSON preview and exact source survive reflow and confirm together',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final p = await workspaceProvider();
      SchoolImportResultEditorOutcome? result;
      await tester.pumpWidget(
        WorkspaceHarness(
          provider: p,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await Navigator.of(context)
                      .push<SchoolImportResultEditorOutcome>(
                        MaterialPageRoute(
                          builder: (_) => SchoolImportResultEditorPage(
                            initialText: _draft('Initial'),
                          ),
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
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(
        tester.element(find.byType(SchoolImportResultEditorPage)),
      );
      final field = find.byType(TextField);
      final originalElement = tester.element(field);
      expect(find.byType(SchoolImportSummaryPreview), findsOneWidget);
      expect(find.text('Test course'), findsOneWidget);
      final raw = '  ${_draft('Changed title')}\n';
      await tester.enterText(field, raw);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      expect(find.text('Changed title'), findsOneWidget);
      tester.view.physicalSize = const Size(360, 800);
      await tester.pumpAndSettle();
      expect(tester.element(field), same(originalElement));
      expect(find.byType(SchoolImportSummaryPreview), findsNothing);
      expect(tester.widget<TextField>(field).controller!.text, raw);
      await tester.tap(find.byTooltip(l.confirm));
      await tester.pumpAndSettle();
      expect(result!.rawText, raw);
      expect(result!.timetable.name, 'Changed title');
      expect(result!.rawText, contains('unknownField'));
      await tester.pumpWidget(const SizedBox.shrink());
      p.dispose();
    },
  );

  testWidgets(
    'invalid JSON stays editable and Back protects the unsaved correction',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final p = await workspaceProvider();
      await tester.pumpWidget(
        WorkspaceHarness(
          provider: p,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => SchoolImportResultEditorPage(
                      initialText: _draft('Initial'),
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(
        tester.element(find.byType(SchoolImportResultEditorPage)),
      );
      await tester.enterText(find.byType(TextField), '{invalid draft');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      expect(find.byType(SchoolImportSummaryPreview), findsNothing);
      expect(find.text(l.noImportableTimetables), findsOneWidget);
      await tester.tap(find.byTooltip(l.confirm));
      await tester.pumpAndSettle();
      expect(find.text(l.importFailedCheckContent), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text(l.unsavedChangesMessage), findsOneWidget);
      await tester.tap(find.text(l.cancel));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '{invalid draft',
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.discardChangesAndExit));
      await tester.pumpAndSettle();
      expect(find.byType(SchoolImportResultEditorPage), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      p.dispose();
    },
  );
}
