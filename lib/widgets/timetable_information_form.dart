import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import 'app_modal_sheet.dart';
import 'expressive_dialog.dart';
import 'workspace_editor.dart';
import 'workspace_editor_form.dart';

class TimetableInformationForm extends StatelessWidget {
  const TimetableInformationForm({
    super.key,
    required this.nameController,
    required this.weeksController,
    required this.startDateLabel,
    required this.periodTimeSetSummary,
    required this.enabled,
    required this.onPickStartDate,
    required this.onPickPeriodTimeSet,
    this.nameValidator,
    this.weeksInputFormatters,
    this.startDateAnchorKey,
    this.periodTimeSetAnchorKey,
  });

  final TextEditingController nameController;
  final TextEditingController weeksController;
  final String startDateLabel;
  final Key? startDateAnchorKey;
  final Key? periodTimeSetAnchorKey;
  final String periodTimeSetSummary;
  final bool enabled;
  final VoidCallback? onPickStartDate;
  final VoidCallback? onPickPeriodTimeSet;
  final FormFieldValidator<String>? nameValidator;
  final List<TextInputFormatter>? weeksInputFormatters;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SkedEditorTextField(
          label: l10n.timetableName,
          controller: nameController,
          enabled: enabled,
          icon: Icons.view_week_outlined,
          headline: true,
          formField: true,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          textInputAction: TextInputAction.next,
          validator: nameValidator,
        ),
        const SizedBox(height: 16),
        SkedEditorFormRow(
          minimumChildWidths: [
            workspaceEditorMinimumFieldWidth(
              context,
              label: l10n.totalWeeks,
              minimumWidth: 96,
            ),
            workspaceEditorMinimumFieldWidth(
              context,
              label: l10n.semesterStartDate,
              value: startDateLabel,
              valuePadding: 68,
              minimumWidth: 160,
            ),
          ],
          children: [
            SkedEditorTextField(
              label: l10n.totalWeeks,
              controller: weeksController,
              enabled: enabled,
              icon: Icons.numbers,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: weeksInputFormatters,
            ),
            SkedEditorValueField(
              key: startDateAnchorKey,
              label: l10n.semesterStartDate,
              value: startDateLabel,
              icon: Icons.calendar_month_outlined,
              enabled: enabled,
              onPressed: onPickStartDate == null
                  ? null
                  : (_) => onPickStartDate!(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SkedEditorFormRow(
          minimumChildWidths: [
            workspaceEditorMinimumFieldWidth(
              context,
              label: l10n.periodTimeSets,
              value: periodTimeSetSummary,
              valuePadding: 68,
              minimumWidth: 240,
            ),
          ],
          children: [
            SkedEditorValueField(
              key: periodTimeSetAnchorKey,
              label: l10n.periodTimeSets,
              value: periodTimeSetSummary,
              icon: Icons.schedule_outlined,
              enabled: enabled,
              onPressed: onPickPeriodTimeSet == null
                  ? null
                  : (_) => onPickPeriodTimeSet!(),
            ),
          ],
        ),
      ],
    );
  }
}

/// Compatibility entry for existing previews; editor geometry and chrome are
/// provided by the same scaffold as course and event editing.
class TimetableInformationDialogSurface extends StatelessWidget {
  const TimetableInformationDialogSurface({
    super.key,
    required this.title,
    required this.form,
    this.editorActions,
    this.actions = const [],
    this.leading,
    this.embedded = false,
    this.onClose,
    this.closeEnabled = true,
    this.busy = false,
  });

  final Widget title;
  final Widget form;
  final SkedEditorActions? editorActions;
  final Widget? leading;
  final List<Widget> actions;
  final bool embedded;
  final VoidCallback? onClose;
  final bool closeEnabled;
  final bool busy;

  @override
  Widget build(BuildContext context) => AppSheetScaffold.editor(
    title: title,
    onClose:
        onClose ??
        () {
          Navigator.of(context).maybePop();
        },
    closeEnabled: closeEnabled,
    compact: true,
    busy: busy,
    editorActions:
        editorActions ??
        const SkedEditorActions(onCancel: null, onSubmit: null),
    footer: editorActions == null
        ? ExpressiveActionArea(leading: leading, actions: actions)
        : null,
    child: form,
  );
}
