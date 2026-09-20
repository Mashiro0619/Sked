import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/screens/settings_page.dart';
import 'package:sked/screens/theme_settings_page.dart';
import 'package:sked/widgets/settings_list.dart';
import 'package:sked/widgets/sked_dropdown_menu.dart';

import '../support/workspace_harness.dart';

Finder k(String id) => find.byKey(ValueKey(id));
void viewport(WidgetTester t, Size size) {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = size;
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.view.resetPhysicalSize);
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'connected settings have neutral row surfaces and continuous first/last corners in $brightness',
      (t) async {
        viewport(t, const Size(393, 1000));
        final p = await workspaceProvider();
        addTearDown(p.dispose);
        await t.pumpWidget(
          WorkspaceHarness(
            provider: p,
            brightness: brightness,
            home: const SettingsPage(),
          ),
        );
        await t.pumpAndSettle();
        final group = k('settings-overview-appearance');
        final rows = find.descendant(
          of: group,
          matching: find.byWidgetPredicate(
            (w) =>
                w is Material &&
                w.key is ValueKey<String> &&
                (w.key! as ValueKey<String>).value.startsWith(
                  'settings-group-row-',
                ),
          ),
        );
        expect(rows, findsNWidgets(5));
        final colors = Theme.of(t.element(group)).colorScheme;
        expect(
          find.descendant(of: group, matching: find.byType(Card)),
          findsNothing,
        );
        for (var i = 0; i < 5; i++) {
          final row = t.widget<Material>(rows.at(i));
          expect(row.color, SettingsVisuals.rowColor(colors));
          expect(row.color, isNot(colors.surface));
          final radius = (row.shape! as RoundedRectangleBorder).borderRadius
              .resolve(TextDirection.ltr);
          expect(radius.topLeft.x, i == 0 ? 24 : 4);
          expect(radius.bottomRight.x, i == 4 ? 24 : 4);
          if (i > 0) {
            expect(
              t.getTopLeft(rows.at(i)).dy - t.getBottomLeft(rows.at(i - 1)).dy,
              closeTo(2, .01),
            );
          }
        }
        final icon = find.descendant(
          of: k('settings-language'),
          matching: find.byIcon(Icons.language),
        );
        expect(IconTheme.of(t.element(icon)).color, colors.onSurfaceVariant);
        expect(IconTheme.of(t.element(icon)).color, isNot(colors.primary));
        expect(t.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }

  for (final direction in TextDirection.values) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets(
        'choice current value wraps without truncation at 320/$scale/$direction and activates once',
        (t) async {
          viewport(t, const Size(320, 900));
          final p = await workspaceProvider();
          addTearDown(p.dispose);
          var selected = 0;
          await t.pumpWidget(
            WorkspaceHarness(
              provider: p,
              textScale: scale,
              home: Directionality(
                textDirection: direction,
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: SettingsConnectedGroup(
                      tonal: true,
                      children: [
                        SettingsChoiceTile<String>(
                          key: const ValueKey('choice'),
                          title: 'View and interaction',
                          subtitle:
                              'One preference, not a second focusable button.',
                          icon: Icons.view_week_outlined,
                          value: 'auto',
                          entries: const [
                            DropdownMenuEntry(
                              value: 'auto',
                              label: 'Match the current workspace',
                            ),
                            DropdownMenuEntry(value: 'manual', label: 'Manual'),
                          ],
                          onSelected: (_) => selected++,
                        ),
                        SettingsConnectedTile(
                          key: const ValueKey('readable-value'),
                          leading: const Icon(Icons.language),
                          title: 'Language',
                          value: 'Traditional Chinese (Taiwan)',
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          await t.pumpAndSettle();
          for (final label in [
            'View and interaction',
            'Match the current workspace',
            'Traditional Chinese (Taiwan)',
          ]) {
            final paragraph = t.renderObject<RenderParagraph>(find.text(label));
            expect(paragraph.didExceedMaxLines, isFalse, reason: label);
            expect(
              paragraph.getBoxesForSelection(
                TextSelection(baseOffset: 0, extentOffset: label.length),
              ),
              isNotEmpty,
            );
            final rect = t.getRect(find.text(label));
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(320));
          }
          final semantics = t.ensureSemantics();
          final current = t
              .getSemantics(k('readable-value'))
              .getSemanticsData();
          expect(current.value, 'Traditional Chinese (Taiwan)');
          await t.tap(k('choice'));
          await t.pumpAndSettle();
          await t.tap(find.text('Manual').last);
          await t.pumpAndSettle();
          expect(selected, 1);
          expect(
            t
                .widget<SkedDropdownMenu<String>>(
                  find.descendant(
                    of: k('choice'),
                    matching: find.byType(SkedDropdownMenu<String>),
                  ),
                )
                .initialSelection,
            'auto',
          );
          semantics.dispose();
          expect(t.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.android),
      );
    }
  }

  testWidgets(
    'phone large title collapses with the overview scroll and detail returns to the same position',
    (t) async {
      viewport(t, const Size(393, 900));
      final p = await workspaceProvider();
      addTearDown(p.dispose);
      await t.pumpWidget(
        WorkspaceHarness(provider: p, home: const SettingsPage()),
      );
      await t.pumpAndSettle();
      final scroll = t
          .widget<CustomScrollView>(
            find.byKey(const PageStorageKey('settings-overview-scroll')),
          )
          .controller!;
      final title = AppLocalizations.of(
        t.element(k('settings-overview-appearance')),
      ).settingsTitle;
      final paragraphs = find.descendant(
        of: k('settings-overview-app-bar'),
        matching: find.text(title),
      );
      final large = paragraphs
          .evaluate()
          .map(
            (e) =>
                (e.renderObject! as RenderParagraph).text.style?.fontSize ?? 0,
          )
          .reduce((a, b) => a > b ? a : b);
      expect(large, greaterThanOrEqualTo(32));
      final before = t.getTopLeft(k('settings-overview-appearance')).dy;
      scroll.jumpTo(180);
      await t.pumpAndSettle();
      expect(
        t.getTopLeft(k('settings-overview-appearance')).dy,
        lessThan(before),
      );
      final appbar = t.widget<SliverAppBar>(k('settings-overview-app-bar'));
      expect(appbar.pinned, isTrue);
      expect(find.byType(BackButton).hitTestable(), findsOneWidget);
      await t.ensureVisible(k('settings-general-display'));
      await t.pumpAndSettle();
      final offset = scroll.offset;
      await t.tap(k('settings-general-display'));
      await t.pumpAndSettle();
      await t.tap(find.byType(BackButton).hitTestable().first);
      await t.pumpAndSettle();
      expect(scroll.offset, closeTo(offset, .01));
      expect(k('settings-general-display').hitTestable(), findsOneWidget);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'overview title, common control state and detail survives wide/narrow resize',
    (t) async {
      viewport(t, const Size(393, 900));
      final p = await workspaceProvider();
      addTearDown(p.dispose);
      await t.pumpWidget(
        WorkspaceHarness(provider: p, home: const SettingsPage()),
      );
      await t.pumpAndSettle();
      final themeState = t.state(find.byType(ThemeSettingsPage));
      final controller = t
          .widget<ScrollView>(
            find.byKey(const PageStorageKey('settings-overview-scroll')),
          )
          .controller;
      for (final width in [1280.0, 660.0, 393.0]) {
        t.view.physicalSize = Size(width, 900);
        await t.pumpAndSettle();
        expect(t.state(find.byType(ThemeSettingsPage)), same(themeState));
        expect(
          t
              .widget<ScrollView>(
                find.byKey(const PageStorageKey('settings-overview-scroll')),
              )
              .controller,
          same(controller),
        );
        expect(find.byType(BackButton).hitTestable(), findsOneWidget);
        expect(t.takeException(), isNull);
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'compact appearance places actual preferences before the live preview',
    (t) async {
      viewport(t, const Size(393, 900));
      final p = await workspaceProvider();
      addTearDown(p.dispose);
      await t.pumpWidget(
        WorkspaceHarness(provider: p, home: const ThemeSettingsPage()),
      );
      await t.pumpAndSettle();
      final choice = k('theme-brightness-mode-choice-list');
      final preview = k('theme-workspace-preview');
      expect(choice.hitTestable(), findsOneWidget);
      expect(t.getTopLeft(preview).dy, greaterThan(t.getBottomLeft(choice).dy));
      await t.ensureVisible(preview);
      await t.pumpAndSettle();
      // The preview is deliberately non-interactive (IgnorePointer).
      final previewRect = t.getRect(preview);
      expect(previewRect.overlaps(const Rect.fromLTWH(0, 0, 393, 900)), isTrue);
      expect(previewRect.bottom, lessThanOrEqualTo(900));
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('explanatory note remains outside connected control surfaces', (
    t,
  ) async {
    viewport(t, const Size(393, 900));
    final p = await workspaceProvider();
    addTearDown(p.dispose);
    await t.pumpWidget(
      WorkspaceHarness(
        provider: p,
        home: Scaffold(
          body: ResponsiveSettingsBody(
            connectedSections: true,
            children: [
              const SettingsSectionNote('A platform limitation, not an action'),
              SettingsSwitchTile(
                value: false,
                onChanged: (_) {},
                icon: Icons.notifications_outlined,
                title: 'Enable notifications',
              ),
              const SettingsSectionHeader(title: 'Details'),
              SettingsConnectedTile(
                leading: const Icon(Icons.tune),
                title: 'Preferences',
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    final note = find.text('A platform limitation, not an action');
    expect(
      find.ancestor(
        of: note,
        matching: find.byWidgetPredicate(
          (w) =>
              w is Material && w.key == const ValueKey('settings-group-row-0'),
        ),
      ),
      findsNothing,
    );
    expect(find.byType(SettingsConnectedGroup), findsNWidgets(2));
    expect(t.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
