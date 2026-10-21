import 'dart:ui' as ui;

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
  const _DraftDetail();

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
  detailBuilder: (_) => const _DraftDetail(),
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
}
