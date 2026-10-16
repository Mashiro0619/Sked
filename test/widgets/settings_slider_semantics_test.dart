import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/widgets/settings_list.dart';

import '../support/semantics_update_audit.dart';

class _AuditedBinding extends AutomatedTestWidgetsFlutterBinding {
  final audit = SemanticsUpdateAudit();

  @override
  ui.SemanticsUpdateBuilder createSemanticsUpdateBuilder() =>
      audit.createBuilder();
}

List<SemanticsNode> _sliders(WidgetTester tester) {
  final root = tester
      .binding
      .renderViews
      .first
      .owner!
      .semanticsOwner!
      .rootSemanticsNode!;
  final sliders = <SemanticsNode>[];
  void visit(SemanticsNode node) {
    if (node.getSemanticsData().flagsCollection.isSlider) sliders.add(node);
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(root);
  return sliders;
}

SemanticsNode _sliderWithValue(WidgetTester tester, String value) =>
    _sliders(tester)
        .singleWhere((node) => node.getSemanticsData().value == value);

void main() {
  final binding = _AuditedBinding();
  setUp(binding.audit.reset);

  testWidgets(
    'sibling slider indicators stay reachable and retain independent actions',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1000, 700);
      final semantics = tester.ensureSemantics();
      final scroll = ScrollController();
      final values = [6, 23, 72];
      final enabled = [true, true, true];
      final commits = [0, 0, 0];
      late StateSetter rebuild;
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return Scaffold(
                  body: SingleChildScrollView(
                    controller: scroll,
                    child: Column(
                      children: [
                        for (var index = 0; index < 3; index++)
                          SettingsSliderTile(
                            key: ValueKey('setting-slider-$index'),
                            icon: Icons.access_time,
                            title: [
                              'Start hour',
                              'End hour',
                              'Hour height',
                            ][index],
                            value: values[index],
                            min: index == 2 ? 28 : 0,
                            max: index == 2 ? 168 : 24,
                            step: index == 2 ? 4 : 1,
                            enabled: enabled[index],
                            labelBuilder: (value) => index == 2
                                ? '$value dp'
                                : '${value.toString().padLeft(2, '0')}:00',
                            onChangeEnd: (value) => setState(() {
                              values[index] = value;
                              commits[index] += 1;
                            }),
                          ),
                        const SizedBox(height: 700),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(binding.audit.errors, isEmpty);
        final sliderNodes = _sliders(tester);
        expect(sliderNodes, hasLength(3));
        expect(sliderNodes.map((node) => node.id).toSet(), hasLength(3));
        expect(
          sliderNodes.map((node) => node.getSemanticsData().value),
          unorderedEquals(['06:00', '23:00', '72 dp']),
        );
        for (final node in sliderNodes) {
          final data = node.getSemanticsData();
          expect(data.hasAction(ui.SemanticsAction.increase), isTrue);
          expect(data.hasAction(ui.SemanticsAction.decrease), isTrue);
          expect(data.hasAction(ui.SemanticsAction.focus), isTrue);
          expect(node.rect.width, lessThan(1000));
        }

        final start = _sliderWithValue(tester, '06:00');
        start.owner!.performAction(start.id, ui.SemanticsAction.increase);
        await tester.pumpAndSettle();
        expect(values, [7, 23, 72]);
        expect(commits, [1, 0, 0]);
        expect(_sliderWithValue(tester, '07:00').id, start.id);
        expect(binding.audit.errors, isEmpty);

        final end = _sliderWithValue(tester, '23:00');
        end.owner!.performAction(end.id, ui.SemanticsAction.decrease);
        await tester.pumpAndSettle();
        expect(values, [7, 22, 72]);
        expect(commits, [1, 1, 0]);

        final height = _sliderWithValue(tester, '72 dp');
        height.owner!.performAction(height.id, ui.SemanticsAction.focus);
        await tester.pump();
        await tester.sendKeyEvent(
          LogicalKeyboardKey.arrowRight,
          physicalKey: PhysicalKeyboardKey.arrowRight,
        );
        await tester.pumpAndSettle();
        expect(values, [7, 22, 76]);
        expect(commits, [1, 1, 1]);
        expect(_sliderWithValue(tester, '76 dp').id, height.id);

        rebuild(() => enabled[1] = false);
        await tester.pumpAndSettle();
        final disabled = _sliderWithValue(tester, '22:00');
        final disabledData = disabled.getSemanticsData();
        expect(disabledData.hasAction(ui.SemanticsAction.increase), isFalse);
        expect(disabledData.hasAction(ui.SemanticsAction.decrease), isFalse);
        disabled.owner!.performAction(disabled.id, ui.SemanticsAction.increase);
        await tester.pumpAndSettle();
        expect(values, [7, 22, 76]);
        expect(commits, [1, 1, 1]);

        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -120),
        );
        await tester.pumpAndSettle();
        expect(scroll.offset, greaterThan(0));
        expect(binding.audit.errors, isEmpty);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        expect(binding.audit.errors, isEmpty);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        scroll.dispose();
        semantics.dispose();
        tester.view.reset();
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'closing a route retires indicators whose sliders left the scroll cache',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(760, 640);
      final semantics = tester.ensureSemantics();
      final scroll = ScrollController();
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (context) => Scaffold(
                          appBar: AppBar(title: const Text('Slider settings')),
                          body: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              showValueIndicator:
                                  ShowValueIndicator.alwaysVisible,
                            ),
                            child: ListView(
                              controller: scroll,
                              scrollCacheExtent: const ScrollCacheExtent.pixels(
                                0,
                              ),
                              children: [
                                Column(
                                  children: [
                                    for (var index = 0; index < 3; index++)
                                      SettingsSliderTile(
                                        icon: Icons.access_time,
                                        title: [
                                          'Start hour',
                                          'End hour',
                                          'Hour height',
                                        ][index],
                                        value: [6, 23, 72][index],
                                        min: index == 2 ? 28 : 0,
                                        max: index == 2 ? 168 : 24,
                                        step: index == 2 ? 4 : 1,
                                        labelBuilder: (value) => index == 2
                                            ? '$value dp'
                                            : '${value.toString().padLeft(2, '0')}:00',
                                        onChangeEnd: (_) {},
                                      ),
                                    const SizedBox(height: 900),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    child: const Text('Open slider settings'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open slider settings'));
        await tester.pumpAndSettle();
        expect(_sliders(tester), hasLength(3));
        expect(binding.audit.errors, isEmpty);
        await tester.drag(find.byType(ListView), const Offset(0, -500));
        await tester.pumpAndSettle();
        expect(scroll.offset, greaterThan(400));
        expect(
          _sliders(tester),
          isEmpty,
          reason: 'The slider anchors must actually leave the viewport semantics cache.',
        );
        expect(binding.audit.errors, isEmpty);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('Slider settings'), findsNothing);
        expect(find.text('Open slider settings'), findsOneWidget);
        expect(
          binding.audit.errors,
          isEmpty,
          reason: 'Popping must not serialize an indicator after its anchor was clipped.',
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        scroll.dispose();
        semantics.dispose();
        tester.view.reset();
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
