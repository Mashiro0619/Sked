import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/general_display_settings_page.dart';
import 'package:sked/screens/settings_page.dart';
import 'package:sked/widgets/settings_list.dart';

import '../support/semantics_update_audit.dart';
import '../support/workspace_harness.dart';

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

  for (final width in [900.0, 1440.0]) {
    testWidgets(
      'real display settings retain hidden slider anchors when closing at $width',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 640);
        final semantics = tester.ensureSemantics();
        final provider = await workspaceProvider(mode: AppMode.general);
        try {
          // Include the conditional fourth production SettingsSliderTile.
          await provider.generalCommands.updateCustomDayMinWidth(
            generalCustomDayMinWidthDefault,
          );
          await tester.pumpWidget(WorkspaceHarness(provider: provider));
          await tester.pumpAndSettle();
          final directSettings =
              [
                'workspace-resource-settings',
                'general-settings-button',
                'adaptive-shell-settings-action',
              ].where(
                (key) => find
                    .byKey(ValueKey(key))
                    .hitTestable()
                    .evaluate()
                    .isNotEmpty,
              );
          if (directSettings.isNotEmpty) {
            await tester.tap(
              find.byKey(ValueKey(directSettings.first)).hitTestable().first,
            );
          } else {
            await tester.tap(
              find.byKey(const ValueKey('general-toolbar-more-button')),
            );
            await tester.pumpAndSettle();
            await tester.tap(
              find.byKey(const ValueKey('general-more-settings')).last,
            );
          }
          await tester.pumpAndSettle();
          final displayEntry = find.byKey(
            const ValueKey('settings-general-display'),
          );
          await tester.ensureVisible(displayEntry.first);
          await tester.pumpAndSettle();
          await tester.tap(displayEntry.hitTestable().first);
          await tester.pumpAndSettle();

          final page = find.byType(GeneralDisplaySettingsPage);
          expect(page, findsOneWidget);
          final tiles = find.descendant(
            of: page,
            matching: find.byType(SettingsSliderTile),
          );
          expect(tiles, findsNWidgets(4));
          final seenSliderIds = <int>{};
          final tilesById = <int, Finder>{};
          for (var index = 0; index < 4; index++) {
            final tile = tiles.at(index);
            await tester.ensureVisible(tile);
            await tester.pumpAndSettle();
            final slider = tester.widget<Slider>(
              find.descendant(of: tile, matching: find.byType(Slider)),
            );
            final node = _sliderWithValue(tester, slider.label!);
            seenSliderIds.add(node.id);
            tilesById[node.id] = tile;
            final data = node.getSemanticsData();
            expect(data.flagsCollection.isHidden, isFalse);
            expect(data.hasAction(ui.SemanticsAction.increase), isTrue);
            expect(data.hasAction(ui.SemanticsAction.decrease), isTrue);

            // Exercise each real production command through its Slider action,
            // then restore the value before testing the next control.
            final before = tester.widget<SettingsSliderTile>(tile);
            final canIncrease = before.value + before.step <= before.max;
            final delta = canIncrease ? before.step : -before.step;
            node.owner!.performAction(
              node.id,
              canIncrease
                  ? ui.SemanticsAction.increase
                  : ui.SemanticsAction.decrease,
            );
            await tester.pumpAndSettle();
            expect(
              tester.widget<SettingsSliderTile>(tile).value,
              before.value + delta,
            );
            final updated = _sliders(tester)
                .singleWhere((value) => value.id == node.id);
            expect(
              updated.getSemanticsData().flagsCollection.isHidden,
              isFalse,
            );
            updated.owner!.performAction(
              updated.id,
              canIncrease
                  ? ui.SemanticsAction.decrease
                  : ui.SemanticsAction.increase,
            );
            await tester.pumpAndSettle();
            expect(tester.widget<SettingsSliderTile>(tile).value, before.value);
            expect(binding.audit.errors, isEmpty);
          }
          expect(seenSliderIds, hasLength(4));

          final list = find.byKey(
            const ValueKey('general-display-settings-list'),
          );
          final scrollable = find
              .descendant(of: list, matching: find.byType(Scrollable))
              .first;
          final position = tester.state<ScrollableState>(scrollable).position;
          final beforeScroll = position.pixels;
          // The finite form keeps offscreen anchors attached and marks them
          // hidden outside the paint clip, while their global indicators live.
          for (var attempt = 0; attempt < 8; attempt++) {
            await tester.drag(
              list,
              Offset(0, -tester.getSize(list).height * .9),
            );
            await tester.pumpAndSettle();
            final hidden = _sliders(tester)
                .where(
                  (node) => node.getSemanticsData().flagsCollection.isHidden,
                )
                .map((node) => node.id)
                .toSet();
            if (seenSliderIds.intersection(hidden).isNotEmpty &&
                (position.pixels - beforeScroll).abs() > 20) {
              break;
            }
          }
          final afterScroll = _sliders(tester);
          final remaining = afterScroll.map((node) => node.id).toSet();
          final hidden = afterScroll
              .where((node) => node.getSemanticsData().flagsCollection.isHidden)
              .map((node) => node.id)
              .toSet();
          expect(
            (position.pixels - beforeScroll).abs(),
            greaterThan(20),
            reason: 'The regression must exercise actual settings scrolling.',
          );
          expect(
            remaining,
            containsAll(seenSliderIds),
            reason:
                'The finite form must retain every previously serialized '
                'slider anchor while its global indicator remains mounted.',
          );
          expect(
            seenSliderIds.intersection(hidden),
            isNotEmpty,
            reason:
                'At least one slider must be outside the paint clip and '
                'reported hidden before testing the route transition.',
          );
          expect(tiles, findsNWidgets(4));
          expect(binding.audit.errors, isEmpty);

          final hiddenId = seenSliderIds.intersection(hidden).first;
          final hiddenTile = tilesById[hiddenId]!;
          final hiddenOffset = position.pixels;
          final hiddenControl = find.descendant(
            of: hiddenTile,
            matching: find.byType(Slider),
          );
          expect(
            tester.getRect(hiddenControl).overlaps(tester.getRect(list)),
            isFalse,
            reason: 'The hidden state must correspond to measured offscreen geometry.',
          );
          await tester.ensureVisible(hiddenTile);
          await tester.pumpAndSettle();
          final revealed = _sliders(tester)
              .singleWhere((node) => node.id == hiddenId);
          expect(revealed.getSemanticsData().flagsCollection.isHidden, isFalse);
          expect(
            revealed.getSemanticsData().hasAction(ui.SemanticsAction.increase),
            isTrue,
          );
          expect(
            tester.getRect(hiddenControl).overlaps(tester.getRect(list)),
            isTrue,
          );
          expect(binding.audit.errors, isEmpty);
          position.jumpTo(hiddenOffset);
          await tester.pumpAndSettle();
          expect(
            _sliders(tester)
                .singleWhere((node) => node.id == hiddenId)
                .getSemanticsData()
                .flagsCollection
                .isHidden,
            isTrue,
          );
          expect(binding.audit.errors, isEmpty);

          if (width == 1440) {
            // Match the desktop flow: dismiss the outer settings route while
            // its inner Navigator still owns the display detail route.
            Navigator.of(
              tester.element(page),
              rootNavigator: true,
            ).popUntil((route) => route.isFirst);
          } else {
            await tester.pageBack();
          }
          await tester.pumpAndSettle();
          expect(page, findsNothing);
          expect(binding.audit.errors, isEmpty);
          expect(binding.audit.updateCount, greaterThan(0));
          expect(tester.takeException(), isNull);
          if (width != 1440) {
            expect(find.byType(SettingsPage), findsWidgets);
            await tester.pageBack();
            await tester.pumpAndSettle();
          }
          expect(find.byType(SettingsPage), findsNothing);
          expect(binding.audit.errors, isEmpty);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          provider.dispose();
          semantics.dispose();
          tester.view.reset();
        }
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }
}
