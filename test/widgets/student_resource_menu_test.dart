import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/widgets/workbench_chrome_metrics.dart';

import '../support/workspace_harness.dart';

Finder k(String value) => find.byKey(ValueKey(value));

void main() {
  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      for (final empty in [true, false]) {
        testWidgets(
          'student resource menu is centered: $platform scale=$scale empty=$empty',
          (t) async {
            t.view.devicePixelRatio = 1;
            t.view.physicalSize = const Size(1920, 1080);
            addTearDown(t.view.resetDevicePixelRatio);
            addTearDown(t.view.resetPhysicalSize);
            final p = await workspaceProvider(
              locale: 'zh',
              storage: empty
                  ? WorkspaceMemoryStorage(
                      buildInitialAppData(
                        buildDefaultPeriodTimes(),
                        localeCode: 'zh',
                      ),
                    )
                  : null,
            );
            addTearDown(p.dispose);
            await t.pumpWidget(
              WorkspaceHarness(
                provider: p,
                locale: const Locale('zh'),
                textScale: scale,
                textDirection: scale == 1.3
                    ? TextDirection.rtl
                    : TextDirection.ltr,
                brightness: scale == 2 ? Brightness.dark : Brightness.light,
              ),
            );
            await t.pumpAndSettle();
            final menu = k('student-resource-menu').hitTestable();
            expect(menu, findsOneWidget);
            final metrics = WorkbenchChromeMetrics.of(t.element(menu));
            final l = AppLocalizations.of(t.element(menu));
            final add = find.descendant(
              of: k('workspace-resource-panel').hitTestable(),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is IconButton && widget.tooltip == l.createTimetable,
              ),
            );
            final moreIcon = find.descendant(
              of: menu,
              matching: find.byIcon(Icons.more_horiz),
            );
            final addIcon = find.descendant(
              of: add,
              matching: find.byIcon(Icons.add),
            );
            final glyph = find.descendant(
              of: moreIcon,
              matching: find.byType(RichText),
            );
            final menuRect = t.getRect(menu);
            final paragraph = t.renderObject<RenderParagraph>(glyph);
            final glyphBox = paragraph
                .getBoxesForSelection(
                  const TextSelection(baseOffset: 0, extentOffset: 1),
                )
                .single
                .toRect();
            final paintedCenter = paragraph.localToGlobal(glyphBox.center);
            expect(
              (paintedCenter - menuRect.center).distance,
              lessThan(0.001),
              reason: 'The glyph must not overflow a smaller layout box.',
            );
            // Check the actual icon-font layout as well as the outer Icon box.
            // An oversized glyph can overflow a centered, constrained Icon.
            expect(
              (t.getCenter(glyph) - menuRect.center).distance,
              lessThan(0.001),
            );
            expect(
              (t.getCenter(moreIcon) - menuRect.center).distance,
              lessThan(0.001),
            );
            expect(
              t.getCenter(glyph).dy,
              closeTo(t.getCenter(addIcon).dy, 0.001),
            );
            expect(
              IconTheme.of(t.element(moreIcon)).size,
              metrics.desktop ? 18 : 22,
            );
            expect(t.getSize(moreIcon), t.getSize(addIcon));
            expect(menuRect.size, Size.square(metrics.iconTarget));
            expect(menuRect.size, t.getSize(add));
            final glyphRect = t.getRect(glyph);
            expect(glyphRect.left, greaterThanOrEqualTo(menuRect.left));
            expect(glyphRect.right, lessThanOrEqualTo(menuRect.right));
            expect(glyphRect.top, greaterThanOrEqualTo(menuRect.top));
            expect(glyphRect.bottom, lessThanOrEqualTo(menuRect.bottom));
            await t.tapAt(menuRect.center);
            await t.pumpAndSettle();
            for (final value in ['periods', 'import', 'export']) {
              expect(
                find.byWidgetPredicate(
                  (widget) =>
                      widget is PopupMenuItem<String> && widget.value == value,
                ),
                findsOneWidget,
              );
            }
            await t.sendKeyEvent(LogicalKeyboardKey.escape);
            await t.pumpAndSettle();
            expect(menu.hitTestable(), findsOneWidget);
            expect(t.getRect(menu), menuRect);
            expect(t.takeException(), isNull);
          },
          variant: TargetPlatformVariant.only(platform),
        );
      }
    }
  }
}
