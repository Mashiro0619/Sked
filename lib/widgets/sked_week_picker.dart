import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../models/timetable_models.dart';
import '../theme/sked_expressive_theme.dart';
import 'sked_picker_task.dart';
import 'workbench_chrome_metrics.dart';

/// A bounded semester-week navigation task, never a persisted preference.
Future<int?> showSkedWeekPicker({
  required BuildContext context,
  required TimetableConfig config,
  required int selectedWeek,
  BuildContext? anchorContext,
  DateTime? currentDate,
  bool Function()? isSessionCurrent,
}) => showSkedPickerTask<int>(
  context: context,
  routeName: 'sked-week-picker',
  compactPresentation: SkedPickerCompactPresentation.anchored,
  surfaceKey: const ValueKey('sked-week-picker-surface'),
  anchorContext: anchorContext,
  workspace: AppMode.student,
  isSessionCurrent: isSessionCurrent,
  preferredSize: (context) {
    final metrics = WorkbenchChromeMetrics.of(context);
    final width =
        metrics.desktop || WorkbenchChromeMetrics.compactTouch(context)
        ? 320.0
        : 360.0;
    final layout = _WeekGridLayout.resolve(
      context,
      width - 24,
      config.totalWeeks,
    );
    return Size(
      width,
      layout.height +
          24 +
          8 +
          math.max(metrics.iconTarget, 24 * metrics.textScale),
    );
  },
  builder: (context, finish, isCurrent) => SkedWeekPicker(
    config: config,
    selectedWeek: selectedWeek,
    currentDate: currentDate,
    isSessionCurrent: isCurrent,
    onSelected: finish,
    onCancel: () => finish(null),
  ),
);

class SkedWeekPicker extends StatefulWidget {
  SkedWeekPicker({
    super.key,
    required this.config,
    required this.selectedWeek,
    required this.onSelected,
    required this.onCancel,
    this.currentDate,
    this.isSessionCurrent,
  }) : assert(config.totalWeeks > 0 && config.totalWeeks <= maxTimetableWeeks),
       assert(selectedWeek >= 1 && selectedWeek <= config.totalWeeks);

  final TimetableConfig config;
  final int selectedWeek;
  final ValueChanged<int> onSelected;
  final VoidCallback onCancel;
  final DateTime? currentDate;
  final bool Function()? isSessionCurrent;

  @override
  State<SkedWeekPicker> createState() => _SkedWeekPickerState();
}

class _WeekGridLayout {
  const _WeekGridLayout(this.columns, this.rowHeight, this.rows);
  static const gap = 4.0;
  final int columns, rows;
  final double rowHeight;
  double get stride => rowHeight + gap;
  double get height => math.min(rows, 6) * stride - gap;

  factory _WeekGridLayout.resolve(
    BuildContext context,
    double width,
    int count,
  ) {
    final metrics = WorkbenchChromeMetrics.of(context);
    final rowHeight = math.max(
      metrics.desktop ? 36.0 : 48.0,
      20 * metrics.textScale + 12,
    );
    final minimumWidth = math.max(rowHeight, 48 * metrics.textScale);
    final compact = WorkbenchChromeMetrics.compactTouch(context);
    final fittingColumns = ((width + gap) / (minimumWidth + gap)).floor().clamp(
      1,
      compact ? 7 : 5,
    );
    // Use phone width without a lonely last item when fewer columns fit the
    // same number of rows (19 weeks: 5×4 rather than 6×4 with only one at end).
    final rows = (count / fittingColumns).ceil();
    final columns = compact ? (count / rows).ceil() : fittingColumns;
    return _WeekGridLayout(columns, rowHeight, (count / columns).ceil());
  }
}

class _SkedWeekPickerState extends State<SkedWeekPicker> {
  final _scroll = ScrollController();
  final _gridFocus = FocusNode(debugLabel: 'Semester week grid');
  late int _focusedWeek = widget.selectedWeek;
  late final DateTime _openedDate = normalizeDateOnly(DateTime.now());
  _WeekGridLayout? _layout;
  int _visibleRows = 1;
  double? _viewportHeight;
  int _scrollGeneration = 0;
  bool _focused = false, _finished = false;
  bool get _current => !_finished && widget.isSessionCurrent?.call() != false;

  int? get _todayWeek {
    final first = startOfWeekFor(widget.config, 1);
    final today = normalizeDateOnly(widget.currentDate ?? _openedDate);
    final days = calendarDaysBetween(first, today);
    final week = days ~/ 7 + 1;
    return days >= 0 && week <= widget.config.totalWeeks ? week : null;
  }

