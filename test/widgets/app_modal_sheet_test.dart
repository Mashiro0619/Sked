import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/widgets/app_modal_sheet.dart';
import 'package:sked/widgets/expressive_dialog.dart';
import 'package:sked/widgets/ui_command.dart';

Widget _localizedApp(Widget home) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}

void main() {
  testWidgets('disabling sheet drag also removes the draggable handle', (
    tester,
  ) async {
    await tester.pumpWidget(
      _localizedApp(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                unawaited(
                  showAppModalSheet<void>(
                    context: context,
                    enableDrag: false,
                    builder: (_) => const SizedBox(height: 160),
                  ),
                );
              },
              child: const Text('Open sheet'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open sheet'));
    await tester.pumpAndSettle();

    final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
    expect(sheet.enableDrag, isFalse);
    expect(sheet.showDragHandle, isFalse);
    expect(sheet.clipBehavior, Clip.antiAlias);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sheet command failures render above the modal route', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _localizedApp(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                unawaited(
                  showAppModalSheet<void>(
                    context: context,
                    enableDrag: false,
                    builder: (sheetContext) => SizedBox(
                      height: 240,
                      child: Center(
                        child: FilledButton(
                          onPressed: () {
                            unawaited(
                              runUiCommandWithFeedback(
                                context: sheetContext,
                                debugLabel: 'Test sheet command',
                                command: () async {
                                  throw StateError('sheet failure');
                                },
                              ),
                            );
                          },
                          child: const Text('Fail in sheet'),
                        ),
                      ),
                    ),
                  ),
                );
              },
              child: const Text('Open sheet'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open sheet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fail in sheet'));
    await tester.pumpAndSettle();

    final notice = find.byKey(const ValueKey('ui-command-failure-notice'));
    final dismiss = find.byKey(const ValueKey('ui-command-failure-dismiss'));
    expect(notice, findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(dismiss.hitTestable(), findsOneWidget);

    final sheetRect = tester.getRect(find.byType(BottomSheet));
    final noticeRect = tester.getRect(notice);
    expect(sheetRect.contains(noticeRect.topLeft), isTrue);
    expect(
      sheetRect.contains(noticeRect.bottomRight - const Offset(1, 1)),
      isTrue,
    );
    expect(
      tester.getSemantics(
        find.byKey(const ValueKey('ui-command-failure-live-region-1')),
      ),
      matchesSemantics(
        label: 'Save failed. Please try again later.',
        isLiveRegion: true,
      ),
    );

    await tester.tap(dismiss);
    await tester.pump();
    expect(notice, findsNothing);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('dialog command failures stay above the modal barrier', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _localizedApp(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                unawaited(
                  showExpressiveDialog<void>(
                    context: context,
                    barrierDismissible: false,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Test dialog'),
                      actions: [
                        FilledButton(
                          onPressed: () {
                            unawaited(
                              runUiCommandWithFeedback(
                                context: dialogContext,
                                debugLabel: 'Test dialog command',
                                command: () async {
                                  throw StateError('dialog failure');
                                },
                              ),
                            );
                          },
                          child: const Text('Fail in dialog'),
                        ),
                      ],
                    ),
                  ),
                );
              },
              child: const Text('Open dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fail in dialog'));
    await tester.pumpAndSettle();

    final notice = find.byKey(const ValueKey('ui-command-failure-notice'));
    final dismiss = find.byKey(const ValueKey('ui-command-failure-dismiss'));
    expect(notice, findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(dismiss.hitTestable(), findsOneWidget);
    expect(
      tester.getSemantics(
        find.byKey(const ValueKey('ui-command-failure-live-region-1')),
      ),
      matchesSemantics(
        label: 'Save failed. Please try again later.',
        isLiveRegion: true,
      ),
    );

    await tester.tap(dismiss);
    await tester.pump();
    expect(notice, findsNothing);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
