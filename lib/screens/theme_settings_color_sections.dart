part of 'theme_settings_page.dart';

class _ColorfulThemeSection extends StatelessWidget {
  const _ColorfulThemeSection({
    super.key,
    required this.provider,
    required this.onPickUiColor,
    required this.onPickGeneralMonthTextColor,
    required this.onPickCourseColor,
    required this.onPickCalendarColor,
  });

  final TimetableProvider provider;
  final ValueChanged<String> onPickUiColor;
  final ValueChanged<String> onPickGeneralMonthTextColor;
  final ValueChanged<String> onPickCourseColor;
  final ValueChanged<GeneralSchedule> onPickCalendarColor;

  @override
  Widget build(BuildContext context) {
    final courseNames = provider.courseNameColorValues.keys.toList()..sort();
    final calendars = provider.generalSchedules.toList()
      ..sort((a, b) {
        final order = a.sortOrder.compareTo(b.sortOrder);
        return order != 0 ? order : a.name.compareTo(b.name);
      });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ColorSettingsGroup(
          title: AppLocalizations.of(context).themeColorUiColors,
          children: [
            for (final key in [
              colorfulUiPrimaryKey,
              colorfulUiSecondaryKey,
              colorfulUiTertiaryKey,
              if (provider.isStudentMode) colorfulCourseTextColorKey,
            ])
              _ColorValueTile(
                key: ValueKey('theme-ui-color-$key'),
                title: _uiColorLabel(context, key),
                colorValue: _effectiveUiColorValue(context, provider, key),
                onTap: () => onPickUiColor(key),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (provider.isStudentMode) ...[
          _ColorSettingsGroup(
            title: AppLocalizations.of(context).themeColorCourseColors,
            children: courseNames.isEmpty
                ? [
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        AppLocalizations.of(context)
                            .themeColorCourseColorsEmpty,
                      ),
                    ),
                  ]
                : [
                    for (final courseName in courseNames)
                      _ColorValueTile(
                        key: ValueKey('theme-course-color-$courseName'),
                        title: courseName,
                        colorValue:
                            provider.courseNameColorValues[courseName] ??
                            provider.themeSeedColorValue,
                        onTap: () => onPickCourseColor(courseName),
                      ),
                  ],
          ),
        ] else ...[
          _ColorSettingsGroup(
            title: AppLocalizations.of(context).calendars,
            children: [
              for (final schedule in calendars)
                _ColorValueTile(
                  key: ValueKey('theme-general-calendar-color-${schedule.id}'),
                  title: schedule.name,
                  colorValue: effectiveGeneralCalendarColor(
                    context,
                    schedule,
                  ).toARGB32(),
                  onTap: () => onPickCalendarColor(schedule),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _ColorSettingsGroup(
            title: _generalMonthTextColorGroupTitle(context),
            children: [
              for (final key in colorfulGeneralMonthTextColorKeys)
                _ColorValueTile(
                  key: ValueKey('theme-general-month-text-color-$key'),
                  title: _generalMonthTextColorLabel(context, key),
                  colorValue: _effectiveGeneralMonthTextColorValue(
                    context,
                    provider,
                    key,
                  ),
                  onTap: () => onPickGeneralMonthTextColor(key),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ColorSettingsGroup extends StatelessWidget {
  const _ColorSettingsGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return _SurfacePanel(
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(title, style: Theme.of(context).textTheme.titleSmall),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _ColorValueTile extends StatelessWidget {
  const _ColorValueTile({
    super.key,
    required this.title,
    required this.colorValue,
    required this.onTap,
  });

  final String title;
  final int colorValue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final colorLabel = _formatColorHex(colorValue);
    return Semantics(
      label: '$title, $colorLabel',
      button: true,
      onTap: onTap,
      child: ExcludeSemantics(
        child: ExpressiveTap(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        colorLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _ThemeColorPreview(colorValue: colorValue, selected: false),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
