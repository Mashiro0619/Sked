import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/app_home_screen.dart';

import '../support/workspace_harness.dart';

class _FirstLaunchStorage extends WorkspaceMemoryStorage {
  _FirstLaunchStorage(super.data);
  var saveCount = 0;

  @override
  Future<void> save(AppData value) async {
    saveCount++;
    await super.save(value);
  }
}

SemanticsNode? _linkNode(SemanticsNode root, String label) {
  if (root.getSemanticsData().label == label) return root;
  SemanticsNode? result;
  root.visitChildren((child) {
    result = _linkNode(child, label);
    return result == null;
  });
  return result;
}

void main() {
  for (final (locale, size, scale) in [
    ('en', const Size(1280, 800), 1.0),
    ('zh', const Size(320, 900), 2.0),
  ]) {
    testWidgets(
      'inline privacy link supports Tab, Enter, Space and semantics at $locale/$scale',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final previousStrategy = FocusManager.instance.highlightStrategy;
        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.alwaysTraditional;
        addTearDown(
          () => FocusManager.instance.highlightStrategy = previousStrategy,
        );
        const urlChannel = MethodChannel('plugins.flutter.io/url_launcher');
        final launches = <MethodCall>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          urlChannel,
          (call) async {
            launches.add(call);
            return true;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            urlChannel,
            null,
          ),
        );
        final storage = _FirstLaunchStorage(
          buildInitialAppData(buildDefaultPeriodTimes(), localeCode: locale),
        );
        final provider = await workspaceProvider(
          locale: locale,
          storage: storage,
        );
        addTearDown(provider.dispose);
        final semantics = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            WorkspaceHarness(
              provider: provider,
              locale: Locale(locale),
              textScale: scale,
              home: const AppHomeScreen(),
            ),
          );
          await tester.pumpAndSettle();
          final consent = find.byKey(
            const ValueKey('first-launch-privacy-consent'),
          );
          final focus = tester
              .widget<FocusableActionDetector>(
                find.byKey(const ValueKey('first-launch-privacy-link-focus')),
              )
              .focusNode!;
          TextSpan link() =>
              (tester.widget<Text>(consent).textSpan! as TextSpan).children![1]
                  as TextSpan;
          expect(link().style!.decoration, isNull);
          for (var step = 0; step < 4; step++) {
            await tester.sendKeyEvent(LogicalKeyboardKey.tab);
            await tester.pumpAndSettle();
          }
          expect(focus.hasPrimaryFocus, isTrue);
          expect(consent.hitTestable(), findsOneWidget);
          expect(link().style!.decoration, TextDecoration.underline);
          expect(link().style!.decorationThickness, 2);

          for (final key in [
            LogicalKeyboardKey.enter,
            LogicalKeyboardKey.space,
          ]) {
            final before = launches.length;
            await tester.sendKeyEvent(key);
            await tester.pumpAndSettle();
            expect(launches.length, before + 1);
          }

          final l10n = AppLocalizations.of(tester.element(consent));
          final node = _linkNode(
            tester.getSemantics(consent),
            l10n.firstLaunchPrivacyConsentLink,
          )!;
          expect(node.getSemanticsData().flagsCollection.isLink, isTrue);
          expect(
            node.getSemanticsData().hasAction(ui.SemanticsAction.tap),
            isTrue,
          );
          node.owner!.performAction(node.id, ui.SemanticsAction.tap);
          await tester.pumpAndSettle();
          expect(launches, hasLength(3));
          expect(provider.lifecycle.acceptedPrivacyPolicyVersion, isNull);
          expect(storage.saveCount, 0);
          expect(
            find.byKey(const ValueKey('first-launch-onboarding')),
            findsOneWidget,
          );

          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pumpAndSettle();
          expect(focus.hasFocus, isFalse);
          expect(link().style!.decoration, isNull);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }
}
