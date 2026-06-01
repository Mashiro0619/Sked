import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/widgets/settings_list.dart';

void main() {
  testWidgets('SettingsSwitchTile switch tap changes once', (tester) async {
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

    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(value, isTrue);
    expect(changeCount, 1);
  });
}
