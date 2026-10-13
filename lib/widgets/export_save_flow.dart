import 'sked_confirmation_dialog.dart';

import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../services/export_service.dart';
import 'expressive_dialog.dart';
import 'sked_task_route.dart';
import 'sked_task_session.dart';

/// Saves one captured export. Retries and sharing keep that exact payload,
/// while the calling page retains its own busy and exit policy.
Future<void> saveExportWithFeedback({
  required BuildContext context,
  required ExportService service,
  required ExportPayload payload,
  Future<void> Function(ExportPayload)? shareFile,
  bool Function()? isCurrent,
}) async {
  if (!context.mounted) return;
  final session = SkedTaskSession(
    parent: SkedTaskSessionScope.maybeOf(context)?.session,
    ownerRoute: ModalRoute.of(context),
    isOwnerActive: () => context.mounted,
    isTargetCurrent: isCurrent,
  );
  bool available() => context.mounted && session.isCurrent;
  void message(String value) {
    if (available()) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(value)));
    }
  }

  try {
    while (available()) {
      final result = await service.saveFile(payload);
      if (!context.mounted || !session.isCurrent) return;
      final l10n = AppLocalizations.of(context);
      switch (result.status) {
        case ExportSaveStatus.saved:
          message(l10n.savedToPath(result.path ?? payload.fileName));
          return;
        case ExportSaveStatus.cancelled:
          message(l10n.saveCancelled);
          return;
        case ExportSaveStatus.permissionDenied:
          final retry = await _confirmExportAction(
            context: context,
            session: session,
            title: l10n.fileSaveRestrictedTitle,
            message: l10n.fileSaveRestrictedRetryMessage,
            cancelLabel: l10n.cancel,
            confirmLabel: l10n.retrySave,
          );
          if (retry == true && available()) continue;
          return;
        case ExportSaveStatus.permissionPermanentlyDenied:
          final openSettings = await _confirmExportAction(
            context: context,
            session: session,
            title: l10n.fileSaveRestrictedTitle,
            message: l10n.fileSaveRestrictedSettingsMessage,
            cancelLabel: l10n.cancel,
            confirmLabel: l10n.openSettings,
          );
          if (openSettings == true && available()) {
            await service.openSettings();
          }
          return;
        case ExportSaveStatus.unsupported:
        case ExportSaveStatus.failed:
          final unsupported = result.status == ExportSaveStatus.unsupported;
          final shouldShare = await _confirmExportAction(
            context: context,
            session: session,
            title: unsupported
                ? l10n.browserDownloadRestrictedTitle
                : service.usesDesktopFileSaveErrors
                ? l10n.fileSaveFailedTitle
                : l10n.fileSaveRestrictedTitle,
            message: unsupported
                ? l10n.browserDownloadRestrictedMessage
                : service.usesDesktopFileSaveErrors
                ? l10n.fileSaveFailedWindowsMessage
                : l10n.fileSaveFailedGenericMessage,
            cancelLabel: l10n.retryLater,
            confirmLabel: l10n.switchToShare,
          );
          if (!available()) return;
          if (shouldShare == true) {
            await (shareFile ?? service.shareFile)(payload);
            message(l10n.exportSwitchedToShare);
          } else if (!unsupported) {
            message(l10n.saveFailedRetry);
          }
          return;
      }
    }
  } finally {
    session.dispose();
  }
}

Future<bool?> _confirmExportAction({
  required BuildContext context,
  required SkedTaskSession session,
  required String title,
  required String message,
  required String cancelLabel,
  required String confirmLabel,
}) {
  var completed = false;
  return showExpressiveDialog<bool>(
    context: context,
    session: session,
    waitForTransitionComplete: true,
    builder: (dialogContext) {
      void finish(bool result) {
        if (completed || !session.isCurrent) return;
        completed = true;
        completeSkedTaskRoute(dialogContext, result);
      }

      return SkedConfirmationDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => finish(false), child: Text(cancelLabel)),
          FilledButton(
            onPressed: () => finish(true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
}
