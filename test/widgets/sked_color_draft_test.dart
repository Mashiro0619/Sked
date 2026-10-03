import 'package:flutter_test/flutter_test.dart';
import 'package:sked/widgets/sked_color_draft.dart';

void main() {
  test('raw slots remain raw after preview and unchanged validation', () {
    final draft = SkedColorDraft(-101);
    expect(draft.preview((_) => 0xff123456), 0xff123456);
    expect(draft.value, -101);
    expect(draft.changed, isFalse);
    draft.setValidity(false);
    expect(draft.value, -101);
    draft.select(-102);
    expect(draft.validHex, isTrue);
    expect(draft.changed, isTrue);
    expect(draft.inputRevision, 1);
    draft.select(-101);
    expect(draft.changed, isFalse);
  });
  test('Hex parser rejects malformed input without truncation', () {
    for (final invalid in ['', '12345', '1234567', '##123456', '#GG1234']) {
      expect(SkedColorDraft.parseHex(invalid), isNull);
    }
    expect(SkedColorDraft.parseHex('  #AbC123  '), 0xffabc123);
    expect(SkedColorDraft.parseHex('abc123'), 0xffabc123);
  });
}
