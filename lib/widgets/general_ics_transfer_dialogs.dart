import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import 'expressive_dialog.dart';
import 'sked_confirmation_dialog.dart';
import 'sked_task_session.dart';

enum GeneralIcsExportFormat { ics, json }

/// Every skipped or changed event is reviewed before an append or replacement.
Future<bool> confirmGeneralIcsImportReview(
  BuildContext context, {
  required SkedTaskSession session,
  required int eventCount,
  required List<String> details,
}) async {
  var popped = false;
  final confirmed = await showExpressiveDialog<bool>(
    context: context,
    session: session,
    waitForTransitionComplete: true,
    builder: (dialogContext) {
      final l10n = AppLocalizations.of(dialogContext);
      bool canAct() =>
          !popped &&
          dialogContext.mounted &&
          session.isCurrent &&
          ModalRoute.of(dialogContext)?.isCurrent == true;
      void finish(bool value) {
        if (!canAct()) return;
        popped = true;
        Navigator.of(dialogContext).pop(value);
      }

      final report = [
        l10n.icsImportReviewNotice(eventCount, details.length),
        ...details,
      ].join('\n\n');
      return SkedConfirmationDialog(
        key: const ValueKey('general-ics-import-review'),
        scrollable: true,
        title: Text(l10n.icsImportReportTitle),
        content: SelectableText(report),
        actions: [
          TextButton(
            key: const ValueKey('general-ics-import-review-cancel'),
            onPressed: () => finish(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            key: const ValueKey('general-ics-import-review-copy'),
            onPressed: () async {
              if (!canAct()) return;
              await Clipboard.setData(ClipboardData(text: report));
              if (!dialogContext.mounted || !canAct()) return;
              ScaffoldMessenger.maybeOf(
                dialogContext,
              )?.showSnackBar(SnackBar(content: Text(l10n.copiedToClipboard)));
            },
            child: Text(l10n.copyText),
          ),
          FilledButton(
            key: const ValueKey('general-ics-import-review-continue'),
            onPressed: () => finish(true),
            child: Text(l10n.icsImportContinueAction),
          ),
        ],
      );
    },
  );
  return confirmed == true && session.isCurrent;
}

/// The complete report stays available until the user closes or copies it.
Future<void> showGeneralIcsImportReport(
  BuildContext context, {
  required SkedTaskSession session,
  required String summary,
  required List<String> details,
}) async {
  var popped = false;
  await showExpressiveDialog<void>(
    context: context,
    session: session,
    waitForTransitionComplete: true,
    builder: (dialogContext) {
      final l10n = AppLocalizations.of(dialogContext);
      bool canAct() =>
          !popped &&
          dialogContext.mounted &&
          session.isCurrent &&
          ModalRoute.of(dialogContext)?.isCurrent == true;
      return SkedConfirmationDialog(
        key: const ValueKey('general-ics-import-report'),
        scrollable: true,
        title: Text(l10n.icsImportReportTitle),
        content: SelectableText(
          [
            summary,
            ...details.indexed.map((entry) => '${entry.$1 + 1}. ${entry.$2}'),
          ].join('\n\n'),
        ),
        actions: [
          TextButton(
            key: const ValueKey('general-ics-report-close'),
            onPressed: () {
              if (!canAct()) return;
              popped = true;
              Navigator.of(dialogContext).pop();
            },
            child: Text(
              MaterialLocalizations.of(dialogContext).closeButtonLabel,
            ),
          ),
          FilledButton(
            key: const ValueKey('general-ics-report-copy'),
            onPressed: () async {
              if (!canAct()) return;
              await Clipboard.setData(
                ClipboardData(text: [summary, ...details].join('\n\n')),
              );
              if (!dialogContext.mounted || !canAct()) return;
              ScaffoldMessenger.maybeOf(
                dialogContext,
              )?.showSnackBar(SnackBar(content: Text(l10n.copiedToClipboard)));
            },
            child: Text(l10n.copyText),
          ),
        ],
      );
    },
  );
}

/// A rejected ICS export can still produce a complete JSON payload.
Future<bool> showGeneralIcsExportFailure(
  BuildContext context, {
  required SkedTaskSession session,
  required String message,
  required String diagnostics,
}) async {
  var popped = false;
  final useJson = await showExpressiveDialog<bool>(
    context: context,
    session: session,
    waitForTransitionComplete: true,
    builder: (dialogContext) {
      final l10n = AppLocalizations.of(dialogContext);
      bool canAct() =>
          !popped &&
          dialogContext.mounted &&
          session.isCurrent &&
          ModalRoute.of(dialogContext)?.isCurrent == true;
      void finish(bool value) {
        if (!canAct()) return;
        popped = true;
        Navigator.of(dialogContext).pop(value);
      }

      return SkedConfirmationDialog(
        key: const ValueKey('general-ics-export-failure'),
        scrollable: true,
        title: Text(l10n.icsExportFailureTitle),
        content: Text(message),
        actions: [
          TextButton(
            key: const ValueKey('general-ics-failure-cancel'),
            onPressed: () => finish(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            key: const ValueKey('general-ics-failure-copy'),
            onPressed: () async {
              if (!canAct()) return;
              await Clipboard.setData(
                ClipboardData(text: '$message\n$diagnostics'),
              );
              if (!dialogContext.mounted || !canAct()) return;
              ScaffoldMessenger.maybeOf(
                dialogContext,
              )?.showSnackBar(SnackBar(content: Text(l10n.copiedToClipboard)));
            },
            child: Text(l10n.icsCopyDiagnosticsAction),
          ),
          FilledButton(
            key: const ValueKey('general-ics-failure-json'),
            onPressed: () => finish(true),
            child: Text(l10n.icsReminderExportJsonAction),
          ),
        ],
      );
    },
  );
  return useJson == true && session.isCurrent;
}

/// Keeps the current format limitation visible before any payload is created.
Future<GeneralIcsExportFormat?> showGeneralIcsExportFormat(
  BuildContext context, {
  required SkedTaskSession session,
}) {
  var popped = false;
  return showExpressiveDialog<GeneralIcsExportFormat>(
    context: context,
    session: session,
    waitForTransitionComplete: true,
    builder: (dialogContext) {
      final l10n = AppLocalizations.of(dialogContext);
      void finish(GeneralIcsExportFormat? format) {
        if (popped ||
            !dialogContext.mounted ||
            !session.isCurrent ||
            ModalRoute.of(dialogContext)?.isCurrent != true) {
          return;
        }
        popped = true;
        Navigator.of(dialogContext).pop(format);
      }

      return SkedConfirmationDialog(
        key: const ValueKey('general-ics-export-warning'),
        scrollable: true,
        title: Text(l10n.icsReminderExportTitle),
        content: Text(l10n.icsReminderExportMessage),
        actions: [
          TextButton(
            key: const ValueKey('general-ics-export-cancel'),
            onPressed: () => finish(null),
            child: Text(l10n.cancel),
          ),
          TextButton(
            key: const ValueKey('general-ics-export-continue'),
            onPressed: () => finish(GeneralIcsExportFormat.ics),
            child: Text(l10n.icsReminderExportContinueAction),
          ),
          FilledButton(
            key: const ValueKey('general-ics-export-json'),
            onPressed: () => finish(GeneralIcsExportFormat.json),
            child: Text(l10n.icsReminderExportJsonAction),
          ),
        ],
      );
    },
  );
}

/// Import replacement remains explicit after the target category is selected.
Future<bool> confirmGeneralIcsScheduleReplacement(
  BuildContext context, {
  required String scheduleName,
  required SkedTaskSession session,
}) async {
  var popped = false;
  final confirmed = await showExpressiveDialog<bool>(
    context: context,
    session: session,
    barrierDismissible: false,
    waitForTransitionComplete: true,
    builder: (dialogContext) {
      final l10n = AppLocalizations.of(dialogContext);
      void finish(bool value) {
        if (popped ||
            !dialogContext.mounted ||
            !session.isCurrent ||
            ModalRoute.of(dialogContext)?.isCurrent != true) {
          return;
        }
        popped = true;
        Navigator.of(dialogContext).pop(value);
      }

      return SkedConfirmationDialog(
        key: const ValueKey('general-ics-replacement-warning'),
        scrollable: true,
        title: Text(l10n.icsReminderReplaceTitle),
        content: Text(l10n.icsReminderReplaceMessage(scheduleName)),
        actions: [
          TextButton(
            key: const ValueKey('general-ics-replacement-cancel'),
            onPressed: () => finish(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const ValueKey('general-ics-replacement-confirm'),
            onPressed: () => finish(true),
            child: Text(l10n.replaceCategory),
          ),
        ],
      );
    },
  );
  return confirmed == true && session.isCurrent;
}
