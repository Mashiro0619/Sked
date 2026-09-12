import 'dart:async';

import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

import '../models/app_mode.dart';
import '../theme/sked_expressive_theme.dart';
import 'sked_picker_task.dart';
import 'workbench_chrome_metrics.dart';

Future<TimeOfDay?> showSkedTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
  BuildContext? anchorContext,
  AppMode? workspace,
  bool? alwaysUse24HourFormat,
}) {
  final use24 =
      alwaysUse24HourFormat ?? MediaQuery.alwaysUse24HourFormatOf(context);
  return showSkedPickerTask<TimeOfDay>(
    context: context,
    routeName: 'sked-time-picker',
    surfaceKey: const ValueKey('sked-time-picker-surface'),
    anchorContext: anchorContext,
    workspace: workspace,
    preferredSize: (context) {
      final metrics = WorkbenchChromeMetrics.of(context);
      return Size(
        math.max(metrics.desktop ? 320.0 : 360.0, 220 * metrics.textScale),
        metrics.iconTarget * 5 + 180 * metrics.textScale,
      );
    },
    builder: (context, finish, isCurrent) => SkedTimePicker(
      initialTime: initialTime,
      alwaysUse24HourFormat: use24,
      isSessionCurrent: isCurrent,
      onSelected: finish,
      onCancel: () => finish(null),
    ),
  );
}

/// Edits one time-of-day draft. Scrolling browses; only explicit selection
/// changes the draft, and only confirmation returns it to the owning workflow.
class SkedTimePicker extends StatefulWidget {
  const SkedTimePicker({
    super.key,
    required this.initialTime,
    required this.onSelected,
    required this.onCancel,
    this.alwaysUse24HourFormat,
    this.isSessionCurrent,
  });
  final TimeOfDay initialTime;
  final ValueChanged<TimeOfDay> onSelected;
  final VoidCallback onCancel;
  final bool? alwaysUse24HourFormat;
  final bool Function()? isSessionCurrent;
  @override
  State<SkedTimePicker> createState() => _SkedTimePickerState();
}

class _SkedTimePickerState extends State<SkedTimePicker> {
  final _hours = TextEditingController();
  final _minutes = TextEditingController();
  final _hourFocus = FocusNode(debugLabel: 'Time hour input');
  final _minuteFocus = FocusNode(debugLabel: 'Time minute input');
  late int _hour = widget.initialTime.hour;
  late int _minute = widget.initialTime.minute;
  late bool _pm = _hour >= 12;
  bool? _use24;
  bool _finished = false;
  bool get _current => !_finished && (widget.isSessionCurrent?.call() ?? true);
  String _two(int value) => value.toString().padLeft(2, '0');
  int? _parse(String value, int first, int last) {
    if (!RegExp(r'^\d{1,2}$').hasMatch(value)) return null;
    final parsed = int.tryParse(value);
    return parsed != null && parsed >= first && parsed <= last ? parsed : null;
  }

