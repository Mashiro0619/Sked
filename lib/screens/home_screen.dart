import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/timetable_models.dart';
import '../providers/timetable_provider.dart';
import '../widgets/app_layout_tokens.dart';
import '../widgets/app_modal_sheet.dart';
import '../widgets/course_details_sheet.dart';
import '../widgets/course_editor_sheet.dart';
import '../widgets/expressive_empty_state.dart';
import '../widgets/expressive_dialog.dart';
import '../widgets/mode_switch_action.dart';
import '../widgets/text_transfer_widgets.dart';
import '../widgets/timetable_grid.dart';
import '../widgets/ui_command.dart';
import 'settings_page.dart';
import 'timetable_import_flow.dart';

part 'home_screen_course_actions.dart';
part 'home_screen_imports.dart';
part 'home_screen_timetable_management.dart';
part 'home_screen_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  PageController? _pageController;
  bool _weekPickerOpen = false;
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

  Future<void> _addTimetableOnce(TimetableProvider provider) async {
    if (_addTimetableInProgress || !mounted) {
      return;
    }
    _setAddTimetableInProgress(true);
    try {
      await runUiCommandWithFeedback(
        context: context,
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

  Future<void> _switchTimetableFromDrawer(
    BuildContext drawerContext,
    TimetableProvider provider,
    TimetableData activeTimetable,
    TimetableData targetTimetable,
  ) async {
    if (_timetableSwitchInProgress) {
      return;
    }
    _setTimetableSwitchInProgress(true);
    try {
      var saved = true;
      if (targetTimetable.id != activeTimetable.id) {
        saved = await runUiCommandWithFeedback(
          context: drawerContext,
          debugLabel: 'Switch timetable',
          command: () => provider.switchTimetable(targetTimetable.id),
        );
      }
      if (saved && drawerContext.mounted) {
        await Navigator.of(drawerContext).maybePop();
      }
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
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final timetable = snapshot.activeTimetable;
        if (timetable == null) {
          return Scaffold(
            appBar: AppBar(
              title: Text(l10n.appTitle),
              actions: const [ModeSwitchAction()],
            ),
            body: _EmptyTimetableState(
              onCreate: _addTimetableInProgress
                  ? null
                  : () => _addTimetableOnce(provider),
              onImport: _fileImportInProgress
                  ? null
                  : () => _importTimetableData(context, provider),
              onImportFromText: _textImportPageOpen
                  ? null
                  : () => _importTimetablesFromText(context, provider),
              onImportFromWeb: _schoolWebImportPageOpen
                  ? null
                  : () => _importTimetableFromWeb(context, provider),
            ),
          );
        }

        final config = timetable.config;
        final week = snapshot.selectedWeek;
        _ensurePageController(week);

        return Scaffold(
          appBar: _StudentHomeAppBar(
            provider: provider,
            timetable: timetable,
            week: week,
            onTitleTap: _weekPickerOpen
                ? null
                : () => _showWeekPicker(
                    context,
                    provider,
                    config.totalWeeks,
                    currentWeekFor(config),
                  ),
            onAddCourse: _courseEditorOpen
                ? null
                : () => _openEditor(context, provider),
            onOpenSettings: _settingsPageOpen
                ? null
                : () => _openSettingsPage(provider),
          ),
          drawer: _TimetableDrawer(
            provider: provider,
            activeTimetable: timetable,
            switchingTimetable: _timetableSwitchInProgress,
            onSwitchTimetable: _timetableSwitchInProgress
                ? null
                : (drawerContext, item) => _switchTimetableFromDrawer(
                    drawerContext,
                    provider,
                    timetable,
                    item,
                  ),
            onEditTimetable:
                _timetableItemDialogOpen || _timetableSwitchInProgress
                ? null
                : (item) =>
                      _openTimetableItemDialog(this.context, provider, item),
            onCreateTimetable:
                _addTimetableInProgress || _timetableSwitchInProgress
                ? null
                : () => _addTimetableOnce(provider),
          ),
          body: _TimetableWeekPager(
            controller: _pageController!,
            provider: provider,
            timetable: timetable,
            config: config,
            onJumpWeekBy: (offset) => _jumpWeekBy(provider, offset),
            onCourseTap: (info) => _openDetails(context, provider, info),
            onEmptySlotTap: (slotInfo) => _openEditor(
              context,
              provider,
              weekday: slotInfo.weekday,
              emptySlot: slotInfo,
            ),
          ),
        );
      },
    );
  }

  void _ensurePageController(int week) {
    // 周数要等 provider 异步加载完成后才稳定，所以这里每次 build 都顺手校正一下页码。
    final targetPage = week - 1;
    if (_pageController == null) {
      _pageController = PageController(initialPage: targetPage);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _pageController == null || !_pageController!.hasClients) {
        return;
      }
      final currentPage = _pageController!.page?.round() ?? targetPage;
      if (currentPage != targetPage) {
        _pageController!.jumpToPage(targetPage);
      }
    });
  }

  Future<void> _jumpWeekBy(TimetableProvider provider, int offset) async {
    final timetable = provider.activeTimetableOrNull;
    if (timetable == null || offset == 0) {
      return;
    }
    final targetWeek = (provider.selectedWeek + offset).clamp(
      1,
      timetable.config.totalWeeks,
    );
    if (targetWeek == provider.selectedWeek) {
      return;
    }
    await _animateToWeek(provider, targetWeek);
  }

  Future<void> _animateToWeek(TimetableProvider provider, int week) async {
    final controller = _pageController;
    final targetPage = week - 1;
    if (controller == null || !controller.hasClients) {
      await provider.setSelectedWeek(week);
      return;
    }
    await controller.animateToPage(
      targetPage,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
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
