import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/widgets/update_prompt_scope.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'current blockers, foreground and idempotent removal control eligibility',
    () async {
      var foreground = true;
      var blocked = true;
      final controller = UpdatePromptController(isForeground: () => foreground);
      final remove = controller.register(() => blocked);
      expect(controller.canPrompt, isFalse);
      blocked = false;
      expect(controller.canPrompt, isTrue);
      foreground = false;
      expect(controller.canPrompt, isFalse);
      foreground = true;
      blocked = true;
      remove();
      remove();
      expect(controller.canPrompt, isTrue);
      var calls = 0;
      await controller.startOnce(() async {
        calls++;
      });
      await controller.startOnce(() async {
        calls++;
      });
      expect(calls, 1);
      controller.dispose();
      expect(controller.canPrompt, isFalse);
    },
  );

  testWidgets('root routes block through their exit transition', (
    tester,
  ) async {
    final controller = UpdatePromptController(isForeground: () => true);
    addTearDown(controller.dispose);
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [controller.observer],
        home: Builder(
          builder: (c) {
            context = c;
            return const Scaffold();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.canPrompt, isTrue);
    unawaited(
      showDialog<void>(
        context: context,
        builder: (_) => const AlertDialog(title: Text('Task')),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.canPrompt, isFalse);
    Navigator.of(context).pop();
    expect(controller.canPrompt, isFalse);
    await tester.pumpAndSettle();
    expect(controller.canPrompt, isTrue);
  });

  testWidgets(
    'a non-route overlay blocker follows current state and unregisters on unmount',
    (tester) async {
      final controller = UpdatePromptController(isForeground: () => true);
      addTearDown(controller.dispose);
      var visible = true;
      await tester.pumpWidget(
        UpdatePromptScope(
          controller: controller,
          child: UpdatePromptBlocker(
            blocked: () => visible,
            child: const SizedBox(),
          ),
        ),
      );
      expect(controller.canPrompt, isFalse);
      visible = false;
      expect(controller.canPrompt, isTrue);
      visible = true;
      await tester.pumpWidget(const SizedBox());
      expect(controller.canPrompt, isTrue);
    },
  );
}
