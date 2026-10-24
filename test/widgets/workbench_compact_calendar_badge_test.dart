import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/widgets/workbench_compact_calendar_bar.dart';

WorkbenchOverflowAction _action(String id, String label, IconData icon) =>
    WorkbenchOverflowAction(
      id: id,
      label: label,
      icon: icon,
      onSelected: (_) {},
    );

Widget _bar({required int count}) {
  return WorkbenchCompactCalendarBar(
    id: 'general',
    date: _action('date', 'Date', Icons.today),
    shortDateLabel: 'Oct 1',
    previous: _action('previous', 'Previous', Icons.chevron_left),
    next: _action('next', 'Next', Icons.chevron_right),
    today: _action('today', 'Today', Icons.today),
    actions: const [],
    badgeCount: count,
  );
}

Future<void> _pumpBar(WidgetTester tester, {required int count}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1200, 120);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: _bar(count: count)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('hides an empty complete reminder badge', (tester) async {
    await _pumpBar(tester, count: 0);

    final badge = tester.widget<Badge>(find.byType(Badge));
    expect(badge.isLabelVisible, isFalse);
    expect(find.text('0'), findsNothing);
    expect(find.text('0+'), findsNothing);
  });

  testWidgets('shows a complete positive reminder count without plus', (
    tester,
  ) async {
    await _pumpBar(tester, count: 5);

    final badge = tester.widget<Badge>(find.byType(Badge));
    expect(badge.isLabelVisible, isTrue);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('5+'), findsNothing);
    expect(
      tester.getSemantics(find.text('5')).getSemanticsData().label,
      contains('5'),
    );
  });

  testWidgets('shows the full reminder count above the old projection limit', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await _pumpBar(tester, count: 5000);

      final badge = tester.widget<Badge>(find.byType(Badge));
      expect(badge.isLabelVisible, isTrue);
      expect(find.text('5000'), findsOneWidget);
      expect(find.text('5000+'), findsNothing);
      expect(
        tester.getSemantics(find.text('5000')).getSemanticsData().label,
        contains('5000'),
      );
    } finally {
      semantics.dispose();
    }
  });
}
