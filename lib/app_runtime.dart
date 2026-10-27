import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'controllers/app_backup_controller.dart';
import 'controllers/app_data_clear_controller.dart';
import 'controllers/app_data_defaults.dart';
import 'controllers/app_data_maintenance.dart';
import 'controllers/app_lifecycle.dart';
import 'controllers/app_persistence.dart';
import 'controllers/app_quiescence.dart';
import 'controllers/app_session.dart';
import 'controllers/app_shutdown_controller.dart';
import 'controllers/data_transfer_controller.dart';
import 'controllers/developer_commands.dart';
import 'controllers/general_commands.dart';
import 'controllers/general_navigation_controller.dart';
import 'controllers/general_view_state.dart';
import 'controllers/observable_view_state.dart';
import 'controllers/school_import_secret_controller.dart';
import 'controllers/settings_commands.dart';
import 'controllers/settings_view_state.dart';
import 'controllers/student_commands.dart';
import 'controllers/student_view_state.dart';
import 'controllers/workspace_commands.dart';
import 'controllers/workspace_transactions.dart';
import 'controllers/workspace_view_state.dart';
import 'data/app_repository.dart';
import 'data/timetable_storage.dart';
import 'l10n/app_locale.dart' as app_locale;
import 'models/timetable_models.dart';
import 'services/agenda_runtime_mutation_lock.dart';
import 'services/app_backup_restore_journal.dart';
import 'services/data_transfer_codec.dart';
import 'services/privacy_service.dart';
import 'services/school_site_service.dart';
import 'services/secret_store.dart';
import 'services/settings_service.dart';

