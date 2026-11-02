import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/selective_backup_page.dart';

import '../support/workspace_harness.dart';

void main() {
  Future<AppRuntime> fixture(
    WidgetTester tester, {
    Uint8List? source,
    Size size = const Size(393, 900),
    double textScale = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final runtime = (await tester.runAsync(() async {
      final value = await workspaceProvider();
      return value;
    }))!;
    addTearDown(runtime.dispose);
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: SelectiveBackupPage(
            service: runtime.backups.selective,
            pickBackup: () async => source,
          ),
        ),
      );
      await runtime.backups.selective.inventory();
    });
    await tester.pumpAndSettle();
    return runtime;
  }

  testWidgets(
    'narrow selector keeps empty selection inert and filters object rows',
    (tester) async {
      await fixture(tester);
      final l = AppLocalizations.of(
        tester.element(find.byType(SelectiveBackupPage)),
      );
      await tester.tap(find.text(l.selectiveBackupClearSelection));
      await tester.enterText(
        find.byType(TextField),
        'no object has this label',
      );
      await tester.pumpAndSettle();
      final primary = find.byKey(const ValueKey('selective-backup-primary'));
      await tester.scrollUntilVisible(
        primary,
        300,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(tester.widget<FilledButton>(primary).onPressed, isNull);
      expect(find.byType(CheckboxListTile), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'legacy file opens the same object selector and cancelled review preserves saved data',
    (tester) async {
      final initial = buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: 'en',
      );
      final incoming = initial.copyWith(
        generalMode: initial.generalMode.copyWith(
          schedules: [
            const GeneralSchedule(
              id: 'new-calendar',
              name: 'Only selected archive calendar',
              events: [],
            ),
          ],
          activeScheduleId: 'new-calendar',
        ),
      );
      final source = Uint8List.fromList(
        utf8.encode(encodeAppBackup(incoming, const [])),
      );
      final runtime = await fixture(tester, source: source);
      final before = runtime.session.committedData.toJson();
      final l = AppLocalizations.of(
        tester.element(find.byType(SelectiveBackupPage)),
      );
      await tester.tap(find.text(l.selectiveBackupOpenFile));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.selectiveBackupClearSelection));
      await tester.enterText(
        find.byType(TextField),
        'Only selected archive calendar',
      );
      await tester.pumpAndSettle();
      final row = find.byKey(
        const ValueKey('backup-object-calendar:new-calendar'),
      );
      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      final primary = find.byKey(const ValueKey('selective-backup-primary'));
      await tester.ensureVisible(primary);
      await tester.runAsync(() async {
        final prepared = Completer<void>();
        var preparing = false;
        void preparationChanged() {
          if (runtime.backups.selective.isBusy) {
            preparing = true;
          } else if (preparing && !prepared.isCompleted) {
            prepared.complete();
          }
        }

        runtime.backups.selective.addListener(preparationChanged);
        try {
          await tester.tap(primary);
          await prepared.future;
        } finally {
          runtime.backups.selective.removeListener(preparationChanged);
        }
      });
      await tester.pumpAndSettle();
      expect(find.text(l.selectiveBackupConfirmTitle), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(runtime.session.committedData.toJson(), before);
      await tester.tap(find.widgetWithText(TextButton, l.cancel));
      await tester.pumpAndSettle();
      expect(runtime.session.committedData.toJson(), before);
      expect(tester.takeException(), isNull);
    },
  );

  for (final textScale in [1.0, 2.0]) {
    testWidgets(
      'scrolling and cancelled review keep the filter draft at ${textScale.toInt()}x',
      (tester) async {
        final initial = buildInitialAppData(
          buildDefaultPeriodTimes(),
          localeCode: 'en',
        );
        final incoming = initial.copyWith(
          generalMode: initial.generalMode.copyWith(
            schedules: [
              const GeneralSchedule(
                id: 'selected-calendar',
                name: 'Archive calendar selected',
                events: [],
              ),
              for (var index = 0; index < 40; index++)
                GeneralSchedule(
                  id: 'other-calendar-$index',
                  name: 'Archive calendar $index',
                  events: const [],
                ),
            ],
            activeScheduleId: 'selected-calendar',
          ),
        );
        final source = Uint8List.fromList(
          utf8.encode(encodeAppBackup(incoming, const [])),
        );
        final runtime = await fixture(
          tester,
          source: source,
          size: const Size(393, 600),
          textScale: textScale,
        );
        final before = runtime.session.committedData.toJson();
        final page = find.byType(SelectiveBackupPage);
        final l = AppLocalizations.of(tester.element(page));
        final scrollable = find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first;
        final search = find.descendant(
          of: page,
          matching: find.byType(TextField),
        );
        final row = find.byKey(
          const ValueKey('backup-object-calendar:selected-calendar'),
        );
        const query = 'Archive calendar';

        await tester.scrollUntilVisible(
          find.text(l.selectiveBackupOpenFile),
          200,
          scrollable: scrollable,
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text(l.selectiveBackupOpenFile));
        await tester.pumpAndSettle();
        expect(
          find.text(l.selectiveBackupOpenFile).hitTestable(),
          findsOneWidget,
        );
        await tester.tap(find.text(l.selectiveBackupOpenFile));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text(l.selectiveBackupClearSelection),
          200,
          scrollable: scrollable,
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text(l.selectiveBackupClearSelection));
        await tester.pumpAndSettle();
        expect(
          find.text(l.selectiveBackupClearSelection).hitTestable(),
          findsOneWidget,
        );
        await tester.tap(find.text(l.selectiveBackupClearSelection));
        await tester.scrollUntilVisible(search, -200, scrollable: scrollable);
        await tester.pumpAndSettle();
        await tester.ensureVisible(search);
        await tester.pumpAndSettle();
        expect(search.hitTestable(), findsOneWidget);
        await tester.enterText(search, query);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(row, 200, scrollable: scrollable);
        await tester.pumpAndSettle();
        await tester.ensureVisible(row);
        await tester.pumpAndSettle();
        expect(row.hitTestable(), findsOneWidget);
        await tester.tap(row);
        await tester.pumpAndSettle();

        final primary = find.byKey(const ValueKey('selective-backup-primary'));
        await tester.scrollUntilVisible(
          primary,
          400,
          scrollable: scrollable,
          maxScrolls: 60,
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(primary);
        await tester.pumpAndSettle();
        expect(primary.hitTestable(), findsOneWidget);
        expect(
          tester.state<ScrollableState>(scrollable).position.pixels,
          greaterThan(1000),
        );
        expect(search.hitTestable(), findsNothing);
        await tester.runAsync(() async {
          final prepared = Completer<void>();
          var preparing = false;
          void preparationChanged() {
            if (runtime.backups.selective.isBusy) {
              preparing = true;
            } else if (preparing && !prepared.isCompleted) {
              prepared.complete();
            }
          }

          runtime.backups.selective.addListener(preparationChanged);
          try {
            await tester.tap(primary);
            await prepared.future;
          } finally {
            runtime.backups.selective.removeListener(preparationChanged);
          }
        });
        await tester.pumpAndSettle();
        expect(find.text(l.selectiveBackupConfirmTitle), findsOneWidget);
        expect(
          find.widgetWithText(TextButton, l.cancel).hitTestable(),
          findsOneWidget,
        );
        await tester.runAsync(
          () => tester.tap(find.widgetWithText(TextButton, l.cancel)),
        );
        await tester.pumpAndSettle();
        expect(find.text(l.selectiveBackupConfirmTitle), findsNothing);
        await tester.scrollUntilVisible(
          search,
          -400,
          scrollable: scrollable,
          maxScrolls: 60,
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(search);
        await tester.pumpAndSettle();
        expect(search.hitTestable(), findsOneWidget);

        expect(tester.widget<TextField>(search).enabled, isTrue);
        final input = tester.widget<EditableText>(
          find.descendant(of: search, matching: find.byType(EditableText)),
        );
        expect(input.controller.text, query);
        expect(find.text(l.selectiveBackupSelectedCount(1)), findsOneWidget);
        await tester.scrollUntilVisible(row, 200, scrollable: scrollable);
        await tester.pumpAndSettle();
        await tester.ensureVisible(row);
        await tester.pumpAndSettle();
        expect(row.hitTestable(), findsOneWidget);
        expect(tester.widget<CheckboxListTile>(row).value, isTrue);
        expect(runtime.session.committedData.toJson(), before);
        expect(runtime.backups.selective.recoveryPending, isFalse);

        await tester.scrollUntilVisible(
          find.text(l.selectiveBackupOpenFile),
          -300,
          scrollable: scrollable,
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text(l.selectiveBackupOpenFile));
        await tester.pumpAndSettle();
        expect(
          find.text(l.selectiveBackupOpenFile).hitTestable(),
          findsOneWidget,
        );
        expect(
          tester
              .widget<OutlinedButton>(
                find.ancestor(
                  of: find.text(l.selectiveBackupOpenFile),
                  matching: find.byWidgetPredicate(
                    (widget) => widget is OutlinedButton,
                  ),
                ),
              )
              .onPressed,
          isNotNull,
        );
        await tester.tap(find.text(l.selectiveBackupOpenFile));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(search, 200, scrollable: scrollable);
        await tester.pumpAndSettle();
        await tester.ensureVisible(search);
        await tester.pumpAndSettle();
        expect(search.hitTestable(), findsOneWidget);
        expect(
          tester
              .widget<EditableText>(
                find.descendant(
                  of: search,
                  matching: find.byType(EditableText),
                ),
              )
              .controller
              .text,
          isEmpty,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
