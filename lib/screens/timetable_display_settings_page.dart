import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/timetable_provider.dart';
import '../widgets/settings_list.dart';

class TimetableDisplaySettingsPage extends StatelessWidget {
  const TimetableDisplaySettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TimetableProvider>(
      builder: (context, provider, child) {
        final l10n = AppLocalizations.of(context);
        return Scaffold(
          appBar: AppBar(title: Text(l10n.timetableDisplaySettings)),
          body: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              SettingsSectionHeader(title: l10n.generalPopupSection),
              SettingsSwitchTile(
                icon: Icons.open_in_full_outlined,
                value: provider.closeCoursePopupOnOutsideTap,
                title: l10n.coursePopupDismissSetting,
                subtitle: l10n.coursePopupDismissSettingHint,
                onChanged: provider.updateCloseCoursePopupOnOutsideTap,
              ),
              SettingsSectionHeader(title: l10n.generalScheduleDisplaySection),
              SettingsSwitchTile(
                icon: Icons.view_timeline_outlined,
                value: provider.preserveTimetableGaps,
                title: l10n.preserveTimetableGaps,
                subtitle: l10n.preserveTimetableGapsHint,
                onChanged: provider.updatePreserveTimetableGaps,
              ),
              SettingsSwitchTile(
                icon: Icons.history_outlined,
                value: provider.showPastEndedCourses,
                title: l10n.showPastEndedCourses,
                subtitle: l10n.showPastEndedCoursesHint,
                onChanged: provider.updateShowPastEndedCourses,
              ),
              SettingsSwitchTile(
                icon: Icons.upcoming_outlined,
                value: provider.showFutureCourses,
                title: l10n.showFutureCourses,
                subtitle: l10n.showFutureCoursesHint,
                onChanged: provider.updateShowFutureCourses,
              ),
              SettingsSectionHeader(title: l10n.generalTimeGridSection),
              SettingsSwitchTile(
                icon: Icons.grid_4x4_outlined,
                value: provider.showTimetableGridLines,
                title: l10n.showTimetableGridLines,
                subtitle: l10n.showTimetableGridLinesHint,
                onChanged: provider.updateShowTimetableGridLines,
              ),
            ],
          ),
        );
      },
    );
  }
}