  @override
  void didUpdateWidget(SkedWeekPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedWeek != oldWidget.selectedWeek) {
      _focusedWeek = widget.selectedWeek;
      _scheduleScroll(revealFocus: true);
    }
    _focusedWeek = _focusedWeek.clamp(1, widget.config.totalWeeks);
  }

  @override
  void dispose() {
    _scrollGeneration++;
    _scroll.dispose();
    _gridFocus.dispose();
    super.dispose();
  }

  void _select(int week) {
    if (!_current) return;
    _finished = true;
    widget.onSelected(week);
  }

  void _cancel() {
    if (_finished) return;
    _finished = true;
    widget.onCancel();
  }

  void _scheduleScroll({
    required bool revealFocus,
    int? topWeek,
    bool animate = false,
  }) {
    final generation = ++_scrollGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _scrollGeneration || !_scroll.hasClients) {
        return;
      }
      final layout = _layout!;
      final position = _scroll.position;
      double target = position.pixels;
      if (topWeek != null) {
        target = ((topWeek - 1) ~/ layout.columns) * layout.stride;
      }
      if (revealFocus) {
        final top = ((_focusedWeek - 1) ~/ layout.columns) * layout.stride;
        final bottom = top + layout.rowHeight;
        if (top < target) target = top;
        if (bottom > target + position.viewportDimension) {
          target = bottom - position.viewportDimension;
        }
      }
      target = target.clamp(0.0, position.maxScrollExtent);
      if ((target - position.pixels).abs() < .5) return;
      final motion = SkedMotionPolicy.of(context);
      if (animate && motion.spatialAnimationsEnabled) {
        unawaited(
          _scroll.animateTo(
            target,
            duration: motion.effects(SkedMotionSpeed.fast),
            curve: Curves.easeOutCubic,
          ),
        );
      } else {
        _scroll.jumpTo(target);
      }
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _cancel();
      return KeyEventResult.handled;
    }
    if (!_current) return KeyEventResult.handled;
    final columns = _layout?.columns ?? 5;
    final horizontal = Directionality.of(context) == TextDirection.rtl ? -1 : 1;
    final next = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowLeft => _focusedWeek - horizontal,
      LogicalKeyboardKey.arrowRight => _focusedWeek + horizontal,
      LogicalKeyboardKey.arrowUp => _focusedWeek - columns,
      LogicalKeyboardKey.arrowDown => _focusedWeek + columns,
      LogicalKeyboardKey.home => 1,
      LogicalKeyboardKey.end => widget.config.totalWeeks,
      LogicalKeyboardKey.pageUp => _focusedWeek - columns * _visibleRows,
      LogicalKeyboardKey.pageDown => _focusedWeek + columns * _visibleRows,
      _ => null,
    };
    if (next != null) {
      setState(() => _focusedWeek = next.clamp(1, widget.config.totalWeeks));
      _scheduleScroll(revealFocus: true, animate: true);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.space) {
      _select(_focusedWeek);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final m = MaterialLocalizations.of(context);
    final metrics = WorkbenchChromeMetrics.of(context);
    final compact = WorkbenchChromeMetrics.compactTouch(context);
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
      },
      child: Actions(
        actions: {
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              _cancel();
              return null;
            },
          ),
        },
        child: FocusTraversalGroup(
          child: Padding(
            key: const ValueKey('sked-week-picker-content'),
            padding: compact
                ? const EdgeInsets.symmetric(horizontal: 12, vertical: 4)
                : const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.jumpToWeek,
                        style: compact
                            ? Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontSize: 18,
                                height: 1.2,
                                fontWeight: FontWeight.w500,
                              )
                            : Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('sked-week-picker-close'),
                      tooltip: m.closeButtonLabel,
                      style: metrics.iconStyle,
                      onPressed: _cancel,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                if (!compact) const SizedBox(height: 8),
                Flexible(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final next = _WeekGridLayout.resolve(
                        context,
                        constraints.maxWidth,
                        widget.config.totalWeeks,
                      );
                      final old = _layout;
                      final height = math.min(
                        next.height,
                        constraints.maxHeight,
                      );
                      final visibleRows = math.max(
                        1,
                        ((height + _WeekGridLayout.gap) / next.stride).floor(),
                      );
                      if (old == null ||
                          old.columns != next.columns ||
                          old.rowHeight != next.rowHeight ||
                          old.rows != next.rows ||
                          _visibleRows != visibleRows ||
                          _viewportHeight != height) {
                        final topWeek = old != null && _scroll.hasClients
                            ? (_scroll.offset / old.stride).floor() *
                                      old.columns +
                                  1
                            : null;
                        final focusWasVisible =
                            old == null ||
                            !_scroll.hasClients ||
                            (((_focusedWeek - 1) ~/ old.columns) * old.stride >=
                                    _scroll.offset &&
                                ((_focusedWeek - 1) ~/ old.columns) *
                                            old.stride +
                                        old.rowHeight <=
                                    _scroll.offset +
                                        _scroll.position.viewportDimension +
                                        .5);
                        _layout = next;
                        _visibleRows = visibleRows;
                        _viewportHeight = height;
                        _scheduleScroll(
                          topWeek: topWeek,
                          revealFocus: focusWasVisible,
                        );
                      }
                      return SizedBox(
                        height: math.max(0, height),
                        child: Focus(
                          key: const ValueKey('sked-week-grid-focus'),
                          focusNode: _gridFocus,
                          autofocus: true,
                          onKeyEvent: _onKey,
                          onFocusChange: (focused) {
                            if (mounted) setState(() => _focused = focused);
                          },
                          child: ScrollConfiguration(
                            behavior: ScrollConfiguration.of(context).copyWith(
                              scrollbars: false,
                              dragDevices: {
                                ...ScrollConfiguration.of(context).dragDevices,
                                PointerDeviceKind.mouse,
                              },
                            ),
                            child: Scrollbar(
                              controller: _scroll,
                              thickness: 3,
                              thumbVisibility: false,
                              child: GridView.builder(
                                key: const ValueKey('sked-week-picker-grid'),
                                controller: _scroll,
                                primary: false,
                                padding: EdgeInsets.zero,
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: next.columns,
                                      crossAxisSpacing: _WeekGridLayout.gap,
                                      mainAxisSpacing: _WeekGridLayout.gap,
                                      mainAxisExtent: next.rowHeight,
                                    ),
                                itemCount: widget.config.totalWeeks,
                                itemBuilder: (context, index) =>
                                    _week(context, index + 1),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _week(BuildContext context, int week) {
    final l = AppLocalizations.of(context);
    final m = MaterialLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final start = startOfWeekFor(widget.config, week);
    final end = addCalendarDays(start, 6);
    final today = week == _todayWeek;
    final dates = '${m.formatShortDate(start)} – ${m.formatShortDate(end)}';
    final label = l.weekLabel(week);
    final selected = week == widget.selectedWeek;
    final focused = _focused && week == _focusedWeek;
    final hint = today ? '$dates · ${l.today}' : dates;
    return Semantics(
      key: ValueKey('student-week-option-$week'),
      button: true,
      selected: selected,
      focusable: true,
      focused: focused,
      label: label,
      value: hint,
      onTap: () => _select(week),
      excludeSemantics: true,
      child: Tooltip(
        message: '$label · $hint',
        excludeFromSemantics: true,
        child: WorkbenchChromeMetrics.compactTouch(context)
            ? _touchWeek(
                context,
                week,
                selected: selected,
                focused: focused,
                today: today,
              )
            : Material(
                color: Colors.transparent,
                child: InkWell(
                  canRequestFocus: false,
                  excludeFromSemantics: true,
                  onTap: () => _select(week),
                  borderRadius: BorderRadius.circular(6),
                  child: Ink(
                    decoration: BoxDecoration(
                      color: selected
                          ? colors.primary.withValues(alpha: .12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: focused
                          ? Border.all(color: colors.primary)
                          : null,
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Text(
                            '$week',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                          ),
                        ),
                        if (today)
                          Positioned(
                            bottom: 3,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Container(
                                key: ValueKey('student-week-current-$week'),
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: colors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _touchWeek(
    BuildContext context,
    int week, {
    required bool selected,
    required bool focused,
    required bool today,
  }) {
    final theme = Theme.of(context), colors = theme.colorScheme;
    final keyboardFocus =
        focused &&
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _select(week),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final diameter = math.min(
            constraints.maxWidth,
            constraints.maxHeight - 6,
          );
          return Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.square(
                dimension: diameter,
                child: DecoratedBox(
                  key: ValueKey('student-week-touch-marker-$week'),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? colors.primary : null,
                    border: keyboardFocus
                        ? Border.all(
                            color: selected ? colors.onPrimary : colors.primary,
                            width: 2,
                          )
                        : null,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '$week',
                  maxLines: 1,
                  softWrap: false,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 18,
                    height: 1.2,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? colors.onPrimary : colors.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              if (today)
                Positioned(
                  bottom: (constraints.maxHeight - diameter) / 2 + 3,
                  child: Container(
                    key: ValueKey('student-week-current-$week'),
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: selected ? colors.onPrimary : colors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
