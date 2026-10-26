import '../controllers/course_task_controller.dart';
import '../widgets/course_task_editor.dart';
import '../widgets/sked_floating_surface.dart';
import '../widgets/sked_panel_header.dart';
import '../utils/mobile_toolbar_layout.dart';
import '../widgets/sked_week_picker.dart';

import '../theme/sked_surface.dart';

import '../widgets/desktop_window_host.dart';
import '../widgets/workbench_chrome_metrics.dart';
import '../widgets/workbench_resource_widgets.dart';
import '../widgets/workbench_compact_calendar_bar.dart';

import 'dart:async';

import '../services/desktop_layout_preferences.dart';

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widget_previews.dart';
import 'package:material_ui/material_ui.dart';

import '../widgets/sked_tooltip.dart';

import '../widgets/sked_date_picker.dart';

import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/timetable_models.dart';
import '../models/workspace_context_snapshot.dart';
import '../controllers/app_data_maintenance.dart';
import '../controllers/app_session.dart';
import '../controllers/settings_view_state.dart';
import '../controllers/student_commands.dart';
import '../controllers/student_view_state.dart';
import '../controllers/workspace_commands.dart';
import '../controllers/workspace_view_state.dart';
import '../providers/app_scope.dart';
import '../previews/sked_preview_support.dart';
import '../theme/sked_expressive_theme.dart';
import '../theme/sked_menu_style.dart';
import '../widgets/app_modal_sheet.dart';
import '../widgets/sked_task_body.dart';
import '../widgets/sked_task_header.dart';
import '../widgets/workspace_frame.dart';
import '../widgets/assistant_pane.dart' show AssistantPaneScope;
import '../widgets/app_layout_tokens.dart';
import '../widgets/editor_exit_guard.dart';
import '../widgets/sked_task_route.dart';
import '../widgets/workspace_navigation.dart';
import '../widgets/course_details_sheet.dart';
import '../widgets/course_editor_sheet.dart';
import '../widgets/expressive_empty_state.dart';
import '../widgets/expressive_dialog.dart';
import '../widgets/sked_task_dialog.dart';
import '../widgets/sked_task_session.dart';
import '../widgets/sked_mutation_confirmation_dialog.dart';
import '../widgets/sked_adaptive_picker_dialog.dart';
import '../widgets/expressive_motion.dart';
import '../widgets/period_time_set_picker_dialog.dart';
import '../widgets/period_time_set_manager.dart';
import '../widgets/sked_expressive_components.dart';
import '../widgets/sked_menu_item_content.dart';
import '../widgets/sked_popup_menu.dart';
import '../widgets/text_transfer_widgets.dart';
import '../widgets/timetable_information_form.dart';
import '../widgets/timetable_grid.dart';
import '../widgets/timetable_day_agenda.dart';
import '../widgets/ui_command.dart';
import 'settings_page.dart';
import 'timetable_import_flow.dart';

part 'home_screen_course_actions.dart';
part 'home_screen_imports.dart';
part 'home_screen_timetable_management.dart';
part 'home_screen_widgets.dart';
part '../previews/timetable_information_previews.dart';

