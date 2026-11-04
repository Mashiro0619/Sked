import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';

import '../support/workspace_harness.dart';

void main() {
  for (final width in [320.0, 360.0, 393.0, 412.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      for (final language in ['zh', 'en']) {
        testWidgets(
          'phone bar $width / $scale / $language keeps its touch layout compact and shifts the unpillled icon above the safe area',
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
            expect(t.widget<NavigationBar>(bar).destinations, hasLength(3));
            final barRect = t.getRect(bar);
            expect(
              barRect.height,
              height + 24,
            ); // The gesture inset is outside the content budget.
            final l = AppLocalizations.of(t.element(bar));
            var wraps = false;
            for (final (id, title) in [
              ('student', l.studentTimetable),
              ('general', l.generalSchedule),
              ('agent', l.agentTitle),
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
              expect(destination.hitTestable(), findsOneWidget);
              expect(target.width, closeTo(barRect.width / 3, .5));
              final group = t
                  .getRect(indicator)
                  .expandToInclude(t.getRect(label));
              expect(group.center.dx, closeTo(target.center.dx, .5));
              expect(group.center.dy, closeTo(barRect.top + height / 2, .5));
              expect(target.height, greaterThanOrEqualTo(48));
              expect(group.top, greaterThanOrEqualTo(target.top));
              expect(group.bottom, lessThanOrEqualTo(target.bottom));
              expect(
                t.widget<NavigationBar>(bar).indicatorColor,
                Colors.transparent,
              );
              final icon = find
                  .descendant(of: destination, matching: find.byType(Icon))
                  .first;
              expect(
                t.getCenter(icon).dy,
                closeTo(t.getCenter(indicator).dy + 4, .01),
              );
              final paragraph = t.renderObject<RenderParagraph>(label);
              final lines = paragraph
                  .getBoxesForSelection(
                    TextSelection(
                      baseOffset: 0,
                      extentOffset: paragraph.text.toPlainText().length,
                    ),
                  )
                  .map((box) => box.top)
                  .toSet();
              wraps = wraps || lines.length > 1;
              expect(paragraph.didExceedMaxLines, isFalse);
              expect(paragraph.textAlign, TextAlign.center);
            }
            expect(
              height,
              wraps ? greaterThan(64) : equals(64),
              reason: 'Grow only when a painted destination label wraps.',
            );
            expect(t.takeException(), isNull);
          },
          variant: const TargetPlatformVariant({TargetPlatform.android}),
        );
      }
    }
  }

  for (final scale in [1.3, 2.0]) {
    testWidgets(
      'Agent toggle recalculates the narrow bar destination budget at $scale',
      (t) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = const Size(320, 850);
        addTearDown(t.view.reset);
        final provider = await workspaceProvider(locale: 'zh');
        addTearDown(provider.dispose);
        await t.pumpWidget(
          WorkspaceHarness(
            provider: provider,
            locale: const Locale('zh'),
            textScale: scale,
          ),
        );
        await t.pumpAndSettle();
        final bar = find.byKey(const ValueKey('adaptive-shell-navigation-bar'));
        final agent = find.byKey(
          const ValueKey('adaptive-shell-agent-destination'),
        );
        expect(provider.agent.settings.enabled, isTrue);
        expect(t.widget<NavigationBar>(bar).destinations, hasLength(3));
        expect(t.widget<NavigationBar>(bar).height, greaterThan(64));
        expect(agent.hitTestable(), findsOneWidget);

        await provider.agent.setEnabled(false);
        await t.pumpAndSettle();
        expect(agent, findsNothing);
        expect(t.widget<NavigationBar>(bar).destinations, hasLength(2));
        expect(t.widget<NavigationBar>(bar).height, 64);
        final width = t.getSize(bar).width;
        for (final id in ['student', 'general']) {
          final destination = find.byKey(
            ValueKey('adaptive-shell-$id-destination'),
          );
          expect(destination.hitTestable(), findsOneWidget);
          expect(t.getSize(destination).width, closeTo(width / 2, .5));
          expect(t.getSize(destination).height, greaterThanOrEqualTo(48));
        }
        await t.tap(
          find.byKey(const ValueKey('adaptive-shell-general-destination')),
        );
        await t.pumpAndSettle();
        expect(provider.workspaceView.activeMode, AppMode.general);
        expect(t.widget<NavigationBar>(bar).selectedIndex, 1);

        await provider.agent.setEnabled(true);
        await t.pumpAndSettle();
        expect(t.widget<NavigationBar>(bar).destinations, hasLength(3));
        expect(t.widget<NavigationBar>(bar).height, greaterThan(64));
        expect(agent.hitTestable(), findsOneWidget);
        expect(t.getSize(agent).width, closeTo(width / 3, .5));
        expect(t.widget<NavigationBar>(bar).selectedIndex, 1);
        expect(provider.workspaceView.activeMode, AppMode.general);
        expect(t.takeException(), isNull);
      },
      variant: const TargetPlatformVariant({TargetPlatform.android}),
    );
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
      expect(t.widget<NavigationBar>(bar).destinations, hasLength(3));
      for (final id in ['student', 'general', 'agent']) {
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
