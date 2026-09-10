import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/timetable_models.dart';
import '../providers/timetable_provider.dart';
import '../l10n/app_localizations.dart';
import 'ui_command.dart';
import 'app_layout_tokens.dart';
import 'workbench_chrome_metrics.dart';
import 'desktop_window_host.dart';
import 'workspace_frame.dart';
import '../screens/settings_page.dart';
import '../screens/timetable_display_settings_page.dart';
import '../screens/general_display_settings_page.dart';

/// All shell navigation, including integrated resource links, uses the same
/// save gate and focus hand-off as the compact navigation bar.
class WorkspaceNavigationScope extends InheritedWidget {
  const WorkspaceNavigationScope({
    super.key,
    required this.enabled,
    required this.integrated,
    required this.onSelect,
    required this.onToggleResources,
    required super.child,
  });
  final bool enabled;
  final bool integrated;
  final ValueChanged<AppMode> onSelect;
  final VoidCallback onToggleResources;
  static WorkspaceNavigationScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<WorkspaceNavigationScope>();
  @override
  bool updateShouldNotify(WorkspaceNavigationScope oldWidget) =>
      enabled != oldWidget.enabled ||
      integrated != oldWidget.integrated ||
      onSelect != oldWidget.onSelect;
}

void _selectWorkspace(BuildContext context, AppMode mode) {
  final navigation = WorkspaceNavigationScope.maybeOf(context);
  if (navigation != null) {
    if (navigation.enabled) navigation.onSelect(mode);
    return;
  }
  unawaited(
    runUiCommandWithFeedback(
      context: context,
      debugLabel: 'Switch workspace',
      command: () => context.read<TimetableProvider>().switchMode(mode),
    ),
  );
}

/// An explicit fallback remains available even when the user hides mode chrome.
class WorkspaceModeMenu extends StatelessWidget {
  const WorkspaceModeMenu({super.key});
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TimetableProvider>();
    final l10n = AppLocalizations.of(context);
    if (!provider.hasMultipleWorkspaces) return const SizedBox.shrink();
    return PopupMenuButton<AppMode>(
      tooltip: l10n.settingsSectionWorkspace,
      icon: const Icon(Icons.swap_horiz),
      enabled: WorkspaceNavigationScope.maybeOf(context)?.enabled ?? true,
      onSelected: (mode) => _selectWorkspace(context, mode),
      itemBuilder: (_) => [
        for (final mode in provider.enabledWorkspaces)
          CheckedPopupMenuItem(
            value: mode,
            checked: provider.activeMode == mode,
            child: Text(
              mode == AppMode.student
                  ? l10n.studentTimetable
                  : l10n.generalSchedule,
            ),
          ),
      ],
    );
  }
}

class WorkspaceResourcePanel extends StatelessWidget {
  const WorkspaceResourcePanel({
    super.key,
    required this.title,
    required this.children,
    this.actions = const [],
    this.headerActions = const [],
    this.onSettings,
    this.onOpenResources,
    this.settingsFocusNode,
  });
  final String title;
  final List<Widget> children;
  final List<Widget> actions;
  final List<Widget> headerActions;
  final VoidCallback? onSettings;
  final VoidCallback? onOpenResources;
  final FocusNode? settingsFocusNode;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<TimetableProvider>();
    final scope = WorkspaceNavigationScope.maybeOf(context);
    final layout = WorkspaceCanvasScope.maybeOf(context);
    final m = WorkbenchChromeMetrics.of(context);
    final l = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final collapsed =
        (layout?.resourceWidth ?? AppBreakpoints.resourcePane) <
        AppBreakpoints.resourcePane *
            WorkbenchLayoutPolicy.textFactor(m.textScale);
    final forcedCompact = collapsed && !p.homeWorkspaceNavigationCollapsed;
    final enabled = scope?.enabled ?? true;
    void toggle() {
      if (scope != null) {
        scope.onToggleResources();
        return;
      }
      unawaited(
        runUiCommandWithFeedback(
          context: context,
          debugLabel: 'Toggle resources',
          command: () => p.updateHomeWorkspaceNavigationCollapsed(
            !p.homeWorkspaceNavigationCollapsed,
          ),
        ),
      );
    }

