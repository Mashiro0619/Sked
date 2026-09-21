import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/widgets/adaptive_collection_scaffold.dart';

import '../support/workspace_harness.dart';

Finder k(String id) => find.byKey(ValueKey(id));
Finder get dialogSurface => find.descendant(
  of: k('calendar-name-dialog'),
  matching: find.byWidgetPredicate(
    (widget) => widget is Material && widget.type == MaterialType.card,
  ),
);
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
      expect(find.byType(BackButton), findsOneWidget);
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
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
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
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(t.takeException(), isNull);
      }
      await t.testTextInput.receiveAction(TextInputAction.done);
      await t.pumpAndSettle();
      expect(k('calendar-name-dialog'), findsNothing);
      expect(find.byType(BackButton), findsOneWidget);
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
      await t.tap(find.byType(BackButton));
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
      await t.tap(find.byTooltip('Add category'));
      await t.pumpAndSettle();
      expect(t.widget<FilledButton>(saveButton).onPressed, isNull);
      expect(p.generalSchedules, hasLength(1));
      await t.tap(cancelButton);
      await t.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(storage.saves, savedBefore);
      await t.tap(find.byTooltip('Add category'));
      await t.pumpAndSettle();
      await t.enterText(k('add-calendar-field'), 'Abandoned draft');
      await t.pump();
      await t.tap(cancelButton);
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'Discard and exit'));
      await t.pumpAndSettle();
      expect(p.generalSchedules.single.id, original);
      expect(storage.saves, savedBefore);
      await t.tap(find.byTooltip('Add category'));
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
      expect(find.text('Confirmed category'), findsOneWidget);
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
      await t.tap(find.byTooltip('Add category'));
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
      expect(find.byType(AlertDialog), findsNWidgets(2));
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
      expect(find.byType(AlertDialog), findsNWidgets(2));
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
      await t.tap(find.byType(BackButton));
      await t.pumpAndSettle();
      final add = k('general-resource-add');
      await t.tap(add);
      await t.tap(add, warnIfMissed: false);
      await t.pumpAndSettle();
      expect(k('add-calendar-field'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(p.generalSchedules, hasLength(1));
      expect(storage.saves, savedBefore);
      await t.tap(cancelButton);
      await t.pumpAndSettle();
      expect(k('calendar-name-dialog'), findsNothing);
      expect(
        find.byKey(const PageStorageKey('calendar-manager-list')),
        findsOneWidget,
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
}