  int? get _displayHour =>
      _parse(_hours.text, _use24 == true ? 0 : 1, _use24 == true ? 23 : 12);
  int? get _displayMinute => _parse(_minutes.text, 0, 59);
  TimeOfDay? get _value {
    final h = _displayHour, m = _displayMinute;
    if (h == null || m == null) return null;
    return TimeOfDay(
      hour: _use24 == true ? h : h % 12 + (_pm ? 12 : 0),
      minute: m,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final format = MaterialLocalizations.of(context).timeOfDayFormat(
      alwaysUse24HourFormat:
          widget.alwaysUse24HourFormat ??
          MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final use24 =
        format != TimeOfDayFormat.h_colon_mm_space_a &&
        format != TimeOfDayFormat.a_space_h_colon_mm;
    if (_use24 != use24) {
      _use24 = use24;
      _hours.text = _two(use24 ? _hour : (_hour % 12 == 0 ? 12 : _hour % 12));
      if (_minutes.text.isEmpty) _minutes.text = _two(_minute);
    }
  }

  @override
  void dispose() {
    _hours.dispose();
    _minutes.dispose();
    _hourFocus.dispose();
    _minuteFocus.dispose();
    super.dispose();
  }

  void _changed() {
    if (!_current) return;
    setState(() {
      final h = _displayHour, m = _displayMinute;
      if (h != null) _hour = _use24! ? h : h % 12 + (_pm ? 12 : 0);
      if (m != null) _minute = m;
    });
  }

  void _select(bool hour, int value) {
    if (!_current) return;
    (hour ? _hours : _minutes).text = _two(value);
    _changed();
  }

  void _submit() {
    final value = _value;
    if (!_current || value == null) return;
    _finished = true;
    widget.onSelected(value);
  }

  void _cancel() {
    if (_finished) return;
    _finished = true;
    widget.onCancel();
  }

  @override
  Widget build(BuildContext context) {
    final m = MaterialLocalizations.of(context);
    final metrics = WorkbenchChromeMetrics.of(context);
    final rowHeight = math.max(
      metrics.desktop ? 36.0 : 52.0,
      24 * metrics.textScale + 12,
    );
    Widget field(bool hour) => TextField(
      key: ValueKey(hour ? 'sked-time-hour-input' : 'sked-time-minute-input'),
      controller: hour ? _hours : _minutes,
      focusNode: hour ? _hourFocus : _minuteFocus,
      autofocus: hour && metrics.desktop,
      keyboardType: TextInputType.number,
      textInputAction: hour ? TextInputAction.next : TextInputAction.done,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.headlineSmall
          ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      decoration: InputDecoration(
        labelText: hour ? m.timePickerHourLabel : m.timePickerMinuteLabel,
        border: const OutlineInputBorder(),
      ),
      onChanged: (_) => _changed(),
      onSubmitted: (_) => hour ? _minuteFocus.requestFocus() : _submit(),
    );
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
          child: SingleChildScrollView(
            key: const ValueKey('sked-time-picker-scroll'),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  m.timePickerDialHelpText,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: field(true)),
                    const SizedBox(
                      width: 12,
                      child: Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(':', textAlign: TextAlign.center),
                      ),
                    ),
                    Expanded(child: field(false)),
                  ],
                ),
                if (_value == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        m.invalidTimeLabel,
                        key: const ValueKey('sked-time-error'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                if (!_use24!)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        for (final pm in [false, true])
                          ChoiceChip(
                            key: ValueKey(pm ? 'sked-time-pm' : 'sked-time-am'),
                            label: Text(
                              pm
                                  ? m.postMeridiemAbbreviation
                                  : m.anteMeridiemAbbreviation,
                            ),
                            selected: _pm == pm,
                            onSelected: (_) {
                              if (_current) {
                                _pm = pm;
                                _changed();
                              }
                            },
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _TimeValueList(
                        key: const ValueKey('sked-time-hours'),
                        label: m.timePickerHourLabel,
                        id: 'hour',
                        first: _use24! ? 0 : 1,
                        last: _use24! ? 23 : 12,
                        selected: _displayHour,
                        rowHeight: rowHeight,
                        onSelected: (value) => _select(true, value),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TimeValueList(
                        key: const ValueKey('sked-time-minutes'),
                        label: m.timePickerMinuteLabel,
                        id: 'minute',
                        first: 0,
                        last: 59,
                        selected: _displayMinute,
                        rowHeight: rowHeight,
                        onSelected: (value) => _select(false, value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  children: [
                    TextButton(
                      key: const ValueKey('sked-time-cancel'),
                      onPressed: _cancel,
                      child: Text(m.cancelButtonLabel),
                    ),
                    FilledButton(
                      key: const ValueKey('sked-time-confirm'),
                      onPressed: _value != null && _current ? _submit : null,
                      child: Text(m.okButtonLabel),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimeValueList extends StatefulWidget {
  const _TimeValueList({
    super.key,
    required this.label,
    required this.id,
    required this.first,
    required this.last,
    required this.selected,
    required this.rowHeight,
    required this.onSelected,
  });
  final String label, id;
  final int first, last;
  final int? selected;
  final double rowHeight;
  final ValueChanged<int> onSelected;
  @override
  State<_TimeValueList> createState() => _TimeValueListState();
}

class _TimeValueListState extends State<_TimeValueList> {
  static const _visibleRows = 5;
  late final _scroll = ScrollController(
    initialScrollOffset:
        ((widget.selected ?? widget.first) - widget.first - 2)
            .clamp(0, widget.last - widget.first + 1 - _visibleRows)
            .toDouble() *
        widget.rowHeight,
  );
  final _focus = FocusNode(debugLabel: 'Time value list');
  int _revealGeneration = 0;
  bool _focused = false;

  @override
  void didUpdateWidget(_TimeValueList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final geometryChanged =
        oldWidget.rowHeight != widget.rowHeight ||
        oldWidget.first != widget.first;
    final selectionChanged =
        oldWidget.selected != widget.selected ||
        oldWidget.first != widget.first;
    if (selectionChanged || geometryChanged) {
      final generation = ++_revealGeneration;
      final oldTopRow = _scroll.hasClients
          ? _scroll.offset / oldWidget.rowHeight
          : null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            generation != _revealGeneration ||
            !_scroll.hasClients) {
          return;
        }
        if (geometryChanged && oldTopRow != null) {
          _scroll.jumpTo(
            (oldTopRow * widget.rowHeight).clamp(
              0.0,
              _scroll.position.maxScrollExtent,
            ),
          );
        }
        if (selectionChanged) _revealSelection(animate: !geometryChanged);
      });
    }
  }

  void _revealSelection({required bool animate}) {
    if (!_scroll.hasClients || widget.selected == null) return;
    final position = _scroll.position;
    final top = (widget.selected! - widget.first) * widget.rowHeight;
    final bottom = top + widget.rowHeight;
    // Visible choices stay where they are. Re-centering on every click moves
    // the user's next target and makes repeated adjustments unnecessarily hard.
    final target =
        (top < position.pixels
                ? top
                : bottom > position.pixels + position.viewportDimension
                ? bottom - position.viewportDimension
                : position.pixels)
            .clamp(0.0, position.maxScrollExtent);
    if ((position.pixels - target).abs() < .5) return;
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
  }

  @override
  void dispose() {
    _revealGeneration++;
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final value = widget.selected ?? widget.first;
    final next = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowDown => value + 1,
      LogicalKeyboardKey.arrowUp => value - 1,
      LogicalKeyboardKey.pageDown => value + _visibleRows,
      LogicalKeyboardKey.pageUp => value - _visibleRows,
      LogicalKeyboardKey.home => widget.first,
      LogicalKeyboardKey.end => widget.last,
      _ => null,
    };
    if (next == null) return KeyEventResult.ignored;
    widget.onSelected(next.clamp(widget.first, widget.last));
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final behavior = ScrollConfiguration.of(context);
    return Focus(
      focusNode: _focus,
      onKeyEvent: _key,
      onFocusChange: (value) {
        if (mounted) setState(() => _focused = value);
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _focused
                ? colors.primary
                : colors.outlineVariant.withValues(alpha: .45),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(1),
          child: SizedBox(
            height: widget.rowHeight * _visibleRows,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: ScrollConfiguration(
                // Own exactly one slim scrollbar; Flutter's desktop behavior
                // must not add another. Mouse drag browses just like touch.
                behavior: behavior.copyWith(
                  scrollbars: false,
                  overscroll: false,
                  dragDevices: {
                    ...behavior.dragDevices,
                    PointerDeviceKind.mouse,
                  },
                ),
                child: Scrollbar(
                  controller: _scroll,
                  thickness: 3,
                  radius: const Radius.circular(3),
                  thumbVisibility: false,
                  trackVisibility: false,
                  child: NotificationListener<ScrollStartNotification>(
                    onNotification: (notification) {
                      if (notification.dragDetails != null) _revealGeneration++;
                      return false;
                    },
                    child: ListView.builder(
                      controller: _scroll,
                      primary: false,
                      padding: EdgeInsets.zero,
                      itemExtent: widget.rowHeight,
                      itemCount: widget.last - widget.first + 1,
                      itemBuilder: (context, index) {
                        final value = widget.first + index;
                        final selected = value == widget.selected;
                        void select() {
                          _focus.requestFocus();
                          widget.onSelected(value);
                        }

                        return Padding(
                          // Symmetric insets keep numbers aligned with the
                          // inputs and leave space for the unobtrusive thumb.
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          child: Semantics(
                            button: true,
                            selected: selected,
                            label:
                                '${widget.label} ${value.toString().padLeft(2, '0')}',
                            onTap: select,
                            excludeSemantics: true,
                            child: Material(
                              color: selected
                                  ? colors.primaryContainer
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                              child: InkWell(
                                key: ValueKey('sked-time-${widget.id}-$value'),
                                onTap: select,
                                canRequestFocus: false,
                                excludeFromSemantics: true,
                                borderRadius: BorderRadius.circular(6),
                                child: Center(
                                  child: Text(
                                    value.toString().padLeft(2, '0'),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: selected
                                              ? colors.onPrimaryContainer
                                              : colors.onSurfaceVariant,
                                          fontWeight: selected
                                              ? FontWeight.w700
                                              : FontWeight.w400,
                                          fontFeatures: const [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
