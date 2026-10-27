import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/semantics.dart' show SemanticsProperties;
import 'package:material_ui/material_ui.dart';

import '../l10n/app_locale.dart';
import '../l10n/app_localizations.dart';
import '../models/timetable_models.dart';
import '../theme/color_contrast.dart';
import '../theme/sked_expressive_theme.dart';
import '../theme/timetable_contrast.dart';
import 'timetable_entry.dart';
import 'timetable_week_projection.dart';
import 'sked_calendar_day_label.dart';
import 'sked_floating_anchor.dart';
import 'workspace_frame.dart';
import 'workbench_chrome_metrics.dart';

export 'timetable_week_projection.dart'
    show CourseDisplayState, CourseLayout, OverlapGroup, buildOverlapGroups;

const _minuteHeight = 1.4;
const _compactHeaderHeight = 56.0;
const _regularHeaderHeight = 64.0;
const _minimumCourseHitExtent = 48.0;

class TimetableCourseTapInfo {
  const TimetableCourseTapInfo({
    required this.course,
    required this.courses,
    required this.isFullConflict,
    this.conflictKey,
    this.selectedWeek,
    this.anchorRect,
  });

  final CourseItem course;
  final List<CourseItem> courses;
  final bool isFullConflict;
  final String? conflictKey;

  /// Week rendered by this grid when the course was tapped.
  final int? selectedWeek;
  final Rect? anchorRect;

  TimetableCourseTapInfo copyWith({
    CourseItem? course,
    List<CourseItem>? courses,
    bool? isFullConflict,
    String? conflictKey,
    int? selectedWeek,
    Rect? anchorRect,
  }) {
    return TimetableCourseTapInfo(
      course: course ?? this.course,
      courses: courses ?? this.courses,
      isFullConflict: isFullConflict ?? this.isFullConflict,
      conflictKey: conflictKey ?? this.conflictKey,
      selectedWeek: selectedWeek ?? this.selectedWeek,
      anchorRect: anchorRect ?? this.anchorRect,
    );
  }
}

class TimetableEmptySlotTapInfo {
  const TimetableEmptySlotTapInfo({
    required this.weekday,
    required this.startMinutes,
    required this.endMinutes,
    required this.periods,
    this.anchorRect,
  });

  /// Bounds of the selected period, captured before opening an editor.
  final Rect? anchorRect;
  final int weekday;
  final int startMinutes;
  final int endMinutes;
  final List<int> periods;
}

/// 这里按真实时间排版课程块，这样换一套节次时间后，视觉位置也会跟着对齐。
class TimetableGrid extends StatefulWidget {
  const TimetableGrid({
    super.key,
    required this.timetable,
    required this.periodTimes,
    required this.weekDateStart,
    required this.selectedWeek,
    required this.realCurrentWeek,
    required this.localeCode,
    required this.preserveGaps,
    required this.showPastEndedCourses,
    required this.showFutureCourses,
    required this.showGridLines,
    required this.onCourseTap,
    required this.onEmptySlotTap,
    required this.themeColorMode,
    required this.courseNameColorValues,
    required this.colorfulCourseTextColorMode,
    this.colorfulCourseTextColorValue,
    this.displayedCourseIdForConflict,
    this.liveCourseTarget,
    required this.liveCourseOutlineEnabled,
    required this.liveCourseOutlineMode,
    required this.liveCourseOutlineColorValue,
    required this.liveCourseOutlineWidth,
    this.entries,
    this.onEntryTap,
    this.visibleWeekdays = const <int>[1, 2, 3, 4, 5, 6, 7],
    this.showDayHeader = true,
    this.bottomContentInset = 0,
    this.fitVisibleDaysToWidth = false,
    this.horizontalScrollLocked = false,
    this.onHorizontalPointerDown,
    this.onHorizontalEdgeDrag,
  }) : assert(visibleWeekdays.length > 0),
       assert(bottomContentInset >= 0);

  final TimetableData timetable;
  final List<CoursePeriodTime> periodTimes;
  final DateTime weekDateStart;
  final int selectedWeek;
  final int realCurrentWeek;
  final String localeCode;
  final bool preserveGaps;
  final bool showPastEndedCourses;
  final bool showFutureCourses;
  final bool showGridLines;
  final ValueChanged<TimetableCourseTapInfo> onCourseTap;
  final ValueChanged<TimetableEmptySlotTapInfo>? onEmptySlotTap;
  final String themeColorMode;
  final Map<String, int> courseNameColorValues;
  final String colorfulCourseTextColorMode;
  final int? colorfulCourseTextColorValue;
  final String? Function(String conflictKey)? displayedCourseIdForConflict;
  final TimetableLiveCourseTarget? liveCourseTarget;
  final bool liveCourseOutlineEnabled;
  final String liveCourseOutlineMode;
  final int liveCourseOutlineColorValue;
  final double liveCourseOutlineWidth;
  final List<TimetableEntry>? entries;
  final ValueChanged<TimetableEntry>? onEntryTap;
  final List<int> visibleWeekdays;
  final bool showDayHeader;
  final double bottomContentInset;

  /// Whether the visible day columns should share the available viewport
  /// width instead of retaining the minimum width used by scrollable grids.
  ///
  /// This is intentionally opt-in so generic grid callers keep the existing
  /// horizontally scrollable behavior.
  final bool fitVisibleDaysToWidth;

  /// Temporarily freezes the inner horizontal viewport while an ancestor
  /// pager takes over the same pointer gesture at the content edge.
  final bool horizontalScrollLocked;

  /// Marks pointers that start inside an overflowing horizontal viewport so
  /// the ancestor pager waits for an edge handoff before taking over.
  final ValueChanged<int>? onHorizontalPointerDown;

  /// Reports the finger delta when a horizontal drag continues beyond either
  /// edge. Ancestor pagers can use it to reveal an adjacent logical page.
  final ValueChanged<double>? onHorizontalEdgeDrag;

  @override
  State<TimetableGrid> createState() => _TimetableGridState();
}

class _TimetableGridState extends State<TimetableGrid> {
  final ScrollController _headerHorizontalController = ScrollController();
  final ScrollController _bodyHorizontalController = ScrollController();
  bool _syncingHorizontalScroll = false;
  bool _horizontalSyncScheduled = false;
  final _projectionCache = TimetableWeekProjectionCache();
  late TimetableWeekProjection _weekProjection;
  _TimetableVerticalLayout? _verticalLayout;
  final _dayGeometries =
      <
        int,
        ({
          List<CourseLayout> layouts,
          _TimetableVerticalLayout verticalLayout,
          double gap,
          List<_CourseGeometry> geometries,
        })
      >{};

  @override
  void initState() {
    super.initState();
    _updateWeekProjection();
    _headerHorizontalController.addListener(_syncHeaderToBody);
    _bodyHorizontalController.addListener(_syncBodyToHeader);
  }

  @override
  void didUpdateWidget(covariant TimetableGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateWeekProjection();
    _scheduleHorizontalSync();
  }

  void _updateWeekProjection() {
    _weekProjection = _projectionCache.project(
      timetable: widget.timetable,
      periodTimes: widget.periodTimes,
      selectedWeek: widget.selectedWeek,
      realCurrentWeek: widget.realCurrentWeek,
      showPastEndedCourses: widget.showPastEndedCourses,
      showFutureCourses: widget.showFutureCourses,
      preserveGaps: widget.preserveGaps || widget.entries != null,
      entries: widget.entries,
    );
  }

  _TimetableVerticalLayout _layoutFor(double minuteHeight) {
    final previous = _verticalLayout;
    final preserveGaps = widget.preserveGaps || widget.entries != null;
    if (previous != null &&
        identical(previous.slots, _weekProjection.periodTimes) &&
        listEquals(
          previous.occupiedGapRanges,
          _weekProjection.occupiedGapRanges,
        ) &&
        previous.preserveGaps == preserveGaps &&
        previous.minuteHeight == minuteHeight) {
      return previous;
    }
    return _verticalLayout = _TimetableVerticalLayout(
      slots: _weekProjection.periodTimes,
      occupiedGapRanges: _weekProjection.occupiedGapRanges,
      preserveGaps: preserveGaps,
      minuteHeight: minuteHeight,
    );
  }

  List<_CourseGeometry> _geometriesForDay(
    int weekday,
    List<CourseLayout> layouts,
    _TimetableVerticalLayout verticalLayout,
    double gap,
  ) {
    final previous = _dayGeometries[weekday];
    if (previous != null &&
        identical(previous.layouts, layouts) &&
        identical(previous.verticalLayout, verticalLayout) &&
        previous.gap == gap) {
      return previous.geometries;
    }
    final geometries = _buildCourseGeometries(
      layouts: layouts,
      verticalLayout: verticalLayout,
      visualGap: gap,
    );
    _dayGeometries[weekday] = (
      layouts: layouts,
      verticalLayout: verticalLayout,
      gap: gap,
      geometries: geometries,
    );
    return geometries;
  }

  Color? _customColorfulText() {
    if (widget.themeColorMode != themeColorModeColorful) return null;
    if (widget.colorfulCourseTextColorMode ==
            colorfulCourseTextColorModeCustom &&
        widget.colorfulCourseTextColorValue != null) {
      return Color(widget.colorfulCourseTextColorValue!);
    }
    return null;
  }

  @override
  void dispose() {
    _headerHorizontalController
      ..removeListener(_syncHeaderToBody)
      ..dispose();
    _bodyHorizontalController
      ..removeListener(_syncBodyToHeader)
      ..dispose();
    super.dispose();
  }

  void _syncHeaderToBody() {
    _syncHorizontalOffset(
      source: _headerHorizontalController,
      target: _bodyHorizontalController,
    );
  }

  void _syncBodyToHeader() {
    _syncHorizontalOffset(
      source: _bodyHorizontalController,
      target: _headerHorizontalController,
    );
  }

