import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/theme/sked_expressive_theme.dart';
import 'package:sked/widgets/sked_menu_surface.dart';
import 'package:sked/widgets/sked_popup_menu.dart';

void main() {
  Future<void> mount(
    WidgetTester tester, {
    required int count,
    bool reduced = false,
    bool disabled = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => SkedMotionPolicyScope(
          disableAnimations: disabled,
          reduceMotion: reduced,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: disabled),
            child: child!,
          ),
        ),
        home: Scaffold(
          body: Center(
            child: SkedPopupMenuButton<int>(
              itemBuilder: (_) => [
                for (var i = 0; i < count; i++)
                  SkedPopupMenuItem(value: i, child: Text('Option $i')),
              ],
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pump();
  }

  double opacity(WidgetTester tester) => tester
      .widget<Opacity>(
        find
            .descendant(
              of: find.byType(SkedMenuSurface),
              matching: find.byType(Opacity),
            )
            .first,
      )
      .opacity;

  double scale(WidgetTester tester) => tester
      .widget<Transform>(
        find
            .descendant(
              of: find.byType(SkedMenuSurface),
              matching: find.byType(Transform),
            )
            .first,
      )
      .transform
      .entry(0, 0);

  for (final count in [2, 5, 12]) {
    testWidgets('$count popup items share the complete 240ms entrance', (
      tester,
    ) async {
      await mount(tester, count: count);
      expect(opacity(tester), 0);
      expect(scale(tester), closeTo(.96, .0001));
      await tester.pump(const Duration(milliseconds: 40));
      final at40 = Curves.easeOutCubic.transform(40 / 240);
      expect(opacity(tester), closeTo(at40, .0001));
      expect(scale(tester), closeTo(.96 + .04 * at40, .0001));
      await tester.pump(const Duration(milliseconds: 80));
      expect(
        opacity(tester),
        closeTo(Curves.easeOutCubic.transform(.5), .0001),
      );
      await tester.pump(const Duration(milliseconds: 120));
      expect(opacity(tester), 1);
      expect(scale(tester), 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('popup closes in 140ms and immediately disables its contents', (
    tester,
  ) async {
    await mount(tester, count: 5);
    await tester.pumpAndSettle();
    final menuContext = tester.element(find.byType(SkedMenuSurface));
    Navigator.of(menuContext).pop();
    await tester.pump();
    expect(find.text('Option 0').hitTestable(), findsNothing);
    await tester.pump(const Duration(milliseconds: 70));
    expect(opacity(tester), greaterThan(0));
    expect(opacity(tester), lessThan(1));
    await tester.pump(const Duration(milliseconds: 70));
    expect(opacity(tester), closeTo(0, .0001));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(find.byType(SkedMenuSurface), findsNothing);
  });

  testWidgets('reduced motion uses a 120ms fade without scaling', (
    tester,
  ) async {
    await mount(tester, count: 5, reduced: true);
    expect(opacity(tester), 0);
    expect(scale(tester), 1);
    await tester.pump(const Duration(milliseconds: 60));
    expect(opacity(tester), closeTo(Curves.easeOutCubic.transform(.5), .0001));
    expect(scale(tester), 1);
    await tester.pump(const Duration(milliseconds: 60));
    expect(opacity(tester), 1);
  });

  testWidgets('disabled animations present the popup immediately', (
    tester,
  ) async {
    await mount(tester, count: 5, disabled: true);
    expect(opacity(tester), 1);
    expect(scale(tester), 1);
    await tester.tap(find.text('Option 2'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(SkedMenuSurface), findsNothing);
  });

  testWidgets('a closing item cannot dismiss a newer route', (tester) async {
    await mount(tester, count: 2);
    await tester.pumpAndSettle();
    final item = find
        .ancestor(of: find.text('Option 0'), matching: find.byType(InkWell))
        .first;
    final lateTap = tester.widget<InkWell>(item).onTap!;
    final navigator = Navigator.of(tester.element(item));
    navigator.pop();
    await tester.pump();
    unawaited(
      navigator.push<void>(
        MaterialPageRoute(
          builder: (_) => const Scaffold(body: Text('Newer page')),
        ),
      ),
    );
    await tester.pump();
    lateTap();
    await tester.pumpAndSettle();
    expect(find.text('Newer page'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
