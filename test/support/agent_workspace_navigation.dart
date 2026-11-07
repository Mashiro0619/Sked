import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Finder _key(String value) => find.byKey(ValueKey(value));

const _resourceControls = [
  'workspace-main-navigation',
  'workspace-resource-open',
  'workspace-resource-collapse',
  'student-timetable-picker-button',
  'student-empty-resources',
  'general-calendar-selector',
];
const _resourceMoreControls = [
  'student-desktop-toolbar-more',
  'general-desktop-toolbar-more',
];

Iterable<String> _destinationKeys(String name) => [
  'adaptive-shell-$name-destination',
  'adaptive-shell-$name-entry',
  'adaptive-shell-$name-selected',
  name == 'agent' ? 'workspace-agent-entry' : 'workspace-resource-mode-$name',
];

Finder _destination(String name, {bool hitTestable = true}) {
  for (final key in _destinationKeys(name)) {
    final target = hitTestable ? _key(key).hitTestable() : _key(key);
    if (target.evaluate().isNotEmpty) return target.first;
  }
  return find.byKey(const ValueKey('absent-shell-destination'));
}

Finder _firstControl(Iterable<String> keys, {bool hitTestable = true}) {
  for (final key in keys) {
    final target = hitTestable ? _key(key).hitTestable() : _key(key);
    if (target.evaluate().isNotEmpty) return target.first;
  }
  return find.byKey(const ValueKey('absent-shell-resource-control'));
}

/// The first usable product control on the path to the Agent destination.
String? agentShellEntryControl() {
  for (final key in [
    ..._destinationKeys('agent'),
    ..._resourceControls,
    ..._resourceMoreControls,
  ]) {
    if (_key(key).hitTestable().evaluate().length == 1) return key;
  }
  return null;
}

String _controlId(Finder target) =>
    (target.evaluate().single.widget.key! as ValueKey<String>).value;

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  for (var attempt = 0; attempt < 120 && !ready(); attempt++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(ready(), isTrue);
}

Future<String> _openShellResources(WidgetTester tester) async {
  // Closing the outgoing drawer can precede the incoming toolbar's paint.
  // Resolve the current host's control after input becomes available.
  await _until(
    tester,
    () =>
        _firstControl(_resourceControls).evaluate().isNotEmpty ||
        _firstControl(_resourceMoreControls).evaluate().isNotEmpty,
  );
  final direct = _firstControl(_resourceControls);
  if (direct.evaluate().isNotEmpty) {
    final id = _controlId(direct);
    await tester.tap(direct);
    await tester.pump();
    return id;
  }
  // Narrow desktop command bars move their existing resource action into More.
  final more = _firstControl(_resourceMoreControls);
  expect(more, findsOneWidget);
  final moreId = _controlId(more);
  await tester.tap(more);
  await tester.pumpAndSettle();
  const resourceActions = [
    'student-timetable-picker-button',
    'general-calendar-selector',
  ];
  final resources = find.byWidgetPredicate(
    (widget) =>
        widget is PopupMenuItem<dynamic> &&
        resourceActions.any((key) => widget.key == ValueKey(key)),
  );
  await _until(tester, () => resources.evaluate().isNotEmpty);
  final resource = resources.first;
  await tester.ensureVisible(resource);
  await tester.pump();
  expect(resource.hitTestable(), findsOneWidget);
  final resourceId = _controlId(resource);
  await tester.tap(resource.hitTestable());
  await tester.pump();
  return '$moreId / $resourceId';
}

/// Opens the actual navigation entry, including a narrow desktop More menu.
Future<void> openWorkspaceShellResources(WidgetTester tester) =>
    _openShellResources(tester);

/// Opens global Settings through the current shell's visible controls.
Future<({String entry, String control})> openWorkspaceShellSettings(
  WidgetTester tester,
) async {
  const settingsKeys = [
    'adaptive-shell-settings-action',
    'workspace-resource-settings',
    'general-settings-button',
    'student-settings-button',
  ];
  String? resources;
  if (_firstControl(settingsKeys).evaluate().isEmpty) {
    resources = await _openShellResources(tester);
  }
  await _until(
    tester,
    () => _firstControl(settingsKeys, hitTestable: false).evaluate().isNotEmpty,
  );
  final target = _firstControl(settingsKeys, hitTestable: false);
  await tester.ensureVisible(target);
  await tester.pump();
  await _until(tester, () => target.hitTestable().evaluate().length == 1);
  final id = _controlId(target);
  await tester.tap(target.hitTestable());
  await tester.pump();
  return (entry: id, control: resources == null ? id : '$resources / $id');
}

/// Operates the product's bottom bar, rail or main resource drawer.
Future<void> selectAgentShellDestination(
  WidgetTester tester,
  String name,
) async {
  // Fade-through temporarily blocks the still-painted destination's input.
  // Keep that entry and wait below instead of opening another resource menu.
  if (_destination(name, hitTestable: false).evaluate().isEmpty) {
    await _openShellResources(tester);
    await _until(
      tester,
      () => _destination(name, hitTestable: false).evaluate().isNotEmpty,
    );
  }
  final target = _destination(name, hitTestable: false);
  await tester.ensureVisible(target);
  await tester.pump();
  await _until(tester, () => target.hitTestable().evaluate().isNotEmpty);
  expect(target.hitTestable(), findsOneWidget);
  await tester.tap(target.hitTestable());
  await tester.pump();
}

/// History belongs to the same resources pane as the main destinations.
Future<void> openAgentShellHistory(WidgetTester tester) async {
  final history = find
      .byKey(const PageStorageKey('agent-conversation-list'))
      .hitTestable();
  if (history.evaluate().isNotEmpty) return;
  final mainMenu = _key('workspace-main-navigation').hitTestable();
  final resourceMenu = _key('workspace-resource-open').hitTestable();
  final trigger = mainMenu.evaluate().isNotEmpty ? mainMenu : resourceMenu;
  expect(trigger, findsOneWidget);
  await tester.tap(trigger);
  await _until(tester, () => history.evaluate().isNotEmpty);
}