  void _syncHorizontalOffset({
    required ScrollController source,
    required ScrollController target,
  }) {
    if (_syncingHorizontalScroll ||
        !source.hasClients ||
        !target.hasClients ||
        !source.position.hasContentDimensions ||
        !target.position.hasContentDimensions) {
      return;
    }
    final targetOffset = source.offset.clamp(
      target.position.minScrollExtent,
      target.position.maxScrollExtent,
    );
    if ((target.offset - targetOffset).abs() < 0.5) return;
    _syncingHorizontalScroll = true;
    target.jumpTo(targetOffset);
    _syncingHorizontalScroll = false;
  }

  void _clampHorizontalOffsets() {
    final controllers =
        <ScrollController>[
              _headerHorizontalController,
              _bodyHorizontalController,
            ]
            .where(
              (controller) =>
                  controller.hasClients &&
                  controller.position.hasContentDimensions,
            )
            .toList();
    if (controllers.isEmpty) return;
    final hasCollapsedViewport = controllers.any(
      (controller) => controller.position.maxScrollExtent <= 0,
    );
    final desiredOffset = hasCollapsedViewport
        ? 0.0
        : controllers.map((controller) => controller.offset).reduce(math.min);
    _syncingHorizontalScroll = true;
    for (final controller in controllers) {
      final clamped = desiredOffset.clamp(
        controller.position.minScrollExtent,
        controller.position.maxScrollExtent,
      );
      if ((controller.offset - clamped).abs() >= 0.5) {
        controller.jumpTo(clamped);
      }
    }
    _syncingHorizontalScroll = false;
  }

