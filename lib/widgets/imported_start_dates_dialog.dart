import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../models/timetable_models.dart';
import 'expressive_dialog.dart';
import 'sked_confirmation_dialog.dart';
import 'sked_date_picker.dart';

Future<Map<String, DateTime>?> showImportedStartDatesConfirmation({
  required BuildContext context,
  required List<TimetableData> timetables,
  required bool Function() isCurrent,
}) {
  final dates = {
    for (final timetable in timetables)
      timetable.id: normalizeDateOnly(timetable.config.startDate),
  };
  var pickerOpen = false;
  var popped = false;
  return showExpressiveDialog<Map<String, DateTime>>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (dialogContext, setState) {
        final l10n = AppLocalizations.of(dialogContext);
        void finish(Map<String, DateTime>? result) {
          if (popped || pickerOpen) return;
          popped = true;
          Navigator.of(dialogContext).pop(result);
        }

        return SkedConfirmationDialog(
          key: const ValueKey('import-start-dates-confirmation'),
          title: Text(l10n.confirmImportedStartDatesTitle),
          content: ExpressiveDialogContent(
            maxWidth: 420,
            child: ListView.separated(
              key: const ValueKey('import-start-dates-list'),
              shrinkWrap: true,
              itemCount: timetables.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (rowContext, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(l10n.confirmImportedStartDatesMessage),
                  );
                }
                final timetable = timetables[index - 1];
                return ExpressiveDialogOption(
                  key: ValueKey('import-start-date-${timetable.id}'),
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: Text(timetable.config.name),
                  subtitle: Text(
                    MaterialLocalizations.of(rowContext)
                        .formatFullDate(dates[timetable.id]!),
                  ),
                  onTap: pickerOpen
                      ? null
                      : () async {
                          if (popped || !isCurrent()) return;
                          setState(() => pickerOpen = true);
                          try {
                            final date = await showSkedDatePicker(
                              context: dialogContext,
                              initialDate: dates[timetable.id]!,
                              firstDate: DateTime(1),
                              lastDate: DateTime(9999, 12, 31),
                              workspace: AppMode.student,
                            );
                            if (dialogContext.mounted &&
                                isCurrent() &&
                                date != null) {
                              setState(() => dates[timetable.id] = date);
                            }
                          } finally {
                            if (dialogContext.mounted) {
                              setState(() => pickerOpen = false);
                            }
                          }
                        },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: pickerOpen ? null : () => finish(null),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              key: const ValueKey('confirm-import-start-dates'),
              onPressed: pickerOpen
                  ? null
                  : () => finish(isCurrent() ? Map.of(dates) : null),
              child: Text(l10n.confirm),
            ),
          ],
        );
      },
    ),
  );
}
