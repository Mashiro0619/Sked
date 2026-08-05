import 'dart:async';

import 'package:flutter/material.dart';
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
          appBar: AppBar(title: Text(l10n.timetableDisplaySettings)),
          body: Column(
            children: [
              UiCommandBusyIndicator(busy: uiCommandBusy),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    SettingsSectionHeader(title: l10n.generalPopupSection),
                    SettingsSwitchTile(
                      icon: Icons.open_in_full_outlined,
                      value: provider.closeCoursePopupOnOutsideTap,
                      title: l10n.coursePopupDismissSetting,
                      subtitle: l10n.coursePopupDismissSettingHint,
                      onChanged: uiCommandBusy
                          ? null
                          : (value) => _updateSetting(
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
                      onChanged: uiCommandBusy
                          ? null
                          : (value) => _updateSetting(
                              'Update timetable gap preservation',
                              () => provider.updatePreserveTimetableGaps(value),
                            ),
                    ),
                    SettingsSwitchTile(
                      icon: Icons.history_outlined,
                      value: provider.showPastEndedCourses,
                      title: l10n.showPastEndedCourses,
                      subtitle: l10n.showPastEndedCoursesHint,
                      onChanged: uiCommandBusy
                          ? null
                          : (value) => _updateSetting(
                              'Update past course visibility',
                              () => provider.updateShowPastEndedCourses(value),
                            ),
                    ),
                    SettingsSwitchTile(
                      icon: Icons.upcoming_outlined,
                      value: provider.showFutureCourses,
                      title: l10n.showFutureCourses,
                      subtitle: l10n.showFutureCoursesHint,
                      onChanged: uiCommandBusy
                          ? null
                          : (value) => _updateSetting(
                              'Update future course visibility',
                              () => provider.updateShowFutureCourses(value),
                            ),
                    ),
                    SettingsSectionHeader(title: l10n.generalTimeGridSection),
                    SettingsSwitchTile(
                      icon: Icons.grid_4x4_outlined,
                      value: provider.showTimetableGridLines,
                      title: l10n.showTimetableGridLines,
                      subtitle: l10n.showTimetableGridLinesHint,
                      onChanged: uiCommandBusy
                          ? null
                          : (value) => _updateSetting(
                              'Update timetable grid line visibility',
                              () =>
                                  provider.updateShowTimetableGridLines(value),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
