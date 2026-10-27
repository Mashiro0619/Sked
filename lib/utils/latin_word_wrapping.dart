import 'package:flutter/painting.dart';

final _latinWord = RegExp(
  r"\p{Script=Latin}[\p{Script=Latin}\p{Mark}\p{Number}]*(?:['’][\p{Script=Latin}\p{Mark}\p{Number}]+)*",
  unicode: true,
);

/// Flutter wraps a word at spaces when it fits, but can split an oversized word
/// across several lines. Keep preceding complete lines and ellipsize that word
/// on its first line instead. The displayed Text and its semantic label retain
/// the original string; CJK and explicit line breaks keep their normal layout.
void limitOversizedLatinWords(TextPainter painter, String value, double width) {
  if (width <= 0 || !width.isFinite) return;
  for (final word in _latinWord.allMatches(value)) {
    final position = TextPosition(offset: word.start);
    final line = painter.getLineBoundary(position);
    if (line.end <= word.start || line.end >= word.end) continue;
    final boxes = painter.getBoxesForSelection(
      TextSelection(baseOffset: word.start, extentOffset: word.end),
    );
    if (boxes.isEmpty) return;
    final wordCenterY = (boxes.first.top + boxes.first.bottom) / 2;
    final lineMetrics = painter.computeLineMetrics();
    final firstLine = lineMetrics.firstWhere(
      (line) => wordCenterY < line.baseline + line.descent,
      orElse: () => lineMetrics.last,
    );
    painter
      ..maxLines = firstLine.lineNumber + 1
      ..ellipsis = '…'
      ..layout(maxWidth: width);
    return;
  }
}
