import 'package:material_ui/material_ui.dart';

import '../controllers/general_event_task_controller.dart';
import '../l10n/app_localizations.dart';
import '../models/timetable_models.dart';
import 'general_event_editor_sheet.dart';

/// Presentation adapter; persistence and target lifetime belong to [task].
class GeneralEventTaskEditor extends StatelessWidget {
  const GeneralEventTaskEditor({
    super.key,
    required this.task,
    this.initialDate,
  });

  final GeneralEventTaskController task;
  final DateTime? initialDate;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: task.provider,
    builder: (context, _) => GeneralEventEditorSheet(
      initialEvent: task.initialEvent,
      initialDate: initialDate,
      editScope: task.occurrence?.event.recurrenceRule.isRepeating == true
          ? task.scope
          : null,
      calendars: task.provider.generalSchedules,
      activeCalendarId: task.calendarId,
      defaultReminderMinutesBefore: task.provider.generalDefaultMinutesBefore,
      onSave: (draft) async {
        try {
          await task.save(draft);
        } on GeneralEventEditConflictException {
          if (!context.mounted) rethrow;
          throw FormatException(AppLocalizations.of(context).eventEditConflict);
        }
      },
      onDelete: task.occurrence == null ? null : task.delete,
    ),
  );
}
