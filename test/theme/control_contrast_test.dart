import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/theme/app_theme.dart';
import 'package:sked/theme/sked_surface.dart';
import 'package:sked/utils/constants.dart';
import 'package:sked/widgets/expressive_dialog.dart';
import 'package:sked/widgets/sked_calendar_day_label.dart';
import 'package:sked/widgets/settings_list.dart';
import 'package:sked/widgets/workspace_editor_form.dart';

double _contrast(Color foreground, Color background) {
  final a = Color.alphaBlend(foreground, background).computeLuminance();
  final b = background.computeLuminance();
  return a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05);
}

Color _textColor(WidgetTester tester, String text) =>
    tester.renderObject<RenderParagraph>(find.text(text)).text.style!.color!;

void main() {
  const seeds = [
    Color(defaultThemeSeedColorValue),
    Color(0xff101010),
    Color(0xffffffff),
    Color(0xffffff00),
    Color(0xff00897b),
  ];

  test(
    'accent foregrounds remain readable across actual and custom surfaces',
    () {
      for (final brightness in Brightness.values) {
        for (final seed in seeds) {
          final colors = buildAppTheme(
            seedColor: seed,
            brightness: brightness,
            themeColorMode: themeColorModeSingle,
            colorfulUiColorValues: const {},
          ).colorScheme;
          for (final surface in [
            colors.surface,
            colors.surfaceContainerLow,
            colors.surfaceContainerHighest,
            colors.primaryContainer,
            const Color(0xff666666),
            const Color(0xffdddddd),
            Colors.white,
            Colors.black,
          ]) {
            final accent = skedReadableAccent(colors, surface: surface);
            expect(_contrast(accent, surface), greaterThanOrEqualTo(4.5));
            if (_contrast(seed, surface) >= 4.5) expect(accent, seed);
          }
          expect(colors.primary, seed);
        }
      }
    },
  );

  testWidgets(
    'visible actions, selections, and focused input retain contrast',
    (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      for (final brightness in Brightness.values) {
        for (final seed in seeds) {
          final theme = buildAppTheme(
            seedColor: seed,
            brightness: brightness,
            themeColorMode: themeColorModeSingle,
            colorfulUiColorValues: const {},
          );
          for (final role in SkedSurfaceRole.values) {
            await tester.pumpWidget(
              MaterialApp(
                theme: theme,
                themeAnimationDuration: Duration.zero,
                home: SkedSurface(
                  role: role,
                  child: Column(
                    children: [
                      TextButton(onPressed: () {}, child: const Text('Cancel')),
                      OutlinedButton(
                        onPressed: () {},
                        child: const Text('Edit'),
                      ),
                      FilledButton(onPressed: () {}, child: const Text('Save')),
                      TextButton(
                        onPressed: null,
                        child: const Text('Disabled'),
                      ),
                      ExpressiveDialogOption(
                        title: const Text('Selected option'),
                        subtitle: const Text('Selected description'),
                        selected: true,
                        onTap: () {},
                      ),
                      TextField(
                        focusNode: focus,
                        decoration: const InputDecoration(labelText: 'Title'),
                      ),
                      SkedCalendarDayLabel(
                        date: DateTime.now(),
                        compact: true,
                        localeCode: 'en',
                      ),
                    ],
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            focus.requestFocus();
            await tester.pumpAndSettle();
            final colors = theme.colorScheme;
            final surface = role.resolve(colors);
            final editorField = workspaceEditorInputDecoration(
              tester.element(find.text('Title')),
            );
            expect(
              _contrast(
                editorField.focusedBorder!.borderSide.color,
                colors.surfaceContainerHighest,
              ),
              greaterThanOrEqualTo(3),
            );
            for (final label in ['Cancel', 'Edit']) {
              expect(
                _contrast(_textColor(tester, label), surface),
                greaterThanOrEqualTo(4.5),
                reason: '$label / $brightness / $seed / $role',
              );
            }
            final selectedSurface = Color.alphaBlend(
              colors.primary.withValues(alpha: .12),
              surface,
            );
            for (final label in ['Selected option', 'Selected description']) {
              expect(
                _contrast(_textColor(tester, label), selectedSurface),
                greaterThanOrEqualTo(4.5),
                reason: '$label / $brightness / $seed / $role',
              );
            }
            final editable = tester.widget<EditableText>(
              find.byType(EditableText),
            );
            expect(
              _contrast(editable.cursorColor, colors.surfaceContainerLow),
              greaterThanOrEqualTo(4.5),
            );
            expect(
              _contrast(
                _textColor(tester, 'Title'),
                colors.surfaceContainerLow,
              ),
              greaterThanOrEqualTo(4.5),
            );
            expect(_textColor(tester, 'Disabled').a, lessThan(1));
            final filled = tester.widget<Material>(
              find.descendant(
                of: find.widgetWithText(FilledButton, 'Save'),
                matching: find.byType(Material),
              ),
            );
            expect(filled.color, seed);
            expect(
              _contrast(_textColor(tester, 'Save'), seed),
              greaterThanOrEqualTo(4.5),
            );
            final badge = tester.widget<Container>(
              find.descendant(
                of: find.byType(SkedCalendarDayLabel),
                matching: find.byWidgetPredicate(
                  (widget) =>
                      widget is Container && widget.decoration is BoxDecoration,
                ),
              ),
            );
            expect((badge.decoration! as BoxDecoration).color, seed);
            expect(
              _contrast(_textColor(tester, '${DateTime.now().day}'), seed),
              greaterThanOrEqualTo(4.5),
            );
            expect(tester.takeException(), isNull);
          }
        }
      }
    },
  );

  test(
    'selected navigation and menus contrast with their tinted backgrounds',
    () {
      const selected = {WidgetState.selected};
      const focused = {WidgetState.focused};
      for (final brightness in Brightness.values) {
        for (final seed in seeds) {
          final theme = buildAppTheme(
            seedColor: seed,
            brightness: brightness,
            themeColorMode: themeColorModeSingle,
            colorfulUiColorValues: const {},
          );
          final colors = theme.colorScheme;
          final foregrounds = [
            theme.navigationBarTheme.labelTextStyle!.resolve(selected)!.color!,
            theme.navigationBarTheme.iconTheme!.resolve(selected)!.color!,
            theme.navigationRailTheme.selectedIconTheme!.color!,
            theme.segmentedButtonTheme.style!.foregroundColor!.resolve(
              selected,
            )!,
            theme.menuButtonTheme.style!.foregroundColor!.resolve(focused)!,
            theme.menuButtonTheme.style!.iconColor!.resolve(focused)!,
          ];
          for (final background in [
            colors.surface,
            colors.surfaceContainerLow,
          ]) {
            final selectedBackground = Color.alphaBlend(
              colors.primary.withValues(alpha: .12),
              background,
            );
            for (final foreground in foregrounds) {
              expect(
                _contrast(foreground, selectedBackground),
                greaterThanOrEqualTo(4.5),
              );
            }
          }
          expect(colors.primary, seed);
        }
      }
    },
  );

  test('standalone marks contrast without changing the saved fill colors', () {
    for (final brightness in Brightness.values) {
      for (final seed in seeds) {
        final theme = buildAppTheme(
          seedColor: seed,
          brightness: brightness,
          themeColorMode: themeColorModeSingle,
          colorfulUiColorValues: const {},
        );
        final colors = theme.colorScheme;
        final radio = theme.radioTheme.fillColor!.resolve({
          WidgetState.selected,
        })!;
        final progress = theme.progressIndicatorTheme;
        for (final background in [
          colors.surface,
          colors.surfaceContainerLow,
          colors.surfaceContainerHighest,
        ]) {
          for (final mark in [
            radio,
            progress.color!,
            progress.stopIndicatorColor!,
            theme.sliderTheme.thumbColor!,
            theme.sliderTheme.activeTrackColor!,
          ]) {
            expect(
              _contrast(mark, background),
              greaterThanOrEqualTo(3),
              reason: '$brightness / $seed / $background',
            );
          }
        }
        expect(
          _contrast(
            theme.sliderTheme.activeTickMarkColor!,
            theme.sliderTheme.activeTrackColor!,
          ),
          greaterThanOrEqualTo(3),
        );
        expect(
          _contrast(progress.color!, colors.secondaryContainer),
          greaterThanOrEqualTo(3),
        );
        expect(colors.primary, seed);
        expect(theme.sliderTheme.valueIndicatorColor, seed);
        expect(
          _contrast(theme.sliderTheme.valueIndicatorTextStyle!.color!, seed),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          theme.switchTheme.trackColor!.resolve({WidgetState.selected}),
          seed,
        );
        expect(
          theme.switchTheme.thumbColor!.resolve({WidgetState.selected}),
          colors.onPrimary,
        );
      }
    }
  });

  test('sliders and progress use current M3 shapes and track markers', () {
    final theme = buildAppTheme(
      seedColor: const Color(defaultThemeSeedColorValue),
      brightness: Brightness.light,
      themeColorMode: themeColorModeSingle,
      colorfulUiColorValues: const {},
    );
    expect(theme.sliderTheme.thumbShape, isA<HandleThumbShape>());
    expect(theme.sliderTheme.trackShape, isA<GappedSliderTrackShape>());
    expect(theme.sliderTheme.trackGap, 6);
    // These migration flags select the corresponding current package defaults.
    // ignore: deprecated_member_use
    expect(theme.sliderTheme.year2023, isFalse);
    // ignore: deprecated_member_use
    expect(theme.progressIndicatorTheme.year2023, isFalse);
    expect(theme.progressIndicatorTheme.trackGap, 4);
    expect(theme.progressIndicatorTheme.stopIndicatorRadius, 2);
  });

  testWidgets('reorder focus contrasts with its actual plain or tonal row', (
    tester,
  ) async {
    final previous = FocusManager.instance.highlightStrategy;
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    try {
      for (final brightness in Brightness.values) {
        for (final seed in seeds) {
          for (final tonal in [false, true]) {
            final theme = buildAppTheme(
              seedColor: seed,
              brightness: brightness,
              themeColorMode: themeColorModeSingle,
              colorfulUiColorValues: const {},
            );
            await tester.pumpWidget(
              MaterialApp(
                theme: theme,
                themeAnimationDuration: Duration.zero,
                home: Scaffold(
                  body: SkedSurface(
                    role: SkedSurfaceRole.frame,
                    child: SettingsConnectedGroup(
                      tonal: tonal,
                      children: [
                        SettingsToolbarNavigationEditor(
                          items: const [
                            SettingsToolbarNavigationItem(
                              id: 'first',
                              label: 'First',
                              icon: Icons.calendar_today,
                              visible: true,
                            ),
                          ],
                          onReorder: (_) {},
                          onVisibilityChanged: (_, _) {},
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final visual = find.byKey(
              const ValueKey('toolbar-navigation-drag-handle-visual-first'),
            );
            Focus.of(tester.element(visual)).requestFocus();
            await tester.pumpAndSettle();
            final decoration =
                tester.widget<AnimatedContainer>(visual).decoration!
                    as ShapeDecoration;
            final side = (decoration.shape as RoundedRectangleBorder).side;
            final colors = theme.colorScheme;
            final surface = tonal
                ? SettingsVisuals.rowColor(colors)
                : SkedSurfaceRole.frame.resolve(colors);
            expect(side.width, 2);
            expect(
              _contrast(
                side.color,
                Color.alphaBlend(decoration.color!, surface),
              ),
              greaterThanOrEqualTo(3),
              reason: '$brightness / $seed / tonal=$tonal',
            );
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
          }
        }
      }
    } finally {
      FocusManager.instance.highlightStrategy = previous;
    }
  });

  testWidgets(
    'current controls keep touch, keyboard, labels and checked state at large text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 700);
      addTearDown(tester.view.reset);
      final focus = FocusNode();
      addTearDown(focus.dispose);
      final semantics = tester.ensureSemantics();
      try {
        for (final brightness in Brightness.values) {
          final seed = brightness == Brightness.light
              ? Colors.white
              : const Color(0xff101010);
          final theme = buildAppTheme(
            seedColor: seed,
            brightness: brightness,
            themeColorMode: themeColorModeSingle,
            colorfulUiColorValues: const {},
          );
          var value = .5;
          var selected = 'first';
          var committed = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              themeAnimationDuration: Duration.zero,
              home: MediaQuery(
                data: const MediaQueryData(
                  size: Size(360, 700),
                  textScaler: TextScaler.linear(2),
                ),
                child: Scaffold(
                  body: StatefulBuilder(
                    builder: (context, update) => Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        RadioGroup<String>(
                          groupValue: selected,
                          onChanged: (next) => update(() => selected = next!),
                          child: Column(
                            children: [
                              for (final name in ['first', 'second'])
                                RadioListTile<String>(
                                  key: ValueKey('contrast-radio-$name'),
                                  value: name,
                                  title: Text(name),
                                  selected: selected == name,
                                ),
                            ],
                          ),
                        ),
                        Slider(
                          key: const ValueKey('contrast-slider'),
                          value: value,
                          divisions: 10,
                          focusNode: focus,
                          label: '${(value * 100).round()}%',
                          onChanged: (next) => update(() => value = next),
                          onChangeEnd: (_) => committed++,
                        ),
                        const SizedBox.square(
                          dimension: 40,
                          child: CircularProgressIndicator(
                            value: .5,
                            semanticsLabel: 'Import',
                          ),
                        ),
                        const SizedBox(height: 16),
                        const LinearProgressIndicator(
                          value: .5,
                          semanticsLabel: 'Save',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final radio = find.byKey(const ValueKey('contrast-radio-second'));
          await tester.tap(radio);
          await tester.pumpAndSettle();
          expect(selected, 'second');
          expect(
            tester
                .getSemantics(radio)
                .getSemanticsData()
                .flagsCollection
                .isChecked,
            ui.CheckedState.isTrue,
          );
          final slider = find.byKey(const ValueKey('contrast-slider'));
          expect(tester.getSize(slider).height, greaterThanOrEqualTo(48));
          await tester.drag(slider, const Offset(70, 0));
          await tester.pumpAndSettle();
          expect(value, greaterThan(.5));
          expect(committed, greaterThan(0));
          final beforeKey = value;
          focus.requestFocus();
          await tester.pump();
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
          await tester.pumpAndSettle();
          expect(value, greaterThan(beforeKey));
          expect(
            tester.widget<Slider>(slider).label,
            '${(value * 100).round()}%',
          );
          String? spokenValue;
          void visitSlider(SemanticsNode node) {
            final data = node.getSemanticsData();
            if (data.flagsCollection.isSlider) spokenValue = data.value;
            node.visitChildren((child) {
              visitSlider(child);
              return true;
            });
          }

          visitSlider(tester.getSemantics(slider));
          expect(spokenValue, '${(value * 100).round()}%');
          expect(
            tester
                .getSemantics(find.bySemanticsLabel('Import'))
                .getSemanticsData()
                .value,
            '50',
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        }
      } finally {
        semantics.dispose();
      }
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.windows,
    }),
  );
}
