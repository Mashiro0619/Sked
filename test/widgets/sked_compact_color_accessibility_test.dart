import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/theme/color_contrast.dart';
import 'package:sked/widgets/sked_compact_color_picker.dart';

Finder key(String value) => find.byKey(ValueKey(value));
Finder axis(String value) => key('compact-color-picker-$value');
Finder get hex => key('compact-color-picker-hex-field');

class _PickerHost extends StatefulWidget {
  const _PickerHost({super.key});

  @override
  State<_PickerHost> createState() => _PickerHostState();
}

class _PickerHostState extends State<_PickerHost> {
  int value = 0xff804040, revision = 0;
  bool valid = true, blocked = false;
  final changes = <int>[];

  void replace(int color) => setState(() {
    value = color;
    revision++;
  });

  void block() => setState(() => blocked = true);

  @override
  Widget build(BuildContext context) => FocusScope(
    canRequestFocus: !blocked,
    descendantsAreFocusable: !blocked,
    descendantsAreTraversable: !blocked,
    child: SkedCompactColorPicker(
      colorValue: value,
      resetToken: revision,
      invalidHexMessage: AppLocalizations.of(context).colorHexInvalid,
      onValidityChanged: (next) => setState(() => valid = next),
      onColorChanged: (next) => setState(() {
        value = next;
        changes.add(next);
      }),
    ),
  );
}

Future<GlobalKey<_PickerHostState>> _pumpPicker(
  WidgetTester t, {
  Locale locale = const Locale('en'),
  double scale = 1,
  TargetPlatform platform = TargetPlatform.android,
  ColorScheme? colors,
}) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = const Size(320, 850);
  addTearDown(t.view.reset);
  final host = GlobalKey<_PickerHostState>();
  await t.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        useMaterial3: true,
        platform: platform,
        colorScheme: colors,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Center(child: _PickerHost(key: host)),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  return host;
}

void act(WidgetTester t, String name, ui.SemanticsAction action) {
  final node = t.getSemantics(axis(name));
  expect(node.getSemanticsData().hasAction(action), isTrue);
  node.owner!.performAction(node.id, action);
}

String valueOf(WidgetTester t, String name) =>
    t.getSemantics(axis(name)).getSemanticsData().value;

