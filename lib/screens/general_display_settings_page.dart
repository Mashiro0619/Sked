import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../l10n/app_locale.dart' as app_locale;
import '../l10n/app_localizations.dart';
import '../models/timetable_models.dart';
import '../providers/timetable_provider.dart';
import '../widgets/sked_dropdown_menu.dart';
import '../widgets/settings_list.dart';
import '../widgets/ui_command.dart';

class GeneralDisplaySettingsPage extends StatefulWidget {
  const GeneralDisplaySettingsPage({super.key});

  @override
  State<GeneralDisplaySettingsPage> createState() =>
      _GeneralDisplaySettingsPageState();
}

class _GeneralDisplaySettingsPageState extends State<GeneralDisplaySettingsPage>
    with UiCommandRunner<GeneralDisplaySettingsPage> {
  void _updateSetting(String debugLabel, Future<void> Function() command) {
    unawaited(runUiCommand(debugLabel: debugLabel, command: command));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Consumer<TimetableProvider>(
      builder: (context, provider, child) {
        final localeCode = app_locale.normalizeLocaleCode(provider.localeCode);
        return Scaffold(
          appBar: AppBar(title: Text(l10n.generalDisplaySettings)),
          body: Column(
            children: [
              UiCommandBusyIndicator(busy: uiCommandBusy),
              Expanded(
                child: SafeArea(
                  top: false,
                  child: ResponsiveSettingsBody(
                    firstColumnSectionIndices: const {0, 3},
                    children: [
                      SettingsSectionHeader(
                        title: l10n.generalDefaultViewSection,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SkedDropdownMenu<String>(
                          key: const ValueKey('general-default-view'),
                          initialSelection: provider.generalDefaultView,
                          label: Text(l10n.defaultView),
                          leadingIcon: const Icon(
                            Icons.space_dashboard_outlined,
                          ),
                          expandedInsets: EdgeInsets.zero,
                          enabled: !uiCommandBusy,
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
                              _updateSetting(
                                'Update general default view',
                                () => provider.updateGeneralDisplaySettings(
                                  defaultView: value,
                                ),
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SkedDropdownMenu<String>(
                          key: const ValueKey('general-view-switch-behavior'),
                          initialSelection: provider.generalViewSwitchBehavior,
                          label: Text(l10n.generalViewSwitchBehavior),
                          leadingIcon: const Icon(Icons.swap_horiz_outlined),
                          expandedInsets: EdgeInsets.zero,
                          enabled: !uiCommandBusy,
                          dropdownMenuEntries: [
                            DropdownMenuEntry(
                              value: generalViewSwitchBehaviorCycle,
                              label: l10n.generalViewSwitchCycle,
                            ),
                            DropdownMenuEntry(
                              value: generalViewSwitchBehaviorMenu,
                              label: l10n.generalViewSwitchMenu,
                            ),
                          ],
                          onSelected: (value) {
                            if (value != null) {
                              _updateSetting(
                                'Update general view switch behavior',
                                () => provider.updateGeneralDisplaySettings(
                                  viewSwitchBehavior: value,
                                ),
                              );
                            }
                          },
                        ),
                      ),
                      SettingsSectionHeader(title: l10n.generalToolbarSection),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SkedDropdownMenu<String>(
                          key: const ValueKey('general-toolbar-width-policy'),
                          initialSelection: provider.generalToolbarWidthPolicy,
                          label: Text(l10n.generalToolbarWidthPolicy),
                          leadingIcon: const Icon(Icons.space_bar_outlined),
                          expandedInsets: EdgeInsets.zero,
                          enabled: !uiCommandBusy,
                          dropdownMenuEntries: [
                            DropdownMenuEntry(
                              value: generalToolbarWidthPolicyContent,
                              label: l10n.generalToolbarWidthContent,
                            ),
                            DropdownMenuEntry(
                              value: generalToolbarWidthPolicyBalanced,
                              label: l10n.generalToolbarWidthBalanced,
                            ),
                            DropdownMenuEntry(
                              value: generalToolbarWidthPolicyCalendarPriority,
                              label: l10n.generalToolbarWidthCalendarPriority,
                            ),
                            DropdownMenuEntry(
                              value: generalToolbarWidthPolicyDatePriority,
                              label: l10n.generalToolbarWidthDatePriority,
                            ),
                          ],
                          onSelected: (value) {
                            if (value != null) {
                              _updateSetting(
                                'Update general toolbar width policy',
                                () => provider.updateGeneralDisplaySettings(
                                  toolbarWidthPolicy: value,
                                ),
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SkedDropdownMenu<String>(
                          key: const ValueKey('general-date-label-format'),
                          initialSelection: provider.generalDateLabelFormat,
                          label: Text(l10n.generalDateLabelFormat),
                          leadingIcon: const Icon(Icons.text_format_outlined),
                          expandedInsets: EdgeInsets.zero,
                          enabled: !uiCommandBusy,
                          dropdownMenuEntries: [
                            DropdownMenuEntry(
                              value: generalDateLabelFormatLocalized,
                              label: l10n.generalDateLabelFormatLocalized,
                            ),
                            DropdownMenuEntry(
                              value: generalDateLabelFormatSlash,
                              label: l10n.generalDateLabelFormatSlash,
                            ),
                            DropdownMenuEntry(
                              value: generalDateLabelFormatIso,
                              label: l10n.generalDateLabelFormatIso,
                            ),
                          ],
                          onSelected: (value) {
                            if (value != null) {
                              _updateSetting(
                                'Update general date label format',
                                () => provider.updateGeneralDisplaySettings(
                                  dateLabelFormat: value,
                                ),
                              );
                            }
                          },
                        ),
                      ),
                      SettingsSectionHeader(
                        title: l10n.generalScheduleDisplaySection,
                      ),
                      SettingsSwitchTile(
                        icon: Icons.weekend_outlined,
                        title: l10n.showWeekends,
                        value: provider.generalShowWeekends,
                        onChanged: uiCommandBusy
                            ? null
                            : (value) => _updateSetting(
                                'Update weekend visibility',
                                () => provider.updateGeneralDisplaySettings(
                                  showWeekends: value,
                                ),
                              ),
                      ),
                      if (localeCode == 'zh' || localeCode == 'zh-Hant')
                        SettingsSwitchTile(
                          icon: Icons.brightness_2_outlined,
                          title: l10n.showLunarCalendar,
                          value: provider.generalShowLunarCalendar,
                          onChanged: uiCommandBusy
                              ? null
                              : (value) => _updateSetting(
                                  'Update lunar calendar visibility',
                                  () => provider.updateGeneralDisplaySettings(
                                    showLunarCalendar: value,
                                  ),
                                ),
                        ),
                      SettingsSectionHeader(title: l10n.generalTimeGridSection),
                      SettingsSliderTile(
                        icon: Icons.access_time,
                        title: l10n.startHour,
                        value: provider.generalDayStartHour,
                        min: 0,
                        max: provider.generalDayEndHour - 1,
                        labelBuilder: _hourLabel,
                        enabled: !uiCommandBusy,
                        onChangeEnd: (value) => _updateSetting(
                          'Update general day start hour',
                          () => provider.updateGeneralDisplaySettings(
                            dayStartHour: value,
                          ),
                        ),
                      ),
                      SettingsSliderTile(
                        icon: Icons.access_time,
                        title: l10n.endHour,
                        value: provider.generalDayEndHour,
                        min: provider.generalDayStartHour + 1,
                        max: 24,
                        labelBuilder: _hourLabel,
                        enabled: !uiCommandBusy,
                        onChangeEnd: (value) => _updateSetting(
                          'Update general day end hour',
                          () => provider.updateGeneralDisplaySettings(
                            dayEndHour: value,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SkedDropdownMenu<int>(
                          key: const ValueKey('general-time-grid'),
                          initialSelection: provider.generalTimeGridMinutes,
                          label: Text(l10n.timeGridDensity),
                          leadingIcon: const Icon(Icons.grid_4x4_outlined),
                          expandedInsets: EdgeInsets.zero,
                          enabled: !uiCommandBusy,
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
                              _updateSetting(
                                'Update general time grid density',
                                () => provider.updateGeneralDisplaySettings(
                                  timeGridMinutes: value,
                                ),
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
                        onChanged: uiCommandBusy
                            ? null
                            : (value) => _updateSetting(
                                'Update general popup dismissal',
                                () => provider.updateGeneralDisplaySettings(
                                  closeEventPopupOnOutsideTap: value,
                                ),
                              ),
                      ),
                      SettingsSectionHeader(title: l10n.quickActionsSection),
                      SettingsSwitchTile(
                        key: const ValueKey('show-add-event-fab-setting'),
                        icon: Icons.add_circle_outline,
                        title: l10n.showAddEventFab,
                        subtitle: l10n.showAddEventFabHint,
                        value: provider.showAddEventFab,
                        onChanged: uiCommandBusy
                            ? null
                            : (value) => _updateSetting(
                                'Update add event button visibility',
                                () => provider.updateGeneralDisplaySettings(
                                  showAddEventFab: value,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

String _hourLabel(int hour) => '${hour.toString().padLeft(2, '0')}:00';
