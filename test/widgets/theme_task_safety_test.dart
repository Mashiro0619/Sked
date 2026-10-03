import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/theme_task_harness.dart';

void main() {
  for (final kind in ['seed', 'value', 'course']) {
    for (final fail in [false, true]) {
      testWidgets(
        'theme $kind save owns its route; failure=$fail',
        (t) async {
          final (_, storage) = await mountThemeTask(t, kind: kind);
          await t.enterText(
            themeTaskKey('compact-color-picker-hex-field'),
            '#123456',
          );
          await t.pump();
          final owner = ModalRoute.of(t.element(themeTask))!;
          final element = t.element(themeTask);
          final gate = Completer<void>();
          storage.pending = gate;
          if (fail) {
            storage.saveError = StateError('Expected theme save failure');
          }
          await t.tap(themeApply(kind));
          await t.pump();
          await t.pump(const Duration(milliseconds: 100));
          final writes = storage.writes;
          final extra = showDialog<void>(
            context: t.element(themeTask),
            builder: (_) => const AlertDialog(
              key: ValueKey('unrelated-theme-task'),
              title: Text('Other task'),
            ),
          );
          await t.pump();
          await t.pump(const Duration(seconds: 1));
          gate.complete();
          await t.pumpAndSettle();
          expect(themeTaskKey('unrelated-theme-task'), findsOneWidget);
          expect(owner.isActive, fail);
          expect(storage.writes, writes);
          Navigator.of(t.element(themeTaskKey('unrelated-theme-task'))).pop();
          await extra;
          await t.pumpAndSettle();
          if (fail) {
            expect(t.element(themeTask), same(element));
            expect(
              t.widget<FilledButton>(themeApply(kind)).onPressed,
              isNotNull,
            );
            await t.tap(themeTaskKey('ui-command-failure-dismiss'));
            await t.pumpAndSettle();
            storage.pending = null;
            await t.tap(themeApply(kind));
            await t.pumpAndSettle();
          }
          expect(themeTask, findsNothing);
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
        },
        variant: TargetPlatformVariant({
          TargetPlatform.windows,
          TargetPlatform.android,
        }),
      );
    }
  }
}