/// Constructs the application's domains and owns their shared lifetime.
/// Screens subscribe to typed state registered by AppScope.
final class AppRuntime {
  AppRuntime({
    TimetableStorage? storage,
    AppRepository? repository,
    String Function()? systemLocaleCodeResolver,
    SettingsService? settingsService,
    PrivacyService? privacyService,
    SecretStore? secretStore,
    SchoolSiteService? schoolSiteService,
    AppBackupRestoreJournal? backupRestoreJournal,
    DataTransferCodec dataTransferCodec = const DataTransferCodec(),
    @visibleForTesting Duration? uiStateSaveDelay,
    @visibleForTesting
    Future<void> Function(Future<void> Function())? workspaceMutationLock,
  }) {
    final localeCodeResolver =
        systemLocaleCodeResolver ?? _defaultSystemLocaleCodeResolver;
    final privacy = privacyService ?? const PrivacyService();
    final schoolSites = schoolSiteService ?? SchoolSiteService();
    final journal = backupRestoreJournal ?? AppBackupRestoreJournal();
    final mutationLock =
        workspaceMutationLock ?? withAgendaRuntimeMutationLock<void>;
    final transactions = WorkspaceTransactions();
    late final AppViewUpdates viewUpdates;
    void publishViews() {
      if (!_isDisposed) viewUpdates.publish();
    }

    final appRepository =
        repository ?? AppRepository(storage: storage ?? TimetableStorage());
    maintenance = AppDataMaintenance(
      repository: appRepository,
      notifyViewChanged: publishViews,
    );
    session = AppSession(
      repository: appRepository,
      initialData: buildInitialAppData(buildDefaultPeriodTimes()),
      requireMutationAllowed: maintenance.ensureMutationAllowed,
      restoreRuntimeFields: (persisted, current) =>
          withRuntimeSchoolImportApiKey(
            persisted,
            current.aiApiSettings.customApiKey,
          ),
    );
    schoolImportSecrets = SchoolImportSecretController(
      session: session,
      store: secretStore ?? SecretStore(),
      notifyViewChanged: publishViews,
    );
    final defaults = AppDataDefaults(
      session: session,
      localeCodeResolver: localeCodeResolver,
      codec: dataTransferCodec,
    );
    studentView = StudentViewState(session);
    persistence = AppPersistence(
      session: session,
      student: studentView,
      transactions: transactions,
      maintenance: maintenance,
      notifyViewChanged: publishViews,
      uiStateSaveDelay: uiStateSaveDelay ?? const Duration(milliseconds: 450),
    );
    studentCommands = StudentCommands(
      session: session,
      view: studentView,
      persist: persistence.saveAndNotify,
      loadDefaultPeriodTimes: defaults.loadPeriodTimes,
      notifyViewChanged: publishViews,
    );
    generalView = GeneralViewState(session);
    generalCommands = GeneralCommands(
      session: session,
      persist: persistence.saveAndNotify,
    );
    workspaceView = WorkspaceViewState(session, generalView);
    workspaces = WorkspaceCommands(
      session: session,
      view: workspaceView,
      transactions: transactions,
      persistence: persistence,
      secrets: schoolImportSecrets,
      runtimeMutationLock: mutationLock,
      notifyViewChanged: publishViews,
    );
    generalNavigation = GeneralNavigationController(
      session: session,
      view: generalView,
      transactions: transactions,
      persistence: persistence,
      maintenance: maintenance,
      notifyViewChanged: publishViews,
    );
    settingsView = SettingsViewState(workspaceView);
    settingsCommands = SettingsCommands(
      secrets: schoolImportSecrets,
      session: session,
      persist: persistence.saveAndNotify,
      service: settingsService ?? const SettingsService(),
    );
    transfers = DataTransferController(
      session: session,
      student: studentView,
      general: generalView,
      persistence: persistence,
      maintenance: maintenance,
      codec: dataTransferCodec,
    );
    backups = AppBackupController(
      session: session,
      persistence: persistence,
      maintenance: maintenance,
      student: studentView,
      workspace: workspaceView,
      workspaces: workspaces,
      secrets: schoolImportSecrets,
      schoolSites: schoolSites,
      journal: journal,
      defaults: defaults,
      transfers: transfers,
      codec: dataTransferCodec,
      runtimeMutationLock: mutationLock,
      notifyViewChanged: publishViews,
    );
    lifecycle = AppLifecycle(
      session: session,
      student: studentView,
      persistence: persistence,
      defaults: defaults,
      backups: backups,
      secrets: schoolImportSecrets,
      privacy: privacy,
      codec: dataTransferCodec,
      notifyViewChanged: publishViews,
    );
    final quiescence = AppQuiescence(
      session: session,
      persistence: persistence,
      secrets: schoolImportSecrets,
      schoolSites: schoolSites,
      transactions: transactions,
    );
    dataClear = AppDataClearController(
      maintenance: maintenance,
      persistence: persistence,
      schoolSites: schoolSites,
      quiescence: quiescence,
      notifyViewChanged: publishViews,
    );
    shutdown = AppShutdownController(
      session: session,
      persistence: persistence,
      maintenance: maintenance,
      secrets: schoolImportSecrets,
      schoolSites: schoolSites,
      workspace: workspaceView,
      workspaces: workspaces,
      dataClear: dataClear,
      quiescence: quiescence,
    );
    developer = DeveloperCommands(
      session: session,
      student: studentView,
      persistence: persistence,
      notifyViewChanged: publishViews,
    );
    viewUpdates = AppViewUpdates([
      studentView,
      generalView,
      workspaceView,
      settingsView,
      lifecycle,
    ]);
  }

  late final AppSession session;
  late final AppDataMaintenance maintenance;
  late final AppPersistence persistence;
  late final StudentViewState studentView;
  late final StudentCommands studentCommands;
  late final GeneralViewState generalView;
  late final GeneralCommands generalCommands;
  late final GeneralNavigationController generalNavigation;
  late final WorkspaceViewState workspaceView;
  late final WorkspaceCommands workspaces;
  late final SettingsViewState settingsView;
  late final SettingsCommands settingsCommands;
  late final SchoolImportSecretController schoolImportSecrets;
  late final DataTransferController transfers;
  late final AppBackupController backups;
  late final AppLifecycle lifecycle;
  late final AppDataClearController dataClear;
  late final AppShutdownController shutdown;
  late final DeveloperCommands developer;

  var _isDisposed = false;

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    persistence.flushScheduledUiStateSave();
    studentView.dispose();
    generalView.dispose();
    workspaceView.dispose();
    settingsView.dispose();
    lifecycle.dispose();
    dataClear.dispose();
    maintenance.dispose();
    unawaited(session.close());
  }
}

String _defaultSystemLocaleCodeResolver() {
  final locales = PlatformDispatcher.instance.locales;
  return app_locale.resolveFirstLaunchLocaleCode(
    locales.isEmpty ? null : locales.first,
  );
}
