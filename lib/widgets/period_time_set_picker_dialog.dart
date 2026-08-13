import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/timetable_models.dart';
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

          return PeriodTimeSetPickerDialogView(
            periodTimeSets: provider.periodTimeSets,
            selectedPeriodTimeSetId: currentSelectedId,
            busy: busy,
            blocked: busy || popped,
            onCreate: () {
              unawaited(
                runBusy(
                  debugLabel: 'Create period time set',
                  action: () async {
                    final created = await provider.addPeriodTimeSet();
                    if (!dialogContext.mounted || popped) return;
                    currentSelectedId = created.id;
                    await openPeriodTimePage(created.id);
                  },
                ),
              );
            },
            onEdit: (item) {
              unawaited(
                runBusy(
                  debugLabel: 'Edit period time set',
                  action: () async {
                    await openPeriodTimePage(item.id);
                    final stillExists =
                        provider.periodTimeSetForId(item.id) != null;
                    if (!stillExists && currentSelectedId == item.id) {
                      currentSelectedId =
                          provider.activePeriodTimeSetOrNull?.id ?? '';
                    }
                  },
                ),
              );
            },
            onSelect: popOnce,
            onCancel: popOnce,
          );
        },
      );
    },
  );
}

/// The presentation layer shared by the live picker route and widget previews.
class PeriodTimeSetPickerDialogView extends StatelessWidget {
  const PeriodTimeSetPickerDialogView({
    super.key,
    required this.periodTimeSets,
    required this.selectedPeriodTimeSetId,
    required this.busy,
    required this.blocked,
    required this.onCreate,
    required this.onEdit,
    required this.onSelect,
    required this.onCancel,
  });

  final List<PeriodTimeSet> periodTimeSets;
  final String selectedPeriodTimeSetId;
  final bool busy;
  final bool blocked;
  final VoidCallback onCreate;
  final ValueChanged<PeriodTimeSet> onEdit;
  final ValueChanged<String> onSelect;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final mediaQuery = MediaQuery.of(context);
    final useCompactSpacing =
        mediaQuery.size.width < 360 || mediaQuery.textScaler.scale(1) > 1.3;
    final horizontalInset = useCompactSpacing ? 16.0 : 24.0;
    final horizontalContentPadding = useCompactSpacing ? 12.0 : 20.0;
    final maxListHeight = (mediaQuery.size.height * 0.58).clamp(96.0, 480.0);

    return PopScope(
      canPop: !blocked,
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
        titleTextStyle: Theme.of(context).textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.w700),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            UiCommandBusyIndicator(busy: busy),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Expanded(child: Text(l10n.selectPeriodTimeSet)),
                IconButton(
                  tooltip: l10n.newItem,
                  onPressed: blocked ? null : onCreate,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ],
        ),
        content: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxListHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ExpressiveDialogContent(
                maxWidth: 320,
                child: ListView.separated(
                  key: const ValueKey('period-time-set-picker-list'),
                  primary: false,
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: periodTimeSets.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final item = periodTimeSets[index];
                    return ExpressiveDialogOption(
                      selected: item.id == selectedPeriodTimeSetId,
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
                        onPressed: blocked ? null : () => onEdit(item),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      onTap: () => onSelect(item.id),
                      enabled: !blocked,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: blocked ? null : onCancel,
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }
}
