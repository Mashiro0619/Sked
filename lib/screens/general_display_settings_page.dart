import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_locale.dart' as app_locale;
import '../l10n/app_localizations.dart';
import '../models/timetable_models.dart';
import '../providers/timetable_provider.dart';
import '../widgets/settings_list.dart';

class GeneralDisplaySettingsPage extends StatelessWidget {
  const GeneralDisplaySettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Consumer<TimetableProvider>(
      builder: (context, provider, child) {
        final localeCode = app_locale.normalizeLocaleCode(provider.localeCode);
        return Scaffold(
          appBar: AppBar(title: Text(l10n.generalDisplaySettings)),
          body: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              SettingsSectionHeader(title: l10n.generalDefaultViewSection),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DropdownMenu<String>(
                  initialSelection: provider.generalDefaultView,
                  label: Text(l10n.defaultView),
                  leadingIcon: const Icon(Icons.space_dashboard_outlined),
                  expandedInsets: EdgeInsets.zero,
                  dropdownMenuEntries: [
                    DropdownMenuEntry(
                      value: generalViewWeek,
                      label: l10n.viewWeek,
                    ),
                    DropdownMenuEntry(
                      value: generalViewDay,
                      label: l10n.viewDay,
                    ),
                    DropdownMenuEntry(
                      value: generalViewList,
                      label: l10n.viewList,
                    ),
                    DropdownMenuEntry(
                      value: generalViewMonth,
                      label: l10n.viewMonth,
                    ),
                  ],
                  onSelected: (value) {
                    if (value != null) {
                      provider.updateGeneralDisplaySettings(defaultView: value);
                    }
                  },
                ),
              ),
              SettingsSectionHeader(title: l10n.generalScheduleDisplaySection),
              SettingsSwitchTile(
                icon: Icons.weekend_outlined,
                title: l10n.showWeekends,
                value: provider.generalShowWeekends,
                onChanged: (value) =>
                    provider.updateGeneralDisplaySettings(showWeekends: value),
              ),
              if (localeCode == 'zh' || localeCode == 'zh-Hant')
                SettingsSwitchTile(
                  icon: Icons.brightness_2_outlined,
                  title: l10n.showLunarCalendar,
                  value: provider.generalShowLunarCalendar,
                  onChanged: (value) => provider.updateGeneralDisplaySettings(
                    showLunarCalendar: value,
                  ),
                ),
              SettingsSectionHeader(title: l10n.generalTimeGridSection),
              SettingsSliderTile(
                icon: Icons.access_time,
                title: l10n.startHour,
                value: provider.generalDayStartHour,
                min: 0,
                max: provider.generalDayEndHour - 1,
                label:
                    '${provider.generalDayStartHour.toString().padLeft(2, '0')}:00',
                onChanged: (value) =>
                    provider.updateGeneralDisplaySettings(dayStartHour: value),
              ),
              SettingsSliderTile(
                icon: Icons.access_time,
                title: l10n.endHour,
                value: provider.generalDayEndHour,
                min: provider.generalDayStartHour + 1,
                max: 24,
                label:
                    '${provider.generalDayEndHour.toString().padLeft(2, '0')}:00',
                onChanged: (value) =>
                    provider.updateGeneralDisplaySettings(dayEndHour: value),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DropdownMenu<int>(
                  initialSelection: provider.generalTimeGridMinutes,
                  label: Text(l10n.timeGridDensity),
                  leadingIcon: const Icon(Icons.grid_4x4_outlined),
                  expandedInsets: EdgeInsets.zero,
                  dropdownMenuEntries: [
                    DropdownMenuEntry(
                      value: 15,
                      label: l10n.timeGridMinutes(15),
                    ),
                    DropdownMenuEntry(
                      value: 30,
                      label: l10n.timeGridMinutes(30),
                    ),
                    DropdownMenuEntry(
                      value: 60,
                      label: l10n.timeGridMinutes(60),
                    ),
                  ],
                  onSelected: (value) {
                    if (value != null) {
                      provider.updateGeneralDisplaySettings(
                        timeGridMinutes: value,
                      );
                    }
                  },
                ),
              ),
              SettingsSectionHeader(title: l10n.generalPopupSection),
              SettingsSwitchTile(
                icon: Icons.open_in_full_outlined,
                title: l10n.closePopupOnOutsideTap,
                value: provider.closeGeneralEventPopupOnOutsideTap,
                onChanged: (value) => provider.updateGeneralDisplaySettings(
                  closeEventPopupOnOutsideTap: value,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
