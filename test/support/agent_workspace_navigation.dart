import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Finder _key(String value) => find.byKey(ValueKey(value));

Finder _destination(String name, {bool hitTestable = true}) {
  for (final key in [
    'adaptive-shell-$name-destination',
    'adaptive-shell-$name-entry',
    'adaptive-shell-$name-selected',
    name == 'agent' ? 'workspace-agent-entry' : 'workspace-resource-mode-$name',
  ]) {
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

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  for (var attempt = 0; attempt < 120 && !ready(); attempt++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(ready(), isTrue);
}

Future<void> _openShellResources(WidgetTester tester) async {
  final direct = _firstControl([
    'workspace-main-navigation',
    'workspace-resource-open',
    'workspace-resource-collapse',
    'student-timetable-picker-button',
    'student-empty-resources',
    'general-calendar-selector',
  ]);
  if (direct.evaluate().isNotEmpty) {
    await tester.tap(direct);
    await tester.pump();
    return;
  }
  // Narrow desktop command bars move their existing resource action into More.
  final more = _firstControl([
    'student-desktop-toolbar-more',
    'general-desktop-toolbar-more',
  ]);
  expect(more, findsOneWidget);
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
  await tester.tap(resource.hitTestable());
  await tester.pump();
}

/// Operates the product's bottom bar, rail or main resource drawer.
Future<void> selectAgentShellDestination(
  WidgetTester tester,
  String name,
) async {
  if (_destination(name).evaluate().isEmpty) {
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
