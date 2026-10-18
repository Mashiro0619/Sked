import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/theme/app_theme.dart';
import 'package:sked/utils/constants.dart';
import 'package:sked/widgets/settings_list.dart';
import 'package:sked/widgets/sked_dropdown_menu.dart';
import 'package:sked/widgets/sked_popup_menu.dart';

const skedMenuStyleCaptureKey = ValueKey('sked-menu-style-capture');

typedef SkedMenuStyleCapture = Future<void> Function(
  WidgetTester tester,
  String scene,
);

enum _MenuKind { popup, focusedPopup, direct, dropdown, settings }

const _triggerKey = ValueKey('menu-style-trigger');
const _selectedLabel = 'Selected choice';
const _otherLabel = 'Other choice';
const _disabledLabel = 'Unavailable choice';
const _entries = [
  DropdownMenuEntry(value: 'selected', label: _selectedLabel),
  DropdownMenuEntry(value: 'other', label: _otherLabel),
  DropdownMenuEntry(value: 'disabled', label: _disabledLabel, enabled: false),
];

class _MenuHarness extends StatefulWidget {
  const _MenuHarness({
    super.key,
    required this.kind,
    required this.theme,
    required this.results,
    this.entries = _entries,
    this.textScale = 1,
  });

  final _MenuKind kind;
  final ThemeData theme;
  final List<String?> results;
  final List<DropdownMenuEntry<String>> entries;
  final double textScale;

  @override
  State<_MenuHarness> createState() => _MenuHarnessState();
}

class _MenuHarnessState extends State<_MenuHarness> {
  final triggerFocus = FocusNode(debugLabel: 'Menu style trigger');
  String selected = 'selected';

  void select(String? value) {
    widget.results.add(value);
    if (value != null) setState(() => selected = value);
  }

  List<PopupMenuEntry<String>> popupEntries() => [
    for (final entry in widget.entries)
      SkedCheckedPopupMenuItem(
        value: entry.value,
        checked: selected == entry.value,
        enabled: entry.enabled,
        label: entry.label,
      ),
  ];

  Widget control(BuildContext context) => switch (widget.kind) {
    _MenuKind.popup => SkedPopupMenuButton<String>(
      key: _triggerKey,
      itemBuilder: (_) => popupEntries(),
      onSelected: select,
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Text('Open choices'),
      ),
    ),
    _MenuKind.focusedPopup => SkedPopupMenuButton<String>(
      key: _triggerKey,
      focusNode: triggerFocus,
      itemBuilder: (_) => popupEntries(),
      onSelected: select,
      icon: const Icon(Icons.more_horiz),
      tooltip: 'Open choices',
    ),
    _MenuKind.direct => TextButton(
      key: _triggerKey,
      focusNode: triggerFocus,
      onPressed: () async {
        final button = context.findRenderObject()! as RenderBox;
        final overlay =
            Navigator.of(context).overlay!.context.findRenderObject()!
                as RenderBox;
        final origin = button.localToGlobal(
          Offset(0, button.size.height),
          ancestor: overlay,
        );
        final value = await showSkedMenu<String>(
          context: context,
          position: RelativeRect.fromRect(
            origin & Size(button.size.width, 0),
            Offset.zero & overlay.size,
          ),
          requestFocus: true,
          items: popupEntries(),
        );
        if (mounted && value != null) select(value);
      },
      child: const Text('Open choices'),
    ),
    _MenuKind.dropdown => SkedDropdownMenu<String>(
      key: _triggerKey,
      initialSelection: selected,
      expandedInsets: EdgeInsets.zero,
      dropdownMenuEntries: widget.entries,
      onSelected: select,
    ),
    _MenuKind.settings => SettingsChoiceTile<String>(
      key: _triggerKey,
      title: 'Layout',
      icon: Icons.view_week_outlined,
      value: selected,
      entries: widget.entries,
      onSelected: select,
      changesAppData: false,
    ),
  };

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    key: skedMenuStyleCaptureKey,
    child: MaterialApp(
      theme: widget.theme,
      locale: const Locale('en'),
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(widget.textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.fromLTRB(24, 64, 24, 24),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: 280, child: Builder(builder: control)),
          ),
        ),
      ),
    ),
  );

  @override
  void dispose() {
    triggerFocus.dispose();
    super.dispose();
  }
}

