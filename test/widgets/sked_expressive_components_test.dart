import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/widgets/sked_expressive_components.dart';
import 'package:sked/widgets/sked_expressive_loading_indicator.dart';

void main() {
  testWidgets(
    'expressive segmented button keeps official selection semantics',
    (tester) async {
      Set<String> selected = {'day'};
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Directionality(
                textDirection: TextDirection.rtl,
                child: MediaQuery(
                  data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                  child: SkedExpressiveSegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'day', label: Text('Day')),
                      ButtonSegment(value: 'week', label: Text('Week')),
                    ],
                    selected: selected,
                    onSelectionChanged: (value) =>
                        setState(() => selected = value),
                  ),
                ),
              );
            },
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(SegmentedButton<String>)).height,
        greaterThanOrEqualTo(48),
      );
      await tester.tap(find.text('Week'));
      await tester.pumpAndSettle();
      expect(selected, {'week'});
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'segmented button supports vertical multi-selection and disabled motion',
    (tester) async {
      Set<String> selected = {'day'};
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: StatefulBuilder(
              builder: (context, setState) {
                return SkedExpressiveSegmentedButton<String>(
                  direction: Axis.vertical,
                  multiSelectionEnabled: true,
                  emptySelectionAllowed: true,
                  showSelectedIcon: true,
                  selectedIcon: const Icon(Icons.done),
                  expandedInsets: EdgeInsets.zero,
                  style: const ButtonStyle(
                    padding: WidgetStatePropertyAll(EdgeInsets.zero),
                  ),
                  segments: const [
                    ButtonSegment(value: 'day', label: Text('Day')),
                    ButtonSegment(value: 'week', label: Text('Week')),
                  ],
                  selected: selected,
                  onSelectionChanged: (value) =>
                      setState(() => selected = value),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Week'));
      await tester.pump();
      expect(selected, {'day', 'week'});
      await tester.tap(find.text('Day'));
      await tester.pump();
      expect(selected, {'week'});
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('workspace toolbar reflows its actions on a compact surface', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SkedWorkspaceToolbar(
            title: Text('A long workspace title that must remain readable'),
            subtitle: Text('Current week'),
            actions: [
              IconButton(onPressed: null, icon: Icon(Icons.settings_outlined)),
              IconButton(onPressed: null, icon: Icon(Icons.more_vert)),
            ],
          ),
        ),
      ),
    );
    expect(find.byType(SkedWorkspaceToolbar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'workspace toolbar keeps navigation and actions inline when wide',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SkedWorkspaceToolbar(
              leading: Icon(Icons.school_outlined),
              title: Text('Timetable'),
              subtitle: Text('Current week'),
              navigation: SizedBox(
                height: 48,
                child: Center(child: Text('Navigation')),
              ),
              actions: [
                IconButton(
                  onPressed: null,
                  icon: Icon(Icons.settings_outlined),
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text('Navigation'), findsOneWidget);
      expect(find.byIcon(Icons.school_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('workspace toolbar allows a title-only compact header', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SkedWorkspaceToolbar(
            leading: Icon(Icons.menu),
            title: Text('Sked'),
          ),
        ),
      ),
    );
    expect(find.text('Sked'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('workspace toolbar wraps many wide actions without overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(560, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SkedWorkspaceToolbar(
            title: Text('Timetable'),
            actions: [
              IconButton(onPressed: null, icon: Icon(Icons.add)),
              IconButton(onPressed: null, icon: Icon(Icons.edit)),
              IconButton(onPressed: null, icon: Icon(Icons.share)),
              IconButton(onPressed: null, icon: Icon(Icons.settings)),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('primary FAB exposes one action and remains touchable', (
    tester,
  ) async {
    var pressed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          floatingActionButton: SkedPrimaryFab(
            tooltip: 'Add event',
            icon: const Icon(Icons.add),
            label: const Text('Add event'),
            onPressed: () => pressed = true,
          ),
        ),
      ),
    );
    final fab = find.byType(FloatingActionButton);
    expect(tester.getSize(fab).height, greaterThanOrEqualTo(48));
    await tester.tap(fab);
    expect(pressed, isTrue);
  });

  testWidgets('primary FAB supports icon-only and loading states', (
    tester,
  ) async {
    var pressed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          floatingActionButton: SkedPrimaryFab(
            heroTag: 'icon-only',
            tooltip: 'Add',
            icon: const Icon(Icons.add),
            onPressed: () => pressed = true,
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Add'));
    expect(pressed, isTrue);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          floatingActionButton: SkedPrimaryFab(
            heroTag: 'loading',
            isLoading: true,
            label: Text('Saving'),
            onPressed: null,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading indicator has a semantic label and static fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Center(
            child: SkedExpressiveLoadingIndicator(semanticsLabel: 'Loading'),
          ),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Loading'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final semantics = tester.getSemantics(
      find.byType(SkedExpressiveLoadingIndicator),
    );
    expect(semantics.flagsCollection.isLiveRegion, isFalse);
    expect(semantics.role, SemanticsRole.loadingSpinner);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading indicator supports determinate progress and updates', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SkedExpressiveLoadingIndicator(
            value: 0.25,
            size: 32,
            semanticsLabel: 'Progress',
          ),
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.bySemanticsLabel('Progress'), findsOneWidget);
    final semantics = tester.getSemantics(
      find.byType(SkedExpressiveLoadingIndicator),
    );
    expect(semantics.label, 'Progress');
    expect(semantics.value, '25%');
    expect(semantics.minValue, '0');
    expect(semantics.maxValue, '100');
    expect(semantics.role, SemanticsRole.progressBar);
    expect(
      tester.getSize(find.byType(SkedExpressiveLoadingIndicator)),
      const Size(32, 32),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Center(
            child: SkedExpressiveLoadingIndicator(
              value: null,
              size: 32,
              semanticsLabel: 'Progress',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading indicator synchronizes animation when value changes', (
    tester,
  ) async {
    double? value = 0.25;
    late void Function(void Function()) update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return SkedExpressiveLoadingIndicator(
              value: value,
              semanticsLabel: 'Changing progress',
            );
          },
        ),
      ),
    );

    update(() => value = null);
    await tester.pump();
    expect(find.byType(CustomPaint), findsWidgets);
    update(() => value = 0.75);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading indicator stops when ticker mode is disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TickerMode(
          enabled: false,
          child: SkedExpressiveLoadingIndicator(semanticsLabel: 'Paused'),
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.bySemanticsLabel('Paused'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading indicator avoids spatial motion under reduce motion', (
    tester,
  ) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: SkedExpressiveLoadingIndicator(semanticsLabel: 'Reduced motion'),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.bySemanticsLabel('Reduced motion'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading indicator animates with one controller when enabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SkedExpressiveLoadingIndicator(semanticsLabel: 'Loading'),
        ),
      ),
    );
    expect(find.byType(CustomPaint), findsWidgets);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 700));
    expect(tester.takeException(), isNull);
  });
}
