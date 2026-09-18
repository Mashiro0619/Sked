import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../models/timetable_models.dart';
import '../providers/timetable_provider.dart';
import 'settings_list.dart';

typedef SettingsUpdate = void Function(
  String label,
  Future<void> Function() command,
);

Widget studentWeekWidthSetting(
  TimetableProvider provider,
  AppLocalizations l,
  SettingsUpdate update, {
  bool enabled = true,
}) => SettingsSwitchTile(
  key: const ValueKey('student-fit-week-columns-setting'),
  icon: Icons.view_column_outlined,
  value: provider.fitWeekColumnsToWidth,
  title: l.fitWeekColumnsToWidth,
  onChanged: (value) {
    if (!enabled) return;
    update(
      'Update week column width mode',
      () => provider.updateFitWeekColumnsToWidth(value),
    );
  },
);

Widget studentGridLinesSetting(
  TimetableProvider provider,
  AppLocalizations l,
  SettingsUpdate update, {
  bool enabled = true,
}) => SettingsSwitchTile(
  key: const ValueKey('student-grid-lines-setting'),
  icon: Icons.grid_4x4_outlined,
  value: provider.showTimetableGridLines,
  title: l.showTimetableGridLines,
  onChanged: (value) {
    if (!enabled) return;
    update(
      'Update timetable grid line visibility',
      () => provider.updateShowTimetableGridLines(value),
    );
  },
);

Widget generalDefaultViewSetting(
  TimetableProvider provider,
  AppLocalizations l,
  SettingsUpdate update, {
  bool enabled = true,
}) => SettingsChoiceTile<String>(
  key: const ValueKey('general-default-view'),
  title: l.defaultView,
  icon: Icons.space_dashboard_outlined,
  value: provider.generalDefaultView,
  enabled: enabled,
  workspace: AppMode.general,
  entries: [
    DropdownMenuEntry(value: generalViewWeek, label: l.viewWeek),
    DropdownMenuEntry(value: generalViewDay, label: l.viewDay),
    DropdownMenuEntry(value: generalViewList, label: l.viewList),
    DropdownMenuEntry(value: generalViewMonth, label: l.viewMonth),
  ],
  onSelected: (value) {
    if (value != null) {
      update(
        'Update general default view',
        () => provider.updateGeneralDisplaySettings(defaultView: value),
      );
    }
  },
);

List<Widget> generalCalendarDisplaySettings(
  TimetableProvider provider,
  AppLocalizations l,
  SettingsUpdate update, {
  bool enabled = true,
}) => [
  SettingsSwitchTile(
    key: const ValueKey('general-fit-week-columns-setting'),
    icon: Icons.view_column_outlined,
    title: l.generalFitWeekColumnsToWidth,
    value: provider.generalFitWeekColumnsToWidth,
    onChanged: (value) {
      if (!enabled) return;
      update(
        'Update general week column width mode',
        () =>
            provider.updateGeneralDisplaySettings(fitWeekColumnsToWidth: value),
      );
    },
  ),
  SettingsSwitchTile(
    key: const ValueKey('general-show-weekends-setting'),
    icon: Icons.weekend_outlined,
    title: l.showWeekends,
    value: provider.generalShowWeekends,
    onChanged: (value) {
      if (!enabled) return;
      update(
        'Update weekend visibility',
        () => provider.updateGeneralDisplaySettings(showWeekends: value),
      );
    },
  ),
  if (l.localeName.startsWith('zh'))
    SettingsSwitchTile(
      key: const ValueKey('general-show-lunar-setting'),
      icon: Icons.brightness_2_outlined,
      title: l.showLunarCalendar,
      value: provider.generalShowLunarCalendar,
      onChanged: (value) {
        if (!enabled) return;
        update(
          'Update lunar calendar visibility',
          () => provider.updateGeneralDisplaySettings(showLunarCalendar: value),
        );
      },
    ),
  SettingsChoiceTile<bool>(
    key: const ValueKey('general-custom-column-width-mode'),
    title: l.generalCustomColumnWidth,
    icon: Icons.width_normal_outlined,
    value: provider.generalCustomDayMinWidth != null,
    enabled: enabled,
    workspace: AppMode.general,
    entries: [
      DropdownMenuEntry(value: false, label: l.generalCustomColumnWidthAuto),
      DropdownMenuEntry(value: true, label: l.generalCustomColumnWidthManual),
    ],
    onSelected: (manual) {
      if (manual != null) {
        update(
          'Update custom calendar column width mode',
          () => provider.updateGeneralCustomDayMinWidth(
            manual ? generalCustomDayMinWidthDefault : null,
          ),
        );
      }
    },
  ),
  if (provider.generalCustomDayMinWidth case final int width)
    SettingsSliderTile(
      key: const ValueKey('general-custom-column-width-slider'),
      icon: Icons.view_column_outlined,
      title: l.generalCustomColumnWidthMinimum,
      subtitle: l.generalCustomColumnWidthHint,
      value: width,
      min: generalCustomDayMinWidthMin,
      max: generalCustomDayMinWidthMax,
      step: generalCustomDayMinWidthStep,
      enabled: enabled,
      labelBuilder: (value) => '$value dp',
      onChangeEnd: (value) => update(
        'Update custom calendar column width',
        () => provider.updateGeneralCustomDayMinWidth(value),
      ),
    ),
];
