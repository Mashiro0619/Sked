import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/timetable_models.dart';
import '../providers/timetable_provider.dart';
import '../theme/sked_expressive_theme.dart';
import '../utils/general_schedule_colors.dart';
import '../widgets/expressive_dialog.dart';
import '../widgets/expressive_motion.dart';
import '../widgets/settings_list.dart';
import '../widgets/sked_expressive_components.dart';
import '../widgets/ui_command.dart';

part 'theme_settings_color_sections.dart';
part 'theme_settings_outline_page.dart';

const _themeSeedOptions = <int>[
  0xFF6750A4,
  0xFF5E35B1,
  0xFF3949AB,
  0xFF1E88E5,
  0xFF00897B,
  0xFF2E7D32,
  0xFF7CB342,
  0xFFF9A825,
  0xFFEF6C00,
  0xFFF4511E,
  0xFFD32F2F,
  0xFFD81B60,
  0xFFC2185B,
  0xFF6D4C41,
  0xFF455A64,
  0xFF546E7A,
];

bool _isPresetThemeColor(int colorValue) =>
    _themeSeedOptions.contains(colorValue);

String _formatColorHex(int colorValue) {
  final rgb = colorValue & 0x00FFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

String _formatOutlineWidthNumber(double width) {
  return width.toStringAsFixed(width % 1 == 0 ? 0 : 1);
}

String _formatOutlineWidthValue(BuildContext context, double width) {
  final l10n = AppLocalizations.of(context);
  return '${_formatOutlineWidthNumber(width)} ${l10n.outlineWidthUnit}';
}

String _outlineModeLabel(BuildContext context, String mode) {
  final l10n = AppLocalizations.of(context);
  return switch (mode) {
    liveCourseOutlineModeAllDisplayed =>
      l10n.liveCourseOutlineTargetAllDisplayed,
    _ => l10n.liveCourseOutlineTargetCurrentOrNext,
  };
}

int _derivedOutlineColorValue(int themeSeedColorValue) {
  return deriveLiveCourseOutlineColorFromSeed(Color(themeSeedColorValue))
      .toARGB32();
}

int _effectiveUiColorValue(
  BuildContext context,
  TimetableProvider provider,
  String key,
) {
  final colorScheme = Theme.of(context).colorScheme;
  return switch (key) {
    colorfulUiPrimaryKey =>
      provider.colorfulUiColorValues[key] ?? colorScheme.primary.toARGB32(),
    colorfulUiSecondaryKey =>
      provider.colorfulUiColorValues[key] ?? colorScheme.secondary.toARGB32(),
    colorfulUiTertiaryKey =>
      provider.colorfulUiColorValues[key] ?? colorScheme.tertiary.toARGB32(),
    colorfulCourseTextColorKey =>
      provider.colorfulUiColorValues[key] ?? colorScheme.onSurface.toARGB32(),
    _ => provider.colorfulUiColorValues[key] ?? colorScheme.primary.toARGB32(),
  };
}

String _uiColorLabel(BuildContext context, String key) {
  final l10n = AppLocalizations.of(context);
  return switch (key) {
    colorfulUiPrimaryKey => l10n.themeColorPrimary,
    colorfulUiSecondaryKey => l10n.themeColorSecondary,
    colorfulUiTertiaryKey => l10n.themeColorTertiary,
    colorfulCourseTextColorKey => l10n.themeColorCourseText,
    _ => key,
  };
}

int _effectiveGeneralMonthTextColorValue(
  BuildContext context,
  TimetableProvider provider,
  String key,
) {
  final customValue = provider.colorfulUiColorValues[key];
  if (customValue != null) {
    return customValue;
  }
  final colors = Theme.of(context).colorScheme;
  return switch (key) {
    colorfulGeneralFestivalTextColorKey => effectiveGeneralFestivalTextColor(
      context,
      colors.primary,
    ).toARGB32(),
    colorfulGeneralSolarTermTextColorKey => effectiveGeneralSolarTermTextColor(
      context,
      colors.tertiary,
    ).toARGB32(),
    _ => effectiveGeneralLunarTextColor(
      context,
      colors.onSurfaceVariant,
    ).toARGB32(),
  };
}

String _generalMonthTextColorGroupTitle(BuildContext context) {
  final localeName = AppLocalizations.of(context).localeName;
  if (localeName.startsWith('zh')) {
    return '月视图文本';
  }
  return 'Month view text';
}

String _generalMonthTextColorLabel(BuildContext context, String key) {
  final localeName = AppLocalizations.of(context).localeName;
  if (localeName.startsWith('zh')) {
    return switch (key) {
      colorfulGeneralFestivalTextColorKey => '节日/假日',
      colorfulGeneralSolarTermTextColorKey => '节气',
      _ => '农历日期',
    };
  }
  return switch (key) {
    colorfulGeneralFestivalTextColorKey => 'Festivals and holidays',
    colorfulGeneralSolarTermTextColorKey => 'Solar terms',
    _ => 'Lunar dates',
  };
}

class _SegmentOption {
  const _SegmentOption({required this.value, required this.label});

  final String value;
  final String label;
}

class _ResponsiveSegmentedButton extends StatelessWidget {
  const _ResponsiveSegmentedButton({
    super.key,
    required this.segments,
    required this.selected,
    required this.onSelectionChanged,
    this.choiceListKey,
  });

  final List<_SegmentOption> segments;
  final Set<String> selected;
  final ValueChanged<Set<String>> onSelectionChanged;
  final Key? choiceListKey;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final theme = Theme.of(context);
        final textStyle = theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        );
        final textScaler = MediaQuery.textScalerOf(context);
        final direction = Directionality.of(context);
        final segmentWidth = constraints.maxWidth / segments.length;
        const horizontalLabelPadding = 8.0;
        final labelsFit =
            constraints.maxWidth.isFinite &&
            segments.every((segment) {
              final painter = TextPainter(
                text: TextSpan(text: segment.label, style: textStyle),
                textDirection: direction,
                textScaler: textScaler,
                locale: Localizations.maybeLocaleOf(context),
                maxLines: 1,
              )..layout();
              return painter.width <=
                  (segmentWidth - horizontalLabelPadding).clamp(
                    0.0,
                    double.infinity,
                  );
            });
        final buttonSegments = [
          for (final segment in segments)
            ButtonSegment<String>(
              value: segment.value,
              label: Text(
                segment.label,
                maxLines: labelsFit ? 1 : null,
                softWrap: !labelsFit,
                overflow: labelsFit ? TextOverflow.clip : null,
                textAlign: TextAlign.center,
              ),
              tooltip: segment.label,
            ),
        ];
        final style = ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          ),
          textStyle: WidgetStatePropertyAll(textStyle),
        );
        if (!labelsFit) {
          return _ConnectedSingleChoiceList(
            key: choiceListKey,
            segments: segments,
            selected: selected,
            onSelectionChanged: onSelectionChanged,
          );
        }
        return SkedExpressiveSegmentedButton<String>(
          expandedInsets: EdgeInsets.zero,
          segments: buttonSegments,
          selected: selected,
          showSelectedIcon: false,
          movingIndicator: true,
          movingIndicatorFillsSegment: true,
          style: style,
          onSelectionChanged: onSelectionChanged,
        );
      },
    );
  }
}

