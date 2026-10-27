import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/widgets/general_ics_transfer_dialogs.dart';
import 'package:sked/widgets/sked_task_session.dart';

void main() {
  for (final scenario in [
    (locale: 'en', size: const Size(1000, 760), scale: 1.0),
    (locale: 'zh', size: const Size(320, 568), scale: 2.0),
    (locale: 'de', size: const Size(320, 568), scale: 2.0),
  ]) {
    Future<BuildContext> pumpPage(WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = scenario.size;
      addTearDown(tester.view.reset);
      late BuildContext pageContext;
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(scenario.locale),
          theme: ThemeData(
            platform: scenario.locale == 'en'
                ? TargetPlatform.windows
                : TargetPlatform.android,
          ),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scenario.scale)),
            child: child!,
          ),
          home: Builder(
            builder: (context) {
              pageContext = context;
              return const Scaffold(body: SizedBox.shrink());
            },
          ),
        ),
      );
      return pageContext;
    }

    void expectActionsVisible(WidgetTester tester, List<String> keys) {
      for (final key in keys) {
        final action = find.byKey(ValueKey(key));
        expect(action.hitTestable(), findsOneWidget, reason: key);
        final bounds = tester.getRect(action);
        expect(bounds.left, greaterThanOrEqualTo(0), reason: key);
        expect(
          bounds.right,
          lessThanOrEqualTo(scenario.size.width),
          reason: key,
        );
        expect(bounds.top, greaterThanOrEqualTo(0), reason: key);
        expect(
          bounds.bottom,
          lessThanOrEqualTo(scenario.size.height),
          reason: key,
        );
      }
      expect(tester.takeException(), isNull);
    }

    testWidgets(
      'ICS format choices remain reachable ${scenario.locale} ${scenario.scale}',
      (tester) async {
        final context = await pumpPage(tester);
        final session = SkedTaskSession(ownerRoute: ModalRoute.of(context));
        addTearDown(session.dispose);
        final choice = showGeneralIcsExportFormat(context, session: session);
        await tester.pumpAndSettle();
        expectActionsVisible(tester, [
          'general-ics-export-cancel',
          'general-ics-export-continue',
          'general-ics-export-json',
        ]);
        await tester.tap(find.byKey(const ValueKey('general-ics-export-json')));
        await tester.pumpAndSettle();
        expect(await choice, GeneralIcsExportFormat.json);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'ICS full report remains readable and closable ${scenario.locale} ${scenario.scale}',
      (tester) async {
        final context = await pumpPage(tester);
        final session = SkedTaskSession(ownerRoute: ModalRoute.of(context));
        addTearDown(session.dispose);
        final report = showGeneralIcsImportReport(
          context,
          session: session,
          summary: 'Imported 1 category with 12 warnings',
          details: List.generate(
            12,
            (i) =>
                'Event $i: A complete diagnostic message with its identifier.',
          ),
        );
        await tester.pumpAndSettle();
        expectActionsVisible(tester, [
          'general-ics-report-close',
          'general-ics-report-copy',
        ]);
        expect(
          tester.widget<SelectableText>(find.byType(SelectableText)).data,
          contains('Event 11'),
        );
        await tester.tap(
          find.byKey(const ValueKey('general-ics-report-close')),
        );
        await tester.pumpAndSettle();
        await report;
        expect(
          find.byKey(const ValueKey('general-ics-import-report')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'ICS full review remains cancellable ${scenario.locale} ${scenario.scale}',
      (tester) async {
        final context = await pumpPage(tester);
        final session = SkedTaskSession(ownerRoute: ModalRoute.of(context));
        addTearDown(session.dispose);
        final confirmation = confirmGeneralIcsImportReview(
          context,
          session: session,
          eventCount: 1,
          details: [
            'A skipped event\nUID: unsupported\nDTSTART;TZID=Europe/London',
            'A repeat rule will be imported as a single event.',
          ],
        );
        await tester.pumpAndSettle();
        expectActionsVisible(tester, [
          'general-ics-import-review-cancel',
          'general-ics-import-review-copy',
          'general-ics-import-review-continue',
        ]);
        expect(
          tester.widget<SelectableText>(find.byType(SelectableText)).data,
          contains(AppLocalizations.of(context).icsImportReviewNotice(1, 2)),
        );
        await tester.tap(
          find.byKey(const ValueKey('general-ics-import-review-cancel')),
        );
        await tester.pumpAndSettle();
        expect(await confirmation, isFalse);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'ICS export failure choices remain reachable ${scenario.locale} ${scenario.scale}',
      (tester) async {
        final context = await pumpPage(tester);
        final session = SkedTaskSession(ownerRoute: ModalRoute.of(context));
        addTearDown(session.dispose);
        final choice = showGeneralIcsExportFailure(
          context,
          session: session,
          message: 'A recurring event cannot be represented accurately. Use JSON to retain the complete record.',
          diagnostics: 'monthlyAnchorMismatch\nUID: example',
        );
        await tester.pumpAndSettle();
        expectActionsVisible(tester, [
          'general-ics-failure-cancel',
          'general-ics-failure-copy',
          'general-ics-failure-json',
        ]);
        await tester.tap(
          find.byKey(const ValueKey('general-ics-failure-json')),
        );
        await tester.pumpAndSettle();
        expect(await choice, isTrue);
      },
    );

    testWidgets(
      'ICS replacement choices remain reachable ${scenario.locale} ${scenario.scale}',
      (tester) async {
        final context = await pumpPage(tester);
        final session = SkedTaskSession(ownerRoute: ModalRoute.of(context));
        addTearDown(session.dispose);
        final confirmation = confirmGeneralIcsScheduleReplacement(
          context,
          scheduleName: 'My important calendar',
          session: session,
        );
        await tester.pumpAndSettle();
        expectActionsVisible(tester, [
          'general-ics-replacement-cancel',
          'general-ics-replacement-confirm',
        ]);
        await tester.tap(
          find.byKey(const ValueKey('general-ics-replacement-cancel')),
        );
        await tester.pumpAndSettle();
        expect(await confirmation, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
