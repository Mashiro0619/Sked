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
  });

  final _MenuKind kind;
  final ThemeData theme;
  final List<String?> results;

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
    SkedCheckedPopupMenuItem(
      value: 'selected',
      checked: selected == 'selected',
      label: _selectedLabel,
    ),
    SkedCheckedPopupMenuItem(
      value: 'other',
      checked: selected == 'other',
      label: _otherLabel,
    ),
    const SkedCheckedPopupMenuItem(
      value: 'disabled',
      checked: false,
      enabled: false,
      label: _disabledLabel,
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
      dropdownMenuEntries: _entries,
      onSelected: select,
    ),
    _MenuKind.settings => SettingsChoiceTile<String>(
      key: _triggerKey,
      title: 'Layout',
      icon: Icons.view_week_outlined,
      value: selected,
      entries: _entries,
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
  final material = tester.widget<Material>(surface);
  expect(material.color, theme.colorScheme.surface.withValues(alpha: 1));
  expect(material.surfaceTintColor, Colors.transparent);
  expect(material.elevation, 3);
  expect(material.shape, isA<OutlinedBorder>());
  final shape = material.shape! as OutlinedBorder;
  expect(shape.side.style, BorderStyle.solid);
  expect(shape.side.width, greaterThanOrEqualTo(1));
  expect(shape.side.color.a, greaterThan(0));
  final outline = shape.getOuterPath(const Rect.fromLTWH(0, 0, 100, 100));
  expect(outline.contains(const Offset(50, 50)), isTrue);
  expect(outline.contains(const Offset(.1, .1)), isFalse);
  if (theme.platform == TargetPlatform.windows) {
    expect(shape, isA<RoundedRectangleBorder>());
    expect(
      (shape as RoundedRectangleBorder).borderRadius.resolve(TextDirection.ltr),
      BorderRadius.circular(8),
    );
  }
  for (final label in [_selectedLabel, _otherLabel, _disabledLabel]) {
    final row = _row(surface, label);
    expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
    expect(
      _paintedTextStyle(tester, _label(surface, label)).fontWeight,
      FontWeight.w600,
    );
  }
  final normal = _paintedTextStyle(tester, _label(surface, _otherLabel));
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
              theme.colorScheme.primary.withValues(alpha: .12),
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