class _ConnectedSingleChoiceList extends StatelessWidget {
  const _ConnectedSingleChoiceList({
    super.key,
    required this.segments,
    required this.selected,
    required this.onSelectionChanged,
  });

  final List<_SegmentOption> segments;
  final Set<String> selected;
  final ValueChanged<Set<String>> onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final shapes = skedShapeSchemeOf(context);
    return Material(
      color: colors.surfaceContainerLow,
      shape: shapes.container,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < segments.length; index++) ...[
            if (index > 0)
              Divider(
                height: 1,
                color: colors.outlineVariant.withValues(alpha: 0.55),
              ),
            _ConnectedSingleChoiceRow(
              segment: segments[index],
              selected: selected.contains(segments[index].value),
              onTap: () => onSelectionChanged({segments[index].value}),
            ),
          ],
        ],
      ),
    );
  }
}

class _ConnectedSingleChoiceRow extends StatelessWidget {
  const _ConnectedSingleChoiceRow({
    required this.segment,
    required this.selected,
    required this.onTap,
  });

  final _SegmentOption segment;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: segment.label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: ExpressiveTap(
          onTap: onTap,
          borderRadius: BorderRadius.zero,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      segment.label,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: selected ? colors.primary : colors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ThemeSettingsPage extends StatefulWidget {
  const ThemeSettingsPage({super.key});

  @override
  State<ThemeSettingsPage> createState() => _ThemeSettingsPageState();
}

class _ThemeSettingsPageState extends State<ThemeSettingsPage>
    with UiCommandRunner<ThemeSettingsPage> {
  var _outlineSettingsPageOpen = false;

  void _updateSetting(String debugLabel, Future<void> Function() command) {
    unawaited(runUiCommand(debugLabel: debugLabel, command: command));
  }

  void _switchWorkspace(TimetableProvider provider, String value) {
    final targetMode = value == AppMode.general.value
        ? AppMode.general
        : AppMode.student;
    if (targetMode == provider.activeMode) return;
    _updateSetting(
      'Switch theme workspace',
      () => provider.switchMode(targetMode),
    );
  }

  Future<void> _openOutlineSettingsPage(
    BuildContext context,
    TimetableProvider provider,
  ) async {
    if (_outlineSettingsPageOpen || uiCommandBusy) return;
    _outlineSettingsPageOpen = true;
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider<TimetableProvider>.value(
            value: provider,
            child: const _ThemeSettingsOutlinePage(),
          ),
        ),
      );
    } finally {
      _outlineSettingsPageOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TimetableProvider>(
      builder: (context, provider, child) {
        final l10n = AppLocalizations.of(context);
        final hasCustomColor = !_isPresetThemeColor(
          provider.themeSeedColorValue,
        );
        final effectiveOutlineColorValue = provider.liveCourseOutlineFollowTheme
            ? _derivedOutlineColorValue(provider.themeSeedColorValue)
            : provider.liveCourseOutlineColorValue;
        final outlineWidth = provider.liveCourseOutlineWidth;
        final switcherDuration = SkedMotionPolicy.of(context)
            .effects(SkedMotionSpeed.fast);
        return Scaffold(
          appBar: AppBar(title: Text(l10n.theme)),
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                UiCommandBusyIndicator(
                  busy: uiCommandBusy,
                  showDelay: const Duration(milliseconds: 180),
                ),
                Expanded(
                  child: SettingsInteractionBlocker(
                    blocked: uiCommandBusy,
                    child: ResponsiveSettingsBody(
                      scrollViewKey: const PageStorageKey(
                        'theme-settings-scroll-view',
                      ),
                      firstColumnSectionIndices: const {0, 1, 2},
                      children: [
                        SettingsSectionHeader(
                          title: l10n.settingsSectionWorkspace,
                        ),
                        _ResponsiveSegmentedButton(
                          key: const ValueKey('theme-workspace-mode-segmented'),
                          choiceListKey: const ValueKey(
                            'theme-workspace-mode-choice-list',
                          ),
                          segments: [
                            _SegmentOption(
                              value: AppMode.student.value,
                              label: l10n.timetable,
                            ),
                            _SegmentOption(
                              value: AppMode.general.value,
                              label: l10n.themeWorkspaceSchedule,
                            ),
                          ],
                          selected: {provider.activeMode.value},
                          onSelectionChanged: (selection) {
                            if (selection.isEmpty) return;
                            _switchWorkspace(provider, selection.first);
                          },
                        ),
                        const SizedBox(height: 12),
                        SettingsSectionHeader(title: l10n.theme),
                        _ResponsiveSegmentedButton(
                          key: const ValueKey(
                            'theme-brightness-mode-segmented',
                          ),
                          choiceListKey: const ValueKey(
                            'theme-brightness-mode-choice-list',
                          ),
                          segments: [
                            _SegmentOption(
                              value: 'system',
                              label: l10n.themeFollowSystem,
                            ),
                            _SegmentOption(
                              value: 'light',
                              label: l10n.themeLight,
                            ),
                            _SegmentOption(
                              value: 'dark',
                              label: l10n.themeDark,
                            ),
                          ],
                          selected: {provider.themeMode},
                          onSelectionChanged: (selection) {
                            if (selection.isEmpty) {
                              return;
                            }
                            _updateSetting(
                              'Update theme brightness mode',
                              () => provider.updateThemeMode(selection.first),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        SettingsSectionHeader(title: l10n.themeColor),
                        _ResponsiveSegmentedButton(
                          key: const ValueKey('theme-color-mode-segmented'),
                          choiceListKey: const ValueKey(
                            'theme-color-mode-choice-list',
                          ),
                          segments: [
                            _SegmentOption(
                              value: themeColorModeSingle,
                              label: l10n.themeColorModeSingle,
                            ),
                            _SegmentOption(
                              value: themeColorModeColorful,
                              label: l10n.themeColorModeColorful,
                            ),
                          ],
                          selected: {provider.themeColorMode},
                          onSelectionChanged: (selection) {
                            if (selection.isEmpty) {
                              return;
                            }
                            _updateSetting(
                              'Update theme color mode',
                              () => provider.updateThemeColorMode(
                                selection.first,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        const SettingsSectionBreak(),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: AnimatedSwitcher(
                            duration: switcherDuration,
                            switchInCurve: Curves.easeOut,
                            switchOutCurve: Curves.easeIn,
                            child:
                                provider.themeColorMode == themeColorModeSingle
                                ? _SingleThemeColorSection(
                                    key: const ValueKey(
                                      'single-theme-color-section',
                                    ),
                                    provider: provider,
                                    hasCustomColor: hasCustomColor,
                                    onSelectColor: (colorValue) =>
                                        _updateSetting(
                                          'Update theme seed color',
                                          () => provider
                                              .updateThemeSeedColorValue(
                                                colorValue,
                                              ),
                                        ),
                                    onPickCustomColor: () => unawaited(
                                      _openCustomColorDialog(context, provider),
                                    ),
                                  )
                                : _ColorfulThemeSection(
                                    key: const ValueKey(
                                      'colorful-theme-section',
                                    ),
                                    provider: provider,
                                    onPickUiColor: (key) {
                                      if (key == colorfulCourseTextColorKey) {
                                        unawaited(
                                          _openCourseTextColorDialog(
                                            context,
                                            provider,
                                          ),
                                        );
                                        return;
                                      }
                                      unawaited(
                                        _openColorValueDialog(
                                          context,
                                          title: _uiColorLabel(context, key),
                                          previewTitle: l10n.themeColorUiColors,
                                          initialColorValue:
                                              _effectiveUiColorValue(
                                                context,
                                                provider,
                                                key,
                                              ),
                                          onApply: (colorValue) => provider
                                              .updateColorfulUiColorValue(
                                                key,
                                                colorValue,
                                              ),
                                        ),
                                      );
                                    },
                                    onPickGeneralMonthTextColor: (key) {
                                      unawaited(
                                        _openColorValueDialog(
                                          context,
                                          title: _generalMonthTextColorLabel(
                                            context,
                                            key,
                                          ),
                                          previewTitle:
                                              _generalMonthTextColorGroupTitle(
                                                context,
                                              ),
                                          initialColorValue:
                                              _effectiveGeneralMonthTextColorValue(
                                                context,
                                                provider,
                                                key,
                                              ),
                                          onApply: (colorValue) => provider
                                              .updateColorfulUiColorValue(
                                                key,
                                                colorValue,
                                              ),
                                        ),
                                      );
                                    },
                                    onPickCourseColor: (courseName) => unawaited(
                                      _openColorValueDialog(
                                        context,
                                        title: courseName,
                                        previewTitle:
                                            l10n.themeColorCourseColors,
                                        initialColorValue:
                                            provider
                                                .courseNameColorValues[courseName] ??
                                            provider.themeSeedColorValue,
                                        onApply: (colorValue) =>
                                            provider.updateCourseNameColorValue(
                                              courseName,
                                              colorValue,
                                            ),
                                      ),
                                    ),
                                    onPickCalendarColor: (schedule) =>
                                        unawaited(
                                          _openColorValueDialog(
                                            context,
                                            title: schedule.name,
                                            previewTitle: l10n.calendars,
                                            initialColorValue:
                                                effectiveGeneralCalendarColor(
                                                  context,
                                                  schedule,
                                                ).toARGB32(),
                                            onApply: (colorValue) =>
                                                provider.updateGeneralSchedule(
                                                  schedule.copyWith(
                                                    colorValue: colorValue,
                                                  ),
                                                ),
                                          ),
                                        ),
                                  ),
                          ),
                        ),
                        if (provider.isStudentMode) ...[
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: _OutlineSettingsCard(
                              key: const ValueKey(
                                'theme-outline-settings-card',
                              ),
                              provider: provider,
                              effectiveOutlineColorValue:
                                  effectiveOutlineColorValue,
                              outlineWidth: outlineWidth,
                              onTap: () => unawaited(
                                _openOutlineSettingsPage(context, provider),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openCustomColorDialog(
    BuildContext context,
    TimetableProvider provider,
  ) async {
    final l10n = AppLocalizations.of(context);
    var selectedColor = Color(provider.themeSeedColorValue);
    await showExpressiveDialog<void>(
      context: context,
      builder: (context) {
        var popped = false;
        var busy = false;
        void popOnce() {
          if (popped) return;
          popped = true;
          Navigator.of(context).pop();
        }

        return StatefulBuilder(
          builder: (context, setState) {
            final colorValue = selectedColor.toARGB32();
            return _PersistingThemeDialog(
              busy: busy,
              popped: popped,
              title: Text(l10n.themeCustomColor),
              content: SingleChildScrollView(
                child: ExpressiveDialogContent(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PreviewBanner(
                        title: l10n.themeColor,
                        value: _formatColorHex(colorValue),
                        preview: _ThemeColorPreview(
                          colorValue: colorValue,
                          selected: true,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SurfacePanel(
                        padding: const EdgeInsets.all(12),
                        child: Center(
                          child: _CompactColorPicker(
                            colorValue: colorValue,
                            onColorChanged: (updatedColorValue) => setState(() {
                              selectedColor = Color(updatedColorValue);
                            }),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: (busy || popped) ? null : popOnce,
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: (busy || popped)
                      ? null
                      : () async {
                          if (busy || popped) return;
                          final submittedColorValue = colorValue;
                          FocusScope.of(context).unfocus();
                          setState(() => busy = true);
                          final saved = await runUiCommandWithFeedback(
                            context: context,
                            debugLabel: 'Update custom theme seed color',
                            command: () => provider.updateThemeSeedColorValue(
                              submittedColorValue,
                            ),
                          );
                          if (!context.mounted) return;
                          if (saved) {
                            popOnce();
                          } else {
                            setState(() => busy = false);
                          }
                        },
                  child: Text(l10n.themeApplyCustomColor),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openColorValueDialog(
    BuildContext context, {
    required String title,
    required String previewTitle,
    required int initialColorValue,
    required Future<void> Function(int colorValue) onApply,
  }) async {
    final l10n = AppLocalizations.of(context);
    var selectedColor = Color(initialColorValue);
    await showExpressiveDialog<void>(
      context: context,
      builder: (context) {
        var popped = false;
        var busy = false;
        void popOnce() {
          if (popped) return;
          popped = true;
          Navigator.of(context).pop();
        }

        return StatefulBuilder(
          builder: (context, setState) {
            final colorValue = selectedColor.toARGB32();
            return _PersistingThemeDialog(
              busy: busy,
              popped: popped,
              title: Text(title),
              content: SingleChildScrollView(
                child: ExpressiveDialogContent(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PreviewBanner(
                        title: previewTitle,
                        value: _formatColorHex(colorValue),
                        preview: _ThemeColorPreview(
                          colorValue: colorValue,
                          selected: true,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SurfacePanel(
                        padding: const EdgeInsets.all(12),
                        child: Center(
                          child: _CompactColorPicker(
                            colorValue: colorValue,
                            onColorChanged: (updatedColorValue) => setState(() {
                              selectedColor = Color(updatedColorValue);
                            }),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: (busy || popped) ? null : popOnce,
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: (busy || popped)
                      ? null
                      : () async {
                          if (busy || popped) return;
                          final submittedColorValue = colorValue;
                          FocusScope.of(context).unfocus();
                          setState(() => busy = true);
                          final saved = await runUiCommandWithFeedback(
                            context: context,
                            debugLabel: 'Update theme color value',
                            command: () => onApply(submittedColorValue),
                          );
                          if (!context.mounted) return;
                          if (saved) {
                            popOnce();
                          } else {
                            setState(() => busy = false);
                          }
                        },
                  child: Text(l10n.themeApplySettings),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openCourseTextColorDialog(
    BuildContext context,
    TimetableProvider provider,
  ) async {
    final l10n = AppLocalizations.of(context);
    var mode = provider.colorfulCourseTextColorMode;
    var colorValue = _effectiveUiColorValue(
      context,
      provider,
      colorfulCourseTextColorKey,
    );
    await showExpressiveDialog<void>(
      context: context,
      builder: (context) {
        var popped = false;
        var busy = false;
        void popOnce() {
          if (popped) return;
          popped = true;
          Navigator.of(context).pop();
        }

        return StatefulBuilder(
          builder: (context, setState) {
            final modeLabel = mode == colorfulCourseTextColorModeCustom
                ? l10n.themeColorCourseTextCustom
                : l10n.themeColorCourseTextAuto;
            return _PersistingThemeDialog(
              busy: busy,
              popped: popped,
              title: Text(l10n.themeColorCourseText),
              content: SingleChildScrollView(
                child: ExpressiveDialogContent(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PreviewBanner(
                        title: l10n.themeColorCourseText,
                        value: mode == colorfulCourseTextColorModeCustom
                            ? '$modeLabel - ${_formatColorHex(colorValue)}'
                            : modeLabel,
                        preview: _ThemeColorPreview(
                          colorValue: colorValue,
                          selected: true,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SurfacePanel(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.themeColorCourseText,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 12),
                            _ResponsiveSegmentedButton(
                              segments: [
                                _SegmentOption(
                                  value: colorfulCourseTextColorModeAuto,
                                  label: l10n.themeColorCourseTextAuto,
                                ),
                                _SegmentOption(
                                  value: colorfulCourseTextColorModeCustom,
                                  label: l10n.themeColorCourseTextCustom,
                                ),
                              ],
                              selected: {mode},
                              onSelectionChanged: (selection) {
                                if (selection.isEmpty) {
                                  return;
                                }
                                setState(() {
                                  mode = selection.first;
                                });
                              },
                            ),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeInOut,
                              alignment: Alignment.topCenter,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                switchInCurve: Curves.easeOut,
                                switchOutCurve: Curves.easeIn,
                                child: mode == colorfulCourseTextColorModeCustom
                                    ? Padding(
                                        key: const ValueKey(
                                          'course-text-color-picker',
                                        ),
                                        padding: const EdgeInsets.only(top: 12),
                                        child: Center(
                                          child: _CompactColorPicker(
                                            colorValue: colorValue,
                                            onColorChanged:
                                                (updatedColorValue) =>
                                                    setState(() {
                                                      colorValue =
                                                          updatedColorValue;
                                                    }),
                                          ),
                                        ),
                                      )
                                    : const SizedBox.shrink(
                                        key: ValueKey('course-text-color-auto'),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: (busy || popped) ? null : popOnce,
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: (busy || popped)
                      ? null
                      : () async {
                          if (busy || popped) return;
                          final submittedMode = mode;
                          final submittedColorValue = colorValue;
                          FocusScope.of(context).unfocus();
                          setState(() => busy = true);
                          final saved = await runUiCommandWithFeedback(
                            context: context,
                            debugLabel: 'Update course text color settings',
                            command: () =>
                                provider.updateColorfulCourseTextSettings(
                                  mode: submittedMode,
                                  customColorValue: submittedColorValue,
                                ),
                          );
                          if (!context.mounted) return;
                          if (saved) {
                            popOnce();
                          } else {
                            setState(() => busy = false);
                          }
                        },
                  child: Text(l10n.themeApplySettings),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _PersistingThemeDialog extends StatelessWidget {
  const _PersistingThemeDialog({
    required this.busy,
    required this.popped,
    required this.title,
    required this.content,
    required this.actions,
  });

  final bool busy;
  final bool popped;
  final Widget title;
  final Widget content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final blocked = busy || popped;
    return PopScope(
      canPop: !blocked,
      child: FocusScope(
        key: const ValueKey('theme-persistence-dialog-focus-scope'),
        canRequestFocus: !blocked,
        descendantsAreFocusable: !blocked,
        descendantsAreTraversable: !blocked,
        child: AbsorbPointer(
          key: const ValueKey('theme-persistence-dialog-pointer-guard'),
          absorbing: blocked,
          child: AlertDialog(
            title: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                UiCommandBusyIndicator(
                  key: const ValueKey(
                    'theme-persistence-dialog-busy-indicator',
                  ),
                  busy: busy,
                ),
                const SizedBox(height: 8),
                title,
              ],
            ),
            content: content,
            actions: actions,
          ),
        ),
      ),
    );
  }
}

class _SingleThemeColorSection extends StatelessWidget {
  const _SingleThemeColorSection({
    super.key,
    required this.provider,
    required this.hasCustomColor,
    required this.onSelectColor,
    required this.onPickCustomColor,
  });

  final TimetableProvider provider;
  final bool hasCustomColor;
  final ValueChanged<int> onSelectColor;
  final VoidCallback onPickCustomColor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PreviewBanner(
          title: l10n.themeColor,
          value: _formatColorHex(provider.themeSeedColorValue),
          preview: _ThemeColorPreview(
            colorValue: provider.themeSeedColorValue,
            selected: true,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          key: const ValueKey('theme-seed-color-palette'),
          width: double.infinity,
          child: Wrap(
            alignment: WrapAlignment.center,
            runAlignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final colorValue in _themeSeedOptions)
                _ThemeColorOption(
                  key: ValueKey(
                    'theme-seed-color-${_formatColorHex(colorValue)}',
                  ),
                  colorValue: colorValue,
                  selected: provider.themeSeedColorValue == colorValue,
                  onTap: () => onSelectColor(colorValue),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _ActionOptionCard(
          onTap: onPickCustomColor,
          selected: hasCustomColor,
          leading: _ThemeColorPreview(
            colorValue: provider.themeSeedColorValue,
            selected: hasCustomColor,
          ),
          title: l10n.themeCustomColor,
          subtitle: hasCustomColor
              ? _formatColorHex(provider.themeSeedColorValue)
              : null,
        ),
      ],
    );
  }
}

class _OutlineSettingsCard extends StatelessWidget {
  const _OutlineSettingsCard({
    super.key,
    required this.provider,
    required this.effectiveOutlineColorValue,
    required this.outlineWidth,
    required this.onTap,
  });

  final TimetableProvider provider;
  final int effectiveOutlineColorValue;
  final double outlineWidth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return _SurfacePanel(
      padding: EdgeInsets.zero,
      child: ExpressiveTap(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.liveCourseOutlineSettings,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.liveCourseOutlineSettingsHint,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _OutlineColorPreview(
                    colorValue: effectiveOutlineColorValue,
                    borderWidth: outlineWidth,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SummaryValueRow(
                label: l10n.liveCourseOutlineEnabled,
                value: Icon(
                  provider.liveCourseOutlineEnabled
                      ? Icons.check_circle_outline
                      : Icons.remove_circle_outline,
                  color: provider.liveCourseOutlineEnabled
                      ? colors.primary
                      : colors.outline,
                ),
              ),
              const SizedBox(height: 10),
              _SummaryValueRow(
                label: l10n.liveCourseOutlineFollowTheme,
                value: Icon(
                  provider.liveCourseOutlineFollowTheme
                      ? Icons.check_circle_outline
                      : Icons.palette_outlined,
                  color: provider.liveCourseOutlineFollowTheme
                      ? colors.primary
                      : colors.outline,
                ),
              ),
              const SizedBox(height: 10),
              _SummaryValueRow(
                label: l10n.liveCourseOutlineTarget,
                value: Text(
                  _outlineModeLabel(context, provider.liveCourseOutlineMode),
                ),
              ),
              const SizedBox(height: 10),
              _SummaryValueRow(
                label: l10n.liveCourseOutlineEffectiveColor,
                value: Text(_formatColorHex(effectiveOutlineColorValue)),
              ),
              const SizedBox(height: 10),
              _SummaryValueRow(
                label: l10n.liveCourseOutlineWidth,
                value: Text(_formatOutlineWidthValue(context, outlineWidth)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutlineSwitchRow extends StatelessWidget {
  const _OutlineSwitchRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    void toggle() => onChanged(!value);
    return Semantics(
      label: title,
      toggled: value,
      onTap: toggle,
      child: ExcludeSemantics(
        child: ExpressiveTap(
          onTap: toggle,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final textScale = MediaQuery.textScalerOf(context).scale(1);
                final label = Text(
                  title,
                  softWrap: true,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                );
                final leading = SizedBox.square(
                  dimension: 40,
                  child: Center(
                    child: Icon(icon, color: colors.onSurfaceVariant),
                  ),
                );
                final toggleControl = Switch(
                  value: value,
                  onChanged: onChanged,
                );
                if (constraints.maxWidth < 240 || textScale > 1.3) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          leading,
                          const SizedBox(width: 12),
                          Expanded(child: label),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: toggleControl,
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    leading,
                    const SizedBox(width: 12),
                    Expanded(child: label),
                    const SizedBox(width: 12),
                    toggleControl,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SurfacePanel extends StatelessWidget {
  const _SurfacePanel({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
    );
  }
}

class _ThemeColorOption extends StatelessWidget {
  const _ThemeColorOption({
    super.key,
    required this.colorValue,
    required this.selected,
    required this.onTap,
  });

  final int colorValue;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _ThemeColorPreview(
      colorValue: colorValue,
      selected: selected,
      onTap: onTap,
    );
  }
}

class _ThemeColorPreview extends StatelessWidget {
  const _ThemeColorPreview({
    required this.colorValue,
    required this.selected,
    this.onTap,
  });

  final int colorValue;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(colorValue);
    final child = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected
              ? Theme.of(context).colorScheme.onSurface
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: selected
          ? Icon(
              Icons.check,
              color:
                  ThemeData.estimateBrightnessForColor(color) == Brightness.dark
                  ? Colors.white
                  : Colors.black,
            )
          : null,
    );
    return Semantics(
      label: _formatColorHex(colorValue),
      selected: onTap == null ? null : selected,
      button: onTap != null,
      onTap: onTap,
      child: ExcludeSemantics(
        child: onTap == null
            ? child
            : ExpressiveTap(
                borderRadius: BorderRadius.circular(999),
                onTap: onTap,
                child: SizedBox.square(
                  dimension: 48,
                  child: Center(child: child),
                ),
              ),
      ),
    );
  }
}

class _ActionOptionCard extends StatelessWidget {
  const _ActionOptionCard({
    required this.onTap,
    required this.selected,
    required this.leading,
    required this.title,
    this.subtitle,
  });

  final VoidCallback onTap;
  final bool selected;
  final Widget leading;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: title,
      hint: subtitle,
      button: true,
      selected: selected,
      onTap: onTap,
      child: ExcludeSemantics(
        child: ExpressiveTap(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Material(
            color: selected
                ? colors.primary.withValues(alpha: 0.12)
                : colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  leading,
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    selected ? Icons.check : Icons.chevron_right,
                    color: selected ? colors.primary : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewBanner extends StatelessWidget {
  const _PreviewBanner({
    required this.title,
    required this.value,
    required this.preview,
  });

  final String title;
  final String value;
  final Widget preview;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(value, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(width: 12),
          preview,
        ],
      ),
    );
  }
}

class _SummaryValueRow extends StatelessWidget {
  const _SummaryValueRow({required this.label, required this.value});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: DefaultTextStyle.merge(
              textAlign: TextAlign.end,
              child: value,
            ),
          ),
        ),
      ],
    );
  }
}

class _ColorValueRow extends StatelessWidget {
  const _ColorValueRow({
    required this.title,
    required this.colorValue,
    required this.preview,
  });

  final String title;
  final int colorValue;
  final Widget preview;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(title, style: textTheme.titleSmall)),
        const SizedBox(width: 12),
        Flexible(
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                preview,
                Text(
                  _formatColorHex(colorValue),
                  textAlign: TextAlign.end,
                  style: textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OutlineWidthSummaryRow extends StatelessWidget {
  const _OutlineWidthSummaryRow({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return _SummaryValueRow(
      label: AppLocalizations.of(context).liveCourseOutlineWidth,
      value: Text(_formatOutlineWidthValue(context, width)),
    );
  }
}

class _OutlineColorPreview extends StatelessWidget {
  const _OutlineColorPreview({
    required this.colorValue,
    required this.borderWidth,
  });

  final int colorValue;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final color = Color(colorValue);
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: borderWidth),
      ),
    );
  }
}

class _CompactColorPicker extends StatefulWidget {
  const _CompactColorPicker({
    required this.colorValue,
    required this.onColorChanged,
  });

  final int colorValue;
  final ValueChanged<int> onColorChanged;

  @override
  State<_CompactColorPicker> createState() => _CompactColorPickerState();
}

class _CompactColorPickerState extends State<_CompactColorPicker> {
  static const double _maxPickerWidth = 300;
  static const double _minPickerWidth = 160;

  late final TextEditingController _hexController;
  int? _syncedHexValue;

  @override
  void initState() {
    super.initState();
    _hexController = TextEditingController();
    _syncHexField(widget.colorValue);
  }

  @override
  void didUpdateWidget(covariant _CompactColorPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.colorValue != _syncedHexValue) {
      _syncHexField(widget.colorValue);
    }
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  void _updateColor(Color color) {
    final colorValue = color.toARGB32();
    _syncHexField(colorValue);
    widget.onColorChanged(colorValue);
  }

  void _syncHexField(int colorValue) {
    final text = _formatColorHex(colorValue);
    _syncedHexValue = colorValue;
    if (_hexController.text == text) {
      return;
    }
    _hexController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _handleHexChanged(String value) {
    final hex = value.replaceAll('#', '').trim();
    if (hex.length != 6) {
      return;
    }
    final rgb = int.tryParse(hex, radix: 16);
    if (rgb == null) {
      return;
    }
    final colorValue = 0xFF000000 | rgb;
    _syncedHexValue = colorValue;
    widget.onColorChanged(colorValue);
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(widget.colorValue);
    final hsvColor = HSVColor.fromColor(color);
    final mediaQuery = MediaQuery.of(context);
    final availableWidth =
        mediaQuery.size.width - mediaQuery.viewPadding.horizontal - 128;
    final pickerWidth = availableWidth.clamp(_minPickerWidth, _maxPickerWidth);
    final showHexLabel = pickerWidth >= 220;
    return SizedBox(
      width: pickerWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: pickerWidth,
            height: pickerWidth * 0.45,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: ColorPickerArea(
                hsvColor,
                (updatedHsvColor) => _updateColor(updatedHsvColor.toColor()),
                PaletteType.hsvWithHue,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: pickerWidth,
            height: 40,
            child: ColorPickerSlider(
              TrackType.hue,
              hsvColor,
              (updatedHsvColor) => _updateColor(updatedHsvColor.toColor()),
              displayThumbColor: true,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                if (showHexLabel) ...[
                  Text('Hex', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: TextField(
                    key: const ValueKey('compact-color-picker-hex-field'),
                    controller: _hexController,
                    maxLength: 7,
                    decoration: const InputDecoration(
                      isDense: true,
                      counterText: '',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                    ),
                    onChanged: _handleHexChanged,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
