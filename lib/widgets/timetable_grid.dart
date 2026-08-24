import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../models/timetable_models.dart';
import '../theme/sked_expressive_theme.dart';
import 'timetable_entry.dart';

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
  });

  final CourseItem course;
  final List<CourseItem> courses;
  final bool isFullConflict;
  final String? conflictKey;

  TimetableCourseTapInfo copyWith({
    CourseItem? course,
    List<CourseItem>? courses,
    bool? isFullConflict,
    String? conflictKey,
  }) {
    return TimetableCourseTapInfo(
      course: course ?? this.course,
      courses: courses ?? this.courses,
      isFullConflict: isFullConflict ?? this.isFullConflict,
      conflictKey: conflictKey ?? this.conflictKey,
    );
  }
}

class TimetableEmptySlotTapInfo {
  const TimetableEmptySlotTapInfo({
    required this.weekday,
    required this.startMinutes,
    required this.endMinutes,
    required this.periods,
  });

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

  @override
  void initState() {
    super.initState();
    _headerHorizontalController.addListener(_syncHeaderToBody);
    _bodyHorizontalController.addListener(_syncBodyToHeader);
  }

  @override
  void didUpdateWidget(covariant TimetableGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleHorizontalSync();
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
    final slots = widget.periodTimes.isEmpty
        ? buildPeriodTimesForCount(1)
        : widget.periodTimes;
    final textScaler = MediaQuery.textScalerOf(context);
    final textScale = textScaler.scale(1);
    final layout = _TimetableVerticalLayout(
      slots: slots,
      preserveGaps: widget.preserveGaps || widget.entries != null,
      minuteHeight: _minuteHeight * textScale.clamp(1.0, 1.8),
    );
    final colors = Theme.of(context).colorScheme;
    final useEntries = widget.entries != null;
    assert(
      widget.entries == null || widget.onEntryTap != null,
      'onEntryTap must be provided when entries is provided',
    );
    // Resolve automatic colorful text against the complete week so switching
    // the day view cannot make the same course palette change text color.
    final dayLayoutsByWeekday = <int, List<CourseLayout>>{
      for (var weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++)
        weekday: useEntries
            ? _buildDayLayoutsFromEntries(
                entries: widget.entries!,
                weekday: weekday,
              )
            : _buildDayLayouts(
                timetable: widget.timetable,
                courses: widget.timetable.courses,
                periodTimes: slots,
                weekday: weekday,
                selectedWeek: widget.selectedWeek,
                realCurrentWeek: widget.realCurrentWeek,
                showPastEndedCourses: widget.showPastEndedCourses,
                showFutureCourses: widget.showFutureCourses,
                displayedCourseIdForConflict:
                    widget.displayedCourseIdForConflict,
                liveCourseTarget: widget.liveCourseTarget,
                liveCourseOutlineEnabled: widget.liveCourseOutlineEnabled,
                liveCourseOutlineMode: widget.liveCourseOutlineMode,
                preserveGaps: layout.preserveGaps,
              ),
    };
    final colorfulTextColor = widget.themeColorMode == themeColorModeColorful
        ? widget.colorfulCourseTextColorMode ==
                      colorfulCourseTextColorModeCustom &&
                  widget.colorfulCourseTextColorValue != null
              ? Color(widget.colorfulCourseTextColorValue!)
              : resolveSharedColorfulTextColor(
                  layouts: dayLayoutsByWeekday.values.expand((items) => items),
                  courseNameColorValues: widget.courseNameColorValues,
                  surfaceColor: colors.surface,
                  fallbackColor: colors.onSecondaryContainer,
                )
        : null;

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
        );
        final baseHeaderHeight = metrics.compact
            ? _compactHeaderHeight
            : _regularHeaderHeight;
        // The day header contains two stacked labels. Measure their actual
        // scaled line heights so large accessibility text gets room instead
        // of overflowing the fixed-size inner slot.
        final headerHeight = math.max(
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

        return SizedBox(
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
                                            width: metrics.dayColumnWidth,
                                            borderColor: widget.showGridLines
                                                ? colors.outlineVariant
                                                      .withValues(alpha: 0.25)
                                                : Colors.transparent,
                                            showGridLines: widget.showGridLines,
                                            slots: slots,
                                            layouts:
                                                dayLayoutsByWeekday[weekday]!,
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
                                            outlineColor: Color(
                                              widget
                                                  .liveCourseOutlineColorValue,
                                            ),
                                            outlineWidth:
                                                widget.liveCourseOutlineWidth,
                                            onLongPressAt:
                                                widget.onEmptySlotTap == null
                                                ? null
                                                : (localPosition) {
                                                    final matchedPeriod = layout
                                                        .slotForY(
                                                          localPosition.dy,
                                                        );
                                                    widget.onEmptySlotTap!(
                                                      TimetableEmptySlotTapInfo(
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
                                            onLayoutTap: (item) {
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
    required this.width,
    required this.borderColor,
    required this.showGridLines,
    required this.slots,
    required this.layouts,
    required this.verticalLayout,
    required this.metrics,
    required this.themeColorMode,
    required this.courseNameColorValues,
    required this.colorfulTextColor,
    required this.liveCourseOutlineMode,
    required this.outlineColor,
    required this.outlineWidth,
    required this.onLongPressAt,
    required this.onLayoutTap,
  });

  final int weekday;
  final double width;
  final Color borderColor;
  final bool showGridLines;
  final List<CoursePeriodTime> slots;
  final List<CourseLayout> layouts;
  final _TimetableVerticalLayout verticalLayout;
  final _TimetableMetrics metrics;
  final String themeColorMode;
  final Map<String, int> courseNameColorValues;
  final Color? colorfulTextColor;
  final String liveCourseOutlineMode;
  final Color outlineColor;
  final double outlineWidth;
  final ValueChanged<Offset>? onLongPressAt;
  final ValueChanged<CourseLayout> onLayoutTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final geometries = _buildCourseGeometries(
      layouts: layouts,
      verticalLayout: verticalLayout,
      visualGap: metrics.courseVerticalGap,
    );
    final hasDenseHitTargets = geometries.any(
      (geometry) => geometry.hitHeight < _minimumCourseHitExtent,
    );
    return Container(
      key: ValueKey('timetable-day-column-$weekday'),
      width: width,
      decoration: BoxDecoration(
        border: BorderDirectional(start: BorderSide(color: borderColor)),
      ),
      child: GestureDetector(
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
                onLongPressAt!(details.localPosition);
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
                  outlineColor: outlineColor,
                  outlineWidth: outlineWidth,
                ),
              for (final geometry in geometries)
                _CourseHitTarget(
                  geometry: geometry,
                  metrics: metrics,
                  onTap: () => onLayoutTap(geometry.layout),
                  onLongPress: () => onLayoutTap(geometry.layout),
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
                    onTap: () => onLayoutTap(geometry.layout),
                  ),
            ],
          ),
        ),
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
                        children: [
                          Text(
                            slot.index.toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (showTimes) ...[
                            const SizedBox(height: 2),
                            Text(
                              formatMinutes(slot.startMinutes),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: textTheme.labelSmall?.copyWith(height: 1),
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
      courseGap: dayColumnWidth < 72
          ? 2.0
          : compact
          ? 4.0
          : 6.0,
      courseVerticalGap: dayColumnWidth < 72
          ? 2.0
          : compact
          ? 4.0
          : 6.0,
      cardPadding: dayColumnWidth < 72
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
      ? theme.textTheme.labelSmall
      : theme.textTheme.bodySmall;
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
    final colorScheme = Theme.of(context).colorScheme;
    final isToday = _isSameDate(date, DateTime.now());
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 1 : 4, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            formatWeekdayShortLabel(weekday, localeCode: localeCode),
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
            style: compact
                ? Theme.of(context).textTheme.labelMedium
                : Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 2),
          Container(
            constraints: BoxConstraints(minWidth: compact ? 24 : 28),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 2 : 6,
              vertical: compact ? 2 : 3,
            ),
            decoration: isToday
                ? ShapeDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.10),
                    shape: skedShapeSchemeOf(context).compact.copyWith(
                      side: BorderSide(
                        color: colorScheme.primary.withValues(alpha: 0.65),
                      ),
                    ),
                  )
                : null,
            child: Text(
              '${date.day}',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style:
                  (compact
                          ? Theme.of(context).textTheme.labelSmall
                          : Theme.of(context).textTheme.bodySmall)
                      ?.copyWith(
                        color: isToday ? colorScheme.primary : null,
                        fontWeight: isToday ? FontWeight.w700 : null,
                      ),
            ),
          ),
        ],
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
  }) : _slotTops = _buildSlotTops(slots, preserveGaps, minuteHeight) {
    totalHeight = slots.isEmpty
        ? 0
        : preserveGaps
        ? (slots.last.endMinutes - slots.first.startMinutes) * minuteHeight
        : slots.fold<double>(
            0,
            (sum, slot) => sum + _slotHeightFor(slot, minuteHeight),
          );
  }

  final List<CoursePeriodTime> slots;
  final bool preserveGaps;
  final double minuteHeight;
  final List<double> _slotTops;
  late final double totalHeight;

  static List<double> _buildSlotTops(
    List<CoursePeriodTime> slots,
    bool preserveGaps,
    double minuteHeight,
  ) {
    if (slots.isEmpty) {
      return const [];
    }
    if (preserveGaps) {
      final startMinutes = slots.first.startMinutes;
      return [
        for (final slot in slots)
          (slot.startMinutes - startMinutes) * minuteHeight,
      ];
    }
    var currentTop = 0.0;
    final tops = <double>[];
    for (final slot in slots) {
      tops.add(currentTop);
      currentTop += _slotHeightFor(slot, minuteHeight);
    }
    return tops;
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
    final firstStart = slots.first.startMinutes;
    final lastEnd = slots.last.endMinutes;
    final clampedMinute = minute.clamp(firstStart, lastEnd).toInt();
    if (preserveGaps) {
      return (clampedMinute - firstStart) * minuteHeight;
    }
    for (var index = 0; index < slots.length; index++) {
      final slot = slots[index];
      final top = _slotTops[index];
      if (clampedMinute < slot.startMinutes) {
        return top;
      }
      if (clampedMinute <= slot.endMinutes) {
        return top + (clampedMinute - slot.startMinutes) * minuteHeight;
      }
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

enum CourseDisplayState { active, futureInactive, pastEnded }

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
    final timeRange = _resolvedLayoutTimeRange(layout, verticalLayout);
    final top = verticalLayout.rangeTop(timeRange.startMinutes);
    ranges.add((
      layout: layout,
      startMinutes: timeRange.startMinutes,
      endMinutes: timeRange.endMinutes,
      top: top,
      bottom:
          top +
          verticalLayout.rangeHeight(
            timeRange.startMinutes,
            timeRange.endMinutes,
          ),
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
    required this.outlineColor,
    required this.outlineWidth,
  });

  final _CourseGeometry geometry;
  final _TimetableMetrics metrics;
  final String themeColorMode;
  final Map<String, int> courseNameColorValues;
  final Color? colorfulTextColor;
  final String liveCourseOutlineMode;
  final Color outlineColor;
  final double outlineWidth;

  CourseLayout get layout => geometry.layout;

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
            layout.isPrimaryLiveTarget
        ? effectiveOutlineWidth + (compact ? 1.2 : 1.6)
        : effectiveOutlineWidth;
    final side = layout.isLiveHighlighted
        ? BorderSide(
            color: outlineColor,
            width: layout.isPrimaryLiveTarget
                ? effectivePrimaryOutlineWidth
                : effectiveOutlineWidth,
          )
        : BorderSide.none;
    final shape = skedShapeSchemeOf(context).compact.copyWith(side: side);
    final itemId = layout.entry?.id ?? layout.course?.id ?? _title;

    return PositionedDirectional(
      top: geometry.visualTop,
      start: metrics.courseGap,
      width: width,
      height: geometry.visualHeight,
      child: ExcludeSemantics(
        child: Card.filled(
          key: ValueKey('timetable-course-visual-$itemId'),
          margin: EdgeInsets.zero,
          color: color,
          clipBehavior: Clip.antiAlias,
          elevation: 0,
          shape: shape,
          child: Padding(
            padding: EdgeInsets.all(metrics.cardPadding),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final textColor =
                    (themeColorMode == themeColorModeColorful
                            ? (colorfulTextColor ??
                                  colorScheme.onSecondaryContainer)
                            : (_isInactiveForCurrentWeek
                                  ? colorScheme.onSurfaceVariant
                                  : colorScheme.onSecondaryContainer))
                        .withValues(
                          alpha: _isInactiveForCurrentWeek
                              ? 0.9
                              : layout.priorityDepth == 0
                              ? 0.96
                              : 0.92,
                        );
                final titleStyle =
                    (compact ? textTheme.titleSmall : textTheme.titleMedium)
                        ?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                          color: textColor,
                        );
                final bodyStyle =
                    (compact ? textTheme.bodySmall : textTheme.bodyMedium)
                        ?.copyWith(height: 1.1, color: textColor);
                final teacherStyle =
                    (compact ? textTheme.labelSmall : textTheme.labelMedium)
                        ?.copyWith(
                          height: 1.1,
                          color: textColor,
                          fontWeight: FontWeight.w600,
                        );
                return Stack(
                  children: [
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
                                    overflow: TextOverflow.visible,
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
                    if (layout.isFullConflict &&
                        cardHeight >= 24 &&
                        width >= 32)
                      PositionedDirectional(
                        end: 0,
                        bottom: 0,
                        child: Container(
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
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _CourseHitTarget extends StatelessWidget {
  const _CourseHitTarget({
    required this.geometry,
    required this.metrics,
    required this.onTap,
    required this.onLongPress,
    this.useVisualBounds = false,
    this.includeSemantics = true,
  });

  final _CourseGeometry geometry;
  final _TimetableMetrics metrics;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
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
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('timetable-course-hit-$itemId'),
          onTap: onTap,
          onLongPress: onLongPress,
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
          ? Semantics(
              container: true,
              button: true,
              enabled: true,
              label: _semanticLabelForGeometry(geometry),
              onTap: onTap,
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
    required this.onTap,
  });

  final _CourseGeometry geometry;
  final double totalHeight;
  final VoidCallback onTap;

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
      child: Semantics(
        container: true,
        button: true,
        enabled: true,
        label: _semanticLabelForGeometry(geometry),
        onTap: onTap,
        child: IgnorePointer(child: const SizedBox.expand()),
      ),
    );
  }
}

String _semanticLabelForGeometry(_CourseGeometry geometry) {
  final layout = geometry.layout;
  final title = layout.entry?.title ?? layout.course?.name ?? '';
  final location = layout.entry?.location ?? layout.course?.location ?? '';
  final teacher = layout.entry?.teacher ?? layout.course?.teacher ?? '';
  return <String>[
    title,
    if (location.isNotEmpty) location,
    if (teacher.isNotEmpty) teacher,
    '${formatMinutes(geometry.startMinutes)}–${formatMinutes(geometry.endMinutes)}',
  ].join(', ');
}

({int startMinutes, int endMinutes}) _resolvedLayoutTimeRange(
  CourseLayout layout,
  _TimetableVerticalLayout verticalLayout,
) {
  final entry = layout.entry;
  if (entry != null) {
    return (startMinutes: entry.startMinutes, endMinutes: entry.endMinutes);
  }
  final course = layout.course!;
  if (course.endMinutes > course.startMinutes) {
    return (startMinutes: course.startMinutes, endMinutes: course.endMinutes);
  }

  final periodIndexes = course.periods.toSet();
  final matchedSlots = verticalLayout.slots
      .where((slot) => periodIndexes.contains(slot.index))
      .toList();
  if (matchedSlots.isNotEmpty) {
    return (
      startMinutes: matchedSlots
          .map((slot) => slot.startMinutes)
          .reduce(math.min),
      endMinutes: matchedSlots.map((slot) => slot.endMinutes).reduce(math.max),
    );
  }
  return (startMinutes: course.startMinutes, endMinutes: course.endMinutes);
}

class CourseLayout {
  const CourseLayout({
    this.course,
    this.entry,
    required this.priorityDepth,
    required this.isFullConflict,
    required this.conflictCourses,
    required this.displayState,
    required this.isLiveHighlighted,
    required this.isPrimaryLiveTarget,
    required this.liveTargetIsCurrentCourse,
    this.conflictKey,
  });

  final CourseItem? course;
  final TimetableEntry? entry;
  final int priorityDepth;
  final bool isFullConflict;
  final List<Object> conflictCourses;
  final CourseDisplayState displayState;
  final bool isLiveHighlighted;
  final bool isPrimaryLiveTarget;
  final bool liveTargetIsCurrentCourse;
  final String? conflictKey;
}

class OverlapGroup {
  const OverlapGroup(this.courses);

  final List<CourseItem> courses;
}

Color resolveSharedColorfulTextColor({
  required Iterable<CourseLayout> layouts,
  required Map<String, int> courseNameColorValues,
  required Color surfaceColor,
  required Color fallbackColor,
}) {
  var minLuminance = 1.0;
  var foundColor = false;

  for (final layout in layouts) {
    final normalizedColorName =
        layout.entry?.colorName ??
        (layout.course != null
            ? normalizeCourseColorName(layout.course!.name)
            : '');
    if (normalizedColorName.isEmpty) {
      continue;
    }
    final courseColorValue = courseNameColorValues[normalizedColorName];
    if (courseColorValue == null) {
      continue;
    }
    foundColor = true;
    final activeBaseColor = Color(courseColorValue);
    final inactiveColor =
        Color.lerp(activeBaseColor, surfaceColor, 0.74) ?? surfaceColor;
    final baseColor = switch (layout.displayState) {
      CourseDisplayState.active => activeBaseColor,
      CourseDisplayState.futureInactive =>
        Color.lerp(activeBaseColor, surfaceColor, 0.58) ?? surfaceColor,
      CourseDisplayState.pastEnded => inactiveColor,
    };
    final blendedColor = Color.alphaBlend(
      baseColor.withValues(
        alpha: layout.displayState != CourseDisplayState.active
            ? (layout.displayState == CourseDisplayState.pastEnded
                  ? 0.92
                  : 0.96)
            : layout.isFullConflict
            ? 0.94
            : layout.priorityDepth == 0
            ? 0.92
            : math.max(0.48, 0.82 - (layout.priorityDepth * 0.10)),
      ),
      surfaceColor,
    );
    minLuminance = math.min(minLuminance, blendedColor.computeLuminance());
  }

  if (!foundColor) {
    return fallbackColor;
  }

  final colorfulTextProgress = minLuminance < 0.5
      ? minLuminance * 0.4
      : 0.8 + ((minLuminance - 0.5) * 0.4);
  return Color.lerp(Colors.white, Colors.black, colorfulTextProgress) ??
      fallbackColor;
}

List<CourseLayout> _buildDayLayouts({
  required TimetableData timetable,
  required List<CourseItem> courses,
  required List<CoursePeriodTime> periodTimes,
  required int weekday,
  required int selectedWeek,
  required int realCurrentWeek,
  required bool showPastEndedCourses,
  required bool showFutureCourses,
  required String? Function(String conflictKey)? displayedCourseIdForConflict,
  required TimetableLiveCourseTarget? liveCourseTarget,
  required bool liveCourseOutlineEnabled,
  required String liveCourseOutlineMode,
  required bool preserveGaps,
}) {
  final dayCourses =
      courses
          .where((item) => item.dayOfWeek == weekday)
          .where((item) {
            return _displayStateForCourse(
                  item,
                  selectedWeek: selectedWeek,
                  realCurrentWeek: realCurrentWeek,
                  showPastEndedCourses: showPastEndedCourses,
                  showFutureCourses: showFutureCourses,
                ) !=
                null;
          })
          .map(
            (course) => _courseWithResolvedPeriodTime(
              course,
              periodTimes,
              preserveGaps: preserveGaps,
            ),
          )
          .toList()
        ..sort((a, b) {
          final startCompare = a.startMinutes.compareTo(b.startMinutes);
          if (startCompare != 0) {
            return startCompare;
          }
          final endCompare = a.endMinutes.compareTo(b.endMinutes);
          if (endCompare != 0) {
            return endCompare;
          }
          return a.id.compareTo(b.id);
        });

  final layouts = <CourseLayout>[];
  for (final group in buildOverlapGroups(dayCourses)) {
    if (_isFullConflictGroup(group.courses)) {
      final conflictKey = buildConflictKeyForCourses(
        timetable.id,
        weekday,
        group.courses,
      );
      final displayedCourseId = displayedCourseIdForConflict?.call(conflictKey);
      final displayedCourse = _pickDisplayedCourse(
        group.courses,
        displayedCourseId,
      );
      final sortedCourses = [...group.courses]
        ..sort(_compareDisplayedCourseChoice);
      final displayState =
          _displayStateForCourse(
            displayedCourse,
            selectedWeek: selectedWeek,
            realCurrentWeek: realCurrentWeek,
            showPastEndedCourses: showPastEndedCourses,
            showFutureCourses: showFutureCourses,
          ) ??
          CourseDisplayState.active;
      final isPrimaryLiveTarget =
          liveCourseOutlineEnabled &&
          liveCourseTarget?.week == selectedWeek &&
          liveCourseTarget?.weekday == weekday &&
          liveCourseTarget?.courseId == displayedCourse.id;
      final isLiveHighlighted =
          liveCourseOutlineEnabled &&
          (liveCourseOutlineMode == liveCourseOutlineModeAllDisplayed ||
              isPrimaryLiveTarget);
      layouts.add(
        CourseLayout(
          course: displayedCourse,
          priorityDepth: 0,
          isFullConflict: true,
          conflictCourses: sortedCourses,
          displayState: displayState,
          isLiveHighlighted: isLiveHighlighted,
          isPrimaryLiveTarget: isPrimaryLiveTarget,
          liveTargetIsCurrentCourse:
              isPrimaryLiveTarget &&
              (liveCourseTarget?.isCurrentCourse ?? false),
          conflictKey: conflictKey,
        ),
      );
      continue;
    }

    final sortedCourses = [...group.courses]..sort(_comparePaintPriority);
    for (var index = 0; index < sortedCourses.length; index++) {
      final course = sortedCourses[index];
      final displayState =
          _displayStateForCourse(
            course,
            selectedWeek: selectedWeek,
            realCurrentWeek: realCurrentWeek,
            showPastEndedCourses: showPastEndedCourses,
            showFutureCourses: showFutureCourses,
          ) ??
          CourseDisplayState.active;
      final isPrimaryLiveTarget =
          liveCourseOutlineEnabled &&
          liveCourseTarget?.week == selectedWeek &&
          liveCourseTarget?.weekday == weekday &&
          liveCourseTarget?.courseId == course.id;
      final isLiveHighlighted =
          liveCourseOutlineEnabled &&
          (liveCourseOutlineMode == liveCourseOutlineModeAllDisplayed ||
              isPrimaryLiveTarget);
      layouts.add(
        CourseLayout(
          course: course,
          priorityDepth: index,
          isFullConflict: false,
          conflictCourses: [course],
          displayState: displayState,
          isLiveHighlighted: isLiveHighlighted,
          isPrimaryLiveTarget: isPrimaryLiveTarget,
          liveTargetIsCurrentCourse:
              isPrimaryLiveTarget &&
              (liveCourseTarget?.isCurrentCourse ?? false),
        ),
      );
    }
  }
  return layouts;
}

CourseItem _courseWithResolvedPeriodTime(
  CourseItem course,
  List<CoursePeriodTime> periodTimes, {
  required bool preserveGaps,
}) {
  if (periodTimes.isEmpty) {
    return course;
  }
  final matched = course.periods.isEmpty
      ? const <CoursePeriodTime>[]
      : periodTimes
            .where((slot) => course.periods.contains(slot.index))
            .toList();
  if (matched.isNotEmpty && course.endMinutes <= course.startMinutes) {
    return course.copyWith(
      startMinutes: matched.map((slot) => slot.startMinutes).reduce(math.min),
      endMinutes: matched.map((slot) => slot.endMinutes).reduce(math.max),
    );
  }
  if (preserveGaps || course.endMinutes <= course.startMinutes) {
    return course;
  }

  // When gaps are collapsed, a course entirely inside a gap maps to zero
  // height. Anchor it to the nearest configured period so it remains visible
  // and participates in the same overlap group as the period it occupies.
  final start = course.startMinutes;
  final end = course.endMinutes;
  final overlapsSlot = periodTimes.where(
    (slot) => start < slot.endMinutes && end > slot.startMinutes,
  );
  if (overlapsSlot.isNotEmpty) return course;
  final anchor = periodTimes.firstWhere(
    (slot) => end <= slot.startMinutes,
    orElse: () => periodTimes.last,
  );
  return course.copyWith(
    startMinutes: anchor.startMinutes,
    endMinutes: anchor.endMinutes,
  );
}

List<CourseLayout> _buildDayLayoutsFromEntries({
  required List<TimetableEntry> entries,
  required int weekday,
}) {
  final dayEntries = entries.where((e) => e.dayOfWeek == weekday).toList()
    ..sort((a, b) {
      final startCompare = a.startMinutes.compareTo(b.startMinutes);
      if (startCompare != 0) return startCompare;
      final endCompare = a.endMinutes.compareTo(b.endMinutes);
      if (endCompare != 0) return endCompare;
      return a.id.compareTo(b.id);
    });

  final layouts = <CourseLayout>[];
  for (final group in _buildEntryOverlapGroups(dayEntries)) {
    final sorted = [...group]..sort(_compareEntryPaintPriority);
    for (var i = 0; i < sorted.length; i++) {
      layouts.add(
        CourseLayout(
          entry: sorted[i],
          priorityDepth: i,
          isFullConflict: false,
          conflictCourses: [sorted[i]],
          displayState: CourseDisplayState.active,
          isLiveHighlighted: false,
          isPrimaryLiveTarget: false,
          liveTargetIsCurrentCourse: false,
        ),
      );
    }
  }
  return layouts;
}

List<List<TimetableEntry>> _buildEntryOverlapGroups(
  List<TimetableEntry> entries,
) {
  if (entries.isEmpty) return const [];
  final groups = <List<TimetableEntry>>[];
  var current = <TimetableEntry>[];
  var currentEnd = -1;
  for (final entry in entries) {
    if (current.isEmpty) {
      current = [entry];
      currentEnd = entry.endMinutes;
      continue;
    }
    if (entry.startMinutes < currentEnd) {
      current.add(entry);
      currentEnd = math.max(currentEnd, entry.endMinutes);
      continue;
    }
    groups.add(List<TimetableEntry>.from(current));
    current = [entry];
    currentEnd = entry.endMinutes;
  }
  if (current.isNotEmpty) groups.add(List<TimetableEntry>.from(current));
  return groups;
}

int _compareEntryPaintPriority(TimetableEntry a, TimetableEntry b) {
  final startCompare = a.startMinutes.compareTo(b.startMinutes);
  if (startCompare != 0) return startCompare;
  final durCompare = (b.endMinutes - b.startMinutes).compareTo(
    a.endMinutes - a.startMinutes,
  );
  if (durCompare != 0) return durCompare;
  return a.id.compareTo(b.id);
}

CourseDisplayState? _displayStateForCourse(
  CourseItem course, {
  required int selectedWeek,
  required int realCurrentWeek,
  required bool showPastEndedCourses,
  required bool showFutureCourses,
}) {
  if (matchesSemesterWeek(course, selectedWeek)) {
    return CourseDisplayState.active;
  }
  if (course.semesterWeeks.isEmpty) {
    return CourseDisplayState.active;
  }
  final normalizedWeeks = normalizeSemesterWeeks(course.semesterWeeks);
  if (normalizedWeeks.isEmpty) {
    return CourseDisplayState.active;
  }
  if (selectedWeek < realCurrentWeek) {
    final nextWeek = normalizedWeeks.firstWhere(
      (week) => week > selectedWeek,
      orElse: () => -1,
    );
    if (nextWeek != -1) {
      return showFutureCourses ? CourseDisplayState.futureInactive : null;
    }
    return showPastEndedCourses ? CourseDisplayState.pastEnded : null;
  }
  if (selectedWeek > realCurrentWeek) {
    final lastWeek = normalizedWeeks.lastWhere(
      (week) => week < selectedWeek,
      orElse: () => -1,
    );
    if (lastWeek != -1) {
      return showPastEndedCourses ? CourseDisplayState.pastEnded : null;
    }
    return showFutureCourses ? CourseDisplayState.futureInactive : null;
  }
  final hasFutureWeek = normalizedWeeks.any((week) => week > realCurrentWeek);
  if (hasFutureWeek) {
    return showFutureCourses ? CourseDisplayState.futureInactive : null;
  }
  return showPastEndedCourses ? CourseDisplayState.pastEnded : null;
}

List<OverlapGroup> buildOverlapGroups(List<CourseItem> courses) {
  if (courses.isEmpty) {
    return const [];
  }
  final groups = <OverlapGroup>[];
  var currentCourses = <CourseItem>[];
  var currentEnd = -1;

  for (final course in courses) {
    if (currentCourses.isEmpty) {
      currentCourses = [course];
      currentEnd = course.endMinutes;
      continue;
    }
    if (course.startMinutes < currentEnd) {
      currentCourses.add(course);
      currentEnd = math.max(currentEnd, course.endMinutes);
      continue;
    }
    groups.add(OverlapGroup(List<CourseItem>.from(currentCourses)));
    currentCourses = [course];
    currentEnd = course.endMinutes;
  }

  if (currentCourses.isNotEmpty) {
    groups.add(OverlapGroup(List<CourseItem>.from(currentCourses)));
  }
  return groups;
}

bool _isFullConflictGroup(List<CourseItem> courses) {
  if (courses.length < 2) {
    return false;
  }
  final first = courses.first;
  final allSameRange = courses.every(
    (item) =>
        item.startMinutes == first.startMinutes &&
        item.endMinutes == first.endMinutes,
  );
  if (allSameRange) {
    return true;
  }
  if (courses.length == 2) {
    return _contains(courses[0], courses[1]) ||
        _contains(courses[1], courses[0]);
  }
  return false;
}

bool _contains(CourseItem outer, CourseItem inner) {
  return outer.startMinutes <= inner.startMinutes &&
      outer.endMinutes >= inner.endMinutes;
}

CourseItem _pickDisplayedCourse(
  List<CourseItem> courses,
  String? displayedCourseId,
) {
  for (final course in courses) {
    if (course.id == displayedCourseId) {
      return course;
    }
  }
  final sorted = [...courses]..sort(_compareDisplayedCourseChoice);
  return sorted.first;
}

int _compareDisplayedCourseChoice(CourseItem a, CourseItem b) {
  final durationCompare = (b.endMinutes - b.startMinutes).compareTo(
    a.endMinutes - a.startMinutes,
  );
  if (durationCompare != 0) {
    return durationCompare;
  }
  final startCompare = b.startMinutes.compareTo(a.startMinutes);
  if (startCompare != 0) {
    return startCompare;
  }
  return a.id.compareTo(b.id);
}

/// 晚开始的课压在上层，更符合肉眼对重叠关系的直觉；开始时间一样时再优先短课。
int _comparePaintPriority(CourseItem a, CourseItem b) {
  final startCompare = a.startMinutes.compareTo(b.startMinutes);
  if (startCompare != 0) {
    return startCompare;
  }
  final durationCompare = (b.endMinutes - b.startMinutes).compareTo(
    a.endMinutes - a.startMinutes,
  );
  if (durationCompare != 0) {
    return durationCompare;
  }
  return a.id.compareTo(b.id);
}

bool _isSameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
