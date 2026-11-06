import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/theme/app_theme.dart';
import 'package:sked/widgets/sked_popup_menu.dart';
import 'package:sked/widgets/sked_tooltip.dart';

Widget _view(Widget child) => MaterialApp(
  theme: buildAppTheme(
    seedColor: const Color(0xff336699),
    brightness: Brightness.light,
    themeColorMode: 'solid',
    colorfulUiColorValues: const {},
  ),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  const target = ValueKey('tooltip-source');
  const message = 'Helpful hint';

  for (final kind in ['plain', 'wrapped', 'icon', 'popup']) {
    testWidgets('$kind tooltip waits for sustained mouse hover', (
      tester,
    ) async {
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      final Widget control = switch (kind) {
        'plain' => const Tooltip(
          message: message,
          child: SizedBox(key: target, width: 80, height: 48),
        ),
        'wrapped' => const SkedTooltip(
          message: message,
          child: SizedBox(key: target, width: 80, height: 48),
        ),
        'icon' => IconButton(
          key: target,
          tooltip: message,
          onPressed: () {},
          icon: const Icon(Icons.add),
        ),
        _ => SkedPopupMenuButton<int>(
          key: target,
          tooltip: message,
          itemBuilder: (_) => const [
            SkedPopupMenuItem(value: 1, child: Text('Item')),
          ],
          child: const SizedBox(
            width: 80,
            height: 48,
            child: Icon(Icons.more_horiz),
          ),
        ),
      };
      try {
        await tester.pumpWidget(_view(control));
        await tester.pumpAndSettle();
        await mouse.addPointer(location: const Offset(0, 0));
        await mouse.moveTo(tester.getCenter(find.byKey(target)));
        await tester.pump(const Duration(milliseconds: 599));
        expect(find.text(message), findsNothing);
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump(const Duration(milliseconds: 150));
        expect(find.text(message), findsOneWidget);
      } finally {
        await mouse.removePointer();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  }

  testWidgets('passing over buttons cancels each pending tooltip', (
    tester,
  ) async {
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    try {
      await tester.pumpWidget(
        _view(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final name in ['First', 'Second'])
                IconButton(
                  key: ValueKey(name),
                  tooltip: '$name hint',
                  onPressed: () {},
                  icon: const Icon(Icons.add),
                ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await mouse.addPointer(location: const Offset(0, 0));
      await mouse.moveTo(tester.getCenter(find.byKey(const ValueKey('First'))));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('First hint'), findsNothing);
      await mouse.moveTo(
        tester.getCenter(find.byKey(const ValueKey('Second'))),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Second hint'), findsNothing);
      await mouse.moveTo(const Offset(0, 0));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('First hint'), findsNothing);
      expect(find.text('Second hint'), findsNothing);
      await mouse.moveTo(
        tester.getCenter(find.byKey(const ValueKey('Second'))),
      );
      await tester.pump(const Duration(milliseconds: 599));
      expect(find.text('Second hint'), findsNothing);
      await tester.pump(const Duration(milliseconds: 151));
      expect(find.text('Second hint'), findsOneWidget);
    } finally {
      await mouse.removePointer();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('clicking during the hover wait keeps the action immediate', (
    tester,
  ) async {
    var presses = 0;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    try {
      await tester.pumpWidget(
        _view(
          IconButton(
            key: target,
            tooltip: message,
            onPressed: () => presses++,
            icon: const Icon(Icons.add),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await mouse.addPointer(location: const Offset(0, 0));
      await mouse.moveTo(tester.getCenter(find.byKey(target)));
      await tester.pump(const Duration(milliseconds: 300));
      await mouse.down(tester.getCenter(find.byKey(target)));
      await mouse.up();
      expect(presses, 1);
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.text(message), findsNothing);
      await mouse.moveTo(const Offset(0, 0));
      await tester.pump(const Duration(milliseconds: 200));
      await mouse.moveTo(tester.getCenter(find.byKey(target)));
      await tester.pump(const Duration(milliseconds: 599));
      expect(find.text(message), findsNothing);
      await tester.pump(const Duration(milliseconds: 151));
      expect(find.text(message), findsOneWidget);
      await mouse.down(tester.getCenter(find.byKey(target)));
      await mouse.up();
      expect(presses, 2);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text(message), findsNothing);
      await mouse.moveTo(const Offset(0, 0));
      await tester.pump(const Duration(milliseconds: 200));
      await mouse.moveTo(tester.getCenter(find.byKey(target)));
      await tester.pump(const Duration(milliseconds: 599));
      expect(find.text(message), findsNothing);
      await tester.pump(const Duration(milliseconds: 151));
      expect(find.text(message), findsOneWidget);
    } finally {
      await mouse.removePointer();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets(
    'touch long press and accessible tooltip labels remain available',
    (tester) async {
      final semantics = tester.ensureSemantics();
      var presses = 0;
      try {
        await tester.pumpWidget(
          _view(
            IconButton(
              key: target,
              tooltip: message,
              onPressed: () => presses++,
              icon: const Icon(Icons.add),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getSemantics(find.byKey(target)).getSemanticsData().tooltip,
          message,
        );
        expect(find.text(message), findsNothing);
        await tester.longPress(find.byKey(target));
        await tester.pumpAndSettle();
        expect(find.text(message), findsOneWidget);
        expect(presses, 0);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        semantics.dispose();
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
