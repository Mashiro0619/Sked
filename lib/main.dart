import 'controllers/course_task_controller.dart';
import 'widgets/course_task_editor.dart';
import 'controllers/general_event_task_controller.dart';
import 'widgets/general_event_task_editor.dart';
import 'widgets/sked_confirmation_dialog.dart';
import 'widgets/sked_task_route.dart';
import 'widgets/general_event_edit_flow.dart';
import 'widgets/update_prompt_scope.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'theme/app_theme.dart';
import 'theme/sked_expressive_theme.dart';
import 'l10n/app_locale.dart';
import 'l10n/app_localization_delegates.dart';
import 'l10n/app_localizations.dart';
import 'models/timetable_models.dart';
import 'providers/timetable_provider.dart';
import 'screens/app_home_screen.dart';
import 'services/app_instance_lease.dart';
import 'services/agenda_background_reconciler.dart';
import 'services/agenda_coordinator.dart';
import 'services/notification_occurrence_resolver.dart';
import 'widgets/app_modal_sheet.dart';
import 'widgets/course_details_sheet.dart';
import 'widgets/course_editor_sheet.dart';
import 'widgets/general_event_details_sheet.dart';
import 'widgets/general_event_editor_sheet.dart';
import 'widgets/sked_expressive_loading_indicator.dart';
import 'widgets/material_ui_compatibility.dart';
import 'widgets/desktop_window_host.dart';
import 'services/desktop_window_bridge.dart';
import 'services/desktop_layout_preferences.dart';
import 'services/developer_ui_preferences.dart';

Future<void> main() async {
  // Keep the Android WorkManager entry point in the AOT snapshot. The worker
  // invokes it by library URI after the foreground application is gone.
  assert(_backgroundEntrypoints.isNotEmpty);
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await DesktopWindowBridge.instance.initialize();
  _registerLicenses();
  runApp(AppBootstrap());
}

final _backgroundEntrypoints = <void Function()>[agendaBackgroundReconcile];

void _registerLicenses() {
  LicenseRegistry.addLicense(() async* {
    final notice = await rootBundle.loadString('NOTICE');
    yield LicenseEntryWithLineBreaks(['App icon assets'], notice);
  });
}

typedef TimetableProviderFactory = TimetableProvider Function();

enum _AppBootstrapStatus { acquiring, ready, blocked, failed }

class AppBootstrap extends StatefulWidget {
  AppBootstrap({
    super.key,
    AppInstanceLease? lease,
    TimetableProviderFactory? providerFactory,
  }) : lease = lease ?? AppInstanceLease(),
       providerFactory = providerFactory ?? TimetableProvider.new;

  final AppInstanceLease lease;
  final TimetableProviderFactory providerFactory;

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  late final AppInstanceLease _lease;
  late final TimetableProviderFactory _providerFactory;
  var _status = _AppBootstrapStatus.acquiring;
  TimetableProvider? _provider;
  DesktopLayoutPreferences? _desktopLayout;
  Future<void>? _providerLoad;
  Future<void>? _acquireOperation;
  var _attemptInProgress = false;
  var _leaseOwned = false;

  @override
  void initState() {
    super.initState();
    _lease = widget.lease;
    _providerFactory = widget.providerFactory;
    _startLeaseAcquisition();
  }

  void _startLeaseAcquisition() {
    if (_attemptInProgress || _provider != null) return;
    final operation = _acquireLease();
    _acquireOperation = operation;
    unawaited(operation);
  }

  Future<void> _acquireLease() async {
    if (_attemptInProgress || _provider != null) return;
    _attemptInProgress = true;
    if (mounted && _status != _AppBootstrapStatus.acquiring) {
      setState(() => _status = _AppBootstrapStatus.acquiring);
    }

    try {
      final acquired = await _lease.tryAcquire();
      if (acquired) {
        _leaseOwned = true;
      }
      if (!mounted) {
        return;
      }
      if (!acquired) {
        setState(() => _status = _AppBootstrapStatus.blocked);
        return;
      }

      try {
        final provider = _providerFactory();
        _provider = provider;
        _desktopLayout = DesktopLayoutPreferences();
        unawaited(_desktopLayout!.load());
        final load = provider.load();
        _providerLoad = load;
        unawaited(
          load.then<void>(
            (_) {},
            onError: (Object error, StackTrace stackTrace) {
              debugPrint(
                'Provider load failed unexpectedly: $error\n$stackTrace',
              );
            },
          ),
        );
        setState(() => _status = _AppBootstrapStatus.ready);
      } catch (error, stackTrace) {
        debugPrint('App provider creation failed: $error\n$stackTrace');
        await _releaseLeaseIfOwned();
        if (mounted) {
          setState(() => _status = _AppBootstrapStatus.failed);
        }
      }
    } catch (error, stackTrace) {
      debugPrint('App instance lease acquisition failed: $error\n$stackTrace');
      if (mounted) {
        setState(() => _status = _AppBootstrapStatus.failed);
      }
    } finally {
      _attemptInProgress = false;
      if (mounted && _status != _AppBootstrapStatus.ready) {
        setState(() {});
      }
    }
  }

