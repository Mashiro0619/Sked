import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../models/timetable_models.dart';
import '../theme/timetable_contrast.dart';
import 'sked_floating_anchor.dart';
import 'timetable_grid.dart' show TimetableCourseTapInfo;
import 'timetable_week_projection.dart';
import 'workspace_frame.dart';

/// A naturally sized course agenda for the selected student timetable day.
/// Its parent owns the date selector, horizontal padding and content width.
class TimetableDayAgenda extends StatefulWidget {
  const TimetableDayAgenda({
    super.key,
    required this.timetable,
    required this.periodTimes,
    required this.weekDateStart,
    required this.selectedWeek,
    required this.realCurrentWeek,
    required this.localeCode,
    required this.selectedWeekday,
    required this.showPastEndedCourses,
    required this.showFutureCourses,
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
    this.onCourseTap,
    this.onAddCourse,
    this.showEmptyAddCourseAction = true,
    this.bottomContentInset = 0,
  }) : assert(selectedWeekday >= DateTime.monday),
       assert(selectedWeekday <= DateTime.sunday),
       assert(bottomContentInset >= 0);

  final TimetableData timetable;
  final List<CoursePeriodTime> periodTimes;
  final DateTime weekDateStart;
  final int selectedWeek;
  final int realCurrentWeek;
  final String localeCode;
  final int selectedWeekday;
  final bool showPastEndedCourses;
  final bool showFutureCourses;
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
  final ValueChanged<TimetableCourseTapInfo>? onCourseTap;
  final ValueChanged<BuildContext>? onAddCourse;
  final bool showEmptyAddCourseAction;
  final double bottomContentInset;

  @override
  State<TimetableDayAgenda> createState() => _TimetableDayAgendaState();
}

class _TimetableDayAgendaState extends State<TimetableDayAgenda> {
  final _scrollController = ScrollController(keepScrollOffset: false);
  final _projectionCache = TimetableWeekProjectionCache();
  final _nextProjectionCache = TimetableWeekProjectionCache();
  late TimetableWeekProjection _projection;
  bool _scrollResetPending = false;

  @override
  void initState() {
    super.initState();
    _updateProjection();
  }

  @override
  void didUpdateWidget(covariant TimetableDayAgenda oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateProjection();
    if (oldWidget.timetable.id != widget.timetable.id ||
        oldWidget.selectedWeek != widget.selectedWeek ||
        oldWidget.selectedWeekday != widget.selectedWeekday ||
        !DateUtils.isSameDay(oldWidget.weekDateStart, widget.weekDateStart)) {
      _resetScrollAfterLayout();
    }
  }

  void _updateProjection() {
    _projection = _projectionCache.project(
      timetable: widget.timetable,
      periodTimes: widget.periodTimes,
      selectedWeek: widget.selectedWeek,
      realCurrentWeek: widget.realCurrentWeek,
      showPastEndedCourses: widget.showPastEndedCourses,
      showFutureCourses: widget.showFutureCourses,
      preserveGaps: false,
    );
  }

