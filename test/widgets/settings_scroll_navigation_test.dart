import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/screens/settings_page.dart';
import 'package:sked/screens/theme_settings_page.dart';

import '../support/workspace_harness.dart';

const _categories = [
  'student',
  'general',
  'notifications',
  'appearance',
  'features',
  'data',
  'about',
];

Finder _key(String id) => find.byKey(ValueKey(id));

Finder get _overview =>
    find.byKey(const PageStorageKey('settings-overview-scroll'));

ScrollController _overviewController(WidgetTester tester) =>
    tester.widget<ScrollView>(_overview).controller!;

Future<void> _pumpSettings(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1600, 900);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final provider = await workspaceProvider();
  addTearDown(provider.dispose);
  await tester.pumpWidget(
    WorkspaceHarness(provider: provider, home: const SettingsPage()),
  );
  await tester.pumpAndSettle();
}

void _expectSelected(WidgetTester tester, String category) {
  for (final id in _categories) {
    expect(
      tester.widget<ListTile>(_key('settings-category-$id')).selected,
      id == category,
      reason: 'The sidebar should select only $category after scrolling.',
    );
  }
}

Future<void> _wheelScroll(WidgetTester tester, double delta) async {
  final viewport = tester.getRect(_overview);
  await tester.sendEventToBinding(
    PointerScrollEvent(
      position: Offset(viewport.right - 32, viewport.center.dy),
      scrollDelta: Offset(0, delta),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _readSection(WidgetTester tester, String category) async {
  final header = find.descendant(
    of: _key('settings-overview-app-bar'),
    matching: find.byType(AppBar),
  );
  final section = _key('settings-overview-$category');
  // Drive the real desktop wheel path. Put the section just under the pinned
  // toolbar so the previous section has completely left the reading area.
  final readingTop = tester.getBottomLeft(header).dy;
  await _wheelScroll(tester, tester.getTopLeft(section).dy - readingTop + 16);
  expect(tester.getTopLeft(section).dy, lessThan(readingTop));
  expect(tester.getBottomLeft(section).dy, greaterThan(readingTop));
}

void main() {
  testWidgets(
    'desktop sidebar follows overview wheel scrolling down and back up',
    (tester) async {
      await _pumpSettings(tester);
      _expectSelected(tester, 'student');

      for (final category in ['general', 'notifications', 'appearance']) {
        await _readSection(tester, category);
        _expectSelected(tester, category);
      }
      for (final category in ['notifications', 'general']) {
        await _readSection(tester, category);
        _expectSelected(tester, category);
      }
      await _wheelScroll(tester, -_overviewController(tester).offset);
      _expectSelected(tester, 'student');
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'desktop sidebar selects the final category at the end of the overview',
    (tester) async {
      await _pumpSettings(tester);
      final controller = _overviewController(tester);
      expect(controller.position.maxScrollExtent, greaterThan(0));
      await _wheelScroll(tester, controller.position.maxScrollExtent + 1);

      expect(
        controller.offset,
        closeTo(controller.position.maxScrollExtent, .01),
      );
      expect(_key('settings-about').hitTestable(), findsOneWidget);
      _expectSelected(tester, 'about');

      await _readSection(tester, 'appearance');
      _expectSelected(tester, 'appearance');
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'desktop sidebar resumes following wheel scrolling after category clicks',
    (tester) async {
      await _pumpSettings(tester);
      await tester.tap(_key('settings-category-appearance'));
      await tester.pumpAndSettle();
      _expectSelected(tester, 'appearance');

      await _readSection(tester, 'notifications');
      _expectSelected(tester, 'notifications');
      await _readSection(tester, 'appearance');
      _expectSelected(tester, 'appearance');
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'desktop sidebar keeps clicked categories that cannot reach the top',
    (tester) async {
      await _pumpSettings(tester);
      final controller = _overviewController(tester);
      for (final category in ['features', 'data']) {
        await tester.tap(_key('settings-category-$category'));
        await tester.pumpAndSettle();

        expect(
          controller.offset,
          closeTo(controller.position.maxScrollExtent, .01),
          reason: 'The trailing categories share the bottom scroll limit.',
        );
        expect(
          _key('settings-overview-$category').hitTestable(),
          findsOneWidget,
        );
        _expectSelected(tester, category);

        await _readSection(tester, 'appearance');
        _expectSelected(tester, 'appearance');
      }
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'desktop sidebar follows wheel input that interrupts a category jump',
    (tester) async {
      await _pumpSettings(tester);
      final controller = _overviewController(tester);
      await tester.tap(_key('settings-category-appearance'));
      // Start the jump after its layout frame, then stop partway through the
      // standard 150 ms fast effect with one wheel event in the other direction.
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(controller.offset, greaterThan(0));
      _expectSelected(tester, 'appearance');

      await _wheelScroll(tester, -controller.offset);

      expect(controller.offset, closeTo(0, .01));
      _expectSelected(tester, 'student');
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'desktop sidebar follows the reading section after hiding and restoring it',
    (tester) async {
      await _pumpSettings(tester);
      await _readSection(tester, 'appearance');
      _expectSelected(tester, 'appearance');
      final controller = _overviewController(tester);

      tester.view.physicalSize = const Size(660, 900);
      await tester.pumpAndSettle();
      expect(_key('settings-category-appearance').hitTestable(), findsNothing);
      expect(_overviewController(tester), same(controller));
      await _readSection(tester, 'notifications');

      tester.view.physicalSize = const Size(1600, 900);
      await tester.pumpAndSettle();
      expect(_overviewController(tester), same(controller));
      expect(
        _key('settings-category-notifications').hitTestable(),
        findsOneWidget,
      );
      _expectSelected(tester, 'notifications');
      await _readSection(tester, 'general');
      _expectSelected(tester, 'general');
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'desktop overview keeps its active category after returning from details',
    (tester) async {
      await _pumpSettings(tester);
      await _readSection(tester, 'appearance');
      final controller = _overviewController(tester);
      final overviewOffset = controller.offset;
      await tester.tap(_key('settings-appearance-details'));
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (widget) => widget is ThemeSettingsPage && !widget.embedded,
        ),
        findsOneWidget,
      );

      await tester.tap(find.byType(BackButton).hitTestable());
      await tester.pumpAndSettle();
      expect(_overview, findsOneWidget);
      expect(controller.offset, closeTo(overviewOffset, .01));
      _expectSelected(tester, 'appearance');
      await _readSection(tester, 'notifications');
      _expectSelected(tester, 'notifications');
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
