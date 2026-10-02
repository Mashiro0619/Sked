import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/widgets/adaptive_collection_scaffold.dart';
import 'package:sked/widgets/sked_task_dialog.dart';
import 'package:sked/widgets/sked_floating_surface.dart';

import '../support/workspace_harness.dart';

Finder k(String id) => find.byKey(ValueKey(id));
Finder get dialogSurface => k('floating-form-surface').evaluate().isNotEmpty
    ? k('floating-form-surface').last
    : find.descendant(
        of: k('calendar-name-dialog'),
        matching: find.byWidgetPredicate(
          (widget) => widget is Material && widget.type == MaterialType.card,
        ),
      );
bool get desktopManager => k('category-manager-panel').evaluate().isNotEmpty;
Finder get addButton => desktopManager
    ? find.widgetWithText(TextButton, 'Add category')
    : find.byTooltip('Add category');
Finder get saveButton => find.widgetWithText(FilledButton, 'Save');
Finder get cancelButton => find.widgetWithText(TextButton, 'Cancel');

class _RecordingStorage extends WorkspaceMemoryStorage {
  _RecordingStorage(super.data);
  int saves = 0;
  Completer<void>? pending;
  @override
  Future<void> save(AppData value) async {
    saves++;
    await pending?.future;
    await super.save(value);
  }
}

void viewport(WidgetTester t, Size size) {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = size;
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.view.resetPhysicalSize);
}

Future<(TimetableProvider, _RecordingStorage)> start(
  WidgetTester t, {
  int count = 1,
  double scale = 1,
  TextDirection direction = TextDirection.ltr,
}) async {
  final calendars = List.generate(
    count,
    (i) => GeneralSchedule(
      id: 'category-$i',
      name: 'Category $i',
      events: const [],
    ),
  );
  final base = buildInitialAppData(buildDefaultPeriodTimes(), localeCode: 'en');
  final storage = _RecordingStorage(
    base.copyWith(
      activeMode: AppMode.general,
      generalMode: base.generalMode.copyWith(
        schedules: calendars,
        activeScheduleId: calendars.first.id,
      ),
    ),
  );
  final p = await workspaceProvider(mode: AppMode.general, storage: storage);
  addTearDown(() {
    final pending = storage.pending;
    if (pending != null && !pending.isCompleted) pending.complete();
    p.dispose();
  });
  await t.pumpWidget(
    WorkspaceHarness(provider: p, textScale: scale, textDirection: direction),
  );
  await t.pumpAndSettle();
  final resources = k('workspace-resource-open').hitTestable();
  await t.tap(
    resources.evaluate().isNotEmpty
        ? resources
        : k('general-calendar-selector'),
  );
  await t.pumpAndSettle();
  return (p, storage);
}

