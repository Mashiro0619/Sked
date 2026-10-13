import 'sked_task_dialog.dart';

import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../models/timetable_models.dart';
import 'expressive_dialog.dart';

String generalEventEditScopeLabel(
  GeneralEventEditScope scope,
  AppLocalizations l10n,
) => switch (scope) {
  GeneralEventEditScope.thisOccurrence => l10n.eventEditThisOccurrence,
  GeneralEventEditScope.thisAndFollowing => l10n.eventEditThisAndFollowing,
  GeneralEventEditScope.entireSeries => l10n.eventEditEntireSeries,
};

Future<GeneralEventEditScope?> showGeneralEventEditScopeDialog(
  BuildContext context,
  GeneralEventOccurrence occurrence, {
  ValueChanged<ModalRoute<dynamic>?>? onChildRouteChanged,
}) async {
  if (!occurrence.event.recurrenceRule.isRepeating) {
    return GeneralEventEditScope.entireSeries;
  }
  try {
    return await showExpressiveDialog<GeneralEventEditScope>(
      context: context,
      waitForTransitionComplete: true,
      builder: (dialogContext) {
        onChildRouteChanged?.call(ModalRoute.of(dialogContext));
        final l10n = AppLocalizations.of(dialogContext);
        var completed = false;
        void finish([GeneralEventEditScope? scope]) {
          if (completed) return;
          completed = true;
          Navigator.of(dialogContext).pop(scope);
        }

        return SkedTaskDialog(
          key: const ValueKey('general-event-edit-scope-dialog'),
          constraints: const BoxConstraints(
            minWidth: expressiveDialogMaxWidth,
            maxWidth: expressiveDialogMaxWidth,
          ),
          scrollable: true,
          title: Text(l10n.eventEditScopeTitle),
          content: ExpressiveDialogContent(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(occurrence.event.title),
                const SizedBox(height: 8),
                for (final scope in GeneralEventEditScope.values)
                  if (scope != GeneralEventEditScope.thisAndFollowing ||
                      occurrence.sequence > 0)
                    ExpressiveDialogOption(
                      key: ValueKey('event-edit-scope-${scope.name}'),
                      title: Text(generalEventEditScopeLabel(scope, l10n)),
                      onTap: () => finish(scope),
                    ),
              ],
            ),
          ),
          actions: [TextButton(onPressed: finish, child: Text(l10n.cancel))],
        );
      },
    );
  } finally {
    onChildRouteChanged?.call(null);
  }
}

void showHiddenCalendarSaveFeedback(
  BuildContext context, {
  required GeneralSchedule calendar,
  required VoidCallback onView,
}) {
  if (calendar.isVisible || !context.mounted) return;
  final l10n = AppLocalizations.of(context);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(l10n.eventSavedToHiddenCalendar(calendar.name)),
      action: SnackBarAction(label: l10n.viewEvent, onPressed: onView),
    ),
  );
}
