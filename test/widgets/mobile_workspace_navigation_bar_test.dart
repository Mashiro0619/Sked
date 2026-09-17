import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';

import '../support/workspace_harness.dart';

void main() {
  for (final width in [320.0, 360.0, 393.0, 412.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      for (final language in ['zh', 'en']) {
        testWidgets(
          'phone bar $width / $scale / $language is compact and centers the visible group above the safe area',
          (t) async {
            t.view.devicePixelRatio = 1;
            t.view.physicalSize = Size(width, 850);
            t.view.padding = const FakeViewPadding(top: 24, bottom: 24);
            t.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
            addTearDown(t.view.resetDevicePixelRatio);
            addTearDown(t.view.resetPhysicalSize);
            addTearDown(t.view.resetPadding);
            addTearDown(t.view.resetViewPadding);
            final provider = await workspaceProvider(locale: language);
            addTearDown(provider.dispose);
            await t.pumpWidget(
              WorkspaceHarness(
                provider: provider,
                locale: Locale(language),
                textScale: scale,
              ),
            );
            await t.pumpAndSettle();
            final bar = find.byKey(
              const ValueKey('adaptive-shell-navigation-bar'),
            );
            final height = t.widget<NavigationBar>(bar).height!;
            expect(height, greaterThanOrEqualTo(64));
            if (language == 'zh') expect(height, 64);
            final barRect = t.getRect(bar);
            expect(
              barRect.height,
              height + 24,
            ); // 64 content + one 24dp gesture inset.
            final l = AppLocalizations.of(t.element(bar));
            for (final (id, title) in [
              ('student', l.studentTimetable),
              ('general', l.generalSchedule),
            ]) {
              final destination = find.byKey(
                ValueKey('adaptive-shell-$id-destination'),
              );
              final indicator = find.descendant(
                of: destination,
                matching: find.byType(NavigationIndicator),
              );
              final label = find.descendant(
                of: destination,
                matching: find.text(title),
              );
              final target = t.getRect(destination);
              final group = t
                  .getRect(indicator)
                  .expandToInclude(t.getRect(label));
              expect(group.center.dx, closeTo(target.center.dx, .5));
              expect(group.center.dy, closeTo(barRect.top + height / 2, .5));
              expect(target.height, greaterThanOrEqualTo(48));
              expect(group.top, greaterThanOrEqualTo(target.top));
              expect(group.bottom, lessThanOrEqualTo(target.bottom));
              final paragraph = t.renderObject<RenderParagraph>(label);
              expect(paragraph.didExceedMaxLines, isFalse);
              expect(paragraph.textAlign, TextAlign.center);
            }
            expect(t.takeException(), isNull);
          },
          variant: const TargetPlatformVariant({TargetPlatform.android}),
        );
      }
    }
  }

  testWidgets(
    'long labels may grow the compact bar without shrinking or left-aligning wrapped text',
    (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(280, 850);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.view.resetPhysicalSize);
      final provider = await workspaceProvider(locale: 'de');
      addTearDown(provider.dispose);
      await t.pumpWidget(
        WorkspaceHarness(
          provider: provider,
          locale: const Locale('de'),
          textScale: 2,
        ),
      );
      await t.pumpAndSettle();
      final bar = find.byKey(const ValueKey('adaptive-shell-navigation-bar'));
      final height = t.widget<NavigationBar>(bar).height!;
      expect(height, greaterThanOrEqualTo(64));
      for (final id in ['student', 'general']) {
        final destination = find.byKey(
          ValueKey('adaptive-shell-$id-destination'),
        );
        final label = find
            .descendant(of: destination, matching: find.byType(Text))
            .first;
        expect(
          t.renderObject<RenderParagraph>(label).textAlign,
          TextAlign.center,
        );
        expect(
          t.getRect(destination).contains(t.getRect(label).center),
          isTrue,
        );
        expect(
          t.getRect(label).bottom,
          lessThanOrEqualTo(t.getRect(destination).bottom),
        );
      }
      expect(t.takeException(), isNull);
    },
    variant: const TargetPlatformVariant({TargetPlatform.android}),
  );
}
