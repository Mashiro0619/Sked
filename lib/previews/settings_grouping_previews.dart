import 'package:flutter/widget_previews.dart';
import 'package:material_ui/material_ui.dart';

import '../widgets/settings_list.dart';
import 'sked_preview_support.dart';

@Preview(
  group: 'Responsive settings grouping',
  name: 'Phone',
  size: skedPhonePreviewSize,
  wrapper: skedPreviewWrapper,
)
@Preview(
  group: 'Responsive settings grouping',
  name: 'Phone - 2x text',
  size: skedPhoneLargeTextPreviewSize,
  textScaleFactor: 2,
  wrapper: skedPreviewWrapper,
)
@Preview(
  group: 'Responsive settings grouping',
  name: 'Wide',
  size: skedWidePreviewSize,
  wrapper: skedPreviewWrapper,
)
Widget responsiveSettingsGroupingPreview() {
  const workspace = SettingsConnectedGroup(
    title: 'Workspace',
    children: <Widget>[
      SettingsConnectedTile(
        leading: Icon(Icons.space_dashboard_outlined),
        title: 'Workspace navigation',
        subtitle: 'Show timetable and general schedule destinations',
        trailing: Switch(value: true, onChanged: null),
      ),
      SettingsConnectedTile(
        leading: Icon(Icons.schedule_outlined),
        title: 'Default period-time set',
        subtitle: 'Standard day - 10 periods',
        trailing: Icon(Icons.chevron_right),
      ),
    ],
  );
  const timetable = SettingsConnectedGroup(
    title: 'Timetable',
    children: <Widget>[
      SettingsConnectedTile(
        leading: Icon(Icons.grid_view_outlined),
        title: 'Timetable display',
        subtitle: 'Course details, grid, and quick actions',
        trailing: Icon(Icons.chevron_right),
      ),
      SettingsConnectedTile(
        leading: Icon(Icons.access_time_outlined),
        title: 'Period times',
        subtitle: 'Edit reusable daily schedules',
        trailing: Icon(Icons.chevron_right),
      ),
    ],
  );
  const appearance = SettingsConnectedGroup(
    title: 'Appearance and language',
    children: <Widget>[
      SettingsConnectedTile(
        leading: Icon(Icons.palette_outlined),
        title: 'Theme',
        subtitle: 'Light with a custom accent color',
        trailing: Icon(Icons.chevron_right),
      ),
      SettingsConnectedTile(
        leading: Icon(Icons.language_outlined),
        title: 'Language',
        subtitle: 'English',
        trailing: Icon(Icons.chevron_right),
      ),
    ],
  );
  const data = SettingsConnectedGroup(
    title: 'Data and security',
    children: <Widget>[
      SettingsConnectedTile(
        leading: Icon(Icons.import_export_outlined),
        title: 'Import and export',
        subtitle: 'Back up or transfer local data',
        trailing: Icon(Icons.chevron_right),
      ),
      SettingsConnectedTile(
        leading: Icon(Icons.privacy_tip_outlined),
        title: 'Privacy',
        subtitle: 'Review local storage and network use',
        trailing: Icon(Icons.chevron_right),
      ),
    ],
  );

  return const ResponsiveSettingsBody(
    firstColumnChildren: <Widget>[workspace, timetable],
    secondColumnChildren: <Widget>[appearance, data],
    topPadding: 12,
    children: <Widget>[workspace, timetable, appearance, data],
  );
}
