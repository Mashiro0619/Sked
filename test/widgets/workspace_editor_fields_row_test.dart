import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/widgets/workspace_editor.dart';
import 'package:sked/widgets/workspace_editor_form.dart';

void main() {
  for (final direction in TextDirection.values) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets(
        'natural option width reflows without resetting input or trigger: $direction/$scale',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(1600, 1000);
          addTearDown(tester.view.reset);
          final controller = TextEditingController();
          final selected = ValueNotifier('Weekly');
          final triggerKey = GlobalKey();
          addTearDown(controller.dispose);
          addTearDown(selected.dispose);
          const longValue = 'Every Monday through December';
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: Directionality(textDirection: direction, child: child!),
              ),
              home: Scaffold(
                body: Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: 600 * scale,
                    child: ValueListenableBuilder<String>(
                      valueListenable: selected,
                      builder: (context, value, _) => WorkspaceEditorFieldsRow(
                        minimumChildWidths: [
                          workspaceEditorMinimumFieldWidth(
                            context,
                            label: 'Teacher',
                          ),
                          workspaceEditorMinimumFieldWidth(
                            context,
                            label: 'Repeat',
                            value: value,
                          ),
                        ],
                        children: [
                          WorkspaceEditorField(
                            label: 'Teacher',
                            child: TextField(
                              controller: controller,
                              style: workspaceEditorContentStyle(context),
                              decoration: workspaceEditorInputDecoration(
                                context,
                                'Teacher',
                              ),
                            ),
                          ),
                          WorkspaceEditorField(
                            label: 'Repeat',
                            child: WorkspaceEditorValue(
                              key: triggerKey,
                              label: 'Repeat',
                              value: value,
                              onPressed: () {},
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final fields = find.byType(WorkspaceEditorField);
          final input = find.byType(TextField);
          expect(
            tester.getRect(fields.first).top,
            tester.getRect(fields.last).top,
          );
          await tester.enterText(
            input,
            'This deliberately long free-text draft keeps its original column',
          );
          controller.selection = const TextSelection(
            baseOffset: 4,
            extentOffset: 12,
          );
          final element = tester.element(input);
          final triggerElement = triggerKey.currentContext;
          final focus = FocusManager.instance.primaryFocus;
          await tester.pumpAndSettle();
          expect(
            tester.getRect(fields.first).top,
            tester.getRect(fields.last).top,
            reason: 'Free typing must not make the form change columns.',
          );

          selected.value = longValue;
          await tester.pumpAndSettle();
          expect(
            tester.getRect(fields.last).top -
                tester.getRect(fields.first).bottom,
            12,
          );
          expect(tester.getSize(fields.first).width, 600 * scale);
          final text = find.descendant(
            of: find.byKey(triggerKey),
            matching: find.text(longValue),
          );
          final paragraph = tester.renderObject<RenderBox>(text);
          expect(
            paragraph.size.width,
            greaterThanOrEqualTo(
              paragraph.getMaxIntrinsicWidth(double.infinity),
            ),
            reason:
                'The selected value fits naturally after taking a full row.',
          );
          expect(tester.element(input), same(element));
          expect(triggerKey.currentContext, same(triggerElement));
          expect(FocusManager.instance.primaryFocus, same(focus));
          expect(
            controller.selection,
            const TextSelection(baseOffset: 4, extentOffset: 12),
          );

          selected.value = 'Weekly';
          await tester.pumpAndSettle();
          expect(
            tester.getRect(fields.first).top,
            tester.getRect(fields.last).top,
          );
          expect(tester.element(input), same(element));
          expect(triggerKey.currentContext, same(triggerElement));
          expect(FocusManager.instance.primaryFocus, same(focus));
          expect(controller.selection.extentOffset, 12);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        },
      );
    }
  }

  testWidgets('a long upper label also requires a full-width row', (
    tester,
  ) async {
    const longLabel = 'Long localized semester information';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 600,
            child: Builder(
              builder: (context) => WorkspaceEditorFieldsRow(
                minimumChildWidths: [
                  workspaceEditorMinimumFieldWidth(context, label: longLabel),
                  workspaceEditorMinimumFieldWidth(context, label: 'Date'),
                ],
                children: const [
                  WorkspaceEditorField(
                    label: longLabel,
                    child: SizedBox(height: 40),
                  ),
                  WorkspaceEditorField(
                    label: 'Date',
                    child: SizedBox(height: 40),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final fields = find.byType(WorkspaceEditorField);
    expect(
      tester.getRect(fields.last).top - tester.getRect(fields.first).bottom,
      12,
    );
    expect(tester.getSize(fields.first).width, 600);
    expect(tester.takeException(), isNull);
  });
}
