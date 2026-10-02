import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/screens/general_schedule_home_screen.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';
import 'package:sked/widgets/sked_floating_surface.dart';
import 'package:sked/screens/settings_page.dart';

import '../support/category_manager_harness.dart';
import '../support/workspace_harness.dart';

Finder k(String key) => find.byKey(ValueKey(key));
Finder get panel => k('category-manager-panel');
Finder get color => k('category-color-dialog');
Finder within(Finder parent, String key) =>
    find.descendant(of: parent, matching: k(key));
Finder textIn(Finder parent, String text) =>
    find.descendant(of: parent, matching: find.text(text));
final desktop = TargetPlatformVariant.only(TargetPlatform.windows);
Future<TimetableProvider> mount(
  WidgetTester t, {
  WorkspaceMemoryStorage? storage,
  double scale = 1,
  TextDirection direction = TextDirection.ltr,
  bool open = true,
  bool fullShell = false,
}) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = const Size(1440, 900);
  addTearDown(t.view.reset);
  final p = await workspaceProvider(
    mode: AppMode.general,
    storage: storage ?? categoryManagerStorage(),
  );
  addTearDown(p.dispose);
  await t.pumpWidget(
    fullShell
        ? WorkspaceHarness(
            provider: p,
            textScale: scale,
            textDirection: direction,
          )
        : categoryManagerHarness(p, scale: scale, direction: direction),
  );
  await t.pumpAndSettle();
  if (open) {
    await t.tap(k('workspace-resource-open'));
    await t.pumpAndSettle();
  }
  return p;
}

class GateStorage extends WorkspaceMemoryStorage {
  GateStorage(super.data);
  Completer<void>? gate;
  int writes = 0;
  @override
  Future<void> save(AppData next) async {
    writes++;
    await gate?.future;
    await super.save(next);
  }
}

Future<void> finish(WidgetTester t) async {
  expect(t.takeException(), isNull);
  await t.pumpWidget(const SizedBox());
}

