import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/widgets/workspace_editor_form.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.windows]) {
    testWidgets(
      'shared editor inputs retain draft, selection and validation while reflowing',
      (tester) async {
        final name = TextEditingController();
        final weeks = TextEditingController(text: '18');
        final focus = FocusNode();
        final form = GlobalKey<FormState>();
        addTearDown(name.dispose);
        addTearDown(weeks.dispose);
        addTearDown(focus.dispose);
        var width = 560.0;
        var scale = 1.0;
        late StateSetter changeLayout;
        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                changeLayout = setState;
                return MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: Scaffold(
                    body: Align(
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        width: width,
                        child: Form(
                          key: form,
                          child: SkedEditorFormRow(
                            flexes: const [2, 1],
                            minimumChildWidths: [180 * scale, 120 * scale],
                            children: [
                              SkedEditorTextField(
                                label: 'Name',
                                controller: name,
                                focusNode: focus,
                                controlKey: const ValueKey('editor-name'),
                              ),
                              SkedEditorTextField(
                                label: 'Weeks',
                                controller: weeks,
                                controlKey: const ValueKey('editor-weeks'),
                                formField: true,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                validator: (value) =>
                                    (int.tryParse(value ?? '') ?? 0) > 0
                                    ? null
                                    : 'Enter a positive number',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        final input = find.byKey(const ValueKey('editor-name'));
        await tester.enterText(input, 'Retained course draft');
        name.selection = const TextSelection(baseOffset: 1, extentOffset: 7);
        final element = tester.element(input);
        for (final layout in [(300.0, 1.0), (560.0, 2.0), (560.0, 1.0)]) {
          changeLayout(() {
            width = layout.$1;
            scale = layout.$2;
          });
          await tester.pumpAndSettle();
          expect(tester.element(input), same(element));
          expect(focus.hasFocus, isTrue);
          expect(name.text, 'Retained course draft');
          expect(
            name.selection,
            const TextSelection(baseOffset: 1, extentOffset: 7),
          );
        }
        final number = find.byKey(const ValueKey('editor-weeks'));
        await tester.enterText(number, '12abc');
        expect(weeks.text, '12');
        expect(form.currentState!.validate(), isTrue);
        await tester.enterText(number, '0');
        expect(form.currentState!.validate(), isFalse);
        await tester.pumpAndSettle();
        expect(find.text('Enter a positive number'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(platform),
    );

    testWidgets(
      'shared picker field keeps an anchored action and disables activation',
      (tester) async {
        var enabled = true;
        var calls = 0;
        BuildContext? anchor;
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return SizedBox(
                    width: 320,
                    child: SkedEditorValueField(
                      label: 'Start date',
                      value: 'October 12',
                      icon: Icons.calendar_month_outlined,
                      enabled: enabled,
                      onPressed: (context) {
                        calls++;
                        anchor = context;
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.tap(find.text('October 12'));
        await tester.pumpAndSettle();
        expect(calls, 1);
        expect(anchor?.mounted, isTrue);
        final control = platform == TargetPlatform.windows
            ? find.byType(TextButton)
            : find.byType(SkedEditorValueField);
        expect(
          tester.getSize(control).height,
          greaterThanOrEqualTo(platform == TargetPlatform.windows ? 40 : 48),
        );
        update(() => enabled = false);
        await tester.pumpAndSettle();
        await tester.tap(find.text('October 12'));
        await tester.pumpAndSettle();
        expect(calls, 1);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(platform),
    );
  }
}
