import '../theme/sked_surface.dart';

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:provider/provider.dart';

import '../models/timetable_models.dart';
import '../providers/timetable_provider.dart';
import '../l10n/app_localizations.dart';
import 'ui_command.dart';
import 'sked_popup_menu.dart';
import 'app_layout_tokens.dart';
import 'workbench_chrome_metrics.dart';
import 'desktop_window_host.dart';
import 'workspace_frame.dart';
import '../screens/settings_page.dart';

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

void selectWorkspace(BuildContext context, AppMode mode) {
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
    if (WorkbenchChromeMetrics.compactTouch(context)) {
      return SkedPopupMenuButton<AppMode>(
        tooltip: l10n.settingsSectionWorkspace,
        icon: const Icon(Icons.swap_horiz),
        enabled: WorkspaceNavigationScope.maybeOf(context)?.enabled ?? true,
        onSelected: (mode) {
          if (context.mounted && provider.isWorkspaceEnabled(mode)) {
            selectWorkspace(context, mode);
          }
        },
        itemBuilder: (_) => [
          for (final mode in provider.enabledWorkspaces)
            SkedPopupMenuItem<AppMode>(
              value: mode,
              child: Row(
                children: [
                  Icon(
                    provider.activeMode == mode ? Icons.check : null,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      mode == AppMode.student
                          ? l10n.studentTimetable
                          : l10n.generalSchedule,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    }
    final metrics = WorkbenchChromeMetrics.of(context);
    return PopupMenuButton<AppMode>(
      style: metrics.desktop ? metrics.iconStyle : null,
      padding: EdgeInsets.all(metrics.desktop ? 6 : 8),
      iconSize: metrics.desktop ? 18 : null,
      tooltip: l10n.settingsSectionWorkspace,
      icon: const Icon(Icons.swap_horiz),
      enabled: WorkspaceNavigationScope.maybeOf(context)?.enabled ?? true,
      onSelected: (mode) => selectWorkspace(context, mode),
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
    final factor = WorkbenchLayoutPolicy.textFactor(m.textScale);
    final compactWidth =
        (m.desktop
            ? AppBreakpoints.pointerCompactResourcePane
            : AppBreakpoints.compactResourcePane) *
        factor;
    final expandedWidth = AppBreakpoints.resourcePane * factor;

    return SkedSurface(
      key: const ValueKey('workspace-resource-panel'),
      role: SkedSurfaceRole.frame,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < compactWidth) {
            return const SizedBox.shrink();
          }
          // Read the *animated* width, not just the target layout. All icons
          // keep one slot and one row height throughout the transition.
          final progress =
              ((constraints.maxWidth - compactWidth) /
                      (expandedWidth - compactWidth))
                  .clamp(0.0, 1.0);
          final labelOpacity = const Interval(.15, .85).transform(progress);
          final detailsInteractive = !collapsed && progress >= .999;
          Widget label(Widget child) => _ResourcePaneReveal(
            width: expandedWidth - compactWidth,
            opacity: labelOpacity,
            child: child,
          );
          final header = SizedBox(
            height: m.toolbarHeight,
            child: Material(
              color: SkedSurfaceRole.frame.resolve(colors),
              shape: Border(bottom: BorderSide(color: colors.outlineVariant)),
              child: DesktopDragRegion(
                child: Row(
                  children: [
                    SizedBox(
                      width: compactWidth,
                      child: Center(
                        child: IconButton(
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
                      ),
                    ),
                    Expanded(
                      child: label(
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            l.appTitle,
                            style: Theme.of(context).textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
          Widget navigationAction({
            required String id,
            required String title,
            required IconData icon,
            required VoidCallback? onTap,
            bool selected = false,
            FocusNode? focusNode,
          }) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Tooltip(
              message: collapsed ? title : '',
              excludeFromSemantics: true,
              child: ListTile(
                key: ValueKey(id),
                focusNode: focusNode,
                enabled: onTap != null,
                minTileHeight: m.resourceRowHeight,
                minVerticalPadding: 0,
                contentPadding: EdgeInsets.zero,
                selected: selected,
                selectedTileColor: colors.secondaryContainer.withValues(
                  alpha: .65,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                // The same ListTile owns focus, semantics and its hit target in
                // both states; hiding a label must not replace it with a button.
                title: SizedBox(
                  height: m.resourceRowHeight,
                  child: Row(
                    children: [
                      SizedBox(
                        width: compactWidth - 16,
                        child: Icon(
                          icon,
                          size: m.desktop ? 20 : 22,
                          color: onTap == null
                              ? colors.onSurface.withValues(alpha: .38)
                              : selected
                              ? colors.onSecondaryContainer
                              : colors.onSurfaceVariant,
                        ),
                      ),
                      Expanded(
                        child: _ResourcePaneReveal(
                          width: expandedWidth - compactWidth,
                          opacity: labelOpacity,
                          keepSemantics: true,
                          child: Padding(
                            padding: const EdgeInsetsDirectional.only(end: 8),
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                onTap: onTap,
              ),
            ),
          );
          final navigation = <Widget>[
            if (showModes) ...[
              const SizedBox(height: 8),
              for (final mode in p.enabledWorkspaces)
                navigationAction(
                  id: 'workspace-resource-mode-${mode.value}',
                  title: mode == AppMode.student
                      ? l.studentTimetable
                      : l.generalSchedule,
                  icon: mode == AppMode.student
                      ? Icons.school_outlined
                      : Icons.event_note_outlined,
                  selected: p.activeMode == mode,
                  onTap: enabled ? () => selectWorkspace(context, mode) : null,
                ),
            ],
            Padding(
              padding: const EdgeInsets.only(top: 20, bottom: 8),
              child: SizedBox(
                height: m.resourceRowHeight,
                child: Row(
                  children: [
                    SizedBox(
                      width: compactWidth,
                      child: Center(
                        child: IconButton(
                          key: const ValueKey('workspace-resource-open'),
                          style: m.iconStyle,
                          tooltip: title,
                          onPressed: enabled
                              ? (onOpenResources ?? toggle)
                              : null,
                          icon: Icon(
                            p.isStudentMode
                                ? Icons.view_week_outlined
                                : Icons.category_outlined,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: IgnorePointer(
                        ignoring: !detailsInteractive,
                        child: ExcludeFocus(
                          excluding: !detailsInteractive,
                          child: ExcludeSemantics(
                            excluding: !detailsInteractive,
                            child: label(
                              Padding(
                                padding: const EdgeInsetsDirectional.only(
                                  end: 8,
                                ),
                                child: IconButtonTheme(
                                  data: IconButtonThemeData(style: m.iconStyle),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          title,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      ...headerActions,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ];
          final settings = onSettings == null
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: navigationAction(
                    id: 'workspace-resource-settings',
                    title: l.settings,
                    icon: Icons.settings_outlined,
                    focusNode: layout?.resources == true
                        ? settingsFocusNode
                        : null,
                    onTap: enabled ? onSettings : null,
                  ),
                );
          Widget resources({bool shrinkWrap = false}) => IgnorePointer(
            ignoring: !detailsInteractive,
            child: ExcludeFocus(
              excluding: !detailsInteractive,
              child: ExcludeSemantics(
                excluding: !detailsInteractive,
                child: _ResourcePaneReveal(
                  width: expandedWidth,
                  opacity: labelOpacity,
                  child: ListView(
                    key: const PageStorageKey('workspace-resource-list'),
                    primary: false,
                    shrinkWrap: shrinkWrap,
                    physics: shrinkWrap
                        ? const NeverScrollableScrollPhysics()
                        : null,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    children: [...children, ...actions],
                  ),
                ),
              ),
            ),
          );
          if (constraints.maxHeight < m.toolbarHeight + 200 * m.textScale) {
            // Even a very short window keeps Settings anchored at the bottom.
            return Column(
              children: [
                Expanded(
                  child: ListView(
                    children: [
                      header,
                      ...navigation,
                      if (!collapsed) resources(shrinkWrap: true),
                    ],
                  ),
                ),
                settings,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              ...navigation,
              Expanded(child: resources()),
              settings,
            ],
          );
        },
      ),
    );
  }
}

/// Keep the expanded content laid out at its final width while clipping and
/// revealing it. Calendars and labels never reflow into a narrow intermediate
/// column; navigation labels keep their accessible name when visually hidden.
class _ResourcePaneReveal extends StatelessWidget {
  const _ResourcePaneReveal({
    required this.width,
    required this.opacity,
    required this.child,
    this.keepSemantics = false,
  });
  final double width;
  final double opacity;
  final bool keepSemantics;
  final Widget child;
  @override
  Widget build(BuildContext context) => ClipRect(
    child: OverflowBox(
      fit: OverflowBoxFit.deferToChild,
      alignment: AlignmentDirectional.centerStart,
      minWidth: width,
      maxWidth: width,
      child: Opacity(
        opacity: opacity,
        alwaysIncludeSemantics: keepSemantics,
        child: child,
      ),
    ),
  );
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
