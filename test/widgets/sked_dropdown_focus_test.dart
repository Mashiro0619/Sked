import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/widgets/settings_list.dart';

import '../support/workspace_harness.dart';

Finder k(String id) => find.byKey(ValueKey(id));
Finder get menuAnchor =>
    find.descendant(of: k('choice'), matching: find.byType(MenuAnchor));

Future<(FocusNode, TestGesture, List<int?>)> start(WidgetTester t) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = const Size(900, 700);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.view.resetPhysicalSize);
  final p = await workspaceProvider();
  addTearDown(p.dispose);
  final nextFocus = FocusNode();
  addTearDown(nextFocus.dispose);
  final selected = <int?>[];
  await t.pumpWidget(
    WorkspaceHarness(
      provider: p,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              SettingsConnectedGroup(
                title: 'Appearance',
                tonal: true,
                children: [
                  SettingsChoiceTile<int>(
                    key: const ValueKey('choice'),
                    title: 'Color mode',
                    icon: Icons.brightness_6,
                    value: 1,
                    entries: const [
                      DropdownMenuEntry(value: 0, label: 'System'),
                      DropdownMenuEntry(value: 1, label: 'Light'),
                      DropdownMenuEntry(value: 2, label: 'Dark'),
                    ],
                    onSelected: selected.add,
                  ),
                ],
              ),
              const SizedBox(height: 240),
              TextField(
                key: const ValueKey('next-field'),
                focusNode: nextFocus,
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: const Offset(4, 4));
  addTearDown(mouse.removePointer);
  return (nextFocus, mouse, selected);
}

Future<void> click(WidgetTester t, TestGesture mouse, Finder target) async {
  final position = t.getCenter(target);
  await mouse.moveTo(position);
  await mouse.down(position);
  await mouse.up();
  await t.pumpAndSettle();
}

Future<void> leaveRow(WidgetTester t, TestGesture mouse) async {
  await mouse.moveTo(const Offset(4, 650));
  await t.pumpAndSettle();
}

void main() {
  final platforms = TargetPlatformVariant({
    TargetPlatform.windows,
    TargetPlatform.android,
  });
  for (final opening in ['row', 'value']) {
    for (final dismissal in [
      'outside',
      'row',
      'value',
      'selection',
      'escape',
    ]) {
      testWidgets(
        'pointer-opened $opening menu releases focus after $dismissal dismissal',
        (t) async {
          final (_, mouse, selected) = await start(t);
          final trigger = t.widget<MenuAnchor>(menuAnchor).childFocusNode!;
          await click(
            t,
            mouse,
            opening == 'row' ? find.text('Color mode') : menuAnchor,
          );
          expect(find.byType(MenuItemButton), findsNWidgets(3));
          switch (dismissal) {
            case 'outside':
              await mouse.down(const Offset(4, 650));
              await mouse.up();
            case 'row':
              await click(t, mouse, find.text('Color mode'));
            case 'value':
              await click(t, mouse, menuAnchor);
            case 'selection':
              await click(
                t,
                mouse,
                find.widgetWithText(MenuItemButton, 'Dark'),
              );
            case 'escape':
              await t.sendKeyEvent(LogicalKeyboardKey.escape);
          }
          await leaveRow(t, mouse);
          expect(find.byType(MenuItemButton), findsNothing);
          expect(selected, dismissal == 'selection' ? [2] : isEmpty);
          expect(
            trigger.hasFocus,
            isFalse,
            reason:
                'Pointer dismissal must not leave the row focus-highlighted.',
          );
          expect(t.takeException(), isNull);
        },
        variant: platforms,
      );
    }
  }

  for (final keyboardOpen in [false, true]) {
    testWidgets(
      'outside click keeps the next field focused after menu closure, keyboard open: $keyboardOpen',
      (t) async {
        final (nextFocus, mouse, _) = await start(t);
        final trigger = t.widget<MenuAnchor>(menuAnchor).childFocusNode!;
        if (keyboardOpen) {
          trigger.requestFocus();
          await t.pump();
          await t.sendKeyEvent(LogicalKeyboardKey.enter);
          await t.pumpAndSettle();
        } else {
          await click(t, mouse, menuAnchor);
        }
        await click(t, mouse, k('next-field'));
        await leaveRow(t, mouse);
        expect(find.byType(MenuItemButton), findsNothing);
        expect(nextFocus.hasPrimaryFocus, isTrue);
        expect(trigger.hasFocus, isFalse);
        expect(t.takeException(), isNull);
      },
      variant: platforms,
    );
  }

  testWidgets('a mouse selection releases a keyboard-opened menu trigger', (
    t,
  ) async {
    final (_, mouse, selected) = await start(t);
    final trigger = t.widget<MenuAnchor>(menuAnchor).childFocusNode!;
    trigger.requestFocus();
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pumpAndSettle();
    await click(t, mouse, find.widgetWithText(MenuItemButton, 'Dark'));
    await leaveRow(t, mouse);
    expect(selected, [2]);
    expect(find.byType(MenuItemButton), findsNothing);
    expect(trigger.hasFocus, isFalse);
    expect(t.takeException(), isNull);
  }, variant: platforms);

  testWidgets(
    'switching from mouse to keyboard navigation restores trigger focus',
    (t) async {
      final (_, mouse, selected) = await start(t);
      final trigger = t.widget<MenuAnchor>(menuAnchor).childFocusNode!;
      await click(t, mouse, menuAnchor);
      await leaveRow(t, mouse);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await t.pumpAndSettle();
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(selected, hasLength(1));
      expect(find.byType(MenuItemButton), findsNothing);
      expect(trigger.hasPrimaryFocus, isTrue);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(find.byType(MenuItemButton), findsNWidgets(3));
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(trigger.hasPrimaryFocus, isTrue);
      expect(t.takeException(), isNull);
    },
    variant: platforms,
  );
}
