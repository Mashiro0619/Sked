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
                    width: 460 * scale,
                    child: ValueListenableBuilder<String>(
                      valueListenable: selected,
                      builder: (context, value, _) => WorkspaceEditorFieldsRow(
                        flexes: const [1, 0],
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
          expect(tester.getSize(fields.first).width, 460 * scale);
          expect(tester.getSize(fields.last).width, lessThan(460 * scale));
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

  testWidgets('a long upper label does not widen its short neighbor', (
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
    expect(tester.getRect(fields.last).top, tester.getRect(fields.first).top);
    expect(tester.getSize(fields.first).width, greaterThan(300));
    expect(tester.getSize(fields.last).width, 120);
    expect(tester.takeException(), isNull);
  });

  for (final direction in TextDirection.values) {
    testWidgets(
      'compact fields keep individual widths through wrapping: $direction',
      (tester) async {
        final width = ValueNotifier(440.0);
        addTearDown(width.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Directionality(
              textDirection: direction,
              child: Scaffold(
                body: ValueListenableBuilder<double>(
                  valueListenable: width,
                  builder: (context, width, _) => SizedBox(
                    width: width,
                    child: const WorkspaceEditorFieldsRow(
                      minimumChildWidths: [96, 160],
                      children: [
                        SizedBox(key: ValueKey('short'), height: 40),
                        SizedBox(key: ValueKey('date'), height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        for (final available in [440.0, 680.0, 260.0, 280.0]) {
          width.value = available;
          await tester.pumpAndSettle();
          final short = tester.getRect(find.byKey(const ValueKey('short')));
          final date = tester.getRect(find.byKey(const ValueKey('date')));
          expect(short.width, 96);
          expect(date.width, 160);
          if (available < 268) {
            expect(date.top - short.bottom, 12);
            expect(
              direction == TextDirection.ltr ? short.left : short.right,
              direction == TextDirection.ltr ? date.left : date.right,
            );
          } else {
            expect(short.top, date.top);
            expect(
              direction == TextDirection.ltr
                  ? date.left - short.right
                  : short.left - date.right,
              12,
            );
          }
          expect(tester.takeException(), isNull);
        }
      },
    );
  }

  testWidgets('only flexible inputs use the remaining row width', (
    tester,
  ) async {
    final width = ValueNotifier(440.0);
    addTearDown(width.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<double>(
            valueListenable: width,
            builder: (context, width, _) => SizedBox(
              width: width,
              child: const WorkspaceEditorFieldsRow(
                minimumChildWidths: [180, 96],
                flexes: [1, 0],
                children: [
                  SizedBox(key: ValueKey('input'), height: 40),
                  SizedBox(key: ValueKey('number'), height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    for (final available in [440.0, 680.0, 260.0]) {
      width.value = available;
      await tester.pumpAndSettle();
      final input = tester.getRect(find.byKey(const ValueKey('input')));
      final number = tester.getRect(find.byKey(const ValueKey('number')));
      expect(number.width, 96);
      if (available < 288) {
        expect(input.width, available);
        expect(number.top - input.bottom, 12);
      } else {
        expect(input.width, available - 108);
        expect(number.top, input.top);
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('measured baselines scale without widening other fields', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: SizedBox(
              width: 680,
              child: Builder(
                builder: (context) => WorkspaceEditorFieldsRow(
                  minimumChildWidths: [
                    workspaceEditorMinimumFieldWidth(
                      context,
                      label: 'No.',
                      value: '18',
                      minimumWidth: 96,
                    ),
                    workspaceEditorMinimumFieldWidth(
                      context,
                      label: 'Day',
                      value: 'Monday',
                    ),
                  ],
                  children: const [
                    SizedBox(key: ValueKey('number'), height: 40),
                    SizedBox(key: ValueKey('day'), height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(const ValueKey('number'))).width, 192);
    expect(tester.getSize(find.byKey(const ValueKey('day'))).width, 240);
    expect(tester.takeException(), isNull);
  });
}
