import 'dart:ui' show PointerDeviceKind;

import 'package:material_ui/material_ui.dart';
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
}