void main() {
  for (final locale in [const Locale('en'), const Locale('zh')]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        '$locale color controls at ${scale}x expose named values and a full Hex label',
        (t) async {
          final semantics = t.ensureSemantics();
          try {
            await _pumpPicker(t, locale: locale, scale: scale);
            final l = AppLocalizations.of(t.element(hex));
            for (final (name, label) in [
              ('hue', l.colorPickerHue),
              ('saturation', l.colorPickerSaturation),
              ('value', l.colorPickerValue),
            ]) {
              final data = t.getSemantics(axis(name)).getSemanticsData();
              expect(data.label, label);
              expect(data.value, isNotEmpty);
              expect(data.flagsCollection.isSlider, isTrue);
              expect(data.hasAction(ui.SemanticsAction.increase), isTrue);
              expect(data.hasAction(ui.SemanticsAction.decrease), isTrue);
            }
            final editable = find.descendant(
              of: hex,
              matching: find.byType(EditableText),
            );
            expect(
              t.getSemantics(editable).getSemanticsData().label,
              l.colorPickerHex,
            );
            final label = t.renderObject<RenderParagraph>(
              find.text(l.colorPickerHex),
            );
            expect(label.didExceedMaxLines, isFalse);
            expect(t.getSize(axis('hue')).height, greaterThanOrEqualTo(48));
            expect(
              t.getSize(find.byType(ColorPickerSlider)).height,
              greaterThanOrEqualTo(48),
            );
            expect(t.takeException(), isNull);
          } finally {
            semantics.dispose();
          }
        },
      );
    }
  }

  testWidgets(
    'HSV semantic adjustments update the draft and preserve gray hue',
    (t) async {
      final semantics = t.ensureSemantics();
      try {
        final host = await _pumpPicker(t);
        expect(valueOf(t, 'saturation'), '50%');
        act(t, 'saturation', ui.SemanticsAction.increase);
        await t.pump();
        expect(valueOf(t, 'saturation'), '51%');
        expect(host.currentState!.value, isNot(0xff804040));
        act(t, 'saturation', ui.SemanticsAction.decrease);
        await t.pump();
        expect(host.currentState!.value, 0xff804040);
        act(t, 'value', ui.SemanticsAction.increase);
        await t.pump();
        expect(valueOf(t, 'value'), '51%');
        expect(valueOf(t, 'saturation'), '50%');
        act(t, 'value', ui.SemanticsAction.decrease);
        await t.pump();
        expect(valueOf(t, 'value'), '50%');

        host.currentState!.replace(0xff808080);
        await t.pump();
        act(t, 'hue', ui.SemanticsAction.increase);
        await t.pump();
        expect(valueOf(t, 'hue'), '1°');
        expect(host.currentState!.value, 0xff808080);
        act(t, 'saturation', ui.SemanticsAction.increase);
        await t.pump();
        expect(valueOf(t, 'hue'), '1°');
        expect(valueOf(t, 'saturation'), '1%');
        expect(host.currentState!.value, isNot(0xff808080));
        expect(
          t.widget<TextField>(hex).controller!.text,
          formatSkedColorHex(host.currentState!.value),
        );
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('keyboard uses both spectrum axes and the hue slider', (t) async {
    final semantics = t.ensureSemantics();
    try {
      await _pumpPicker(t);
      act(t, 'spectrum', ui.SemanticsAction.focus);
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await t.pump();
      expect(valueOf(t, 'saturation'), '51%');
      expect(valueOf(t, 'value'), '51%');
      await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await t.pump();
      expect(valueOf(t, 'saturation'), '50%');
      expect(valueOf(t, 'value'), '50%');
      act(t, 'hue', ui.SemanticsAction.focus);
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await t.pump();
      expect(valueOf(t, 'hue'), '1°');
      await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await t.pump();
      expect(valueOf(t, 'hue'), '0°');
      expect(t.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
    'pointer spectrum remains two dimensional and hue remains draggable',
    (t) async {
      final host = await _pumpPicker(t);
      final area = t.getRect(find.byType(ColorPickerArea));
      await t.tapAt(area.topLeft + Offset(area.width * .25, area.height * .4));
      await t.pump();
      var hsv = HSVColor.fromColor(Color(host.currentState!.value));
      expect(hsv.saturation, closeTo(.25, .01));
      expect(hsv.value, closeTo(.6, .01));
      final hue = t.getRect(find.byType(ColorPickerSlider));
      await t.dragFrom(hue.center, Offset(hue.width * .2, 0));
      await t.pumpAndSettle();
      hsv = HSVColor.fromColor(Color(host.currentState!.value));
      expect(hsv.hue, greaterThan(180));
      expect(
        t.widget<TextField>(hex).controller!.text,
        formatSkedColorHex(host.currentState!.value),
      );
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'invalid Hex survives layout changes until an explicit color choice',
    (t) async {
      final semantics = t.ensureSemantics();
      try {
        final host = await _pumpPicker(t);
        await t.enterText(hex, '#ZZ1234');
        await t.pump();
        t.view.physicalSize = const Size(850, 320);
        await t.pumpAndSettle();
        expect(host.currentState!.value, 0xff804040);
        expect(host.currentState!.valid, isFalse);
        expect(host.currentState!.changes, isEmpty);
        expect(t.widget<TextField>(hex).controller!.text, '#ZZ1234');
        act(t, 'hue', ui.SemanticsAction.increase);
        await t.pump();
        expect(host.currentState!.valid, isTrue);
        expect(host.currentState!.changes, hasLength(1));
        expect(
          t.widget<TextField>(hex).controller!.text,
          formatSkedColorHex(host.currentState!.value),
        );
        expect(t.widget<TextField>(hex).decoration!.errorText, isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('old adjustments obey the owning dialog focus guard', (t) async {
    final semantics = t.ensureSemantics();
    try {
      final host = await _pumpPicker(t);
      final saturation = t.widget<Semantics>(axis('saturation'));
      final hue = t.widget<Semantics>(axis('hue'));
      host.currentState!.block();
      await t.pumpAndSettle();
      saturation.properties.onIncrease!();
      hue.properties.onIncrease!();
      await t.pump();
      expect(host.currentState!.value, 0xff804040);
      expect(host.currentState!.changes, isEmpty);
      expect(
        t
            .getSemantics(axis('hue'))
            .getSemanticsData()
            .hasAction(ui.SemanticsAction.increase),
        isFalse,
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('desktop color slider retains compact height', (t) async {
    await _pumpPicker(t, platform: TargetPlatform.windows);
    expect(t.getSize(find.byType(ColorPickerSlider)).height, 40);
  });

  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets('$brightness keyboard focus has a contrasting inset gap', (
      t,
    ) async {
      final semantics = t.ensureSemantics();
      final originalHighlight = FocusManager.instance.highlightStrategy;
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      try {
        await _pumpPicker(
          t,
          colors: ColorScheme.fromSeed(
            seedColor: Colors.yellow,
            brightness: brightness,
          ).copyWith(primary: Colors.yellow),
        );
        for (final name in ['spectrum', 'hue']) {
          final initialSize = t.getSize(axis(name));
          act(t, name, ui.SemanticsAction.focus);
          await t.pumpAndSettle();
          final frames = find.descendant(
            of: key('compact-color-picker-$name-focus'),
            matching: find.byType(DecoratedBox),
          );
          final borders = t
              .widgetList<DecoratedBox>(frames)
              .map((frame) => (frame.decoration as BoxDecoration).border)
              .whereType<Border>()
              .toList();
          expect(borders.map((border) => border.top.width), [2, 4]);
          expect(borders.last.top.color.a, 1);
          expect(
            colorContrastRatio(borders.first.top.color, borders.last.top.color),
            greaterThanOrEqualTo(4.5),
          );
          expect(t.getSize(axis(name)), initialSize);
        }
      } finally {
        FocusManager.instance.highlightStrategy = originalHighlight;
        semantics.dispose();
      }
    });
  }
}
