import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../l10n/app_locale.dart' as app_locale;
import '../l10n/app_localizations.dart';
import '../providers/timetable_provider.dart';
import '../services/agenda_coordinator.dart';
import '../services/agenda_notification_runtime_store.dart';
import '../services/agenda_notification_service.dart';
import '../services/android_productivity_bridge.dart';
import '../services/developer_sample_data_service.dart';
import '../widgets/settings_list.dart';
import '../widgets/ui_command.dart';

/// A deliberately unlinked toolbox for visual and interaction testing.
///
/// The route is only reachable through the long-press affordance in Settings;
/// no unlock state is stored in app data.
class DeveloperModePage extends StatefulWidget {
  const DeveloperModePage({
    super.key,
    this.agendaCoordinator,
    this.productivityBridge,
  });

  /// Injectable only for widget tests and previews. The application normally
  /// obtains the already-running coordinator from Provider.
  final AgendaCoordinator? agendaCoordinator;
  final AndroidProductivityBridge? productivityBridge;

  @override
  State<DeveloperModePage> createState() => _DeveloperModePageState();
}

class _DeveloperModePageState extends State<DeveloperModePage>
    with UiCommandRunner<DeveloperModePage> {
  late DeveloperSampleLanguage _language;
  late final AndroidProductivityBridge _productivityBridge;
  late final bool _ownsProductivityBridge;
  AgendaCoordinator? _agendaCoordinator;
  AndroidNotificationDiagnostics? _androidNotificationDiagnostics;
  AgendaNotificationDiagnostics? _agendaNotificationDiagnostics;
  AgendaNotificationTestChannel _testChannel =
      AgendaNotificationTestChannel.course;
  Future<void>? _diagnosticRefresh;
  var _diagnosticLoading = false;
  var _diagnosticInitialized = false;
  String? _diagnosticError;

  bool get _notificationsSupported => _productivityBridge.isSupported;

  bool get _notificationActionsEnabled =>
      _notificationsSupported &&
      _agendaCoordinator != null &&
      !_diagnosticLoading &&
      !uiCommandBusy;

  bool get _diagnosticRefreshEnabled =>
      _notificationsSupported && !_diagnosticLoading && !uiCommandBusy;

  @override
  void initState() {
    super.initState();
    _ownsProductivityBridge = widget.productivityBridge == null;
    _productivityBridge =
        widget.productivityBridge ?? AndroidProductivityBridge();
    _agendaCoordinator = widget.agendaCoordinator;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final code = app_locale.normalizeLocaleCode(
        context.read<TimetableProvider>().localeCode,
      );
      _language = code == 'zh' || code.startsWith('zh-')
          ? DeveloperSampleLanguage.simplifiedChinese
          : DeveloperSampleLanguage.english;
      _initialized = true;
    }
    _agendaCoordinator ??= _readAgendaCoordinator();
    if (!_diagnosticInitialized) {
      _diagnosticInitialized = true;
      unawaited(_refreshNotificationDiagnostics());
    }
  }

  var _initialized = false;

  AgendaCoordinator? _readAgendaCoordinator() {
    try {
      return context.read<AgendaCoordinator>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  @override
  void dispose() {
    if (_ownsProductivityBridge) _productivityBridge.dispose();
    super.dispose();
  }

  Future<void> _addSamples() async {
    final provider = context.read<TimetableProvider>();
    final completed = await runUiCommand(
      debugLabel: 'Add developer sample data',
      command: () => provider.addDeveloperSampleData(_language),
    );
    if (!completed || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).developerSampleDataAdded),
        ),
      );
  }

  Future<void> _refreshNotificationDiagnostics({bool maintenance = false}) {
    final active = _diagnosticRefresh;
    if (active != null) return active;
    final operation = _refreshNotificationDiagnosticsNow(
      maintenance: maintenance,
    );
    _diagnosticRefresh = operation;
    return operation.whenComplete(() {
      if (identical(_diagnosticRefresh, operation)) {
        _diagnosticRefresh = null;
      }
    });
  }

  Future<void> _refreshNotificationDiagnosticsNow({
    required bool maintenance,
  }) async {
    if (!mounted) return;
    setState(() {
      _diagnosticLoading = true;
      _diagnosticError = null;
    });
    try {
      if (!_notificationsSupported) {
        if (mounted) {
          setState(() {
            _androidNotificationDiagnostics =
                const AndroidNotificationDiagnostics.unsupported();
            _agendaNotificationDiagnostics = null;
          });
        }
        return;
      }
      final coordinator = _agendaCoordinator;
      if (maintenance && coordinator != null) {
        await coordinator.runNotificationMaintenance();
      }
      // Channel creation is lazy. Read Android state after a maintenance pass
      // so the diagnostic panel reflects channels created by that same pass.
      final android = await _productivityBridge.notificationDiagnostics();
      final agenda = coordinator == null
          ? null
          : await coordinator.notificationDiagnostics();
      if (!mounted) return;
      setState(() {
        _agendaNotificationDiagnostics = agenda;
        _androidNotificationDiagnostics = android;
      });
    } catch (error, stackTrace) {
      debugPrint(
        'Refreshing developer notification diagnostics failed: '
        '$error\n$stackTrace',
      );
      if (mounted) setState(() => _diagnosticError = error.toString());
    } finally {
      if (mounted) setState(() => _diagnosticLoading = false);
    }
  }

  Future<void> _runNotificationMaintenance() async {
    if (!_notificationActionsEnabled) return;
    final coordinator = _agendaCoordinator;
    if (coordinator == null) return;
    final completed = await runUiCommand(
      debugLabel: 'Rebuild notification plan from developer mode',
      command: () async {
        await coordinator.runNotificationMaintenance();
        await _refreshNotificationDiagnostics();
      },
    );
    if (!completed || !mounted) return;
    _showSnackBar(
      AppLocalizations.of(context).developerNotificationMaintenanceComplete,
    );
  }

  Future<void> _sendImmediateNotificationTest() async {
    if (!_notificationActionsEnabled) return;
    final coordinator = _agendaCoordinator;
    if (coordinator == null) return;
    final block = await _refreshNotificationTestBlock();
    if (block != null || !mounted) {
      if (mounted && block != null) {
        _showSnackBar(
          _notificationTestBlockMessage(AppLocalizations.of(context), block),
        );
      }
      return;
    }
    final completed = await runUiCommand(
      debugLabel: 'Send immediate developer notification test',
      command: () async {
        await coordinator.showImmediateNotificationTest(_testChannel);
        await _refreshNotificationDiagnostics();
      },
    );
    if (!completed || !mounted) return;
    _showSnackBar(
      AppLocalizations.of(context).developerNotificationImmediateQueued,
    );
  }

  Future<void> _scheduleThirtySecondNotificationTest() async {
    if (!_notificationActionsEnabled) return;
    final coordinator = _agendaCoordinator;
    if (coordinator == null) return;
    final block = await _refreshNotificationTestBlock();
    if (block != null || !mounted) {
      if (mounted && block != null) {
        _showSnackBar(
          _notificationTestBlockMessage(AppLocalizations.of(context), block),
        );
      }
      return;
    }
    final completed = await runUiCommand(
      debugLabel: 'Schedule 30-second developer notification test',
      command: () async {
        await coordinator.scheduleThirtySecondNotificationTest(_testChannel);
        await _refreshNotificationDiagnostics();
      },
    );
    if (!completed || !mounted) return;
    _showSnackBar(
      AppLocalizations.of(context).developerNotificationThirtySecondQueued,
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<_NotificationTestBlock?> _refreshNotificationTestBlock() async {
    if (!_notificationsSupported) return _NotificationTestBlock.unsupported;
    try {
      final android = await _productivityBridge.notificationDiagnostics();
      if (mounted) {
        setState(() {
          _androidNotificationDiagnostics = android;
          _diagnosticError = null;
        });
      }
      return _notificationTestBlock(android);
    } catch (error, stackTrace) {
      debugPrint(
        'Refreshing developer notification test status failed: '
        '$error\n$stackTrace',
      );
      if (mounted) setState(() => _diagnosticError = error.toString());
      return _NotificationTestBlock.statusUnavailable;
    }
  }

  _NotificationTestBlock? _notificationTestBlock(
    AndroidNotificationDiagnostics? android,
  ) {
    if (!_notificationsSupported) return _NotificationTestBlock.unsupported;
    if (_agendaCoordinator == null) {
      return _NotificationTestBlock.coordinatorUnavailable;
    }
    if (android == null) return _NotificationTestBlock.statusUnavailable;
    if (!android.appNotificationsEnabled || !android.postNotificationsGranted) {
      return _NotificationTestBlock.systemNotificationsBlocked;
    }
    final channel = _selectedChannelState(android);
    if (channel?.exists == true && !channel!.enabled) {
      return _NotificationTestBlock.channelBlocked;
    }
    return null;
  }

  AndroidNotificationChannelState? _selectedChannelState(
    AndroidNotificationDiagnostics? android,
  ) {
    final id = switch (_testChannel) {
      AgendaNotificationTestChannel.course => _courseReminderChannelId,
      AgendaNotificationTestChannel.schedule => _scheduleReminderChannelId,
    };
    for (final channel
        in android?.channels ?? const <AndroidNotificationChannelState>[]) {
      if (channel.id == id) return channel;
    }
    return null;
  }

  String _notificationTestBlockMessage(
    AppLocalizations l10n,
    _NotificationTestBlock block,
  ) {
    return switch (block) {
      _NotificationTestBlock.unsupported =>
        l10n.developerNotificationUnsupported,
      _NotificationTestBlock.coordinatorUnavailable =>
        l10n.developerNotificationCoordinatorUnavailable,
      _NotificationTestBlock.statusUnavailable =>
        l10n.developerNotificationTestChecking,
      _NotificationTestBlock.systemNotificationsBlocked =>
        l10n.developerNotificationTestBlockedSystem,
      _NotificationTestBlock.channelBlocked =>
        l10n.developerNotificationTestBlockedChannel,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final appNotificationsEnabled = context
        .watch<TimetableProvider>()
        .notificationsEnabled;
    return PopScope<void>(
      canPop: !uiCommandBusy,
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.developerModeTitle)),
        body: Column(
          children: [
            UiCommandBusyIndicator(
              busy: uiCommandBusy,
              semanticsKey: const ValueKey('developer-mode-busy'),
            ),
            Expanded(
              child: ResponsiveSettingsSingleColumnBody(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Text(
                        l10n.developerModeDescription,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SettingsSectionHeader(title: l10n.developerSampleLanguage),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SegmentedButton<DeveloperSampleLanguage>(
                        key: const ValueKey('developer-sample-language'),
                        segments: [
                          ButtonSegment(
                            value: DeveloperSampleLanguage.simplifiedChinese,
                            label: Text(l10n.developerSampleChinese),
                          ),
                          ButtonSegment(
                            value: DeveloperSampleLanguage.english,
                            label: Text(l10n.developerSampleEnglish),
                          ),
                        ],
                        selected: {_language},
                        expandedInsets: EdgeInsets.zero,
                        onSelectionChanged: uiCommandBusy
                            ? null
                            : (selection) {
                                if (selection.isEmpty) return;
                                setState(() => _language = selection.first);
                              },
                      ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            l10n.developerSampleDataDescription,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            key: const ValueKey('developer-add-sample-data'),
                            onPressed: uiCommandBusy ? null : _addSamples,
                            icon: const Icon(Icons.dataset_outlined),
                            label: Text(l10n.developerAddSampleData),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(48, 48),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildNotificationDiagnostics(
                      l10n,
                      appNotificationsEnabled: appNotificationsEnabled,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationDiagnostics(
    AppLocalizations l10n, {
    required bool appNotificationsEnabled,
  }) {
    final android = _androidNotificationDiagnostics;
    final agenda = _agendaNotificationDiagnostics;
    final diagnosticError = _diagnosticError;
    final coordinator = _agendaCoordinator;
    final statusLoading = _diagnosticLoading && android == null;
    final systemNotificationsEnabled = android?.appNotificationsEnabled;
    final postNotificationsGranted = android?.postNotificationsGranted;
    final exactAlarmsAllowed = android?.exactAlarmsAllowed;
    final statusText =
        systemNotificationsEnabled == null || postNotificationsGranted == null
        ? l10n.notificationPermissionChecking
        : systemNotificationsEnabled && postNotificationsGranted
        ? l10n.developerNotificationPermissionAllowed
        : l10n.developerNotificationPermissionBlocked;
    final exactText = exactAlarmsAllowed == null
        ? l10n.notificationPermissionChecking
        : exactAlarmsAllowed
        ? l10n.developerNotificationExactAlarmAllowed
        : l10n.developerNotificationExactAlarmInexact;
    final channels = _notificationChannels(l10n, android);
    final selectedChannelBlock = _notificationTestBlock(android);
    final testEnabled =
        _notificationActionsEnabled && selectedChannelBlock == null;
    final testBlockMessage = selectedChannelBlock == null
        ? null
        : _notificationTestBlockMessage(l10n, selectedChannelBlock);
    final nextReminder = _nextReminder(agenda);
    final now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSectionHeader(title: l10n.developerNotificationDiagnostics),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            l10n.developerNotificationDiagnosticsDescription,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        const SizedBox(height: 10),
        if (!_notificationsSupported)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              l10n.developerNotificationUnsupported,
              key: const ValueKey('developer-notification-unsupported'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else ...[
          if (coordinator == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                l10n.developerNotificationCoordinatorUnavailable,
                key: const ValueKey(
                  'developer-notification-coordinator-unavailable',
                ),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          SettingsConnectedGroup(
            children: [
              SettingsConnectedTile(
                key: const ValueKey('developer-notification-app-switch-status'),
                leading: const Icon(Icons.tune_outlined),
                title: l10n.developerNotificationAppSwitch,
                subtitle: appNotificationsEnabled
                    ? l10n.developerNotificationAppSwitchEnabled
                    : l10n.developerNotificationAppSwitchDisabled,
                trailing: Icon(
                  appNotificationsEnabled
                      ? Icons.toggle_on_outlined
                      : Icons.toggle_off_outlined,
                ),
                onTap: _diagnosticRefreshEnabled
                    ? () => unawaited(_refreshNotificationDiagnostics())
                    : null,
              ),
              SettingsConnectedTile(
                key: const ValueKey('developer-notification-system-status'),
                leading: const Icon(Icons.notifications_outlined),
                title: l10n.developerNotificationSystemStatus,
                subtitle: statusText,
                onTap: _diagnosticLoading
                    ? null
                    : () => unawaited(_refreshNotificationDiagnostics()),
              ),
              SettingsConnectedTile(
                key: const ValueKey(
                  'developer-notification-exact-alarm-status',
                ),
                leading: const Icon(Icons.alarm_outlined),
                title: l10n.developerNotificationExactAlarm,
                subtitle: exactText,
                onTap: _diagnosticLoading
                    ? null
                    : () => unawaited(_refreshNotificationDiagnostics()),
              ),
              SettingsConnectedTile(
                key: const ValueKey('developer-notification-time-zone'),
                leading: const Icon(Icons.public_outlined),
                title: l10n.developerNotificationTimeZone,
                subtitle: _timeZoneLabel(l10n, now),
                onTap: _diagnosticRefreshEnabled
                    ? () => unawaited(_refreshNotificationDiagnostics())
                    : null,
              ),
              SettingsConnectedTile(
                key: const ValueKey('developer-notification-plan-status'),
                leading: const Icon(Icons.schedule_outlined),
                title: l10n.developerNotificationPlan,
                subtitle: agenda == null
                    ? l10n.developerNotificationNoDiagnostic
                    : l10n.developerNotificationPlanSummary(
                        agenda.scheduledCount,
                        agenda.plannedCount,
                      ),
                onTap: _diagnosticLoading
                    ? null
                    : () => unawaited(_refreshNotificationDiagnostics()),
              ),
              if (agenda != null &&
                  agenda.platformPendingCount != null &&
                  agenda.platformActiveCount != null)
                SettingsConnectedTile(
                  key: const ValueKey('developer-notification-platform-state'),
                  leading: const Icon(Icons.devices_outlined),
                  title: l10n.developerNotificationPlan,
                  subtitle:
                      '${l10n.developerNotificationPlatformState(agenda.platformPendingCount!, agenda.platformActiveCount!)}${_nativeActiveNotificationSuffix(l10n, android)}',
                  onTap: _diagnosticRefreshEnabled
                      ? () => unawaited(_refreshNotificationDiagnostics())
                      : null,
                ),
              SettingsConnectedTile(
                key: const ValueKey('developer-notification-next-reminder'),
                leading: const Icon(Icons.notifications_active_outlined),
                title: l10n.developerNotificationNextReminder,
                subtitle: nextReminder == null
                    ? l10n.developerNotificationNoPendingReminder
                    : _formatDateTime(context, nextReminder.fireAt),
                onTap: _diagnosticRefreshEnabled
                    ? () => unawaited(_refreshNotificationDiagnostics())
                    : null,
              ),
              SettingsConnectedTile(
                key: const ValueKey('developer-notification-next-maintenance'),
                leading: const Icon(Icons.event_repeat_outlined),
                title: l10n.developerNotificationNextMaintenance,
                subtitle: agenda?.nextMaintenanceAt == null
                    ? l10n.developerNotificationNoMaintenance
                    : _formatDateTime(context, agenda!.nextMaintenanceAt!),
                onTap: _diagnosticRefreshEnabled
                    ? () => unawaited(_refreshNotificationDiagnostics())
                    : null,
              ),
              SettingsConnectedTile(
                key: const ValueKey('developer-notification-truncation'),
                leading: const Icon(Icons.filter_list_off_outlined),
                title: l10n.developerNotificationTruncation,
                subtitle: agenda == null
                    ? l10n.developerNotificationNoDiagnostic
                    : l10n.developerNotificationTruncationCount(
                        agenda.truncatedCount,
                      ),
                onTap: _diagnosticRefreshEnabled
                    ? () => unawaited(_refreshNotificationDiagnostics())
                    : null,
              ),
              SettingsConnectedTile(
                key: const ValueKey('developer-notification-last-reconcile'),
                leading: const Icon(Icons.history_outlined),
                title: l10n.developerNotificationLastReconciliation,
                subtitle: agenda == null
                    ? l10n.developerNotificationNoDiagnostic
                    : l10n.developerNotificationReconciliationSummary(
                        _reconcileOriginLabel(l10n, agenda.origin),
                        _reconcileModeLabel(l10n, agenda.mode),
                        _reconcileResultLabel(l10n, agenda.result),
                        _formatDateTime(context, agenda.recordedAt),
                      ),
                onTap: _diagnosticRefreshEnabled
                    ? () => unawaited(_refreshNotificationDiagnostics())
                    : null,
              ),
              if (agenda?.error case final error? when error.isNotEmpty)
                SettingsConnectedTile(
                  key: const ValueKey('developer-notification-plan-error'),
                  leading: const Icon(Icons.error_outline),
                  title: l10n.developerNotificationPlan,
                  subtitle: l10n.developerNotificationPlanError(error),
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
              if (diagnosticError case final error? when error.isNotEmpty)
                SettingsConnectedTile(
                  key: const ValueKey(
                    'developer-notification-diagnostic-error',
                  ),
                  leading: const Icon(Icons.error_outline),
                  title: l10n.developerNotificationDiagnostics,
                  subtitle: l10n.developerNotificationPlanError(error),
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
            ],
          ),
          if (!statusLoading)
            SettingsConnectedGroup(
              children: [
                for (final channel in channels)
                  SettingsConnectedTile(
                    key: ValueKey(
                      'developer-notification-channel-${channel.id}',
                    ),
                    leading: Icon(
                      channel.state == null || !channel.state!.exists
                          ? Icons.notifications_none_outlined
                          : channel.state!.enabled
                          ? Icons.notifications_active_outlined
                          : Icons.notifications_off_outlined,
                    ),
                    title: channel.name,
                    subtitle: _channelSummary(l10n, channel.state),
                  ),
              ],
            ),
        ],
        _NotificationDiagnosticActions(
          selectedChannel: _testChannel,
          channelSelectionEnabled: _notificationActionsEnabled,
          testEnabled: testEnabled,
          maintenanceEnabled: _notificationActionsEnabled,
          refreshEnabled: _diagnosticRefreshEnabled,
          testBlockMessage: testBlockMessage,
          l10n: l10n,
          onChannelChanged: (channel) {
            if (uiCommandBusy || _diagnosticLoading) return;
            setState(() => _testChannel = channel);
          },
          onRefresh: () => unawaited(_refreshNotificationDiagnostics()),
          onMaintenance: () => unawaited(_runNotificationMaintenance()),
          onImmediateTest: () => unawaited(_sendImmediateNotificationTest()),
          onDelayedTest: () =>
              unawaited(_scheduleThirtySecondNotificationTest()),
        ),
      ],
    );
  }

  String _nativeActiveNotificationSuffix(
    AppLocalizations l10n,
    AndroidNotificationDiagnostics? diagnostics,
  ) {
    final active = diagnostics?.activeNotifications ?? const [];
    if (active.isEmpty) return '';
    final latest = active.reduce(
      (left, right) =>
          left.postTimeMillis >= right.postTimeMillis ? left : right,
    );
    final time = DateTime.fromMillisecondsSinceEpoch(latest.postTimeMillis)
        .toLocal();
    return ' · ${l10n.developerNotificationNativeLastPosted(time.toString())}';
  }

  List<_NotificationChannelPresentation> _notificationChannels(
    AppLocalizations l10n,
    AndroidNotificationDiagnostics? android,
  ) {
    final statesById = <String, AndroidNotificationChannelState>{
      for (final channel
          in android?.channels ?? const <AndroidNotificationChannelState>[])
        channel.id: channel,
    };
    final channels = <_NotificationChannelPresentation>[
      _NotificationChannelPresentation(
        id: _courseReminderChannelId,
        name: l10n.developerNotificationTestCourse,
        state: statesById.remove(_courseReminderChannelId),
      ),
      _NotificationChannelPresentation(
        id: _scheduleReminderChannelId,
        name: l10n.developerNotificationTestSchedule,
        state: statesById.remove(_scheduleReminderChannelId),
      ),
    ];
    for (final state in statesById.values) {
      channels.add(
        _NotificationChannelPresentation(
          id: state.id,
          name: state.name,
          state: state,
        ),
      );
    }
    return channels;
  }

  AgendaNotificationDiagnosticPlanItem? _nextReminder(
    AgendaNotificationDiagnostics? diagnostics,
  ) {
    if (diagnostics == null) return null;
    final now = DateTime.now();
    AgendaNotificationDiagnosticPlanItem? next;
    for (final item in diagnostics.plan) {
      if (item.fireAt.isBefore(now)) continue;
      if (next == null || item.fireAt.isBefore(next.fireAt)) next = item;
    }
    return next;
  }

  String _channelSummary(
    AppLocalizations l10n,
    AndroidNotificationChannelState? channel,
  ) {
    if (channel == null || !channel.exists) {
      return l10n.developerNotificationChannelNotCreated;
    }
    final state = channel.enabled
        ? l10n.developerNotificationChannelEnabledState
        : l10n.developerNotificationChannelBlockedState;
    final importance = channel.importance == null
        ? l10n.developerNotificationChannelImportanceUnavailable
        : l10n.developerNotificationChannelImportance(channel.importance!);
    return l10n.developerNotificationChannelSummary(state, importance);
  }

  String _timeZoneLabel(AppLocalizations l10n, DateTime now) {
    final offset = now.timeZoneOffset;
    final totalMinutes = offset.inMinutes.abs();
    final hours = (totalMinutes ~/ 60).toString().padLeft(2, '0');
    final minutes = (totalMinutes % 60).toString().padLeft(2, '0');
    final sign = offset.isNegative ? '-' : '+';
    return l10n.developerNotificationTimeZoneValue(
      now.timeZoneName,
      '$sign$hours:$minutes',
    );
  }

  String _formatDateTime(BuildContext context, DateTime value) {
    final local = value.toLocal();
    final material = MaterialLocalizations.of(context);
    return '${material.formatMediumDate(local)} '
        '${material.formatTimeOfDay(TimeOfDay.fromDateTime(local), alwaysUse24HourFormat: MediaQuery.of(context).alwaysUse24HourFormat)}';
  }

  String _reconcileOriginLabel(
    AppLocalizations l10n,
    AgendaNotificationReconcileOrigin origin,
  ) {
    return switch (origin) {
      AgendaNotificationReconcileOrigin.foreground =>
        l10n.developerNotificationReconcileOriginForeground,
      AgendaNotificationReconcileOrigin.background =>
        l10n.developerNotificationReconcileOriginBackground,
    };
  }

  String _reconcileModeLabel(
    AppLocalizations l10n,
    AgendaNotificationReconcileMode mode,
  ) {
    return switch (mode) {
      AgendaNotificationReconcileMode.authoritative =>
        l10n.developerNotificationReconcileModeAuthoritative,
      AgendaNotificationReconcileMode.maintenance =>
        l10n.developerNotificationReconcileModeMaintenance,
    };
  }

  String _reconcileResultLabel(
    AppLocalizations l10n,
    AgendaNotificationDiagnosticResult result,
  ) {
    return switch (result) {
      AgendaNotificationDiagnosticResult.success =>
        l10n.developerNotificationReconcileResultSuccess,
      AgendaNotificationDiagnosticResult.skipped =>
        l10n.developerNotificationReconcileResultSkipped,
      AgendaNotificationDiagnosticResult.failed =>
        l10n.developerNotificationReconcileResultFailed,
    };
  }
}

class _NotificationDiagnosticActions extends StatelessWidget {
  const _NotificationDiagnosticActions({
    required this.selectedChannel,
    required this.channelSelectionEnabled,
    required this.testEnabled,
    required this.maintenanceEnabled,
    required this.refreshEnabled,
    required this.testBlockMessage,
    required this.l10n,
    required this.onChannelChanged,
    required this.onRefresh,
    required this.onMaintenance,
    required this.onImmediateTest,
    required this.onDelayedTest,
  });

  final AgendaNotificationTestChannel selectedChannel;
  final bool channelSelectionEnabled;
  final bool testEnabled;
  final bool maintenanceEnabled;
  final bool refreshEnabled;
  final String? testBlockMessage;
  final AppLocalizations l10n;
  final ValueChanged<AgendaNotificationTestChannel> onChannelChanged;
  final VoidCallback onRefresh;
  final VoidCallback onMaintenance;
  final VoidCallback onImmediateTest;
  final VoidCallback onDelayedTest;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.developerNotificationTestChannel),
          const SizedBox(height: 8),
          SegmentedButton<AgendaNotificationTestChannel>(
            key: const ValueKey('developer-notification-test-channel'),
            expandedInsets: EdgeInsets.zero,
            selected: {selectedChannel},
            onSelectionChanged: channelSelectionEnabled
                ? (selection) {
                    if (selection.isNotEmpty) onChannelChanged(selection.first);
                  }
                : null,
            segments: [
              ButtonSegment(
                value: AgendaNotificationTestChannel.course,
                label: Text(l10n.developerNotificationTestCourse),
                icon: const Icon(Icons.school_outlined),
              ),
              ButtonSegment(
                value: AgendaNotificationTestChannel.schedule,
                label: Text(l10n.developerNotificationTestSchedule),
                icon: const Icon(Icons.event_outlined),
              ),
            ],
          ),
          if (testBlockMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              testBlockMessage!,
              key: const ValueKey('developer-notification-test-blocked'),
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final useColumn = constraints.maxWidth < 440;
              final actions = [
                FilledButton.icon(
                  key: const ValueKey('developer-notification-immediate-test'),
                  onPressed: testEnabled ? onImmediateTest : null,
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: Text(l10n.developerNotificationImmediateTest),
                ),
                OutlinedButton.icon(
                  key: const ValueKey(
                    'developer-notification-thirty-second-test',
                  ),
                  onPressed: testEnabled ? onDelayedTest : null,
                  icon: const Icon(Icons.timer_outlined),
                  label: Text(l10n.developerNotificationThirtySecondTest),
                ),
              ];
              if (useColumn) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [actions[0], const SizedBox(height: 8), actions[1]],
                );
              }
              return Row(
                children: [
                  Expanded(child: actions[0]),
                  const SizedBox(width: 12),
                  Expanded(child: actions[1]),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            key: const ValueKey('developer-notification-maintenance'),
            onPressed: maintenanceEnabled ? onMaintenance : null,
            icon: const Icon(Icons.sync_outlined),
            label: Text(l10n.developerNotificationRunMaintenance),
          ),
          TextButton.icon(
            key: const ValueKey('developer-notification-refresh'),
            onPressed: refreshEnabled ? onRefresh : null,
            icon: const Icon(Icons.refresh_outlined),
            label: Text(l10n.developerNotificationRefresh),
          ),
        ],
      ),
    );
  }
}

enum _NotificationTestBlock {
  unsupported,
  coordinatorUnavailable,
  statusUnavailable,
  systemNotificationsBlocked,
  channelBlocked,
}

class _NotificationChannelPresentation {
  const _NotificationChannelPresentation({
    required this.id,
    required this.name,
    required this.state,
  });

  final String id;
  final String name;
  final AndroidNotificationChannelState? state;
}

const _courseReminderChannelId = 'sked_course_reminders';
const _scheduleReminderChannelId = 'sked_schedule_reminders';
