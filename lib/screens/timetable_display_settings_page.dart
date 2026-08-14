import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/timetable_provider.dart';
import '../widgets/settings_list.dart';
import '../widgets/ui_command.dart';

class TimetableDisplaySettingsPage extends StatefulWidget {
  const TimetableDisplaySettingsPage({super.key});

  @override
  State<TimetableDisplaySettingsPage> createState() =>
      _TimetableDisplaySettingsPageState();
}

class _TimetableDisplaySettingsPageState
    extends State<TimetableDisplaySettingsPage>
    with UiCommandRunner<TimetableDisplaySettingsPage> {
  void _updateSetting(String debugLabel, Future<void> Function() command) {
    unawaited(runUiCommand(debugLabel: debugLabel, command: command));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TimetableProvider>(
      builder: (context, provider, child) {
        final l10n = AppLocalizations.of(context);
        return Scaffold(
          appBar: AppBar(
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
                        SettingsSwitchTile(
                          icon: Icons.view_column_outlined,
                          value: provider.fitWeekColumnsToWidth,
                          title: l10n.fitWeekColumnsToWidth,
                          subtitle: l10n.fitWeekColumnsToWidthHint,
                          onChanged: (value) => _updateSetting(
                            'Update week column width mode',
                            () => provider.updateFitWeekColumnsToWidth(value),
                          ),
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
                        SettingsSwitchTile(
                          icon: Icons.grid_4x4_outlined,
                          value: provider.showTimetableGridLines,
                          title: l10n.showTimetableGridLines,
                          subtitle: l10n.showTimetableGridLinesHint,
                          onChanged: (value) => _updateSetting(
                            'Update timetable grid line visibility',
                            () => provider.updateShowTimetableGridLines(value),
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
