import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/widgets/workbench_resource_widgets.dart';
import 'package:sked/widgets/timetable_information_form.dart';

import '../support/workspace_harness.dart';

Finder key(String value) => find.byKey(ValueKey(value));
Finder edit(String id) => key('resource-timetable-edit-$id');
double opacity(WidgetTester t, String id) =>
    t.widget<Opacity>(key('resource-timetable-edit-visibility-$id')).opacity;

Widget rows({
  TargetPlatform platform = TargetPlatform.windows,
  VoidCallback? onEdit,
  VoidCallback? onSelect,
  bool accessible = false,
  bool reducedMotion = false,
}) => MaterialApp(
  theme: ThemeData(platform: platform),
  locale: const Locale('en'),
  localizationsDelegates: appLocalizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      accessibleNavigation: accessible,
      disableAnimations: reducedMotion,
    ),
    child: child!,
  ),
  home: Scaffold(
    body: Column(
      children: [
        TextButton(onPressed: () {}, child: const Text('Before')),
        SizedBox(
          width: 224,
          child: TimetableResourceRow(
            key: const ValueKey('row-a'),
            timetableId: 'a',
            name: 'Selected timetable',
            selected: true,
            onSelected: onSelect,
            onEdit: onEdit,
          ),
        ),
        SizedBox(
          width: 224,
          child: TimetableResourceRow(
            key: const ValueKey('row-b'),
            timetableId: 'b',
            name: 'Other timetable',
            selected: false,
            onSelected: onSelect,
            onEdit: onEdit,
          ),
        ),
        TextButton(onPressed: () {}, child: const Text('After')),
      ],
    ),
  ),
);