Finder _text(String label) =>
    find.byWidgetPredicate((widget) => widget is Text && widget.data == label);

Finder _menuEntry(String label) => find.ancestor(
  of: _text(label),
  matching: find.byWidgetPredicate(
    (widget) => widget is PopupMenuItem || widget is MenuItemButton,
  ),
);

Finder _surface() => find
    .ancestor(
      of: _menuEntry(_otherLabel),
      matching: find.byWidgetPredicate(
        (widget) => widget is Material && widget.elevation > 0,
      ),
    )
    .first;

Finder _label(Finder surface, String label) =>
    find.descendant(of: surface, matching: _text(label));

Finder _row(Finder surface, String label) => find
    .ancestor(of: _label(surface, label), matching: find.byType(InkWell))
    .first;

TextStyle _paintedTextStyle(WidgetTester tester, Finder label) =>
    tester.renderObject<RenderParagraph>(label).text.style!;

Future<List<Color>> _pixels(
  WidgetTester tester,
  List<Offset> points,
) async => (await tester.runAsync(() async {
  final image = await tester
      .renderObject<RenderRepaintBoundary>(find.byKey(skedMenuStyleCaptureKey))
      .toImage(pixelRatio: 1);
  try {
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    return points.map((point) {
      final offset = (point.dy.floor() * image.width + point.dx.floor()) * 4;
      return Color.fromARGB(
        bytes.getUint8(offset + 3),
        bytes.getUint8(offset),
        bytes.getUint8(offset + 1),
        bytes.getUint8(offset + 2),
      );
    }).toList();
  } finally {
    image.dispose();
  }
}))!;

void _expectColor(Color actual, Color expected, String reason) {
  expect(actual.r, closeTo(expected.r, 2 / 255), reason: reason);
  expect(actual.g, closeTo(expected.g, 2 / 255), reason: reason);
  expect(actual.b, closeTo(expected.b, 2 / 255), reason: reason);
  expect(actual.a, closeTo(1, 1 / 255), reason: reason);
}

typedef _Appearance = ({
  Color surface,
  OutlinedBorder shape,
  double elevation,
  Color? shadow,
  FontWeight? weight,
  double? labelSize,
});

