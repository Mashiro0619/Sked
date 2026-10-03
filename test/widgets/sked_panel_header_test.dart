import 'package:sked/widgets/sked_floating_surface.dart';
import 'package:sked/widgets/sked_task_dialog.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/widgets/sked_panel_header.dart';

void main() {
  testWidgets('task header preserves inherited picker drag handle', (t) async {
    var drags = 0;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              height: 300,
              child: SkedFloatingDragScope(
                onDrag: (_) => drags++,
                child: const SkedTaskDialogScope(
                  child: SkedTaskDialog(
                    title: Text('Picker'),
                    content: Text('Content'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final handle = find.byKey(const ValueKey('sked-picker-drag-handle'));
    expect(handle, findsOneWidget);
    await t.drag(handle, const Offset(40, 20));
    expect(drags, greaterThan(0));
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'header drag excludes action buttons; wrapped action and close remain interactive',
    (t) async {
      var drags = 0, actions = 0, closes = 0;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 340,
              child: SkedPanelHeader(
                title: const Text('Title'),
                onDrag: (_) => drags++,
                dragKey: const ValueKey('drag'),
                inlineAction: false,
                action: TextButton(
                  onPressed: () => actions++,
                  child: const Text('Create'),
                ),
                onClose: () => closes++,
                closeKey: const ValueKey('close'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Create'));
      await t.tap(find.byKey(const ValueKey('close')));
      expect(actions, 1);
      expect(closes, 1);
      expect(drags, 0);
      await t.drag(find.byKey(const ValueKey('drag')), const Offset(30, 20));
      expect(drags, greaterThan(0));
    },
  );
  testWidgets('preview header has no close or drag behavior', (t) async {
    await t.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SkedPanelHeader(title: Text('Preview'), showClose: false),
        ),
      ),
    );
    expect(find.byType(IconButton), findsNothing);
    expect(t.takeException(), isNull);
  });
}
