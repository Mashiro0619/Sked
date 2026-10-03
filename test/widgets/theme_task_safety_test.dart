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
  for (final kind in ['seed', 'value', 'course']) {
    testWidgets(
      'theme $kind rejects invalid Hex and permits corrected input',
      (t) async {
        final (_, storage) = await mountThemeTask(t, kind: kind);
        final initialWrites = storage.writes;
        final field = themeTaskKey('compact-color-picker-hex-field');
        for (final invalid in [
          '#12ZZZZ',
          '##123456',
          '12345',
          '#1234567',
          '',
        ]) {
          await t.enterText(field, invalid);
          await t.pump();
          expect(t.widget<FilledButton>(themeApply(kind)).onPressed, isNull);
          expect(t.widget<TextField>(field).decoration!.errorText, isNotNull);
          expect(storage.writes, initialWrites);
        }
        await t.enterText(field, '  #aBc123  ');
        await t.pump();
        expect(t.widget<FilledButton>(themeApply(kind)).onPressed, isNotNull);
        expect(t.widget<TextField>(field).decoration!.errorText, isNull);
        await t.tap(themeApply(kind));
        await t.pumpAndSettle();
        expect(themeTask, findsNothing);
        expect(storage.writes, initialWrites + 1);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      },
      variant: TargetPlatformVariant({
        TargetPlatform.windows,
        TargetPlatform.android,
      }),
    );
  }
  testWidgets(
    'outline invalid Hex blocks apply but leaves cancel and correction usable',
    (t) async {
      await mountThemeTask(t);
      Navigator.of(t.element(themeTask)).pop();
      await t.pumpAndSettle();
      final card = themeTaskKey('theme-outline-settings-card');
      await t.scrollUntilVisible(
        card,
        200,
        maxScrolls: 20,
        scrollable: find.byType(Scrollable).first,
      );
      await t.pumpAndSettle();
      await t.tap(card);
      await t.pumpAndSettle();
      final follow = find.descendant(
        of: themeTaskKey('live-course-outline-follow-theme-row'),
        matching: find.byType(Switch),
      );
      await t.ensureVisible(follow);
      await t.tap(follow);
      await t.pumpAndSettle();
      final field = themeTaskKey('compact-color-picker-hex-field');
      await t.ensureVisible(field);
      await t.enterText(field, '#oops');
      await t.pump();
      expect(
        t
            .widget<FilledButton>(themeTaskKey('theme-outline-page-apply'))
            .onPressed,
        isNull,
      );
      expect(
        t
            .widget<TextButton>(themeTaskKey('theme-outline-page-cancel'))
            .onPressed,
        isNotNull,
      );
      await t.enterText(field, '123ABC');
      await t.pump();
      expect(
        t
            .widget<FilledButton>(themeTaskKey('theme-outline-page-apply'))
            .onPressed,
        isNotNull,
      );
      await t.tap(themeTaskKey('theme-outline-page-apply'));
      await t.pumpAndSettle();
      expect(field, findsNothing);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant({
      TargetPlatform.windows,
      TargetPlatform.android,
    }),
  );
}
