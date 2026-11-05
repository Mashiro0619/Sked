import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/ui/agent_credential_input.dart';
import 'package:sked/agent/provider/provider.dart';

import 'agent_ui_test_support.dart';

void main() {
  testWidgets(
    'cancellation closes only its credential dialog beneath a newer route',
    (tester) async {
      addTearDown(tester.view.reset);
      final cancellation = ProviderCancellationToken();
      late BuildContext host;
      String? result;
      var settled = false;
      await mountAgentUi(
        tester,
        Builder(
          builder: (context) {
            host = context;
            return TextButton(
              onPressed: () async {
                result = await requestAgentCredential(
                  context,
                  Uri.parse('https://model.example/v1'),
                  cancellation: cancellation,
                );
                settled = true;
              },
              child: const Text('Enter key'),
            );
          },
        ),
      );
      await tester.tap(find.text('Enter key'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('agent-credential-input')),
        'cancelled-key',
      );
      final newer = showDialog<void>(
        context: host,
        builder: (_) => const AlertDialog(title: Text('Newer dialog')),
      );
      await tester.pumpAndSettle();
      cancellation.cancel();
      await tester.pumpAndSettle();
      expect(settled, isTrue);
      expect(result, isNull);
      expect(
        find.byKey(
          const ValueKey('agent-credential-input'),
          skipOffstage: false,
        ),
        findsNothing,
      );
      expect(find.text('Newer dialog'), findsOneWidget);
      Navigator.of(host, rootNavigator: true).pop();
      await tester.pumpAndSettle();
      await newer;
      expect(find.text('Enter key'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('already cancelled input never opens a route', (tester) async {
    final cancellation = ProviderCancellationToken()..cancel();
    late BuildContext host;
    await mountAgentUi(
      tester,
      Builder(
        builder: (context) {
          host = context;
          return const Text('Host');
        },
      ),
    );
    expect(
      await requestAgentCredential(
        host,
        Uri.parse('https://model.example/v1'),
        cancellation: cancellation,
      ),
      isNull,
    );
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

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
