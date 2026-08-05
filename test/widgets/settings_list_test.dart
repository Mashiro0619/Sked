import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/widgets/expressive_motion.dart';
import 'package:sked/widgets/settings_list.dart';

void main() {
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
