import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/timetable_provider.dart';
import '../services/agenda_notification_service.dart';
import '../services/agenda_coordinator.dart';
import '../widgets/sked_dropdown_menu.dart';
import '../widgets/settings_list.dart';
import '../widgets/ui_command.dart';

/// Application-wide notification and productivity integration settings.
///
/// Platform capabilities are intentionally queried through injectable services
/// so this page remains safe to render in desktop previews and widget tests.
class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({
    super.key,
    this.notificationService,
    this.agendaCoordinator,
  });

  final AgendaNotificationService? notificationService;
  final AgendaCoordinator? agendaCoordinator;

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage>
    with WidgetsBindingObserver, UiCommandRunner<NotificationSettingsPage> {
  late final AgendaNotificationService _notificationService;
  AgendaCoordinator? _agendaCoordinator;

  bool _permissionLoading = false;
  bool? _notificationsPermissionGranted;
  bool? _exactAlarmAllowed;
  bool _permissionError = false;
  Future<void>? _permissionRefreshOperation;

  @override
  void initState() {
    super.initState();
    _notificationService =
        widget.notificationService ?? AgendaNotificationService();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refreshPermissionState());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _agendaCoordinator ??= widget.agendaCoordinator ?? _readAgendaCoordinator();
  }

  AgendaCoordinator? _readAgendaCoordinator() {
    try {
      return context.read<AgendaCoordinator>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshPermissionState());
    }
  }

  Future<void> _refreshPermissionState() {
    if (!_notificationService.isSupported) return Future<void>.value();
    final current = _permissionRefreshOperation;
    if (current != null) return current;
    final operation = _refreshPermissionStateNow();
    _permissionRefreshOperation = operation;
    return operation.whenComplete(() {
      if (identical(_permissionRefreshOperation, operation)) {
        _permissionRefreshOperation = null;
      }
    });
  }

  Future<void> _refreshPermissionStateNow() async {
    if (mounted) {
      setState(() {
        _permissionLoading = true;
        _permissionError = false;
      });
    }
    try {
      final gateway = _notificationService.gateway;
      final notificationsEnabled = await gateway.notificationsEnabled;
      final exactAlarmsAllowed = await gateway.exactAlarmsAllowed;
      if (!mounted) return;
      // Opening Android's permission settings is asynchronous.  The first
      // reconciliation runs before the user makes a choice, so detect a
      // later, known permission change on resume and rebuild the platform
      // plan with the newly granted (or revoked) capability.
      final permissionChanged =
          _notificationsPermissionGranted != null &&
          _notificationsPermissionGranted != notificationsEnabled;
      final exactAlarmChanged =
          _exactAlarmAllowed != null &&
          _exactAlarmAllowed != exactAlarmsAllowed;
      setState(() {
        _notificationsPermissionGranted = notificationsEnabled;
        _exactAlarmAllowed = exactAlarmsAllowed;
        _permissionLoading = false;
        _permissionError = false;
      });
      if (permissionChanged || exactAlarmChanged) {
        await _agendaCoordinator?.reconcileNow();
      }
    } catch (error, stackTrace) {
      debugPrint(
        'Refreshing notification permission state failed: '
        '$error\n$stackTrace',
      );
      if (!mounted) return;
      setState(() {
        _permissionLoading = false;
        _permissionError = true;
      });
    }
  }

  void _updateSetting(String debugLabel, Future<void> Function() command) {
    unawaited(runUiCommand(debugLabel: debugLabel, command: command));
  }

  Future<void> _setNotificationsEnabled(
    TimetableProvider provider,
    bool value,
  ) async {
    if (uiCommandBusy) return;
    await runUiCommand(
      debugLabel: 'Update notifications enabled',
      command: () async {
        await provider.updateNotificationsEnabled(value);
        if (!value || !_notificationService.isSupported) return;
        try {
          await _notificationService.gateway.requestPermission();
          await _agendaCoordinator?.reconcileNow();
        } catch (error, stackTrace) {
          // The setting itself is durable even when a platform permission
          // request is unavailable. The status row exposes a retry path.
          debugPrint(
            'Requesting notification permission after enabling failed: '
            '$error\n$stackTrace',
          );
        }
      },
    );
    await _refreshPermissionState();
  }

  Future<void> _handleNotificationPermission() async {
    if (!_notificationService.isSupported || uiCommandBusy) return;
    setState(() {
      _permissionLoading = true;
      _permissionError = false;
    });
    final granted = _notificationsPermissionGranted == true;
    await runUiCommand(
      debugLabel: granted
          ? 'Open notification settings'
          : 'Request notification permission',
      command: () async {
        final gateway = _notificationService.gateway;
        if (granted) {
          final opened = await gateway.openNotificationSettings();
          if (!opened) {
            throw StateError('Notification settings could not be opened.');
          }
        } else {
          await gateway.requestPermission();
          await _agendaCoordinator?.reconcileNow();
        }
      },
    );
    await _refreshPermissionState();
  }

  Future<void> _requestExactAlarmPermission() async {
    if (!_notificationService.isSupported || uiCommandBusy) return;
    setState(() {
      _permissionLoading = true;
      _permissionError = false;
    });
    await runUiCommand(
      debugLabel: 'Request exact alarm permission',
      command: () async {
        await _notificationService.gateway.requestExactAlarmPermission();
        await _agendaCoordinator?.reconcileNow();
      },
    );
    await _refreshPermissionState();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Consumer<TimetableProvider>(
      builder: (context, provider, child) {
        final permissionActionLabel = _notificationsPermissionGranted == true
            ? l10n.notificationPermissionOpenSettings
            : l10n.notificationPermissionRequest;
        final permissionSubtitle = _permissionSubtitle(l10n);
        final exactAlarmSubtitle = _exactAlarmSubtitle(l10n);
        final children = <Widget>[
          SettingsSectionHeader(title: l10n.notificationSettingsSection),
          SettingsSwitchTile(
            key: const ValueKey('notification-settings-enabled'),
            icon: Icons.notifications_active_outlined,
            value: provider.notificationsEnabled,
            title: l10n.notificationSettingsEnabled,
            subtitle: l10n.notificationSettingsEnabledHint,
            onChanged: uiCommandBusy
                ? null
                : (value) =>
                      unawaited(_setNotificationsEnabled(provider, value)),
          ),
          SettingsSectionHeader(title: l10n.notificationDefaultsSection),
          _buildReminderDropdown(
            key: const ValueKey('notification-course-default-reminder'),
            label: l10n.notificationCourseDefaultReminder,
            icon: Icons.school_outlined,
            value: provider.courseDefaultReminderMinutesBefore,
            l10n: l10n,
            onChanged: (minutes) => _updateSetting(
              'Update course default reminder',
              () => provider.updateCourseDefaultReminder(minutes),
            ),
          ),
          const SizedBox(height: 12),
          _buildReminderDropdown(
            key: const ValueKey('notification-general-default-reminder'),
            label: l10n.notificationGeneralDefaultReminder,
            icon: Icons.event_outlined,
            value: provider.generalDefaultReminderMinutesBefore,
            l10n: l10n,
            onChanged: (minutes) => _updateSetting(
              'Update general default reminder',
              () => provider.updateGeneralDefaultReminder(minutes),
            ),
          ),
          SettingsSectionHeader(title: l10n.notificationPermission),
          SettingsConnectedTile(
            key: const ValueKey('notification-permission'),
            leading: const Icon(Icons.notifications_outlined),
            title: l10n.notificationPermission,
            subtitle: permissionSubtitle,
            trailing: IconButton(
              key: const ValueKey('notification-permission-action'),
              tooltip: permissionActionLabel,
              onPressed:
                  _notificationService.isSupported &&
                      !uiCommandBusy &&
                      !_permissionLoading
                  ? _handleNotificationPermission
                  : null,
              icon: Icon(
                _notificationsPermissionGranted == true
                    ? Icons.settings_outlined
                    : Icons.lock_open_outlined,
              ),
            ),
            onTap:
                _notificationService.isSupported &&
                    !uiCommandBusy &&
                    !_permissionLoading
                ? _handleNotificationPermission
                : null,
          ),
          if (_notificationService.isSupported)
            SettingsConnectedTile(
              key: const ValueKey('notification-exact-alarm'),
              leading: const Icon(Icons.alarm_outlined),
              title: l10n.notificationExactAlarm,
              subtitle: exactAlarmSubtitle,
              trailing: IconButton(
                key: const ValueKey('notification-exact-alarm-action'),
                tooltip: l10n.notificationExactAlarmRequest,
                onPressed:
                    uiCommandBusy ||
                        _permissionLoading ||
                        _exactAlarmAllowed == true
                    ? null
                    : _requestExactAlarmPermission,
                icon: const Icon(Icons.open_in_new),
              ),
              onTap:
                  uiCommandBusy ||
                      _permissionLoading ||
                      _exactAlarmAllowed == true
                  ? null
                  : _requestExactAlarmPermission,
            ),
          SettingsSwitchTile(
            key: const ValueKey('notification-lock-screen-titles'),
            icon: Icons.lock_outline,
            value: provider.lockScreenShowTitles,
            title: l10n.notificationLockScreenTitles,
            subtitle: l10n.notificationLockScreenTitlesHint,
            onChanged: uiCommandBusy
                ? null
                : (value) => _updateSetting(
                    'Update lock screen notification titles',
                    () => provider.updateLockScreenShowTitles(value),
                  ),
          ),
        ];
        return PopScope<void>(
          canPop: !uiCommandBusy,
          child: Scaffold(
            appBar: AppBar(title: Text(l10n.notificationSettingsSection)),
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
                      child: ResponsiveSettingsSingleColumnBody(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: children,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReminderDropdown({
    required Key key,
    required String label,
    required IconData icon,
    required int? value,
    required AppLocalizations l10n,
    required ValueChanged<int?> onChanged,
  }) {
    final currentSelection = _selectionForMinutes(value);
    final entries = _reminderEntries(l10n, value);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SkedDropdownMenu<int>(
        key: key,
        initialSelection: currentSelection,
        label: Text(label),
        leadingIcon: Icon(icon),
        expandedInsets: EdgeInsets.zero,
        enabled: !uiCommandBusy,
        dropdownMenuEntries: entries,
        onSelected: (selection) {
          if (selection == null) return;
          onChanged(_minutesForSelection(selection));
        },
      ),
    );
  }

  List<DropdownMenuEntry<int>> _reminderEntries(
    AppLocalizations l10n,
    int? current,
  ) {
    final entries = <DropdownMenuEntry<int>>[
      DropdownMenuEntry(value: -1, label: l10n.notificationReminderOff),
      DropdownMenuEntry(value: 0, label: l10n.reminderAtStart),
      DropdownMenuEntry(value: 5, label: l10n.reminderMinutesBefore(5)),
      DropdownMenuEntry(value: 10, label: l10n.reminderMinutesBefore(10)),
      DropdownMenuEntry(value: 15, label: l10n.reminderMinutesBefore(15)),
      DropdownMenuEntry(value: 30, label: l10n.reminderMinutesBefore(30)),
      DropdownMenuEntry(value: 60, label: l10n.reminderHourBefore),
      DropdownMenuEntry(value: 1440, label: l10n.reminderDayBefore),
    ];
    if (current != null && !entries.any((entry) => entry.value == current)) {
      entries.insert(
        1,
        DropdownMenuEntry(
          value: current,
          label: l10n.notificationReminderCustom(current),
        ),
      );
    }
    return entries;
  }

  String _permissionSubtitle(AppLocalizations l10n) {
    if (!_notificationService.isSupported) {
      return l10n.notificationPlatformUnsupported;
    }
    if (_permissionError) return l10n.notificationPermissionRequestFailed;
    if (_permissionLoading || _notificationsPermissionGranted == null) {
      return l10n.notificationPermissionChecking;
    }
    return _notificationsPermissionGranted == true
        ? l10n.notificationPermissionGranted
        : l10n.notificationPermissionDenied;
  }

  String _exactAlarmSubtitle(AppLocalizations l10n) {
    if (_permissionLoading || _exactAlarmAllowed == null) {
      return l10n.notificationPermissionChecking;
    }
    return _exactAlarmAllowed == true
        ? l10n.notificationExactAlarmAllowed
        : l10n.notificationExactAlarmRequired;
  }
}

int _selectionForMinutes(int? minutes) => minutes ?? -1;

int? _minutesForSelection(int selection) => selection < 0 ? null : selection;
