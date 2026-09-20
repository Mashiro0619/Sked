import '../widgets/workbench_chrome_metrics.dart';

import '../widgets/desktop_window_host.dart';
import '../widgets/adaptive_navigation_scope.dart';
import '../widgets/workspace_route_lifecycle.dart';
import '../models/app_mode.dart';

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../utils/constants.dart';
import '../providers/timetable_provider.dart';
import '../widgets/settings_list.dart';
import '../widgets/workspace_display_controls.dart';
import '../widgets/ui_command.dart';

class TimetableDisplaySettingsPage extends StatefulWidget {
  const TimetableDisplaySettingsPage({super.key});

  @override
  State<TimetableDisplaySettingsPage> createState() =>
      _TimetableDisplaySettingsPageState();
}

class _TimetableDisplaySettingsPageState
    extends State<TimetableDisplaySettingsPage>
    with
        UiCommandRunner<TimetableDisplaySettingsPage>,
        WorkspaceRouteLifecycle<TimetableDisplaySettingsPage> {
  @override
  AppMode get routeWorkspace => AppMode.student;

  void _updateSetting(String debugLabel, Future<void> Function() command) {
    unawaited(runUiCommand(debugLabel: debugLabel, command: command));
  }

  @override
  Widget build(BuildContext context) {
    if (!routeWorkspaceEnabled) return const SizedBox.shrink();
    return Consumer<TimetableProvider>(
      builder: (context, provider, child) {
        final l10n = AppLocalizations.of(context);
        return Scaffold(
          appBar: WorkbenchAppBar(
            automaticallyImplyLeading: !AdaptiveNavigationScope.isWide(context),
            title: Semantics(
              header: true,
              label: l10n.timetableDisplaySettings,
              child: SingleChildScrollView(
                key: const ValueKey('timetable-display-settings-title-scroll'),
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                child: ExcludeSemantics(
                  child: Text(
                    l10n.timetableDisplaySettings,
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
              ),
            ),
          ),
          body: Column(
            children: [
              UiCommandBusyIndicator(
                busy: uiCommandBusy,
                showDelay: const Duration(milliseconds: 180),
              ),
              Expanded(
                child: SafeArea(
                  top: false,
                  child: SettingsInteractionBlocker(
                    blocked: uiCommandBusy,
                    child: ResponsiveSettingsBody(
                      connectedSections: true,
                      scrollViewKey: const ValueKey(
                        'timetable-display-settings-list',
                      ),
                      firstColumnSectionIndices: const {0, 1, 4},
                      children: [
                        SettingsSectionHeader(title: l10n.generalPopupSection),
                        SettingsSwitchTile(
                          icon: Icons.open_in_full_outlined,
                          value: provider.closeCoursePopupOnOutsideTap,
                          title: l10n.coursePopupDismissSetting,
                          subtitle: l10n.coursePopupDismissSettingHint,
                          onChanged: (value) => _updateSetting(
                            'Update course popup dismissal',
                            () => provider.updateCloseCoursePopupOnOutsideTap(
                              value,
                            ),
                          ),
                        ),
                        SettingsSectionHeader(
                          title: l10n.generalScheduleDisplaySection,
                        ),
                        SettingsSwitchTile(
                          icon: Icons.view_timeline_outlined,
                          value: provider.preserveTimetableGaps,
                          title: l10n.preserveTimetableGaps,
                          subtitle: l10n.preserveTimetableGapsHint,
                          onChanged: (value) => _updateSetting(
                            'Update timetable gap preservation',
                            () => provider.updatePreserveTimetableGaps(value),
                          ),
                        ),
                        SettingsSwitchTile(
                          icon: Icons.history_outlined,
                          value: provider.showPastEndedCourses,
                          title: l10n.showPastEndedCourses,
                          subtitle: l10n.showPastEndedCoursesHint,
                          onChanged: (value) => _updateSetting(
                            'Update past course visibility',
                            () => provider.updateShowPastEndedCourses(value),
                          ),
                        ),
                        SettingsSwitchTile(
                          icon: Icons.upcoming_outlined,
                          value: provider.showFutureCourses,
                          title: l10n.showFutureCourses,
                          subtitle: l10n.showFutureCoursesHint,
                          onChanged: (value) => _updateSetting(
                            'Update future course visibility',
                            () => provider.updateShowFutureCourses(value),
                          ),
                        ),
                        SettingsSectionHeader(
                          title: l10n.timetableHorizontalLayoutSection,
                        ),
                        SettingsSwitchTile(
                          icon: Icons.view_week_outlined,
                          value: provider.fitDaySelectorToWidth,
                          title: l10n.fitDaySelectorToWidth,
                          subtitle: l10n.fitDaySelectorToWidthHint,
                          onChanged: (value) => _updateSetting(
                            'Update day selector width mode',
                            () => provider.updateFitDaySelectorToWidth(value),
                          ),
                        ),
                        studentWeekWidthSetting(
                          provider,
                          l10n,
                          _updateSetting,
                          enabled: !uiCommandBusy,
                        ),
                        SettingsSwitchTile(
                          icon: Icons.swipe_outlined,
                          value: provider.enableWeekSwipeNavigation,
                          title: l10n.enableWeekSwipeNavigation,
                          subtitle: l10n.enableWeekSwipeNavigationHint,
                          onChanged: (value) => _updateSetting(
                            'Update week swipe navigation',
                            () =>
                                provider.updateEnableWeekSwipeNavigation(value),
                          ),
                        ),
                        SettingsSectionHeader(
                          title: l10n.generalTimeGridSection,
                        ),
                        studentGridLinesSetting(
                          provider,
                          l10n,
                          _updateSetting,
                          enabled: !uiCommandBusy,
                        ),
                        SettingsSectionHeader(
                          title: l10n.toolbarNavigationSection,
                        ),
                        SettingsChoiceTile<String>(
                          enabled:
                              !WorkbenchChromeMetrics.compactTouch(context) ||
                              !uiCommandBusy,
                          key: const ValueKey(
                            'timetable-toolbar-hidden-behavior',
                          ),
                          value: provider.studentToolbarHiddenItemsBehavior,
                          title: l10n.toolbarNavigationHiddenBehavior,
                          icon: Icons.more_horiz_outlined,
                          entries: [
                            DropdownMenuEntry<String>(
                              value: toolbarHiddenItemsBehaviorRemove,
                              label: l10n.toolbarNavigationRemove,
                            ),
                            DropdownMenuEntry<String>(
                              value: toolbarHiddenItemsBehaviorMore,
                              label: l10n.toolbarNavigationMore,
                            ),
                          ],
                          onSelected: (value) {
                            if (value != null) {
                              _updateSetting(
                                'Update timetable toolbar hidden items behavior',
                                () => provider
                                    .updateStudentToolbarHiddenItemsBehavior(
                                      value,
                                    ),
                              );
                            }
                          },
                        ),
                        SettingsToolbarNavigationEditor(
                          key: const ValueKey(
                            'timetable-toolbar-navigation-editor',
                          ),
                          items: _studentToolbarItems(l10n, provider),
                          busy: uiCommandBusy,
                          reorderLabel: l10n.toolbarNavigationReorder,
                          visibilityLabel: l10n.toolbarNavigationVisibility,
                          onReorder: (order) => _updateSetting(
                            'Update timetable toolbar navigation order',
                            () => provider.updateStudentToolbarNavigationOrder(
                              order,
                            ),
                          ),
                          onVisibilityChanged: (id, visible) => _updateSetting(
                            'Update timetable toolbar navigation visibility',
                            () => provider
                                .updateStudentToolbarNavigationVisibility(
                                  id,
                                  visible,
                                ),
                          ),
                        ),
                        SettingsSectionHeader(title: l10n.quickActionsSection),
                        SettingsSwitchTile(
                          key: const ValueKey('show-add-course-fab-setting'),
                          icon: Icons.add_circle_outline,
                          value: provider.showAddCourseFab,
                          title: l10n.showAddCourseFab,
                          subtitle: l10n.showAddCourseFabHint,
                          onChanged: (value) => _updateSetting(
                            'Update add course button visibility',
                            () => provider.updateShowAddCourseFab(value),
                          ),
                        ),
                        SettingsSwitchTile(
                          key: const ValueKey(
                            'enable-long-press-add-course-setting',
                          ),
                          icon: Icons.touch_app_outlined,
                          value: provider.enableLongPressAddCourse,
                          title: l10n.enableLongPressAddCourse,
                          subtitle: l10n.enableLongPressAddCourseHint,
                          onChanged: (value) => _updateSetting(
                            'Update long-press course creation',
                            () =>
                                provider.updateEnableLongPressAddCourse(value),
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

List<SettingsToolbarNavigationItem> _studentToolbarItems(
  AppLocalizations l10n,
  TimetableProvider provider,
) {
  final labels = <String, String>{
    'timetable': l10n.toolbarNavigationTimetable,
    'week': l10n.toolbarNavigationWeek,
    'view': l10n.toolbarNavigationView,
    'settings': l10n.settings,
    'more': l10n.more,
  };
  final icons = <String, IconData>{
    'timetable': Icons.table_chart_outlined,
    'week': Icons.date_range_outlined,
    'view': Icons.view_agenda_outlined,
    'settings': Icons.settings_outlined,
    'more': Icons.more_horiz_outlined,
  };
  final hidden = provider.studentHiddenToolbarNavigationIds.toSet();
  final order = [
    ...provider.studentToolbarNavigationOrder,
    if (!provider.studentToolbarNavigationOrder.contains('more')) 'more',
  ];
  return [
    for (final id in order)
      if (labels.containsKey(id))
        SettingsToolbarNavigationItem(
          id: id,
          label: labels[id]!,
          icon: icons[id]!,
          visible: !hidden.contains(id),
          canHide: id != 'settings',
        ),
  ];
}
