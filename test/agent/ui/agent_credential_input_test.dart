import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/ui/agent_credential_input.dart';

import 'agent_ui_test_support.dart';

void main() {
  testWidgets(
    'credential dialog hides input and destination secrets and returns only explicit entry',
    (tester) async {
      addTearDown(tester.view.reset);
      String? result;
      await mountAgentUi(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await requestAgentCredential(
                context,
                Uri.parse(
                  'https://user:password@model.example/v1?token=private#secret',
                ),
              );
            },
            child: const Text('Enter key'),
          ),
        ),
        size: const Size(390, 844),
        scale: 2,
      );
      await tester.tap(find.text('Enter key'));
      await tester.pumpAndSettle();
      expect(find.text('https://model.example/v1'), findsOneWidget);
      expect(find.textContaining('password'), findsNothing);
      final field = find.byKey(const ValueKey('agent-credential-input'));
      expect(tester.widget<TextField>(field).obscureText, isTrue);
      expect(tester.widget<TextField>(field).enableSuggestions, isFalse);
      expect(tester.widget<TextField>(field).autocorrect, isFalse);
      await tester.enterText(field, 'fixture-key');
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(const ValueKey('agent-credential-save')),
      );
      await tester.tap(find.byKey(const ValueKey('agent-credential-save')));
      await tester.pumpAndSettle();
      expect(result, 'fixture-key');
      expect(field, findsNothing);
      await tester.tap(find.text('Enter key'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
      await tester.enterText(field, 'cancelled-key');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}
