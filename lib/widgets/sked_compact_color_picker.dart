import 'sked_color_draft.dart';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../l10n/app_localizations.dart';
import '../theme/sked_surface.dart';
import '../utils/constants.dart';
import 'sked_task_dialog.dart';
import 'workbench_chrome_metrics.dart';

enum _ColorAxis { hue, saturation, value }

const skedColorPresets = <int>[
  defaultThemeSeedColorValue,
  0xFF6750A4,
  0xFF5E35B1,
  0xFF3949AB,
  0xFF1E88E5,
  0xFF00897B,
  0xFF2E7D32,
  0xFF7CB342,
  0xFFF9A825,
  0xFFEF6C00,
  0xFFF4511E,
  0xFFD32F2F,
  0xFFD81B60,
  0xFFC2185B,
  0xFF6D4C41,
  0xFF455A64,
  0xFF546E7A,
];

String formatSkedColorHex(int colorValue) {
  final rgb = colorValue & 0x00FFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

class SkedCompactColorPicker extends StatefulWidget {
  const SkedCompactColorPicker({
    super.key,
    required this.colorValue,
    required this.onColorChanged,
    this.paletteValues = skedColorPresets,
    this.showPreview = true,
    this.onValidityChanged,
    this.invalidHexMessage,
    this.resetToken,
  });

  final int colorValue;
  final ValueChanged<int> onColorChanged;
  final List<int> paletteValues;
  final bool showPreview;
  final ValueChanged<bool>? onValidityChanged;
  final String? invalidHexMessage;

  /// Resynchronizes Hex text and validation, including an unchanged RGB value.
  /// HSV positions remain meaningful when gray/black cannot encode their hue.
  final Object? resetToken;

  @override
  State<SkedCompactColorPicker> createState() => _SkedCompactColorPickerState();
}

class _SkedCompactColorPickerState extends State<SkedCompactColorPicker> {
  static const double _maxPickerWidth = 300;
  static const double _minPickerWidth = 160;

  late final TextEditingController _hexController;
  late HSVColor _hsvColor;
  final _spectrumFocus = FocusNode(debugLabel: 'Color spectrum');
  final _hueFocus = FocusNode(debugLabel: 'Color hue');
  bool _spectrumFocused = false, _hueFocused = false;
  int? _syncedHexValue;
  bool _valid = true;

  @override
  void initState() {
    super.initState();
    _hexController = TextEditingController();
    _hsvColor = HSVColor.fromColor(Color(widget.colorValue));
    _syncHexField(widget.colorValue);
  }

  @override
  void didUpdateWidget(covariant SkedCompactColorPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.colorValue != _syncedHexValue ||
        widget.resetToken != oldWidget.resetToken) {
      // RGB cannot remember hue at zero saturation/value. Keep the user's HSV
      // position when a controlled parent echoes the color we just selected.
      if (widget.colorValue != _hsvColor.toColor().toARGB32()) {
        _hsvColor = HSVColor.fromColor(Color(widget.colorValue));
      }
      _syncHexField(widget.colorValue);
    }
  }

  @override
  void dispose() {
    _hexController.dispose();
    _spectrumFocus.dispose();
    _hueFocus.dispose();
    super.dispose();
  }

  void _updateColor(Color color) => _updateHsv(HSVColor.fromColor(color));

  void _updateHsv(HSVColor color) {
    final colorValue = color.toColor().toARGB32();
    setState(() {
      _hsvColor = color;
      _syncHexField(colorValue);
    });
    widget.onValidityChanged?.call(true);
    widget.onColorChanged(colorValue);
  }

  void _syncHexField(int colorValue) {
    _valid = true;
    final text = formatSkedColorHex(colorValue);
    _syncedHexValue = colorValue;
    if (_hexController.text == text) {
      return;
    }
    _hexController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _handleHexChanged(String value) {
    final colorValue = SkedColorDraft.parseHex(value);
    final valid = colorValue != null;
    if (_valid != valid) setState(() => _valid = valid);
    widget.onValidityChanged?.call(valid);
    if (colorValue == null) return;
    _hsvColor = HSVColor.fromColor(Color(colorValue));
    _syncedHexValue = colorValue;
    widget.onColorChanged(colorValue);
  }

  double _axisValue(_ColorAxis axis, HSVColor color) => switch (axis) {
    _ColorAxis.hue => color.hue,
    _ColorAxis.saturation => color.saturation * 100,
    _ColorAxis.value => color.value * 100,
  };

  String _axisText(_ColorAxis axis, HSVColor color) =>
      '${_axisValue(axis, color).round()}${axis == _ColorAxis.hue ? '°' : '%'}';

  HSVColor _steppedColor(_ColorAxis axis, int delta) => switch (axis) {
    _ColorAxis.hue => _hsvColor.withHue((_hsvColor.hue + delta) % 360),
    _ColorAxis.saturation => _hsvColor.withSaturation(
      ((_hsvColor.saturation * 100).round() + delta).clamp(0, 100) / 100,
    ),
    _ColorAxis.value => _hsvColor.withValue(
      ((_hsvColor.value * 100).round() + delta).clamp(0, 100) / 100,
    ),
  };

  void _adjust(_ColorAxis axis, int delta) {
    final focus = axis == _ColorAxis.hue ? _hueFocus : _spectrumFocus;
    // The owning dialog disables descendant focus during saves/retirement.
    // Semantic adjustments must obey that same live guard as keyboard input.
    if (!mounted || !focus.canRequestFocus) return;
    _updateHsv(_steppedColor(axis, delta));
  }

  KeyEventResult _spectrumKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final (axis, delta) = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowLeft => (_ColorAxis.saturation, -1),
      LogicalKeyboardKey.arrowRight => (_ColorAxis.saturation, 1),
      LogicalKeyboardKey.arrowDown => (_ColorAxis.value, -1),
      LogicalKeyboardKey.arrowUp => (_ColorAxis.value, 1),
      _ => (null, 0),
    };
    if (axis == null) return KeyEventResult.ignored;
    _adjust(axis, delta);
    return KeyEventResult.handled;
  }

  KeyEventResult _hueKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final delta = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowLeft || LogicalKeyboardKey.arrowDown => -1,
      LogicalKeyboardKey.arrowRight || LogicalKeyboardKey.arrowUp => 1,
      _ => 0,
    };
    if (delta == 0) return KeyEventResult.ignored;
    _adjust(_ColorAxis.hue, delta);
    return KeyEventResult.handled;
  }

  Widget _axisSemantics(
    BuildContext context,
    _ColorAxis axis, {
    required Widget child,
  }) {
    final l = AppLocalizations.of(context);
    final focus = axis == _ColorAxis.hue ? _hueFocus : _spectrumFocus;
    final enabled = focus.canRequestFocus;
    final current = _axisValue(axis, _hsvColor);
    final increase = enabled && (axis == _ColorAxis.hue || current < 100);
    final decrease = enabled && (axis == _ColorAxis.hue || current > 0);
    return Semantics(
      key: ValueKey('compact-color-picker-${axis.name}'),
      container: true,
      excludeSemantics: true,
      slider: true,
      enabled: enabled,
      focusable: enabled,
      focused: axis == _ColorAxis.hue && _hueFocused,
      label: switch (axis) {
        _ColorAxis.hue => l.colorPickerHue,
        _ColorAxis.saturation => l.colorPickerSaturation,
        _ColorAxis.value => l.colorPickerValue,
      },
      value: _axisText(axis, _hsvColor),
      increasedValue: increase ? _axisText(axis, _steppedColor(axis, 1)) : null,
      decreasedValue: decrease
          ? _axisText(axis, _steppedColor(axis, -1))
          : null,
      onIncrease: increase ? () => _adjust(axis, 1) : null,
      onDecrease: decrease ? () => _adjust(axis, -1) : null,
      onFocus: enabled ? focus.requestFocus : null,
      child: child,
    );
  }

  Widget _focusFrame(
    BuildContext context, {
    required bool focused,
    required BorderRadius radius,
    required Widget child,
  }) {
    final visible =
        focused &&
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    final gap = SkedSurface.colorOf(context).withValues(alpha: 1);
    final accent = skedReadableAccent(
      Theme.of(context).colorScheme,
      surface: gap,
    );
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: visible ? Border.all(color: accent, width: 2) : null,
      ),
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: radius,
          // An opaque inset gap separates the ring from every hue in the
          // spectrum without changing the canvas or its pointer geometry.
          border: visible ? Border.all(color: gap, width: 4) : null,
        ),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(widget.colorValue);
    final l = AppLocalizations.of(context);
    final desktop = WorkbenchChromeMetrics.of(context).desktop;
    final mediaQuery = MediaQuery.of(context);
    final availableWidth =
        mediaQuery.size.width - mediaQuery.viewPadding.horizontal - 128;
    final pickerWidth = availableWidth.clamp(_minPickerWidth, _maxPickerWidth);
    return SizedBox(
      width: pickerWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showPreview &&
              SkedTaskDialogScope.maybeOf(context) != null) ...[
            Row(
              children: [
                Container(width: 24, height: 24, color: color),
                const SizedBox(width: 8),
                Text(formatSkedColorHex(widget.colorValue)),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final value in widget.paletteValues)
                  SizedBox(
                    width: desktop ? 36 : 48,
                    height: desktop ? 36 : 48,
                    child: IconButton(
                      tooltip: formatSkedColorHex(value),
                      onPressed: () => _updateColor(Color(value)),
                      icon: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Color(value),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          SizedBox(
            width: pickerWidth,
            height: pickerWidth * 0.45,
            child: Semantics(
              key: const ValueKey('compact-color-picker-spectrum'),
              label: l.colorPickerSpectrum,
              hint: l.colorPickerSpectrumKeyboardHint,
              container: true,
              explicitChildNodes: true,
              enabled: _spectrumFocus.canRequestFocus,
              focusable: _spectrumFocus.canRequestFocus,
              focused: _spectrumFocused,
              onFocus: _spectrumFocus.canRequestFocus
                  ? _spectrumFocus.requestFocus
                  : null,
              child: Focus(
                key: const ValueKey('compact-color-picker-spectrum-focus'),
                focusNode: _spectrumFocus,
                includeSemantics: false,
                onKeyEvent: _spectrumKey,
                onFocusChange: (value) =>
                    setState(() => _spectrumFocused = value),
                child: Listener(
                  onPointerDown: (_) => _spectrumFocus.requestFocus(),
                  child: _focusFrame(
                    context,
                    focused: _spectrumFocused,
                    radius: BorderRadius.circular(2),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ExcludeSemantics(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: ColorPickerArea(
                              _hsvColor,
                              _updateHsv,
                              PaletteType.hsvWithHue,
                            ),
                          ),
                        ),
                        // Separate semantic targets describe each axis without
                        // adding duplicate visible sliders over the 2D canvas.
                        Row(
                          children: [
                            for (final axis in [
                              _ColorAxis.saturation,
                              _ColorAxis.value,
                            ])
                              Expanded(
                                child: _axisSemantics(
                                  context,
                                  axis,
                                  child: const SizedBox.expand(),
                                ),
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
          const SizedBox(height: 10),
          SizedBox(
            width: pickerWidth,
            height: desktop ? 40 : 48,
            child: _axisSemantics(
              context,
              _ColorAxis.hue,
              child: Focus(
                key: const ValueKey('compact-color-picker-hue-focus'),
                focusNode: _hueFocus,
                includeSemantics: false,
                onKeyEvent: _hueKey,
                onFocusChange: (value) => setState(() => _hueFocused = value),
                child: Listener(
                  onPointerDown: (_) => _hueFocus.requestFocus(),
                  child: _focusFrame(
                    context,
                    focused: _hueFocused,
                    radius: BorderRadius.circular(12),
                    child: ColorPickerSlider(
                      TrackType.hue,
                      _hsvColor,
                      _updateHsv,
                      displayThumbColor: true,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ExcludeSemantics(
                  child: Text(
                    l.colorPickerHex,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: 4),
                Semantics(
                  label: l.colorPickerHex,
                  child: TextField(
                    key: const ValueKey('compact-color-picker-hex-field'),
                    controller: _hexController,
                    // Do not truncate pasted invalid text into a valid color.
                    // Validation accepts surrounding whitespace without a length filter.
                    decoration: InputDecoration(
                      errorText: _valid ? null : widget.invalidHexMessage,
                      errorMaxLines: 8,
                      isDense: true,
                      counterText: '',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                    ),
                    onChanged: _handleHexChanged,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
