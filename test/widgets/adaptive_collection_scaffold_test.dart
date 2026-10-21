import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/widgets/adaptive_collection_scaffold.dart';
import 'package:sked/widgets/expressive_dialog.dart';

import '../support/semantics_update_audit.dart';
import '../support/workspace_harness.dart';

class _AuditedBinding extends AutomatedTestWidgetsFlutterBinding {
  final audit = SemanticsUpdateAudit();

  @override
  ui.SemanticsUpdateBuilder createSemanticsUpdateBuilder() =>
      audit.createBuilder();
}

class _DraftDetail extends StatefulWidget {
  const _DraftDetail(this.id);

  final String id;

  @override
  State<_DraftDetail> createState() => _DraftDetailState();
}

class _DraftDetailState extends State<_DraftDetail> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: TextField(
      key: const ValueKey('collection-detail-draft'),
      controller: controller,
    ),
  );
}

Widget _collection(void Function(int) onBuild) => AdaptiveCollectionScaffold(
  title: 'Time sets',
  items: List.generate(
    100,
    (index) => CollectionItem(
      id: '$index',
      title: 'Set $index',
      tileBuilder: (selected, open) {
        onBuild(index);
        return ExpressiveDialogOption(
          key: ValueKey('collection-row-$index'),
          selected: selected,
          title: Text('Set $index'),
          subtitle: const Text('12 periods, used by 1 timetable'),
          onTap: open,
        );
      },
    ),
  ),
  detailBuilder: _DraftDetail.new,
);

