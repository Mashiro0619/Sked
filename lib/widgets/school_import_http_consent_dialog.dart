import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../services/school_import_http_consent.dart';
import 'expressive_dialog.dart';

Future<bool> confirmSchoolImportHttpEndpoint({
  required BuildContext context,
  required String baseUrl,
  required SchoolImportHttpConsentStore consentStore,
}) async {
  if (!consentStore.requiresConfirmation(baseUrl)) {
    return true;
  }

  final endpoint = consentStore.displayEndpoint(baseUrl);
  final confirmed = await showExpressiveDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      final l10n = AppLocalizations.of(dialogContext);
      var popped = false;
      void close(bool value) {
        if (popped) return;
        popped = true;
        Navigator.of(dialogContext).pop(value);
      }

      return PopScope(
        canPop: false,
        child: AlertDialog(
          icon: Icon(
            Icons.warning_amber_rounded,
            color: Theme.of(dialogContext).colorScheme.error,
          ),
          title: Text(l10n.schoolImportHttpConfirmationTitle),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.schoolImportHttpConfirmationMessage),
                const SizedBox(height: 12),
                Text(
                  l10n.schoolImportParserBaseUrl,
                  style: Theme.of(dialogContext).textTheme.labelMedium,
                ),
                const SizedBox(height: 4),
                SelectableText(endpoint),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => close(false), child: Text(l10n.cancel)),
            FilledButton(
              onPressed: () => close(true),
              child: Text(l10n.confirm),
            ),
          ],
        ),
      );
    },
  );
  if (confirmed != true) {
    return false;
  }
  consentStore.approve(baseUrl);
  return true;
}
