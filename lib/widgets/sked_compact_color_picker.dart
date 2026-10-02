import 'package:material_ui/material_ui.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import 'sked_task_dialog.dart';

const skedColorPresets = <int>[
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
  final Object? resetToken;

  @override
  State<SkedCompactColorPicker> createState() => _SkedCompactColorPickerState();
}

class _SkedCompactColorPickerState extends State<SkedCompactColorPicker> {
  static const double _maxPickerWidth = 300;
  static const double _minPickerWidth = 160;

  late final TextEditingController _hexController;
  int? _syncedHexValue;
  bool _valid = true;

  @override
  void initState() {
    super.initState();
    _hexController = TextEditingController();
    _syncHexField(widget.colorValue);
  }

  @override
  void didUpdateWidget(covariant SkedCompactColorPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.colorValue != _syncedHexValue ||
        widget.resetToken != oldWidget.resetToken) {
      _syncHexField(widget.colorValue);
    }
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  void _updateColor(Color color) {
    final colorValue = color.toARGB32();
    _syncHexField(colorValue);
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
    final hex = widget.invalidHexMessage == null
        ? value.replaceAll('#', '').trim()
        : value.trim().replaceFirst(RegExp(r'^#'), '');
    final valid = RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(hex);
    if (_valid != valid) setState(() => _valid = valid);
    widget.onValidityChanged?.call(valid);
    if (!valid) return;
    final colorValue = 0xFF000000 | int.parse(hex, radix: 16);
    _syncedHexValue = colorValue;
    widget.onColorChanged(colorValue);
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(widget.colorValue);
    final hsvColor = HSVColor.fromColor(color);
    final mediaQuery = MediaQuery.of(context);
    final availableWidth =
        mediaQuery.size.width - mediaQuery.viewPadding.horizontal - 128;
    final pickerWidth = availableWidth.clamp(_minPickerWidth, _maxPickerWidth);
    final showHexLabel = pickerWidth >= 220;
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
                    width: 36,
                    height: 36,
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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: ColorPickerArea(
                hsvColor,
                (updatedHsvColor) => _updateColor(updatedHsvColor.toColor()),
                PaletteType.hsvWithHue,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: pickerWidth,
            height: 40,
            child: ColorPickerSlider(
              TrackType.hue,
              hsvColor,
              (updatedHsvColor) => _updateColor(updatedHsvColor.toColor()),
              displayThumbColor: true,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                if (showHexLabel) ...[
                  Text('Hex', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: TextField(
                    key: const ValueKey('compact-color-picker-hex-field'),
                    controller: _hexController,
                    maxLength: 7,
                    decoration: InputDecoration(
                      errorText: _valid ? null : widget.invalidHexMessage,
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
