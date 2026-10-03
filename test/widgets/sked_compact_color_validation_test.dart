import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/widgets/sked_compact_color_picker.dart';
import 'package:sked/widgets/sked_task_dialog.dart';

void main() {
  testWidgets('preset repairs invalid Hex and restores valid callback', (
    t,
  ) async {
    var value = 0xff123456;
    var valid = true;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SkedTaskDialogScope(
              child: SkedCompactColorPicker(
                colorValue: value,
                invalidHexMessage: 'Invalid color',
                onValidityChanged: (v) => setState(() => valid = v),
                onColorChanged: (v) => setState(() => value = v),
              ),
            ),
          ),
        ),
      ),
    );
    final field = find.byKey(const ValueKey('compact-color-picker-hex-field'));
    await t.enterText(field, '#12ZZZZ');
    await t.pump();
    expect(valid, isFalse);
    await t.tap(find.byTooltip('#6750A4'));
    await t.pump();
    expect(valid, isTrue);
    expect(t.widget<TextField>(field).decoration!.errorText, isNull);
    expect(value, 0xff6750a4);
    expect(t.widget<TextField>(field).controller!.text, '#6750A4');
  });
}
