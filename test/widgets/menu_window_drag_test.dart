import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/desktop_window_bridge.dart';
import 'package:sked/widgets/desktop_window_drag_guard.dart';
import 'package:sked/widgets/desktop_window_host.dart';
import 'package:sked/widgets/sked_date_picker.dart';
import 'package:sked/widgets/sked_dropdown_menu.dart';
import 'package:sked/widgets/sked_popup_menu.dart';
import 'package:sked/widgets/sked_week_picker.dart';

import '../support/mobile_layout_data.dart';
import '../support/workspace_harness.dart';

const _channel = MethodChannel('com.mashiro.sked/window');
final _commands = <String>[];

Finder _key(String value) => find.byKey(ValueKey(value));

Finder _text(String label) =>
    find.byWidgetPredicate((widget) => widget is Text && widget.data == label);

Finder _option(String label) => find.ancestor(
  of: _text(label),
  matching: find.byWidgetPredicate(
    (widget) => widget is PopupMenuItem || widget is MenuItemButton,
  ),
);

class _Storage extends WorkspaceMemoryStorage {
  _Storage(super.data);
  int writes = 0;

  @override
  Future<void> save(AppData value) async {
    writes++;
    await super.save(value);
  }
}

Future<void> _mouseClick(WidgetTester tester, Finder target) async {
  expect(target.hitTestable(), findsOneWidget);
  await _mouseClickAt(tester, tester.getCenter(target));
}

Future<void> _mouseClickAt(WidgetTester tester, Offset point) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.down(point);
  await mouse.up();
  await tester.pumpAndSettle();
  await mouse.removePointer();
}

Future<void> _drag(WidgetTester tester, Offset point) async {
  _commands.clear();
  await tester.dragFrom(
    point,
    const Offset(80, 0),
    kind: PointerDeviceKind.mouse,
  );
  await tester.pumpAndSettle();
}

Future<void> _escape(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await tester.pumpAndSettle();
}

typedef _MenuIdentity = ({Element entry, ModalRoute<dynamic> route});

_MenuIdentity _menuIdentity(WidgetTester tester, Finder option) {
  final entry = tester.element(option);
  return (entry: entry, route: ModalRoute.of(entry)!);
}

void _expectSameMenu(
  WidgetTester tester,
  Finder option,
  _MenuIdentity original,
) {
  expect(original.entry.mounted, isTrue);
  expect(original.route.isActive, isTrue);
  expect(tester.element(option), same(original.entry));
  expect(ModalRoute.of(tester.element(option)), same(original.route));
}

void _expectChecked(Finder selected, Finder other) {
  expect(
    find.descendant(of: selected, matching: find.byIcon(Icons.check)),
    findsOneWidget,
  );
  expect(
    find.descendant(of: other, matching: find.byIcon(Icons.check)),
    findsNothing,
  );
}

enum _Adapter { dropdown, focusedPopup, direct, nestedPopup }

const _week = 'Week choice';
const _day = 'Day choice';

class _Host extends StatefulWidget {
  const _Host(this.adapter);
  final _Adapter adapter;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  final observer = DesktopWindowModalObserver();
  final rootNavigator = GlobalKey<NavigatorState>();
  final nestedNavigator = GlobalKey<NavigatorState>();
  final triggerFocus = FocusNode();
  final draft = TextEditingController(text: 'Unsaved editor draft');
  String selection = 'week';
  int choices = 0, backgroundActions = 0;

  void choose(String value) => setState(() {
    selection = value;
    choices++;
  });

  List<PopupMenuEntry<String>> entries() => [
    SkedCheckedPopupMenuItem(
      value: 'week',
      checked: selection == 'week',
      label: _week,
    ),
    SkedCheckedPopupMenuItem(
      value: 'day',
      checked: selection == 'day',
      label: _day,
    ),
  ];

