import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import 'expressive_dialog.dart';

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
  });

  final TextEditingController nameController;
  final TextEditingController weeksController;
  final String startDateLabel;
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
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextFormField(
                controller: nameController,
                enabled: enabled,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                textInputAction: TextInputAction.next,
                validator: nameValidator,
                decoration: InputDecoration(labelText: l10n.timetableName),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: weeksController,
                enabled: enabled,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                inputFormatters: weeksInputFormatters,
                decoration: InputDecoration(labelText: l10n.totalWeeks),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _TimetableInformationTile(
          title: l10n.semesterStartDate,
          summary: startDateLabel,
          leadingIcon: Icons.calendar_month_outlined,
          trailingIcon: Icons.calendar_month,
          enabled: enabled,
          onTap: onPickStartDate,
        ),
        const SizedBox(height: 4),
        _TimetableInformationTile(
          title: l10n.periodTimeSets,
          summary: periodTimeSetSummary,
          leadingIcon: Icons.schedule_outlined,
          trailingIcon: Icons.chevron_right,
          enabled: enabled,
          onTap: onPickPeriodTimeSet,
        ),
      ],
    );
  }
}

class TimetableInformationDialogSurface extends StatelessWidget {
  const TimetableInformationDialogSurface({
    super.key,
    required this.title,
    required this.form,
    required this.actions,
    this.leading,
  });

  final Widget title;
  final Widget form;
  final Widget? leading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 6,
      borderRadius: BorderRadius.circular(28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: DefaultTextStyle.merge(
                style: Theme.of(context).textTheme.headlineSmall,
                child: title,
              ),
            ),
            const SizedBox(height: 24),
            form,
            Padding(
              padding: const EdgeInsets.all(24),
              child: ExpressiveActionArea(leading: leading, actions: actions),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimetableInformationTile extends StatelessWidget {
  const _TimetableInformationTile({
    required this.title,
    required this.summary,
    required this.leadingIcon,
    required this.trailingIcon,
    required this.enabled,
    required this.onTap,
  });

  final String title;
  final String summary;
  final IconData leadingIcon;
  final IconData trailingIcon;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final contentColor = enabled
        ? colors.onSurface
        : colors.onSurface.withValues(alpha: 0.38);
    final secondaryColor = enabled
        ? colors.onSurfaceVariant
        : colors.onSurface.withValues(alpha: 0.38);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: <Widget>[
                Icon(leadingIcon, color: secondaryColor),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: contentColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: secondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(trailingIcon, color: secondaryColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
