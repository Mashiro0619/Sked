import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../models/timetable_models.dart';
import '../controllers/general_commands.dart';
import '../controllers/settings_commands.dart';
import '../controllers/settings_view_state.dart';
import 'settings_list.dart';

typedef SettingsUpdate = void Function(
  String label,
  Future<void> Function() command,
);

Widget studentWeekWidthSetting(
  SettingsViewState settings,
  SettingsCommands commands,
  AppLocalizations l,
  SettingsUpdate update, {
  bool enabled = true,
}) => SettingsSwitchTile(
  key: const ValueKey('student-fit-week-columns-setting'),
  icon: Icons.view_column_outlined,
  value: settings.fitWeekColumnsToWidth,
  title: l.fitWeekColumnsToWidth,
  onChanged: (value) {
    if (!enabled) return;
    update(
      'Update week column width mode',
      () => commands.updateFitWeekColumnsToWidth(value),
    );
  },
);

Widget studentGridLinesSetting(
  SettingsViewState settings,
  SettingsCommands commands,
  AppLocalizations l,
  SettingsUpdate update, {
  bool enabled = true,
}) => SettingsSwitchTile(
  key: const ValueKey('student-grid-lines-setting'),
  icon: Icons.grid_4x4_outlined,
  value: settings.showTimetableGridLines,
  title: l.showTimetableGridLines,
  onChanged: (value) {
    if (!enabled) return;
    update(
      'Update timetable grid line visibility',
      () => commands.updateShowTimetableGridLines(value),
    );
  },
);

Widget generalDefaultViewSetting(
  GeneralScheduleData display,
  GeneralCommands commands,
  AppLocalizations l,
  SettingsUpdate update, {
  bool enabled = true,
}) => SettingsChoiceTile<String>(
  key: const ValueKey('general-default-view'),
  title: l.defaultView,
  icon: Icons.space_dashboard_outlined,
  value: display.defaultView,
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
        () => commands.updateDisplaySettings(defaultView: value),
      );
    }
  },
);

List<Widget> generalCalendarDisplaySettings(
  GeneralScheduleData display,
  GeneralCommands commands,
  AppLocalizations l,
  SettingsUpdate update, {
  bool enabled = true,
}) => [
  SettingsSwitchTile(
    key: const ValueKey('general-fit-week-columns-setting'),
    icon: Icons.view_column_outlined,
    title: l.generalFitWeekColumnsToWidth,
    value: display.fitWeekColumnsToWidth,
    onChanged: (value) {
      if (!enabled) return;
      update(
        'Update general week column width mode',
        () => commands.updateDisplaySettings(fitWeekColumnsToWidth: value),
      );
    },
  ),
  SettingsSwitchTile(
    key: const ValueKey('general-show-weekends-setting'),
    icon: Icons.weekend_outlined,
    title: l.showWeekends,
    value: display.showWeekends,
    onChanged: (value) {
      if (!enabled) return;
      update(
        'Update weekend visibility',
        () => commands.updateDisplaySettings(showWeekends: value),
      );
    },
  ),
  if (l.localeName.startsWith('zh'))
    SettingsSwitchTile(
      key: const ValueKey('general-show-lunar-setting'),
      icon: Icons.brightness_2_outlined,
      title: l.showLunarCalendar,
      value: display.showLunarCalendar,
      onChanged: (value) {
        if (!enabled) return;
        update(
          'Update lunar calendar visibility',
          () => commands.updateDisplaySettings(showLunarCalendar: value),
        );
      },
    ),
  SettingsChoiceTile<bool>(
    key: const ValueKey('general-custom-column-width-mode'),
    title: l.generalCustomColumnWidth,
    icon: Icons.width_normal_outlined,
    value: display.customDayMinWidth != null,
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
          () => commands.updateCustomDayMinWidth(
            manual ? generalCustomDayMinWidthDefault : null,
          ),
        );
      }
    },
  ),
  if (display.customDayMinWidth case final int width)
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
        () => commands.updateCustomDayMinWidth(value),
      ),
    ),
];