  Widget control() {
    switch (widget.adapter) {
      case _Adapter.dropdown:
        return SizedBox(
          width: 180,
          child: SkedDropdownMenu<String>(
            key: const ValueKey('menu-drag-trigger'),
            initialSelection: selection,
            expandedInsets: EdgeInsets.zero,
            dropdownMenuEntries: const [
              DropdownMenuEntry(value: 'week', label: _week),
              DropdownMenuEntry(value: 'day', label: _day),
            ],
            onSelected: (value) {
              if (value != null) choose(value);
            },
          ),
        );
      case _Adapter.direct:
        return Builder(
          builder: (anchor) => TextButton(
            key: const ValueKey('menu-drag-trigger'),
            onPressed: () async {
              final button = anchor.findRenderObject()! as RenderBox;
              final overlay =
                  Navigator.of(anchor).overlay!.context.findRenderObject()!
                      as RenderBox;
              final position = button.localToGlobal(
                Offset(0, button.size.height),
                ancestor: overlay,
              );
              final value = await showSkedMenu<String>(
                context: anchor,
                position: RelativeRect.fromRect(
                  position & Size(button.size.width, 0),
                  Offset.zero & overlay.size,
                ),
                items: entries(),
              );
              if (mounted && value != null) choose(value);
            },
            child: const Text('Choices'),
          ),
        );
      case _Adapter.focusedPopup:
      case _Adapter.nestedPopup:
        return SkedPopupMenuButton<String>(
          key: const ValueKey('menu-drag-trigger'),
          focusNode: widget.adapter == _Adapter.focusedPopup
              ? triggerFocus
              : null,
          itemBuilder: (_) => entries(),
          onSelected: choose,
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Choices'),
          ),
        );
    }
  }

  Widget page() => Scaffold(
    key: const ValueKey('menu-drag-page'),
    appBar: WorkbenchAppBar(
      key: const ValueKey('menu-drag-toolbar'),
      title: const Text('Workspace'),
      // Actions are siblings above flexibleSpace's DesktopDragRegion. A hit
      // test of just the registered region would incorrectly call these blank.
      actions: [
        TextButton(
          key: const ValueKey('menu-drag-action'),
          onPressed: () => setState(() => backgroundActions++),
          child: const Text('Background action'),
        ),
        control(),
      ],
    ),
    body: const Text('Fixture page'),
  );

  Future<void> showRootDialog() => showDialog<void>(
    context: rootNavigator.currentContext!,
    builder: (_) => const AlertDialog(
      key: ValueKey('menu-drag-dialog'),
      title: Text('Unrelated dialog'),
    ),
  );

  Future<void> showEditorDialog() => showDialog<void>(
    context: rootNavigator.currentContext!,
    barrierDismissible: false,
    builder: (_) => DesktopEditorWindowGuard(
      active: true,
      child: AlertDialog(
        key: const ValueKey('menu-drag-editor'),
        title: const Text('Editor'),
        content: TextField(controller: draft),
        actions: [
          SkedPopupMenuButton<String>(
            key: const ValueKey('menu-drag-editor-menu'),
            itemBuilder: (_) => entries(),
            onSelected: choose,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Text('Editor choices'),
            ),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: rootNavigator,
    navigatorObservers: [observer],
    theme: ThemeData(platform: TargetPlatform.windows),
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) =>
        DesktopWindowHost(modalObserver: observer, child: child!),
    home: widget.adapter == _Adapter.nestedPopup
        ? Navigator(
            key: nestedNavigator,
            onGenerateRoute: (_) =>
                MaterialPageRoute<void>(builder: (_) => page()),
          )
        : page(),
  );

  @override
  void dispose() {
    draft.dispose();
    triggerFocus.dispose();
    observer.dispose();
    super.dispose();
  }
}

Future<_HostState> _mountHost(WidgetTester tester, _Adapter adapter) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1000, 760);
  addTearDown(tester.view.reset);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
  await tester.pumpWidget(_Host(adapter));
  await tester.pumpAndSettle();
  return tester.state<_HostState>(find.byType(_Host));
}

void main() => runMenuWindowDragTests();

