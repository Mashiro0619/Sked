import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/theme/app_theme.dart';
import 'package:sked/theme/sked_surface.dart';
import 'package:sked/utils/constants.dart';
import 'package:sked/widgets/expressive_dialog.dart';
import 'package:sked/widgets/sked_calendar_day_label.dart';
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
    Color(0xff6750a4),
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
              'Notes',
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
}