void main() {
  testWidgets(
    'category manager opens next to resource entry, is transparent modal and draggable',
    (t) async {
      await mount(t, open: false);
      final entry = t.getRect(k('workspace-resource-open'));
      await t.tap(k('workspace-resource-open'));
      await t.pumpAndSettle();
      expect(panel, findsOneWidget);
      expect(find.byType(GeneralScheduleHomeScreen), findsOneWidget);
      final surface = k('floating-form-surface');
      final before = t.getRect(surface);
      expect(before.left, closeTo(entry.right + 6, 1));
      expect(before.width, 440);
      expect(before.height, lessThan(550));
      final barrier = find
          .byType(ModalBarrier)
          .evaluate()
          .map((e) => e.widget as ModalBarrier)
          .where((b) => b.dismissible)
          .last;
      expect(barrier.color?.a ?? 0, 0);
      await t.drag(
        within(panel, 'floating-form-drag-handle'),
        const Offset(140, 100),
      );
      await t.pumpAndSettle();
      expect(
        t.getRect(surface).topLeft,
        before.topLeft + const Offset(140, 100),
      );
      await t.tapAt(const Offset(1200, 850));
      await t.pumpAndSettle();
      expect(panel, findsNothing);
      expect(find.byType(GeneralEventEditorSheet), findsNothing);
      await t.tap(k('workspace-resource-open'));
      await t.pumpAndSettle();
      expect(t.getRect(surface), before);
      await finish(t);
    },
    variant: desktop,
  );

  testWidgets(
    'resource plus creates directly and preserves blank/dirty guards',
    (t) async {
      final p = await mount(t, open: false);
      await t.tap(k('general-resource-add'));
      await t.pumpAndSettle();
      expect(panel, findsNothing);
      expect(k('calendar-name-dialog'), findsOneWidget);
      expect(
        t
            .widget<FilledButton>(
              find.descendant(
                of: k('calendar-name-dialog'),
                matching: find.byType(FilledButton),
              ),
            )
            .onPressed,
        isNull,
      );
      await t.enterText(k('add-calendar-field'), 'New category');
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await t.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Cancel'),
        ),
      );
      await t.pumpAndSettle();
      expect(k('add-calendar-field'), findsOneWidget);
      await t.tap(textIn(k('calendar-name-dialog'), 'Save'));
      await t.pumpAndSettle();
      expect(p.generalSchedules.last.name, 'New category');
      expect(panel, findsNothing);
      await finish(t);
    },
    variant: desktop,
  );

  testWidgets(
    'rename child cancellation preserves parent position and scroll',
    (t) async {
      await mount(t);
      await t.drag(
        within(panel, 'floating-form-drag-handle'),
        const Offset(100, 55),
      );
      await t.pumpAndSettle();
      final parent = t.element(panel);
      final pos = t.getRect(k('floating-form-surface'));
      await t.tap(k('calendar-name-category-1'));
      await t.pumpAndSettle();
      expect(
        t
            .widget<FilledButton>(
              find.descendant(
                of: k('calendar-name-dialog'),
                matching: find.byType(FilledButton),
              ),
            )
            .onPressed,
        isNull,
      );
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(t.element(panel), same(parent));
      expect(t.getRect(k('floating-form-surface')), pos);
      await finish(t);
    },
    variant: desktop,
  );

  testWidgets(
    'color slot stays raw on unchanged confirmation and cancellation',
    (t) async {
      final p = await mount(t);
      final initial = p.generalSchedules[1].colorValue;
      await t.tap(k('calendar-color-category-1'));
      await t.pumpAndSettle();
      expect(color, findsOneWidget);
      await t.tap(k('category-color-save'));
      await t.pumpAndSettle();
      expect(p.generalSchedules[1].colorValue, initial);
      await t.tap(k('calendar-color-category-1'));
      await t.pumpAndSettle();
      await t.tap(k('category-color-slot-4'));
      await t.tap(textIn(color, 'Cancel'));
      await t.pumpAndSettle();
      expect(p.generalSchedules[1].colorValue, initial);
      await t.tap(k('calendar-color-category-1'));
      await t.pumpAndSettle();
      await t.tap(k('category-color-slot-4'));
      await t.tap(k('category-color-save'));
      await t.pumpAndSettle();
      expect(
        p.generalSchedules[1].colorValue,
        generalCalendarSlotColorValues[4],
      );
      await finish(t);
    },
    variant: desktop,
  );

  testWidgets(
    'invalid hex blocks saving and color write preserves current category fields',
    (t) async {
      final p = await mount(t);
      await t.tap(k('calendar-color-category-1'));
      await t.pumpAndSettle();
      final input = find.descendant(
        of: color,
        matching: find.byType(TextField),
      );
      await t.enterText(input, '12ZZ');
      await t.pump();
      expect(
        t.widget<FilledButton>(k('category-color-save')).onPressed,
        isNull,
      );
      expect(find.text('Enter a six-digit hex color.'), findsOneWidget);
      await t.enterText(input, '#123456');
      await t.pump();
      expect(
        t.widget<FilledButton>(k('category-color-save')).onPressed,
        isNotNull,
      );
      final old = p.generalSchedules[1];
      await p.updateGeneralSchedule(
        old.copyWith(
          name: 'Renamed elsewhere',
          isVisible: false,
          events: [
            ...old.events,
            old.events.first.copyWith(id: 'new-event', title: 'New event'),
          ],
        ),
      );
      await t.pumpAndSettle();
      await t.tap(k('category-color-save'));
      await t.pumpAndSettle();
      final result = p.generalSchedules[1];
      expect(result.colorValue, 0xff123456);
      expect(result.name, 'Renamed elsewhere');
      expect(result.isVisible, isFalse);
      expect(result.events, hasLength(2));
      await finish(t);
    },
    variant: desktop,
  );

  testWidgets(
    'busy color protects child and parent; failed save retains position and draft',
    (t) async {
      final storage = GateStorage(categoryManagerStorage().data);
      final p = await mount(t, storage: storage);
      await t.tap(k('calendar-color-category-1'));
      await t.pumpAndSettle();
      await t.enterText(
        find.descendant(of: color, matching: find.byType(TextField)),
        '#987654',
      );
      await t.pump();
      final original = p.generalSchedules[1].colorValue;
      final element = t.element(color);
      final before = t.getRect(color);
      final gate = Completer<void>();
      storage.gate = gate;
      storage.saveError = StateError('Expected category color failure');
      await t.tap(k('category-color-save'));
      await t.pump();
      final writes = storage.writes;
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.tapAt(const Offset(1200, 800));
      await t.pump();
      expect(color, findsOneWidget);
      expect(panel, findsOneWidget);
      expect(storage.writes, writes);
      gate.complete();
      await t.pumpAndSettle();
      expect(t.element(color), same(element));
      expect(t.getRect(color), before);
      expect(p.generalSchedules[1].colorValue, original);
      await t.tap(k('ui-command-failure-dismiss'));
      await t.pumpAndSettle();
      storage.gate = null;
      await t.tap(k('category-color-save'));
      await t.pumpAndSettle();
      expect(color, findsNothing);
      expect(p.generalSchedules[1].colorValue, 0xff987654);
      expect(panel, findsOneWidget);
      await finish(t);
    },
    variant: desktop,
  );

  testWidgets('visibility failed write rolls back without closing manager', (
    t,
  ) async {
    final storage = categoryManagerStorage();
    final p = await mount(t, storage: storage);
    storage.saveError = StateError('Expected visibility failure');
    await t.tap(k('calendar-visibility-category-1'));
    await t.pumpAndSettle();
    expect(p.generalSchedules[1].isVisible, isTrue);
    expect(panel, findsOneWidget);
    await t.tap(k('ui-command-failure-dismiss'));
    await t.pumpAndSettle();
    await t.tap(k('calendar-visibility-category-1'));
    await t.pumpAndSettle();
    expect(p.generalSchedules[1].isVisible, isFalse);
    expect(
      find.descendant(
        of: k('calendar-manager-tile-category-1'),
        matching: find.textContaining('Hidden'),
      ),
      findsOneWidget,
    );
    await finish(t);
  }, variant: desktop);

  for (final child in ['color', 'name']) {
    testWidgets('external category deletion retires only its child: $child', (
      t,
    ) async {
      final p = await mount(t);
      await t.tap(k('calendar-$child-category-1'));
      await t.pumpAndSettle();
      await p.deleteGeneralSchedule('category-1');
      await t.pumpAndSettle();
      expect(color, findsNothing);
      expect(k('calendar-name-dialog'), findsNothing);
      expect(panel, findsOneWidget);
      expect(k('calendar-manager-tile-category-1'), findsNothing);
      await finish(t);
    }, variant: desktop);
  }
  testWidgets(
    'data replacement retires manager and child, cannot write into replacement',
    (t) async {
      final p = await mount(t);
      final backup = await p.exportAppDataJson();
      await t.tap(k('calendar-color-category-1'));
      await t.pumpAndSettle();
      await t.enterText(
        find.descendant(of: color, matching: find.byType(TextField)),
        '#123456',
      );
      await t.pump();
      await p.importAppDataJson(backup, mode: AppImportMode.replaceAll);
      await t.pumpAndSettle();
      expect(color, findsNothing);
      expect(panel, findsNothing);
      expect(
        p.generalSchedules[1].colorValue,
        generalCalendarSlotColorValues[1],
      );
      await finish(t);
    },
    variant: desktop,
  );

  testWidgets(
    'delete confirmation cancellation and final-category behavior remain unchanged',
    (t) async {
      final p = await mount(t, storage: categoryManagerStorage(count: 1));
      await t.tap(k('calendar-actions-category-0'));
      await t.pumpAndSettle();
      await t.tap(find.text('Delete'));
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(find.byType(AlertDialog), findsOneWidget);
      await t.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Cancel'),
        ),
      );
      await t.pumpAndSettle();
      expect(p.generalSchedules, hasLength(1));
      expect(panel, findsOneWidget);
      await t.tap(k('calendar-actions-category-0'));
      await t.pumpAndSettle();
      await t.tap(find.text('Delete'));
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      await t.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Delete'),
        ),
      );
      await t.pumpAndSettle();
      expect(p.generalSchedules, hasLength(1));
      expect(p.generalSchedules.single.id, isNot('category-0'));
      expect(panel, findsOneWidget);
      await finish(t);
    },
    variant: desktop,
  );

  testWidgets(
    'export closes manager then opens existing transfer page without resurrecting it',
    (t) async {
      await mount(t);
      await t.tap(k('category-manager-export'));
      await t.pumpAndSettle();
      expect(panel, findsNothing);
      expect(find.byType(SettingsPage), findsOneWidget);
      Navigator.of(t.element(find.byType(SettingsPage))).pop();
      await t.pumpAndSettle();
      expect(panel, findsNothing);
      await finish(t);
    },
    variant: desktop,
  );

  for (final direction in TextDirection.values) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets(
        'manager and color fit long names and short windows $direction $scale',
        (t) async {
          await mount(
            t,
            scale: scale,
            direction: direction,
            storage: categoryManagerStorage(count: 20, longNames: true),
          );
          expect(panel, findsOneWidget);
          final rect = t.getRect(k('floating-form-surface'));
          expect(rect.width, lessThanOrEqualTo(520));
          await t.tap(k('calendar-color-category-0'));
          await t.pumpAndSettle();
          t.view.physicalSize = const Size(800, 650);
          t.view.viewInsets = const FakeViewPadding(bottom: 100);
          await t.pumpAndSettle();
          expect(color, findsOneWidget);
          expect(
            t
                .widget<Text>(
                  textIn(
                    color,
                    'Long category name for accessibility and wrapping 0',
                  ),
                )
                .maxLines,
            2,
          );
          expect(t.getRect(color).bottom, lessThanOrEqualTo(542));
          expect(t.getRect(color).left, greaterThanOrEqualTo(8));
          await finish(t);
        },
        variant: desktop,
      );
    }
  }
  testWidgets(
    'name failure keeps draft and parent; double submit writes once',
    (t) async {
      final storage = GateStorage(categoryManagerStorage().data);
      final p = await mount(t, storage: storage);
      await t.tap(k('calendar-name-category-1'));
      await t.pumpAndSettle();
      await t.enterText(k('rename-calendar-field'), 'New saved name');
      await t.pump();
      final gate = Completer<void>();
      storage.gate = gate;
      storage.saveError = StateError('Expected name failure');
      await t.tap(textIn(k('calendar-name-dialog'), 'Save'));
      await t.pump();
      final writes = storage.writes;
      await t.tap(textIn(k('calendar-name-dialog'), 'Save'));
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pump();
      expect(storage.writes, writes);
      expect(k('calendar-name-dialog'), findsOneWidget);
      gate.complete();
      await t.pumpAndSettle();
      expect(
        t.widget<TextField>(k('rename-calendar-field')).controller!.text,
        'New saved name',
      );
      await t.tap(k('ui-command-failure-dismiss'));
      await t.pumpAndSettle();
      storage.gate = null;
      await t.tap(textIn(k('calendar-name-dialog'), 'Save'));
      await t.pumpAndSettle();
      expect(p.generalSchedules[1].name, 'New saved name');
      expect(panel, findsOneWidget);
      await finish(t);
    },
    variant: desktop,
  );

  testWidgets(
    'name entered through more uses persistent action button and restores its focus',
    (t) async {
      await mount(t);
      final button = k('calendar-actions-category-1');
      final anchor = t.getRect(button);
      await t.tap(button);
      await t.pumpAndSettle();
      await t.tap(find.text('Rename'));
      await t.pumpAndSettle();
      final form = k('floating-form-surface').last;
      expect((t.getRect(form).top - anchor.bottom).abs(), lessThan(100));
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(k('calendar-name-dialog'), findsNothing);
      expect(panel, findsOneWidget);
      expect(FocusScope.of(t.element(panel)).hasFocus, isTrue);
      await finish(t);
    },
    variant: desktop,
  );

  testWidgets(
    'outside closes only color child; slot click repairs invalid hex draft',
    (t) async {
      final p = await mount(t);
      final before = p.generalSchedules[1].colorValue;
      await t.tap(k('calendar-color-category-1'));
      await t.pumpAndSettle();
      await t.enterText(
        find.descendant(of: color, matching: find.byType(TextField)),
        'bad',
      );
      await t.pump();
      expect(
        t.widget<FilledButton>(k('category-color-save')).onPressed,
        isNull,
      );
      await t.tap(k('category-color-slot-2'));
      await t.pumpAndSettle();
      expect(
        t.widget<FilledButton>(k('category-color-save')).onPressed,
        isNotNull,
      );
      await t.tapAt(const Offset(1200, 850));
      await t.pumpAndSettle();
      expect(color, findsNothing);
      expect(panel, findsOneWidget);
      expect(p.generalSchedules[1].colorValue, before);
      await finish(t);
    },
    variant: desktop,
  );

  testWidgets(
    'failed category deletion retains manager and confirmation for retry',
    (t) async {
      final storage = GateStorage(categoryManagerStorage().data);
      final p = await mount(t, storage: storage);
      await t.tap(k('calendar-actions-category-1'));
      await t.pumpAndSettle();
      await t.tap(find.text('Delete'));
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      storage.saveError = StateError('Expected category deletion failure');
      await t.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Delete'),
        ),
      );
      await t.pumpAndSettle();
      expect(p.generalSchedules, hasLength(4));
      expect(panel, findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
      await t.tap(k('ui-command-failure-dismiss'));
      await t.pumpAndSettle();
      await t.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Delete'),
        ),
      );
      await t.pumpAndSettle();
      expect(p.generalSchedules, hasLength(3));
      expect(panel, findsOneWidget);
      await finish(t);
    },
    variant: desktop,
  );

  testWidgets('workspace disable removes manager and color child', (t) async {
    final p = await mount(t, fullShell: true);
    await t.tap(k('calendar-color-category-1'));
    await t.pumpAndSettle();
    await p.setWorkspaceEnabled(AppMode.general, false);
    await t.pumpAndSettle();
    expect(color, findsNothing);
    expect(panel, findsNothing);
    expect(t.takeException(), isNull);
  }, variant: desktop);
  testWidgets(
    'external deletion retires a dirty name and its discard confirmation only',
    (t) async {
      final p = await mount(t);
      await t.tap(k('calendar-name-category-1'));
      await t.pumpAndSettle();
      await t.enterText(k('rename-calendar-field'), 'Unsaved draft');
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await p.deleteGeneralSchedule('category-1');
      await t.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(k('calendar-name-dialog'), findsNothing);
      expect(panel, findsOneWidget);
      await finish(t);
    },
    variant: desktop,
  );

  testWidgets(
    'manager closes with Escape immediately and restores its entry focus',
    (t) async {
      await mount(t, open: false);
      final entry = k('workspace-resource-open');
      final focus = skedFloatingAnchorFocus(t.element(entry));
      expect(focus, isNotNull);
      await t.tap(entry);
      await t.pumpAndSettle();
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(panel, findsNothing);
      expect(focus!.hasFocus, isTrue);
      await finish(t);
    },
    variant: desktop,
  );
  testWidgets(
    'short manager gives its list the visible height, with no nested body scrolling',
    (t) async {
      await mount(
        t,
        scale: 2,
        storage: categoryManagerStorage(count: 30, longNames: true),
      );
      t.view.physicalSize = const Size(700, 550);
      await t.pumpAndSettle();
      final list = find.byKey(const PageStorageKey('calendar-manager-list'));
      final body = find.descendant(of: list, matching: find.byType(Scrollable));
      expect(
        t.getRect(list).bottom,
        lessThanOrEqualTo(t.getRect(k('category-manager-import')).top),
      );
      await t.scrollUntilVisible(
        k('calendar-manager-tile-category-29'),
        250,
        scrollable: body,
      );
      await t.pumpAndSettle();
      expect(k('calendar-name-category-29').hitTestable(), findsOneWidget);
      expect(
        t.getRect(k('calendar-manager-tile-category-29')).bottom,
        lessThanOrEqualTo(t.getRect(k('category-manager-import')).top),
      );
      await t.tap(k('calendar-name-category-29'));
      await t.pumpAndSettle();
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(k('calendar-name-category-29').hitTestable(), findsOneWidget);
      await finish(t);
    },
    variant: desktop,
  );
}
