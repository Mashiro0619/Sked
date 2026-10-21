import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/timetable_models.dart';
import '../controllers/settings_view_state.dart';
import 'workspace_editor_form.dart';

/// Course-specific overrides of the system notification default. The controls
/// only edit the parent draft; notification permissions belong to settings.
class CourseSystemReminderField extends StatelessWidget {
  const CourseSystemReminderField({
    super.key,
    required this.behavior,
    required this.minutesController,
    required this.onChanged,
    this.enabled = true,
    this.minutesFocusNode,
    this.minutesError,
    this.onMinutesChanged,
  });
  final CourseReminderBehavior behavior;
  final TextEditingController minutesController;
  final ValueChanged<CourseReminderBehavior> onChanged;
  final bool enabled;
  final FocusNode? minutesFocusNode;
  final String? minutesError;
  final ValueChanged<String>? onMinutesChanged;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final defaultMinutes = context.select<SettingsViewState?, int?>(
      (settings) => settings?.notificationSettings.courseDefaultMinutesBefore,
    );
    final inherited = l.courseReminderInherit(
      defaultMinutes == null
          ? l.notificationReminderOff
          : l.notificationReminderCustom(defaultMinutes),
    );
    final minutesInput = SkedEditorTextField(
      controlKey: const ValueKey('course-reminder-custom-minutes'),
      label: l.courseReminderMinutesLabel,
      controller: minutesController,
      focusNode: minutesFocusNode,
      onChanged: onMinutesChanged,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(),
      errorText: minutesError,
    );
    final modePicker = SkedEditorChoiceField<CourseReminderBehavior>(
      controlKey: const ValueKey('course-reminder-behavior'),
      initialSelection: behavior,
      label: l.courseSystemReminder,
      enabled: enabled,
      workspace: AppMode.student,
      entries: [
        DropdownMenuEntry(
          value: CourseReminderBehavior.inherit,
          label: inherited,
        ),
        DropdownMenuEntry(
          value: CourseReminderBehavior.disabled,
          label: l.notificationReminderOff,
        ),
        DropdownMenuEntry(
          value: CourseReminderBehavior.custom,
          label: l.recurrenceCustom,
        ),
      ],
      onSelected: (value) {
        if (value != null) onChanged(value);
      },
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        modePicker,
        if (behavior == CourseReminderBehavior.custom) ...[
          const SizedBox(height: 12),
          minutesInput,
        ],
      ],
    );
  }
}
