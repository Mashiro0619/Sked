import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/timetable_models.dart';
import '../providers/timetable_provider.dart';
import '../theme/sked_expressive_theme.dart';
import '../widgets/app_modal_sheet.dart';
import '../widgets/course_details_sheet.dart';
import '../widgets/course_editor_sheet.dart';
import '../widgets/expressive_empty_state.dart';
import '../widgets/expressive_dialog.dart';
import '../widgets/expressive_motion.dart';
import '../widgets/sked_expressive_components.dart';
import '../widgets/text_transfer_widgets.dart';
import '../widgets/timetable_grid.dart';
import '../widgets/ui_command.dart';
import 'settings_page.dart';
import 'timetable_import_flow.dart';

part 'home_screen_course_actions.dart';
part 'home_screen_imports.dart';
part 'home_screen_timetable_management.dart';
part 'home_screen_widgets.dart';

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

  /// Keeps the compact shell's single settings action in the workspace bar.
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
  bool _addTimetableInProgress = false;
  bool _settingsPageOpen = false;
  bool _fileImportInProgress = false;
  bool _textImportPageOpen = false;
  bool _schoolWebImportPageOpen = false;

  @override
  void dispose() {
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

  void _setAddTimetableInProgress(bool value) {
    if (_addTimetableInProgress == value) return;
    if (mounted) {
      setState(() => _addTimetableInProgress = value);
    } else {
      _addTimetableInProgress = value;
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

  Future<bool> _addTimetableOnce(
    TimetableProvider provider, {
    BuildContext? feedbackContext,
  }) async {
    if (_addTimetableInProgress || !mounted) {
      return false;
    }
    _setAddTimetableInProgress(true);
    try {
      return await runUiCommandWithFeedback(
        context: feedbackContext ?? context,
        debugLabel: 'Create timetable',
        command: provider.addTimetable,
      );
    } finally {
      _setAddTimetableInProgress(false);
    }
  }

  Future<void> _openSettingsPage(TimetableProvider provider) async {
    if (_settingsPageOpen || !mounted) {
      return;
    }
    _setSettingsPageOpen(true);
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider<TimetableProvider>.value(
            value: provider,
            child: const SettingsPage(),
          ),
        ),
      );
    } finally {
      _setSettingsPageOpen(false);
    }
  }

  Future<bool> _switchTimetableFromPicker(
    BuildContext pickerContext,
    TimetableProvider provider,
    TimetableData activeTimetable,
    TimetableData targetTimetable,
  ) async {
    if (_timetableSwitchInProgress) {
      return false;
    }
    _setTimetableSwitchInProgress(true);
    try {
      var saved = true;
      if (targetTimetable.id != activeTimetable.id) {
        saved = await runUiCommandWithFeedback(
          context: pickerContext,
          debugLabel: 'Switch timetable',
          command: () => provider.switchTimetable(targetTimetable.id),
        );
      }
      return saved;
    } finally {
      _setTimetableSwitchInProgress(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Selector<TimetableProvider, _StudentHomeSnapshot>(
      selector: (_, provider) => _StudentHomeSnapshot.from(provider),
      builder: (context, snapshot, child) {
        final provider = context.read<TimetableProvider>();
        final l10n = AppLocalizations.of(context);
        if (!snapshot.isLoaded) {
          return _wrapStandalone(
            const SafeArea(child: Center(child: CircularProgressIndicator())),
          );
        }
        return _wrapStandalone(
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final timetable = snapshot.activeTimetable;
                final horizontalInset = constraints.maxWidth < 600 ? 8.0 : 16.0;
                final settingsAction = !widget.settingsEnabled
                    ? null
                    : widget.settingsAction ??
                          (_settingsPageOpen
                              ? null
                              : () => _openSettingsPage(provider));

                if (timetable == null) {
                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalInset,
                      8,
                      horizontalInset,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SkedWorkspaceToolbar(
                          key: const ValueKey('student-workspace-toolbar'),
                          title: Text(l10n.appTitle),
                          actions: [
                            if (widget.showSettingsAction)
                              IconButton(
                                focusNode: widget.settingsFocusNode,
                                onPressed: settingsAction,
                                icon: const Icon(Icons.settings_outlined),
                                tooltip: l10n.settings,
                              ),
                          ],
                        ),
                        Expanded(
                          child: _EmptyTimetableState(
                            onCreate: _addTimetableInProgress
                                ? null
                                : () => _addTimetableOnce(provider),
                            onImport: _fileImportInProgress
                                ? null
                                : () => _importTimetableData(context, provider),
                            onImportFromText: _textImportPageOpen
                                ? null
                                : () => _importTimetablesFromText(
                                    context,
                                    provider,
                                  ),
                            onImportFromWeb: _schoolWebImportPageOpen
                                ? null
                                : () => _importTimetableFromWeb(
                                    context,
                                    provider,
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
                final fabVisible =
                    widget.active &&
                    widget.interactive &&
                    !_courseEditorOpen &&
                    !keyboardVisible;
                // Keep the viewport full-height so the grid remains visible
                // behind the FAB. The clearance is added only to the
                // scrollable grid content, allowing the final course to be
                // brought above the button without painting a blank strip.
                final fabContentInset = fabVisible ? 80.0 : 0.0;
                _ensurePageController(week);
                _ensureLocalViewState(
                  availableWidth: constraints.maxWidth,
                  config: config,
                  selectedWeek: week,
                );
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

                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalInset,
                    8,
                    horizontalInset,
                    0,
                  ),
                  child: Stack(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _StudentWorkspaceToolbar(
                            timetable: timetable,
                            week: week,
                            weekNavigationDirection:
                                _weekNavigationTarget == week
                                ? _weekNavigationDirection
                                : 0,
                            viewMode: viewMode,
                            compactWidth: constraints.maxWidth < 600,
                            compactHeight: constraints.maxHeight < 600,
                            interactive: widget.interactive,
                            showSettings: widget.showSettingsAction,
                            settingsFocusNode: widget.settingsFocusNode,
                            onOpenTimetablePicker: _timetablePickerOpen
                                ? null
                                : () => _showTimetablePicker(
                                    context,
                                    provider,
                                    timetable,
                                    availableWidth: constraints.maxWidth,
                                  ),
                            onOpenWeekPicker: _weekPickerOpen
                                ? null
                                : () => _showWeekPicker(
                                    context,
                                    provider,
                                    config.totalWeeks,
                                    realCurrentWeek,
                                  ),
                            onJumpToToday: widget.interactive
                                ? () => unawaited(
                                    _jumpToToday(provider, realCurrentWeek),
                                  )
                                : null,
                            onViewChanged: widget.interactive
                                ? (value) => setState(() => _viewMode = value)
                                : null,
                            onOpenSettings: settingsAction,
                          ),
                          const SizedBox(height: 4),
                          Expanded(
                            child: _TimetableWeekPager(
                              controller: _pageController!,
                              provider: provider,
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
                              onPageScrollStateChanged: (scrolling) {
                                _weekPageScrolling = scrolling;
                              },
                              onWeekSettled: (settledWeek) =>
                                  _settleWeekFromPager(provider, settledWeek),
                              onWeekdaySelected: (weekday) {
                                if (_selectedWeekday == weekday) return;
                                setState(() => _selectedWeekday = weekday);
                              },
                              onJumpWeekBy: (offset) =>
                                  _jumpWeekBy(provider, offset),
                              onCourseTap: (info) =>
                                  _openDetails(context, provider, info),
                              onEmptySlotTap: (slotInfo) => _openEditor(
                                context,
                                provider,
                                weekday: slotInfo.weekday,
                                emptySlot: slotInfo,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (fabVisible)
                        PositionedDirectional(
                          end: 12,
                          bottom: 16,
                          child: SkedPrimaryFab(
                            heroTag: 'student-add-course',
                            tooltip: l10n.addCourse,
                            onPressed: () => _openEditor(context, provider),
                            icon: const Icon(Icons.add),
                            label: constraints.maxWidth >= 760
                                ? Text(l10n.addCourse)
                                : null,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _wrapStandalone(Widget workspace) {
    if (widget.embedded) return workspace;
    return Scaffold(key: widget.scaffoldKey, body: workspace);
  }

  void _ensureLocalViewState({
    required double availableWidth,
    required TimetableConfig config,
    required int selectedWeek,
  }) {
    if (_viewMode == null) {
      final textTheme = Theme.of(context).textTheme;
      final scaler = MediaQuery.textScalerOf(context);
      final fontSize = textTheme.bodyLarge?.fontSize ?? 16;
      final usesLargeText = scaler.scale(fontSize) > fontSize * 1.3;
      _viewMode = availableWidth < 760 || usesLargeText
          ? _StudentTimetableView.day
          : _StudentTimetableView.week;
    }
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

  Future<void> _jumpWeekBy(TimetableProvider provider, int offset) async {
    final timetable = provider.activeTimetableOrNull;
    if (timetable == null || offset == 0) {
      return;
    }
    final currentWeek = _weekNavigationTarget ?? provider.selectedWeek;
    final targetWeek = (currentWeek + offset).clamp(
      1,
      timetable.config.totalWeeks,
    );
    if (targetWeek == currentWeek) {
      return;
    }
    await _animateToWeek(provider, targetWeek);
  }

  Future<void> _settleWeekFromPager(
    TimetableProvider provider,
    int settledWeek,
  ) async {
    final timetable = provider.activeTimetableOrNull;
    if (!mounted || timetable == null || _weekNavigationTarget != null) return;
    final targetWeek = settledWeek.clamp(1, timetable.config.totalWeeks);
    if (targetWeek == provider.selectedWeek) return;

    setState(() => _weekNavigationTarget = targetWeek);
    try {
      await provider.setSelectedWeek(targetWeek);
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

  Future<void> _jumpToToday(
    TimetableProvider provider,
    int realCurrentWeek,
  ) async {
    final todayWeekday = normalizeDayOfWeek(DateTime.now().weekday);
    if (_selectedWeekday != todayWeekday && mounted) {
      setState(() => _selectedWeekday = todayWeekday);
    }
    await _animateToWeek(provider, realCurrentWeek);
  }

  Future<void> _animateToWeek(TimetableProvider provider, int week) async {
    final navigationGeneration = ++_weekNavigationGeneration;
    final originWeek = _weekNavigationTarget ?? provider.selectedWeek;
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
      if (!mounted || navigationGeneration != _weekNavigationGeneration) return;
      await provider.setSelectedWeek(week);
    } finally {
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
    required this.isLoaded,
    required this.activeTimetable,
    required this.timetables,
    required this.periodTimeSets,
    required this.selectedWeek,
    required this.localeCode,
    required this.preserveTimetableGaps,
    required this.showPastEndedCourses,
    required this.showFutureCourses,
    required this.showTimetableGridLines,
    required this.fitDaySelectorToWidth,
    required this.fitWeekColumnsToWidth,
    required this.enableWeekSwipeNavigation,
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
  });

  factory _StudentHomeSnapshot.from(TimetableProvider provider) {
    final data = provider.studentMode;
    return _StudentHomeSnapshot(
      isLoaded: provider.isLoaded,
      activeTimetable: provider.activeTimetableOrNull,
      timetables: data.timetables,
      periodTimeSets: data.periodTimeSets,
      selectedWeek: provider.selectedWeek,
      localeCode: provider.localeCode,
      preserveTimetableGaps: data.preserveTimetableGaps,
      showPastEndedCourses: data.showPastEndedCourses,
      showFutureCourses: data.showFutureCourses,
      showTimetableGridLines: data.showTimetableGridLines,
      fitDaySelectorToWidth: data.fitDaySelectorToWidth,
      fitWeekColumnsToWidth: data.fitWeekColumnsToWidth,
      enableWeekSwipeNavigation: data.enableWeekSwipeNavigation,
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
    );
  }

  final bool isLoaded;
  final TimetableData? activeTimetable;
  final List<TimetableData> timetables;
  final List<PeriodTimeSet> periodTimeSets;
  final int selectedWeek;
  final String localeCode;
  final bool preserveTimetableGaps;
  final bool showPastEndedCourses;
  final bool showFutureCourses;
  final bool showTimetableGridLines;
  final bool fitDaySelectorToWidth;
  final bool fitWeekColumnsToWidth;
  final bool enableWeekSwipeNavigation;
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

  @override
  bool operator ==(Object other) {
    return other is _StudentHomeSnapshot &&
        other.isLoaded == isLoaded &&
        identical(other.activeTimetable, activeTimetable) &&
        identical(other.timetables, timetables) &&
        identical(other.periodTimeSets, periodTimeSets) &&
        other.selectedWeek == selectedWeek &&
        other.localeCode == localeCode &&
        other.preserveTimetableGaps == preserveTimetableGaps &&
        other.showPastEndedCourses == showPastEndedCourses &&
        other.showFutureCourses == showFutureCourses &&
        other.showTimetableGridLines == showTimetableGridLines &&
        other.fitDaySelectorToWidth == fitDaySelectorToWidth &&
        other.fitWeekColumnsToWidth == fitWeekColumnsToWidth &&
        other.enableWeekSwipeNavigation == enableWeekSwipeNavigation &&
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
        other.liveCourseOutlineWidth == liveCourseOutlineWidth;
  }

  @override
  int get hashCode => Object.hashAll([
    isLoaded,
    identityHashCode(activeTimetable),
    identityHashCode(timetables),
    identityHashCode(periodTimeSets),
    selectedWeek,
    localeCode,
    preserveTimetableGaps,
    showPastEndedCourses,
    showFutureCourses,
    showTimetableGridLines,
    fitDaySelectorToWidth,
    fitWeekColumnsToWidth,
    enableWeekSwipeNavigation,
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
  ]);
}
