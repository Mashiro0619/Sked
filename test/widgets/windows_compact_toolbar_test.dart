import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/desktop_window_bridge.dart';
import 'package:sked/widgets/workbench_chrome_metrics.dart';
import 'package:sked/widgets/workspace_navigation.dart';

import '../support/mobile_layout_data.dart';
import '../support/workspace_harness.dart';

Finder _key(String value) => find.byKey(ValueKey(value));
void _size(WidgetTester t, double width) {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = Size(width, 900);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.view.resetPhysicalSize);
  DesktopWindowBridge.instance.available = true;
  addTearDown(() => DesktopWindowBridge.instance.available = false);
}

void main() {
  for (final width in [330.0, 400.0, 520.0, 660.0, 800.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      for (final language in ['zh', 'en']) {
        for (final mode in AppMode.values) {
          testWidgets(
            'Windows $width/$scale/$language/$mode keeps complete commands before captions',
            (t) async {
              _size(t, width);
              final p = await workspaceProvider(
                storage: WorkspaceMemoryStorage(
                  mobileLayoutData(locale: language).copyWith(activeMode: mode),
                ),
                locale: language,
              );
              addTearDown(p.dispose);
              await t.pumpWidget(
                WorkspaceHarness(
                  provider: p,
                  locale: Locale(language),
                  textScale: scale,
                ),
              );
              await t.pumpAndSettle();
              final primary = _key(
                mode == AppMode.student
                    ? 'student-week-picker-button'
                    : 'general-date-picker',
              );
              final m = WorkbenchChromeMetrics.of(t.element(primary));
              final bar = _key('${mode.value}-workspace-toolbar');
              final clip = Rect.fromLTRB(
                t.getRect(bar).left,
                0,
                width - m.captionWidth,
                m.toolbarHeight,
              );
              expect(primary.hitTestable(), findsOneWidget);
              final more = _key('${mode.value}-desktop-toolbar-more');
              expect(more.hitTestable(), findsOneWidget);
              final buttons = find.descendant(
                of: bar,
                matching: find.byWidgetPredicate(
                  (w) =>
                      w is IconButton || w is TextButton || w is FilledButton,
                ),
              );
              for (final element in buttons.evaluate()) {
                final button = find.byWidget(element.widget);
                final rect = t.getRect(button);
                expect(rect.left, greaterThanOrEqualTo(clip.left));
                expect(rect.right, lessThanOrEqualTo(clip.right));
                expect(rect.top, greaterThanOrEqualTo(clip.top));
                expect(rect.bottom, lessThanOrEqualTo(clip.bottom));
                for (final text
                    in find
                        .descendant(of: button, matching: find.byType(Text))
                        .evaluate()) {
                  final paragraph = text.renderObject! as RenderParagraph;
                  expect(paragraph.didExceedMaxLines, isFalse);
                  final textRect = t.getRect(find.byWidget(text.widget));
                  expect(textRect.left, greaterThanOrEqualTo(rect.left));
                  expect(textRect.right, lessThanOrEqualTo(rect.right));
                }
              }
              expect(
                find.descendant(
                  of: bar,
                  matching: find.byWidgetPredicate(
                    (w) =>
                        w is SingleChildScrollView &&
                        w.scrollDirection == Axis.horizontal,
                  ),
                ),
                findsNothing,
              );
              final moreIcon = find.descendant(
                of: more,
                matching: find.byIcon(Icons.more_horiz),
              );
              expect(t.getCenter(moreIcon), t.getCenter(more));
              expect(t.takeException(), isNull);
            },
            variant: TargetPlatformVariant.only(TargetPlatform.windows),
          );
        }
      }
    }
  }

  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets(
      'collapsed resource header shares the navigation icon center at $scale text',
      (t) async {
        _size(t, 1800);
        final p = await workspaceProvider(
          storage: WorkspaceMemoryStorage(
            mobileLayoutData().copyWith(
              activeMode: AppMode.student,
              homeWorkspaceNavigationCollapsed: true,
            ),
          ),
        );
        addTearDown(p.dispose);
        await t.pumpWidget(WorkspaceHarness(provider: p, textScale: scale));
        await t.pumpAndSettle();
        final panel = _key('workspace-resource-panel').hitTestable();
        final collapse = _key('workspace-resource-collapse').hitTestable();
        final icon = find.descendant(of: collapse, matching: find.byType(Icon));
        expect(t.getCenter(icon).dx, closeTo(t.getCenter(panel).dx, .01));
        for (final id in [
          'workspace-resource-mode-student',
          'workspace-resource-mode-general',
          'workspace-resource-open',
          'workspace-resource-settings',
        ]) {
          final peerIcon = find.descendant(
            of: _key(id).hitTestable(),
            matching: find.byType(Icon),
          );
          expect(t.getCenter(icon).dx, closeTo(t.getCenter(peerIcon).dx, .01));
        }
        await t.tap(collapse);
        await t.pumpAndSettle();
        expect(p.homeWorkspaceNavigationCollapsed, isFalse);
        await t.tap(_key('workspace-resource-collapse'));
        await t.pumpAndSettle();
        expect(p.homeWorkspaceNavigationCollapsed, isTrue);
        expect(
          t
              .getCenter(
                find.descendant(
                  of: _key('workspace-resource-collapse'),
                  matching: find.byType(Icon),
                ),
              )
              .dx,
          closeTo(t.getCenter(panel).dx, .01),
        );
        expect(t.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }

  testWidgets(
    'desktop workspace menu icon is centered inside its pointer target',
    (t) async {
      _size(t, 1440);
      final p = await workspaceProvider(
        storage: WorkspaceMemoryStorage(
          mobileLayoutData().copyWith(
            activeMode: AppMode.student,
            hideHomeWorkspaceNavigation: true,
          ),
        ),
      );
      addTearDown(p.dispose);
      await t.pumpWidget(WorkspaceHarness(provider: p));
      await t.pumpAndSettle();
      final menu = find.byType(WorkspaceModeMenu).hitTestable();
      final icon = find.descendant(
        of: menu,
        matching: find.byIcon(Icons.swap_horiz),
      );
      final button = t.getRect(menu), glyph = t.getRect(icon);
      expect(glyph.center.dx, closeTo(button.center.dx, .01));
      expect(glyph.center.dy, closeTo(button.center.dy, .01));
      expect(button.contains(glyph.topLeft), isTrue);
      expect(button.contains(glyph.bottomRight), isTrue);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
