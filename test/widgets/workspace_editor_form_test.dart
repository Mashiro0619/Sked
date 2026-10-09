import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/widgets/sked_dropdown_menu.dart';
import 'package:sked/widgets/workspace_editor.dart';
import 'package:sked/widgets/workspace_editor_form.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'editor styling is theme-aware and leaves the surrounding theme unchanged: $brightness',
      (t) async {
        final theme = ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.teal,
            brightness: brightness,
          ),
        );
        late BuildContext formContext;
        await t.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  formContext = context;
                  return const WorkspaceEditorDropdownStyle(child: SizedBox());
                },
              ),
            ),
          ),
        );
        final basic = workspaceEditorInputDecoration(formContext, 'Notes');
        expect(basic.labelText, isNull);
        expect(basic.hintText, isNull);
        expect(
          basic.enabledBorder!.borderSide,
          BorderSide(color: theme.colorScheme.outlineVariant),
        );
        expect(
          basic.focusedBorder!.borderSide.color,
          theme.colorScheme.primary,
        );
        expect(basic.errorBorder!.borderSide.color, theme.colorScheme.error);
        expect(
          basic.fillColor,
          theme.colorScheme.surfaceContainerHighest.withValues(alpha: .35),
        );
        final headline = workspaceEditorInputDecoration(
          formContext,
          'Title',
          headline: true,
        );
        expect(headline.hintText, 'Title');
        expect(headline.hintStyle!.fontSize, 22);
        expect(headline.filled, isFalse);
        expect(headline.enabledBorder!.borderSide, BorderSide.none);
        expect(workspaceEditorLabelStyle(formContext).fontSize, 12);
        expect(workspaceEditorContentStyle(formContext).fontSize, 14);
        expect(
          Theme.of(formContext).inputDecorationTheme,
          theme.inputDecorationTheme,
        );
      },
    );
  }

  for (final direction in TextDirection.values) {
    testWidgets(
      'upper labels retain input identity while resizing: $direction',
      (t) async {
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
        final label = find.text('Long localized field label').first;
        expect(t.getRect(label).bottom + 6, t.getRect(field).top);
        expect(t.getRect(label).left, t.getRect(field).left);
        expect(t.getRect(label).right, t.getRect(field).right);
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
      },
    );
  }

  testWidgets(
    'text, choice, and dropdown controls share a visible 40dp height',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(visualDensity: VisualDensity.compact),
          home: Scaffold(
            body: Builder(
              builder: (context) => SizedBox(
                width: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      style: workspaceEditorContentStyle(context),
                      decoration: workspaceEditorInputDecoration(
                        context,
                        'Name',
                      ),
                    ),
                    WorkspaceEditorValue(
                      label: 'Day',
                      value: 'Monday',
                      onPressed: () {},
                    ),
                    const WorkspaceEditorDropdownStyle(
                      child: SkedDropdownMenu<String>(
                        initialSelection: 'default',
                        dropdownMenuEntries: [
                          DropdownMenuEntry(value: 'default', label: 'Default'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      final decorators = find.byType(InputDecorator);
      expect(decorators, findsNWidgets(2));
      for (final decorator in decorators.evaluate()) {
        expect(
          tester
              .getSize(
                find.byElementPredicate(
                  (element) => identical(element, decorator),
                ),
              )
              .height,
          40,
        );
      }
      expect(tester.getSize(find.byType(TextButton)).height, 40);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'value controls retain a 40dp target and keyboard activation in compact theme',
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
      final button = find.byType(TextButton);
      expect(t.getSize(button).height, greaterThanOrEqualTo(40));
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

  for (final direction in TextDirection.values) {
    testWidgets('choice arrows align to the trailing edge: $direction', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: direction,
            child: Scaffold(
              body: SizedBox(
                width: 340,
                child: Column(
                  children: [
                    for (final value in ['Monday', 'Weeks 1–18'])
                      WorkspaceEditorValue(
                        label: 'Selection',
                        value: value,
                        onPressed: () {},
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      final arrows = find.byIcon(Icons.keyboard_arrow_down);
      expect(
        tester.getCenter(arrows.first).dx,
        tester.getCenter(arrows.last).dx,
      );
      final button = tester.getRect(find.byType(TextButton).first);
      final arrow = tester.getRect(arrows.first);
      expect(
        direction == TextDirection.ltr
            ? button.right - arrow.right
            : arrow.left - button.left,
        closeTo(10, .1),
      );
      final theme = Theme.of(tester.element(find.byType(TextButton).first));
      final style = tester
          .widget<TextButton>(find.byType(TextButton).first)
          .style!;
      expect(style.side!.resolve({})!.color, theme.colorScheme.outlineVariant);
      expect(
        style.side!.resolve({WidgetState.focused})!.color,
        theme.colorScheme.primary,
      );
      expect(style.textStyle!.resolve({})!.fontSize, 14);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'paired fields stack at the scaled minimum without losing focus',
    (tester) async {
      final controller = TextEditingController(text: 'A retained value');
      addTearDown(controller.dispose);
      final width = ValueNotifier(600.0);
      addTearDown(width.dispose);
      final scale = ValueNotifier(1.0);
      addTearDown(scale.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<double>(
              valueListenable: scale,
              builder: (context, factor, _) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(factor)),
                child: ValueListenableBuilder<double>(
                  valueListenable: width,
                  builder: (context, width, _) => SizedBox(
                    width: width,
                    child: WorkspaceEditorFieldsRow(
                      children: [
                        WorkspaceEditorField(
                          label: 'First',
                          child: TextField(controller: controller),
                        ),
                        const WorkspaceEditorField(
                          label: 'Second',
                          child: SizedBox(height: 40),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final fields = find.byType(WorkspaceEditorField);
      final input = find.byType(TextField);
      final element = tester.element(input);
      await tester.tap(input);
      await tester.pump();
      controller.selection = const TextSelection(
        baseOffset: 2,
        extentOffset: 8,
      );
      final focus = FocusManager.instance.primaryFocus;
      expect(
        tester.getTopLeft(fields.first).dy,
        tester.getTopLeft(fields.last).dy,
      );
      for (final (nextWidth, nextScale) in [(480.0, 1.0), (600.0, 1.5)]) {
        width.value = nextWidth;
        scale.value = nextScale;
        await tester.pumpAndSettle();
        expect(
          tester.getRect(fields.last).top - tester.getRect(fields.first).bottom,
          12,
        );
        expect(tester.element(input), same(element));
        expect(FocusManager.instance.primaryFocus, same(focus));
        expect(controller.selection.extentOffset, 8);
      }
      expect(tester.takeException(), isNull);
    },
  );
}