_Appearance _inspectMenu(WidgetTester tester, Finder surface, ThemeData theme) {
  final desktop = theme.platform == TargetPlatform.windows;
  final material = tester.widget<Material>(surface);
  expect(material.color, theme.colorScheme.surface.withValues(alpha: 1));
  expect(material.surfaceTintColor, Colors.transparent);
  expect(material.elevation, desktop ? 2 : 3);
  expect(
    material.shadowColor,
    theme.colorScheme.shadow.withValues(alpha: desktop ? .14 : .18),
  );
  expect(material.shape, isA<OutlinedBorder>());
  final shape = material.shape! as OutlinedBorder;
  expect(shape.side.style, BorderStyle.solid);
  expect(shape.side.width, closeTo(1, .01));
  expect(shape.side.color.a, greaterThan(0));
  final outline = shape.getOuterPath(const Rect.fromLTWH(0, 0, 100, 100));
  expect(outline.contains(const Offset(50, 50)), isTrue);
  expect(outline.contains(const Offset(.1, .1)), isFalse);
  if (desktop) {
    expect(
      shape.side.color,
      theme.colorScheme.outlineVariant.withValues(alpha: .65),
    );
    expect(shape, isA<RoundedRectangleBorder>());
    expect(
      (shape as RoundedRectangleBorder).borderRadius.resolve(TextDirection.ltr),
      BorderRadius.circular(8),
    );
  }
  for (final label in [_selectedLabel, _otherLabel, _disabledLabel]) {
    final row = _row(surface, label);
    expect(tester.getSize(row).height, closeTo(desktop ? 32 : 48, .1));
    expect(
      _paintedTextStyle(tester, _label(surface, label)).fontWeight,
      desktop ? FontWeight.w400 : FontWeight.w600,
    );
    if (desktop) {
      final rowRect = tester.getRect(row);
      final textRect = tester.getRect(_label(surface, label));
      expect(textRect.top - rowRect.top, greaterThanOrEqualTo(5.9));
      expect(rowRect.bottom - textRect.bottom, greaterThanOrEqualTo(5.9));
    }
  }
  final normal = _paintedTextStyle(tester, _label(surface, _otherLabel));
  expect(normal.fontSize, theme.textTheme.labelLarge?.fontSize ?? 14);
  expect(normal.color, theme.colorScheme.onSurface);
  expect(
    _paintedTextStyle(tester, _label(surface, _disabledLabel)).color,
    theme.colorScheme.onSurface.withValues(alpha: .38),
  );
  expect(
    find.descendant(
      of: _row(surface, _selectedLabel),
      matching: find.byIcon(Icons.check),
    ),
    findsOneWidget,
  );
  expect(
    find.descendant(
      of: _row(surface, _otherLabel),
      matching: find.byIcon(Icons.check),
    ),
    findsNothing,
  );
  final rowRect = tester.getRect(_row(surface, _selectedLabel));
  final labelRect = tester.getRect(_label(surface, _selectedLabel));
  final checkRect = tester.getRect(
    find.descendant(
      of: _row(surface, _selectedLabel),
      matching: find.byIcon(Icons.check),
    ),
  );
  expect(labelRect.left - rowRect.left, closeTo(desktop ? 10 : 12, .01));
  expect(rowRect.right - checkRect.right, closeTo(desktop ? 10 : 12, .01));
  expect(checkRect.left - labelRect.right, closeTo(desktop ? 8 : 12, .01));
  expect(checkRect.width, closeTo(desktop ? 16 : 20, .01));
  expect(checkRect.height, closeTo(desktop ? 16 : 20, .01));
  expect(
    tester.getRect(_label(surface, _otherLabel)).left,
    closeTo(labelRect.left, .01),
    reason: 'Selected and unselected labels share their start edge.',
  );
  final rows = [
    for (final label in [_selectedLabel, _otherLabel, _disabledLabel])
      tester.getRect(_row(surface, label)),
  ];
  final surfaceRect = tester.getRect(surface);
  expect(rows.first.left - surfaceRect.left, closeTo(4, .01));
  expect(surfaceRect.right - rows.first.right, closeTo(4, .01));
  expect(rows.first.top - surfaceRect.top, closeTo(desktop ? 4 : 8, .01));
  expect(surfaceRect.bottom - rows.last.bottom, closeTo(desktop ? 4 : 8, .01));
  for (var index = 1; index < rows.length; index++) {
    expect(
      rows[index].top - rows[index - 1].bottom,
      closeTo(desktop ? 0 : 4, .01),
    );
  }
  expect(
    surfaceRect.height,
    closeTo(desktop ? 104 : 168, .1),
    reason:
        'Three standard rows include only the agreed menu padding and margins.',
  );
  return (
    surface: material.color!,
    shape: shape,
    elevation: material.elevation,
    shadow: material.shadowColor,
    weight: normal.fontWeight,
    labelSize: normal.fontSize,
  );
}

Future<void> _open(WidgetTester tester) async {
  final trigger = find.byKey(_triggerKey);
  expect(trigger.hitTestable(), findsOneWidget);
  await tester.tap(trigger);
  await tester.pumpAndSettle();
  expect(_surface(), findsOneWidget);
}

FocusNode _triggerFocus(WidgetTester tester, _MenuKind kind) {
  if (kind == _MenuKind.focusedPopup || kind == _MenuKind.direct) {
    return tester
        .state<_MenuHarnessState>(find.byType(_MenuHarness))
        .triggerFocus;
  }
  final trigger = find.descendant(
    of: find.byKey(_triggerKey),
    matching: find.byWidgetPredicate(
      (widget) => widget is InkWell && widget.focusNode != null,
    ),
  );
  expect(trigger, findsOneWidget);
  return tester.widget<InkWell>(trigger).focusNode!;
}

void main() => runSkedMenuStyleTests();

