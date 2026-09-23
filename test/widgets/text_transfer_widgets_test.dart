import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/widgets/text_transfer_widgets.dart';

Future<void> _openTextImport(
  WidgetTester tester,
  TextImportSubmit onSubmit,
) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => TextImportPage(
                  title: 'Import text',
                  initialContent: '{"ok":true}',
                  onSubmit: onSubmit,
                ),
              ),
            ),
            child: const Text('Open import'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open import'));
  await tester.pumpAndSettle();
}

void main() {
  for (final succeeds in [false, true]) {
    testWidgets(
      'text import blocks both Back actions until submission settles: $succeeds',
      (tester) async {
        final pending = Completer<bool>();
        var submissions = 0;
        bool? feedbackContextMounted;
        addTearDown(() {
          if (!pending.isCompleted) pending.complete(false);
        });
        await _openTextImport(tester, (context, _) async {
          submissions++;
          final result = await pending.future;
          feedbackContextMounted = context.mounted;
          return result;
        });
        await tester.tap(find.widgetWithText(FilledButton, 'Import'));
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        await tester.tap(find.byType(BackButton));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(TextImportPage), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(TextImportPage), findsOneWidget);
        expect(submissions, 1);
        expect(feedbackContextMounted, isNull);
        pending.complete(succeeds);
        await tester.pumpAndSettle();
        expect(feedbackContextMounted, isTrue);
        if (succeeds) {
          expect(find.byType(TextImportPage), findsNothing);
          expect(find.text('Open import'), findsOneWidget);
        } else {
          expect(find.byType(TextImportPage), findsOneWidget);
          expect(
            tester.widget<TextField>(find.byType(TextField)).controller!.text,
            '{"ok":true}',
          );
          expect(
            tester
                .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Import'),
                )
                .onPressed,
            isNotNull,
          );
          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
          expect(find.byType(TextImportPage), findsNothing);
        }
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.windows,
      }),
    );
  }

  testWidgets('text import can still leave before submission', (tester) async {
    var submitted = false;
    await _openTextImport(tester, (_, _) async {
      submitted = true;
      return false;
    });
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(TextImportPage), findsNothing);
    expect(submitted, isFalse);
  });

  testWidgets('TextImportPage ignores rapid duplicate submit calls', (
    tester,
  ) async {
    final submitCompleter = Completer<bool>();
    var submitCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TextImportPage(
          title: 'Import text',
          initialContent: '{"ok":true}',
          onSubmit: (_, _) {
            submitCount += 1;
            return submitCompleter.future;
          },
        ),
      ),
    );

    final importButton = find.widgetWithText(FilledButton, 'Import');
    expect(importButton, findsOneWidget);

    await tester.tap(importButton);
    await tester.tap(importButton, warnIfMissed: false);

    expect(submitCount, 1);

    submitCompleter.complete(false);
    await tester.pumpAndSettle();

    expect(submitCount, 1);
    expect(tester.widget<FilledButton>(importButton).onPressed, isNotNull);
  });
}