    final showModes =
        p.hasMultipleWorkspaces &&
        !p.hideHomeWorkspaceNavigation &&
        (scope?.integrated ?? true);
    final header = SizedBox(
      height: m.toolbarHeight,
      child: Material(
        color: colors.surfaceContainerLow,
        shape: Border(bottom: BorderSide(color: colors.outlineVariant)),
        child: DesktopDragRegion(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                IconButton(
                  key: const ValueKey('workspace-resource-collapse'),
                  style: m.iconStyle,
                  tooltip: collapsed
                      ? l.expandWorkspaceNavigation
                      : l.collapseWorkspaceNavigation,
                  onPressed: enabled
                      ? (forcedCompact ? onOpenResources : toggle)
                      : null,
                  icon: Icon(collapsed ? Icons.menu_open : Icons.menu),
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l.appTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    final navigation = <Widget>[
      if (showModes) ...[
        const SizedBox(height: 8),
        for (final mode in p.enabledWorkspaces)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: collapsed ? 8 : 10,
              vertical: 2,
            ),
            child: collapsed
                ? IconButton(
                    key: ValueKey('workspace-resource-mode-${mode.value}'),
                    style: m.iconStyle,
                    isSelected: p.activeMode == mode,
                    tooltip: mode == AppMode.student
                        ? l.studentTimetable
                        : l.generalSchedule,
                    onPressed: enabled
                        ? () => _selectWorkspace(context, mode)
                        : null,
                    icon: Icon(
                      mode == AppMode.student
                          ? Icons.school_outlined
                          : Icons.event_note_outlined,
                    ),
                  )
                : ListTile(
                    key: ValueKey('workspace-resource-mode-${mode.value}'),
                    minTileHeight: m.resourceRowHeight,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    selected: p.activeMode == mode,
                    selectedTileColor: colors.secondaryContainer.withValues(
                      alpha: .65,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    leading: Icon(
                      mode == AppMode.student
                          ? Icons.school_outlined
                          : Icons.event_note_outlined,
                      size: 20,
                    ),
                    title: Text(
                      mode == AppMode.student
                          ? l.studentTimetable
                          : l.generalSchedule,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: enabled
                        ? () => _selectWorkspace(context, mode)
                        : null,
                  ),
          ),
      ],
      if (collapsed)
        Padding(
          padding: const EdgeInsets.all(8),
          child: IconButton(
            key: const ValueKey('workspace-resource-open'),
            style: m.iconStyle,
            tooltip: title,
            onPressed: enabled ? (onOpenResources ?? toggle) : null,
            icon: Icon(
              p.isStudentMode
                  ? Icons.view_week_outlined
                  : Icons.category_outlined,
            ),
          ),
        )
      else
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 20, 8, 8),
          child: IconButtonTheme(
            data: IconButtonThemeData(style: m.iconStyle),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                ...headerActions,
              ],
            ),
          ),
        ),
    ];
    final settings = onSettings == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.all(8),
            child: collapsed
                ? IconButton(
                    key: const ValueKey('workspace-resource-settings'),
                    style: m.iconStyle,
                    tooltip: l.settings,
                    onPressed: enabled ? onSettings : null,
                    icon: const Icon(Icons.settings_outlined),
                  )
                : ListTile(
                    key: const ValueKey('workspace-resource-settings'),
                    focusNode: layout?.resources == true
                        ? settingsFocusNode
                        : null,
                    minTileHeight: m.resourceRowHeight,
                    leading: const Icon(Icons.settings_outlined, size: 20),
                    title: Text(l.settings),
                    onTap: enabled ? onSettings : null,
                  ),
          );
    return Material(
      key: const ValueKey('workspace-resource-panel'),
      color: colors.surfaceContainerLow,
      child: LayoutBuilder(
        builder: (context, c) {
          if (c.maxHeight < m.toolbarHeight + 200 * m.textScale) {
            return ListView(
              children: [
                header,
                ...navigation,
                if (!collapsed) ...children,
                if (!collapsed) ...actions,
                settings,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              ...navigation,
              Expanded(
                child: collapsed
                    ? const SizedBox.shrink()
                    : ListView(
                        key: const PageStorageKey('workspace-resource-list'),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        children: [...children, ...actions],
                      ),
              ),
              settings,
            ],
          );
        },
      ),
    );
  }
}

/// Only show the fallback when no visible navigation can switch workspaces.
bool needsWorkspaceMenu(BuildContext context) {
  final p = context.watch<TimetableProvider>();
  if (!p.hasMultipleWorkspaces) return false;
  if (p.hideHomeWorkspaceNavigation) return true;
  return WorkspaceCanvasScope.maybeOf(context)?.resources != true &&
      (WorkspaceNavigationScope.maybeOf(context)?.integrated ?? true);
}

Future<void> openWorkspaceTransfer(
  BuildContext context,
  AppMode mode, {
  required SettingsTransferDirection direction,
}) => Navigator.of(context, rootNavigator: true).push<void>(
  MaterialPageRoute(
    builder: (_) => ChangeNotifierProvider<TimetableProvider>.value(
      value: context.read<TimetableProvider>(),
      child: SettingsPage(
        transferDirection: direction,
        initialDestination: mode == AppMode.student
            ? SettingsDestination.student
            : SettingsDestination.general,
      ),
    ),
  ),
);

Future<void> openWorkspacePreferences(BuildContext context, AppMode mode) =>
    Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider<TimetableProvider>.value(
          value: context.read<TimetableProvider>(),
          child: mode == AppMode.student
              ? const TimetableDisplaySettingsPage()
              : const GeneralDisplaySettingsPage(),
        ),
      ),
    );

class WorkspaceActionsMenu extends StatelessWidget {
  const WorkspaceActionsMenu({super.key, required this.mode});
  final AppMode mode;
  @override
  Widget build(BuildContext context) => IconButton(
    key: ValueKey('workspace-actions-${mode.value}'),
    tooltip: AppLocalizations.of(context).workspacePreferences,
    icon: const Icon(Icons.tune),
    onPressed: (WorkspaceNavigationScope.maybeOf(context)?.enabled ?? true)
        ? () => openWorkspacePreferences(context, mode)
        : null,
  );
}
