import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/timetable_models.dart';
import '../providers/timetable_provider.dart';
import '../screens/notification_settings_page.dart';
import '../services/agenda_coordinator.dart';
import '../services/agenda_notification_service.dart';
import 'workbench_chrome_metrics.dart';
import 'sked_dropdown_menu.dart';

/// Course-specific overrides of the system notification default. The controls
/// only edit the parent draft; permission reads never schedule notifications.
class CourseSystemReminderField extends StatefulWidget {
  const CourseSystemReminderField({
    super.key,
    required this.behavior,
    required this.minutesController,
    required this.onChanged,
    this.enabled = true,
    this.notificationService,
  });
  final CourseReminderBehavior behavior;
  final TextEditingController minutesController;
  final ValueChanged<CourseReminderBehavior> onChanged;
  final bool enabled;
  final AgendaNotificationService? notificationService;
  @override
  State<CourseSystemReminderField> createState() =>
      _CourseSystemReminderFieldState();
}

class _CourseSystemReminderFieldState extends State<CourseSystemReminderField>
    with WidgetsBindingObserver {
  AgendaNotificationService? _service;
  bool? _permission;
  bool? _exact;
  bool? _battery;
  bool _loading = false;
  bool _error = false;
  bool _settingsOpen = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next =
        widget.notificationService ??
        context.read<AgendaCoordinator?>()?.notificationService;
    if (identical(next, _service)) return;
    _service = next;
    unawaited(_refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _refresh() async {
    final service = _service;
    if (_loading || service == null || !service.isSupported) return;
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final gateway = service.gateway;
      final permission = await gateway.notificationsEnabled;
      final exact = await gateway.exactAlarmsAllowed;
      final battery = gateway is AgendaNotificationBatteryOptimizationGateway
          ? await (gateway as AgendaNotificationBatteryOptimizationGateway)
                .batteryOptimizationIgnored
          : true;
      if (!mounted || !identical(service, _service)) return;
      setState(() {
        _permission = permission;
        _exact = exact;
        _battery = battery;
      });
    } catch (_) {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openSettings() async {
    if (_settingsOpen || !widget.enabled) return;
    _settingsOpen = true;
    try {
      final provider = context.read<TimetableProvider?>();
      if (provider == null) return;
      FocusManager.instance.primaryFocus?.unfocus();
      await Navigator.of(context, rootNavigator: true).push<void>(
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider.value(
            value: provider,
            child: NotificationSettingsPage(notificationService: _service),
          ),
        ),
      );
      if (mounted) await _refresh();
    } finally {
      _settingsOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final provider = context.watch<TimetableProvider?>();
    final settings =
        provider?.appData.notificationSettings ?? const NotificationSettings();
    final defaultMinutes = settings.courseDefaultMinutesBefore;
    final inherited = l.courseReminderInherit(
      defaultMinutes == null
          ? l.notificationReminderOff
          : l.notificationReminderCustom(defaultMinutes),
    );
    final warnings = <String>[
      if (!settings.enabled) l.courseReminderMasterOff,
      if (widget.behavior == CourseReminderBehavior.inherit &&
          defaultMinutes == null)
        l.courseReminderDefaultOff,
      if (_service != null && !_service!.isSupported)
        l.notificationPlatformUnsupported,
      if (_error)
        l.notificationPermissionRequestFailed
      else if (_permission == false)
        l.notificationPermissionDenied
      else if (!_loading &&
          _permission == null &&
          (_service?.isSupported ?? true))
        l.courseReminderPermissionUnknown,
      if (_exact == false) l.notificationExactAlarmRequired,
      if (_battery == false) l.notificationBatteryOptimizationRequired,
    ];
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (WorkbenchChromeMetrics.compactTouch(context))
          SkedDropdownMenu<CourseReminderBehavior>(
            key: const ValueKey('course-reminder-behavior'),
            initialSelection: widget.behavior,
            label: Text(l.courseSystemReminder),
            enabled: widget.enabled,
            workspace: AppMode.student,
            expandedInsets: EdgeInsets.zero,
            dropdownMenuEntries: [
              DropdownMenuEntry(
                value: CourseReminderBehavior.inherit,
                label: inherited,
              ),
              DropdownMenuEntry(
                value: CourseReminderBehavior.disabled,
                label: l.notificationReminderOff,
              ),
              DropdownMenuEntry(
                value: CourseReminderBehavior.custom,
                label: l.recurrenceCustom,
              ),
            ],
            onSelected: (value) {
              if (value != null) widget.onChanged(value);
            },
          )
        else
          DropdownButtonFormField<CourseReminderBehavior>(
            key: const ValueKey('course-reminder-behavior'),
            initialValue: widget.behavior,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l.courseSystemReminder,
              isDense: WorkbenchChromeMetrics.of(context).desktop,
            ),
            itemHeight: null,
            items: [
              DropdownMenuItem(
                value: CourseReminderBehavior.inherit,
                child: Text(inherited),
              ),
              DropdownMenuItem(
                value: CourseReminderBehavior.disabled,
                child: Text(l.notificationReminderOff),
              ),
              DropdownMenuItem(
                value: CourseReminderBehavior.custom,
                child: Text(l.recurrenceCustom),
              ),
            ],
            onChanged: !widget.enabled
                ? null
                : (value) {
                    if (value != null) widget.onChanged(value);
                  },
          ),
        if (widget.behavior == CourseReminderBehavior.custom) ...[
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('course-reminder-custom-minutes'),
            controller: widget.minutesController,
            enabled: widget.enabled,
            keyboardType: const TextInputType.numberWithOptions(),
            decoration: InputDecoration(
              labelText: l.courseReminderMinutesLabel,
            ),
          ),
        ],
        const SizedBox(height: 8),
        if (_loading)
          Text(
            l.notificationPermissionChecking,
            style: theme.textTheme.bodySmall,
          ),
        for (final warning in warnings)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              warning,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        Text(
          l.courseReminderDeliveryHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (provider != null)
          TextButton.icon(
            key: const ValueKey('course-open-notifications'),
            onPressed: widget.enabled ? _openSettings : null,
            icon: const Icon(Icons.notifications_outlined, size: 18),
            label: Text(l.notificationSettingsSection),
          ),
        if (_error)
          TextButton(
            onPressed: _loading ? null : _refresh,
            child: Text(l.dataRecoveryRetryAction),
          ),
      ],
    );
  }
}
