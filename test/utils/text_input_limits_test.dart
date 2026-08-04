import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/utils/text_input_limits.dart';

void main() {
  test('UTF-16 truncation never splits a surrogate pair', () {
    const source = 'A\u{1f600}B';

    expect(truncateUtf16CodeUnits(source, 3), 'A\u{1f600}');
    expect(truncateUtf16CodeUnits(source, 2), 'A');
  });

  test('formatter bounds combining input by code units and clamps ranges', () {
    const formatter = Utf16CodeUnitLimitingTextInputFormatter(4);
    const input = TextEditingValue(
      text: 'a\u0301\u0301\u0301\u0301',
      selection: TextSelection.collapsed(offset: 5),
      composing: TextRange(start: 0, end: 5),
    );

    final result = formatter.formatEditUpdate(TextEditingValue.empty, input);

    expect(result.text, 'a\u0301\u0301\u0301');
    expect(result.text.length, 4);
    expect(result.selection, const TextSelection.collapsed(offset: 4));
    expect(result.composing, const TextRange(start: 0, end: 4));
  });
}