  void _scheduleHorizontalSync() {
    if (_horizontalSyncScheduled) return;
    _horizontalSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _horizontalSyncScheduled = false;
      if (!mounted) return;
      _clampHorizontalOffsets();
    });
  }

  @override
  Widget build(BuildContext context) {
    _scheduleHorizontalSync();
    _validateVisibleWeekdays(widget.visibleWeekdays);
    final slots = _weekProjection.periodTimes;
    final textScaler = MediaQuery.textScalerOf(context);
    final textScale = textScaler.scale(1);
    final layout = _layoutFor(_minuteHeight * textScale.clamp(1.0, 1.8));
    final colors = Theme.of(context).colorScheme;
    final useEntries = widget.entries != null;
    assert(
      widget.entries == null || widget.onEntryTap != null,
      'onEntryTap must be provided when entries is provided',
    );
    final dayLayoutsByWeekday = _weekProjection.resolveLayouts(
      widget.displayedCourseIdForConflict,
    );
    final colorfulTextColor = _customColorfulText();

    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = _TimetableMetrics.fromWidth(
          constraints.maxWidth,
          visibleDayCount: widget.visibleWeekdays.length,
          textScaler: textScaler,
          textDirection: Directionality.of(context),
          textTheme: Theme.of(context).textTheme,
          periodTimes: slots,
          fitVisibleDaysToWidth: widget.fitVisibleDaysToWidth,
          desktop: WorkbenchChromeMetrics.of(context).desktop,
          courseSpacing: _weekProjection.courseSpacing,
        );
        final baseHeaderHeight = WorkbenchChromeMetrics.of(context).desktop
            ? 60.0
            : metrics.compact
            ? _compactHeaderHeight
            : _regularHeaderHeight;
        // The day header contains two stacked labels. Measure their actual
        // scaled line heights so large accessibility text gets room instead
        // of overflowing the fixed-size inner slot.
        final headerHeight = WorkbenchChromeMetrics.compactTouch(context)
            ? SkedCalendarDayLabel.measuredHeight(
                context,
                compact: metrics.compact,
                localeCode: widget.localeCode,
              )
            : math.max(
                baseHeaderHeight,
                _scaledDayHeaderHeight(
                  context,
                  compact: metrics.compact,
                  localeCode: widget.localeCode,
                  weekdays: widget.visibleWeekdays,
                ),
              );
        final availableDaysWidth = math.max(
          constraints.maxWidth - metrics.timeLabelWidth,
          0.0,
        );
        final horizontalContentOverflows =
            metrics.daysContentWidth > availableDaysWidth + 0.5;
        final horizontalPhysics =
            widget.horizontalScrollLocked || !horizontalContentOverflows
            ? const NeverScrollableScrollPhysics()
            : const AlwaysScrollableScrollPhysics(
                parent: ClampingScrollPhysics(),
              );

        bool reportHorizontalOverscroll(OverscrollNotification notification) {
          if (notification.metrics.axis != Axis.horizontal ||
              notification.dragDetails == null) {
            return false;
          }
          final delta = notification.dragDetails!.primaryDelta;
          if (delta != null && delta != 0) {
            widget.onHorizontalEdgeDrag?.call(delta);
          }
          return false;
        }

        final content = SizedBox(
          width: constraints.maxWidth,
          child: Column(
            children: [
              if (widget.showDayHeader)
                SizedBox(
                  key: const ValueKey('timetable-day-header'),
                  height: headerHeight,
                  child: Row(
                    children: [
                      SizedBox(
                        width: metrics.timeLabelWidth,
                        child: _MonthHeader(
                          date: widget.weekDateStart,
                          compact: metrics.compact,
                          localeCode: widget.localeCode,
                        ),
                      ),
                      Expanded(
                        child: NotificationListener<OverscrollNotification>(
                          onNotification: reportHorizontalOverscroll,
                          child: Listener(
                            onPointerDown: horizontalContentOverflows
                                ? (event) => widget.onHorizontalPointerDown
                                      ?.call(event.pointer)
                                : null,
                            onPointerPanZoomStart: horizontalContentOverflows
                                ? (event) => widget.onHorizontalPointerDown
                                      ?.call(event.pointer)
                                : null,
                            child: SingleChildScrollView(
                              key: const ValueKey(
                                'timetable-day-header-horizontal-scroll',
                              ),
                              controller: _headerHorizontalController,
                              scrollDirection: Axis.horizontal,
                              physics: horizontalPhysics,
                              child: SizedBox(
                                width: metrics.daysContentWidth,
                                child: Row(
                                  children: [
                                    for (final weekday
                                        in widget.visibleWeekdays)
                                      SizedBox(
                                        key: ValueKey(
                                          'timetable-day-header-$weekday',
                                        ),
                                        width: metrics.dayColumnWidth,
                                        child: _DayHeader(
                                          weekday: weekday,
                                          date: addCalendarDays(
                                            widget.weekDateStart,
                                            weekday - 1,
                                          ),
                                          compact: metrics.compact,
                                          localeCode: widget.localeCode,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  key: const ValueKey('timetable-grid-vertical-scroll'),
                  padding: EdgeInsets.only(bottom: widget.bottomContentInset),
                  child: SizedBox(
                    height: layout.totalHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          key: const ValueKey('timetable-time-rail'),
                          width: metrics.timeLabelWidth,
                          child: _TimeRail(
                            slots: slots,
                            layout: layout,
                            sidePadding: metrics.sidePadding,
                          ),
                        ),
                        Expanded(
                          child: Scrollbar(
                            controller: _bodyHorizontalController,
                            notificationPredicate: (notification) =>
                                notification.metrics.axis == Axis.horizontal,
                            child: NotificationListener<OverscrollNotification>(
                              onNotification: reportHorizontalOverscroll,
                              child: Listener(
                                onPointerDown: horizontalContentOverflows
                                    ? (event) => widget.onHorizontalPointerDown
                                          ?.call(event.pointer)
                                    : null,
                                onPointerPanZoomStart:
                                    horizontalContentOverflows
                                    ? (event) => widget.onHorizontalPointerDown
                                          ?.call(event.pointer)
                                    : null,
                                child: SingleChildScrollView(
                                  key: const ValueKey(
                                    'timetable-grid-horizontal-scroll',
                                  ),
                                  controller: _bodyHorizontalController,
                                  scrollDirection: Axis.horizontal,
                                  physics: horizontalPhysics,
                                  child: SizedBox(
                                    key: const ValueKey(
                                      'timetable-grid-horizontal-content',
                                    ),
                                    width: metrics.daysContentWidth,
                                    height: layout.totalHeight,
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        for (final weekday
                                            in widget.visibleWeekdays)
                                          _DayColumn(
                                            weekday: weekday,
                                            localeCode: widget.localeCode,
                                            emptySlotSemanticLabel:
                                                '${formatDayOfWeekLabel(weekday, localeCode: widget.localeCode)}, ${lookupAppLocalizations(appLocaleFromCode(widget.localeCode)).addCourse}',
                                            width: metrics.dayColumnWidth,
                                            borderColor: widget.showGridLines
                                                ? colors.outlineVariant
                                                      .withValues(alpha: 0.25)
                                                : Colors.transparent,
                                            showGridLines: widget.showGridLines,
                                            slots: slots,
                                            geometries: _geometriesForDay(
                                              weekday,
                                              dayLayoutsByWeekday[weekday]!,
                                              layout,
                                              metrics.courseVerticalGap,
                                            ),
                                            verticalLayout: layout,
                                            metrics: metrics,
                                            themeColorMode:
                                                widget.themeColorMode,
                                            courseNameColorValues:
                                                widget.courseNameColorValues,
                                            colorfulTextColor:
                                                colorfulTextColor,
                                            liveCourseOutlineMode:
                                                widget.liveCourseOutlineMode,
                                            liveCourseOutlineEnabled:
                                                widget.liveCourseOutlineEnabled,
                                            liveCourseTarget:
                                                widget.liveCourseTarget,
                                            selectedWeek: widget.selectedWeek,
                                            outlineColor: Color(
                                              widget
                                                  .liveCourseOutlineColorValue,
                                            ),
                                            outlineWidth:
                                                widget.liveCourseOutlineWidth,
                                            onLongPressAt:
                                                widget.onEmptySlotTap == null
                                                ? null
                                                : (localPosition, anchor) {
                                                    final matchedPeriod = layout
                                                        .slotForY(
                                                          localPosition.dy,
                                                        );
                                                    widget.onEmptySlotTap!(
                                                      TimetableEmptySlotTapInfo(
                                                        anchorRect: anchor,
                                                        weekday: weekday,
                                                        startMinutes:
                                                            matchedPeriod
                                                                .startMinutes,
                                                        endMinutes:
                                                            matchedPeriod
                                                                .endMinutes,
                                                        periods: [
                                                          matchedPeriod.index,
                                                        ],
                                                      ),
                                                    );
                                                  },
                                            onLayoutTap: (item, anchor) {
                                              if (useEntries &&
                                                  item.entry != null) {
                                                widget.onEntryTap!(item.entry!);
                                                return;
                                              }
                                              widget.onCourseTap(
                                                TimetableCourseTapInfo(
                                                  course: item.course!,
                                                  courses: item.conflictCourses
                                                      .map(
                                                        (course) =>
                                                            course
                                                                as CourseItem,
                                                      )
                                                      .toList(),
                                                  isFullConflict:
                                                      item.isFullConflict,
                                                  conflictKey: item.conflictKey,
                                                  selectedWeek:
                                                      widget.selectedWeek,
                                                  anchorRect: anchor,
                                                ),
                                              );
                                            },
                                          ),
                                      ],
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
              ),
            ],
          ),
        );
        if (!constraints.hasBoundedHeight) return content;
        // A keyboard can leave less room than the measured day header alone.
        // Keep the header and a usable grid viewport at their real sizes and
        // let that short surface scroll instead of overflowing the column.
        final minimumHeight = widget.showDayHeader
            ? headerHeight + _minimumCourseHitExtent
            : 0.0;
        final contentHeight = math.max(constraints.maxHeight, minimumHeight);
        return SingleChildScrollView(
          key: const ValueKey('timetable-grid-height-scroll'),
          primary: false,
          physics: contentHeight > constraints.maxHeight
              ? const ClampingScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          child: SizedBox(height: contentHeight, child: content),
        );
      },
    );
  }
}

/// 这些阈值先保证整周能塞进当前宽度，再去调留白和可读性。
void _validateVisibleWeekdays(List<int> weekdays) {
  if (weekdays.isEmpty ||
      weekdays.any(
        (weekday) => weekday < DateTime.monday || weekday > DateTime.sunday,
      ) ||
      weekdays.length != weekdays.toSet().length) {
    throw ArgumentError.value(
      weekdays,
      'visibleWeekdays',
      'must contain unique weekday values from 1 through 7',
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.weekday,
    required this.localeCode,
    required this.emptySlotSemanticLabel,
    required this.width,
    required this.borderColor,
    required this.showGridLines,
    required this.slots,
    required this.geometries,
    required this.verticalLayout,
    required this.metrics,
    required this.themeColorMode,
    required this.courseNameColorValues,
    required this.colorfulTextColor,
    required this.liveCourseOutlineMode,
    required this.liveCourseOutlineEnabled,
    required this.liveCourseTarget,
    required this.selectedWeek,
    required this.outlineColor,
    required this.outlineWidth,
    required this.onLongPressAt,
    required this.onLayoutTap,
  });

  final int weekday;
  final String localeCode;
  final String emptySlotSemanticLabel;
  final double width;
  final Color borderColor;
  final bool showGridLines;
  final List<CoursePeriodTime> slots;
  final List<_CourseGeometry> geometries;
  final _TimetableVerticalLayout verticalLayout;
  final _TimetableMetrics metrics;
  final String themeColorMode;
  final Map<String, int> courseNameColorValues;
  final Color? colorfulTextColor;
  final String liveCourseOutlineMode;
  final bool liveCourseOutlineEnabled;
  final TimetableLiveCourseTarget? liveCourseTarget;
  final int selectedWeek;
  final Color outlineColor;
  final double outlineWidth;
  final void Function(Offset position, Rect anchor)? onLongPressAt;
  final void Function(CourseLayout layout, Rect? anchor) onLayoutTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasDenseHitTargets = geometries.any(
      (geometry) => geometry.hitHeight < _minimumCourseHitExtent,
    );
    final content = Container(
      key: ValueKey('timetable-day-column-$weekday'),
      width: width,
      decoration: BoxDecoration(
        border: BorderDirectional(start: BorderSide(color: borderColor)),
      ),
      child: Builder(
        builder: (hitContext) => GestureDetector(
          key: ValueKey('timetable-day-column-long-press-$weekday'),
          behavior: HitTestBehavior.opaque,
          onLongPressStart: onLongPressAt == null
              ? null
              : (details) {
                  final y = details.localPosition.dy;
                  for (final geometry in geometries) {
                    if (y >= geometry.hitTop &&
                        y < geometry.hitTop + geometry.hitHeight) {
                      // Course hit targets own their long-press interaction.
                      return;
                    }
                  }
                  final slot = verticalLayout.slotForY(y);
                  final origin = details.globalPosition - details.localPosition;
                  onLongPressAt!(
                    details.localPosition,
                    Rect.fromLTWH(
                      origin.dx,
                      origin.dy + verticalLayout.slotTop(slot),
                      (hitContext.findRenderObject()! as RenderBox).size.width,
                      verticalLayout.slotHeight(slot),
                    ),
                  );
                },
          child: Material(
            color: Colors.transparent,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                if (showGridLines)
                  for (final slot in slots)
                    Positioned(
                      top: verticalLayout.slotTop(slot),
                      left: 0,
                      right: 0,
                      child: Container(
                        height: verticalLayout.slotHeight(slot),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: colors.outlineVariant.withValues(
                                alpha: 0.18,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                for (final geometry in geometries)
                  _CourseCard(
                    geometry: geometry,
                    metrics: metrics,
                    themeColorMode: themeColorMode,
                    courseNameColorValues: courseNameColorValues,
                    colorfulTextColor: colorfulTextColor,
                    liveCourseOutlineMode: liveCourseOutlineMode,
                    liveCourseOutlineEnabled: liveCourseOutlineEnabled,
                    liveCourseTarget: liveCourseTarget,
                    selectedWeek: selectedWeek,
                    outlineColor: outlineColor,
                    outlineWidth: outlineWidth,
                  ),
                for (final geometry in geometries)
                  _CourseHitTarget(
                    geometry: geometry,
                    metrics: metrics,
                    semanticLabel: _semanticLabelForGeometry(
                      geometry,
                      weekday: weekday,
                      selectedWeek: selectedWeek,
                      localeCode: localeCode,
                    ),
                    onTap: (anchor) => onLayoutTap(
                      geometry.layout,
                      SkedFloatingAnchor.capture(anchor).globalRect,
                    ),
                    onLongPress: (anchor) => onLayoutTap(
                      geometry.layout,
                      SkedFloatingAnchor.capture(anchor).globalRect,
                    ),
                    useVisualBounds:
                        hasDenseHitTargets &&
                        geometry.hitHeight < _minimumCourseHitExtent,
                    includeSemantics:
                        geometry.hitHeight >= _minimumCourseHitExtent,
                  ),
                for (final geometry in geometries)
                  if (geometry.hitHeight < _minimumCourseHitExtent)
                    _CourseSemanticTarget(
                      geometry: geometry,
                      totalHeight: verticalLayout.totalHeight,
                      semanticLabel: _semanticLabelForGeometry(
                        geometry,
                        weekday: weekday,
                        selectedWeek: selectedWeek,
                        localeCode: localeCode,
                      ),
                      onTap: (anchor) => onLayoutTap(
                        geometry.layout,
                        SkedFloatingAnchor.capture(anchor).globalRect,
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
    // Keep animation listeners local to this day when many cards are replaced.
    // A disabled ancestor still mutes the whole column, including ink effects.
    return TickerMode(
      enabled: true,
      child: Semantics(
        container: true,
        label: onLongPressAt == null ? null : emptySlotSemanticLabel,
        child: content,
      ),
    );
  }
}

class _TimeRail extends StatelessWidget {
  const _TimeRail({
    required this.slots,
    required this.layout,
    required this.sidePadding,
  });

  final List<CoursePeriodTime> slots;
  final _TimetableVerticalLayout layout;
  final double sidePadding;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        for (final slot in slots)
          Positioned(
            top: layout.slotTop(slot),
            left: 0,
            right: 0,
            child: SizedBox(
              height: layout.slotHeight(slot),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: sidePadding),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final showTimes =
                        constraints.maxHeight >=
                        MediaQuery.textScalerOf(context).scale(42);
                    return ClipRect(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            slot.index.toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (showTimes) ...[
                            const SizedBox(height: 2),
                            Text(
                              formatMinutes(slot.startMinutes),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: textTheme.labelSmall?.copyWith(
                                height: 1.15,
                                color: muted,
                              ),
                            ),
                            Text(
                              formatMinutes(slot.endMinutes),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: textTheme.labelSmall?.copyWith(height: 1),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TimetableMetrics {
  const _TimetableMetrics({
    required this.timeLabelWidth,
    required this.dayColumnWidth,
    required this.daysContentWidth,
    required this.courseGap,
    required this.courseVerticalGap,
    required this.cardPadding,
    required this.sidePadding,
    required this.compact,
  });

  final double timeLabelWidth;
  final double dayColumnWidth;
  final double daysContentWidth;
  final double courseGap;
  final double courseVerticalGap;
  final double cardPadding;
  final double sidePadding;
  final bool compact;

  factory _TimetableMetrics.fromWidth(
    double width, {
    required int visibleDayCount,
    required TextScaler textScaler,
    required TextDirection textDirection,
    required TextTheme textTheme,
    required List<CoursePeriodTime> periodTimes,
    required bool fitVisibleDaysToWidth,
    required bool desktop,
    required bool courseSpacing,
  }) {
    final safeWidth = width.isFinite && width > 0 ? width : 980.0;
    final timeLabelTextStyle = textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w800,
    );
    final clockTextStyle = textTheme.labelSmall?.copyWith(height: 1);
    final textScale = textScaler.scale(1);
    final sidePadding = textScale > 1.3 ? 2.0 : 4.0;
    var measuredTimeWidth = 0.0;
    for (final slot in periodTimes) {
      for (final text in <String>[
        slot.index.toString(),
        formatMinutes(slot.startMinutes),
        formatMinutes(slot.endMinutes),
      ]) {
        final style = text == slot.index.toString()
            ? timeLabelTextStyle
            : clockTextStyle;
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: textDirection,
          textScaler: textScaler,
          maxLines: 1,
        )..layout();
        measuredTimeWidth = math.max(measuredTimeWidth, painter.width);
        painter.dispose();
      }
    }
    // Keep a compact but usable rail. The padding is the actual breathing
    // room around measured labels, rather than a viewport-size heuristic.
    // Keep the default rail compact even with unusually wide fallback glyphs.
    // Enlarged text still receives its full measured width.
    final measuredRailWidth = measuredTimeWidth + (sidePadding * 2);
    final timeLabelWidth = textScale <= 1.0
        ? measuredRailWidth.clamp(48.0, 56.0)
        : math.max(48.0, measuredRailWidth);
    final availableDaysWidth = math.max(safeWidth - timeLabelWidth, 0.0);
    final minimumDayWidth = visibleDayCount == 1
        ? 0.0
        : textScale > 1.7
        ? 156.0
        : textScale > 1.3
        ? 136.0
        : 112.0;
    final daysContentWidth = fitVisibleDaysToWidth && visibleDayCount > 1
        ? availableDaysWidth
        : math.max(availableDaysWidth, minimumDayWidth * visibleDayCount);
    final dayColumnWidth = daysContentWidth / visibleDayCount;
    final compact = dayColumnWidth < 140;
    return _TimetableMetrics(
      timeLabelWidth: timeLabelWidth,
      dayColumnWidth: dayColumnWidth,
      daysContentWidth: daysContentWidth,
      courseGap: desktop
          ? (courseSpacing ? 4.0 : 3.0)
          : dayColumnWidth < 72
          ? 2.0
          : compact
          ? 4.0
          : 6.0,
      courseVerticalGap: desktop
          ? (courseSpacing ? 8.0 : 3.0)
          : dayColumnWidth < 72
          ? 2.0
          : compact
          ? 4.0
          : 6.0,
      cardPadding: desktop
          ? 6.0
          : dayColumnWidth < 72
          ? 3.0
          : compact
          ? 6.0
          : 8.0,
      sidePadding: sidePadding,
      compact: compact,
    );
  }
}

double _scaledDayHeaderHeight(
  BuildContext context, {
  required bool compact,
  required String localeCode,
  required List<int> weekdays,
}) {
  final theme = Theme.of(context);
  final textScaler = MediaQuery.textScalerOf(context);
  final textDirection = Directionality.of(context);
  final weekdayStyle = compact
      ? theme.textTheme.labelMedium
      : theme.textTheme.titleSmall;
  final dateStyle = compact
      ? theme.textTheme.labelLarge
      : theme.textTheme.titleMedium;
  var maxWeekdayHeight = 0.0;
  for (final weekday in weekdays) {
    final weekdayPainter = TextPainter(
      text: TextSpan(
        text: formatWeekdayShortLabel(weekday, localeCode: localeCode),
        style: weekdayStyle,
      ),
      textDirection: textDirection,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    maxWeekdayHeight = math.max(maxWeekdayHeight, weekdayPainter.height);
    weekdayPainter.dispose();
  }
  final datePainter = TextPainter(
    text: TextSpan(text: '88', style: dateStyle),
    textDirection: textDirection,
    textScaler: textScaler,
    maxLines: 1,
  )..layout();
  final maxDateHeight = datePainter.height;
  datePainter.dispose();
  final datePadding = compact ? 4.0 : 6.0;
  // Text widgets can round their scaled line boxes up to the next device
  // pixel. Keep a small allowance so the measured header remains stable at
  // large accessibility text scales.
  return maxWeekdayHeight + 2 + maxDateHeight + datePadding + 18;
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.date,
    required this.compact,
    required this.localeCode,
  });

  final DateTime date;
  final bool compact;
  final String localeCode;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 1 : 4, vertical: 8),
      child: Center(
        child: Text(
          formatMonthLabel(date.month, localeCode: localeCode),
          maxLines: 1,
          overflow: TextOverflow.fade,
          softWrap: false,
          style: compact
              ? Theme.of(context).textTheme.labelSmall
              : Theme.of(context).textTheme.labelMedium,
        ),
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.weekday,
    required this.date,
    required this.compact,
    required this.localeCode,
  });
  final int weekday;
  final DateTime date;
  final bool compact;
  final String localeCode;
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: MaterialLocalizations.of(context).formatFullDate(date),
      excludeSemantics: true,
      child: SkedCalendarDayLabel(
        date: date,
        compact: compact,
        localeCode: localeCode,
      ),
    );
  }
}

class _TimetableVerticalLayout {
  static const _collapsedRangeHeight = 28.0;

  _TimetableVerticalLayout({
    required this.slots,
    required this.preserveGaps,
    required this.minuteHeight,
    required this.occupiedGapRanges,
  }) {
    _collapsedRanges = _buildCollapsedRanges(slots, occupiedGapRanges);
    totalHeight = slots.isEmpty
        ? 0
        : preserveGaps
        ? (slots.last.endMinutes - slots.first.startMinutes) * minuteHeight
        : _collapsedRanges.fold<double>(
            0,
            (sum, range) => sum + (range.$2 - range.$1) * minuteHeight,
          );
    _slotTops = [for (final slot in slots) minuteToY(slot.startMinutes)];
  }

  final List<CoursePeriodTime> slots;
  final bool preserveGaps;
  final double minuteHeight;
  final List<(int, int)> occupiedGapRanges;
  late final List<(int, int)> _collapsedRanges;
  late final List<double> _slotTops;
  late final double totalHeight;

  static List<(int, int)> _buildCollapsedRanges(
    List<CoursePeriodTime> slots,
    List<(int, int)> occupiedGapRanges,
  ) {
    final ranges = [
      for (final slot in slots) (slot.startMinutes, slot.endMinutes),
      ...occupiedGapRanges,
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    final merged = <(int, int)>[];
    for (final range in ranges) {
      if (range.$2 <= range.$1) continue;
      if (merged.isEmpty || range.$1 > merged.last.$2) {
        merged.add(range);
      } else {
        merged[merged.length - 1] = (
          merged.last.$1,
          math.max(merged.last.$2, range.$2),
        );
      }
    }
    return merged;
  }

  static double _slotHeightFor(CoursePeriodTime slot, double minuteHeight) {
    return math.max(0, slot.endMinutes - slot.startMinutes) * minuteHeight;
  }

  int _slotIndex(CoursePeriodTime slot) {
    final index = slots.indexWhere((item) => item.index == slot.index);
    return index < 0 ? 0 : index;
  }

  double slotTop(CoursePeriodTime slot) => _slotTops[_slotIndex(slot)];

  double slotHeight(CoursePeriodTime slot) =>
      _slotHeightFor(slot, minuteHeight);

  double minuteToY(int minute) {
    if (slots.isEmpty) {
      return 0;
    }
    final firstStart = preserveGaps
        ? slots.first.startMinutes
        : _collapsedRanges.first.$1;
    final lastEnd = preserveGaps
        ? slots.last.endMinutes
        : _collapsedRanges.last.$2;
    final clampedMinute = minute.clamp(firstStart, lastEnd).toInt();
    if (preserveGaps) {
      return (clampedMinute - firstStart) * minuteHeight;
    }
    var top = 0.0;
    for (final range in _collapsedRanges) {
      if (clampedMinute < range.$1) {
        return top;
      }
      if (clampedMinute <= range.$2) {
        return top + (clampedMinute - range.$1) * minuteHeight;
      }
      top += (range.$2 - range.$1) * minuteHeight;
    }
    return totalHeight;
  }

  double rangeTop(int startMinutes) {
    final top = minuteToY(startMinutes);
    if (!preserveGaps &&
        startMinutes > slots.last.endMinutes &&
        top >= totalHeight) {
      return _slotTops.last;
    }
    return top;
  }

  double rangeHeight(int startMinutes, int endMinutes) {
    final top = rangeTop(startMinutes);
    final mappedBottom = minuteToY(endMinutes);
    final height = math.max(0.0, mappedBottom - top).toDouble();
    if (height > 0 || endMinutes <= startMinutes || preserveGaps) {
      return height;
    }
    final anchorIndex = _slotIndexForCollapsedTop(top);
    final anchorHeight = slotHeight(slots[anchorIndex]);
    final fallbackHeight = math.max(_collapsedRangeHeight, anchorHeight);
    return math
        .min(fallbackHeight, math.max(0.0, totalHeight - top))
        .toDouble();
  }

  int _slotIndexForCollapsedTop(double top) {
    for (var index = 0; index < _slotTops.length; index++) {
      if (_slotTops[index] >= top - 0.001) return index;
    }
    return _slotTops.length - 1;
  }

  CoursePeriodTime slotForY(double y) {
    if (slots.isEmpty) {
      throw StateError('No period slots available');
    }
    final clampedY = totalHeight <= 0
        ? 0.0
        : y.clamp(0.0, math.max(totalHeight - 0.001, 0.0)).toDouble();
    for (var index = 0; index < slots.length; index++) {
      final bottom = _slotTops[index] + slotHeight(slots[index]);
      if (clampedY < bottom) {
        return slots[index];
      }
    }
    return slots.last;
  }
}

class _CourseGeometry {
  const _CourseGeometry({
    required this.layout,
    required this.startMinutes,
    required this.endMinutes,
    required this.visualTop,
    required this.visualHeight,
    required this.hitTop,
    required this.hitHeight,
  });

  final CourseLayout layout;
  final int startMinutes;
  final int endMinutes;
  final double visualTop;
  final double visualHeight;
  final double hitTop;
  final double hitHeight;
}

List<_CourseGeometry> _buildCourseGeometries({
  required List<CourseLayout> layouts,
  required _TimetableVerticalLayout verticalLayout,
  required double visualGap,
}) {
  final ranges =
      <
        ({
          CourseLayout layout,
          int startMinutes,
          int endMinutes,
          double top,
          double bottom,
        })
      >[];
  for (final layout in layouts) {
    final top = verticalLayout.rangeTop(layout.startMinutes);
    ranges.add((
      layout: layout,
      startMinutes: layout.startMinutes,
      endMinutes: layout.endMinutes,
      top: top,
      bottom:
          top +
          verticalLayout.rangeHeight(layout.startMinutes, layout.endMinutes),
    ));
  }

  return [
    for (final range in ranges)
      (() {
        final visualHeight = math.max(0.0, range.bottom - range.top);
        final center = range.top + (visualHeight / 2);
        double? previousBottom;
        double? nextTop;
        for (final other in ranges) {
          if (identical(other.layout, range.layout)) continue;
          if (other.bottom <= range.top &&
              (previousBottom == null || other.bottom > previousBottom)) {
            previousBottom = other.bottom;
          }
          if (other.top >= range.bottom &&
              (nextTop == null || other.top < nextTop)) {
            nextTop = other.top;
          }
        }

        // When timetable gaps are collapsed, two courses can otherwise share
        // the exact same visual boundary and read as one card. Reserve a
        // small, responsive gap between adjacent non-overlapping cards while
        // leaving their hit regions tied to the original time geometry.
        final previousDistance = previousBottom == null
            ? double.infinity
            : range.top - previousBottom;
        final nextDistance = nextTop == null
            ? double.infinity
            : nextTop - range.bottom;
        final topInset =
            previousDistance >= -0.5 && previousDistance < visualGap
            ? (visualGap - math.max(0.0, previousDistance)) / 2
            : 0.0;
        final bottomInset = nextDistance >= -0.5 && nextDistance < visualGap
            ? (visualGap - math.max(0.0, nextDistance)) / 2
            : 0.0;
        final requestedInset = topInset + bottomInset;
        // Keep very short courses visible. Longer cards receive the full
        // requested separation; tiny cards proportionally keep at least a
        // one-pixel visual surface.
        final insetScale = requestedInset <= 0 || visualHeight <= 1
            ? 0.0
            : math.min(1.0, (visualHeight - 1) / requestedInset);
        final visualTop = range.top + (topInset * insetScale);
        final visualBottom = math.max(
          visualTop + (visualHeight > 0 ? math.min(1.0, visualHeight) : 0.0),
          range.bottom - (bottomInset * insetScale),
        );
        // Overlapping cards already share physical pixels. Extending a short
        // card's target can cover the still-visible part of a card behind it,
        // so their pointer regions must follow the painted bounds exactly.
        final hasVisualOverlap = ranges.any(
          (other) =>
              !identical(other.layout, range.layout) &&
              other.top < range.bottom &&
              other.bottom > range.top,
        );
        if (hasVisualOverlap) {
          return _CourseGeometry(
            layout: range.layout,
            startMinutes: range.startMinutes,
            endMinutes: range.endMinutes,
            visualTop: visualTop,
            visualHeight: math.max(0.0, visualBottom - visualTop),
            hitTop: visualTop,
            hitHeight: math.max(0.0, visualBottom - visualTop),
          );
        }
        final previousBoundary = previousBottom == null
            ? 0.0
            : (previousBottom + range.top) / 2;
        final nextBoundary = nextTop == null
            ? verticalLayout.totalHeight
            : (range.bottom + nextTop) / 2;
        final desiredTop = math.min(
          range.top,
          center - (_minimumCourseHitExtent / 2),
        );
        final desiredBottom = math.max(
          range.bottom,
          center + (_minimumCourseHitExtent / 2),
        );
        var hitTop = desiredTop.clamp(previousBoundary, nextBoundary);
        var hitBottom = desiredBottom.clamp(hitTop, nextBoundary);
        final missingExtent = _minimumCourseHitExtent - (hitBottom - hitTop);
        if (missingExtent > 0) {
          final growAfter = math.min(missingExtent, nextBoundary - hitBottom);
          hitBottom += growAfter;
          final growBefore = math.min(
            missingExtent - growAfter,
            hitTop - previousBoundary,
          );
          hitTop -= growBefore;
        }
        return _CourseGeometry(
          layout: range.layout,
          startMinutes: range.startMinutes,
          endMinutes: range.endMinutes,
          visualTop: visualTop,
          visualHeight: math.max(0.0, visualBottom - visualTop),
          hitTop: hitTop,
          hitHeight: math.max(0.0, hitBottom - hitTop),
        );
      })(),
  ];
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({
    required this.geometry,
    required this.metrics,
    required this.themeColorMode,
    required this.courseNameColorValues,
    required this.colorfulTextColor,
    required this.liveCourseOutlineMode,
    required this.liveCourseOutlineEnabled,
    required this.liveCourseTarget,
    required this.selectedWeek,
    required this.outlineColor,
    required this.outlineWidth,
  });

  final _CourseGeometry geometry;
  final _TimetableMetrics metrics;
  final String themeColorMode;
  final Map<String, int> courseNameColorValues;
  final Color? colorfulTextColor;
  final String liveCourseOutlineMode;
  final bool liveCourseOutlineEnabled;
  final TimetableLiveCourseTarget? liveCourseTarget;
  final int selectedWeek;
  final Color outlineColor;
  final double outlineWidth;

  CourseLayout get layout => geometry.layout;

  bool get _isPrimaryLiveTarget =>
      layout.course != null &&
      liveCourseOutlineEnabled &&
      liveCourseTarget?.week == selectedWeek &&
      liveCourseTarget?.weekday == layout.course!.dayOfWeek &&
      liveCourseTarget?.courseId == layout.course!.id;

  bool get _isLiveHighlighted =>
      layout.course != null &&
      liveCourseOutlineEnabled &&
      (liveCourseOutlineMode == liveCourseOutlineModeAllDisplayed ||
          _isPrimaryLiveTarget);

  bool get _isInactiveForCurrentWeek =>
      layout.entry?.isInactive ??
      layout.displayState != CourseDisplayState.active;

  bool get _isPastEnded =>
      layout.entry?.isPastEnded ??
      layout.displayState == CourseDisplayState.pastEnded;

  String get _title => layout.entry?.title ?? layout.course?.name ?? '';

  String get _location =>
      layout.entry?.location ?? layout.course?.location ?? '';

  String get _teacher => layout.entry?.teacher ?? layout.course?.teacher ?? '';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final width = math.max(
      0.0,
      metrics.dayColumnWidth - (metrics.courseGap * 2),
    );
    final cardHeight = geometry.visualHeight;
    final compact = width < 140 || cardHeight < 96;
    final desktop = WorkbenchChromeMetrics.of(context).desktop;
    final baseTitleStyle = compact
        ? textTheme.titleSmall
        : textTheme.titleMedium;
    var minimumTitleWidth = 0.0;
    if (!desktop) {
      final style = DefaultTextStyle.of(context).style
          .merge(baseTitleStyle)
          .copyWith(fontWeight: FontWeight.w700);
      final scaler = MediaQuery.textScalerOf(context);
      final ellipsis = TextPainter(
        text: TextSpan(text: '…', style: style),
        textDirection: Directionality.of(context),
        textScaler: scaler,
        locale: Localizations.maybeLocaleOf(context),
      )..layout();
      // A little room beyond an exact glyph-width boundary also avoids native
      // font fallback rounding a CJK line into the following glyph's space.
      minimumTitleWidth = math
          .max(
            scaler.scale(style.fontSize ?? 14) + (style.letterSpacing ?? 0),
            ellipsis.width,
          )
          .ceilToDouble();
      ellipsis.dispose();
    }
    final horizontalPadding = desktop
        ? metrics.cardPadding
        : math.min(
            metrics.cardPadding,
            math.max(0.0, (width - minimumTitleWidth) / 2),
          );
    final normalizedColorName =
        layout.entry?.colorName ??
        (layout.course != null
            ? normalizeCourseColorName(layout.course!.name)
            : '');
    final colorfulCourseBase = normalizedColorName.isEmpty
        ? null
        : courseNameColorValues[normalizedColorName];
    final entryColorValue = layout.entry?.colorValue;
    final activeBaseColor = entryColorValue != null
        ? Color(entryColorValue)
        : themeColorMode == themeColorModeColorful && colorfulCourseBase != null
        ? Color(colorfulCourseBase)
        : Color.lerp(
                colorScheme.secondaryContainer,
                colorScheme.primaryContainer,
                0.18 + (layout.priorityDepth * 0.18),
              ) ??
              colorScheme.secondaryContainer;
    final futureInactiveColor = themeColorMode == themeColorModeColorful
        ? Color.lerp(activeBaseColor, colorScheme.surface, 0.58) ??
              colorScheme.surfaceContainerHighest
        : Color.lerp(
                colorScheme.surfaceContainerHighest,
                colorScheme.outlineVariant,
                0.34,
              ) ??
              colorScheme.surfaceContainerHighest;
    final pastEndedColor = themeColorMode == themeColorModeColorful
        ? Color.lerp(activeBaseColor, colorScheme.surface, 0.74) ??
              colorScheme.surfaceContainerHighest
        : Color.lerp(
                colorScheme.surface,
                colorScheme.surfaceContainerHighest,
                0.72,
              ) ??
              colorScheme.surfaceContainerHighest;
    final baseColor = switch (layout.displayState) {
      CourseDisplayState.active => activeBaseColor,
      CourseDisplayState.futureInactive => futureInactiveColor,
      CourseDisplayState.pastEnded => pastEndedColor,
    };
    final color = baseColor.withValues(
      alpha: _isInactiveForCurrentWeek
          ? (_isPastEnded ? 0.92 : 0.96)
          : layout.isFullConflict
          ? 0.94
          : layout.priorityDepth == 0
          ? 0.92
          : math.max(0.48, 0.82 - (layout.priorityDepth * 0.10)),
    );

    final effectiveOutlineWidth = compact
        ? math.max(minLiveCourseOutlineWidth, outlineWidth - 0.5)
        : outlineWidth;
    final effectivePrimaryOutlineWidth =
        liveCourseOutlineMode == liveCourseOutlineModeAllDisplayed &&
            _isPrimaryLiveTarget
        ? effectiveOutlineWidth + (compact ? 1.2 : 1.6)
        : effectiveOutlineWidth;
    final selected = WorkspaceSelectionScope.isSelected(
      context,
      'course:${layout.course?.id}',
    );
    final renderedBackground = Color.alphaBlend(color, colorScheme.surface);
    final outline = resolveTimetableOutlineColors(
      selected ? colorScheme.primary : outlineColor,
      cardBackground: renderedBackground,
      surroundingSurface: colorScheme.surface,
    );
    final side = selected
        ? BorderSide(color: outline.outer, width: 2)
        : _isLiveHighlighted
        ? BorderSide(
            color: outline.outer,
            width: _isPrimaryLiveTarget
                ? effectivePrimaryOutlineWidth
                : effectiveOutlineWidth,
          )
        : BorderSide.none;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(
        WorkbenchChromeMetrics.of(context).desktop ? 5 : 8,
      ),
      side: side,
    );
    final itemId = layout.entry?.id ?? layout.course?.id ?? _title;

    Widget withOutlineGuard(Widget child) {
      final guard = outline.inner;
      if (side == BorderSide.none || guard == null) return child;
      return Stack(
        fit: StackFit.expand,
        children: [
          child,
          Positioned.fill(
            child: IgnorePointer(
              child: Padding(
                padding: EdgeInsets.all(side.width),
                child: DecoratedBox(
                  key: ValueKey('timetable-course-outline-guard-$itemId'),
                  decoration: ShapeDecoration(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(desktop ? 3 : 5),
                      side: BorderSide(color: guard, width: 1),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return PositionedDirectional(
      top: geometry.visualTop,
      start: metrics.courseGap,
      width: width,
      height: geometry.visualHeight,
      child: ExcludeSemantics(
        child: Card.filled(
          key: ValueKey('timetable-course-visual-$itemId'),
          margin: EdgeInsets.zero,
          // Precompose once so a translucent overlap never mixes a lower
          // card's glyphs into the fill used for contrast selection.
          color: renderedBackground,
          clipBehavior: Clip.antiAlias,
          elevation: 0,
          shape: shape,
          child: withOutlineGuard(
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: metrics.cardPadding,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final textColor = themeColorMode == themeColorModeColorful
                      ? colorfulTextColor ??
                            resolveAutomaticTimetableTextColor(
                              renderedBackground,
                              preferred: colorScheme.onSecondaryContainer,
                            )
                      : (_isInactiveForCurrentWeek
                                ? colorScheme.onSurfaceVariant
                                : colorScheme.onSecondaryContainer)
                            .withValues(
                              alpha: _isInactiveForCurrentWeek
                                  ? 0.9
                                  : layout.priorityDepth == 0
                                  ? 0.96
                                  : 0.92,
                            );
                  final desktopCourse =
                      desktop &&
                      layout.entry?.kind != TimetableEntryKind.generalEvent;
                  // Colorful automatic text is resolved against this card's
                  // final fill; explicit user colors remain unchanged.
                  // Theme-derived monochrome cards can use a stronger hierarchy.
                  final foregrounds =
                      desktopCourse && themeColorMode != themeColorModeColorful
                      ? _desktopCourseForegrounds(
                          _isInactiveForCurrentWeek
                              ? colorScheme.onSurfaceVariant
                              : colorScheme.onSurface,
                          Color.alphaBlend(color, colorScheme.surface),
                        )
                      : (title: textColor, metadata: textColor);
                  final titleStyle =
                      (compact ? textTheme.titleSmall : textTheme.titleMedium)
                          ?.copyWith(
                            fontWeight: desktopCourse
                                ? FontWeight.w600
                                : FontWeight.w700,
                            height: desktopCourse ? 1.2 : 1.1,
                            color: foregrounds.title,
                          );
                  final bodyStyle = desktopCourse
                      ? textTheme.bodySmall?.copyWith(
                          fontSize: compact ? 12 : 13,
                          height: 1.3,
                          color: foregrounds.metadata,
                          fontWeight: FontWeight.w400,
                        )
                      : (compact ? textTheme.bodySmall : textTheme.bodyMedium)
                            ?.copyWith(height: 1.1, color: textColor);
                  final teacherStyle = desktopCourse
                      ? bodyStyle
                      : (compact ? textTheme.labelSmall : textTheme.labelMedium)
                            ?.copyWith(
                              height: 1.1,
                              color: textColor,
                              fontWeight: FontWeight.w600,
                            );
                  final showConflict =
                      layout.isFullConflict &&
                      cardHeight >= 24 &&
                      (desktop ? width >= 32 : constraints.maxWidth >= 18);
                  final conflictBadge = showConflict
                      ? Container(
                          key: ValueKey('timetable-course-conflict-$itemId'),
                          padding: EdgeInsets.all(compact ? 2 : 3),
                          decoration: ShapeDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.18),
                            shape: skedShapeSchemeOf(context)
                                .selectionIndicator,
                          ),
                          child: Icon(
                            Icons.layers_outlined,
                            size: compact ? 14 : 16,
                            color: textColor,
                          ),
                        )
                      : null;
                  return Stack(
                    children: [
                      if (desktopCourse)
                        Positioned.fill(
                          child: _DesktopCourseTypography(
                            title: _title,
                            location: _location,
                            teacher: _teacher,
                            titleStyle: titleStyle,
                            metadataStyle: bodyStyle,
                            reserveConflict:
                                layout.isFullConflict &&
                                cardHeight >= 24 &&
                                width >= 32,
                          ),
                        )
                      else if (!desktop)
                        Positioned.fill(
                          child: _TouchCourseTypography(
                            title: _title,
                            location: _location,
                            teacher: _teacher,
                            titleStyle: titleStyle,
                            locationStyle: bodyStyle,
                            teacherStyle: teacherStyle,
                            conflictBadge: conflictBadge,
                            badgeExtent: compact ? 18 : 22,
                          ),
                        )
                      else
                        Positioned.fill(
                          child: ClipRect(
                            child: Padding(
                              padding: EdgeInsetsDirectional.only(
                                end: layout.isFullConflict && cardHeight >= 24
                                    ? 22
                                    : 0,
                              ),
                              child: OverflowBox(
                                alignment: AlignmentDirectional.topStart,
                                minWidth: constraints.maxWidth,
                                maxWidth: constraints.maxWidth,
                                minHeight: 0,
                                maxHeight: double.infinity,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (_title.isNotEmpty)
                                      Text(
                                        _title,
                                        softWrap: true,
                                        overflow:
                                            WorkbenchChromeMetrics.of(context)
                                                .desktop
                                            ? TextOverflow.ellipsis
                                            : TextOverflow.visible,
                                        maxLines:
                                            WorkbenchChromeMetrics.of(context)
                                                .desktop
                                            ? (constraints.maxHeight >
                                                      MediaQuery.textScalerOf(
                                                        context,
                                                      ).scale(44)
                                                  ? 2
                                                  : 1)
                                            : null,
                                        style: titleStyle,
                                      ),
                                    if (_location.isNotEmpty)
                                      Text(
                                        _location,
                                        softWrap: true,
                                        overflow: TextOverflow.visible,
                                        style: bodyStyle,
                                      ),
                                    if (_teacher.isNotEmpty)
                                      Text(
                                        _teacher,
                                        softWrap: true,
                                        overflow: TextOverflow.visible,
                                        style: teacherStyle,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (desktop && conflictBadge != null)
                        PositionedDirectional(
                          end: 0,
                          bottom: 0,
                          child: conflictBadge,
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fit complete lines to the time-sized card without scaling or clipping text.
/// The title uses the available height first; optional fields use what remains.
class _TouchCourseTypography extends StatefulWidget {
  const _TouchCourseTypography({
    required this.title,
    required this.location,
    required this.teacher,
    required this.titleStyle,
    required this.locationStyle,
    required this.teacherStyle,
    required this.conflictBadge,
    required this.badgeExtent,
  });

  final String title;
  final String location;
  final String teacher;
  final TextStyle? titleStyle;
  final TextStyle? locationStyle;
  final TextStyle? teacherStyle;
  final Widget? conflictBadge;
  final double badgeExtent;

  @override
  State<_TouchCourseTypography> createState() => _TouchCourseTypographyState();
}

typedef _TouchCourseField = ({String value, TextStyle style});
typedef _TouchCourseLayoutInputs = ({
  (String, String, String) text,
  (TextStyle, TextStyle, TextStyle) styles,
  double width,
  double height,
  TextScaler scaler,
  TextDirection direction,
  Locale? locale,
  TextHeightBehavior? textHeightBehavior,
  bool boldText,
  bool hasBadge,
  double badgeExtent,
});
typedef _TouchCourseFieldLayout = ({
  int field,
  int? lines,
  double height,
  double emptyTruncatedLineHeight,
});
typedef _TouchCourseLayout = ({
  bool showBadge,
  List<_TouchCourseFieldLayout> fields,
});

class _TouchCourseTypographyState extends State<_TouchCourseTypography> {
  _TouchCourseLayoutInputs? _previousInputs;
  _TouchCourseLayout? _previousLayout;

  @override
  void initState() {
    super.initState();
    PaintingBinding.instance.systemFonts.addListener(_handleFontsChanged);
  }

  @override
  void dispose() {
    PaintingBinding.instance.systemFonts.removeListener(_handleFontsChanged);
    super.dispose();
  }

  void _handleFontsChanged() {
    setState(() {
      _previousInputs = null;
      _previousLayout = null;
    });
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth <= 0 || constraints.maxHeight <= 0) {
        return const SizedBox.shrink();
      }
      final defaults = DefaultTextStyle.of(context);
      final boldText = MediaQuery.boldTextOf(context);
      TextStyle resolveStyle(TextStyle? style) {
        final resolved = defaults.style.merge(style);
        return boldText
            ? resolved.merge(const TextStyle(fontWeight: FontWeight.bold))
            : resolved;
      }

      final titleStyle = resolveStyle(widget.titleStyle);
      final locationStyle = resolveStyle(widget.locationStyle);
      final teacherStyle = resolveStyle(widget.teacherStyle);
      final fields = <_TouchCourseField>[
        if (widget.title.isNotEmpty) (value: widget.title, style: titleStyle),
        if (widget.location.isNotEmpty)
          (value: widget.location, style: locationStyle),
        if (widget.teacher.isNotEmpty)
          (value: widget.teacher, style: teacherStyle),
      ];
      final scaler = MediaQuery.textScalerOf(context);
      final direction = Directionality.of(context);
      final locale = Localizations.maybeLocaleOf(context);
      final inputs = (
        text: (widget.title, widget.location, widget.teacher),
        styles: (titleStyle, locationStyle, teacherStyle),
        width: constraints.maxWidth,
        height: constraints.maxHeight,
        scaler: scaler,
        direction: direction,
        locale: locale,
        textHeightBehavior: defaults.textHeightBehavior,
        boldText: boldText,
        hasBadge: widget.conflictBadge != null,
        badgeExtent: widget.badgeExtent,
      );
      if (inputs != _previousInputs) {
        final layout = _measureLayout(inputs, fields);
        _previousInputs = inputs;
        _previousLayout = layout;
      }
      final layout = _previousLayout!;

      Widget omissionMark(int field, double height) => SizedBox(
        width: constraints.maxWidth,
        height: height,
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Icon(
            Icons.more_horiz,
            key: const ValueKey('timetable-course-text-omitted'),
            size: math.min(18, math.min(constraints.maxWidth, height)),
            color: fields[field].style.color,
          ),
        ),
      );

      final children = <Widget>[];
      for (final row in layout.fields) {
        final field = row.field;
        if (row.lines == null) {
          children.add(omissionMark(field, row.height));
          continue;
        }
        final height = row.height;
        final text = Text(
          fields[field].value,
          style: fields[field].style,
          textScaler: scaler,
          locale: locale,
          textHeightBehavior: defaults.textHeightBehavior,
          softWrap: true,
          maxLines: row.lines,
          overflow: TextOverflow.ellipsis,
        );
        children.add(
          SizedBox(
            width: constraints.maxWidth,
            height: height,
            // Some native fallback fonts leave the ellipsis-only final line
            // empty at narrow widths. Mark that measured empty line explicitly
            // without covering any text or altering its line height.
            child: row.emptyTruncatedLineHeight > 0
                ? Stack(
                    fit: StackFit.expand,
                    clipBehavior: Clip.none,
                    children: [
                      text,
                      PositionedDirectional(
                        start: 0,
                        end: 0,
                        top: height - row.emptyTruncatedLineHeight,
                        child: omissionMark(
                          field,
                          row.emptyTruncatedLineHeight,
                        ),
                      ),
                    ],
                  )
                : text,
          ),
        );
      }
      return Stack(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
          if (layout.showBadge)
            PositionedDirectional(
              end: 0,
              bottom: 0,
              child: widget.conflictBadge!,
            ),
        ],
      );
    },
  );

  // Keep just this mounted card's last numeric layout. Rebuild its widgets
  // with current text, styles and badge so interaction/semantics never freeze.
  _TouchCourseLayout _measureLayout(
    _TouchCourseLayoutInputs inputs,
    List<_TouchCourseField> fields,
  ) {
    ({double height, double width, int lines, double emptyTruncatedLineHeight})
    measure(int field, int? lines) {
      final painter = TextPainter(
        text: TextSpan(text: fields[field].value, style: fields[field].style),
        textDirection: inputs.direction,
        textScaler: inputs.scaler,
        locale: inputs.locale,
        textHeightBehavior: inputs.textHeightBehavior,
        maxLines: lines,
        ellipsis: lines == null ? null : '…',
      )..layout(maxWidth: inputs.width);
      final metrics = painter.computeLineMetrics();
      final result = (
        height: painter.height,
        width: metrics.fold(0.0, (width, line) => math.max(width, line.width)),
        lines: metrics.length,
        emptyTruncatedLineHeight:
            painter.didExceedMaxLines &&
                metrics.isNotEmpty &&
                metrics.last.width <= .01
            ? metrics.last.height
            : 0.0,
      );
      painter.dispose();
      return result;
    }

    // A narrow card cannot spare an entire side column for the badge. Keep
    // it below the text, and give a complete primary line precedence when
    // even that line and the badge cannot coexist in a very short card.
    final firstLineHeight = fields.isEmpty ? 0.0 : measure(0, 1).height;
    final showBadge =
        inputs.hasBadge &&
        inputs.width >= inputs.badgeExtent &&
        inputs.height >= firstLineHeight + inputs.badgeExtent + 2;
    var remaining = inputs.height - (showBadge ? inputs.badgeExtent + 2 : 0);
    final rows = <_TouchCourseFieldLayout>[];
    for (var field = 0; field < fields.length; field++) {
      final firstLine = measure(field, 1);
      if (firstLine.height > remaining) break;
      if (firstLine.width > inputs.width + .01) {
        // At the largest accessibility sizes even a single glyph (including
        // the font's ellipsis) may exceed a fitted day column. Use a bounded
        // omission mark instead of painting part of a character. The course
        // hit target still exposes its full title and details.
        if (field == 0) {
          rows.add((
            field: field,
            lines: null,
            height: firstLine.height,
            emptyTruncatedLineHeight: 0,
          ));
        }
        break;
      }
      final full = measure(field, null);
      var lines = math.max(1, full.lines);
      if (full.height > remaining || full.width > inputs.width + .01) {
        var lower = 1;
        var upper = lines;
        while (lower < upper) {
          final candidate = (lower + upper + 1) ~/ 2;
          final measured = measure(field, candidate);
          if (measured.height <= remaining &&
              measured.width <= inputs.width + .01) {
            lower = candidate;
          } else {
            upper = candidate - 1;
          }
        }
        lines = lower;
      }
      final measured = measure(field, lines);
      rows.add((
        field: field,
        lines: lines,
        height: measured.height,
        emptyTruncatedLineHeight: measured.emptyTruncatedLineHeight,
      ));
      remaining -= measured.height;
    }
    return (showBadge: showBadge, fields: List.unmodifiable(rows));
  }
}

/// Soften secondary text only while it remains readable on the actual fill.
/// User-specified colorful course text bypasses this theme-only hierarchy.
({Color title, Color metadata}) _desktopCourseForegrounds(
  Color preferred,
  Color background,
) {
  double contrast(Color foreground) =>
      colorContrastRatio(Color.alphaBlend(foreground, background), background);

  final title = contrast(preferred) >= 4.5
      ? preferred
      : contrast(Colors.black) >= contrast(Colors.white)
      ? Colors.black
      : Colors.white;
  var amount = .24;
  var metadata = Color.lerp(title, background, amount)!;
  // Do not turn secondary text into an inaccessible low-opacity grey.
  for (var i = 0; i < 8 && contrast(metadata) < 4.5; i++) {
    amount /= 2;
    metadata = Color.lerp(title, background, amount)!;
  }
  return (title: title, metadata: contrast(metadata) >= 4.5 ? metadata : title);
}

/// A top-aligned hierarchy; spacing yields to readable text in short cards.
/// Kept separate so touch typography and timetable geometry stay unchanged.
class _DesktopCourseTypography extends StatefulWidget {
  const _DesktopCourseTypography({
    required this.title,
    required this.location,
    required this.teacher,
    required this.titleStyle,
    required this.metadataStyle,
    required this.reserveConflict,
  });
  final String title;
  final String location;
  final String teacher;
  final TextStyle? titleStyle;
  final TextStyle? metadataStyle;
  final bool reserveConflict;

  @override
  State<_DesktopCourseTypography> createState() =>
      _DesktopCourseTypographyState();
}

typedef _DesktopCourseField = ({String value, TextStyle style, double gap});
typedef _DesktopCourseLayoutInputs = ({
  (String, String, String) text,
  (TextStyle, TextStyle) styles,
  TextStyle defaultStyle,
  double width,
  double height,
  TextScaler scaler,
  TextDirection direction,
  Locale? locale,
  TextHeightBehavior? textHeightBehavior,
  bool boldText,
  double badgeInset,
});
typedef _DesktopCourseFieldLayout = ({
  int field,
  double gap,
  double height,
  int lines,
});
typedef _DesktopCourseLayout = ({
  double inset,
  List<_DesktopCourseFieldLayout> fields,
});

class _DesktopCourseTypographyState extends State<_DesktopCourseTypography> {
  static final _mandatoryLineBreak = RegExp(
    r'[\r\n\u000b\u000c\u0085\u2028\u2029]',
  );

  _DesktopCourseLayoutInputs? _previousInputs;
  _DesktopCourseLayout? _previousLayout;

  @override
  void initState() {
    super.initState();
    PaintingBinding.instance.systemFonts.addListener(_handleFontsChanged);
  }

  @override
  void dispose() {
    PaintingBinding.instance.systemFonts.removeListener(_handleFontsChanged);
    super.dispose();
  }

  void _handleFontsChanged() {
    setState(() {
      _previousInputs = null;
      _previousLayout = null;
    });
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final defaults = DefaultTextStyle.of(context);
      final boldText = MediaQuery.boldTextOf(context);
      final titleStyle = defaults.style.merge(widget.titleStyle);
      final metadataStyle = defaults.style.merge(widget.metadataStyle);
      final fields = <_DesktopCourseField>[
        if (widget.title.isNotEmpty)
          (value: widget.title, style: titleStyle, gap: 0),
        if (widget.location.isNotEmpty)
          (
            value: widget.location,
            style: metadataStyle,
            gap: widget.title.isEmpty ? 0 : 12,
          ),
        if (widget.teacher.isNotEmpty)
          (
            value: widget.teacher,
            style: metadataStyle,
            gap: widget.location.isNotEmpty
                ? 2
                : widget.title.isNotEmpty
                ? 12
                : 0,
          ),
      ];
      if (fields.isEmpty) return const SizedBox.shrink();
      final scaler = MediaQuery.textScalerOf(context);
      final direction = Directionality.of(context);
      final locale = Localizations.maybeLocaleOf(context);
      final textHeightBehavior =
          defaults.textHeightBehavior ??
          DefaultTextHeightBehavior.maybeOf(context);
      final badgeInset = widget.reserveConflict ? 22.0 : 0.0;
      final inputs = (
        text: (widget.title, widget.location, widget.teacher),
        styles: (titleStyle, metadataStyle),
        defaultStyle: defaults.style,
        width: constraints.maxWidth,
        height: constraints.maxHeight,
        scaler: scaler,
        direction: direction,
        locale: locale,
        textHeightBehavior: textHeightBehavior,
        boldText: boldText,
        badgeInset: badgeInset,
      );
      if (inputs != _previousInputs) {
        final layout = _measureLayout(inputs, fields);
        _previousInputs = inputs;
        _previousLayout = layout;
      }
      final layout = _previousLayout!;
      final children = <Widget>[];
      for (final row in layout.fields) {
        if (row.gap > 0) children.add(SizedBox(height: row.gap));
        children.add(
          SizedBox(
            height: row.height,
            child: ClipRect(
              child: Text(
                fields[row.field].value,
                style: fields[row.field].style,
                textScaler: scaler,
                locale: locale,
                softWrap: true,
                maxLines: row.lines,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        );
      }
      return Padding(
        padding: EdgeInsetsDirectional.fromSTEB(
          layout.inset,
          layout.inset,
          layout.inset + badgeInset,
          layout.inset,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      );
    },
  );

  // Keep only the last numeric plan for this mounted card. Every build still
  // creates Text widgets from its current fields and inherited presentation.
  _DesktopCourseLayout _measureLayout(
    _DesktopCourseLayoutInputs inputs,
    List<_DesktopCourseField> fields,
  ) {
    ({double height, int lines, bool didExceedMaxLines}) measure(
      int i,
      double maxWidth,
      int? lines,
    ) {
      final painter = TextPainter(
        text: TextSpan(text: fields[i].value, style: fields[i].style),
        textDirection: inputs.direction,
        textScaler: inputs.scaler,
        locale: inputs.locale,
        maxLines: lines,
        ellipsis: lines == null ? null : '…',
      )..layout(maxWidth: maxWidth);
      final result = (
        height: painter.height,
        lines: painter.computeLineMetrics().length,
        didExceedMaxLines: painter.didExceedMaxLines,
      );
      painter.dispose();
      return result;
    }

    // Preserve the reference spacing if at least one line per field fits.
    // Long content determines its own line count, not the spacing mode.
    const extraInset = 6.0;
    final width = math.max(0.0, inputs.width - inputs.badgeInset);
    final preferredWidth = math.max(0.0, width - extraInset * 2);
    final preferredProbes = [
      for (var i = 0; i < fields.length; i++) measure(i, preferredWidth, 1),
    ];
    var preferredHeight = extraInset * 2;
    for (var i = 0; i < fields.length; i++) {
      preferredHeight += preferredProbes[i].height + fields[i].gap;
    }
    final spacious = width > extraInset * 2 && preferredHeight <= inputs.height;
    final inset = spacious ? extraInset : 0.0;
    final textWidth = math.max(0.0, width - inset * 2);
    final minimumProbes = spacious
        ? preferredProbes
        : [for (var i = 0; i < fields.length; i++) measure(i, textWidth, 1)];
    var remaining = math.max(0.0, inputs.height - inset * 2);
    final rows = <_DesktopCourseFieldLayout>[];
    for (var i = 0; i < fields.length && remaining > 0; i++) {
      final gap = spacious ? fields[i].gap : 0.0;
      final probe = minimumProbes[i];
      final oneLine = probe.height;
      if (i > 0 && gap + oneLine > remaining) break;
      // A long title/location must not consume the teacher's last line.
      var reserved = 0.0;
      for (var j = i + 1; j < fields.length; j++) {
        reserved += minimumProbes[j].height + (spacious ? fields[j].gap : 0);
      }
      final budget = math.min(
        remaining - gap,
        math.max(oneLine, remaining - gap - reserved),
      );
      // A trailing hard break can add an empty line without reporting overflow
      // in a one-line probe. Keep unrestricted measurement for those strings.
      final full =
          probe.lines == 1 &&
              !probe.didExceedMaxLines &&
              textWidth > 0 &&
              textWidth.isFinite &&
              !_mandatoryLineBreak.hasMatch(fields[i].value)
          ? probe
          : measure(i, textWidth, null);
      var lines = math.max(1, full.lines);
      var height = full.height;
      if (height > budget) {
        // Find the largest whole-line layout that fits the real pixel budget.
        // Measuring candidates also handles explicit newlines and font fallback.
        var lower = 1;
        var upper = lines;
        var fittedHeight = oneLine;
        while (lower < upper) {
          final candidate = (lower + upper + 1) ~/ 2;
          final candidateHeight = measure(i, textWidth, candidate).height;
          if (candidateHeight <= budget) {
            lower = candidate;
            fittedHeight = candidateHeight;
          } else {
            upper = candidate - 1;
          }
        }
        lines = lower;
        height = math.min(fittedHeight, budget);
      }
      rows.add((field: i, gap: gap, height: height, lines: lines));
      remaining -= height + gap;
    }
    return (inset: inset, fields: List.unmodifiable(rows));
  }
}

class _CourseHitTarget extends StatelessWidget {
  const _CourseHitTarget({
    required this.geometry,
    required this.metrics,
    required this.semanticLabel,
    required this.onTap,
    required this.onLongPress,
    this.useVisualBounds = false,
    this.includeSemantics = true,
  });

  final _CourseGeometry geometry;
  final _TimetableMetrics metrics;
  final String semanticLabel;
  final ValueChanged<BuildContext> onTap;
  final ValueChanged<BuildContext> onLongPress;
  final bool useVisualBounds;
  final bool includeSemantics;

  @override
  Widget build(BuildContext context) {
    final layout = geometry.layout;
    final itemId = layout.entry?.id ?? layout.course?.id ?? 'unknown';
    final width = math.max(
      0.0,
      metrics.dayColumnWidth - (metrics.courseGap * 2),
    );
    final visual = ExcludeSemantics(
      child: Material(
        type: MaterialType.transparency,
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('timetable-course-hit-$itemId'),
          onTap: () => onTap(context),
          onLongPress: () => onLongPress(context),
          customBorder: skedShapeSchemeOf(context).compact,
          overlayColor: WidgetStatePropertyAll(
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
          ),
        ),
      ),
    );
    return PositionedDirectional(
      // Dense courses keep physical hit regions on their exact visual
      // intervals. Their separate semantic targets still provide 48dp
      // accessibility actions without overlapping pointer targets.
      top: useVisualBounds ? geometry.visualTop : geometry.hitTop,
      start: metrics.courseGap,
      width: width,
      height: useVisualBounds ? geometry.visualHeight : geometry.hitHeight,
      child: includeSemantics
          ? _CourseSemantics(
              selected: WorkspaceSelectionScope.isSelected(
                context,
                'course:${layout.course?.id}',
              ),
              label: semanticLabel,
              onTap: () => onTap(context),
              child: visual,
            )
          : ExcludeSemantics(child: visual),
    );
  }
}

/// Dense adjacent courses share the available physical pixels. Keep their
/// pointer routing disjoint, but expose a full-size semantic action target so
/// keyboard and assistive-technology users retain a reliable 48dp action.
class _CourseSemanticTarget extends StatelessWidget {
  const _CourseSemanticTarget({
    required this.geometry,
    required this.totalHeight,
    required this.semanticLabel,
    required this.onTap,
  });

  final _CourseGeometry geometry;
  final double totalHeight;
  final String semanticLabel;
  final ValueChanged<BuildContext> onTap;

  @override
  Widget build(BuildContext context) {
    final height = math.min(_minimumCourseHitExtent, totalHeight).toDouble();
    final top = (geometry.visualTop + (geometry.visualHeight / 2) - height / 2)
        .clamp(0.0, math.max(0.0, totalHeight - height))
        .toDouble();
    return PositionedDirectional(
      top: top,
      start: 0,
      end: 0,
      height: height,
      child: _CourseSemantics(
        label: semanticLabel,
        onTap: () => onTap(context),
        child: IgnorePointer(child: const SizedBox.expand()),
      ),
    );
  }
}

class _CourseSemantics extends StatefulWidget {
  const _CourseSemantics({
    required this.label,
    this.selected,
    required this.onTap,
    required this.child,
  });

  final String label;
  final bool? selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  State<_CourseSemantics> createState() => _CourseSemanticsState();
}

class _CourseSemanticsState extends State<_CourseSemantics> {
  SemanticsProperties? _properties;

  // Keep the action stable while resolving the current course and anchor.
  void _handleTap() => widget.onTap();

  @override
  Widget build(BuildContext context) {
    final previous = _properties;
    if (previous == null ||
        previous.label != widget.label ||
        previous.selected != widget.selected) {
      _properties = SemanticsProperties(
        button: true,
        enabled: true,
        selected: widget.selected,
        label: widget.label,
        onTap: _handleTap,
      );
    }
    // Reusing the properties also preserves the render object's unchanged path.
    return Semantics.fromProperties(
      container: true,
      properties: _properties!,
      child: widget.child,
    );
  }
}

String _semanticLabelForGeometry(
  _CourseGeometry geometry, {
  required int weekday,
  required int selectedWeek,
  required String localeCode,
}) {
  final layout = geometry.layout;
  final l = lookupAppLocalizations(appLocaleFromCode(localeCode));
  final source = layout.entry?.source;
  final course = layout.course ?? (source is CourseItem ? source : null);
  final isCourse =
      layout.course != null || layout.entry?.kind == TimetableEntryKind.course;
  final inactive =
      isCourse &&
      (layout.entry?.isInactive ??
          layout.displayState != CourseDisplayState.active);
  final title = layout.entry?.title ?? layout.course?.name ?? '';
  final location = (layout.entry?.location ?? layout.course?.location ?? '')
      .trim();
  final teacher = (layout.entry?.teacher ?? layout.course?.teacher ?? '')
      .trim();
  return <String>[
    title,
    formatDayOfWeekLabel(weekday, localeCode: localeCode),
    l.weekLabel(selectedWeek),
    '${formatMinutes(geometry.startMinutes)}–${formatMinutes(geometry.endMinutes)}',
    if (location.isNotEmpty) '${l.location}: $location',
    if (teacher.isNotEmpty) '${l.teacherName}: $teacher',
    if (inactive) ...[
      l.courseInactiveThisWeek,
      if (course != null)
        formatSemesterWeeksLabel(course.semesterWeeks, localeCode: localeCode),
    ],
    if (isCourse && layout.conflictCourses.length > 1)
      '${l.conflictCourses}: ${layout.conflictCourses.length}',
  ].join(', ');
}