void runMenuWindowDragTests() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    final bridge = DesktopWindowBridge.instance;
    final previous = (
      available: bridge.available,
      maximized: bridge.maximized,
      focused: bridge.focused,
      hovered: bridge.maximizeHovered,
    );
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_channel, (call) async {
      _commands.add(call.method);
      return call.method == 'initialize'
          ? {'maximized': false, 'focused': true}
          : null;
    });
    final platform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await bridge.initialize();
    } finally {
      debugDefaultTargetPlatformOverride = platform;
    }
    _commands.clear();
    addTearDown(() {
      messenger.setMockMethodCallHandler(_channel, null);
      bridge.available = previous.available;
      bridge.maximized = previous.maximized;
      bridge.focused = previous.focused;
      bridge.maximizeHovered = previous.hovered;
    });
  });

  for (final (name, mode, compact) in [
    ('student week/day', AppMode.student, false),
    ('general view', AppMode.general, false),
    ('compact More', AppMode.student, true),
  ]) {
    testWidgets('open $name menu survives repeated blank caption drags', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(compact ? 520 : 1366, 800);
      addTearDown(tester.view.reset);
      final storage = _Storage(mobileLayoutData().copyWith(activeMode: mode));
      final provider = await workspaceProvider(storage: storage, locale: 'zh');
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        provider.dispose();
      });
      await tester.pumpWidget(
        WorkspaceHarness(provider: provider, locale: const Locale('zh')),
      );
      await tester.pumpAndSettle();
      final trigger = _key(
        compact
            ? 'student-desktop-toolbar-more'
            : mode == AppMode.student
            ? 'student-view-toggle'
            : 'general-view-switcher',
      );
      final l10n = AppLocalizations.of(tester.element(trigger));
      final date = tester.getRect(
        _key(
          mode == AppMode.student
              ? 'student-week-picker-button'
              : 'general-date-picker',
        ),
      );
      final button = tester.getRect(trigger);
      expect(button.left - date.right, greaterThan(8));
      final blank = Offset((date.right + button.left) / 2, date.center.dy);

      // Establish the blank point through actual pointer dispatch before a
      // modal barrier exists. Do not use the guard under test to choose it.
      await _drag(tester, blank);
      expect(_commands.where((value) => value == 'startDrag'), hasLength(1));
      final before = storage.data.toJson();
      final liveBefore = provider.workspaceView.data.toJson();
      final writes = storage.writes;
      Finder choice(bool week) => compact
          ? _key('student-view-choice-${week ? 'week' : 'day'}')
          : _option(week ? l10n.viewWeek : l10n.viewDay);
      void unchanged() {
        expect(storage.data.toJson(), before);
        expect(storage.writes, writes);
        expect(provider.workspaceView.data.toJson(), liveBefore);
      }

      await _mouseClick(tester, trigger);
      expect(choice(false), findsOneWidget);
      final menu = _menuIdentity(tester, choice(false));

      // The channel spy returns immediately: WM_NCLBUTTONDOWN must never be
      // entered by a widget test using synthesized pointer events.
      for (var attempt = 0; attempt < 2; attempt++) {
        await _drag(tester, blank);
        expect(_commands.where((value) => value == 'startDrag'), hasLength(1));
        _expectSameMenu(tester, choice(false), menu);
        _expectChecked(choice(true), choice(false));
        unchanged();
      }
      await _escape(tester);
      expect(choice(false), findsNothing);
      unchanged();

      await _mouseClick(tester, trigger);
      _commands.clear();
      await _mouseClickAt(tester, blank);
      await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      expect(choice(false), findsNothing);
      expect(_commands, isNot(contains('startDrag')));
      unchanged();

      await _mouseClick(tester, trigger);
      _expectChecked(choice(true), choice(false));
      await tester.ensureVisible(choice(false));
      await tester.pumpAndSettle();
      await _drag(tester, tester.getCenter(choice(false)));
      expect(_commands, isNot(contains('startDrag')));
      unchanged();
      if (choice(false).evaluate().isNotEmpty) await _escape(tester);

      await _mouseClick(tester, trigger);
      await _drag(tester, date.center);
      expect(_commands, isNot(contains('startDrag')));
      expect(find.byType(SkedWeekPicker), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is SkedDatePicker && !widget.embedded,
        ),
        findsNothing,
      );
      unchanged();
      if (choice(false).evaluate().isNotEmpty) await _escape(tester);
      await _mouseClick(tester, trigger);
      await _escape(tester);
      expect(choice(false), findsNothing);
      unchanged();

      await _mouseClick(tester, trigger);
      await tester.ensureVisible(choice(false));
      await tester.pumpAndSettle();
      _commands.clear();
      await _mouseClick(tester, choice(false));
      expect(_commands, isNot(contains('startDrag')));
      expect(choice(false), findsNothing);
      await _mouseClick(tester, trigger);
      _expectChecked(choice(false), choice(true));
      if (mode == AppMode.student && !compact) {
        // This first row crosses the 48 px toolbar edge. Clicking the overlap
        // must select Week, not be intercepted as blank caption above it.
        final toolbar = tester.getRect(_key('student-workspace-toolbar'));
        final week = tester.getRect(choice(true));
        final overlap = week.intersect(toolbar);
        expect(overlap.height, greaterThan(0));
        _commands.clear();
        await _mouseClickAt(tester, overlap.center);
        expect(_commands, isNot(contains('startDrag')));
        expect(choice(false), findsNothing);
        await _mouseClick(tester, trigger);
        _expectChecked(choice(true), choice(false));
      }
      await _escape(tester);
      expect(choice(false), findsNothing);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  }

  for (final adapter in _Adapter.values) {
    testWidgets('${adapter.name} menu protects only real blank caption space', (
      tester,
    ) async {
      final host = await _mountHost(tester, adapter);
      final page = tester.element(_key('menu-drag-page'));
      final toolbar = tester.getRect(_key('menu-drag-toolbar'));
      final blank = Offset(300, toolbar.center.dy);
      final action = tester.getCenter(_key('menu-drag-action'));
      final trigger = _key('menu-drag-trigger');
      await _drag(tester, blank);
      expect(_commands.where((value) => value == 'startDrag'), hasLength(1));
      await _mouseClick(tester, trigger);
      expect(_option(_day), findsOneWidget);
      final menu = adapter == _Adapter.dropdown
          ? null
          : _menuIdentity(tester, _option(_day));
      await _drag(tester, blank);
      expect(_commands.where((value) => value == 'startDrag'), hasLength(1));
      if (menu != null) {
        _expectSameMenu(tester, _option(_day), menu);
        _expectChecked(_option(_week), _option(_day));
        expect(host.selection, 'week');
        expect(host.choices, 0);
        await _drag(tester, blank);
        expect(_commands.where((value) => value == 'startDrag'), hasLength(1));
        _expectSameMenu(tester, _option(_day), menu);
        _expectChecked(_option(_week), _option(_day));
        await _escape(tester);
      }
      expect(_option(_day), findsNothing);
      expect(host.selection, 'week');
      expect(host.choices, 0);
      expect(tester.element(_key('menu-drag-page')), same(page));

      await _mouseClick(tester, trigger);
      _commands.clear();
      await _mouseClickAt(tester, blank);
      await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      expect(_option(_day), findsNothing);
      expect(_commands, isNot(contains('startDrag')));
      expect(host.choices, 0);

      await _mouseClick(tester, trigger);
      await _drag(tester, action);
      expect(_commands, isNot(contains('startDrag')));
      expect(host.backgroundActions, 0);
      expect(host.choices, 0);
      if (_option(_day).evaluate().isNotEmpty) await _escape(tester);
      await _mouseClick(tester, trigger);
      await _drag(tester, tester.getCenter(_option(_day)));
      expect(_commands, isNot(contains('startDrag')));
      expect(host.choices, 0);
      if (_option(_day).evaluate().isNotEmpty) await _escape(tester);

      await _mouseClick(tester, trigger);
      await _mouseClick(tester, _option(_day));
      expect(host.selection, 'day');
      expect(host.choices, 1);
      expect(_option(_day), findsNothing);
      await _mouseClick(tester, trigger);
      _expectChecked(_option(_day), _option(_week));
      await _escape(tester);
      expect(_option(_day), findsNothing);
      expect(host.choices, 1);
      expect(host.rootNavigator.currentState!.canPop(), isFalse);
      if (adapter == _Adapter.nestedPopup) {
        expect(host.nestedNavigator.currentState!.canPop(), isFalse);
      }
      expect(tester.element(_key('menu-drag-page')), same(page));
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  }

  for (final menuBehind in [false, true]) {
    testWidgets(
      'root dialog does not borrow menu dragging with menuBehind=$menuBehind',
      (tester) async {
        final host = await _mountHost(tester, _Adapter.nestedPopup);
        final page = tester.element(_key('menu-drag-page'));
        final blank = Offset(
          300,
          tester.getRect(_key('menu-drag-toolbar')).center.dy,
        );
        _MenuIdentity? menu;
        if (menuBehind) {
          await _mouseClick(tester, _key('menu-drag-trigger'));
          expect(_option(_day), findsOneWidget);
          menu = _menuIdentity(tester, _option(_day));
        }
        unawaited(host.showRootDialog());
        await tester.pumpAndSettle();
        expect(host.nestedNavigator.currentState!.canPop(), menuBehind);
        await _drag(tester, blank);
        expect(_commands, isNot(contains('startDrag')));
        expect(_key('menu-drag-dialog'), findsOneWidget);
        expect(host.backgroundActions, 0);
        expect(host.choices, 0);
        expect(host.nestedNavigator.currentState!.canPop(), menuBehind);
        host.rootNavigator.currentState!.pop();
        await tester.pumpAndSettle();
        expect(host.nestedNavigator.currentState!.canPop(), menuBehind);
        if (menuBehind) expect(_option(_day), findsOneWidget);
        expect(tester.element(_key('menu-drag-page')), same(page));
        await _drag(tester, blank);
        expect(_commands.where((value) => value == 'startDrag'), hasLength(1));
        if (menu != null) {
          _expectSameMenu(tester, _option(_day), menu);
          expect(host.nestedNavigator.currentState!.canPop(), isTrue);
          await _drag(tester, blank);
          expect(
            _commands.where((value) => value == 'startDrag'),
            hasLength(1),
          );
          _expectSameMenu(tester, _option(_day), menu);
          _expectChecked(_option(_week), _option(_day));
          expect(host.selection, 'week');
          expect(host.choices, 0);
          await _escape(tester);
        }
        expect(_option(_day), findsNothing);
        expect(host.nestedNavigator.currentState!.canPop(), isFalse);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }

  testWidgets(
    'editor keeps blank caption dragging while its own popup is open',
    (tester) async {
      final host = await _mountHost(tester, _Adapter.focusedPopup);
      final blank = Offset(
        300,
        tester.getRect(_key('menu-drag-toolbar')).center.dy,
      );
      unawaited(host.showEditorDialog());
      await tester.pumpAndSettle();
      final editor = tester.element(_key('menu-drag-editor'));
      await _drag(tester, blank);
      expect(_commands.where((value) => value == 'startDrag'), hasLength(1));
      expect(tester.element(_key('menu-drag-editor')), same(editor));

      await _mouseClick(tester, _key('menu-drag-editor-menu'));
      expect(_option(_day), findsOneWidget);
      final menu = _menuIdentity(tester, _option(_day));
      for (var attempt = 0; attempt < 2; attempt++) {
        await _drag(tester, blank);
        expect(_commands.where((value) => value == 'startDrag'), hasLength(1));
        _expectSameMenu(tester, _option(_day), menu);
        _expectChecked(_option(_week), _option(_day));
        expect(tester.element(_key('menu-drag-editor')), same(editor));
        expect(host.draft.text, 'Unsaved editor draft');
        expect(host.selection, 'week');
        expect(host.choices, 0);
      }
      await _escape(tester);
      expect(_option(_day), findsNothing);
      expect(tester.element(_key('menu-drag-editor')), same(editor));
      expect(host.draft.text, 'Unsaved editor draft');
      expect(host.selection, 'week');
      expect(host.choices, 0);
      expect(host.backgroundActions, 0);
      await _drag(tester, blank);
      expect(_commands.where((value) => value == 'startDrag'), hasLength(1));
      host.rootNavigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(_key('menu-drag-editor'), findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  for (final buttons in [kPrimaryMouseButton, kSecondaryMouseButton]) {
    testWidgets(
      'a caption press ($buttons) under menu A cannot act on replacement menu B',
      (tester) async {
        final host = await _mountHost(tester, _Adapter.focusedPopup);
        final trigger = _key('menu-drag-trigger');
        final blank = Offset(
          300,
          tester.getRect(_key('menu-drag-toolbar')).center.dy,
        );
        await _mouseClick(tester, trigger);
        final menuA = tester.element(_option(_day));
        final mouse = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
          buttons: buttons,
        );
        final launcher = tester.state<PopupMenuButtonState<String>>(
          find.descendant(
            of: trigger,
            matching: find.byWidgetPredicate(
              (widget) => widget is PopupMenuButton<String>,
            ),
          ),
        );
        _commands.clear();
        await mouse.down(blank);
        // Replace before TapGestureRecognizer's deadline, while the physical
        // pointer still belongs to the original caption press.
        host.rootNavigator.currentState!.removeRoute(ModalRoute.of(menuA)!);
        launcher.showButtonMenu();
        await tester.pumpAndSettle();
        expect(menuA.mounted, isFalse);
        final menuB = tester.element(_option(_day));
        expect(menuB, isNot(same(menuA)));

        await mouse.up();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        await mouse.removePointer();
        expect(menuB.mounted, isTrue);
        expect(_option(_day), findsOneWidget);
        expect(_commands, isNot(contains('startDrag')));
        expect(_commands, isNot(contains('systemMenu')));
        expect(host.choices, 0);
        await _mouseClick(tester, _option(_day));
        expect(host.selection, 'day');
        expect(host.choices, 1);
        expect(_option(_day), findsNothing);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }
}
