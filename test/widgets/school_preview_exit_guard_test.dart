import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/school_import_models.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/widgets/app_modal_sheet.dart';
import 'package:sked/widgets/school_web_import_result_sheet.dart';
import 'package:sked/widgets/sked_date_picker.dart';

import '../support/workspace_harness.dart';

Finder get _preview => find.byType(SchoolWebImportResultSheet);
Finder get _name =>
    find.descendant(of: _preview, matching: find.byType(TextField)).first;

SchoolImportResponse _response() => SchoolImportResponse(
  meta: const SchoolImportMeta(
    sourceUrl: '',
    pageTitle: '',
    parser: '',
    warnings: [],
  ),
  timetable: SchoolImportTimetableDraft(
    name: 'Imported timetable',
    startDate: DateTime(2026, 9, 21),
    totalWeeks: 18,
    periodTimeSet: const ImportedPeriodTimeSetDraft(name: '', periodTimes: []),
    courses: const [
      ImportedCourseDraft(
        name: 'A course to review',
        teacher: '',
        location: '',
        dayOfWeek: 1,
        semesterWeeks: [1, 2],
        periods: [1],
        startMinutes: 480,
        endMinutes: 525,
        credit: 0,
        remarks: '',
        customFields: {},
      ),
    ],
  ),
);

Future<TimetableProvider> _mount(
  WidgetTester tester, {
  required List<SchoolImportApplyRequest?> results,
  Future<void> Function(SchoolImportApplyRequest)? onApply,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(393, 852);
  tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
  tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
  addTearDown(tester.view.reset);
  final provider = await workspaceProvider();
  addTearDown(provider.dispose);
  await tester.pumpWidget(
    WorkspaceHarness(
      provider: provider,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              results.add(
                await showAppModalSheet<SchoolImportApplyRequest>(
                  context: context,
                  workspace: AppMode.student,
                  enableDrag: true,
                  builder: (_) => SchoolWebImportResultSheet(
                    response: _response(),
                    canReplaceCurrent: false,
                    initialPeriodTimeSetId: provider.periodTimeSets.first.id,
                    onApply: onApply,
                  ),
                ),
              );
            },
            child: const Text('Review imported data'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Review imported data'));
  await tester.pumpAndSettle();
  expect(_preview, findsOneWidget);
  return provider;
}

Future<void> _dragDown(WidgetTester tester, {bool settle = true}) async {
  final sheet = find.byType(BottomSheet).last;
  final header = find.descendant(
    of: sheet,
    matching: find.byKey(const ValueKey('app-sheet-header')),
  );
  await tester.fling(header, const Offset(0, 480), 1600);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }
}

void main() {
  testWidgets(
    'preview native close and Back preserve its dirty configuration and child picker',
    (tester) async {
      final results = <SchoolImportApplyRequest?>[];
      final provider = await _mount(tester, results: results);
      final originalTables = provider.timetables
          .map((table) => table.id)
          .toList();
      final state = tester.state(_preview);
      final l = AppLocalizations.of(tester.element(_preview));
      await tester.enterText(_name, 'Reviewed draft name');
      for (final drag in [true, false]) {
        if (drag) {
          await _dragDown(tester);
        } else {
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
        }
        expect(find.text(l.unsavedChangesMessage), findsOneWidget);
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text(l.cancel),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.state(_preview), same(state));
        expect(
          tester.widget<TextField>(_name).controller!.text,
          'Reviewed draft name',
        );
        expect(results, isEmpty);
      }
      final closeParent = tester
          .widget<AppSheetScaffold>(
            find.descendant(
              of: _preview,
              matching: find.byType(AppSheetScaffold),
            ),
          )
          .onClose!;
      final date = find.byKey(const ValueKey('school-import-start-date-tile'));
      await tester.ensureVisible(date);
      await tester.tap(date);
      await tester.pumpAndSettle();
      expect(find.byType(SkedDatePicker), findsOneWidget);
      closeParent();
      await tester.pumpAndSettle();
      expect(find.byType(SkedDatePicker), findsOneWidget);
      expect(results, isEmpty);
      await tester.tap(find.byKey(const ValueKey('sked-date-cancel')));
      await tester.pumpAndSettle();
      expect(tester.state(_preview), same(state));
      expect(
        tester.widget<TextField>(_name).controller!.text,
        'Reviewed draft name',
      );
      closeParent();
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.discardChangesAndExit));
      await tester.pumpAndSettle();
      expect(_preview, findsNothing);
      expect(results, [null]);
      expect(provider.timetables.map((table) => table.id), originalTables);
      expect(find.text('Review imported data').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'preview waits for apply, survives failure and retries the same draft once',
    (tester) async {
      final gate = Completer<void>();
      addTearDown(() {
        if (!gate.isCompleted) gate.complete();
      });
      final results = <SchoolImportApplyRequest?>[];
      final requests = <SchoolImportApplyRequest>[];
      await _mount(
        tester,
        results: results,
        onApply: (request) async {
          requests.add(request);
          if (requests.length == 1) {
            await gate.future;
            throw StateError('Expected import failure');
          }
        },
      );
      final state = tester.state(_preview);
      final l = AppLocalizations.of(tester.element(_preview));
      await tester.enterText(_name, 'Retry reviewed import');
      final submit = find.descendant(
        of: _preview,
        matching: find.widgetWithText(FilledButton, l.importAsNewTimetable),
      );
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      final staleSubmit = tester.widget<FilledButton>(submit).onPressed!;
      await tester.tap(submit);
      await tester.pump();
      staleSubmit();
      await tester.pump();
      await _dragDown(tester, settle: false);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(tester.state(_preview), same(state));
      expect(find.byType(AlertDialog), findsNothing);
      expect(requests, hasLength(1));
      expect(results, isEmpty);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text(l.saveFailedRetry), findsOneWidget);
      expect(
        tester.widget<TextField>(_name).controller!.text,
        'Retry reviewed import',
      );
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(_preview, findsNothing);
      expect(requests, hasLength(2));
      expect(results, hasLength(1));
      expect(results.single!.response.timetable.name, 'Retry reviewed import');
      expect(find.text('Review imported data').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
