import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/widgets/expressive_motion.dart';
import 'package:sked/widgets/settings_list.dart';

void main() {
  testWidgets('compact connected tile keeps its indicator inline', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsConnectedGroup(
            children: [
              SettingsConnectedTile(
                leading: const Icon(Icons.grid_view_outlined),
                title: 'Timetable display and interaction',
                subtitle: 'Course popup, empty time, and grid line settings',
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
    );

    final titleRect = tester.getRect(
      find.text('Timetable display and interaction'),
    );
    final subtitleRect = tester.getRect(
      find.text('Course popup, empty time, and grid line settings'),
    );
    final indicatorRect = tester.getRect(
      find.byKey(const ValueKey('compact-connected-indicator')),
    );
    expect(indicatorRect.center.dy, greaterThanOrEqualTo(titleRect.top));
    expect(indicatorRect.center.dy, lessThanOrEqualTo(subtitleRect.bottom));
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

  testWidgets('compact list tile keeps its indicator inline at large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
          child: Scaffold(
            body: SettingsListTile(
              leading: const Icon(Icons.palette_outlined),
              title: 'Theme appearance',
              subtitle: 'Light theme and custom colors',
              trailing: const Icon(
                Icons.chevron_right,
                key: ValueKey('compact-list-indicator'),
              ),
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    final titleRect = tester.getRect(find.text('Theme appearance'));
    final subtitleRect = tester.getRect(
      find.text('Light theme and custom colors'),
    );
    final indicatorRect = tester.getRect(
      find.byKey(const ValueKey('compact-list-indicator')),
    );
    expect(indicatorRect.center.dy, greaterThanOrEqualTo(titleRect.top));
    expect(indicatorRect.center.dy, lessThanOrEqualTo(subtitleRect.bottom));
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