  Future<void> _releaseLeaseIfOwned() async {
    if (!_leaseOwned) return;
    _leaseOwned = false;
    await _lease.release();
  }

  @override
  void dispose() {
    final shutdown = _shutdownResources();
    unawaited(shutdown);
    super.dispose();
  }

  Future<void> _shutdownResources() async {
    final acquisition = _acquireOperation;
    if (acquisition != null) {
      try {
        await acquisition;
      } catch (_) {
        // Acquisition already mapped the failure to the bootstrap gate.
      }
    }

    try {
      final provider = _provider;
      final load = _providerLoad;
      if (load != null) {
        try {
          await load;
        } catch (error, stackTrace) {
          debugPrint(
            'Provider load ended during shutdown: $error\n$stackTrace',
          );
        }
      }
      if (provider != null) {
        try {
          await provider.quiesceForShutdown();
        } finally {
          provider.dispose();
        }
      }
    } catch (error, stackTrace) {
      debugPrint('App provider shutdown failed: $error\n$stackTrace');
    } finally {
      try {
        final layout = _desktopLayout;
        if (layout != null) {
          try {
            if (!await layout.flush()) {
              debugPrint(
                'Desktop layout preference save failed during shutdown',
              );
            }
          } finally {
            layout.dispose();
          }
        }
      } catch (error, stackTrace) {
        debugPrint(
          'Desktop layout preference shutdown failed: $error\n$stackTrace',
        );
      } finally {
        try {
          await _releaseLeaseIfOwned();
        } catch (error, stackTrace) {
          debugPrint('App instance lease release failed: $error\n$stackTrace');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = _provider;
    if (_status == _AppBootstrapStatus.ready && provider != null) {
      return MyApp(
        provider: provider,
        providerReady: _providerLoad,
        desktopLayoutPreferences: _desktopLayout,
      );
    }
    return _AppBootstrapGate(
      status: _status,
      onRetry: _attemptInProgress ? null : _startLeaseAcquisition,
    );
  }
}

class _AppBootstrapGate extends StatefulWidget {
  const _AppBootstrapGate({required this.status, required this.onRetry});

  final _AppBootstrapStatus status;
  final VoidCallback? onRetry;

  @override
  State<_AppBootstrapGate> createState() => _AppBootstrapGateState();
}

class _AppBootstrapGateState extends State<_AppBootstrapGate> {
  final _windowModals = DesktopWindowModalObserver();

  @override
  void dispose() {
    _windowModals.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorObservers: [_windowModals],
      // The bootstrap gate has no loaded user locale yet. Keep this transient
      // screen deterministic and LTR until the persisted locale is available.
      locale: const Locale('en'),
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: appLocalizationsDelegates,
      builder: (context, child) => bridgeLegacyMaterialUi(
        context,
        DesktopWindowHost(modalObserver: _windowModals, child: child!),
      ),
      theme: buildAppTheme(
        seedColor: const Color(0xFF6750A4),
        brightness: Brightness.light,
        themeColorMode: themeColorModeSingle,
        colorfulUiColorValues: const {},
      ),
      darkTheme: buildAppTheme(
        seedColor: const Color(0xFF6750A4),
        brightness: Brightness.dark,
        themeColorMode: themeColorModeSingle,
        colorfulUiColorValues: const {},
      ),
      home: Builder(
        builder: (context) {
          final l10n = AppLocalizations.of(context);
          final acquiring = widget.status == _AppBootstrapStatus.acquiring;
          final failed = widget.status == _AppBootstrapStatus.failed;
          return Scaffold(
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Semantics(
                      liveRegion: true,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            acquiring
                                ? Icons.hourglass_top_outlined
                                : failed
                                ? Icons.storage_outlined
                                : Icons.copy_all_outlined,
                            size: 48,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 20),
                          if (acquiring)
                            const SkedExpressiveLoadingIndicator()
                          else ...[
                            Text(
                              failed
                                  ? l10n.appInstanceLeaseFailedTitle
                                  : l10n.appInstanceBlockedTitle,
                              key: const ValueKey('app-instance-gate-title'),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              failed
                                  ? l10n.appInstanceLeaseFailedMessage
                                  : l10n.appInstanceBlockedMessage,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 24),
                            FilledButton.icon(
                              onPressed: widget.onRetry,
                              icon: const Icon(Icons.refresh_outlined),
                              label: Text(l10n.dataRecoveryRetryAction),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({
    super.key,
    required this.provider,
    this.providerReady,
    this.desktopLayoutPreferences,
  });

  final TimetableProvider provider;
  final Future<void>? providerReady;
  final DesktopLayoutPreferences? desktopLayoutPreferences;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late AgendaCoordinator _agendaCoordinator;
  final _developerUi = DeveloperUiPreferences();
  late final DesktopLayoutPreferences _desktopLayout;
  late final bool _ownsDesktopLayout;
  final _windowModals = DesktopWindowModalObserver();
  final _updatePrompts = UpdatePromptController();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  var _layoutSaveErrorShown = false;
  var _layoutFeedbackScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    DesktopWindowBridge.instance.prepareClose = _prepareWindowClose;
    _ownsDesktopLayout = widget.desktopLayoutPreferences == null;
    _desktopLayout =
        widget.desktopLayoutPreferences ?? DesktopLayoutPreferences();
    _desktopLayout.addListener(_onDesktopLayoutChanged);
    unawaited(_desktopLayout.load());
    unawaited(_developerUi.load());
    _agendaCoordinator = AgendaCoordinator(
      provider: widget.provider,
      onTarget: _openAgendaTarget,
    );
    _agendaCoordinator.setForegroundActive(true);
    unawaited(_agendaCoordinator.start(providerReady: widget.providerReady));
  }

  void _onDesktopLayoutChanged() {
    if (!_desktopLayout.hasError) {
      _layoutSaveErrorShown = false;
      return;
    }
    if (!_desktopLayout.hasUnsavedChanges ||
        _layoutSaveErrorShown ||
        _layoutFeedbackScheduled) {
      return;
    }
    _layoutFeedbackScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _layoutFeedbackScheduled = false;
      if (!mounted ||
          !_desktopLayout.hasError ||
          !_desktopLayout.hasUnsavedChanges) {
        return;
      }
      final context = _navigatorKey.currentContext;
      final messenger = _scaffoldMessengerKey.currentState;
      if (context == null || messenger == null) return;
      final l10n = AppLocalizations.of(context);
      _layoutSaveErrorShown = true;
      messenger.showSnackBar(
        SnackBar(
          key: const ValueKey('desktop-layout-save-error'),
          content: Text(l10n.saveFailedRetry),
          action: SnackBarAction(
            key: const ValueKey('desktop-layout-save-retry'),
            label: l10n.retrySave,
            onPressed: () {
              _layoutSaveErrorShown = false;
              unawaited(_desktopLayout.retry());
            },
          ),
        ),
      );
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<bool> _prepareWindowClose() async {
    try {
      if (!await _desktopLayout.flush()) {
        debugPrint('Desktop layout preference save failed during close');
      }
      if (!await _developerUi.waitForPendingSave()) {
        throw StateError('Developer UI preference save failed');
      }
      return await widget.provider.prepareForWindowClose();
    } catch (_) {
      final context = _navigatorKey.currentContext;
      if (context != null && context.mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => SkedConfirmationDialog(
            title: Text(AppLocalizations.of(context).saveFailedRetry),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(MaterialLocalizations.of(context).okButtonLabel),
              ),
            ],
          ),
        );
      }
      return false;
    }
  }

  @override
  void didUpdateWidget(MyApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.provider != widget.provider) {
      _flushPendingUiStateSaves(oldWidget.provider);
      _agendaCoordinator.dispose();
      _agendaCoordinator = AgendaCoordinator(
        provider: widget.provider,
        onTarget: _openAgendaTarget,
      );
      _agendaCoordinator.setForegroundActive(true);
      unawaited(_agendaCoordinator.start(providerReady: widget.providerReady));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _agendaCoordinator.setForegroundActive(false);
      _flushPendingUiStateSaves(widget.provider);
      _flushDesktopLayoutPreferences(_desktopLayout);
    }
    if (state == AppLifecycleState.resumed) {
      _agendaCoordinator.setForegroundActive(true);
      unawaited(_agendaCoordinator.onResume());
    }
  }

  @override
  void didChangeAccessibilityFeatures() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    DesktopWindowBridge.instance.prepareClose = null;
    _agendaCoordinator.setForegroundActive(false);
    _agendaCoordinator.dispose();
    _developerUi.dispose();
    _desktopLayout.removeListener(_onDesktopLayoutChanged);
    _flushDesktopLayoutPreferences(
      _desktopLayout,
      disposeWhenComplete: _ownsDesktopLayout,
    );
    _windowModals.dispose();
    _updatePrompts.dispose();
    _flushPendingUiStateSaves(widget.provider);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final features =
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures;
    return SkedMotionPolicyScope(
      disableAnimations: features.disableAnimations,
      reduceMotion: features.reduceMotion,
      child: ChangeNotifierProvider<TimetableProvider>.value(
        value: widget.provider,
        child: Selector<TimetableProvider, _AppShellSnapshot>(
          selector: (_, provider) => _AppShellSnapshot.from(provider),
          builder: (context, snapshot, child) {
            return MultiProvider(
              providers: [
                Provider<AgendaCoordinator>.value(value: _agendaCoordinator),
                ChangeNotifierProvider<DeveloperUiPreferences>.value(
                  value: _developerUi,
                ),
                ChangeNotifierProvider<DesktopLayoutPreferences>.value(
                  value: _desktopLayout,
                ),
              ],
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                navigatorKey: _navigatorKey,
                scaffoldMessengerKey: _scaffoldMessengerKey,
                navigatorObservers: [_windowModals, _updatePrompts.observer],
                onGenerateTitle: (context) =>
                    AppLocalizations.of(context).appTitle,
                locale: appLocaleFromCode(snapshot.localeCode),
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: appLocalizationsDelegates,
                builder: (context, child) => bridgeLegacyMaterialUi(
                  context,
                  DesktopWindowHost(
                    modalObserver: _windowModals,
                    child: UpdatePromptScope(
                      controller: _updatePrompts,
                      child: child!,
                    ),
                  ),
                ),
                themeMode: themeModeFromValue(snapshot.themeMode),
                themeAnimationStyle: appThemeAnimationStyle,
                theme: buildAppTheme(
                  seedColor: Color(snapshot.themeSeedColorValue),
                  brightness: Brightness.light,
                  themeColorMode: snapshot.themeColorMode,
                  colorfulUiColorValues: snapshot.colorfulUiColorValues,
                ),
                darkTheme: buildAppTheme(
                  seedColor: Color(snapshot.themeSeedColorValue),
                  brightness: Brightness.dark,
                  themeColorMode: snapshot.themeColorMode,
                  colorfulUiColorValues: snapshot.colorfulUiColorValues,
                ),
                home: Selector<DesktopLayoutPreferences, bool>(
                  selector: (_, preferences) => preferences.ready,
                  builder: (_, ready, _) => ready
                      ? const AppHomeScreen()
                      : const Scaffold(
                          body: Center(child: CircularProgressIndicator()),
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Opens the concrete item after [AgendaActionRouter] has selected its
  /// workspace and date. Keeping this in the composition root means platform
  /// taps do not need to reach into either workspace's private State object.
  Future<void> _openAgendaTarget(AgendaTarget target) async {
    final context = _navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    switch (target.sourceType) {
      case AgendaSourceType.course:
        return _openAgendaCourseDetails(context, target);
      case AgendaSourceType.generalEvent:
        return _openAgendaGeneralDetails(context, target);
    }
  }

  Future<void> _openAgendaCourseDetails(
    BuildContext context,
    AgendaTarget target,
  ) async {
    final courseId = target.courseId;
    final timetable = widget.provider.timetables
        .where((item) => item.id == target.timetableId)
        .firstOrNull;
    if (courseId == null || timetable == null) return;
    CourseItem? course;
    for (final candidate in timetable.courses) {
      if (candidate.id == courseId) {
        course = candidate;
        break;
      }
    }
    final selectedCourse = course;
    if (selectedCourse == null || !context.mounted) return;
    await showAppModalSheet<void>(
      context: context,
      useRootNavigator: true,
      isDismissible: widget.provider.closeCoursePopupOnOutsideTap,
      enableDrag: true,
      maxWidth: 860,
      builder: (sheetContext) => CourseDetailsSheet(
        timetableId: timetable.id,
        courseId: selectedCourse.id,
        weekday: selectedCourse.dayOfWeek,
        conflictKey: null,
        isFullConflict: false,
        onEdit: () async {
          if (sheetContext.mounted) {
            completeSkedTaskRoute(sheetContext);
          }
          if (context.mounted) {
            await _openAgendaCourseEditor(
              context,
              selectedCourse,
              timetableId: timetable.id,
            );
          }
        },
        onMissing: () {
          if (sheetContext.mounted) {
            final route = ModalRoute.of(sheetContext);
            if (route != null && route.isActive) {
              Navigator.of(sheetContext).removeRoute(route);
            }
          }
        },
      ),
    );
  }

  Future<void> _openAgendaCourseEditor(
    BuildContext context,
    CourseItem course, {
    required String timetableId,
  }) async {
    final student = widget.provider.studentView;
    final timetable = student.timetables
        .where((item) => item.id == timetableId)
        .firstOrNull;
    if (timetable == null || !context.mounted) return;
    final currentCourse = timetable.courses
        .where((item) => item.id == course.id)
        .firstOrNull;
    if (currentCourse == null) return;
    final task = CourseTaskController(
      commands: widget.provider.studentCommands,
      view: student,
      workspaceView: widget.provider.workspaceView,
      maintenance: widget.provider.maintenance,
      timetable: timetable,
      initialCourse: currentCourse,
    );
    await showAppModalSheet<CourseEditorResult>(
      context: context,
      useRootNavigator: true,
      workspace: AppMode.student,
      isSessionCurrent: () => task.isCurrent,
      isDismissible: widget.provider.settingsView.closeCoursePopupOnOutsideTap,
      enableDrag: true,
      maxWidth: appSheetWidthExpanded,
      builder: (_) => CourseTaskEditor(task: task),
    );
  }

  Future<void> _openAgendaGeneralDetails(
    BuildContext context,
    AgendaTarget target,
  ) async {
    final occurrence = resolveNotificationOccurrence(widget.provider, target);
    if (occurrence == null || !context.mounted) return;
    await _openGeneralOccurrenceDetails(context, occurrence);
  }

  GeneralEventOccurrence? _currentGeneralOccurrence(
    GeneralEventOccurrence source,
  ) => resolveCurrentGeneralOccurrence(widget.provider.generalView, source);

  Future<void> _openGeneralOccurrenceDetails(
    BuildContext context,
    GeneralEventOccurrence occurrence,
  ) async {
    var mutating = false;
    await showAppModalSheet<void>(
      context: context,
      useRootNavigator: true,
      workspace: AppMode.general,
      isSessionCurrent: () =>
          mutating || _currentGeneralOccurrence(occurrence) != null,
      isDismissible: widget.provider.closeGeneralEventPopupOnOutsideTap,
      enableDrag: true,
      maxWidth: appSheetWidthCompact,
      builder: (sheetContext) => Consumer<TimetableProvider>(
        builder: (_, provider, _) {
          final current = _currentGeneralOccurrence(occurrence) ?? occurrence;
          void close() {
            final route = ModalRoute.of(sheetContext);
            if (route?.isCurrent == true) completeSkedTaskRoute(sheetContext);
          }

          Future<void> command(
            Future<void> Function(GeneralEventOccurrence) action,
          ) async {
            final latest = _currentGeneralOccurrence(occurrence);
            if (latest == null) {
              close();
              return;
            }
            mutating = true;
            try {
              await action(latest);
              close();
            } catch (_) {
              mutating = false;
              rethrow;
            }
          }

          return GeneralEventDetailsSheet(
            occurrence: current,
            notificationSettings: provider.notificationSettings,
            isReminderHandled: provider.isGeneralReminderHandled(current),
            onBeforeAction: () => _currentGeneralOccurrence(occurrence) != null,
            onShowCalendar: () => provider.updateGeneralScheduleVisibility(
              current.calendar.id,
              true,
            ),
            onEditScoped: (scope) async {
              final latest = _currentGeneralOccurrence(occurrence);
              if (latest == null) {
                close();
                return;
              }
              close();
              if (context.mounted) {
                await _openAgendaGeneralEditor(context, latest, scope);
              }
            },
            onDismissReminder: () => command(provider.dismissGeneralReminder),
            onRestoreReminder: () => command(provider.restoreGeneralReminder),
            onDuplicate: () => command((value) async {
              await provider.duplicateGeneralOccurrence(value);
            }),
            onDeleteThis: () => command(provider.deleteGeneralOccurrence),
            onDeleteFuture: current.event.recurrenceRule.isRepeating
                ? () => command(provider.deleteFutureGeneralOccurrences)
                : null,
            onDeleteAll: () =>
                command((value) => provider.deleteGeneralEvent(value.event.id)),
          );
        },
      ),
    );
  }

  Future<void> _openAgendaGeneralEditor(
    BuildContext context,
    GeneralEventOccurrence occurrence,
    GeneralEventEditScope scope,
  ) async {
    if (!context.mounted) return;
    final general = widget.provider.generalView;
    final task = GeneralEventTaskController(
      commands: widget.provider.generalCommands,
      view: general,
      workspaceView: widget.provider.workspaceView,
      maintenance: widget.provider.maintenance,
      updates: widget.provider,
      occurrence: occurrence,
      scope: scope,
    );
    await showAppModalSheet<GeneralEventEditorResult>(
      context: context,
      useRootNavigator: true,
      workspace: AppMode.general,
      isSessionCurrent: () => task.isCurrent,
      isDismissible: general.data.closeEventPopupOnOutsideTap,
      enableDrag: true,
      maxWidth: appSheetWidthExpanded,
      builder: (_) => GeneralEventTaskEditor(
        task: task,
        settings: widget.provider.settingsView,
      ),
    );
    final event = task.savedEvent;
    if (!context.mounted) return;
    if (event == null) {
      if (!task.committed && task.isCurrent) {
        await _openGeneralOccurrenceDetails(context, occurrence);
      }
      return;
    }
    final calendar = general.schedules
        .where((item) => item.id == event.calendarId)
        .firstOrNull;
    if (calendar == null || calendar.isVisible) return;
    showHiddenCalendarSaveFeedback(
      context,
      calendar: calendar,
      onView: () {
        if (!context.mounted) return;
        final date = tryParseStrictIsoDateTime(event.startDateTimeIso);
        if (date == null) return;
        final displayed = general
            .occurrencesForRange(
              startInclusive: date,
              endExclusive: addCalendarDays(date, 32),
              onlyVisibleCalendars: false,
            )
            .where((item) => item.event.id == event.id)
            .firstOrNull;
        if (displayed != null) {
          unawaited(_openGeneralOccurrenceDetails(context, displayed));
        }
      },
    );
  }
}

void _flushPendingUiStateSaves(TimetableProvider provider) {
  unawaited(
    provider.flushPendingUiStateSaves().onError((error, stackTrace) {
      debugPrint('Lifecycle UI state flush failed: $error\n$stackTrace');
    }),
  );
}

void _flushDesktopLayoutPreferences(
  DesktopLayoutPreferences preferences, {
  bool disposeWhenComplete = false,
}) {
  unawaited(
    preferences
        .flush()
        .then((saved) {
          if (!saved) debugPrint('Desktop layout preference flush failed');
        })
        .whenComplete(() {
          if (disposeWhenComplete) preferences.dispose();
        }),
  );
}

class _AppShellSnapshot {
  const _AppShellSnapshot({
    required this.localeCode,
    required this.themeMode,
    required this.themeColorMode,
    required this.themeSeedColorValue,
    required this.colorfulUiColorValues,
  });

  factory _AppShellSnapshot.from(TimetableProvider provider) {
    return _AppShellSnapshot(
      localeCode: provider.localeCode,
      themeMode: provider.themeMode,
      themeColorMode: provider.themeColorMode,
      themeSeedColorValue: provider.themeSeedColorValue,
      colorfulUiColorValues: Map.unmodifiable(provider.colorfulUiColorValues),
    );
  }

  final String localeCode;
  final String themeMode;
  final String themeColorMode;
  final int themeSeedColorValue;
  final Map<String, int> colorfulUiColorValues;

  @override
  bool operator ==(Object other) {
    return other is _AppShellSnapshot &&
        other.localeCode == localeCode &&
        other.themeMode == themeMode &&
        other.themeColorMode == themeColorMode &&
        other.themeSeedColorValue == themeSeedColorValue &&
        mapEquals(other.colorfulUiColorValues, colorfulUiColorValues);
  }

  @override
  int get hashCode => Object.hash(
    localeCode,
    themeMode,
    themeColorMode,
    themeSeedColorValue,
    _stableMapHash(colorfulUiColorValues),
  );
}

int _stableMapHash(Map<String, int> values) {
  final keys = values.keys.toList()..sort();
  return Object.hashAll([
    for (final key in keys) Object.hash(key, values[key]),
  ]);
}
