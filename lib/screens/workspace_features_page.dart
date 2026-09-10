import '../widgets/desktop_window_host.dart';

import 'dart:async';

import '../widgets/adaptive_navigation_scope.dart';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/timetable_models.dart';
import '../providers/timetable_provider.dart';
import '../services/agenda_coordinator.dart';
import '../services/agenda_notification_service.dart';
import '../widgets/settings_list.dart';
import '../widgets/ui_command.dart';

class WorkspaceFeaturesPage extends StatefulWidget {
  const WorkspaceFeaturesPage({
    super.key,
    this.coordinator,
    this.notificationService,
  });
  final AgendaCoordinator? coordinator;
  final AgendaNotificationService? notificationService;
  @override
  State<WorkspaceFeaturesPage> createState() => _WorkspaceFeaturesPageState();
}

class _WorkspaceFeaturesPageState extends State<WorkspaceFeaturesPage>
    with UiCommandRunner<WorkspaceFeaturesPage> {
  bool _cleanupPending = false;
  bool _confirming = false;
  AgendaNotificationService? get _service =>
      widget.coordinator?.notificationService ?? widget.notificationService;
  @override
  void initState() {
    super.initState();
    _service?.addListener(_notificationStateChanged);
  }

  @override
  void didUpdateWidget(covariant WorkspaceFeaturesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldService =
        oldWidget.coordinator?.notificationService ??
        oldWidget.notificationService;
    if (!identical(oldService, _service)) {
      oldService?.removeListener(_notificationStateChanged);
      _service?.addListener(_notificationStateChanged);
    }
  }

  void _notificationStateChanged() {
    if (mounted) {
      setState(() {
        if (_service?.status.lastError == null) _cleanupPending = false;
      });
    }
  }

  @override
  void dispose() {
    _service?.removeListener(_notificationStateChanged);
    super.dispose();
  }

  Future<void> _reconcile() async {
    if (widget.coordinator != null) {
      await widget.coordinator!.reconcileNow();
    } else if (widget.notificationService != null) {
      await widget.notificationService!.reconcile(
        context.read<TimetableProvider>().committedAppData,
      );
    }
    final service =
        widget.coordinator?.notificationService ?? widget.notificationService;
    if (service?.status.lastError != null) throw service!.status.lastError!;
  }

  Future<void> _set(AppMode mode, bool enabled) async {
    if (uiCommandBusy || _confirming) return;
    final provider = context.read<TimetableProvider>();
    final l = AppLocalizations.of(context);
    if (!enabled && !provider.hasMultipleWorkspaces) return;
    if (!enabled) {
      _confirming = true;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l.workspaceDisableTitle),
          content: Text(l.workspaceDisableMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.confirm),
            ),
          ],
        ),
      ).whenComplete(() => _confirming = false);
      if (confirm != true || !mounted) return;
    }
    await runUiCommand(
      debugLabel: 'Change enabled workspaces',
      command: () async {
        await provider.setWorkspaceEnabled(mode, enabled);
        if (provider.isWorkspaceEnabled(mode) != enabled) return;
        try {
          await _reconcile();
          if (mounted) setState(() => _cleanupPending = false);
        } catch (_) {
          if (mounted) setState(() => _cleanupPending = true);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<TimetableProvider>();
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: WorkbenchAppBar(
        automaticallyImplyLeading: !AdaptiveNavigationScope.isWide(context),
        title: Text(l.workspaceFeatures),
      ),
      body: Column(
        children: [
          UiCommandBusyIndicator(busy: uiCommandBusy),
          Expanded(
            child: SettingsInteractionBlocker(
              blocked: uiCommandBusy,
              child: ResponsiveSettingsSingleColumnBody(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(l.workspaceEnableHint),
                  ),
                  for (final mode in AppMode.values)
                    SettingsSwitchTile(
                      key: ValueKey('workspace-enabled-${mode.value}'),
                      icon: mode == AppMode.student
                          ? Icons.school_outlined
                          : Icons.event_note_outlined,
                      title: mode == AppMode.student
                          ? l.studentTimetable
                          : l.generalSchedule,
                      subtitle:
                          p.isWorkspaceEnabled(mode) && !p.hasMultipleWorkspaces
                          ? l.workspaceLastRequired
                          : null,
                      value: p.isWorkspaceEnabled(mode),
                      onChanged:
                          p.isWorkspaceEnabled(mode) && !p.hasMultipleWorkspaces
                          ? null
                          : (value) => unawaited(_set(mode, value)),
                    ),
                  if (p.hasMultipleWorkspaces)
                    SettingsSwitchTile(
                      icon: Icons.navigation_outlined,
                      title: l.hideHomeWorkspaceNavigation,
                      subtitle: l.hideHomeWorkspaceNavigationDesc,
                      value: p.hideHomeWorkspaceNavigation,
                      onChanged: (value) => unawaited(
                        runUiCommand(
                          debugLabel: 'Change workspace navigation',
                          command: () =>
                              p.updateHideHomeWorkspaceNavigation(value),
                        ),
                      ),
                    ),
                  if (_cleanupPending ||
                      (!p.hasMultipleWorkspaces &&
                          _service?.status.lastError != null))
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            l.workspaceReminderCleanupFailed,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                          TextButton(
                            onPressed: () => unawaited(
                              runUiCommand(
                                debugLabel: 'Retry notification cleanup',
                                command: () async {
                                  await _reconcile();
                                  if (mounted) {
                                    setState(() => _cleanupPending = false);
                                  }
                                },
                              ),
                            ),
                            child: Text(l.dataRecoveryRetryAction),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