  void _resetScrollAfterLayout() {
    if (_scrollResetPending) return;
    _scrollResetPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollResetPending = false;
      if (mounted && _scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }

  _NextDayCourse? _nextCourseAfter(DateTime selectedDate) {
    final config = widget.timetable.config;
    final semesterStart = startOfWeekFor(config, 1);
    final semesterEnd = addCalendarDays(
      semesterStart,
      config.totalWeeks * 7 - 1,
    );
    final followingDate = nextCalendarDate(selectedDate);
    if (followingDate.isAfter(semesterEnd)) return null;
    final firstDate = followingDate.isBefore(semesterStart)
        ? semesterStart
        : followingDate;
    final firstWeek = calendarDaysBetween(semesterStart, firstDate) ~/ 7 + 1;
    DateTime? nextDate;

    // Find the first real meeting date in one pass over stored course weeks.
    // This avoids projecting every empty week in a sparse or long semester.
    for (final course in widget.timetable.courses) {
      if (course.dayOfWeek < DateTime.monday ||
          course.dayOfWeek > DateTime.sunday ||
          resolveCourseTimeRange(course, _projection.periodTimes) == null) {
        continue;
      }
      final earliestWeek =
          firstWeek + (course.dayOfWeek < firstDate.weekday ? 1 : 0);
      if (earliestWeek > config.totalWeeks) continue;
      final weeks = normalizeSemesterWeeks(course.semesterWeeks);
      final candidateWeeks = weeks.isEmpty
          ? Iterable.generate(
              config.totalWeeks - earliestWeek + 1,
              (index) => earliestWeek + index,
            )
          : weeks.where((week) => week >= earliestWeek);
      for (final week in candidateWeeks) {
        if (week > config.totalWeeks) break;
        final dayOffset = (week - 1) * 7 + course.dayOfWeek - DateTime.monday;
        final date = addCalendarDays(semesterStart, dayOffset);
        // A timezone may omit an entire civil date. DateTime then normalizes
        // it into another weekday; that is not this course's real meeting.
        // Keep searching its later weeks instead of blocking other courses.
        if (calendarDaysBetween(semesterStart, date) != dayOffset) continue;
        if (nextDate == null || date.isBefore(nextDate)) nextDate = date;
        break;
      }
    }
    if (nextDate == null) return null;

    final week = calendarDaysBetween(semesterStart, nextDate) ~/ 7 + 1;
    // Resolve the chosen day with the same conflict and legacy-period rules
    // as the agenda; inactive previews cannot become the next real course.
    final projection = _nextProjectionCache.project(
      timetable: widget.timetable,
      periodTimes: widget.periodTimes,
      selectedWeek: week,
      realCurrentWeek: widget.realCurrentWeek,
      showPastEndedCourses: widget.showPastEndedCourses,
      showFutureCourses: widget.showFutureCourses,
      preserveGaps: false,
    );
    final layouts =
        (projection.resolveLayouts(
                  widget.displayedCourseIdForConflict,
                )[nextDate.weekday] ??
                const <CourseLayout>[])
            .where(
              (layout) =>
                  layout.displayState == CourseDisplayState.active &&
                  layout.endMinutes > layout.startMinutes,
            )
            .toList()
          ..sort((a, b) {
            final start = a.startMinutes.compareTo(b.startMinutes);
            if (start != 0) return start;
            final end = a.endMinutes.compareTo(b.endMinutes);
            return end != 0 ? end : a.course!.id.compareTo(b.course!.id);
          });
    return layouts.isEmpty
        ? null
        : _NextDayCourse(date: nextDate, layout: layouts.first);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layouts =
        List<CourseLayout>.of(
          _projection.resolveLayouts(
                widget.displayedCourseIdForConflict,
              )[widget.selectedWeekday] ??
              const [],
        )..sort((a, b) {
          final start = a.startMinutes.compareTo(b.startMinutes);
          if (start != 0) return start;
          final end = a.endMinutes.compareTo(b.endMinutes);
          return end != 0 ? end : a.course!.id.compareTo(b.course!.id);
        });
    final date = addCalendarDays(
      widget.weekDateStart,
      widget.selectedWeekday - DateTime.monday,
    );
    final customTextColor =
        widget.themeColorMode == themeColorModeColorful &&
            widget.colorfulCourseTextColorMode ==
                colorfulCourseTextColorModeCustom &&
            widget.colorfulCourseTextColorValue != null
        ? Color(widget.colorfulCourseTextColorValue!)
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final inlineTime = constraints.maxWidth < 360 || textScale >= 1.6;
        const topPadding = 12.0;
        final bottomPadding = 16 + widget.bottomContentInset;
        return ListView.separated(
          key: const ValueKey('student-day-agenda-scroll'),
          controller: _scrollController,
          padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
          itemCount: layouts.isEmpty ? 1 : layouts.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (layouts.isEmpty) {
              return ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.hasBoundedHeight
                      ? math.max(
                          0,
                          constraints.maxHeight - topPadding - bottomPadding,
                        )
                      : 0,
                ),
                child: _DayAgendaEmptyState(
                  nextCourse: _nextCourseAfter(date),
                  onAddCourse: widget.showEmptyAddCourseAction
                      ? widget.onAddCourse
                      : null,
                ),
              );
            }
            final layout = layouts[index];
            return _DayAgendaCourseRow(
              key: ValueKey('student-day-course-${layout.course!.id}'),
              layout: layout,
              date: date,
              selectedWeek: widget.selectedWeek,
              localeCode: widget.localeCode,
              inlineTime: inlineTime,
              timeColumnWidth: 56 * textScale,
              themeColorMode: widget.themeColorMode,
              courseNameColorValues: widget.courseNameColorValues,
              customTextColor: customTextColor,
              liveCourseTarget: widget.liveCourseTarget,
              liveCourseOutlineEnabled: widget.liveCourseOutlineEnabled,
              liveCourseOutlineMode: widget.liveCourseOutlineMode,
              outlineColor: Color(widget.liveCourseOutlineColorValue),
              outlineWidth: widget.liveCourseOutlineWidth,
              onCourseTap: widget.onCourseTap,
            );
          },
        );
      },
    );
  }
}

