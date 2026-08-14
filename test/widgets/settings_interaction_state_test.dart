import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/widgets/settings_list.dart';
import 'package:sked/widgets/ui_command.dart';

void main() {
  testWidgets(
    'interaction blocker preserves enabled controls while blocking input',
    (tester) async {
      var blocked = false;
      var value = false;
      var changeCount = 0;
      late StateSetter rebuild;
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return Scaffold(
                body: SettingsInteractionBlocker(
                  blocked: blocked,
                  child: Switch(
                    key: const ValueKey('blocked-switch'),
                    focusNode: focusNode,
                    value: value,
                    onChanged: (next) {
                      changeCount += 1;
                      setState(() => value = next);
                    },
                  ),
                ),
              );
            },
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();
      expect(focusNode.hasFocus, isTrue);

      rebuild(() => blocked = true);
      await tester.pump();

      expect(focusNode.hasFocus, isFalse);
      final blockedSwitch = tester.widget<Switch>(
        find.byKey(const ValueKey('blocked-switch')),
      );
      expect(blockedSwitch.onChanged, isNotNull);
      expect(
        tester
            .widget<AbsorbPointer>(
              find.byWidgetPredicate(
                (widget) => widget is AbsorbPointer && widget.absorbing,
              ),
            )
            .absorbing,
        isTrue,
      );

      await tester.tap(
        find.byKey(const ValueKey('blocked-switch')),
        warnIfMissed: false,
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(value, isFalse);
      expect(changeCount, 0);

      rebuild(() => blocked = false);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('blocked-switch')));
      await tester.pump();
      expect(value, isTrue);
      expect(changeCount, 1);
    },
  );

  testWidgets('busy indicator delays visibility without changing height', (
    tester,
  ) async {
    var busy = false;
    late StateSetter rebuild;
    const indicatorKey = ValueKey('delayed-busy-indicator');

    Widget indicator() => UiCommandBusyIndicator(
      key: indicatorKey,
      busy: busy,
      showDelay: const Duration(milliseconds: 180),
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return Scaffold(body: indicator());
          },
        ),
      ),
    );

    final indicatorFinder = find.byKey(indicatorKey);
    expect(tester.getSize(indicatorFinder).height, 4);
    expect(find.byType(LinearProgressIndicator), findsNothing);

    rebuild(() => busy = true);
    await tester.pump();
    expect(tester.getSize(indicatorFinder).height, 4);
    expect(find.byType(LinearProgressIndicator), findsNothing);

    await tester.pump(const Duration(milliseconds: 179));
    expect(tester.getSize(indicatorFinder).height, 4);
    expect(find.byType(LinearProgressIndicator), findsNothing);

    await tester.pump(const Duration(milliseconds: 1));
    expect(tester.getSize(indicatorFinder).height, 4);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    rebuild(() => busy = false);
    await tester.pump();
    expect(tester.getSize(indicatorFinder).height, 4);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
}