void main() {
  final binding = _AuditedBinding();
  setUp(binding.audit.reset);

  for (final width in [390.0, 1280.0]) {
    testWidgets('collection builds only viewport items at width $width', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final app = await workspaceProvider();
      addTearDown(app.dispose);
      final semantics = tester.ensureSemantics();
      try {
        final built = <int>[];
        await tester.pumpWidget(
          WorkspaceHarness(provider: app, home: _collection(built.add)),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ListView, skipOffstage: false), findsOneWidget);
        expect(built.length, lessThan(30));
        expect(built, contains(0));
        expect(built, isNot(contains(99)));
        final list = find.byType(ListView);
        final controller = tester.widget<ListView>(list).controller!;
        final viewport = tester.getRect(list);
        var visibleRows = 0;
        for (final element in find.byType(ExpressiveDialogOption).evaluate()) {
          if (tester
              .getRect(find.byWidget(element.widget))
              .overlaps(viewport)) {
            visibleRows++;
          }
        }
        expect(built.length, greaterThanOrEqualTo(visibleRows));

        built.clear();
        await tester.tap(find.byKey(const ValueKey('collection-row-0')));
        await tester.pumpAndSettle();
        expect(built.length, lessThan(30));
        expect(find.byType(_DraftDetail), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('period-time-set-manager-back')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(_DraftDetail), findsNothing);
        expect(find.byType(ListView, skipOffstage: false), findsOneWidget);
        await tester.dragUntilVisible(
          find.byKey(const ValueKey('collection-row-99')),
          find.byType(ListView),
          const Offset(0, -600),
          maxIteration: 30,
        );
        await tester.pumpAndSettle();
        expect(built, contains(99));
        expect(controller.offset, greaterThan(0));
        expect(binding.audit.errors, isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  }

  testWidgets(
    'collection retains one scrolled list and the detail draft across reflow',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final app = await workspaceProvider();
      addTearDown(app.dispose);
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          WorkspaceHarness(provider: app, home: _collection((_) {})),
        );
        await tester.pumpAndSettle();
        final list = find.byType(ListView, skipOffstage: false);
        final listElement = tester.element(list);
        final controller = tester.widget<ListView>(list).controller!;
        controller.jumpTo(600);
        await tester.pumpAndSettle();
        await tester.tap(
          find.byType(ExpressiveDialogOption).hitTestable().first,
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('collection-detail-draft')),
          'Draft retained across widths',
        );
        await tester.pump();
        final detailState = tester.state(find.byType(_DraftDetail));

        for (final width in [390.0, 1280.0, 390.0]) {
          tester.view.physicalSize = Size(width, 800);
          await tester.pumpAndSettle();
          expect(list, findsOneWidget);
          expect(tester.element(list), same(listElement));
          expect(tester.widget<ListView>(list).controller, same(controller));
          expect(controller.positions, hasLength(1));
          expect(controller.offset, closeTo(600, 1));
          expect(tester.state(find.byType(_DraftDetail)), same(detailState));
          expect(find.text('Draft retained across widths'), findsOneWidget);
        }
        await tester.tap(
          find.byKey(const ValueKey('period-time-set-manager-back')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(_DraftDetail), findsNothing);
        expect(find.byType(ListView), findsOneWidget);
        expect(tester.element(list), same(listElement));
        expect(controller.offset, closeTo(600, 1));
        expect(binding.audit.updateCount, greaterThan(0));
        expect(binding.audit.errors, isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'compact details exclude retained list focus and restore it on return',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final app = await workspaceProvider();
      addTearDown(app.dispose);
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          WorkspaceHarness(provider: app, home: _collection((_) {})),
        );
        await tester.pumpAndSettle();
        final list = find.byType(ListView, skipOffstage: false);
        final listElement = tester.element(list);
        final controller = tester.widget<ListView>(list).controller!;
        final firstRowFocus = Focus.of(tester.element(find.text('Set 0')));
        final secondRowFocus = Focus.of(tester.element(find.text('Set 1')));
        firstRowFocus.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        final detailState = tester.state(find.byType(_DraftDetail));
        expect(tester.widget<_DraftDetail>(find.byType(_DraftDetail)).id, '0');
        expect(firstRowFocus.hasPrimaryFocus, isTrue);

        for (final width in [390.0, 1280.0, 390.0]) {
          tester.view.physicalSize = Size(width, 800);
          await tester.pumpAndSettle();
          expect(tester.element(list), same(listElement));
          expect(tester.widget<ListView>(list).controller, same(controller));
          expect(controller.positions, hasLength(1));
          expect(tester.state(find.byType(_DraftDetail)), same(detailState));
          expect(firstRowFocus.canRequestFocus, width == 1280);
          expect(secondRowFocus.canRequestFocus, width == 1280);
          if (width == 390) {
            expect(firstRowFocus.hasPrimaryFocus, isFalse);
            for (var index = 0; index < 6; index++) {
              await tester.sendKeyEvent(LogicalKeyboardKey.tab);
              await tester.pumpAndSettle();
              expect(firstRowFocus.hasPrimaryFocus, isFalse);
              expect(secondRowFocus.hasPrimaryFocus, isFalse);
            }
          }
        }

        final detailFocus = tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode;
        detailFocus.requestFocus();
        await tester.pump();
        secondRowFocus.requestFocus();
        await tester.pump();
        expect(detailFocus.hasPrimaryFocus, isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(tester.state(find.byType(_DraftDetail)), same(detailState));
        expect(tester.widget<_DraftDetail>(find.byType(_DraftDetail)).id, '0');

        await tester.tap(
          find.byKey(const ValueKey('period-time-set-manager-back')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(_DraftDetail), findsNothing);
        expect(tester.element(list), same(listElement));
        expect(firstRowFocus.canRequestFocus, isTrue);
        firstRowFocus.requestFocus();
        await tester.pump();
        expect(firstRowFocus.hasPrimaryFocus, isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(secondRowFocus.hasPrimaryFocus, isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(tester.widget<_DraftDetail>(find.byType(_DraftDetail)).id, '1');
        expect(secondRowFocus.hasPrimaryFocus, isFalse);
        expect(secondRowFocus.canRequestFocus, isFalse);
        expect(binding.audit.errors, isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'removing a compact selection re-enables the retained list focus',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final app = await workspaceProvider();
      addTearDown(app.dispose);
      final semantics = tester.ensureSemantics();
      final ids = ValueNotifier(['0', '1', '2']);
      addTearDown(ids.dispose);
      try {
        await tester.pumpWidget(
          WorkspaceHarness(
            provider: app,
            home: ValueListenableBuilder(
              valueListenable: ids,
              builder: (context, ids, _) => AdaptiveCollectionScaffold(
                title: 'Time sets',
                items: [
                  for (final id in ids)
                    CollectionItem(id: id, title: 'Set $id'),
                ],
                detailBuilder: _DraftDetail.new,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final list = find.byType(ListView, skipOffstage: false);
        final listElement = tester.element(list);
        final retainedFocus = Focus.of(tester.element(find.text('Set 1')));
        final firstFocus = Focus.of(tester.element(find.text('Set 0')));
        firstFocus.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        tester.view.physicalSize = const Size(390, 800);
        await tester.pumpAndSettle();
        expect(retainedFocus.canRequestFocus, isFalse);

        ids.value = ['1', '2'];
        await tester.pumpAndSettle();
        expect(find.byType(_DraftDetail), findsNothing);
        expect(tester.element(list), same(listElement));
        expect(retainedFocus.canRequestFocus, isTrue);
        retainedFocus.requestFocus();
        await tester.pump();
        expect(retainedFocus.hasPrimaryFocus, isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(tester.widget<_DraftDetail>(find.byType(_DraftDetail)).id, '1');
        expect(retainedFocus.canRequestFocus, isFalse);
        expect(binding.audit.errors, isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
