import 'package:sked/widgets/sked_floating_surface.dart';
import 'package:sked/widgets/sked_task_dialog.dart';
import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/widgets/sked_panel_header.dart';

void main() {
  for (final direction in TextDirection.values) {
    testWidgets(
      'short task header scrolls its full title while actions stay fixed: $direction',
      (t) async {
        var drags = 0, adds = 0, closes = 0;
        await t.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: Directionality(textDirection: direction, child: child!),
            ),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 520,
                  height: 240,
                  child: SkedTaskDialogScope(
                    onDragUpdate: (_) => drags++,
                    onClose: () => closes++,
                    child: SkedTaskDialog(
                      title: const Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Manage categories with a long title that remains '
                            'fully readable when the window is short',
                          ),
                          Text('Tail', key: ValueKey('title-tail')),
                        ],
                      ),
                      titleBottom: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton.icon(
                          key: const ValueKey('header-add'),
                          onPressed: () => adds++,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add category'),
                        ),
                      ),
                      content: const Text('Category list'),
                      actions: [
                        TextButton(
                          onPressed: () {},
                          child: const Text('Import'),
                        ),
                        TextButton(
                          onPressed: () {},
                          child: const Text('Export'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        final header = t.getRect(find.byType(SkedPanelHeader));
        final add = find.byKey(const ValueKey('header-add'));
        final close = find.byKey(const ValueKey('floating-form-close'));
        final controls = [add, close];
        final positions = controls.map(t.getRect).toList();
        void expectFixedControls() {
          for (var index = 0; index < controls.length; index++) {
            final control = controls[index];
            final rect = t.getRect(control);
            expect(rect, positions[index]);
            expect(rect.left, greaterThanOrEqualTo(header.left));
            expect(rect.right, lessThanOrEqualTo(header.right));
            expect(rect.top, greaterThanOrEqualTo(header.top));
            expect(rect.bottom, lessThanOrEqualTo(header.bottom));
            expect(control.hitTestable(), findsOneWidget);
          }
        }

        expectFixedControls();
        final titleScroll = find
            .ancestor(
              of: find.byKey(const ValueKey('title-tail')),
              matching: find.byType(Scrollable),
            )
            .first;
        final position = t.state<ScrollableState>(titleScroll).position;
        expect(position.maxScrollExtent, greaterThan(0));
        await t.sendEventToBinding(
          PointerScrollEvent(
            kind: PointerDeviceKind.mouse,
            position: t.getCenter(titleScroll),
            scrollDelta: const Offset(0, 10000),
          ),
        );
        await t.pumpAndSettle();
        expect(position.pixels, closeTo(position.maxScrollExtent, .01));
        final tail = t.getRect(find.byKey(const ValueKey('title-tail')));
        final viewport = t.getRect(titleScroll);
        expect(tail.top, greaterThanOrEqualTo(viewport.top - .01));
        expect(tail.bottom, lessThanOrEqualTo(viewport.bottom + .01));
        expectFixedControls();
        expect(drags, 0);

        await t.tap(add);
        await t.tap(close);
        expect(adds, 1);
        expect(closes, 1);
        expect(drags, 0);
        await t.drag(titleScroll, const Offset(32, 18));
        expect(drags, greaterThan(0));
        expectFixedControls();
        expect(t.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }

  for (final height in <double?>[null, 20]) {
    testWidgets(
      'scrollable task titles handle unbounded and sub-control heights: $height',
      (t) async {
        final header = SkedPanelHeader(
          scrollableTitle: true,
          title: const Text('A complete title with several lines of text'),
          bottom: TextButton(onPressed: () {}, child: const Text('Add')),
          onClose: () {},
        );
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 240,
                height: height,
                child: height == null
                    ? SingleChildScrollView(child: header)
                    : header,
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(find.text('Add'), findsOneWidget);
        expect(find.byType(SingleChildScrollView), findsOneWidget);
        expect(t.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }

  testWidgets('task header preserves inherited picker drag handle', (t) async {
    var drags = 0;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              height: 300,
              child: SkedFloatingDragScope(
                onDrag: (_) => drags++,
                child: const SkedTaskDialogScope(
                  child: SkedTaskDialog(
                    title: Text('Picker'),
                    content: Text('Content'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final handle = find.byKey(const ValueKey('sked-picker-drag-handle'));
    expect(handle, findsOneWidget);
    await t.drag(handle, const Offset(40, 20));
    expect(drags, greaterThan(0));
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'header drag excludes action buttons; wrapped action and close remain interactive',
    (t) async {
      var drags = 0, actions = 0, closes = 0;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 340,
              child: SkedPanelHeader(
                title: const Text('Title'),
                onDrag: (_) => drags++,
                dragKey: const ValueKey('drag'),
                inlineAction: false,
                action: TextButton(
                  onPressed: () => actions++,
                  child: const Text('Create'),
                ),
                onClose: () => closes++,
                closeKey: const ValueKey('close'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Create'));
      await t.tap(find.byKey(const ValueKey('close')));
      expect(actions, 1);
      expect(closes, 1);
      expect(drags, 0);
      await t.drag(find.byKey(const ValueKey('drag')), const Offset(30, 20));
      expect(drags, greaterThan(0));
    },
  );
  testWidgets('preview header has no close or drag behavior', (t) async {
    await t.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SkedPanelHeader(title: Text('Preview'), showClose: false),
        ),
      ),
    );
    expect(find.byType(IconButton), findsNothing);
    expect(t.takeException(), isNull);
  });
}
