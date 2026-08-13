import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/timetable_provider.dart';
import '../screens/period_times_page.dart';
import 'expressive_dialog.dart';
import 'ui_command.dart';

Future<String?> showPeriodTimeSetPickerDialog(
  BuildContext context, {
  required TimetableProvider provider,
  required String selectedPeriodTimeSetId,
}) {
  return showExpressiveDialog<String>(
    context: context,
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
          final mediaQuery = MediaQuery.of(dialogContext);
          final useCompactSpacing =
              mediaQuery.size.width < 360 ||
              mediaQuery.textScaler.scale(1) > 1.3;
          final horizontalInset = useCompactSpacing ? 16.0 : 24.0;
          final horizontalContentPadding = useCompactSpacing ? 12.0 : 20.0;

          Future<void> runBusy({
            required String debugLabel,
            required Future<void> Function() action,
          }) async {
            if (busy || popped) return;
            refreshDialog(() => busy = true);
            try {
              await runUiCommandWithFeedback(
                context: dialogContext,
                debugLabel: debugLabel,
                command: action,
              );
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

          final createButton = IconButton(
            tooltip: l10n.newItem,
            onPressed: (busy || popped)
                ? null
                : () {
                    unawaited(
                      runBusy(
                        debugLabel: 'Create period time set',
                        action: () async {
                          final created = await provider.addPeriodTimeSet();
                          if (!dialogContext.mounted || popped) {
                            return;
                          }
                          currentSelectedId = created.id;
                          await openPeriodTimePage(created.id);
                        },
                      ),
                    );
                  },
            icon: const Icon(Icons.add),
          );

          return PopScope(
            canPop: !busy && !popped,
            child: AlertDialog(
              constraints: const BoxConstraints(maxWidth: 400),
              insetPadding: EdgeInsets.symmetric(
                horizontal: horizontalInset,
                vertical: 24,
              ),
              titlePadding: EdgeInsetsDirectional.fromSTEB(
                horizontalContentPadding,
                20,
                horizontalContentPadding,
                12,
              ),
              contentPadding: EdgeInsetsDirectional.fromSTEB(
                horizontalContentPadding,
                0,
                horizontalContentPadding,
                0,
              ),
              actionsPadding: EdgeInsetsDirectional.fromSTEB(
                horizontalContentPadding,
                8,
                horizontalContentPadding,
                16,
              ),
              titleTextStyle: Theme.of(
                dialogContext,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  UiCommandBusyIndicator(busy: busy),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: Text(l10n.selectPeriodTimeSet)),
                      createButton,
                    ],
                  ),
                ],
              ),
              content: Align(
                alignment: Alignment.center,
                child: ExpressiveDialogContent(
                  maxWidth: 352,
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: provider.periodTimeSets.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final item = provider.periodTimeSets[index];
                      final selected = item.id == currentSelectedId;
                      return ExpressiveDialogOption(
                        selected: selected,
                        title: Text(item.name),
                        subtitle: Text(
                          l10n.schoolWebImportPeriodCount(
                            item.periodTimes.length,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        trailing: IconButton(
                          tooltip: l10n.editPeriodTimeSet,
                          onPressed: (busy || popped)
                              ? null
                              : () {
                                  unawaited(
                                    runBusy(
                                      debugLabel: 'Edit period time set',
                                      action: () async {
                                        await openPeriodTimePage(item.id);
                                        final stillExists =
                                            provider.periodTimeSetForId(
                                              item.id,
                                            ) !=
                                            null;
                                        if (!stillExists &&
                                            currentSelectedId == item.id) {
                                          currentSelectedId =
                                              provider
                                                  .activePeriodTimeSetOrNull
                                                  ?.id ??
                                              '';
                                        }
                                      },
                                    ),
                                  );
                                },
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        onTap: () => popOnce(item.id),
                        enabled: !(busy || popped),
                      );
                    },
                  ),
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
