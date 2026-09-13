import 'package:flutter/scheduler.dart';

import '../theme/sked_surface.dart';

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

/// Edits one time-of-day draft. Wheels select on settling; only confirmation
/// returns the minute-precise value to the owning workflow.
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
  int _hourInputRevision = 0, _minuteInputRevision = 0;
  bool _hourMoving = false, _minuteMoving = false;
  final _hourWheel = GlobalKey<_TimeValueWheelState>();
  final _minuteWheel = GlobalKey<_TimeValueWheelState>();
  bool get _settled =>
      !_hourMoving &&
      !_minuteMoving &&
      _hourWheel.currentState?.isMoving != true &&
      _minuteWheel.currentState?.isMoving != true;
  int get _lastDisplayHour =>
      _use24 == true ? _hour : (_hour % 12 == 0 ? 12 : _hour % 12);
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

  void _changed(bool hour) {
    if (!_current) return;
    setState(() {
      if (hour) {
        final h = _displayHour;
        if (h != null) _hour = _use24! ? h : h % 12 + (_pm ? 12 : 0);
        _hourInputRevision++;
        _hourMoving = true;
      } else {
        final m = _displayMinute;
        if (m != null) _minute = m;
        _minuteInputRevision++;
        _minuteMoving = true;
      }
    });
  }

  void _select(bool hour, int value) {
    if (!_current) return;
    setState(() {
      (hour ? _hours : _minutes).text = _two(value);
      if (hour) {
        _hour = _use24! ? value : value % 12 + (_pm ? 12 : 0);
      } else {
        _minute = value;
      }
    });
  }

  void _activityChanged(bool hour, bool moving) {
    if (!_current) return;
    setState(() {
      if (hour) {
        _hourMoving = moving;
      } else {
        _minuteMoving = moving;
      }
    });
  }

  void _submit() {
    final value = _value;
    if (!_current || !_settled || value == null) return;
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
    final hourRevision = _hourInputRevision;
    final minuteRevision = _minuteInputRevision;
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
      onChanged: (_) => _changed(hour),
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
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              // An exceptionally short window may not fit even the footer.
              // Retain one tree (and draft) while allowing that fallback to scroll.
              primary: false,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight.isFinite
                      ? math.max(
                          constraints.maxHeight,
                          metrics.iconTarget + 100,
                        )
                      : double.infinity,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Flexible(
                        child: SingleChildScrollView(
                          key: const ValueKey('sked-time-picker-scroll'),
                          primary: false,
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
                                      child: Text(
                                        ':',
                                        textAlign: TextAlign.center,
                                      ),
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
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error,
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
                                          key: ValueKey(
                                            pm
                                                ? 'sked-time-pm'
                                                : 'sked-time-am',
                                          ),
                                          label: Text(
                                            pm
                                                ? m.postMeridiemAbbreviation
                                                : m.anteMeridiemAbbreviation,
                                          ),
                                          selected: _pm == pm,
                                          onSelected: (_) {
                                            if (_current) {
                                              setState(() {
                                                _pm = pm;
                                                // Period selection never changes the displayed hour.
                                                _hour =
                                                    _hour % 12 + (pm ? 12 : 0);
                                              });
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
                                    child: _TimeValueWheel(
                                      key: _hourWheel,
                                      label: m.timePickerHourLabel,
                                      id: 'hour',
                                      first: _use24! ? 0 : 1,
                                      last: _use24! ? 23 : 12,
                                      value: _lastDisplayHour,
                                      inputRevision: _hourInputRevision,
                                      onActivityChanged: (moving) {
                                        if (hourRevision ==
                                            _hourInputRevision) {
                                          _activityChanged(true, moving);
                                        }
                                      },
                                      rowHeight: rowHeight,
                                      onSelected: (value) {
                                        if (hourRevision ==
                                            _hourInputRevision) {
                                          _select(true, value);
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _TimeValueWheel(
                                      key: _minuteWheel,
                                      label: m.timePickerMinuteLabel,
                                      id: 'minute',
                                      first: 0,
                                      last: 59,
                                      value: _minute,
                                      inputRevision: _minuteInputRevision,
                                      onActivityChanged: (moving) {
                                        if (minuteRevision ==
                                            _minuteInputRevision) {
                                          _activityChanged(false, moving);
                                        }
                                      },
                                      rowHeight: rowHeight,
                                      onSelected: (value) {
                                        if (minuteRevision ==
                                            _minuteInputRevision) {
                                          _select(false, value);
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
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
                            onPressed: _value != null && _current && _settled
                                ? _submit
                                : null,
                            child: Text(m.okButtonLabel),
                          ),
                        ],
                      ),
                    ],
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

enum _WheelOrigin { input, gesture, selection }

class _TimeValueWheel extends StatefulWidget {
  const _TimeValueWheel({
    super.key,
    required this.label,
    required this.id,
    required this.first,
    required this.last,
    required this.value,
    required this.inputRevision,
    required this.rowHeight,
    required this.onSelected,
    required this.onActivityChanged,
  });
  final String label, id;
  final int first, last, value, inputRevision;
  final double rowHeight;
  final ValueChanged<int> onSelected;
  final ValueChanged<bool> onActivityChanged;
  @override
  State<_TimeValueWheel> createState() => _TimeValueWheelState();
}

class _TimeValueWheelState extends State<_TimeValueWheel> {
  static const _visibleRows = 5;
  late final _scroll = FixedExtentScrollController(
    initialItem: widget.value - widget.first,
  );
  final _focus = FocusNode(debugLabel: 'Time value wheel');
  bool _focused = false, _moving = false, _pointerDown = false;
  bool _activityQueued = false;
  int _generation = 0;
  int? _targetIndex;
  _WheelOrigin? _origin;

  bool get isMoving =>
      _moving ||
      (_scroll.hasClients && _scroll.position.isScrollingNotifier.value);
  int get _count => widget.last - widget.first + 1;
  int _valueAt(int index) => widget.first + index % _count;
  String _two(int value) => value.toString().padLeft(2, '0');

  int _nearest(int value, int from) {
    final forward = (value - _valueAt(from)) % _count;
    return from + (forward > _count / 2 ? forward - _count : forward);
  }

  void _reportActivity() {
    if (SchedulerBinding.instance.schedulerPhase !=
        SchedulerPhase.persistentCallbacks) {
      widget.onActivityChanged(isMoving);
      return;
    }
    if (_activityQueued) return;
    _activityQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _activityQueued = false;
      if (mounted) widget.onActivityChanged(isMoving);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void didUpdateWidget(_TimeValueWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final geometryChanged =
        widget.rowHeight != oldWidget.rowHeight ||
        widget.first != oldWidget.first ||
        widget.last != oldWidget.last;
    if (geometryChanged || widget.inputRevision != oldWidget.inputRevision) {
      // Invalidate old drag/animation callbacks before the next layout. Even an
      // invalid edit interrupts inertia, but never gets replaced by a wheel value.
      final index = _scroll.hasClients ? _scroll.selectedItem : 0;
      final generation = ++_generation;
      _origin = _WheelOrigin.input;
      _pointerDown = false;
      _moving = true;
      _reportActivity();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || generation != _generation || !_scroll.hasClients) {
          return;
        }
        _moveTo(
          _nearest(widget.value, index),
          _WheelOrigin.input,
          animate: !geometryChanged,
        );
      });
    }
  }

  void _moveTo(int index, _WheelOrigin origin, {bool animate = true}) {
    if (!_scroll.hasClients) return;
    final generation = ++_generation;
    _origin = origin;
    _targetIndex = index;
    _moving = true;
    _reportActivity();
    final motion = SkedMotionPolicy.of(context);
    final offset = index * widget.rowHeight;
    if (animate &&
        motion.spatialAnimationsEnabled &&
        (_scroll.offset - offset).abs() > .5) {
      unawaited(
        _scroll
            .animateToItem(
              index,
              duration: motion.effects(SkedMotionSpeed.fast),
              curve: Curves.easeOutCubic,
            )
            .then((_) => _queueSettled(generation)),
      );
    } else {
      _scroll.jumpToItem(index);
      _queueSettled(generation);
    }
  }

  void _beginGesture() {
    _generation++;
    _origin = _WheelOrigin.gesture;
    _targetIndex = null;
  }

  void _queueSettled(int generation) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          generation != _generation ||
          !_scroll.hasClients ||
          _pointerDown ||
          _scroll.position.isScrollingNotifier.value) {
        return;
      }
      final origin = _origin;
      if (origin == null) return;
      final index = _scroll.selectedItem;
      // Pointer signals end before FixedExtentScrollPhysics starts its snap.
      // Never publish a fractional/intermediate position from that notification.
      // Spring simulations stop within device-pixel tolerance, not necessarily
      // exactly on an item. Canonicalize the resting position before publishing.
      if ((_scroll.offset - index * widget.rowHeight).abs() > .01) {
        _scroll.jumpToItem(index);
      }
      _origin = null;
      _targetIndex = null;
      _moving = false;
      if (origin != _WheelOrigin.input) widget.onSelected(_valueAt(index));
      _reportActivity();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0 ||
        notification.metrics is! FixedExtentMetrics) {
      return false;
    }
    if (notification is ScrollStartNotification) {
      if (_origin == null) _beginGesture();
      _moving = true;
      _reportActivity();
    } else if (notification is ScrollEndNotification) {
      _queueSettled(_generation);
    }
    return false;
  }

  void _step(int amount) {
    if (!_scroll.hasClients) return;
    _moveTo(
      (_targetIndex ?? _scroll.selectedItem) + amount,
      _WheelOrigin.selection,
    );
  }

  void _select(int value) {
    _focus.requestFocus();
    if (_scroll.hasClients) {
      _moveTo(_nearest(value, _scroll.selectedItem), _WheelOrigin.selection);
    }
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        _step(1);
      case LogicalKeyboardKey.arrowUp:
        _step(-1);
      case LogicalKeyboardKey.pageDown:
        _step(_visibleRows);
      case LogicalKeyboardKey.pageUp:
        _step(-_visibleRows);
      case LogicalKeyboardKey.home:
        _select(widget.first);
      case LogicalKeyboardKey.end:
        _select(widget.last);
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    _generation++;
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final behavior = ScrollConfiguration.of(context);
    return Semantics(
      key: ValueKey(
        widget.id == 'hour' ? 'sked-time-hours' : 'sked-time-minutes',
      ),
      label: widget.label,
      value: _two(widget.value),
      increasedValue: _two(
        widget.first + (widget.value - widget.first + 1) % _count,
      ),
      decreasedValue: _two(
        widget.first + (widget.value - widget.first - 1) % _count,
      ),
      onIncrease: () => _step(1),
      onDecrease: () => _step(-1),
      focusable: true,
      focused: _focused,
      child: ExcludeSemantics(
        child: Focus(
          focusNode: _focus,
          onKeyEvent: _key,
          onFocusChange: (value) {
            if (mounted) setState(() => _focused = value);
          },
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: SkedSurface.colorOf(context),
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
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Center(
                        child: IgnorePointer(
                          child: Container(
                            key: ValueKey('sked-time-${widget.id}-center'),
                            height: widget.rowHeight,
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: .10),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                      Listener(
                        onPointerDown: (_) {
                          _pointerDown = true;
                          _beginGesture();
                        },
                        onPointerUp: (_) {
                          _pointerDown = false;
                          _queueSettled(_generation);
                        },
                        onPointerCancel: (_) {
                          _pointerDown = false;
                          _queueSettled(_generation);
                        },
                        onPointerSignal: (event) {
                          if (event is PointerScrollEvent &&
                              event.scrollDelta.dy != 0) {
                            _beginGesture();
                          }
                        },
                        onPointerPanZoomStart: (_) => _beginGesture(),
                        child: NotificationListener<ScrollNotification>(
                          onNotification: _onScroll,
                          child: ListWheelScrollView.useDelegate(
                            key: ValueKey('sked-time-${widget.id}-wheel'),
                            controller: _scroll,
                            physics: const FixedExtentScrollPhysics(
                              parent: ClampingScrollPhysics(),
                            ),
                            itemExtent: widget.rowHeight,
                            diameterRatio: 100,
                            perspective: .001,
                            useMagnifier: true,
                            overAndUnderCenterOpacity: .65,
                            scrollBehavior: behavior.copyWith(
                              scrollbars: false,
                              overscroll: false,
                              dragDevices: {
                                ...behavior.dragDevices,
                                PointerDeviceKind.mouse,
                              },
                            ),
                            childDelegate: ListWheelChildLoopingListDelegate(
                              children: [
                                for (
                                  var value = widget.first;
                                  value <= widget.last;
                                  value++
                                )
                                  GestureDetector(
                                    key: ValueKey(
                                      'sked-time-${widget.id}-$value',
                                    ),
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => _select(value),
                                    child: Center(
                                      child: Text(
                                        _two(value),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              color: colors.onSurface,
                                              fontWeight: FontWeight.w600,
                                              fontFeatures: const [
                                                FontFeature.tabularFigures(),
                                              ],
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
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