void main() {
  for (final platform in [
    TargetPlatform.windows,
    TargetPlatform.macOS,
    TargetPlatform.linux,
  ]) {
    testWidgets(
      'only the hovered resource shows edit on $platform without moving its name',
      (t) async {
        var edits = 0;
        var selections = 0;
        await t.pumpWidget(
          rows(
            platform: platform,
            onEdit: () => edits++,
            onSelect: () => selections++,
          ),
        );
        await t.pumpAndSettle();
        final name = t.getRect(find.text('Selected timetable'));
        final button = t.getRect(edit('a'));
        expect(opacity(t, 'a'), 0);
        expect(opacity(t, 'b'), 0);
        expect(edit('a').hitTestable(), findsNothing);
        final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: const Offset(1, 1));
        addTearDown(mouse.removePointer);
        await mouse.moveTo(name.center);
        await t.pumpAndSettle();
        expect(opacity(t, 'a'), 1);
        expect(opacity(t, 'b'), 0);
        expect(t.getRect(find.text('Selected timetable')), name);
        expect(t.getRect(edit('a')), button);
        await mouse.moveTo(button.center);
        await t.pumpAndSettle();
        expect(opacity(t, 'a'), 1);
        await mouse.down(button.center);
        await mouse.up();
        await t.pumpAndSettle();
        expect(edits, 1);
        expect(selections, 0);
        FocusManager.instance.primaryFocus?.unfocus();
        await mouse.moveTo(t.getCenter(find.text('Other timetable')));
        await t.pumpAndSettle();
        expect(opacity(t, 'a'), 0);
        expect(opacity(t, 'b'), 1);
        await mouse.moveTo(const Offset(1, 1));
        await t.pumpAndSettle();
        expect(opacity(t, 'a'), 0);
        expect(opacity(t, 'b'), 0);
        expect(t.takeException(), isNull);
      },
    );
  }

  testWidgets('hidden edit is absent from semantics and shown once on hover', (
    t,
  ) async {
    final semantics = t.ensureSemantics();
    try {
      await t.pumpWidget(rows(onEdit: () {}, onSelect: () {}));
      await t.pumpAndSettle();
      int editSemanticsCount() {
        var count = 0;
        void visit(SemanticsNode node) {
          final data = node.getSemanticsData();
          if (data.tooltip == 'Edit timetable' ||
              data.label == 'Edit timetable') {
            count++;
          }
          node.visitChildren((child) {
            visit(child);
            return true;
          });
        }

        visit(
          t
              .binding
              .renderViews
              .single
              .owner!
              .semanticsOwner!
              .rootSemanticsNode!,
        );
        return count;
      }

      expect(editSemanticsCount(), 0);
      final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(
        location: t.getCenter(find.text('Selected timetable')),
      );
      addTearDown(mouse.removePointer);
      await t.pumpAndSettle();
      expect(editSemanticsCount(), 1);
      await mouse.moveTo(const Offset(1, 1));
      await t.pumpAndSettle();
      expect(editSemanticsCount(), 0);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('Tab reveals the focused edit and Enter invokes it', (t) async {
    var edits = 0;
    await t.pumpWidget(rows(onEdit: () => edits++, onSelect: () {}));
    await t.pumpAndSettle();
    Focus.of(t.element(find.text('Before'))).requestFocus();
    await t.pumpAndSettle();
    var reached = false;
    for (var i = 0; i < 8; i++) {
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pumpAndSettle();
      final ctx = FocusManager.instance.primaryFocus?.context;
      final ancestors = <Widget>[];
      ctx?.visitAncestorElements((element) {
        ancestors.add(element.widget);
        return true;
      });
      if (ancestors.any(
        (widget) => widget.key == const ValueKey('resource-timetable-edit-a'),
      )) {
        reached = true;
        break;
      }
    }
    expect(reached, isTrue);
    expect(opacity(t, 'a'), 1);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pumpAndSettle();
    expect(edits, 1);
    Focus.of(t.element(find.text('After'))).requestFocus();
    await t.pumpAndSettle();
    expect(opacity(t, 'a'), 0);
    expect(t.takeException(), isNull);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('touch resource edit stays visible on $platform', (t) async {
      var edits = 0;
      await t.pumpWidget(
        rows(platform: platform, onEdit: () => edits++, onSelect: () {}),
      );
      await t.pumpAndSettle();
      expect(opacity(t, 'a'), 1);
      expect(opacity(t, 'b'), 1);
      await t.tap(edit('a'));
      await t.pumpAndSettle();
      expect(edits, 1);
    });
  }

  testWidgets(
    'accessible navigation exposes edits and disabled action remains disabled',
    (t) async {
      await t.pumpWidget(rows(accessible: true));
      await t.pumpAndSettle();
      expect(opacity(t, 'a'), 1);
      expect(t.widget<IconButton>(edit('a')).onPressed, isNull);
      await t.pumpWidget(rows(onSelect: () {}, reducedMotion: true));
      await t.pumpAndSettle();
      final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(
        location: t.getCenter(find.text('Selected timetable')),
      );
      addTearDown(mouse.removePointer);
      await t.pumpAndSettle();
      expect(opacity(t, 'a'), 1);
      expect(t.widget<IconButton>(edit('a')).onPressed, isNull);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('real workspace row still opens timetable editor on hover', (
    t,
  ) async {
    t.view.physicalSize = const Size(1440, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final p = await workspaceProvider();
    addTearDown(p.dispose);
    await t.pumpWidget(WorkspaceHarness(provider: p));
    await t.pumpAndSettle();
    final id = p.activeTimetable.id;
    expect(opacity(t, id), 0);
    final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(
      location: t.getCenter(key('resource-timetable-$id')),
    );
    addTearDown(mouse.removePointer);
    await t.pumpAndSettle();
    expect(opacity(t, id), 1);
    await t.tap(edit(id));
    await t.pumpAndSettle();
    expect(find.byType(TimetableInformationDialogSurface), findsOneWidget);
    expect(t.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  testWidgets('temporary resource drawer has the same hover edit behavior', (
    t,
  ) async {
    t.view.physicalSize = const Size(1000, 750);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final p = await workspaceProvider();
    addTearDown(p.dispose);
    await t.pumpWidget(WorkspaceHarness(provider: p));
    await t.pumpAndSettle();
    await t.tap(key('workspace-resource-collapse'));
    await t.pumpAndSettle();
    expect(key('workspace-resource-scrim'), findsOneWidget);
    final id = p.activeTimetable.id;
    expect(opacity(t, id), 0);
    final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(
      location: t.getCenter(key('resource-timetable-$id')),
    );
    addTearDown(mouse.removePointer);
    await t.pumpAndSettle();
    expect(opacity(t, id), 1);
    await t.tap(edit(id));
    await t.pumpAndSettle();
    expect(find.byType(TimetableInformationDialogSurface), findsOneWidget);
    expect(t.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
