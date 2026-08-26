import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/widgets/app_modal_sheet.dart';
import 'package:sked/widgets/expressive_dialog.dart';
import 'package:sked/widgets/ui_command.dart';

Widget _localizedApp(Widget home) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}

void main() {
  testWidgets('custom footer stays fixed while the sheet body scrolls', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _localizedApp(
        Scaffold(
          body: AppSheetScaffold(
            title: const Text('Import preview'),
            leading: const Text('Legacy leading action'),
            actions: const [Text('Legacy trailing action')],
            footer: const FilledButton(
              onPressed: null,
              child: Text('Import as new timetable'),
            ),
            child: const SizedBox(
              height: 1200,
              child: Align(
                alignment: Alignment.topLeft,
                child: Text('Scrollable import content'),
              ),
            ),
          ),
        ),
      ),
    );

    final footer = find.text('Import as new timetable');
    expect(footer, findsOneWidget);
    expect(find.text('Legacy leading action'), findsNothing);
    expect(find.text('Legacy trailing action'), findsNothing);
    expect(find.byType(SingleChildScrollView), findsOneWidget);

    final beforeScroll = tester.getRect(footer);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -320),
    );
    await tester.pumpAndSettle();

    expect(tester.getRect(footer), beforeScroll);
    expect(tester.takeException(), isNull);
  });

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
