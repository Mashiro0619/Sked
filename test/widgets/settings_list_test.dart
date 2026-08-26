import 'dart:ui' show PointerDeviceKind, Rect, SemanticsAction;

import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/services.dart'
    show LogicalKeyboardKey, MethodCall, SystemChannels;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/widgets/expressive_motion.dart';
import 'package:sked/widgets/settings_list.dart';

void main() {
  testWidgets('responsive settings body switches at its usable column width', (
    tester,
  ) async {
    Future<void> pump(double width, {double textScale = 1}) async {
      await tester.binding.setSurfaceSize(Size(width, 640));
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: Scaffold(
              body: ResponsiveSettingsBody(
                firstColumnSectionIndices: const {0},
                children: const [
                  SettingsSectionHeader(title: 'First'),
                  SizedBox(height: 400),
                  SettingsSectionHeader(title: 'Second'),
                  SizedBox(height: 400),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pump(839);
    expect(
      find.byKey(const ValueKey('responsive-settings-single-column')),
      findsOneWidget,
    );

    await pump(840);
    expect(
      find.byKey(const ValueKey('responsive-settings-two-column')),
      findsOneWidget,
    );

    await pump(840, textScale: 1.31);
    expect(
      find.byKey(const ValueKey('responsive-settings-single-column')),
      findsOneWidget,
    );
  });

  testWidgets('wide settings gutters drag the single scroll viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ResponsiveSettingsSingleColumnBody(
            child: SizedBox(width: double.infinity, height: 1200),
          ),
        ),
      ),
    );

    final list = find.byType(ListView);
    final content = find.byKey(
      const ValueKey('responsive-settings-single-column-content'),
    );
    expect(tester.getSize(list).width, 1200);
    expect(tester.getSize(content).width, 720);

    final gesture = await tester.startGesture(
      const Offset(80, 500),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(0, -300));
    await gesture.up();
    await tester.pumpAndSettle();

    final scrollable = tester.state<ScrollableState>(
      find.descendant(of: list, matching: find.byType(Scrollable)),
    );
    expect(scrollable.position.pixels, greaterThan(0));
  });

  testWidgets('compact connected tile keeps its indicator inline at 2x text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: SettingsConnectedGroup(
                children: [
                  SettingsConnectedTile(
                    leading: const Icon(Icons.grid_view_outlined),
                    title: 'Timetable display and interaction with long text',
                    subtitle: 'Course popup, empty time, grid line, and gesture settings',
                    trailing: const Icon(
                      Icons.chevron_right,
                      key: ValueKey('compact-connected-indicator'),
                    ),
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final titleRect = tester.getRect(
      find.text('Timetable display and interaction with long text'),
    );
    final subtitleRect = tester.getRect(
      find.text('Course popup, empty time, grid line, and gesture settings'),
    );
    final indicatorRect = tester.getRect(
      find.byKey(const ValueKey('compact-connected-indicator')),
    );
    expect(indicatorRect.left, greaterThan(titleRect.right));
    expect(indicatorRect.left, greaterThan(subtitleRect.right));
    expect(
      indicatorRect.center.dy,
      closeTo((titleRect.top + subtitleRect.bottom) / 2, 1),
    );
    final trailingSlot = find.ancestor(
      of: find.byKey(const ValueKey('compact-connected-indicator')),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is ConstrainedBox &&
            widget.constraints.minWidth == 48 &&
            widget.constraints.minHeight == 48,
      ),
    );
    expect(trailingSlot, findsOneWidget);
    expect(tester.getSize(trailingSlot), const Size(48, 48));
    expect(tester.takeException(), isNull);
  });

  testWidgets('connected tile forwards a trailing switch state to semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var value = false;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: SettingsConnectedTile(
              key: const ValueKey('connected-toggle'),
              leading: const Icon(Icons.navigation_outlined),
              title: 'Hide bottom navigation',
              trailing: Switch(value: value, onChanged: (_) {}),
              semanticToggled: value,
              onTap: () => setState(() => value = !value),
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSemantics(find.byKey(const ValueKey('connected-toggle'))),
      matchesSemantics(
        label: 'Hide bottom navigation',
        hasEnabledState: true,
        isEnabled: true,
        hasToggledState: true,
        isToggled: false,
        hasTapAction: true,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('connected-toggle')));
    await tester.pump();
    expect(
      tester.getSemantics(find.byKey(const ValueKey('connected-toggle'))),
      matchesSemantics(
        label: 'Hide bottom navigation',
        hasEnabledState: true,
        isEnabled: true,
        hasToggledState: true,
        isToggled: true,
        hasTapAction: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets(
    'connected tile exposes one tap and long-press semantics node with hints',
    (tester) async {
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsConnectedTile(
              key: const ValueKey('developer-entry'),
              leading: const Icon(Icons.update_outlined),
              title: 'Check for updates',
              subtitle: 'Current version 2.1.0',
              onTap: () {},
              onTapHint: 'Check now',
              onLongPress: () {},
              onLongPressHint: 'Open developer mode',
            ),
          ),
        ),
      );

      expect(
        find.bySemanticsLabel('Check for updates, Current version 2.1.0'),
        findsOneWidget,
      );
      final data = tester
          .getSemantics(find.byKey(const ValueKey('developer-entry')))
          .getSemanticsData();
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      expect(data.hasAction(SemanticsAction.longPress), isTrue);
      expect(
        data.customSemanticsActionIds
            ?.map(CustomSemanticsAction.getAction)
            .whereType<CustomSemanticsAction>(),
        containsAll(<CustomSemanticsAction>[
          const CustomSemanticsAction.overridingAction(
            hint: 'Check now',
            action: SemanticsAction.tap,
          ),
          const CustomSemanticsAction.overridingAction(
            hint: 'Open developer mode',
            action: SemanticsAction.longPress,
          ),
        ]),
      );
      semantics.dispose();
    },
  );

  testWidgets('compact list tile keeps its indicator inline at 2x text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: SettingsListTile(
                leading: const Icon(Icons.palette_outlined),
                title: 'Theme appearance and language preferences',
                subtitle:
                    'Light theme, custom colors, and a long explanatory note',
                trailing: const Icon(
                  Icons.chevron_right,
                  key: ValueKey('compact-list-indicator'),
                ),
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );

    final titleRect = tester.getRect(
      find.text('Theme appearance and language preferences'),
    );
    final subtitleRect = tester.getRect(
      find.text('Light theme, custom colors, and a long explanatory note'),
    );
    final indicatorRect = tester.getRect(
      find.byKey(const ValueKey('compact-list-indicator')),
    );
    expect(indicatorRect.left, greaterThan(titleRect.right));
    expect(indicatorRect.left, greaterThan(subtitleRect.right));
    expect(
      indicatorRect.center.dy,
      closeTo((titleRect.top + subtitleRect.bottom) / 2, 1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact switch stays right of its full text block', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: SettingsSwitchTile(
                value: true,
                onChanged: (_) {},
                icon: Icons.navigation_outlined,
                title: 'Hide workspace navigation on the home screen',
                subtitle:
                    'Keep both workspaces available from settings when hidden',
              ),
            ),
          ),
        ),
      ),
    );

    final titleRect = tester.getRect(
      find.text('Hide workspace navigation on the home screen'),
    );
    final subtitleRect = tester.getRect(
      find.text('Keep both workspaces available from settings when hidden'),
    );
    final switchRect = tester.getRect(find.byType(Switch));
    expect(switchRect.left, greaterThan(titleRect.right));
    expect(switchRect.left, greaterThan(subtitleRect.right));
    expect(
      switchRect.center.dy,
      closeTo((titleRect.top + subtitleRect.bottom) / 2, 1),
    );
    expect(switchRect.width, greaterThanOrEqualTo(48));
    expect(switchRect.height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact slider keeps its value in the title row', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: SettingsSliderTile(
                icon: Icons.straighten,
                title: 'Maximum course information lines',
                value: 12,
                min: 1,
                max: 24,
                labelBuilder: (value) => '$value lines',
                onChangeEnd: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    final titleRect = tester.getRect(
      find.text('Maximum course information lines'),
    );
    final valueText = find.text('12 lines');
    final valueRect = tester.getRect(valueText);
    expect(valueRect.left, greaterThan(titleRect.right));
    expect(valueRect.center.dy, closeTo(titleRect.center.dy, 1));
    expect(tester.widget<Text>(valueText).maxLines, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disabled connected row dims leading, text, and trailing alike', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SettingsConnectedTile(
            key: ValueKey('disabled-connected-row'),
            leading: Icon(
              Icons.schedule_outlined,
              key: ValueKey('disabled-leading'),
            ),
            title: 'Period time set',
            subtitle: 'No timetable is currently available for settings.',
            trailing: Icon(
              Icons.keyboard_arrow_down,
              key: ValueKey('disabled-trailing'),
            ),
          ),
        ),
      ),
    );

    Color? inheritedIconColor(Finder finder) =>
        IconTheme.of(tester.element(finder)).color;

    final leadingColor = inheritedIconColor(
      find.byKey(const ValueKey('disabled-leading')),
    );
    final trailingColor = inheritedIconColor(
      find.byKey(const ValueKey('disabled-trailing')),
    );
    final titleColor = tester
        .widget<Text>(find.text('Period time set'))
        .style
        ?.color;
    final subtitleColor = tester
        .widget<Text>(
          find.text('No timetable is currently available for settings.'),
        )
        .style
        ?.color;

    expect(leadingColor, titleColor);
    expect(subtitleColor, titleColor);
    expect(trailingColor, titleColor);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SettingsSwitchTile switch tap changes once', (tester) async {
    final semantics = tester.ensureSemantics();
    var value = false;
    var changeCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              body: SettingsSwitchTile(
                value: value,
                icon: Icons.tune,
                title: 'Toggle setting',
                onChanged: (next) {
                  changeCount += 1;
                  setState(() => value = next);
                },
              ),
            );
          },
        ),
      ),
    );

    expect(find.bySemanticsLabel('Toggle setting'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(value, isTrue);
    expect(changeCount, 1);
    semantics.dispose();
  });

  testWidgets(
    'SettingsSwitchTile handles subtitle, tile tap, and disabled state',
    (tester) async {
      var value = false;
      var enabled = true;
      var changeCount = 0;
      late StateSetter rebuild;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return Scaffold(
                body: SettingsSwitchTile(
                  value: value,
                  icon: Icons.tune,
                  title: 'Detailed setting',
                  subtitle: 'Explains the setting',
                  onChanged: enabled
                      ? (next) {
                          changeCount += 1;
                          setState(() => value = next);
                        }
                      : null,
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.byType(ExpressiveTap));
      await tester.pump();
      expect(value, isTrue);
      expect(changeCount, 1);
      expect(find.text('Explains the setting'), findsOneWidget);

      rebuild(() => enabled = false);
      await tester.pump();
      expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);

      await tester.tap(find.byType(ExpressiveTap), warnIfMissed: false);
      await tester.pump();
      expect(changeCount, 1);
    },
  );

  testWidgets('SettingsSliderTile previews, commits, disables, and resyncs', (
    tester,
  ) async {
    var value = 5;
    var enabled = true;
    var maximum = 10;
    var commitCount = 0;
    late StateSetter rebuild;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return Scaffold(
              body: SettingsSliderTile(
                icon: Icons.straighten,
                title: 'Range setting',
                value: value,
                min: 0,
                max: maximum,
                labelBuilder: (next) => '$next units',
                enabled: enabled,
                onChangeEnd: (next) {
                  commitCount += 1;
                  setState(() => value = next);
                },
              ),
            );
          },
        ),
      ),
    );

    var slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChangeStart!(slider.value);
    slider.onChanged!(8);
    await tester.pump();
    expect(find.text('8 units'), findsOneWidget);

    slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChangeEnd!(8);
    await tester.pump();
    expect(value, 8);
    expect(commitCount, 1);

    rebuild(() => enabled = false);
    await tester.pump();
    slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.onChanged, isNull);
    expect(slider.onChangeEnd, isNull);

    rebuild(() {
      enabled = true;
      value = 20;
      maximum = 12;
    });
    await tester.pump();
    slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.value, 12);
    expect(find.text('12 units'), findsOneWidget);
  });

  testWidgets('toolbar editor handles keyboard moves and visibility', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final reordered = <List<String>>[];
    final visibilityChanges = <(String, bool)>[];

    const items = [
      SettingsToolbarNavigationItem(
        id: 'first',
        label: 'First',
        icon: Icons.looks_one_outlined,
        visible: true,
      ),
      SettingsToolbarNavigationItem(
        id: 'second',
        label: 'Second',
        icon: Icons.looks_two_outlined,
        visible: true,
      ),
      SettingsToolbarNavigationItem(
        id: 'settings',
        label: 'Settings',
        icon: Icons.settings_outlined,
        visible: true,
        canHide: false,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsToolbarNavigationEditor(
            items: items,
            reorderLabel: 'Reorder',
            visibilityLabel: 'Visibility',
            onReorder: (order) => reordered.add(order),
            onVisibilityChanged: (id, visible) =>
                visibilityChanges.add((id, visible)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    SemanticsNode semanticsFor(String label) =>
        tester.getSemantics(find.bySemanticsLabel(label));

    // The first item cannot move up; the second item can move down/up through
    // the same semantics actions exposed to keyboard and assistive technology.
    final firstSemantics = semanticsFor('Reorder: First');
    expect(
      firstSemantics.getSemanticsData().hasAction(SemanticsAction.decrease),
      isFalse,
    );
    final secondNode = semanticsFor('Reorder: Second');
    secondNode.owner!.performAction(secondNode.id, SemanticsAction.decrease);
    await tester.pump();
    expect(reordered.single, <String>['second', 'first', 'settings']);

    // Visibility remains independently actionable, while the required
    // settings item exposes a disabled switch.
    await tester.tap(find.byType(Switch).first);
    await tester.pump();
    expect(visibilityChanges, contains(('second', false)));
    expect(tester.widget<Switch>(find.byType(Switch).last).onChanged, isNull);

    expect(reordered, hasLength(1));
    expect(find.byType(DragTarget), findsNothing);
    semantics.dispose();
  });

  testWidgets('toolbar editor moves a focused handle with arrow keys', (
    tester,
  ) async {
    final reordered = <List<String>>[];
    const items = [
      SettingsToolbarNavigationItem(
        id: 'first',
        label: 'First',
        icon: Icons.looks_one_outlined,
        visible: true,
      ),
      SettingsToolbarNavigationItem(
        id: 'second',
        label: 'Second',
        icon: Icons.looks_two_outlined,
        visible: true,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsToolbarNavigationEditor(
            items: items,
            onReorder: reordered.add,
            onVisibilityChanged: (_, _) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final focusVisual = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('toolbar-navigation-drag-handle-visual-first')),
    );
    final focusShape =
        (focusVisual.decoration! as ShapeDecoration).shape
            as RoundedRectangleBorder;
    expect(focusShape.side.width, 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();

    expect(reordered, <List<String>>[
      <String>['second', 'first'],
    ]);
  });

  testWidgets(
    'toolbar editor restores the provider order after a failed save',
    (tester) async {
      final reordered = <List<String>>[];
      var busy = false;
      late StateSetter rebuild;
      const items = [
        SettingsToolbarNavigationItem(
          id: 'first',
          label: 'First',
          icon: Icons.looks_one_outlined,
          visible: true,
        ),
        SettingsToolbarNavigationItem(
          id: 'second',
          label: 'Second',
          icon: Icons.looks_two_outlined,
          visible: true,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return Scaffold(
                body: SettingsToolbarNavigationEditor(
                  items: items,
                  busy: busy,
                  onReorder: (order) {
                    reordered.add(order);
                    setState(() => busy = true);
                  },
                  onVisibilityChanged: (_, _) {},
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final semantics = tester.ensureSemantics();
      final second = tester.getSemantics(
        find.bySemanticsLabel('Reorder: Second'),
      );
      second.owner!.performAction(second.id, SemanticsAction.decrease);
      await tester.pump();
      expect(reordered, <List<String>>[
        <String>['second', 'first'],
      ]);
      expect(
        tester.getRect(find.text('Second')).top,
        lessThan(tester.getRect(find.text('First')).top),
      );

      // The Provider's snapshot remains in the original order, as it does when
      // persistence rejects the mutation. Ending the page command must restore
      // that source of truth rather than leaving an unsaved local reorder.
      rebuild(() => busy = false);
      await tester.pump();
      expect(
        tester.getRect(find.text('First')).top,
        lessThan(tester.getRect(find.text('Second')).top),
      );

      semantics.dispose();
    },
  );

  testWidgets('toolbar editor reorders with a primary mouse drag', (
    tester,
  ) async {
    final reordered = <List<String>>[];
    const items = [
      SettingsToolbarNavigationItem(
        id: 'first',
        label: 'First',
        icon: Icons.looks_one_outlined,
        visible: true,
      ),
      SettingsToolbarNavigationItem(
        id: 'second',
        label: 'Second',
        icon: Icons.looks_two_outlined,
        visible: true,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsToolbarNavigationEditor(
            items: items,
            onReorder: (order) => reordered.add(order),
            onVisibilityChanged: (_, _) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final handles = find.descendant(
      of: find.byKey(const ValueKey('toolbar-navigation-reorderable-list')),
      matching: find.byIcon(Icons.drag_indicator),
    );
    expect(handles, findsNWidgets(2));
    final gesture = await tester.startGesture(
      tester.getCenter(handles.at(0)),
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryButton,
    );
    await tester.pump();
    await gesture.moveBy(const Offset(0, 50));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(reordered, hasLength(1));
    expect(reordered.single, <String>['second', 'first']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('toolbar editor settles a drop before accepting another drag', (
    tester,
  ) async {
    final reordered = <List<String>>[];
    const items = [
      SettingsToolbarNavigationItem(
        id: 'first',
        label: 'First',
        icon: Icons.looks_one_outlined,
        visible: true,
      ),
      SettingsToolbarNavigationItem(
        id: 'second',
        label: 'Second',
        icon: Icons.looks_two_outlined,
        visible: true,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsToolbarNavigationEditor(
            items: items,
            onReorder: reordered.add,
            onVisibilityChanged: (_, _) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final firstHandle = find.byKey(
      const ValueKey('toolbar-navigation-drag-handle-first'),
    );
    final firstDrag = await tester.startGesture(
      tester.getCenter(firstHandle),
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryButton,
    );
    await tester.pump();
    await firstDrag.moveBy(const Offset(0, 50));
    await firstDrag.up();
    await tester.pump();

    // The native list is still returning the drag proxy to its destination.
    // A second pointer must not cancel the first drop before its callback runs.
    final secondDrag = await tester.startGesture(
      tester.getCenter(
        find.byKey(const ValueKey('toolbar-navigation-drag-handle-second')),
      ),
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryButton,
    );
    await tester.pump();
    await secondDrag.moveBy(const Offset(0, -50));
    await secondDrag.up();
    await tester.pumpAndSettle();

    expect(reordered, <List<String>>[
      <String>['second', 'first'],
    ]);
  });

  testWidgets('toolbar editor moves siblings before a mouse drag is released', (
    tester,
  ) async {
    final reordered = <List<String>>[];
    const items = [
      SettingsToolbarNavigationItem(
        id: 'first',
        label: 'First',
        icon: Icons.looks_one_outlined,
        visible: true,
      ),
      SettingsToolbarNavigationItem(
        id: 'second',
        label: 'Second',
        icon: Icons.looks_two_outlined,
        visible: true,
      ),
      SettingsToolbarNavigationItem(
        id: 'third',
        label: 'Third',
        icon: Icons.looks_3_outlined,
        visible: true,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsToolbarNavigationEditor(
            items: items,
            onReorder: (order) => reordered.add(order),
            onVisibilityChanged: (_, _) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final handles = find.byIcon(Icons.drag_indicator);
    final second = find.text('Second');
    final initialSecondTop = tester.getRect(second).top;
    final gesture = await tester.startGesture(
      tester.getCenter(handles.at(0)),
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryButton,
    );
    await tester.pump();
    for (var step = 0; step < 6; step++) {
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(tester.getRect(second).top, lessThan(initialSecondTop));
    expect(reordered, isEmpty);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(reordered, hasLength(1));
    expect(reordered.single, <String>['second', 'third', 'first']);
  });

  testWidgets('toolbar editor waits for a touch long press before reordering', (
    tester,
  ) async {
    final reordered = <List<String>>[];
    const items = [
      SettingsToolbarNavigationItem(
        id: 'first',
        label: 'First',
        icon: Icons.looks_one_outlined,
        visible: true,
      ),
      SettingsToolbarNavigationItem(
        id: 'second',
        label: 'Second',
        icon: Icons.looks_two_outlined,
        visible: true,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsToolbarNavigationEditor(
            items: items,
            onReorder: (order) => reordered.add(order),
            onVisibilityChanged: (_, _) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final handles = find.byIcon(Icons.drag_indicator);
    final gesture = await tester.startGesture(
      tester.getCenter(handles.at(0)),
      kind: PointerDeviceKind.touch,
    );
    await tester.pump(const Duration(milliseconds: 550));
    await tester.pump(const Duration(milliseconds: 400));
    for (var step = 0; step < 4; step++) {
      await gesture.moveBy(const Offset(0, 16));
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(reordered, isEmpty);
    await tester.pump(const Duration(milliseconds: 150));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(reordered, hasLength(1));
    expect(reordered.single, <String>['second', 'first']);
  });

  testWidgets('toolbar editor cancels a touch before the long press', (
    tester,
  ) async {
    final reordered = <List<String>>[];
    const items = [
      SettingsToolbarNavigationItem(
        id: 'first',
        label: 'First',
        icon: Icons.looks_one_outlined,
        visible: true,
      ),
      SettingsToolbarNavigationItem(
        id: 'second',
        label: 'Second',
        icon: Icons.looks_two_outlined,
        visible: true,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsToolbarNavigationEditor(
            items: items,
            onReorder: (order) => reordered.add(order),
            onVisibilityChanged: (_, _) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.drag_indicator).first),
      kind: PointerDeviceKind.touch,
    );
    await tester.pump(const Duration(milliseconds: 250));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(reordered, isEmpty);
  });

  testWidgets('toolbar editor cancels an active drag without saving', (
    tester,
  ) async {
    final reordered = <List<String>>[];
    const items = [
      SettingsToolbarNavigationItem(
        id: 'first',
        label: 'First',
        icon: Icons.looks_one_outlined,
        visible: true,
      ),
      SettingsToolbarNavigationItem(
        id: 'second',
        label: 'Second',
        icon: Icons.looks_two_outlined,
        visible: true,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsToolbarNavigationEditor(
            items: items,
            onReorder: reordered.add,
            onVisibilityChanged: (_, _) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.drag_indicator).first),
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryButton,
    );
    await tester.pump();
    await gesture.moveBy(const Offset(0, 50));
    await tester.pump(const Duration(milliseconds: 50));

    await gesture.cancel();
    await tester.pumpAndSettle();

    expect(reordered, isEmpty);
    expect(
      tester.getRect(find.text('First')).top,
      lessThan(tester.getRect(find.text('Second')).top),
    );
  });

  testWidgets('toolbar editor cancels when a drag leaves its list surface', (
    tester,
  ) async {
    final reordered = <List<String>>[];
    const items = [
      SettingsToolbarNavigationItem(
        id: 'first',
        label: 'First',
        icon: Icons.looks_one_outlined,
        visible: true,
      ),
      SettingsToolbarNavigationItem(
        id: 'second',
        label: 'Second',
        icon: Icons.looks_two_outlined,
        visible: true,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsToolbarNavigationEditor(
            items: items,
            onReorder: reordered.add,
            onVisibilityChanged: (_, _) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final listBounds = tester.getRect(
      find.byKey(const ValueKey('toolbar-navigation-reorderable-list')),
    );
    final reorderable = tester.widget<ReorderableList>(
      find.byType(ReorderableList),
    );
    final boundary = reorderable.dragBoundaryProvider!(
      tester.element(find.byType(ReorderableList)),
    );
    expect(boundary, isNotNull);
    expect(
      boundary!.isWithinBoundary(
        Rect.fromLTWH(listBounds.center.dx, listBounds.center.dy, 1, 1),
      ),
      isTrue,
    );
    expect(
      boundary.isWithinBoundary(
        Rect.fromLTWH(listBounds.center.dx, listBounds.bottom + 32, 1, 1),
      ),
      isFalse,
    );
    final handle = find.byIcon(Icons.drag_indicator).first;
    final gesture = await tester.startGesture(
      tester.getCenter(handle),
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryButton,
    );
    await tester.pump();
    await gesture.moveTo(
      Offset(tester.getCenter(handle).dx, listBounds.bottom + 32),
    );
    await tester.pumpAndSettle();

    expect(reordered, isEmpty);
    expect(
      tester.getRect(find.text('First')).top,
      lessThan(tester.getRect(find.text('Second')).top),
    );
    await gesture.up();
    await tester.pumpAndSettle();
    expect(reordered, isEmpty);
    expect(
      tester.getRect(find.text('First')).top,
      lessThan(tester.getRect(find.text('Second')).top),
    );
  });

  testWidgets('toolbar editor gives feedback only for a touch drag', (
    tester,
  ) async {
    final hapticCalls = <MethodCall>[];
    final previousTargetPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            hapticCalls.add(call);
          }
          return null;
        },
      );

      const items = [
        SettingsToolbarNavigationItem(
          id: 'first',
          label: 'First',
          icon: Icons.looks_one_outlined,
          visible: true,
        ),
        SettingsToolbarNavigationItem(
          id: 'second',
          label: 'Second',
          icon: Icons.looks_two_outlined,
          visible: true,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsToolbarNavigationEditor(
              items: items,
              onReorder: (_) {},
              onVisibilityChanged: (_, _) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final handles = find.byIcon(Icons.drag_indicator);
      final touchGesture = await tester.startGesture(
        tester.getCenter(handles.first),
        kind: PointerDeviceKind.touch,
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      expect(hapticCalls, hasLength(1));
      expect(hapticCalls.single.method, 'HapticFeedback.vibrate');
      await touchGesture.cancel();
      await tester.pumpAndSettle();

      hapticCalls.clear();
      final mouseGesture = await tester.startGesture(
        tester.getCenter(find.byIcon(Icons.drag_indicator).first),
        kind: PointerDeviceKind.mouse,
        buttons: kPrimaryButton,
      );
      await tester.pump();
      expect(hapticCalls, isEmpty);
      await mouseGesture.cancel();
      await tester.pumpAndSettle();
    } finally {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
      debugDefaultTargetPlatformOverride = previousTargetPlatform;
    }
  });
}
