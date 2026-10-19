import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/widgets/sked_compact_color_picker.dart';
import 'package:sked/widgets/sked_task_dialog.dart';

void main() {
  for (final locale in [const Locale('en'), const Locale('zh')]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        '$locale Hex error wraps fully at $scale without replacing the draft',
        (t) async {
          t.view.devicePixelRatio = 1;
          t.view.physicalSize = const Size(360, 800);
          addTearDown(t.view.reset);
          var value = 0xff123456;
          var valid = true;
          final changes = <int>[];
          await t.pumpWidget(
            MaterialApp(
              locale: locale,
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: StatefulBuilder(
                    builder: (context, setState) => SkedCompactColorPicker(
                      colorValue: value,
                      invalidHexMessage: AppLocalizations.of(context)
                          .colorHexInvalid,
                      onValidityChanged: (next) => setState(() => valid = next),
                      onColorChanged: (next) => setState(() {
                        value = next;
                        changes.add(next);
                      }),
                    ),
                  ),
                ),
              ),
            ),
          );
          final field = find.byKey(
            const ValueKey('compact-color-picker-hex-field'),
          );
          await t.enterText(field, '#ZZ1234');
          await t.pumpAndSettle();
          final message = AppLocalizations.of(t.element(field)).colorHexInvalid;
          for (final width in [360.0, 320.0, 960.0]) {
            t.view.physicalSize = Size(width, 800);
            await t.pumpAndSettle();
            final error = t.renderObject<RenderParagraph>(find.text(message));
            expect(error.didExceedMaxLines, isFalse);
            expect(error.size.height, greaterThan(0));
            expect(t.widget<TextField>(field).controller!.text, '#ZZ1234');
            expect(valid, isFalse);
            expect(value, 0xff123456);
            expect(changes, isEmpty);
            expect(t.takeException(), isNull);
          }
          await t.enterText(field, '#AbC123');
          await t.pumpAndSettle();
          expect(find.text(message), findsNothing);
          expect(valid, isTrue);
          expect(changes, [0xffabc123]);
          expect(t.widget<TextField>(field).controller!.text, '#AbC123');
        },
      );
    }
  }

  testWidgets('preset repairs invalid Hex and restores valid callback', (
    t,
  ) async {
    var value = 0xff123456;
    var valid = true;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SkedTaskDialogScope(
              child: SkedCompactColorPicker(
                colorValue: value,
                invalidHexMessage: 'Invalid color',
                onValidityChanged: (v) => setState(() => valid = v),
                onColorChanged: (v) => setState(() => value = v),
              ),
            ),
          ),
        ),
      ),
    );
    final field = find.byKey(const ValueKey('compact-color-picker-hex-field'));
    await t.enterText(field, '#12ZZZZ');
    await t.pump();
    expect(valid, isFalse);
    await t.tap(find.byTooltip('#6750A4'));
    await t.pump();
    expect(valid, isTrue);
    expect(t.widget<TextField>(field).decoration!.errorText, isNull);
    expect(value, 0xff6750a4);
    expect(t.widget<TextField>(field).controller!.text, '#6750A4');
  });
}
