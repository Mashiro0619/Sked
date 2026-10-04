import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/widgets/workspace_editor_form.dart';

void main() {
  for (final direction in TextDirection.values) {
    testWidgets('form labels reflow without reparenting input: $direction', (
      t,
    ) async {
      final input = TextEditingController(text: 'Unchanged draft');
      addTearDown(input.dispose);
      double width = 560;
      late StateSetter resize;
      await t.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: direction,
            child: StatefulBuilder(
              builder: (context, setState) {
                resize = setState;
                return Scaffold(
                  body: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: width,
                      child: WorkspaceEditorField(
                        label: 'Long localized field label',
                        child: TextField(
                          controller: input,
                          decoration: workspaceEditorInputDecoration(
                            context,
                            'Long localized field label',
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
      );
      final field = find.byType(TextField);
      final element = t.element(field);
      await t.tap(field);
      await t.pump();
      input.selection = const TextSelection(baseOffset: 1, extentOffset: 8);
      final focus = FocusManager.instance.primaryFocus;
      resize(() => width = 240);
      await t.pumpAndSettle();
      expect(t.element(field), same(element));
      expect(FocusManager.instance.primaryFocus, same(focus));
      expect(input.selection.extentOffset, 8);
      expect(
        t.getTopLeft(field).dy,
        greaterThan(
          t.getTopLeft(find.text('Long localized field label').first).dy,
        ),
      );
      resize(() => width = 560);
      await t.pumpAndSettle();
      expect(t.element(field), same(element));
      expect(input.text, 'Unchanged draft');
      expect(t.takeException(), isNull);
    });
  }
  testWidgets(
    'value controls retain a 36dp target and keyboard activation in compact theme',
    (t) async {
      var calls = 0;
      await t.pumpWidget(
        MaterialApp(
          theme: ThemeData(visualDensity: VisualDensity.compact),
          home: Scaffold(
            body: SizedBox(
              width: 280,
              child: WorkspaceEditorValue(
                label: 'Repeat',
                value: 'Every week',
                onPressed: () => calls++,
              ),
            ),
          ),
        ),
      );
      final button = find.byType(OutlinedButton);
      expect(t.getSize(button).height, greaterThanOrEqualTo(36));
      await t.tap(button);
      expect(calls, 1);
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.space);
      await t.pump();
      expect(calls, 2);
      final semantics = t.ensureSemantics();
      expect(
        t.getSemantics(find.byType(WorkspaceEditorValue)).label,
        contains('Repeat'),
      );
      semantics.dispose();
    },
  );
}