class _DayAgendaCourseRow extends StatelessWidget {
  const _DayAgendaCourseRow({
    super.key,
    required this.layout,
    required this.date,
    required this.selectedWeek,
    required this.localeCode,
    required this.inlineTime,
    required this.timeColumnWidth,
    required this.themeColorMode,
    required this.courseNameColorValues,
    required this.customTextColor,
    required this.liveCourseTarget,
    required this.liveCourseOutlineEnabled,
    required this.liveCourseOutlineMode,
    required this.outlineColor,
    required this.outlineWidth,
    required this.onCourseTap,
  });

  final CourseLayout layout;
  final DateTime date;
  final int selectedWeek;
  final String localeCode;
  final bool inlineTime;
  final double timeColumnWidth;
  final String themeColorMode;
  final Map<String, int> courseNameColorValues;
  final Color? customTextColor;
  final TimetableLiveCourseTarget? liveCourseTarget;
  final bool liveCourseOutlineEnabled;
  final String liveCourseOutlineMode;
  final Color outlineColor;
  final double outlineWidth;
  final ValueChanged<TimetableCourseTapInfo>? onCourseTap;

  CourseItem get course => layout.course!;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final selected = WorkspaceSelectionScope.isSelected(
      context,
      'course:${course.id}',
    );
    final colorful = themeColorMode == themeColorModeColorful;
    final courseColorValue =
        courseNameColorValues[normalizeCourseColorName(course.name)];
    final activeCourseColor = colorful && courseColorValue != null
        ? Color(courseColorValue)
        : colors.primary;
    final inactive = layout.displayState != CourseDisplayState.active;
    final background = Color.alphaBlend(
      activeCourseColor.withValues(alpha: inactive ? 0.05 : 0.07),
      colors.surfaceContainerLow,
    );
    final textColor =
        customTextColor ??
        resolveAutomaticTimetableTextColor(
          background,
          preferred: colors.onSurface,
        );
    final metadataColor =
        customTextColor ??
        resolveAutomaticTimetableTextColor(
          background,
          preferred: colors.onSurfaceVariant,
        );
    final primaryLiveTarget =
        liveCourseOutlineEnabled &&
        liveCourseTarget?.week == selectedWeek &&
        liveCourseTarget?.weekday == course.dayOfWeek &&
        liveCourseTarget?.courseId == course.id;
    final liveHighlighted =
        liveCourseOutlineEnabled &&
        (liveCourseOutlineMode == liveCourseOutlineModeAllDisplayed ||
            primaryLiveTarget);
    final outline = resolveTimetableOutlineColors(
      selected ? colors.primary : outlineColor,
      cardBackground: background,
      surroundingSurface: colors.surface,
    );
    final side = selected
        ? BorderSide(color: outline.outer, width: 2)
        : liveHighlighted
        ? BorderSide(
            color: outline.outer,
            width:
                normalizeLiveCourseOutlineWidth(outlineWidth) +
                (primaryLiveTarget &&
                        liveCourseOutlineMode ==
                            liveCourseOutlineModeAllDisplayed
                    ? 1.6
                    : 0),
          )
        : BorderSide.none;
    final periodsLabel = _periodsLabel(l10n, course.periods);
    final timeRange =
        '${formatMinutes(layout.startMinutes)}–${formatMinutes(layout.endMinutes)}';
    final location = course.location.trim();
    final teacher = course.teacher.trim();
    final inactiveWeeksLabel = inactive
        ? formatSemesterWeeksLabel(course.semesterWeeks, localeCode: localeCode)
        : '';
    final semanticsLabel = [
      course.name,
      MaterialLocalizations.of(context).formatFullDate(date),
      l10n.weekLabel(selectedWeek),
      timeRange,
      if (periodsLabel.isNotEmpty) periodsLabel,
      if (location.isNotEmpty) '${l10n.location}: $location',
      if (teacher.isNotEmpty) '${l10n.teacherName}: $teacher',
      if (inactive) ...[l10n.courseInactiveThisWeek, inactiveWeeksLabel],
      if (layout.conflictCourses.length > 1)
        '${l10n.conflictCourses}: ${layout.conflictCourses.length}',
    ].join(', ');
    final bodyStyle = theme.textTheme.bodyMedium?.copyWith(
      color: metadataColor,
      height: 1.4,
    );

