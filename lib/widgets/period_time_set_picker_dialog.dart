import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/timetable_provider.dart';
import '../screens/period_times_page.dart';
import 'expressive_dialog.dart';

Future<String?> showPeriodTimeSetPickerDialog(
  BuildContext context, {
  required TimetableProvider provider,
  required String selectedPeriodTimeSetId,
}) {
  return showExpressiveDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      var currentSelectedId = selectedPeriodTimeSetId;
      var popped = false;
      var busy = false;

      Future<void> openPeriodTimePage(String periodTimeSetId) async {
        await Navigator.of(dialogContext).push(
          MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider<TimetableProvider>.value(
              value: provider,
              child: PeriodTimesPage(periodTimeSetId: periodTimeSetId),
            ),
          ),
        );
      }

      return StatefulBuilder(
        builder: (dialogContext, refreshDialog) {
          final l10n = AppLocalizations.of(dialogContext);

          Future<void> runBusy(Future<void> Function() action) async {
            if (busy || popped) return;
            refreshDialog(() => busy = true);
            try {
              await action();
            } finally {
              if (dialogContext.mounted) {
                refreshDialog(() => busy = false);
              }
            }
          }

          void popOnce([String? result]) {
            if (popped) return;
            popped = true;
            Navigator.of(dialogContext).pop(result);
          }

          return PopScope(
            canPop: !busy && !popped,
            child: AlertDialog(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.selectPeriodTimeSet),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton.icon(
                      onPressed: (busy || popped)
                          ? null
                          : () => runBusy(() async {
                              final created = await provider.addPeriodTimeSet();
                              if (!dialogContext.mounted || popped) {
                                return;
                              }
                              currentSelectedId = created.id;
                              await openPeriodTimePage(created.id);
                            }),
                      icon: const Icon(Icons.add),
                      label: Text(l10n.newItem),
                    ),
                  ),
                ],
              ),
              content: ExpressiveDialogContent(
                maxWidth: 420,
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: provider.periodTimeSets.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = provider.periodTimeSets[index];
                    final selected = item.id == currentSelectedId;
                    return ExpressiveDialogOption(
                      selected: selected,
                      leading: const Icon(Icons.schedule_outlined),
                      title: Text(item.name),
                      subtitle: Text(
                        l10n.periodTimeSetSummary(
                          item.name,
                          item.periodTimes.length,
                        ),
                      ),
                      trailing: IconButton(
                        tooltip: l10n.editPeriodTimeSet,
                        onPressed: (busy || popped)
                            ? null
                            : () => runBusy(() async {
                                await openPeriodTimePage(item.id);
                                final stillExists =
                                    provider.periodTimeSetForId(item.id) !=
                                    null;
                                if (!stillExists &&
                                    currentSelectedId == item.id) {
                                  currentSelectedId =
                                      provider.activePeriodTimeSetOrNull?.id ??
                                      '';
                                }
                              }),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      onTap: () => popOnce(item.id),
                      enabled: !(busy || popped),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: (busy || popped) ? null : () => popOnce(),
                  child: Text(l10n.cancel),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