Future<void> rename(WidgetTester t, String id) async {
  final row = k('calendar-manager-tile-$id');
  await t.tap(find.descendant(of: row, matching: find.byType(Text)).first);
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'anchored name form drags without losing draft and blocks background actions',
    (t) async {
      viewport(t, const Size(1280, 800));
      final (p, storage) = await start(t);
      final row = t.getRect(k('calendar-name-category-0'));
      final savedBefore = storage.saves;
      await rename(t, 'category-0');
      final original = t.getRect(dialogSurface);
      expect(original.top, closeTo(row.bottom + 6, 1));
      expect(
        ModalRoute.of(t.element(k('calendar-name-dialog')))!.barrierColor,
        Colors.transparent,
      );
      await t.enterText(k('rename-calendar-field'), 'Dragged draft');
      await t.pump();
      final dx = original.center.dx > 640 ? -80.0 : 80.0;
      await t.drag(k('floating-form-drag-handle').last, Offset(dx, 80));
      await t.pumpAndSettle();
      final moved = t.getRect(dialogSurface);
      expect(moved.top, greaterThan(original.top));
      expect(moved.left, closeTo(original.left + dx, 1));
      final visible = p.generalSchedules.single.isVisible;
      await t.tap(k('calendar-visibility-category-0'), warnIfMissed: false);
      await t.pumpAndSettle();
      expect(p.generalSchedules.single.isVisible, visible);
      expect(
        find.widgetWithText(FilledButton, 'Discard and exit'),
        findsOneWidget,
      );
      await t.tap(cancelButton.last);
      await t.pumpAndSettle();
      expect(t.getRect(dialogSurface), moved);
      expect(
        t.widget<TextField>(k('rename-calendar-field')).controller!.text,
        'Dragged draft',
      );
      storage.saveError = StateError('retry dragged form');
      await t.tap(saveButton);
      await t.pumpAndSettle();
      expect(
        t.widget<TextField>(k('rename-calendar-field')).controller!.text,
        'Dragged draft',
      );
      expect(t.getRect(dialogSurface).topLeft, moved.topLeft);
      await t.tap(saveButton);
      await t.pumpAndSettle();
      expect(p.generalSchedules.single.name, 'Dragged draft');
      expect(storage.saves, savedBefore + 2);
      await rename(t, 'category-0');
      expect(t.getRect(dialogSurface).topLeft, original.topLeft);
      await t.tap(k('floating-form-close').last);
      await t.pumpAndSettle();
      expect(k('calendar-name-dialog'), findsNothing);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'menu rename uses the persistent trigger and dragged form stays inside a small window',
    (t) async {
      viewport(t, const Size(1100, 800));
      await start(t);
      final trigger = k('calendar-actions-category-0');
      final anchor = t.getRect(trigger);
      final triggerFocus = skedFloatingAnchorFocus(t.element(trigger));
      expect(triggerFocus, isNotNull);
      await t.tap(trigger);
      await t.pumpAndSettle();
      await t.tap(find.text('Rename'));
      await t.pumpAndSettle();
      expect(t.getRect(dialogSurface).top, closeTo(anchor.bottom + 6, 1));
      await t.drag(
        k('floating-form-drag-handle').last,
        const Offset(-2000, 2000),
      );
      await t.pumpAndSettle();
      t.view.physicalSize = const Size(520, 420);
      await t.pumpAndSettle();
      final rect = t.getRect(dialogSurface);
      expect(rect.left, greaterThanOrEqualTo(8));
      expect(rect.right, lessThanOrEqualTo(512));
      expect(rect.top, greaterThanOrEqualTo(56));
      expect(rect.bottom, lessThanOrEqualTo(412));
      expect(k('floating-form-close').last.hitTestable(), findsOneWidget);
      await t.tap(k('floating-form-close').last);
      await t.pumpAndSettle();
      expect(triggerFocus!.hasFocus, isTrue);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  final platforms = TargetPlatformVariant({
    TargetPlatform.android,
    TargetPlatform.windows,
  });

  testWidgets(
    'management has one list and renaming preserves its position across resize',
    (t) async {
      viewport(t, const Size(1280, 800));
      final (p, storage) = await start(t, count: 40);
      expect(find.byType(AdaptiveCollectionScaffold), findsNothing);
      expect(
        find.byType(BackButton),
        desktopManager ? findsNothing : findsOneWidget,
      );
      final list = find.byKey(const PageStorageKey('calendar-manager-list'));
      final scrollable = find.descendant(
        of: list,
        matching: find.byType(Scrollable),
      );
      await t.scrollUntilVisible(
        k('calendar-manager-tile-category-20'),
        300,
        scrollable: scrollable,
      );
      await t.pumpAndSettle();
      final before = t.state<ScrollableState>(scrollable).position.pixels;
      final savedBefore = storage.saves;
      final original = p.generalSchedules[20];
      await rename(t, original.id);
      expect(
        find.byType(SkedTaskDialog),
        desktopManager ? findsNWidgets(2) : findsOneWidget,
      );
      expect(
        find.byType(BackButton),
        desktopManager ? findsNothing : findsOneWidget,
      );
      expect(t.getSize(dialogSurface).width, lessThanOrEqualTo(440));
      expect(t.widget<FilledButton>(saveButton).onPressed, isNull);
      await t.enterText(k('rename-calendar-field'), '  Updated category  ');
      await t.pump();
      for (final size in [const Size(360, 800), const Size(1280, 800)]) {
        t.view.physicalSize = size;
        await t.pumpAndSettle();
        expect(
          t.widget<TextField>(k('rename-calendar-field')).controller!.text,
          '  Updated category  ',
        );
        expect(
          find.byType(SkedTaskDialog),
          desktopManager ? findsNWidgets(2) : findsOneWidget,
        );
        expect(t.takeException(), isNull);
      }
      await t.testTextInput.receiveAction(TextInputAction.done);
      await t.pumpAndSettle();
      expect(k('calendar-name-dialog'), findsNothing);
      expect(
        find.byType(BackButton),
        desktopManager ? findsNothing : findsOneWidget,
      );
      expect(p.generalSchedules[20].name, 'Updated category');
      expect(p.generalSchedules[20].id, original.id);
      expect(p.generalSchedules[20].isVisible, original.isVisible);
      expect(storage.saves, savedBefore + 1);
      expect(
        t.state<ScrollableState>(scrollable).position.pixels,
        closeTo(before, 1),
      );
      expect(
        k('calendar-manager-tile-category-20').hitTestable(),
        findsOneWidget,
      );
      await t.tap(
        desktopManager ? k('floating-form-close') : find.byType(BackButton),
      );
      await t.pumpAndSettle();
      expect(list, findsNothing);
      expect(t.takeException(), isNull);
    },
    variant: platforms,
  );

  testWidgets(
    'new category stays a draft until saved and cancellation leaves no placeholder',
    (t) async {
      viewport(t, const Size(1100, 800));
      final (p, storage) = await start(t);
      final savedBefore = storage.saves;
      final original = p.generalSchedules.single.id;
      await t.tap(addButton);
      await t.pumpAndSettle();
      expect(t.widget<FilledButton>(saveButton).onPressed, isNull);
      expect(p.generalSchedules, hasLength(1));
      await t.tap(cancelButton);
      await t.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(storage.saves, savedBefore);
      await t.tap(addButton);
      await t.pumpAndSettle();
      await t.enterText(k('add-calendar-field'), 'Abandoned draft');
      await t.pump();
      await t.tap(cancelButton);
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'Discard and exit'));
      await t.pumpAndSettle();
      expect(p.generalSchedules.single.id, original);
      expect(storage.saves, savedBefore);
      await t.tap(addButton);
      await t.pumpAndSettle();
      await t.enterText(k('add-calendar-field'), '   ');
      await t.pump();
      expect(t.widget<FilledButton>(saveButton).onPressed, isNull);
      await t.enterText(k('add-calendar-field'), '  Confirmed category  ');
      await t.pump();
      await t.tap(saveButton);
      await t.pumpAndSettle();
      expect(k('calendar-name-dialog'), findsNothing);
      expect(p.generalSchedules, hasLength(2));
      expect(p.generalSchedules.last.name, 'Confirmed category');
      expect(storage.saves, savedBefore + 1);
      expect(
        find.descendant(
          of: k('calendar-manager-tile-${p.generalSchedules.last.id}'),
          matching: find.text('Confirmed category'),
        ),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    },
    variant: platforms,
  );

  testWidgets(
    'failed creation retains the name and retry creates exactly one category',
    (t) async {
      viewport(t, const Size(1100, 800));
      final (p, storage) = await start(t);
      final savedBefore = storage.saves;
      await t.tap(addButton);
      await t.pumpAndSettle();
      await t.enterText(k('add-calendar-field'), 'Retry category');
      await t.pump();
      storage.saveError = StateError('test save failure');
      await t.tap(saveButton);
      await t.pumpAndSettle();
      expect(p.generalSchedules, hasLength(1));
      expect(
        t.widget<TextField>(k('add-calendar-field')).controller!.text,
        'Retry category',
      );
      expect(find.text('Save failed. Please try again later.'), findsOneWidget);
      await t.tap(saveButton);
      await t.pumpAndSettle();
      expect(k('calendar-name-dialog'), findsNothing);
      expect(p.generalSchedules, hasLength(2));
      expect(p.generalSchedules.last.name, 'Retry category');
      expect(storage.saves, savedBefore + 2);
      expect(t.takeException(), isNull);
    },
    variant: platforms,
  );

  testWidgets(
    'a pending rename blocks repeated save, Escape, barrier and workspace disable',
    (t) async {
      viewport(t, const Size(1100, 800));
      final (p, storage) = await start(t);
      final savedBefore = storage.saves;
      await rename(t, 'category-0');
      await t.enterText(k('rename-calendar-field'), 'Saved once');
      await t.pump();
      final submit = t
          .widget<TextField>(k('rename-calendar-field'))
          .onSubmitted!;
      storage.pending = Completer<void>();
      submit('Saved once');
      submit('Saved once');
      await t.pump();
      expect(storage.saves, savedBefore + 1);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pump();
      await t.binding.handlePopRoute();
      await t.pump();
      await t.tapAt(const Offset(10, 200));
      await t.pump();
      await p.setWorkspaceEnabled(AppMode.general, false);
      await t.pump();
      expect(p.isWorkspaceEnabled(AppMode.general), isTrue);
      expect(k('rename-calendar-field'), findsOneWidget);
      expect(t.widget<FilledButton>(saveButton).onPressed, isNull);
      expect(t.widget<TextButton>(cancelButton).onPressed, isNull);
      if (k('floating-form-close').evaluate().isNotEmpty) {
        expect(
          t.widget<IconButton>(k('floating-form-close').last).onPressed,
          isNull,
        );
      }
      storage.pending!.complete();
      await t.pumpAndSettle();
      expect(k('calendar-name-dialog'), findsNothing);
      expect(p.generalSchedules.single.name, 'Saved once');
      expect(storage.saves, savedBefore + 1);
      expect(t.takeException(), isNull);
    },
    variant: platforms,
  );

  testWidgets(
    'Escape and workspace disable preserve an unsaved name until discard is confirmed',
    (t) async {
      viewport(t, const Size(1100, 800));
      final (p, storage) = await start(t);
      final savedBefore = storage.saves;
      await rename(t, 'category-0');
      await t.enterText(k('rename-calendar-field'), 'Unsaved rename');
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(
        find.byType(AlertDialog),
        findsNWidgets(
          Theme.of(t.element(k('calendar-name-dialog'))).platform ==
                  TargetPlatform.windows
              ? 1
              : 2,
        ),
      );
      await t.tap(cancelButton.last);
      await t.pumpAndSettle();
      expect(
        t.widget<TextField>(k('rename-calendar-field')).controller!.text,
        'Unsaved rename',
      );
      var finished = false;
      final disabling = p
          .setWorkspaceEnabled(AppMode.general, false)
          .then((_) => finished = true);
      await t.pumpAndSettle();
      expect(finished, isFalse);
      expect(
        find.byType(AlertDialog),
        findsNWidgets(
          Theme.of(t.element(k('calendar-name-dialog'))).platform ==
                  TargetPlatform.windows
              ? 1
              : 2,
        ),
      );
      await t.tap(find.widgetWithText(FilledButton, 'Discard and exit'));
      await t.pumpAndSettle();
      await disabling;
      expect(p.isWorkspaceEnabled(AppMode.general), isFalse);
      expect(k('calendar-name-dialog'), findsNothing);
      expect(
        find.byKey(const PageStorageKey('calendar-manager-list')),
        findsNothing,
      );
      expect(p.generalSchedules.single.name, 'Category 0');
      expect(storage.saves, savedBefore + 1);
      expect(t.takeException(), isNull);
    },
    variant: platforms,
  );

  testWidgets(
    'sidebar add opens one draft dialog and cancel leaves the original categories',
    (t) async {
      viewport(t, const Size(1440, 900));
      final (p, storage) = await start(t);
      final savedBefore = storage.saves;
      await t.tap(k('floating-form-close'));
      await t.pumpAndSettle();
      final add = k('general-resource-add');
      await t.tap(add);
      await t.tap(add, warnIfMissed: false);
      await t.pumpAndSettle();
      expect(k('add-calendar-field'), findsOneWidget);
      expect(
        find.byType(SkedTaskDialog),
        desktopManager ? findsNWidgets(2) : findsOneWidget,
      );
      expect(p.generalSchedules, hasLength(1));
      expect(storage.saves, savedBefore);
      await t.tap(cancelButton);
      await t.pumpAndSettle();
      expect(k('calendar-name-dialog'), findsNothing);
      expect(
        find.byKey(const PageStorageKey('calendar-manager-list')),
        findsNothing,
      );
      expect(p.generalSchedules, hasLength(1));
      expect(storage.saves, savedBefore);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  for (final direction in TextDirection.values) {
    testWidgets(
      'name dialog fits 320dp, large text and keyboard in $direction',
      (t) async {
        viewport(t, const Size(320, 640));
        final (p, _) = await start(t, scale: 2, direction: direction);
        t.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
        t.view.padding = const FakeViewPadding(top: 24);
        t.view.viewInsets = const FakeViewPadding(bottom: 240);
        addTearDown(t.view.resetViewPadding);
        addTearDown(t.view.resetPadding);
        addTearDown(t.view.resetViewInsets);
        await rename(t, 'category-0');
        expect(
          Directionality.of(t.element(k('calendar-name-dialog'))),
          direction,
        );
        final dialog = t.getRect(dialogSurface);
        expect(dialog.left, greaterThanOrEqualTo(16));
        expect(dialog.right, lessThanOrEqualTo(304));
        expect(dialog.bottom, lessThanOrEqualTo(400));
        await t.enterText(
          k('rename-calendar-field'),
          'A long but editable category name',
        );
        await t.pump();
        await t.ensureVisible(saveButton);
        await t.pumpAndSettle();
        expect(saveButton.hitTestable(), findsOneWidget);
        await t.tap(saveButton);
        await t.pumpAndSettle();
        expect(k('calendar-name-dialog'), findsNothing);
        expect(
          p.generalSchedules.single.name,
          'A long but editable category name',
        );
        expect(t.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }
  for (final fail in [false, true]) {
    testWidgets(
      'pending deletion rejects workspace exit and replacement; failure=$fail',
      (t) async {
        viewport(t, const Size(1280, 800));
        final (p, storage) = await start(t, count: 2);
        final backup = await p.exportAppDataJson();
        final originalSession = p.dataSessionToken;
        final savesBefore = storage.saves;
        await t.tap(k('calendar-actions-category-0'));
        await t.pumpAndSettle();
        await t.tap(find.text('Delete'));
        await t.pumpAndSettle();
        final submit = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Delete'),
        );
        final gate = Completer<void>();
        storage.pending = gate;
        if (fail) {
          storage.saveError = StateError('Expected review delete failure');
        }
        await t.tap(submit);
        await t.pump();
        await t.pump(const Duration(milliseconds: 100));
        expect(storage.saves, savesBefore + 1);
        await t.tap(submit);
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await t.pump();
        await p.setWorkspaceEnabled(AppMode.general, false);
        await expectLater(
          p.importAppDataJson(backup, mode: AppImportMode.replaceAll),
          throwsA(isA<WorkspaceChangeCancelledException>()),
        );
        expect(storage.saves, savesBefore + 1);
        expect(p.isWorkspaceEnabled(AppMode.general), isTrue);
        expect(p.dataSessionToken, same(originalSession));
        expect(find.byType(AlertDialog), findsOneWidget);
        gate.complete();
        await t.pumpAndSettle();
        expect(
          storage.data.generalMode.schedules.any((s) => s.id == 'category-0'),
          fail,
        );
        expect(p.generalSchedules.any((s) => s.id == 'category-0'), fail);
        expect(p.isWorkspaceEnabled(AppMode.general), isTrue);
        if (fail) {
          expect(find.byType(AlertDialog), findsOneWidget);
          await t.tap(k('ui-command-failure-dismiss'));
          await t.pumpAndSettle();
          storage.pending = null;
          await t.tap(submit);
          await t.pumpAndSettle();
          expect(p.generalSchedules.any((s) => s.id == 'category-0'), isFalse);
        }
        expect(find.byType(AlertDialog), findsNothing);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      },
      variant: platforms,
    );
  }
}
