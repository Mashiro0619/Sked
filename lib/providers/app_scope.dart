import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../controllers/app_backup_controller.dart';
import '../controllers/app_data_maintenance.dart';
import '../controllers/app_persistence.dart';
import '../controllers/app_session.dart';
import '../controllers/data_transfer_controller.dart';
import '../controllers/general_commands.dart';
import '../controllers/general_navigation_controller.dart';
import '../controllers/general_view_state.dart';
import '../controllers/school_import_secret_controller.dart';
import '../controllers/settings_commands.dart';
import '../controllers/settings_view_state.dart';
import '../controllers/student_commands.dart';
import '../controllers/student_view_state.dart';
import '../controllers/workspace_commands.dart';
import '../controllers/workspace_view_state.dart';
import 'timetable_provider.dart';

/// Registers the application's typed state and commands for screens and routes.
/// The owning app controls their lifetime; scopes may reuse the same instances.
class AppScope extends StatelessWidget {
  const AppScope({super.key, required this.app, required this.child});

  final TimetableProvider app;
  final Widget child;

  static List<SingleChildWidget> providersFor(TimetableProvider app) => [
    ChangeNotifierProvider<TimetableProvider>.value(value: app),
    Provider<AppSession>.value(value: app.session),
    ListenableProvider<ValueListenable<AppSessionReadiness>>.value(
      value: app.session.readiness,
    ),
    ProxyProvider<ValueListenable<AppSessionReadiness>, AppSessionReadiness>(
      update: (_, readiness, _) => readiness.value,
    ),
    ChangeNotifierProvider<StudentViewState>.value(value: app.studentView),
    Provider<StudentCommands>.value(value: app.studentCommands),
    ChangeNotifierProvider<GeneralViewState>.value(value: app.generalView),
    Provider<GeneralCommands>.value(value: app.generalCommands),
    Provider<GeneralNavigationController>.value(value: app.generalNavigation),
    ChangeNotifierProvider<WorkspaceViewState>.value(value: app.workspaceView),
    Provider<WorkspaceCommands>.value(value: app.workspaces),
    ChangeNotifierProvider<SettingsViewState>.value(value: app.settingsView),
    Provider<SettingsCommands>.value(value: app.settingsCommands),
    ChangeNotifierProvider<AppDataMaintenance>.value(value: app.maintenance),
    Provider<AppPersistence>.value(value: app.persistence),
    Provider<SchoolImportSecretController>.value(
      value: app.schoolImportSecrets,
    ),
    Provider<DataTransferController>.value(value: app.transfers),
    Provider<AppBackupController>.value(value: app.backups),
  ];

  @override
  Widget build(BuildContext context) =>
      MultiProvider(providers: providersFor(app), child: child);
}
