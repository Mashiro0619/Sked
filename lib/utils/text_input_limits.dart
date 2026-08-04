import 'package:flutter/services.dart';

String truncateUtf16CodeUnits(String value, int maxCodeUnits) {
  if (maxCodeUnits < 0) {
    throw RangeError.range(maxCodeUnits, 0, null, 'maxCodeUnits');
  }
  if (value.length <= maxCodeUnits) {
    return value;
  }

  var end = maxCodeUnits;
  if (end > 0 &&
      end < value.length &&
      _isHighSurrogate(value.codeUnitAt(end - 1)) &&
      _isLowSurrogate(value.codeUnitAt(end))) {
    end -= 1;
  }
  return value.substring(0, end);
}

class Utf16CodeUnitLimitingTextInputFormatter extends TextInputFormatter {
  const Utf16CodeUnitLimitingTextInputFormatter(this.maxCodeUnits)
    : assert(maxCodeUnits >= 0);

  final int maxCodeUnits;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final boundedText = truncateUtf16CodeUnits(newValue.text, maxCodeUnits);
    if (boundedText.length == newValue.text.length) {
      return newValue;
    }

    return TextEditingValue(
      text: boundedText,
      selection: _boundedSelection(newValue.selection, boundedText.length),
      composing: _boundedComposing(newValue.composing, boundedText.length),
    );
  }
}

TextSelection _boundedSelection(TextSelection selection, int textLength) {
  if (!selection.isValid) {
    return const TextSelection.collapsed(offset: -1);
  }
  return TextSelection(
    baseOffset: _boundedOffset(selection.baseOffset, textLength),
    extentOffset: _boundedOffset(selection.extentOffset, textLength),
    affinity: selection.affinity,
    isDirectional: selection.isDirectional,
  );
}

TextRange _boundedComposing(TextRange composing, int textLength) {
  if (!composing.isValid || composing.isCollapsed) {
    return TextRange.empty;
  }
  final start = _boundedOffset(composing.start, textLength);
  final end = _boundedOffset(composing.end, textLength);
  return start < end ? TextRange(start: start, end: end) : TextRange.empty;
}

int _boundedOffset(int offset, int textLength) {
  if (offset < 0) return 0;
  if (offset > textLength) return textLength;
  return offset;
}

bool _isHighSurrogate(int codeUnit) => codeUnit >= 0xd800 && codeUnit <= 0xdbff;

bool _isLowSurrogate(int codeUnit) => codeUnit >= 0xdc00 && codeUnit <= 0xdfff;
