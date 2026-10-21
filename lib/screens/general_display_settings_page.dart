import '../utils/mobile_toolbar_layout.dart';
import '../widgets/workbench_chrome_metrics.dart';

import '../widgets/workspace_route_lifecycle.dart';

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/timetable_models.dart';
import '../controllers/general_commands.dart';
import '../controllers/general_view_state.dart';
import '../controllers/settings_view_state.dart';
import '../controllers/workspace_view_state.dart';
import '../widgets/settings_list.dart';
import '../widgets/settings_page_header.dart';
import '../widgets/workspace_display_controls.dart';
import '../widgets/ui_command.dart';

class GeneralDisplaySettingsPage extends StatefulWidget {
  const GeneralDisplaySettingsPage({super.key});

  @override
  State<GeneralDisplaySettingsPage> createState() =>
      _GeneralDisplaySettingsPageState();
}

class _GeneralDisplaySettingsPageState extends State<GeneralDisplaySettingsPage>
    with
        UiCommandRunner<GeneralDisplaySettingsPage>,
        WorkspaceRouteLifecycle<GeneralDisplaySettingsPage> {
  @override
  AppMode get routeWorkspace => AppMode.general;

  void _updateSetting(String debugLabel, Future<void> Function() command) {
    unawaited(runUiCommand(debugLabel: debugLabel, command: command));
  }

  @override
  Widget build(BuildContext context) {
    if (!routeWorkspaceEnabled) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return Consumer3<GeneralViewState, SettingsViewState, WorkspaceViewState>(
      builder: (context, general, settings, workspace, child) {
        final display = general.data;
        final commands = context.read<GeneralCommands>();
        final workspaceFallback =
            workspace.enabledWorkspaces.length > 1 &&
            settings.hideHomeWorkspaceNavigation;
        return SettingsPageScaffold(
          title: l10n.generalDisplaySettings,
          statusIndicator: UiCommandBusyIndicator(
            busy: uiCommandBusy,
            showDelay: const Duration(milliseconds: 180),
          ),
          bodyBuilder: (_, headerSliver) => Column(
            children: [
              Expanded(
                child: SafeArea(
                  top: false,
                  child: SettingsInteractionBlocker(
                    blocked: uiCommandBusy,
                    child: ResponsiveSettingsBody(
                      headerSliver: headerSliver,
                      connectedSections: true,
                      scrollViewKey: const ValueKey(
                        'general-display-settings-list',
                      ),
                      // Keep startup, toolbar, schedule display, and toolbar
                      // navigation together; time-grid, popup, and quick
                      // actions form the adjacent work column on wide views.
                      firstColumnSectionIndices: const {0, 1, 2, 5},
                      children: [
                        SettingsSectionHeader(
                          title: l10n.generalDefaultViewSection,
                        ),
                        generalDefaultViewSetting(
                          display,
                          commands,
                          l10n,
                          _updateSetting,
                          enabled: !uiCommandBusy,
                        ),
                        const SizedBox(height: 12),
                        SettingsChoiceTile<String>(
                          enabled:
                              !WorkbenchChromeMetrics.compactTouch(context) ||
                              !uiCommandBusy,
                          key: const ValueKey('general-view-switch-behavior'),
                          value: display.viewSwitchBehavior,
                          title: l10n.generalViewSwitchBehavior,
                          icon: Icons.swap_horiz_outlined,
                          entries: [
                            DropdownMenuEntry<String>(
                              value: generalViewSwitchBehaviorCycle,
                              label: l10n.generalViewSwitchCycle,
                            ),
                            DropdownMenuEntry<String>(
                              value: generalViewSwitchBehaviorMenu,
                              label: l10n.generalViewSwitchMenu,
                            ),
                          ],
                          onSelected: (value) {
                            if (value != null) {
                              _updateSetting(
                                'Update general view switch behavior',
                                () => commands.updateDisplaySettings(
                                  viewSwitchBehavior: value,
                                ),
                              );
                            }
                          },
                        ),
                        SettingsSectionHeader(
                          title: l10n.generalToolbarSection,
                        ),
                        SettingsChoiceTile<String>(
                          enabled:
                              !WorkbenchChromeMetrics.compactTouch(context) ||
                              !uiCommandBusy,
                          key: const ValueKey('general-toolbar-width-policy'),
                          value: display.toolbarWidthPolicy,
                          title: l10n.generalToolbarWidthPolicy,
                          icon: Icons.space_bar_outlined,
                          entries: [
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
                                () => commands.updateDisplaySettings(
                                  toolbarWidthPolicy: value,
                                ),
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        SettingsChoiceTile<String>(
                          enabled:
                              !WorkbenchChromeMetrics.compactTouch(context) ||
                              !uiCommandBusy,
                          key: const ValueKey('general-date-label-format'),
                          value: display.dateLabelFormat,
                          title: l10n.generalDateLabelFormat,
                          subtitle: l10n.generalDateLabelFormatDescription,
                          icon: Icons.text_format_outlined,
                          entries: [
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
                                () => commands.updateDisplaySettings(
                                  dateLabelFormat: value,
                                ),
                              );
                            }
                          },
                        ),

                        SettingsSectionHeader(
                          title: l10n.generalScheduleDisplaySection,
                        ),
                        ...generalCalendarDisplaySettings(
                          display,
                          commands,
                          l10n,
                          _updateSetting,
                          enabled: !uiCommandBusy,
                        ),
                        SettingsSectionHeader(
                          title: l10n.generalTimeGridSection,
                        ),
                        SettingsSliderTile(
                          icon: Icons.access_time,
                          title: l10n.startHour,
                          value: display.dayStartHour,
                          min: 0,
                          max: display.dayEndHour - 1,
                          labelBuilder: _hourLabel,
                          onChangeEnd: (value) => _updateSetting(
                            'Update general day start hour',
                            () => commands.updateDisplaySettings(
                              dayStartHour: value,
                            ),
                          ),
                        ),
                        SettingsSliderTile(
                          icon: Icons.access_time,
                          title: l10n.endHour,
                          value: display.dayEndHour,
                          min: display.dayStartHour + 1,
                          max: 24,
                          labelBuilder: _hourLabel,
                          onChangeEnd: (value) => _updateSetting(
                            'Update general day end hour',
                            () => commands.updateDisplaySettings(
                              dayEndHour: value,
                            ),
                          ),
                        ),
                        SettingsChoiceTile<int>(
                          enabled:
                              !WorkbenchChromeMetrics.compactTouch(context) ||
                              !uiCommandBusy,
                          key: const ValueKey('general-time-grid'),
                          value: display.timeGridMinutes,
                          title: l10n.timeGridDensity,
                          icon: Icons.grid_4x4_outlined,
                          entries: [
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
                                () => commands.updateDisplaySettings(
                                  timeGridMinutes: value,
                                ),
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 8),
                        SettingsSliderTile(
                          key: const ValueKey('general-time-grid-hour-height'),
                          icon: Icons.height,
                          title: l10n.timeGridHourHeight,
                          subtitle: l10n.timeGridHourHeightHint,
                          value: display.timeGridHourHeight,
                          min: generalTimeGridHourHeightMin,
                          max: generalTimeGridHourHeightMax,
                          step: generalTimeGridHourHeightStep,
                          labelBuilder: l10n.timeGridHourHeightValue,
                          onChangeEnd: (value) => _updateSetting(
                            'Update general time grid hour height',
                            () => commands.updateDisplaySettings(
                              timeGridHourHeight: value,
                            ),
                          ),
                        ),
                        SettingsSectionHeader(title: l10n.generalPopupSection),
                        SettingsSwitchTile(
                          icon: Icons.open_in_full_outlined,
                          title: l10n.closePopupOnOutsideTap,
                          value: display.closeEventPopupOnOutsideTap,
                          onChanged: (value) => _updateSetting(
                            'Update general popup dismissal',
                            () => commands.updateDisplaySettings(
                              closeEventPopupOnOutsideTap: value,
                            ),
                          ),
                        ),
                        SettingsSectionHeader(
                          title: l10n.toolbarNavigationSection,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Text(l10n.toolbarNavigationEssentialHint),
                        ),
                        SettingsChoiceTile<Object>(
                          enabled:
                              !WorkbenchChromeMetrics.compactTouch(context) ||
                              !uiCommandBusy,
                          key: const ValueKey(
                            'general-toolbar-hidden-behavior',
                          ),
                          value: display.toolbarHiddenItemsBehavior,
                          title: l10n.toolbarNavigationHiddenBehavior,
                          icon: Icons.more_horiz_outlined,
                          entries: <DropdownMenuEntry<Object>>[
                            DropdownMenuEntry<Object>(
                              value: toolbarHiddenItemsBehaviorRemove,
                              label: l10n.toolbarNavigationRemove,
                            ),
                            DropdownMenuEntry<Object>(
                              value: toolbarHiddenItemsBehaviorMore,
                              label: l10n.toolbarNavigationMore,
                            ),
                          ],
                          onSelected: (value) {
                            if (value is String) {
                              _updateSetting(
                                'Update general toolbar hidden items behavior',
                                () => commands.updateToolbarHiddenItemsBehavior(
                                  value,
                                ),
                              );
                            }
                          },
                        ),
                        SettingsToolbarNavigationEditor(
                          key: const ValueKey(
                            'general-toolbar-navigation-editor',
                          ),
                          items: _generalToolbarItems(
                            l10n,
                            display,
                            workspaceFallback: workspaceFallback,
                          ),
                          busy: uiCommandBusy,
                          reorderLabel: l10n.toolbarNavigationReorder,
                          visibilityLabel: l10n.toolbarNavigationVisibility,
                          onReorder: (order) => _updateSetting(
                            'Update general toolbar navigation order',
                            () => commands.updateToolbarNavigationOrder(order),
                          ),
                          onVisibilityChanged: (id, visible) => _updateSetting(
                            'Update general toolbar navigation visibility',
                            () => commands.updateToolbarNavigationVisibility(
                              id,
                              visible,
                            ),
                          ),
                        ),
                        SettingsSectionHeader(title: l10n.quickActionsSection),
                        SettingsSwitchTile(
                          key: const ValueKey('show-add-event-fab-setting'),
                          icon: Icons.add_circle_outline,
                          title: l10n.showAddEventFab,
                          subtitle: l10n.showAddEventFabHint,
                          value: display.showAddEventFab,
                          onChanged: (value) => _updateSetting(
                            'Update add event button visibility',
                            () => commands.updateDisplaySettings(
                              showAddEventFab: value,
                            ),
                          ),
                        ),
                        SettingsSwitchTile(
                          key: const ValueKey(
                            'enable-long-press-add-event-setting',
                          ),
                          icon: Icons.touch_app_outlined,
                          title: l10n.enableLongPressAddEvent,
                          subtitle: l10n.enableLongPressAddEventHint,
                          value: display.enableLongPressAddEvent,
                          onChanged: (value) => _updateSetting(
                            'Update long-press event creation',
                            () => commands.updateDisplaySettings(
                              enableLongPressAddEvent: value,
                            ),
                          ),
                        ),
                      ],
                    ),
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

List<SettingsToolbarNavigationItem> _generalToolbarItems(
  AppLocalizations l10n,
  GeneralScheduleData display, {
  required bool workspaceFallback,
}) {
  final labels = <String, String>{
    'category': l10n.toolbarNavigationCategory,
    'date': l10n.toolbarNavigationDate,
    'view': l10n.toolbarNavigationView,
    'workspace': l10n.settingsSectionWorkspace,
    'settings': l10n.settings,
    'more': l10n.more,
  };
  final icons = <String, IconData>{
    'category': Icons.label_outline,
    'date': Icons.calendar_today_outlined,
    'view': Icons.view_agenda_outlined,
    'workspace': Icons.swap_horiz,
    'settings': Icons.settings_outlined,
    'more': Icons.more_horiz_outlined,
  };
  final hidden = display.hiddenToolbarNavigationIds.toSet();
  final order = [
    ...display.toolbarNavigationOrder,
    if (!display.toolbarNavigationOrder.contains('more')) 'more',
  ];
  final placement = MobileToolbarLayout.resolve(
    order: display.toolbarNavigationOrder,
    hiddenIds: display.hiddenToolbarNavigationIds,
    hiddenBehavior: display.toolbarHiddenItemsBehavior,
    defaultOrder: generalToolbarNavigationDefaultOrder,
    availableIds: {'settings', if (workspaceFallback) 'workspace'},
    hasFixedMenuItems: true,
  );
  return [
    for (final id in order)
      if (labels.containsKey(id))
        SettingsToolbarNavigationItem(
          id: id,
          label: labels[id]!,
          icon: icons[id]!,
          visible:
              (id == 'more' && placement.moreRequired) || !hidden.contains(id),
          canHide: id != 'more' || !placement.moreRequired,
        ),
  ];
}