enum _StudentTimetableView { day, week }

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.embedded = false,
    this.active = true,
    this.interactive = true,
    this.showSettingsAction = true,
    this.settingsEnabled = true,
    this.settingsAction,
    this.settingsFocusNode,
    this.scaffoldKey,
    this.weekShortcutFocusNode,
  });

  /// Whether this screen is hosted by the adaptive application shell.
  final bool embedded;

  /// Whether this workspace is currently active in the adaptive shell.
  final bool active;

  /// Whether input may mutate this workspace while it remains visible.
  final bool interactive;

  /// Keeps the shell's single settings action in the workspace bar.
  final bool showSettingsAction;

  /// Optional shell-owned settings action. When omitted, this screen opens
  /// settings itself for backwards-compatible standalone use.
  final VoidCallback? settingsAction;

  /// Preserves logical focus for the shell-owned global settings action.
  final FocusNode? settingsFocusNode;

  /// Allows the adaptive shell to close the settings entry while a command is
  /// persisting, without changing the standalone screen behavior.
  final bool settingsEnabled;

  /// Optional key for the compatibility scaffold used outside the app shell.
  /// Embedded workspaces never create a second scaffold.
  final GlobalKey<ScaffoldState>? scaffoldKey;

  /// Lets the adaptive shell restore the timetable's keyboard shortcuts after
  /// a workspace transition without rebuilding the persistent page view.
  final FocusNode? weekShortcutFocusNode;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _pane = WorkspacePaneController();
  PageController? _pageController;
  _StudentTimetableView? _viewMode;
  int? _selectedWeekday;
  int? _weekNavigationTarget;
  int _weekNavigationGeneration = 0;
  int _weekNavigationDirection = 0;
  int? _scheduledWeekPageSync;
  bool _weekPageScrolling = false;
  bool _weekPickerOpen = false;
  bool _timetablePickerOpen = false;
  bool _courseEditorOpen = false;
  bool _courseDetailsOpen = false;
  bool _timetableItemDialogOpen = false;
  bool _timetableSwitchInProgress = false;
  bool _settingsPageOpen = false;
  bool _periodTimeSetManagerOpen = false;
  bool _fileImportInProgress = false;
  bool _textImportPageOpen = false;
  bool _schoolWebImportPageOpen = false;

  @override
  void dispose() {
    _pane.dispose();
    _pageController?.dispose();
    super.dispose();
  }

  void _setWeekPickerOpen(bool value) {
    if (_weekPickerOpen == value) return;
    if (mounted) {
      setState(() => _weekPickerOpen = value);
    } else {
      _weekPickerOpen = value;
    }
  }

  void _setTimetablePickerOpen(bool value) {
    if (_timetablePickerOpen == value) return;
    if (mounted) {
      setState(() => _timetablePickerOpen = value);
    } else {
      _timetablePickerOpen = value;
    }
  }

  void _setCourseEditorOpen(bool value) {
    if (_courseEditorOpen == value) return;
    if (mounted) {
      setState(() => _courseEditorOpen = value);
    } else {
      _courseEditorOpen = value;
    }
  }

  void _setCourseDetailsOpen(bool value) {
    if (_courseDetailsOpen == value) return;
    if (mounted) {
      setState(() => _courseDetailsOpen = value);
    } else {
      _courseDetailsOpen = value;
    }
  }

  void _setTimetableItemDialogOpen(bool value) {
    if (_timetableItemDialogOpen == value) return;
    if (mounted) {
      setState(() => _timetableItemDialogOpen = value);
    } else {
      _timetableItemDialogOpen = value;
    }
  }

  void _setTimetableSwitchInProgress(bool value) {
    if (_timetableSwitchInProgress == value) return;
    if (mounted) {
      setState(() => _timetableSwitchInProgress = value);
    } else {
      _timetableSwitchInProgress = value;
    }
  }

  void _setSettingsPageOpen(bool value) {
    if (_settingsPageOpen == value) return;
    if (mounted) {
      setState(() => _settingsPageOpen = value);
    } else {
      _settingsPageOpen = value;
    }
  }

  void _setFileImportInProgress(bool value) {
    if (_fileImportInProgress == value) return;
    if (mounted) {
      setState(() => _fileImportInProgress = value);
    } else {
      _fileImportInProgress = value;
    }
  }

  void _setTextImportPageOpen(bool value) {
    if (_textImportPageOpen == value) return;
    if (mounted) {
      setState(() => _textImportPageOpen = value);
    } else {
      _textImportPageOpen = value;
    }
  }

  void _setSchoolWebImportPageOpen(bool value) {
    if (_schoolWebImportPageOpen == value) return;
    if (mounted) {
      setState(() => _schoolWebImportPageOpen = value);
    } else {
      _schoolWebImportPageOpen = value;
    }
  }

  Future<void> _openSettingsPage() async {
    if (_settingsPageOpen || !mounted) {
      return;
    }
    final appScope = AppScope.capture(context);
    _setSettingsPageOpen(true);
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              appScope?.wrap(const SettingsPage()) ?? const SettingsPage(),
        ),
      );
    } finally {
      _setSettingsPageOpen(false);
    }
  }

  Future<bool> _switchTimetableFromPicker(
    BuildContext pickerContext,
    TimetableData targetTimetable,
  ) async {
    if (!mounted || !pickerContext.mounted || _timetableSwitchInProgress) {
      return false;
    }
    final student = context.read<StudentViewState>();
    final commands = context.read<StudentCommands>();
    _setTimetableSwitchInProgress(true);
    try {
      var saved = true;
      // The picker can remain open while another command updates the
      // student data. Compare against the live selection instead of the snapshot
      // captured when the panel was opened.
      if (targetTimetable.id != student.activeTimetableOrNull?.id) {
        saved = await runUiCommandWithFeedback(
          context: pickerContext,
          debugLabel: 'Switch timetable',
          command: () => commands.switchTimetable(targetTimetable.id),
        );
      }
      return saved;
    } finally {
      _setTimetableSwitchInProgress(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoaded = context.select<AppSessionReadiness, bool>(
      (readiness) => readiness.isLoaded,
    );
    final snapshot = context.select<StudentViewState, _StudentHomeSnapshot>(
      _StudentHomeSnapshot.from,
    );
    final l10n = AppLocalizations.of(context);
    if (!isLoaded) {
      return _wrapStandalone(
        const SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }
    return _wrapStandalone(
      SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final timetable = snapshot.activeTimetable;
            final desktop = WorkbenchChromeMetrics.of(context).desktop;
            final compactTouch = WorkbenchChromeMetrics.compactTouch(
              context,
              width: constraints.maxWidth,
            );
            final horizontalInset = !desktop && constraints.maxWidth < 600
                ? 8.0
                : 0.0;
            final showSettingsHere =
                widget.showSettingsAction &&
                WorkspaceCanvasScope.maybeOf(context)?.resources != true;
            final settingsAction = !widget.settingsEnabled
                ? null
                : widget.settingsAction ??
                      (_settingsPageOpen ? null : () => _openSettingsPage());

            if (timetable == null) {
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalInset,
                  desktop || compactTouch ? 0 : 8,
                  horizontalInset,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Desktop chrome needs a drag surface even when the
                    // resource panel owns the settings action.
                    _EmptyTimetableToolbar(
                      key: const ValueKey('student-workspace-toolbar'),
                      title: l10n.appTitle,
                      showSettingsAction: showSettingsHere,
                      settingsFocusNode: widget.settingsFocusNode,
                      onOpenSettings: settingsAction,
                      onManagePeriodTimeSets: widget.interactive
                          ? () => _managePeriodTimeSets()
                          : null,
                    ),
                    Expanded(
                      child: WorkspaceCanvasBody(
                        child: _EmptyTimetableState(
                          onCreate: _timetableItemDialogOpen
                              ? null
                              : (anchor) => _openCreateTimetableDialog(
                                  context,
                                  editor: WorkspaceEditorConfiguration(
                                    anchorContext: anchor,
                                  ),
                                ),
                          onImport: _fileImportInProgress
                              ? null
                              : () => _importTimetableData(context),
                          onImportFromText: _textImportPageOpen
                              ? null
                              : () => _importTimetablesFromText(context),
                          onImportFromWeb: _schoolWebImportPageOpen
                              ? null
                              : () => _importTimetableFromWeb(context),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            final config = timetable.config;
            final week = snapshot.selectedWeek;
            final view = View.of(context);
            final rawKeyboardInset =
                view.viewInsets.bottom / view.devicePixelRatio;
            final keyboardVisible =
                rawKeyboardInset > 0 ||
                MediaQuery.viewInsetsOf(context).bottom > 0;
            final inlineAdd = desktop || constraints.maxWidth >= 600;
            final addVisible =
                (desktop || snapshot.showAddCourseFab) &&
                widget.active &&
                widget.interactive &&
                !_courseEditorOpen &&
                !keyboardVisible;
            // Keep the viewport full-height so the grid remains visible
            // behind the FAB. The clearance is added only to the
            // scrollable grid content, allowing the final course to be
            // brought above the button without painting a blank strip.
            final fabVisible = addVisible && !inlineAdd;
            final fabContentInset = fabVisible ? 80.0 : 0.0;
            _ensurePageController(week);
            _ensureLocalViewState(config: config, selectedWeek: week);
            final viewMode = _viewMode!;
            final selectedWeekday = _selectedWeekday!;
            final realCurrentWeek = currentWeekFor(config);
            final weekSwipeEnabled =
                snapshot.enableWeekSwipeNavigation &&
                widget.active &&
                widget.interactive &&
                !_courseEditorOpen &&
                !_courseDetailsOpen &&
                !_weekPickerOpen &&
                !_timetablePickerOpen &&
                !_timetableItemDialogOpen &&
                !_timetableSwitchInProgress &&
                !_settingsPageOpen &&
                _weekNavigationTarget == null;
            final longPressAddEnabled =
                snapshot.enableLongPressAddCourse &&
                widget.active &&
                widget.interactive &&
                !_courseEditorOpen &&
                !_courseDetailsOpen;

            return Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalInset,
                desktop || compactTouch ? 0 : 8,
                horizontalInset,
                0,
              ),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _StudentWorkspaceToolbar(
                        onAddCourse: inlineAdd && addVisible
                            ? (anchor) => _openEditor(
                                context,
                                weekday: viewMode == _StudentTimetableView.day
                                    ? selectedWeekday
                                    : null,
                                editor: WorkspaceEditorConfiguration(
                                  anchorContext: anchor,
                                ),
                              )
                            : null,
                        showAddLabel: constraints.maxWidth >= 760,
                        timetable: timetable,
                        week: week,
                        onStep: widget.interactive
                            ? (delta) => _jumpWeekBy(delta)
                            : null,
                        weekNavigationDirection: _weekNavigationTarget == week
                            ? _weekNavigationDirection
                            : 0,
                        viewMode: viewMode,
                        navigationOrder: snapshot.toolbarNavigationOrder,
                        hiddenNavigationIds:
                            snapshot.hiddenToolbarNavigationIds,
                        hiddenItemsBehavior:
                            snapshot.toolbarHiddenItemsBehavior,
                        compactWidth: constraints.maxWidth < 600,
                        compactHeight: constraints.maxHeight < 600,
                        interactive: widget.interactive,
                        showSettings: showSettingsHere,
                        settingsFocusNode: widget.settingsFocusNode,
                        onOpenTimetablePicker: _timetablePickerOpen
                            ? null
                            : (anchor) => _showTimetablePicker(
                                context,
                                availableWidth: constraints.maxWidth,
                                anchorContext: anchor,
                              ),
                        onManagePeriodTimeSets: widget.interactive
                            ? () => _managePeriodTimeSets()
                            : null,
                        onOpenWeekPicker: _weekPickerOpen
                            ? null
                            : (anchor) => _showWeekPicker(
                                context,
                                anchorContext: anchor,
                              ),
                        onJumpToToday: widget.interactive
                            ? () => unawaited(_jumpToToday(realCurrentWeek))
                            : null,
                        onViewChanged: widget.interactive
                            ? (value) => setState(() => _viewMode = value)
                            : null,
                        onOpenSettings: settingsAction,
                      ),
                      Expanded(
                        child: WorkspaceCanvasBody(
                          // This spacing belongs to the grid, not the
                          // shared body edge used to position task panes.
                          child: Padding(
                            padding: EdgeInsets.only(top: compactTouch ? 0 : 4),
                            child: _TimetableWeekPager(
                              controller: _pageController!,
                              snapshot: snapshot,
                              timetable: timetable,
                              config: config,
                              committedWeek: week,
                              active: widget.active,
                              interactive: widget.interactive,
                              swipeEnabled: weekSwipeEnabled,
                              viewMode: viewMode,
                              selectedWeekday: selectedWeekday,
                              fitDaySelectorToWidth:
                                  snapshot.fitDaySelectorToWidth,
                              fitWeekColumnsToWidth:
                                  snapshot.fitWeekColumnsToWidth,
                              shortcutFocusNode: widget.weekShortcutFocusNode,
                              bottomContentInset: fabContentInset,
                              dayHorizontalInset: desktop
                                  ? 24
                                  : 16 - horizontalInset,
                              onPageScrollStateChanged: (scrolling) {
                                _weekPageScrolling = scrolling;
                              },
                              onWeekSettled: (settledWeek) =>
                                  _settleWeekFromPager(settledWeek),
                              onWeekdaySelected: (weekday) {
                                if (_selectedWeekday == weekday) return;
                                setState(() => _selectedWeekday = weekday);
                              },
                              onJumpWeekBy: (offset) => _jumpWeekBy(offset),
                              onCourseTap: (info) =>
                                  _openDetails(context, info),
                              onAddCourse: addVisible
                                  ? (anchor) => _openEditor(
                                      context,
                                      weekday: selectedWeekday,
                                      editor: WorkspaceEditorConfiguration(
                                        anchorContext: anchor,
                                      ),
                                    )
                                  : null,
                              onEmptySlotTap: longPressAddEnabled
                                  ? (slotInfo) => _openEditor(
                                      context,
                                      weekday: slotInfo.weekday,
                                      emptySlot: slotInfo,
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (fabVisible)
                    PositionedDirectional(
                      end: 12,
                      bottom: 16,
                      child: Builder(
                        builder: (anchor) => SkedPrimaryFab(
                          heroTag: 'student-add-course',
                          tooltip: l10n.addCourse,
                          onPressed: () => _openEditor(
                            context,
                            weekday: viewMode == _StudentTimetableView.day
                                ? selectedWeekday
                                : null,
                            editor: WorkspaceEditorConfiguration(
                              anchorContext: anchor,
                            ),
                          ),
                          icon: const Icon(Icons.add),
                          label: constraints.maxWidth >= 760
                              ? Text(l10n.addCourse)
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _managePeriodTimeSets() async {
    if (!mounted ||
        _periodTimeSetManagerOpen ||
        _courseEditorOpen ||
        !widget.interactive) {
      return;
    }
    final appScope = AppScope.capture(context);
    _periodTimeSetManagerOpen = true;
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) =>
              appScope?.wrap(const PeriodTimeSetManagerPage()) ??
              const PeriodTimeSetManagerPage(),
        ),
      );
    } finally {
      _periodTimeSetManagerOpen = false;
    }
  }

  Widget _wrapStandalone(Widget workspace) {
    final framed = Builder(
      builder: (context) {
        final enabledWorkspaces = context
            .select<WorkspaceViewState, Set<AppMode>>(
              (view) => view.enabledWorkspaces,
            );
        final resourceId = context.select<StudentViewState, String?>(
          (view) => view.activeTimetableOrNull?.id,
        );
        final preferences = context
            .select<
              SettingsViewState,
              ({bool collapsed, WorkspacePanelDisplayMode panelMode})
            >(
              (view) => (
                collapsed: view.homeWorkspaceNavigationCollapsed,
                panelMode: view.workspacePanelDisplayMode,
              ),
            );
        return WorkspaceFrame(
          controller: _pane,
          contextSnapshot: WorkspaceContextSnapshot(
            enabledWorkspaces: enabledWorkspaces,
            mode: AppMode.student,
            view: _viewMode?.name ?? 'week',
            resourceId: resourceId,
          ),
          active: widget.active,
          resourcesCollapsed: preferences.collapsed,
          panelDisplayMode: preferences.panelMode,
          canvas: workspace,
          resources:
              Selector<
                StudentViewState,
                ({List<TimetableData> timetables, String? activeId})
              >(
                selector: (_, view) => (
                  timetables: view.timetables,
                  activeId: view.activeTimetableOrNull?.id,
                ),
                builder: (context, resources, _) {
                  final l10n = AppLocalizations.of(context);
                  final resourcesExpanded =
                      WorkspaceResourceScope.maybeOf(context)?.drawerOpen ==
                          true ||
                      WorkspaceCanvasScope.maybeOf(context)
                              ?.resourcePresentation ==
                          WorkspaceResourcePresentation.expanded;
                  return WorkspaceResourcePanel(
                    title: l10n.timetable,
                    onOpenResourcesAt: widget.interactive && !resourcesExpanded
                        ? (anchor) => _showTimetablePicker(
                            context,
                            availableWidth: 560,
                            anchorContext: anchor,
                          )
                        : null,
                    settingsFocusNode: widget.settingsFocusNode,
                    onSettings:
                        widget.showSettingsAction && widget.settingsEnabled
                        ? widget.settingsAction ?? () => _openSettingsPage()
                        : null,

                    headerActions: [
                      Builder(
                        builder: (anchor) => IconButton(
                          tooltip: l10n.createTimetable,
                          icon: const Icon(Icons.add),
                          onPressed:
                              _courseEditorOpen || _timetableItemDialogOpen
                              ? null
                              : () => _openCreateTimetableDialog(
                                  context,
                                  editor: WorkspaceEditorConfiguration(
                                    anchorContext: anchor,
                                  ),
                                ),
                        ),
                      ),
                      Builder(
                        builder: (anchor) => SkedPopupMenuButton<String>(
                          key: const ValueKey('student-resource-menu'),
                          // Popup defaults otherwise override the compact icon theme.
                          style: WorkbenchChromeMetrics.of(context).iconStyle,
                          tooltip: l10n.more,
                          icon: const Icon(Icons.more_horiz),
                          onSelected: (value) => value == 'periods'
                              ? _managePeriodTimeSets()
                              : openWorkspaceTransfer(
                                  context,
                                  AppMode.student,
                                  direction: value == 'import'
                                      ? SettingsTransferDirection.import
                                      : SettingsTransferDirection.export,
                                ),
                          itemBuilder: (_) => [
                            SkedPopupMenuItem(
                              value: 'periods',
                              child: Text(l10n.managePeriodTimeSets),
                            ),
                            SkedPopupMenuItem(
                              value: 'import',
                              child: Text(l10n.importAction),
                            ),
                            SkedPopupMenuItem(
                              value: 'export',
                              child: Text(l10n.exportAction),
                            ),
                          ],
                        ),
                      ),
                    ],
                    children: [
                      for (final timetable in resources.timetables)
                        TimetableResourceRow(
                          key: ValueKey('resource-timetable-${timetable.id}'),
                          timetableId: timetable.id,
                          name: timetable.config.name,
                          selected: timetable.id == resources.activeId,
                          onSelected: widget.interactive
                              ? () => _switchTimetableFromPicker(
                                  context,
                                  timetable,
                                )
                              : null,
                          onEditAt:
                              _courseEditorOpen || _timetableItemDialogOpen
                              ? null
                              : (anchor) => _openTimetableItemDialog(
                                  context,
                                  timetable,
                                  editor: WorkspaceEditorConfiguration(
                                    anchorContext: anchor,
                                  ),
                                ),
                        ),
                    ],
                  );
                },
              ),
        );
      },
    );
    if (widget.embedded) return framed;
    return Scaffold(key: widget.scaffoldKey, body: framed);
  }

  void _ensureLocalViewState({
    required TimetableConfig config,
    required int selectedWeek,
  }) {
    // A new timetable always opens in the week view. Once initialized, keep
    // the user's selection stable across window and text-scale changes.
    _viewMode ??= _StudentTimetableView.week;
    _selectedWeekday ??= selectedWeek == currentWeekFor(config)
        ? normalizeDayOfWeek(DateTime.now().weekday)
        : DateTime.monday;
  }

  void _ensurePageController(int week) {
    final targetPage = week - 1;
    if (_pageController == null) {
      _pageController = PageController(initialPage: targetPage);
      return;
    }
    if (_weekNavigationTarget != null || _weekPageScrolling) return;
    if (_scheduledWeekPageSync == targetPage) return;
    _scheduledWeekPageSync = targetPage;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scheduledWeekPageSync == targetPage) {
        _scheduledWeekPageSync = null;
      }
      if (!mounted ||
          _weekNavigationTarget != null ||
          _weekPageScrolling ||
          _pageController == null ||
          !_pageController!.hasClients) {
        return;
      }
      final currentPage = _pageController!.page;
      if (currentPage == null || (currentPage - targetPage).abs() >= 0.01) {
        _pageController!.jumpToPage(targetPage);
      }
    });
  }

  Future<void> _jumpWeekBy(int offset) async {
    if (!mounted) return;
    final student = context.read<StudentViewState>();
    final timetable = student.activeTimetableOrNull;
    if (timetable == null || offset == 0) {
      return;
    }
    final currentWeek = _weekNavigationTarget ?? student.selectedWeek;
    final targetWeek = (currentWeek + offset).clamp(
      1,
      timetable.config.totalWeeks,
    );
    if (targetWeek == currentWeek) {
      return;
    }
    await _animateToWeek(targetWeek);
  }

  Future<void> _settleWeekFromPager(int settledWeek) async {
    if (!mounted) return;
    final student = context.read<StudentViewState>();
    final timetable = student.activeTimetableOrNull;
    if (!mounted || timetable == null || _weekNavigationTarget != null) return;
    final targetWeek = settledWeek.clamp(1, timetable.config.totalWeeks);
    if (targetWeek == student.selectedWeek) return;

    final commands = context.read<StudentCommands>();
    setState(() => _weekNavigationTarget = targetWeek);
    try {
      await commands.setSelectedWeek(targetWeek);
    } finally {
      if (_weekNavigationTarget == targetWeek) {
        if (mounted) {
          setState(() => _weekNavigationTarget = null);
        } else {
          _weekNavigationTarget = null;
        }
      }
    }
  }

  Future<void> _jumpToToday(int realCurrentWeek) async {
    final todayWeekday = normalizeDayOfWeek(DateTime.now().weekday);
    if (_selectedWeekday != todayWeekday && mounted) {
      setState(() => _selectedWeekday = todayWeekday);
    }
    await _animateToWeek(realCurrentWeek);
  }

  Future<void> _animateToWeek(
    int week, {
    bool Function()? isSessionCurrent,
  }) async {
    if (!mounted || isSessionCurrent?.call() == false) return;
    final student = context.read<StudentViewState>();
    final commands = context.read<StudentCommands>();
    final sessionChanges = Listenable.merge([
      student,
      context.read<AppDataMaintenance>(),
      context.read<WorkspaceViewState>(),
    ]);
    var sessionValid = true;
    void validateSession() {
      sessionValid = sessionValid && isSessionCurrent?.call() != false;
    }

    if (isSessionCurrent != null) sessionChanges.addListener(validateSession);
    final navigationGeneration = ++_weekNavigationGeneration;
    final originWeek = _weekNavigationTarget ?? student.selectedWeek;
    final direction = week.compareTo(originWeek).sign;
    if (mounted) {
      setState(() {
        _weekNavigationDirection = direction;
        _weekNavigationTarget = week;
      });
    } else {
      _weekNavigationDirection = direction;
      _weekNavigationTarget = week;
    }
    try {
      final controller = _pageController;
      final targetPage = week - 1;
      if (controller != null && controller.hasClients) {
        final motion = SkedMotionPolicy.of(context);
        if (!motion.spatialAnimationsEnabled) {
          controller.jumpToPage(targetPage);
        } else {
          await controller.animateToPage(
            targetPage,
            duration: motion.effects(SkedMotionSpeed.standard),
            curve: motion.scheme.standardCurve,
          );
        }
      }
      validateSession();
      if (!mounted ||
          !sessionValid ||
          navigationGeneration != _weekNavigationGeneration) {
        return;
      }
      await commands.setSelectedWeek(week);
    } finally {
      if (isSessionCurrent != null) {
        sessionChanges.removeListener(validateSession);
      }
      if (navigationGeneration == _weekNavigationGeneration) {
        _weekNavigationTarget = null;
        if (mounted && _weekNavigationDirection != 0) {
          setState(() => _weekNavigationDirection = 0);
        }
      }
    }
  }
}

class _StudentHomeSnapshot {
  const _StudentHomeSnapshot({
    required this.activeTimetable,
    required this.periodTimes,
    required this.selectedWeek,
    required this.localeCode,
    required this.preserveTimetableGaps,
    required this.showPastEndedCourses,
    required this.showFutureCourses,
    required this.showTimetableGridLines,
    required this.fitDaySelectorToWidth,
    required this.fitWeekColumnsToWidth,
    required this.enableWeekSwipeNavigation,
    required this.enableLongPressAddCourse,
    required this.showAddCourseFab,
    required this.themeMode,
    required this.themeColorMode,
    required this.themeSeedColorValue,
    required this.colorfulUiColorValues,
    required this.courseNameColorValues,
    required this.colorfulCourseTextColorMode,
    required this.conflictDisplayCourseIds,
    required this.liveCourseOutlineEnabled,
    required this.liveCourseOutlineFollowTheme,
    required this.liveCourseOutlineColorValue,
    required this.liveCourseOutlineMode,
    required this.liveCourseOutlineWidth,
    required this.toolbarNavigationOrder,
    required this.hiddenToolbarNavigationIds,
    required this.toolbarHiddenItemsBehavior,
  });

  factory _StudentHomeSnapshot.from(StudentViewState student) {
    final data = student.data;
    final timetable = student.activeTimetableOrNull;
    return _StudentHomeSnapshot(
      activeTimetable: timetable,
      periodTimes: timetable == null
          ? const []
          : student.periodTimesForTimetable(timetable),
      selectedWeek: student.selectedWeek,
      localeCode: student.localeCode,
      preserveTimetableGaps: data.preserveTimetableGaps,
      showPastEndedCourses: data.showPastEndedCourses,
      showFutureCourses: data.showFutureCourses,
      showTimetableGridLines: data.showTimetableGridLines,
      fitDaySelectorToWidth: data.fitDaySelectorToWidth,
      fitWeekColumnsToWidth: data.fitWeekColumnsToWidth,
      enableWeekSwipeNavigation: data.enableWeekSwipeNavigation,
      enableLongPressAddCourse: data.enableLongPressAddCourse,
      showAddCourseFab: data.showAddCourseFab,
      themeMode: data.themeMode,
      themeColorMode: data.themeColorMode,
      themeSeedColorValue: data.themeSeedColorValue,
      colorfulUiColorValues: data.colorfulUiColorValues,
      courseNameColorValues: data.courseNameColorValues,
      colorfulCourseTextColorMode: data.colorfulCourseTextColorMode,
      conflictDisplayCourseIds: data.conflictDisplayCourseIds,
      liveCourseOutlineEnabled: data.liveCourseOutlineEnabled,
      liveCourseOutlineFollowTheme: data.liveCourseOutlineFollowTheme,
      liveCourseOutlineColorValue: data.liveCourseOutlineColorValue,
      liveCourseOutlineMode: data.liveCourseOutlineMode,
      liveCourseOutlineWidth: data.liveCourseOutlineWidth,
      toolbarNavigationOrder: data.toolbarNavigationOrder,
      hiddenToolbarNavigationIds: data.hiddenToolbarNavigationIds,
      toolbarHiddenItemsBehavior: data.toolbarHiddenItemsBehavior,
    );
  }

  final TimetableData? activeTimetable;
  final List<CoursePeriodTime> periodTimes;
  final int selectedWeek;
  final String localeCode;
  final bool preserveTimetableGaps;
  final bool showPastEndedCourses;
  final bool showFutureCourses;
  final bool showTimetableGridLines;
  final bool fitDaySelectorToWidth;
  final bool fitWeekColumnsToWidth;
  final bool enableWeekSwipeNavigation;
  final bool enableLongPressAddCourse;
  final bool showAddCourseFab;
  final String themeMode;
  final String themeColorMode;
  final int themeSeedColorValue;
  final Map<String, int> colorfulUiColorValues;
  final Map<String, int> courseNameColorValues;
  final String colorfulCourseTextColorMode;
  final Map<String, String> conflictDisplayCourseIds;
  final bool liveCourseOutlineEnabled;
  final bool liveCourseOutlineFollowTheme;
  final int liveCourseOutlineColorValue;
  final String liveCourseOutlineMode;
  final double liveCourseOutlineWidth;
  final List<String> toolbarNavigationOrder;
  final List<String> hiddenToolbarNavigationIds;
  final String toolbarHiddenItemsBehavior;

  String? displayedCourseIdForConflict(String key) =>
      readDisplayedCourseIdForConflict(conflictDisplayCourseIds, key);

  @override
  bool operator ==(Object other) {
    return other is _StudentHomeSnapshot &&
        identical(other.activeTimetable, activeTimetable) &&
        identical(other.periodTimes, periodTimes) &&
        other.selectedWeek == selectedWeek &&
        other.localeCode == localeCode &&
        other.preserveTimetableGaps == preserveTimetableGaps &&
        other.showPastEndedCourses == showPastEndedCourses &&
        other.showFutureCourses == showFutureCourses &&
        other.showTimetableGridLines == showTimetableGridLines &&
        other.fitDaySelectorToWidth == fitDaySelectorToWidth &&
        other.fitWeekColumnsToWidth == fitWeekColumnsToWidth &&
        other.enableWeekSwipeNavigation == enableWeekSwipeNavigation &&
        other.enableLongPressAddCourse == enableLongPressAddCourse &&
        other.showAddCourseFab == showAddCourseFab &&
        other.themeMode == themeMode &&
        other.themeColorMode == themeColorMode &&
        other.themeSeedColorValue == themeSeedColorValue &&
        identical(other.colorfulUiColorValues, colorfulUiColorValues) &&
        identical(other.courseNameColorValues, courseNameColorValues) &&
        other.colorfulCourseTextColorMode == colorfulCourseTextColorMode &&
        identical(other.conflictDisplayCourseIds, conflictDisplayCourseIds) &&
        other.liveCourseOutlineEnabled == liveCourseOutlineEnabled &&
        other.liveCourseOutlineFollowTheme == liveCourseOutlineFollowTheme &&
        other.liveCourseOutlineColorValue == liveCourseOutlineColorValue &&
        other.liveCourseOutlineMode == liveCourseOutlineMode &&
        other.liveCourseOutlineWidth == liveCourseOutlineWidth &&
        _listEquals(other.toolbarNavigationOrder, toolbarNavigationOrder) &&
        _listEquals(
          other.hiddenToolbarNavigationIds,
          hiddenToolbarNavigationIds,
        ) &&
        other.toolbarHiddenItemsBehavior == toolbarHiddenItemsBehavior;
  }

  @override
  int get hashCode => Object.hashAll([
    identityHashCode(activeTimetable),
    identityHashCode(periodTimes),
    selectedWeek,
    localeCode,
    preserveTimetableGaps,
    showPastEndedCourses,
    showFutureCourses,
    showTimetableGridLines,
    fitDaySelectorToWidth,
    fitWeekColumnsToWidth,
    enableWeekSwipeNavigation,
    enableLongPressAddCourse,
    showAddCourseFab,
    themeMode,
    themeColorMode,
    themeSeedColorValue,
    identityHashCode(colorfulUiColorValues),
    identityHashCode(courseNameColorValues),
    colorfulCourseTextColorMode,
    identityHashCode(conflictDisplayCourseIds),
    liveCourseOutlineEnabled,
    liveCourseOutlineFollowTheme,
    liveCourseOutlineColorValue,
    liveCourseOutlineMode,
    liveCourseOutlineWidth,
    Object.hashAll(toolbarNavigationOrder),
    Object.hashAll(hiddenToolbarNavigationIds),
    toolbarHiddenItemsBehavior,
  ]);
}

bool _listEquals(List<String> a, List<String> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
