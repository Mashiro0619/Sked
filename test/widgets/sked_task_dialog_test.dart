import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/widgets/sked_task_dialog.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'without floating scope original AlertDialog defaults and geometry are retained at $scale',
      (t) async {
        Widget host(Widget dialog) => MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(body: dialog),
        );
        const title = Text('Original title');
        const content = Text('Original body');
        final actions = [
          TextButton(onPressed: () {}, child: const Text('Cancel')),
        ];
        await t.pumpWidget(
          host(AlertDialog(title: title, content: content, actions: actions)),
        );
        await t.pumpAndSettle();
        final original = t.getRect(find.text('Original body'));
        await t.pumpWidget(
          host(
            SkedTaskDialog(title: title, content: content, actions: actions),
          ),
        );
        await t.pumpAndSettle();
        final dialog = t.widget<AlertDialog>(find.byType(AlertDialog));
        expect(dialog.insetPadding, isNull);
        expect(dialog.contentPadding, isNull);
        expect(dialog.actionsPadding, isNull);
        expect(t.getRect(find.text('Original body')), original);
        expect(t.takeException(), isNull);
      },
      variant: TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.windows,
      }),
    );
  }
}
