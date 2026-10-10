import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/services/export_service.dart';
import 'package:sked/widgets/export_save_flow.dart';

class _ExportService extends ExportService {
  _ExportService(this.results);

  final List<ExportSaveStatus> results;
  final saved = <ExportPayload>[];
  final shared = <ExportPayload>[];
  Completer<ExportSaveResult>? pendingSave;
  Completer<void>? pendingShare;
  Object? shareError;
  int settingsOpened = 0;

  @override
  bool get usesDesktopFileSaveErrors => true;

  @override
  Future<ExportSaveResult> saveFile(ExportPayload payload) async {
    saved.add(payload);
    final pending = pendingSave;
    if (pending != null) return pending.future;
    return ExportSaveResult(status: results.removeAt(0));
  }

  @override
  Future<void> shareFile(ExportPayload payload) async {
    shared.add(payload);
    await pendingShare?.future;
    if (shareError != null) throw shareError!;
  }

  @override
  Future<void> openSettings() async {
    settingsOpened++;
  }
}

class _ExportRun {
  late BuildContext ownerContext;
  late Future<void> completed;

  AppLocalizations get l10n => AppLocalizations.of(ownerContext);
}

const _payload = ExportPayload(
  fileName: 'Captured export.ics',
  content: 'BEGIN:VCALENDAR\nEND:VCALENDAR',
  mimeType: 'text/calendar',
  allowedExtensions: ['ics'],
);

Future<_ExportRun> _startExport(
  WidgetTester tester,
  _ExportService service,
) async {
  final run = _ExportRun();
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => FilledButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  body: Builder(
                    builder: (ownerContext) => FilledButton(
                      onPressed: () {
                        run.ownerContext = ownerContext;
                        run.completed = saveExportWithFeedback(
                          context: ownerContext,
                          service: service,
                          payload: _payload,
                        );
                        // The caller handles platform failures. Tests can still
                        // inspect the original Future without an unhandled error.
                        unawaited(run.completed.catchError((Object _) {}));
                      },
                      child: const Text('Save export'),
                    ),
                  ),
                ),
              ),
            ),
            child: const Text('Open exporter'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open exporter'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Save export'));
  await tester.pumpAndSettle();
  return run;
}

void main() {
  testWidgets(
    'permission retry keeps the export snapshot and respects cancel',
    (tester) async {
      final service = _ExportService([
        ExportSaveStatus.permissionDenied,
        ExportSaveStatus.cancelled,
      ]);
      final run = await _startExport(tester, service);
      expect(
        find.text(run.l10n.fileSaveRestrictedRetryMessage),
        findsOneWidget,
      );
      final retry = tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, run.l10n.retrySave),
          )
          .onPressed!;
      retry();
      retry();
      await tester.pumpAndSettle();
      await run.completed;
      expect(service.saved, [same(_payload), same(_payload)]);
      expect(service.shared, isEmpty);
      expect(find.text(run.l10n.saveCancelled), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final status in [
    ExportSaveStatus.failed,
    ExportSaveStatus.unsupported,
  ]) {
    testWidgets(
      'sharing after $status waits for the captured export to finish',
      (tester) async {
        final service = _ExportService([status])
          ..pendingShare = Completer<void>();
        final run = await _startExport(tester, service);
        final share = tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, run.l10n.switchToShare),
            )
            .onPressed!;
        share();
        share();
        await tester.pumpAndSettle();
        expect(service.shared, [same(_payload)]);
        expect(find.text(run.l10n.exportSwitchedToShare), findsNothing);
        service.pendingShare!.complete();
        await tester.pumpAndSettle();
        await run.completed;
        expect(find.text(run.l10n.exportSwitchedToShare), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('declining the sharing fallback does not start another export', (
    tester,
  ) async {
    final service = _ExportService([ExportSaveStatus.failed]);
    final run = await _startExport(tester, service);
    await tester.tap(find.widgetWithText(TextButton, run.l10n.retryLater));
    await tester.pumpAndSettle();
    await run.completed;
    expect(service.saved, [same(_payload)]);
    expect(service.shared, isEmpty);
    expect(service.settingsOpened, 0);
    expect(find.text(run.l10n.saveFailedRetry), findsOneWidget);
  });

  testWidgets('permanent denial opens settings only after confirmation', (
    tester,
  ) async {
    final service = _ExportService([
      ExportSaveStatus.permissionPermanentlyDenied,
    ]);
    final run = await _startExport(tester, service);
    expect(service.settingsOpened, 0);
    await tester.tap(find.widgetWithText(FilledButton, run.l10n.openSettings));
    await tester.pumpAndSettle();
    await run.completed;
    expect(service.settingsOpened, 1);
    expect(service.saved, [same(_payload)]);
    expect(service.shared, isEmpty);
  });

  for (final pending in [false, true]) {
    testWidgets(
      'retired export owners cannot retry; native save pending=$pending',
      (tester) async {
        final service = _ExportService([ExportSaveStatus.permissionDenied]);
        if (pending) service.pendingSave = Completer<ExportSaveResult>();
        final run = await _startExport(tester, service);
        final retry = pending
            ? null
            : tester
                  .widget<FilledButton>(
                    find.widgetWithText(FilledButton, run.l10n.retrySave),
                  )
                  .onPressed;
        final owner = ModalRoute.of(run.ownerContext)!;
        owner.navigator!.removeRoute(owner);
        await tester.pumpAndSettle();
        service.pendingSave?.complete(
          const ExportSaveResult(status: ExportSaveStatus.permissionDenied),
        );
        retry?.call();
        await tester.pumpAndSettle();
        await run.completed;
        expect(find.byType(AlertDialog), findsNothing);
        expect(service.saved, [same(_payload)]);
        expect(service.shared, isEmpty);
        expect(service.settingsOpened, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('sharing failure never produces successful export feedback', (
    tester,
  ) async {
    final service = _ExportService([ExportSaveStatus.failed])
      ..shareError = StateError('share unavailable');
    final run = await _startExport(tester, service);
    await tester.tap(find.widgetWithText(FilledButton, run.l10n.switchToShare));
    await tester.pumpAndSettle();
    await expectLater(run.completed, throwsStateError);
    expect(find.text(run.l10n.exportSwitchedToShare), findsNothing);
    expect(service.shared, [same(_payload)]);
  });
}
