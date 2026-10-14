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

  /// Captures the current composition without subscribing to its owner. Routes
  /// can reuse these dependencies even when their Navigator is outside the scope.
  /// Standalone UI without an application scope returns null.
  static CapturedAppScope? capture(BuildContext context) {
    final owner = context.getInheritedWidgetOfExactType<_AppScopeOwner>();
    return owner == null ? null : CapturedAppScope._(owner.app);
  }

  static List<SingleChildWidget> providersFor(TimetableProvider app) => [
    _AppScopeAnchor(app: app),
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

/// A reference to the same domain instances; the original application retains
/// ownership of their lifetime when the captured route is removed.
class CapturedAppScope {
  const CapturedAppScope._(this._app);

  final TimetableProvider _app;

  Widget wrap(Widget child) => AppScope(app: _app, child: child);
}

class _AppScopeAnchor extends SingleChildStatelessWidget {
  const _AppScopeAnchor({required this.app});

  final TimetableProvider app;

  @override
  Widget buildWithChild(BuildContext context, Widget? child) =>
      _AppScopeOwner(app: app, child: child ?? const SizedBox.shrink());
}

class _AppScopeOwner extends InheritedWidget {
  const _AppScopeOwner({required this.app, required super.child});

  final TimetableProvider app;

  @override
  bool updateShouldNotify(_AppScopeOwner oldWidget) => false;
}