    final card = Builder(
      builder: (cardContext) {
        void openCourse() {
          onCourseTap?.call(
            TimetableCourseTapInfo(
              course: course,
              courses: layout.conflictCourses.whereType<CourseItem>().toList(),
              isFullConflict: layout.isFullConflict,
              conflictKey: layout.conflictKey,
              selectedWeek: selectedWeek,
              anchorRect: SkedFloatingAnchor.capture(cardContext).globalRect,
            ),
          );
        }

        return Semantics(
          container: true,
          button: true,
          enabled: onCourseTap != null,
          selected: selected,
          label: semanticsLabel,
          onTap: onCourseTap == null ? null : openCourse,
          child: ExcludeSemantics(
            child: Material(
              key: ValueKey('student-day-course-card-${course.id}'),
              color: background,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: side,
              ),
              child: Stack(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: InkWell(
                      onTap: onCourseTap == null ? null : openCourse,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (inlineTime) ...[
                              Text(
                                timeRange,
                                key: ValueKey(
                                  'student-day-course-inline-time-${course.id}',
                                ),
                                style: bodyStyle?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            Text(
                              course.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: textColor,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                            ),
                            if (periodsLabel.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(periodsLabel, style: bodyStyle),
                            ],
                            if (inactive) ...[
                              const SizedBox(height: 4),
                              Text(
                                l10n.courseInactiveThisWeek,
                                style: bodyStyle,
                              ),
                              const SizedBox(height: 2),
                              Text(inactiveWeeksLabel, style: bodyStyle),
                            ],
                            if (location.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              _AgendaMetadata(
                                icon: Icons.location_on_outlined,
                                text: location,
                                style: bodyStyle,
                                color: metadataColor,
                              ),
                            ],
                            if (teacher.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              _AgendaMetadata(
                                icon: Icons.person_outline,
                                text: teacher,
                                style: bodyStyle,
                                color: metadataColor,
                              ),
                            ],
                            if (layout.conflictCourses.length > 1) ...[
                              const SizedBox(height: 8),
                              _AgendaMetadata(
                                icon: Icons.layers_outlined,
                                text:
                                    '${l10n.conflictCourses} · ${layout.conflictCourses.length}',
                                style: bodyStyle,
                                color: metadataColor,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (side != BorderSide.none && outline.inner != null)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Padding(
                          padding: EdgeInsets.all(side.width),
                          child: DecoratedBox(
                            key: ValueKey(
                              'student-day-course-outline-guard-${course.id}',
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                math.max(0, 12 - side.width),
                              ),
                              border: Border.all(color: outline.inner!),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (inlineTime) return card;
    final timeColor = resolveAutomaticTimetableTextColor(
      colors.surface,
      preferred: colors.onSurfaceVariant,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: SizedBox(
            width: timeColumnWidth,
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatMinutes(layout.startMinutes),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: timeColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatMinutes(layout.endMinutes),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: timeColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: card),
      ],
    );
  }
}

class _AgendaMetadata extends StatelessWidget {
  const _AgendaMetadata({
    required this.icon,
    required this.text,
    required this.style,
    required this.color,
  });

  final IconData icon;
  final String text;
  final TextStyle? style;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: style)),
      ],
    );
  }
}

class _NextDayCourse {
  const _NextDayCourse({required this.date, required this.layout});

  final DateTime date;
  final CourseLayout layout;
}

class _DayAgendaEmptyState extends StatelessWidget {
  const _DayAgendaEmptyState({
    required this.nextCourse,
    required this.onAddCourse,
  });

  final _NextDayCourse? nextCourse;
  final ValueChanged<BuildContext>? onAddCourse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_available_outlined,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.studentDayEmpty,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 24),
            if (nextCourse case final next?) ...[
              Text(
                l10n.studentDayNextCourse,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                next.layout.course!.name,
                key: const ValueKey('student-day-next-course-name'),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                MaterialLocalizations.of(context).formatFullDate(next.date),
                key: const ValueKey('student-day-next-course-date'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(
                buildTimeRange(
                  next.layout.startMinutes,
                  next.layout.endMinutes,
                ),
                key: const ValueKey('student-day-next-course-time'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ] else
              Text(
                l10n.studentDayNoMoreCourses,
                key: const ValueKey('student-day-no-more-courses'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            if (onAddCourse != null) ...[
              const SizedBox(height: 16),
              Builder(
                builder: (buttonContext) => ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: FilledButton.icon(
                    onPressed: () => onAddCourse!(buttonContext),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.addCourse),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _periodsLabel(AppLocalizations l10n, List<int> periods) {
  final sorted = periods.where((period) => period > 0).toSet().toList()..sort();
  if (sorted.isEmpty) return '';
  final labels = <String>[];
  var start = sorted.first;
  var end = start;
  void addRange() {
    labels.add(
      start == end
          ? l10n.periodNumberLabel(start)
          : l10n.periodRangeLabel(start, end),
    );
  }

  for (final period in sorted.skip(1)) {
    if (period == end + 1) {
      end = period;
    } else {
      addRange();
      start = period;
      end = period;
    }
  }
  addRange();
  return labels.join(' · ');
}