/// Native Windows reuse checks Android styling, not Android device behavior.
void runSkedMenuStyleTests({SkedMenuStyleCapture? capture}) {
  for (final (platform, brightness) in [
    (TargetPlatform.windows, Brightness.light),
    (TargetPlatform.android, Brightness.dark),
  ]) {
    testWidgets(
      'real menu adapters share appearance, disabled behavior and selection: '
      '${platform.name}/${brightness.name}',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = platform == TargetPlatform.windows
            ? const Size(640, 480)
            : const Size(390, 640);
        addTearDown(tester.view.reset);
        final theme = buildAppTheme(
          seedColor: const Color(defaultThemeSeedColorValue),
          brightness: brightness,
          themeColorMode: themeColorModeSingle,
          colorfulUiColorValues: const {},
        );
        _Appearance? reference;
        try {
          for (final kind in _MenuKind.values) {
            final results = <String?>[];
            await tester.pumpWidget(
              _MenuHarness(
                key: ValueKey(kind),
                kind: kind,
                theme: theme,
                results: results,
              ),
            );
            await tester.pumpAndSettle();
            await _open(tester);
            final surface = _surface();
            await capture?.call(
              tester,
              'menu-style-${platform.name}-${brightness.name}-${kind.name}',
            );
            final appearance = _inspectMenu(tester, surface, theme);
            if (reference == null) {
              reference = appearance;
            } else {
              expect(
                appearance,
                reference,
                reason: '${kind.name} must match the rendered popup menu.',
              );
            }
            final surfaceRect = tester.getRect(surface);
            final selected = tester.getRect(_row(surface, _selectedLabel));
            final other = tester.getRect(_row(surface, _otherLabel));
            final disabled = tester.getRect(_row(surface, _disabledLabel));
            final pixels = await _pixels(tester, [
              surfaceRect.topCenter + const Offset(0, 3),
              selected.centerRight + const Offset(-6, 0),
              other.centerRight + const Offset(-6, 0),
              disabled.centerRight + const Offset(-6, 0),
            ]);
            final selectedColor = Color.alphaBlend(
              theme.colorScheme.primary.withValues(
                alpha: platform == TargetPlatform.windows ? .06 : .12,
              ),
              theme.colorScheme.surface,
            );
            for (final index in [0, 2, 3]) {
              _expectColor(
                pixels[index],
                theme.colorScheme.surface,
                '${kind.name} unselected menu surface',
              );
            }
            _expectColor(
              pixels[1],
              selectedColor,
              '${kind.name} selected background must actually be painted',
            );

            await tester.tapAt(disabled.center);
            await tester.pumpAndSettle();
            expect(results, isEmpty);
            expect(_surface(), findsOneWidget);
            await tester.sendKeyEvent(LogicalKeyboardKey.escape);
            await tester.pumpAndSettle();
            expect(_text(_otherLabel), findsNothing);
            expect(results, isEmpty);
            expect(
              tester
                  .state<_MenuHarnessState>(find.byType(_MenuHarness))
                  .selected,
              'selected',
            );

            await _open(tester);
            await tester.tap(_row(_surface(), _otherLabel));
            await tester.pumpAndSettle();
            expect(results, ['other']);
            await _open(tester);
            expect(
              find.descendant(
                of: _row(_surface(), _otherLabel),
                matching: find.byIcon(Icons.check),
              ),
              findsOneWidget,
            );
            expect(
              find.descendant(
                of: _row(_surface(), _selectedLabel),
                matching: find.byIcon(Icons.check),
              ),
              findsNothing,
            );
            await tester.sendKeyEvent(LogicalKeyboardKey.escape);
            await tester.pumpAndSettle();
            expect(results, ['other']);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
          }
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        }
      },
      variant: TargetPlatformVariant.only(platform),
    );
  }

  testWidgets('compact desktop rows expand for large text and multiline labels', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 720);
    addTearDown(tester.view.reset);
    const longLabel =
        'A longer selected choice that remains fully readable across multiple lines';
    const entries = [
      DropdownMenuEntry(value: 'selected', label: longLabel),
      DropdownMenuEntry(value: 'other', label: _otherLabel),
      DropdownMenuEntry(
        value: 'disabled',
        label: _disabledLabel,
        enabled: false,
      ),
    ];
    final theme = buildAppTheme(
      seedColor: const Color(defaultThemeSeedColorValue),
      brightness: Brightness.light,
      themeColorMode: themeColorModeSingle,
      colorfulUiColorValues: const {},
    );
    Size? reference;
    try {
      for (final kind in [_MenuKind.popup, _MenuKind.dropdown]) {
        final results = <String?>[];
        await tester.pumpWidget(
          _MenuHarness(
            key: ValueKey(kind),
            kind: kind,
            theme: theme,
            results: results,
            entries: entries,
            textScale: 2,
          ),
        );
        await tester.pumpAndSettle();
        await _open(tester);
        await capture?.call(
          tester,
          'menu-style-windows-large-text-${kind.name}',
        );
        final surface = _surface();
        final label = _label(surface, longLabel);
        final paragraph = tester.renderObject<RenderParagraph>(label);
        final textRect = tester.getRect(label);
        final rowRect = tester.getRect(_row(surface, longLabel));
        final menuRect = tester.getRect(surface);
        final naturalText = TextPainter(
          text: paragraph.text,
          textDirection: paragraph.textDirection,
          textScaler: paragraph.textScaler,
          locale: paragraph.locale,
          strutStyle: paragraph.strutStyle,
          textHeightBehavior: paragraph.textHeightBehavior,
          textWidthBasis: paragraph.textWidthBasis,
        )..layout(maxWidth: textRect.width);
        addTearDown(naturalText.dispose);
        expect(paragraph.textScaler.scale(13), closeTo(26, .01));
        expect(paragraph.text.style!.fontWeight, FontWeight.w400);
        expect(naturalText.computeLineMetrics().length, greaterThan(1));
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(textRect.height, closeTo(naturalText.height, .1));
        expect(rowRect.height, greaterThan(32));
        expect(rowRect.height, greaterThanOrEqualTo(naturalText.height + 11.9));
        expect(textRect.top - rowRect.top, greaterThanOrEqualTo(5.9));
        expect(rowRect.bottom - textRect.bottom, greaterThanOrEqualTo(5.9));
        expect(menuRect.width, inInclusiveRange(143.9, 360.1));
        expect(menuRect.left, greaterThanOrEqualTo(0));
        expect(menuRect.right, lessThanOrEqualTo(900));
        expect(menuRect.bottom, lessThanOrEqualTo(720));
        final check = tester.getRect(
          find.descendant(
            of: _row(surface, longLabel),
            matching: find.byIcon(Icons.check),
          ),
        );
        expect(check.size, const Size(16, 16));
        expect(check.center.dy, closeTo(rowRect.center.dy, .1));
        final layout = Size(textRect.width, rowRect.height);
        if (reference == null) {
          reference = layout;
        } else {
          expect(layout.width, closeTo(reference.width, .1));
          expect(layout.height, closeTo(reference.height, .1));
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(results, isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  for (final kind in [
    _MenuKind.focusedPopup,
    _MenuKind.direct,
    _MenuKind.dropdown,
    _MenuKind.settings,
  ]) {
    testWidgets(
      '${kind.name} keyboard cancellation restores its original trigger focus',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(640, 480);
        addTearDown(tester.view.reset);
        final results = <String?>[];
        try {
          await tester.pumpWidget(
            _MenuHarness(
              kind: kind,
              theme: buildAppTheme(
                seedColor: const Color(defaultThemeSeedColorValue),
                brightness: Brightness.dark,
                themeColorMode: themeColorModeSingle,
                colorfulUiColorValues: const {},
              ),
              results: results,
            ),
          );
          await tester.pumpAndSettle();
          final focus = _triggerFocus(tester, kind);
          focus.requestFocus();
          await tester.pump();
          for (var attempt = 0; attempt < 2; attempt++) {
            await tester.sendKeyEvent(LogicalKeyboardKey.enter);
            await tester.pumpAndSettle();
            expect(_surface(), findsOneWidget);
            await tester.sendKeyEvent(LogicalKeyboardKey.escape);
            await tester.pumpAndSettle();
            expect(_text(_otherLabel), findsNothing);
            expect(results, isEmpty);
            expect(focus.hasFocus, isTrue);
          }
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        }
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }
}
